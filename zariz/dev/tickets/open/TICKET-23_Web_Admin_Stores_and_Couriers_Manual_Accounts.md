Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-23] Web Admin — Stores & Couriers: ручное управление учётками и параметрами

1. Task Summary

Objective: Реализовать в web‑админке две основные вкладки — Stores и Couriers — с полным ручным управлением записями и их учётными данными (логин/пароль), доступными только системному администратору Zariz.

Expected Outcome: Админ может создавать/редактировать магазины и курьеров, задавать/менять логин (email/телефон) и пароль, управлять статусами. Никакого self‑service, приглашений или независимого управления пользователями магазинами.

Success Criteria:
- Страницы `/stores` и `/couriers` со списками, фильтрами и действиями `create/edit/deactivate/reactivate`.
- Карточки `/stores/[id]`, `/couriers/[id]` с блоком «Учётные данные» (смена логина, сброс/смена пароля, показ/копирование временного).
- API защищены RBAC, доступны только администратору.

Go/No-Go Preconditions: Бэкенд-авторизация по JWT/refresh (см. TICKET-21), админ‑роуты готовы. Доступны секреты и .env (NEXT_PUBLIC_API_BASE и т. п.).

2. Assumptions & Scope

Assumptions: В админку логинится только системный администратор. Для `Store` и `Courier` хранится один логин+пароль. Курьеры используют iOS‑клиент; магазины пользуются только своей учёткой (внешние порталы вне этого тикета). Пароли задаёт/меняет только админ.

Non-Goals: Нет self‑service, приглашений, восстановления пароля end‑user’ом; нет кастомных ролей. Нет расширенного справочника SLA (только MVP‑настройки).

Budgets: Списки рендерятся ≤200 мс при 1k строках (клиентская пагинация/серверные лимиты). Формы сохраняются ≤300 мс.

3. Architecture Overview

Components: Next.js страницы `stores`, `couriers`; API‑клиент к FastAPI админ‑эндпоинтам; защищённый layout с проверкой admin JWT; модули форм и подтверждений.

Patterns: Adapter (api.ts), Context (AuthProvider), Template Method (withAuth admin‑guard), Form components reuse.

Flow: Админ авторизуется → переходит на Stores/Couriers → создаёт/редактирует записи → для учётных данных: меняет логин, генерирует временный пароль → копирует пароль и передаёт его по внешнему каналу.

MVP deployability: Одновазовый VPS; без SSR‑охраны достаточно client‑guard + backend RBAC; позже можно добавить middleware.

4. Affected Modules/Files (if repo is available)

Files to Modify:
- `zariz/web-admin/libs/api.ts` — добавить методы для admin CRUD: stores/couriers, смена логина/пароля, статусы.
- `zariz/web-admin/pages/_app.tsx` — убедиться, что layout/guard применён ко всем, кроме `/login`.
- `zariz/web-admin/pages/couriers.tsx` — заменить текущий список на полноценный CRUD UI.

Files to Create:
- `zariz/web-admin/pages/stores.tsx` — список магазинов.
- `zariz/web-admin/pages/stores/[id].tsx`, `zariz/web-admin/pages/stores/new.tsx` — карточка/создание.
- `zariz/web-admin/pages/couriers/[id].tsx`, `zariz/web-admin/pages/couriers/new.tsx` — карточка/создание.
- Компоненты форм: `zariz/web-admin/components/forms/StoreForm.tsx`, `CourierForm.tsx`, `CredentialsBlock.tsx`.

Backend (reference only; implemented in TICKET-21):
- Админ‑эндпоинты: `GET/POST /v1/admin/stores`, `GET/PATCH /v1/admin/stores/{id}`, `POST /v1/admin/stores/{id}/credentials`, аналогично для курьеров.

5. Implementation Steps

1) API контракты (web‑admin): описать в `libs/api.ts` функции:
   - `listStores()`, `getStore(id)`, `createStore(dto)`, `updateStore(id,dto)`, `changeStoreCredentials(id,{login,password?})`, `setStoreStatus(id,status)`.
   - Аналогично `listCouriers()`, `getCourier(id)`, `createCourier(dto)`, `updateCourier(id,dto)`, `changeCourierCredentials(id,{login,password?})`, `setCourierStatus(id,status)`.
2) Списки:
   - Таблицы с колонками из описания (название/статус/контакт/логин для Stores; имя/телефон/привязанные магазины/статус/логин для Couriers).
   - Кнопки «Create», переход в карточку, фильтры по статусу.
3) Карточки и формы:
   - Общие поля + MVP‑настройки (лимиты по коробкам, часы работы — простые строки/числа).
   - Блок «Учётные данные»: поле логина, кнопка «Сменить пароль» → генерация временного (показать + копировать). Предупреждение о безопасной передаче пароля.
4) Guards & RBAC:
   - Использовать существующий withAuth guard (админ‑токен); скрыть навигацию для не‑админов (если роль ≠ admin, редирект на `/login`).
5) Ошибки/UX:
   - Показ ошибок сохранения, лоадеры, disable при pending, подтверждение перед деактивацией.
6) Тесты:
   - Unit для `libs/api.ts` (msw), smoke‑E2E (Playwright): создать магазин → сменить логин/пароль → деактивировать → реактивировать; аналогично курьер.

6. Interfaces & Contracts

DTO (client‑side; зеркалит backend из TICKET-21):
- StoreDTO `{ id?, name, contact_name?, contact_phone?, status: 'active'|'suspended'|'offboarded', pickup_address?, box_limit? }`
- CourierDTO `{ id?, name, phone, status, capacity_boxes?, shift_info?, vehicle_id? }`
- CredentialsChange `{ login: string, password?: string }` (если password пустой, только смена логина).

Errors: `{ code, message, details? }`.

7. Data Model & Migration (if relevant)

Опирается на TICKET-21: у `stores` есть ссылка на учётку (user) или поля логина/пароля; у `users` для couriers — хэш пароля и параметры курьера. Для данного тикета — только потребление этих API.

8. Testing & Validation

Unit: мокировать fetch (msw) и проверять парсинг/ошибки вызовов api.ts.
E2E: сценарии CRUD для Stores и Couriers (создать → сменить логин/пароль → деактивировать → реактивировать).
Accessibility: label’ы, aria‑описания на формах.

9. Observability & Operations

Клиентские события: логировать (redacted) `admin.ui.action` (create/update/deactivate) в консоль (dev) и отправлять beacon (опционально). Backend логирует аудиты.

10. Risks & Considerations

- Смена логина может инвалидировать активные сессии — подтверждение перед действием.
- Генерация пароля: показать только один раз; кнопки Copy/Download; предупредить об обязательной смене при первом входе (если поддерживается бэкендом).
- Совместимость с TICKET-22 (admin‑only login).

11. Implementation Checklist

- [] Списки `/stores`, `/couriers` со всеми колонками и действиями.
- [] Карточки `new`/`[id]` с формами и блоком Credentials.
- [] Методы в `libs/api.ts` + обработка ошибок.
- [] Guard только для admin.
- [] Тесты unit+E2E.
- [] Документация: короткий README в web‑admin о новых экранах.
