from fastapi import APIRouter
from pydantic import BaseModel

from ..deps import get_current_user
from fastapi import Depends
from ...core.database import db
from ...services.firebase_service import firebase_service

router = APIRouter(prefix="/api/push", tags=["push-notifications"])


class TokenRegister(BaseModel):
    token: str
    platform: str = "android"


class TokenUnregister(BaseModel):
    token: str


class PushTestRequest(BaseModel):
    title: str = "Тестовое уведомление"
    body: str = "FCM работает корректно"


@router.post("/register")
async def register_token(data: TokenRegister, current_user=Depends(get_current_user)):
    await db.execute(
        """
        INSERT INTO user_fcm_tokens(user_id, token)
        VALUES ($1, $2)
        ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id
        """,
        current_user["id"],
        data.token,
    )
    total = await db.fetchrow(
        "SELECT count(*)::int AS total FROM user_fcm_tokens WHERE user_id = $1",
        current_user["id"],
    )
    return {
        "status": "registered",
        "user_id": str(current_user["id"]),
        "tokens": total["total"],
        "platform": data.platform,
    }


@router.post("/unregister")
async def unregister_token(data: TokenUnregister, current_user=Depends(get_current_user)):
    await db.execute(
        "DELETE FROM user_fcm_tokens WHERE user_id = $1 AND token = $2",
        current_user["id"],
        data.token,
    )
    total = await db.fetchrow(
        "SELECT count(*)::int AS total FROM user_fcm_tokens WHERE user_id = $1",
        current_user["id"],
    )
    return {"status": "unregistered", "user_id": str(current_user["id"]), "tokens": total["total"]}


@router.post("/test")
async def send_test_push(data: PushTestRequest, current_user=Depends(get_current_user)):
    rows = await db.fetch(
        "SELECT token FROM user_fcm_tokens WHERE user_id = $1",
        current_user["id"],
    )
    sent = firebase_service.send_push_to_tokens(
        [r["token"] for r in rows],
        title=data.title,
        body=data.body,
        data={"type": "manual_test"},
    )
    return {"status": "sent" if sent else "not_sent", "user_id": str(current_user["id"])}


@router.get("/stats")
async def push_stats(current_user=Depends(get_current_user)):
    total = await db.fetchrow(
        "SELECT count(*)::int AS total FROM user_fcm_tokens WHERE user_id = $1",
        current_user["id"],
    )
    return {"user_id": str(current_user["id"]), "tokens": total["total"]}
