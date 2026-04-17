"""
Константы приложения
"""

# Климатические профили
PROFILES = [
    {
        "name": "💊 Аптека",
        "temp_min": 20,
        "temp_max": 24,
        "humidity_max": 60,
        "co2_max": 800,
        "co_max": 30,
    },
    {
        "name": "🧪 Лаборатория",
        "temp_min": 19,
        "temp_max": 23,
        "humidity_max": 55,
        "co2_max": 700,
        "co_max": 25,
    },
    {
        "name": "🏠 Дом",
        "temp_min": 20,
        "temp_max": 26,
        "humidity_max": 65,
        "co2_max": 1000,
        "co_max": 35,
    },
    {
        "name": "❄️ Холодная комната",
        "temp_min": 4,
        "temp_max": 8,
        "humidity_max": 80,
        "co2_max": 800,
        "co_max": 20,
    },
    {
        "name": "🌅 Офис",
        "temp_min": 21,
        "temp_max": 25,
        "humidity_max": 50,
        "co2_max": 600,
        "co_max": 20,
    }
]

# Лимиты
MAX_HISTORY_SIZE = 100
MAX_WEBSOCKET_CLIENTS = 100
