import { useEffect, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';
import { api } from '@/api/client';
import { PomodoroTimerView } from '@/components/pomodoro/pomodoro-timer-view';
import { usePomodoro } from '@/context/pomodoro-context';
import { PageHeader, Spinner } from '@/components/ui/primitives';

export function PomodoroPage() {
  const pomodoro = usePomodoro();
  const { selectTask } = pomodoro;
  const [searchParams] = useSearchParams();
  const taskParam = searchParams.get('task');
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
    if (!taskParam || !tasks.data?.length) return;
    const id = Number(taskParam);
    if (!Number.isFinite(id)) return;
    const task = tasks.data.find((t) => t.id === id);
    if (task) void selectTask(task.id, task.title);
  }, [taskParam, tasks.data, selectTask]);

  return (
    <div>
      <PageHeader title="Фокус" subtitle="Pomodoro с учётом времени в задаче" />

      <div className="mx-auto max-w-xl">
        <section className="card">
          <div className="card-body">
            <PomodoroTimerView />
            {pomodoro.phase === 'idle' && !pomodoro.taskId && (
              <p className="mt-2 text-center text-sm text-ink-muted">
                Выберите задачу ниже — без неё время не сохранится.
              </p>
            )}
          </div>
        </section>

        <section className="card mt-6">
          <div className="card-body">
            <h2 className="mb-3 font-semibold">Задача для фокуса</h2>
            <input
              className="input mb-3"
              placeholder="Поиск по названию…"
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
            {tasks.isLoading ? (
              <Spinner />
            ) : filtered.length === 0 ? (
              <p className="text-sm text-ink-muted">Нет активных задач.</p>
            ) : (
              <ul className="max-h-80 space-y-2 overflow-y-auto">
                {filtered.map((task) => {
                  const selected = pomodoro.taskId === task.id;
                  return (
                    <li key={task.id}>
                      <button
                        type="button"
                        className={`w-full rounded-lg border px-3 py-2 text-left text-sm transition ${
                          selected
                            ? 'border-accent bg-accent-soft'
                            : 'border-border hover:bg-surface-3'
                        }`}
                        onClick={() => void selectTask(task.id, task.title)}
                      >
                        {task.title}
                        {selected && pomodoro.phase !== 'idle' && (
                          <span className="mt-0.5 block text-xs text-ink-muted">текущая сессия</span>
                        )}
                      </button>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
