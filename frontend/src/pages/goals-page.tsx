import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link2, Pencil, Plus, Trash2, X } from 'lucide-react';
import { api } from '@/api/client';
import type { Goal, GoalLinkTarget } from '@/api/types';
import { PageHeader, Modal, Spinner, EmptyState, ErrorBanner } from '@/components/ui/primitives';
import { FormField } from '@/components/ui/form-field';
import { fmtDate, pct } from '@/lib/format';
import { PATTERN_MODE_LABEL } from '@/lib/labels';
import { confirmDelete } from '@/lib/confirm';

export function GoalsPage() {
  const qc = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [editGoal, setEditGoal] = useState<Goal | null>(null);
  const [selectedId, setSelectedId] = useState<number | null>(null);

  const goals = useQuery({ queryKey: ['goals'], queryFn: api.goals.list });

  const deleteMut = useMutation({
    mutationFn: (id: number) => api.goals.remove(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['goals'] });
      setSelectedId(null);
    },
  });

  return (
    <div>
      <PageHeader
        title="Цели"
        subtitle="Целевое значение — сколько единиц прогресса нужно: +1 за выполненную задачу или +1 за успешный день привычки."
        actions={
          <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
            <Plus size={16} /> Новая цель
          </button>
        }
      />

      {goals.isError && (
        <div className="mb-4">
          <ErrorBanner message="Не удалось загрузить цели" />
        </div>
      )}

      {goals.isLoading ? (
        <div className="flex justify-center py-16">
          <Spinner />
        </div>
      ) : (goals.data ?? []).length === 0 ? (
        <EmptyState
          title="Целей пока нет"
          description="Создайте цель, укажите целевое число и привяжите задачи или привычки."
          action={
            <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
              Создать цель
            </button>
          }
        />
      ) : (
        <div className="grid gap-6 lg:grid-cols-2">
          <div className="space-y-2">
            {(goals.data ?? []).map((goal) => (
              <button
                key={goal.id}
                type="button"
                className={`card w-full p-4 text-left transition ${
                  selectedId === goal.id ? 'border-accent ring-1 ring-accent/30' : ''
                }`}
                onClick={() =>
                  setSelectedId((id) => (id === goal.id ? null : goal.id))
                }
              >
                <div className="font-semibold">{goal.title}</div>
                <div className="mt-1 text-xs text-ink-muted">
                  цель: {goal.target_value} ед. · связей: {goal.links.length}
                  {goal.is_completed && ' · ✓ достигнута'}
                </div>
              </button>
            ))}
          </div>
          {selectedId != null && (() => {
            const selectedGoal = (goals.data ?? []).find((g) => g.id === selectedId);
            if (!selectedGoal) return null;
            return (
              <>
                <button
                  type="button"
                  className="fixed inset-0 z-30 bg-black/30 lg:hidden"
                  aria-label="Закрыть панель"
                  onClick={() => setSelectedId(null)}
                />
                <div className="relative z-40 lg:z-auto">
                  <GoalDetail
                    goalId={selectedId}
                    goal={selectedGoal}
                    onClose={() => setSelectedId(null)}
                    onDelete={() => {
                      if (confirmDelete(`цель «${selectedGoal.title}»`)) {
                        deleteMut.mutate(selectedId);
                      }
                    }}
                    onEdit={() => setEditGoal(selectedGoal)}
                  />
                </div>
              </>
            );
          })()}
        </div>
      )}

      <GoalFormModal
        open={showForm}
        onClose={() => setShowForm(false)}
        onCreated={(g) => setSelectedId(g.id)}
      />
      <GoalFormModal
        open={!!editGoal}
        goal={editGoal}
        onClose={() => setEditGoal(null)}
      />
    </div>
  );
}

function GoalDetail({
  goalId,
  goal,
  onClose,
  onDelete,
  onEdit,
}: {
  goalId: number;
  goal: Goal;
  onClose: () => void;
  onDelete: () => void;
  onEdit: () => void;
}) {
  const qc = useQueryClient();
  const progress = useQuery({
    queryKey: ['goal-progress', goalId],
    queryFn: () => api.goals.progress(goalId),
  });
  const tasks = useQuery({ queryKey: ['tasks', 'goal-link'], queryFn: () => api.tasks.list({ view: 'all' }) });
  const patterns = useQuery({ queryKey: ['patterns'], queryFn: api.patterns.list });

  const addLinkMut = useMutation({
    mutationFn: (body: { target_type: GoalLinkTarget; target_id: number }) =>
      api.goals.addLink(goalId, body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['goals'] });
      qc.invalidateQueries({ queryKey: ['goal-progress', goalId] });
    },
  });

  const removeLinkMut = useMutation({
    mutationFn: (body: { target_type: GoalLinkTarget; target_id: number }) =>
      api.goals.removeLink(goalId, body.target_type, body.target_id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['goals'] });
      qc.invalidateQueries({ queryKey: ['goal-progress', goalId] });
    },
  });

  const p = progress.data;

  return (
    <section className="card">
      <div className="card-body space-y-4">
        {progress.isError && (
          <ErrorBanner message="Не удалось загрузить прогресс цели" />
        )}
        <div className="flex items-start justify-between gap-2">
          <div>
            <h2 className="text-lg font-semibold">{goal.title}</h2>
            {goal.description && <p className="text-sm text-ink-muted">{goal.description}</p>}
          </div>
          <div className="flex gap-1">
            <button type="button" className="btn-ghost px-2" onClick={onEdit} title="Редактировать">
              <Pencil size={16} />
            </button>
            <button type="button" className="btn-ghost px-2" onClick={onDelete} title="Удалить">
              <Trash2 size={16} />
            </button>
            <button type="button" className="btn-ghost px-2" onClick={onClose} title="Закрыть">
              <X size={16} />
            </button>
          </div>
        </div>

        {goal.deadline && (
          <p className="text-sm text-ink-muted">Срок цели: {fmtDate(goal.deadline)}</p>
        )}

        {progress.isLoading ? (
          <Spinner />
        ) : p ? (
          <>
            <div>
              <div className="mb-1 flex justify-between text-sm">
                <span>
                  Прогресс: <strong>{p.done_units}</strong> / {p.target_value} ед. ({pct(p.progress)})
                </span>
                <span className="text-ink-muted">осталось {p.remaining_units}</span>
              </div>
              <div className="h-3 overflow-hidden rounded-full bg-surface-3">
                <div
                  className="h-full rounded-full bg-accent transition-all"
                  style={{ width: `${Math.min(100, p.progress)}%` }}
                />
              </div>
            </div>

            <div>
              <h3 className="mb-2 flex items-center gap-2 text-sm font-semibold">
                <Link2 size={14} /> Что входит в цель
              </h3>
              {p.links.length === 0 ? (
                <p className="text-sm text-ink-muted">Связей пока нет — добавьте ниже.</p>
              ) : (
                <ul className="space-y-2">
                  {p.links.map((link) => (
                    <li
                      key={`${link.target_type}-${link.target_id}`}
                      className="flex items-center justify-between rounded-lg border border-border px-3 py-2 text-sm"
                    >
                      <div>
                        <span className="badge mr-2 bg-surface-3">
                          {link.target_type === 'task' ? 'задача' : 'привычка'}
                        </span>
                        {link.title}
                        <span className="ml-2 text-xs text-ink-muted">{link.detail}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className={link.contributed ? 'text-accent' : 'text-ink-muted'}>
                          {link.contributed ? '✓' : '○'}
                        </span>
                        <button
                          type="button"
                          className="btn-ghost px-1"
                          onClick={() => {
                            if (
                              confirmDelete(
                                `привязку «${link.title}» от цели`,
                              )
                            ) {
                              removeLinkMut.mutate({
                                target_type: link.target_type,
                                target_id: link.target_id,
                              });
                            }
                          }}
                        >
                          <X size={14} />
                        </button>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </>
        ) : null}

        <div className="space-y-2 border-t border-border pt-4">
          <div className="flex items-center justify-between gap-2">
            <h3 className="text-sm font-semibold">Привязки</h3>
            <button type="button" className="btn-secondary text-xs" onClick={onClose}>
              Готово
            </button>
          </div>
          <FormField label="Привязать задачу">
          <select
            className="select"
            defaultValue=""
            onChange={(e) => {
              const id = Number(e.target.value);
              if (id) addLinkMut.mutate({ target_type: 'task', target_id: id });
              e.target.value = '';
            }}
          >
            <option value="">Выберите задачу…</option>
            {(tasks.data ?? [])
              .filter((t) => !goal.links.some((l) => l.target_type === 'task' && l.target_id === t.id))
              .map((t) => (
                <option key={t.id} value={t.id}>
                  {t.title}
                </option>
              ))}
          </select>
          </FormField>

          <FormField label="Привязать паттерн">
          <select
            className="select"
            defaultValue=""
            onChange={(e) => {
              const id = Number(e.target.value);
              if (id) addLinkMut.mutate({ target_type: 'pattern', target_id: id });
              e.target.value = '';
            }}
          >
            <option value="">Выберите паттерн…</option>
            {(patterns.data ?? [])
              .filter(
                (p) =>
                  !goal.links.some((l) => l.target_type === 'pattern' && l.target_id === p.id),
              )
              .map((p) => (
                <option key={p.id} value={p.id}>
                  {p.title} ({PATTERN_MODE_LABEL[p.pattern_mode]})
                </option>
              ))}
          </select>
          </FormField>
        </div>
      </div>
    </section>
  );
}

function GoalFormModal({
  open,
  onClose,
  onCreated,
  goal = null,
}: {
  open: boolean;
  onClose: () => void;
  /** После создания новой цели (открывается панель привязок — её можно закрыть) */
  onCreated?: (goal: Goal) => void;
  goal?: Goal | null;
}) {
  const qc = useQueryClient();
  const [title, setTitle] = useState('');
  const [targetValue, setTargetValue] = useState('10');
  const [description, setDescription] = useState('');
  const [deadline, setDeadline] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!open) return;
    if (goal) {
      setTitle(goal.title);
      setDescription(goal.description ?? '');
      setTargetValue(String(goal.target_value));
      setDeadline(goal.deadline ? goal.deadline.slice(0, 10) : '');
    } else {
      setTitle('');
      setDescription('');
      setTargetValue('10');
      setDeadline('');
    }
    setError('');
  }, [open, goal]);

  const saveMut = useMutation({
    mutationFn: () => {
      const body = {
        title,
        description: description || null,
        target_value: Number(targetValue) || 1,
        deadline: deadline ? deadline.slice(0, 10) : null,
      };
      if (goal) return api.goals.update(goal.id, body);
      return api.goals.create(body);
    },
    onSuccess: (saved: Goal) => {
      qc.invalidateQueries({ queryKey: ['goals'] });
      onClose();
      if (!goal) onCreated?.(saved);
    },
    onError: (e: Error) => setError(e.message),
  });

  return (
    <Modal open={open} title={goal ? 'Редактировать цель' : 'Новая цель'} onClose={onClose}>
      <form
        className="space-y-3"
        onSubmit={(e) => {
          e.preventDefault();
          saveMut.mutate();
        }}
      >
        {error && <ErrorBanner message={error} />}
        <FormField label="Название" hint="Например: 30 дней зарядки">
          <input
            className="input"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            required
          />
        </FormField>
        <FormField label="Описание" hint="Необязательно">
          <textarea
            className="input min-h-20"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </FormField>
        <label className="block text-sm">
          <span className="mb-1 block font-medium">Целевое значение (единиц прогресса)</span>
          <input
            type="number"
            className="input"
            min={1}
            value={targetValue}
            onChange={(e) => setTargetValue(e.target.value)}
          />
          <span className="mt-1 block text-xs text-ink-muted">
            Например: 10 — выполнить 10 привязанных задач или 10 успешных дней привычки
          </span>
        </label>
        <FormField label="Срок (необязательно)" hint="Только дата, без времени">
          <input
            type="date"
            className="input"
            value={deadline}
            onChange={(e) => setDeadline(e.target.value)}
          />
        </FormField>
        <div className="flex justify-end gap-2">
          <button type="button" className="btn-secondary" onClick={onClose}>
            Отмена
          </button>
          <button type="submit" className="btn-primary" disabled={saveMut.isPending}>
            {saveMut.isPending ? 'Сохранение…' : goal ? 'Сохранить' : 'Создать'}
          </button>
        </div>
      </form>
    </Modal>
  );
}
