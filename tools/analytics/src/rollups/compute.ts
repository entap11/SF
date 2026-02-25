import type { Pool, PoolClient } from "pg";
import { addDays } from "../util/date.js";

async function clearDateRows(client: PoolClient, table: string, dateColumn: string, date: string): Promise<void> {
  await client.query(`DELETE FROM ${table} WHERE ${dateColumn} = $1::date`, [date]);
}

async function computeDailyRollup(client: PoolClient, date: string): Promise<void> {
  await clearDateRows(client, "daily_rollup", "date", date);

  await client.query(
    `
      WITH platforms AS (
        SELECT DISTINCT platform
        FROM events_raw
        WHERE event_date = $1::date
      ),
      stats AS (
        SELECT
          p.platform,
          (
            SELECT COUNT(*)
            FROM installs i
            WHERE i.first_seen_date = $1::date
              AND i.first_platform = p.platform
          ) AS new_installs,
          (
            SELECT COUNT(DISTINCT e.install_id)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
          ) AS dau,
          (
            SELECT COUNT(DISTINCT e.install_id)
            FROM events_raw e
            WHERE e.event_date BETWEEN ($1::date - INTERVAL '6 days')::date AND $1::date
              AND e.platform = p.platform
          ) AS wau,
          (
            SELECT COUNT(DISTINCT e.install_id)
            FROM events_raw e
            WHERE e.event_date BETWEEN ($1::date - INTERVAL '29 days')::date AND $1::date
              AND e.platform = p.platform
          ) AS mau,
          (
            SELECT COUNT(DISTINCT e.session_id)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'session_start'
          ) AS sessions,
          (
            SELECT AVG((e.props->>'duration_ms')::numeric) / 1000.0
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'session_end'
              AND (e.props ? 'duration_ms')
          ) AS avg_session_length_s,
          (
            SELECT COUNT(*)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'match_end_summary'
          ) AS matches_completed,
          (
            SELECT AVG((e.props->>'duration_ms')::numeric) / 1000.0
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'match_end_summary'
              AND (e.props ? 'duration_ms')
          ) AS avg_match_length_s,
          (
            SELECT COUNT(*)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'match_end_summary'
              AND (e.props->>'match_type') = 'VS'
          ) AS vs_matches,
          (
            SELECT COUNT(*)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'match_end_summary'
              AND (e.props->>'match_type') = 'ASYNC'
          ) AS async_matches,
          (
            SELECT COUNT(*)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'match_end_summary'
              AND (e.props->>'match_type') = 'BOT'
          ) AS bot_matches,
          (
            SELECT COUNT(*)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'purchase'
          ) AS purchase_count,
          (
            SELECT COALESCE(SUM(
              ((e.props->>'price_cents')::bigint)
              * COALESCE((e.props->>'quantity')::bigint, 1)
            ), 0)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'purchase'
              AND (e.props ? 'price_cents')
          ) AS gross_revenue_cents,
          (
            SELECT COUNT(DISTINCT e.install_id)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'purchase'
          ) AS paying_users,
          (
            SELECT COUNT(DISTINCT e.session_id)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'crash'
          ) AS crash_sessions,
          (
            SELECT COUNT(*)
            FROM events_raw e
            WHERE e.event_date = $1::date
              AND e.platform = p.platform
              AND e.event_name = 'error'
          ) AS errors_count
        FROM platforms p
      )
      INSERT INTO daily_rollup (
        date,
        platform,
        new_installs,
        dau,
        wau,
        mau,
        sessions,
        avg_session_length_s,
        sessions_per_dau,
        matches_completed,
        avg_match_length_s,
        vs_matches,
        async_matches,
        bot_matches,
        purchase_count,
        gross_revenue_cents,
        paying_users,
        arpdau_cents,
        arppu_cents,
        conversion_rate,
        crash_free_sessions_pct,
        errors_per_1k_sessions,
        updated_at
      )
      SELECT
        $1::date,
        s.platform,
        s.new_installs,
        s.dau,
        s.wau,
        s.mau,
        s.sessions,
        COALESCE(s.avg_session_length_s, 0),
        CASE WHEN s.dau > 0 THEN s.sessions::numeric / s.dau ELSE 0 END,
        s.matches_completed,
        COALESCE(s.avg_match_length_s, 0),
        s.vs_matches,
        s.async_matches,
        s.bot_matches,
        s.purchase_count,
        s.gross_revenue_cents,
        s.paying_users,
        CASE WHEN s.dau > 0 THEN s.gross_revenue_cents::numeric / s.dau ELSE 0 END,
        CASE WHEN s.paying_users > 0 THEN s.gross_revenue_cents::numeric / s.paying_users ELSE 0 END,
        CASE WHEN s.dau > 0 THEN s.paying_users::numeric / s.dau ELSE 0 END,
        CASE WHEN s.sessions > 0 THEN ((s.sessions - s.crash_sessions)::numeric * 100.0) / s.sessions ELSE 100 END,
        CASE WHEN s.sessions > 0 THEN (s.errors_count::numeric * 1000.0) / s.sessions ELSE 0 END,
        now()
      FROM stats s
    `,
    [date]
  );
}

async function computeDailyBuffRollup(client: PoolClient, date: string): Promise<void> {
  await clearDateRows(client, "daily_buff_rollup", "date", date);

  await client.query(
    `
      WITH source AS (
        SELECT install_id, props
        FROM events_raw
        WHERE event_date = $1::date
          AND event_name = 'match_end_summary'
      ),
      exploded AS (
        SELECT s.install_id, j.key AS buff_id, GREATEST((j.value)::bigint, 0) AS uses
        FROM source s
        CROSS JOIN LATERAL jsonb_each_text(COALESCE(s.props->'buffs_used', '{}'::jsonb)) j
        UNION ALL
        SELECT s.install_id, j.key AS buff_id, GREATEST((j.value)::bigint, 0) AS uses
        FROM source s
        CROSS JOIN LATERAL jsonb_each_text(COALESCE(s.props->'lane_buffs_used', '{}'::jsonb)) j
      )
      INSERT INTO daily_buff_rollup (date, buff_id, uses_count, unique_users_count, updated_at)
      SELECT
        $1::date,
        e.buff_id,
        COALESCE(SUM(e.uses), 0),
        COUNT(DISTINCT e.install_id),
        now()
      FROM exploded e
      GROUP BY e.buff_id
    `,
    [date]
  );
}

async function computeDailyMatchWinners(client: PoolClient, date: string): Promise<void> {
  await clearDateRows(client, "daily_match_winner_rollup", "date", date);

  await client.query(
    `
      INSERT INTO daily_match_winner_rollup (date, winner, matches, updated_at)
      SELECT
        $1::date,
        COALESCE(NULLIF(props->>'winner', ''), 'UNKNOWN') AS winner,
        COUNT(*) AS matches,
        now()
      FROM events_raw
      WHERE event_date = $1::date
        AND event_name = 'match_end_summary'
      GROUP BY COALESCE(NULLIF(props->>'winner', ''), 'UNKNOWN')
    `,
    [date]
  );
}

async function computeDailyStabilityRollup(client: PoolClient, date: string): Promise<void> {
  await clearDateRows(client, "daily_stability_rollup", "date", date);
  await clearDateRows(client, "daily_error_code_rollup", "date", date);

  await client.query(
    `
      WITH versions AS (
        SELECT DISTINCT app_version, platform
        FROM events_raw
        WHERE event_date = $1::date
      )
      INSERT INTO daily_stability_rollup (
        date,
        app_version,
        platform,
        sessions,
        errors,
        crashes,
        crash_free_sessions_pct,
        errors_per_1k_sessions,
        updated_at
      )
      SELECT
        $1::date,
        v.app_version,
        v.platform,
        (
          SELECT COUNT(DISTINCT e.session_id)
          FROM events_raw e
          WHERE e.event_date = $1::date
            AND e.app_version = v.app_version
            AND e.platform = v.platform
            AND e.event_name = 'session_start'
        ) AS sessions,
        (
          SELECT COUNT(*)
          FROM events_raw e
          WHERE e.event_date = $1::date
            AND e.app_version = v.app_version
            AND e.platform = v.platform
            AND e.event_name = 'error'
        ) AS errors,
        (
          SELECT COUNT(*)
          FROM events_raw e
          WHERE e.event_date = $1::date
            AND e.app_version = v.app_version
            AND e.platform = v.platform
            AND e.event_name = 'crash'
        ) AS crashes,
        (
          SELECT
            CASE WHEN sess.cnt > 0 THEN ((sess.cnt - crash.cnt)::numeric * 100.0) / sess.cnt ELSE 100 END
          FROM
            (SELECT COUNT(DISTINCT e.session_id) AS cnt
             FROM events_raw e
             WHERE e.event_date = $1::date
               AND e.app_version = v.app_version
               AND e.platform = v.platform
               AND e.event_name = 'session_start') sess,
            (SELECT COUNT(DISTINCT e.session_id) AS cnt
             FROM events_raw e
             WHERE e.event_date = $1::date
               AND e.app_version = v.app_version
               AND e.platform = v.platform
               AND e.event_name = 'crash') crash
        ) AS crash_free_sessions_pct,
        (
          SELECT
            CASE WHEN sess.cnt > 0 THEN (err.cnt::numeric * 1000.0) / sess.cnt ELSE 0 END
          FROM
            (SELECT COUNT(DISTINCT e.session_id) AS cnt
             FROM events_raw e
             WHERE e.event_date = $1::date
               AND e.app_version = v.app_version
               AND e.platform = v.platform
               AND e.event_name = 'session_start') sess,
            (SELECT COUNT(*) AS cnt
             FROM events_raw e
             WHERE e.event_date = $1::date
               AND e.app_version = v.app_version
               AND e.platform = v.platform
               AND e.event_name = 'error') err
        ) AS errors_per_1k_sessions,
        now()
      FROM versions v
    `,
    [date]
  );

  await client.query(
    `
      INSERT INTO daily_error_code_rollup (date, app_version, error_code, errors, updated_at)
      SELECT
        $1::date,
        app_version,
        COALESCE(NULLIF(props->>'error_code', ''), 'UNKNOWN') AS error_code,
        COUNT(*) AS errors,
        now()
      FROM events_raw
      WHERE event_date = $1::date
        AND event_name = 'error'
      GROUP BY app_version, COALESCE(NULLIF(props->>'error_code', ''), 'UNKNOWN')
    `,
    [date]
  );
}

async function computeRetention(client: PoolClient, date: string): Promise<void> {
  const windows = [1, 7] as const;
  for (const dayN of windows) {
    const cohortDate = addDays(date, -dayN);
    await client.query(
      `
        INSERT INTO retention_rollup (
          cohort_date,
          day_n,
          cohort_size,
          retained_users,
          retention_rate,
          calculated_for_date,
          updated_at
        )
        WITH cohort AS (
          SELECT install_id
          FROM installs
          WHERE first_seen_date = $1::date
        ),
        active_on_target AS (
          SELECT DISTINCT install_id
          FROM events_raw
          WHERE event_date = $2::date
        )
        SELECT
          $1::date,
          $3::int,
          (SELECT COUNT(*) FROM cohort),
          (
            SELECT COUNT(*)
            FROM cohort c
            INNER JOIN active_on_target a ON a.install_id = c.install_id
          ),
          CASE
            WHEN (SELECT COUNT(*) FROM cohort) > 0
              THEN (
                (
                  SELECT COUNT(*)
                  FROM cohort c
                  INNER JOIN active_on_target a ON a.install_id = c.install_id
                )::numeric / (SELECT COUNT(*) FROM cohort)
              )
            ELSE 0
          END,
          $2::date,
          now()
        ON CONFLICT (cohort_date, day_n)
        DO UPDATE SET
          cohort_size = EXCLUDED.cohort_size,
          retained_users = EXCLUDED.retained_users,
          retention_rate = EXCLUDED.retention_rate,
          calculated_for_date = EXCLUDED.calculated_for_date,
          updated_at = now()
      `,
      [cohortDate, date, dayN]
    );
  }
}

export async function computeRollupsForDate(pool: Pool, date: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await computeDailyRollup(client, date);
    await computeDailyBuffRollup(client, date);
    await computeDailyMatchWinners(client, date);
    await computeDailyStabilityRollup(client, date);
    await computeRetention(client, date);
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function computeRollupsForRange(pool: Pool, startDate: string, endDate: string): Promise<void> {
  let date = startDate;
  while (date <= endDate) {
    // eslint-disable-next-line no-await-in-loop
    await computeRollupsForDate(pool, date);
    date = addDays(date, 1);
  }
}
