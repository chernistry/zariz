# Ticket 28: Авто‑обновление таблицы заказов по SSE без перезагрузки страницы

Тип: Bug fix / Enhancement
Приоритет: Высокий
Оценка: 2–4 часа

---

## Цель

Обеспечить «jQuery‑подобное» поведение: при приходе нового заказа или изменении существующего, таблица заказов на странице `/dashboard/orders` обновляется автоматически без полной перезагрузки страницы. Сейчас уведомление приходит, но строки в таблице появляются/меняются только после F5.

---

## Наблюдаемое поведение

- При создании нового заказа показывается toast‑уведомление, но строка в таблице не появляется до перезагрузки.
- Аналогично, изменения статуса/назначение курьера/удаление не отражаются в таблице в реальном времени.

---

## Предположительные причины

1) Страница `Orders` не подписана на SSE и не вызывает `refresh()` по событиям (или делает это неэффективно). В `NotificationProvider` события обрабатываются для тостов, но таблица не реагирует.
2) Даже при подписке — возможны гонки/устаревшие замыкания при обновлении состояния (`setOrders`) или слишком частые фетчи без троттлинга.
3) Отсутствует логика локальной синхронизации списка (инкрементальные изменения): создание/удаление/обновление по данным события, с запасным пересинком по API.

---

## Решение (минимально‑инвазивное)

Внести изменения в `Orders` страницу для приема SSE и аккуратного обновления списка.

### Файл: `web-admin-v2/src/app/dashboard/orders/page.tsx`

1) Импортировать SSE‑хук:
```ts
import { useAdminEvents } from '@/hooks/use-admin-events';
```

2) Добавить обработчик событий с троттлингом фетча и локальными инкрементальными обновлениями.

Псевдокод (внутри компонента, после `refresh`):
```ts
  const refreshTimerRef = useRef<NodeJS.Timeout | null>(null);

  const scheduleRefresh = useCallback((delay = 250) => {
    if (refreshTimerRef.current) return; // уже запланировано
    refreshTimerRef.current = setTimeout(async () => {
      refreshTimerRef.current = null;
      await refresh();
    }, delay);
  }, [refresh]);

  const updateOrderInState = useCallback((patch: Partial<Order> & { id: number | string }) => {
    setOrders((prev) => prev.map(o => String(o.id) === String(patch.id) ? { ...o, ...patch } : o));
  }, []);

  const removeOrderFromState = useCallback((id: number | string) => {
    setOrders((prev) => prev.filter(o => String(o.id) !== String(id)));
  }, []);

  const maybeAddOrderToState = useCallback((eventData: any) => {
    // Добавляем быстро, без ожидания API, если запись проходит текущие фильтры
    const newRow: Order = {
      id: eventData.order_id,
      status: 'new',
      store_id: eventData.store_id,
      courier_id: null,
      created_at: eventData.created_at,
      pickup_address: eventData.pickup_address,
      delivery_address: eventData.delivery_address,
      boxes_count: eventData.boxes_count,
    };
    setOrders((prev) => {
      const exists = prev.some(o => String(o.id) === String(newRow.id));
      if (exists) return prev;
      // Если активные фильтры скрывают заказ — не добавляем локально; просто запланируем refresh
      // Прим.: можно добавить checkMatchesFilters(filter, newRow)
      return [newRow, ...prev];
    });
  }, []);

  useAdminEvents((evt) => {
    switch (evt.event) {
      case 'order.created': {
        // Мгновенно добавляем строку для UX, затем мягко пересинхронизируем
        maybeAddOrderToState(evt.data);
        scheduleRefresh(500);
        break;
      }
      case 'order.deleted': {
        removeOrderFromState(evt.data.order_id);
        // На всякий случай пересинхронизируем список
        scheduleRefresh(400);
        break;
      }
      case 'order.assigned': {
        updateOrderInState({ id: evt.data.order_id, courier_id: evt.data.courier_id, status: 'assigned' });
        scheduleRefresh(800); // фолбэк на консистентность
        break;
      }
      case 'order.accepted': {
        updateOrderInState({ id: evt.data.order_id, status: 'accepted' });
        scheduleRefresh(800);
        break;
      }
      case 'order.status_changed': {
        updateOrderInState({ id: evt.data.order_id, status: evt.data.status });
        scheduleRefresh(800);
        break;
      }
      case 'order.updated': {
        scheduleRefresh(300); // детали могли измениться
        break;
      }
      default:
        break;
    }
  });

  useEffect(() => () => {
    if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
  }, []);
```

Пояснения:
- Локальные обновления дают мгновенную «перерисовку» без F5.
- Плановый `refresh()` c троттлингом гарантирует консистентность (если локальные данные были неполными/фильтры изменились).
- Используются функциональные обновления `setOrders((prev) => ...)` для избежания гонок замыканий.
- При желании добавить `checkMatchesFilters(filter, row)` и не показывать строки, скрытые текущими фильтрами.

3) Логирование для диагностики (по желанию): добавить короткие `console.log` на входах обработчика для валидации потока событий.

---

## Критерии приемки

- Создание заказа: новая строка появляется в таблице в течение ~0.3–1.0 секунды без перезагрузки.
- Назначение курьера/смена статуса: соответствующая строка обновляет поля (статус/курьер) автоматически.
- Удаление заказа: строка исчезает из таблицы автоматически.
- Обновления не дублируются, нет «скачков» списка.
- Работает в Chrome/Brave, Firefox, Safari.

---

## Инструкции по тестированию

1) Создание заказа
```bash
curl -X POST http://localhost:8000/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"store_id":1,"pickup_address":"A","delivery_address":"B","boxes_count":1}'
```
Ожидание: без F5 — в таблице появляется новая строка, тост показан.

2) Назначение курьера
- Через UI «Assign» назначить курьера.
Ожидание: строка обновляет `courier_id`/статус на `assigned` автоматически.

3) Удаление
- Удалить заказ из таблицы.
Ожидание: строка исчезает без перезагрузки, тост «New Order» НЕ появляется.

4) Кросс‑браузер
- Повторить шаги 1–3 в Chrome/Brave, Firefox, Safari.

---

## Риски и откаты

- Возможен избыточный фетч при частых событиях — снижается троттлингом (`scheduleRefresh`). При проблемах увеличить задержки.
- Если локальные обновления вызовут несоответствия — временно отключить локальные патчи и оставить только троттлингованный `refresh()`.

Откат: удалить блок `useAdminEvents(...)` и связанные коллбеки/рефы, вернуть поведение «обновление только через F5».

---

## Примечания

- Требуется нормализованный формат SSE `{ event, data }` из тикета 6: он уже внедрен (или внедряется). Если формат сырой (`{ type, ... }`) — использовать преобразование в `use-admin-events.ts`.
- Для дальнейшего UX можно отрисовывать «скелетон» строки до прихода `refresh()`, или подсвечивать новые/измененные строки на несколько секунд.

