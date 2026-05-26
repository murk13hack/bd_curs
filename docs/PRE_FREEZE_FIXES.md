# План исправлений перед code-freeze

Документ составлен по результатам полного аудита проекта (БД, backend, frontend, docs).  
Цель: устранить баги и расхождения до защиты курсовой по БД.

**Оценка суммарно:** ~2–3 рабочих дня (можно разбить на 3 волны).

---

## Как пользоваться

- [ ] — не сделано  
- [x] — сделано  
- Каждый пункт: **проблема → файлы → действия → проверка → что написать в отчёте**

Волны выполнять по порядку: **P0 → P1 → P2 → P3**.

---

## Волна P0 — блокеры (до freeze и деплоя на защиту)

### P0-1. Синхронизировать миграции 012–013 во всех deploy-инструкциях

**Проблема:** `DB_SYNC.md` указывает **007→013**, а `DEPLOY.md`, `deploy-fedora.sh`, комментарии в скриптах — только до **011**. На старом volume без 012/013 возможны ошибки overlap time-logs и `tasks_start_after_created`.

**Файлы:**
- `docs/DEPLOY.md` (§11, §12, списки миграций)
- `scripts/deploy-fedora.sh`
- `scripts/apply-migrations.sh` (комментарий «007–011»)
- `README.md` (если есть упоминание диапазона)

**Действия:**
1. Везде заменить диапазон на **007 → 013**.
2. Добавить описание:
   - `012_time_logs_allow_overlap.sql` — снят exclusion на пересечение интервалов time-logs.
   - `013_drop_tasks_start_after_created.sql` — разрешён `start_at` раньше `created_at`.
3. В DEPLOY явно: «свежий volume = только init; существующий volume = 007–013».

**Проверка:**
- [ ] Прогнать `./scripts/apply-migrations.sh` на тестовом volume с 011 → убедиться, что 012/013 применяются.
- [ ] Создать задачу с `start_at` на минуту раньше «сейчас» — 201, не CheckViolation.

**Отчёт:** раздел «Миграции и версионирование схемы».

---

### P0-2. Починить `apply-migrations.ps1`

**Проблема:** Windows-скрипт прогоняет **все** миграции 001–013 подряд; повторный запуск опасен. Bash-версия фильтрует `>= 007`.

**Файлы:**
- `scripts/apply-migrations.ps1`

**Действия:**
1. Фильтровать только файлы с номером **≥ 007** (как в bash `recent`).
2. Добавить `ON_ERROR_STOP=1` в psql.
3. Опционально: параметр `-All` для полного прогона (dev only), по умолчанию — safe mode.

**Проверка:**
- [ ] Дважды запустить скрипт на БД с уже применёнными 007–013 — второй раз без падений (идемпотентность DROP IF EXISTS / IF NOT EXISTS).

**Отчёт:** приложение «Развёртывание», подраздел Windows.

---

### P0-3. Исправить «18 таблиц» → фактические **23**

**Проблема:** В init, README, DB_SYNC, models docstring — «18 таблиц», в `03-tables.sql` — 23 `CREATE TABLE`.

**Файлы:**
- `db/init/03-tables.sql` (комментарий L3, NOTICE L334)
- `docs/DB_SYNC.md`
- `README.md` (L17 и др.)
- `backend/app/models/__init__.py` (docstring)
- `db/init/00-readme.sql` (порядок файлов, если устарел)

**Действия:**
1. Зафиксировать формулировку для отчёта, например:  
   **«23 таблицы (18 базовых по ТЗ + 5 для режимов паттернов: steps, sessions, answers, markers, closures)»**.
2. Обновить все упоминания «18» на согласованную формулировку.
3. Исправить `00-readme.sql`: порядок `05-functions`, `06-views` (не наоборот).

**Проверка:**
- [ ] `grep -r "18 таблиц"` — только осмысленные контексты (история ТЗ), не как текущее число.

**Отчёт:** ER-диаграмма и перечень таблиц — все 23.

---

### P0-4. Согласовать ТЗ и схему по overlap time-logs

**Проблема:** В ТЗ может быть EXCLUSION `task_time_logs_no_overlap`; в текущей схеме overlap разрешён (012). `btree_gist` установлен, но constraint не используется.

**Файлы:**
- `ТЗ.md` (если в репозитории) или текст курсовой
- `docs/DB_SYNC.md` — дополнить обоснование
- `db/init/03-tables.sql` — комментарий к `task_time_logs`

**Действия:**
1. **Не возвращать** exclusion (ломает Pomodoro multi-task) — зафиксировать решение в документации.
2. Добавить абзац: «Параллельный учёт времени по разным задачам допустим; exclusion снят миграцией 012 по требованию UX».

**Проверка:**
- [ ] `test_time_logs_overlap_allowed` проходит.
- [ ] Два пересекающихся лога на разные задачи — 201.

**Отчёт:** раздел «Проектные решения / отступления от ТЗ».

---

### P0-5. Баг обзора: «Выполнено сегодня» всегда 0

**Проблема:** KPI считается из `view: 'active'`, завершённые задачи не попадают в выборку.

**Файлы:**
- `frontend/src/pages/dashboard-page.tsx`

**Действия:**
1. Добавить отдельный запрос, например:
   - `api.tasks.list({ view: 'completed', limit: 200 })`, фильтр `completed_at` за сегодня, **или**
   - новый query-параметр на backend `completed_on=YYYY-MM-DD` (если нужна точность).
2. Минимальный вариант без backend: второй запрос `view: 'completed'`.

**Проверка:**
- [ ] Завершить задачу сегодня → KPI «Выполнено сегодня» = 1.

**Отчёт:** не обязательно; UX-fix для демо.

---

## Волна P1 — важно для защиты по БД

### P1-1. Подключить stats API к SQL views (или честно описать расхождение)

**Проблема:** Views `v_task_topic_breakdown`, `v_stats_task_priority`, `v_topic_time_distribution` есть в БД, но `stats.py` дублирует SQL inline — на защите сложно показать «view используется приложением».

**Файлы:**
- `backend/app/api/v1/stats.py` — endpoints `/topics`, `/priorities`, `/time-distribution`
- `db/init/06-views.sql` — при необходимости добавить параметризуемые обёртки или фильтрацию
- `docs/DB_SYNC.md`

**Действия (рекомендуемый вариант A):**
1. Переписать endpoints на `SELECT ... FROM v_* WHERE ...` с фильтром по датам через JOIN/WHERE.
2. Если view не содержит user_id/даты — расширить view или создать `v_*_period(user_id, from, to)` как SQL function.

**Действия (вариант B — только документация):**
1. В DB_SYNC указать: «view = эталон; API — параметризованный дубликат для REST».
2. В отчёте показать side-by-side SQL view и endpoint.

**Проверка:**
- [ ] Существующие тесты `test_stats.py` проходят.
- [ ] `EXPLAIN` на запросе показывает scan по view (если вариант A).

**Отчёт:** «Использование представлений в прикладном слое».

---

### P1-2. `v_overdue_tasks` — использовать или демote

**Проблема:** Materialized view обновляется scheduler'ом, но нигде не читается.

**Файлы:**
- `db/init/06-views.sql`
- `db/init/07-procedures.sql` — `sp_recalc_calendar_cache`
- `backend/app/api/v1/tasks.py` или `calendar.py`
- `frontend/src/pages/calendar-page.tsx` или `dashboard-page.tsx`

**Действия (вариант A — подключить):**
1. `GET /api/v1/tasks/overdue` или поле в calendar day stats из `v_overdue_tasks`.
2. На обзоре/календаре — блок «Просроченные».

**Действия (вариант B — документировать):**
1. Комментарий в SQL + DB_SYNC: «кэш для будущего API».
2. В отчёте не заявлять как рабочую фичу UI.

**Проверка:**
- [ ] После `sp_recalc_calendar_cache` — SELECT из matview возвращает строки для просроченных задач.

---

### P1-3. Валидация `goal_links` при создании цели

**Проблема:** `POST /goals` с `links` не вызывает `_validate_link_target`; битые `target_id` сохраняются.

**Файлы:**
- `backend/app/api/v1/goals.py` — `create_goal`
- `backend/tests/test_goals.py`

**Действия:**
1. Перед flush links вызывать `_validate_link_target` для каждого link.
2. Тест: `POST /goals` с `target_id: 999999` → 404.

**Проверка:**
- [ ] pytest `test_create_goal_invalid_link_rejected`

---

### P1-4. Detach recurring — сброс `task.recurring_rule_id`

**Проблема:** При отключении повторения rule деактивируется, ссылка на задаче остаётся.

**Файлы:**
- `backend/app/api/v1/tasks.py` — `detach_task_recurring`
- `backend/tests/test_recurring.py` или `test_tasks.py`

**Действия:**
1. После `rule.is_active = False` установить `task.recurring_rule_id = None`.
2. Тест: detach → GET task → `recurring_rule_id is null`.

---

### P1-5. Человекочитаемые ошибки IntegrityError

**Проблема:** Сырые сообщения PostgreSQL уходят клиенту.

**Файлы:**
- `backend/app/api/v1/tasks.py` (create/update/reopen)
- `backend/app/api/v1/recurring_rules.py`
- Новый helper: `backend/app/api/errors.py` или `backend/app/services/db_errors.py`

**Действия:**
1. Общая функция `integrity_error_to_http(exc) -> HTTPException`.
2. Маппинг известных constraint: `tasks_start_before_deadline`, `tasks_deadline_after_created`, FK topics/tags и т.д.
3. Fallback: «Некорректные данные задачи» без SQL-текста.

**Проверка:**
- [ ] Создать задачу с `start_at >= deadline` → понятное сообщение, не `asyncpg.exceptions...`.

---

### P1-6. Расширить `db/tests/smoke.sql`

**Проблема:** Smoke не покрывает markers/scenario, 013, overlap, custom recurrence.

**Файлы:**
- `db/tests/smoke.sql`

**Действия — добавить блоки:**
1. Insert task с `start_at` < `created_at` (после 013) — OK.
2. Два overlapping time-logs на разных задачах — OK.
3. Marker pattern: insert marker + day closure.
4. Scenario: session + step answer.
5. `fn_next_recurring_date` с `custom` / `interval_days`.
6. SELECT из ключевых views (`v_pattern_streaks`, `v_olap_daily_facts`).

**Проверка:**
- [ ] `psql -f db/tests/smoke.sql` — без ERROR.

---

### P1-7. Тест на регрессию 013 в pytest

**Файлы:**
- `backend/tests/test_tasks.py`

**Действия:**
1. `test_create_task_start_at_before_created_allowed`: создать задачу, где `start_at` = now - 1 min, `deadline` = now + 1 h → 201.

---

### P1-8. Исправить NOTICE-счётчики в init SQL

**Проблема:** Неверные числа ENUM/функций/процедур в RAISE NOTICE.

**Файлы:**
- `db/init/02-types.sql`
- `db/init/05-functions.sql`
- `db/init/07-procedures.sql`

**Действия:**
1. Пересчитать и обновить NOTICE или убрать конкретные числа («types created», «functions created»).

---

## Волна P2 — UX и документация (быстрые wins)

### P2-1. «Ближайшие задачи» на обзоре

**Файлы:** `frontend/src/pages/dashboard-page.tsx`

**Действия:**
1. Сортировать active tasks по `deadline ASC NULLS LAST`.
2. Или переименовать блок в «Активные задачи».

**Проверка:** задача с ближайшим дедлайном — первая в списке.

---

### P2-2. ErrorBanner на страницах без обработки ошибок

**Файлы:**
- `frontend/src/pages/goals-page.tsx` (list + progress)
- `frontend/src/pages/pomodoro-page.tsx`
- `frontend/src/pages/calendar-page.tsx`
- `frontend/src/pages/diary-page.tsx` (month/recent)
- `frontend/src/components/stats/stats-connections-teaser.tsx`

**Действия:** паттерн как на `stats-page.tsx`: `isError` → `<ErrorBanner />`.

---

### P2-3. Убрать технический текст из UI статистики

**Файлы:** `frontend/src/pages/stats-page.tsx`

**Действия:**
1. Удалить «примените миграцию 011».
2. «time-log» → «учёт времени» / «запись времени».

---

### P2-4. Обновить README и DEPLOY

**Файлы:**
- `README.md`
- `docs/DEPLOY.md`

**Действия:**
1. Число тестов: ~96 pytest (актуализировать).
2. Возможности: habit + **scenario** + **markers**, OLAP, «Связи показателей», Pomodoro multi-session.
3. Ссылки: `STATS.md`, `OLAP.md`, `DB_SYNC.md`, `PATTERNS_SCENARIO.md`, **этот файл**.
4. Таблицы: 23 (с пояснением).

---

### P2-5. Валидация `topic_id` при create task/pattern

**Файлы:**
- `backend/app/api/v1/tasks.py`
- `backend/app/api/v1/patterns.py`
- `backend/tests/test_tasks.py`

**Действия:** проверка `Topic.user_id == current_user` перед insert (как для tags).

---

### P2-6. OpenAPI: typed responses

**Файлы:**
- `backend/app/api/v1/patterns.py` — `get_streak` → `PatternStreakRead`
- `backend/app/api/v1/stats.py` — `completion_rate` → response model

---

### P2-7. Pomodoro: empty state при пустом поиске

**Файлы:** `frontend/src/pages/pomodoro-page.tsx`

**Действия:** «Ничего не найдено» при фильтре без совпадений.

---

### P2-8. Settings: подсказки при пустых темах/тегах

**Файлы:** `frontend/src/pages/settings-page.tsx`

---

### P2-9. Favicon

**Файлы:**
- `frontend/public/favicon.ico`
- `frontend/index.html`

**Действия:** добавить иконку (уведомления паттернов ссылаются на `/favicon.ico`).

---

### P2-10. Удалить или пометить legacy API во frontend

**Файлы:** `frontend/src/api/client.ts`

**Действия:**
- `api.stats.correlation`, `api.stats.holistic` — удалить или `@deprecated` + комментарий «заменено diary-insights».

---

### P2-11. XSS в поиске дневника

**Файлы:** `frontend/src/components/diary/diary-search-panel.tsx`

**Действия:**
1. Санитизация HTML сниппета на frontend, **или**
2. Гарантия экранирования на backend в `fn_search_diary` / API.

---

## Волна P3 — по желанию (не блокирует защиту)

### P3-1. NOP-триггер `trg_pattern_streak_recalc`

**Файлы:** `db/init/08-triggers.sql`

**Действия:** удалить триггер + `fn_pattern_streak_touch` или реализовать инвалидацию кэша.

---

### P3-2. Неиспользуемые объекты БД

| Объект | Действие |
|--------|----------|
| `unaccent` extension | удалить или использовать в search |
| trgm indexes topics/tags | удалить или добавить fuzzy search API |
| `btree_gist` | оставить с комментарием «был для exclusion» |

---

### P3-3. Audit: user_id для pattern_logs

**Файлы:** `db/init/08-triggers.sql`

**Действия:** в `fn_audit_log` для pattern-таблиц JOIN `behavior_patterns.user_id`.

---

### P3-4. `sp_ensure_habit_logs_for_day` и timezone

**Файлы:** `db/init/07-procedures.sql`

**Действия:** использовать `users.timezone` вместо hardcode UTC — или документировать UTC-only.

---

### P3-5. Scheduler integration test

**Файлы:** `backend/tests/test_scheduler.py` (новый)

**Действия:** вызов `_spawn_recurring_tasks`, `_recalc_calendar_cache` с test DB.

---

### P3-6. GET /patterns/{id}/today — side effect на GET

**Файлы:** `backend/app/api/v1/patterns.py`

**Действия:** перенести `sp_ensure_habit_logs_for_day` только в scheduler + POST responses; или явно документировать.

---

### P3-7. `PUT /patterns/{id}/steps` — guard при open session

**Файлы:** `patterns.py`, `test_patterns.py`

---

### P3-8. Frontend: lint/test scripts

**Файлы:** `frontend/package.json`

**Действия:** `"lint": "eslint ..."`, опционально vitest smoke.

---

### P3-9. CORS для production

**Файлы:** `backend/app/main.py`, `.env.example`

**Действия:** explicit origins; `allow_credentials=false` при `*`.

---

### P3-10. ORM ↔ SQL appendix alignment

**Файлы:** `backend/app/models/*`

**Действия:** комментарии про domains (`mood_score`, `hex_color`), `content_tsv`; не обязательно менять типы.

---

## Матрица: пункт → волна → оценка

| ID | Кратко | Волна | Часы |
|----|--------|-------|------|
| P0-1 | Миграции 012–013 в DEPLOY | P0 | 0.5 |
| P0-2 | apply-migrations.ps1 | P0 | 0.5 |
| P0-3 | 23 таблицы в docs | P0 | 0.5 |
| P0-4 | Overlap vs ТЗ | P0 | 0.5 |
| P0-5 | KPI «Выполнено сегодня» | P0 | 0.25 |
| P1-1 | Stats → views | P1 | 2–3 |
| P1-2 | v_overdue_tasks | P1 | 1–2 |
| P1-3 | Goal links validate | P1 | 0.5 |
| P1-4 | Recurring detach | P1 | 0.25 |
| P1-5 | IntegrityError messages | P1 | 1 |
| P1-6 | smoke.sql extend | P1 | 1–1.5 |
| P1-7 | pytest 013 | P1 | 0.25 |
| P1-8 | NOTICE counts | P1 | 0.25 |
| P2-1 … P2-11 | UX + docs | P2 | 3–4 |
| P3-* | Cleanup | P3 | 4+ |

**Итого P0+P1 (минимум для защиты):** ~8–10 ч  
**P0+P1+P2 (комфортный freeze):** ~12–14 ч

---

## Рекомендуемый порядок коммитов

1. `fix(deploy): migrations 007-013 sync + ps1 script`
2. `fix(docs): 23 tables, README, DEPLOY test count`
3. `fix(dashboard): done today KPI + nearest tasks sort`
4. `fix(db-api): stats use views, goal links, recurring detach`
5. `fix(api): integrity error messages, topic_id validation`
6. `test(db): smoke.sql + pytest regressions`
7. `fix(ui): error banners, stats copy, favicon`
8. `chore: legacy cleanup (P3)` — опционально после freeze

---

## Чеклист перед защитой (demo day)

- [ ] `git pull && docker compose up -d --build`
- [ ] Миграции 007–013 на demo-volume
- [ ] `pytest` green (~96 tests)
- [ ] `psql -f db/tests/smoke.sql` OK
- [ ] Demo-сценарий:
  - [ ] создать задачу с датами
  - [ ] добавить time-log / Pomodoro → «Время по темам»
  - [ ] habit + scenario + markers
  - [ ] OLAP срез
  - [ ] export JSON → restore
- [ ] Отчёт: ER 23 таблицы, список процедур/триггеров/views, обоснование overlap и goal_links без FK

---

## Связанные документы

- [DB_SYNC.md](./DB_SYNC.md) — карта БД ↔ API  
- [DEPLOY.md](./DEPLOY.md) — развёртывание  
- [STATS.md](./STATS.md) — логика статистики  
- [OLAP.md](./OLAP.md) — OLAP-срезы  
- [PATTERNS_SCENARIO.md](./PATTERNS_SCENARIO.md) — режим scenario

---

*Создано: 2026-05-27. Статус: выполнено в рамках pre-freeze (коммит после аудита).*
