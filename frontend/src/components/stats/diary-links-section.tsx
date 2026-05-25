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
  ChartCaption,
  statsChartMargin,
} from '@/components/stats/stats-chart-labels';
import { fmtDate, pct } from '@/lib/format';

function corrLabel(r: number | null): { text: string; hint: string; tone: string } {
  if (r == null) return { text: '—', hint: 'мало дней или нет разброса', tone: 'text-ink-muted' };
  const abs = Math.abs(r);
  const hint =
    abs >= 0.45
      ? r > 0
        ? 'сильнее вместе'
        : 'сильнее в обратную сторону'
      : abs >= 0.2
        ? 'слабая связь'
        : 'почти нет связи';
  return { text: r.toFixed(2), hint, tone: abs >= 0.35 ? 'text-accent font-medium' : 'text-ink' };
}

function CorrCard({
  title,
  value,
  subtitle,
}: {
  title: string;
  value: number | null;
  subtitle: string;
}) {
  const c = corrLabel(value);
  return (
    <div className="rounded-lg border border-border bg-surface-2 px-3 py-2.5">
      <div className="text-[11px] text-ink-muted">{title}</div>
      <div className={`text-lg tabular-nums ${c.tone}`}>{c.text}</div>
      <div className="text-[10px] text-ink-muted">{c.hint}</div>
      <div className="mt-0.5 text-[10px] text-ink-muted/80">{subtitle}</div>
    </div>
  );
}

function WeekCorrRow({
  week,
}: {
  week: DiaryInsights['weeks'][0];
}) {
  const moodTasks = corrLabel(week.corr_mood_tasks);
  return (
    <div className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-border/70 px-3 py-2 text-sm">
      <span className="font-medium">{fmtDate(week.week_start)}</span>
      <span className="text-xs text-ink-muted">{week.days_count} дн. дневника</span>
      <span className="text-xs">
        настр. {week.avg_mood?.toFixed(1) ?? '—'} · задачи{' '}
        {week.avg_task_rate != null ? pct(week.avg_task_rate) : '—'}
      </span>
      <span className={`text-xs tabular-nums ${moodTasks.tone}`}>
        r(настр.→задачи) {moodTasks.text}
      </span>
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
    <div className="mx-auto w-full min-w-0 max-w-3xl space-y-6">
      <header className="space-y-1 border-b border-border pb-4">
        <h2 className="text-lg font-semibold">Связи: дневник ↔ задачи ↔ паттерны</h2>
        <p className="text-sm text-ink-muted">
          Анализ за выбранный период. Привязки задач и привычек к целям смотрите в разделе «Цели» — здесь
          другая логика: совпадают ли дни с хорошим настроением и продуктивностью.
        </p>
      </header>

      <div className="rounded-lg border border-accent/30 bg-accent/5 px-4 py-3 text-sm text-ink-muted">
        <p>
          <strong className="text-ink">Что такое «связь» здесь:</strong> коэффициент Пирсона (r) между
          показателями по <strong className="text-ink">дням с записью в дневнике</strong> (
          {data.diary_days} дн.). r от −1 до 1 — насколько показатели двигаются вместе.
        </p>
      </div>

      {data.insights.length > 0 && (
        <section className="space-y-2">
          <h3 className="text-sm font-semibold">Выводы за период</h3>
          <ul className="list-disc space-y-1.5 pl-5 text-sm text-ink">
            {data.insights.map((line, i) => (
              <li key={i}>{line}</li>
            ))}
          </ul>
        </section>
      )}

      <section>
        <h3 className="mb-2 text-sm font-semibold">Корреляции за весь период (Пирсон)</h3>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-2">
          <CorrCard
            title="Настроение → задачи"
            value={data.corr_mood_tasks}
            subtitle="% выполненных в день"
          />
          <CorrCard
            title="Настроение → паттерны"
            value={data.corr_mood_patterns}
            subtitle="% чистых дней"
          />
          <CorrCard
            title="Энергия → задачи"
            value={data.corr_energy_tasks}
            subtitle="% выполненных в день"
          />
          <CorrCard
            title="Настроение ↔ энергия"
            value={data.corr_mood_energy}
            subtitle="в одни и те же дни"
          />
        </div>
      </section>

      {data.mood_buckets.length > 0 && (
        <section>
          <h3 className="mb-2 text-sm font-semibold">Средние по уровню настроения</h3>
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
          <ChartCaption>
            Сравнение «при плохом / среднем / хорошем настроении» нагляднее одной цифры r: видно,
            меняется ли % задач и паттернов.
          </ChartCaption>
        </section>
      )}

      {scatterPoints.length >= 3 && (
        <section>
          <h3 className="mb-2 text-sm font-semibold">Дни: настроение и % задач</h3>
          <div className="rounded-lg border border-border bg-surface-2 p-3">
            <ResponsiveContainer width="100%" height={220}>
              <ScatterChart margin={statsChartMargin({ left: 44, bottom: 36, right: 12 })}>
                <CartesianGrid strokeDasharray="3 3" opacity={0.2} />
                <XAxis
                  type="number"
                  dataKey="mood"
                  domain={[1, 5]}
                  tickCount={5}
                  name="Настроение"
                >
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
          <ChartCaption>
            Каждая точка — один день с дневником и хотя бы одной задачей с дедлайном. Облако вверх
            вправо = при лучшем настроении чаще выше % выполнения.
          </ChartCaption>
        </section>
      )}

      {hasChart && (
        <section>
          <h3 className="mb-3 text-sm font-semibold">Динамика по неделям</h3>
          <StatsWeeklyMiniGrid rows={chartData} series={DIARY_WEEKLY_SERIES} />
        </section>
      )}

      {data.weeks.length > 0 && (
        <section>
          <h3 className="mb-2 text-sm font-semibold">По неделям (детализация)</h3>
          <div className="max-h-64 space-y-2 overflow-y-auto pr-1">
            {[...data.weeks].reverse().slice(0, 12).map((w) => (
              <WeekCorrRow key={w.week_start} week={w} />
            ))}
          </div>
          <ChartCaption>
            r по неделе — только дни с дневником внутри этой недели; нужно ≥3 таких дней, иначе
            будет «—».
          </ChartCaption>
        </section>
      )}
    </div>
  );
}
