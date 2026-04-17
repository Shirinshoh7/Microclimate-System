\"\"\"API routes for climate data retrieval and real-time monitoring.

Provides endpoints for:
- Current sensor readings with forecasted values
- WebSocket connections for real-time data streaming
- Prediction verification and historical analysis
\"\"\"
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, status

from ..deps import get_current_user, get_owned_device
from ...core.database import db
from ...core.storage import storage
from ...services.ai_service import ai_service

router = APIRouter(prefix="/api", tags=["climate"])

# Forecast horizons in minutes (for user preference and step calculation)
SUPPORTED_HORIZONS_MIN = {
    "30m": 30,      # 30-minute forecast
    "3h": 180,      # 3-hour forecast
    "24h": 1440,    # 24-hour forecast
}
# ESP32 sensor data is sampled every 5 seconds
SAMPLE_PERIOD_SEC = 5


@router.get("/now")
async def get_current_data(
    forecast: str = "30m",
    forecast_min: int | None = None,
    device_id: str | None = None,
    current_user=Depends(get_current_user),
):
    """
    Retrieve current climate data with Holt-Winters AI forecast.
    
    Args:
        forecast: Forecast horizon - \"30m\" (30 minutes), \"3h\" (3 hours), or \"24h\" (24 hours)
        forecast_min: Custom forecast duration in minutes (overrides forecast parameter)
        device_id: Device ID to query (defaults to first device of current user)
        current_user: Current authenticated user dependency
        
    Returns:
        dict: Current sensor values and predictions for temperature, humidity, CO2, CO
    """
    device = await get_owned_device(current_user["id"], device_id)
    latest = await db.fetchrow(
        """
        SELECT ts, temperature, humidity, co2, co
        FROM device_latest
        WHERE device_id = $1
        """,
        device["id"],
    )
    if not latest:
        return {"error": "no_data", "message": "Нет данных для устройства"}
    
    # Определение горизонта прогноза
    if forecast_min is not None:
        target_minutes = max(1, int(forecast_min))
    else:
        target_minutes = SUPPORTED_HORIZONS_MIN.get(forecast, 30)

    # Шаг = 5 секунд → переводим минуты в секунды и делим на SAMPLE_PERIOD_SEC
    steps_ahead = max(1, round(target_minutes * 60 / SAMPLE_PERIOD_SEC))

    # Загружаем последние 1000 точек — достаточно для метода Хольта при шаге 5 сек
    history_rows = await db.fetch(
        """
        SELECT temperature, humidity, co2, co
        FROM sensor_readings
        WHERE device_id = $1
        ORDER BY ts DESC
        LIMIT 1000
        """,
        device["id"],
    )
    temp_history = [float(row["temperature"] or 0) for row in reversed(history_rows)]
    hum_history = [float(row["humidity"] or 0) for row in reversed(history_rows)]
    co2_history = [float(row["co2"] or 0) for row in reversed(history_rows)]
    co_history = [float(row["co"] or 0) for row in reversed(history_rows)]

    current_payload = {
        "temperature": float(latest["temperature"] or 0),
        "humidity": float(latest["humidity"] or 0),
        "co2_ppm": float(latest["co2"] or 0),
        "co_ppm": float(latest["co"] or 0),
        "timestamp": latest["ts"].isoformat(),
    }

    # -----------------------------------------------------------------------
    # 1. ЭКСТРЕННАЯ ПРОВЕРКА — выполняется первой, до расчёта прогноза.
    #    Анализирует текущий снимок данных в реальном времени.
    #    Работает параллельно и независимо от прогноза Хольта:
    #    прогноз оценивает будущее, а emergency_alert — опасность прямо сейчас.
    # -----------------------------------------------------------------------
    emergency_alert = ai_service.check_emergency_status({
        "temperature": current_payload["temperature"],
        "co":          current_payload["co_ppm"],
        "co2":         current_payload["co2_ppm"],
    })

    # -----------------------------------------------------------------------
    # 2. ПРОГНОЗ ХОЛЬТА — рассчитывается после проверки на экстренный случай.
    # -----------------------------------------------------------------------
    predictions = {
        "temperature": ai_service.predict_holt(temp_history, steps_ahead),
        "humidity": ai_service.predict_holt(hum_history, steps_ahead),
        "co2": ai_service.predict_holt(co2_history, steps_ahead),
        "co": ai_service.predict_holt(co_history, steps_ahead),
    }

    return {
        "current": {
            "temp": current_payload["temperature"],
            "hum": current_payload["humidity"],
            "co2": current_payload["co2_ppm"],
            "co": current_payload["co_ppm"],
        },
        # Блок экстренного оповещения.
        # Если emergency_call=true — мобильное приложение включает сирену и TTS.
        "emergency_alert": emergency_alert,
        "predictions": predictions,
        "forecast": {
            "label": forecast if forecast in SUPPORTED_HORIZONS_MIN else f"{target_minutes}m",
            "minutes": target_minutes,
            "steps_ahead": steps_ahead,
            "sample_period_sec": SAMPLE_PERIOD_SEC,
        },
        "device_id": device["device_id"],
        "timestamp": current_payload["timestamp"],
        "profile": "device_thresholds",
    }


@router.get("/stats")
async def get_statistics(device_id: str | None = None, current_user=Depends(get_current_user)):
    device = await get_owned_device(current_user["id"], device_id)
    rows = await db.fetch(
        """
        SELECT temperature, humidity, co2, co
        FROM sensor_readings
        WHERE device_id = $1
        ORDER BY ts DESC
        LIMIT 1000
        """,
        device["id"],
    )
    if not rows:
        return {"error": "no_data"}

    temps = [float(r["temperature"] or 0) for r in rows]
    hums = [float(r["humidity"] or 0) for r in rows]
    co2s = [float(r["co2"] or 0) for r in rows]
    cos = [float(r["co"] or 0) for r in rows]
    return {
        "measurements": len(rows),
        "device_id": device["device_id"],
        "temperature": {
            "current": temps[0],
            "min": min(temps),
            "max": max(temps),
            "avg": round(sum(temps) / len(temps), 1)
        },
        "humidity": {
            "current": hums[0],
            "min": min(hums),
            "max": max(hums),
            "avg": round(sum(hums) / len(hums), 1)
        },
        "co2": {
            "current": co2s[0],
            "min": min(co2s),
            "max": max(co2s),
            "avg": round(sum(co2s) / len(co2s), 1)
        },
        "co": {
            "current": cos[0],
            "min": min(cos),
            "max": max(cos),
            "avg": round(sum(cos) / len(cos), 1),
        },
    }


@router.websocket("/ws/realtime")
async def websocket_endpoint(websocket: WebSocket):
    """
    WebSocket для real-time обновлений
    """
    await websocket.accept()
    storage.add_websocket(websocket)
    
    client_id = id(websocket)
    print(f"✅ WebSocket [{client_id}] подключен. Всего: {len(storage.active_websockets)}")
    
    try:
        # Отправляем текущие данные сразу
        if storage.current_data["timestamp"]:
            await websocket.send_json(storage.current_data)
        
        # Держим соединение
        while True:
            try:
                message = await websocket.receive_text()
                if message == "ping":
                    await websocket.send_text("pong")
            except WebSocketDisconnect:
                break
                
    except Exception as e:
        print(f"❌ WebSocket [{client_id}] ошибка: {e}")
        
    finally:
        storage.remove_websocket(websocket)
        print(f"❌ WebSocket [{client_id}] отключен. Осталось: {len(storage.active_websockets)}")
