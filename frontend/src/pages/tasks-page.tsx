import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, Plus, Trash2 } from 'lucide-react';
import { api } from '@/api/client';
import type { Task, TaskPriority, TaskStatus } from '@/api/types';
import { PageHeader, Modal, Spinner, EmptyState, ErrorBanner } from '@/components/ui/primitives';
import { fmtDateTime, toIsoDateTimeLocal } from '@/lib/format';
import {
  PRIORITY_COLOR,
  STATUS_COLOR,
  TASK_PRIORITY_LABEL,
  TASK_STATUS_LABEL,
} from '@/lib/labels';

export function TasksPage() {
  const qc = useQueryClient();
  const [q, setQ] = useState('');
  const [status, setStatus] = useState<TaskStatus | ''>('');
  const [topicId, setTopicId] = useState<number | ''>('');
  const [showForm, setShowForm] = useState(false);
  const [editTask, setEditTask] = useState<Task | null>(null);

  const topics = useQuery({ queryKey: ['topics'], queryFn: api.topics.list });
  const tags = useQuery({ queryKey: ['tags'], queryFn: api.tags.list });
  const tasks = useQuery({
    queryKey: ['tasks', { q, status, topicId }],
    queryFn: () =>
      api.tasks.list({
        q: q || undefined,
        status: status || undefined,
        topic_id: topicId || undefined,
        archived: false,
      }),
  });

  const topicMap = useMemo(
    () => new Map((topics.data ?? []).map((t) => [t.id, t])),
    [topics.data],
  );

  const completeMut = useMutation({
    mutationFn: (id: number) => api.tasks.complete(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tasks'] }),
  });
  const deleteMut = useMutation({
    mutationFn: (id: number) => api.tasks.remove(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tasks'] }),
  });

  return (
    <div>
      <PageHeader
        title="Задачи"
        subtitle="Создание, фильтрация и выполнение задач"
        actions={
          <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
            <Plus size={16} /> Новая задача
          </button>
        }
      />

      <div className="mb-4 grid gap-3 md:grid-cols-4">
        <input
          className="input md:col-span-2"
          placeholder="Поиск по названию и описанию…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <select
          className="select"
          value={status}
          onChange={(e) => setStatus(e.target.value as TaskStatus | '')}
        >
          <option value="">Все статусы</option>
          {(Object.keys(TASK_STATUS_LABEL) as TaskStatus[]).map((s) => (
            <option key={s} value={s}>
              {TASK_STATUS_LABEL[s]}
            </option>
          ))}
        </select>
        <select
          className="select"
          value={topicId}
          onChange={(e) => setTopicId(e.target.value ? Number(e.target.value) : '')}
        >
          <option value="">Все темы</option>
          {(topics.data ?? []).map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </select>
      </div>

      {tasks.isLoading ? (
        <div className="flex justify-center py-16">
          <Spinner />
        </div>
      ) : (tasks.data ?? []).length === 0 ? (
        <EmptyState
          title="Задач пока нет"
          description="Создайте первую задачу с темой, дедлайном и приоритетом."
          action={
            <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
              Создать задачу
            </button>
          }
        />
      ) : (
        <div className="space-y-2">
          {(tasks.data ?? []).map((task) => {
            const topic = topicMap.get(task.topic_id);
            return (
              <article
                key={task.id}
                className="card flex items-start gap-3 p-4 transition hover:border-green-500/40"
              >
                <button
                  type="button"
                  className="mt-1 rounded-lg border border-border p-2 hover:bg-accent-soft disabled:opacity-40"
                  disabled={task.status === 'done' || completeMut.isPending}
                  onClick={() => completeMut.mutate(task.id)}
                  title="Отметить выполненной"
                >
                  <Check size={16} className="text-accent" />
                </button>
                <div className="min-w-0 flex-1">
                  <button
                    type="button"
                    className="text-left font-medium hover:text-accent"
                    onClick={() => setEditTask(task)}
                  >
                    {task.title}
                  </button>
                  {task.description && (
                    <p className="mt-1 line-clamp-2 text-sm text-ink-muted">{task.description}</p>
                  )}
                  <div className="mt-2 flex flex-wrap items-center gap-2 text-xs">
                    {topic && (
                      <span
                        className="badge"
                        style={{ backgroundColor: `${topic.color}22`, color: topic.color }}
                      >
                        {topic.name}
                      </span>
                    )}
                    <span className={`badge ${STATUS_COLOR[task.status]}`}>
                      {TASK_STATUS_LABEL[task.status]}
                    </span>
                    <span className={PRIORITY_COLOR[task.priority]}>
                      {TASK_PRIORITY_LABEL[task.priority]}
                    </span>
                    {task.deadline && (
                      <span className="text-ink-muted">до {fmtDateTime(task.deadline)}</span>
                    )}
                    {task.planned_minutes && (
                      <span className="text-ink-muted">{task.planned_minutes} мин</span>
                    )}
                  </div>
                </div>
                <button
                  type="button"
                  className="btn-ghost px-2"
                  onClick={() => deleteMut.mutate(task.id)}
                  title="Удалить"
                >
                  <Trash2 size={16} />
                </button>
              </article>
            );
          })}
        </div>
      )}

      <TaskFormModal
        open={showForm || !!editTask}
        task={editTask}
        topics={topics.data ?? []}
        tags={tags.data ?? []}
        onClose={() => {
          setShowForm(false);
          setEditTask(null);
        }}
      />
    </div>
  );
}

function TaskFormModal({
  open,
  task,
  topics,
  tags,
  onClose,
}: {
  open: boolean;
  task: Task | null;
  topics: { id: number; name: string; color: string }[];
  tags: { id: number; name: string }[];
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [topicId, setTopicId] = useState<number>(topics[0]?.id ?? 1);
  const [priority, setPriority] = useState<TaskPriority>('medium');
  const [deadline, setDeadline] = useState('');
  const [plannedMinutes, setPlannedMinutes] = useState('');
  const [tagIds, setTagIds] = useState<number[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!open) return;
    if (task) {
      setTitle(task.title);
      setDescription(task.description ?? '');
      setTopicId(task.topic_id);
      setPriority(task.priority);
      setDeadline(task.deadline ? toIsoDateTimeLocal(new Date(task.deadline)) : '');
      setPlannedMinutes(task.planned_minutes ? String(task.planned_minutes) : '');
      setTagIds(task.tag_ids);
    } else {
      setTitle('');
      setDescription('');
      setTopicId(topics[0]?.id ?? 1);
      setPriority('medium');
      setDeadline('');
      setPlannedMinutes('');
      setTagIds([]);
    }
    setError('');
  }, [open, task, topics]);

  const saveMut = useMutation({
    mutationFn: async () => {
      const body = {
        title,
        description: description || null,
        topic_id: topicId,
        priority,
        deadline: deadline ? new Date(deadline).toISOString() : null,
        planned_minutes: plannedMinutes ? Number(plannedMinutes) : null,
        tag_ids: tagIds,
      };
      if (task) return api.tasks.update(task.id, body);
      return api.tasks.create(body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['tasks'] });
      onClose();
    },
    onError: (e: Error) => setError(e.message),
  });

  return (
    <Modal
      open={open}
      title={task ? 'Редактировать задачу' : 'Новая задача'}
      onClose={onClose}
    >
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
          placeholder="Название"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
        />
        <textarea
          className="input min-h-24"
          placeholder="Описание"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
        <div className="grid gap-3 sm:grid-cols-2">
          <select
            className="select"
            value={topicId}
            onChange={(e) => setTopicId(Number(e.target.value))}
          >
            {topics.map((t) => (
              <option key={t.id} value={t.id}>
                {t.name}
              </option>
            ))}
          </select>
          <select
            className="select"
            value={priority}
            onChange={(e) => setPriority(e.target.value as TaskPriority)}
          >
            {(Object.keys(TASK_PRIORITY_LABEL) as TaskPriority[]).map((p) => (
              <option key={p} value={p}>
                {TASK_PRIORITY_LABEL[p]}
              </option>
            ))}
          </select>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <input
            type="datetime-local"
            className="input"
            value={deadline}
            onChange={(e) => setDeadline(e.target.value)}
          />
          <input
            type="number"
            className="input"
            placeholder="План, мин"
            min={1}
            value={plannedMinutes}
            onChange={(e) => setPlannedMinutes(e.target.value)}
          />
        </div>
        <div className="flex flex-wrap gap-2">
          {tags.map((tag) => (
            <label key={tag.id} className="flex items-center gap-1 text-sm">
              <input
                type="checkbox"
                checked={tagIds.includes(tag.id)}
                onChange={(e) =>
                  setTagIds((prev) =>
                    e.target.checked ? [...prev, tag.id] : prev.filter((id) => id !== tag.id),
                  )
                }
              />
              {tag.name}
            </label>
          ))}
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" className="btn-secondary" onClick={onClose}>
            Отмена
          </button>
          <button type="submit" className="btn-primary" disabled={saveMut.isPending}>
            {saveMut.isPending ? 'Сохранение…' : 'Сохранить'}
          </button>
        </div>
      </form>
    </Modal>
  );
}
