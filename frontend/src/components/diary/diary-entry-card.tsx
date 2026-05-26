import type { DiaryEntry, Tag } from '@/api/types';
import { fmtDate, toIsoDate } from '@/lib/format';
import { energyEmoji, moodEmoji } from '@/lib/labels';

function previewText(content: string, max = 120): string {
  const t = content.trim().replace(/\s+/g, ' ');
  if (!t) return 'Без текста';
  return t.length > max ? `${t.slice(0, max)}…` : t;
}

export function DiaryEntryCard({
  entry,
  tagsById,
  selected,
  onSelect,
}: {
  entry: DiaryEntry;
  tagsById: Map<number, Tag>;
  selected: boolean;
  onSelect: () => void;
}) {
  const isToday = entry.entry_date === toIsoDate(new Date());
  const mood = moodEmoji(entry.mood);
  const energy = energyEmoji(entry.energy);
  const entryTags = (entry.tag_ids ?? [])
    .map((id) => tagsById.get(id))
    .filter((t): t is Tag => Boolean(t));

  return (
    <button
      type="button"
      onClick={onSelect}
      className={`w-full rounded-xl border px-3 py-2.5 text-left transition ${
        selected
          ? 'border-accent bg-accent-soft shadow-sm'
          : 'border-border bg-surface hover:border-accent/40 hover:bg-surface-3'
      }`}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-1.5">
            <span className="text-sm font-medium">{fmtDate(entry.entry_date)}</span>
            {isToday && (
              <span className="rounded-full bg-accent/15 px-1.5 py-0.5 text-[10px] font-medium text-accent">
                сегодня
              </span>
            )}
          </div>
        </div>
        {(mood || energy) && (
          <span className="shrink-0 text-lg leading-none" aria-hidden>
            {mood}
            {energy}
          </span>
        )}
      </div>
      <p className="mt-1 line-clamp-2 text-sm text-ink-muted">{previewText(entry.content)}</p>
      {entryTags.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-1">
          {entryTags.slice(0, 4).map((tag) => (
            <span
              key={tag.id}
              className="rounded-full border border-border bg-surface-2 px-2 py-0.5 text-[10px] text-ink-muted"
            >
              {tag.name}
            </span>
          ))}
        </div>
      )}
    </button>
  );
}
