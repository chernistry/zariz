# Ticket 4: Web-Admin - SSE клиент и iOS-style нотификации

Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

## Цель
Реализовать SSE клиент в web-админке для получения real-time нотификаций о новых заказах с iOS-style UI и звуковыми уведомлениями.

## Контекст
После реализации Ticket 3 (Backend SSE), нужен frontend для отображения нотификаций админу. Дизайн должен быть похож на iOS notifications для консистентности с мобильным приложением.

## Зависимости
- Ticket 3 должен быть завершен (SSE endpoint `/api/admin/events`)

## Технические требования

### 1. SSE Client Hook
Создать `web-admin/src/hooks/useAdminEvents.ts`

**Функциональность:**
- React hook для подключения к SSE endpoint
- Автоматический reconnect с exponential backoff (1s, 2s, 4s, 8s, max 30s)
- Передача JWT token через query param: `/api/admin/events?token=${jwt}`
- Обработка событий типа `order.created`
- Cleanup при unmount компонента

**Пример:**
```typescript
export function useAdminEvents() {
  const [events, setEvents] = useState<OrderEvent[]>([]);
  const { token } = useAuth();

  useEffect(() => {
    if (!token) return;

    const eventSource = new EventSource(
      `${API_BASE}/api/admin/events?token=${token}`
    );

    eventSource.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.event === 'order.created') {
        setEvents(prev => [data.data, ...prev]);
        showNotification(data.data);
      }
    };

    eventSource.onerror = () => {
      eventSource.close();
      // Reconnect logic with backoff
    };

    return () => eventSource.close();
  }, [token]);

  return events;
}
```

### 2. iOS-Style Toast Component
Создать `web-admin/src/components/OrderNotification.tsx`

**Дизайн:**
- Появление сверху с slide-down анимацией
- Полупрозрачный фон с blur effect (backdrop-filter)
- Иконка заказа слева
- Текст: "New Order #123" + pickup address
- Кнопка "Assign" справа
- Auto-dismiss через 10 секунд
- Swipe-to-dismiss gesture (опционально)

**Стили (Tailwind CSS):**
```tsx
<div className="fixed top-4 right-4 z-50 animate-slide-down">
  <div className="bg-white/90 backdrop-blur-lg rounded-2xl shadow-2xl p-4 min-w-[320px] border border-gray-200">
    <div className="flex items-start gap-3">
      <div className="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center">
        <ShoppingBagIcon className="w-6 h-6 text-white" />
      </div>
      <div className="flex-1">
        <p className="font-semibold text-gray-900">New Order #{order.id}</p>
        <p className="text-sm text-gray-600">{order.pickup_address}</p>
      </div>
      <button className="px-3 py-1 bg-blue-500 text-white rounded-lg text-sm font-medium hover:bg-blue-600">
        Assign
      </button>
    </div>
  </div>
</div>
```

### 3. Notification Manager
Создать `web-admin/src/lib/notificationManager.ts`

**Функциональность:**
- Queue для нотификаций (max 3 одновременно)
- Звуковое уведомление (опционально, с user permission)
- Browser Notification API fallback (если вкладка неактивна)
- Deduplication (не показывать дубликаты)

**Звук:**
```typescript
const notificationSound = new Audio('/sounds/notification.mp3');

function playSound() {
  if (userPreferences.soundEnabled) {
    notificationSound.play().catch(err => {
      console.warn('Sound play failed:', err);
    });
  }
}
```

### 4. Integration в Layout
Добавить в `web-admin/src/app/layout.tsx`

**Реализация:**
- Компонент `<NotificationProvider>` в root layout
- Только для authenticated admin users
- Показывать индикатор подключения (зеленая точка = connected)

```tsx
export default function AdminLayout({ children }) {
  return (
    <NotificationProvider>
      <div className="relative">
        <ConnectionStatus />
        {children}
      </div>
    </NotificationProvider>
  );
}
```

### 5. User Preferences
Добавить настройки в профиль админа:
- Toggle: "Enable sound notifications"
- Toggle: "Enable browser notifications"
- Сохранять в localStorage

### 6. Error Handling & Fallback
- Если SSE недоступен → показать warning banner
- Fallback на polling каждые 30 секунд
- Reconnection indicator: "Reconnecting..." toast

## Критерии приемки
- [ ] SSE подключение устанавливается при логине админа
- [ ] При создании заказа нотификация появляется < 1 секунды
- [ ] iOS-style toast с правильным дизайном и анимацией
- [ ] Кнопка "Assign" открывает модал назначения курьера
- [ ] Звуковое уведомление работает (с user permission)
- [ ] Auto-dismiss через 10 секунд
- [ ] Reconnection с exponential backoff при disconnect
- [ ] Fallback на polling если SSE недоступен
- [ ] Индикатор статуса подключения (connected/disconnected)
- [ ] Настройки звука/browser notifications в профиле
- [ ] Работает в Chrome, Safari, Firefox
- [ ] Unit tests для useAdminEvents hook
- [ ] E2E test: создать заказ → проверить нотификацию

## Файлы для создания/изменения
- `web-admin/src/hooks/useAdminEvents.ts` (создать) - SSE client hook
- `web-admin/src/components/OrderNotification.tsx` (создать) - Toast component
- `web-admin/src/lib/notificationManager.ts` (создать) - Notification logic
- `web-admin/src/app/layout.tsx` (изменить) - Integration
- `web-admin/src/components/ConnectionStatus.tsx` (создать) - Status indicator
- `web-admin/public/sounds/notification.mp3` (добавить) - Sound file
- `web-admin/tailwind.config.js` (изменить) - Add animations

## Зависимости
- Существующая auth система (JWT token)
- Tailwind CSS уже настроен
- React 18+ с hooks

## Примечания
- Использовать native EventSource API (не нужны библиотеки)
- Для звука использовать короткий (~200ms) notification sound
- Browser Notification API требует user permission - запрашивать при первом событии
- Минимальный код - избегать тяжелых библиотек типа socket.io
- Следовать Next.js 14+ app router conventions

## Анимации (Tailwind)
Добавить в `tailwind.config.js`:
```javascript
module.exports = {
  theme: {
    extend: {
      animation: {
        'slide-down': 'slideDown 0.3s ease-out',
        'slide-up': 'slideUp 0.3s ease-in',
      },
      keyframes: {
        slideDown: {
          '0%': { transform: 'translateY(-100%)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(0)', opacity: '1' },
          '100%': { transform: 'translateY(-100%)', opacity: '0' },
        },
      },
    },
  },
}
```

## Риски и митигация
- **Риск:** EventSource не поддерживается в старых браузерах
  - **Митигация:** Polyfill или fallback на polling
- **Риск:** Слишком много нотификаций → UI перегружен
  - **Митигация:** Queue max 3, auto-dismiss, group similar events
- **Риск:** Звук раздражает пользователя
  - **Митигация:** Настройка в профиле, mute по умолчанию
- **Риск:** Browser Notification permission denied
  - **Митигация:** Graceful fallback на in-app toast только
