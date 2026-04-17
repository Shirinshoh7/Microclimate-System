from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import jwt

from ..core.database import db
from ..core.security import decode_access_token

auth_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(auth_scheme),
):
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )

    token = credentials.credentials
    try:
        payload = decode_access_token(token)
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    user = await db.fetchrow(
        "SELECT id, login, created_at FROM users WHERE id = $1",
        user_id,
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return user


async def get_owned_device(user_id: str, device_code: str | None):
    """
    Возвращает устройство пользователя по device_code (MAC/идентификатор).
    Если device_code не указан:
      - 1 устройство → возвращает его автоматически
      - 2+ устройства → 422 с подсказкой указать device_id
      - 0 устройств → 404
    """
    if device_code:
        row = await db.fetchrow(
            """
            SELECT id, device_id, name
            FROM devices
            WHERE owner_user_id = $1 AND device_id = $2
            """,
            user_id,
            device_code,
        )
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Устройство '{device_code}' не найдено или не принадлежит вам",
            )
        return row

    # device_code не указан — проверяем сколько устройств у пользователя
    rows = await db.fetch(
        """
        SELECT id, device_id, name
        FROM devices
        WHERE owner_user_id = $1
        ORDER BY created_at ASC
        """,
        user_id,
    )
    if not rows:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="У вас нет зарегистрированных устройств",
        )
    if len(rows) == 1:
        return rows[0]

    # Несколько устройств — требуем явного указания
    device_ids = [r["device_id"] for r in rows]
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail={
            "message": "У вас несколько устройств. Укажите параметр device_id.",
            "available_devices": device_ids,
        },
    )
