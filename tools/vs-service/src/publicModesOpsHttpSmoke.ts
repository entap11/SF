function expect(value: unknown, message: string, details?: unknown): void {
  if (!value) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

async function main(): Promise<void> {
  process.env.VS_ADMIN_TOKEN = "ops-http-smoke-admin";
  process.env.VS_ADMIN_ROLE = "ops_admin";
  process.env.VS_DURABLE_STORE = "memory";
  process.env.VS_ENABLE_REMOTE_OPS_CONFIG = "true";
  const { startServer } = await import("./server.js");
  const server = startServer(0, "127.0.0.1");
  await new Promise<void>((resolve) => server.once("listening", resolve));
  const address = server.address();
  if (!address || typeof address === "string") throw new Error("server address unavailable");
  const base = `http://127.0.0.1:${address.port}/v1`;
  try {
    const publicResponse = await fetch(`${base}/public_ops_config`);
    const publicConfig = await publicResponse.json() as Record<string, unknown>;
    const flags = publicConfig.feature_flags as Record<string, unknown>;
    expect(publicResponse.status === 200 && publicConfig.rollout_source === "REMOTE_CONFIG_UNAVAILABLE"
      && Object.values(flags).every((value) => value === false),
    "public config did not fail closed when authoritative store was unavailable", publicConfig);

    const unauth = await post(base, "publish_public_ops_config", {});
    expect(unauth.http_status === 401 && unauth.err === "admin_auth_required",
      "unauthenticated publication was not rejected", unauth);
    const wrongRole = await post(base, "publish_public_ops_config", {}, {
      "x-admin-token": "ops-http-smoke-admin", "x-admin-role": "viewer"
    });
    expect(wrongRole.http_status === 401 && wrongRole.err === "admin_auth_required",
      "non-ops role published config", wrongRole);
    const noStore = await post(base, "publish_public_ops_config", {}, {
      "x-admin-token": "ops-http-smoke-admin", "x-admin-role": "ops_admin"
    });
    expect(noStore.http_status === 503 && noStore.err === "public_modes_ops_store_not_configured",
      "authenticated publication did not fail closed without durable store", noStore);
    console.log("PUBLIC_MODES_OPS_HTTP_SMOKE: PASS");
  } finally { await new Promise<void>((resolve) => server.close(() => resolve())); }
}

async function post(base: string, action: string, body: Record<string, unknown>, headers: Record<string, string> = {}): Promise<Record<string, unknown>> {
  const response = await fetch(`${base}/${action}`, { method: "POST",
    headers: { "Content-Type": "application/json", ...headers }, body: JSON.stringify(body) });
  return { http_status: response.status, ...await response.json() as Record<string, unknown> };
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
