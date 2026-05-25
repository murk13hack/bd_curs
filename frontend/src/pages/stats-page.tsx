import { useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
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
import { api, ApiError } from '@/api/client';
import type { HolisticCorrelationWeek, OlapMeta, PatternStreak, StatsOverview } from '@/api/types';
import {
  AxisLabelX,
  AxisLabelYLeft,
  AxisLabelYRight,
  ChartCaption,
  statsChartMargin,
} from '@/components/stats/stats-chart-labels';
import { StatsHeatmapGrid } from '@/components/stats/stats-heatmap-grid';
import { PageHeader, Spinner, ErrorBanner } from '@/components/ui/primitives';
import {
  ENERGY_BUCKET_LABEL,
  MOOD_BUCKET_LABEL,
  PATTERN_MODE_LABEL,
  TASK_PRIORITY_LABEL,
} from '@/lib/labels';
import { FieldGroup, FormField } from '@/components/ui/form-field';
import { fmtDate, minutesLabel, pct } from '@/lib/format';
import {
  formatOlapMeasure,
  OLAP_PERCENT_MEASURES,
  olapYAxisLabel,
  statsPeriodRange,
} from '@/lib/stats-period';

const COLORS = ['#16a34a', '#3b82f6', '#f59e0b', '#ec4899', '#8b5cf6', '#6b7280', '#ef4444'];

type Tab = 'overview' | 'tasks' | 'patterns' | 'diary' | 'olap';

function queryError(e: unknown): string {
  if (e instanceof ApiError) return e.message;
  if (e instanceof Error) return e.message;
  return 'Ошибка загрузки';
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
  const holistic = useQuery({
    queryKey: ['stats-holistic', period],
    queryFn: () => api.stats.holistic(periodParams),
  });
  const correlation = useQuery({
    queryKey: ['stats-correlation', period],
    queryFn: () => api.stats.correlation(periodParams),
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
        subtitle="Задачи, паттерны, дневник и OLAP за выбранный период"
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
          {fmtDate(range.from)} — {fmtDate(range.to)}. Влияет на KPI, обзор, задачи, дневник и
          OLAP. Паттерны в таблице — всегда последние 30 д по расписанию.
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
      </FieldGroup>

      {tab === 'overview' && (
        <div className="grid gap-6 lg:grid-cols-2">
          <ChartCard
            title="Недельная динамика"
            loading={weekly.isLoading}
            error={weekly.isError}
            errorMessage={queryError(weekly.error)}
            empty={!weekly.isLoading && !weekly.isError && !weeklyHasData}
            emptyMessage="Нет задач и записей дневника за период"
            className="lg:col-span-2"
            caption="По каждой неделе: зелёные столбцы — число выполненных задач (левая ось, шт.); фиолетовые — доля «чистых» дней паттернов от запланированных (правая ось, %); линия — среднее настроение из дневника (правая ось, баллы 1–5)."
          >
            <ResponsiveContainer width="100%" height={340}>
              <ComposedChart
                data={weeklyChart}
                margin={statsChartMargin({ right: 88, left: 56, bottom: 44 })}
              >
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis dataKey="name" tick={{ fontSize: 10 }} interval="preserveStartEnd">
                  <AxisLabelX value="Неделя (начало)" />
                </XAxis>
                <YAxis yAxisId="count" domain={[0, 'auto']} allowDecimals={false} width={48}>
                  <AxisLabelYLeft value="Задач, шт." />
                </YAxis>
                <YAxis
                  yAxisId="pct"
                  orientation="right"
                  domain={[0, 100]}
                  tickFormatter={(v) => `${v}%`}
                  width={44}
                >
                  <AxisLabelYRight value="% паттернов" />
                </YAxis>
                <YAxis
                  yAxisId="mood"
                  orientation="right"
                  domain={[0, 5]}
                  tickCount={6}
                  width={40}
                  tick={{ fontSize: 10 }}
                >
                  <AxisLabelYRight value="Настроение" />
                </YAxis>
                <Tooltip
                  formatter={(v: number, name: string) => {
                    if (name.includes('%') || name.includes('чистых')) return pct(v);
                    if (name.includes('Настроение')) return v?.toFixed?.(1) ?? v;
                    return `${v} шт.`;
                  }}
                />
                <Legend wrapperStyle={{ fontSize: 11, paddingTop: 8 }} />
                <Bar
                  yAxisId="count"
                  dataKey="tasks_done"
                  name="Выполнено задач (шт.)"
                  fill="#16a34a"
                />
                <Bar
                  yAxisId="pct"
                  dataKey="pattern_clean_pct"
                  name="% чистых дней (паттерны)"
                  fill="#8b5cf6"
                />
                <Line
                  yAxisId="mood"
                  type="monotone"
                  dataKey="mood"
                  name="Настроение (1–5)"
                  stroke="#f59e0b"
                  connectNulls
                />
              </ComposedChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard
            title={`Активность (${period} д)`}
            loading={heatmap.isLoading}
            error={heatmap.isError}
            errorMessage={queryError(heatmap.error)}
            empty={!heatmap.isLoading && !heatmap.isError && (heatmap.data ?? []).length === 0}
            emptyMessage="Нет событий за период"
            caption="Календарь активности: в каждой ячейке — один день, цвет — суммарный счётчик событий (задачи, дневник, паттерны, метки). Чем темнее зелёный, тем больше действий в этот день."
          >
            <StatsHeatmapGrid points={heatmap.data ?? []} />
          </ChartCard>

          <ChartCard
            title="Время по темам"
            loading={timeDist.isLoading}
            error={timeDist.isError}
            errorMessage={queryError(timeDist.error)}
            empty={!timeDist.isLoading && !timeDist.isError && (timeDist.data ?? []).length === 0}
            emptyMessage="Нет учтённого времени — добавьте time-log к задачам"
            caption="Доля учтённого времени по темам за период. Размер сектора — минуты из time-log (не Pomodoro). Подписи на секторах — тема и длительность."
          >
            <ResponsiveContainer width="100%" height={260}>
              <PieChart margin={{ top: 8, bottom: 8 }}>
                <Pie
                  data={timeDist.data ?? []}
                  dataKey="minutes"
                  nameKey="topic_name"
                  cx="50%"
                  cy="50%"
                  outerRadius={72}
                  label={({ name, value }) => `${name}: ${minutesLabel(value as number)}`}
                >
                  {(timeDist.data ?? []).map((_, i) => (
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  formatter={(v: number) => [minutesLabel(v), 'Учтённое время']}
                />
                <Legend wrapperStyle={{ fontSize: 11 }} />
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
          holistic={holistic.data ?? []}
          correlation={correlation.data ?? []}
          loading={holistic.isLoading || correlation.isLoading}
          holisticError={holistic.isError ? queryError(holistic.error) : undefined}
          correlationError={correlation.isError ? queryError(correlation.error) : undefined}
          periodLabel={`${period} д`}
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
        caption="Доля выполненных задач с дедлайном в периоде по каждой теме: выполнено ÷ (выполнено + просрочено + в работе). Ось Y — проценты 0–100%."
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
        caption="Сложенные столбцы — число задач (шт.), не проценты: зелёный — выполнено, красный — просрочено с дедлайном в выбранном периоде."
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
  holistic,
  correlation,
  loading,
  holisticError,
  correlationError,
  periodLabel,
}: {
  holistic: HolisticCorrelationWeek[];
  correlation: import('@/api/types').CorrelationWeek[];
  loading: boolean;
  holisticError?: string;
  correlationError?: string;
  periodLabel: string;
}) {
  const chartData = holistic.map((w) => ({
    name: fmtDate(w.week_start),
    mood: w.avg_mood,
    tasks: w.avg_task_rate,
    patterns: w.avg_pattern_clean_rate,
  }));
  const hasChart = chartData.some(
    (w) => w.mood != null || w.tasks != null || w.patterns != null,
  );

  return (
    <div className="grid gap-6">
      <p className="text-xs text-ink-muted">
        Недельные средние за {periodLabel}. Корреляции Пирсона считаются по дням внутри недели;
        нужны записи дневника и вариативность показателей.
      </p>
      {holisticError && <ErrorBanner message={`Сводка: ${holisticError}`} />}
      {correlationError && <ErrorBanner message={`Корреляция (задачи): ${correlationError}`} />}

      <ChartCard
        title="Настроение и продуктивность (недели)"
        loading={loading}
        className="lg:col-span-2"
        empty={!loading && !holisticError && !hasChart}
        emptyMessage="Ведите дневник (настроение) и отмечайте задачи/паттерны — тогда появятся графики"
        caption="Средние за календарную неделю: оранжевая линия — настроение из дневника (левая ось, 1–5); зелёная и фиолетовая — % выполненных задач и % «чистых» дней паттернов (правая ось, 0–100%). Показатели на разных шкалах, чтобы не смешивать баллы и проценты."
      >
        <ResponsiveContainer width="100%" height={320}>
          <LineChart data={chartData} margin={statsChartMargin({ right: 56, left: 52, bottom: 44 })}>
            <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
            <XAxis dataKey="name" tick={{ fontSize: 10 }} interval="preserveStartEnd">
              <AxisLabelX value="Неделя (начало)" />
            </XAxis>
            <YAxis yAxisId="mood" domain={[0, 5]} tickCount={6} width={48}>
              <AxisLabelYLeft value="Настроение (1–5)" />
            </YAxis>
            <YAxis
              yAxisId="pct"
              orientation="right"
              domain={[0, 100]}
              tickFormatter={(v) => `${v}%`}
              width={48}
            >
              <AxisLabelYRight value="% задач и паттернов" />
            </YAxis>
            <Tooltip
              formatter={(v: number, name: string) =>
                name === 'Настроение (1–5)' ? [v.toFixed(1), 'балл'] : [pct(v), '%']
              }
            />
            <Legend wrapperStyle={{ fontSize: 11, paddingTop: 8 }} />
            <Line
              yAxisId="mood"
              type="monotone"
              dataKey="mood"
              name="Настроение (1–5)"
              stroke="#f59e0b"
              connectNulls
            />
            <Line
              yAxisId="pct"
              type="monotone"
              dataKey="tasks"
              name="% задач"
              stroke="#16a34a"
              connectNulls
            />
            <Line
              yAxisId="pct"
              type="monotone"
              dataKey="patterns"
              name="% паттернов"
              stroke="#8b5cf6"
              connectNulls
            />
          </LineChart>
        </ResponsiveContainer>
      </ChartCard>

      <ChartCard
        title="Корреляции по неделям"
        loading={loading}
        empty={!loading && holistic.length === 0}
        emptyMessage="Нет недель с данными"
        caption="Таблица: средние за неделю и коэффициенты Пирсона (−1…1) между показателями по дням внутри недели. «—» — мало данных или нет вариации."
      >
        <DataTable
          headers={[
            'Неделя',
            'Настроение',
            'Задачи %',
            'Паттерны %',
            'Настр. → задачи',
            'Настр. → паттерны',
            'Энергия → задачи',
            'Дней',
          ]}
          rows={holistic.slice(-16).map((r) => [
            fmtDate(r.week_start),
            r.avg_mood?.toFixed(1) ?? '—',
            r.avg_task_rate != null ? pct(r.avg_task_rate) : '—',
            r.avg_pattern_clean_rate != null ? pct(r.avg_pattern_clean_rate) : '—',
            r.corr_mood_tasks?.toFixed(2) ?? '—',
            r.corr_mood_patterns?.toFixed(2) ?? '—',
            r.corr_energy_tasks?.toFixed(2) ?? '—',
            String(r.days_count),
          ])}
        />
      </ChartCard>

      {correlation.length > 0 && (
        <ChartCard
          title="Корреляция настроения и выполнения задач (классический срез)"
          caption="Альтернативный срез: дни с записью дневника и задачами по дедлайну в ту же неделю. % задач — доля выполненных с дедлайном."
        >
          <DataTable
            headers={['Неделя', 'Настроение', 'Энергия', '% задач', 'Настр.↔задачи', 'Энерг.↔задачи']}
            rows={correlation.slice(-12).map((r) => [
              fmtDate(r.week_start),
              r.avg_mood?.toFixed(1) ?? '—',
              r.avg_energy?.toFixed(1) ?? '—',
              r.avg_completion_rate != null ? pct(r.avg_completion_rate) : '—',
              r.corr_mood_rate?.toFixed(2) ?? '—',
              r.corr_energy_rate?.toFixed(2) ?? '—',
            ])}
          />
        </ChartCard>
      )}
    </div>
  );
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
        7/30/90). При завышенных % примените миграцию <code className="text-[10px]">011</code>.
      </p>

      <ChartCard
        title="Чистота паттернов (30 д)"
        loading={loading}
        empty={!loading && chartRows.length === 0}
        emptyMessage="Нет дней по расписанию — задайте напоминания в паттерне"
        caption="Горизонтальные полосы: % успешных дней за последние 30 календарных дней по расписанию каждого паттерна (успешные ÷ запланированные). Ось X — только проценты."
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

function OlapBuilder({
  period,
  range,
}: {
  period: number;
  range: { from: string; to: string };
}) {
  const meta = useQuery({ queryKey: ['stats-meta'], queryFn: api.stats.meta });
  const [dim, setDim] = useState('week');
  const [measure, setMeasure] = useState('completion_rate');
  const [moodFilter, setMoodFilter] = useState('');
  const [energyFilter, setEnergyFilter] = useState('');

  const queryMut = useMutation({
    mutationFn: () =>
      api.stats.olap({
        dimensions: dim ? [dim] : [],
        measures: [measure],
        date_from: range.from,
        date_to: range.to,
        filters: {
          ...(moodFilter ? { mood_bucket: moodFilter } : {}),
          ...(energyFilter ? { energy_bucket: energyFilter } : {}),
        },
      }),
  });

  useEffect(() => {
    if (meta.data) queryMut.mutate();
  }, [period, range.from, range.to, meta.data]);

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

  const dimLabel =
    meta.data?.dimensions.find((d) => d.id === dim)?.label ?? 'Измерение';
  const measureLabel =
    meta.data?.measures.find((m) => m.id === measure)?.label ?? 'Значение';
  const yAxisLabel = olapYAxisLabel(measure);

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      {meta.isError && <ErrorBanner message={`OLAP meta: ${queryError(meta.error)}`} />}
      {queryMut.isError && <ErrorBanner message={`OLAP: ${queryError(queryMut.error)}`} />}

      <div className="card lg:col-span-1">
        <div className="card-body space-y-3">
          <h2 className="font-semibold">OLAP-конструктор</h2>
          <p className="text-xs text-ink-muted">
            Период {fmtDate(range.from)} — {fmtDate(range.to)}. Данные из v_olap_daily_facts.
          </p>
          <FormField label="Измерение">
            <select className="select" value={dim} onChange={(e) => setDim(e.target.value)}>
              {(meta.data?.dimensions ?? []).map((d: OlapMeta['dimensions'][0]) => (
                <option key={d.id} value={d.id}>
                  {d.label}
                </option>
              ))}
            </select>
          </FormField>
          <FormField label="Мера">
            <select className="select" value={measure} onChange={(e) => setMeasure(e.target.value)}>
              {(meta.data?.measures ?? []).map((m) => (
                <option key={m.id} value={m.id}>
                  {m.label}
                </option>
              ))}
            </select>
          </FormField>
          <FormField label="Настроение">
            <select className="select" value={moodFilter} onChange={(e) => setMoodFilter(e.target.value)}>
              {Object.entries(MOOD_BUCKET_LABEL).map(([v, label]) => (
                <option key={v || 'any'} value={v}>
                  {label}
                </option>
              ))}
            </select>
          </FormField>
          <FormField label="Энергия">
            <select className="select" value={energyFilter} onChange={(e) => setEnergyFilter(e.target.value)}>
              {Object.entries(ENERGY_BUCKET_LABEL).map(([v, label]) => (
                <option key={v || 'any'} value={v}>
                  {label}
                </option>
              ))}
            </select>
          </FormField>
          <button
            type="button"
            className="btn-primary w-full"
            disabled={queryMut.isPending || meta.isLoading}
            onClick={() => queryMut.mutate()}
          >
            {queryMut.isPending ? 'Построение…' : 'Обновить срез'}
          </button>
        </div>
      </div>

      <ChartCard
        title="Результат OLAP"
        loading={queryMut.isPending}
        empty={!queryMut.isPending && chartData.length === 0 && !queryMut.isError}
        emptyMessage="Нет строк за период и фильтры — смените меру или период"
        className="lg:col-span-2"
        caption={`Срез «${measureLabel}» по измерению «${dimLabel}» за выбранный период. Ось Y — ${yAxisLabel.toLowerCase()}; значения в таблице совпадают с подписями оси.`}
      >
        <>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart
              data={chartData}
              margin={statsChartMargin({
                bottom: 48,
                left: 52,
                right: 24,
              })}
            >
              <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
              <XAxis dataKey="name" tick={{ fontSize: 10 }} interval={0} angle={-18} textAnchor="end" height={52}>
                <AxisLabelX value={dimLabel} />
              </XAxis>
              <YAxis
                width={48}
                domain={OLAP_PERCENT_MEASURES.has(measure) ? [0, 100] : ['auto', 'auto']}
                tickFormatter={(v) =>
                  OLAP_PERCENT_MEASURES.has(measure) ? `${v}%` : String(v)
                }
                allowDecimals={!OLAP_PERCENT_MEASURES.has(measure)}
              >
                <AxisLabelYLeft value={yAxisLabel} />
              </YAxis>
              <Tooltip
                formatter={(v: number) => [formatOlapMeasure(measure, v), measureLabel]}
              />
              <Bar dataKey="value" name={measureLabel} fill="#3b82f6" />
            </BarChart>
          </ResponsiveContainer>
          <DataTable
            headers={['Измерение', 'Значение']}
            rows={chartData.map((r) => [r.name, formatOlapMeasure(measure, r.value)])
          />
        </>
      </ChartCard>
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
