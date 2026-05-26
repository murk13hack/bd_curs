import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  addMonths,
  eachDayOfInterval,
  endOfMonth,
  format,
  getDay,
  startOfMonth,
  subMonths,
} from 'date-fns';
import { ru } from 'date-fns/locale';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import { api } from '@/api/client';
import type { CalendarDay } from '@/api/types';
import { PageHeader, Spinner, ErrorBanner } from '@/components/ui/primitives';
import { toIsoDate } from '@/lib/format';

export function CalendarPage() {
  const [cursor, setCursor] = useState(new Date());
  const year = cursor.getFullYear();
  const month = cursor.getMonth() + 1;

  const monthData = useQuery({
    queryKey: ['calendar', year, month],
    queryFn: () => api.calendar.month(year, month),
  });

  const heatFrom = `${year}-01-01`;
  const heatTo = `${year}-12-31`;
  const heatmap = useQuery({
    queryKey: ['heatmap', year],
    queryFn: () => api.calendar.heatmap(heatFrom, heatTo),
  });

  const dayMap = useMemo(
    () => new Map((monthData.data ?? []).map((d) => [d.day, d])),
    [monthData.data],
  );

  const heatMax = Math.max(1, ...(heatmap.data ?? []).map((h) => h.activity));

  return (
    <div>
      <PageHeader title="Календарь" subtitle="Прогресс задач, праздники и активность" />

      {(monthData.isError || heatmap.isError) && (
        <div className="mb-4">
          <ErrorBanner message="Не удалось загрузить данные календаря" />
        </div>
      )}

      <div className="mb-6 flex items-center justify-between">
        <button type="button" className="btn-ghost" onClick={() => setCursor(subMonths(cursor, 1))}>
          <ChevronLeft size={18} />
        </button>
        <h2 className="text-lg font-semibold capitalize">
          {format(cursor, 'LLLL yyyy', { locale: ru })}
        </h2>
        <button type="button" className="btn-ghost" onClick={() => setCursor(addMonths(cursor, 1))}>
          <ChevronRight size={18} />
        </button>
      </div>

      {monthData.isLoading ? (
        <Spinner />
      ) : (
        <MonthGrid cursor={cursor} dayMap={dayMap} />
      )}

      <section className="card mt-8">
        <div className="card-body">
          <h2 className="mb-4 font-semibold">Тепловая карта {year}</h2>
          {heatmap.isLoading ? (
            <Spinner />
          ) : (
            <div className="flex flex-wrap gap-1">
              {(heatmap.data ?? []).map((p) => {
                const intensity = p.activity / heatMax;
                return (
                  <div
                    key={p.day}
                    title={`${p.day}: ${p.activity}`}
                    className="h-3 w-3 rounded-sm"
                    style={{
                      backgroundColor: `rgba(34, 197, 94, ${Math.max(0.08, intensity)})`,
                    }}
                  />
                );
              })}
            </div>
          )}
        </div>
      </section>
    </div>
  );
}

function MonthGrid({
  cursor,
  dayMap,
}: {
  cursor: Date;
  dayMap: Map<string, CalendarDay>;
}) {
  const start = startOfMonth(cursor);
  const end = endOfMonth(cursor);
  const days = eachDayOfInterval({ start, end });
  const pad = (getDay(start) + 6) % 7;

  return (
    <div className="card">
      <div className="card-body">
        <div className="mb-2 grid grid-cols-7 gap-2 text-center text-xs font-medium text-ink-muted">
          {['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((d) => (
            <div key={d}>{d}</div>
          ))}
        </div>
        <div className="grid grid-cols-7 gap-2">
          {Array.from({ length: pad }).map((_, i) => (
            <div key={`pad-${i}`} />
          ))}
          {days.map((d) => {
            const key = toIsoDate(d);
            const cell = dayMap.get(key);
            const bg = cell?.color ?? '#e5e7eb';
            return (
              <Link
                key={key}
                to={`/tasks?day=${key}`}
                className="relative flex min-h-[4.5rem] flex-col rounded-lg border border-border p-2 text-left transition hover:ring-2 hover:ring-green-500/30"
                style={{ backgroundColor: `${bg}33` }}
              >
                <div className="text-sm font-semibold">{format(d, 'd')}</div>
                {cell && (
                  <div className="mt-auto text-[10px] text-ink-muted">
                    {cell.done}/{cell.total}
                  </div>
                )}
                {cell?.is_holiday && (
                  <span className="absolute right-1 top-1 h-2 w-2 rounded-full bg-red-500" title={cell.holiday_name ?? ''} />
                )}
                {cell?.has_diary && (
                  <span className="absolute bottom-1 right-1 text-[10px]">📓</span>
                )}
              </Link>
            );
          })}
        </div>
      </div>
    </div>
  );
}
