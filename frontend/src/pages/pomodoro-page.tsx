import { useEffect, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';
import { api } from '@/api/client';
import { PomodoroSessionCard } from '@/components/pomodoro/pomodoro-session-card';
import { usePomodoro } from '@/context/pomodoro-context';
import { ErrorBanner, PageHeader, Spinner } from '@/components/ui/primitives';
import { POMODORO_MAX_SESSIONS } from '@/lib/pomodoro-timer';

export function PomodoroPage() {
  const p = usePomodoro();
  const { createSession, sessionForTask } = p;
  const [searchParams, setSearchParams] = useSearchParams();
  const taskParam = searchParams.get('task');
  const addParam = searchParams.get('add');
  const [q, setQ] = useState('');

  const tasks = useQuery({
    queryKey: ['tasks', 'pomodoro'],
    queryFn: () => api.tasks.list({ view: 'active', limit: 100 }),
  });

  const filtered = useMemo(() => {
    const list = tasks.data ?? [];
    const needle = q.trim().toLowerCase();
    if (!needle) return list;
    return list.filter((t) => t.title.toLowerCase().includes(needle));
  }, [tasks.data, q]);

  const untimedSession = sessionForTask(null);

  useEffect(() => {
    if (!addParam || !taskParam || !tasks.data?.length) return;
    const id = Number(taskParam);
    if (!Number.isFinite(id)) return;
    const task = tasks.data.find((t) => t.id === id);
    if (task) {
      createSession(task.id, task.title);
      setSearchParams({}, { replace: true });
    }
  }, [addParam, taskParam, tasks.data, createSession, setSearchParams]);

  return (
    <div>
      <PageHeader
        title="Фокус"
        subtitle={`До ${POMODORO_MAX_SESSIONS} задач параллельно — по одному таймеру на задачу.`}
      />

      {p.notice && (
        <div className="mb-4">
          <ErrorBanner message={p.notice} />
          <button type="button" className="btn-ghost mt-1 text-xs" onClick={p.clearNotice}>
            Закрыть
          </button>
        </div>
      )}

      {tasks.isError && (
        <div className="mb-4">
          <ErrorBanner message="Не удалось загрузить список задач" />
        </div>
      )}

      {p.sessions.length > 0 && (
        <div className="mb-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {p.sessions.map((session) => (
            <PomodoroSessionCard key={session.id} session={session} />
          ))}
        </div>
      )}

      <section className="card">
        <div className="card-body">
          <h2 className="mb-3 font-semibold">Запустить фокус</h2>
          <input
            className="input mb-3"
            placeholder="Поиск задачи…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />

          {tasks.isLoading ? (
            <Spinner />
          ) : filtered.length === 0 ? (
            <p className="text-sm text-ink-muted">
              {q.trim() ? 'Ничего не найдено' : 'Нет активных задач'}
            </p>
          ) : (
            <ul className="space-y-2">
              {filtered.map((task) => {
                const active = sessionForTask(task.id);
                return (
                  <li
                    key={task.id}
                    className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border px-3 py-2"
                  >
                    <span className="min-w-0 flex-1 text-sm font-medium">{task.title}</span>
                    {active ? (
                      <span className="text-xs text-accent">таймер идёт</span>
                    ) : (
                      <button
                        type="button"
                        className="btn-primary shrink-0 text-xs"
                        disabled={!p.canAddSession}
                        onClick={() => createSession(task.id, task.title)}
                      >
                        Старт
                      </button>
                    )}
                  </li>
                );
              })}

              <li className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-dashed border-border px-3 py-2">
                <span className="text-sm text-ink-muted">Без привязки к задаче</span>
                {untimedSession ? (
                  <span className="text-xs text-accent">таймер идёт</span>
                ) : (
                  <button
                    type="button"
                    className="btn-secondary shrink-0 text-xs"
                    disabled={!p.canAddSession}
                    onClick={() => createSession()}
                  >
                    Старт
                  </button>
                )}
              </li>
            </ul>
          )}

          {p.sessions.length === 0 && !tasks.isLoading && (
            <p className="mt-4 text-center text-sm text-ink-muted">
              Выберите задачу и нажмите «Старт».
            </p>
          )}
        </div>
      </section>
    </div>
  );
}
