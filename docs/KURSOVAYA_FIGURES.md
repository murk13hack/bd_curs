# Перечень рисунков и таблиц (сквозная нумерация)

Используется в [KURSOVAYA_BD.md](./KURSOVAYA_BD.md). **Рисунки 1–10** — в основном тексте (после первой ссылки). **Рисунки 11–14** — в приложении (планы EXPLAIN, скриншоты). Исходники: `docs/diagrams/`.

| № | Подпись | Где вставить | Исходник / действие |
|---|---------|--------------|---------------------|
| 1 | ER-диаграмма базы данных ПТТ | § 5.2 | `diagrams/01-er-full.mmd` |
| 2 | Трёхзвенная архитектура и слой PostgreSQL | § 4.1 | `diagrams/02-architecture.mmd` |
| 3 | BPMN процесса завершения задачи | § 3.2 | `diagrams/03-bpmn-complete-task.bpmn` |
| 4 | BPMN суточного цикла паттерна habit | § 3.3 | `diagrams/04-bpmn-pattern-habit.bpmn` |
| 5 | Диаграмма состояний `tasks.status` | § 3.2 | `diagrams/05-state-task.puml` |
| 6 | Диаграмма состояний `pattern_logs.status` | § 3.3 | `diagrams/06-state-pattern-log.puml` |
| 7 | Диаграмма деятельности планировщика БД | § 3.7 | `diagrams/07-activity-daily.puml` |
| 8 | Последовательность запроса календаря месяца | § 3.6 | `diagrams/08-sequence-calendar.mmd` |
| 9 | Зерно OLAP и источники фактов | § 9.2 | нарисовать по § 9 / OLAP.md |
| 10 | Экран OLAP-конструктора (статистика) | § 9.4 | скрин `stats-page` / olap-builder |
| 11 | План Q1: `fn_get_calendar_stats` | Прил. Е | `explain_out.txt` фрагмент |
| 12 | План Q2: `fn_search_diary` (GIN) | Прил. Е | до/после индекса |
| 13 | План Q3: выборка задач по теме | Прил. Е | `benchmark_explain.sql` |
| 14 | Схема развёртывания Docker Compose | Прил. Б | draw.io / ТЗ приложение Б |

**Таблицы** нумеруются отдельно: Таблица 1, 2, … (см. текст записки).
