export function isLoopbackTestUrl(rawUrl: string): boolean {
  try {
    const host = new URL(rawUrl).hostname.toLowerCase();
    return host === "localhost" || host === "::1" || host.startsWith("127.");
  } catch {
    return false;
  }
}

export function assertSafeTestBackend(rawUrl: string, allowLiveValue = process.env.SF_ALLOW_LIVE_BACKEND_TESTS ?? ""): void {
  if (isLoopbackTestUrl(rawUrl) || allowLiveValue.trim() === "1") {
    return;
  }
  throw new Error("unsafe_test_backend");
}
