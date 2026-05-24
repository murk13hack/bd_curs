import { useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ComposedChart,
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
import type { OlapMeta, StatsOverview } from '@/api/types';
import { PageHeader, Spinner, ErrorBanner } from '@/components/ui/primitives';
import { TASK_PRIORITY_LABEL, PATTERN_MODE_LABEL } from '@/lib/labels';
import { fmtDate, minutesLabel, pct, toIsoDate } from '@/lib/format';

const COLORS = ['#16a34a', '#3b82f6', '#f59e0b', '#ec4899', '#8b5cf6', '#6b7280', '#ef4444'];

type Tab = 'overview' | 'tasks' | 'patterns' | 'diary' | 'olap';

export function StatsPage() {
  const [tab, setTab] = useState<Tab>('overview');
  const [period, setPeriod] = useState(30);

  const overview = useQuery({
    queryKey: ['stats-overview', period],
    queryFn: () => api.stats.overview(period),
  });
  const weekly = useQuery({
    queryKey: ['stats-weekly'],
    queryFn: () => api.stats.weekly({ limit: 16 }),
  });
  const topics = useQuery({ queryKey: ['stats-topics'], queryFn: api.stats.topics });
  const priorities = useQuery({ queryKey: ['stats-priorities'], queryFn: api.stats.priorities });
  const timeDist = useQuery({ queryKey: ['stats-time'], queryFn: api.stats.timeDistribution });
  const patterns = useQuery({ queryKey: ['stats-patterns'], queryFn: api.stats.patterns });
  const holistic = useQuery({ queryKey: ['stats-holistic'], queryFn: () => api.stats.holistic() });
  const heatmap = useQuery({
    queryKey: ['stats-heatmap'],
    queryFn: () => {
      const to = toIsoDate(new Date());
      const from = toIsoDate(new Date(Date.now() - 90 * 86400000));
      return api.calendar.heatmap(from, to);
    },
  });

  const weeklyChart = useMemo(
    () =>
      [...(weekly.data ?? [])].reverse().map((w) => ({
        name: fmtDate(w.week_start),
        tasks_done: w.tasks_done,
        tasks_total: w.tasks_total,
        minutes: w.minutes_logged,
        mood: w.avg_mood,
        patterns: w.patterns_success,
        markers_bad: w.marker_bad_events,
      })),
    [weekly.data],
  );

  return (
    <div className="space-y-6">
      <PageHeader
        title="Статистика"
        subtitle="OLAP-срезы: задачи, паттерны, дневник, время — всё в одном месте"
      />

      {(overview.isError || weekly.isError) && (
        <ErrorBanner message="Не удалось загрузить статистику" />
      )}

      <div className="flex flex-wrap gap-2">
        {[7, 30, 90].map((d) => (
          <button
            key={d}
            type="button"
            className={period === d ? 'btn-primary text-xs' : 'btn-secondary text-xs'}
            onClick={() => setPeriod(d)}
          >
            {d} д
          </button>
        ))}
      </div>

      {overview.data && <KpiGrid data={overview.data} />}

      <div className="flex flex-wrap gap-2 border-b border-border pb-2">
        {(
          [
            ['overview', 'Обзор'],
            ['tasks', 'Задачи'],
            ['patterns', 'Паттерны'],
            ['diary', 'Дневник и связи'],
            ['olap', 'OLAP-конструктор'],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            className={`rounded-md px-3 py-1.5 text-sm ${
              tab === id ? 'bg-accent text-white' : 'text-ink-muted hover:bg-surface-3'
            }`}
            onClick={() => setTab(id)}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div className="grid gap-6 lg:grid-cols-2">
          <ChartCard title="Недельная динамика" loading={weekly.isLoading} className="lg:col-span-2">
            <ResponsiveContainer width="100%" height={320}>
              <ComposedChart data={weeklyChart}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis dataKey="name" tick={{ fontSize: 10 }} />
                <YAxis yAxisId="left" />
                <YAxis yAxisId="right" orientation="right" domain={[0, 5]} />
                <Tooltip />
                <Legend />
                <Bar yAxisId="left" dataKey="tasks_done" name="Задач done" fill="#16a34a" />
                <Bar yAxisId="left" dataKey="patterns" name="Чистых паттернов" fill="#8b5cf6" />
                <Line yAxisId="right" type="monotone" dataKey="mood" name="Настроение" stroke="#f59e0b" />
              </ComposedChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="Активность (90 д)" loading={heatmap.isLoading}>
            <HeatmapStrip points={heatmap.data ?? []} />
          </ChartCard>

          <ChartCard title="Время по темам" loading={timeDist.isLoading}>
            <ResponsiveContainer width="100%" height={260}>
              <PieChart>
                <Pie
                  data={timeDist.data ?? []}
                  dataKey="minutes"
                  nameKey="topic_name"
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  label={({ name, value }) => `${name}: ${minutesLabel(value as number)}`}
                >
                  {(timeDist.data ?? []).map((_, i) => (
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(v: number) => minutesLabel(v)} />
              </PieChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>
      )}

      {tab === 'tasks' && (
        <div className="grid gap-6 lg:grid-cols-2">
          <ChartCard title="Выполнение по темам" loading={topics.isLoading}>
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={topics.data ?? []}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis dataKey="topic_name" tick={{ fontSize: 11 }} />
                <YAxis />
                <Tooltip formatter={(v: number) => pct(v)} />
                <Bar dataKey="completion_rate" name="%" fill="#16a34a" />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="По приоритету" loading={priorities.isLoading}>
            <ResponsiveContainer width="100%" height={280}>
              <BarChart
                data={(priorities.data ?? []).map((p) => ({
                  ...p,
                  label: TASK_PRIORITY_LABEL[p.priority as keyof typeof TASK_PRIORITY_LABEL] ?? p.priority,
                }))}
              >
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis dataKey="label" tick={{ fontSize: 11 }} />
                <YAxis />
                <Tooltip />
                <Bar dataKey="done" name="Выполнено" stackId="a" fill="#16a34a" />
                <Bar dataKey="overdue" name="Просрочено" stackId="a" fill="#ef4444" />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="Таблица по темам" loading={topics.isLoading} className="lg:col-span-2">
            <DataTable
              headers={['Тема', 'Всего', 'Выполнено', 'Просрочено', '%', 'План мин']}
              rows={(topics.data ?? []).map((r) => [
                r.topic_name,
                r.total,
                r.done,
                r.overdue,
                pct(r.completion_rate),
                r.avg_planned_minutes ?? '—',
              ])}
            />
          </ChartCard>
        </div>
      )}

      {tab === 'patterns' && (
        <div className="grid gap-6">
          <ChartCard title="Чистота паттернов (30 д)" loading={patterns.isLoading}>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={patterns.data ?? []} layout="vertical" margin={{ left: 80 }}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis type="number" domain={[0, 100]} />
                <YAxis type="category" dataKey="title" tick={{ fontSize: 11 }} width={75} />
                <Tooltip formatter={(v: number) => pct(v)} />
                <Bar dataKey="clean_rate_30d" name="Чистота %" fill="#8b5cf6" />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="Все паттерны" loading={patterns.isLoading}>
            <DataTable
              headers={['Название', 'Режим', 'Серия', 'Max', '30д чистых', '%']}
              rows={(patterns.data ?? []).map((p) => [
                p.title,
                PATTERN_MODE_LABEL[p.pattern_mode as keyof typeof PATTERN_MODE_LABEL] ?? p.pattern_mode,
                p.current_streak,
                p.max_streak,
                `${p.success_days_30d}/${p.scheduled_days_30d}`,
                pct(p.clean_rate_30d),
              ])}
            />
          </ChartCard>
        </div>
      )}

      {tab === 'diary' && (
        <div className="grid gap-6 lg:grid-cols-2">
          <ChartCard title="Настроение и задачи (недели)" loading={holistic.isLoading} className="lg:col-span-2">
            <ResponsiveContainer width="100%" height={300}>
              <LineChart
                data={[...(holistic.data ?? [])].map((w) => ({
                  name: fmtDate(w.week_start),
                  mood: w.avg_mood,
                  tasks: w.avg_task_rate,
                  patterns: w.avg_pattern_clean_rate,
                }))}
              >
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis dataKey="name" tick={{ fontSize: 10 }} />
                <YAxis />
                <Tooltip />
                <Legend />
                <Line type="monotone" dataKey="mood" name="Настроение" stroke="#f59e0b" />
                <Line type="monotone" dataKey="tasks" name="% задач" stroke="#16a34a" />
                <Line type="monotone" dataKey="patterns" name="% паттернов" stroke="#8b5cf6" />
              </LineChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="Корреляции (Пирсон)" loading={holistic.isLoading} className="lg:col-span-2">
            <DataTable
              headers={[
                'Неделя',
                'Mood',
                'Задачи %',
                'Паттерны %',
                'corr(mood→tasks)',
                'corr(mood→patterns)',
                'corr(energy→tasks)',
              ]}
              rows={(holistic.data ?? []).slice(-12).map((r) => [
                fmtDate(r.week_start),
                r.avg_mood?.toFixed(1) ?? '—',
                r.avg_task_rate != null ? pct(r.avg_task_rate) : '—',
                r.avg_pattern_clean_rate != null ? pct(r.avg_pattern_clean_rate) : '—',
                r.corr_mood_tasks?.toFixed(2) ?? '—',
                r.corr_mood_patterns?.toFixed(2) ?? '—',
                r.corr_energy_tasks?.toFixed(2) ?? '—',
              ])}
            />
          </ChartCard>
        </div>
      )}

      {tab === 'olap' && <OlapBuilder period={period} />}
    </div>
  );
}

function KpiGrid({ data }: { data: StatsOverview }) {
  const items = [
    { label: 'Задачи', value: `${data.tasks_done}/${data.tasks_total}`, hint: pct(data.task_completion_rate) },
    { label: 'Просрочено', value: String(data.tasks_overdue), hint: 'за период' },
    { label: 'Время', value: minutesLabel(data.minutes_logged), hint: `Pomodoro ${data.pomodoro_minutes} мин` },
    { label: 'Дневник', value: String(data.diary_entries), hint: `настроение ${data.avg_mood?.toFixed(1) ?? '—'}` },
    { label: 'Паттерны', value: pct(data.pattern_clean_rate), hint: `${data.patterns_success}/${data.patterns_scheduled} дн` },
    { label: 'Метки', value: String(data.marker_events), hint: `негативных ${data.marker_bad_events}` },
    { label: 'Активность', value: String(data.activity_score), hint: `${data.active_days} активных дней` },
  ];
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7">
      {items.map((k) => (
        <div key={k.label} className="rounded-lg border border-border bg-surface-2 px-3 py-2">
          <div className="text-xs text-ink-muted">{k.label}</div>
          <div className="text-lg font-semibold">{k.value}</div>
          <div className="text-xs text-ink-muted">{k.hint}</div>
        </div>
      ))}
    </div>
  );
}

function OlapBuilder({ period }: { period: number }) {
  const meta = useQuery({ queryKey: ['stats-meta'], queryFn: api.stats.meta });
  const [dim, setDim] = useState('week');
  const [measure, setMeasure] = useState('completion_rate');
  const [moodFilter, setMoodFilter] = useState('');
  const [energyFilter, setEnergyFilter] = useState('');

  const queryMut = useMutation({
    mutationFn: () => {
      const to = toIsoDate(new Date());
      const from = toIsoDate(new Date(Date.now() - (period - 1) * 86400000));
      return api.stats.olap({
        dimensions: dim ? [dim] : [],
        measures: [measure],
        date_from: from,
        date_to: to,
        filters: {
          ...(moodFilter ? { mood_bucket: moodFilter } : {}),
          ...(energyFilter ? { energy_bucket: energyFilter } : {}),
        },
      });
    },
  });

  const chartData = useMemo(() => {
    const rows = queryMut.data?.rows ?? [];
    return rows.map((r) => {
      const labelKey = `${dim}_label` as keyof typeof r.dimensions;
      return {
        name: String(r.dimensions[labelKey] ?? r.dimensions[dim] ?? '?'),
        value: r.measures[measure] ?? 0,
      };
    });
  }, [queryMut.data, dim, measure]);

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <div className="card lg:col-span-1">
        <div className="card-body space-y-3">
          <h2 className="font-semibold">OLAP-конструктор</h2>
          <p className="text-xs text-ink-muted">
            Выберите измерение и меру — сервер агрегирует v_olap_daily_facts.
          </p>
          <label className="block text-sm">
            Измерение
            <select className="select mt-1" value={dim} onChange={(e) => setDim(e.target.value)}>
              {(meta.data?.dimensions ?? []).map((d: OlapMeta['dimensions'][0]) => (
                <option key={d.id} value={d.id}>
                  {d.label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm">
            Мера
            <select className="select mt-1" value={measure} onChange={(e) => setMeasure(e.target.value)}>
              {(meta.data?.measures ?? []).map((m) => (
                <option key={m.id} value={m.id}>
                  {m.label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm">
            Фильтр настроения
            <select className="select mt-1" value={moodFilter} onChange={(e) => setMoodFilter(e.target.value)}>
              <option value="">Все</option>
              <option value="low">1–2</option>
              <option value="mid">3</option>
              <option value="high">4–5</option>
            </select>
          </label>
          <label className="block text-sm">
            Фильтр энергии
            <select className="select mt-1" value={energyFilter} onChange={(e) => setEnergyFilter(e.target.value)}>
              <option value="">Все</option>
              <option value="low">1–2</option>
              <option value="mid">3</option>
              <option value="high">4–5</option>
            </select>
          </label>
          <button
            type="button"
            className="btn-primary w-full"
            disabled={queryMut.isPending}
            onClick={() => queryMut.mutate()}
          >
            Построить срез
          </button>
        </div>
      </div>

      <ChartCard
        title="Результат OLAP"
        loading={queryMut.isPending}
        className="lg:col-span-2"
      >
        {chartData.length === 0 ? (
          <p className="py-12 text-center text-sm text-ink-muted">Нажмите «Построить срез»</p>
        ) : (
          <>
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                <YAxis />
                <Tooltip />
                <Bar dataKey="value" fill="#3b82f6" />
              </BarChart>
            </ResponsiveContainer>
            <DataTable
              headers={['Измерение', 'Значение']}
              rows={chartData.map((r) => [r.name, String(r.value)])}
            />
          </>
        )}
      </ChartCard>
    </div>
  );
}

function HeatmapStrip({ points }: { points: { day: string; activity: number }[] }) {
  const max = Math.max(1, ...points.map((p) => p.activity));
  return (
    <div className="flex flex-wrap gap-1">
      {points.map((p) => (
        <span
          key={p.day}
          title={`${p.day}: ${p.activity}`}
          className="h-3 w-3 rounded-sm"
          style={{
            backgroundColor: `rgba(22, 163, 74, ${0.15 + (0.85 * p.activity) / max})`,
          }}
        />
      ))}
    </div>
  );
}

function DataTable({ headers, rows }: { headers: string[]; rows: (string | number)[][] }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-ink-muted">
            {headers.map((h) => (
              <th key={h} className="py-2 pr-4">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr key={i} className="border-b border-border/60">
              {row.map((cell, j) => (
                <td key={j} className="py-2 pr-4">
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
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
