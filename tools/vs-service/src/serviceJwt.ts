import crypto from "node:crypto";
import { uuidV7 } from "./repositories/durableCore.js";

export function signServiceJwt(config: {
  issuer: string; audience: string; subject: string; keyId: string; privateKeyPem: string;
}, scope: string, nowSec = Math.floor(Date.now() / 1000)): string {
  if (!config.issuer || !config.audience || !config.subject || !config.keyId || !config.privateKeyPem) {
    throw new Error("rank_service_identity_not_configured");
  }
  const encodedHeader = encode({ alg: "ES256", typ: "JWT", kid: config.keyId });
  const encodedClaims = encode({
    iss: config.issuer, aud: config.audience, sub: config.subject, scp: [scope],
    iat: nowSec, nbf: nowSec - 1, exp: nowSec + 60, jti: uuidV7()
  });
  const input = `${encodedHeader}.${encodedClaims}`;
  const signature = crypto.sign("sha256", Buffer.from(input, "ascii"), {
    key: config.privateKeyPem, dsaEncoding: "ieee-p1363"
  });
  return `${input}.${signature.toString("base64url")}`;
}

function encode(value: unknown): string {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64url");
}
