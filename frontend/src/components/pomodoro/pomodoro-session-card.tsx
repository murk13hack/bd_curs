import { Pause, Play, RotateCcw, SkipForward, X } from 'lucide-react';
import { usePomodoro } from '@/context/pomodoro-context';
import type { PomodoroSession } from '@/lib/pomodoro-timer';
import {
  formatPomodoroClock,
  POMODORO_PHASE_LABEL,
  pomodoroProgress,
} from '@/lib/pomodoro-timer';

function taskLabel(session: PomodoroSession): string {
  if (session.taskTitle) return session.taskTitle;
  if (session.taskId != null) return 'Задача';
  return 'Без задачи';
}

export function PomodoroSessionCard({ session }: { session: PomodoroSession }) {
  const p = usePomodoro();
  const progress = pomodoroProgress(session.totalSec, session.remainingSec);

  return (
    <article className="card">
      <div className="card-body space-y-3">
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0">
            <div className="text-xs font-medium text-ink-muted">
              {POMODORO_PHASE_LABEL[session.phase]}
            </div>
            <h3 className="truncate font-semibold">{taskLabel(session)}</h3>
          </div>
          <button
            type="button"
            className="btn-ghost shrink-0 p-1"
            title="Закрыть таймер"
            onClick={() => p.reset(session.id)}
          >
            <X size={16} />
          </button>
        </div>

        <div className="relative mx-auto flex h-28 w-28 items-center justify-center">
          <svg className="absolute inset-0 -rotate-90" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="45" fill="none" stroke="currentColor" strokeOpacity={0.1} strokeWidth="6" />
            <circle
              cx="50"
              cy="50"
              r="45"
              fill="none"
              stroke="currentColor"
              className="text-accent"
              strokeWidth="6"
              strokeLinecap="round"
              strokeDasharray={`${progress * 2.827} 282.7`}
            />
          </svg>
          <span className="text-3xl font-bold tabular-nums">{formatPomodoroClock(session.remainingSec)}</span>
        </div>

        <p className="text-center text-[10px] text-ink-muted">
          Цикл {session.cycles}
          {session.phase === 'work' && session.taskId != null && session.taskFocusedSec > 0 && (
            <>
              {' '}
              · в задачу {Math.floor(session.taskFocusedSec / 60)}:
              {(session.taskFocusedSec % 60).toString().padStart(2, '0')}
            </>
          )}
        </p>

        <div className="flex flex-wrap justify-center gap-1.5">
          {session.running ? (
            <button type="button" className="btn-secondary text-xs" onClick={() => p.pause(session.id)}>
              <Pause size={14} /> Пауза
            </button>
          ) : (
            <button type="button" className="btn-primary text-xs" onClick={() => p.resume(session.id)}>
              <Play size={14} /> Продолжить
            </button>
          )}
          <button type="button" className="btn-secondary text-xs" onClick={() => p.skip(session.id)}>
            <SkipForward size={14} />
          </button>
          <button type="button" className="btn-ghost text-xs" onClick={() => p.reset(session.id)}>
            <RotateCcw size={14} />
          </button>
        </div>
      </div>
    </article>
  );
}
