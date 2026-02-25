import type { PoolClient } from "pg";
import type { EventEnvelope, IngestResult } from "./types.js";

export interface BatchIngestSummary {
  accepted_count: number;
  duplicate_count: number;
  invalid_count: number;
  results: IngestResult[];
}

function toUtcDate(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

async function insertEvent(client: PoolClient, event: EventEnvelope): Promise<"accepted" | "duplicate"> {
  const result = await client.query<{ event_id: string }>(
    `
      INSERT INTO events_raw (
        event_id,
        event_name,
        event_time_utc_ms,
        install_id,
        session_id,
        app_version,
        platform,
        device_model,
        os_version,
        country,
        props
      ) VALUES (
        $1::uuid,
        $2::text,
        $3::bigint,
        $4::uuid,
        $5::uuid,
        $6::text,
        $7::text,
        $8::text,
        $9::text,
        $10::text,
        $11::jsonb
      )
      ON CONFLICT (event_id) DO NOTHING
      RETURNING event_id
    `,
    [
      event.event_id,
      event.event_name,
      event.event_time_utc_ms,
      event.install_id,
      event.session_id,
      event.app_version,
      event.platform,
      event.device_model ?? null,
      event.os_version ?? null,
      event.country ?? null,
      event.props
    ]
  );

  if (result.rowCount === 0) {
    return "duplicate";
  }

  await client.query(
    `
      INSERT INTO installs (
        install_id,
        first_seen_date,
        first_seen_time_utc_ms,
        first_app_version,
        first_platform,
        first_country
      ) VALUES (
        $1::uuid,
        $2::date,
        $3::bigint,
        $4::text,
        $5::text,
        $6::text
      )
      ON CONFLICT (install_id) DO NOTHING
    `,
    [
      event.install_id,
      toUtcDate(event.event_time_utc_ms),
      event.event_time_utc_ms,
      event.app_version,
      event.platform,
      event.country ?? null
    ]
  );

  return "accepted";
}

export async function ingestValidatedEvents(client: PoolClient, events: EventEnvelope[]): Promise<BatchIngestSummary> {
  const results: IngestResult[] = [];
  let acceptedCount = 0;
  let duplicateCount = 0;

  for (const event of events) {
    try {
      const status = await insertEvent(client, event);
      if (status === "accepted") {
        acceptedCount += 1;
      } else {
        duplicateCount += 1;
      }
      results.push({ event_id: event.event_id, status });
    } catch (error) {
      const message = error instanceof Error ? error.message : "db_error";
      results.push({ event_id: event.event_id, status: "invalid", error: `db_error: ${message}` });
    }
  }

  return {
    accepted_count: acceptedCount,
    duplicate_count: duplicateCount,
    invalid_count: results.length - acceptedCount - duplicateCount,
    results
  };
}
