# OLAP-конструктор (справка для курсовой)

**Рисунок 9** в пояснительной записке — схема «звезда» (не этот файл). Исходник диаграммы: [`diagrams/09-olap-star.mmd`](./diagrams/09-olap-star.mmd) → PNG: `diagrams/png/09-olap-star.png` (скрипт `scripts/render-diagrams-fedora.sh`).

Ниже — краткие правила предметной области, чтобы не путать метрики при защите.

## Зерно (grain)

Одна строка факта = **пользователь × календарный день** с любой активностью. Центр схемы — представление `v_olap_daily_facts`.

## Откуда берутся поля (лучи «звезды»)

| Источник | Что даёт в facts |
|----------|------------------|
| `tasks` | `tasks_total`, `tasks_done`, `completion_rate` по **дедлайну** в этот день |
| `diary_entries` | `mood`, `energy`, корзины `mood_bucket` / `energy_bucket` |
| `pattern_logs` | слоты habit: `patterns_scheduled`, `patterns_success` |
| `pattern_markers`, `pattern_day_sessions` | эпизоды и итоги сценариев за день |
| `task_time_logs` | `minutes_logged`, `pomodoro_minutes` |

## Важно не перепутать

- **Задачи** считаются по **дедлайну** в день, а не «все открытые задачи».
- **Паттерны** в facts — это **слоты «паттерн × день»** (сколько слотов было в расписании в дату), а не число уникальных `pattern_id`.
- **`avg_mood`** — только дни с записью дневника; дни без записи отфильтровываются через `mood_bucket: none`.

## Измерения (для UI и SQL)

| ID | Назначение |
|----|------------|
| `week` | основной срез по времени |
| `month` | длинные периоды |
| `weekday` | день недели (ISO) |
| `day` | детализация (период ≤ 30 дней) |
| `mood_bucket` / `energy_bucket` | low / mid / high / none |

## API

- `GET /stats/meta` — список измерений и мер
- `POST /stats/olap` — тело: `dimensions[]`, `measures[]`, `date_from`, `date_to`, `filters` (только `mood_bucket`, `energy_bucket`)

**Рисунок 10** — только скриншот страницы «Статистика» с блоком OLAP (делаете вы).
