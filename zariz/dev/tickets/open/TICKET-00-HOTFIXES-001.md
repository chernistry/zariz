Follow the coding rules specified in /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md


View Order Details
Реализуй модальное окно для просмотра/редактирования заказа:
• Открывается по клику на кнопку "View" в таблице Orders
• Показывает все поля заказа (recipient, address, boxes_count, 
status, courier)
• Позволяет редактировать поля с валидацией
• Кнопки: Save, Cancel, Delete

## 3. User Profile Menu
Очисти dropdown меню профиля (правый верхний угол):
• Убери пункты "Settings" и "New Team"
• Оставь только: Profile, Billing, Notifications, Log out

## 4. Push Notifications Timing
Проверь и задокументируй:
• Где в коде настраивается отправка push-уведомлений на iOS после со
здания заказа
• Какая задержка установлена (должна быть immediate/near-realtime)
• Используется ли APNs silent push или alert push
• Путь: backend → gorush → APNs → iOS app

Кроме того, сейчас пуши приходят только если приложение на переднем плане. Если оно в бекграунде (не на экране), то нотификация придёт только после открытия приложения. Это ограничение эмулятора или у нас проблемы в коде? Если проблемы в коде, исправь. Нотификации на iOS о новых заказах должны приходить и при закрытом приложении


## 5. Required Address Fields
В форме Create New Order сделай обязательными:
• Pickup Address (сейчас optional)
• Delivery Address (сейчас optional)
• Добавь валидацию и визуальную индикацию (*)

## 6. Courier Load Visualization
### В списке Couriers:
• Добавь колонку "Current Load" с визуализацией: 5/8 boxes + 
progress bar
• По клику на курьера открывай модал "Courier Details" с:
  • Список активных заказов (order ID, boxes count, status)
  • Визуальная индикация загрузки (progress bar + percentage)
  • Total: X/8 boxes occupied

### В таблице Orders:
• Добавь колонку "Boxes" показывающую boxes_count для каждого заказа

### В модале Assign Courier:
• Улучши визуализацию загрузки:
  • Добавь progress bar для каждого курьера (цветовая индикация: 
green <50%, yellow 50-80%, red >80%)
  • Покажи: Available: 3/8 boxes (37% free) вместо просто 3/8 boxes
  • Добавь badge с количеством коробок в текущем заказе: 
This order: 2 boxes
  • Сортируй курьеров по доступной ёмкости (most available first)
  • Disable курьеров у которых недостаточно места для текущего заказ
а

## Приоритет реализации:
1. View Order modal (критично для операций)
2. Required address fields (предотвращает ошибки)
3. Courier load visualization (улучшает UX assign)
4. Profile menu cleanup (быстрый fix)
5. Push notifications audit (проверка существующего)