import "dotenv/config";
import { readFile } from "node:fs/promises";

// Dedicated API credential; no direct database access or implicit completion.
async function main(): Promise<void> {
  const [command = "list", requestId = "", evidencePath = ""] = process.argv.slice(2);
  const base = (process.env.ENTAP_DELETION_API_URL || "").replace(/\/$/, "");
  const token = process.env.ENTAP_DELETION_OPERATOR_TOKEN || "";
  const url = new URL(base);
  if (url.protocol !== "https:" && !["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)) {
    throw new Error("deletion_api_requires_https");
  }
  if (token.length < 32) throw new Error("ENTAP_DELETION_OPERATOR_TOKEN must contain at least 32 characters");
  if (!["list", "fulfill", "complete", "verified-request"].includes(command)
    || (["fulfill", "complete"].includes(command) && !/^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/.test(requestId))) {
    throw new Error("Usage: account-deletions [list | fulfill REQUEST_ID EVIDENCE_JSON | complete REQUEST_ID | verified-request PRIVATE_JSON]");
  }
  const payload = command === "verified-request" ? JSON.parse(await readFile(requestId, "utf8"))
    : command === "fulfill" ? JSON.parse(await readFile(evidencePath, "utf8")) : {};
  const suffix = command === "verified-request" ? "/verified-request"
    : command === "list" ? "" : `/${encodeURIComponent(requestId)}/${command === "fulfill" ? "fulfillment" : "complete"}`;
  const response = await fetch(`${base}/v1/admin/account-deletions${suffix}`, {
    method: command === "list" ? "GET" : "POST", redirect: "error", signal: AbortSignal.timeout(30000),
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    ...(command === "list" ? {} : { body: JSON.stringify(payload) })
  });
  const result: unknown = await response.json();
  if (!response.ok) throw new Error(`Deletion operation failed (${response.status}): ${JSON.stringify(result)}`);
  console.log(JSON.stringify(result, null, 2));
}
void main().catch(error => { console.error(error instanceof Error ? error.message : "Deletion operation failed"); process.exitCode = 1; });
