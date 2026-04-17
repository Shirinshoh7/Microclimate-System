"""
MQTT service for receiving real-time sensor data from ESP32 IoT devices.

Handles MQTT connection, authentication, message parsing, and data ingestion
into the database. Also manages emergency alert generation for critical conditions.
"""
import paho.mqtt.client as mqtt
import json
import ssl
import asyncio
import time
from typing import Optional
from ..config import settings
from ..core.database import db
from ..core.storage import storage


class MQTTService:
    """Service for managing MQTT broker connections and real-time data ingestion.
    
    Responsibilities:
    - Connect and authenticate with MQTT broker
    - Subscribe to configured topics and receive sensor messages
    - Parse and validate sensor data
    - Store data in database and trigger alerts on anomalies
    """
    
    def __init__(self):
        self.client: Optional[mqtt.Client] = None
        self.event_loop: Optional[asyncio.AbstractEventLoop] = None
        self._danger_state_by_device: dict[str, bool] = {}
        self._last_alert_ts_by_device: dict[str, float] = {}
    
    def setup(self, event_loop: asyncio.AbstractEventLoop):
        """Initialize MQTT client with callbacks and security settings.
        
        Args:
            event_loop: AsyncIO event loop for background operations
        """
        self.event_loop = event_loop
        
        self.client = mqtt.Client(
            client_id="backend_microclimate_prod_v2",
            protocol=mqtt.MQTTv311
        )
        
        # Register event callbacks for connection, message, and disconnection
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message
        self.client.on_disconnect = self._on_disconnect
        
        # Set MQTT broker authentication credentials
        self.client.username_pw_set(
            settings.MQTT_USER,
            settings.MQTT_PASSWORD
        )
        
        # Configure TLS/SSL encryption for secure connection
        self.client.tls_set(cert_reqs=ssl.CERT_NONE)
        self.client.tls_insecure_set(True)
    
    def connect(self):
        """Establish connection to MQTT broker and start background message loop.
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            self.client.connect(
                settings.MQTT_HOST,
                settings.MQTT_PORT,
                60
            )
            self.client.loop_start()
            print(f"✅ MQTT connected to {settings.MQTT_HOST}:{settings.MQTT_PORT}")
            return True
        except Exception as e:
            print(f"❌ MQTT connection error: {e}")
            return False

    def _build_alert_message(self, data: dict, profile: dict, issues: list[str]) -> str:
        """Build human-readable alert message based on violated thresholds.
        
        Args:
            data: Current sensor readings (temperature, humidity, CO2, CO)
            profile: User's climate profile with threshold values
            issues: List of parameter names that exceeded thresholds
            
        Returns:
            str: Formatted alert message for push notification
        """
        profile_name = profile.get("name", "Профиль")
        parts: list[str] = []

        temp = float(data.get("temperature", 0))
        hum = float(data.get("humidity", 0))
        co2 = float(data.get("co2_ppm", 0))
        co = float(data.get("co_ppm", data.get("co", 0)))

        if "temperature" in issues:
            tmin = profile.get("temp_min")
            tmax = profile.get("temp_max")
            if tmin is not None and tmax is not None:
                parts.append(f"temperature {temp:.1f}°C (normal range {tmin}-{tmax}°C)")
            else:
                parts.append(f"temperature {temp:.1f}°C out of range")
        if "humidity" in issues:
            hmax = profile.get("humidity_max")
            if hmax is not None:
                parts.append(f"humidity {hum:.0f}% (max {hmax}%)")
            else:
                parts.append(f"humidity {hum:.0f}% out of range")
        if "co2_ppm" in issues:
            cmax = profile.get("co2_max")
            if cmax is not None:
                parts.append(f"CO2 {co2:.0f} ppm (max {cmax})")
            else:
                parts.append(f"CO2 {co2:.0f} ppm out of range")
        if "co_ppm" in issues:
            comax = profile.get("co_max")
            if comax is not None:
                parts.append(f"CO {co:.1f} ppm (max {comax})")
            else:
                parts.append(f"CO {co:.1f} ppm out of range")
        if not parts:
            parts.append("parameter values out of range")

        return f"{profile_name}: {', '.join(parts)}. Проверьте помещение."

    def _build_alert_message_from_triggers(self, data: dict, trigger_types: list[str]) -> str:
        """Формирует короткий понятный текст по кодам алертов."""
        temp = float(data.get("temperature", 0))
        hum = float(data.get("humidity", 0))
        co2 = float(data.get("co2_ppm", 0))
        co = float(data.get("co_ppm", data.get("co", 0)))

        parts: list[str] = []
        for trigger in trigger_types:
            if trigger in {"TEMP_LOW", "TEMP_HIGH"}:
                parts.append(f"Температура {temp:.1f}°C вне нормы")
            elif trigger in {"HUM_LOW", "HUM_HIGH"}:
                parts.append(f"Влажность {hum:.0f}% вне нормы")
            elif trigger == "CO2_HIGH":
                parts.append(f"CO2 {co2:.0f} ppm выше нормы")
            elif trigger == "CO_HIGH":
                parts.append(f"CO {co:.1f} ppm выше нормы")

        # Убираем дубли при нескольких одинаковых кодах
        unique = list(dict.fromkeys(parts))
        if not unique:
            return "Параметры микроклимата вне нормы"
        return " | ".join(unique)
    
    def disconnect(self):
        """Отключение от MQTT"""
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()
            print("✅ MQTT отключен")
    
    def _on_connect(self, client, userdata, flags, rc):
        """Callback при подключении"""
        if rc == 0:
            print("✅ MQTT подключен к HiveMQ Cloud!")
            # Wildcard — ловим все устройства + discovery
            client.subscribe("iot/microclimate/+")
            print("📡 Подписка: iot/microclimate/+  (все станции + discovery)")
        else:
            error_msgs = {
                1: "Неверная версия протокола",
                2: "Неверный client ID",
                3: "Сервер недоступен",
                4: "Неверный логин/пароль",
                5: "Не авторизован"
            }
            print(f"❌ MQTT ошибка: {error_msgs.get(rc, f'Код {rc}')}")
    
    def _on_message(self, client, userdata, msg):
        """Callback при получении сообщения"""
        try:
            topic = msg.topic                          # "iot/microclimate/A1B2C3D4E5F6"
            segment = topic.split("/")[-1]             # "A1B2C3D4E5F6" или "discovery"

            payload = json.loads(msg.payload.decode('utf-8'))

            # --- Discovery: станция сообщает своё имя ---
            if segment == "discovery":
                if self.event_loop:
                    asyncio.run_coroutine_threadsafe(
                        self._handle_discovery(payload), self.event_loop
                    )
                return

            # --- Данные сенсоров: device_id берём из топика (MAC-адрес) ---
            device_id = segment

            data = {
                "temperature": float(payload.get("temperature", 0)),
                "humidity": float(payload.get("humidity", 0)),
                "co2_ppm": float(payload.get("co2_ppm", 0)),
                "co_ppm": float(payload.get("co_ppm", payload.get("co", 0))),
                "device_id": device_id,
            }

            storage.update_current_data(data)

            print(f"[{device_id}] T={data['temperature']:.1f}°C "
                  f"H={data['humidity']:.0f}% "
                  f"CO2={data['co2_ppm']:.0f}ppm "
                  f"CO={data['co_ppm']:.1f}ppm")

            if self.event_loop:
                asyncio.run_coroutine_threadsafe(
                    self._persist_to_db_and_alert(data), self.event_loop
                )

            if self.event_loop:
                from ..services.websocket_service import websocket_service
                from ..services.ai_service import ai_service

                # Добавляем блок экстренного оповещения в WebSocket-пакет.
                # Телефон получает emergency_alert в реальном времени (каждые 5 сек),
                # не дожидаясь следующего REST-запроса /api/now.
                emergency_alert = ai_service.check_emergency_status({
                    "temperature": data["temperature"],
                    "co":          data["co_ppm"],
                    "co2":         data["co2_ppm"],
                })
                ws_payload = {**storage.current_data, "emergency_alert": emergency_alert}

                asyncio.run_coroutine_threadsafe(
                    websocket_service.broadcast(ws_payload),
                    self.event_loop
                )

        except Exception as e:
            print(f"❌ Ошибка обработки MQTT: {e}")

    async def _handle_discovery(self, payload: dict) -> None:
        """Регистрирует устройство если его нет, обновляет имя если есть."""
        try:
            device_topic = payload.get("topic", "")
            name = payload.get("name", "").strip()
            if not device_topic or not name:
                return
            device_id = device_topic.split("/")[-1]

            # Проверяем — есть ли устройство в БД
            existing = await db.fetchrow(
                "SELECT id FROM devices WHERE device_id = $1",
                device_id,
            )

            if not existing:
                # Устройство новое — создаём с пустым owner и именем из discovery
                from ..core.security import hash_password
                import secrets
                secret_hash = hash_password(secrets.token_hex(16))
                await db.execute(
                    """
                    INSERT INTO devices(device_id, secret_hash, name)
                    VALUES ($1, $2, $3)
                    ON CONFLICT (device_id) DO NOTHING
                    """,
                    device_id,
                    secret_hash,
                    name,
                )
                print(f"✅ Discovery: новое устройство зарегистрировано {device_id} → '{name}'")
            else:
                # Устройство есть — обновляем имя только если не задано вручную
                await db.execute(
                    """
                    UPDATE devices SET name = $1
                    WHERE device_id = $2 AND (name IS NULL OR name = '')
                    """,
                    name,
                    device_id,
                )
                print(f"📍 Discovery: {device_id} → '{name}'")
        except Exception as e:
            print(f"❌ Discovery ошибка: {e}")

    async def _persist_to_db_and_alert(self, data: dict) -> None:
        try:
            result = await db.ingest_sensor_data(
                device_code=str(data["device_id"]),
                temperature=float(data["temperature"]),
                humidity=float(data["humidity"]),
                co2=float(data["co2_ppm"]),
                co=float(data["co_ppm"]),
            )
            if not result.get("known_device"):
                return

            # --- Сохранение прогнозов (30м, 3ч, 24ч) ---
            await self._save_predictions(result["device_uuid"])

            triggered_types = result.get("triggered_types", [])
            owner_user_id = result.get("owner_user_id")
            if not triggered_types or not owner_user_id:
                return

            device_id = str(data["device_id"])
            now_ts = time.time()
            cooldown = max(0, int(settings.FCM_DANGER_REMINDER_SEC))
            last_alert_ts = self._last_alert_ts_by_device.get(device_id, 0.0)
            if cooldown and (now_ts - last_alert_ts) < cooldown:
                return

            rows = await db.fetch(
                "SELECT token FROM user_fcm_tokens WHERE user_id = $1",
                owner_user_id,
            )
            tokens = [row["token"] for row in rows]
            if not tokens:
                return

            from ..services.firebase_service import firebase_service

            issue_by_trigger = {
                "TEMP_LOW": "temperature",
                "TEMP_HIGH": "temperature",
                "HUM_LOW": "humidity",
                "HUM_HIGH": "humidity",
                "CO2_HIGH": "co2_ppm",
                "CO_HIGH": "co_ppm",
            }
            issues = list(
                {
                    issue_by_trigger[t]
                    for t in triggered_types
                    if t in issue_by_trigger
                }
            )
            device_uuid = result.get("device_uuid")
            profile_row = await db.fetchrow(
                """
                SELECT d.name, dt.temp_min, dt.temp_max, dt.hum_max, dt.co2_max
                FROM devices d
                LEFT JOIN device_thresholds dt ON dt.device_id = d.id
                WHERE d.id = $1
                """,
                device_uuid,
            )
            profile = {
                "name": (
                    profile_row["name"]
                    if profile_row and profile_row["name"]
                    else f"Устройство {device_id}"
                ),
                "temp_min": profile_row["temp_min"] if profile_row else None,
                "temp_max": profile_row["temp_max"] if profile_row else None,
                "humidity_max": profile_row["hum_max"] if profile_row else None,
                "co2_max": profile_row["co2_max"] if profile_row else None,
                "co_max": None,
            }

            room_name = profile["name"]
            alert_title = f"⚠️ {room_name}: вне нормы"
            alert_body = self._build_alert_message_from_triggers(data, triggered_types)
            sent = firebase_service.send_push_to_tokens(
                tokens=tokens,
                title=alert_title,
                body=alert_body,
                data={
                    "type": "danger",
                    "device_id": device_id,
                    "alerts": ",".join(triggered_types),
                },
            )
            if sent:
                self._last_alert_ts_by_device[device_id] = now_ts
        except Exception as e:
            print(f"❌ Ошибка сохранения данных в БД: {e}")
    
    async def _save_predictions(self, device_uuid: str) -> None:
        """
        Извлекает последние 1000 записей из БД, строит прогнозы методом Хольта
        на 3 горизонта (30m / 3h / 24h) и сохраняет в таблицу predictions.

        Данные поступают каждые 5 секунд (SAMPLE_PERIOD_SEC = 5):
            30m  →  30 * 60 / 5 =   360 шагов
            3h   → 180 * 60 / 5 =  2160 шагов
            24h  → 1440 * 60 / 5 = 17280 шагов
        """
        from datetime import datetime, timezone
        from ..services.ai_service import ai_service

        SAMPLE_PERIOD_SEC = 5
        # (горизонт в минутах, шагов вперёд)
        horizons_cfg = [
            (30,   30   * 60 // SAMPLE_PERIOD_SEC),   # 360
            (180,  180  * 60 // SAMPLE_PERIOD_SEC),   # 2160
            (1440, 1440 * 60 // SAMPLE_PERIOD_SEC),   # 17280
        ]

        try:
            rows = await db.fetch(
                """
                SELECT temperature, humidity, co2, co
                FROM sensor_readings
                WHERE device_id = $1
                ORDER BY ts DESC
                LIMIT 1000
                """,
                device_uuid,
            )
            if len(rows) < 2:
                return

            # Формируем списки значений (от старого к новому)
            temps = [float(r["temperature"] or 0) for r in reversed(rows)]
            hums  = [float(r["humidity"]    or 0) for r in reversed(rows)]
            co2s  = [float(r["co2"]         or 0) for r in reversed(rows)]
            cos   = [float(r["co"]          or 0) for r in reversed(rows)]

            horizons = []
            for h_min, steps in horizons_cfg:
                horizons.append((h_min, {
                    "temperature": ai_service.predict_holt(temps, steps_ahead=steps),
                    "humidity":    ai_service.predict_holt(hums,  steps_ahead=steps),
                    "co2_ppm":     ai_service.predict_holt(co2s,  steps_ahead=steps),
                    "co_ppm":      ai_service.predict_holt(cos,   steps_ahead=steps),
                }))

            now_ts = datetime.now(timezone.utc)
            await db.save_predictions(
                device_uuid=device_uuid,
                now_ts=now_ts,
                horizons=horizons,
            )
        except Exception as e:
            print(f"❌ save_predictions: {e}")

    def _on_disconnect(self, client, userdata, rc):
        """Callback при отключении"""
        if rc != 0:
            print(f"⚠️ MQTT отключен. Переподключение...")


# Глобальный экземпляр сервиса
mqtt_service = MQTTService()
