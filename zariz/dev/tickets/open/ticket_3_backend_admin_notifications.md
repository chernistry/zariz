# Ticket 3: Backend - SSE нотификации для админ-панели

Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

## Цель
Реализовать Server-Sent Events (SSE) endpoint для отправки real-time нотификаций в web-админку о новых заказах, чтобы админ мог оперативно назначать заказы на курьеров.

## Контекст
Сейчас админ должен вручную обновлять страницу для просмотра новых заказов. Требуется push-механизм для мгновенного уведомления о поступлении заказа от магазина.

## Технические требования

### 1. SSE Endpoint
Создать `backend/app/routes/admin_events.py`

**Функциональность:**
- Endpoint: `GET /api/admin/events`
- Аутентификация: JWT token, роль `admin` обязательна
- SSE stream с `Content-Type: text/event-stream`
- Keepalive каждые 30 секунд (`:keepalive\n\n`)
- Graceful disconnect при logout/timeout

**Event Format:**
```json
{
  "event": "order.created",
  "data": {
    "order_id": 123,
    "pickup_address": "Warehouse A",
    "delivery_address": "Customer Street 45",
    "boxes_count": 5,
    "created_at": "2025-10-24T18:00:00Z"
  }
}
```

### 2. Event Broadcasting
Использовать Redis Pub/Sub для broadcast между workers

**Реализация:**
- При создании заказа (`POST /orders`) публиковать событие в Redis channel `admin:events`
- SSE endpoint подписывается на channel и форвардит события клиентам
- Использовать `aioredis` для async pub/sub

**Пример:**
```python
# В orders.py после создания заказа
await redis.publish(
    "admin:events",
    json.dumps({
        "event": "order.created",
        "data": order_dict
    })
)

# В admin_events.py
async def event_stream(request: Request):
    pubsub = redis.pubsub()
    await pubsub.subscribe("admin:events")
    async for message in pubsub.listen():
        if message["type"] == "message":
            yield f"data: {message['data']}\n\n"
```

### 3. Security & Authorization
- Проверка JWT token в query param или header
- Middleware для проверки роли `admin`
- Rate limiting: max 1 connection per admin user
- Timeout: disconnect после 1 часа inactivity

### 4. Observability
Добавить OpenTelemetry metrics:
- `sse_connections_active{role="admin"}` - активные SSE подключения
- `admin_events_emitted_total{event_type}` - количество отправленных событий
- `sse_connection_duration_seconds` - длительность подключений

Логирование:
```python
logger.info("SSE connection established", extra={
    "user_id": user.id,
    "role": user.role,
    "ip": request.client.host
})
```

### 5. Error Handling
- Graceful shutdown при server restart
- Reconnection hint в response headers: `X-Reconnect-Delay: 3000`
- Catch и log exceptions без crash всего endpoint

## Критерии приемки
- [ ] SSE endpoint `/api/admin/events` работает с JWT auth
- [ ] Только пользователи с ролью `admin` могут подключиться
- [ ] При создании заказа событие приходит в SSE stream < 500ms
- [ ] Redis pub/sub корректно broadcast события между workers
- [ ] Keepalive пакеты отправляются каждые 30 секунд
- [ ] Metrics собираются и доступны в `/metrics`
- [ ] Graceful disconnect при logout/timeout
- [ ] Unit tests для SSE endpoint и event emission
- [ ] Integration test: создать заказ → проверить событие в SSE

## Файлы для создания/изменения
- `backend/app/routes/admin_events.py` (создать) - SSE endpoint
- `backend/app/routes/orders.py` (изменить) - добавить event emission
- `backend/app/core/redis.py` (создать/изменить) - Redis pub/sub setup
- `backend/app/middleware/auth.py` (изменить) - добавить SSE auth support
- `backend/tests/test_admin_events.py` (создать) - тесты

## Зависимости
- `aioredis` или `redis[asyncio]` для async Redis
- Существующая JWT auth система
- OpenTelemetry уже настроен

## Примечания
- SSE работает через Nginx/Caddy без дополнительной настройки
- Для production добавить `X-Accel-Buffering: no` header (Nginx)
- Не использовать WebSocket - SSE проще для one-way communication
- Минимальный код - только необходимая функциональность
- Следовать FastAPI best practices для streaming responses

## Риски и митигация
- **Риск:** Memory leak при долгих подключениях
  - **Митигация:** Timeout 1 час, мониторинг memory usage
- **Риск:** Redis unavailable → события теряются
  - **Митигация:** Fallback polling в web-admin (Ticket 4)
- **Риск:** Слишком много событий → перегрузка клиента
  - **Митигация:** Rate limiting на backend, debounce на frontend
