#!/usr/bin/env python3
"""
Прогон бенчмарков EXPLAIN (ANALYZE, BUFFERS) для курсовой (таблица 9).

Использование (из корня репозитория):
  ./scripts/benchmark_report.sh
  ./scripts/benchmark_report.sh --count 10000 --skip-load

  # напрямую (то же самое):
  python3 scripts/benchmark_report.py --count 10000

Требования: Docker, контейнер ptt-db running, файл .env.

Результат:
  docs/benchmark_results.md   — таблица + фрагменты планов (отправить ассистенту)
  docs/benchmark_results.json — машиночитаемый отчёт
  docs/benchmark_plans/*.txt   — только этот скрипт (не benchmark_run_for_kursovaya.sh)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
PLANS_DIR = DOCS / "benchmark_plans"


@dataclass
class QuerySpec:
    id: str
    label: str
    sql: str
    index_note: str
    conclusion: str


@dataclass
class QueryResult:
    spec: QuerySpec
    execution_ms: float | None
    planning_ms: float | None
    shared_read: int
    shared_hit: int
    plan_nodes: list[str]
    raw_plan_text: str = ""
    error: str | None = None


def load_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def docker_psql(
    container: str,
    user: str,
    database: str,
    sql: str,
    *,
    tuples_only: bool = False,
    timeout: int = 600,
) -> str:
    cmd = [
        "docker",
        "exec",
        container,
        "psql",
        "-U",
        user,
        "-d",
        database,
        "-v",
        "ON_ERROR_STOP=1",
    ]
    if tuples_only:
        # -q: без NOTICE; -F: явный разделитель (иначе на части сборок psql пустые поля)
        cmd.extend(["-t", "-A", "-q", "-F", "|", "--no-psqlrc"])
    proc = subprocess.run(
        cmd,
        input=sql,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=timeout,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"psql failed ({proc.returncode}):\n{proc.stderr}\n{proc.stdout}"
        )
    # NOTICE и прочее иногда только в stderr
    if proc.stderr.strip():
        return proc.stdout + ("\n" if proc.stdout else "") + proc.stderr
    return proc.stdout


def docker_psql_file(
    container: str, user: str, database: str, host_path: Path, variables: dict[str, str] | None = None
) -> str:
    inner = f"/tmp/{host_path.name}"
    subprocess.run(
        ["docker", "cp", str(host_path), f"{container}:{inner}"],
        check=True,
        capture_output=True,
        text=True,
    )
    var_sql = ""
    if variables:
        for k, v in variables.items():
            var_sql += f"\\set {k} {v}\n"
    return docker_psql(container, user, database, var_sql + f"\\i {inner}\n")


def container_running(name: str) -> bool:
    r = subprocess.run(
        ["docker", "inspect", "-f", "{{.State.Running}}", name],
        capture_output=True,
        text=True,
    )
    return r.returncode == 0 and r.stdout.strip() == "true"


def walk_plan(node: dict, nodes: list[str], shared_read: list[int], shared_hit: list[int]) -> None:
    if not isinstance(node, dict):
        return
    nt = node.get("Node Type")
    if nt:
        rel = node.get("Relation Name") or node.get("Index Name") or ""
        extra = f" ({rel})" if rel else ""
        nodes.append(f"{nt}{extra}")
    for key in ("Shared Read Blocks", "Shared Hit Blocks"):
        if key in node:
            val = int(node[key])
            if key.endswith("Read Blocks"):
                shared_read.append(val)
            else:
                shared_hit.append(val)
    for child in node.get("Plans") or []:
        walk_plan(child, nodes, shared_read, shared_hit)


def explain_json(
    container: str, user: str, database: str, sql: str
) -> tuple[dict | None, str]:
    explain_sql = (
        "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)\n" + sql.strip().rstrip(";") + ";\n"
    )
    # -t -A: одна строка JSON; без этого psql рисует «таблицу» с '+' — json.loads ломается
    out = docker_psql(
        container, user, database, explain_sql, timeout=300, tuples_only=True
    )
    stripped = out.strip()
    if not stripped:
        return None, out or "(пустой stdout psql)"

    candidates: list[str] = []
    if stripped.startswith("["):
        candidates.append(stripped)
    m = re.search(r"\[\s*\{", stripped, re.DOTALL)
    if m:
        candidates.append(stripped[m.start() :])

    for json_text in candidates:
        try:
            data = json.loads(json_text)
            if isinstance(data, list) and data:
                return data[0], out
        except json.JSONDecodeError:
            continue

    return None, out


def parse_explain(plan_root: dict) -> tuple[float | None, float | None, int, int, list[str]]:
    exec_ms = plan_root.get("Execution Time")
    plan_ms = plan_root.get("Planning Time")
    nodes: list[str] = []
    reads: list[int] = []
    hits: list[int] = []
    walk_plan(plan_root.get("Plan") or {}, nodes, reads, hits)
    # кратко: первые 4 значимых узла
    brief = []
    for n in nodes:
        if n not in brief and n not in ("Result", "Limit"):
            brief.append(n)
        if len(brief) >= 4:
            break
    return exec_ms, plan_ms, sum(reads), sum(hits), brief


def plan_to_text(plan_root: dict) -> str:
    lines = [
        f"Planning Time: {plan_root.get('Planning Time')} ms",
        f"Execution Time: {plan_root.get('Execution Time')} ms",
    ]

    def rec(node: dict, indent: int) -> None:
        pad = "  " * indent
        nt = node.get("Node Type", "?")
        rel = node.get("Relation Name") or node.get("Index Name") or ""
        tail = f" on {rel}" if rel else ""
        t = node.get("Actual Total Time")
        time_s = f", time={t:.3f}ms" if isinstance(t, (int, float)) else ""
        sr = node.get("Shared Read Blocks")
        sh = node.get("Shared Hit Blocks")
        buf = ""
        if sr is not None or sh is not None:
            buf = f", read={sr}, hit={sh}"
        lines.append(f"{pad}-> {nt}{tail}{time_s}{buf}")
        for ch in node.get("Plans") or []:
            rec(ch, indent + 1)

    rec(plan_root.get("Plan") or {}, 0)
    return "\n".join(lines)


def get_counts(container: str, user: str, database: str) -> dict[str, int]:
    """Счётчики строк; устойчив к разным форматам вывода psql -t -A."""
    sql = """
SELECT 'tasks' AS k, COUNT(*)::text AS v FROM tasks WHERE user_id = 1
UNION ALL
SELECT 'diary', COUNT(*)::text FROM diary_entries WHERE user_id = 1
UNION ALL
SELECT 'pattern_logs', COUNT(*)::text FROM pattern_logs;
"""
    out = docker_psql(container, user, database, sql, tuples_only=True)
    counts = {"tasks": 0, "diary": 0, "pattern_logs": 0}
    for line in out.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        if "|" in line:
            key, _, val = line.partition("|")
        elif "\t" in line:
            key, _, val = line.partition("\t")
        else:
            parts = line.split()
            if len(parts) < 2:
                continue
            key, val = parts[0], parts[-1]
        key = key.strip()
        val = val.strip()
        if key in counts and val.isdigit():
            counts[key] = int(val)

    if not any(counts.values()) and out.strip():
        raise RuntimeError(
            "Не удалось разобрать счётчики из psql. Вывод:\n" + out[:500]
        )
    return counts


def build_queries() -> list[QuerySpec]:
    return [
        QuerySpec(
            "Q1",
            "fn_get_calendar_stats(1, 2025, 5)",
            "SELECT * FROM fn_get_calendar_stats(1, 2025, 5)",
            "агрегат по tasks.deadline, idx_tasks_user_completed_at",
            "календарь месяца; сравнить с лимитом ТЗ 250 мс",
        ),
        QuerySpec(
            "Q2",
            "fn_search_diary(1, 'продуктивность')",
            "SELECT * FROM fn_search_diary(1, 'продуктивность', 50)",
            "idx_diary_fts_gin (GIN content_tsv)",
            "FTS дневника; сравнить с лимитом ТЗ 300 мс",
        ),
        QuerySpec(
            "Q3",
            "tasks по topic_id + status",
            """
SELECT id, title, status, deadline
  FROM tasks
 WHERE user_id = 1
   AND topic_id = (SELECT id FROM topics WHERE user_id = 1 LIMIT 1)
   AND status = 'pending'
 ORDER BY deadline NULLS LAST
 LIMIT 200
""",
            "idx_tasks_topic_status",
            "типовой список задач в UI",
        ),
        QuerySpec(
            "Q4",
            "fn_calculate_streak(pattern_id)",
            """
SELECT fn_calculate_streak(
  (SELECT id FROM behavior_patterns WHERE user_id = 1 LIMIT 1)
)
""",
            "idx_pattern_logs_pattern_date",
            "расчёт серии паттерна",
        ),
        QuerySpec(
            "Q5",
            "OLAP v_olap_daily_facts по неделям",
            """
SELECT date_trunc('week', day)::date AS week,
       SUM(tasks_total), SUM(tasks_done),
       ROUND(AVG(mood)::numeric, 2)
  FROM v_olap_daily_facts
 WHERE user_id = 1 AND day BETWEEN '2025-01-01' AND '2025-12-31'
 GROUP BY 1 ORDER BY 1
""",
            "view → tasks, diary, pattern_logs, task_time_logs",
            "срез OLAP за год",
        ),
        QuerySpec(
            "Q6",
            "FTS tasks (bench)",
            """
SELECT id, title FROM tasks
 WHERE user_id = 1
   AND to_tsvector('russian', coalesce(title,'') || ' ' || coalesce(description,''))
       @@ plainto_tsquery('russian', 'bench')
 LIMIT 50
""",
            "idx_tasks_search_gin",
            "поиск по задачам на нагрузочном наборе",
        ),
    ]


def run_query(
    container: str, user: str, database: str, spec: QuerySpec
) -> QueryResult:
    try:
        root, raw = explain_json(container, user, database, spec.sql)
        if not root:
            return QueryResult(
                spec=spec,
                execution_ms=None,
                planning_ms=None,
                shared_read=0,
                shared_hit=0,
                plan_nodes=[],
                raw_plan_text=raw,
                error="Не удалось разобрать JSON плана",
            )
        exec_ms, plan_ms, sr, sh, nodes = parse_explain(root)
        return QueryResult(
            spec=spec,
            execution_ms=exec_ms,
            planning_ms=plan_ms,
            shared_read=sr,
            shared_hit=sh,
            plan_nodes=nodes,
            raw_plan_text=plan_to_text(root),
        )
    except Exception as e:
        return QueryResult(
            spec=spec,
            execution_ms=None,
            planning_ms=None,
            shared_read=0,
            shared_hit=0,
            plan_nodes=[],
            error=str(e),
        )


def fmt_ms(v: float | None) -> str:
    if v is None:
        return "—"
    return f"{v:.2f}"


def write_reports(
    results: list[QueryResult],
    q2a: QueryResult | None,
    q2b: QueryResult | None,
    meta: dict,
) -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    PLANS_DIR.mkdir(parents=True, exist_ok=True)

    rows: list[dict] = []
    for r in results:
        if r.spec.id == "Q2":
            continue
        rows.append(
            {
                "id": r.spec.id,
                "query": r.spec.label,
                "index": r.spec.index_note,
                "shared_read": r.shared_read,
                "exec_ms": r.execution_ms,
                "nodes": " → ".join(r.plan_nodes) if r.plan_nodes else "—",
                "conclusion": r.spec.conclusion,
                "error": r.error,
            }
        )
    if q2a:
        rows.append(
            {
                "id": "Q2a",
                "query": q2a.spec.label + " (без GIN)",
                "index": "— (idx_diary_fts_gin снят)",
                "shared_read": q2a.shared_read,
                "exec_ms": q2a.execution_ms,
                "nodes": " → ".join(q2a.plan_nodes),
                "conclusion": "базовый Seq Scan / медленнее",
                "error": q2a.error,
            }
        )
    if q2b:
        rows.append(
            {
                "id": "Q2b",
                "query": q2b.spec.label + " (с GIN)",
                "index": "idx_diary_fts_gin",
                "shared_read": q2b.shared_read,
                "exec_ms": q2b.execution_ms,
                "nodes": " → ".join(q2b.plan_nodes),
                "conclusion": "Bitmap Index Scan, ускорение FTS",
                "error": q2b.error,
            }
        )

    def write_plan_file(plan_id: str, r: QueryResult) -> None:
        parts: list[str] = []
        if r.error:
            parts.append(f"# {r.error}\n")
        if r.raw_plan_text:
            parts.append(r.raw_plan_text)
        elif not r.error:
            parts.append("(нет текста плана)")
        (PLANS_DIR / f"{plan_id}_plan.txt").write_text("".join(parts), encoding="utf-8")

    for r in results:
        if r.spec.id == "Q2":
            continue
        write_plan_file(r.spec.id, r)
    if q2a:
        write_plan_file("Q2a", q2a)
    if q2b:
        write_plan_file("Q2b", q2b)

    json_path = DOCS / "benchmark_results.json"
    json_path.write_text(
        json.dumps({"meta": meta, "rows": rows}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    md_lines = [
        "# Результаты бенчмарка ПТТ (для таблицы 9 курсовой)",
        "",
        f"**Дата прогона:** {meta['timestamp']}",
        f"**Контейнер:** `{meta['container']}` · **БД:** `{meta['database']}`",
        f"**Задач (user_id=1):** {meta['counts']['tasks']}",
        f"**Записей дневника:** {meta['counts']['diary']}",
        f"**Нагрузка tasks:** {meta.get('load_count', '—')}",
        "",
        "---",
        "",
        "## Таблица 9 — скопируйте этот блок ассистенту",
        "",
        "| № | Запрос | Индекс / объект | Shared read (buffers) | Время exec (мс) | Узел плана (кратко) | Вывод |",
        "|---|--------|-----------------|------------------------|-----------------|---------------------|-------|",
    ]
    for row in rows:
        err = f" ⚠ {row['error']}" if row.get("error") else ""
        md_lines.append(
            "| {id} | `{query}` | {index} | {sr} | {ms} | {nodes} | {concl}{err} |".format(
                id=row["id"],
                query=row["query"].replace("|", "\\|")[:60],
                index=row["index"].replace("|", "\\|")[:40],
                sr=row["shared_read"],
                ms=fmt_ms(row["exec_ms"]),
                nodes=row["nodes"].replace("|", "\\|")[:50],
                concl=row["conclusion"],
                err=err,
            )
        )

    if q2a and q2b and q2a.execution_ms and q2b.execution_ms and q2a.execution_ms > 0:
        speedup = q2a.execution_ms / q2b.execution_ms
        md_lines.extend(
            [
                "",
                f"**Ускорение Q2 (GIN):** ~{speedup:.1f}× "
                f"({fmt_ms(q2a.execution_ms)} → {fmt_ms(q2b.execution_ms)} мс)",
            ]
        )

    md_lines.extend(
        [
            "",
            "---",
            "",
            "## Фрагменты планов (для рисунков 11–13)",
            "",
        ]
    )
    plan_by_id = {r.spec.id: r for r in all_results}
    if q2a:
        plan_by_id["Q2a"] = q2a
    if q2b:
        plan_by_id["Q2b"] = q2b
    for key, title in [
        ("Q1", "Рисунок 11 — календарь"),
        ("Q2a", "Рисунок 12a — FTS без GIN"),
        ("Q2b", "Рисунок 12b — FTS с GIN"),
        ("Q3", "Рисунок 13 — задачи по индексу"),
    ]:
        r = plan_by_id.get(key)
        if not r or not r.raw_plan_text:
            continue
        md_lines.append(f"### {title}")
        md_lines.append("")
        md_lines.append("```text")
        md_lines.append(r.raw_plan_text[:3500])
        md_lines.append("```")
        md_lines.append("")

    md_lines.extend(
        [
            "---",
            "",
            "## Текст для чата (скопируйте целиком)",
            "",
            "```",
            "Результаты бенчмарка ПТТ:",
            f"tasks={meta['counts']['tasks']}, diary={meta['counts']['diary']}",
            "",
        ]
    )
    for row in rows:
        md_lines.append(
            f"{row['id']}: exec={fmt_ms(row['exec_ms'])} ms, "
            f"shared_read={row['shared_read']}, nodes={row['nodes']}"
        )
    md_lines.append("```")
    md_lines.append("")

    md_path = DOCS / "benchmark_results.md"
    md_path.write_text("\n".join(md_lines), encoding="utf-8")
    print(f"Wrote {md_path}")
    print(f"Wrote {json_path}")
    print(f"Plans in {PLANS_DIR}/")


def main() -> int:
    parser = argparse.ArgumentParser(description="PTT DB benchmark report")
    parser.add_argument("--container", default="ptt-db")
    parser.add_argument("--count", type=int, default=10_000, help="Bench tasks to load")
    parser.add_argument("--skip-load", action="store_true")
    parser.add_argument("--no-diary-seed", action="store_true")
    parser.add_argument("--skip-q2-compare", action="store_true")
    args = parser.parse_args()

    env = load_env(ROOT / ".env")
    user = env.get("POSTGRES_USER", "ptt")
    password = env.get("POSTGRES_PASSWORD", "")
    database = env.get("POSTGRES_DB", "ptt")

    if not (ROOT / ".env").exists():
        print(
            "Файл .env не найден. Выполните: Copy-Item .env.example .env",
            file=sys.stderr,
        )
        return 1

    if not container_running(args.container):
        print(
            f"Контейнер '{args.container}' не запущен (или перезапускается).\n"
            "Выполните: docker compose up -d\n"
            "Проверьте: docker compose ps  и  docker compose logs db",
            file=sys.stderr,
        )
        return 1

    print(f"Using {args.container}, db={database}, user={user}")

    if not args.skip_load:
        print(f"Loading {args.count} bench tasks...")
        load_path = ROOT / "scripts" / "benchmark_load_tasks.sql"
        inner_load = "/tmp/benchmark_load_tasks.sql"
        subprocess.run(
            ["docker", "cp", str(load_path), f"{args.container}:{inner_load}"],
            check=True,
        )
        docker_psql(
            args.container,
            user,
            database,
            (
                "DELETE FROM tasks WHERE user_id = 1 AND title LIKE 'Bench #%';\n"
                f"\\set count {args.count}\n"
                f"\\i {inner_load}\n"
            ),
            timeout=600,
        )

    if not args.no_diary_seed:
        print("Seeding diary for FTS...")
        seed_path = ROOT / "scripts" / "benchmark_seed_diary.sql"
        docker_psql_file(args.container, user, database, seed_path)

    counts = get_counts(args.container, user, database)
    print(f"Counts: {counts}")

    queries = build_queries()
    results: list[QueryResult] = []
    q2_spec = next(q for q in queries if q.id == "Q2")

    for spec in queries:
        if spec.id == "Q2" and not args.skip_q2_compare:
            continue
        print(f"Running {spec.id}...")
        results.append(run_query(args.container, user, database, spec))

    if args.skip_q2_compare:
        print("Running Q2 (single, with index)...")
        results.append(run_query(args.container, user, database, q2_spec))

    q2a = q2b = None
    if not args.skip_q2_compare:
        print("Q2a: diary FTS without GIN index...")
        docker_psql(
            args.container,
            user,
            database,
            "DROP INDEX IF EXISTS idx_diary_fts_gin;\n",
        )
        q2a = run_query(args.container, user, database, q2_spec)
        print("Q2b: recreating GIN + diary FTS...")
        docker_psql(
            args.container,
            user,
            database,
            """
CREATE INDEX IF NOT EXISTS idx_diary_fts_gin
    ON diary_entries USING gin (content_tsv);
ANALYZE diary_entries;
""",
        )
        q2b = run_query(args.container, user, database, q2_spec)

    meta = {
        "timestamp": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "container": args.container,
        "database": database,
        "user": user,
        "counts": counts,
        "load_count": None if args.skip_load else args.count,
    }
    write_reports(results, q2a, q2b, meta)
    print("\nГотово. Откройте docs/benchmark_results.md и отправьте блок «Таблица 9» в чат.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
