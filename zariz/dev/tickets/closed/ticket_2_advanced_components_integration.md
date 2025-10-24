# Ticket 2: Реализация TitleAndValueRow и интеграция в экраны Zariz

Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

## Цель
Внедрить продвинутый компонент TitleAndValueRow из WooCommerce iOS и интегрировать все новые компоненты (BadgeView, NavigationRow, TitleAndValueRow) в существующие экраны Zariz.

## Контекст
После реализации базовых компонентов в Ticket 1, добавляем продвинутый компонент для отображения пар "заголовок-значение" и интегрируем всю систему в реальные экраны приложения.

## Зависимости
- Ticket 1 должен быть завершен (BadgeView, NavigationRow)

## Технические требования

### 1. TitleAndValueRow Component
Создать `ios/Zariz/Presentation/Common/Components/TitleAndValueRow.swift`

**Функциональность:**
- Заголовок слева, значение справа
- Enum `SelectionStyle`: `.none`, `.disclosure`, `.highlight`
- Поддержка `isLoading` состояния
- Настраиваемое выравнивание значения (`.leading`, `.trailing`, `.center`)
- Bold опция для заголовка
- Multiline поддержка
- Опциональная иконка-суффикс для заголовка
- AdaptiveStack для автоматической вертикальной компоновки на малых экранах

**Адаптация под Zariz:**
- Упростить `Value` enum: `.text(String)`, `.placeholder`, `.icon(Image)`
- Убрать сложные binding для titleWidth (не требуется в MVP)
- Использовать существующие стили текста Zariz
- Loading state через ProgressView

**Применение:**
- Детали заказа (адрес, телефон, сумма)
- Настройки профиля курьера
- Информационные строки в списках

### 2. Интеграция в существующие экраны

**OrderDetailView улучшения:**
- Заменить текущие Text пары на TitleAndValueRow
- Добавить BadgeView для статуса заказа
- Использовать NavigationRow для перехода к карте/контактам

**SettingsView улучшения:**
- Все навигационные элементы через NavigationRow
- BadgeView для новых функций/настроек
- TitleAndValueRow для отображения текущих значений (имя, email, версия)

**OrderListView улучшения:**
- BadgeView для индикации срочных заказов
- Визуальные метки статусов

## Критерии приемки
- [ ] TitleAndValueRow рендерит все варианты значений
- [ ] TitleAndValueRow поддерживает все SelectionStyle
- [ ] TitleAndValueRow показывает loading state
- [ ] TitleAndValueRow адаптируется под узкие экраны (AdaptiveStack)
- [ ] OrderDetailView использует новые компоненты
- [ ] SettingsView использует NavigationRow для всех пунктов
- [ ] BadgeView применен для статусов/меток где уместно
- [ ] Все интеграции работают в светлой и темной теме
- [ ] Код соответствует Swift 6 и Clean Architecture
- [ ] SwiftUI previews обновлены для измененных экранов

## Файлы для изменения
- `ios/Zariz/Presentation/Common/Components/TitleAndValueRow.swift` (создать)
- `ios/Zariz/Presentation/Features/Orders/OrderDetailView.swift` (обновить)
- `ios/Zariz/Presentation/Features/Settings/SettingsView.swift` (обновить)
- `ios/Zariz/Presentation/Features/Orders/OrderListView.swift` (обновить)

## Примечания
- Сохранить существующую бизнес-логику, менять только UI
- Не добавлять unit тесты (только если явно запрошено)
- Фокус на визуальном улучшении UX
- Минимальный код - только необходимые изменения
- После интеграции удалить дублирующийся UI код
