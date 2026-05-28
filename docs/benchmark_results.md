# Результаты бенчмарка ПТТ (таблица 9)

**Источник:** `docs/benchmark_explain_out.txt` · набор **S2** · 28.05.2026

**Объёмы:** tasks **10 060** (bench 10 000), diary **578**, patterns **11**, pattern_logs **149**.

| № | exec (мс) | shared read | Узел плана |
|---|-----------|-------------|------------|
| Q1 | 4,64 | 0 | Merge Left Join, GroupAggregate, Seq Scan tasks |
| Q2a | 1,10 | 0 | Seq Scan diary_entries |
| Q2b | 1,06 | 0 | Seq Scan diary_entries (GIN не выбран на S2) |
| Q3 | 1,31 | 0 | Bitmap Index Scan idx_tasks_topic_status |
| Q4 | 3,32 | 0 | Result PL/pgSQL |
| Q5 | 8,76 | 0 | GroupAggregate на v_olap_daily_facts |
| Q6 | 1,04 | 0 | Seq Scan tasks (FTS в Filter) |

Полная таблица и интерпретация — [KURSOVAYA_BD.md](./KURSOVAYA_BD.md), глава 10.
