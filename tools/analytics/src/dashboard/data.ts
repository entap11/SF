import type { Pool } from "pg";
import { addDays, parseDateStrict, todayUtc } from "../util/date.js";

export interface DateRange {
  start: string;
  end: string;
}

export function resolveDateRange(startRaw: unknown, endRaw: unknown): DateRange {
  const defaultEnd = todayUtc();
  const defaultStart = addDays(defaultEnd, -6);
  const start = typeof startRaw === "string" && startRaw ? startRaw : defaultStart;
  const end = typeof endRaw === "string" && endRaw ? endRaw : defaultEnd;
  parseDateStrict(start);
  parseDateStrict(end);
  if (start > end) {
    throw new Error("start must be <= end");
  }
  return { start, end };
}

export async function loadOverview(pool: Pool, range: DateRange) {
  const totals = await pool.query(
    `
      WITH daily AS (
        SELECT
          date,
          SUM(new_installs)::bigint AS new_installs,
          SUM(dau)::bigint AS dau,
          SUM(wau)::bigint AS wau,
          SUM(mau)::bigint AS mau,
          SUM(sessions)::bigint AS sessions,
          SUM(matches_completed)::bigint AS matches_completed,
          SUM(vs_matches)::bigint AS vs_matches,
          SUM(async_matches)::bigint AS async_matches,
          SUM(bot_matches)::bigint AS bot_matches,
          SUM(purchase_count)::bigint AS purchase_count,
          SUM(gross_revenue_cents)::bigint AS gross_revenue_cents,
          SUM(paying_users)::bigint AS paying_users,
          SUM((avg_session_length_s * sessions))::numeric AS weighted_session_s,
          SUM((avg_match_length_s * matches_completed))::numeric AS weighted_match_s,
          SUM(errors_per_1k_sessions * sessions)::numeric AS weighted_errors_per_1k,
          SUM(crash_free_sessions_pct * sessions)::numeric AS weighted_crash_free
        FROM daily_rollup
        WHERE date BETWEEN $1::date AND $2::date
        GROUP BY date
      )
      SELECT
        COALESCE(SUM(new_installs), 0) AS new_installs,
        COALESCE(AVG(dau), 0) AS avg_dau,
        COALESCE(MAX(dau), 0) AS peak_dau,
        COALESCE(MAX(wau), 0) AS latest_wau,
        COALESCE(MAX(mau), 0) AS latest_mau,
        COALESCE(SUM(sessions), 0) AS sessions,
        COALESCE(SUM(matches_completed), 0) AS matches_completed,
        COALESCE(SUM(vs_matches), 0) AS vs_matches,
        COALESCE(SUM(async_matches), 0) AS async_matches,
        COALESCE(SUM(bot_matches), 0) AS bot_matches,
        COALESCE(SUM(purchase_count), 0) AS purchase_count,
        COALESCE(SUM(gross_revenue_cents), 0) AS gross_revenue_cents,
        COALESCE(SUM(paying_users), 0) AS paying_users,
        CASE WHEN SUM(sessions) > 0 THEN SUM(weighted_session_s) / SUM(sessions) ELSE 0 END AS avg_session_length_s,
        CASE WHEN SUM(matches_completed) > 0 THEN SUM(weighted_match_s) / SUM(matches_completed) ELSE 0 END AS avg_match_length_s,
        CASE WHEN SUM(dau) > 0 THEN SUM(sessions)::numeric / SUM(dau) ELSE 0 END AS sessions_per_dau,
        CASE WHEN SUM(dau) > 0 THEN SUM(gross_revenue_cents)::numeric / SUM(dau) ELSE 0 END AS arpdau_cents,
        CASE WHEN SUM(paying_users) > 0 THEN SUM(gross_revenue_cents)::numeric / SUM(paying_users) ELSE 0 END AS arppu_cents,
        CASE WHEN SUM(dau) > 0 THEN SUM(paying_users)::numeric / SUM(dau) ELSE 0 END AS conversion_rate,
        CASE WHEN SUM(sessions) > 0 THEN SUM(weighted_crash_free) / SUM(sessions) ELSE 100 END AS crash_free_sessions_pct,
        CASE WHEN SUM(sessions) > 0 THEN SUM(weighted_errors_per_1k) / SUM(sessions) ELSE 0 END AS errors_per_1k_sessions
      FROM daily
    `,
    [range.start, range.end]
  );

  return totals.rows[0] ?? null;
}

export async function loadRetention(pool: Pool, range: DateRange) {
  const summary = await pool.query(
    `
      SELECT
        day_n,
        AVG(retention_rate)::numeric AS avg_retention_rate,
        MAX(calculated_for_date) AS latest_calculated_for_date
      FROM retention_rollup
      WHERE calculated_for_date BETWEEN $1::date AND $2::date
        AND day_n IN (1, 7)
      GROUP BY day_n
      ORDER BY day_n
    `,
    [range.start, range.end]
  );

  const detail = await pool.query(
    `
      SELECT
        calculated_for_date,
        cohort_date,
        day_n,
        cohort_size,
        retained_users,
        retention_rate
      FROM retention_rollup
      WHERE calculated_for_date BETWEEN $1::date AND $2::date
        AND day_n IN (1, 7)
      ORDER BY calculated_for_date DESC, day_n ASC
      LIMIT 120
    `,
    [range.start, range.end]
  );

  return { summary: summary.rows, detail: detail.rows };
}

export async function loadGameplay(pool: Pool, range: DateRange) {
  const buffs = await pool.query(
    `
      SELECT buff_id, SUM(uses_count)::bigint AS uses_count, SUM(unique_users_count)::bigint AS unique_users_count
      FROM daily_buff_rollup
      WHERE date BETWEEN $1::date AND $2::date
      GROUP BY buff_id
      ORDER BY uses_count DESC
      LIMIT 25
    `,
    [range.start, range.end]
  );

  const winners = await pool.query(
    `
      SELECT winner, SUM(matches)::bigint AS matches
      FROM daily_match_winner_rollup
      WHERE date BETWEEN $1::date AND $2::date
      GROUP BY winner
      ORDER BY matches DESC
    `,
    [range.start, range.end]
  );

  const modeSplit = await pool.query(
    `
      SELECT
        COALESCE(SUM(vs_matches), 0)::bigint AS vs_matches,
        COALESCE(SUM(async_matches), 0)::bigint AS async_matches,
        COALESCE(SUM(bot_matches), 0)::bigint AS bot_matches,
        COALESCE(SUM(matches_completed), 0)::bigint AS matches_completed
      FROM daily_rollup
      WHERE date BETWEEN $1::date AND $2::date
    `,
    [range.start, range.end]
  );

  return {
    buffs: buffs.rows,
    winners: winners.rows,
    modeSplit: modeSplit.rows[0] ?? null
  };
}

export async function loadStability(pool: Pool, range: DateRange) {
  const byVersion = await pool.query(
    `
      SELECT
        app_version,
        platform,
        SUM(sessions)::bigint AS sessions,
        SUM(errors)::bigint AS errors,
        SUM(crashes)::bigint AS crashes,
        CASE WHEN SUM(sessions) > 0 THEN (SUM(errors)::numeric * 1000.0) / SUM(sessions) ELSE 0 END AS errors_per_1k_sessions,
        CASE WHEN SUM(sessions) > 0 THEN ((SUM(sessions) - SUM(crashes))::numeric * 100.0) / SUM(sessions) ELSE 100 END AS crash_free_sessions_pct
      FROM daily_stability_rollup
      WHERE date BETWEEN $1::date AND $2::date
      GROUP BY app_version, platform
      ORDER BY sessions DESC, app_version DESC
      LIMIT 100
    `,
    [range.start, range.end]
  );

  const topErrors = await pool.query(
    `
      SELECT
        app_version,
        error_code,
        SUM(errors)::bigint AS errors
      FROM daily_error_code_rollup
      WHERE date BETWEEN $1::date AND $2::date
      GROUP BY app_version, error_code
      ORDER BY errors DESC
      LIMIT 25
    `,
    [range.start, range.end]
  );

  const trend = await pool.query(
    `
      SELECT
        date,
        SUM(sessions)::bigint AS sessions,
        CASE WHEN SUM(sessions) > 0 THEN SUM(crash_free_sessions_pct * sessions) / SUM(sessions) ELSE 100 END AS crash_free_sessions_pct
      FROM daily_rollup
      WHERE date BETWEEN $1::date AND $2::date
      GROUP BY date
      ORDER BY date ASC
    `,
    [range.start, range.end]
  );

  return {
    byVersion: byVersion.rows,
    topErrors: topErrors.rows,
    trend: trend.rows
  };
}
