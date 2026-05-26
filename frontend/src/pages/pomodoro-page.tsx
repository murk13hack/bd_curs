import { useEffect, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';
import { Plus } from 'lucide-react';
import { api } from '@/api/client';
import { PomodoroSessionCard } from '@/components/pomodoro/pomodoro-session-card';
import { usePomodoro } from '@/context/pomodoro-context';
import { ErrorBanner, PageHeader, Spinner } from '@/components/ui/primitives';
import { POMODORO_MAX_SESSIONS } from '@/lib/pomodoro-timer';

export function PomodoroPage() {
  const p = usePomodoro();
  const { createSession } = p;
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
        subtitle={`До ${POMODORO_MAX_SESSIONS} параллельных таймеров. В задачу — время с момента привязки; интервалы могут пересекаться.`}
        actions={
          <button
            type="button"
            className="btn-primary"
            disabled={!p.canAddSession}
            onClick={() => p.createSession()}
          >
            <Plus size={16} /> Новый таймер
          </button>
        }
      />

      {p.notice && (
        <div className="mb-4">
          <ErrorBanner message={p.notice} />
          <button type="button" className="btn-ghost mt-1 text-xs" onClick={p.clearNotice}>
            Закрыть
          </button>
        </div>
      )}

      <p className="mb-4 text-sm text-ink-muted">
        Активных таймеров: {p.sessions.length} / {POMODORO_MAX_SESSIONS}
      </p>

      {p.sessions.length === 0 ? (
        <section className="card">
          <div className="card-body py-12 text-center text-sm text-ink-muted">
            Нажмите «Новый таймер» или запустите фокус из списка задач ниже.
          </div>
        </section>
      ) : (
        <div className="mb-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {p.sessions.map((session) => (
            <PomodoroSessionCard key={session.id} session={session} />
          ))}
        </div>
      )}

      <section className="card">
        <div className="card-body">
          <h2 className="mb-1 font-semibold">Запустить ещё таймер для задачи</h2>
          <p className="mb-3 text-xs text-ink-muted">
            Каждая кнопка добавляет отдельный параллельный таймер (не заменяет существующие).
          </p>
          <input
            className="input mb-3"
            placeholder="Поиск…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
          {tasks.isLoading ? (
            <Spinner />
          ) : filtered.length === 0 ? (
            <p className="text-sm text-ink-muted">Нет активных задач.</p>
          ) : (
            <ul className="max-h-72 space-y-2 overflow-y-auto">
              {filtered.map((task) => (
                <li key={task.id} className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border px-3 py-2">
                  <span className="min-w-0 flex-1 text-sm font-medium">{task.title}</span>
                  <button
                    type="button"
                    className="btn-secondary shrink-0 text-xs"
                    disabled={!p.canAddSession}
                    onClick={() => p.createSession(task.id, task.title)}
                  >
                    + Таймер
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>
    </div>
  );
}
