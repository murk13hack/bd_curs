import { useState } from 'react';
import { Search, X } from 'lucide-react';
import type { DiarySearchHit } from '@/api/types';
import { Spinner } from '@/components/ui/primitives';
import { fmtDate } from '@/lib/format';

export function DiarySearchPanel({
  query,
  onQueryChange,
  hits,
  loading,
  onPickDate,
}: {
  query: string;
  onQueryChange: (q: string) => void;
  hits: DiarySearchHit[];
  loading: boolean;
  onPickDate: (iso: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const active = open || query.trim().length > 0;

  return (
    <div className="mb-4">
      <div className="flex justify-end">
        <button
          type="button"
          className={`btn-ghost gap-2 text-sm ${active ? 'text-accent' : ''}`}
          onClick={() => setOpen((v) => !v)}
          aria-expanded={active}
        >
          {active ? <X size={16} /> : <Search size={16} />}
          {active ? 'Закрыть поиск' : 'Поиск'}
        </button>
      </div>
      {active && (
        <div className="card mt-2">
          <div className="card-body space-y-3">
            <div className="relative">
              <Search
                size={16}
                className="pointer-events-none absolute left-3 top-1/2 z-10 -translate-y-1/2 text-ink-muted"
              />
              <input
                className="input pl-9"
                placeholder="Слова из записей…"
                value={query}
                onChange={(e) => onQueryChange(e.target.value)}
                autoFocus
              />
            </div>
            {query.trim().length >= 2 && (
              <>
                {loading ? (
                  <Spinner />
                ) : hits.length === 0 ? (
                  <p className="text-sm text-ink-muted">Ничего не найдено.</p>
                ) : (
                  <ul className="max-h-64 space-y-2 overflow-y-auto">
                    {hits.map((hit) => (
                      <li key={hit.entry_id}>
                        <button
                          type="button"
                          className="w-full rounded-lg border border-border p-3 text-left transition hover:bg-surface-3"
                          onClick={() => {
                            onPickDate(hit.entry_date);
                            setOpen(false);
                            onQueryChange('');
                          }}
                        >
                          <div className="mb-1 text-xs text-ink-muted">{fmtDate(hit.entry_date)}</div>
                          <div className="text-sm">{hit.snippet.replace(/<<|>>/g, '')}</div>
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </>
            )}
            {query.trim().length > 0 && query.trim().length < 2 && (
              <p className="text-xs text-ink-muted">Введите хотя бы 2 символа</p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
