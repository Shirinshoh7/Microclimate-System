from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from ...core.database import db
from ...core.security import create_access_token, hash_password, verify_password
from ..deps import get_current_user
from fastapi import Depends

router = APIRouter(prefix="/api/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    login: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=6, max_length=128)
    device_id: str | None = Field(default=None, min_length=3, max_length=128)
    esp_number: str | None = Field(default=None, min_length=3, max_length=128)
    device_secret: str | None = Field(default=None, min_length=1, max_length=256)


class LoginRequest(BaseModel):
    login: str
    password: str


@router.post("/register")
async def register(data: RegisterRequest):
    device_code = (data.device_id or data.esp_number or "").strip()

    existing = await db.fetchrow(
        "SELECT id FROM users WHERE login = $1",
        data.login,
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Login already exists",
        )

    existing_device = None
    if device_code:
        existing_device = await db.fetchrow(
            "SELECT id, owner_user_id FROM devices WHERE device_id = $1",
            device_code,
        )
        if (
            existing_device
            and existing_device["owner_user_id"]
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Device already claimed",
            )

    password_hash = hash_password(data.password)
    user = await db.fetchrow(
        """
        INSERT INTO users(login, password_hash)
        VALUES ($1, $2)
        RETURNING id, login, created_at
        """,
        data.login,
        password_hash,
    )

    attached_device_id = None
    if device_code:
        if existing_device:
            device_uuid = existing_device["id"]
            await db.execute(
                """
                UPDATE devices
                SET owner_user_id = $1
                WHERE id = $2
                """,
                user["id"],
                device_uuid,
            )
        else:
            device_secret = (data.device_secret or data.password).strip()
            secret_hash = hash_password(device_secret)
            device = await db.fetchrow(
                """
                INSERT INTO devices(device_id, secret_hash, owner_user_id, name)
                VALUES ($1, $2, $3, $4)
                RETURNING id
                """,
                device_code,
                secret_hash,
                user["id"],
                device_code,
            )
            device_uuid = device["id"]

        await db.execute(
            "INSERT INTO device_thresholds(device_id) VALUES ($1) ON CONFLICT (device_id) DO NOTHING",
            device_uuid,
        )
        attached_device_id = device_code

    response = {
        "id": str(user["id"]),
        "login": user["login"],
        "created_at": user["created_at"],
    }
    if attached_device_id:
        response["device_id"] = attached_device_id
    return response


@router.post("/login")
async def login(data: LoginRequest):
    user = await db.fetchrow(
        "SELECT id, login, password_hash FROM users WHERE login = $1",
        data.login,
    )
    if not user or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid login or password",
        )

    token = create_access_token(str(user["id"]), user["login"])
    return {"access_token": token, "token_type": "bearer"}


@router.get("/me")
async def me(current_user=Depends(get_current_user)):
    return {
        "id": str(current_user["id"]),
        "login": current_user["login"],
        "created_at": current_user["created_at"],
    }
