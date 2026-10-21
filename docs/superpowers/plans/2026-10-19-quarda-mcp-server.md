# MCP-сервер внутри Quarda — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Встроить в Quarda локальный MCP-сервер (read + add задач), доступный Claude Code, пока открыто приложение.

**Architecture:** NWListener слушает `127.0.0.1:31415`, принимает `POST /mcp` с JSON-RPC 2.0 (подмножество MCP: `initialize`, `notifications/initialized`, `ping`, `tools/list`, `tools/call`). Маршрутизатор протокола (`MCPRouter`) чистый и тестируемый без сокетов; работа с задачами — через `TaskToolHandler` поверх общего ModelContainer на `@MainActor`, поэтому UI обновляется сам.

**Tech Stack:** Swift, SwiftUI, SwiftData, Network.framework (без сторонних зависимостей), XCTest.

**Spec:** `docs/superpowers/specs/2026-10-19-quarda-mcp-server-design.md`

## Global Constraints

- macOS 14+, никаких сторонних зависимостей и Swift-пакетов.
- Только IPv4 loopback `127.0.0.1`, порт `31415`; порт занят — сервер не поднимается, приложение работает дальше (ошибка только в лог).
- Мутации задач — только на `@MainActor`, `modelContext.save()` после каждой мутации.
- Новые `.swift`-файлы надо регистрировать в `Quarda.xcodeproj/project.pbxproj` вручную (проект без synchronized groups).
- Тесты: `xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' test`.
- Protocol version MCP: `2025-03-26`.

## Review Focus

1. Тело HTTP-запроса, пришедшее по TCP в нескольких пакетах — сервер обязан дочитать до Content-Length, а не парсить первый кусок. (тест в Task 4)
2. Порт 31415 уже занят другим процессом — приложение стартует и работает без MCP, без падения. (ручная проверка в Task 5)
3. `add_task` без `title` или без флагов — JSON-RPC ошибка/результат с `isError: true`, а не краш и не задача с пустым именем. (тест в Task 3)
4. `id` в JSON-RPC запросе строкой (`"abc"`) и числом (`1`) — оба валидны, ответ возвращает тот же id. (тест в Task 1)
5. Тело запроса — не JSON вовсе — ответ с ошибкой `-32700`, соединение не зависает. (тест в Task 4)

---

### Task 1: JSONValue и JSON-RPC типы

**Files:**
- Create: `Quarda/MCP/MCPProtocol.swift`
- Test: `QuardaTests/MCPProtocolTests.swift`
- Modify: `Quarda.xcodeproj/project.pbxproj` (регистрация файлов)

**Interfaces:**
- Consumes: ничего.
- Produces (используется в Task 2–4):
  - `enum JSONValue: Codable, Equatable` — кейсы `.string(String)`, `.number(Double)`, `.bool(Bool)`, `.object([String: JSONValue])`, `.array([JSONValue])`, `.null`.
  - `struct JSONRPCRequest: Codable, Equatable` — поля `jsonrpc: String`, `id: JSONValue?`, `method: String`, `params: [String: JSONValue]?`.
  - `enum JSONRPCResponse` — статические фабрики:
    - `static func result(id: JSONValue?, _ result: JSONValue) -> JSONValue` → `.object(["jsonrpc": "2.0", "id": id ?? .null, "result": result])`
    - `static func error(id: JSONValue?, code: Int, message: String) -> JSONValue` → объект с `"error": {"code": …, "message": …}`.

- [ ] **Step 1: Падающий тест**

В `QuardaTests/MCPProtocolTests.swift` (XCTest, `@testable import Quarda`):

```swift
func testRequestDecodesWithIntId() throws — декодировать JSON `{"jsonrpc":"2.0","id":1,"method":"ping"}` в JSONRPCRequest; XCTAssertEqual(request.id, .number(1)).
func testRequestDecodesWithStringId() throws — то же с `"id":"abc"`; XCTAssertEqual(request.id, .string("abc")).
func testBoolDoesNotDecodeAsNumber() throws — JSONValue из `true` даёт `.bool(true)`, из `1` — `.number(1)`.
func testResultResponseKeepsId() — JSONRPCResponse.result(id: .string("abc"), .object([:])) кодируется в JSON, содержащий `"id":"abc"` и `"result":{}`.
```

- [ ] **Step 2: Убедиться, что тесты не компилируются/падают**

Run: `xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' test -only-testing:QuardaTests/MCPProtocolTests 2>&1 | tail -5`
Expected: ошибка компиляции — типов нет.

- [ ] **Step 3: Реализовать типы в `Quarda/MCP/MCPProtocol.swift`**

`JSONValue` — Codable через single value container: пробовать `decodeNil` → `Bool` → `Double` → `String` → `[JSONValue]` → `[String: JSONValue]`; encode симметрично. `Equatable` — синтезированный.

- [ ] **Step 4: Зарегистрировать оба файла в `project.pbxproj`**

По существующему шаблону с последовательными hex-ID: для каждого файла добавить запись `PBXBuildFile` (A1…), `PBXFileReference` (A2…), внести в children соответствующей группы (создать группу `MCP` с `path = MCP;` внутри группы `Quarda`; тест — в группу `QuardaTests`) и в фазу Sources соответствующего таргета (app — для `MCPProtocol.swift`, tests — для `MCPProtocolTests.swift`).

- [ ] **Step 5: Прогнать тесты — зелёные**

Run: та же команда из Step 2. Expected: 4 теста PASS.

- [ ] **Step 6: Commit**

```bash
git add Quarda/MCP/MCPProtocol.swift QuardaTests/MCPProtocolTests.swift Quarda.xcodeproj/project.pbxproj
git commit -m "feat: JSON-RPC типы для MCP-сервера"
```

---

### Task 2: MCPRouter — маршрутизация методов протокола

**Files:**
- Modify: `Quarda/MCP/MCPProtocol.swift` (или Create `Quarda/MCP/MCPRouter.swift` с регистрацией в pbxproj — на выбор исполнителя, в плане далее `MCPRouter` отдельным типом)
- Test: `QuardaTests/MCPRouterTests.swift` (+ регистрация в pbxproj, если файлы новые)

**Interfaces:**
- Consumes: `JSONValue`, `JSONRPCRequest`, `JSONRPCResponse` из Task 1.
- Produces (используется в Task 3–4):
  - `protocol MCPToolHandling` — `func listTasks(includeCompleted: Bool) throws -> JSONValue` и `func addTask(title: String, isImportant: Bool, isUrgent: Bool, details: String?) throws -> JSONValue`.
  - `struct MCPRouter` — `init(tools: MCPToolHandling)`; `func handle(_ request: JSONRPCRequest) async -> JSONValue?` (nil = ответ не нужен, нотификация).
- Поведение методов:
  - `initialize` → result: `{"protocolVersion":"2025-03-26","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"quarda-mcp","version":"1.0.0"}}`
  - `notifications/initialized` (и любой метод с префиксом `notifications/`) → nil
  - `ping` → result `.object([:])`
  - `tools/list` → result `{"tools": [<дескрипторы add_task и list_tasks>]}` со схемами из спеки
  - `tools/call` — params: `name`, `arguments` (object). Диспетчеризация по имени; неизвестный инструмент → `JSONRPCResponse.error(code: -32602, message: "Unknown tool: <name>")`
  - неизвестный метод → `JSONRPCResponse.error(code: -32601, message: "Method not found: <method>")`

- [ ] **Step 1: Падающие тесты со стабом `MCPToolHandling`**

В `QuardaTests/MCPRouterTests.swift`, стаб записывает вызовы и возвращает `.object(["ok": .bool(true)])`:

```swift
func testInitializeReturnsServerInfo() async — handle initialize → объект с protocolVersion "2025-03-26" и serverInfo.name "quarda-mcp".
func testInitializedNotificationReturnsNil() async — handle notifications/initialized → nil.
func testUnknownMethodReturnsError() async — handle "bogus/method" → error code -32601.
func testToolsListContainsBothTools() async — tools/list → имена "add_task" и "list_tasks", у add_task required = ["title","isImportant","isUrgent"].
func testUnknownToolReturnsInvalidParams() async — tools/call с name "nope" → error code -32602.
func testToolCallDispatchesArguments() async — tools/call add_task с arguments {title:"T",isImportant:true,isUrgent:false} → стаб получил именно эти значения; ответ — result, не error.
```

- [ ] **Step 2: Прогнать — не компилируется**

Run: `xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' test -only-testing:QuardaTests/MCPRouterTests 2>&1 | tail -5`
Expected: ошибка компиляции.

- [ ] **Step 3: Реализовать `MCPToolHandling` и `MCPRouter`**

`handle` синхронно матчит `request.method`; вызовы `tools.*` делегирует `tools` (actor-хоп на MainActor — ответственность реализации handler'а в Task 3, роутер вызывает через `await` только если протокол это требует; проще: роутер вызывает синхронно, а `TaskToolHandler` в Task 3 решает изоляцию сам).

- [ ] **Step 4: Прогнать тесты — зелёные**

Run: та же команда. Expected: 6 тестов PASS.

- [ ] **Step 5: Commit**

```bash
git add Quarda/MCP/ QuardaTests/MCPRouterTests.swift Quarda.xcodeproj/project.pbxproj
git commit -m "feat: маршрутизатор MCP-протокола"
```

---

### Task 3: TaskToolHandler — add_task и list_tasks поверх SwiftData

**Files:**
- Create: `Quarda/MCP/MCPTools.swift` (+ регистрация в pbxproj, таргет app)
- Test: `QuardaTests/MCPToolsTests.swift` (+ регистрация, таргет tests)

**Interfaces:**
- Consumes: `MCPToolHandling`, `JSONValue` (Task 1–2); `TaskItem`, `TaskQuadrant`, `TaskOrganizer`, `AppDataStore.makeModelContainer(at:)` (существующие).
- Produces (используется в Task 4–5):
  - `@MainActor final class TaskToolHandler: MCPToolHandling` — `init(container: ModelContainer)`; внутри держит `ModelContext`.
- Результат инструмента — MCP tool result: `.object(["content": .array([.object(["type": "text", "text": .string(<JSON-полезная нагрузка строкой>)])]), "isError": .bool(false)])`.
- `addTask`: валидация — пустой/пробельный `title` → вернуть tool result с `isError: true` и текстом причины (не бросать). Иначе `TaskItem(title:quadrant:details:)`, `sortOrder = TaskOrganizer.nextSortOrder(for:in:)`, `context.insert`, `context.save()`. Полезная нагрузка: `{"title":…,"quadrant":"doNow|schedule|delegate|eliminate","sortOrder":…}`.
- `listTasks`: активные задачи (или все при `includeCompleted == true`), плоский массив объектов `{title, quadrant, isImportant, isUrgent, details, isCompleted, createdAt, completedAt}` (даты ISO8601), порядок — как в `TaskOrganizer.ordered` по квадрантам.

- [ ] **Step 1: Падающие тесты (in-memory контейнер)**

`@MainActor final class MCPToolsTests: XCTestCase`, контейнер — `try! ModelContainer(for: Schema([TaskItem.self]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])`:

```swift
func testAddTaskCreatesTaskInCorrectQuadrantAtEnd() — addTask(title:"A",isImportant:true,isUrgent:false,details:"d") → в контексте одна задача, quadrant == .schedule, details == "d", isCompleted == false; вторая addTask в тот же квадрант получает sortOrder на 1 больше.
func testAddTaskRejectsBlankTitle() — addTask(title:"  ",…) → isError == true, задач в контексте 0.
func testListTasksExcludesCompletedByDefault() — создать активную и выполненную; listTasks(includeCompleted:false) → только активная; listTasks(includeCompleted:true) → обе.
func testRouterCallAddTaskEndToEnd() — MCPRouter(tools: handler), tools/call add_task → result (не error), задача появилась в контейнере.
```

Для чтения полезной нагрузки из tool result в тестах: извлечь `content[0].text`, распарсить как JSON через `JSONSerialization`.

- [ ] **Step 2: Прогнать — не компилируется**

Run: `xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' test -only-testing:QuardaTests/MCPToolsTests 2>&1 | tail -5`
Expected: ошибка компиляции.

- [ ] **Step 3: Реализовать `TaskToolHandler`**

`nextSortOrder` вызывать с массивом всех задач из `context.fetch(FetchDescriptor<TaskItem>())`.

- [ ] **Step 4: Прогнать тесты — зелёные**

Run: та же команда. Expected: 4 теста PASS.

- [ ] **Step 5: Commit**

```bash
git add Quarda/MCP/MCPTools.swift QuardaTests/MCPToolsTests.swift Quarda.xcodeproj/project.pbxproj
git commit -m "feat: инструменты add_task и list_tasks"
```

---

### Task 4: MCPServer — HTTP поверх NWListener

**Files:**
- Create: `Quarda/MCP/MCPServer.swift` (+ регистрация в pbxproj, таргет app)
- Test: `QuardaTests/MCPServerTests.swift` (+ регистрация, таргет tests)

**Interfaces:**
- Consumes: `JSONRPCRequest`, `JSONRPCResponse`, `MCPRouter` (Task 1–2).
- Produces (используется в Task 5):
  - `@MainActor final class MCPServer` — `init(router: MCPRouter, port: UInt16 = 31415)`, `func start() throws` (при занятом порте `NWListener` бросает — пробросить вызывающему), `func stop()`, `var actualPort: UInt16?` (актуальный порт; нужен для тестов с портом 0).
- Поведение:
  - слушает только `NWHostEndpoint` `127.0.0.1` (loopback, IPv4);
  - читает из соединения до конца HTTP-заголовков (`\r\n\r\n`), парсит `Content-Length`, дочитывает тело целиком — в т.ч. если оно пришло частями;
  - `POST /mcp`: тело не парсится как JSON → ответ 200 с JSON-RPC `-32700` ("Parse error"); `batch`-массивы не поддерживаем → `-32600`; валидный запрос → `router.handle`, ответ сериализуется в JSON с `Content-Type: application/json`; нотификация (router вернул nil) → 202 без тела;
  - `GET /mcp` → 405; прочие пути → 404;
  - HTTP/1.1, keep-alive не гарантируем: после ответа соединение можно закрывать (`Connection: close`).

- [ ] **Step 1: Падающие тесты**

`@MainActor final class MCPServerTests: XCTestCase`; в `setUp` поднять сервер на порту 0 со стаб-роутером (initialize отвечает как в Task 2), взять `actualPort`, обращаться через `URLSession` и `NWConnection`:

```swift
func testPostInitializeReturnsResult() async throws — POST /mcp с телом initialize → 200, тело содержит "quarda-mcp".
func testGetReturns405() async throws — GET /mcp → 405.
func testMalformedJSONReturnsParseError() async throws — POST /mcp с телом "not json" → 200, тело содержит -32700.
func testBodySplitAcrossWrites() async throws — NWConnection: отправить заголовки с правильным Content-Length, потом тело двумя кусками с паузой; дождаться полного ответа с "quarda-mcp".
```

- [ ] **Step 2: Прогнать — не компилируется**

Run: `xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' test -only-testing:QuardaTests/MCPServerTests 2>&1 | tail -5`
Expected: ошибка компиляции.

- [ ] **Step 3: Реализовать `MCPServer`**

Приём соединений и чтение — на отдельной `DispatchQueue`; вызовы роутера — через `Task { await router.handle(...) }` (роутер и handler main-actor-изолированы — хоп через await).

- [ ] **Step 4: Прогнать тесты — зелёные**

Run: та же команда. Expected: 4 теста PASS.

- [ ] **Step 5: Commit**

```bash
git add Quarda/MCP/MCPServer.swift QuardaTests/MCPServerTests.swift Quarda.xcodeproj/project.pbxproj
git commit -m "feat: HTTP-транспорт MCP-сервера на NWListener"
```

---

### Task 5: Запуск сервера вместе с приложением

**Files:**
- Modify: `Quarda/QuardaApp.swift`

**Interfaces:**
- Consumes: `MCPServer`, `MCPRouter`, `TaskToolHandler` (Task 2–4).
- Produces: работающее приложение, у которого при запуске поднят MCP на `127.0.0.1:31415`.

- [ ] **Step 1: Изменить `QuardaApp`**

В `init()` после создания `modelContainer`: создать `TaskToolHandler(container:)`, `MCPRouter(tools:)`, `MCPServer(router:)` (порт по умолчанию), сохранить в свойство, вызвать `start()` в `do/catch` — при ошибке только `print("MCP server unavailable: \(error)")` в лог, приложение продолжает работу. Сервер держать сильной ссылкой в свойстве `QuardaApp`.

- [ ] **Step 2: Сборка**

Run: `xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Ручная проверка живого сервера**

Собрать и запустить приложение (`open` на собранный `.app` из DerivedData), затем:

```bash
curl -s -X POST http://127.0.0.1:31415/mcp -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
```
Expected: JSON с `"name":"quarda-mcp"`.
Затем `tools/call` `add_task` — задача видна в UI приложения без перезапуска.

- [ ] **Step 4: Ручная проверка занятого порта (Review Focus #2)**

Занять порт (`nc -l 31415 &`), запустить приложение. Expected: приложение открывается и работает, в консоли Xcode/Terminal — строка о недоступности MCP. Убить `nc`.

- [ ] **Step 5: Commit**

```bash
git add Quarda/QuardaApp.swift
git commit -m "feat: запуск MCP-сервера вместе с приложением"
```

---

### Task 6: Подключение Claude Code и документация

**Files:**
- Create: `.mcp.json`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: работающий сервер из Task 5.
- Produces: конфиг, с которым Claude Code видит инструменты `add_task`/`list_tasks`.

- [ ] **Step 1: Создать `.mcp.json` в корне репозитория**

```json
{
  "mcpServers": {
    "quarda": { "type": "http", "url": "http://127.0.0.1:31415/mcp" }
  }
}
```

- [ ] **Step 2: Дописать в `AGENTS.md` раздел про MCP**

Короткий раздел: приложение поднимает MCP-сервер на `127.0.0.1:31415/mcp` при запуске; инструменты `add_task` (title, isImportant, isUrgent, details?) и `list_tasks` (include_completed?); если приложение закрыто — инструменты недоступны; порт фиксированный.

- [ ] **Step 3: Полный прогон тестов**

Run: `xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' test 2>&1 | tail -5`
Expected: все тесты PASS.

- [ ] **Step 4: Commit**

```bash
git add .mcp.json AGENTS.md
git commit -m "feat: конфиг MCP для Claude Code и документация"
```

---

## Self-Review

1. **Spec coverage:** транспорт/порт/failure mode (Task 4–5), инструменты и схемы (Task 2–3), threading через общий контейнер на MainActor (Task 3, 5), `.mcp.json` (Task 6), юнит-тесты на уровне обработчиков + ручная проверка (Task 3–5) — всё покрыто. Структура файлов `Quarda/MCP/` — Task 1–4.
2. **Step scan:** каждый шаг — одно действие с проверяемым результатом; тела алгоритмов не продиктованы там, где сигнатура и тесты определяют реализацию.
3. **Type consistency:** `JSONValue`, `JSONRPCRequest`, `JSONRPCResponse`, `MCPToolHandling`, `MCPRouter.handle(_:) async -> JSONValue?`, `TaskToolHandler.init(container:)`, `MCPServer.init(router:port:)/start()/stop()/actualPort` — имена и сигнатуры совпадают между задачами.
4. **Review Focus:** все 5 пунктов привязаны к тестам/проверкам (Task 4 ×2, Task 5, Task 3, Task 1).
5. **Proportion:** план компаративен со спекой; кодовые блоки — только тестовые утверждения и точные значения из спеки.
