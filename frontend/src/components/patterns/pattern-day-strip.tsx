import type { PatternDayCell } from '@/api/types';

const STATUS_CLASS: Record<PatternDayCell['status'], string> = {
  success: 'bg-emerald-500',
  failure: 'bg-red-500',
  missed: 'bg-red-300/60',
  pending: 'bg-amber-400/70',
  in_progress: 'bg-amber-500 ring-2 ring-amber-300',
  not_scheduled: 'bg-surface-3 border border-border',
};

const STATUS_TITLE: Record<PatternDayCell['status'], string> = {
  success: 'Успех',
  failure: 'Срыв',
  missed: 'Пропуск',
  pending: 'Ожидает',
  in_progress: 'В процессе',
  not_scheduled: 'Не по расписанию',
};

type Props = {
  days: PatternDayCell[];
  compact?: boolean;
};

export function PatternDayStrip({ days, compact }: Props) {
  if (!days.length) return null;

  return (
    <div className={compact ? 'space-y-1' : 'space-y-2'}>
      {!compact && <p className="text-xs font-medium text-ink-muted">Последние дни</p>}
      <div className="flex flex-wrap gap-1">
        {days.map((d) => {
          const label = d.day.slice(5).replace('-', '.');
          return (
            <span
              key={d.day}
              title={`${d.day} — ${STATUS_TITLE[d.status]}`}
              className={`inline-block rounded-sm ${compact ? 'h-2.5 w-2.5' : 'h-4 w-4'} ${STATUS_CLASS[d.status]}`}
              aria-label={`${d.day}: ${STATUS_TITLE[d.status]}`}
            >
              {!compact && (
                <span className="sr-only">
                  {label} {STATUS_TITLE[d.status]}
                </span>
              )}
            </span>
          );
        })}
      </div>
    </div>
  );
}

export function PatternCalendarGrid({ days }: { days: PatternDayCell[] }) {
  if (!days.length) return null;

  const weeks: PatternDayCell[][] = [];
  let row: PatternDayCell[] = [];
  const firstDow = new Date(`${days[0].day}T12:00:00`).getDay();
  const pad = firstDow === 0 ? 6 : firstDow - 1;
  for (let i = 0; i < pad; i++) row.push({ day: '', status: 'not_scheduled' });
  for (const cell of days) {
    row.push(cell);
    if (row.length === 7) {
      weeks.push(row);
      row = [];
    }
  }
  if (row.length) {
    while (row.length < 7) row.push({ day: '', status: 'not_scheduled' });
    weeks.push(row);
  }

  return (
    <div className="space-y-2">
      <div className="grid grid-cols-7 gap-1 text-center text-[10px] text-ink-muted">
        {['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((w) => (
          <span key={w}>{w}</span>
        ))}
      </div>
      {weeks.map((week, wi) => (
        <div key={wi} className="grid grid-cols-7 gap-1">
          {week.map((cell, ci) =>
            cell.day ? (
              <div
                key={cell.day}
                title={`${cell.day} — ${STATUS_TITLE[cell.status]}`}
                className={`flex h-8 flex-col items-center justify-center rounded-md text-[10px] ${STATUS_CLASS[cell.status]} ${
                  cell.status === 'not_scheduled' ? 'text-ink-muted' : 'text-white'
                }`}
              >
                {Number(cell.day.slice(8))}
              </div>
            ) : (
              <div key={`empty-${wi}-${ci}`} />
            ),
          )}
        </div>
      ))}
      <div className="flex flex-wrap gap-3 text-xs text-ink-muted">
        {(['success', 'failure', 'missed', 'pending', 'in_progress'] as const).map((s) => (
          <span key={s} className="flex items-center gap-1">
            <span className={`inline-block h-3 w-3 rounded-sm ${STATUS_CLASS[s]}`} />
            {STATUS_TITLE[s]}
          </span>
        ))}
      </div>
    </div>
  );
}
