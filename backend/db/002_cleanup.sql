-- Cleanup + hardening migration for existing databases.
-- Safe to run multiple times.

-- 1) Remove duplicate unique index for users.login (UNIQUE on column already exists).
DROP INDEX IF EXISTS uq_users_login;

-- 2) Make device owner link resilient: if user is deleted, keep device with NULL owner.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'devices_owner_user_id_fkey'
      AND conrelid = 'devices'::regclass
  ) THEN
    ALTER TABLE devices DROP CONSTRAINT devices_owner_user_id_fkey;
  END IF;
END $$;

ALTER TABLE devices
  ADD CONSTRAINT devices_owner_user_id_fkey
  FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE SET NULL;

-- 3) Add thresholds checks.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_dt_hum_min_range'
      AND conrelid = 'device_thresholds'::regclass
  ) THEN
    ALTER TABLE device_thresholds
      ADD CONSTRAINT ck_dt_hum_min_range
      CHECK (hum_min IS NULL OR (hum_min >= 0 AND hum_min <= 100));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_dt_hum_max_range'
      AND conrelid = 'device_thresholds'::regclass
  ) THEN
    ALTER TABLE device_thresholds
      ADD CONSTRAINT ck_dt_hum_max_range
      CHECK (hum_max IS NULL OR (hum_max >= 0 AND hum_max <= 100));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_dt_temp_logic'
      AND conrelid = 'device_thresholds'::regclass
  ) THEN
    ALTER TABLE device_thresholds
      ADD CONSTRAINT ck_dt_temp_logic
      CHECK (temp_min IS NULL OR temp_max IS NULL OR temp_min <= temp_max);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_dt_hum_logic'
      AND conrelid = 'device_thresholds'::regclass
  ) THEN
    ALTER TABLE device_thresholds
      ADD CONSTRAINT ck_dt_hum_logic
      CHECK (hum_min IS NULL OR hum_max IS NULL OR hum_min <= hum_max);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_dt_co2_nonneg'
      AND conrelid = 'device_thresholds'::regclass
  ) THEN
    ALTER TABLE device_thresholds
      ADD CONSTRAINT ck_dt_co2_nonneg
      CHECK (co2_max IS NULL OR co2_max >= 0);
  END IF;
END $$;

-- 4) Add readings checks + default timestamp.
ALTER TABLE sensor_readings
  ALTER COLUMN ts SET DEFAULT now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_sr_humidity_0_100'
      AND conrelid = 'sensor_readings'::regclass
  ) THEN
    ALTER TABLE sensor_readings
      ADD CONSTRAINT ck_sr_humidity_0_100
      CHECK (humidity IS NULL OR (humidity >= 0 AND humidity <= 100));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_sr_co2_nonneg'
      AND conrelid = 'sensor_readings'::regclass
  ) THEN
    ALTER TABLE sensor_readings
      ADD CONSTRAINT ck_sr_co2_nonneg
      CHECK (co2 IS NULL OR co2 >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_sr_co_nonneg'
      AND conrelid = 'sensor_readings'::regclass
  ) THEN
    ALTER TABLE sensor_readings
      ADD CONSTRAINT ck_sr_co_nonneg
      CHECK (co IS NULL OR co >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_sr_lux_nonneg'
      AND conrelid = 'sensor_readings'::regclass
  ) THEN
    ALTER TABLE sensor_readings
      ADD CONSTRAINT ck_sr_lux_nonneg
      CHECK (lux IS NULL OR lux >= 0);
  END IF;
END $$;

-- 5) Restrict alert types to known values used by backend + prepared extensions.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ck_alert_type'
      AND conrelid = 'alerts'::regclass
  ) THEN
    ALTER TABLE alerts
      ADD CONSTRAINT ck_alert_type
      CHECK (type IN (
        'TEMP_HIGH', 'TEMP_LOW',
        'HUM_HIGH', 'HUM_LOW',
        'CO2_HIGH', 'CO_HIGH',
        'LUX_HIGH', 'LUX_LOW'
      ));
  END IF;
END $$;
