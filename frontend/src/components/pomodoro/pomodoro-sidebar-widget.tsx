import { Link } from 'react-router-dom';
import { usePomodoro } from '@/context/pomodoro-context';
import { formatPomodoroClock, POMODORO_MAX_SESSIONS, POMODORO_PHASE_LABEL } from '@/lib/pomodoro-timer';

export function PomodoroSidebarWidget() {
  const p = usePomodoro();

  return (
    <div className="border-t border-border p-3">
      <Link
        to="/pomodoro"
        className="mb-2 flex items-center justify-between rounded-lg border border-border bg-surface px-3 py-2 text-sm transition hover:border-accent/40"
      >
        <span className="font-medium">Фокус</span>
        <span className="text-xs text-ink-muted">
          {p.sessions.length}/{POMODORO_MAX_SESSIONS}
        </span>
      </Link>

      {p.sessions.length > 0 && (
        <ul className="max-h-36 space-y-1 overflow-y-auto">
          {p.sessions.map((s) => (
            <li key={s.id} className="rounded border border-border/80 px-2 py-1 text-[10px]">
              <div className="truncate font-medium">{s.taskTitle || 'Без задачи'}</div>
              <div className="flex justify-between text-ink-muted">
                <span>{POMODORO_PHASE_LABEL[s.phase]}</span>
                <span className="tabular-nums font-semibold text-ink">
                  {formatPomodoroClock(s.remainingSec)}
                </span>
              </div>
            </li>
          ))}
        </ul>
      )}

      {p.notice && (
        <p className="mt-2 text-[10px] leading-tight text-red-600" title={p.notice}>
          {p.notice.length > 48 ? `${p.notice.slice(0, 48)}…` : p.notice}
        </p>
      )}
    </div>
  );
}
