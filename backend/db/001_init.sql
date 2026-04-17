CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  login text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id text UNIQUE NOT NULL,
  secret_hash text NOT NULL,
  owner_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_seen timestamptz
);

CREATE INDEX IF NOT EXISTS idx_devices_owner ON devices(owner_user_id);

CREATE TABLE IF NOT EXISTS device_thresholds (
  device_id uuid PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
  temp_min real,
  temp_max real,
  hum_min real,
  hum_max real,
  co2_max real,
  notify_enabled boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_dt_hum_min_range CHECK (hum_min IS NULL OR (hum_min >= 0 AND hum_min <= 100)),
  CONSTRAINT ck_dt_hum_max_range CHECK (hum_max IS NULL OR (hum_max >= 0 AND hum_max <= 100)),
  CONSTRAINT ck_dt_temp_logic CHECK (temp_min IS NULL OR temp_max IS NULL OR temp_min <= temp_max),
  CONSTRAINT ck_dt_hum_logic CHECK (hum_min IS NULL OR hum_max IS NULL OR hum_min <= hum_max),
  CONSTRAINT ck_dt_co2_nonneg CHECK (co2_max IS NULL OR co2_max >= 0)
);

CREATE TABLE IF NOT EXISTS sensor_readings (
  id bigserial PRIMARY KEY,
  device_id uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  ts timestamptz NOT NULL DEFAULT now(),
  temperature real,
  humidity real,
  co2 real,
  co real,
  lux real,
  CONSTRAINT ck_sr_humidity_0_100 CHECK (humidity IS NULL OR (humidity >= 0 AND humidity <= 100)),
  CONSTRAINT ck_sr_co2_nonneg CHECK (co2 IS NULL OR co2 >= 0),
  CONSTRAINT ck_sr_co_nonneg CHECK (co IS NULL OR co >= 0),
  CONSTRAINT ck_sr_lux_nonneg CHECK (lux IS NULL OR lux >= 0)
);

CREATE INDEX IF NOT EXISTS idx_readings_device_ts ON sensor_readings(device_id, ts DESC);

CREATE TABLE IF NOT EXISTS device_latest (
  device_id uuid PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
  ts timestamptz NOT NULL,
  temperature real,
  humidity real,
  co2 real,
  co real,
  lux real
);

CREATE TABLE IF NOT EXISTS alerts (
  id bigserial PRIMARY KEY,
  device_id uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  ts timestamptz NOT NULL DEFAULT now(),
  type text NOT NULL,
  value real,
  is_open boolean NOT NULL DEFAULT true,
  CONSTRAINT ck_alert_type CHECK (type IN (
    'TEMP_HIGH', 'TEMP_LOW',
    'HUM_HIGH', 'HUM_LOW',
    'CO2_HIGH', 'CO_HIGH',
    'LUX_HIGH', 'LUX_LOW'
  ))
);

CREATE INDEX IF NOT EXISTS idx_alerts_device_open ON alerts(device_id, is_open, ts DESC);

CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token text UNIQUE NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_fcm_user ON user_fcm_tokens(user_id);
