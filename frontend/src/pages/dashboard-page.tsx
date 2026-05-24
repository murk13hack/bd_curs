import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { format, startOfMonth, endOfMonth } from 'date-fns';
import { api } from '@/api/client';
import { PageHeader, Spinner, ErrorBanner } from '@/components/ui/primitives';
import { fmtDate, pct, toIsoDate } from '@/lib/format';
import { STATUS_COLOR, TASK_STATUS_LABEL } from '@/lib/labels';

export function DashboardPage() {
  const today = toIsoDate(new Date());
  const monthStart = toIsoDate(startOfMonth(new Date()));
  const monthEnd = toIsoDate(endOfMonth(new Date()));

  const tasks = useQuery({
    queryKey: ['tasks', { view: 'active', archived: false }],
    queryFn: () => api.tasks.list({ view: 'active', archived: false, limit: 200 }),
  });
  const streaks = useQuery({
    queryKey: ['pattern-streaks'],
    queryFn: api.patterns.streaksAll,
  });
  const completion = useQuery({
    queryKey: ['completion-rate', monthStart, monthEnd],
    queryFn: () => api.stats.completionRate(monthStart, monthEnd),
  });
  const diaryToday = useQuery({
    queryKey: ['diary-today', today],
    queryFn: () => api.diary.byDate(today),
    retry: false,
  });

  const pending = tasks.data ?? [];
  const doneToday = (tasks.data ?? []).filter(
    (t) => t.completed_at && t.completed_at.slice(0, 10) === today,
  );

  return (
    <div>
      <PageHeader
        title="Обзор"
        subtitle={`Сегодня ${format(new Date(), 'dd.MM.yyyy')}`}
      />

      {(tasks.isError || streaks.isError || completion.isError) && (
        <div className="mb-4">
          <ErrorBanner message="Не удалось загрузить часть данных обзора" />
        </div>
      )}

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Активных задач" value={String(pending.length)} />
        <StatCard label="Выполнено сегодня" value={String(doneToday.length)} />
        <StatCard
          label="Выполнение за месяц"
          value={completion.isLoading ? '…' : pct(completion.data?.rate ?? 0)}
        />
        <StatCard
          label="Привычки (серии > 0)"
          value={String((streaks.data ?? []).filter((s) => s.current_streak > 0).length)}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="card">
          <div className="card-body">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="font-semibold">Ближайшие задачи</h2>
              <Link to="/tasks" className="text-sm text-accent hover:underline">
                Все задачи
              </Link>
            </div>
            {tasks.isLoading ? (
              <Spinner />
            ) : tasks.isError ? (
              <p className="text-sm text-ink-muted">Не удалось загрузить задачи</p>
            ) : pending.length === 0 ? (
              <p className="text-sm text-ink-muted">Нет активных задач — отличная работа!</p>
            ) : (
              <ul className="space-y-2">
                {pending.slice(0, 6).map((task) => (
                  <li
                    key={task.id}
                    className="flex items-center justify-between gap-3 rounded-lg border border-border px-3 py-2"
                  >
                    <div className="min-w-0">
                      <div className="truncate font-medium">{task.title}</div>
                      <div className="text-xs text-ink-muted">
                        {task.deadline ? fmtDate(task.deadline) : 'без дедлайна'}
                      </div>
                    </div>
                    <span className={`badge ${STATUS_COLOR[task.status]}`}>
                      {TASK_STATUS_LABEL[task.status]}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>

        <section className="card">
          <div className="card-body">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="font-semibold">Привычки</h2>
              <Link to="/patterns" className="text-sm text-accent hover:underline">
                Управление
              </Link>
            </div>
            {streaks.isLoading ? (
              <Spinner />
            ) : streaks.isError ? (
              <p className="text-sm text-ink-muted">Не удалось загрузить привычки</p>
            ) : (streaks.data ?? []).length === 0 ? (
              <p className="text-sm text-ink-muted">Создайте первый паттерн поведения.</p>
            ) : (
              <ul className="space-y-2">
                {(streaks.data ?? []).slice(0, 5).map((s) => (
                  <li
                    key={s.pattern_id}
                    className="flex items-center justify-between rounded-lg border border-border px-3 py-2"
                  >
                    <span>{s.title}</span>
                    <span className="text-sm font-semibold text-accent">
                      🔥 {s.current_streak}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>

        <section className="card lg:col-span-2">
          <div className="card-body">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="font-semibold">Дневник сегодня</h2>
              <Link to="/diary" className="text-sm text-accent hover:underline">
                Открыть дневник
              </Link>
            </div>
            {diaryToday.isLoading ? (
              <Spinner />
            ) : diaryToday.isError ? (
              <p className="text-sm text-ink-muted">
                Запись на сегодня ещё не создана.{' '}
                <Link to="/diary" className="text-accent hover:underline">
                  Написать
                </Link>
              </p>
            ) : (
              <p className="whitespace-pre-wrap text-sm leading-relaxed">
                {diaryToday.data?.content}
              </p>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="card">
      <div className="card-body">
        <div className="text-sm text-ink-muted">{label}</div>
        <div className="mt-1 text-3xl font-semibold tracking-tight">{value}</div>
      </div>
    </div>
  );
}
