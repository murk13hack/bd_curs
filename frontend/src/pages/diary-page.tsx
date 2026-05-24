import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Search } from 'lucide-react';
import { api } from '@/api/client';
import { PageHeader, Spinner, ErrorBanner } from '@/components/ui/primitives';
import { fmtDate, toIsoDate } from '@/lib/format';
import { ENERGY_EMOJI, MOOD_EMOJI } from '@/lib/labels';
import { confirmDelete } from '@/lib/confirm';
export function DiaryPage() {
  const qc = useQueryClient();
  const today = toIsoDate(new Date());
  const [selectedDate, setSelectedDate] = useState(today);
  const [searchQ, setSearchQ] = useState('');
  const [content, setContent] = useState('');
  const [mood, setMood] = useState<number | ''>('');
  const [energy, setEnergy] = useState<number | ''>('');
  const [tagIds, setTagIds] = useState<number[]>([]);
  const [error, setError] = useState('');

  const tags = useQuery({ queryKey: ['tags'], queryFn: api.tags.list });
  const entries = useQuery({
    queryKey: ['diary'],
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

  const saveMut = useMutation({
    mutationFn: async () => {
      const body = {
        entry_date: selectedDate,
        content,
        mood: mood || null,
        energy: energy || null,
        tag_ids: tagIds,
      };      if (current.data) return api.diary.update(current.data.id, body);
      return api.diary.create(body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['diary'] });
      qc.invalidateQueries({ queryKey: ['diary-entry', selectedDate] });
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
      qc.invalidateQueries({ queryKey: ['diary'] });
      qc.invalidateQueries({ queryKey: ['diary-entry', selectedDate] });
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
      setTagIds([]);    }
  }, [current.data, current.isLoading, current.isError, selectedDate]);

  return (
    <div>
      <PageHeader title="Дневник" subtitle="Записи, настроение и полнотекстовый поиск" />

      <div className="mb-4 flex flex-wrap gap-2">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-muted" />
          <input
            className="input pl-9"
            placeholder="Поиск по записям (FTS)…"
            value={searchQ}
            onChange={(e) => setSearchQ(e.target.value)}
          />
        </div>
        <input
          type="date"
          className="input w-auto"
          value={selectedDate}
          onChange={(e) => {
            setSelectedDate(e.target.value);
            setContent('');
            setMood('');
            setEnergy('');
            setTagIds([]);
          }}        />
      </div>

      {searchQ.trim().length >= 2 && (
        <section className="card mb-6">
          <div className="card-body">
            <h2 className="mb-3 font-semibold">Результаты поиска</h2>
            {search.isLoading ? (
              <Spinner />
            ) : (search.data ?? []).length === 0 ? (
              <p className="text-sm text-ink-muted">Ничего не найдено.</p>
            ) : (
              <ul className="space-y-3">
                {(search.data ?? []).map((hit) => (
                  <li key={hit.entry_id} className="rounded-lg border border-border p-3">
                    <div className="mb-1 text-xs text-ink-muted">{fmtDate(hit.entry_date)}</div>
                    <div
                      className="text-sm"
                      dangerouslySetInnerHTML={{ __html: hit.snippet.replace(/<<|>>/g, '') }}
                    />
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      )}

      <div className="grid gap-6 lg:grid-cols-3">
        <section className="card lg:col-span-2">
          <div className="card-body space-y-4">
            <h2 className="font-semibold">Запись на {fmtDate(selectedDate)}</h2>
            {error && <ErrorBanner message={error} />}
            {current.isLoading ? (
              <Spinner />
            ) : (
              <>
                <textarea
                  className="input min-h-48"
                  placeholder="Как прошёл день?"
                  value={content}
                  onChange={(e) => setContent(e.target.value)}
                />
                <div className="grid gap-4 sm:grid-cols-2">
                  <MoodPicker label="Настроение" value={mood} onChange={setMood} emojis={MOOD_EMOJI} />
                  <MoodPicker label="Энергия" value={energy} onChange={setEnergy} emojis={ENERGY_EMOJI} />
                </div>
                {(tags.data ?? []).length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {(tags.data ?? []).map((tag) => (
                      <label key={tag.id} className="flex items-center gap-1 text-sm">
                        <input
                          type="checkbox"
                          checked={tagIds.includes(tag.id)}
                          onChange={(e) =>
                            setTagIds((prev) =>
                              e.target.checked
                                ? [...prev, tag.id]
                                : prev.filter((id) => id !== tag.id),
                            )
                          }
                        />
                        {tag.name}
                      </label>
                    ))}
                  </div>
                )}
                <div className="flex gap-2">                  <button
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
                      }}                    >
                      Удалить
                    </button>
                  )}
                </div>
              </>
            )}
          </div>
        </section>

        <section className="card">
          <div className="card-body">
            <h2 className="mb-3 font-semibold">Лента</h2>
            {entries.isLoading ? (
              <Spinner />
            ) : (
              <ul className="max-h-[32rem] space-y-2 overflow-auto">
                {(entries.data ?? []).map((e) => (
                  <li key={e.id}>
                    <button
                      type="button"
                      className={`w-full rounded-lg border px-3 py-2 text-left text-sm transition ${
                        e.entry_date === selectedDate
                          ? 'border-accent bg-accent-soft'
                          : 'border-border hover:bg-surface-3'
                      }`}
                      onClick={() => setSelectedDate(e.entry_date)}
                    >
                      <div className="font-medium">{fmtDate(e.entry_date)}</div>
                      <div className="line-clamp-2 text-ink-muted">{e.content}</div>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

function MoodPicker({
  label,
  value,
  onChange,
  emojis,
}: {
  label: string;
  value: number | '';
  onChange: (v: number | '') => void;
  emojis: string[];
}) {
  return (
    <div>
      <div className="mb-2 text-sm font-medium">{label}</div>
      <div className="flex gap-1">
        {[1, 2, 3, 4, 5].map((n) => (
          <button
            key={n}
            type="button"
            className={`flex h-10 w-10 items-center justify-center rounded-lg border text-lg ${
              value === n ? 'border-accent bg-accent-soft' : 'border-border'
            }`}
            onClick={() => onChange(value === n ? '' : n)}
            title={`${n}/5`}
          >
            {emojis[n]}
          </button>
        ))}
      </div>
    </div>
  );
}
