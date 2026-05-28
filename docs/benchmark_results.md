# Результаты бенчмарка ПТТ (таблица 9 курсовой)

**Источник:** `docs/benchmark_explain_out.txt` (ручной прогон `benchmark_run_for_kursovaya.sh`, набор **S2**).

**Объёмы:** tasks user_id=1 — **10 060** (bench 10 000); diary — **578**; patterns — **11**; pattern_logs — **149**.

| № | Время exec (мс) | Shared read | Узел плана | Статус |
|---|-----------------|-------------|------------|--------|
| Q1 | 5,82 | 5 | Merge Left Join, GroupAggregate, Seq Scan tasks | ✓ |
| Q3 | 1,12 | 0 | Bitmap Index Scan `idx_tasks_topic_status` | ✓ |
| Q4 | 3,35 | 0 | Result (PL/pgSQL `fn_calculate_streak`) | ✓ |
| Q5 | — | — | — | ✗ ошибка `avg_mood` в скрипте (исправлено) |
| Q6 | — | — | — | не выполнен (остановка на Q5) |
| Q2a / Q2b | — | — | — | не выполнен (остановка на Q5) |

**Повтор Q5–Q6 и Q2** (после `git pull`):

```bash
docker cp scripts/benchmark_for_kursovaya.sql ptt-db:/tmp/
docker exec ptt-db psql -U ptt -d ptt -f /tmp/benchmark_for_kursovaya.sql >> docs/benchmark_explain_out.txt
```

Полная таблица и интерпретация — глава 10, [KURSOVAYA_BD.md](./KURSOVAYA_BD.md).
