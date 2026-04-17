"""API маршруты для профилей."""
from fastapi import APIRouter, Depends, HTTPException

from ..deps import get_current_user, get_owned_device
from ...core.constants import PROFILES
from ...core.database import db

router = APIRouter(prefix="/api", tags=["profiles"])


@router.get("/profiles")
async def get_profiles(device_id: str | None = None, current_user=Depends(get_current_user)):
    """Получение всех профилей и активного профиля устройства пользователя."""
    device = await get_owned_device(current_user["id"], device_id)

    thresholds = await db.fetchrow(
        """
        SELECT temp_min, temp_max, hum_max, co2_max, notify_enabled, updated_at
        FROM device_thresholds
        WHERE device_id = $1
        """,
        device["id"],
    )
    active = {
        "name": "⚙️ Пользовательский",
        "temp_min": 18.0,
        "temp_max": 28.0,
        "humidity_max": 80.0,
        "co2_max": 1200.0,
        "co_max": 99999.0,
    }
    if thresholds:
        active["temp_min"] = float(thresholds["temp_min"]) if thresholds["temp_min"] is not None else active["temp_min"]
        active["temp_max"] = float(thresholds["temp_max"]) if thresholds["temp_max"] is not None else active["temp_max"]
        active["humidity_max"] = float(thresholds["hum_max"]) if thresholds["hum_max"] is not None else active["humidity_max"]
        active["co2_max"] = float(thresholds["co2_max"]) if thresholds["co2_max"] is not None else active["co2_max"]

        for preset in PROFILES:
            if (
                float(preset["temp_min"]) == float(active["temp_min"])
                and float(preset["temp_max"]) == float(active["temp_max"])
                and float(preset["humidity_max"]) == float(active["humidity_max"])
                and float(preset["co2_max"]) == float(active["co2_max"])
            ):
                active["name"] = preset["name"]
                active["co_max"] = preset["co_max"]
                break

    return {
        "presets": PROFILES,
        "device_id": device["device_id"],
        "active": active,
    }


@router.post("/profile/update")
async def update_profile(profile: dict, current_user=Depends(get_current_user)):
    """
    Обновление активного профиля для конкретного устройства пользователя.
    """
    target_device_id = profile.get("device_id")
    device = await get_owned_device(current_user["id"], target_device_id)

    selected = None
    preset_name = profile.get("name")
    if preset_name:
        for preset in PROFILES:
            if preset["name"] == preset_name:
                selected = dict(preset)
                break

    if selected is None:
        required = ["name", "temp_min", "temp_max", "humidity_max", "co2_max", "co_max"]
        for field in required:
            if field not in profile:
                return {"status": "error", "message": f"Отсутствует поле: {field}"}
        selected = dict(profile)

    await db.execute(
        """
        INSERT INTO device_thresholds(device_id, temp_min, temp_max, hum_max, co2_max, notify_enabled, updated_at)
        VALUES ($1, $2, $3, $4, $5, true, now())
        ON CONFLICT (device_id)
        DO UPDATE SET temp_min = EXCLUDED.temp_min,
                      temp_max = EXCLUDED.temp_max,
                      hum_max = EXCLUDED.hum_max,
                      co2_max = EXCLUDED.co2_max,
                      notify_enabled = EXCLUDED.notify_enabled,
                      updated_at = now()
        """,
        device["id"],
        float(selected["temp_min"]),
        float(selected["temp_max"]),
        float(selected["humidity_max"]),
        float(selected["co2_max"]),
    )

    return {
        "status": "success",
        "message": f"Профиль обновлен: {selected['name']}",
        "device_id": device["device_id"],
        "active_profile": selected,
    }
