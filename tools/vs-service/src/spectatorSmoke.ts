import http from "node:http";

type JsonRecord = Record<string, unknown>;

process.env.VS_SPECTATOR_ADMIN_TOKEN = "spectator_smoke_token";
process.env.VS_SPECTATOR_LIVE_ENABLED = "1";

const { createApp } = await import("./server.js");

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

async function post(baseUrl: string, action: string, body: JsonRecord, token = ""): Promise<JsonRecord> {
  const data = await postRaw(baseUrl, action, body, token);
  if (data.http_status !== 200 || data.ok !== true) {
    throw new Error(`${action} failed: ${JSON.stringify(data)}`);
  }
  return data;
}

async function postRaw(baseUrl: string, action: string, body: JsonRecord, token = ""): Promise<JsonRecord> {
  const headers: Record<string, string> = { "Content-Type": "application/json", Accept: "application/json" };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  const response = await fetch(`${baseUrl}/${action}`, {
    method: "POST",
    headers,
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

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hostGuestSignature(sessionValue: unknown): string {
  const session = sessionValue as JsonRecord;
  const host = session.host as JsonRecord;
  const guest = session.guest as JsonRecord;
  return JSON.stringify({
    status: session.status,
    host_uid: host.uid,
    host_ready: host.ready,
    guest_uid: guest.uid,
    guest_ready: guest.ready
  });
}

function sampleVisualSnapshot(): JsonRecord {
  return {
    frame_index: 0,
    replay: {
      map: {
        hives: [[1, 0, 0, 1], [2, 100, 0, 2]],
        lane_candidates: [[1, 2]]
      },
      frames: [
        { t: 0, h: [[1, 1, 20], [2, 2, 20]], l: [[1, 1, 2, 1, 0]], u: [] }
      ]
    }
  };
}

async function main(): Promise<void> {
  const server = await listen(createApp());
  const address = server.address();
  if (address == null || typeof address === "string") {
    throw new Error("server did not expose a TCP address");
  }
  const baseUrl = `http://127.0.0.1:${address.port}/v1`;
  try {
    const context = {
      mode: "PVP_SPECTATOR_SMOKE",
      map_count: 1,
      price_usd: 0,
      free_roll: true,
      stage_map_paths: ["res://maps/json/MAP_TEST_SPECTATOR_8x12.json"]
    };
    const host = { uid: "spec_host", display_name: "Host" };
    const guest = { uid: "spec_guest", display_name: "Guest" };
    const spectatorUid = "spec_observer";

    const invite = await post(baseUrl, "create_invite", { profile: host, context });
    const joined = await post(baseUrl, "join_invite", { invite_code: String(invite.invite_code), profile: guest });
    const sessionId = String(joined.session_id);
    const beforeSession = await post(baseUrl, "get_session", { session_id: sessionId });
    const beforeSignature = hostGuestSignature(beforeSession.session);

    const unauthorizedGrant = await postRaw(baseUrl, "create_spectator_grant", {
      session_id: sessionId,
      role: "invited_spectator",
      spectator_uid: spectatorUid
    });
    expect(unauthorizedGrant.ok === false && unauthorizedGrant.err === "spectator_unauthorized", "spectator grant should require admin auth", unauthorizedGrant);

    const delayedGrantResponse = await post(baseUrl, "create_spectator_grant", {
      session_id: sessionId,
      role: "invited_spectator",
      spectator_uid: spectatorUid,
      display_name: "Observer",
      delay_sec: 20
    }, "spectator_smoke_token");
    const delayedGrant = delayedGrantResponse.grant as JsonRecord;
    const delayedToken = String(delayedGrant.token);
    expect(delayedToken.length >= 32, "delayed spectator token missing", delayedGrantResponse);
    expect(Number(delayedGrant.delay_sec) >= 10, "delayed spectator should be delayed", delayedGrant);

    const joinedSpectator = await post(baseUrl, "join_spectate", {
      grant_token: delayedToken,
      session_id: sessionId,
      spectator_uid: spectatorUid
    });
    expect(String((joinedSpectator.spectator as JsonRecord).spectator_uid) === spectatorUid, "spectator join uid mismatch", joinedSpectator);
    expect(hostGuestSignature(joinedSpectator.session) === beforeSignature, "spectator join changed player session", joinedSpectator);

    const readyBlocked = await postRaw(baseUrl, "set_ready", { session_id: sessionId, uid: spectatorUid, ready: true });
    expect(readyBlocked.ok === false && readyBlocked.err === "player_not_in_session", "spectator should not ready", readyBlocked);

    const publishBlocked = await postRaw(baseUrl, "publish_intent", {
      session_id: sessionId,
      uid: spectatorUid,
      command: { kind: "lane_intent", src: 1, dst: 2, intent: "attack" }
    });
    expect(publishBlocked.ok === false && publishBlocked.err === "player_not_in_session", "spectator should not publish intent", publishBlocked);

    const snapshotPublishBlocked = await postRaw(baseUrl, "publish_spectator_snapshot", {
      session_id: sessionId,
      uid: spectatorUid,
      snapshot: sampleVisualSnapshot()
    });
    expect(snapshotPublishBlocked.ok === false && snapshotPublishBlocked.err === "player_not_in_session", "spectator should not publish visual snapshot", snapshotPublishBlocked);

    const playerPollBlocked = await postRaw(baseUrl, "poll_intents", { session_id: sessionId, uid: spectatorUid, after_seq: 0 });
    expect(playerPollBlocked.ok === false && playerPollBlocked.err === "player_not_in_session", "spectator should not poll player intent stream", playerPollBlocked);

    await post(baseUrl, "publish_intent", {
      session_id: sessionId,
      uid: host.uid,
      command: { kind: "lane_intent", src: 1, dst: 2, intent: "attack", issued_tick: 1 }
    });
    await post(baseUrl, "publish_spectator_snapshot", {
      session_id: sessionId,
      uid: host.uid,
      snapshot: sampleVisualSnapshot()
    });

    const delayedPoll = await post(baseUrl, "poll_spectator_events", { grant_token: delayedToken, session_id: sessionId, after_seq: 0 });
    expect(Array.isArray(delayedPoll.events) && (delayedPoll.events as JsonRecord[]).length === 0, "delayed spectator should not see immediate events", delayedPoll);
    const delayedSnapshotPoll = await post(baseUrl, "poll_spectator_snapshots", { grant_token: delayedToken, session_id: sessionId, after_seq: 0 });
    expect(Array.isArray(delayedSnapshotPoll.snapshots) && (delayedSnapshotPoll.snapshots as JsonRecord[]).length === 0, "delayed spectator should not see immediate visual snapshots", delayedSnapshotPoll);

    const liveGrantResponse = await post(baseUrl, "create_spectator_grant", {
      session_id: sessionId,
      role: "admin_spectate",
      spectator_uid: "admin_observer",
      delay_sec: 0
    }, "spectator_smoke_token");
    const liveToken = String((liveGrantResponse.grant as JsonRecord).token);
    const liveJoin = await post(baseUrl, "join_spectate", { grant_token: liveToken, session_id: sessionId, spectator_uid: "admin_observer" });
    expect((liveJoin.spectator as JsonRecord).live === true, "admin live grant should be live when enabled", liveJoin);
    const livePoll = await post(baseUrl, "poll_spectator_events", { grant_token: liveToken, session_id: sessionId, after_seq: 0 });
    const liveEvents = livePoll.events as JsonRecord[];
    expect(Array.isArray(liveEvents) && liveEvents.length === 1, "live spectator should see authoritative event", livePoll);
    expect(String(liveEvents[0].uid) === host.uid, "live spectator saw wrong event sender", livePoll);
    const liveSnapshotPoll = await post(baseUrl, "poll_spectator_snapshots", { grant_token: liveToken, session_id: sessionId, after_seq: 0 });
    const liveSnapshots = liveSnapshotPoll.snapshots as JsonRecord[];
    expect(Array.isArray(liveSnapshots) && liveSnapshots.length === 1, "live spectator should see visual snapshot", liveSnapshotPoll);
    expect(String(liveSnapshots[0].uid) === host.uid, "live spectator saw wrong snapshot sender", liveSnapshotPoll);
    const visualPayload = liveSnapshots[0].snapshot as JsonRecord;
    expect(isRecord(visualPayload.replay), "live spectator visual snapshot missing replay", liveSnapshotPoll);

    const leaveSessionBlocked = await postRaw(baseUrl, "leave_session", { session_id: sessionId, uid: spectatorUid });
    expect(leaveSessionBlocked.ok === false && leaveSessionBlocked.err === "player_not_in_session", "spectator should not leave player session", leaveSessionBlocked);

    const leaveSpectate = await post(baseUrl, "leave_spectate", { grant_token: delayedToken });
    expect(leaveSpectate.closed === true, "spectator leave should close only the spectator grant", leaveSpectate);

    const afterSession = await post(baseUrl, "get_session", { session_id: sessionId });
    expect(hostGuestSignature(afterSession.session) === beforeSignature, "spectator flow changed player session", afterSession);

    await post(baseUrl, "leave_session", { session_id: sessionId, uid: guest.uid });
    await post(baseUrl, "leave_session", { session_id: sessionId, uid: host.uid });
    console.log(JSON.stringify({ ok: true, smoke: "spectator_pass", base_url: baseUrl }));
  } finally {
    await close(server);
  }
}

main().catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
