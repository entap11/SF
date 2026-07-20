import crypto, { type JsonWebKey } from "node:crypto";

export type PlayerTokenClaims = {
  iss: string;
  aud: string;
  sub: string;
  sid: string;
  did: string;
  scp: string[];
  iat: number;
  nbf: number;
  exp: number;
  jti: string;
  ver: 1;
  name?: string;
  entap_id?: string;
};

export type PlayerTokenKeyConfig = {
  issuer: string;
  audience: string;
  keyId: string;
  privateKeyPem: string;
  publicKeyPem: string;
  accessTokenTtlSec: number;
};

export class PlayerTokenError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.name = "PlayerTokenError";
    this.code = code;
  }
}

function encodeJson(value: unknown): string {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64url");
}

function decodeCanonicalBase64Url(value: string, errorCode: string): Buffer {
  try {
    if (!/^[A-Za-z0-9_-]+$/.test(value)) throw new Error("invalid alphabet");
    const decoded = Buffer.from(value, "base64url");
    if (decoded.toString("base64url") !== value) throw new Error("non-canonical encoding");
    return decoded;
  } catch {
    throw new PlayerTokenError(errorCode);
  }
}

function decodeJson(value: string): Record<string, unknown> {
  try {
    const decoded = JSON.parse(decodeCanonicalBase64Url(value, "token_malformed").toString("utf8")) as unknown;
    if (typeof decoded !== "object" || decoded == null || Array.isArray(decoded)) {
      throw new Error("not an object");
    }
    return decoded as Record<string, unknown>;
  } catch {
    throw new PlayerTokenError("token_malformed");
  }
}

function stringClaim(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function numberClaim(value: unknown): number {
  return typeof value === "number" && Number.isSafeInteger(value) ? value : Number.NaN;
}

function isUuidV7(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export function playerTokenConfigured(config: PlayerTokenKeyConfig): boolean {
  if (!config.privateKeyPem || !config.publicKeyPem || !config.issuer || !config.audience || !config.keyId) {
    return false;
  }
  try {
    const derivedPublic = crypto.createPublicKey(config.privateKeyPem).export({ format: "der", type: "spki" });
    const configuredPublic = crypto.createPublicKey(config.publicKeyPem).export({ format: "der", type: "spki" });
    return derivedPublic.length === configuredPublic.length && crypto.timingSafeEqual(derivedPublic, configuredPublic);
  } catch {
    return false;
  }
}

export function playerTokenPublicJwk(config: PlayerTokenKeyConfig): JsonWebKey & Record<string, unknown> {
  if (!config.publicKeyPem) {
    throw new PlayerTokenError("player_token_key_not_configured");
  }
  const jwk = crypto.createPublicKey(config.publicKeyPem).export({ format: "jwk" });
  return { ...jwk, use: "sig", alg: "ES256", kid: config.keyId };
}

export function signPlayerAccessToken(input: {
  playerId: string;
  sessionId: string;
  deviceId: string;
  scopes: string[];
  displayName?: string;
  entapId?: string;
  nowUnix?: number;
  tokenId?: string;
}, config: PlayerTokenKeyConfig): { token: string; claims: PlayerTokenClaims } {
  if (!playerTokenConfigured(config)) {
    throw new PlayerTokenError("player_token_key_not_configured");
  }
  const now = input.nowUnix ?? Math.floor(Date.now() / 1000);
  const claims: PlayerTokenClaims = {
    iss: config.issuer,
    aud: config.audience,
    sub: input.playerId,
    sid: input.sessionId,
    did: input.deviceId,
    scp: [...new Set(input.scopes.map((scope) => scope.trim()).filter(Boolean))].sort(),
    iat: now,
    nbf: now - 2,
    exp: now + Math.max(60, config.accessTokenTtlSec),
    jti: input.tokenId ?? crypto.randomUUID(),
    ver: 1,
    ...(input.displayName ? { name: input.displayName } : {}),
    ...(input.entapId ? { entap_id: input.entapId } : {})
  };
  const encodedHeader = encodeJson({ alg: "ES256", typ: "JWT", kid: config.keyId });
  const encodedPayload = encodeJson(claims);
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signature = crypto.sign("sha256", Buffer.from(signingInput, "ascii"), {
    key: config.privateKeyPem,
    dsaEncoding: "ieee-p1363"
  });
  return { token: `${signingInput}.${signature.toString("base64url")}`, claims };
}

export function verifyPlayerAccessToken(token: string, config: Pick<PlayerTokenKeyConfig,
  "issuer" | "audience" | "keyId" | "publicKeyPem">, options: {
    requiredScope?: string;
    nowUnix?: number;
    clockSkewSec?: number;
  } = {}): PlayerTokenClaims {
  if (!config.publicKeyPem) {
    throw new PlayerTokenError("player_token_key_not_configured");
  }
  const parts = token.split(".");
  if (parts.length !== 3 || parts.some((part) => part.length === 0)) {
    throw new PlayerTokenError("token_malformed");
  }
  const header = decodeJson(parts[0]);
  if (header.alg !== "ES256" || header.typ !== "JWT" || header.kid !== config.keyId) {
    throw new PlayerTokenError("token_header_invalid");
  }
  let signature: Buffer;
  try {
    signature = decodeCanonicalBase64Url(parts[2], "token_signature_invalid");
  } catch {
    throw new PlayerTokenError("token_signature_invalid");
  }
  if (signature.length !== 64 || !crypto.verify("sha256", Buffer.from(`${parts[0]}.${parts[1]}`, "ascii"), {
    key: config.publicKeyPem,
    dsaEncoding: "ieee-p1363"
  }, signature)) {
    throw new PlayerTokenError("token_signature_invalid");
  }
  const payload = decodeJson(parts[1]);
  const scopes = Array.isArray(payload.scp)
    ? payload.scp.filter((scope): scope is string => typeof scope === "string" && scope.trim().length > 0)
    : [];
  const claims: PlayerTokenClaims = {
    iss: stringClaim(payload.iss),
    aud: stringClaim(payload.aud),
    sub: stringClaim(payload.sub),
    sid: stringClaim(payload.sid),
    did: stringClaim(payload.did),
    scp: scopes,
    iat: numberClaim(payload.iat),
    nbf: numberClaim(payload.nbf),
    exp: numberClaim(payload.exp),
    jti: stringClaim(payload.jti),
    ver: payload.ver === 1 ? 1 : (0 as 1),
    ...(stringClaim(payload.name) ? { name: stringClaim(payload.name) } : {}),
    ...(stringClaim(payload.entap_id) ? { entap_id: stringClaim(payload.entap_id) } : {})
  };
  if (claims.iss !== config.issuer || claims.aud !== config.audience) {
    throw new PlayerTokenError("token_issuer_or_audience_invalid");
  }
  if (!isUuidV7(claims.sub) || !isUuidV7(claims.sid) || !isUuidV7(claims.did) || !claims.jti || claims.ver !== 1
    || !Number.isFinite(claims.iat) || !Number.isFinite(claims.nbf) || !Number.isFinite(claims.exp)) {
    throw new PlayerTokenError("token_claims_invalid");
  }
  const now = options.nowUnix ?? Math.floor(Date.now() / 1000);
  const skew = Math.max(0, options.clockSkewSec ?? 5);
  if (claims.nbf > now + skew || claims.iat > now + skew || claims.exp <= now - skew || claims.exp <= claims.iat) {
    throw new PlayerTokenError("token_expired_or_not_active");
  }
  if (options.requiredScope && !claims.scp.includes(options.requiredScope)) {
    throw new PlayerTokenError("token_scope_missing");
  }
  return claims;
}

export function bearerTokenFromHeader(value: string | undefined): string {
  const raw = String(value ?? "").trim();
  return raw.toLowerCase().startsWith("bearer ") ? raw.slice(7).trim() : "";
}
