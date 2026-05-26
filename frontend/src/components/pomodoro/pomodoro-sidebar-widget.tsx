import { Link } from 'react-router-dom';
import { Plus } from 'lucide-react';
import { usePomodoro } from '@/context/pomodoro-context';
import { formatPomodoroClock, POMODORO_MAX_SESSIONS, POMODORO_PHASE_LABEL } from '@/lib/pomodoro-timer';

export function PomodoroSidebarWidget() {
  const p = usePomodoro();
  const running = p.sessions.filter((s) => s.running);

  return (
    <div className="border-t border-border p-3 space-y-2">
      <div className="flex items-center justify-between gap-1">
        <span className="text-xs font-medium text-ink-muted">
          Фокус {p.sessions.length}/{POMODORO_MAX_SESSIONS}
        </span>
        <Link to="/pomodoro" className="text-[10px] text-accent hover:underline">
          все →
        </Link>
      </div>

      {p.sessions.length === 0 ? (
        <button
          type="button"
          className="btn-secondary w-full text-xs"
          onClick={() => p.createSession()}
        >
          <Plus size={14} className="inline" /> Таймер
        </button>
      ) : (
        <ul className="max-h-32 space-y-1 overflow-y-auto">
          {p.sessions.slice(0, 5).map((s) => (
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
          {p.sessions.length > 5 && (
            <li className="text-center text-[10px] text-ink-muted">+{p.sessions.length - 5} ещё</li>
          )}
        </ul>
      )}

      {p.canAddSession && (
        <button type="button" className="btn-secondary w-full text-xs" onClick={() => p.createSession()}>
          <Plus size={12} className="inline" /> Ещё таймер
        </button>
      )}

      {p.notice && (
        <p className="text-[10px] leading-tight text-red-600" title={p.notice}>
          {p.notice.length > 48 ? `${p.notice.slice(0, 48)}…` : p.notice}
        </p>
      )}

      {running.length > 0 && (
        <p className="text-[10px] text-ink-muted">{running.length} идут сейчас</p>
      )}
    </div>
  );
}
