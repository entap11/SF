import assert from "node:assert/strict";
import express from "express";
import type { Server } from "node:http";
import { playerSessionStatusMiddleware } from "./playerSessionStatus.js";

const start = async (app: express.Express): Promise<{ server: Server; base: string }> => {
  const server = app.listen(0, "127.0.0.1");
  await new Promise<void>(resolve => server.once("listening", resolve));
  return { server, base: `http://127.0.0.1:${(server.address() as { port: number }).port}` };
};
const stop = (server: Server): Promise<void> => new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));

async function main(): Promise<void> {
  let active = true;
  let available = true;
  let checks = 0;
  const authority = express();
  authority.post("/status", (_req, res) => {
    checks++;
    res.status(!available ? 503 : active ? 200 : 403).json({ ok: available && active, active: available && active });
  });
  const issuer = await start(authority);
  const app = express();
  app.use(playerSessionStatusMiddleware(`${issuer.base}/status`, true));
  app.get("/", (_req, res) => res.json({ ok: true }));
  const service = await start(app);
  const missing = express();
  missing.use(playerSessionStatusMiddleware("", true));
  missing.get("/", (_req, res) => res.json({ ok: true }));
  const noIssuer = await start(missing);
  const token = `header.${Buffer.from(JSON.stringify({ sid: "session", did: "device" })).toString("base64url")}.signature`;
  const headers = { Authorization: `Bearer ${token}` };
  try {
    assert.equal((await fetch(service.base, { headers })).status, 200);
    active = false;
    assert.equal((await fetch(service.base, { headers })).status, 403);
    assert.equal(checks, 2, "positive session checks must not be cached");
    available = false;
    assert.equal((await fetch(service.base, { headers })).status, 503);
    assert.equal((await fetch(noIssuer.base, { headers })).status, 503);
    assert.equal((await fetch(service.base)).status, 200, "public routes remain available");
    console.log(JSON.stringify({ ok: true, smoke: "player_session_status", revoked: true, fail_closed: true }));
  } finally { await stop(service.server); await stop(noIssuer.server); await stop(issuer.server); }
}
void main().catch(error => { console.error(error); process.exitCode = 1; });
