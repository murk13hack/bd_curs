import type { ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { api } from '@/api/client';
import { PageHeader, Spinner } from '@/components/ui/primitives';
import { fmtDate, minutesLabel, pct } from '@/lib/format';

const COLORS = ['#16a34a', '#3b82f6', '#f59e0b', '#ec4899', '#8b5cf6', '#6b7280'];

export function StatsPage() {
  const topics = useQuery({ queryKey: ['stats-topics'], queryFn: api.stats.topics });
  const timeDist = useQuery({
    queryKey: ['stats-time'],
    queryFn: api.stats.timeDistribution,
  });
  const weekly = useQuery({
    queryKey: ['stats-weekly'],
    queryFn: () => api.stats.weekly({ limit: 12 }),
  });
  const correlation = useQuery({
    queryKey: ['stats-correlation'],
    queryFn: () => api.stats.correlation(),
  });

  const weeklyChart = [...(weekly.data ?? [])].reverse().map((w) => ({
    name: fmtDate(w.week_start),
    done: w.tasks_done,
    total: w.tasks_total,
    minutes: w.minutes_logged,
  }));

  return (
    <div>
      <PageHeader title="Статистика" subtitle="Разрезы по темам, времени и продуктивности" />

      <div className="grid gap-6 lg:grid-cols-2">
        <ChartCard title="Выполнение по темам" loading={topics.isLoading}>
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={topics.data ?? []}>
              <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
              <XAxis dataKey="topic_name" tick={{ fontSize: 11 }} />
              <YAxis />
              <Tooltip formatter={(v: number) => pct(v)} />
              <Bar dataKey="completion_rate" name="Выполнение %" fill="#16a34a" />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Время по темам" loading={timeDist.isLoading}>
          <ResponsiveContainer width="100%" height={280}>
            <PieChart>
              <Pie
                data={timeDist.data ?? []}
                dataKey="minutes"
                nameKey="topic_name"
                cx="50%"
                cy="50%"
                outerRadius={90}
                label={({ name, value }) => `${name}: ${minutesLabel(value as number)}`}
              >
                {(timeDist.data ?? []).map((_, i) => (
                  <Cell key={i} fill={COLORS[i % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip formatter={(v: number) => minutesLabel(v)} />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Недельная сводка" loading={weekly.isLoading} className="lg:col-span-2">
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={weeklyChart}>
              <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
              <XAxis dataKey="name" tick={{ fontSize: 11 }} />
              <YAxis yAxisId="left" />
              <YAxis yAxisId="right" orientation="right" />
              <Tooltip />
              <Legend />
              <Line yAxisId="left" type="monotone" dataKey="done" name="Выполнено" stroke="#16a34a" />
              <Line yAxisId="left" type="monotone" dataKey="total" name="Всего" stroke="#3b82f6" />
              <Line yAxisId="right" type="monotone" dataKey="minutes" name="Минуты" stroke="#f59e0b" />
            </LineChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Корреляция настроения и продуктивности" loading={correlation.isLoading} className="lg:col-span-2">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-ink-muted">
                  <th className="py-2 pr-4">Неделя</th>
                  <th className="py-2 pr-4">Настроение</th>
                  <th className="py-2 pr-4">Энергия</th>
                  <th className="py-2 pr-4">Выполнение</th>
                  <th className="py-2">corr(mood)</th>
                </tr>
              </thead>
              <tbody>
                {(correlation.data ?? []).slice(0, 8).map((row) => (
                  <tr key={row.week_start} className="border-b border-border/60">
                    <td className="py-2 pr-4">{fmtDate(row.week_start)}</td>
                    <td className="py-2 pr-4">{row.avg_mood?.toFixed(1) ?? '—'}</td>
                    <td className="py-2 pr-4">{row.avg_energy?.toFixed(1) ?? '—'}</td>
                    <td className="py-2 pr-4">
                      {row.avg_completion_rate != null ? pct(row.avg_completion_rate) : '—'}
                    </td>
                    <td className="py-2">
                      {row.corr_mood_rate != null ? row.corr_mood_rate.toFixed(2) : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </ChartCard>
      </div>
    </div>
  );
}

function ChartCard({
  title,
  loading,
  children,
  className = '',
}: {
  title: string;
  loading: boolean;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`card ${className}`}>
      <div className="card-body">
        <h2 className="mb-4 font-semibold">{title}</h2>
        {loading ? (
          <div className="flex h-64 items-center justify-center">
            <Spinner />
          </div>
        ) : (
          children
        )}
      </div>
    </section>
  );
}
