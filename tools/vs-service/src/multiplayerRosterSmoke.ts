import http from "node:http";

type JsonRecord = Record<string, unknown>;
type ListenableApp = { listen: (port: number, hostname: string, callback: () => void) => http.Server };

function listen(app: ListenableApp): Promise<http.Server> {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function close(server: http.Server): Promise<void> {
  return new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

async function postRaw(baseUrl: string, action: string, body: JsonRecord): Promise<JsonRecord> {
  const response = await fetch(`${baseUrl}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(body)
  });
  return { ...(await response.json() as JsonRecord), http_status: response.status };
}

async function post(baseUrl: string, action: string, body: JsonRecord): Promise<JsonRecord> {
  const result = await postRaw(baseUrl, action, body);
  expect(result.ok === true && result.http_status === 200, `${action} failed`, result);
  return result;
}

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : ` :: ${JSON.stringify(details)}`}`);
}

function sessionFrom(result: JsonRecord): JsonRecord {
  return result.session as JsonRecord;
}

function rosterFrom(result: JsonRecord): JsonRecord[] {
  const roster = sessionFrom(result).roster;
  return Array.isArray(roster) ? roster as JsonRecord[] : [];
}

async function main(): Promise<void> {
  process.env.VS_ECONOMY_MUTATIONS_ENABLED = "false";
  const { createApp } = await import("./server.js");
  const server = await listen(createApp());
  const address = server.address();
  if (address == null || typeof address === "string") throw new Error("server address unavailable");
  const baseUrl = `http://127.0.0.1:${address.port}/v1`;
  try {
    const context = { mode: "2V2", map_count: 1, human_pvp: true, free_roll: true, required_players: 2 };
    const invite = await post(baseUrl, "create_invite", { profile: { uid: "team_p1", display_name: "P1" }, context });
    const code = String(invite.invite_code ?? "");
    const sessionId = String(invite.session_id ?? "");
    expect(Number(sessionFrom(invite).required_players) === 4, "2V2 did not normalize to four seats", invite);
    expect(Number(sessionFrom(invite).contract_version) === 2 && String(sessionFrom(invite).contract_hash ?? "").length === 64, "contract identity missing", invite);

    for (let seat = 2; seat <= 4; seat += 1) {
      const joined = await post(baseUrl, "join_invite", { invite_code: code, profile: { uid: `team_p${seat}`, display_name: `P${seat}` } });
      expect(rosterFrom(joined).length === seat, `join did not fill seat ${seat}`, joined);
      expect(String(sessionFrom(joined).status) === (seat === 4 ? "matched" : "waiting"), `wrong status at seat ${seat}`, joined);
    }

    const prematureStart = await postRaw(baseUrl, "start_session", { session_id: sessionId, uid: "team_p1" });
    expect(prematureStart.ok === false && prematureStart.err === "not_ready_or_not_host", "synchronized session started before every player loaded", prematureStart);
    for (let seat = 1; seat <= 4; seat += 1) {
      const ready = await post(baseUrl, "set_ready", { session_id: sessionId, uid: `team_p${seat}`, ready: true });
      expect(String(sessionFrom(ready).status) === (seat === 4 ? "ready" : "matched"), `wrong ready status at seat ${seat}`, ready);
    }
    const started = await post(baseUrl, "start_session", { session_id: sessionId, uid: "team_p1" });
    const startEpoch = Number(sessionFrom(started).start_unix_ms ?? 0);
    expect(String(sessionFrom(started).status) === "started" && startEpoch > Number(started.server_unix_ms), "shared future start epoch missing", started);
    const synchronizedLeadMs = startEpoch - Number(started.server_unix_ms);
    expect(synchronizedLeadMs >= 17_500 && synchronizedLeadMs <= 18_500, "shared start should reserve the 8-second ad window before prematch", started);
    const duplicateStart = await post(baseUrl, "start_session", { session_id: sessionId, uid: "team_p1" });
    expect(Number(sessionFrom(duplicateStart).start_unix_ms ?? 0) === startEpoch, "idempotent start changed the shared epoch", duplicateStart);
    const overflow = await postRaw(baseUrl, "join_invite", { invite_code: code, profile: { uid: "team_p5", display_name: "P5" } });
    expect(overflow.ok === false && overflow.err === "invite_full", "full roster accepted another player", overflow);
    const spoofedSeat = await postRaw(baseUrl, "publish_intent", {
      session_id: sessionId,
      uid: "team_p2",
      command: { kind: "lane_intent", sender_seat: 4, issued_tick: 10, execute_tick: 13 }
    });
    expect(spoofedSeat.ok === false && spoofedSeat.err === "sender_seat_mismatch", "player could publish as another contracted seat", spoofedSeat);

    for (let seat = 2; seat <= 4; seat += 1) {
      await post(baseUrl, "publish_intent", {
        session_id: sessionId,
        uid: `team_p${seat}`,
        command: { kind: "lane_intent", sender_seat: seat, issued_tick: 10, execute_tick: 13 }
      });
    }
    const poll = await post(baseUrl, "poll_intents", { session_id: sessionId, uid: "team_p1", after_seq: 0 });
    const events = Array.isArray(poll.events) ? poll.events as JsonRecord[] : [];
    expect(events.length === 3 && new Set(events.map((event) => event.uid)).size === 3, "host did not receive every remote player's event", poll);

    const quickContext = { mode: "3P FFA", map_count: 1, human_pvp: true, free_roll: true };
    const q1 = await post(baseUrl, "enqueue_quick_match", { profile: { uid: "quick_p1", display_name: "Q1" }, context: quickContext });
    const q2 = await post(baseUrl, "enqueue_quick_match", { profile: { uid: "quick_p2", display_name: "Q2" }, context: quickContext });
    const q3 = await post(baseUrl, "enqueue_quick_match", { profile: { uid: "quick_p3", display_name: "Q3" }, context: quickContext });
    expect(q1.matched === false, "first 3P player should remain queued", q1);
    expect(q2.matched === true && String(sessionFrom(q2).status) === "waiting", "second 3P player should form a partial roster", q2);
    expect(q3.matched === true && String(sessionFrom(q3).status) === "matched" && rosterFrom(q3).length === 3, "third 3P player should complete the loading roster", q3);
    const q1Poll = await post(baseUrl, "poll_quick_match", { ticket_id: q1.ticket_id });
    expect(q1Poll.matched === true && rosterFrom(q1Poll).length === 3, "first ticket did not resolve to the full 3P roster", q1Poll);

    console.log(JSON.stringify({ ok: true, smoke: "multiplayer_roster_pass" }));
  } finally {
    await close(server);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
