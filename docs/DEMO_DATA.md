# Демонстрационные данные

Объёмный набор тестовых данных для демонстрации **всех возможностей** ПТТ перед защитой курсовой или для скриншотов в отчёте.

Базовый seed (`db/init/09-seed.sql`) **не заменяется**: темы «Работа», «Учёба», праздники РФ и настройки остаются. Демо-данные добавляются поверх и удаляются по реестру `app_settings._demo_dataset`.

## Быстрый старт

```powershell
# Windows (контейнер ptt-db должен быть запущен)
.\scripts\demo-data.ps1 seed
.\scripts\demo-data.ps1 status
.\scripts\demo-data.ps1 wipe
```

```bash
# Linux / Fedora / macOS
chmod +x scripts/demo-data.sh
./scripts/demo-data.sh seed
./scripts/demo-data.sh status
./scripts/demo-data.sh wipe
```

Повторная загрузка без ошибки:

```powershell
.\scripts\demo-data.ps1 seed -Force
```

```bash
FORCE=1 ./scripts/demo-data.sh seed
```

## Что входит в набор

| Область | Содержимое |
|--------|------------|
| **Темы и теги** | 4 темы `Демо: …`, 8 тегов `демо-*` + использование базовых тем |
| **Задачи** | ~50+ задач: все приоритеты и статусы, подзадачи, архив, overdue (триггер), `start_at` / `deadline` / `planned_minutes` |
| **Повторения** | daily, weekly, monthly, custom (`interval_days`) + порождённые экземпляры |
| **Время** | ~150 записей `task_time_logs`, Pomodoro и обычные, пересекающиеся интервалы |
| **Дневник** | ~80 записей за 90 дней, mood/energy, FTS-текст, теги |
| **Habit** | boolean positive/negative, multi-option, расписания, 60 дней логов (answered/missed/pending), `auto_create_task` |
| **Scenario** | 2 сценария, шаги note/single_choice, сессии completed/in_progress/abandoned, ответы |
| **Markers** | 2 паттерна, эпизоды, `declare-clean-day`, insights |
| **Цели** | 5 целей, выполненная и активные, `goal_links` к задачам и паттернам |
| **Праздники** | 2 пользовательских (`is_official = false`) |
| **Кэш** | `CALL sp_recalc_calendar_cache()` после seed/wipe |

Все сущности помечены префиксом `[демо]` / `Демо:` в названиях для удобства в UI.

## Файлы

| Файл | Назначение |
|------|------------|
| `db/demo/seed_demo.sql` | Загрузка (генерируется скриптом) |
| `db/demo/wipe_demo.sql` | Удаление по реестру ID |
| `scripts/demo-data.ps1` | Обёртка Windows |
| `scripts/demo-data.sh` | Обёртка Linux |
| `scripts/generate_demo_seed.py` | Перегенерация `seed_demo.sql` при изменении логики |

Перегенерация SQL после правок генератора:

```powershell
python scripts/generate_demo_seed.py
```

## Ручной запуск через psql

```powershell
docker cp db/demo/seed_demo.sql ptt-db:/tmp/seed_demo.sql
docker exec ptt-db psql -U ptt -d ptt -v ON_ERROR_STOP=1 -f /tmp/seed_demo.sql
```

## Проверка после загрузки

1. **Dashboard** — KPI, ближайшие и просроченные задачи.
2. **Задачи** — фильтры, подзадачи, повторения, теги.
3. **Статистика** — время по темам, OLAP, weekly summary.
4. **Календарь** — heatmap, праздники.
5. **Дневник** — поиск FTS («PostgreSQL»).
6. **Паттерны** — habit streaks, scenario insights, markers hourly.
