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
  const response = await fetch(`${baseUrl}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(body)
  });
  const data = await response.json() as JsonRecord;
  if (!response.ok || data.ok !== true) {
    throw new Error(`${action} failed: ${JSON.stringify(data)}`);
  }
  return data;
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

    const guestPoll = await post(baseUrl, "poll_intents", { session_id: sessionId, uid: guest.uid, after_seq: 0 });
    const guestEvents = guestPoll.events as JsonRecord[];
    expect(Array.isArray(guestEvents) && guestEvents.length === 1, "guest did not receive host event", guestPoll);
    expect(guestEvents[0].uid === host.uid, "guest received wrong sender", guestPoll);

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
