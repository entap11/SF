import crypto, { type JsonWebKey } from "node:crypto";
import type { Pool, PoolClient } from "pg";
import { signPlayerAccessToken, type PlayerTokenKeyConfig } from "./playerToken.js";

const PLAYER_SESSION_SCOPES = ["contest:play", "match:queue"];

type IdentityPlayer = {
  id: string;
  entap_id: string;
  call_sign: string;
  region: string;
};

type DeviceRow = {
  id: string;
  player_id: string;
  public_key_jwk: JsonWebKey;
  public_key_sha256: string;
  platform: string;
  device_label: string;
  status: string;
  registration_request_id: string;
};

type ChallengeRow = {
  id: string;
  device_id: string;
  nonce: string;
  request_key: string;
  purpose: string;
  expires_at: Date | string;
  used_at: Date | string | null;
  player_id: string;
  public_key_jwk: JsonWebKey;
  device_status: string;
  entap_id: string;
  call_sign: string;
};

export class IdentitySessionError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, status = 400) {
    super(code);
    this.name = "IdentitySessionError";
    this.code = code;
    this.status = status;
  }
}

function challengeText(id: string, nonce: string): string {
  return `swarmfront:identity-session:v1:${id}:${nonce}`;
}

function normalizePublicJwk(value: unknown): JsonWebKey {
  if (typeof value !== "object" || value == null || Array.isArray(value)) {
    throw new IdentitySessionError("invalid_device_public_key");
  }
  const raw = value as Record<string, unknown>;
  const jwk: JsonWebKey = {
    kty: typeof raw.kty === "string" ? raw.kty : undefined,
    crv: typeof raw.crv === "string" ? raw.crv : undefined,
    x: typeof raw.x === "string" ? raw.x : undefined,
    y: typeof raw.y === "string" ? raw.y : undefined
  };
  if (jwk.kty !== "EC" || jwk.crv !== "P-256" || !jwk.x || !jwk.y || raw.d != null) {
    throw new IdentitySessionError("invalid_device_public_key");
  }
  try {
    crypto.createPublicKey({ key: jwk, format: "jwk" });
  } catch {
    throw new IdentitySessionError("invalid_device_public_key");
  }
  return jwk;
}

function publicKeyFingerprint(jwk: JsonWebKey): string {
  const canonical = JSON.stringify({ crv: jwk.crv, kty: jwk.kty, x: jwk.x, y: jwk.y });
  return crypto.createHash("sha256").update(canonical).digest("hex");
}

function verifyDeviceSignature(publicJwk: JsonWebKey, message: string, encodedSignature: string): boolean {
  let signature: Buffer;
  try {
    signature = Buffer.from(encodedSignature, "base64url");
  } catch {
    return false;
  }
  if (signature.length === 0) {
    return false;
  }
  const key = crypto.createPublicKey({ key: publicJwk, format: "jwk" });
  const data = Buffer.from(message, "utf8");
  try {
    if (signature.length === 64 && crypto.verify("sha256", data, { key, dsaEncoding: "ieee-p1363" }, signature)) {
      return true;
    }
    return crypto.verify("sha256", data, key, signature);
  } catch {
    return false;
  }
}

export class IdentitySessionStore {
  constructor(private readonly pool: Pool, private readonly tokenConfig: PlayerTokenKeyConfig,
    private readonly challengeTtlSec: number) {}

  async registerIdentityAndDevice(input: {
    requestId: string;
    callSign: string;
    region: string;
    publicKeyJwk: unknown;
    platform: string;
    deviceLabel: string;
    installMetadata: Record<string, unknown>;
  }): Promise<{ player: IdentityPlayer; device: Omit<DeviceRow, "public_key_jwk">; challenge: Record<string, unknown>; duplicate: boolean }> {
    const publicKeyJwk = normalizePublicJwk(input.publicKeyJwk);
    const fingerprint = publicKeyFingerprint(publicKeyJwk);
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const existing = await client.query<DeviceRow & IdentityPlayer>(
        `
          SELECT d.id, d.player_id, d.public_key_jwk, d.public_key_sha256, d.platform,
            d.device_label, d.status, d.registration_request_id,
            p.id AS player_identity_id, p.entap_id, p.call_sign, p.region
          FROM entap_player_devices d
          JOIN rank_players p ON p.id = d.player_id
          WHERE d.registration_request_id = $1
          FOR UPDATE
        `,
        [input.requestId]
      );
      if ((existing.rowCount ?? 0) > 0) {
        const row = existing.rows[0] as DeviceRow & IdentityPlayer & { player_identity_id?: string };
        if (row.public_key_sha256 !== fingerprint || row.call_sign.toLowerCase() !== input.callSign.toLowerCase()) {
          throw new IdentitySessionError("idempotency_conflict", 409);
        }
        const challenge = await this.readOrCreateChallenge(client, row.id, `register:${input.requestId}`, "registration");
        await client.query("COMMIT");
        return {
          player: { id: row.player_id, entap_id: row.entap_id, call_sign: row.call_sign, region: row.region },
          device: this.publicDevice(row),
          challenge,
          duplicate: true
        };
      }

      const duplicateKey = await client.query<{ id: string }>(
        "SELECT id::text AS id FROM entap_player_devices WHERE public_key_sha256 = $1 LIMIT 1",
        [fingerprint]
      );
      if ((duplicateKey.rowCount ?? 0) > 0) {
        throw new IdentitySessionError("device_already_registered", 409);
      }

      const playerResult = await client.query<IdentityPlayer>(
        `
          WITH identity AS (
            SELECT rank_uuid_v7() AS id,
              rank_entap_id_from_sequence(nextval('rank_entap_id_seq')) AS entap_id
          )
          INSERT INTO rank_players (
            id, entap_id, call_sign, region, wax_score, last_active_unix, last_decay_day,
            tier_id, color_id, rank_position, percentile, promotion_history, friends,
            apex_active, updated_at
          )
          SELECT identity.id, identity.entap_id, $1, $2, 0,
            floor(extract(epoch from now()))::bigint, -1, 'DRONE', 'GREEN', 0, 0,
            '{"DRONE": true}'::jsonb, '[]'::jsonb, false, now()
          FROM identity
          RETURNING id::text AS id, entap_id, call_sign, region
        `,
        [input.callSign, input.region]
      );
      const player = playerResult.rows[0];
      const deviceResult = await client.query<DeviceRow>(
        `
          INSERT INTO entap_player_devices (
            player_id, public_key_jwk, public_key_sha256, platform, device_label,
            registration_request_id
          ) VALUES ($1::uuid, $2::jsonb, $3, $4, $5, $6)
          RETURNING id::text, player_id::text, public_key_jwk, public_key_sha256,
            platform, device_label, status, registration_request_id
        `,
        [player.id, JSON.stringify(publicKeyJwk), fingerprint, input.platform, input.deviceLabel, input.requestId]
      );
      const device = deviceResult.rows[0];
      const challenge = await this.readOrCreateChallenge(client, device.id, `register:${input.requestId}`, "registration");
      await client.query(
        `
          INSERT INTO rank_audit_events (event_type, player_id, payload)
          VALUES
            ('player_registered', $1, $2::jsonb),
            ('player_device_registered', $1, $2::jsonb)
        `,
        [player.id, JSON.stringify({
          entap_id: player.entap_id,
          call_sign: player.call_sign,
          device_id: device.id,
          public_key_sha256: fingerprint,
          platform: input.platform,
          registration_request_id: input.requestId,
          install_metadata: input.installMetadata,
          economy_exception: "identity_registration_zero_wax"
        })]
      );
      await client.query("COMMIT");
      return { player, device: this.publicDevice(device), challenge, duplicate: false };
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      if (error instanceof IdentitySessionError) {
        throw error;
      }
      const pgError = error as { code?: string; constraint?: string; detail?: string };
      if (pgError.code === "23505") {
        const detail = `${pgError.constraint ?? ""} ${pgError.detail ?? ""}`.toLowerCase();
        if (detail.includes("call_sign")) {
          throw new IdentitySessionError("call_sign_not_unique", 409);
        }
        if (detail.includes("registration_request_id")) {
          throw new IdentitySessionError("registration_request_conflict", 409);
        }
      }
      throw error;
    } finally {
      client.release();
    }
  }

  async issueChallenge(deviceId: string, requestId: string): Promise<Record<string, unknown>> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const device = await client.query<{ status: string }>(
        "SELECT status FROM entap_player_devices WHERE id = $1::uuid FOR UPDATE",
        [deviceId]
      );
      if ((device.rowCount ?? 0) === 0) {
        throw new IdentitySessionError("device_not_found", 404);
      }
      if (device.rows[0].status !== "active") {
        throw new IdentitySessionError("device_revoked", 403);
      }
      const challenge = await this.readOrCreateChallenge(client, deviceId, `session:${deviceId}:${requestId}`, "session");
      await client.query("COMMIT");
      return challenge;
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async createSession(challengeId: string, encodedSignature: string): Promise<Record<string, unknown>> {
    const client = await this.pool.connect();
    let session: { id: string; player_id: string; device_id: string; entap_id: string; call_sign: string };
    let signed: ReturnType<typeof signPlayerAccessToken> | null = null;
    try {
      await client.query("BEGIN");
      const challengeResult = await client.query<ChallengeRow>(
        `
          SELECT c.id::text, c.device_id::text, c.nonce, c.request_key, c.purpose,
            c.expires_at, c.used_at, d.player_id::text, d.public_key_jwk,
            d.status AS device_status, p.entap_id, p.call_sign
          FROM entap_device_challenges c
          JOIN entap_player_devices d ON d.id = c.device_id
          JOIN rank_players p ON p.id = d.player_id
          WHERE c.id = $1::uuid
          FOR UPDATE OF c, d
        `,
        [challengeId]
      );
      if ((challengeResult.rowCount ?? 0) === 0) {
        throw new IdentitySessionError("challenge_not_found", 404);
      }
      const challenge = challengeResult.rows[0];
      if (challenge.used_at != null) {
        throw new IdentitySessionError("challenge_already_used", 409);
      }
      if (new Date(challenge.expires_at).getTime() <= Date.now()) {
        throw new IdentitySessionError("challenge_expired", 410);
      }
      if (challenge.device_status !== "active") {
        throw new IdentitySessionError("device_revoked", 403);
      }
      if (!verifyDeviceSignature(challenge.public_key_jwk, challengeText(challenge.id, challenge.nonce), encodedSignature)) {
        throw new IdentitySessionError("device_signature_invalid", 401);
      }
      const sessionResult = await client.query<{ id: string; player_id: string; device_id: string }>(
        `
          INSERT INTO entap_player_sessions (player_id, device_id, scopes, expires_at)
          VALUES ($1::uuid, $2::uuid, ARRAY['contest:play', 'match:queue']::text[], now() + ($3 * interval '1 second'))
          RETURNING id::text, player_id::text, device_id::text
        `,
        [challenge.player_id, challenge.device_id, this.tokenConfig.accessTokenTtlSec]
      );
      await client.query("UPDATE entap_device_challenges SET used_at = now() WHERE id = $1::uuid", [challenge.id]);
      await client.query("UPDATE entap_player_devices SET last_authenticated_at = now() WHERE id = $1::uuid", [challenge.device_id]);
      session = { ...sessionResult.rows[0], entap_id: challenge.entap_id, call_sign: challenge.call_sign };
      signed = signPlayerAccessToken({
        playerId: session.player_id,
        sessionId: session.id,
        deviceId: session.device_id,
        scopes: PLAYER_SESSION_SCOPES,
        displayName: session.call_sign,
        entapId: session.entap_id
      }, this.tokenConfig);
      await client.query(
        "INSERT INTO rank_audit_events (event_type, player_id, payload) VALUES ('player_session_issued', $1, $2::jsonb)",
        [challenge.player_id, JSON.stringify({ session_id: session.id, device_id: session.device_id, scopes: PLAYER_SESSION_SCOPES })]
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
    if (signed == null) {
      throw new IdentitySessionError("session_signing_failed", 500);
    }
    return {
      access_token: signed.token,
      token_type: "Bearer",
      expires_in: Math.max(60, this.tokenConfig.accessTokenTtlSec),
      session: {
        id: session.id,
        player_id: session.player_id,
        device_id: session.device_id,
        scopes: signed.claims.scp,
        expires_at_unix: signed.claims.exp
      },
      player: { id: session.player_id, entap_id: session.entap_id, call_sign: session.call_sign }
    };
  }

  async revokeSession(sessionId: string, playerId: string, reason: string): Promise<boolean> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const revoked = await client.query<{ id: string; device_id: string; revoked_at: Date | string; revoke_reason: string }>(
        `
          UPDATE entap_player_sessions
          SET revoked_at = now(), revoke_reason = $3
          WHERE id = $1::uuid AND player_id = $2::uuid AND revoked_at IS NULL
          RETURNING id::text, device_id::text, revoked_at, revoke_reason
        `,
        [sessionId, playerId, reason || "player_request"]
      );
      if ((revoked.rowCount ?? 0) > 0) {
        const row = revoked.rows[0];
        await client.query(
          "INSERT INTO rank_audit_events (event_type, player_id, payload) VALUES ('player_session_revoked', $1, $2::jsonb)",
          [playerId, JSON.stringify({
            session_id: row.id,
            device_id: row.device_id,
            revoked_at: new Date(row.revoked_at).toISOString(),
            reason: row.revoke_reason
          })]
        );
        await client.query("COMMIT");
        return true;
      }
      const existing = await client.query<{ id: string }>(
        "SELECT id::text FROM entap_player_sessions WHERE id = $1::uuid AND player_id = $2::uuid AND revoked_at IS NOT NULL",
        [sessionId, playerId]
      );
      await client.query("COMMIT");
      return (existing.rowCount ?? 0) > 0;
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  private async readOrCreateChallenge(client: PoolClient, deviceId: string, requestKey: string,
    purpose: string): Promise<Record<string, unknown>> {
    const existing = await client.query<{ id: string; nonce: string; expires_at: Date | string; used_at: Date | string | null }>(
      "SELECT id::text, nonce, expires_at, used_at FROM entap_device_challenges WHERE request_key = $1",
      [requestKey]
    );
    let row = existing.rows[0];
    if (!row) {
      const nonce = crypto.randomBytes(32).toString("base64url");
      const created = await client.query<{ id: string; nonce: string; expires_at: Date | string; used_at: null }>(
        `
          INSERT INTO entap_device_challenges (device_id, nonce, request_key, purpose, expires_at)
          VALUES ($1::uuid, $2, $3, $4, now() + ($5 * interval '1 second'))
          RETURNING id::text, nonce, expires_at, used_at
        `,
        [deviceId, nonce, requestKey, purpose, this.challengeTtlSec]
      );
      row = created.rows[0];
    }
    return {
      id: row.id,
      device_id: deviceId,
      purpose,
      challenge: challengeText(row.id, row.nonce),
      expires_at: new Date(row.expires_at).toISOString(),
      used: row.used_at != null
    };
  }

  private publicDevice(device: DeviceRow): Omit<DeviceRow, "public_key_jwk"> {
    return {
      id: device.id,
      player_id: device.player_id,
      public_key_sha256: device.public_key_sha256,
      platform: device.platform,
      device_label: device.device_label,
      status: device.status,
      registration_request_id: device.registration_request_id
    };
  }
}
