import crypto from "node:crypto";
import {
  PlayerTokenError,
  playerTokenPublicJwk,
  signPlayerAccessToken,
  verifyPlayerAccessToken,
  type PlayerTokenKeyConfig
} from "./playerToken.js";

function expect(condition: unknown, message: string): void {
  if (!condition) throw new Error(message);
}

function expectCode(fn: () => unknown, code: string): void {
  try {
    fn();
  } catch (error) {
    expect(error instanceof PlayerTokenError && error.code === code,
      `expected ${code}, got ${error instanceof Error ? error.message : String(error)}`);
    return;
  }
  throw new Error(`expected ${code}`);
}

const keyPair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const config: PlayerTokenKeyConfig = {
  issuer: "entap-smoke",
  audience: "swarmfront-vs-smoke",
  keyId: "smoke-key-1",
  privateKeyPem: keyPair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
  publicKeyPem: keyPair.publicKey.export({ format: "pem", type: "spki" }).toString(),
  accessTokenTtlSec: 600
};
const signed = signPlayerAccessToken({
  playerId: "0190f47a-1234-7abc-8def-123456789abc",
  sessionId: "0190f47a-2234-7abc-8def-123456789abc",
  deviceId: "0190f47a-3234-7abc-8def-123456789abc",
  scopes: ["match:queue"],
  displayName: "TokenSmoke",
  entapId: "AAA 001",
  nowUnix: 1_700_000_000,
  tokenId: "token-smoke-1"
}, config);
const verified = verifyPlayerAccessToken(signed.token, config, {
  requiredScope: "match:queue",
  nowUnix: 1_700_000_100
});
expect(verified.sub === signed.claims.sub, "subject mismatch");
expect(verified.name === "TokenSmoke", "display snapshot missing");
expect(playerTokenPublicJwk(config).d == null, "JWKS leaked private key material");
expectCode(() => verifyPlayerAccessToken(signed.token, { ...config, audience: "wrong" }, {
  nowUnix: 1_700_000_100
}), "token_issuer_or_audience_invalid");
expectCode(() => verifyPlayerAccessToken(signed.token, config, {
  requiredScope: "admin",
  nowUnix: 1_700_000_100
}), "token_scope_missing");
expectCode(() => verifyPlayerAccessToken(signed.token, config, {
  nowUnix: 1_700_001_000
}), "token_expired_or_not_active");
const tampered = `${signed.token.slice(0, -1)}${signed.token.endsWith("A") ? "B" : "A"}`;
expectCode(() => verifyPlayerAccessToken(tampered, config, {
  nowUnix: 1_700_000_100
}), "token_signature_invalid");

console.log(JSON.stringify({ ok: true, smoke: "player_token", alg: "ES256", scope: "match:queue" }));
