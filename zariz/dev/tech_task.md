Техническое задание (обновлённое и структурированное)

Цель:
Разработать iOS-приложение для отслеживания заказов курьеров из магазинов.



1. Общая концепция

Приложение позволяет магазинам размещать заказы, а курьерам — видеть доступные заказы, брать их в работу и отмечать статус выполнения (например, «взял заказ», «доставлено»).

⸻

2. Основные роли
	1.	Курьер
	•	Авторизация (через телефон или email).
	•	Просмотр списка активных заказов.
	•	Просмотр деталей заказа (откуда забрать, куда доставить, контактные данные).
	•	Взятие заказа в работу.
	•	Изменение статуса заказа (в пути, доставлено).
	2.	Магазин
	•	Создание заказа (данные: товары, адрес, контакт получателя).
	•	Просмотр статуса заказов.
	•	Опционально: подтверждение завершения доставки.
	•	Можно реализовать как веб-панель (без отдельного мобильного приложения).
	3.	Администратор
	•	Управление пользователями (курьеры, магазины).
	•	Просмотр всех заказов.
	•	Настройка ограничений и мониторинг активности.

⸻

3. Архитектура и компоненты
	1.	Backend-сервис
	•	API на FastAPI / NestJS / Django REST.
	•	Хранение данных о заказах, пользователях, статусах.
	•	Авторизация JWT.
	•	REST/GraphQL API для клиента.
	•	Возможность масштабирования (Docker, AWS ECS, или GCP Cloud Run).
	2.	База данных
	•	PostgreSQL или Firebase Firestore.
	•	Таблицы:
	•	users (id, role, name, phone, store_id)
	•	orders (id, store_id, courier_id, status, pickup_address, delivery_address, created_at, updated_at)
	•	status_history (order_id, status, timestamp)
	3.	iOS-приложение
	•	Разработка на SwiftUI.
	•	Экран входа → список заказов → детали → изменение статуса.
	•	Асинхронная работа с API (Combine / async-await).
	4.	Web-панель для магазинов (опционально)
	•	React / Next.js / Vue.
	•	Авторизация магазина.
	•	Создание заказов.
	•	Мониторинг статусов.

⸻

4. Функциональные требования
	•	Регистрация и вход.
	•	Просмотр списка заказов (по статусу: «свободен», «в работе», «доставлен»).
	•	Фильтрация по магазину и дате.
	•	Изменение статуса заказа курьером.
	•	Реальное обновление статуса в панели магазина.
	•	Без геолокации на MVP-этапе.

⸻

5. Нефункциональные требования
	•	Масштабируемость: поддержка до 100 курьеров и 50 магазинов.
	•	API-латентность: <300 мс (p95).
	•	Надёжность: SLA ≥99%.
	•	Логирование и мониторинг (Prometheus / Grafana / Sentry).
	•	Аутентификация: JWT + HTTPS.

⸻

6. MVP-этап (первые 2–3 недели)
	1.	Создание базовой БД.
	2.	API для CRUD заказов.
	3.	Авторизация и роли.
	4.	iOS-клиент с отображением заказов.
	5.	Тестовая веб-панель для магазинов.

⸻

7. Возможные расширения (v2+)
	•	Геолокация и маршруты.
	•	Push-уведомления.
	•	Расчёт времени доставки.
	•	Аналитика заказов.
	•	Поддержка Android.

⸻

8. Бест-практики / готовые решения
	•	Использовать Clean Architecture (MVVM) для клиента.
	•	Бэкенд — FastAPI + SQLAlchemy + Alembic + Docker.
	•	CI/CD — GitHub Actions.
	•	При желании: можно использовать шаблон delivery-app clone (многие делают как учебные проекты).

⸻



Это типовой диспетчеринг. MVP сделает один инженер. Начните с одного VPS, веб-панели для магазинов и iOS-клиента. Реалтайм для iOS — через APNs тихие пуши + фоновая выборка; постоянные сокеты в фоне на iOS нереалистичны. ([Apple Developer][1])

# 1) ТЗ (MVP, без геопозиции)

**Цель:** курьер видит новые заказы, берёт заказ, ведёт статусы до 'доставлено'.

**Роли:** Магазин, Курьер, Оператор/Админ.

**Сценарии:**

* Магазин создаёт заказ: {store_id, pickup_address, dropoff_address, items, notes}. Курьерам приходит уведомление. ([Apple Developer][1])
* Курьер 'берёт' заказ. Требование: атомарность и защита от гонок и двойных кликов. Используем транзакцию в БД. ([PostgreSQL][2])
* Статусы: new → claimed → picked_up → delivered → canceled. События пишем в журнал.
* Уведомления: тихие пуши APNs (content-available=1) для пробуждения клиента и фоновой синхронизации. iOS может коалесцировать/ограничивать такие пуши, закладываем повторный пуллинг. ([Apple Developer][3])

**Нефункциональные:**

* Надёжность 'claim': одна запись — один исполнитель. Атомарный UPDATE/SELECT FOR UPDATE SKIP LOCKED. ([PostgreSQL][4])
* Идемпотентность всех POST/PUT от клиента через Idempotency-Key. ([Stripe Docs][5])
* Документация API в OpenAPI 3.1. ([Swagger][6])
* Ограничение частоты: 429 Too Many Requests + Retry-After. ([IETF Datatracker][7])
* Безопасность: JWT, проверка прав на объект, базовые OWASP API Top-10. ([IETF Datatracker][8])

**Критерии приёмки:**
p95 API < 300 ms на 1 VPS; 100 курьеров онлайн; отказоустойчивость 'claim' под двойным тапом; доставка пуша → данные обновились в 30–120 c при активной сети. ([Apple Developer][1])

# 2) Архитектура и развёртывание

**Компоненты:**

* **API+БД:** FastAPI/Flask + PostgreSQL. Таблицы: stores, couriers, devices, orders, order_assignments, order_events. Жёсткие уникальные ключи и CHECK для состояний. Атомарный 'claim' через транзакцию: `UPDATE orders SET status='claimed', courier_id=$1 WHERE id=$2 AND status='new' RETURNING id;` либо очередь с `SELECT ... FOR UPDATE SKIP LOCKED`. ([PostgreSQL][4])
* **iOS-клиент:** SwiftUI + SwiftData (локальный кэш, оффлайн). Асинхронная синхронизация, тихие пуши. ([Apple Developer][9])
* **Веб-панель магазинов/админа:** обычный SPA/SSR; отдельная роль, RBAC.
* **Нотификатор:** воркер, отправляющий APNs. ([Apple Developer][3])

**Доставка обновлений:**

* iOS: APNs 'content-available=1' + BGTaskScheduler; сокеты в фоне не рассчитываем. ([Apple Developer][1])
* Веб-панель: SSE или WebSocket; для однонаправленного пуша достаточно SSE. ([MDN Web Docs][10])

**API (ядро):**

* `POST /orders` (магазин)
* `GET /orders?status=new` (курьер)
* `POST /orders/{id}/claim` с Idempotency-Key (атомарно)
* `POST /orders/{id}/status` → picked_up/delivered
* `POST /devices/register` (APNs-токен)
* OpenAPI 3.1 yaml, автоген SDK. ([Swagger][6])

**Безопасность:**

* JWT-access, краткоживущий; авторизация по ролям; BOLA-проверки на каждый ресурс; аудит событий. См. OWASP API Top-10. ([OWASP Foundation][11])

**Наблюдаемость:**

* Логи/трейсы/метрики через OpenTelemetry; алерты по SLO и error-budget. ([OpenTelemetry][12])

**Развёртывание:**

* **Старт с нулевым бюджетом:** один VPS (Docker Compose: API, Postgres, Nginx/Caddy). Дешёвые варианты: Hetzner Cloud; также OCI Always Free даёт до 4 OCPU/24 GB RAM на A1. ([Hetzner][13])
* Cloud-провайдеры PaaS пригодны, но даже 1 VPS достаточно. При росте: вынос Postgres в управляемую БД, Redis для кэша/блокировок, отдельный воркер нотификаций.

**On-prem vs Cloud:** on-prem излишен. Один VPS или бесплатный OCI хватит. Масштабирование потребует облака, но MVP не зависит от конкретного вендора. ([Oracle Docs][14])

**Почему не 'постоянный' сокет на iOS:** система не даёт держать вечные соединения в фоне; используйте тихие пуши и фоновые задачи. ([Swift Forums][15])

---



[1]: https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app "Choosing Background Strategies for Your App"
[2]: https://www.postgresql.org/docs/current/explicit-locking.html "Documentation: 18: 13.3. Explicit Locking"
[3]: https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app "Pushing background updates to your App"
[4]: https://www.postgresql.org/docs/current/sql-update.html "Documentation: 18: UPDATE"
[5]: https://docs.stripe.com/api/idempotent_requests "Idempotent requests | Stripe API Reference"
[6]: https://swagger.io/specification/ "OpenAPI Specification - Version 3.1.0"
[7]: https://datatracker.ietf.org/doc/html/rfc6585 "RFC 6585 - Additional HTTP Status Codes"
[8]: https://datatracker.ietf.org/doc/html/rfc7519 "RFC 7519 - JSON Web Token (JWT)"
[9]: https://developer.apple.com/documentation/swiftdata "SwiftData | Apple Developer Documentation"
[10]: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events "Using server-sent events - Web APIs | MDN - Mozilla"
[11]: https://owasp.org/API-Security/editions/2023/en/0x00-header/ "2023 OWASP API Security Top-10"
[12]: https://opentelemetry.io/docs/specs/otel/logs/ "OpenTelemetry Logging"
[13]: https://www.hetzner.com/cloud "Flexible Cloud Hosting Services und VPS Server - Hetzner"
[14]: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm "Always Free Resources"
[15]: https://forums.swift.org/t/problem-in-communication-with-swiftnio-when-server-is-in-a-background-app/54951 "Problem in communication with SwiftNIO when server is ..."
