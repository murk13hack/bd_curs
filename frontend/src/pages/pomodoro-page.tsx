import { useEffect, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';
import { api } from '@/api/client';
import { PomodoroTimerView } from '@/components/pomodoro/pomodoro-timer-view';
import { usePomodoro } from '@/context/pomodoro-context';
import { PageHeader, Spinner } from '@/components/ui/primitives';

export function PomodoroPage() {
  const pomodoro = usePomodoro();
  const { selectTask, start } = pomodoro;
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

  const noTaskSelected = pomodoro.taskId == null;
  const inSession = pomodoro.phase !== 'idle';

  return (
    <div>
      <PageHeader
        title="Фокус"
        subtitle="Один таймер на всё приложение. Задача по желанию — время пишется в неё при завершении сессии или смене задачи."
      />

      <div className="mx-auto max-w-xl">
        <section className="card">
          <div className="card-body">
            <PomodoroTimerView />
            {pomodoro.phase === 'idle' && (
              <p className="mt-3 text-center text-sm text-ink-muted">
                Можно нажать «Старт» сразу или выбрать задачу — как в Focus To-Do и TickTick.
              </p>
            )}
            {inSession && noTaskSelected && pomodoro.phase === 'work' && (
              <p className="mt-3 text-center text-sm text-amber-700 dark:text-amber-400">
                Выберите задачу до конца сессии, иначе накопленное время не сохранится.
              </p>
            )}
          </div>
        </section>

        <section className="card mt-6">
          <div className="card-body">
            <h2 className="mb-1 font-semibold">Привязка к задаче</h2>
            <p className="mb-3 text-xs text-ink-muted">
              Одновременно идёт только одна сессия. Смена задачи во время фокуса сохраняет время по
              предыдущей задаче.
            </p>
            <input
              className="input mb-3"
              placeholder="Поиск по названию…"
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />

            <ul className="max-h-80 space-y-2 overflow-y-auto">
              <li>
                <button
                  type="button"
                  className={`w-full rounded-lg border px-3 py-2 text-left text-sm transition ${
                    noTaskSelected
                      ? 'border-accent bg-accent-soft'
                      : 'border-border hover:bg-surface-3'
                  }`}
                  onClick={() => void selectTask(null)}
                >
                  <span className="font-medium">Без задачи</span>
                  <span className="mt-0.5 block text-xs text-ink-muted">
                    Таймер без записи в журнал
                  </span>
                </button>
                {pomodoro.phase === 'idle' && noTaskSelected && (
                  <button
                    type="button"
                    className="btn-primary mt-2 w-full text-sm"
                    onClick={() => start()}
                  >
                    Старт без задачи
                  </button>
                )}
              </li>

              {tasks.isLoading ? (
                <li className="py-4">
                  <Spinner />
                </li>
              ) : filtered.length === 0 ? (
                <li className="text-sm text-ink-muted">Нет активных задач.</li>
              ) : (
                filtered.map((task) => {
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
                        {selected && inSession && (
                          <span className="mt-0.5 block text-xs text-ink-muted">
                            {pomodoro.phase === 'work' ? 'учёт времени здесь' : 'следующий фокус здесь'}
                          </span>
                        )}
                      </button>
                      {pomodoro.phase === 'idle' && selected && (
                        <button
                          type="button"
                          className="btn-primary mt-2 w-full text-sm"
                          onClick={() => start(task.id, task.title)}
                        >
                          Старт с этой задачей
                        </button>
                      )}
                    </li>
                  );
                })
              )}
            </ul>
          </div>
        </section>
      </div>
    </div>
  );
}
