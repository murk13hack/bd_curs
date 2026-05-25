# Синхронизация БД ↔ backend ↔ frontend

Актуально после миграций `009`–`011`.

## Таблицы (18)

Все таблицы из `db/init/03-tables.sql` покрыты ORM (`backend/app/models/`) и REST API.

| Таблица | API |
|---------|-----|
| `users` | seed, не CRUD |
| `topics`, `tags` | `/topics`, `/tags` |
| `tasks`, `task_tags`, `task_time_logs` | `/tasks` |
| `recurring_rules` | `/tasks/{id}/recurring`, `/recurring-rules` |
| `diary_entries`, `diary_tags` | `/diary` |
| `behavior_patterns`, `pattern_*` | `/patterns` |
| `goals`, `goal_links` | `/goals` |
| `holidays` | `/holidays` |
| `app_settings` | `/settings` |
| `audit_log` | только триггер, не API |

## Импорт / экспорт JSON

| Режим | Реализация | Что делает |
|--------|------------|------------|
| **Экспорт** | `sp_export_user_data` | Все сущности пользователя, `schema_version: 2`, включая `pattern_marker_day_closures` |
| **merge** | `sp_import_user_data` (SQL) | Только **темы** и **теги** (идемпотентно) |
| **restore** | `import_user_data` (Python) | Полная замена данных: wipe → вставка из JSON → сброс sequences |

Порядок restore и wipe включает `pattern_marker_day_closures` (после `pattern_markers`).

Ограничения restore:

- Нужен `schema_version >= 2` в файле бэкапа.
- Вставляются **старые id** из экспорта (для одного пользователя в single-tenant режиме это нормально).
- Праздники (`holidays`) и `audit_log` не переносятся — глобальные/служебные.

## Повторение задач (`custom`)

| frequency | params | Логика `fn_next_recurring_date` |
|-----------|--------|----------------------------------|
| `daily` | — | +1 день |
| `weekly` | `weekly_mask` (биты Пн–Вс) | следующий день из маски |
| `monthly` | `monthly_day` (1–31) | тот же день следующего месяца |
| `custom` | `interval_days` (≥1) | +N дней |

UI: редактор повторения в задаче — все четыре режима.

## Функции PostgreSQL

| Функция | Кто вызывает |
|---------|----------------|
| `fn_day_color` | `fn_get_calendar_stats` |
| `fn_pattern_is_scheduled` | insights, goals, OLAP view |
| `fn_pattern_day_has_answer` | insights, streaks |
| `fn_pattern_day_success` | insights, goals, streaks |
| `fn_calculate_streak` | `v_pattern_streaks`, API streak |
| `fn_calculate_max_streak` | API streak |
| `fn_pattern_clean_days_30d` | `v_pattern_streaks` |
| `fn_pattern_day_is_failure` | `fn_calculate_anti_streak` |
| `fn_calculate_anti_streak` | `v_pattern_streaks`, API streak |
| `fn_completion_rate` | `/stats/completion-rate` |
| `fn_search_diary` | `/diary/search` |
| `fn_goal_progress` | `/goals/{id}/progress` |
| `fn_next_recurring_date` | tasks, recurring-rules, `sp_spawn_recurring_tasks` |
| `fn_get_calendar_stats` | `/calendar/{year}/{month}` |

Удалены как дубли (миграция 009): `fn_mood_productivity_corr`, `fn_topic_time_breakdown`.

## Представления

| View | API |
|------|-----|
| `v_task_topic_breakdown` | `/stats/topics` |
| `v_pattern_streaks` | `/patterns/streaks/all`, `/stats/patterns` |
| `v_overdue_tasks` | обновляется `sp_recalc_calendar_cache` (кэш, не в REST) |
| `v_mood_productivity_correlation` | `/stats/correlation` |
| `v_olap_daily_facts` | `/stats/olap`, overview |
| `v_mood_holistic_correlation` | `/stats/holistic` |
| `v_stats_task_priority` | `/stats/priorities` |
| `v_weekly_summary` | `/stats/weekly` |
| `v_year_heatmap` | `/calendar/heatmap` |
| `v_task_subtree_progress` | поля `subtask_*` в `TaskRead` |
| `v_topic_time_distribution` | `/stats/time-distribution` |

## Процедуры

| Процедура | Кто вызывает |
|-----------|----------------|
| `sp_complete_task` | POST `/tasks/{id}/complete` |
| `sp_reopen_task` | POST `/tasks/{id}/reopen` |
| `sp_log_pattern_response` | POST `/patterns/{id}/responses` |
| `sp_spawn_recurring_tasks` | APScheduler 00:05 |
| `sp_ensure_habit_logs_for_day` | scheduler + GET `/patterns/{id}/today` (habit) |
| `sp_close_overdue_pattern_logs` | APScheduler каждый час |
| `sp_recalc_calendar_cache` | APScheduler каждые 10 мин |
| `sp_archive_old_audit` | APScheduler вс 03:00 |
| `sp_export_user_data` | GET `/export/json` |
| `sp_import_user_data` | POST `/import/json` **mode=merge** |

## Миграции на существующей БД

```powershell
docker cp db/migrations/007_pattern_logic_fixes.sql ptt-db:/tmp/
docker exec ptt-db psql -U ptt -d ptt -f /tmp/007_pattern_logic_fixes.sql
docker cp db/migrations/008_marker_day_closures.sql ptt-db:/tmp/
docker exec ptt-db psql -U ptt -d ptt -f /tmp/008_marker_day_closures.sql
docker cp db/migrations/009_db_backend_sync.sql ptt-db:/tmp/
docker exec ptt-db psql -U ptt -d ptt -f /tmp/009_db_backend_sync.sql
docker cp db/migrations/010_recurring_custom_interval.sql ptt-db:/tmp/
docker exec ptt-db psql -U ptt -d ptt -f /tmp/010_recurring_custom_interval.sql
```

Свежий `docker compose up` с пустым volume использует актуальные `db/init/*.sql`.
