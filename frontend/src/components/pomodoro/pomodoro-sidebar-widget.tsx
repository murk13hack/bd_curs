import { Link } from 'react-router-dom';
import { Pause, Play, RotateCcw } from 'lucide-react';
import { usePomodoro } from '@/context/pomodoro-context';
import { formatPomodoroClock, POMODORO_PHASE_LABEL } from '@/lib/pomodoro-timer';

export function PomodoroSidebarWidget() {
  const p = usePomodoro();
  const active = p.phase !== 'idle';

  if (!active) {
    return (
      <div className="border-t border-border p-3">
        <Link
          to="/pomodoro"
          className="flex items-center justify-between gap-2 rounded-lg border border-border bg-surface px-3 py-2 text-sm transition hover:border-accent/40"
        >
          <span className="font-medium">Фокус</span>
          <span className="text-xs text-ink-muted">Pomodoro →</span>
        </Link>
      </div>
    );
  }

  return (
    <div className="border-t border-border p-3">
      <div className="mb-1 flex items-center justify-between gap-1">
        <span className="text-xs font-medium text-ink-muted">{POMODORO_PHASE_LABEL[p.phase]}</span>
        <Link to="/pomodoro" className="text-[10px] text-accent hover:underline">
          подробнее
        </Link>
      </div>
      <div className="text-center text-2xl font-bold tabular-nums">{formatPomodoroClock(p.remainingSec)}</div>
      {p.taskTitle && (
        <p className="mt-0.5 truncate text-center text-[10px] text-ink-muted">{p.taskTitle}</p>
      )}
      {p.notice && (
        <p className="mt-1 text-[10px] leading-tight text-red-600" title={p.notice}>
          {p.notice.length > 56 ? `${p.notice.slice(0, 56)}…` : p.notice}
        </p>
      )}
      <div className="mt-2 flex gap-1">
        {p.running ? (
          <button type="button" className="btn-secondary flex-1 px-2 py-1 text-xs" onClick={p.pause}>
            <Pause size={14} className="mx-auto" />
          </button>
        ) : (
          <button type="button" className="btn-primary flex-1 px-2 py-1 text-xs" onClick={p.resume}>
            <Play size={14} className="mx-auto" />
          </button>
        )}
        <button type="button" className="btn-ghost px-2 py-1 text-xs" onClick={p.reset} title="Сброс">
          <RotateCcw size={14} />
        </button>
      </div>
    </div>
  );
}
