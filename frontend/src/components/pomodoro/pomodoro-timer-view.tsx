import { Pause, Play, RotateCcw, SkipForward } from 'lucide-react';
import { usePomodoro } from '@/context/pomodoro-context';
import { ErrorBanner } from '@/components/ui/primitives';
import {
  formatPomodoroClock,
  POMODORO_PHASE_LABEL,
  pomodoroProgress,
} from '@/lib/pomodoro-timer';

function sessionTaskLabel(taskId: number | null, taskTitle: string, phase: string): string {
  if (taskTitle) return taskTitle;
  if (taskId != null) return 'Задача';
  if (phase !== 'idle') return 'Без задачи — время не сохраняется';
  return '';
}

export function PomodoroTimerView({ compact = false }: { compact?: boolean }) {
  const p = usePomodoro();
  const progress = pomodoroProgress(p.totalSec, p.remainingSec);
  const taskLabel = sessionTaskLabel(p.taskId, p.taskTitle, p.phase);

  return (
    <div className={`flex flex-col items-center gap-4 ${compact ? 'py-2' : 'py-6'}`}>
      {!compact && (
        <div className="text-sm font-medium text-ink-muted">{POMODORO_PHASE_LABEL[p.phase]}</div>
      )}

      <div
        className={`relative flex items-center justify-center ${compact ? 'h-24 w-24' : 'h-48 w-48'}`}
      >
        <svg className="absolute inset-0 -rotate-90" viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="45" fill="none" stroke="currentColor" strokeOpacity={0.1} strokeWidth="6" />
          <circle
            cx="50"
            cy="50"
            r="45"
            fill="none"
            stroke="currentColor"
            className="text-accent"
            strokeWidth={compact ? 5 : 6}
            strokeLinecap="round"
            strokeDasharray={`${progress * 2.827} 282.7`}
          />
        </svg>
        <div className={`font-bold tabular-nums ${compact ? 'text-2xl' : 'text-5xl'}`}>
          {formatPomodoroClock(p.remainingSec)}
        </div>
      </div>

      {compact && (
        <div className="text-center text-[10px] font-medium text-ink-muted">
          {POMODORO_PHASE_LABEL[p.phase]}
        </div>
      )}

      {taskLabel && (
        <p
          className={`max-w-full truncate text-center ${compact ? 'text-[10px]' : 'text-sm'} ${
            p.taskId ? 'text-ink' : 'text-ink-muted'
          }`}
        >
          {taskLabel}
        </p>
      )}

      {p.notice && !compact && (
        <div className="w-full">
          <ErrorBanner message={p.notice} />
          <button type="button" className="btn-ghost mt-1 w-full text-xs" onClick={p.clearNotice}>
            Закрыть
          </button>
        </div>
      )}

      <div className={`flex flex-wrap justify-center gap-2 ${compact ? 'w-full' : ''}`}>
        {p.phase === 'idle' ? (
          <button
            type="button"
            className={compact ? 'btn-primary w-full text-xs' : 'btn-primary'}
            onClick={() => p.start(p.taskId ?? undefined, p.taskTitle || undefined)}
          >
            <Play size={16} /> Старт
          </button>
        ) : p.running ? (
          <button type="button" className={compact ? 'btn-secondary flex-1 text-xs' : 'btn-secondary'} onClick={p.pause}>
            <Pause size={16} /> Пауза
          </button>
        ) : (
          <button type="button" className={compact ? 'btn-primary flex-1 text-xs' : 'btn-primary'} onClick={p.resume}>
            <Play size={16} /> Продолжить
          </button>
        )}
        {p.phase !== 'idle' && (
          <>
            <button type="button" className={compact ? 'btn-secondary flex-1 text-xs' : 'btn-secondary'} onClick={p.skip}>
              <SkipForward size={16} />
              {!compact && ' Пропустить'}
            </button>
            <button type="button" className={compact ? 'btn-ghost text-xs' : 'btn-ghost'} onClick={p.reset}>
              <RotateCcw size={16} />
              {!compact && ' Сброс'}
            </button>
          </>
        )}
      </div>

      {!compact && p.phase !== 'idle' && (
        <p className="text-xs text-ink-muted">
          Циклов: {p.cycles}
          {p.phase === 'work' && (
            <>
              {' '}
              · сессия {Math.floor(p.workFocusedSec / 60)}:
              {(p.workFocusedSec % 60).toString().padStart(2, '0')}
              {p.taskId != null && p.taskFocusedSec > 0 && (
                <>
                  {' '}
                  · в задачу {Math.floor(p.taskFocusedSec / 60)}:
                  {(p.taskFocusedSec % 60).toString().padStart(2, '0')}
                </>
              )}
            </>
          )}
        </p>
      )}
    </div>
  );
}
