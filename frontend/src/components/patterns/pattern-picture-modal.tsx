import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { api } from '@/api/client';
import type { Pattern, PatternTimeBucketStat } from '@/api/types';
import { Modal, Spinner, ErrorBanner } from '@/components/ui/primitives';
import { FieldGroup } from '@/components/ui/form-field';
import { PatternCalendarGrid } from '@/components/patterns/pattern-day-strip';
import { rateLabel } from '@/lib/pattern-templates';

const PERIODS = [
  { days: 7, label: '7 д' },
  { days: 30, label: '30 д' },
  { days: 90, label: '90 д' },
] as const;

const TIME_FILTERS: { id: PatternTimeBucketStat['bucket'] | 'all'; label: string }[] = [
  { id: 'all', label: 'Весь день' },
  { id: 'morning', label: 'Утро' },
  { id: 'day', label: 'День' },
  { id: 'evening', label: 'Вечер' },
  { id: 'night', label: 'Ночь' },
];

type Props = {
  pattern: Pattern;
  onClose: () => void;
};

export function PatternPictureModal({ pattern, onClose }: Props) {
  const [days, setDays] = useState<number>(30);
  const [timeFilter, setTimeFilter] = useState<string>('all');
  const insights = useQuery({
    queryKey: ['pattern-insights', pattern.id, days, timeFilter],
    queryFn: () => api.patterns.insights(pattern.id, days, timeFilter),
  });

  const data = insights.data;
  const byStep = new Map<number, { title: string; rows: NonNullable<typeof data>['choice_breakdown'] }>();
  for (const row of data?.choice_breakdown ?? []) {
    const bucket = byStep.get(row.step_id) ?? { title: row.step_title, rows: [] };
    bucket.rows.push(row);
    byStep.set(row.step_id, bucket);
  }

  const successLabel =
    pattern.pattern_mode === 'markers'
      ? 'Без негативных'
      : pattern.pattern_mode === 'scenario'
        ? 'Чистых'
        : 'Успешных';

  return (
    <Modal open title={`Картина · ${pattern.title}`} onClose={onClose} wide>
      <div className="space-y-4">
        <FieldGroup legend="Период">
          <div className="flex flex-wrap gap-2">
            {PERIODS.map((p) => (
              <button
                key={p.days}
                type="button"
                className={days === p.days ? 'btn-primary text-xs' : 'btn-secondary text-xs'}
                onClick={() => setDays(p.days)}
              >
                {p.label}
              </button>
            ))}
          </div>
        </FieldGroup>

        <FieldGroup legend="Время суток">
          <div className="flex flex-wrap gap-2">
          {TIME_FILTERS.map((f) => (
            <button
              key={f.id}
              type="button"
              className={
                timeFilter === f.id ? 'btn-primary text-xs' : 'btn-secondary text-xs'
              }
              onClick={() => setTimeFilter(f.id)}
            >
              {f.label}
            </button>
          ))}
          </div>
        </FieldGroup>

        {insights.isLoading ? (
          <div className="flex justify-center py-12">
            <Spinner />
          </div>
        ) : insights.isError ? (
          <ErrorBanner message="Не удалось загрузить аналитику" />
        ) : data ? (
          <>
            <div className="grid gap-3 sm:grid-cols-3">
              <StatCard
                label="Запланировано"
                value={String(data.scheduled_days)}
                hint="дней по расписанию"
              />
              <StatCard
                label={successLabel}
                value={String(data.success_days)}
                hint={`${Math.round(data.clean_rate * 100)}% от запланированных`}
              />
              <StatCard
                label="Период"
                value={rateLabel(data.scheduled_days, data.success_days)}
                hint={`за ${data.days} дней`}
              />
            </div>

            {data.insights.length > 0 && (
              <div className="rounded-lg border border-amber-500/30 bg-amber-500/5 p-3">
                <p className="mb-2 text-sm font-medium">Наблюдения</p>
                <ul className="list-inside list-disc space-y-1 text-sm text-ink-muted">
                  {data.insights.map((note, i) => (
                    <li key={i}>{note}</li>
                  ))}
                </ul>
              </div>
            )}

            {data.diary_correlation && data.diary_correlation.mood_buckets.length > 0 && (
              <section className="rounded-lg border border-border p-3">
                <h3 className="mb-2 text-sm font-medium">Дневник: настроение и чистые дни</h3>
                {data.diary_correlation.corr_mood_clean != null && (
                  <p className="mb-2 text-xs text-ink-muted">
                    Корреляция настроения и успеха: {data.diary_correlation.corr_mood_clean.toFixed(2)}
                  </p>
                )}
                <div className="grid gap-2 sm:grid-cols-3">
                  {data.diary_correlation.mood_buckets.map((b) => (
                    <div key={b.mood_range} className="rounded-md border border-border px-2 py-2 text-sm">
                      <div className="font-medium">{b.label}</div>
                      <div className="text-xs text-ink-muted">
                        {b.clean_days}/{b.days} чистых ({b.clean_rate}%)
                      </div>
                      {b.avg_energy != null && (
                        <div className="text-xs text-ink-muted">энергия ≈ {b.avg_energy}</div>
                      )}
                    </div>
                  ))}
                </div>
              </section>
            )}

            {data.time_of_day_stats.length > 0 && timeFilter === 'all' && (
              <section>
                <h3 className="mb-2 text-sm font-medium">Срывы по времени суток</h3>
                <div className="h-40">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={data.time_of_day_stats}>
                      <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
                      <XAxis dataKey="label" tick={{ fontSize: 11 }} />
                      <YAxis allowDecimals={false} tick={{ fontSize: 11 }} width={28} />
                      <Tooltip />
                      <Bar dataKey="failure_count" fill="#ef4444" radius={[4, 4, 0, 0]} name="Срывы" />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </section>
            )}

            {pattern.pattern_mode === 'markers' && data.hourly_counts.length > 0 && (
              <section>
                <h3 className="mb-2 text-sm font-medium">Отметки по часам</h3>
                <div className="h-40">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart
                      data={data.hourly_counts.map((h) => ({
                        hour: `${h.hour}:00`,
                        count: h.count,
                        bad: h.bad_count,
                      }))}
                    >
                      <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
                      <XAxis dataKey="hour" tick={{ fontSize: 10 }} interval={1} />
                      <YAxis allowDecimals={false} tick={{ fontSize: 11 }} width={28} />
                      <Tooltip />
                      <Bar dataKey="count" fill="#6366f1" name="Всего" radius={[2, 2, 0, 0]} />
                      <Bar dataKey="bad" fill="#ef4444" name="Негатив" radius={[2, 2, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </section>
            )}

            <section>
              <h3 className="mb-2 text-sm font-medium">Календарь</h3>
              <PatternCalendarGrid days={data.calendar} />
            </section>

            {pattern.pattern_mode === 'scenario' && data.top_paths.length > 0 && (
              <section>
                <h3 className="mb-2 text-sm font-medium">Частые маршруты</h3>
                <ul className="space-y-2 text-sm">
                  {data.top_paths.map((p) => (
                    <li
                      key={p.path}
                      className={`rounded-lg border px-3 py-2 ${
                        p.is_success
                          ? 'border-emerald-500/30 bg-emerald-500/5'
                          : 'border-red-500/30 bg-red-500/5'
                      }`}
                    >
                      <div className="font-medium">{p.path}</div>
                      <div className="text-xs text-ink-muted">
                        {p.count} раз · {p.pct}%
                      </div>
                    </li>
                  ))}
                </ul>
              </section>
            )}

            {byStep.size > 0 && (
              <section className="space-y-4">
                <h3 className="text-sm font-medium">
                  {pattern.pattern_mode === 'scenario'
                    ? 'Частота ответов на развилках'
                    : pattern.pattern_mode === 'markers'
                      ? 'Типы отметок'
                      : 'Распределение ответов'}
                </h3>
                {[...byStep.entries()].map(([stepId, bucket]) => (
                  <div key={stepId} className="rounded-lg border border-border p-3">
                    <p className="mb-2 text-sm font-medium">{bucket.title}</p>
                    <div className="h-48">
                      <ResponsiveContainer width="100%" height="100%">
                        <BarChart
                          data={bucket.rows.map((r) => ({
                            name: r.label,
                            count: r.count,
                            fill:
                              r.is_success === true
                                ? '#10b981'
                                : r.is_success === false
                                  ? '#ef4444'
                                  : '#6366f1',
                          }))}
                          margin={{ top: 4, right: 8, left: 0, bottom: 4 }}
                        >
                          <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
                          <XAxis
                            dataKey="name"
                            tick={{ fontSize: 11 }}
                            interval={0}
                            angle={-20}
                            textAnchor="end"
                            height={50}
                          />
                          <YAxis allowDecimals={false} tick={{ fontSize: 11 }} width={28} />
                          <Tooltip />
                          <Bar dataKey="count" radius={[4, 4, 0, 0]} />
                        </BarChart>
                      </ResponsiveContainer>
                    </div>
                  </div>
                ))}
              </section>
            )}
          </>
        ) : null}
      </div>
    </Modal>
  );
}

function StatCard({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div className="rounded-lg border border-border px-3 py-2">
      <div className="text-xs text-ink-muted">{label}</div>
      <div className="text-xl font-semibold">{value}</div>
      <div className="text-xs text-ink-muted">{hint}</div>
    </div>
  );
}
