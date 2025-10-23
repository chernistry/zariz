Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-21] Backend — Authentication & RBAC Overhaul (admin-only web, 1 учётка на Store/Courier)

1. Task Summary

Objective: Поставить продукционную аутентификацию с Argon2, JWT/refresh, жёстким RBAC и простой моделью учёток: одна учётка на магазин (store user) и одна учётка на курьера (courier user). В админку входит только системный администратор.

Expected Outcome: Работают логин/refresh/logout, админ‑эндпоинты CRUD для Stores/Couriers, смена логина/пароля только админом. Нет self‑service.

Success Criteria: Тесты login/refresh, RBAC, CRUD Stores/Couriers (включая смену логина/пароля) проходят. OpenAPI обновлён.

Go/No-Go: JWT/refresh секреты, Redis для rate limit, Alembic миграции готовы; .env заполнен.

2. Assumptions & Scope

Assumptions: Используем StoreMemberships (1..N) для гибкости доступа (см. `app/db/models/store_user_membership.py`). Для MVP у магазина есть один primary пользователь (роль `store`) через membership `is_primary=True`; курьеры — пользователи с ролью `courier`. В админку логинится только `admin` (системная учётка).

Non-Goals: Нет кастомных ролей, нет self‑signup/invite, нет восстановления пароля конечным пользователем.

3. Architecture Overview

Components: FastAPI auth (login/refresh/logout), таблицы users/stores, админ‑роуты `/v1/admin/*`, сессии refresh в `user_sessions`. Rate limiting через Redis. Prometheus метрики.

4. Affected Modules/Files

Files to Modify:
- `zariz/backend/app/api/routes/auth.py`, `.../deps.py`, `.../schemas.py`
- `zariz/backend/app/core/security.py`, `.../core/config.py`
- `zariz/backend/app/db/models/user.py`, `.../db/models/store.py`
- `zariz/backend/app/api/routes/orders.py` (RBAC: store/courier доступы)

Files to Create:
- `zariz/backend/app/db/models/user_session.py`
- Админ‑роуты: `zariz/backend/app/api/routes/admin/stores.py`, `.../admin/couriers.py`
- Alembic миграции
- Тесты: `zariz/backend/tests/auth/*`, `tests/admin/*`

5. Implementation Steps

1) Миграции:
   - Таблица `users`: поля `email`, `phone`, `password_hash`, `role in ('admin','store','courier')`, `status`, timestamps.
   - Таблица `user_sessions`: `id`, `user_id`, `refresh_token_hash`, `issued_at`, `expires_at`, `revoked_at`, `device_meta`.
   - Таблица `stores`: добавить поля `status`, базовые настройки (pickup_address, box_limit, hours_text). Primary store user связывается через `store_user_memberships`.
   - Для курьеров используем строки в `users` с ролью `courier`; дополнительные поля уже есть (`capacity_boxes`).
2) Безопасность:
   - Argon2id hash/verify; rate limit `POST /v1/auth/login` = 5/min/IP.
   - JWT: `sub`, `role`, `exp=15m`; refresh 14d; хэшируем refresh в БД.
3) Эндпоинты:
   - `POST /v1/auth/login`, `POST /v1/auth/refresh`, `POST /v1/auth/logout`.
   - Admin Stores: `GET/POST /v1/admin/stores`, `GET/PATCH /v1/admin/stores/{id}`, `POST /v1/admin/stores/{id}/credentials`, `POST /v1/admin/stores/{id}/status`.
   - Admin Couriers: `GET/POST /v1/admin/couriers`, `GET/PATCH /v1/admin/couriers/{id}`, `POST /v1/admin/couriers/{id}/credentials`, `POST /v1/admin/couriers/{id}/status`.
   - Все `admin/*` требуют `role=admin`.
4) RBAC/Scopes:
   - Курьер доступен только к своим ресурсам (orders/status). Store доступ к заказам своего магазина (если используется вне админки). Admin — полный доступ.
5) Наблюдаемость:
   - Логи JSON: `event=auth.login`, `user_id`, `role`, `result`, IP редактируем до hash.
   - Метрики Prometheus: `auth_login_success_total`, `auth_login_failure_total`.
6) Тесты: login/refresh/logout, CRUD stores/couriers, смена логина/пароля, RBAC 403’и.

---

Result (Implemented)

- Auth endpoints: `/v1/auth/login_password`, `/v1/auth/refresh`, `/v1/auth/logout` with rate limit 5/min/IP and session rotation. Legacy `/v1/auth/login` kept for demo.
- RBAC: `require_role()` checked on all routes; store scoping on orders via `store_ids` claim; sessions verified when `session_id` present.
- Admin APIs:
  - Stores: `GET/POST /v1/admin/stores`, `GET/PATCH /v1/admin/stores/{id}`, `POST /v1/admin/stores/{id}/credentials`, `POST /v1/admin/stores/{id}/status`.
  - Couriers: `GET/POST /v1/admin/couriers`, `GET/PATCH /v1/admin/couriers/{id}`, `POST /v1/admin/couriers/{id}/credentials`, `POST /v1/admin/couriers/{id}/status`.
- Data model/migrations:
  - `user_sessions` table; users: `email`, `status`, `password_hash`, timestamps, `default_store_id`, `capacity_boxes`.
  - `store_user_memberships` table for store access; stores extended with `status`, `pickup_address`, `box_limit`, `hours_text` (see Alembic `c3d4e5f6a8b9_*`).
- Tests: added `tests/admin/test_admin_stores.py`, `tests/admin/test_admin_couriers.py`. All tests: 16 passed.

How to apply and verify

1) Migrate DB
   cd zariz/backend && source .venv/bin/activate && alembic upgrade head
2) Run tests
   python -m pytest -q zariz/backend/tests
3) Smoke endpoints with an admin JWT
   - `GET /v1/admin/stores`
   - `POST /v1/admin/couriers { name, phone }`

Notes
- Store membership model is used (primary user per store via `is_primary=True`). This supersedes the earlier FK approach.
- Argon2 is preferred when available (passlib); falls back to bcrypt/sha256 in test envs.

Checklist
- [x] Alembic миграции применены; индексы созданы.
- [x] Auth login/refresh/logout с rate‑limit.
- [x] Admin CRUD эндпоинты для Stores/Couriers.
- [x] RBAC и тесты зелёные; метрики и логи пишутся.

6. Interfaces & Contracts

Schemas (Pydantic v2):
- `AuthLoginRequest { identifier: EmailStr|PhoneStr, password: str } → AuthTokenPair { access_token, refresh_token, expires_in, refresh_expires_in, role, user_id }`
- `StoreCreate/Update`, `CourierCreate/Update`, `CredentialsChange { login: str, password?: str }`, `StatusChange { status: 'active'|'suspended'|'offboarded' }`

7. Data Model & Migration

- `stores.store_user_id` обеспечивает правило «1 учётка на магазин» (UNIQUE, FK). Для курьеров — каждая строка в `users` с ролью `courier` — отдельная учётка.
- Downgrade: удаление `user_sessions`, снятие FK/UNIQUE (данные теряются при откате).

8. Testing & Validation

- Pytest: позитив/негатив для логина, refresh rotate, revoke; CRUD admin; RBAC.
- Adversarial: brute‑force → rate‑limit; попытка смены логина не‑админом → 403; повторная смена на занятый логин → 409.

9. Observability & Operations

- OpenTelemetry трассы на auth/refresh; Prometheus счётчики; структурированные логи без PII.
- .env.example: `JWT_SECRET`, `JWT_REFRESH_SECRET`, `ARGON2_*`, `AUTH_MODE=strict`.

10. Risks & Considerations

- Коллизии логинов (email/phone) → уникальные индексы, нормализация.
- Смена логина инвалидирует активные сессии (по флагу) — желательно.
- Миграция существующих пользователей: задать временные пароли, статус `disabled` до ручной активации админом.

11. Implementation Checklist

- [] Alembic миграции применены; индексы созданы.
- [] Auth login/refresh/logout реализованы с rate‑limit.
- [] Admin CRUD эндпоинты для Stores/Couriers.
- [] RBAC для admin/store/courier на нужных роутерах.
- [] Тесты зелёные; метрики и логи пишутся.
