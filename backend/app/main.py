"""
Main entry point for the MicroClimate AI Pro Backend application.

This module initializes the FastAPI application, configures middleware (CORS),
registers API routers, and manages startup/shutdown events for external services
like MQTT and Firebase.
"""
import asyncio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from .config import settings
from .core.database import db
from .services.mqtt_service import mqtt_service
from .services.firebase_service import firebase_service
from .core.storage import storage

# Import API route modules
from .api.routes import auth, climate, devices, history, profiles, push, test


app = FastAPI(
    title=settings.APP_NAME,
    description="Real-Time IoT Backend with MQTT and WebSocket support for climate monitoring",
    version=settings.APP_VERSION
)

# Configure CORS middleware for development
# WARNING: Production should restrict origins to specific domains
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # Allow all origins (DEV only, restrict in production)
    allow_credentials=False,      # Must be False when allow_origins=["*"]
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)


# Register API route handlers
app.include_router(climate.router)
app.include_router(auth.router)
app.include_router(devices.router)
app.include_router(profiles.router)
app.include_router(history.router)
app.include_router(test.router)
app.include_router(push.router)


@app.on_event("startup")
async def startup_event():
    print("\n" + "=" * 70)
    print(f"🚀 {settings.APP_NAME} v{settings.APP_VERSION}")
    print("=" * 70)

    # Initialize database connection pool
    await db.connect()

    # Initialize Firebase Cloud Messaging service
    firebase_service.init_firebase()

    # Setup and connect MQTT broker client
    loop = asyncio.get_event_loop()
    mqtt_service.setup(loop)

    if mqtt_service.connect():
        print("✅ MQTT client connected")
        print(f"📡 Broker: {settings.MQTT_HOST}:{settings.MQTT_PORT}")
        print(f"📬 Topic: {settings.MQTT_TOPIC}")
    else:
        print("⚠️ Backend running without MQTT")

    # Background tasks: verify predictions (hourly) and cleanup old data (daily)
    asyncio.create_task(_hourly_verify())
    asyncio.create_task(_daily_cleanup())

    print("=" * 70 + "\n")


async def _hourly_verify():
    """
    Periodically verify predictions against actual data (hourly).
    
    Compares previously forecasted values with actual sensor readings
    to evaluate model accuracy and identify drift.
    """
    while True:
        await asyncio.sleep(3600)
        try:
            await db.verify_predictions()
        except Exception as e:
            print(f"❌ verify_predictions: {e}")


async def _daily_cleanup():
    """
    Remove stale prediction data (daily).
    
    Cleans up forecasts older than 48 hours to optimize database storage.
    """
    while True:
        await asyncio.sleep(86400)
        try:
            await db.cleanup_old_predictions()
        except Exception as e:
            print(f"❌ cleanup_old_predictions: {e}")


@app.on_event("shutdown")
async def shutdown_event():
    print("\n🛑 Остановка сервиса...")
    mqtt_service.disconnect()
    await db.disconnect()
    print("✅ Сервис остановлен")


@app.get("/")
async def root():
    return {
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "online",
        "parameters": ["temperature", "humidity", "co2_ppm", "co_ppm"],
        "mqtt": {
            "broker": settings.MQTT_HOST,
            "port": settings.MQTT_PORT,
            "topic": settings.MQTT_TOPIC,
            "connected": mqtt_service.client.is_connected() if mqtt_service.client else False
        },
        "websockets": len(storage.active_websockets),
        "last_update": storage.current_data.get("timestamp"),
        "measurements": len(storage.data_history)
    }


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=settings.SERVER_HOST,     # совет: поставь 0.0.0.0 если нужно с телефона
        port=settings.SERVER_PORT,
        reload=settings.DEBUG,
        log_level="info",
        ws_ping_interval=30,
        ws_ping_timeout=60,
    )
