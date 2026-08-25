import http from "node:http";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

type JsonRecord = Record<string, unknown>;
type ListenableApp = { listen: (port: number, hostname: string, callback: () => void) => http.Server };

function expect(value: unknown, message: string, details?: unknown): void {
  if (!value) throw new Error(`${message}${details == null ? "" : ` :: ${JSON.stringify(details)}`}`);
}

function listen(app: ListenableApp): Promise<http.Server> {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function close(server: http.Server): Promise<void> {
  return new Promise((resolve, reject) => server.close((err) => err ? reject(err) : resolve()));
}

async function post(baseUrl: string, action: string, body: JsonRecord = {}, headers: Record<string, string> = {}): Promise<JsonRecord> {
  const response = await fetch(`${baseUrl}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json", ...headers },
    body: JSON.stringify(body)
  });
  return { ...await response.json() as JsonRecord, http_status: response.status };
}

async function main(): Promise<void> {
  const tempDir = mkdtempSync(join(tmpdir(), "sf-economy-quarantine-"));
  process.env.CRUCIBLE_LEDGER_PATH = join(tempDir, "crucible.json");
  process.env.HONEY_LEDGER_PATH = join(tempDir, "honey.json");
  process.env.VS_ADMIN_TOKEN = "quarantine_admin_fixture";
  process.env.VS_ADMIN_ROLE = "ops_admin";
  process.env.VS_MATCH_AUTHORITY_TOKEN = "quarantine_authority_fixture";
  process.env.VS_SPECTATOR_ADMIN_TOKEN = "quarantine_spectator_fixture";
  process.env.VS_CONTEST_DASH_PATH = join(tempDir, "contest-dash.json");
  process.env.VS_ECONOMY_MUTATIONS_ENABLED = "false";
  process.env.VS_ECONOMY_RESET_ENABLED = "false";

  const [{ createApp }, { MoneyLedger }, { HoneyLedger }, { CrucibleLedger }, contestDash] = await Promise.all([
    import("./server.js"), import("./moneyLedger.js"), import("./honeyLedger.js"), import("./crucibleLedger.js"), import("./contestDash.js")
  ]);
  const server = await listen(createApp());
  const address = server.address();
  if (address == null || typeof address === "string") throw new Error("missing listen address");
  const root = `http://127.0.0.1:${address.port}`;
  const base = `${root}/v1`;
  const adminHeaders = { "x-admin-token": "quarantine_admin_fixture", "x-admin-role": "ops_admin" };

  const quarantined = [
    "open_money_escrow", "settle_money_match", "refund_money_match", "open_async_entry_escrow",
    "submit_async_contest_result", "preview_async_contest_result_payout_report",
    "preview_async_contest_payout_report", "approve_async_contest_payout_report", "settle_async_contest",
    "settle_async_contest_payouts", "settle_async_contest_payout_percentages", "refund_async_entry",
    "record_honey_activity", "grant_honey", "debit_honey", "debit_hive_honey_purchase",
    "debug_set_honey_balance", "preview_crucible_entry", "update_crucible_config", "open_crucible_escrow",
    "settle_crucible_match", "refund_crucible_match", "resolve_crucible_review", "record_crucible_lifecycle",
    "record_competitive_wax_result", "award_crucible_wax", "debug_set_crucible_balance"
  ];
  const superseded = new Set([
    "record_honey_activity", "grant_honey", "debit_hive_honey_purchase", "debug_set_honey_balance",
    "update_crucible_config", "open_crucible_escrow", "settle_crucible_match", "refund_crucible_match",
    "resolve_crucible_review", "record_crucible_lifecycle", "record_competitive_wax_result",
    "award_crucible_wax", "debug_set_crucible_balance"
  ]);

  try {
    for (const prefix of [root, base]) {
      for (const action of quarantined) {
        const result = await post(prefix, action);
        const moved = superseded.has(action)
          && result.http_status === 410 && result.err === "platform_economy_authority_required";
        const disabled = result.http_status === 503
          && (["economy_disabled", "platform_economy_delivery_disabled"].includes(String(result.err)));
        const playerAuthClosed = action === "debit_honey" && result.http_status === 401
          && result.err === "player_token_required";
        expect(moved || disabled || playerAuthClosed,
          `quarantine failed for ${prefix}/${action}`, result);
      }
    }

    for (const path of ["contest_dash/config", "contest_dash/delete"]) {
      const result = await post(base, path, {}, adminHeaders);
      expect(result.http_status === 503 && result.err === "economy_disabled", `dashboard mutation escaped quarantine: ${path}`, result);
    }
    const directDashSave = await contestDash.saveContestDashContest({ id: "DIRECT_BLOCKED" });
    const directDashDelete = await contestDash.deleteContestDashContest({ id: "DIRECT_BLOCKED" });
    expect(directDashSave.err === "economy_disabled" && directDashDelete.err === "economy_disabled",
      "direct contest-dashboard mutation bypassed guard", { directDashSave, directDashDelete });
    expect(!existsSync(process.env.VS_CONTEST_DASH_PATH), "direct contest-dashboard guard wrote storage");

    const health = await fetch(`${root}/health`).then((res) => res.json() as Promise<JsonRecord>);
    const healthKeys = Object.keys(health).sort();
    expect(JSON.stringify(healthKeys) === JSON.stringify([
      "admin_auth_required", "authenticated_1v1_slice_enabled", "build", "contest_rewards_enabled",
      "crucible_wax_settlement_enabled", "ctf_bot_fallback_enabled",
      "durable_public_1v1_enabled", "economy_mutations_enabled", "embedded_settlement_workers",
      "hctf_live_secrecy_certified",
      "match_authority_auth_required", "match_verification_enabled", "ok", "ops_reconcile_interval_ms",
      "platform_economy_delivery_enabled", "player_auth_configured",
      "public_1v1_enabled", "public_2v2_enabled", "public_3p_ffa_enabled", "public_4p_ffa_enabled",
      "public_async_3map_enabled", "public_async_5map_enabled",
      "public_contests_enabled", "public_contests_store_authorized",
      "public_crucible_enabled",
      "public_ctf_enabled", "public_gauntlet_enabled", "public_hctf_enabled", "public_leaderboards_enabled",
      "public_time_puzzles_enabled",
      "rank_mutations_enabled", "remote_ops_config_enabled", "service", "storage"
    ]), "health disclosed unexpected fields", health);
    expect(health.economy_mutations_enabled === false && health.admin_auth_required === true
      && health.match_authority_auth_required === true && health.authenticated_1v1_slice_enabled === false
      && health.match_verification_enabled === false && health.durable_public_1v1_enabled === false
      && health.platform_economy_delivery_enabled === false && health.embedded_settlement_workers === true
      && health.public_1v1_enabled === false && health.public_2v2_enabled === false
      && health.public_3p_ffa_enabled === false && health.public_4p_ffa_enabled === false
      && health.public_async_3map_enabled === false
      && health.public_async_5map_enabled === false && health.public_ctf_enabled === false
      && health.public_hctf_enabled === false && health.hctf_live_secrecy_certified === false
      && health.public_crucible_enabled === false && health.crucible_wax_settlement_enabled === false
      && health.ctf_bot_fallback_enabled === false && health.public_leaderboards_enabled === false
      && health.public_contests_enabled === false && health.public_time_puzzles_enabled === false
      && health.public_gauntlet_enabled === false && health.public_contests_store_authorized === false
      && health.rank_mutations_enabled === false,
      "health auth/quarantine flags incorrect", health);

    const freeContext = { free_roll: true, paid_entry: false, mode: "1V1", vs_ruleset: "STANDARD" };
    const invite = await post(base, "create_invite", {
      profile: { uid: "free_host", display_name: "Free Host", balance_cents: 999999 }, context: freeContext
    });
    expect(invite.ok === true, "free invite failed", invite);
    const inviteSession = invite.session as JsonRecord;
    expect(!("balance_cents" in (inviteSession.host as JsonRecord)), "session leaked private balance", inviteSession);
    const joined = await post(base, "join_invite", {
      invite_code: invite.invite_code,
      profile: { uid: "free_guest", display_name: "Free Guest", crucible_wax_millis: 888888 }
    });
    expect(joined.ok === true, "free join failed", joined);
    expect(!("crucible_wax_millis" in ((joined.session as JsonRecord).guest as JsonRecord)), "session leaked Crucible balance", joined);

    const publish = await post(base, "publish_intent", {
      session_id: invite.session_id, uid: "free_host", command: { type: "MOVE", issued_tick: 1, execute_tick: 4 }
    });
    expect(publish.ok === true, "free intent publish failed", publish);
    const poll = await post(base, "poll_intents", { session_id: invite.session_id, uid: "free_guest", after_seq: 0 });
    expect(poll.ok === true && Array.isArray(poll.events), "free intent poll failed", poll);

    const queued = await post(base, "enqueue_quick_match", {
      profile: { uid: "free_bot_player", display_name: "Free Bot Player" }, context: freeContext
    });
    const filled = await post(base, "fill_free_bot_match", { ticket_id: queued.ticket_id, bot_name: "Free Bot" });
    expect(filled.ok === true && ((filled.session as JsonRecord).status === "started"), "restricted free bot fill failed", filled);
    const debugDenied = await post(base, "debug_fill_session", { session_id: filled.session_id });
    expect(debugDenied.http_status === 401 && debugDenied.err === "admin_auth_required", "debug fill was public", debugDenied);
    const debugForged = await post(base, "debug_fill_session", { session_id: filled.session_id }, {
      "x-admin-token": "forged", "x-admin-role": "ops_admin"
    });
    expect(debugForged.http_status === 401, "forged debug authorization passed", debugForged);

    const privateReads = [
      "get_money_transactions", "get_money_payout_summary", "debug_get_money_ledger_snapshot", "list_async_contest_results",
      "list_async_contest_payout_reports", "get_honey_transactions",
      "preview_hive_honey_purchase", "debug_get_honey_ledger_snapshot", "debug_get_crucible_snapshot", "get_wax_audit_snapshot"
    ];
    for (const action of privateReads) {
      const changedUid = await post(base, action, { player_id: "some_other_player", uid: "some_other_player" });
      expect(changedUid.http_status === 401 && changedUid.err === "admin_auth_required", `private read was not admin-only: ${action}`, changedUid);
      const forged = await post(base, action, { player_id: "some_other_player" }, {
        "x-admin-token": "forged", "x-admin-role": "ops_admin"
      });
      expect(forged.http_status === 401, `forged admin read passed: ${action}`, forged);
    }
    const honeyRead = await post(base, "get_honey_balance", { player_id: "some_other_player" });
    expect(honeyRead.http_status === 401 && honeyRead.err === "player_token_required",
      "Honey balance read was not player-authenticated", honeyRead);

    process.env.VS_ECONOMY_MUTATIONS_ENABLED = "true";
    const missingAuthority = await post(base, "settle_money_match", { session_id: "forged", winner_id: "attacker" });
    const forgedAuthority = await post(base, "settle_money_match", { session_id: "forged", winner_id: "attacker" }, {
      "x-match-authority-token": "forged"
    });
    expect(missingAuthority.http_status === 401 && forgedAuthority.http_status === 401,
      "missing or forged match authority authorized", { missingAuthority, forgedAuthority });
    const missingAdmin = await post(base, "preview_async_contest_payout_report", { contest_id: "forged" });
    const forgedAdmin = await post(base, "preview_async_contest_payout_report", { contest_id: "forged" }, {
      "x-admin-token": "forged", "x-admin-role": "ops_admin"
    });
    expect(missingAdmin.http_status === 401 && forgedAdmin.http_status === 401,
      "missing or forged admin authorized", { missingAdmin, forgedAdmin });
    process.env.VS_ECONOMY_MUTATIONS_ENABLED = "false";

    const spectatorMissing = await post(base, "create_spectator_grant", { session_id: invite.session_id });
    expect(spectatorMissing.http_status === 403 && spectatorMissing.err === "spectator_unauthorized",
      "missing spectator credential did not fail closed", spectatorMissing);
    const spectatorForged = await post(base, "create_spectator_grant", { session_id: invite.session_id }, { Authorization: "Bearer forged" });
    expect(spectatorForged.http_status === 403, "forged spectator credential passed", spectatorForged);

    const freeSnapshotBefore = await post(base, "debug_get_money_ledger_snapshot", {}, adminHeaders);
    const left = await post(base, "leave_session", { session_id: invite.session_id, uid: "free_host" });
    expect(left.ok === true, "free leave failed", left);
    const freeSnapshotAfter = await post(base, "debug_get_money_ledger_snapshot", {}, adminHeaders);
    expect(JSON.stringify(freeSnapshotBefore.ledger) === JSON.stringify(freeSnapshotAfter.ledger), "free leave mutated economy", { freeSnapshotBefore, freeSnapshotAfter });

    const paidInvite = await post(base, "create_invite", {
      profile: { uid: "paid_host", display_name: "Paid Host" }, context: { paid_entry: true, wager_cents: 100 }
    });
    expect(paidInvite.http_status === 503 && paidInvite.err === "economy_disabled", "paid invite was not quarantined", paidInvite);
    const paidFriendInvite = await post(base, "create_friend_invite", {
      profile: { uid: "paid_friend_host", display_name: "Paid Friend Host" }, target_uid: "paid_friend_guest",
      context: { paid_entry: true, wager_cents: 100 }
    });
    expect(paidFriendInvite.http_status === 503 && paidFriendInvite.err === "economy_disabled", "paid friend invite was not quarantined", paidFriendInvite);

    process.env.VS_ECONOMY_MUTATIONS_ENABLED = "true";
    const preexistingPaidInvite = await post(base, "create_invite", {
      profile: { uid: "preexisting_paid_host", display_name: "Paid Host", balance_cents: 1000 },
      context: { paid_entry: true, wager_cents: 100 }
    });
    const preexistingFriendInvite = await post(base, "create_friend_invite", {
      profile: { uid: "preexisting_friend_host", display_name: "Friend Host", balance_cents: 1000 },
      target_uid: "preexisting_friend_guest",
      context: { paid_entry: true, wager_cents: 100 }
    });
    process.env.VS_ECONOMY_MUTATIONS_ENABLED = "false";
    const paidJoinBlocked = await post(base, "join_invite", {
      invite_code: preexistingPaidInvite.invite_code,
      profile: { uid: "preexisting_paid_guest", display_name: "Paid Guest", balance_cents: 1000 }
    });
    expect(paidJoinBlocked.http_status === 503 && paidJoinBlocked.err === "economy_disabled", "paid join did not return stable quarantine response", paidJoinBlocked);
    const paidFriendResponseBlocked = await post(base, "respond_friend_invite", {
      invite_id: (preexistingFriendInvite.invite as JsonRecord).id,
      accept: true,
      profile: { uid: "preexisting_friend_guest", display_name: "Friend Guest", balance_cents: 1000 }
    });
    expect(paidFriendResponseBlocked.http_status === 503 && paidFriendResponseBlocked.err === "economy_disabled",
      "paid friend accept did not return stable quarantine response", paidFriendResponseBlocked);
    const paidLeaveBlocked = await post(base, "leave_session", {
      session_id: preexistingPaidInvite.session_id, uid: "preexisting_paid_host"
    });
    expect(paidLeaveBlocked.http_status === 503 && paidLeaveBlocked.err === "economy_disabled", "paid leave escaped quarantine", paidLeaveBlocked);

    const money = new MoneyLedger();
    const moneyBefore = money.getSnapshot();
    expect(money.setBalanceCents("direct_player", 1000).err === "economy_disabled", "direct money mutation bypassed guard");
    expect(money.openMoneyEscrow("direct_match", [{ player_id: "a", balance_cents: 1000 }, { player_id: "b", balance_cents: 1000 }], 100, "open:direct").err === "economy_disabled", "direct escrow bypassed guard");
    expect(JSON.stringify(moneyBefore) === JSON.stringify(money.getSnapshot()), "direct money guard changed state");

    const honey = new HoneyLedger(join(tempDir, "direct-honey.json"), "beta_2026071301");
    const honeyBefore = honey.getSnapshot();
    expect(honey.grant("direct_player", 100, "test", {}, "direct:honey").err === "economy_disabled", "direct Honey mutation bypassed guard");
    expect(JSON.stringify(honeyBefore) === JSON.stringify(honey.getSnapshot()), "direct Honey guard changed state");

    const crucible = new CrucibleLedger(join(tempDir, "direct-crucible.json"), "beta_2026071301");
    const crucibleBefore = crucible.getSnapshot();
    expect(crucible.setBalanceMillis("direct_player", 1000).err === "economy_disabled", "direct Crucible mutation bypassed guard");
    expect(crucible.openEscrow("direct_match", "a", "b", {}, "open:direct").err === "economy_disabled", "direct Crucible escrow bypassed guard");
    expect(JSON.stringify(crucibleBefore) === JSON.stringify(crucible.getSnapshot()), "direct Crucible guard changed state");

    process.env.VS_ECONOMY_MUTATIONS_ENABLED = "true";
    const legacyHoneyPath = join(tempDir, "legacy-honey.json");
    process.env.VS_ECONOMY_RESET_ENABLED = "true";
    const legacyHoney = new HoneyLedger(legacyHoneyPath, "legacy_epoch");
    legacyHoney.grant("preserved_player", 500, "fixture", {}, "fixture:grant");
    process.env.VS_ECONOMY_MUTATIONS_ENABLED = "false";
    const mutationGatePreservedHoney = new HoneyLedger(legacyHoneyPath, "beta_2026071301").getSnapshot();
    expect(Number((mutationGatePreservedHoney.balances_by_player as JsonRecord).preserved_player) === 500,
      "reset ran while the mutation gate was disabled", mutationGatePreservedHoney);
    expect(mutationGatePreservedHoney.economy_epoch === "legacy_epoch", "mutation gate allowed epoch advancement", mutationGatePreservedHoney);
    process.env.VS_ECONOMY_MUTATIONS_ENABLED = "true";
    process.env.VS_ECONOMY_RESET_ENABLED = "false";
    const preservedHoney = new HoneyLedger(legacyHoneyPath, "beta_2026071301").getSnapshot();
    expect(Number((preservedHoney.balances_by_player as JsonRecord).preserved_player) === 500,
      "disabled reset gate cleared Honey", preservedHoney);
    expect(preservedHoney.economy_epoch === "legacy_epoch", "disabled reset gate advanced epoch", preservedHoney);
  } finally {
    process.env.VS_ECONOMY_MUTATIONS_ENABLED = "false";
    process.env.VS_ECONOMY_RESET_ENABLED = "false";
    await close(server);
    rmSync(tempDir, { recursive: true, force: true });
  }

  console.log(JSON.stringify({ ok: true, smoke: "economy_quarantine" }));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
