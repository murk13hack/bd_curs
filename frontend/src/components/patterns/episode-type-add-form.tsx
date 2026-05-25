import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { Plus } from 'lucide-react';
import { api } from '@/api/client';
import type { PatternOption, PatternType } from '@/api/types';
import { FormField } from '@/components/ui/form-field';
import { ErrorBanner } from '@/components/ui/primitives';

/** Пояснение к галочке «Поддерживающий» / «Успех дня». */
export const EPISODE_SUCCESS_HINT =
  'Поддерживающий эпизод не портит день (серия «без негатива» сохраняется). Негативный — учитывается как срыв или тяга.';

type Props = {
  patternId: number;
  patternType: PatternType;
  optionsCount: number;
  onAdded: (option: PatternOption) => void;
  /** В модалке «Новый эпизод» — колонка, без налезания блоков. */
  layout?: 'row' | 'stack';
};

export function EpisodeTypeSuccessField({
  checked,
  onChange,
  id = 'episode-success',
  layout = 'row',
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  id?: string;
  layout?: 'row' | 'stack';
}) {
  const label = layout === 'stack' ? 'Поддерживающий эпизод' : 'Успех дня';

  return (
    <div className={layout === 'stack' ? 'w-full space-y-1' : 'min-w-0 max-w-full space-y-0.5'}>
      <label htmlFor={id} className="flex cursor-pointer items-start gap-2 text-sm">
        <input
          id={id}
          type="checkbox"
          className="mt-0.5 shrink-0"
          checked={checked}
          onChange={(e) => onChange(e.target.checked)}
        />
        <span>{label}</span>
      </label>
      <p
        className={
          layout === 'stack'
            ? 'text-xs leading-relaxed text-ink-muted pl-6'
            : 'text-[10px] leading-snug text-ink-muted'
        }
      >
        {EPISODE_SUCCESS_HINT}
      </p>
    </div>
  );
}

export function EpisodeTypeAddForm({
  patternId,
  patternType,
  optionsCount,
  onAdded,
  layout = 'row',
}: Props) {
  const [label, setLabel] = useState('');
  const [isSuccess, setIsSuccess] = useState(patternType === 'positive');
  const [error, setError] = useState('');
  const stacked = layout === 'stack';

  const addMut = useMutation({
    mutationFn: () =>
      api.patterns.addOption(patternId, {
        label: label.trim(),
        is_success: isSuccess,
        sort_order: optionsCount,
      }),
    onSuccess: (opt) => {
      onAdded(opt);
      setLabel('');
      setError('');
      setIsSuccess(patternType === 'positive');
    },
    onError: (e: Error) => setError(e.message),
  });

  const handleAdd = () => {
    if (!label.trim()) return;
    addMut.mutate();
  };

  return (
    <div
      className={`space-y-3 rounded-lg border border-dashed border-indigo-500/35 bg-indigo-500/5 p-3 ${
        stacked ? 'w-full' : ''
      }`}
    >
      <p className="text-xs font-medium text-ink-muted">Новый тип эпизода</p>
      {error && <ErrorBanner message={error} />}
      {stacked ? (
        <div className="flex w-full min-w-0 flex-col gap-3">
          <FormField label="Название" className="w-full">
            <input
              className="input w-full text-sm"
              value={label}
              placeholder="Например: тяга, прогулка"
              onChange={(e) => setLabel(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  handleAdd();
                }
              }}
            />
          </FormField>
          <EpisodeTypeSuccessField
            checked={isSuccess}
            onChange={setIsSuccess}
            id={`episode-success-${patternId}`}
            layout="stack"
          />
          <button
            type="button"
            className="btn-secondary w-full text-sm"
            disabled={!label.trim() || addMut.isPending}
            onClick={handleAdd}
          >
            <Plus size={14} className="inline mr-1" />
            {addMut.isPending ? 'Сохранение…' : 'Добавить тип'}
          </button>
        </div>
      ) : (
        <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end">
          <FormField label="Название" className="min-w-0 flex-1 sm:min-w-[12rem]">
            <input
              className="input w-full text-sm"
              value={label}
              placeholder="Например: тяга, прогулка"
              onChange={(e) => setLabel(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  handleAdd();
                }
              }}
            />
          </FormField>
          <EpisodeTypeSuccessField
            checked={isSuccess}
            onChange={setIsSuccess}
            id={`episode-success-${patternId}`}
            layout="row"
          />
          <button
            type="button"
            className="btn-secondary w-full shrink-0 sm:w-auto"
            disabled={!label.trim() || addMut.isPending}
            onClick={handleAdd}
          >
            <Plus size={14} className="inline mr-1" />
            {addMut.isPending ? '…' : 'Добавить'}
          </button>
        </div>
      )}
    </div>
  );
}
