import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { endOfMonth, parseISO, startOfMonth } from 'date-fns';
import { api } from '@/api/client';
import { DiaryDayNav } from '@/components/diary/diary-day-nav';
import { DiaryEntryCard } from '@/components/diary/diary-entry-card';
import { DiaryMonthCalendar } from '@/components/diary/diary-month-calendar';
import { DiarySearchPanel } from '@/components/diary/diary-search-panel';
import { MoodScalePicker } from '@/components/diary/mood-scale-picker';
import { PageHeader, Spinner, ErrorBanner } from '@/components/ui/primitives';
import { FormField } from '@/components/ui/form-field';
import { toIsoDate } from '@/lib/format';
import { confirmDelete } from '@/lib/confirm';

export function DiaryPage() {
  const qc = useQueryClient();
  const today = toIsoDate(new Date());
  const [selectedDate, setSelectedDate] = useState(today);
  const [monthCursor, setMonthCursor] = useState(() => startOfMonth(new Date()));
  const [searchQ, setSearchQ] = useState('');
  const [content, setContent] = useState('');
  const [mood, setMood] = useState<number | ''>('');
  const [energy, setEnergy] = useState<number | ''>('');
  const [tagIds, setTagIds] = useState<number[]>([]);
  const [error, setError] = useState('');

  const monthFrom = toIsoDate(startOfMonth(monthCursor));
  const monthTo = toIsoDate(endOfMonth(monthCursor));

  const tags = useQuery({ queryKey: ['tags'], queryFn: api.tags.list });
  const monthEntries = useQuery({
    queryKey: ['diary', 'month', monthFrom, monthTo],
    queryFn: () => api.diary.list({ from: monthFrom, to: monthTo }),
  });
  const recentEntries = useQuery({
    queryKey: ['diary', 'recent'],
    queryFn: () => api.diary.list(),
  });
  const current = useQuery({
    queryKey: ['diary-entry', selectedDate],
    queryFn: () => api.diary.byDate(selectedDate),
    retry: false,
  });
  const search = useQuery({
    queryKey: ['diary-search', searchQ],
    queryFn: () => api.diary.search(searchQ),
    enabled: searchQ.trim().length >= 2,
  });

  const entriesByDate = useMemo(
    () => new Map((monthEntries.data ?? []).map((e) => [e.entry_date, e])),
    [monthEntries.data],
  );
  const tagsById = useMemo(
    () => new Map((tags.data ?? []).map((t) => [t.id, t])),
    [tags.data],
  );

  const invalidateDiary = () => {
    qc.invalidateQueries({ queryKey: ['diary'] });
    qc.invalidateQueries({ queryKey: ['diary-entry', selectedDate] });
    qc.invalidateQueries({ queryKey: ['diary', 'month'] });
    qc.invalidateQueries({ queryKey: ['diary', 'recent'] });
  };

  const saveMut = useMutation({
    mutationFn: async () => {
      const body = {
        entry_date: selectedDate,
        content,
        mood: mood || null,
        energy: energy || null,
        tag_ids: tagIds,
      };
      if (current.data) return api.diary.update(current.data.id, body);
      return api.diary.create(body);
    },
    onSuccess: () => {
      invalidateDiary();
      setError('');
    },
    onError: (e: Error) => setError(e.message),
  });

  const deleteMut = useMutation({
    mutationFn: () => api.diary.remove(current.data!.id),
    onSuccess: () => {
      setContent('');
      setMood('');
      setEnergy('');
      setTagIds([]);
      invalidateDiary();
    },
  });

  useEffect(() => {
    if (current.data) {
      setContent(current.data.content);
      setMood(current.data.mood ?? '');
      setEnergy(current.data.energy ?? '');
      setTagIds(current.data.tag_ids ?? []);
    } else if (!current.isLoading && current.isError) {
      setContent('');
      setMood('');
      setEnergy('');
      setTagIds([]);
    }
  }, [current.data, current.isLoading, current.isError, selectedDate]);

  const pickDate = (iso: string) => {
    setSelectedDate(iso);
    setMonthCursor(startOfMonth(parseISO(iso.slice(0, 10))));
  };

  const toggleTag = (id: number) => {
    setTagIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };

  return (
    <div>
      <PageHeader title="Дневник" subtitle="Записи по дням и настроение" />

      <DiarySearchPanel
        query={searchQ}
        onQueryChange={setSearchQ}
        hits={search.data ?? []}
        loading={search.isLoading}
        onPickDate={pickDate}
      />

      <div className="grid gap-6 lg:grid-cols-[minmax(0,17rem)_minmax(0,1fr)]">
        <DiaryMonthCalendar
          monthCursor={monthCursor}
          onMonthChange={setMonthCursor}
          entriesByDate={entriesByDate}
          selectedDate={selectedDate}
          onSelectDate={pickDate}
          loading={monthEntries.isLoading}
        />

        <section className="card min-w-0">
          <div className="card-body space-y-4">
            <DiaryDayNav selectedDate={selectedDate} onDateChange={pickDate} />

            {error && <ErrorBanner message={error} />}
            {current.isLoading ? (
              <Spinner />
            ) : (
              <>
                <div className="grid gap-4 sm:grid-cols-2">
                  <MoodScalePicker kind="mood" label="Настроение" value={mood} onChange={setMood} />
                  <MoodScalePicker
                    kind="energy"
                    label="Энергия"
                    value={energy}
                    onChange={setEnergy}
                  />
                </div>

                <FormField label="Запись">
                  <textarea
                    className="input min-h-52 resize-y text-base leading-relaxed"
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    placeholder="Как прошёл ваш день?"
                  />
                </FormField>

                {(tags.data ?? []).length > 0 && (
                  <FormField label="Теги">
                    <div className="flex flex-wrap gap-2">
                      {(tags.data ?? []).map((tag) => {
                        const on = tagIds.includes(tag.id);
                        return (
                          <button
                            key={tag.id}
                            type="button"
                            className={`rounded-full border px-3 py-1 text-sm transition ${
                              on
                                ? 'border-accent bg-accent-soft text-ink'
                                : 'border-border bg-surface-2 text-ink-muted hover:border-accent/50'
                            }`}
                            onClick={() => toggleTag(tag.id)}
                            aria-pressed={on}
                          >
                            {tag.name}
                          </button>
                        );
                      })}
                    </div>
                  </FormField>
                )}

                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    className="btn-primary"
                    disabled={!content.trim() || saveMut.isPending}
                    onClick={() => saveMut.mutate()}
                  >
                    Сохранить
                  </button>
                  {current.data && (
                    <button
                      type="button"
                      className="btn-danger"
                      disabled={deleteMut.isPending}
                      onClick={() => {
                        if (confirmDelete('запись дневника')) deleteMut.mutate();
                      }}
                    >
                      Удалить
                    </button>
                  )}
                </div>
              </>
            )}
          </div>
        </section>
      </div>

      <section className="mt-8">
        <h2 className="mb-3 text-base font-semibold">Недавние записи</h2>
        {recentEntries.isLoading ? (
          <Spinner />
        ) : (recentEntries.data ?? []).length === 0 ? (
          <p className="text-sm text-ink-muted">Пока нет записей — начните с сегодняшнего дня.</p>
        ) : (
          <ul className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {(recentEntries.data ?? []).map((e) => (
              <li key={e.id}>
                <DiaryEntryCard
                  entry={e}
                  tagsById={tagsById}
                  selected={e.entry_date === selectedDate}
                  onSelect={() => pickDate(e.entry_date)}
                />
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
