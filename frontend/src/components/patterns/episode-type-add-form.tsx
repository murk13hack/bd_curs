import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { Plus } from 'lucide-react';
import { api } from '@/api/client';
import type { PatternOption, PatternType } from '@/api/types';
import { FormField } from '@/components/ui/form-field';
import { ErrorBanner } from '@/components/ui/primitives';

/** Пояснение к галочке «Успех дня» для типов эпизодов и вариантов ответа. */
export const EPISODE_SUCCESS_HINT =
  'Поддерживающий эпизод не портит день (серия «без негатива» сохраняется). Негативный — учитывается как срыв или тяга.';

type Props = {
  patternId: number;
  patternType: PatternType;
  optionsCount: number;
  onAdded: (option: PatternOption) => void;
  compact?: boolean;
};

export function EpisodeTypeSuccessField({
  checked,
  onChange,
  id = 'episode-success',
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  id?: string;
}) {
  return (
    <div className="min-w-[10rem] max-w-xs space-y-0.5">
      <label htmlFor={id} className="flex cursor-pointer items-center gap-2 text-sm">
        <input
          id={id}
          type="checkbox"
          checked={checked}
          onChange={(e) => onChange(e.target.checked)}
        />
        Успех дня
      </label>
      <p className="text-[10px] leading-snug text-ink-muted">{EPISODE_SUCCESS_HINT}</p>
    </div>
  );
}

export function EpisodeTypeAddForm({
  patternId,
  patternType,
  optionsCount,
  onAdded,
  compact = false,
}: Props) {
  const [label, setLabel] = useState('');
  const [isSuccess, setIsSuccess] = useState(patternType === 'positive');
  const [error, setError] = useState('');

  const addMut = useMutation({
    mutationFn: () =>
      api.patterns.addOption(patternId, {
        label: label.trim(),
        is_success: isSuccess,
        sort_order: optionsCount,
      }),
    onSuccess: (opt) => {
      onAdded(opt as PatternOption);
      setLabel('');
      setError('');
      setIsSuccess(patternType === 'positive');
    },
    onError: (e: Error) => setError(e.message),
  });

  return (
    <div
      className={`space-y-2 rounded-lg border border-dashed border-indigo-500/35 bg-indigo-500/5 ${
        compact ? 'p-2' : 'p-3'
      }`}
    >
      <p className={`font-medium text-ink-muted ${compact ? 'text-[10px]' : 'text-xs'}`}>
        Новый тип эпизода
      </p>
      {error && <ErrorBanner message={error} />}
      <div className={`flex flex-wrap gap-2 ${compact ? 'items-start' : 'items-end'}`}>
        <FormField label="Название" className="min-w-0 flex-1">
          <input
            className="input text-sm"
            value={label}
            placeholder="Например: тяга, прогулка"
            onChange={(e) => setLabel(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && label.trim()) {
                e.preventDefault();
                addMut.mutate();
              }
            }}
          />
        </FormField>
        <EpisodeTypeSuccessField
          checked={isSuccess}
          onChange={setIsSuccess}
          id={`episode-success-${patternId}`}
        />
        <button
          type="button"
          className={`btn-secondary shrink-0 ${compact ? 'text-xs' : ''}`}
          disabled={!label.trim() || addMut.isPending}
          onClick={() => addMut.mutate()}
        >
          <Plus size={14} className="inline mr-1" />
          Добавить
        </button>
      </div>
    </div>
  );
}
