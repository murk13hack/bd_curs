import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { BarChart3, Clock, MapPin, Plus, Trash2 } from 'lucide-react';
import { api } from '@/api/client';
import type { Pattern, PatternMarker, PatternStreak } from '@/api/types';
import { MarkerEpisodeModal } from '@/components/patterns/marker-episode-modal';
import { PatternDayStrip } from '@/components/patterns/pattern-day-strip';
import { formatScheduleTimes, markersRateHint, rateLabel, streakLabel, todayTone } from '@/lib/pattern-templates';
import { PATTERN_TYPE_LABEL } from '@/lib/labels';

type Props = {
  pattern: Pattern;
  streak?: PatternStreak;
  onPicture: () => void;
  headerActions: React.ReactNode;
};

export function MarkersJournalCard({
  pattern,
  streak,
  onPicture,
  headerActions,
}: Props) {
  const qc = useQueryClient();
  const [episodeOpen, setEpisodeOpen] = useState(false);
  const [episodeError, setEpisodeError] = useState('');
  const [cleanDayError, setCleanDayError] = useState('');

  const today = useQuery({
    queryKey: ['pattern-today', pattern.id],
    queryFn: () => api.patterns.today(pattern.id),
  });
  const markers = useQuery({
    queryKey: ['pattern-markers', pattern.id],
    queryFn: () => api.patterns.markers(pattern.id, 40),
  });
  const mini = useQuery({
    queryKey: ['pattern-insights', pattern.id, 7],
    queryFn: () => api.patterns.insights(pattern.id, 7),
    staleTime: 30_000,
  });

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['pattern-today', pattern.id] });
    qc.invalidateQueries({ queryKey: ['pattern-markers', pattern.id] });
    qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
    qc.invalidateQueries({ queryKey: ['pattern-insights', pattern.id] });
  };

  const addMut = useMutation({
    mutationFn: ({ optionId, note }: { optionId: number; note: string }) =>
      api.patterns.addMarker(pattern.id, {
        marker_option_id: optionId,
        note: note || undefined,
      }),
    onSuccess: () => {
      invalidate();
      qc.invalidateQueries({ queryKey: ['patterns'] });
      qc.invalidateQueries({ queryKey: ['pattern', pattern.id] });
      setEpisodeOpen(false);
      setEpisodeError('');
    },
    onError: (e: Error) => setEpisodeError(e.message),
  });

  const patternLive = useQuery({
    queryKey: ['pattern', pattern.id],
    queryFn: () => api.patterns.get(pattern.id),
    staleTime: 5_000,
  });
  const activePattern = patternLive.data ?? pattern;

  const removeMut = useMutation({
    mutationFn: (markerId: number) => api.patterns.removeMarker(pattern.id, markerId),
    onSuccess: invalidate,
  });

  const cleanDayMut = useMutation({
    mutationFn: () => api.patterns.declareCleanDay(pattern.id),
    onSuccess: () => {
      invalidate();
      setCleanDayError('');
    },
    onError: (e: Error) => setCleanDayError(e.message),
  });

  const undoCleanMut = useMutation({
    mutationFn: () => api.patterns.undeclareCleanDay(pattern.id),
    onSuccess: () => {
      invalidate();
      setCleanDayError('');
    },
    onError: (e: Error) => setCleanDayError(e.message),
  });

  const t = today.data;
  const tone = todayTone(t?.is_success_today ?? null, t?.status);
  const todayMarkers = (markers.data ?? []).filter(
    (m) => m.occurred_at.slice(0, 10) === t?.day,
  );
  const scheduled = t?.is_scheduled_today !== false;
  const hasBad = todayMarkers.some((m) => !m.is_success);
  const canAddEpisode = scheduled && !t?.day_declared_clean;
  const canDeclareClean =
    scheduled && todayMarkers.length === 0 && !t?.day_declared_clean;
  const hourStats = mini.data?.hourly_counts ?? [];
  const maxHour = Math.max(...hourStats.map((h) => h.count), 1);

  return (
    <>
      <article className="card border-l-4 border-l-indigo-500/80">
        <div className="card-body space-y-3">
          <div className="flex items-start justify-between gap-2">
            <div>
              <span className="mb-1 inline-block rounded-full bg-indigo-500/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-indigo-800 dark:text-indigo-200">
                Журнал эпизодов
              </span>
              <h3 className="flex items-center gap-2 font-semibold">
                <MapPin size={18} className="shrink-0 text-indigo-500" />
                {pattern.title}
              </h3>
              <p className="text-xs text-ink-muted">
                Точки · {PATTERN_TYPE_LABEL[pattern.pattern_type]}
              </p>
            </div>
            <div className="flex gap-1">{headerActions}</div>
          </div>

          {streak && (
            <div
              className={`rounded-lg border px-3 py-2 text-sm ${
                tone === 'good'
                  ? 'bg-emerald-500/10 border-emerald-500/30'
                  : tone === 'bad'
                    ? 'bg-red-500/10 border-red-500/30'
                    : 'bg-indigo-500/10 border-indigo-500/30'
              }`}
            >
              <div
                className={`flex items-center gap-2 font-semibold ${
                  tone === 'good'
                    ? 'text-emerald-600'
                    : tone === 'bad'
                      ? 'text-red-600'
                      : 'text-indigo-600'
                }`}
              >
                <MapPin size={16} />
                {streak.current_streak}{' '}
                <span className="font-normal text-ink-muted">
                  {streakLabel(pattern.pattern_type, pattern.pattern_mode)}
                </span>
              </div>
              <div className="mt-1 text-xs text-ink-muted">
                за 30 д {rateLabel(streak.scheduled_days_30d, streak.success_days_30d)}
                <span className="mt-0.5 block text-[11px] leading-snug opacity-90">
                  {markersRateHint(pattern.pattern_type)}. В календаре:{' '}
                  <span className="text-red-600">тёмно-красный</span> — негативный эпизод,{' '}
                  <span className="text-red-400">светлый</span> — день без отметок.
                </span>
              </div>
            </div>
          )}

          <div className="rounded-lg border border-indigo-500/20 bg-indigo-500/5 px-3 py-3 text-sm">
            <p className="mb-2 text-xs text-ink-muted">
              Отмечайте эпизоды по мере появления — не один итог, а лента за день.
            </p>
            {!scheduled ? (
              <p className="text-ink-muted">По расписанию сегодня не активно</p>
            ) : t?.day_declared_clean ? (
              <p className="text-emerald-600">День закрыт: эпизодов не было</p>
            ) : hasBad ? (
              <p className="text-red-600">Были негативные эпизоды</p>
            ) : todayMarkers.length > 0 ? (
              <p className="text-emerald-600">
                {todayMarkers.length} эпизод(ов), без негативных
              </p>
            ) : (
              <p className="text-ink-muted">Эпизодов пока нет — день открыт</p>
            )}

            {cleanDayError && (
              <p className="mb-2 text-xs text-red-600" role="alert">
                {cleanDayError}
              </p>
            )}
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                type="button"
                className="btn-primary text-sm"
                disabled={!canAddEpisode || addMut.isPending}
                onClick={() => setEpisodeOpen(true)}
              >
                <Plus size={16} /> Эпизод
              </button>
              {canDeclareClean && (
                <button
                  type="button"
                  className="btn-secondary text-sm"
                  disabled={cleanDayMut.isPending}
                  onClick={() => cleanDayMut.mutate()}
                >
                  День без эпизодов
                </button>
              )}
              {t?.day_declared_clean && !hasBad && todayMarkers.length === 0 && (
                <button
                  type="button"
                  className="btn-ghost text-xs"
                  disabled={undoCleanMut.isPending}
                  onClick={() => undoCleanMut.mutate()}
                >
                  Отменить закрытие
                </button>
              )}
            </div>
          </div>

          {todayMarkers.length > 0 && (
            <div className="space-y-1">
              <p className="text-xs font-medium text-ink-muted flex items-center gap-1">
                <Clock size={12} /> Лента сегодня
              </p>
              <ul className="max-h-40 space-y-1 overflow-y-auto border-l-2 border-indigo-500/30 pl-3">
                {[...todayMarkers]
                  .sort((a, b) => a.occurred_at.localeCompare(b.occurred_at))
                  .map((m) => (
                    <TimelineRow
                      key={m.id}
                      marker={m}
                      onRemove={() => removeMut.mutate(m.id)}
                      removing={removeMut.isPending}
                    />
                  ))}
              </ul>
            </div>
          )}

          {hourStats.some((h) => h.count > 0) && (
            <div>
              <p className="mb-1 text-xs font-medium text-ink-muted">Активность по часам (7 д)</p>
              <div className="flex h-10 items-end gap-px rounded bg-surface-3/80 p-1">
                {hourStats.map((h) => (
                  <div
                    key={h.hour}
                    title={`${h.hour}:00 — ${h.count} (${h.bad_count} негат.)`}
                    className="flex-1 rounded-t min-w-0"
                    style={{
                      height: `${Math.max(8, (h.count / maxHour) * 100)}%`,
                      backgroundColor: h.bad_count > 0 ? '#f87171' : '#818cf8',
                    }}
                  />
                ))}
              </div>
            </div>
          )}

          <p className="text-xs text-ink-muted">
            Напоминания: {formatScheduleTimes(pattern.schedules)}
          </p>

          {mini.data && <PatternDayStrip days={mini.data.calendar} compact />}

          <button type="button" className="btn-secondary w-full text-xs" onClick={onPicture}>
            <BarChart3 size={14} /> Картина и разрезы
          </button>
        </div>
      </article>

      <MarkerEpisodeModal
        pattern={activePattern}
        open={episodeOpen}
        onClose={() => setEpisodeOpen(false)}
        pending={addMut.isPending}
        error={episodeError}
        onSubmit={(optionId, note) => addMut.mutate({ optionId, note })}
      />
    </>
  );
}

function TimelineRow({
  marker,
  onRemove,
  removing,
}: {
  marker: PatternMarker;
  onRemove: () => void;
  removing: boolean;
}) {
  const time = marker.occurred_at.slice(11, 16);
  return (
    <li
      className={`flex items-start justify-between gap-2 rounded-md px-2 py-1.5 text-xs ${
        marker.is_success ? 'bg-emerald-500/10' : 'bg-red-500/10'
      }`}
    >
      <div>
        <span className="font-mono text-ink-muted">{time}</span>
        <span className="mx-1">·</span>
        <span className="font-medium">{marker.label}</span>
        {marker.note && <p className="mt-0.5 text-ink-muted">{marker.note}</p>}
      </div>
      <button
        type="button"
        className="btn-ghost shrink-0 px-1"
        disabled={removing}
        onClick={onRemove}
        title="Удалить эпизод"
      >
        <Trash2 size={12} />
      </button>
    </li>
  );
}
