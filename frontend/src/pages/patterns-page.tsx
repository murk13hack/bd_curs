import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Flame, Plus, Trash2 } from 'lucide-react';
import { api } from '@/api/client';
import type { PatternType } from '@/api/types';
import { PageHeader, Modal, Spinner, EmptyState, ErrorBanner } from '@/components/ui/primitives';
import { PATTERN_TYPE_LABEL } from '@/lib/labels';

export function PatternsPage() {
  const qc = useQueryClient();
  const [showForm, setShowForm] = useState(false);

  const patterns = useQuery({ queryKey: ['patterns'], queryFn: api.patterns.list });
  const streaks = useQuery({ queryKey: ['pattern-streaks'], queryFn: api.patterns.streaksAll });

  const deleteMut = useMutation({
    mutationFn: (id: number) => api.patterns.remove(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['patterns'] });
      qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
    },
  });

  const respondMut = useMutation({
    mutationFn: ({ id, optionId }: { id: number; optionId: number }) =>
      api.patterns.respond(id, { response_option_id: optionId }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['pattern-streaks'] }),
  });

  const streakMap = new Map((streaks.data ?? []).map((s) => [s.pattern_id, s]));

  return (
    <div>
      <PageHeader
        title="Привычки"
        subtitle="Паттерны поведения, ответы и серии"
        actions={
          <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
            <Plus size={16} /> Новый паттерн
          </button>
        }
      />

      {patterns.isLoading ? (
        <div className="flex justify-center py-16">
          <Spinner />
        </div>
      ) : (patterns.data ?? []).length === 0 ? (
        <EmptyState
          title="Паттернов пока нет"
          description="Создайте полезную или вредную привычку с расписанием и вариантами ответа."
          action={
            <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
              Создать паттерн
            </button>
          }
        />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {(patterns.data ?? []).map((p) => {
            const streak = streakMap.get(p.id);
            return (
              <article key={p.id} className="card">
                <div className="card-body space-y-3">
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <h3 className="font-semibold">{p.title}</h3>
                      <p className="text-xs text-ink-muted">
                        {PATTERN_TYPE_LABEL[p.pattern_type]}
                        {p.is_boolean ? ' · да/нет' : ''}
                      </p>
                    </div>
                    <button
                      type="button"
                      className="btn-ghost px-2"
                      onClick={() => deleteMut.mutate(p.id)}
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>

                  {streak && (
                    <div className="flex items-center gap-4 rounded-lg bg-surface-3 px-3 py-2 text-sm">
                      <span className="flex items-center gap-1 font-semibold text-accent">
                        <Flame size={16} /> {streak.current_streak}
                      </span>
                      <span className="text-ink-muted">макс. {streak.max_streak}</span>
                      <span className="text-ink-muted">
                        {Math.round(streak.success_rate_30d)}% / 30д
                      </span>
                    </div>
                  )}

                  <div className="flex flex-wrap gap-2">
                    {p.options.map((opt) => (
                      <button
                        key={opt.id}
                        type="button"
                        className="btn-secondary text-xs"
                        disabled={respondMut.isPending}
                        onClick={() => respondMut.mutate({ id: p.id, optionId: opt.id })}
                      >
                        {opt.label}
                      </button>
                    ))}
                  </div>

                  {p.schedules.length > 0 && (
                    <p className="text-xs text-ink-muted">
                      Расписание:{' '}
                      {p.schedules.map((s) => s.time_of_day.slice(0, 5)).join(', ')}
                    </p>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      )}

      <PatternFormModal open={showForm} onClose={() => setShowForm(false)} />
    </div>
  );
}

function PatternFormModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const qc = useQueryClient();
  const [title, setTitle] = useState('');
  const [patternType, setPatternType] = useState<PatternType>('positive');
  const [isBoolean, setIsBoolean] = useState(true);
  const [time, setTime] = useState('08:00');
  const [error, setError] = useState('');

  const saveMut = useMutation({
    mutationFn: () =>
      api.patterns.create({
        title,
        pattern_type: patternType,
        is_boolean: isBoolean,
        schedules: [{ time_of_day: `${time}:00`, dow_mask: 127 }],
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['patterns'] });
      qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
      onClose();
      setTitle('');
    },
    onError: (e: Error) => setError(e.message),
  });

  return (
    <Modal open={open} title="Новый паттерн" onClose={onClose}>
      <form
        className="space-y-3"
        onSubmit={(e) => {
          e.preventDefault();
          saveMut.mutate();
        }}
      >
        {error && <ErrorBanner message={error} />}
        <input
          className="input"
          placeholder="Название (например, Зарядка)"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
        />
        <select
          className="select"
          value={patternType}
          onChange={(e) => setPatternType(e.target.value as PatternType)}
        >
          <option value="positive">Полезная привычка</option>
          <option value="negative">Вредная привычка</option>
        </select>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={isBoolean}
            onChange={(e) => setIsBoolean(e.target.checked)}
          />
          Булев ответ (Сделал / Не сделал)
        </label>
        <input type="time" className="input" value={time} onChange={(e) => setTime(e.target.value)} />
        <div className="flex justify-end gap-2">
          <button type="button" className="btn-secondary" onClick={onClose}>
            Отмена
          </button>
          <button type="submit" className="btn-primary" disabled={saveMut.isPending}>
            Создать
          </button>
        </div>
      </form>
    </Modal>
  );
}
