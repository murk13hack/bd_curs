import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/api/client';
import { Spinner } from '@/components/ui/primitives';
import { fmtDateTime, minutesLabel } from '@/lib/format';
import { confirmDelete } from '@/lib/confirm';

export function TaskTimeLogsPanel({ taskId }: { taskId: number }) {
  const qc = useQueryClient();
  const logs = useQuery({
    queryKey: ['task-time-logs', taskId],
    queryFn: () => api.tasks.timeLogs(taskId),
  });

  const removeMut = useMutation({
    mutationFn: (logId: number) => api.tasks.removeTimeLog(taskId, logId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['task-time-logs', taskId] });
      qc.invalidateQueries({ queryKey: ['stats'] });
      qc.invalidateQueries({ queryKey: ['stats-time'] });
    },
  });

  const totalSec = (logs.data ?? []).reduce((s, l) => s + l.duration_seconds, 0);
  const pomoSec = (logs.data ?? [])
    .filter((l) => l.is_pomodoro)
    .reduce((s, l) => s + l.duration_seconds, 0);

  if (logs.isLoading) return <Spinner />;

  return (
    <div>
      <div className="mb-2 flex flex-wrap gap-3 text-xs text-ink-muted">
        <span>Всего: {minutesLabel(Math.round(totalSec / 60))}</span>
        {pomoSec > 0 && <span>Pomodoro: {minutesLabel(Math.round(pomoSec / 60))}</span>}
      </div>
      {(logs.data ?? []).length === 0 ? (
        <p className="text-sm text-ink-muted">Учтённого времени пока нет. Запустите фокус с этой задачей.</p>
      ) : (
        <ul className="max-h-40 space-y-1 overflow-y-auto text-sm">
          {(logs.data ?? []).map((log) => (
            <li
              key={log.id}
              className="flex items-center justify-between gap-2 rounded border border-border px-2 py-1.5"
            >
              <div className="min-w-0">
                <div className="text-xs text-ink-muted">
                  {fmtDateTime(log.started_at)} — {fmtDateTime(log.ended_at)}
                </div>
                <div>
                  {minutesLabel(Math.round(log.duration_seconds / 60))}
                  {log.is_pomodoro && (
                    <span className="ml-1 rounded bg-accent/15 px-1 text-[10px] text-accent">фокус</span>
                  )}
                </div>
              </div>
              <button
                type="button"
                className="btn-ghost shrink-0 px-2 text-xs text-ink-muted hover:text-red-600"
                disabled={removeMut.isPending}
                onClick={() => {
                  if (confirmDelete('запись времени')) removeMut.mutate(log.id);
                }}
              >
                Удалить
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
