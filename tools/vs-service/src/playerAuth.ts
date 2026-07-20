import crypto from "node:crypto";

export type AuthenticatedPlayer = {
  playerId: string;
  sessionId: string;
  deviceId: string;
  scopes: string[];
  displayName: string;
  entapId: string;
  expiresAtUnix: number;
};

export class PlayerAuthError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
    this.name = "PlayerAuthError";
  }
}

type VerifyConfig = {
  issuer: string;
  audience: string;
  keyId: string;
  publicKeyPem: string;
};

function decodeObject(value: string): Record<string, unknown> {
  try {
    const decoded = JSON.parse(Buffer.from(value, "base64url").toString("utf8")) as unknown;
    if (typeof decoded !== "object" || decoded == null || Array.isArray(decoded)) throw new Error("not_object");
    return decoded as Record<string, unknown>;
  } catch {
    throw new PlayerAuthError("player_token_invalid", 401);
  }
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function integerValue(value: unknown): number {
  return typeof value === "number" && Number.isSafeInteger(value) ? value : Number.NaN;
}

export function playerAuthConfigured(config: VerifyConfig): boolean {
  if (!config.issuer || !config.audience || !config.keyId || !config.publicKeyPem) return false;
  try {
    crypto.createPublicKey(config.publicKeyPem);
    return true;
  } catch {
    return false;
  }
}

export function verifyPlayerToken(token: string, config: VerifyConfig, requiredScope: string,
  nowUnix = Math.floor(Date.now() / 1000)): AuthenticatedPlayer {
  if (!playerAuthConfigured(config)) {
    throw new PlayerAuthError("player_auth_not_configured", 503);
  }
  const parts = token.split(".");
  if (parts.length !== 3 || parts.some((part) => !part)) {
    throw new PlayerAuthError("player_token_invalid", 401);
  }
  const header = decodeObject(parts[0]);
  if (header.alg !== "ES256" || header.typ !== "JWT" || header.kid !== config.keyId) {
    throw new PlayerAuthError("player_token_invalid", 401);
  }
  const signature = Buffer.from(parts[2], "base64url");
  if (signature.length !== 64 || !crypto.verify("sha256", Buffer.from(`${parts[0]}.${parts[1]}`, "ascii"), {
    key: config.publicKeyPem,
    dsaEncoding: "ieee-p1363"
  }, signature)) {
    throw new PlayerAuthError("player_token_invalid", 401);
  }
  const payload = decodeObject(parts[1]);
  const issuer = stringValue(payload.iss);
  const audience = stringValue(payload.aud);
  const playerId = stringValue(payload.sub);
  const sessionId = stringValue(payload.sid);
  const deviceId = stringValue(payload.did);
  const tokenId = stringValue(payload.jti);
  const issuedAt = integerValue(payload.iat);
  const notBefore = integerValue(payload.nbf);
  const expiresAt = integerValue(payload.exp);
  const scopes = Array.isArray(payload.scp)
    ? payload.scp.filter((scope): scope is string => typeof scope === "string" && scope.length > 0)
    : [];
  const uuidV7 = /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (issuer !== config.issuer || audience !== config.audience || payload.ver !== 1
    || !uuidV7.test(playerId) || !uuidV7.test(sessionId) || !uuidV7.test(deviceId) || !tokenId || !Number.isFinite(issuedAt)
    || !Number.isFinite(notBefore) || !Number.isFinite(expiresAt)
    || notBefore > nowUnix + 5 || issuedAt > nowUnix + 5 || expiresAt <= nowUnix - 5 || expiresAt <= issuedAt) {
    throw new PlayerAuthError("player_token_invalid", 401);
  }
  if (!scopes.includes(requiredScope)) {
    throw new PlayerAuthError("player_scope_required", 403);
  }
  return {
    playerId,
    sessionId,
    deviceId,
    scopes,
    displayName: stringValue(payload.name),
    entapId: stringValue(payload.entap_id),
    expiresAtUnix: expiresAt
  };
}

export function bearerPlayerToken(value: string | undefined): string {
  const raw = String(value ?? "").trim();
  return raw.toLowerCase().startsWith("bearer ") ? raw.slice(7).trim() : "";
}
