import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { AxisLabelX, AxisLabelYLeft, statsChartMargin } from '@/components/stats/stats-chart-labels';
import { pct } from '@/lib/format';

export type WeeklyChartRow = Record<string, string | number | null | undefined> & {
  name: string;
};

export type WeeklyMiniSeries = {
  dataKey: string;
  title: string;
  yLabel: string;
  kind: 'bar' | 'line';
  color: string;
  unit: 'count' | 'percent' | 'mood';
};

function hasSeriesData(rows: WeeklyChartRow[], key: string): boolean {
  return rows.some((r) => r[key] != null && r[key] !== '');
}

function yDomain(unit: WeeklyMiniSeries['unit']): [number, number] | [number, string] {
  if (unit === 'percent') return [0, 100];
  if (unit === 'mood') return [0, 5];
  return [0, 'auto'];
}

function formatTooltip(unit: WeeklyMiniSeries['unit'], v: number): string {
  if (unit === 'percent') return pct(v);
  if (unit === 'mood') return v.toFixed(1);
  return `${v} шт.`;
}

function MiniChart({
  rows,
  series,
}: {
  rows: WeeklyChartRow[];
  series: WeeklyMiniSeries;
}) {
  const empty = !hasSeriesData(rows, series.dataKey);
  const margin = statsChartMargin({ left: 44, right: 12, bottom: 36, top: 8 });
  const tickFmt =
    series.unit === 'percent' ? (v: number) => `${v}%` : undefined;

  if (empty) {
    return (
      <div className="flex h-[200px] flex-col rounded-lg border border-border bg-surface-2 p-3">
        <h3 className="text-sm font-medium text-ink">{series.title}</h3>
        <p className="text-[10px] text-ink-muted">{series.yLabel}</p>
        <p className="mt-auto text-center text-xs text-ink-muted">Нет данных за период</p>
      </div>
    );
  }

  const chartProps = {
    data: rows,
    margin,
  };

  return (
    <div className="rounded-lg border border-border bg-surface-2 p-3">
      <h3 className="text-sm font-medium text-ink">{series.title}</h3>
      <p className="mb-2 text-[10px] text-ink-muted">{series.yLabel}</p>
      <ResponsiveContainer width="100%" height={200}>
        {series.kind === 'bar' ? (
          <BarChart {...chartProps}>
            <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
            <XAxis dataKey="name" tick={{ fontSize: 9 }} interval="preserveStartEnd" />
            <YAxis domain={yDomain(series.unit)} allowDecimals={series.unit !== 'count'} tickFormatter={tickFmt} width={40}>
              <AxisLabelYLeft value={series.yLabel} />
            </YAxis>
            <Tooltip formatter={(v: number) => [formatTooltip(series.unit, v), series.title]} />
            <Bar dataKey={series.dataKey} fill={series.color} radius={[2, 2, 0, 0]} />
          </BarChart>
        ) : (
          <LineChart {...chartProps}>
            <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
            <XAxis dataKey="name" tick={{ fontSize: 9 }} interval="preserveStartEnd">
              <AxisLabelX value="Неделя" />
            </XAxis>
            <YAxis domain={yDomain(series.unit)} tickCount={series.unit === 'mood' ? 6 : 5} tickFormatter={tickFmt} width={40}>
              <AxisLabelYLeft value={series.yLabel} />
            </YAxis>
            <Tooltip formatter={(v: number) => [formatTooltip(series.unit, v), series.title]} />
            <Line
              type="monotone"
              dataKey={series.dataKey}
              stroke={series.color}
              strokeWidth={2}
              dot={{ r: 2 }}
              connectNulls
            />
          </LineChart>
        )}
      </ResponsiveContainer>
    </div>
  );
}

export function StatsWeeklyMiniGrid({
  rows,
  series,
}: {
  rows: WeeklyChartRow[];
  series: WeeklyMiniSeries[];
}) {
  return (
    <div
      className={`grid gap-4 ${
        series.length >= 3 ? 'sm:grid-cols-2 lg:grid-cols-3' : 'sm:grid-cols-2'
      }`}
    >
      {series.map((s) => (
        <MiniChart key={s.dataKey} rows={rows} series={s} />
      ))}
    </div>
  );
}

export const OVERVIEW_WEEKLY_SERIES: WeeklyMiniSeries[] = [
  {
    dataKey: 'tasks_done',
    title: 'Задачи',
    yLabel: 'Выполнено, шт.',
    kind: 'bar',
    color: '#16a34a',
    unit: 'count',
  },
  {
    dataKey: 'pattern_clean_pct',
    title: 'Паттерны',
    yLabel: 'Чистых дней, %',
    kind: 'bar',
    color: '#8b5cf6',
    unit: 'percent',
  },
  {
    dataKey: 'mood',
    title: 'Дневник',
    yLabel: 'Настроение, 1–5',
    kind: 'line',
    color: '#f59e0b',
    unit: 'mood',
  },
];

export const DIARY_WEEKLY_SERIES: WeeklyMiniSeries[] = [
  {
    dataKey: 'mood',
    title: 'Настроение',
    yLabel: 'Среднее, 1–5',
    kind: 'line',
    color: '#f59e0b',
    unit: 'mood',
  },
  {
    dataKey: 'tasks',
    title: 'Задачи',
    yLabel: '% выполнено',
    kind: 'line',
    color: '#16a34a',
    unit: 'percent',
  },
  {
    dataKey: 'patterns',
    title: 'Паттерны',
    yLabel: '% чистых дней',
    kind: 'line',
    color: '#8b5cf6',
    unit: 'percent',
  },
];
