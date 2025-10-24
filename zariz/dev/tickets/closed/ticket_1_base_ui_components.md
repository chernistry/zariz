# Ticket 1: Реализация базовых переиспользуемых UI компонентов

Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

## Цель
Внедрить production-grade переиспользуемые SwiftUI компоненты из WooCommerce iOS для улучшения визуальной системы Zariz: BadgeView и NavigationRow.

## Контекст
Анализ кодовой базы WooCommerce iOS выявил продвинутые паттерны UI компонентов, которые значительно улучшат дизайн-систему Zariz. Первый этап фокусируется на базовых строительных блоках.

## Технические требования

### 1. BadgeView Component
Создать `ios/Zariz/Presentation/Common/Components/BadgeView.swift`

**Функциональность:**
- Поддержка типов: `.new`, `.tip`, `.customText(String)`
- Кастомизация цветов (текст, фон)
- Две формы фона: `.roundedRectangle(cornerRadius)`, `.circle`
- Адаптация под Dynamic Type
- Белая обводка (1pt) для визуального разделения

**Адаптация под Zariz:**
- Использовать цвета из существующей палитры Zariz
- Убрать зависимость от `.remoteImage` (не требуется в MVP)
- Применить Swift 6 strict concurrency

**Применение:**
- Бейджи "Новый" для новых функций
- Статусные индикаторы в списках заказов
- Визуальные метки в настройках

### 2. NavigationRow Component
Создать `ios/Zariz/Presentation/Common/Components/NavigationRow.swift`

**Функциональность:**
- Generic content через `@ViewBuilder`
- Disclosure indicator (chevron) при `selectable = true`
- Минимальная высота 44pt (accessibility)
- Поддержка safe area insets
- Disabled state когда `selectable = false`

**Адаптация под Zariz:**
- Интеграция с существующими стилями текста
- Использовать SF Symbols для disclosure indicator
- Поддержка темной темы

**Применение:**
- Навигационные строки в настройках
- Переходы к деталям заказа
- Списки выбора (курьеры, статусы)

## Критерии приемки
- [ ] BadgeView рендерит все типы бейджей корректно
- [ ] BadgeView поддерживает кастомные цвета и формы
- [ ] NavigationRow работает с произвольным content
- [ ] NavigationRow показывает/скрывает disclosure indicator
- [ ] Оба компонента адаптируются под Dynamic Type
- [ ] Оба компонента работают в светлой и темной теме
- [ ] Код соответствует Swift 6 и архитектуре Zariz
- [ ] Добавлены SwiftUI previews для обоих компонентов

## Файлы для создания
- `ios/Zariz/Presentation/Common/Components/BadgeView.swift`
- `ios/Zariz/Presentation/Common/Components/NavigationRow.swift`

## Зависимости
Нет (базовые компоненты)

## Примечания
- Не добавлять unit тесты (только если явно запрошено)
- Фокус на визуальном качестве и переиспользуемости
- Следовать минималистичному подходу - только необходимый код
