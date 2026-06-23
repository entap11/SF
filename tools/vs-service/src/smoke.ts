import http from "node:http";
import { bestQuickMatchCandidateForTest, createApp } from "./server.js";

type JsonRecord = Record<string, unknown>;

function listen(app: ReturnType<typeof createApp>): Promise<http.Server> {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function close(server: http.Server): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((err) => (err ? reject(err) : resolve()));
  });
}

async function post(baseUrl: string, action: string, body: JsonRecord): Promise<JsonRecord> {
  const data = await postRaw(baseUrl, action, body);
  if (data.http_status !== 200 || data.ok !== true) {
    throw new Error(`${action} failed: ${JSON.stringify(data)}`);
  }
  return data;
}

async function postRaw(baseUrl: string, action: string, body: JsonRecord): Promise<JsonRecord> {
  const response = await fetch(`${baseUrl}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
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
  const server = await listen(createApp());
  const address = server.address();
  if (address == null || typeof address === "string") {
    throw new Error("server did not expose a TCP address");
  }
  const baseUrl = `http://127.0.0.1:${address.port}/v1`;
  try {
    const health = await fetch(`http://127.0.0.1:${address.port}/health`).then((res) => res.json() as Promise<JsonRecord>);
    expect(health.ok === true, "health failed", health);

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
  } finally {
    await close(server);
  }
}

main().catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
