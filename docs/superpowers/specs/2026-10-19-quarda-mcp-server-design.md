# Дизайн: MCP-сервер внутри Quarda

Дата: 2026-10-19

## Зачем

Пользователь работает с Claude Code и хочет, чтобы Claude мог создавать задачи в Quarda прямо из разговора, а также читать текущую матрицу как контекст. Задачи должны появляться в открытом приложении сразу, через тот же ModelContext, что и UI.

## Цели

- Quarda при запуске поднимает локальный MCP-сервер (только localhost), живущий, пока открыто приложение.
- Claude Code подключается к серверу через запись в `.mcp.json` и получает два инструмента:
  - `list_tasks` — список задач (по умолчанию активные; параметр `include_completed` для включения выполненных). Для каждой задачи: заголовок, квадрант, детали, статус, даты.
  - `add_task` — создать задачу. Параметры: `title` (обязательный), `isImportant`, `isUrgent` (обязательные — Claude явно выбирает квадрант), `details` (опциональный). Задача встаёт в конец своего квадранта (через `TaskOrganizer.nextSortOrder`).
- Создание идёт через тот же ModelContext/ModelContainer, что и UI — интерфейс обновляется сам, без отдельной нотификации.

## Не цели (non-goals)

- Изменение, перемещение между квадрантами, удаление, отметка «выполнено» — только руками в приложении.
- Аутентификация, TLS, доступ извне localhost.
- Работа MCP при закрытом приложении.

## Анти-цели (что будет провалом, даже если «работает»)

- Внешний процесс или Claude, пишущий напрямую в SQLite-файл SwiftData в обход приложения — риск конфликтов и повреждения схемы.
- Падение или блокировка приложения, если порт занят или сервер не стартовал.
- Сторонние зависимости ради транспорта, если протокол ложится на компактную собственную реализацию.

## Ограничения и факты о проекте

- macOS 14+, SwiftUI + SwiftData, Xcode-проект без Swift-пакетов.
- Приложение не sandboxed (нет entitlements, CODE_SIGN_STYLE = Automatic) — слушать localhost можно без дополнительных энтайтлментов. Если sandbox появится в будущем, понадобится `com.apple.security.network.server`.
- Хранилище: `~/Library/Application Support/ru.msidukov.Quarda/tasks.store`, контейнер создаётся в `QuardaApp.init` через `AppDataStore`.
- `TaskItem`: title, isImportant, isUrgent, isCompleted, createdAt, sortOrder, details?, completedAt?. Квадрант — вычисляемый (`TaskQuadrant(isImportant:isUrgent:)`).

## Технические решения (приняты при дизайне, мои — автора дизайна)

- **Транспорт:** MCP «streamable HTTP», один endpoint `POST /mcp` на `http://127.0.0.1:31415`. Реализуется минимальный подмножество протокола: JSON-RPC 2.0 методы `initialize`, `notifications/initialized`, `ping`, `tools/list`, `tools/call`. Ответы — `application/json` без SSE; `GET /mcp` → 405 (SSE-стримы не поддерживаем). MCP-протокол: версия `2025-03-26` (или новее, по факту реализации), заголовок сессии не используем.
- **HTTP-сервер:** на Network.framework (`NWListener`), только IPv4 loopback (`127.0.0.1`). Без Vapor/Hummingbird/сторонних пакетов.
- **Порт:** фиксированный `31415`. Если занят — сервер не поднимается, приложение работает как обычно (ошибка только в лог консоли). Настройки порта в UI нет.
- **Запуск:** сервер стартует в `QuardaApp` после создания ModelContainer (передаём контейнер в сервер). Останавливается вместе с приложением автоматически (слушатель живёт в объекте приложения).
- **Потоки:** Network.framework отдаёт колбэки на своей очереди; обращения к ModelContext и мутaции — на `@MainActor`. Сохранение — `modelContext.save()` после каждой мутации, как в остальном приложении.
- **Структура кода:** новая группа `Quarda/MCP/`:
  - `MCPServer.swift` — NWListener, разбор HTTP-запроса, маршрутизация JSON-RPC.
  - `MCPProtocol.swift` — Codable-типы JSON-RPC и MCP (initialize/tools).
  - `MCPTools.swift` — реализация `list_tasks` и `add_task` поверх ModelContext.
- **Конфиг Claude Code:** в репозиторий добавляется `.mcp.json`:
  ```json
  {
    "mcpServers": {
      "quarda": { "type": "http", "url": "http://127.0.0.1:31415/mcp" }
    }
  }
  ```
  Когда Quarda закрыта, сервер недоступен — инструменты просто отсутствуют, это норма.

## Формат инструментов

`add_task` input schema:
```json
{
  "type": "object",
  "properties": {
    "title": { "type": "string" },
    "isImportant": { "type": "boolean" },
    "isUrgent": { "type": "boolean" },
    "details": { "type": "string" }
  },
  "required": ["title", "isImportant", "isUrgent"]
}
```
Ответ: созданная задача (id, заголовок, квадрант, sortOrder).

`list_tasks` input schema:
```json
{
  "type": "object",
  "properties": {
    "include_completed": { "type": "boolean", "default": false }
  }
}
```
Ответ: массив задач, сгруппированный по квадрантам (или плоский список с полем quadrant — решает исполнитель), с заголовком, деталями, статусом и датами.

## Тестирование

- Юнит-тесты на уровне вызова обработчиков JSON-RPC (без сокета): initialize → tools/list → tools/call(add_task) → tools/call(list_tasks), на in-memory ModelContainer (как существующие тесты).
- Ручная проверка: запустить приложение, добавить `.mcp.json`, убедиться, что Claude Code видит инструменты и созданная задача появляется в UI.

## Что остаётся на исполнителя

- Детали разбора HTTP-поверх-NWListener (чтение заголовков, Content-Length, keep-alive).
- Точная форма ответа `list_tasks` (плоский список vs группировка).
- Тексты описаний инструментов для Claude (на английском или русском).
- Точный номер версии протокола MCP в ответе initialize.
