CREATE TABLE IF NOT EXISTS events_raw (
  event_id UUID PRIMARY KEY,
  event_name TEXT NOT NULL,
  event_time_utc_ms BIGINT NOT NULL,
  event_ts_utc TIMESTAMPTZ GENERATED ALWAYS AS (to_timestamp(event_time_utc_ms / 1000.0)) STORED,
  event_date DATE GENERATED ALWAYS AS ((timezone('UTC', to_timestamp(event_time_utc_ms / 1000.0)))::date) STORED,
  install_id UUID NOT NULL,
  session_id UUID NOT NULL,
  app_version TEXT NOT NULL,
  platform TEXT NOT NULL,
  device_model TEXT,
  os_version TEXT,
  country TEXT,
  props JSONB NOT NULL DEFAULT '{}'::jsonb,
  ingested_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_raw_date_name ON events_raw (event_date, event_name);
CREATE INDEX IF NOT EXISTS idx_events_raw_install_date ON events_raw (install_id, event_date);
CREATE INDEX IF NOT EXISTS idx_events_raw_session_id ON events_raw (session_id);
CREATE INDEX IF NOT EXISTS idx_events_raw_app_version_date ON events_raw (app_version, event_date);

CREATE TABLE IF NOT EXISTS installs (
  install_id UUID PRIMARY KEY,
  first_seen_date DATE NOT NULL,
  first_seen_time_utc_ms BIGINT NOT NULL,
  first_app_version TEXT NOT NULL,
  first_platform TEXT NOT NULL,
  first_country TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_rollup (
  date DATE NOT NULL,
  platform TEXT NOT NULL,
  new_installs INTEGER NOT NULL DEFAULT 0,
  dau INTEGER NOT NULL DEFAULT 0,
  wau INTEGER NOT NULL DEFAULT 0,
  mau INTEGER NOT NULL DEFAULT 0,
  sessions INTEGER NOT NULL DEFAULT 0,
  avg_session_length_s NUMERIC(12,2) NOT NULL DEFAULT 0,
  sessions_per_dau NUMERIC(12,4) NOT NULL DEFAULT 0,
  matches_completed INTEGER NOT NULL DEFAULT 0,
  avg_match_length_s NUMERIC(12,2) NOT NULL DEFAULT 0,
  vs_matches INTEGER NOT NULL DEFAULT 0,
  async_matches INTEGER NOT NULL DEFAULT 0,
  bot_matches INTEGER NOT NULL DEFAULT 0,
  purchase_count INTEGER NOT NULL DEFAULT 0,
  gross_revenue_cents BIGINT NOT NULL DEFAULT 0,
  paying_users INTEGER NOT NULL DEFAULT 0,
  arpdau_cents NUMERIC(14,4) NOT NULL DEFAULT 0,
  arppu_cents NUMERIC(14,4) NOT NULL DEFAULT 0,
  conversion_rate NUMERIC(10,6) NOT NULL DEFAULT 0,
  crash_free_sessions_pct NUMERIC(10,4) NOT NULL DEFAULT 100,
  errors_per_1k_sessions NUMERIC(14,4) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (date, platform)
);

CREATE TABLE IF NOT EXISTS daily_buff_rollup (
  date DATE NOT NULL,
  buff_id TEXT NOT NULL,
  uses_count BIGINT NOT NULL DEFAULT 0,
  unique_users_count BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (date, buff_id)
);

CREATE TABLE IF NOT EXISTS retention_rollup (
  cohort_date DATE NOT NULL,
  day_n INTEGER NOT NULL,
  cohort_size INTEGER NOT NULL DEFAULT 0,
  retained_users INTEGER NOT NULL DEFAULT 0,
  retention_rate NUMERIC(10,6) NOT NULL DEFAULT 0,
  calculated_for_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (cohort_date, day_n)
);

CREATE TABLE IF NOT EXISTS daily_stability_rollup (
  date DATE NOT NULL,
  app_version TEXT NOT NULL,
  platform TEXT NOT NULL,
  sessions INTEGER NOT NULL DEFAULT 0,
  errors INTEGER NOT NULL DEFAULT 0,
  crashes INTEGER NOT NULL DEFAULT 0,
  crash_free_sessions_pct NUMERIC(10,4) NOT NULL DEFAULT 100,
  errors_per_1k_sessions NUMERIC(14,4) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (date, app_version, platform)
);

CREATE TABLE IF NOT EXISTS daily_error_code_rollup (
  date DATE NOT NULL,
  app_version TEXT NOT NULL,
  error_code TEXT NOT NULL,
  errors INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (date, app_version, error_code)
);

CREATE TABLE IF NOT EXISTS daily_match_winner_rollup (
  date DATE NOT NULL,
  winner TEXT NOT NULL,
  matches INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (date, winner)
);

CREATE TABLE IF NOT EXISTS admin_users (
  id BIGSERIAL PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
