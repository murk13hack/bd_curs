import { Link } from 'react-router-dom';
import type { DiaryInsights } from '@/api/types';
import { Spinner } from '@/components/ui/primitives';

export function StatsConnectionsTeaser({
  data,
  loading,
  onOpenTab,
}: {
  data?: DiaryInsights;
  loading: boolean;
  onOpenTab: () => void;
}) {
  const hasDiary = (data?.diary_days ?? 0) > 0;

  return (
    <section className="card lg:col-span-2">
      <div className="card-body flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="min-w-0">
          <h2 className="text-base font-semibold">Связи показателей</h2>
          {loading ? (
            <div className="mt-2 flex items-center gap-2 text-sm text-ink-muted">
              <Spinner /> Загрузка…
            </div>
          ) : hasDiary && data!.insights[0] ? (
            <p className="mt-1 text-sm text-ink">{data!.insights[0]}</p>
          ) : (
            <p className="mt-1 text-sm text-ink-muted">
              Заполните{' '}
              <Link to="/diary" className="text-accent underline-offset-2 hover:underline">
                дневник
              </Link>{' '}
              — появятся выводы о настроении и делах.
            </p>
          )}
        </div>
        <button type="button" className="btn-secondary shrink-0 text-sm" onClick={onOpenTab}>
          Подробнее
        </button>
      </div>
    </section>
  );
}
