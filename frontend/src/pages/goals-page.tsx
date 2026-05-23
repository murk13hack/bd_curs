import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2 } from 'lucide-react';
import { api } from '@/api/client';
import { PageHeader, Modal, Spinner, EmptyState, ErrorBanner } from '@/components/ui/primitives';
import { fmtDate, pct } from '@/lib/format';

export function GoalsPage() {
  const qc = useQueryClient();
  const [showForm, setShowForm] = useState(false);

  const goals = useQuery({ queryKey: ['goals'], queryFn: api.goals.list });

  const deleteMut = useMutation({
    mutationFn: (id: number) => api.goals.remove(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['goals'] }),
  });

  return (
    <div>
      <PageHeader
        title="Цели"
        subtitle="Долгосрочные цели и прогресс выполнения"
        actions={
          <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
            <Plus size={16} /> Новая цель
          </button>
        }
      />

      {goals.isLoading ? (
        <div className="flex justify-center py-16">
          <Spinner />
        </div>
      ) : (goals.data ?? []).length === 0 ? (
        <EmptyState
          title="Целей пока нет"
          description="Создайте цель и привяжите к ней задачи или паттерны."
          action={
            <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
              Создать цель
            </button>
          }
        />
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {(goals.data ?? []).map((goal) => (
            <GoalCard key={goal.id} goalId={goal.id} goal={goal} onDelete={() => deleteMut.mutate(goal.id)} />
          ))}
        </div>
      )}

      <GoalFormModal open={showForm} onClose={() => setShowForm(false)} />
    </div>
  );
}

function GoalCard({
  goalId,
  goal,
  onDelete,
}: {
  goalId: number;
  goal: { title: string; description: string | null; deadline: string | null; is_completed: boolean; target_value: number; links: unknown[] };
  onDelete: () => void;
}) {
  const progress = useQuery({
    queryKey: ['goal-progress', goalId],
    queryFn: () => api.goals.progress(goalId),
  });

  const p = progress.data?.progress ?? 0;

  return (
    <article className="card">
      <div className="card-body space-y-3">
        <div className="flex items-start justify-between gap-2">
          <div>
            <h3 className="font-semibold">{goal.title}</h3>
            {goal.description && <p className="text-sm text-ink-muted">{goal.description}</p>}
          </div>
          <button type="button" className="btn-ghost px-2" onClick={onDelete}>
            <Trash2 size={16} />
          </button>
        </div>
        {goal.deadline && (
          <p className="text-xs text-ink-muted">Срок: {fmtDate(goal.deadline)}</p>
        )}
        <div>
          <div className="mb-1 flex justify-between text-sm">
            <span>Прогресс</span>
            <span className="font-semibold">{pct(p)}</span>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-surface-3">
            <div
              className="h-full rounded-full bg-accent transition-all"
              style={{ width: `${Math.min(100, p)}%` }}
            />
          </div>
        </div>
        <div className="text-xs text-ink-muted">
          Цель: {goal.target_value} · Связей: {goal.links.length}
          {goal.is_completed && ' · ✓ Завершена'}
        </div>
      </div>
    </article>
  );
}

function GoalFormModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const qc = useQueryClient();
  const [title, setTitle] = useState('');
  const [targetValue, setTargetValue] = useState('1');
  const [error, setError] = useState('');

  const saveMut = useMutation({
    mutationFn: () =>
      api.goals.create({ title, target_value: Number(targetValue) || 1 }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['goals'] });
      onClose();
      setTitle('');
    },
    onError: (e: Error) => setError(e.message),
  });

  return (
    <Modal open={open} title="Новая цель" onClose={onClose}>
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
          placeholder="Название цели"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
        />
        <input
          type="number"
          className="input"
          min={1}
          placeholder="Целевое значение"
          value={targetValue}
          onChange={(e) => setTargetValue(e.target.value)}
        />
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
