"""API маршруты для истории."""
from fastapi import APIRouter, Depends

from ..deps import get_current_user, get_owned_device
from ...core.database import db

router = APIRouter(prefix="/api", tags=["history"])


@router.get("/history")
async def get_history(
    limit: int = 50,
    device_id: str | None = None,
    current_user=Depends(get_current_user),
):
    device = await get_owned_device(current_user["id"], device_id)

    thresholds = await db.fetchrow(
        """
        SELECT temp_min, temp_max, hum_min, hum_max, co2_max
        FROM device_thresholds
        WHERE device_id = $1
        """,
        device["id"],
    )
    profile = {
        "temp_min": float(thresholds["temp_min"]) if thresholds and thresholds["temp_min"] is not None else 18.0,
        "temp_max": float(thresholds["temp_max"]) if thresholds and thresholds["temp_max"] is not None else 28.0,
        "humidity_max": float(thresholds["hum_max"]) if thresholds and thresholds["hum_max"] is not None else 80.0,
        "co2_max": float(thresholds["co2_max"]) if thresholds and thresholds["co2_max"] is not None else 1200.0,
        "co_max": 99999.0,
        "name": "device_thresholds",
    }

    rows = await db.fetch(
        """
        SELECT ts, temperature, humidity, co2, co
        FROM sensor_readings
        WHERE device_id = $1
        ORDER BY ts DESC
        LIMIT $2
        """,
        device["id"],
        min(max(limit, 1), 1000),
    )

    enriched = []
    for row in rows:
        temp = float(row["temperature"] or 0)
        hum = float(row["humidity"] or 0)
        co2 = float(row["co2"] or 0)
        co = float(row["co"] or 0)
        issues = []

        if temp < profile["temp_min"] or temp > profile["temp_max"]:
            issues.append("temperature")
        if hum > profile["humidity_max"]:
            issues.append("humidity")
        if co2 > profile["co2_max"]:
            issues.append("co2_ppm")

        enriched.append(
            {
                "temp": temp,
                "hum": hum,
                "co2": co2,
                "co": co,
                "time": row["ts"].isoformat(),
                "is_danger": len(issues) > 0,
                "issues": issues,
                "status": "out_of_range" if issues else "ok",
                "message": "Вне нормы" if issues else "Норма",
            }
        )

    return {
        "count": len(enriched),
        "device_id": device["device_id"],
        "profile": profile["name"],
        # Keep both keys for backward compatibility with clients.
        "items": enriched,
        "data": enriched,
    }
