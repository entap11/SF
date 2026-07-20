import crypto from "node:crypto";

type JsonRecord = Record<string, unknown>;

export class ServiceTrustError extends Error {
  constructor(readonly code: string, readonly status = 401) { super(code); }
}

export function verifyServiceJwt(raw: string, config: {
  issuer: string; audience: string; subject: string; keyId: string; publicKeyPem: string;
}, requiredScope: string, nowSec = Math.floor(Date.now() / 1000)): JsonRecord {
  if (!config.publicKeyPem || !config.issuer || !config.audience || !config.subject || !config.keyId) {
    throw new ServiceTrustError("service_auth_not_configured", 503);
  }
  const parts = raw.trim().split(".");
  if (parts.length !== 3) throw new ServiceTrustError("service_token_invalid");
  let header: JsonRecord;
  let claims: JsonRecord;
  try {
    header = JSON.parse(Buffer.from(parts[0]!, "base64url").toString("utf8")) as JsonRecord;
    claims = JSON.parse(Buffer.from(parts[1]!, "base64url").toString("utf8")) as JsonRecord;
  } catch { throw new ServiceTrustError("service_token_invalid"); }
  if (header.alg !== "ES256" || header.typ !== "JWT" || header.kid !== config.keyId) {
    throw new ServiceTrustError("service_token_invalid");
  }
  const signature = Buffer.from(parts[2]!, "base64url");
  if (signature.length !== 64 || !crypto.verify("sha256", Buffer.from(`${parts[0]}.${parts[1]}`, "ascii"), {
    key: config.publicKeyPem, dsaEncoding: "ieee-p1363"
  }, signature)) throw new ServiceTrustError("service_token_invalid");
  const exp = Number(claims.exp);
  const nbf = Number(claims.nbf ?? claims.iat);
  const iat = Number(claims.iat);
  if (claims.iss !== config.issuer || claims.aud !== config.audience || claims.sub !== config.subject
    || !Number.isSafeInteger(iat) || !Number.isSafeInteger(exp) || !Number.isSafeInteger(nbf)
    || nbf > nowSec + 5 || exp <= nowSec || iat > nowSec + 5 || exp - iat > 180) {
    throw new ServiceTrustError("service_token_invalid");
  }
  const scopes = Array.isArray(claims.scp) ? claims.scp.map(String) : String(claims.scope ?? "").split(/\s+/).filter(Boolean);
  if (!scopes.includes(requiredScope)) throw new ServiceTrustError("service_scope_missing", 403);
  if (!String(claims.jti ?? "")) throw new ServiceTrustError("service_token_invalid");
  return claims;
}

export function bearerToken(value: string | undefined): string {
  const raw = String(value ?? "");
  return raw.startsWith("Bearer ") ? raw.slice(7).trim() : "";
}
