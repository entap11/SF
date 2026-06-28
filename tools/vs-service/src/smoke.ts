import http from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

type JsonRecord = Record<string, unknown>;

type ListenableApp = {
  listen: (port: number, hostname: string, callback: () => void) => http.Server;
};

function listen(app: ListenableApp): Promise<http.Server> {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function close(server: http.Server): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((err) => (err ? reject(err) : resolve()));
  });
}

async function post(baseUrl: string, action: string, body: JsonRecord, headers: JsonRecord = {}): Promise<JsonRecord> {
  const data = await postRaw(baseUrl, action, body, headers);
  if (data.http_status !== 200 || data.ok !== true) {
    throw new Error(`${action} failed: ${JSON.stringify(data)}`);
  }
  return data;
}

async function postRaw(baseUrl: string, action: string, body: JsonRecord, headers: JsonRecord = {}): Promise<JsonRecord> {
  const response = await fetch(`${baseUrl}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json", ...headers as Record<string, string> },
    body: JSON.stringify(body)
  });
  const data = await response.json() as JsonRecord;
  return { ...data, http_status: response.status };
}

function expect(condition: unknown, message: string, details?: unknown): void {
  if (condition) {
    return;
  }
  throw new Error(`${message}${details == null ? "" : ` :: ${JSON.stringify(details)}`}`);
}

async function main(): Promise<void> {
  const tempDir = mkdtempSync(join(tmpdir(), "sf-vs-crucible-"));
  process.env.CRUCIBLE_LEDGER_PATH = join(tempDir, "crucible-ledger.json");
  process.env.HONEY_LEDGER_PATH = join(tempDir, "honey-ledger.json");
  process.env.VS_ADMIN_TOKEN = "smoke_admin_token";
  process.env.VS_ADMIN_ROLE = "ops_admin";
  process.env.VS_MATCH_AUTHORITY_TOKEN = "smoke_match_token";
  const adminHeaders = { "x-admin-token": "smoke_admin_token", "x-admin-role": "ops_admin" };
  const matchHeaders = { "x-match-authority-token": "smoke_match_token" };
  const { bestQuickMatchCandidateForTest, createApp } = await import("./server.js");
  const { CrucibleLedger } = await import("./crucibleLedger.js");
  const server = await listen(createApp());
  const address = server.address();
  if (address == null || typeof address === "string") {
    throw new Error("server did not expose a TCP address");
  }
  const baseUrl = `http://127.0.0.1:${address.port}/v1`;
  try {
    const health = await fetch(`http://127.0.0.1:${address.port}/health`).then((res) => res.json() as Promise<JsonRecord>);
    expect(health.ok === true, "health failed", health);
    expect(String(((health.honey as JsonRecord).storage as JsonRecord)?.kind ?? "") === "file", "health missing Honey storage", health);
    const serviceIndex = await fetch(`http://127.0.0.1:${address.port}/v1`).then((res) => res.json() as Promise<JsonRecord>);
    expect(serviceIndex.ok === true && String((serviceIndex.dashboard as JsonRecord)?.path ?? "") === "/dash", "service index missing dashboard link", serviceIndex);
    expect(String(((serviceIndex.honey as JsonRecord).storage as JsonRecord)?.kind ?? "") === "file", "service index missing Honey readiness", serviceIndex);
    const dashHtml = await fetch(`http://127.0.0.1:${address.port}/dash`).then((res) => res.text());
    expect(dashHtml.includes("Swarmfront Contest Dash"), "contest dash html missing title");
    const dashState = await fetch(`${baseUrl}/contest_dash/config`).then((res) => res.json() as Promise<JsonRecord>);
    const dashMaps = dashState.maps as JsonRecord[];
    expect(dashState.ok === true && Array.isArray(dashMaps) && dashMaps.length >= 5, "contest dash state missing maps", dashState);
    const dashSave = await fetch(`${baseUrl}/contest_dash/config`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({
        contest: {
          id: "WEEKLY_USD_5_SMOKE_RACE",
          name: "Smoke Weekly Race",
          scope: "WEEKLY",
          family: "RACE",
          schedule_kind: "SCHEDULED",
          status: "OPEN",
          published: false,
          price_usd: 5,
          map_count: 5,
          map_paths: dashMaps.slice(0, 5).map((entry) => String(entry.path ?? "")),
          payout_schedule: [
            { placement: 1, payout_bps: 5000 },
            { placement: 2, payout_bps: 3000 },
            { placement: 3, payout_bps: 2000 }
          ]
        }
      })
    }).then((res) => res.json() as Promise<JsonRecord>);
    expect(dashSave.ok === true && String((dashSave.contest as JsonRecord)?.id ?? "") === "WEEKLY_USD_5_SMOKE_RACE", "contest dash save failed", dashSave);
    expect(((health.crucible as JsonRecord).match_authority_required) === true, "health missing match authority readiness", health);

    const context = {
      mode: "PVP",
      map_count: 1,
      price_usd: 0,
      free_roll: true,
      stage_map_paths: ["res://maps/json/MAP_TEST_8x12.json"]
    };
    const host = { uid: "u_host", display_name: "Host" };
    const guest = { uid: "u_guest", display_name: "Guest" };

    const invite = await post(baseUrl, "create_invite", { profile: host, context });
    const sessionId = String(invite.session_id ?? "");
    const inviteCode = String(invite.invite_code ?? "");
    expect(sessionId.length > 0, "session_id missing", invite);
    expect(inviteCode.length > 0, "invite_code missing", invite);

    const joined = await post(baseUrl, "join_invite", { invite_code: inviteCode, profile: guest });
    expect(String(joined.session_id) === sessionId, "joined wrong session", joined);
    const joinedSession = joined.session as JsonRecord;
    expect(joinedSession.status === "started", "joined session did not auto-start", joined);

    const hostPublish = await post(baseUrl, "publish_intent", {
      session_id: sessionId,
      uid: host.uid,
      command: { kind: "lane_intent", src: 1, dst: 2, intent: "attack", src_owner: 1, dst_owner: 2, issued_ms: 1 }
    });
    expect(Number(hostPublish.seq) === 1, "host seq mismatch", hostPublish);
    expect(Number(hostPublish.command_seq) === 1, "host command_seq mismatch", hostPublish);
    expect(String(hostPublish.command_id ?? "").length > 0, "host command_id missing", hostPublish);
    const hostCanonical = hostPublish.canonical_command as JsonRecord;
    expect(Number(hostCanonical.command_seq) === 1, "host canonical command_seq missing", hostPublish);
    expect(Number(hostCanonical.execute_tick) >= 0, "host canonical execute_tick missing", hostPublish);

    const guestPoll = await post(baseUrl, "poll_intents", { session_id: sessionId, uid: guest.uid, after_seq: 0 });
    const guestEvents = guestPoll.events as JsonRecord[];
    expect(Array.isArray(guestEvents) && guestEvents.length === 1, "guest did not receive host event", guestPoll);
    expect(guestEvents[0].uid === host.uid, "guest received wrong sender", guestPoll);
    const guestCommand = guestEvents[0].command as JsonRecord;
    expect(Number(guestCommand.command_seq) === 1, "guest received non-canonical host command", guestPoll);
    expect(Number(guestCommand.execute_tick) >= 0, "guest received command without execute_tick", guestPoll);

    await post(baseUrl, "publish_intent", {
      session_id: sessionId,
      uid: guest.uid,
      command: { kind: "lane_retract", from_id: 2, to_id: 1, owner_id: 2, issued_ms: 2 }
    });
    const hostPoll = await post(baseUrl, "poll_intents", { session_id: sessionId, uid: host.uid, after_seq: 0 });
    const hostEvents = hostPoll.events as JsonRecord[];
    expect(Array.isArray(hostEvents) && hostEvents.some((event) => event.uid === guest.uid), "host did not receive guest event", hostPoll);

    const q1 = await post(baseUrl, "enqueue_quick_match", { profile: { uid: "q1", display_name: "Q1" }, context });
    expect(q1.matched === false && String(q1.ticket_id ?? "").length > 0, "first quick ticket failed", q1);
    const q2 = await post(baseUrl, "enqueue_quick_match", { profile: { uid: "q2", display_name: "Q2" }, context });
    expect(q2.matched === true && String(q2.session_id ?? "").length > 0, "second quick match failed", q2);
    expect((q2.session as JsonRecord).status === "started", "quick match did not auto-start", q2);
    const qPoll = await post(baseUrl, "poll_quick_match", { ticket_id: String(q1.ticket_id) });
    expect(qPoll.matched === true && qPoll.session_id === q2.session_id, "quick poll did not find match", qPoll);

    const paidContext = {
      mode: "PVP_PAID_SMOKE",
      map_count: 1,
      price_usd: 1,
      wager_cents: 100,
      free_roll: false,
      paid_entry: true,
      stage_map_paths: ["res://maps/json/MAP_TEST_PAID_8x12.json"]
    };
    const paidInvite = await post(baseUrl, "create_invite", {
      profile: { uid: "paid_host", display_name: "Paid Host", balance_cents: 1000 },
      context: paidContext
    });
    const paidJoin = await post(baseUrl, "join_invite", {
      invite_code: String(paidInvite.invite_code),
      profile: { uid: "paid_guest", display_name: "Paid Guest", balance_cents: 1000 }
    });
    const paidSession = paidJoin.session as JsonRecord;
    const paidSessionContext = paidSession.context as JsonRecord;
    expect(paidSession.status === "started", "paid invite did not start after escrow", paidJoin);
    expect(paidSessionContext.ledger_status === "escrowed", "paid invite missing escrow status", paidSessionContext);
    expect(Number(paidSessionContext.pot_cents) === 200, "paid invite pot mismatch", paidSessionContext);
    const paidSessionId = String(paidJoin.session_id);
    const paidOpenTransactions = await post(baseUrl, "get_money_transactions", { session_id: paidSessionId });
    expect((paidOpenTransactions.transactions as JsonRecord[]).length === 2, "paid invite should debit both players", paidOpenTransactions);
    const paidSettle = await post(baseUrl, "settle_money_match", {
      session_id: paidSessionId,
      winner_id: "paid_host",
      idempotency_key: `settle:${paidSessionId}:paid_host`
    });
    expect(Number(paidSettle.winner_payout_cents) === 180, "paid winner payout mismatch", paidSettle);
    expect(Number(paidSettle.house_rake_cents) === 20, "paid house rake mismatch", paidSettle);
    const paidTransactionsAfterSettle = await post(baseUrl, "get_money_transactions", { session_id: paidSessionId });
    const paidTransactionCount = (paidTransactionsAfterSettle.transactions as JsonRecord[]).length;
    await post(baseUrl, "settle_money_match", {
      session_id: paidSessionId,
      winner_id: "paid_host",
      idempotency_key: `settle:${paidSessionId}:paid_host`
    });
    const paidTransactionsAfterDuplicate = await post(baseUrl, "get_money_transactions", { session_id: paidSessionId });
    expect((paidTransactionsAfterDuplicate.transactions as JsonRecord[]).length === paidTransactionCount, "duplicate paid settle added transactions", paidTransactionsAfterDuplicate);
    const paidSecondSettle = await postRaw(baseUrl, "settle_money_match", {
      session_id: paidSessionId,
      winner_id: "paid_guest",
      idempotency_key: `settle:${paidSessionId}:paid_guest`
    });
    expect(paidSecondSettle.ok === false && paidSecondSettle.err === "match_already_closed", "second paid settle should fail", paidSecondSettle);

    const directOpen = await post(baseUrl, "open_money_escrow", {
      session_id: "direct_refund_session",
      player_ids: ["refund_a", "refund_b"],
      player_balances_cents: { refund_a: 500, refund_b: 500 },
      wager_cents: 250,
      idempotency_key: "open:direct_refund_session"
    });
    expect(Number(directOpen.pot_cents) === 500, "direct open pot mismatch", directOpen);
    const directRefund = await post(baseUrl, "refund_money_match", {
      session_id: "direct_refund_session",
      reason: "failed_start",
      idempotency_key: "refund:direct_refund_session"
    });
    expect(Number(directRefund.refunded_cents_per_player) === 250, "direct refund amount mismatch", directRefund);
    const directRefundTransactions = await post(baseUrl, "get_money_transactions", { session_id: "direct_refund_session" });
    const directRefundTransactionCount = (directRefundTransactions.transactions as JsonRecord[]).length;
    await post(baseUrl, "refund_money_match", {
      session_id: "direct_refund_session",
      reason: "failed_start",
      idempotency_key: "refund:direct_refund_session"
    });
    const duplicateRefundTransactions = await post(baseUrl, "get_money_transactions", { session_id: "direct_refund_session" });
    expect((duplicateRefundTransactions.transactions as JsonRecord[]).length === directRefundTransactionCount, "duplicate refund added transactions", duplicateRefundTransactions);

    const paidShortFirst = await post(baseUrl, "enqueue_quick_match", {
      profile: { uid: "paid_short_a", display_name: "Short A", balance_cents: 50 },
      context: paidContext
    });
    expect(paidShortFirst.matched === false, "first underfunded paid quick should queue", paidShortFirst);
    const paidShortSecond = await postRaw(baseUrl, "enqueue_quick_match", {
      profile: { uid: "paid_short_b", display_name: "Short B", balance_cents: 1000 },
      context: paidContext
    });
    expect(paidShortSecond.ok === false && paidShortSecond.err === "insufficient_funds", "underfunded paid quick should not start", paidShortSecond);
    const stillQueued = await post(baseUrl, "poll_quick_match", { ticket_id: String(paidShortFirst.ticket_id) });
    expect(stillQueued.matched === false, "failed paid quick should keep original player queued", stillQueued);
    await post(baseUrl, "cancel_quick_match", { ticket_id: String(paidShortFirst.ticket_id), uid: "paid_short_a" });

    const asyncOpenA = await post(baseUrl, "open_async_entry_escrow", {
      entry_id: "async_entry_a",
      contest_id: "async_contest_paid",
      player_id: "async_a",
      balance_cents: 1000,
      wager_cents: 500,
      idempotency_key: "open:async_entry_a"
    });
    expect(Number(asyncOpenA.pot_cents) === 500, "first async pot mismatch", asyncOpenA);
    await post(baseUrl, "open_async_entry_escrow", {
      entry_id: "async_entry_a",
      contest_id: "async_contest_paid",
      player_id: "async_a",
      balance_cents: 1000,
      wager_cents: 500,
      idempotency_key: "open:async_entry_a"
    });
    const asyncEntryATransactions = await post(baseUrl, "get_money_transactions", { entry_id: "async_entry_a" });
    expect((asyncEntryATransactions.transactions as JsonRecord[]).length === 1, "duplicate async open added transactions", asyncEntryATransactions);
    const asyncOpenB = await post(baseUrl, "open_async_entry_escrow", {
      entry_id: "async_entry_b",
      contest_id: "async_contest_paid",
      player_id: "async_b",
      balance_cents: 1000,
      wager_cents: 500,
      idempotency_key: "open:async_entry_b"
    });
    expect(Number(asyncOpenB.pot_cents) === 1000, "second async pot mismatch", asyncOpenB);
    const asyncSettle = await post(baseUrl, "settle_async_contest", {
      contest_id: "async_contest_paid",
      winner_id: "async_b",
      idempotency_key: "settle:async_contest_paid:async_b"
    });
    expect(Number(asyncSettle.winner_payout_cents) === 900, "async winner payout mismatch", asyncSettle);
    expect(Number(asyncSettle.house_rake_cents) === 100, "async house rake mismatch", asyncSettle);
    const asyncContestTransactions = await post(baseUrl, "get_money_transactions", { contest_id: "async_contest_paid" });
    const asyncContestTransactionCount = (asyncContestTransactions.transactions as JsonRecord[]).length;
    await post(baseUrl, "settle_async_contest", {
      contest_id: "async_contest_paid",
      winner_id: "async_b",
      idempotency_key: "settle:async_contest_paid:async_b"
    });
    const asyncDuplicateSettleTransactions = await post(baseUrl, "get_money_transactions", { contest_id: "async_contest_paid" });
    expect((asyncDuplicateSettleTransactions.transactions as JsonRecord[]).length === asyncContestTransactionCount, "duplicate async settle added transactions", asyncDuplicateSettleTransactions);

    for (let i = 1; i <= 5; i += 1) {
      await post(baseUrl, "open_async_entry_escrow", {
        entry_id: `async_pool_entry_${i}`,
        contest_id: "async_contest_pool",
        player_id: `async_pool_${i}`,
        balance_cents: 1000,
        wager_cents: 500,
        idempotency_key: `open:async_pool_entry_${i}`
      });
    }
    const asyncPayoutReport = await post(baseUrl, "preview_async_contest_payout_report", {
      contest_id: "async_contest_pool",
      house_rake_bps: 1000,
      payouts: [
        { placement: 1, player_id: "async_pool_1", payout_bps: 4000 },
        { placement: 2, player_id: "async_pool_2", payout_bps: 2500 },
        { placement: 3, player_id: "async_pool_3", payout_bps: 1500 },
        { placement: 4, player_id: "async_pool_4", payout_bps: 2000 }
      ]
    });
    expect(String(asyncPayoutReport.approval_status) === "pending_approval", "async payout report should require approval", asyncPayoutReport);
    expect(Number(asyncPayoutReport.players_count) === 5, "async payout report player count mismatch", asyncPayoutReport);
    expect(Number(asyncPayoutReport.entries_count) === 5, "async payout report entry count mismatch", asyncPayoutReport);
    expect(Number(asyncPayoutReport.total_take_cents) === 2500, "async payout report total take mismatch", asyncPayoutReport);
    expect(Number(asyncPayoutReport.house_rake_cents) === 250, "async payout report rake mismatch", asyncPayoutReport);
    expect(Number(asyncPayoutReport.player_pool_cents) === 2250, "async payout report player pool mismatch", asyncPayoutReport);
    const pendingPayoutReports = await post(baseUrl, "list_async_contest_payout_reports", {
      status: "pending_approval",
      contest_id: "async_contest_pool"
    });
    expect(
      ((pendingPayoutReports.reports as JsonRecord[]) ?? []).some((report) => String(report.report_id) === String(asyncPayoutReport.report_id)),
      "async payout report should be listed for ops approval",
      pendingPayoutReports
    );
    const asyncPayoutSettle = await post(baseUrl, "approve_async_contest_payout_report", {
      report: asyncPayoutReport,
      approver_id: "ops_admin",
      idempotency_key: "settle:async_contest_pool:top4"
    });
    expect(String(asyncPayoutSettle.approval_status) === "approved", "async payout approval status mismatch", asyncPayoutSettle);
    expect(Number(asyncPayoutSettle.payout_total_cents) === 2250, "async payout table total mismatch", asyncPayoutSettle);
    expect(Number(asyncPayoutSettle.house_rake_cents) === 250, "async payout table rake mismatch", asyncPayoutSettle);
    expect(!Array.isArray(asyncPayoutSettle.wax_awards), "async payout approval should not emit Crucible ledger Wax awards", asyncPayoutSettle);
    const asyncPayoutTransactions = await post(baseUrl, "get_money_transactions", {
      contest_id: "async_contest_pool",
      transaction_type: "async_winner_payout"
    });
    expect((asyncPayoutTransactions.transactions as JsonRecord[]).length === 4, "async payout table should write one row per winner", asyncPayoutTransactions);
    expect(String((asyncPayoutTransactions.transactions as JsonRecord[])[0]?.approval_id ?? "") === String(asyncPayoutReport.report_id ?? ""), "async payout row approval id mismatch", asyncPayoutTransactions);
    const pendingPayoutReportsAfterApproval = await post(baseUrl, "list_async_contest_payout_reports", {
      status: "pending_approval",
      contest_id: "async_contest_pool"
    });
    expect(
      ((pendingPayoutReportsAfterApproval.reports as JsonRecord[]) ?? []).length === 0,
      "approved async payout report should leave pending queue",
      pendingPayoutReportsAfterApproval
    );

    for (const playerId of ["race_backend_p1", "race_backend_p2", "race_backend_p3"]) {
      await post(baseUrl, "open_async_entry_escrow", {
        entry_id: `entry_${playerId}`,
        contest_id: "async_race_backend",
        player_id: playerId,
        balance_cents: 20_000,
        wager_cents: 5000,
        idempotency_key: `open:entry_${playerId}`
      });
    }
    await post(baseUrl, "submit_async_contest_result", {
      contest_id: "async_race_backend",
      contest_family: "RACE",
      player_id: "race_backend_p1",
      result: { player_id: "race_backend_p1", run_id: "race_p1", map_count: 3, completed_maps: 3, map_times_ms: [60000, 61000, 62000] },
      idempotency_key: "submit:async_race_backend:p1"
    });
    await post(baseUrl, "submit_async_contest_result", {
      contest_id: "async_race_backend",
      contest_family: "RACE",
      player_id: "race_backend_p2",
      result: { player_id: "race_backend_p2", run_id: "race_p2", map_count: 3, completed_maps: 3, map_times_ms: [59000, 60000, 61000] },
      idempotency_key: "submit:async_race_backend:p2"
    });
    await post(baseUrl, "submit_async_contest_result", {
      contest_id: "async_race_backend",
      contest_family: "RACE",
      player_id: "race_backend_p3",
      result: { player_id: "race_backend_p3", run_id: "race_p3", map_count: 3, completed_maps: 2, map_times_ms: [58000, 59000], failed_map_elapsed_ms: 30000 },
      idempotency_key: "submit:async_race_backend:p3"
    });
    const raceResults = await post(baseUrl, "list_async_contest_results", {
      contest_id: "async_race_backend",
      contest_family: "RACE"
    });
    expect(String(((raceResults.results as JsonRecord[])[0]?.player_id ?? "")) === "race_backend_p2", "backend race result ranking mismatch", raceResults);
    const raceBackendReport = await post(baseUrl, "preview_async_contest_result_payout_report", {
      contest_id: "async_race_backend",
      contest_family: "RACE",
      map_count: 3,
      payout_schedule: [
        { placement: 1, payout_bps: 7000 },
        { placement: 2, payout_bps: 3000 }
      ],
      house_rake_bps: 1000
    });
    expect(String(raceBackendReport.result_source) === "backend_result_ledger", "race report should come from backend result ledger", raceBackendReport);
    expect(String(((raceBackendReport.planned_payouts as JsonRecord[])[0]?.player_id ?? "")) === "race_backend_p2", "race backend report first payout mismatch", raceBackendReport);
    const raceBackendSettle = await post(baseUrl, "approve_async_contest_payout_report", {
      report: raceBackendReport,
      approver_id: "ops_admin",
      idempotency_key: "settle:async_race_backend:backend_results"
    });
    expect(Number(raceBackendSettle.payout_count) === 2, "race backend result settlement payout count mismatch", raceBackendSettle);
    expect(!Array.isArray(raceBackendSettle.wax_awards), "race backend settlement should not award Crucible ledger Wax", raceBackendSettle);

    for (const playerId of ["miss_backend_p1", "miss_backend_p2", "miss_backend_p3"]) {
      await post(baseUrl, "open_async_entry_escrow", {
        entry_id: `entry_${playerId}`,
        contest_id: "async_miss_backend",
        player_id: playerId,
        balance_cents: 10_000,
        wager_cents: 1500,
        idempotency_key: `open:entry_${playerId}`
      });
    }
    await post(baseUrl, "submit_async_contest_result", {
      contest_id: "async_miss_backend",
      contest_family: "MISS_N_OUT",
      player_id: "miss_backend_p1",
      result: { player_id: "miss_backend_p1", placement: 2, eliminated_round: 2, time_ms: 64000 },
      idempotency_key: "submit:async_miss_backend:p1"
    });
    await post(baseUrl, "submit_async_contest_result", {
      contest_id: "async_miss_backend",
      contest_family: "MISS_N_OUT",
      player_id: "miss_backend_p2",
      result: { player_id: "miss_backend_p2", placement: 1, is_winner: true, time_ms: 60000 },
      idempotency_key: "submit:async_miss_backend:p2"
    });
    await post(baseUrl, "submit_async_contest_result", {
      contest_id: "async_miss_backend",
      contest_family: "MISS_N_OUT",
      player_id: "miss_backend_p3",
      result: { player_id: "miss_backend_p3", placement: 3, eliminated_round: 1, time_ms: 70000 },
      idempotency_key: "submit:async_miss_backend:p3"
    });
    const missBackendReport = await post(baseUrl, "preview_async_contest_result_payout_report", {
      contest_id: "async_miss_backend",
      contest_family: "MISS_N_OUT",
      payout_schedule: [{ placement: 1, payout_bps: 10000 }],
      house_rake_bps: 1000
    });
    expect(String(((missBackendReport.planned_payouts as JsonRecord[])[0]?.player_id ?? "")) === "miss_backend_p2", "miss backend report winner mismatch", missBackendReport);

    const payoutSummary = await post(baseUrl, "get_money_payout_summary", { limit: 10 });
    expect(Number(payoutSummary.paid_out_cents) >= 3330, "payout summary paid total mismatch", payoutSummary);
    expect(Number(payoutSummary.house_rake_cents) >= 370, "payout summary rake total mismatch", payoutSummary);
    const contestSummaries = (payoutSummary.contests as JsonRecord[]) ?? [];
    const poolSummary = contestSummaries.find((summary) => String(summary.contest_id) === "async_contest_pool");
    expect(poolSummary != null, "payout summary missing async contest pool", payoutSummary);
    expect(Number(poolSummary?.paid_out_cents) === 2250, "payout summary contest paid amount mismatch", poolSummary);
    expect(Number(poolSummary?.house_rake_cents) === 250, "payout summary contest rake mismatch", poolSummary);

    const asyncLateRefund = await postRaw(baseUrl, "refund_async_entry", {
      entry_id: "async_entry_a",
      reason: "late_refund",
      idempotency_key: "refund:async_entry_a"
    });
    expect(asyncLateRefund.ok === false && asyncLateRefund.err === "entry_already_closed", "settled async entry refund should fail", asyncLateRefund);
    await post(baseUrl, "open_async_entry_escrow", {
      entry_id: "async_entry_refund",
      contest_id: "async_contest_refund",
      player_id: "async_refund_player",
      balance_cents: 1000,
      wager_cents: 250,
      idempotency_key: "open:async_entry_refund"
    });
    const asyncRefund = await post(baseUrl, "refund_async_entry", {
      entry_id: "async_entry_refund",
      reason: "failed_start",
      idempotency_key: "refund:async_entry_refund"
    });
    expect(Number(asyncRefund.refunded_cents) === 250, "async refund amount mismatch", asyncRefund);
    const latestAsync = await post(baseUrl, "get_money_transactions", {
      contest_id: "async_contest_paid",
      sort_desc: true,
      limit: 1
    });
    expect((latestAsync.transactions as JsonRecord[]).length === 1, "transaction limit filter failed", latestAsync);

    const rankedContext = {
      ...context,
      mode: "PVP_RANKED_SMOKE",
      stage_map_paths: ["res://maps/json/MAP_TEST_RANKED_8x12.json"]
    };
    const rankedCandidate = bestQuickMatchCandidateForTest(
      { uid: "rank_requester", display_name: "Requester", tier_id: "WORKER", rank_position: 100, wax_score: 1000 },
      rankedContext,
      [
        { uid: "rank_far_tier", display_name: "Far Tier", context: rankedContext, tier_id: "QUEEN", rank_position: 10, wax_score: 1000, created_unix: 1 },
        { uid: "rank_same_far", display_name: "Same Far", context: rankedContext, tier_id: "WORKER", rank_position: 900, wax_score: 1000, created_unix: 2 },
        { uid: "rank_same_close", display_name: "Same Close", context: rankedContext, tier_id: "WORKER", rank_position: 110, wax_score: 1000, created_unix: 3 }
      ]
    );
    expect(rankedCandidate?.uid === "rank_same_close", "ranked quick chose wrong candidate", rankedCandidate);

    const humanPvpContextA = {
      ...context,
      mode: "PVP_HUMAN_CONTEXT_SMOKE",
      human_pvp: true,
      map_ids: ["MAP_A"]
    };
    const humanPvpContextB = {
      ...context,
      mode: "PVP_HUMAN_CONTEXT_SMOKE",
      human_pvp: true,
      map_ids: ["MAP_B"]
    };
    const humanPvpFirst = await post(baseUrl, "enqueue_quick_match", {
      profile: { uid: "human_pvp_a", display_name: "Human A", tier_id: "WORKER", rank_position: 100 },
      context: humanPvpContextA
    });
    const humanPvpSecond = await post(baseUrl, "enqueue_quick_match", {
      profile: { uid: "human_pvp_b", display_name: "Human B", tier_id: "WORKER", rank_position: 101 },
      context: humanPvpContextB
    });
    expect(humanPvpFirst.matched === false && humanPvpSecond.matched === true, "human PvP pregame context blocked match", humanPvpSecond);
    await post(baseUrl, "leave_session", { session_id: String(humanPvpSecond.session_id), uid: "human_pvp_b" });
    await post(baseUrl, "leave_session", { session_id: String(humanPvpSecond.session_id), uid: "human_pvp_a" });

    const honeyPolicy = await post(baseUrl, "get_honey_policy", {});
    const honeyPolicyPayload = honeyPolicy.policy as JsonRecord;
    expect(String(honeyPolicyPayload.precision) === "centi_honey", "Honey policy precision mismatch", honeyPolicy);
    const honeyActivity = await post(baseUrl, "record_honey_activity", {
      player_id: "activity_player",
      activity_key: "competitive.live_free",
      entap_title: "Swarmfront",
      completed: true,
      duration_sec: 600,
      opponent_ids: ["activity_opp"],
      metadata: { match_id: "activity_match_1" },
      idempotency_key: "honey:activity:activity_player:match_1"
    }, matchHeaders);
    expect(Number(honeyActivity.amount_centi) === 400 && Number(honeyActivity.balance_centi) === 400, "Honey activity award mismatch", honeyActivity);
    await post(baseUrl, "record_honey_activity", {
      player_id: "activity_player",
      activity_key: "competitive.live_free",
      entap_title: "Swarmfront",
      completed: true,
      duration_sec: 600,
      opponent_ids: ["activity_opp"],
      metadata: { match_id: "activity_match_1" },
      idempotency_key: "honey:activity:activity_player:match_1"
    }, matchHeaders);
    const activityBalance = await post(baseUrl, "get_honey_balance", { player_id: "activity_player" });
    expect(Number(activityBalance.balance_centi) === 400, "duplicate Honey activity should be idempotent", activityBalance);
    const lowEffort = await post(baseUrl, "record_honey_activity", {
      player_id: "activity_player",
      activity_key: "competitive.live_free",
      entap_title: "Swarmfront",
      completed: true,
      duration_sec: 60,
      opponent_ids: ["activity_opp_low"],
      metadata: { match_id: "activity_match_low" },
      idempotency_key: "honey:activity:activity_player:low"
    }, matchHeaders);
    expect(lowEffort.awarded === false && Number(lowEffort.amount_centi) === 0, "low-effort Honey activity should not award", lowEffort);
    for (let i = 0; i < 4; i += 1) {
      await post(baseUrl, "record_honey_activity", {
        player_id: "farm_player",
        activity_key: "competitive.live_free",
        entap_title: "Swarmfront",
        completed: true,
        duration_sec: 600,
        opponent_ids: ["same_opp"],
        metadata: { match_id: `farm_match_${i}` },
        idempotency_key: `honey:activity:farm_player:${i}`
      }, matchHeaders);
    }
    const farmBalance = await post(baseUrl, "get_honey_balance", { player_id: "farm_player" });
    expect(Number(farmBalance.balance_centi) === 1400, "same-opponent Honey diminishing return mismatch", farmBalance);

    const honeyGrant = await post(baseUrl, "grant_honey", {
      player_id: "honey_player",
      amount_centi: 1600,
      source: "platform_growth.purchase_bundle",
      metadata: { entap_title: "Swarmfront", activity_id: "bundle_25" },
      idempotency_key: "honey:grant:honey_player:bundle_25"
    }, matchHeaders);
    expect(Number(honeyGrant.balance_centi) === 1600, "Honey grant balance mismatch", honeyGrant);
    await post(baseUrl, "grant_honey", {
      player_id: "honey_player",
      amount_centi: 1600,
      source: "platform_growth.purchase_bundle",
      metadata: { entap_title: "Swarmfront", activity_id: "bundle_25" },
      idempotency_key: "honey:grant:honey_player:bundle_25"
    }, matchHeaders);
    const honeyBalance = await post(baseUrl, "get_honey_balance", { player_id: "honey_player" });
    expect(Number(honeyBalance.balance_centi) === 1600 && Number(honeyBalance.balance_honey_whole) === 16, "Honey duplicate grant should be idempotent", honeyBalance);
    const honeyDebit = await post(baseUrl, "debit_honey", {
      player_id: "honey_player",
      amount_centi: 400,
      source: "hive_cosmetic.test",
      idempotency_key: "honey:debit:honey_player:test"
    }, matchHeaders);
    expect(Number(honeyDebit.balance_centi) === 1200, "Honey debit balance mismatch", honeyDebit);
    const honeyOverDebit = await postRaw(baseUrl, "debit_honey", {
      player_id: "honey_player",
      amount_centi: 5000,
      source: "hive_cosmetic.test",
      idempotency_key: "honey:debit:honey_player:too_much"
    }, matchHeaders);
    expect(honeyOverDebit.ok === false && honeyOverDebit.err === "insufficient_honey", "Honey over-debit should fail", honeyOverDebit);
    await post(baseUrl, "debug_set_honey_balance", {
      player_id: "hive_a",
      balance_centi: 1000,
      idempotency_key: "honey:set:hive_a"
    }, adminHeaders);
    await post(baseUrl, "debug_set_honey_balance", {
      player_id: "hive_b",
      balance_centi: 3000,
      idempotency_key: "honey:set:hive_b"
    }, adminHeaders);
    await post(baseUrl, "debug_set_honey_balance", {
      player_id: "hive_c",
      balance_centi: 6000,
      idempotency_key: "honey:set:hive_c"
    }, adminHeaders);
    const hiveHoneyPreview = await post(baseUrl, "preview_hive_honey_purchase", {
      hive_id: "hive_smoke",
      member_ids: ["hive_a", "hive_b", "hive_c"],
      cost_centi: 2500
    });
    expect(Number(hiveHoneyPreview.available_centi) === 10000, "Hive Honey preview total mismatch", hiveHoneyPreview);
    const hivePreviewDeductions = hiveHoneyPreview.deductions as JsonRecord[];
    expect(Number(hivePreviewDeductions.find((row) => row.player_id === "hive_a")?.deduction_centi ?? 0) === 250, "Hive Honey p1 deduction mismatch", hiveHoneyPreview);
    expect(Number(hivePreviewDeductions.find((row) => row.player_id === "hive_b")?.deduction_centi ?? 0) === 750, "Hive Honey p2 deduction mismatch", hiveHoneyPreview);
    expect(Number(hivePreviewDeductions.find((row) => row.player_id === "hive_c")?.deduction_centi ?? 0) === 1500, "Hive Honey p3 deduction mismatch", hiveHoneyPreview);
    const hiveHoneyDebit = await post(baseUrl, "debit_hive_honey_purchase", {
      hive_id: "hive_smoke",
      member_ids: ["hive_a", "hive_b", "hive_c"],
      cost_centi: 2500,
      source: "hive_tournament.weekly",
      metadata: { entap_title: "Swarmfront" },
      idempotency_key: "honey:hive_debit:hive_smoke:weekly"
    }, matchHeaders);
    expect((hiveHoneyDebit.transactions as JsonRecord[]).length === 3, "Hive Honey debit should write one transaction per payer", hiveHoneyDebit);
    await post(baseUrl, "debit_hive_honey_purchase", {
      hive_id: "hive_smoke",
      member_ids: ["hive_a", "hive_b", "hive_c"],
      cost_centi: 2500,
      source: "hive_tournament.weekly",
      idempotency_key: "honey:hive_debit:hive_smoke:weekly"
    }, matchHeaders);
    const hiveABalance = await post(baseUrl, "get_honey_balance", { player_id: "hive_a" });
    const hiveCBalance = await post(baseUrl, "get_honey_balance", { player_id: "hive_c" });
    expect(Number(hiveABalance.balance_centi) === 750 && Number(hiveCBalance.balance_centi) === 4500, "Hive Honey duplicate debit should be idempotent", { hiveABalance, hiveCBalance });
    const honeyTransactions = await post(baseUrl, "get_honey_transactions", { player_id: "hive_c", type: "hive_debit" });
    expect((honeyTransactions.transactions as JsonRecord[]).length === 1, "Honey transaction filter mismatch", honeyTransactions);
    const honeySnapshot = await post(baseUrl, "debug_get_honey_ledger_snapshot", {}, adminHeaders);
    expect(String((honeySnapshot.ledger as JsonRecord).precision ?? "") === "centi_honey", "Honey snapshot precision mismatch", honeySnapshot);

    const crucibleConfig = await post(baseUrl, "get_crucible_config", {});
    const crucibleConfigPayload = crucibleConfig.config as JsonRecord;
    expect(Number(crucibleConfigPayload.config_version) > 0, "crucible config missing version", crucibleConfig);
    const waxPolicy = await post(baseUrl, "get_wax_policy", {});
    expect(String((waxPolicy.policy as JsonRecord).precision) === "wax_millis", "Wax policy precision mismatch", waxPolicy);
    const waxWin = await post(baseUrl, "record_competitive_wax_result", {
      match_id: "wax_win_smoke",
      player_id: "wax_winner",
      opponent_id: "wax_even",
      mode_name: "1V1",
      did_win: true,
      player_rating: 1000,
      opponent_rating: 1000,
      idempotency_key: "wax:win"
    }, matchHeaders);
    expect(waxWin.suppressed === true && waxWin.awarded === false, "deprecated competitive Wax endpoint should be suppressed", waxWin);
    const waxWinDuplicate = await post(baseUrl, "record_competitive_wax_result", {
      match_id: "wax_win_smoke",
      player_id: "wax_winner",
      opponent_id: "wax_even",
      mode_name: "1V1",
      did_win: true,
      player_rating: 1000,
      opponent_rating: 1000,
      idempotency_key: "wax:win"
    }, matchHeaders);
    expect(waxWinDuplicate.suppressed === true && waxWinDuplicate.awarded === false, "deprecated competitive Wax duplicate should be suppressed", waxWinDuplicate);
    await post(baseUrl, "debug_set_crucible_balance", {
      player_id: "wax_loss",
      balance_millis: 10000
    }, adminHeaders);
    const waxLoss = await post(baseUrl, "record_competitive_wax_result", {
      match_id: "wax_loss_smoke",
      player_id: "wax_loss",
      opponent_id: "wax_weaker",
      mode_name: "PVP",
      did_win: false,
      player_rating: 2000,
      opponent_rating: 1000,
      idempotency_key: "wax:loss"
    }, matchHeaders);
    expect(waxLoss.suppressed === true && Number(waxLoss.balance_millis) === 10000, "deprecated competitive Wax loss should be suppressed", waxLoss);
    for (let i = 1; i <= 4; i += 1) {
      await post(baseUrl, "record_competitive_wax_result", {
        match_id: `wax_repeat_${i}`,
        player_id: "wax_repeat",
        opponent_id: "wax_repeat_opp",
        mode_name: "1V1",
        did_win: true,
        player_rating: 1000,
        opponent_rating: 1000,
        idempotency_key: `wax:repeat:${i}`
      }, matchHeaders);
    }
    const waxRepeatSnapshot = await post(baseUrl, "debug_get_crucible_snapshot", {}, adminHeaders);
    const waxRepeatBalances = ((waxRepeatSnapshot.ledger as JsonRecord).balances_by_player as JsonRecord);
    expect(Number(waxRepeatBalances.wax_repeat ?? 0) === 0, "deprecated repeated-opponent competitive Wax should be suppressed", waxRepeatSnapshot);
    const waxCrucibleBlocked = await post(baseUrl, "record_competitive_wax_result", {
      match_id: "wax_crucible_blocked",
      player_id: "wax_crucible",
      opponent_id: "wax_crucible_opp",
      mode_name: "1V1",
      did_win: true,
      vs_crucible: true,
      idempotency_key: "wax:crucible_blocked"
    }, matchHeaders);
    expect(waxCrucibleBlocked.awarded === false && waxCrucibleBlocked.suppressed === true, "Crucible participation should not award competitive Wax", waxCrucibleBlocked);
    const crucibleContext = {
      ...context,
      mode: "1V1",
      human_pvp: true,
      vs_ruleset: "CRUCIBLE",
      vs_crucible: true,
      free_roll: true,
      crucible_config_version: crucibleConfigPayload.config_version,
      crucible_config_hash: crucibleConfigPayload.config_hash
    };
    const regularContext = {
      ...context,
      mode: "1V1",
      human_pvp: true
    };
    const regularFirst = await post(baseUrl, "enqueue_quick_match", {
      profile: { uid: "regular_not_crucible", display_name: "Regular" },
      context: regularContext
    });
    const crucibleFirst = await post(baseUrl, "enqueue_quick_match", {
      profile: { uid: "crucible_a", display_name: "Crucible A", crucible_wax_millis: 50000 },
      context: crucibleContext
    });
    expect(regularFirst.matched === false && crucibleFirst.matched === false, "regular and Crucible tickets must not match", { regularFirst, crucibleFirst });
    const crucibleSecond = await post(baseUrl, "enqueue_quick_match", {
      profile: { uid: "crucible_b", display_name: "Crucible B", crucible_wax_millis: 50000 },
      context: crucibleContext
    });
    expect(crucibleSecond.matched === true, "Crucible second player should match", crucibleSecond);
    const crucibleSession = crucibleSecond.session as JsonRecord;
    const crucibleSessionContext = crucibleSession.context as JsonRecord;
    expect(crucibleSession.status === "started", "Crucible session did not start", crucibleSecond);
    expect(crucibleSessionContext.vs_ruleset === "CRUCIBLE", "Crucible session lost ruleset", crucibleSessionContext);
    expect(crucibleSessionContext.crucible_ledger_status === "escrowed", "Crucible session missing escrow", crucibleSessionContext);
    expect(Number(crucibleSessionContext.crucible_stake_each) === 1000, "Crucible stake mismatch", crucibleSessionContext);
    const crucibleMatchId = String(crucibleSessionContext.crucible_match_id);
    const unauthSettle = await postRaw(baseUrl, "settle_crucible_match", {
      match_id: crucibleMatchId,
      winner_id: "crucible_a",
      result_source: "SERVER_MATCH_RESULT",
      reason: "missing_match_auth"
    });
    expect(unauthSettle.http_status === 401 && unauthSettle.err === "match_authority_required", "Crucible settlement should require match authority", unauthSettle);
    const crucibleSettle = await post(baseUrl, "settle_crucible_match", {
      match_id: crucibleMatchId,
      winner_id: "crucible_a",
      result_source: "SERVER_MATCH_RESULT",
      reason: "smoke_win",
      idempotency_key: `settle:${crucibleMatchId}:crucible_a`
    }, matchHeaders);
    const crucibleSettlement = crucibleSettle.settlement as JsonRecord;
    expect(String(crucibleSettlement.settlement_status) === "SETTLED", "Crucible settlement status mismatch", crucibleSettle);
    expect(Number(crucibleSettlement.winner_payout) === 2000, "Crucible winner payout mismatch", crucibleSettle);

    const noContestOpen = await post(baseUrl, "open_crucible_escrow", {
      match_id: "crucible_no_contest_smoke",
      player_a_id: "crucible_nc_a",
      player_b_id: "crucible_nc_b",
      metadata: {
        player_balance_millis_by_id: { crucible_nc_a: 10000, crucible_nc_b: 10000 },
        expected_config_version: crucibleConfigPayload.config_version,
        expected_config_hash: crucibleConfigPayload.config_hash
      },
      idempotency_key: "open:crucible_no_contest_smoke"
    }, matchHeaders);
    expect((noContestOpen.escrow as JsonRecord).match_id === "crucible_no_contest_smoke", "Crucible direct escrow failed", noContestOpen);
    const noContestSettle = await post(baseUrl, "settle_crucible_match", {
      match_id: "crucible_no_contest_smoke",
      winner_id: "crucible_nc_a",
      result_source: "UI",
      reason: "ui_attempt",
      idempotency_key: "settle:crucible_no_contest_smoke:ui"
    }, matchHeaders);
    expect(String((noContestSettle.settlement as JsonRecord).settlement_status) === "NO_CONTEST", "UI source should no-contest", noContestSettle);

    const lifecycleOpen = await post(baseUrl, "open_crucible_escrow", {
      match_id: "crucible_lifecycle_smoke",
      player_a_id: "crucible_life_a",
      player_b_id: "crucible_life_b",
      metadata: {
        player_balance_millis_by_id: { crucible_life_a: 20000, crucible_life_b: 20000 },
        expected_config_version: crucibleConfigPayload.config_version,
        expected_config_hash: crucibleConfigPayload.config_hash
      },
      idempotency_key: "open:crucible_lifecycle_smoke"
    }, matchHeaders);
    expect(lifecycleOpen.ok === true, "Crucible lifecycle escrow failed", lifecycleOpen);
    const lifecycle = await post(baseUrl, "record_crucible_lifecycle", {
      match_id: "crucible_lifecycle_smoke",
      event_type: "voluntary_quit",
      player_id: "crucible_life_b"
    }, matchHeaders);
    expect(String((lifecycle.settlement as JsonRecord).winner_id) === "crucible_life_a", "voluntary quit should award opponent", lifecycle);

    const heldOpen = await post(baseUrl, "open_crucible_escrow", {
      match_id: "crucible_held_smoke",
      player_a_id: "crucible_hold_a",
      player_b_id: "crucible_hold_b",
      metadata: {
        player_balance_millis_by_id: { crucible_hold_a: 20000, crucible_hold_b: 20000 },
        anti_collusion_signals: { unusual_win_trading: true },
        expected_config_version: crucibleConfigPayload.config_version,
        expected_config_hash: crucibleConfigPayload.config_hash
      },
      idempotency_key: "open:crucible_held_smoke"
    }, matchHeaders);
    expect(heldOpen.ok === true, "Crucible held escrow failed", heldOpen);
    const heldSettle = await post(baseUrl, "settle_crucible_match", {
      match_id: "crucible_held_smoke",
      winner_id: "crucible_hold_a",
      result_source: "SERVER_MATCH_RESULT",
      reason: "risk_smoke",
      idempotency_key: "settle:crucible_held_smoke"
    }, matchHeaders);
    expect(String((heldSettle.settlement as JsonRecord).settlement_status) === "HELD_REVIEW", "risk match should be held", heldSettle);
    const heldReview = await post(baseUrl, "resolve_crucible_review", {
      match_id: "crucible_held_smoke",
      action: "refund",
      actor_id: "ops_smoke",
      idempotency_key: "review:crucible_held_smoke:refund"
    }, adminHeaders);
    expect(String((heldReview.settlement as JsonRecord).settlement_status) === "REFUNDED", "held match review refund failed", heldReview);

    const unauthBalancePreview = await postRaw(baseUrl, "preview_crucible_entry", {
      player_id: "preview_hint_unauth",
      balance_millis: 10000
    });
    expect(unauthBalancePreview.http_status === 401 && unauthBalancePreview.err === "crucible_balance_hint_auth_required", "Crucible balance hints should require authority", unauthBalancePreview);
    const authBalancePreview = await post(baseUrl, "preview_crucible_entry", {
      player_id: "preview_hint_auth",
      balance_millis: 10000
    }, matchHeaders);
    expect(authBalancePreview.ok === true && Number(authBalancePreview.balance_millis) === 10000, "authorized Crucible balance preview failed", authBalancePreview);

    const unauthConfigPatch = await postRaw(baseUrl, "update_crucible_config", {
      actor_id: "ops_smoke",
      patch: { capacity_max: 2 }
    });
    expect(unauthConfigPatch.http_status === 401 && unauthConfigPatch.err === "admin_auth_required", "Crucible config update should require admin auth", unauthConfigPatch);
    const configPatch = await post(baseUrl, "update_crucible_config", {
      actor_id: "ops_smoke",
      patch: { capacity_max: 1, reserved_slots: 1 }
    }, adminHeaders);
    expect(Number((configPatch.config as JsonRecord).capacity_max) === 1, "Crucible config update failed", configPatch);
    const capacityBlocked = await postRaw(baseUrl, "preview_crucible_entry", {
      player_id: "capacity_blocked"
    });
    expect(capacityBlocked.ok === false && capacityBlocked.err === "capacity", "Crucible capacity block failed", capacityBlocked);
    await post(baseUrl, "update_crucible_config", {
      actor_id: "ops_smoke",
      patch: { capacity_max: 100, reserved_slots: 0 }
    }, adminHeaders);

    const devQuick = await post(baseUrl, "enqueue_quick_match", { profile: { uid: "dev_q", display_name: "Dev Q" }, context });
    const devFill = await post(baseUrl, "debug_fill_quick_match", {
      ticket_id: String(devQuick.ticket_id),
      bot_name: "Turtle Bot"
    });
    expect((devFill.session as JsonRecord).status === "started", "debug quick fill did not auto-start", devFill);
    expect(((devFill.session as JsonRecord).guest as JsonRecord).display_name === "Turtle Bot", "debug quick fill used wrong bot", devFill);

    await post(baseUrl, "heartbeat", { profile: { uid: "friend_a", display_name: "Friend A" } });
    const online = await post(baseUrl, "list_online_friends", { uid: "friend_b", friends: ["friend_a"] });
    expect(Array.isArray(online.online) && (online.online as JsonRecord[]).length === 1, "online friend missing", online);
    const friendInvite = await post(baseUrl, "create_friend_invite", {
      profile: { uid: "friend_a", display_name: "Friend A" },
      target_uid: "friend_b",
      context
    });
    const pending = await post(baseUrl, "poll_friend_invites", { uid: "friend_b" });
    expect(Array.isArray(pending.invites) && (pending.invites as JsonRecord[]).length === 1, "friend invite missing", pending);
    const accepted = await post(baseUrl, "respond_friend_invite", {
      invite_id: String((friendInvite.invite as JsonRecord).id),
      profile: { uid: "friend_b", display_name: "Friend B" },
      accept: true
    });
    expect((accepted.session as JsonRecord).status === "started", "friend invite did not auto-start", accepted);

    const cancel = await post(baseUrl, "enqueue_quick_match", { profile: { uid: "cancel_me", display_name: "Cancel" }, context });
    await post(baseUrl, "cancel_quick_match", { ticket_id: String(cancel.ticket_id), uid: "cancel_me" });

    await post(baseUrl, "leave_session", { session_id: sessionId, uid: guest.uid });
    await post(baseUrl, "leave_session", { session_id: sessionId, uid: host.uid });

    console.log(JSON.stringify({ ok: true, smoke: "pass", base_url: baseUrl }));
    const persistencePath = join(tempDir, "crucible-persistence.json");
    const persistedLedgerA = new CrucibleLedger(persistencePath);
    const persistedConfig = persistedLedgerA.updateConfig({ stake_bps: 0, burn_bps: 0, config_version: 9 }, "smoke");
    expect(persistedConfig.ok === true, "persisted config update failed", persistedConfig);
    persistedLedgerA.setBalanceMillis("persist_a", 10000);
    persistedLedgerA.setBalanceMillis("persist_b", 10000);
    const persistedEscrow = persistedLedgerA.openEscrow("persist_match", "persist_a", "persist_b", {}, "persist_open");
    expect(persistedEscrow.ok === true, "persisted escrow open failed", persistedEscrow);
    const persistedSettlement = persistedLedgerA.settleMatch("persist_match", "persist_a", "SERVER_MATCH_RESULT", "persist_smoke", {}, "persist_settle");
    expect(persistedSettlement.ok === true, "persisted settlement failed", persistedSettlement);
    const persistedLedgerB = new CrucibleLedger(persistencePath);
    const persistedSnapshot = persistedLedgerB.getSnapshot();
    expect(Number((persistedSnapshot.config as JsonRecord).stake_bps) === 0, "persisted config missing", persistedSnapshot.config);
    expect(((persistedSnapshot.settlements_by_match_id as JsonRecord).persist_match as JsonRecord)?.winner_id === "persist_a", "persisted settlement missing", persistedSnapshot);
    expect(Number((persistedSnapshot.balances_by_player as JsonRecord).persist_a) === 11000, "persisted balance missing", persistedSnapshot.balances_by_player);
  } finally {
    await close(server);
    rmSync(tempDir, { recursive: true, force: true });
  }
}

main().catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
