# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор проекта

Quarda — нативный macOS-менеджер задач на SwiftUI, реализующий матрицу Эйзенхауэра. Четыре квадранта: сделать (важно + срочно), запланировать (важно, не срочно), делегировать (срочно, не важно), исключить (не важно, не срочно).

Требуется macOS 14+.

## Команды сборки и тестирования

```bash
# Сборка Debug
xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' build

# Сборка Release
xcodebuild -project Quarda.xcodeproj -scheme Quarda -configuration Release -destination 'generic/platform=macOS' build

# Запуск тестов
xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' test

# Запуск отдельного теста
xcodebuild -project Quarda.xcodeproj -scheme Quarda -destination 'platform=macOS' test -only-testing:QuardaTests/TaskQuadrantTests/testTasksCanBeReorderedAndMovedBetweenQuadrants

# Установка (Release + копирование в /Applications)
./install.sh
```

## Архитектура

### Модель данных (SwiftData)

- **TaskItem** (`Models/TaskItem.swift`) — `@Model`-сущность с полями: title, isImportant, isUrgent, isCompleted, createdAt, sortOrder, details, completedAt
- **TaskQuadrant** (`Models/TaskQuadrant.swift`) — enum четырёх квадрантов с вычисляемыми свойствами title, subtitle, systemImage, tint
- **TaskOrganizer** (`Models/TaskOrganizer.swift`) — утилита для сортировки, перемещения и перенумерации задач

### Хранение данных

**AppDataStore** (`Models/AppDataStore.swift`) управляет ModelContainer. Данные хранятся в:
```
~/Library/Application Support/ru.msidukov.Quarda/tasks.store
```

### Структура Views

- **MatrixView** (`Views/MatrixView.swift`) — главный контейнер с сеткой 2×2 из QuadrantView; управляет состоянием показа выполненных задач через `showsCompletedTasks`
- **QuadrantView** — отдельный квадрант с drag & drop
- **AddTaskView / EditTaskView / TaskDetailView** — модальные окна для CRUD-операций
- **CompletedTasksView** — отдельный экран истории выполненных задач

### Паттерны

- **Drag & drop между квадрантами**: через `@State draggedTask` в MatrixView → передаётся в QuadrantView
- **Анимация переключения**: единый `withAnimation(.easeInOut(duration: 0.18))` на `showsCompletedTasks`
- **Сохранение**: `modelContext.save()` вызывается после каждой мутации в async-таске
- **Preview**: используется in-memory ModelContainer (`modelContainer(for: TaskItem.self, inMemory: true)`)

## MCP-сервер

При запуске приложение поднимает локальный MCP-сервер на `http://127.0.0.1:31415/mcp` (код в `Quarda/MCP/`). Порт фиксированный; если порт занят, приложение работает как обычно без MCP (ошибка в логе). Когда приложение закрыто, сервер недоступен.

Инструменты:

- `add_task` — создать задачу. Параметры: `title`, `isImportant`, `isUrgent` (обязательные), `details` (опционально). Задача встаёт в конец своего квадранта и сразу видна в UI.
- `list_tasks` — список задач по квадрантам. Параметр `include_completed` (по умолчанию false) включает выполненные.

Подключение Claude Code — через `.mcp.json` в корне репозитория.