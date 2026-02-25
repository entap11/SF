import { z } from "zod";
import { PHASE0_EVENT_NAMES, type EventEnvelope } from "./types.js";

const idObject = z.record(z.string(), z.coerce.number().int().nonnegative());
const floatPctObject = z.record(z.string(), z.coerce.number().min(0).max(1));
const buffCountObject = z.record(z.string(), z.coerce.number().int().nonnegative());

const sessionStartPropsSchema = z
  .object({
    launch_reason: z.enum(["cold", "warm", "resume"]).optional(),
    timezone_offset_min: z.coerce.number().int().optional()
  })
  .passthrough();

const sessionEndPropsSchema = z
  .object({
    duration_ms: z.coerce.number().int().nonnegative(),
    matches_played: z.coerce.number().int().nonnegative().optional(),
    purchases_made: z.coerce.number().int().nonnegative().optional()
  })
  .passthrough();

const matchEndSummaryPropsSchema = z
  .object({
    match_id: z.string().min(1),
    season_id: z.string().min(1),
    map_id: z.string().min(1),
    match_type: z.enum(["VS", "ASYNC", "BOT"]),
    duration_ms: z.coerce.number().int().nonnegative(),
    winner: z.string().min(1),
    hive_damage_dealt: idObject.optional(),
    hive_damage_taken: idObject.optional(),
    production_idle_pct: floatPctObject.optional(),
    buffs_used: buffCountObject.optional(),
    lane_buffs_used: buffCountObject.optional(),
    swing_moment_ms: z.coerce.number().int().nonnegative().optional()
  })
  .passthrough();

const purchasePropsSchema = z
  .object({
    purchase_id: z.string().min(1),
    product_id: z.string().min(1),
    price_cents: z.coerce.number().int().nonnegative(),
    currency: z.string().length(3),
    quantity: z.coerce.number().int().positive().optional(),
    context: z.string().optional()
  })
  .passthrough();

const errorPropsSchema = z
  .object({
    error_code: z.string().min(1),
    message: z.string().optional(),
    stack: z.string().optional(),
    context: z.record(z.unknown()).optional()
  })
  .passthrough();

const crashPropsSchema = z
  .object({
    crash_id: z.string().min(1),
    signal: z.string().optional(),
    message: z.string().optional(),
    context: z.record(z.unknown()).optional()
  })
  .passthrough();

const baseEventSchema = z
  .object({
    event_id: z.string().uuid(),
    event_name: z.enum(PHASE0_EVENT_NAMES),
    event_time_utc_ms: z.coerce.number().int().nonnegative(),
    install_id: z.string().uuid(),
    session_id: z.string().uuid(),
    app_version: z.string().min(1),
    platform: z.string().min(1),
    device_model: z.string().optional(),
    os_version: z.string().optional(),
    country: z.string().optional(),
    props: z.record(z.unknown())
  })
  .superRefine((value, ctx) => {
    const parsed = parseProps(value.event_name, value.props);
    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["props", ...(issue.path ?? [])],
          message: issue.message
        });
      }
    }
  });

function parseProps(eventName: EventEnvelope["event_name"], props: Record<string, unknown>) {
  switch (eventName) {
    case "session_start":
      return sessionStartPropsSchema.safeParse(props);
    case "session_end":
      return sessionEndPropsSchema.safeParse(props);
    case "match_end_summary":
      return matchEndSummaryPropsSchema.safeParse(props);
    case "purchase":
      return purchasePropsSchema.safeParse(props);
    case "error":
      return errorPropsSchema.safeParse(props);
    case "crash":
      return crashPropsSchema.safeParse(props);
    default:
      return z.never().safeParse(eventName);
  }
}

export function parseEventEnvelope(raw: unknown): { ok: true; event: EventEnvelope } | { ok: false; error: string } {
  const parsed = baseEventSchema.safeParse(raw);
  if (!parsed.success) {
    const first = parsed.error.issues[0];
    const path = first?.path?.join(".") ?? "event";
    return { ok: false, error: `${path}: ${first?.message ?? "invalid payload"}` };
  }
  return { ok: true, event: parsed.data as EventEnvelope };
}
