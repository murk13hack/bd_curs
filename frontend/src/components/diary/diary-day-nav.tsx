import { addDays, format, parseISO } from 'date-fns';
import { ru } from 'date-fns/locale';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { toIsoDate } from '@/lib/format';

export function DiaryDayNav({
  selectedDate,
  onDateChange,
}: {
  selectedDate: string;
  onDateChange: (iso: string) => void;
}) {
  const today = toIsoDate(new Date());
  const isToday = selectedDate === today;
  const d = parseISO(selectedDate.slice(0, 10));

  const shift = (delta: number) => onDateChange(toIsoDate(addDays(d, delta)));

  return (
    <div className="flex flex-wrap items-center gap-2">
      <button
        type="button"
        className={`btn-secondary text-sm ${isToday ? 'opacity-60' : ''}`}
        disabled={isToday}
        onClick={() => onDateChange(today)}
      >
        Сегодня
      </button>
      <div className="flex min-w-0 flex-1 items-center justify-center gap-1 sm:justify-start">
        <button
          type="button"
          className="btn-ghost shrink-0 p-2"
          aria-label="Предыдущий день"
          onClick={() => shift(-1)}
        >
          <ChevronLeft size={20} />
        </button>
        <time
          dateTime={selectedDate}
          className="min-w-[10rem] text-center text-base font-semibold capitalize sm:text-left"
        >
          {format(d, 'd MMMM yyyy', { locale: ru })}
          {isToday && (
            <span className="ml-2 text-sm font-normal text-accent">· сегодня</span>
          )}
        </time>
        <button
          type="button"
          className="btn-ghost shrink-0 p-2"
          aria-label="Следующий день"
          onClick={() => shift(1)}
        >
          <ChevronRight size={20} />
        </button>
      </div>
      <input
        type="date"
        className="input w-auto shrink-0 text-sm"
        value={selectedDate}
        onChange={(e) => e.target.value && onDateChange(e.target.value)}
        aria-label="Выбрать дату"
      />
    </div>
  );
}
