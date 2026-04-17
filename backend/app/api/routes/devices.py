from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from ..deps import get_current_user
from ...core.database import db
from ...core.security import hash_password, verify_password

router = APIRouter(prefix="/api/devices", tags=["devices"])


class ClaimDeviceRequest(BaseModel):
    device_id: str = Field(max_length=128)
    secret: str = Field(max_length=256)
    name: str | None = Field(default=None, max_length=128)


class RegisterDeviceRequest(BaseModel):
    device_id: str = Field(max_length=128)
    secret: str = Field(max_length=256)
    name: str | None = Field(default=None, max_length=128)


class AdoptDeviceRequest(BaseModel):
    device_id: str = Field(max_length=128)
    name: str | None = Field(default=None, max_length=128)


class ThresholdsUpdateRequest(BaseModel):
    temp_min: float | None = None
    temp_max: float | None = None
    hum_min: float | None = None
    hum_max: float | None = None
    co2_max: float | None = None
    notify_enabled: bool = True


@router.get("")
async def list_devices(current_user=Depends(get_current_user)):
    rows = await db.fetch(
        """
        SELECT device_id, name, created_at, last_seen
        FROM devices
        WHERE owner_user_id = $1
        ORDER BY created_at DESC
        """,
        current_user["id"],
    )
    return {"devices": [dict(row) for row in rows]}


@router.post("/register")
async def register_device(data: RegisterDeviceRequest, current_user=Depends(get_current_user)):
    device_id = data.device_id.strip()
    secret = data.secret.strip()
    name = data.name.strip() if data.name else None

    if not device_id or not secret:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="device_id and secret are required")

    existing = await db.fetchrow(
        "SELECT id FROM devices WHERE device_id = $1",
        device_id,
    )
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Device already exists")

    secret_hash = hash_password(data.secret)
    device = await db.fetchrow(
        """
        INSERT INTO devices(device_id, secret_hash, owner_user_id, name)
        VALUES ($1, $2, $3, $4)
        RETURNING id
        """,
        device_id,
        secret_hash,
        current_user["id"],
        name,
    )
    await db.execute(
        "INSERT INTO device_thresholds(device_id) VALUES ($1) ON CONFLICT (device_id) DO NOTHING",
        device["id"],
    )
    return {"status": "registered", "device_id": device_id}


@router.post("/claim")
async def claim_device(data: ClaimDeviceRequest, current_user=Depends(get_current_user)):
    device_id = data.device_id.strip()
    secret = data.secret.strip()
    name = data.name.strip() if data.name else None

    if not device_id or not secret:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="device_id and secret are required")

    device = await db.fetchrow(
        """
        SELECT id, device_id, secret_hash, owner_user_id, name
        FROM devices
        WHERE device_id = $1
        """,
        device_id,
    )
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")

    if not verify_password(secret, device["secret_hash"]):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid device secret")

    if device["owner_user_id"] and str(device["owner_user_id"]) != str(current_user["id"]):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Device already claimed")

    await db.execute(
        """
        UPDATE devices
        SET owner_user_id = $1, name = COALESCE($2, name)
        WHERE id = $3
        """,
        current_user["id"],
        name,
        device["id"],
    )
    await db.execute(
        """
        INSERT INTO device_thresholds(device_id)
        VALUES ($1)
        ON CONFLICT (device_id) DO NOTHING
        """,
        device["id"],
    )

    return {"status": "claimed", "device_id": device_id}


@router.post("/adopt")
async def adopt_device(data: AdoptDeviceRequest, current_user=Depends(get_current_user)):
    """Привязать устройство без пароля — только если оно ещё без владельца."""
    device_id = data.device_id.strip()

    device = await db.fetchrow(
        "SELECT id, owner_user_id FROM devices WHERE device_id = $1",
        device_id,
    )
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Устройство не найдено. Включите его — оно зарегистрируется автоматически.")
    if device["owner_user_id"]:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="Устройство уже принадлежит другому пользователю.")

    await db.execute(
        """
        UPDATE devices
        SET owner_user_id = $1, name = COALESCE($2, name)
        WHERE id = $3
        """,
        current_user["id"],
        data.name.strip() if data.name else None,
        device["id"],
    )
    await db.execute(
        """
        INSERT INTO device_thresholds(device_id)
        VALUES ($1)
        ON CONFLICT (device_id) DO NOTHING
        """,
        device["id"],
    )
    return {"status": "adopted", "device_id": device_id}


@router.get("/{device_id}/thresholds")
async def get_thresholds(device_id: str, current_user=Depends(get_current_user)):
    row = await db.fetchrow(
        """
        SELECT dt.temp_min, dt.temp_max, dt.hum_min, dt.hum_max, dt.co2_max, dt.notify_enabled, dt.updated_at
        FROM device_thresholds dt
        JOIN devices d ON d.id = dt.device_id
        WHERE d.owner_user_id = $1 AND d.device_id = $2
        """,
        current_user["id"],
        device_id,
    )
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device thresholds not found")
    return dict(row)


@router.put("/{device_id}/thresholds")
async def update_thresholds(device_id: str, data: ThresholdsUpdateRequest, current_user=Depends(get_current_user)):
    device = await db.fetchrow(
        """
        SELECT id
        FROM devices
        WHERE owner_user_id = $1 AND device_id = $2
        """,
        current_user["id"],
        device_id,
    )
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")

    await db.execute(
        """
        INSERT INTO device_thresholds(device_id, temp_min, temp_max, hum_min, hum_max, co2_max, notify_enabled)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (device_id)
        DO UPDATE SET temp_min = EXCLUDED.temp_min,
                      temp_max = EXCLUDED.temp_max,
                      hum_min = EXCLUDED.hum_min,
                      hum_max = EXCLUDED.hum_max,
                      co2_max = EXCLUDED.co2_max,
                      notify_enabled = EXCLUDED.notify_enabled,
                      updated_at = now()
        """,
        device["id"],
        data.temp_min,
        data.temp_max,
        data.hum_min,
        data.hum_max,
        data.co2_max,
        data.notify_enabled,
    )
    return {"status": "updated", "device_id": device_id}
