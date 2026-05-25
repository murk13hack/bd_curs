import { Link } from 'react-router-dom';
import type { DiaryInsights } from '@/api/types';
import { Spinner } from '@/components/ui/primitives';
export function StatsConnectionsTeaser({
  data,
  loading,
  periodLabel,
  onOpenTab,
}: {
  data?: DiaryInsights;
  loading: boolean;
  periodLabel: string;
  onOpenTab: () => void;
}) {
  const moodTasks = data?.corr_mood_tasks;
  const hasDiary = (data?.diary_days ?? 0) > 0;

  return (
    <section className="card lg:col-span-2">
      <div className="card-body space-y-3">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div className="min-w-0 space-y-1">
            <h2 className="text-base font-semibold">Связи показателей</h2>
            <p className="text-sm text-ink-muted">
              За {periodLabel}: насколько <strong className="text-ink">настроение и энергия из дневника</strong>{' '}
              совпадают с выполнением задач и успехом паттернов. Это не привязки задач к{' '}
              <Link to="/goals" className="text-accent underline-offset-2 hover:underline">
                целям
              </Link>
              .
            </p>
          </div>
          <button type="button" className="btn-primary shrink-0 text-sm" onClick={onOpenTab}>
            Открыть раздел «Связи»
          </button>
        </div>

        {loading ? (
          <div className="flex items-center gap-2 text-sm text-ink-muted">
            <Spinner /> Загрузка…
          </div>
        ) : hasDiary ? (
          <div className="rounded-lg border border-border bg-surface-2/80 px-4 py-3 space-y-2">
            {data!.insights[0] && (
              <p className="text-sm text-ink">{data!.insights[0]}</p>
            )}
            <div className="flex flex-wrap gap-4 text-xs text-ink-muted">
              <span>
                Дней с дневником: <strong className="text-ink">{data!.diary_days}</strong>
              </span>
              <span>
                Настроение → задачи:{' '}
                <strong className="text-ink">
                  {moodTasks != null ? `r = ${moodTasks.toFixed(2)}` : '—'}
                </strong>
              </span>
              {data!.corr_mood_patterns != null && (
                <span>
                  Настроение → паттерны:{' '}
                  <strong className="text-ink">r = {data!.corr_mood_patterns.toFixed(2)}</strong>
                </span>
              )}
            </div>
            <p className="text-[11px] text-ink-muted">
              Подробные графики, сравнение по уровню настроения и разбивка по неделям — во вкладке
              «Связи показателей».
            </p>
          </div>
        ) : (
          <p className="text-sm text-ink-muted">
            За выбранный период нет записей дневника с настроением. Заполните{' '}
            <Link to="/diary" className="text-accent underline-offset-2 hover:underline">
              дневник
            </Link>{' '}
            — тогда здесь и во вкладке «Связи» появятся выводы.
          </p>
        )}
      </div>
    </section>
  );
}
