import crypto from "node:crypto";
import type { Pool, QueryResult } from "pg";
import { PGlite, type PGliteInterface } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { runMigrations } from "../db/migrate.js";
import { IdentitySessionError, IdentitySessionStore } from "./sessionStore.js";
import { verifyPlayerAccessToken, type PlayerTokenKeyConfig } from "./playerToken.js";

type PGliteResult<T> = { rows: T[]; affectedRows?: number };

class PGlitePoolAdapter {
  constructor(private readonly db: PGliteInterface) {}

  async query<T extends Record<string, unknown> = Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<QueryResult<T>> {
    if (params.length === 0 && sql.split(";").filter((part) => part.trim()).length > 1) {
      const results = await this.db.exec(sql);
      const last = (results.at(-1) ?? { rows: [], affectedRows: 0 }) as PGliteResult<T>;
      return this.normalize(last);
    }
    return this.normalize(await this.db.query<T>(sql, params) as PGliteResult<T>);
  }

  async connect(): Promise<PGlitePoolAdapter & { release: () => void }> {
    return Object.assign(this, { release: () => undefined });
  }

  private normalize<T extends Record<string, unknown>>(result: PGliteResult<T>): QueryResult<T> {
    return {
      command: "",
      rowCount: result.rows.length > 0 ? result.rows.length : (result.affectedRows ?? 0),
      oid: 0,
      fields: [],
      rows: result.rows
    };
  }
}

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

async function expectIdentityError(promise: Promise<unknown>, code: string): Promise<void> {
  try {
    await promise;
  } catch (error) {
    expect(error instanceof IdentitySessionError && error.code === code,
      `expected ${code}`, error instanceof Error ? error.message : error);
    return;
  }
  throw new Error(`expected ${code}`);
}

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const adapter = new PGlitePoolAdapter(db);
  const pool = adapter as unknown as Pool;
  await runMigrations(pool);

  const issuerPair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const tokenConfig: PlayerTokenKeyConfig = {
    issuer: "entap-embedded-smoke",
    audience: "swarmfront-vs-embedded-smoke",
    keyId: "embedded-key-v1",
    privateKeyPem: issuerPair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
    publicKeyPem: issuerPair.publicKey.export({ format: "pem", type: "spki" }).toString(),
    accessTokenTtlSec: 600
  };
  const devicePair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const deviceJwk = devicePair.publicKey.export({ format: "jwk" });
  const sessions = new IdentitySessionStore(pool, tokenConfig, 300);
  const registrationInput = {
    requestId: "embedded-register-0001",
    callSign: "EmbeddedSmoke",
    region: "SMOKE",
    publicKeyJwk: deviceJwk,
    platform: "embedded",
    deviceLabel: "PGlite",
    installMetadata: { smoke: true }
  };
  const registration = await sessions.registerIdentityAndDevice(registrationInput);
  expect(registration.duplicate === false, "first registration marked duplicate", registration);
  expect(/^.{8}-.{4}-7/.test(registration.player.id), "player is not UUIDv7", registration.player);
  expect(/^.{8}-.{4}-7/.test(registration.device.id), "device is not UUIDv7", registration.device);

  const duplicate = await sessions.registerIdentityAndDevice(registrationInput);
  expect(duplicate.duplicate === true && duplicate.player.id === registration.player.id,
    "registration idempotency failed", duplicate);
  await expectIdentityError(sessions.registerIdentityAndDevice({ ...registrationInput, callSign: "ConflictName" }),
    "idempotency_conflict");

  const challenge = registration.challenge;
  const signature = crypto.sign("sha256", Buffer.from(String(challenge.challenge), "utf8"), {
    key: devicePair.privateKey,
    dsaEncoding: "ieee-p1363"
  }).toString("base64url");
  const issued = await sessions.createSession(String(challenge.id), signature);
  const accessToken = String(issued.access_token ?? "");
  const claims = verifyPlayerAccessToken(accessToken, tokenConfig, { requiredScope: "match:queue" });
  expect(claims.sub === registration.player.id && claims.did === registration.device.id
    && claims.scp.includes("contest:play"),
    "issued token identity mismatch", claims);
  await expectIdentityError(sessions.createSession(String(challenge.id), signature), "challenge_already_used");

  const session = issued.session as Record<string, unknown>;
  expect(await sessions.revokeSession(String(session.id), claims.sub, "embedded_smoke"), "first revoke failed");
  expect(await sessions.revokeSession(String(session.id), claims.sub, "duplicate"), "duplicate revoke was not idempotent");

  const restartedStore = new IdentitySessionStore(pool, tokenConfig, 300);
  const resumeChallenge = await restartedStore.issueChallenge(registration.device.id, "embedded-resume-0001");
  const derSignature = crypto.sign("sha256", Buffer.from(String(resumeChallenge.challenge), "utf8"), devicePair.privateKey)
    .toString("base64url");
  const resumed = await restartedStore.createSession(String(resumeChallenge.id), derSignature);
  const resumedClaims = verifyPlayerAccessToken(String(resumed.access_token), tokenConfig, { requiredScope: "match:queue" });
  expect(resumedClaims.sub === registration.player.id, "restart/resume changed identity", resumedClaims);

  const counts = await adapter.query<{ devices: string; sessions: string; audits: string }>(`
    SELECT
      (SELECT count(*)::text FROM entap_player_devices) AS devices,
      (SELECT count(*)::text FROM entap_player_sessions) AS sessions,
      (SELECT count(*)::text FROM rank_audit_events
        WHERE event_type IN ('player_registered', 'player_device_registered', 'player_session_issued', 'player_session_revoked')) AS audits
  `);
  expect(counts.rows[0].devices === "1" && counts.rows[0].sessions === "2"
    && Number(counts.rows[0].audits) >= 5, "durable identity/session/audit counts mismatch", counts.rows[0]);

  await db.close();
  console.log(JSON.stringify({
    ok: true,
    smoke: "embedded_device_session",
    migrations: 5,
    player_id: registration.player.id,
    sessions: 2,
    restart_resume: true
  }));
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
