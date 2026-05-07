import http from "node:http";
import { createApp } from "./server.js";

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

    await post(baseUrl, "set_ready", { session_id: sessionId, uid: host.uid, ready: true });
    await post(baseUrl, "set_ready", { session_id: sessionId, uid: guest.uid, ready: true });

    const hostCanStart = await post(baseUrl, "can_start", { session_id: sessionId, uid: host.uid });
    const guestCanStart = await post(baseUrl, "can_start", { session_id: sessionId, uid: guest.uid });
    expect(hostCanStart.can_start === true, "host should be able to start", hostCanStart);
    expect(guestCanStart.can_start === false, "guest should not be able to start", guestCanStart);

    const started = await post(baseUrl, "start_session", { session_id: sessionId, uid: host.uid });
    const startedSession = started.session as JsonRecord;
    expect(startedSession.status === "started", "session did not start", started);

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
    const qPoll = await post(baseUrl, "poll_quick_match", { ticket_id: String(q1.ticket_id) });
    expect(qPoll.matched === true && qPoll.session_id === q2.session_id, "quick poll did not find match", qPoll);

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
