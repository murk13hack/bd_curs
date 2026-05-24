import { X } from 'lucide-react';
import { DOW_LABELS, dowArrayFromMask, dowMaskFromArray } from '@/lib/pattern-templates';

export type ScheduleRow = {
  id?: number;
  time: string;
  dow_mask: number;
};

type Props = {
  rows: ScheduleRow[];
  onChange: (rows: ScheduleRow[]) => void;
};

export function ScheduleEditor({ rows, onChange }: Props) {
  return (
    <div className="space-y-2">
      <p className="text-sm font-medium">Напоминания</p>
      {rows.map((row, i) => {
        const days = dowArrayFromMask(row.dow_mask);
        return (
          <div key={row.id ?? `new-${i}`} className="rounded-lg border border-border p-3 space-y-2">
            <div className="flex gap-2">
              <input
                type="time"
                className="input flex-1"
                value={row.time}
                onChange={(e) => {
                  const next = [...rows];
                  next[i] = { ...next[i], time: e.target.value };
                  onChange(next);
                }}
              />
              <button
                type="button"
                className="btn-ghost px-2"
                onClick={() => onChange(rows.filter((_, j) => j !== i))}
              >
                <X size={16} />
              </button>
            </div>
            <div className="flex flex-wrap gap-1">
              {DOW_LABELS.map((label, di) => (
                <button
                  key={label}
                  type="button"
                  className={`rounded px-2 py-0.5 text-xs ${
                    days[di] ? 'bg-accent text-white' : 'bg-surface-3 text-ink-muted'
                  }`}
                  onClick={() => {
                    const nextDays = [...days];
                    nextDays[di] = !nextDays[di];
                    const next = [...rows];
                    next[i] = { ...next[i], dow_mask: dowMaskFromArray(nextDays) || 127 };
                    onChange(next);
                  }}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
        );
      })}
      <button
        type="button"
        className="btn-secondary text-xs"
        onClick={() => onChange([...rows, { time: '12:00', dow_mask: 127 }])}
      >
        + Напоминание
      </button>
    </div>
  );
}

export function schedulesToApi(rows: ScheduleRow[]) {
  return rows
    .filter((r) => r.time)
    .map((r) => ({
      time_of_day: `${r.time}:00`,
      dow_mask: r.dow_mask || 127,
    }));
}
