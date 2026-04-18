# 🌡️ MicroClimate Pro (Fullstack IoT System)

Комплексная система мониторинга и прогнозирования микроклимата, объединяющая **IoT-устройства (ESP32)**, асинхронный **FastAPI бэкенд** и кроссплатформенное приложение на **Flutter**.

---

## 📸 Интерфейс приложения (Screenshots)

| 🔐 Login Screen | 📊 Dashboard | 📈 Smart Forecasting |
| :---: | :---: | :---: |
| ![Login](assets/screenshots/login.jpg) | ![Dashboard](assets/screenshots/Dashboard.jpg) | ![Prediction](assets/screenshots/Prediction.jpg) |

| 📜 History | 🛠 Profiles | 🔔 Push Alerts |
| :---: | :---: | :---: |
| ![History](assets/screenshots/History.jpg) | ![Profiles](assets/screenshots/Profiles.jpg) | ![Push](assets/screenshots/Push.jpg) |

---

## 🏗 Архитектура системы

Проект построен на событийно-ориентированной архитектуре для обеспечения минимальной задержки при передаче данных от сенсоров к пользователю.
---

## 📉 Математическая модель прогнозирования

Для анализа динамики микроклимата в системе реализовано **двойное экспоненциальное сглаживание (Метод Хольта)**. Алгоритм позволяет предсказывать тренды без использования ресурсозатратных нейросетей, работая непосредственно в потоке данных бэкенда.

### Технические параметры модели:
* **Smoothing Factors:**
    * $\alpha = 0.9$ (Level smoothing) — высокий приоритет актуальных данных для быстрой реакции на изменения.
    * $\beta = 0.1$ (Trend smoothing) — фильтрация высокочастотных шумов сенсоров для стабилизации тренда.
* **History Window:** Индексация последних 1000 точек данных (обработка ~1.4 часа непрерывных измерений при шаге 5 сек).
* **Forecasting Horizons:** Автоматический расчет прогнозных значений на 30 мин, 3 часа и 24 часа.

### Алгоритм обработки:
1. **MQTT Ingestion:** Обработка пакетов данных с датчиков температуры, влажности и CO/CO₂.
2. **Trend Analysis:** Расчет текущего уровня и наклона тренда (Slope) для экстраполяции значений.
3. **Accuracy Verification:** Фоновая задача `_hourly_verify()` сопоставляет архивные прогнозы с фактическими данными для оценки точности модели.

---

## 🛡️ Безопасность и мониторинг

* **Emergency Alerts:** Система мониторинга критических порогов (Пожар T > 60°C, утечка газа CO > 100 ppm).
* **Push Notifications:** Интеграция с Firebase Cloud Messaging для мгновенного оповещения через мобильное приложение.
* **JWT Auth:** Безопасная авторизация пользователей и разграничение доступа к IoT-устройствам.

---

## 🛠 Технологический стек

* **Backend:** Python 3.12, FastAPI, PostgreSQL, MQTT (Paho), WebSockets.
* **Mobile:** Flutter (Dart), Dio (HTTP), Provider (State Management).
* **DevOps:** Docker, Docker Compose, Firebase FCM.

---

## 🚀 Быстрый запуск

### 1. Backend (Docker)
```bash
cd backend
docker-compose up -d
