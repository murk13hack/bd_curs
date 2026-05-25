import { Bell, X } from 'lucide-react';
import { usePatternNotifications } from '@/hooks/use-pattern-notifications';
import { notificationBody } from '@/lib/pattern-notifications';
import { PATTERN_MODE_LABEL } from '@/lib/labels';

export function NotificationHost() {
  const { toasts, dismissToast, openPattern } = usePatternNotifications();

  if (!toasts.length) return null;

  return (
    <div
      className="fixed bottom-20 right-4 z-50 flex max-w-sm flex-col gap-2 md:bottom-6"
      aria-live="polite"
    >
      {toasts.map((t) => (
        <div
          key={t.id}
          className="card shadow-lg border-l-4 border-l-accent"
        >
          <div className="card-body flex gap-2 p-3">
            <Bell size={18} className="shrink-0 text-accent mt-0.5" />
            <div className="min-w-0 flex-1">
              <p className="text-sm font-semibold">{t.patternTitle}</p>
              <p className="text-xs text-ink-muted">
                {t.scheduleTime} · {PATTERN_MODE_LABEL[t.patternMode]}
              </p>
              <p className="mt-1 text-xs">{notificationBody(t.patternMode)}</p>
              <button
                type="button"
                className="btn-primary mt-2 text-xs"
                onClick={() => openPattern(t)}
              >
                Открыть паттерны
              </button>
            </div>
            <button
              type="button"
              className="btn-ghost shrink-0 self-start px-1"
              aria-label="Закрыть"
              onClick={() => dismissToast(t.id)}
            >
              <X size={14} />
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
