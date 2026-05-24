import { DOW_LABELS, dowArrayFromMask, dowMaskFromArray } from '@/lib/pattern-templates';

export type RecurrenceFreq = 'daily' | 'weekly' | 'monthly';

export type RecurringDraft = {
  enabled: boolean;
  frequency: RecurrenceFreq;
  weeklyMask: number;
  monthlyDay: number;
  isActive: boolean;
};

export const DEFAULT_RECURRING_DRAFT: RecurringDraft = {
  enabled: false,
  frequency: 'weekly',
  weeklyMask: 127,
  monthlyDay: 1,
  isActive: true,
};

export function recurringDraftFromRule(rule: {
  frequency: RecurrenceFreq | 'custom';
  params: Record<string, unknown>;
  is_active: boolean;
}): RecurringDraft {
  const freq = rule.frequency === 'custom' ? 'daily' : rule.frequency;
  return {
    enabled: true,
    frequency: freq,
    weeklyMask: Number(rule.params.weekly_mask ?? 127),
    monthlyDay: Number(rule.params.monthly_day ?? 1),
    isActive: rule.is_active,
  };
}

export function recurringDraftToApi(draft: RecurringDraft) {
  const params: Record<string, number> = {};
  if (draft.frequency === 'weekly') params.weekly_mask = draft.weeklyMask || 127;
  if (draft.frequency === 'monthly') params.monthly_day = draft.monthlyDay || 1;
  return {
    frequency: draft.frequency,
    params,
    is_active: draft.isActive,
  };
}

type Props = {
  value: RecurringDraft;
  onChange: (value: RecurringDraft) => void;
  allowDisable?: boolean;
};

export function RecurringEditor({ value, onChange, allowDisable = true }: Props) {
  const set = (patch: Partial<RecurringDraft>) => onChange({ ...value, ...patch });
  const days = dowArrayFromMask(value.weeklyMask);

  return (
    <div className="space-y-3 rounded-lg border border-border p-3">
      <label className="flex items-center gap-2 text-sm font-medium">
        <input
          type="checkbox"
          checked={value.enabled}
          onChange={(e) => set({ enabled: e.target.checked })}
          disabled={!allowDisable && value.enabled}
        />
        Повторяющаяся задача
      </label>

      {value.enabled && (
        <>
          <label className="block text-sm">
            <span className="mb-1 block text-ink-muted">Частота</span>
            <select
              className="select"
              value={value.frequency}
              onChange={(e) => set({ frequency: e.target.value as RecurrenceFreq })}
            >
              <option value="daily">Каждый день</option>
              <option value="weekly">По дням недели</option>
              <option value="monthly">Ежемесячно</option>
            </select>
          </label>

          {value.frequency === 'weekly' && (
            <div>
              <div className="mb-1 text-xs text-ink-muted">Дни недели</div>
              <div className="flex flex-wrap gap-1">
                {DOW_LABELS.map((label, i) => (
                  <button
                    key={label}
                    type="button"
                    className={`rounded px-2 py-0.5 text-xs ${
                      days[i] ? 'bg-accent text-white' : 'bg-surface-3 text-ink-muted'
                    }`}
                    onClick={() => {
                      const nextDays = [...days];
                      nextDays[i] = !nextDays[i];
                      set({ weeklyMask: dowMaskFromArray(nextDays) || 127 });
                    }}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
          )}

          {value.frequency === 'monthly' && (
            <label className="block text-sm">
              <span className="mb-1 block text-ink-muted">День месяца</span>
              <input
                type="number"
                className="input"
                min={1}
                max={31}
                value={value.monthlyDay}
                onChange={(e) => set({ monthlyDay: Number(e.target.value) || 1 })}
              />
            </label>
          )}

          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={value.isActive}
              onChange={(e) => set({ isActive: e.target.checked })}
            />
            Повторение активно
          </label>
          <p className="text-xs text-ink-muted">
            После выполнения создаётся следующий экземпляр по правилу.
          </p>
        </>
      )}
    </div>
  );
}
