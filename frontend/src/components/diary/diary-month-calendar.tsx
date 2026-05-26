import { useMemo } from 'react';
import {
  addMonths,
  eachDayOfInterval,
  endOfMonth,
  format,
  getDay,
  isToday,
  startOfMonth,
  subMonths,
} from 'date-fns';
import { ru } from 'date-fns/locale';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import type { DiaryEntry } from '@/api/types';
import { toIsoDate } from '@/lib/format';
import { energyEmoji, MOOD_LEVEL_COLOR, moodEmoji } from '@/lib/labels';

export function DiaryMonthCalendar({
  monthCursor,
  onMonthChange,
  entriesByDate,
  selectedDate,
  onSelectDate,
  loading,
}: {
  monthCursor: Date;
  onMonthChange: (d: Date) => void;
  entriesByDate: Map<string, DiaryEntry>;
  selectedDate: string;
  onSelectDate: (iso: string) => void;
  loading?: boolean;
}) {
  const start = startOfMonth(monthCursor);
  const end = endOfMonth(monthCursor);
  const days = eachDayOfInterval({ start, end });
  const pad = (getDay(start) + 6) % 7;

  const title = useMemo(
    () => format(monthCursor, 'LLLL yyyy', { locale: ru }),
    [monthCursor],
  );

  return (
    <div className="card h-fit">
      <div className="card-body">
        <div className="mb-3 flex items-center justify-between gap-2">
          <button
            type="button"
            className="btn-ghost p-2"
            aria-label="Предыдущий месяц"
            onClick={() => onMonthChange(subMonths(monthCursor, 1))}
          >
            <ChevronLeft size={18} />
          </button>
          <h2 className="text-center text-sm font-semibold capitalize">{title}</h2>
          <button
            type="button"
            className="btn-ghost p-2"
            aria-label="Следующий месяц"
            onClick={() => onMonthChange(addMonths(monthCursor, 1))}
          >
            <ChevronRight size={18} />
          </button>
        </div>

        <div className="mb-1 grid grid-cols-7 gap-1 text-center text-[10px] font-medium text-ink-muted">
          {['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((d) => (
            <div key={d}>{d}</div>
          ))}
        </div>

        <div
          className={`grid grid-cols-7 gap-1 ${loading ? 'pointer-events-none opacity-60' : ''}`}
          aria-busy={loading}
        >
          {Array.from({ length: pad }).map((_, i) => (
            <div key={`pad-${i}`} className="aspect-square" />
          ))}
          {days.map((d) => {
            const key = toIsoDate(d);
            const entry = entriesByDate.get(key);
            const selected = key === selectedDate;
            const today = isToday(d);
            const mood = entry?.mood;
            const accent = mood != null && mood >= 1 && mood <= 5 ? MOOD_LEVEL_COLOR[mood] : null;
            return (
              <button
                key={key}
                type="button"
                onClick={() => onSelectDate(key)}
                className={`relative flex aspect-square flex-col items-center justify-center rounded-lg border text-xs transition ${
                  selected
                    ? 'border-accent ring-2 ring-accent/30'
                    : 'border-transparent hover:border-border hover:bg-surface-3'
                } ${today && !selected ? 'font-bold' : ''}`}
                style={
                  accent
                    ? { backgroundColor: `${accent}28` }
                    : entry
                      ? { backgroundColor: 'var(--surface-3)' }
                      : undefined
                }
                aria-label={format(d, 'd MMMM', { locale: ru })}
                aria-pressed={selected}
              >
                <span className={today ? 'text-accent' : ''}>{format(d, 'd')}</span>
                {entry && (
                  <span className="mt-0.5 text-sm leading-none" aria-hidden>
                    {moodEmoji(entry.mood) || energyEmoji(entry.energy) || '✎'}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        <p className="mt-3 text-[10px] text-ink-muted">Нажмите день, чтобы открыть запись.</p>
      </div>
    </div>
  );
}
