export async function fetchDependency(
  dependency: string,
  input: string,
  init: RequestInit,
  timeoutMs: number
): Promise<Response> {
  const startedMs = Date.now();
  const deadlineMs = Math.max(100, Math.trunc(timeoutMs));
  try {
    const response = await fetch(input, {
      ...init,
      signal: init.signal ?? AbortSignal.timeout(deadlineMs)
    });
    console.log(JSON.stringify({
      ts: new Date().toISOString(),
      event: "dependency_call",
      dependency,
      outcome: response.ok ? "ok" : "http_error",
      status: response.status,
      ms: Date.now() - startedMs
    }));
    return response;
  } catch (error) {
    console.warn(JSON.stringify({
      ts: new Date().toISOString(),
      event: "dependency_call",
      dependency,
      outcome: "transport_error",
      error: error instanceof Error ? error.name : "unknown_error",
      ms: Date.now() - startedMs
    }));
    throw error;
  }
}
