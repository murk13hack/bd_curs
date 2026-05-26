import { useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { api, ApiError } from '@/api/client';
import type { DiaryInsights, PatternStreak, StatsOverview } from '@/api/types';
import { DiaryLinksSection } from '@/components/stats/diary-links-section';
import { StatsConnectionsTeaser } from '@/components/stats/stats-connections-teaser';
import { OlapBuilder } from '@/components/stats/olap-builder';
import {
  AxisLabelX,
  AxisLabelYLeft,
  ChartCaption,
  statsChartMargin,
} from '@/components/stats/stats-chart-labels';
import { StatsHeatmapGrid } from '@/components/stats/stats-heatmap-grid';
import {
  OVERVIEW_WEEKLY_SERIES,
  StatsWeeklyMiniGrid,
} from '@/components/stats/stats-weekly-mini-charts';
import { PageHeader, Spinner, ErrorBanner } from '@/components/ui/primitives';
import { PATTERN_MODE_LABEL, TASK_PRIORITY_LABEL } from '@/lib/labels';
import { FieldGroup } from '@/components/ui/form-field';
import { fmtDate, minutesLabel, pct } from '@/lib/format';
import {
  statsPeriodRange,
} from '@/lib/stats-period';

const COLORS = ['#16a34a', '#3b82f6', '#f59e0b', '#ec4899', '#8b5cf6', '#6b7280', '#ef4444'];
const PIE_MAX_LABEL_CHARS = 14;

type Tab = 'overview' | 'tasks' | 'patterns' | 'diary' | 'olap';

function queryError(e: unknown): string {
  if (e instanceof ApiError) return e.message;
  if (e instanceof Error) return e.message;
  return 'Ошибка загрузки';
}

function ellipsis(value: string, max = PIE_MAX_LABEL_CHARS): string {
  if (value.length <= max) return value;
  return `${value.slice(0, Math.max(1, max - 1))}…`;
}

export function StatsPage() {
  const [tab, setTab] = useState<Tab>('overview');
  const [period, setPeriod] = useState(30);
  const range = useMemo(() => statsPeriodRange(period), [period]);
  const periodParams = { from: range.from, to: range.to, days: period };

  const overview = useQuery({
    queryKey: ['stats-overview', period],
    queryFn: () => api.stats.overview(period),
  });
  const weekly = useQuery({
    queryKey: ['stats-weekly', period],
    queryFn: () => api.stats.weekly({ ...periodParams, limit: 52 }),
  });
  const topics = useQuery({
    queryKey: ['stats-topics', period],
    queryFn: () => api.stats.topics(periodParams),
  });
  const priorities = useQuery({
    queryKey: ['stats-priorities', period],
    queryFn: () => api.stats.priorities(periodParams),
  });
  const timeDist = useQuery({
    queryKey: ['stats-time', period],
    queryFn: () => api.stats.timeDistribution(periodParams),
  });
  const patterns = useQuery({
    queryKey: ['pattern-streaks'],
    queryFn: api.patterns.streaksAll,
  });
  const diaryInsights = useQuery({
    queryKey: ['stats-diary-insights', period],
    queryFn: () => api.stats.diaryInsights(periodParams),
    enabled: tab === 'diary' || tab === 'overview',
  });
  const heatmap = useQuery({
    queryKey: ['stats-heatmap', period],
    queryFn: () => api.calendar.heatmap(range.from, range.to),
  });

  const weeklyChart = useMemo(
    () =>
      [...(weekly.data ?? [])].reverse().map((w) => ({
        name: fmtDate(w.week_start),
        tasks_done: w.tasks_done,
        tasks_total: w.tasks_total,
        mood: w.avg_mood,
        pattern_clean_pct:
          w.patterns_scheduled > 0
            ? Math.round((100 * w.patterns_success) / w.patterns_scheduled)
            : null,
      })),
    [weekly.data],
  );

  const weeklyHasData = weeklyChart.some(
    (w) => w.tasks_total > 0 || w.mood != null || w.pattern_clean_pct != null,
  );

  return (
    <div className="space-y-6">
      <PageHeader
        title="Статистика"
        subtitle="Сводка по задачам, паттернам и дневнику"
      />

      <FieldGroup legend="Период отчёта">
        <div className="flex flex-wrap items-center gap-2">
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
        <p className="mt-2 text-xs text-ink-muted">
          {fmtDate(range.from)} — {fmtDate(range.to)}
        </p>
      </FieldGroup>

      {overview.isError && <ErrorBanner message={`KPI: ${queryError(overview.error)}`} />}

      {overview.data && <KpiGrid data={overview.data} />}

      <FieldGroup legend="Раздел" className="border-b border-border pb-2">
        <div className="flex flex-wrap gap-2">
          {(
            [
              ['overview', 'Обзор'],
              ['tasks', 'Задачи'],
              ['patterns', 'Паттерны'],
              ['diary', 'Связи показателей'],
              ['olap', 'Сводные отчёты'],
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
      </FieldGroup>

      {tab === 'overview' && (
        <div className="grid gap-6 lg:grid-cols-2">
          <StatsConnectionsTeaser
            data={diaryInsights.data}
            loading={diaryInsights.isLoading}
            onOpenTab={() => setTab('diary')}
          />

          <ChartCard
            title="Недели за период"
            loading={weekly.isLoading}
            error={weekly.isError}
            errorMessage={queryError(weekly.error)}
            empty={!weekly.isLoading && !weekly.isError && !weeklyHasData}
            emptyMessage="Нет задач и записей дневника за период"
            className="lg:col-span-2"
          >
            <StatsWeeklyMiniGrid rows={weeklyChart} series={OVERVIEW_WEEKLY_SERIES} />
          </ChartCard>

          <ChartCard
            title={`Активность (${period} д)`}
            loading={heatmap.isLoading}
            error={heatmap.isError}
            errorMessage={queryError(heatmap.error)}
            empty={!heatmap.isLoading && !heatmap.isError && (heatmap.data ?? []).length === 0}
            emptyMessage="Нет событий за период"
          >
            <StatsHeatmapGrid points={heatmap.data ?? []} />
          </ChartCard>

          <ChartCard
            title="Время по темам"
            loading={timeDist.isLoading}
            error={timeDist.isError}
            errorMessage={queryError(timeDist.error)}
            empty={!timeDist.isLoading && !timeDist.isError && (timeDist.data ?? []).length === 0}
            emptyMessage="Нет учтённого времени — добавьте запись времени к задачам"
          >
            <ResponsiveContainer width="100%" height={260}>
              <PieChart margin={{ top: 8, bottom: 8 }}>
                <Pie
                  data={timeDist.data ?? []}
                  dataKey="minutes"
                  nameKey="topic_name"
                  cx="50%"
                  cy="50%"
                  outerRadius={70}
                  labelLine={false}
                  label={false}
                >
                  {(timeDist.data ?? []).map((_, i) => (
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  formatter={(v: number) => [minutesLabel(v), 'Учтённое время']}
                />
                <Legend
                  wrapperStyle={{ fontSize: 11 }}
                  formatter={(topic: string) => ellipsis(topic, 24)}
                />
              </PieChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>
      )}

      {tab === 'tasks' && (
        <TasksTab
          topics={topics.data ?? []}
          priorities={priorities.data ?? []}
          loading={topics.isLoading || priorities.isLoading}
          topicsError={topics.isError ? queryError(topics.error) : undefined}
          prioritiesError={priorities.isError ? queryError(priorities.error) : undefined}
          periodLabel={`${period} д`}
        />
      )}

      {tab === 'patterns' && (
        <PatternsTab
          rows={patterns.data ?? []}
          loading={patterns.isLoading}
          error={patterns.isError}
          errorMessage={patterns.isError ? queryError(patterns.error) : undefined}
        />
      )}

      {tab === 'diary' && (
        <DiaryTab
          data={diaryInsights.data}
          loading={diaryInsights.isLoading}
          error={diaryInsights.isError ? queryError(diaryInsights.error) : undefined}
        />
      )}

      {tab === 'olap' && <OlapBuilder period={period} range={range} />}
    </div>
  );
}

function TasksTab({
  topics,
  priorities,
  loading,
  topicsError,
  prioritiesError,
  periodLabel,
}: {
  topics: import('@/api/types').TopicBreakdown[];
  priorities: import('@/api/types').PriorityBreakdown[];
  loading: boolean;
  topicsError?: string;
  prioritiesError?: string;
  periodLabel: string;
}) {
  return (
    <div className="grid gap-6 lg:grid-cols-2">
      <p className="text-xs text-ink-muted lg:col-span-2">
        Задачи с дедлайном в выбранном периоде ({periodLabel}).
      </p>
      {topicsError && <ErrorBanner message={`Темы: ${topicsError}`} />}
      {prioritiesError && <ErrorBanner message={`Приоритеты: ${prioritiesError}`} />}

      <ChartCard
        title="Выполнение по темам"
        loading={loading}
        empty={!loading && !topicsError && topics.length === 0}
        emptyMessage="Нет задач с дедлайном за период"
      >
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={topics} margin={statsChartMargin({ bottom: 48, left: 48 })}>
            <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
            <XAxis dataKey="topic_name" tick={{ fontSize: 10 }} interval={0} angle={-20} textAnchor="end" height={56}>
              <AxisLabelX value="Тема" />
            </XAxis>
            <YAxis domain={[0, 100]} tickFormatter={(v) => `${v}%`} width={44}>
              <AxisLabelYLeft value="% выполнено" />
            </YAxis>
            <Tooltip formatter={(v: number) => [pct(v), '% выполнения']} />
            <Bar dataKey="completion_rate" name="% выполнения" fill="#16a34a" />
          </BarChart>
        </ResponsiveContainer>
      </ChartCard>

      <ChartCard
        title="По приоритету"
        loading={loading}
        empty={!loading && !prioritiesError && priorities.length === 0}
        emptyMessage="Нет задач за период"
      >
        <ResponsiveContainer width="100%" height={300}>
          <BarChart
            data={priorities.map((p) => ({
              ...p,
              label: TASK_PRIORITY_LABEL[p.priority as keyof typeof TASK_PRIORITY_LABEL] ?? p.priority,
            }))}
            margin={statsChartMargin({ bottom: 40, left: 48 })}
          >
            <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
            <XAxis dataKey="label" tick={{ fontSize: 11 }}>
              <AxisLabelX value="Приоритет" />
            </XAxis>
            <YAxis allowDecimals={false} width={44}>
              <AxisLabelYLeft value="Задач, шт." />
            </YAxis>
            <Tooltip formatter={(v: number, name: string) => [`${v} шт.`, name]} />
            <Legend wrapperStyle={{ fontSize: 11 }} />
            <Bar dataKey="done" name="Выполнено" stackId="a" fill="#16a34a" />
            <Bar dataKey="overdue" name="Просрочено" stackId="a" fill="#ef4444" />
          </BarChart>
        </ResponsiveContainer>
      </ChartCard>

      <ChartCard
        title="Таблица по темам"
        loading={loading}
        className="lg:col-span-2"
        empty={!loading && topics.length === 0}
        emptyMessage="Нет данных"
      >
        <DataTable
          headers={['Тема', 'Всего', 'Выполнено', 'Просрочено', '%', 'План мин']}
          rows={topics.map((r) => [
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
  );
}

function DiaryTab({
  data,
  loading,
  error,
}: {
  data?: DiaryInsights;
  loading: boolean;
  error?: string;
}) {
  if (error) {
    return <ErrorBanner message={error} />;
  }
  if (loading) {
    return (
      <div className="flex min-h-[240px] items-center justify-center">
        <Spinner />
      </div>
    );
  }
  if (!data || (data.diary_days === 0 && data.weeks.length === 0)) {
    return (
      <div className="mx-auto max-w-3xl rounded-lg border border-border bg-surface-2 px-6 py-10 text-center">
        <p className="text-sm text-ink-muted">
          За этот период в дневнике нет записей с настроением. Добавьте несколько дней — здесь
          появится сравнение с задачами и паттернами.
        </p>
        <Link to="/diary" className="btn-primary mt-4 inline-flex">
          Открыть дневник
        </Link>
      </div>
    );
  }
  return <DiaryLinksSection data={data} />;
}

function PatternsTab({
  rows,
  loading,
  error,
  errorMessage,
}: {
  rows: PatternStreak[];
  loading: boolean;
  error: boolean;
  errorMessage?: string;
}) {
  const withSchedule = rows.filter((p) => p.scheduled_days_30d > 0);
  const chartRows = withSchedule.length > 0 ? withSchedule : rows;

  if (!loading && !error && rows.length === 0) {
    return (
      <div className="card">
        <div className="card-body space-y-3 text-center py-10">
          <p className="text-sm text-ink-muted">Паттернов пока нет — статистика появится после создания.</p>
          <Link to="/patterns" className="btn-primary inline-flex">
            Перейти к паттернам
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="grid gap-6">
      {errorMessage && <ErrorBanner message={errorMessage} />}
      <p className="text-xs text-ink-muted">
        Последние 30 календарных дней по расписанию каждого паттерна (не зависит от переключателя
        7/30/90).
      </p>

      <ChartCard
        title="Чистота паттернов (30 д)"
        loading={loading}
        empty={!loading && chartRows.length === 0}
        emptyMessage="Нет дней по расписанию — задайте напоминания в паттерне"
      >
        <ResponsiveContainer width="100%" height={Math.max(220, chartRows.length * 40)}>
          <BarChart
            data={chartRows}
            layout="vertical"
            margin={{ top: 8, right: 48, bottom: 36, left: 128 }}
          >
            <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
            <XAxis type="number" domain={[0, 100]} tickFormatter={(v) => `${v}%`}>
              <AxisLabelX value="% чистых дней" />
            </XAxis>
            <YAxis type="category" dataKey="title" tick={{ fontSize: 11 }} width={116}>
              <AxisLabelYLeft value="Паттерн" />
            </YAxis>
            <Tooltip formatter={(v: number) => [pct(v), 'Чистота за 30 д']} />
            <Bar dataKey="clean_rate_30d" name="% чистых дней" fill="#8b5cf6" />
          </BarChart>
        </ResponsiveContainer>
      </ChartCard>

      <ChartCard title="Все паттерны" loading={loading} empty={rows.length === 0}>
        <DataTable
          headers={['Название', 'Режим', 'Серия', 'Max', '30д успешных', 'Чистота']}
          rows={rows.map((p) => [
            p.title,
            PATTERN_MODE_LABEL[p.pattern_mode] ?? p.pattern_mode,
            p.current_streak,
            p.max_streak,
            p.scheduled_days_30d === 0 ? '—' : `${p.success_days_30d}/${p.scheduled_days_30d}`,
            p.scheduled_days_30d === 0 ? '—' : pct(p.clean_rate_30d),
          ])}
        />
      </ChartCard>
    </div>
  );
}

function KpiGrid({ data }: { data: StatsOverview }) {
  const items = [
    { label: 'Задачи', value: `${data.tasks_done}/${data.tasks_total}`, hint: pct(data.task_completion_rate) },
    { label: 'Просрочено', value: String(data.tasks_overdue), hint: 'за период' },
    { label: 'Время', value: minutesLabel(data.minutes_logged), hint: `Pomodoro ${data.pomodoro_minutes} мин` },
    { label: 'Дневник', value: String(data.diary_entries), hint: `настроение ${data.avg_mood?.toFixed(1) ?? '—'}` },
    {
      label: 'Паттерны (свод)',
      value: data.patterns_scheduled === 0 ? '—' : pct(data.pattern_clean_rate),
      hint:
        data.patterns_scheduled === 0
          ? 'нет дней по расписанию'
          : `${data.patterns_success}/${data.patterns_scheduled} дней-паттернов`,
    },
    { label: 'Метки', value: String(data.marker_events), hint: `негативных ${data.marker_bad_events}` },
    { label: 'Активность', value: String(data.activity_score), hint: `${data.active_days} дней с событиями` },
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

function DataTable({ headers, rows }: { headers: string[]; rows: (string | number)[][] }) {
  if (rows.length === 0) {
    return <p className="text-sm text-ink-muted py-4">Нет строк</p>;
  }
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
  error,
  errorMessage,
  empty,
  emptyMessage,
  caption,
  children,
  className = '',
}: {
  title: string;
  loading?: boolean;
  error?: boolean;
  errorMessage?: string;
  empty?: boolean;
  emptyMessage?: string;
  /** Пояснение под графиком (только при успешной отрисовке) */
  caption?: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`card ${className}`}>
      <div className="card-body">
        <h2 className="mb-4 font-semibold">{title}</h2>
        {error && errorMessage ? (
          <ErrorBanner message={errorMessage} />
        ) : loading ? (
          <div className="flex h-64 items-center justify-center">
            <Spinner />
          </div>
        ) : empty ? (
          <p className="py-12 text-center text-sm text-ink-muted">{emptyMessage ?? 'Нет данных'}</p>
        ) : (
          <>
            {children}
            {caption ? <ChartCaption>{caption}</ChartCaption> : null}
          </>
        )}
      </div>
    </section>
  );
}
