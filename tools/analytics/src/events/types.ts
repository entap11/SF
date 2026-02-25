export const PHASE0_EVENT_NAMES = [
  "session_start",
  "session_end",
  "match_end_summary",
  "purchase",
  "error",
  "crash"
] as const;

export type Phase0EventName = (typeof PHASE0_EVENT_NAMES)[number];

export interface EventEnvelope {
  event_id: string;
  event_name: Phase0EventName;
  event_time_utc_ms: number;
  install_id: string;
  session_id: string;
  app_version: string;
  platform: string;
  device_model?: string;
  os_version?: string;
  country?: string;
  props: Record<string, unknown>;
}

export type IngestStatus = "accepted" | "duplicate" | "invalid";

export interface IngestResult {
  event_id: string | null;
  status: IngestStatus;
  error?: string;
}
