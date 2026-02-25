import { Router, type Request, type Response } from "express";
import type { Pool } from "pg";
import { card, fmtInt, fmtMoneyCents, fmtPct, fmtPctRaw, layout, table } from "./html.js";
import { loadGameplay, loadOverview, loadRetention, loadStability, resolveDateRange } from "./data.js";

function rangeFromReq(req: Request) {
  return resolveDateRange(req.query.start, req.query.end);
}

export function createDashboardRouter(pool: Pool): Router {
  const router = Router();

  router.get("/", async (req: Request, res: Response) => {
    const range = rangeFromReq(req);
    const data = await loadOverview(pool, range);
    const cards = [
      card("New Installs", fmtInt(data?.new_installs)),
      card("Avg DAU", fmtInt(data?.avg_dau)),
      card("Peak DAU", fmtInt(data?.peak_dau)),
      card("Latest WAU", fmtInt(data?.latest_wau)),
      card("Latest MAU", fmtInt(data?.latest_mau)),
      card("Sessions", fmtInt(data?.sessions)),
      card("Avg Session Length", `${Number(data?.avg_session_length_s ?? 0).toFixed(1)}s`),
      card("Sessions / DAU", Number(data?.sessions_per_dau ?? 0).toFixed(2)),
      card("Matches", fmtInt(data?.matches_completed)),
      card(
        "Matches / Session",
        (
          Number(data?.sessions ?? 0) > 0
            ? Number(data?.matches_completed ?? 0) / Number(data?.sessions ?? 1)
            : 0
        ).toFixed(2)
      ),
      card("Avg Match Length", `${Number(data?.avg_match_length_s ?? 0).toFixed(1)}s`),
      card("Purchases", fmtInt(data?.purchase_count)),
      card("Gross Revenue", fmtMoneyCents(data?.gross_revenue_cents)),
      card("ARPDAU", fmtMoneyCents(data?.arpdau_cents)),
      card("ARPPU", fmtMoneyCents(data?.arppu_cents)),
      card("Conversion", fmtPct(data?.conversion_rate)),
      card("Crash-free Sessions", fmtPctRaw(data?.crash_free_sessions_pct))
    ].join("");

    const modeRows = [
      ["VS", fmtInt(data?.vs_matches)],
      ["ASYNC", fmtInt(data?.async_matches)],
      ["BOT", fmtInt(data?.bot_matches)]
    ];

    const body = `
      <div class=\"cards\">${cards}</div>
      <section>
        <h2>Mode Split</h2>
        ${table(["Mode", "Matches"], modeRows)}
      </section>
      <p class=\"muted\">Range: ${range.start} to ${range.end}</p>
    `;

    res.type("html").send(layout("Overview", "/dashboard", range, body));
  });

  router.get("/retention", async (req: Request, res: Response) => {
    const range = rangeFromReq(req);
    const data = await loadRetention(pool, range);
    const summaryCards = data.summary
      .map((row) => card(`D${row.day_n} Avg`, fmtPct(row.avg_retention_rate)))
      .join("");

    const detailRows = data.detail.map((row) => [
      String(row.calculated_for_date).slice(0, 10),
      String(row.cohort_date).slice(0, 10),
      `D${row.day_n}`,
      fmtInt(row.cohort_size),
      fmtInt(row.retained_users),
      fmtPct(row.retention_rate)
    ]);

    const body = `
      <div class=\"cards\">${summaryCards || card("No Data", "-")}</div>
      <section>
        <h2>Retention Detail</h2>
        ${table(["Calculated Date", "Cohort Date", "Window", "Cohort", "Retained", "Rate"], detailRows)}
      </section>
    `;

    res.type("html").send(layout("Retention", "/dashboard/retention", range, body));
  });

  router.get("/gameplay", async (req: Request, res: Response) => {
    const range = rangeFromReq(req);
    const data = await loadGameplay(pool, range);

    const totalMatches = Number(data.modeSplit?.matches_completed ?? 0);
    const cards = [
      card("Total Matches", fmtInt(totalMatches)),
      card("VS", fmtInt(data.modeSplit?.vs_matches ?? 0)),
      card("ASYNC", fmtInt(data.modeSplit?.async_matches ?? 0)),
      card("BOT", fmtInt(data.modeSplit?.bot_matches ?? 0))
    ].join("");

    const buffRows = data.buffs.map((row) => [
      String(row.buff_id),
      fmtInt(row.uses_count),
      fmtInt(row.unique_users_count),
      totalMatches > 0 ? `${((Number(row.uses_count ?? 0) / totalMatches) * 100).toFixed(2)}%` : "0.00%"
    ]);

    const winnerRows = data.winners.map((row) => [
      String(row.winner),
      fmtInt(row.matches)
    ]);

    const body = `
      <div class=\"cards\">${cards}</div>
      <section>
        <h2>Top Buff Usage</h2>
        ${table(["Buff", "Uses", "Unique Users", "Uses / Match"], buffRows)}
      </section>
      <section>
        <h2>Win Distribution</h2>
        ${table(["Winner", "Matches"], winnerRows)}
      </section>
    `;

    res.type("html").send(layout("Gameplay", "/dashboard/gameplay", range, body));
  });

  router.get("/stability", async (req: Request, res: Response) => {
    const range = rangeFromReq(req);
    const data = await loadStability(pool, range);

    const versionRows = data.byVersion.map((row) => [
      String(row.app_version),
      String(row.platform),
      fmtInt(row.sessions),
      fmtInt(row.errors),
      fmtInt(row.crashes),
      Number(row.errors_per_1k_sessions ?? 0).toFixed(2),
      fmtPctRaw(row.crash_free_sessions_pct)
    ]);

    const topErrorRows = data.topErrors.map((row) => [
      String(row.app_version),
      String(row.error_code),
      fmtInt(row.errors)
    ]);

    const trendRows = data.trend.map((row) => [
      String(row.date).slice(0, 10),
      fmtInt(row.sessions),
      fmtPctRaw(row.crash_free_sessions_pct)
    ]);

    const body = `
      <section>
        <h2>By App Version</h2>
        ${table(["App Version", "Platform", "Sessions", "Errors", "Crashes", "Errors/1k Sessions", "Crash-free Sessions %"], versionRows)}
      </section>
      <section>
        <h2>Top Error Codes</h2>
        ${table(["App Version", "Error Code", "Count"], topErrorRows)}
      </section>
      <section>
        <h2>Crash-free Trend</h2>
        ${table(["Date", "Sessions", "Crash-free Sessions %"], trendRows)}
      </section>
    `;

    res.type("html").send(layout("Stability", "/dashboard/stability", range, body));
  });

  return router;
}
