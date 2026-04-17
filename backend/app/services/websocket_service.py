"""
WebSocket сервис для real-time обновлений
"""
from typing import Dict
from fastapi import WebSocket
from ..core.storage import storage


class WebSocketService:
    """Сервис для WebSocket — рассылка по device_id"""

    # Словарь: device_id → список WebSocket клиентов
    _subscribers: dict[str, list[WebSocket]] = {}

    def subscribe(self, websocket: WebSocket, device_id: str):
        """Подписать клиента на данные конкретного устройства."""
        if device_id not in self._subscribers:
            self._subscribers[device_id] = []
        if websocket not in self._subscribers[device_id]:
            self._subscribers[device_id].append(websocket)
        storage.add_websocket(websocket)

    def unsubscribe(self, websocket: WebSocket, device_id: str):
        """Отписать клиента."""
        if device_id in self._subscribers:
            self._subscribers[device_id] = [
                ws for ws in self._subscribers[device_id] if ws != websocket
            ]
        storage.remove_websocket(websocket)

    async def broadcast(self, data: Dict):
        """
        Рассылка данных только тем клиентам,
        которые подписаны на device_id из data.
        """
        device_id = data.get("device_id")
        targets = self._subscribers.get(device_id, [])

        # Если нет подписчиков по device_id — шлём всем (обратная совместимость)
        if not targets:
            targets = list(storage.active_websockets)

        disconnected = []
        for websocket in targets:
            try:
                await websocket.send_json(data)
            except Exception:
                disconnected.append(websocket)

        for ws in disconnected:
            self.unsubscribe(ws, device_id or "")
            storage.remove_websocket(ws)


# Глобальный экземпляр сервиса
websocket_service = WebSocketService()
