# -*- coding: utf-8 -*-
"""Содержание рисунков 1–14 для KURSOVAYA_BD.md и build_kursovaya_docx.py."""

from __future__ import annotations

FIGURES: dict[int, dict[str, str]] = {
    1: {
        "title": "ER-диаграмма базы данных ПТТ",
        "content": (
            "Концептуальная модель в нотации «воронья лапка»: сущности users, topics, tags, "
            "tasks, recurring_rules, diary_entries, behavior_patterns (режимы habit / scenario / "
            "markers — разные группы таблиц), goals, goal_links, holidays; связи 1:N и M:N "
            "(task_tags, diary_tags). Отражены суррогатные ключи и основные атрибуты сущностей."
        ),
        "file": "docs/diagrams/png/01-er-full.png",
        "status": "вставлен",
    },
    2: {
        "title": "Трёхзвенная архитектура и слой PostgreSQL",
        "content": (
            "Пользователь обращается по HTTP к веб-клиенту (React, nginx, порт 80); клиент — "
            "к прикладному серверу (FastAPI, REST/JSON, порт 8000); сервер — к PostgreSQL 16 "
            "(порт 5432). Показан том pgdata для персистентности данных."
        ),
        "file": "docs/diagrams/png/02-architecture.png",
        "status": "вставлен",
    },
    3: {
        "title": "BPMN процесса завершения задачи",
        "content": (
            "Участники: пользователь, прикладной сервер, СУБД. Цепочка: отметка о выполнении → "
            "вызов процедуры завершения → фиксация статуса и времени → шлюз «срок нарушен» "
            "(автоматический перевод в «просрочена») → запись в журнал аудита → шлюз "
            "«есть правило повторения» → создание следующего экземпляра задачи → ответ клиенту."
        ),
        "file": "docs/diagrams/png/03-bpmn-complete-task.png",
        "status": "вставлен",
    },
    4: {
        "title": "BPMN суточного цикла привычки",
        "content": (
            "Регламент дня: подготовка слотов отклика по расписанию → ожидание времени "
            "напоминания → шлюз «пользователь ответил в регламентный срок» — ветви «да» "
            "(фиксация ответа, пересчёт серии) и «нет» (пропуск, влияние на серию положительной "
            "привычки) → учёт дня в статистике."
        ),
        "file": "docs/diagrams/png/04-bpmn-pattern-habit.png",
        "status": "вставлен",
    },
    5: {
        "title": "Диаграмма состояний жизненного цикла задачи",
        "content": (
            "Состояния: к выполнению, в работе, выполнена, просрочена, отменена. "
            "Переход в «просрочена» после отметки о выполнении показан как автоматический "
            "(не действие пользователя)."
        ),
        "file": "docs/diagrams/png/05-state-task.png",
        "status": "вставлен",
    },
    6: {
        "title": "Диаграмма состояний слота отклика на привычку",
        "content": (
            "Состояния слота: ожидание ответа → отвечено или пропущено (по истечении "
            "регламентного интервала без ответа)."
        ),
        "file": "docs/diagrams/png/06-state-pattern-log.png",
        "status": "вставлен",
    },
    7: {
        "title": "Диаграмма деятельности регламентных заданий",
        "content": (
            "Фоновые задания без участия пользователя: порождение повторяющихся задач; "
            "подготовка слотов привычек на день; закрытие просроченных откликов; обновление "
            "материализованных агрегатов; архивирование журнала аудита."
        ),
        "file": "docs/diagrams/png/07-activity-daily.png",
        "status": "вставлен",
    },
    8: {
        "title": "Последовательность формирования данных календаря месяца",
        "content": (
            "Пользователь запрашивает календарь месяца → прикладной сервер → функция СУБД "
            "агрегирует задачи по дням, проверяет записи дневника и праздники → возврат "
            "готовых полей (доля выполнения, цвет ячейки) в ответ API."
        ),
        "file": "docs/diagrams/png/08-sequence-calendar.png",
        "status": "вставлен",
    },
    9: {
        "title": "Зерно OLAP и источники фактов",
        "content": (
            "Схема «звезда»: в центре представление v_olap_daily_facts (зерно: пользователь × "
            "день); лучи к источникам — tasks, diary_entries, pattern_logs, pattern_markers, "
            "pattern_day_sessions, task_time_logs. Подписи связей: метрики задач, настроение, "
            "слоты паттернов, минуты работы."
        ),
        "file": "docs/diagrams/png/09-olap-star.png",
        "status": "готов (PNG в репозитории)",
    },
    10: {
        "title": "Интерфейс OLAP-конструктора",
        "content": (
            "Скриншот страницы «Статистика»: блок выбора измерений (неделя, месяц, день недели, "
            "корзины mood/energy) и мер (доля выполненных задач, среднее настроение, минуты "
            "Pomodoro и др.), кнопка построения среза."
        ),
        "file": "страница «Статистика» → блок OLAP (localhost после docker compose up)",
        "status": "скриншот",
    },
    11: {
        "title": "План запроса календаря месяца при наборе S2",
        "content": (
            "Фрагмент EXPLAIN (ANALYZE, BUFFERS) для fn_get_calendar_stats — запрос Q1, "
            "набор S2 (~10 000 задач): узлы плана, время выполнения, использование буферов."
        ),
        "file": "docs/diagrams/png/11-explain-q1-calendar.png",
        "status": "готов (PNG в репозитории)",
    },
    12: {
        "title": "Планы полнотекстового поиска дневника (Q2a и Q2b)",
        "content": (
            "Два плана fn_search_diary: Q2a — без GIN-индекса; Q2b — с idx_diary_fts_gin; "
            "сравнение типа сканирования и времени на наборе S2."
        ),
        "file": "docs/diagrams/png/12-explain-q2a-q2b-diary.png",
        "status": "готов (PNG в репозитории)",
    },
    13: {
        "title": "План фильтра задач по составному индексу",
        "content": (
            "Фрагмент EXPLAIN для выборки задач по topic_id и status (Q3): использование "
            "idx_tasks_topic_status (Bitmap Index Scan → Bitmap Heap Scan)."
        ),
        "file": "docs/diagrams/png/13-explain-q3-tasks-index.png",
        "status": "готов (PNG в репозитории)",
    },
    14: {
        "title": "Развёртывание системы ПТТ (Docker Compose)",
        "content": (
            "Контейнеры db (PostgreSQL 16), backend (FastAPI), frontend (React + nginx); "
            "сеть docker-compose; том pgdata; порты 5432, 8000, 80."
        ),
        "file": "docs/diagrams/png/14-deploy-compose.png",
        "status": "готов (PNG в репозитории)",
    },
}


def figure_blockquote(n: int) -> str:
    spec = FIGURES[n]
    if spec["status"] == "вставлен":
        status_line = f"**Уже вставлено** (PNG: `{spec['file']}`)."
    elif spec["status"].startswith("готов"):
        status_line = f"**Файл для вставки:** `{spec['file']}` ({spec['status']})."
    elif spec["status"] == "скриншот":
        status_line = f"**Скриншот (вставить вручную):** {spec['file']}."
    else:
        status_line = f"**Вставить:** {spec['file']}."
    return (
        f"> **Содержание рисунка.** {spec['content']}\n"
        f">\n"
        f"> **Подпись под рисунком:** «Рисунок {n} — {spec['title']}»\n"
        f">\n"
        f"> {status_line}"
    )
