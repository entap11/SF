import type { RequestHandler } from "express";
import { bearerPlayerToken } from "./playerAuth.js";

// JWT expiry alone cannot enforce account deletion. Do not cache successful checks.
// The identity issuer is the only authority for revocation/account lifecycle.
export function playerSessionStatusMiddleware(url: string, required: boolean): RequestHandler {
  if (url) {
    const parsed = new URL(url);
    if (parsed.protocol !== "https:" && !["localhost", "127.0.0.1", "[::1]"].includes(parsed.hostname)) {
      throw new Error("player_session_status_requires_https");
    }
  }
  return (req, res, next): void => {
    const token = bearerPlayerToken(req.header("authorization"));
    if (!token || token.split(".").length !== 3) { next(); return; }
    // Service JWTs are validated by their dedicated routes. Only player tokens carry sid/did.
    let payload: Record<string, unknown>;
    try { payload = JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString("utf8")); }
    catch { next(); return; }
    if (!payload || !payload.sid || !payload.did) { next(); return; }
    if (!url) {
      if (required) res.status(503).json({ ok: false, err: "player_session_status_not_configured" });
      else next();
      return;
    }
    void fetch(url, {
      method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: "{}", signal: AbortSignal.timeout(5000), redirect: "error"
    }).then(async response => {
      const result = await response.json() as { ok?: boolean; active?: boolean };
      if (response.ok && result.ok === true && result.active === true) { next(); return; }
      res.status(response.status === 401 || response.status === 403 ? 403 : 503)
        .json({ ok: false, err: response.status === 401 || response.status === 403
          ? "account_or_session_inactive" : "player_session_status_unavailable" });
    }).catch(() => res.status(503).json({ ok: false, err: "player_session_status_unavailable" }));
  };
}
