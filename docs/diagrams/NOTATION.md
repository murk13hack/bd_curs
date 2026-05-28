# Нотации диаграмм проекта ПТТ

Исходники лежат в `docs/diagrams/`. Каждый файл — текст разметки для внешнего рендерера. В пояснительной записке после экспорта вставляйте **рисунок** (PNG/SVG) и подпись по ГОСТ: «Рисунок N — …».

## Рекомендуемые сервисы

| Сервис | Форматы | Зачем | URL |
|--------|---------|-------|-----|
| **Mermaid Live Editor** | `.mmd` | ER, sequence, state, flowchart; быстрый экспорт PNG/SVG | https://mermaid.live |
| **PlantUML Online** | `.puml` | диаграммы состояний, activity (аналог BPMN), deployment | https://www.plantuml.com/plantuml |
| **draw.io (diagrams.net)** | импорт `.drawio`, BPMN-шаблоны | официальная BPMN 2.0, ручная доводка для защиты | https://app.diagrams.net |
| **Camunda Modeler** | `.bpmn` | строгая BPMN 2.0 XML, валидация нотации | https://camunda.com/download/modeler/ |
| **Kroki** | Mermaid, PlantUML, BPMN через URL | вставка в Markdown/GitLab | https://kroki.io |
| **dbdiagram.io** | DBML (опционально) | только ER из таблиц | https://dbdiagram.io |

**Практическая связка для курсовой:** черновик в Mermaid/PlantUML → финальный рисунок в draw.io или Camunda (BPMN) → вставка в Word с нумерацией «Рисунок 1…».

**Автоэкспорт PNG на Fedora:** `./scripts/render-diagrams-fedora.sh` → `docs/diagrams/png/` (см. [scripts/diagrams-render/README.md](../../scripts/diagrams-render/README.md)). Файлы `.bpmn` без BPMNDI вручную не рисуются — скрипт добавляет разметку через `bpmn-auto-layout`.

## Условные обозначения (для текста записки)

| Символ / элемент | Нотация | Значение в ПТТ |
|------------------|---------|----------------|
| Прямоугольник с закруглением | BPMN: Task | Действие пользователя или системы |
| Двойной прямоугольник | BPMN: Sub-process | Вызов `sp_*` / пакет SQL |
| Ромб | BPMN: Gateway XOR | Ветвление по условию (статус, режим паттерна) |
| Цилиндр | ER / Archimate | Таблица PostgreSQL |
| Стрелка сплошная | Поток управления / FK | Порядок шагов или ссылка |
| Стрелка пунктир | Данные / REST | JSON API, чтение view |
| `<<trigger>>` | UML / PlantUML | Триггер `trg_*` |
| `<<proc>>` | UML | Хранимая процедура `sp_*` |
| `<<fn>>` | UML | Функция `fn_*` |

## Соответствие файлов и рисунков записки

| Файл | Рисунок в записке | Нотация |
|------|-------------------|---------|
| `01-er-full.mmd` | Рисунок 1 — ER-диаграмма | Mermaid `erDiagram` |
| `02-architecture.mmd` | Рисунок 2 — Развёртывание | Mermaid `flowchart` |
| `03-bpmn-complete-task.bpmn` | Рисунок 3 — BPMN завершения задачи | BPMN 2.0 XML → PNG скриптом |
| `04-bpmn-pattern-habit.bpmn` | Рисунок 4 — BPMN паттерна habit | BPMN 2.0 XML → PNG скриптом |
| `png/03-*.png`, `png/04-*.png` | готовые рис. 3–4 | после `render-diagrams-fedora.sh` |
| `05-state-task.puml` | Рисунок 5 — Диаграмма состояний задачи | PlantUML state |
| `06-state-pattern-log.puml` | Рисунок 6 — Состояния pattern_logs | PlantUML state |
| `07-activity-daily.puml` | Рисунок 7 — Суточный цикл планировщика | PlantUML activity |
| `08-sequence-calendar.mmd` | Рисунок 8 — Запрос календаря | Mermaid sequence |
