import { useQuery } from '@tanstack/react-query';
import { Pause, Play, RotateCcw, SkipForward } from 'lucide-react';
import { api } from '@/api/client';
import { usePomodoro } from '@/context/pomodoro-context';
import { PageHeader, Spinner } from '@/components/ui/primitives';

const PHASE_LABEL = {
  idle: 'Готов к работе',
  work: 'Фокус',
  short_break: 'Короткий перерыв',
  long_break: 'Длинный перерыв',
};

export function PomodoroPage() {
  const pomodoro = usePomodoro();
  const tasks = useQuery({
    queryKey: ['tasks', 'pomodoro'],
    queryFn: () => api.tasks.list({ status: 'pending', limit: 50 }),
  });

  const mins = Math.floor(pomodoro.remainingSec / 60)
    .toString()
    .padStart(2, '0');
  const secs = (pomodoro.remainingSec % 60).toString().padStart(2, '0');
  const progress =
    pomodoro.totalSec > 0
      ? ((pomodoro.totalSec - pomodoro.remainingSec) / pomodoro.totalSec) * 100
      : 0;

  return (
    <div>
      <PageHeader title="Pomodoro" subtitle="Таймер фокусировки с привязкой к задаче" />

      <div className="mx-auto max-w-xl">
        <section className="card">
          <div className="card-body flex flex-col items-center gap-6 py-10">
            <div className="text-sm font-medium text-ink-muted">
              {PHASE_LABEL[pomodoro.phase]}
            </div>
            <div className="relative flex h-48 w-48 items-center justify-center">
              <svg className="absolute inset-0 -rotate-90" viewBox="0 0 100 100">
                <circle cx="50" cy="50" r="45" fill="none" stroke="currentColor" strokeOpacity={0.1} strokeWidth="6" />
                <circle
                  cx="50"
                  cy="50"
                  r="45"
                  fill="none"
                  stroke="currentColor"
                  className="text-accent"
                  strokeWidth="6"
                  strokeLinecap="round"
                  strokeDasharray={`${progress * 2.827} 282.7`}
                />
              </svg>
              <div className="text-5xl font-bold tabular-nums">
                {mins}:{secs}
              </div>
            </div>
            {pomodoro.taskTitle && (
              <p className="text-sm text-ink-muted">Задача: {pomodoro.taskTitle}</p>
            )}
            <div className="flex flex-wrap justify-center gap-2">
              {pomodoro.phase === 'idle' ? (
                <button type="button" className="btn-primary" onClick={() => pomodoro.start()}>
                  <Play size={16} /> Старт
                </button>
              ) : pomodoro.running ? (
                <button type="button" className="btn-secondary" onClick={pomodoro.pause}>
                  <Pause size={16} /> Пауза
                </button>
              ) : (
                <button type="button" className="btn-primary" onClick={pomodoro.resume}>
                  <Play size={16} /> Продолжить
                </button>
              )}
              <button type="button" className="btn-secondary" onClick={pomodoro.skip}>
                <SkipForward size={16} /> Пропустить
              </button>
              <button type="button" className="btn-ghost" onClick={pomodoro.reset}>
                <RotateCcw size={16} /> Сброс
              </button>
            </div>
            <p className="text-xs text-ink-muted">Циклов: {pomodoro.cycles}</p>
          </div>
        </section>

        <section className="card mt-6">
          <div className="card-body">
            <h2 className="mb-3 font-semibold">Привязать к задаче</h2>
            {tasks.isLoading ? (
              <Spinner />
            ) : (
              <ul className="space-y-2">
                {(tasks.data ?? []).slice(0, 10).map((task) => (
                  <li key={task.id}>
                    <button
                      type="button"
                      className={`w-full rounded-lg border px-3 py-2 text-left text-sm transition ${
                        pomodoro.taskId === task.id
                          ? 'border-accent bg-accent-soft'
                          : 'border-border hover:bg-surface-3'
                      }`}
                      onClick={() => pomodoro.start(task.id, task.title)}
                    >
                      {task.title}
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
