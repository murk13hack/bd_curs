import {
  CartesianGrid,
  ResponsiveContainer,
  Scatter,
  ScatterChart,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { DiaryInsights } from '@/api/types';
import { StatsWeeklyMiniGrid, DIARY_WEEKLY_SERIES } from '@/components/stats/stats-weekly-mini-charts';
import {
  AxisLabelX,
  AxisLabelYLeft,
  statsChartMargin,
} from '@/components/stats/stats-chart-labels';
import { fmtDate, pct } from '@/lib/format';

function linkStrength(value: number | null): { label: string; tone: string } {
  if (value == null) return { label: 'Мало данных', tone: 'text-ink-muted' };
  const abs = Math.abs(value);
  if (abs >= 0.45) {
    return {
      label: value > 0 ? 'Часто растут вместе' : 'Часто в противофазе',
      tone: 'text-accent font-medium',
    };
  }
  if (abs >= 0.2) {
    return {
      label: value > 0 ? 'Слабая связь' : 'Слабая обратная связь',
      tone: 'text-ink',
    };
  }
  return { label: 'Почти не связаны', tone: 'text-ink-muted' };
}

function LinkCard({ title, value }: { title: string; value: number | null }) {
  const s = linkStrength(value);
  return (
    <div className="rounded-lg border border-border bg-surface-2 px-3 py-3">
      <div className="text-sm text-ink-muted">{title}</div>
      <div className={`mt-1 text-sm ${s.tone}`}>{s.label}</div>
    </div>
  );
}

function WeekRow({ week }: { week: DiaryInsights['weeks'][0] }) {
  const link = linkStrength(week.corr_mood_tasks);
  return (
    <div className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-border/70 px-3 py-2 text-sm">
      <span className="font-medium">{fmtDate(week.week_start)}</span>
      <span className="text-xs text-ink-muted">
        настроение {week.avg_mood?.toFixed(1) ?? '—'} · задачи{' '}
        {week.avg_task_rate != null ? pct(week.avg_task_rate) : '—'}
      </span>
      <span className={`text-xs ${link.tone}`}>{link.label}</span>
    </div>
  );
}

export function DiaryLinksSection({ data }: { data: DiaryInsights }) {
  const chartData = data.weeks.map((w) => ({
    name: fmtDate(w.week_start),
    mood: w.avg_mood,
    tasks: w.avg_task_rate,
    patterns: w.avg_pattern_clean_rate,
  }));
  const hasChart = chartData.some(
    (w) => w.mood != null || w.tasks != null || w.patterns != null,
  );
  const scatterPoints = data.scatter_days
    .filter((d) => d.task_rate != null)
    .map((d) => ({
      mood: d.mood,
      task_rate: d.task_rate as number,
      day: fmtDate(d.day),
    }));

  return (
    <div className="mx-auto w-full min-w-0 max-w-3xl space-y-8">
      {data.insights.length > 0 && (
        <section className="space-y-2">
          <h3 className="font-semibold">Итог за период</h3>
          <ul className="space-y-2 text-sm text-ink">
            {data.insights.map((line, i) => (
              <li key={i} className="rounded-lg border border-border/70 bg-surface-2/50 px-3 py-2">
                {line}
              </li>
            ))}
          </ul>
        </section>
      )}

      <section>
        <h3 className="mb-3 font-semibold">Насколько совпадают показатели</h3>
        <div className="grid grid-cols-2 gap-2">
          <LinkCard title="Настроение и задачи" value={data.corr_mood_tasks} />
          <LinkCard title="Настроение и паттерны" value={data.corr_mood_patterns} />
          <LinkCard title="Энергия и задачи" value={data.corr_energy_tasks} />
          <LinkCard title="Настроение и энергия" value={data.corr_mood_energy} />
        </div>
      </section>

      {data.mood_buckets.length > 0 && (
        <section>
          <h3 className="mb-3 font-semibold">При разном настроении</h3>
          <div className="space-y-2">
            {data.mood_buckets.map((b) => (
              <div
                key={b.bucket}
                className="rounded-md border border-border/70 px-3 py-2 text-sm"
              >
                <div className="font-medium">{b.label}</div>
                <div className="mt-1 text-xs text-ink-muted">
                  {b.days} дн. · задачи{' '}
                  {b.avg_task_rate != null ? pct(b.avg_task_rate) : '—'} · паттерны{' '}
                  {b.avg_pattern_rate != null ? pct(b.avg_pattern_rate) : '—'}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {scatterPoints.length >= 3 && (
        <section>
          <h3 className="mb-3 font-semibold">Настроение и задачи по дням</h3>
          <div className="rounded-lg border border-border bg-surface-2 p-3">
            <ResponsiveContainer width="100%" height={220}>
              <ScatterChart margin={statsChartMargin({ left: 44, bottom: 36, right: 12 })}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis type="number" dataKey="mood" domain={[1, 5]} tickCount={5}>
                  <AxisLabelX value="Настроение (1–5)" />
                </XAxis>
                <YAxis
                  type="number"
                  dataKey="task_rate"
                  domain={[0, 100]}
                  tickFormatter={(v) => `${v}%`}
                  width={40}
                >
                  <AxisLabelYLeft value="% задач" />
                </YAxis>
                <Tooltip
                  cursor={{ strokeDasharray: '3 3' }}
                  formatter={(v: number, name: string) =>
                    name === 'task_rate' ? [pct(v), '% задач'] : [v.toFixed(1), 'настроение']
                  }
                  labelFormatter={(_, payload) =>
                    payload?.[0]?.payload?.day ? String(payload[0].payload.day) : ''
                  }
                />
                <Scatter data={scatterPoints} fill="#16a34a" />
              </ScatterChart>
            </ResponsiveContainer>
          </div>
        </section>
      )}

      {hasChart && (
        <section>
          <h3 className="mb-3 font-semibold">По неделям</h3>
          <StatsWeeklyMiniGrid rows={chartData} series={DIARY_WEEKLY_SERIES} />
        </section>
      )}

      {data.weeks.length > 0 && (
        <section>
          <h3 className="mb-2 font-semibold">Недели подробнее</h3>
          <div className="max-h-64 space-y-2 overflow-y-auto pr-1">
            {[...data.weeks].reverse().slice(0, 12).map((w) => (
              <WeekRow key={w.week_start} week={w} />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
