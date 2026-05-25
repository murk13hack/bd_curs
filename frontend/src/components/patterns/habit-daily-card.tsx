import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { BarChart3, CheckCircle2, ChevronDown, ChevronUp, Flame, Shield } from 'lucide-react';
import { api } from '@/api/client';
import type { Pattern, PatternStreak } from '@/api/types';
import { PatternDayStrip } from '@/components/patterns/pattern-day-strip';
import { rateLabel, streakLabel, todayDateOnly, todayTone } from '@/lib/pattern-templates';
import { PATTERN_TYPE_LABEL } from '@/lib/labels';

type CardShellProps = {
  pattern: Pattern;
  streak?: PatternStreak;
  tone: 'good' | 'bad' | 'pending';
  icon: typeof Flame;
  children: React.ReactNode;
  footer: React.ReactNode;
};

export function HabitCardShell({
  pattern,
  streak,
  tone,
  icon: Icon,
  children,
  footer,
}: CardShellProps) {
  return (
    <article className="card border-l-4 border-l-amber-500/80">
      <div className="card-body space-y-3">
        <div className="flex items-start justify-between gap-2">
          <div>
            <span className="mb-1 inline-block rounded-full bg-amber-500/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-800 dark:text-amber-200">
              Итог дня
            </span>
            <h3 className="flex items-center gap-2 font-semibold">
              <Icon size={18} className="shrink-0 text-ink-muted" />
              {pattern.title}
            </h3>
            <p className="text-xs text-ink-muted">
              Привычка · {PATTERN_TYPE_LABEL[pattern.pattern_type]}
            </p>
          </div>
          <div className="flex gap-1">{footer}</div>
        </div>

        {streak && (
          <div
            className={`rounded-lg border px-3 py-2 text-sm ${
              tone === 'good'
                ? 'bg-emerald-500/10 border-emerald-500/30'
                : tone === 'bad'
                  ? 'bg-red-500/10 border-red-500/30'
                  : 'bg-amber-500/10 border-amber-500/30'
            }`}
          >
            <div
              className={`flex items-center gap-2 font-semibold ${
                tone === 'good'
                  ? 'text-emerald-600'
                  : tone === 'bad'
                    ? 'text-red-600'
                    : 'text-amber-600'
              }`}
            >
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

        {children}
      </div>
    </article>
  );
}

type Props = {
  pattern: Pattern;
  streak?: PatternStreak;
  onPicture: () => void;
  onLogs: () => void;
  headerActions: React.ReactNode;
};

export function HabitDailyCard({
  pattern,
  streak,
  onPicture,
  onLogs,
  headerActions,
}: Props) {
  const qc = useQueryClient();
  const [expanded, setExpanded] = useState(false);
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
      setExpanded(false);
    },
  });

  const t = today.data;
  const tone = todayTone(t?.is_success_today, t?.status);
  const Icon = pattern.pattern_type === 'negative' ? Shield : Flame;
  const answered = t?.status === 'answered' && t.response_label;
  const canAnswer =
    t?.is_scheduled_today && t.can_respond && t.status !== 'missed';

  return (
    <HabitCardShell
      pattern={pattern}
      streak={streak}
      tone={tone}
      icon={Icon}
      footer={headerActions}
    >
      <div className="rounded-lg border border-amber-500/25 bg-amber-500/5 px-3 py-3 text-sm">
        <p className="text-xs text-ink-muted mb-2">
          Один ответ в конце дня — как прошёл день в целом.
        </p>
        {!t?.is_scheduled_today ? (
          <p className="text-ink-muted">По расписанию сегодня не активно</p>
        ) : answered ? (
          <div className="flex items-start justify-between gap-2">
            <div className="flex items-center gap-2">
              <CheckCircle2
                size={18}
                className={t.is_success_today ? 'text-emerald-600' : 'text-red-600'}
              />
              <div>
                <div className="font-medium">Итог: {t.response_label}</div>
                <div
                  className={`text-xs ${t.is_success_today ? 'text-emerald-600' : 'text-red-600'}`}
                >
                  {t.is_success_today ? 'Успешный день' : 'Срыв'}
                </div>
              </div>
            </div>
            {canAnswer && (
              <button
                type="button"
                className="btn-ghost text-xs"
                onClick={() => setExpanded((v) => !v)}
              >
                Изменить {expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
              </button>
            )}
          </div>
        ) : t?.status === 'missed' || t?.log_status === 'missed' ? (
          <p className="text-red-600">Пропуск — ответ не получен в срок</p>
        ) : t?.log_status === 'pending' ? (
          <p className="text-amber-700 dark:text-amber-300">Ожидает ваш итог за сегодня</p>
        ) : (
          <p className="text-ink-muted">Итог ещё не отмечен</p>
        )}

        {canAnswer && (!answered || expanded) && (
          <div className="mt-3 space-y-2">
            <p className="text-xs font-medium">Выберите итог дня</p>
            <div className="flex flex-wrap gap-2">
              {pattern.options.map((opt) => {
                const selected = t?.response_option_id === opt.id;
                return (
                  <button
                    key={opt.id}
                    type="button"
                    className={`text-sm px-3 py-2 rounded-lg border transition ${
                      selected
                        ? opt.is_success
                          ? 'bg-emerald-600 text-white border-emerald-600'
                          : 'bg-red-600 text-white border-red-600'
                        : 'btn-secondary'
                    }`}
                    disabled={respondMut.isPending}
                    onClick={() => respondMut.mutate(opt.id)}
                  >
                    {opt.label}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {canAnswer && !answered && !expanded && (
          <button
            type="button"
            className="btn-primary mt-3 w-full"
            onClick={() => setExpanded(true)}
          >
            Отметить итог дня
          </button>
        )}
      </div>

      {mini.data && <PatternDayStrip days={mini.data.calendar} compact />}

      <div className="flex gap-2">
        <button type="button" className="btn-secondary flex-1 text-xs" onClick={onPicture}>
          <BarChart3 size={14} /> Картина
        </button>
        <button type="button" className="btn-secondary flex-1 text-xs" onClick={onLogs}>
          История итогов
        </button>
      </div>
    </HabitCardShell>
  );
}
