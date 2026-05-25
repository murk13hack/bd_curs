import { useMemo } from 'react';
import { addDays, format, parseISO, startOfWeek } from 'date-fns';
import { ru } from 'date-fns/locale';

type Point = { day: string; activity: number };

const DOW = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

export function StatsHeatmapGrid({ points }: { points: Point[] }) {
  const { weeks, max } = useMemo(() => {
    if (!points.length) return { weeks: [] as Point[][], max: 1 };
    const map = new Map(points.map((p) => [p.day, p.activity]));
    const sorted = [...points].sort((a, b) => a.day.localeCompare(b.day));
    const start = parseISO(sorted[0].day);
    const end = parseISO(sorted[sorted.length - 1].day);
    const gridStart = startOfWeek(start, { weekStartsOn: 1 });
    const cells: Point[] = [];
    for (let d = gridStart; d <= end; d = addDays(d, 1)) {
      const key = format(d, 'yyyy-MM-dd');
      cells.push({ day: key, activity: map.get(key) ?? 0 });
    }
    const maxAct = Math.max(1, ...cells.map((c) => c.activity));
    const rows: Point[][] = [];
    for (let i = 0; i < cells.length; i += 7) {
      rows.push(cells.slice(i, i + 7));
    }
    return { weeks: rows, max: maxAct };
  }, [points]);

  if (!points.length) {
    return (
      <p className="text-sm text-ink-muted py-8 text-center">
        Нет активности за выбранный период.
      </p>
    );
  }

  return (
    <div className="overflow-x-auto">
      <div className="inline-flex flex-col gap-1">
        <div className="grid grid-cols-7 gap-1 text-[10px] text-ink-muted pl-8">
          {DOW.map((d) => (
            <span key={d} className="w-4 text-center">
              {d}
            </span>
          ))}
        </div>
        {weeks.map((row, wi) => (
          <div key={wi} className="flex items-center gap-1">
            <span className="w-7 shrink-0 text-[10px] text-ink-muted">
              {row[0] ? format(parseISO(row[0].day), 'd MMM', { locale: ru }) : ''}
            </span>
            <div className="grid grid-cols-7 gap-1">
              {row.map((cell) => (
                <div
                  key={cell.day}
                  title={`${cell.day}: ${cell.activity}`}
                  className="h-4 w-4 rounded-sm border border-border/50"
                  style={{
                    backgroundColor: `rgba(22, 163, 74, ${
                      cell.activity === 0 ? 0.06 : 0.12 + (0.88 * cell.activity) / max
                    })`,
                  }}
                />
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
