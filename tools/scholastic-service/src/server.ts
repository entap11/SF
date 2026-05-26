import express, { type NextFunction, type Request, type Response } from "express";
import {
  createTournament,
  fileEnrollmentComplaint,
  joinCollegeProgram,
  metricsSummary,
  joinSchool,
  recordActivity,
  recordTournamentResult,
  registerCollegeProgram,
  registerHighSchool,
  reportAge,
  resolveAdPolicy,
  reviewSchoolHive
} from "./actions.js";
import { config } from "./config.js";
import { pool } from "./db/pool.js";
import { normalizeId } from "./logic.js";
import { PgScholasticStore } from "./store.js";

const app = express();
const store = new PgScholasticStore(pool);

app.use(express.json({ limit: "1mb" }));

function requireToken(req: Request, res: Response, next: NextFunction): void {
  if (!config.apiToken) {
    next();
    return;
  }
  const token = String(req.header("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (token !== config.apiToken) {
    res.status(401).json({ ok: false, err: "unauthorized" });
    return;
  }
  next();
}

function requireAdmin(req: Request, res: Response, next: NextFunction): void {
  const expected = config.adminToken || config.apiToken;
  if (!expected) {
    next();
    return;
  }
  const token = String(req.header("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (token !== expected) {
    res.status(401).json({ ok: false, err: "admin_unauthorized" });
    return;
  }
  next();
}

function body(req: Request): Record<string, unknown> {
  return typeof req.body === "object" && req.body !== null && !Array.isArray(req.body) ? req.body as Record<string, unknown> : {};
}

function writeAction(handler: Parameters<typeof store.write>[0]) {
  return async (_req: Request, res: Response, next: NextFunction) => {
    try {
      res.json(await store.write(handler));
    } catch (error) {
      next(error);
    }
  };
}

app.get("/health", async (_req, res) => {
  res.json({ ok: await store.healthCheck(), service: "swarmfront-scholastic" });
});
app.get("/v1/health", async (_req, res) => {
  res.json({ ok: await store.healthCheck(), service: "swarmfront-scholastic" });
});

app.post("/v1/report_age", requireToken, (req, res, next) => writeAction((state, context) => reportAge(state, context, body(req)))(req, res, next));
app.post("/v1/register_high_school", requireToken, (req, res, next) => writeAction((state, context) => registerHighSchool(state, context, body(req)))(req, res, next));
app.post("/v1/join_school", requireToken, (req, res, next) => writeAction((state, context) => joinSchool(state, context, body(req)))(req, res, next));
app.post("/v1/file_enrollment_complaint", requireToken, (req, res, next) => writeAction((state, context) => fileEnrollmentComplaint(state, context, body(req)))(req, res, next));
app.post("/v1/register_college_program", requireToken, (req, res, next) => writeAction((state, context) => registerCollegeProgram(state, context, body(req)))(req, res, next));
app.post("/v1/join_college_program", requireToken, (req, res, next) => writeAction((state, context) => joinCollegeProgram(state, context, body(req)))(req, res, next));
app.post("/v1/create_sfa_tournament", requireAdmin, (req, res, next) => writeAction((state, context) => createTournament(state, context, body(req), "SFA"))(req, res, next));
app.post("/v1/create_sfu_tournament", requireAdmin, (req, res, next) => writeAction((state, context) => createTournament(state, context, body(req), "SFU"))(req, res, next));
app.post("/v1/review_school_hive", requireAdmin, (req, res, next) => writeAction((state, context) => reviewSchoolHive(state, context, body(req)))(req, res, next));
app.post("/v1/record_sfa_tournament_result", requireToken, (req, res, next) => writeAction((state, context) => recordTournamentResult(state, context, body(req), "SFA"))(req, res, next));
app.post("/v1/record_sfu_tournament_result", requireToken, (req, res, next) => writeAction((state, context) => recordTournamentResult(state, context, body(req), "SFU"))(req, res, next));
app.post("/v1/record_activity", requireToken, (req, res, next) => writeAction((state, context) => recordActivity(state, context, body(req)))(req, res, next));

app.get("/v1/profile/:playerId", requireToken, async (req, res, next) => {
  try {
    const playerId = normalizeId(req.params.playerId);
    res.json(await store.read((state) => ({ ok: true, profile: state.profiles[playerId] ?? null })));
  } catch (error) {
    next(error);
  }
});

app.get("/v1/school/:schoolId", requireToken, async (req, res, next) => {
  try {
    const schoolId = normalizeId(req.params.schoolId);
    res.json(await store.read((state) => ({ ok: true, school: state.schools[schoolId] ?? null })));
  } catch (error) {
    next(error);
  }
});

app.get("/v1/ad_policy/:playerId", requireToken, async (req, res, next) => {
  try {
    res.json(await store.read((state) => resolveAdPolicy(state, req.params.playerId)));
  } catch (error) {
    next(error);
  }
});

app.get("/v1/admin/summary", requireAdmin, async (_req, res, next) => {
  try {
    res.json(await store.read((state) => metricsSummary(state)));
  } catch (error) {
    next(error);
  }
});

app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
  console.error(error);
  res.status(500).json({ ok: false, err: "internal_error" });
});

await store.init();
app.listen(config.port, config.bindHost, () => {
  console.log(`scholastic service running on ${config.bindHost}:${config.port}`);
});
