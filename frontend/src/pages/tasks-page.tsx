import { useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, Plus, RotateCcw, Timer, Trash2 } from 'lucide-react';
import { TaskTimeLogsPanel } from '@/components/tasks/task-time-logs-panel';
import { api } from '@/api/client';
import type { Task, TaskPriority, TaskStatus, TaskView } from '@/api/types';
import {
  DEFAULT_RECURRING_DRAFT,
  RecurringEditor,
  recurringDraftFromRule,
  recurringDraftToApi,
  type RecurringDraft,
} from '@/components/tasks/recurring-editor';
import { PageHeader, Modal, Spinner, EmptyState, ErrorBanner } from '@/components/ui/primitives';
import { FormField } from '@/components/ui/form-field';
import { fmtDateTime, toIsoDateTimeLocal } from '@/lib/format';
import { confirmDelete } from '@/lib/confirm';
import {
  PRIORITY_COLOR,
  STATUS_COLOR,
  TASK_PRIORITY_LABEL,
  TASK_STATUS_LABEL,
} from '@/lib/labels';

const VIEWS: { id: TaskView | 'archived'; label: string }[] = [
  { id: 'active', label: 'Активные' },
  { id: 'completed', label: 'Выполненные' },
  { id: 'all', label: 'Все' },
  { id: 'archived', label: 'Архив' },
];

export function TasksPage() {
  const qc = useQueryClient();
  const [searchParams, setSearchParams] = useSearchParams();
  const dayFilter = searchParams.get('day') ?? '';
  const [view, setView] = useState<TaskView | 'archived'>('active');
  const [q, setQ] = useState('');
  const [status, setStatus] = useState<TaskStatus | ''>('');
  const [topicId, setTopicId] = useState<number | ''>('');
  const [showForm, setShowForm] = useState(false);
  const [editTask, setEditTask] = useState<Task | null>(null);

  const topics = useQuery({ queryKey: ['topics'], queryFn: api.topics.list });
  const tags = useQuery({ queryKey: ['tags'], queryFn: api.tags.list });
  const searchQ = q.trim();
  const listView: TaskView = searchQ || view === 'archived' ? 'all' : view;
  const tasks = useQuery({
    queryKey: ['tasks', { view: listView, q: searchQ, status, topicId, dayFilter, archived: view }],
    queryFn: () =>
      api.tasks.list({
        view: dayFilter ? 'all' : listView,
        q: searchQ || undefined,
        status: status || undefined,
        topic_id: topicId || undefined,
        deadline_on: dayFilter || undefined,
        archived: view === 'archived' ? true : view === 'all' ? undefined : false,
        roots_only: true,
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
  const reopenMut = useMutation({
    mutationFn: (id: number) => api.tasks.reopen(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tasks'] }),
  });
  const deleteMut = useMutation({
    mutationFn: (id: number) => api.tasks.remove(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tasks'] }),
  });
  const startMut = useMutation({
    mutationFn: (id: number) => api.tasks.start(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tasks'] }),
  });
  const cancelMut = useMutation({
    mutationFn: (id: number) => api.tasks.cancel(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tasks'] }),
  });
  const archiveMut = useMutation({
    mutationFn: ({ id, archived }: { id: number; archived: boolean }) =>
      api.tasks.update(id, { is_archived: archived }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tasks'] }),
  });

  const isCompleted = (s: TaskStatus) => s === 'done';
  return (
    <div>
      <PageHeader
        title="Задачи"
        subtitle="Окно выполнения: «начать с» → «сделать до». План в минутах — оценка работы, не длительность интервала."
        actions={
          <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
            <Plus size={16} /> Новая задача
          </button>
        }
      />

      {dayFilter && (
        <div className="mb-4 flex items-center justify-between rounded-lg border border-accent/40 bg-accent-soft px-4 py-2 text-sm">
          <span>Дедлайн на {dayFilter}</span>
          <button
            type="button"
            className="btn-ghost text-xs"
            onClick={() => setSearchParams({})}
          >
            Сбросить фильтр
          </button>
        </div>
      )}

      <div className="mb-4 flex flex-wrap gap-2">
        {VIEWS.map((v) => (
          <button
            key={v.id}
            type="button"
            className={view === v.id ? 'btn-primary' : 'btn-secondary'}
            onClick={() => setView(v.id)}
          >
            {v.label}
          </button>
        ))}
      </div>

      <div className="mb-4 grid gap-3 md:grid-cols-4">
        <FormField label="Поиск" className="md:col-span-2">
          <input
            className="input"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </FormField>
        <FormField label="Статус">
          <select
            className="select"
            value={status}
            onChange={(e) => setStatus(e.target.value as TaskStatus | '')}
          >
            <option value="">Все</option>
            {(Object.keys(TASK_STATUS_LABEL) as TaskStatus[]).map((s) => (
              <option key={s} value={s}>
                {TASK_STATUS_LABEL[s]}
              </option>
            ))}
          </select>
        </FormField>
        <FormField label="Тема">
          <select
            className="select"
            value={topicId}
            onChange={(e) => setTopicId(e.target.value ? Number(e.target.value) : '')}
          >
            <option value="">Все</option>
            {(topics.data ?? []).map((t) => (
              <option key={t.id} value={t.id}>
                {t.name}
              </option>
            ))}
          </select>
        </FormField>
      </div>

      {tasks.isError ? (
        <ErrorBanner message="Не удалось загрузить задачи" />
      ) : tasks.isLoading ? (
        <div className="flex justify-center py-16">
          <Spinner />
        </div>
      ) : (tasks.data ?? []).length === 0 ? (
        <EmptyState
          title={
            searchQ
              ? 'Ничего не найдено'
              : view === 'completed'
                ? 'Выполненных задач пока нет'
                : 'Задач пока нет'
          }
          description={
            searchQ
              ? `По запросу «${searchQ}» задач нет. Попробуйте часть слова из названия или описания.`
              : view === 'completed'
                ? 'Отметьте задачу галочкой — она появится здесь.'
                : 'Создайте задачу с темой, окном выполнения и планом времени.'
          }
          action={
            view !== 'completed' ? (
              <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
                Создать задачу
              </button>
            ) : undefined
          }
        />
      ) : (
        <div className="space-y-2">
          {(tasks.data ?? []).map((task) => {
            const topic = topicMap.get(task.topic_id);
            const done = isCompleted(task.status);
            return (
              <article
                key={task.id}
                className="card flex items-start gap-3 p-4 transition hover:border-green-500/40"
              >
                {!done ? (
                  <button
                    type="button"
                    className="mt-1 rounded-lg border border-border p-2 hover:bg-accent-soft disabled:opacity-40"
                    disabled={completeMut.isPending}
                    onClick={() => completeMut.mutate(task.id)}
                    title="Отметить выполненной"
                  >
                    <Check size={16} className="text-accent" />
                  </button>
                ) : (
                  <button
                    type="button"
                    className="mt-1 rounded-lg border border-border p-2 hover:bg-accent-soft"
                    disabled={reopenMut.isPending}
                    onClick={() => reopenMut.mutate(task.id)}
                    title="Вернуть в работу"
                  >
                    <RotateCcw size={16} className="text-ink-muted" />
                  </button>
                )}
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
                    {task.start_at && (
                      <span className="text-ink-muted">с {fmtDateTime(task.start_at)}</span>
                    )}
                    {task.deadline && (
                      <span className="text-ink-muted">до {fmtDateTime(task.deadline)}</span>
                    )}
                    {task.planned_minutes && (
                      <span className="text-ink-muted">план {task.planned_minutes} мин</span>
                    )}
                    {task.recurring_rule_id && (
                      <span className="badge bg-violet-500/10 text-violet-700">повтор</span>
                    )}
                    {done && task.completed_at && (
                      <span className="text-ink-muted">
                        выполнена {fmtDateTime(task.completed_at)}
                        {task.status === 'overdue' ? ' · с опозданием' : ' · в срок'}
                      </span>
                    )}
                  </div>
                  {!done && view !== 'archived' && (
                    <div className="mt-2 flex flex-wrap gap-1">
                      {(task.status === 'pending' || task.status === 'overdue') && (
                        <button
                          type="button"
                          className="btn-ghost px-2 py-1 text-xs"
                          onClick={() => startMut.mutate(task.id)}
                        >
                          В работу
                        </button>
                      )}
                      {task.status !== 'cancelled' && (
                        <button
                          type="button"
                          className="btn-ghost px-2 py-1 text-xs"
                          onClick={() => cancelMut.mutate(task.id)}
                        >
                          Отменить
                        </button>
                      )}
                      <button
                        type="button"
                        className="btn-ghost px-2 py-1 text-xs"
                        onClick={() =>
                          archiveMut.mutate({ id: task.id, archived: !task.is_archived })
                        }
                      >
                        {task.is_archived ? 'Из архива' : 'В архив'}
                      </button>
                      <Link
                        to={`/pomodoro?task=${task.id}`}
                        className="btn-ghost inline-flex items-center gap-1 px-2 py-1 text-xs"
                      >
                        <Timer size={14} /> Фокус
                      </Link>
                    </div>
                  )}
                </div>
                <div className="flex shrink-0 flex-col gap-1">
                  <button
                    type="button"
                    className="btn-ghost px-2"
                    onClick={() => {
                      if (confirmDelete(`задачу «${task.title}»`)) deleteMut.mutate(task.id);
                    }}
                    title="Удалить"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
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
  const [topicId, setTopicId] = useState<number>(topics[0]?.id ?? 0);
  const [priority, setPriority] = useState<TaskPriority>('medium');
  const [startAt, setStartAt] = useState('');
  const [deadline, setDeadline] = useState('');
  const [plannedMinutes, setPlannedMinutes] = useState('');
  const [tagIds, setTagIds] = useState<number[]>([]);
  const [recurringDraft, setRecurringDraft] = useState<RecurringDraft>(DEFAULT_RECURRING_DRAFT);
  const [newSubtaskTitle, setNewSubtaskTitle] = useState('');
  const [error, setError] = useState('');

  const subtasks = useQuery({
    queryKey: ['subtasks', task?.id],
    queryFn: () => api.tasks.subtasks(task!.id),
    enabled: open && !!task,
  });

  const taskRecurring = useQuery({
    queryKey: ['task-recurring', task?.id],
    queryFn: () => api.tasks.getRecurring(task!.id),
    enabled: open && !!task?.recurring_rule_id,
  });

  useEffect(() => {
    if (!open) return;
    if (task) {
      setTitle(task.title);
      setDescription(task.description ?? '');
      setTopicId(task.topic_id);
      setPriority(task.priority);
      setStartAt(task.start_at ? toIsoDateTimeLocal(new Date(task.start_at)) : '');
      setDeadline(task.deadline ? toIsoDateTimeLocal(new Date(task.deadline)) : '');
      setPlannedMinutes(task.planned_minutes ? String(task.planned_minutes) : '');
      setTagIds(task.tag_ids);
      if (!task.recurring_rule_id) {
        setRecurringDraft(DEFAULT_RECURRING_DRAFT);
      }
    } else {
      setTitle('');
      setDescription('');
      setTopicId(topics[0]?.id ?? 0);
      setPriority('medium');
      setStartAt('');
      setDeadline('');
      setPlannedMinutes('');
      setTagIds([]);
      setRecurringDraft(DEFAULT_RECURRING_DRAFT);
    }
    setNewSubtaskTitle('');
    setError('');
  }, [open, task, topics]);

  useEffect(() => {
    if (!open || !task?.recurring_rule_id || !taskRecurring.data) return;
    setRecurringDraft(recurringDraftFromRule(taskRecurring.data));
  }, [open, task?.recurring_rule_id, taskRecurring.data]);

  const saveMut = useMutation({
    mutationFn: async () => {
      const body = {
        title,
        description: description || null,
        topic_id: topicId,
        priority,
        start_at: startAt ? new Date(startAt).toISOString() : null,
        deadline: deadline ? new Date(deadline).toISOString() : null,
        planned_minutes: plannedMinutes ? Number(plannedMinutes) : null,
        tag_ids: tagIds,
      };
      const recurringBody = recurringDraftToApi(recurringDraft);
      if (task) {
        const updated = await api.tasks.update(task.id, body);
        const hadRecurring = !!task.recurring_rule_id;
        if (recurringDraft.enabled && !task.parent_task_id) {
          if (hadRecurring) {
            await api.tasks.updateRecurring(task.id, recurringBody);
          } else {
            await api.tasks.attachRecurring(task.id, recurringBody);
          }
        } else if (hadRecurring && !recurringDraft.enabled) {
          await api.tasks.detachRecurring(task.id);
        }
        return updated;
      }
      return api.tasks.create({
        ...body,
        ...(recurringDraft.enabled ? { recurring: recurringBody } : {}),
      });
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['tasks'] });
      if (task?.id) {
        qc.invalidateQueries({ queryKey: ['task-recurring', task.id] });
      }
      onClose();
    },
    onError: (e: Error) => setError(e.message),
  });

  const addSubtaskMut = useMutation({
    mutationFn: () =>
      api.tasks.create({
        topic_id: topicId,
        title: newSubtaskTitle.trim(),
        parent_task_id: task!.id,
        priority: 'medium',
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['subtasks', task!.id] });
      qc.invalidateQueries({ queryKey: ['tasks'] });
      setNewSubtaskTitle('');
    },
    onError: (e: Error) => setError(e.message),
  });

  const deleteSubtaskMut = useMutation({
    mutationFn: (id: number) => api.tasks.remove(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['subtasks', task!.id] });
      qc.invalidateQueries({ queryKey: ['tasks'] });
    },
    onError: (e: Error) => setError(e.message),
  });

  return (
    <Modal open={open} title={task ? 'Редактировать задачу' : 'Новая задача'} onClose={onClose} wide>
      <form
        className="space-y-3"
        onSubmit={(e) => {
          e.preventDefault();
          saveMut.mutate();
        }}
      >
        {error && <ErrorBanner message={error} />}
        {topics.length === 0 && (
          <p className="text-sm text-ink-muted">Сначала создайте тему в настройках.</p>
        )}
        <FormField label="Название">
          <input
            className="input"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            required
          />
        </FormField>
        <FormField label="Описание" hint="Необязательно">
          <textarea
            className="input min-h-24"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </FormField>
        <div className="grid gap-3 sm:grid-cols-2">
          <FormField label="Тема">
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
          </FormField>
          <FormField label="Приоритет">
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
          </FormField>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="block text-sm">
            <span className="mb-1 block font-medium">Начать не раньше</span>
            <input
              type="datetime-local"
              className="input"
              value={startAt}
              onChange={(e) => setStartAt(e.target.value)}
            />
            <span className="mt-1 block text-xs text-ink-muted">
              Начало окна выполнения (не время старта таймера)
            </span>
          </label>
          <label className="block text-sm">
            <span className="mb-1 block font-medium">Сделать до (дедлайн)</span>
            <input
              type="datetime-local"
              className="input"
              value={deadline}
              onChange={(e) => setDeadline(e.target.value)}
            />
            <span className="mt-1 block text-xs text-ink-muted">
              Крайний срок окончания задачи
            </span>
          </label>
        </div>
        <label className="block text-sm">
          <span className="mb-1 block font-medium">Плановое время (мин)</span>
          <input
            type="number"
            className="input"
            placeholder="например, 90"
            min={1}
            value={plannedMinutes}
            onChange={(e) => setPlannedMinutes(e.target.value)}
          />
          <span className="mt-1 block text-xs text-ink-muted">
            Сколько минут планируете потратить — не длительность между датами выше
          </span>
        </label>
        {!task?.parent_task_id && (
          <RecurringEditor value={recurringDraft} onChange={setRecurringDraft} />
        )}
        {task && !task.parent_task_id && (
          <div>
            <div className="mb-2 text-sm font-medium">Подзадачи</div>
            {(subtasks.data ?? []).length > 0 && (
              <ul className="mb-2 space-y-1 text-sm">
                {(subtasks.data ?? []).map((st) => (
                  <li
                    key={st.id}
                    className="flex items-center justify-between rounded border border-border px-2 py-1"
                  >
                    <span>
                      {st.title}{' '}
                      <span className="text-ink-muted">({TASK_STATUS_LABEL[st.status]})</span>
                    </span>
                    <button
                      type="button"
                      className="btn-ghost px-1 text-ink-muted hover:text-red-600"
                      title="Удалить подзадачу"
                      disabled={deleteSubtaskMut.isPending}
                      onClick={() => {
                        if (confirmDelete(`подзадачу «${st.title}»`)) {
                          deleteSubtaskMut.mutate(st.id);
                        }
                      }}
                    >
                      <Trash2 size={14} />
                    </button>
                  </li>
                ))}
              </ul>
            )}
            <div className="flex gap-2">
              <FormField label="Подзадача" className="min-w-0 flex-1">
                <input
                  className="input"
                  value={newSubtaskTitle}
                  onChange={(e) => setNewSubtaskTitle(e.target.value)}
                />
              </FormField>
              <button
                type="button"
                className="btn-secondary"
                disabled={!newSubtaskTitle.trim() || addSubtaskMut.isPending}
                onClick={() => addSubtaskMut.mutate()}
              >
                Добавить
              </button>
            </div>
          </div>
        )}
        {task && (
          <div>
            <div className="mb-2 text-sm font-medium">Учтённое время</div>
            <TaskTimeLogsPanel taskId={task.id} />
          </div>
        )}
        {tags.length > 0 && (
        <FormField label="Теги">
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
        </FormField>
        )}
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" className="btn-secondary" onClick={onClose}>
            Отмена
          </button>
          <button type="submit" className="btn-primary" disabled={saveMut.isPending || !topicId || topics.length === 0}>
            {saveMut.isPending ? 'Сохранение…' : 'Сохранить'}
          </button>
        </div>
      </form>
    </Modal>
  );
}
