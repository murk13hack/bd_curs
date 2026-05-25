import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
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
import { api, ApiError } from '@/api/client';
import {
  AxisLabelX,
  AxisLabelYLeft,
  ChartCaption,
  statsChartMargin,
} from '@/components/stats/stats-chart-labels';
import { FormField } from '@/components/ui/form-field';
import { ErrorBanner, Spinner } from '@/components/ui/primitives';
import { ENERGY_BUCKET_LABEL, MOOD_BUCKET_LABEL } from '@/lib/labels';
import { fmtDate } from '@/lib/format';
import {
  formatOlapMeasure,
  OLAP_MAX_DAY_PERIOD,
  OLAP_PERCENT_MEASURES,
  OLAP_TIME_DIMENSIONS,
  olapYAxisLabel,
  olapYDomain,
} from '@/lib/stats-period';

function queryError(e: unknown): string {
  if (e instanceof ApiError) return e.message;
  if (e instanceof Error) return e.message;
  return 'Ошибка загрузки';
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
}: {
  title: string;
  loading?: boolean;
  error?: boolean;
  errorMessage?: string;
  empty?: boolean;
  emptyMessage?: string;
  caption?: string;
  children: React.ReactNode;
}) {
  return (
    <section className="card min-w-0">
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

export function OlapBuilder({
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

  const dimMeta = meta.data?.dimensions.find((d) => d.id === dim);
  const measureMeta = meta.data?.measures.find((m) => m.id === measure);
  const dayBlocked = period > OLAP_MAX_DAY_PERIOD;

  useEffect(() => {
    if (dayBlocked && dim === 'day') {
      setDim('week');
    }
  }, [dayBlocked, dim]);

  const queryMut = useMutation({
    mutationFn: () =>
      api.stats.olap({
        dimensions: [dim],
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
    if (!meta.data || (dim === 'day' && dayBlocked)) return;
    queryMut.mutate();
  }, [period, range.from, range.to, dim, measure, moodFilter, energyFilter, meta.data, dayBlocked]);

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

  const useLineChart =
    OLAP_TIME_DIMENSIONS.has(dim) && chartData.length > 1 && chartData.length <= 60;
  const dimLabel = dimMeta?.label ?? 'Измерение';
  const measureLabel = measureMeta?.label ?? 'Значение';
  const yAxisLabel = olapYAxisLabel(measure);
  const yDomain = olapYDomain(measure);

  const chartMargin = statsChartMargin({
    bottom: useLineChart ? 44 : 48,
    left: 52,
    right: 16,
  });

  return (
    <div className="mx-auto w-full min-w-0 max-w-5xl space-y-4">
      {meta.isError && <ErrorBanner message={`OLAP meta: ${queryError(meta.error)}`} />}
      {queryMut.isError && <ErrorBanner message={`OLAP: ${queryError(queryMut.error)}`} />}

      {meta.data?.help && (
        <p className="rounded-lg border border-border bg-surface-2/80 px-4 py-3 text-sm text-ink-muted">
          {meta.data.help}
        </p>
      )}

      <div className="grid min-w-0 gap-4 lg:grid-cols-[minmax(0,260px)_minmax(0,1fr)]">
        <div className="card min-w-0">
          <div className="card-body space-y-3">
            <h2 className="font-semibold">OLAP-конструктор</h2>
            <p className="text-xs text-ink-muted">
              {fmtDate(range.from)} — {fmtDate(range.to)} ({period} д)
            </p>

            <FormField label="Измерение (разрез)">
              <select className="select w-full" value={dim} onChange={(e) => setDim(e.target.value)}>
                {(meta.data?.dimensions ?? []).map((d) => (
                  <option key={d.id} value={d.id} disabled={d.id === 'day' && dayBlocked}>
                    {d.label}
                    {d.id === 'day' && dayBlocked ? ' (только ≤30 д)' : ''}
                  </option>
                ))}
              </select>
              {dimMeta?.hint && (
                <p className="mt-1 text-[11px] text-ink-muted">{dimMeta.hint}</p>
              )}
            </FormField>

            <FormField label="Мера">
              <select
                className="select w-full"
                value={measure}
                onChange={(e) => setMeasure(e.target.value)}
              >
                {(meta.data?.measures ?? []).map((m) => (
                  <option key={m.id} value={m.id}>
                    {m.label}
                  </option>
                ))}
              </select>
              {measureMeta?.hint && (
                <p className="mt-1 text-[11px] text-ink-muted">{measureMeta.hint}</p>
              )}
            </FormField>

            <FormField label="Фильтр: настроение">
              <select
                className="select w-full"
                value={moodFilter}
                onChange={(e) => setMoodFilter(e.target.value)}
              >
                {Object.entries(MOOD_BUCKET_LABEL).map(([v, label]) => (
                  <option key={v || 'any'} value={v}>
                    {label}
                  </option>
                ))}
              </select>
            </FormField>

            <FormField label="Фильтр: энергия">
              <select
                className="select w-full"
                value={energyFilter}
                onChange={(e) => setEnergyFilter(e.target.value)}
              >
                {Object.entries(ENERGY_BUCKET_LABEL).map(([v, label]) => (
                  <option key={v || 'any'} value={v}>
                    {label}
                  </option>
                ))}
              </select>
            </FormField>

            <button
              type="button"
              className="btn-secondary w-full text-sm"
              disabled={queryMut.isPending || meta.isLoading}
              onClick={() => queryMut.mutate()}
            >
              Обновить
            </button>
          </div>
        </div>

        <ChartCard
          title="Результат"
          loading={queryMut.isPending || meta.isLoading}
          empty={!queryMut.isPending && !meta.isLoading && chartData.length === 0 && !queryMut.isError}
          emptyMessage="Нет данных — ослабьте фильтры или смените период"
          caption={`${measureLabel} в разрезе «${dimLabel}». ${
            useLineChart ? 'Линия — динамика по времени.' : 'Столбцы — категории.'
          } Задачи считаются по дедлайну в день; паттерны — слоты «паттерн×день».`}
        >
          <ResponsiveContainer width="100%" height={280}>
            {useLineChart ? (
              <LineChart data={chartData} margin={chartMargin}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis dataKey="name" tick={{ fontSize: 10 }} interval="preserveStartEnd">
                  <AxisLabelX value={dimLabel} />
                </XAxis>
                <YAxis
                  width={44}
                  domain={yDomain}
                  tickFormatter={(v) =>
                    OLAP_PERCENT_MEASURES.has(measure) ? `${v}%` : String(v)
                  }
                  allowDecimals={OLAP_PERCENT_MEASURES.has(measure) ? false : true}
                >
                  <AxisLabelYLeft value={yAxisLabel} />
                </YAxis>
                <Tooltip
                  formatter={(v: number) => [formatOlapMeasure(measure, v), measureLabel]}
                />
                <Line
                  type="monotone"
                  dataKey="value"
                  stroke="#3b82f6"
                  strokeWidth={2}
                  dot={{ r: 3 }}
                />
              </LineChart>
            ) : (
              <BarChart data={chartData} margin={chartMargin}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis
                  dataKey="name"
                  tick={{ fontSize: 10 }}
                  interval={0}
                  angle={chartData.length > 6 ? -18 : 0}
                  textAnchor={chartData.length > 6 ? 'end' : 'middle'}
                  height={chartData.length > 6 ? 52 : 32}
                >
                  <AxisLabelX value={dimLabel} />
                </XAxis>
                <YAxis
                  width={44}
                  domain={yDomain}
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
                <Bar dataKey="value" fill="#3b82f6" radius={[2, 2, 0, 0]} />
              </BarChart>
            )}
          </ResponsiveContainer>
          <DataTable
            headers={['Разрез', 'Значение']}
            rows={chartData.map((r) => [r.name, formatOlapMeasure(measure, r.value)])}
          />
        </ChartCard>
      </div>
    </div>
  );
}
