from typing import List, Dict

# Holt-Winters Double Exponential Smoothing coefficients
ALPHA = 0.9   # Level smoothing coefficient (weight for current observation)
BETA  = 0.1   # Trend smoothing coefficient (weight for trend direction)

# Maximum number of historical data points used for Holt-Winters calculation
HISTORY_WINDOW = 1000

# ---------------------------------------------------------------------------
# Emergency thresholds for critical condition alerts
# Emergency detection runs in parallel with Holt-Winters forecasting:
# - Each /api/now response includes both forecast and emergency_alert sections
# - Alerts are sent immediately when thresholds are exceeded
# ---------------------------------------------------------------------------
EMERGENCY_THRESHOLDS = {
    "temperature": 60.0,   # °C - Fire detection threshold
    "co":          100.0,  # ppm - Carbon monoxide lethal exposure
    "co2":         5000.0, # ppm - Critical CO2 concentration
}

# Text-to-speech (TTS) alert messages for critical conditions
# Mobile app renders these through device TTS engine for immediate user notification
TTS_FIRE    = "Alert! Possible fire detected! Evacuate immediately and call fire department!"
TTS_CO      = "Alert! Carbon monoxide leak detected! Evacuate immediately!"
TTS_CO2     = "Alert! Critical CO2 level! Ventilate room and go outside!"
TTS_MULTI   = "Alert! Multiple critical threats detected! Evacuate immediately and call emergency services!"


class AIService:
    """Climate parameter forecasting service using Holt-Winters method.
    
    Implements Double Exponential Smoothing (Holt's method) for time-series forecasting
    of temperature, humidity, CO2, and CO levels. Also monitors for emergency conditions
    (fire, gas leaks) and triggers alerts when critical thresholds are exceeded.
    """

    # ------------------------------------------------------------------
    # Forecasting using Holt-Winters Double Exponential Smoothing
    # ------------------------------------------------------------------

    @staticmethod
    def predict_holt(data_points: List[float], steps_ahead: int = 1) -> float:
        """Forecast using Holt-Winters Double Exponential Smoothing.

        Args:
            data_points: Historical sensor values (minimum 2 points)
            steps_ahead: Number of steps to forecast ahead
                        (step = 5 seconds per ESP32 reading interval)

        Returns:
            float: Rounded predicted value
        """
        # Limit history to last HISTORY_WINDOW data points
        data = data_points[-HISTORY_WINDOW:]
        n = len(data)

        if n < 2:
            return round(data[-1], 1) if data else 0.0

        # Initialize: level = first point, trend = slope between first two
        level = data[0]
        trend = data[1] - data[0]

        for i in range(1, n):
            prev_level = level
            level = ALPHA * data[i] + (1 - ALPHA) * (level + trend)
            trend = BETA * (level - prev_level) + (1 - BETA) * trend

        prediction = level + trend * steps_ahead
        return round(prediction, 1)

    def get_forecast(self, data: List[float], mode: str) -> Dict:
        """High-level forecast generation by horizon (30m, 3h, 24h).

        Data arrives from ESP32 every 5 seconds (SAMPLE_PERIOD_SEC = 5).
        Horizons are converted to steps:
            30m  →  30 * 60 / 5 =   360 steps
            3h   → 180 * 60 / 5 =  2160 steps
            24h  → 1440 * 60 / 5 = 17280 steps
        """
        steps_map = {
            "30m":  360,
            "3h":   2160,
            "24h":  17280,
        }

        steps = steps_map.get(mode, 1)
        predicted_value = self.predict_holt(data, steps_ahead=steps)

        current_value = data[-1] if data else 0
        delta = round(predicted_value - current_value, 1)

        return {
            "target_value": predicted_value,
            "delta": delta,
            "trend": "up" if delta > 0 else "down" if delta < 0 else "stable",
            "message": f"За {mode}: значение может {'вырасти' if delta > 0 else 'упасть'} на {abs(delta)}",
        }

    # ------------------------------------------------------------------
    # Экстренное оповещение — проверка в реальном времени
    # Работает независимо от прогноза: анализирует текущий снимок данных,
    # не требует истории и не зависит от шага дискретизации.
    # ------------------------------------------------------------------

    @staticmethod
    def check_emergency_status(current_data: Dict) -> Dict:
        """
        Проверяет текущие показания датчиков на критические пороги.

        Вызывается при каждом запросе /api/now параллельно с прогнозом Хольта.
        При обнаружении опасности возвращает флаг emergency_call=True и
        инструкции для мобильного приложения (сирена + TTS).

        Args:
            current_data: словарь с ключами temperature, co, co2 (числа).

        Returns:
            Словарь блока "emergency_alert" для JSON-ответа.
        """
        triggered: List[str] = []
        fire_triggered = False
        co_triggered   = False
        co2_triggered  = False

        temp = current_data.get("temperature", 0)
        co   = current_data.get("co",   0)
        co2  = current_data.get("co2",  0)

        if temp > EMERGENCY_THRESHOLDS["temperature"]:
            triggered.append(f"ОПАСНОСТЬ: Высокая температура ({temp}°C)! Возможен пожар.")
            fire_triggered = True

        if co > EMERGENCY_THRESHOLDS["co"]:
            triggered.append(f"ОПАСНОСТЬ: Высокий уровень CO ({co} ppm)! Угарный газ.")
            co_triggered = True

        if co2 > EMERGENCY_THRESHOLDS["co2"]:
            triggered.append(f"ОПАСНОСТЬ: Высокий уровень CO₂ ({co2} ppm)! Покиньте помещение.")
            co2_triggered = True

        is_emergency = len(triggered) > 0

        # Выбираем наиболее подходящую TTS-фразу под конкретную угрозу.
        # При нескольких одновременных угрозах — общая фраза об опасности.
        active = sum([fire_triggered, co_triggered, co2_triggered])
        if not is_emergency:
            tts_message = None
        elif active > 1:
            tts_message = TTS_MULTI
        elif fire_triggered:
            tts_message = TTS_FIRE
        elif co_triggered:
            tts_message = TTS_CO
        else:
            tts_message = TTS_CO2

        return {
            # Основной флаг: мобильное приложение включает режим "Звонка"
            "emergency_call": is_emergency,
            # Список конкретных причин срабатывания (для отображения на экране)
            "reasons": triggered,
            # Одна строка с объединёнными причинами (удобно для push-уведомления)
            "summary": " | ".join(triggered) if triggered else "Норма",
            # Текст для синтеза речи (TTS): воспроизводится при emergency_call=true
            "tts_message": tts_message,
            # Флаг сирены: мобильное приложение проигрывает громкий звук
            "play_alarm": is_emergency,
            # Пороги, по которым выполнялась проверка (для отладки / UI)
            "thresholds": EMERGENCY_THRESHOLDS,
        }


# Инициализация сервиса для использования в приложении
ai_service = AIService()
