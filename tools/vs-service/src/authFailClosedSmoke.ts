import http from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

type JsonRecord = Record<string, unknown>;
type ListenableApp = { listen: (port: number, hostname: string, callback: () => void) => http.Server };

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : ` :: ${JSON.stringify(details)}`}`);
}

function listen(app: ListenableApp): Promise<http.Server> {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function close(server: http.Server): Promise<void> {
  return new Promise((resolve, reject) => server.close((err) => err ? reject(err) : resolve()));
}

async function post(base: string, action: string, headers: Record<string, string> = {}): Promise<JsonRecord> {
  const response = await fetch(`${base}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: "{}"
  });
  return { ...await response.json() as JsonRecord, http_status: response.status };
}

async function main(): Promise<void> {
  const tempDir = mkdtempSync(join(tmpdir(), "sf-auth-fail-closed-"));
  process.env.CRUCIBLE_LEDGER_PATH = join(tempDir, "crucible.json");
  process.env.HONEY_LEDGER_PATH = join(tempDir, "honey.json");
  process.env.VS_ADMIN_TOKEN = "";
  process.env.VS_MATCH_AUTHORITY_TOKEN = "";
  process.env.VS_SPECTATOR_ADMIN_TOKEN = "";
  process.env.NODE_ENV = "production";
  process.env.VS_SPECTATOR_DEV_OPEN = "true";
  process.env.VS_ECONOMY_MUTATIONS_ENABLED = "true";
  process.env.VS_ECONOMY_RESET_ENABLED = "false";

  const { createApp } = await import("./server.js");
  const server = await listen(createApp());
  const address = server.address();
  if (address == null || typeof address === "string") throw new Error("missing listen address");
  const base = `http://127.0.0.1:${address.port}/v1`;
  try {
    const authorityHeaderCases: Array<Record<string, string>> = [{}, { "x-match-authority-token": "forged" }];
    for (const headers of authorityHeaderCases) {
      const result = await post(base, "settle_money_match", headers);
      expect(result.http_status === 503 && result.err === "match_authority_not_configured",
        "empty configured match-authority token did not fail closed", result);
    }
    const adminHeaderCases: Array<Record<string, string>> = [{}, { "x-admin-token": "forged", "x-admin-role": "ops_admin" }];
    for (const headers of adminHeaderCases) {
      const mutation = await post(base, "preview_async_contest_payout_report", headers);
      const privateRead = await post(base, "get_money_transactions", headers);
      const debugFill = await post(base, "debug_fill_session", headers);
      expect(mutation.http_status === 503 && mutation.err === "admin_auth_not_configured",
        "empty configured admin token authorized mutation", mutation);
      expect(privateRead.http_status === 503 && privateRead.err === "admin_auth_not_configured",
        "empty configured admin token authorized private read", privateRead);
      expect(debugFill.http_status === 503 && debugFill.err === "admin_auth_not_configured",
        "empty configured admin token authorized debug route", debugFill);
    }
    const spectator = await post(base, "create_spectator_grant", { Authorization: "Bearer forged" });
    expect(spectator.http_status === 403 && spectator.err === "spectator_unauthorized",
      "empty configured spectator token or production dev bypass authorized grant creation", spectator);
  } finally {
    await close(server);
    rmSync(tempDir, { recursive: true, force: true });
  }
  console.log(JSON.stringify({ ok: true, smoke: "auth_fail_closed" }));
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
