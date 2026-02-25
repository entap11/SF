import express, { type NextFunction, type Request, type Response } from "express";
import type { PoolClient } from "pg";
import { config } from "./config.js";
import { pool } from "./db/pool.js";
import { runMigrations } from "./db/migrate.js";
import { parseEventEnvelope } from "./events/validation.js";
import { ingestValidatedEvents } from "./events/ingest.js";
import type { EventEnvelope, IngestResult } from "./events/types.js";
import { requireAdminAuth } from "./auth/basic_auth.js";
import { bootstrapAdminUserIfConfigured } from "./auth/bootstrap.js";
import { createDashboardRouter } from "./dashboard/routes.js";
import { computeRollupsForDate, computeRollupsForRange } from "./rollups/compute.js";
import { startRollupScheduler } from "./rollups/scheduler.js";
import { parseDateStrict } from "./util/date.js";

interface IndexedResult {
  index: number;
  result: IngestResult;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function enrichCountry(raw: unknown, req: Request): unknown {
  const inferredCountry = req.header("cf-ipcountry") ?? req.header("x-country") ?? undefined;
  if (!inferredCountry || !isRecord(raw)) {
    return raw;
  }
  if (typeof raw.country === "string" && raw.country.trim() !== "") {
    return raw;
  }
  return {
    ...raw,
    country: inferredCountry
  };
}

function getEventsFromBody(body: unknown): unknown[] {
  if (Array.isArray(body)) {
    return body;
  }
  if (isRecord(body) && Array.isArray(body.events)) {
    return body.events;
  }
  return [];
}

async function handleBatch(req: Request, res: Response): Promise<void> {
  const rawEvents = getEventsFromBody(req.body);
  if (!Array.isArray(rawEvents) || rawEvents.length === 0) {
    res.status(400).json({ error: "events array required" });
    return;
  }
  if (rawEvents.length > config.ingestBatchMax) {
    res.status(400).json({
      error: "batch_too_large",
      message: `max batch size is ${config.ingestBatchMax}`
    });
    return;
  }

  const validEvents: Array<{ index: number; event: EventEnvelope }> = [];
  const indexedResults: IndexedResult[] = [];

  for (let i = 0; i < rawEvents.length; i += 1) {
    const normalized = enrichCountry(rawEvents[i], req);
    const parsed = parseEventEnvelope(normalized);
    if (!parsed.ok) {
      const maybeEventId = isRecord(rawEvents[i]) && typeof rawEvents[i].event_id === "string" ? rawEvents[i].event_id : null;
      indexedResults.push({
        index: i,
        result: {
          event_id: maybeEventId,
          status: "invalid",
          error: parsed.error
        }
      });
      continue;
    }
    validEvents.push({ index: i, event: parsed.event });
  }

  if (validEvents.length > 0) {
    let client: PoolClient | null = null;
    try {
      client = await pool.connect();
      const summary = await ingestValidatedEvents(
        client,
        validEvents.map((entry) => entry.event)
      );
      summary.results.forEach((result, idx) => {
        indexedResults.push({ index: validEvents[idx].index, result });
      });
    } finally {
      client?.release();
    }
  }

  indexedResults.sort((a, b) => a.index - b.index);
  const results = indexedResults.map((entry) => entry.result);
  const acceptedCount = results.filter((r) => r.status === "accepted").length;
  const duplicateCount = results.filter((r) => r.status === "duplicate").length;
  const invalidCount = results.filter((r) => r.status === "invalid").length;

  res.json({
    accepted_count: acceptedCount,
    duplicate_count: duplicateCount,
    invalid_count: invalidCount,
    results
  });
}

function asyncHandler(fn: (req: Request, res: Response, next: NextFunction) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction) => {
    void fn(req, res, next).catch(next);
  };
}

const app = express();
app.use(express.json({ limit: "2mb" }));

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "swarmfront-analytics" });
});

app.get("/", (_req, res) => {
  res.json({ ok: true, service: "swarmfront-analytics", dashboard: "/dashboard" });
});

app.post(
  "/v1/events/batch",
  asyncHandler(async (req, res) => {
    await handleBatch(req, res);
  })
);

app.post(
  "/v1/events/single",
  asyncHandler(async (req, res) => {
    if (!isRecord(req.body)) {
      res.status(400).json({ error: "event object required" });
      return;
    }
    req.body = { events: [req.body] };
    await handleBatch(req, res);
  })
);

app.use("/dashboard", requireAdminAuth, createDashboardRouter(pool));

app.post(
  "/admin/rollups/recompute",
  requireAdminAuth,
  asyncHandler(async (req, res) => {
    const date = typeof req.body?.date === "string" ? req.body.date : typeof req.query.date === "string" ? req.query.date : null;
    const start =
      typeof req.body?.start === "string" ? req.body.start : typeof req.query.start === "string" ? req.query.start : null;
    const end = typeof req.body?.end === "string" ? req.body.end : typeof req.query.end === "string" ? req.query.end : null;

    if (date) {
      parseDateStrict(date);
      await computeRollupsForDate(pool, date);
      res.json({ ok: true, mode: "date", date });
      return;
    }

    if (start && end) {
      parseDateStrict(start);
      parseDateStrict(end);
      if (start > end) {
        res.status(400).json({ error: "start must be <= end" });
        return;
      }
      await computeRollupsForRange(pool, start, end);
      res.json({ ok: true, mode: "range", start, end });
      return;
    }

    res.status(400).json({ error: "provide date or start+end" });
  })
);

app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
  // eslint-disable-next-line no-console
  console.error(error);
  res.status(500).json({ error: "internal_server_error" });
});

async function start(): Promise<void> {
  await runMigrations(pool);
  await bootstrapAdminUserIfConfigured();
  startRollupScheduler();

  app.listen(config.port, config.bindHost, () => {
    // eslint-disable-next-line no-console
    console.log(`analytics server running on ${config.bindHost}:${config.port}`);
  });
}

void start();
