import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  Ban,
  BarChart3,
  ChevronLeft,
  ChevronRight,
  Flame,
  Map as MapIcon,
  MapPin,
  Pencil,
  Plus,
  Shield,
  Trash2,
} from 'lucide-react';
import { api } from '@/api/client';
import type {
  Pattern,
  PatternMode,
  PatternSession,
  PatternStep,
  PatternStreak,
  PatternType,
} from '@/api/types';
import { PageHeader, Modal, Spinner, EmptyState, ErrorBanner } from '@/components/ui/primitives';
import { ScenarioBuilder } from '@/components/patterns/scenario-builder';
import { PatternDayStrip } from '@/components/patterns/pattern-day-strip';
import { PatternPictureModal } from '@/components/patterns/pattern-picture-modal';
import {
  ScheduleEditor,
  schedulesToApi,
  type ScheduleRow,
} from '@/components/patterns/schedule-editor';
import {
  PATTERN_MODE_LABEL,
  PATTERN_STEP_ROLE_LABEL,
  PATTERN_TYPE_LABEL,
} from '@/lib/labels';
import { confirmDelete } from '@/lib/confirm';
import {
  SCENARIO_TEMPLATES,
  formatScheduleTimes,
  fromPatternSteps,
  rateLabel,
  streakLabel,
  todayDateOnly,
  todayTone,
  toApiSteps,
  toStepDrafts,
  validateScenarioSteps,
  type StepDraft,
} from '@/lib/pattern-templates';

export function PatternsPage() {
  const qc = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [wizardPattern, setWizardPattern] = useState<Pattern | null>(null);
  const [editPattern, setEditPattern] = useState<Pattern | null>(null);
  const [picturePattern, setPicturePattern] = useState<Pattern | null>(null);
  const [logsPattern, setLogsPattern] = useState<Pattern | null>(null);

  const patterns = useQuery({ queryKey: ['patterns'], queryFn: api.patterns.list });
  const streaks = useQuery({ queryKey: ['pattern-streaks'], queryFn: api.patterns.streaksAll });
  const streakMap = new Map((streaks.data ?? []).map((s) => [s.pattern_id, s]));

  const deleteMut = useMutation({
    mutationFn: (id: number) => api.patterns.remove(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['patterns'] });
      qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
    },
  });

  return (
    <div>
      <PageHeader
        title="Паттерны поведения"
        subtitle="Чеклист, сценарии дня и точечные отметки эпизодов."
        actions={
          <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
            <Plus size={16} /> Новый паттерн
          </button>
        }
      />

      {patterns.isError && (
        <div className="mb-4">
          <ErrorBanner message="Не удалось загрузить паттерны" />
        </div>
      )}

      {patterns.isLoading ? (
        <div className="flex justify-center py-16">
          <Spinner />
        </div>
      ) : (patterns.data ?? []).length === 0 ? (
        <EmptyState
          title="Паттернов пока нет"
          description="Создайте быструю привычку или сценарий дня — например, «Бросаю курить»."
          action={
            <button type="button" className="btn-primary" onClick={() => setShowForm(true)}>
              Создать паттерн
            </button>
          }
        />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {(patterns.data ?? []).map((p) =>
            p.pattern_mode === 'scenario' ? (
              <ScenarioCard
                key={p.id}
                pattern={p}
                streak={streakMap.get(p.id)}
                onOpen={() => setWizardPattern(p)}
                onPicture={() => setPicturePattern(p)}
                onEdit={() => setEditPattern(p)}
                onDelete={() => {
                  if (confirmDelete(`паттерн «${p.title}»`)) deleteMut.mutate(p.id);
                }}
              />
            ) : p.pattern_mode === 'markers' ? (
              <MarkersCard
                key={p.id}
                pattern={p}
                streak={streakMap.get(p.id)}
                onPicture={() => setPicturePattern(p)}
                onEdit={() => setEditPattern(p)}
                onDelete={() => {
                  if (confirmDelete(`паттерн «${p.title}»`)) deleteMut.mutate(p.id);
                }}
              />
            ) : (
              <HabitCard
                key={p.id}
                pattern={p}
                streak={streakMap.get(p.id)}
                onPicture={() => setPicturePattern(p)}
                onLogs={() => setLogsPattern(p)}
                onEdit={() => setEditPattern(p)}
                onDelete={() => {
                  if (confirmDelete(`паттерн «${p.title}»`)) deleteMut.mutate(p.id);
                }}
              />
            ),
          )}
        </div>
      )}

      <PatternCreateModal open={showForm} onClose={() => setShowForm(false)} />
      {wizardPattern && (
        <ScenarioWizard pattern={wizardPattern} onClose={() => setWizardPattern(null)} />
      )}
      {editPattern && (
        <PatternEditModal pattern={editPattern} onClose={() => setEditPattern(null)} />
      )}
      {picturePattern && (
        <PatternPictureModal pattern={picturePattern} onClose={() => setPicturePattern(null)} />
      )}
      {logsPattern && (
        <PatternLogsModal pattern={logsPattern} onClose={() => setLogsPattern(null)} />
      )}
    </div>
  );
}

function statToneClass(tone: 'good' | 'bad' | 'pending'): string {
  if (tone === 'good') return 'text-emerald-600';
  if (tone === 'bad') return 'text-red-600';
  return 'text-amber-600';
}

function statBgClass(tone: 'good' | 'bad' | 'pending'): string {
  if (tone === 'good') return 'bg-emerald-500/10 border-emerald-500/30';
  if (tone === 'bad') return 'bg-red-500/10 border-red-500/30';
  return 'bg-amber-500/10 border-amber-500/30';
}

function HabitCard({
  pattern,
  streak,
  onPicture,
  onLogs,
  onEdit,
  onDelete,
}: {
  pattern: Pattern;
  streak?: PatternStreak;
  onPicture: () => void;
  onLogs: () => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const qc = useQueryClient();
  const mini = useQuery({
    queryKey: ['pattern-insights', pattern.id, 7],
    queryFn: () => api.patterns.insights(pattern.id, 7),
    staleTime: 60_000,
  });
  const today = useQuery({
    queryKey: ['pattern-today', pattern.id],
    queryFn: () => api.patterns.today(pattern.id),
  });

  const respondMut = useMutation({
    mutationFn: (optionId: number) =>
      api.patterns.respond(pattern.id, {
        response_option_id: optionId,
        scheduled_at: todayDateOnly(),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['pattern-today', pattern.id] });
      qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
      qc.invalidateQueries({ queryKey: ['pattern-insights', pattern.id] });
    },
  });

  const t = today.data;
  const tone = todayTone(t?.is_success_today);
  const Icon = pattern.pattern_type === 'negative' ? Shield : Flame;

  return (
    <article className="card">
      <div className="card-body space-y-3">
        <CardHeader
          pattern={pattern}
          onEdit={onEdit}
          onDelete={onDelete}
          icon={pattern.pattern_type === 'negative' ? Ban : Icon}
        />

        {streak && (
          <div className={`rounded-lg border px-3 py-2 text-sm ${statBgClass(tone)}`}>
            <div className={`flex items-center gap-2 font-semibold ${statToneClass(tone)}`}>
              <Icon size={16} />
              {streak.current_streak}{' '}
              <span className="font-normal text-ink-muted">
                {streakLabel(pattern.pattern_type, pattern.pattern_mode)}
              </span>
            </div>
            <div className="mt-1 text-xs text-ink-muted">
              рекорд {streak.max_streak} · за 30 д{' '}
              {rateLabel(streak.scheduled_days_30d, streak.success_days_30d)}
            </div>
          </div>
        )}

        <TodayBlock today={t} />

        <div className="flex flex-wrap gap-2">
          {pattern.options.map((opt) => {
            const selected = t?.response_option_id === opt.id;
            const btnClass = selected
              ? opt.is_success
                ? 'btn-primary bg-emerald-600 hover:bg-emerald-700 border-emerald-600'
                : 'btn-primary bg-red-600 hover:bg-red-700 border-red-600'
              : 'btn-secondary';
            return (
              <button
                key={opt.id}
                type="button"
                className={`text-xs ${btnClass}`}
                disabled={
                  respondMut.isPending ||
                  (t !== undefined && !t.can_respond) ||
                  (t !== undefined && !t.is_scheduled_today)
                }
                onClick={() => respondMut.mutate(opt.id)}
              >
                {opt.label}
              </button>
            );
          })}
        </div>

        <ScheduleLine schedules={pattern.schedules} />

        {mini.data && <PatternDayStrip days={mini.data.calendar} compact />}

        <button type="button" className="btn-secondary w-full text-xs" onClick={onPicture}>
          <BarChart3 size={14} /> Картина
        </button>
        <button type="button" className="btn-secondary w-full text-xs" onClick={onLogs}>
          История ответов
        </button>
      </div>
    </article>
  );
}

function PatternLogsModal({ pattern, onClose }: { pattern: Pattern; onClose: () => void }) {
  const logs = useQuery({
    queryKey: ['pattern-logs', pattern.id],
    queryFn: () => api.patterns.logs(pattern.id, { limit: 50 }),
  });
  const optMap = new Map(pattern.options.map((o) => [o.id, o.label]));

  return (
    <Modal open title={`История: ${pattern.title}`} onClose={onClose}>
      {logs.isLoading ? (
        <Spinner />
      ) : (logs.data ?? []).length === 0 ? (
        <p className="text-sm text-ink-muted">Ответов пока нет.</p>
      ) : (
        <ul className="max-h-96 space-y-2 overflow-auto text-sm">
          {(logs.data ?? []).map((log) => (
            <li key={log.id} className="rounded border border-border px-3 py-2">
              <div className="font-medium">
                {log.response_option_id
                  ? optMap.get(log.response_option_id) ?? '—'
                  : '—'}{' '}
                · {log.status}
              </div>
              <div className="text-xs text-ink-muted">
                {log.scheduled_at.slice(0, 10)}
                {log.answered_at && ` · ${log.answered_at.slice(0, 16).replace('T', ' ')}`}
              </div>
            </li>
          ))}
        </ul>
      )}
    </Modal>
  );
}

function MarkersCard({
  pattern,
  streak,
  onPicture,
  onEdit,
  onDelete,
}: {
  pattern: Pattern;
  streak?: PatternStreak;
  onPicture: () => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const qc = useQueryClient();
  const today = useQuery({
    queryKey: ['pattern-today', pattern.id],
    queryFn: () => api.patterns.today(pattern.id),
  });
  const markers = useQuery({
    queryKey: ['pattern-markers', pattern.id],
    queryFn: () => api.patterns.markers(pattern.id, 20),
  });
  const mini = useQuery({
    queryKey: ['pattern-insights', pattern.id, 7, 'all'],
    queryFn: () => api.patterns.insights(pattern.id, 7),
    staleTime: 30_000,
  });

  const addMut = useMutation({
    mutationFn: (optionId: number) =>
      api.patterns.addMarker(pattern.id, { marker_option_id: optionId }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['pattern-today', pattern.id] });
      qc.invalidateQueries({ queryKey: ['pattern-markers', pattern.id] });
      qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
      qc.invalidateQueries({ queryKey: ['pattern-insights', pattern.id] });
    },
  });

  const removeMut = useMutation({
    mutationFn: (markerId: number) => api.patterns.removeMarker(pattern.id, markerId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['pattern-today', pattern.id] });
      qc.invalidateQueries({ queryKey: ['pattern-markers', pattern.id] });
      qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
      qc.invalidateQueries({ queryKey: ['pattern-insights', pattern.id] });
    },
  });

  const t = today.data;
  const tone = todayTone(t?.is_success_today ?? null);
  const todayMarkers = (markers.data ?? []).filter(
    (m) => m.occurred_at.slice(0, 10) === t?.day,
  );

  return (
    <article className="card">
      <div className="card-body space-y-3">
        <CardHeader pattern={pattern} onEdit={onEdit} onDelete={onDelete} icon={MapPin} />

        {streak && (
          <div className={`rounded-lg border px-3 py-2 text-sm ${statBgClass(tone)}`}>
            <div className={`flex items-center gap-2 font-semibold ${statToneClass(tone)}`}>
              <MapPin size={16} />
              {streak.current_streak}{' '}
              <span className="font-normal text-ink-muted">
                {streakLabel(pattern.pattern_type, pattern.pattern_mode)}
              </span>
            </div>
            <div className="mt-1 text-xs text-ink-muted">
              за 30 д {rateLabel(streak.scheduled_days_30d, streak.success_days_30d)}
            </div>
          </div>
        )}

        <div className="rounded-lg border border-border px-3 py-2 text-sm">
          <div className="font-medium">Сегодня · {t?.markers_today_count ?? 0} отметок</div>
          {t?.last_marker_label && (
            <p className="text-xs text-ink-muted">
              Последняя: {t.last_marker_label}
              {t.last_marker_at && ` · ${t.last_marker_at.slice(11, 16)}`}
            </p>
          )}
          {t?.is_success_today === true && (
            <p className="text-emerald-600">Без негативных отметок</p>
          )}
          {t?.is_success_today === false && (
            <p className="text-red-600">Были негативные отметки</p>
          )}
        </div>

        <div className="flex flex-wrap gap-2">
          {pattern.options.map((opt) => (
            <button
              key={opt.id}
              type="button"
              className={`text-xs btn-secondary ${
                !opt.is_success ? 'border-red-500/40 text-red-700 dark:text-red-400' : ''
              }`}
              disabled={addMut.isPending || t?.is_scheduled_today === false}
              onClick={() => addMut.mutate(opt.id)}
            >
              + {opt.label}
            </button>
          ))}
        </div>

        {todayMarkers.length > 0 && (
          <ul className="max-h-32 space-y-1 overflow-y-auto text-xs">
            {todayMarkers.map((m) => (
              <li
                key={m.id}
                className={`flex items-center justify-between rounded px-2 py-1 ${
                  m.is_success ? 'bg-emerald-500/10' : 'bg-red-500/10'
                }`}
              >
                <span>
                  {m.occurred_at.slice(11, 16)} — {m.label}
                </span>
                <button
                  type="button"
                  className="btn-ghost px-1"
                  disabled={removeMut.isPending}
                  onClick={() => removeMut.mutate(m.id)}
                >
                  <Trash2 size={12} />
                </button>
              </li>
            ))}
          </ul>
        )}

        <ScheduleLine schedules={pattern.schedules} />
        {mini.data && <PatternDayStrip days={mini.data.calendar} compact />}
        <button type="button" className="btn-secondary w-full text-xs" onClick={onPicture}>
          <BarChart3 size={14} /> Картина
        </button>
      </div>
    </article>
  );
}

function ScenarioCard({
  pattern,
  streak,
  onOpen,
  onPicture,
  onEdit,
  onDelete,
}: {
  pattern: Pattern;
  streak?: PatternStreak;
  onOpen: () => void;
  onPicture: () => void;
  onDelete: () => void;
  onEdit: () => void;
}) {
  const mini = useQuery({
    queryKey: ['pattern-insights', pattern.id, 7],
    queryFn: () => api.patterns.insights(pattern.id, 7),
    staleTime: 60_000,
  });
  const today = useQuery({
    queryKey: ['pattern-today', pattern.id],
    queryFn: () => api.patterns.today(pattern.id),
  });
  const session = useQuery({
    queryKey: ['pattern-session', pattern.id],
    queryFn: () => api.patterns.sessionToday(pattern.id),
    retry: false,
  });

  const t = today.data;
  const sess = session.data;
  const tone = todayTone(t?.is_success_today ?? null);
  const progress =
    sess && pattern.steps.length
      ? `${sess.answered_count}/${pattern.steps.length}`
      : `0/${pattern.steps.length}`;

  return (
    <article className="card">
      <div className="card-body space-y-3">
        <CardHeader pattern={pattern} onEdit={onEdit} onDelete={onDelete} icon={MapIcon} />

        {pattern.guide_intro && (
          <p className="text-xs text-ink-muted line-clamp-2">{pattern.guide_intro}</p>
        )}

        {streak && (
          <div className={`rounded-lg border px-3 py-2 text-sm ${statBgClass(tone)}`}>
            <div className={`flex items-center gap-2 font-semibold ${statToneClass(tone)}`}>
              <Shield size={16} />
              {streak.current_streak}{' '}
              <span className="font-normal text-ink-muted">
                {streakLabel(pattern.pattern_type, pattern.pattern_mode)}
              </span>
            </div>
            <div className="mt-1 text-xs text-ink-muted">
              за 30 д {rateLabel(streak.scheduled_days_30d, streak.success_days_30d)}
            </div>
          </div>
        )}

        <div className="rounded-lg border border-border px-3 py-2 text-sm">
          <div className="font-medium">Сегодня · {progress} шагов</div>
          {t?.status === 'answered' && t.is_success_today === true && (
            <p className="text-emerald-600">Сценарий завершён — чистый день</p>
          )}
          {t?.status === 'answered' && t.is_success_today === false && (
            <p className="text-red-600">Сценарий завершён — был срыв</p>
          )}
          {t?.status === 'in_progress' && (
            <p className="text-amber-600">В процессе — продолжите прохождение</p>
          )}
          {t?.status === 'pending' && <p className="text-ink-muted">Ещё не начато сегодня</p>}
        </div>

        <button type="button" className="btn-primary w-full" onClick={onOpen}>
          {t?.status === 'in_progress' ? 'Продолжить сценарий' : 'Пройти сценарий'}
        </button>

        {mini.data && <PatternDayStrip days={mini.data.calendar} compact />}

        <button type="button" className="btn-secondary w-full text-xs" onClick={onPicture}>
          <BarChart3 size={14} /> Картина
        </button>

        <ScheduleLine schedules={pattern.schedules} />
      </div>
    </article>
  );
}

function CardHeader({
  pattern,
  onEdit,
  onDelete,
  icon: Icon,
}: {
  pattern: Pattern;
  onEdit: () => void;
  onDelete: () => void;
  icon: typeof Flame;
}) {
  return (
    <div className="flex items-start justify-between gap-2">
      <div>
        <h3 className="flex items-center gap-2 font-semibold">
          <Icon size={18} className="shrink-0 text-ink-muted" />
          {pattern.title}
        </h3>
        <p className="text-xs text-ink-muted">
          {PATTERN_MODE_LABEL[pattern.pattern_mode]} · {PATTERN_TYPE_LABEL[pattern.pattern_type]}
        </p>
      </div>
      <div className="flex gap-1">
        <button type="button" className="btn-ghost px-2" onClick={onEdit} title="Редактировать">
          <Pencil size={16} />
        </button>
        <button type="button" className="btn-ghost px-2" onClick={onDelete}>
          <Trash2 size={16} />
        </button>
      </div>
    </div>
  );
}

function TodayBlock({
  today,
}: {
  today?: {
    is_scheduled_today: boolean;
    status: string;
    response_label: string | null;
    is_success_today: boolean | null;
  };
}) {
  if (!today) return <Spinner />;
  return (
    <div className="rounded-lg border border-border px-3 py-2 text-sm">
      <div className="font-medium">Сегодня</div>
      {!today.is_scheduled_today ? (
        <p className="text-ink-muted">По расписанию сегодня не активно</p>
      ) : today.status === 'answered' && today.response_label ? (
        <p className={today.is_success_today ? 'text-emerald-600' : 'text-red-600'}>
          {today.is_success_today ? '✓' : '✗'} {today.response_label}
        </p>
      ) : today.status === 'missed' ? (
        <p className="text-red-600">Пропуск</p>
      ) : (
        <p className="text-ink-muted">Ещё не отмечено</p>
      )}
    </div>
  );
}

function ScheduleLine({ schedules }: { schedules: Pattern['schedules'] }) {
  return (
    <p className="text-xs text-ink-muted">Напоминания: {formatScheduleTimes(schedules)}</p>
  );
}

function isScenarioStepAnswered(
  step: PatternStep,
  answer?: PatternSession['answers'][0],
): boolean {
  if (!step.is_required) return true;
  if (step.step_kind === 'note') return Boolean(answer?.note_text?.trim());
  if (step.step_kind === 'check') return answer?.checked !== undefined && answer?.checked !== null;
  return Boolean(answer?.choice_id);
}

function ScenarioWizard({ pattern, onClose }: { pattern: Pattern; onClose: () => void }) {
  const qc = useQueryClient();
  const [stepIdx, setStepIdx] = useState(0);
  const [error, setError] = useState('');

  const sessionQ = useQuery({
    queryKey: ['pattern-session', pattern.id],
    queryFn: async () => {
      try {
        return await api.patterns.sessionToday(pattern.id);
      } catch {
        return api.patterns.startSessionToday(pattern.id);
      }
    },
  });

  const steps = [...pattern.steps].sort((a, b) => a.sort_order - b.sort_order);
  const step = steps[stepIdx];
  const sess = sessionQ.data;

  const answerMut = useMutation({
    mutationFn: (body: Record<string, unknown>) =>
      api.patterns.answerStep(pattern.id, sess!.id, step!.id, body),
    onSuccess: (data) => {
      qc.setQueryData(['pattern-session', pattern.id], data);
      setError('');
      if (stepIdx < steps.length - 1) setStepIdx((i) => i + 1);
    },
    onError: (e: Error) => setError(e.message),
  });

  const completeMut = useMutation({
    mutationFn: () => api.patterns.completeSession(pattern.id, sess!.id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['pattern-today', pattern.id] });
      qc.invalidateQueries({ queryKey: ['pattern-session', pattern.id] });
      qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
      onClose();
    },
    onError: (e: Error) => setError(e.message),
  });

  useEffect(() => {
    if (!sess || !steps.length) return;
    const answeredIds = new Set(sess.answers.map((a) => a.step_id));
    const firstOpen = steps.findIndex((s) => !answeredIds.has(s.id));
    if (firstOpen >= 0) setStepIdx(firstOpen);
  }, [sess?.id]);

  if (sessionQ.isLoading || !sess || !step) {
    return (
      <Modal open title={pattern.title} onClose={onClose}>
        <Spinner />
      </Modal>
    );
  }

  const currentAnswer = sess.answers.find((a) => a.step_id === step.id);
  const pct = Math.round(((stepIdx + 1) / steps.length) * 100);
  const stepAnswered = isScenarioStepAnswered(step, currentAnswer);
  const allRequiredDone = steps
    .filter((s) => s.is_required)
    .every((s) => isScenarioStepAnswered(s, sess.answers.find((a) => a.step_id === s.id)));

  return (
    <Modal open title={pattern.title} onClose={onClose}>
      <div className="space-y-4">
        {pattern.guide_intro && stepIdx === 0 && (
          <p className="rounded-lg bg-surface-3 p-3 text-sm text-ink-muted">{pattern.guide_intro}</p>
        )}
        {error && <ErrorBanner message={error} />}

        <div>
          <div className="mb-1 flex justify-between text-xs text-ink-muted">
            <span>
              Шаг {stepIdx + 1} из {steps.length} · {PATTERN_STEP_ROLE_LABEL[step.step_role]}
            </span>
            <span>{pct}%</span>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-surface-3">
            <div className="h-full bg-accent transition-all" style={{ width: `${pct}%` }} />
          </div>
        </div>

        <div>
          <h3 className="text-lg font-semibold">{step.title}</h3>
          {step.hint && <p className="mt-1 text-sm text-ink-muted">{step.hint}</p>}
        </div>

        <StepInput
          step={step}
          answer={currentAnswer}
          onSubmit={(body) => answerMut.mutate(body)}
          disabled={answerMut.isPending}
        />

        <div className="flex justify-between gap-2">
          <button
            type="button"
            className="btn-secondary"
            disabled={stepIdx === 0}
            onClick={() => setStepIdx((i) => i - 1)}
          >
            <ChevronLeft size={16} /> Назад
          </button>
          {stepIdx < steps.length - 1 ? (
            <button
              type="button"
              className="btn-primary"
              disabled={answerMut.isPending || !stepAnswered}
              onClick={() => setStepIdx((i) => i + 1)}
            >
              Далее <ChevronRight size={16} />
            </button>
          ) : (
            <button
              type="button"
              className="btn-primary"
              disabled={completeMut.isPending || !allRequiredDone}
              onClick={() => completeMut.mutate()}
            >
              Завершить день
            </button>
          )}
        </div>
      </div>
    </Modal>
  );
}

function StepInput({
  step,
  answer,
  onSubmit,
  disabled,
}: {
  step: PatternStep;
  answer?: PatternSession['answers'][0];
  onSubmit: (body: Record<string, unknown>) => void;
  disabled: boolean;
}) {
  if (step.step_kind === 'note') {
    return <NoteStepInput answer={answer} onSubmit={onSubmit} disabled={disabled} />;
  }

  if (step.step_kind === 'check') {
    return (
      <div className="flex gap-2">
        <button
          type="button"
          className={`btn-secondary flex-1 ${answer?.checked ? 'ring-2 ring-accent' : ''}`}
          disabled={disabled}
          onClick={() => onSubmit({ checked: true })}
        >
          Да, было
        </button>
        <button
          type="button"
          className={`btn-secondary flex-1 ${answer?.checked === false ? 'ring-2 ring-accent' : ''}`}
          disabled={disabled}
          onClick={() => onSubmit({ checked: false })}
        >
          Нет
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {step.choices.map((c) => {
        const selected = answer?.choice_id === c.id;
        const tone = c.is_success
          ? 'bg-emerald-600/15 border-emerald-600 text-emerald-700'
          : selected
            ? 'bg-red-600/10 border-border'
            : 'border-border';
        return (
          <button
            key={c.id}
            type="button"
            disabled={disabled}
            className={`w-full rounded-lg border px-3 py-2 text-left text-sm transition hover:border-accent/50 ${
              selected ? `ring-2 ring-accent ${tone}` : tone
            }`}
            onClick={() => onSubmit({ choice_id: c.id })}
          >
            {c.label}
          </button>
        );
      })}
    </div>
  );
}

function NoteStepInput({
  answer,
  onSubmit,
  disabled,
}: {
  answer?: PatternSession['answers'][0];
  onSubmit: (body: Record<string, unknown>) => void;
  disabled: boolean;
}) {
  const [text, setText] = useState(answer?.note_text ?? '');
  return (
    <div className="space-y-2">
      <textarea
        className="input min-h-24"
        value={text}
        onChange={(e) => setText(e.target.value)}
      />
      <button
        type="button"
        className="btn-secondary"
        disabled={disabled}
        onClick={() => onSubmit({ note_text: text })}
      >
        Сохранить
      </button>
    </div>
  );
}

function PatternCreateModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const qc = useQueryClient();
  const [mode, setMode] = useState<PatternMode>('habit');
  const [title, setTitle] = useState('');
  const [patternType, setPatternType] = useState<PatternType>('negative');
  const [guideIntro, setGuideIntro] = useState('');
  const [schedules, setSchedules] = useState<ScheduleRow[]>([
    { time: '09:00', dow_mask: 127 },
    { time: '21:00', dow_mask: 127 },
  ]);
  const [steps, setSteps] = useState<StepDraft[]>(() =>
    toStepDrafts(SCENARIO_TEMPLATES[0].steps),
  );
  const [autoCreateTask, setAutoCreateTask] = useState(false);
  const [error, setError] = useState('');

  const saveMut = useMutation({
    mutationFn: () => {
      const sch = schedulesToApi(schedules);
      if (mode === 'scenario') {
        const err = validateScenarioSteps(steps);
        if (err) throw new Error(err);
        return api.patterns.create({
          title,
          pattern_type: patternType,
          pattern_mode: 'scenario',
          guide_intro: guideIntro.trim() || null,
          schedules: sch,
          steps: toApiSteps(steps),
        });
      }
      if (mode === 'markers') {
        return api.patterns.create({
          title,
          pattern_type: patternType,
          pattern_mode: 'markers',
          schedules: sch,
        });
      }
      return api.patterns.create({
        title,
        pattern_type: patternType,
        pattern_mode: 'habit',
        is_boolean: true,
        auto_create_task: autoCreateTask,
        schedules: sch,
      });
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['patterns'] });
      qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
      onClose();
      setTitle('');
      setGuideIntro('');
      setSteps(toStepDrafts(SCENARIO_TEMPLATES[0].steps));
    },
    onError: (e: Error) => setError(e.message),
  });

  const isScenario = mode === 'scenario';

  return (
    <Modal open={open} title="Новый паттерн" onClose={onClose} wide={isScenario}>
      <form
        className="space-y-4"
        onSubmit={(e) => {
          e.preventDefault();
          saveMut.mutate();
        }}
      >
        {error && <ErrorBanner message={error} />}

        <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
          {(['habit', 'scenario', 'markers'] as PatternMode[]).map((m) => (
            <button
              key={m}
              type="button"
              className={`rounded-lg border p-3 text-left text-sm ${
                mode === m ? 'border-accent ring-1 ring-accent/40' : 'border-border'
              }`}
              onClick={() => setMode(m)}
            >
              <div className="font-semibold">{PATTERN_MODE_LABEL[m]}</div>
              <div className="mt-1 text-xs text-ink-muted">
                {m === 'habit' && 'Один ответ за день'}
                {m === 'scenario' && 'Цепочка шагов за день'}
                {m === 'markers' && 'Много отметок в течение дня'}
              </div>
            </button>
          ))}
        </div>

        <input
          className="input"
          placeholder={
            mode === 'scenario'
              ? 'Название сценария'
              : mode === 'markers'
                ? 'Название (например, Тяга к курению)'
                : 'Название привычки'
          }
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
        />

        <select
          className="select"
          value={patternType}
          onChange={(e) => setPatternType(e.target.value as PatternType)}
        >
          <option value="positive">Полезное поведение</option>
          <option value="negative">Отказ / абстиненция</option>
        </select>

        {isScenario && (
          <>
            <textarea
              className="input min-h-16"
              placeholder="Вступление путеводителя — зачем проходить этот сценарий"
              value={guideIntro}
              onChange={(e) => setGuideIntro(e.target.value)}
            />
            <ScenarioBuilder steps={steps} onChange={setSteps} patternType={patternType} />
          </>
        )}

        <ScheduleEditor rows={schedules} onChange={setSchedules} />

        {mode === 'habit' && (
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={autoCreateTask}
              onChange={(e) => setAutoCreateTask(e.target.checked)}
            />
            Создавать задачу при ответе на привычку
          </label>
        )}

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

function PatternEditModal({ pattern, onClose }: { pattern: Pattern; onClose: () => void }) {
  const qc = useQueryClient();
  const [title, setTitle] = useState(pattern.title);
  const [guideIntro, setGuideIntro] = useState(pattern.guide_intro ?? '');
  const [steps, setSteps] = useState<StepDraft[]>(() => fromPatternSteps(pattern.steps));
  const [schedules, setSchedules] = useState<ScheduleRow[]>(
    pattern.schedules.length
      ? pattern.schedules.map((s) => ({
          id: s.id,
          time: s.time_of_day.slice(0, 5),
          dow_mask: s.dow_mask,
        }))
      : [{ time: '09:00', dow_mask: 127 }],
  );
  const [error, setError] = useState('');
  const [autoCreateTask, setAutoCreateTask] = useState(pattern.auto_create_task);
  const [newOptionLabel, setNewOptionLabel] = useState('');
  const [newOptionSuccess, setNewOptionSuccess] = useState(true);
  const isScenario = pattern.pattern_mode === 'scenario';

  const addOptionMut = useMutation({
    mutationFn: () =>
      api.patterns.addOption(pattern.id, {
        label: newOptionLabel.trim(),
        is_success: newOptionSuccess,
        sort_order: pattern.options.length,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['patterns'] });
      setNewOptionLabel('');
    },
    onError: (e: Error) => setError(e.message),
  });

  const saveMut = useMutation({
    mutationFn: async () => {
      await api.patterns.update(pattern.id, {
        title,
        guide_intro: guideIntro.trim() || null,
        auto_create_task: autoCreateTask,
      });
      if (isScenario) {
        const err = validateScenarioSteps(steps);
        if (err) throw new Error(err);
        await api.patterns.replaceSteps(pattern.id, toApiSteps(steps));
      }
      const existingIds = new Set(pattern.schedules.map((s) => s.id));
      const keptIds = new Set<number>();
      for (const row of schedules) {
        const body = {
          time_of_day: `${row.time}:00`,
          dow_mask: row.dow_mask || 127,
        };
        if (row.id) {
          keptIds.add(row.id);
          await api.patterns.updateSchedule(pattern.id, row.id, body);
        } else {
          await api.patterns.addSchedule(pattern.id, body);
        }
      }
      for (const id of existingIds) {
        if (!keptIds.has(id)) await api.patterns.removeSchedule(pattern.id, id);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['patterns'] });
      qc.invalidateQueries({ queryKey: ['pattern-streaks'] });
      onClose();
    },
    onError: (e: Error) => setError(e.message),
  });

  return (
    <Modal open title="Настройки паттерна" onClose={onClose} wide={isScenario}>
      <form
        className="space-y-4"
        onSubmit={(e) => {
          e.preventDefault();
          saveMut.mutate();
        }}
      >
        {error && <ErrorBanner message={error} />}
        <input className="input" value={title} onChange={(e) => setTitle(e.target.value)} required />
        {isScenario && (
          <>
            <textarea
              className="input min-h-16"
              placeholder="Вступление путеводителя"
              value={guideIntro}
              onChange={(e) => setGuideIntro(e.target.value)}
            />
            <ScenarioBuilder
              steps={steps}
              onChange={setSteps}
              patternType={pattern.pattern_type}
            />
            <p className="text-xs text-amber-700 dark:text-amber-400">
              Изменение шагов не переписывает прошлые дни — только новые прохождения.
            </p>
          </>
        )}
        {!isScenario && (
          <div className="space-y-2">
            <div className="text-sm font-medium">Варианты ответа</div>
            <ul className="flex flex-wrap gap-2 text-sm">
              {pattern.options.map((o) => (
                <li key={o.id} className="badge bg-surface-3">
                  {o.label} {o.is_success ? '✓' : '✗'}
                </li>
              ))}
            </ul>
            <div className="flex flex-wrap gap-2">
              <input
                className="input flex-1"
                placeholder="Новый вариант"
                value={newOptionLabel}
                onChange={(e) => setNewOptionLabel(e.target.value)}
              />
              <label className="flex items-center gap-1 text-sm">
                <input
                  type="checkbox"
                  checked={newOptionSuccess}
                  onChange={(e) => setNewOptionSuccess(e.target.checked)}
                />
                успех
              </label>
              <button
                type="button"
                className="btn-secondary"
                disabled={!newOptionLabel.trim() || addOptionMut.isPending}
                onClick={() => addOptionMut.mutate()}
              >
                Добавить
              </button>
            </div>
          </div>
        )}
        {pattern.pattern_mode === 'habit' && (
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={autoCreateTask}
              onChange={(e) => setAutoCreateTask(e.target.checked)}
            />
            Создавать задачу при ответе
          </label>
        )}
        <ScheduleEditor rows={schedules} onChange={setSchedules} />
        <div className="flex justify-end gap-2">
          <button type="button" className="btn-secondary" onClick={onClose}>
            Отмена
          </button>
          <button type="submit" className="btn-primary" disabled={saveMut.isPending}>
            Сохранить
          </button>
        </div>
      </form>
    </Modal>
  );
}
