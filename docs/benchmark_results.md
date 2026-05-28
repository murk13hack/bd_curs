# Результаты бенчмарка ПТТ (для таблицы 9 курсовой)

**Дата прогона:** 2026-05-28T11:26:56+03:00
**Контейнер:** `ptt-db` · **БД:** `ptt`
**Задач (user_id=1):** 0
**Записей дневника:** 0
**Нагрузка tasks:** 10000

---

## Таблица 9 — скопируйте этот блок ассистенту

| № | Запрос | Индекс / объект | Shared read (buffers) | Время exec (мс) | Узел плана (кратко) | Вывод |
|---|--------|-----------------|------------------------|-----------------|---------------------|-------|
| Q1 | `fn_get_calendar_stats(1, 2025, 5)` | агрегат по tasks.deadline, idx_tasks_use | 0 | — | — | календарь месяца; сравнить с лимитом ТЗ 250 мс ⚠ Не удалось разобрать JSON плана |
| Q3 | `tasks по topic_id + status` | idx_tasks_topic_status | 0 | — | — | типовой список задач в UI ⚠ Не удалось разобрать JSON плана |
| Q4 | `fn_calculate_streak(pattern_id)` | idx_pattern_logs_pattern_date | 0 | — | — | расчёт серии паттерна ⚠ Не удалось разобрать JSON плана |
| Q5 | `OLAP v_olap_daily_facts по неделям` | view → tasks, diary, pattern_logs, task_ | 0 | — | — | срез OLAP за год ⚠ Не удалось разобрать JSON плана |
| Q6 | `FTS tasks (bench)` | idx_tasks_search_gin | 0 | — | — | поиск по задачам на нагрузочном наборе ⚠ Не удалось разобрать JSON плана |
| Q2a | `fn_search_diary(1, 'продуктивность') (без GIN)` | — (idx_diary_fts_gin снят) | 0 | — |  | базовый Seq Scan / медленнее ⚠ Не удалось разобрать JSON плана |
| Q2b | `fn_search_diary(1, 'продуктивность') (с GIN)` | idx_diary_fts_gin | 0 | — |  | Bitmap Index Scan, ускорение FTS ⚠ Не удалось разобрать JSON плана |

---

## Фрагменты планов (для рисунков 11–13)

---

## Текст для чата (скопируйте целиком)

```
Результаты бенчмарка ПТТ:
tasks=0, diary=0

Q1: exec=— ms, shared_read=0, nodes=—
Q3: exec=— ms, shared_read=0, nodes=—
Q4: exec=— ms, shared_read=0, nodes=—
Q5: exec=— ms, shared_read=0, nodes=—
Q6: exec=— ms, shared_read=0, nodes=—
Q2a: exec=— ms, shared_read=0, nodes=
Q2b: exec=— ms, shared_read=0, nodes=
```
