from datetime import datetime, timezone
from typing import Any

import asyncpg

from ..config import settings


class Database:
    def __init__(self) -> None:
        self.pool: asyncpg.Pool | None = None

    async def connect(self) -> None:
        self.pool = await asyncpg.create_pool(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            database=settings.DB_NAME,
            min_size=2,
            max_size=20,
        )

    async def disconnect(self) -> None:
        if self.pool:
            await self.pool.close()
            self.pool = None

    async def fetchrow(self, query: str, *args: Any) -> asyncpg.Record | None:
        if not self.pool:
            raise RuntimeError("Database pool is not initialized")
        async with self.pool.acquire() as conn:
            return await conn.fetchrow(query, *args)

    async def fetch(self, query: str, *args: Any) -> list[asyncpg.Record]:
        if not self.pool:
            raise RuntimeError("Database pool is not initialized")
        async with self.pool.acquire() as conn:
            return await conn.fetch(query, *args)

    async def execute(self, query: str, *args: Any) -> str:
        if not self.pool:
            raise RuntimeError("Database pool is not initialized")
        async with self.pool.acquire() as conn:
            return await conn.execute(query, *args)

    async def ingest_sensor_data(
        self,
        *,
        device_code: str,
        temperature: float,
        humidity: float,
        co2: float,
        co: float,
    ) -> dict[str, Any]:
        if not self.pool:
            raise RuntimeError("Database pool is not initialized")

        ts = datetime.now(timezone.utc)
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                device = await conn.fetchrow(
                    """
                    UPDATE devices
                    SET last_seen = $2
                    WHERE device_id = $1
                    RETURNING id, owner_user_id
                    """,
                    device_code,
                    ts,
                )

                if not device:
                    return {"known_device": False}

                device_uuid = device["id"]
                await conn.execute(
                    """
                    INSERT INTO sensor_readings(device_id, ts, temperature, humidity, co2, co)
                    VALUES ($1, $2, $3, $4, $5, $6)
                    """,
                    device_uuid,
                    ts,
                    temperature,
                    humidity,
                    co2,
                    co,
                )

                await conn.execute(
                    """
                    INSERT INTO device_latest(device_id, ts, temperature, humidity, co2, co)
                    VALUES ($1, $2, $3, $4, $5, $6)
                    ON CONFLICT (device_id)
                    DO UPDATE SET ts = EXCLUDED.ts,
                                  temperature = EXCLUDED.temperature,
                                  humidity = EXCLUDED.humidity,
                                  co2 = EXCLUDED.co2,
                                  co = EXCLUDED.co
                    """,
                    device_uuid,
                    ts,
                    temperature,
                    humidity,
                    co2,
                    co,
                )

                thresholds = await conn.fetchrow(
                    """
                    SELECT temp_min, temp_max, hum_min, hum_max, co2_max, notify_enabled
                    FROM device_thresholds
                    WHERE device_id = $1
                    """,
                    device_uuid,
                )
                triggered: list[tuple[str, float]] = []
                if thresholds and thresholds["notify_enabled"]:
                    temp_min = thresholds["temp_min"]
                    temp_max = thresholds["temp_max"]
                    hum_min = thresholds["hum_min"]
                    hum_max = thresholds["hum_max"]
                    co2_max = thresholds["co2_max"]

                    if temp_min is not None and temperature < temp_min:
                        triggered.append(("TEMP_LOW", temperature))
                    if temp_max is not None and temperature > temp_max:
                        triggered.append(("TEMP_HIGH", temperature))
                    if hum_min is not None and humidity < hum_min:
                        triggered.append(("HUM_LOW", humidity))
                    if hum_max is not None and humidity > hum_max:
                        triggered.append(("HUM_HIGH", humidity))
                    if co2_max is not None and co2 > co2_max:
                        triggered.append(("CO2_HIGH", co2))

                    active_types = [alert_type for alert_type, _ in triggered]
                    for alert_type, value in triggered:
                        open_alert = await conn.fetchrow(
                            """
                            SELECT id
                            FROM alerts
                            WHERE device_id = $1 AND type = $2 AND is_open = true
                            LIMIT 1
                            """,
                            device_uuid,
                            alert_type,
                        )
                        if not open_alert:
                            await conn.execute(
                                """
                                INSERT INTO alerts(device_id, ts, type, value, is_open)
                                VALUES ($1, $2, $3, $4, true)
                                """,
                                device_uuid,
                                ts,
                                alert_type,
                                value,
                            )

                    if active_types:
                        await conn.execute(
                            """
                            UPDATE alerts
                            SET is_open = false
                            WHERE device_id = $1
                              AND is_open = true
                              AND NOT (type = ANY($2::text[]))
                            """,
                            device_uuid,
                            active_types,
                        )
                    else:
                        await conn.execute(
                            """
                            UPDATE alerts
                            SET is_open = false
                            WHERE device_id = $1 AND is_open = true
                            """,
                            device_uuid,
                        )

                return {
                    "known_device": True,
                    "device_uuid": str(device_uuid),
                    "owner_user_id": str(device["owner_user_id"]) if device["owner_user_id"] else None,
                    "triggered_types": [alert_type for alert_type, _ in triggered],
                }


    async def save_predictions(
        self,
        *,
        device_uuid: str,
        now_ts,
        horizons: list[tuple[int, dict]],
    ) -> None:
        """Сохраняет прогнозы на 3 горизонта (30м, 3ч, 24ч) в таблицу predictions."""
        if not self.pool:
            return
        params = ["temp", "hum", "co2", "co"]
        keys   = ["temperature", "humidity", "co2_ppm", "co_ppm"]
        async with self.pool.acquire() as conn:
            for horizon_minutes, forecast in horizons:
                from datetime import timedelta
                target_ts = now_ts + timedelta(minutes=horizon_minutes)
                for param, key in zip(params, keys):
                    value = forecast.get(key)
                    if value is None:
                        continue
                    await conn.execute(
                        """
                        INSERT INTO predictions
                            (device_id, parameter_type, predicted_value,
                             prediction_ts, target_ts, horizon_minutes)
                        VALUES ($1, $2, $3, $4, $5, $6)
                        """,
                        device_uuid,
                        param,
                        float(value),
                        now_ts,
                        target_ts,
                        horizon_minutes,
                    )

    async def verify_predictions(self) -> None:
        """
        Верификация: сравнивает сохранённые прогнозы с реальными данными.
        Если ошибка > 15% — помечает прогноз как is_accurate = false.
        Запускается раз в час фоновой задачей.
        """
        if not self.pool:
            return
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT p.id,
                       p.predicted_value,
                       p.parameter_type,
                       p.device_id,
                       p.target_ts
                FROM predictions p
                WHERE p.is_accurate IS NULL
                  AND p.target_ts <= now()
                """
            )
            for row in rows:
                col_map = {"temp": "temperature", "hum": "humidity",
                           "co2": "co2", "co": "co"}
                col = col_map.get(row["parameter_type"])
                if not col:
                    continue
                real = await conn.fetchval(
                    f"""
                    SELECT {col}
                    FROM sensor_readings
                    WHERE device_id = $1
                      AND ts BETWEEN $2 - INTERVAL '3 minutes'
                               AND $2 + INTERVAL '3 minutes'
                    ORDER BY ABS(EXTRACT(EPOCH FROM (ts - $2)))
                    LIMIT 1
                    """,
                    row["device_id"],
                    row["target_ts"],
                )
                if real is None:
                    continue
                predicted = row["predicted_value"]
                divisor = abs(real) if abs(real) > 0.01 else 1.0
                error_pct = abs(predicted - real) / divisor * 100
                await conn.execute(
                    "UPDATE predictions SET is_accurate = $1 WHERE id = $2",
                    error_pct <= 15.0,
                    row["id"],
                )

    async def cleanup_old_predictions(self) -> None:
        """Удаляет прогнозы старше 48 часов. Запускается раз в сутки."""
        if not self.pool:
            return
        deleted = await self.pool.execute(
            "DELETE FROM predictions WHERE target_ts < now() - INTERVAL '48 hours'"
        )
        print(f"🧹 Очистка predictions: {deleted}")


db = Database()
