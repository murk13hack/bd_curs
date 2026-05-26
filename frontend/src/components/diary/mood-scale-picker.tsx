import {
  ENERGY_LABEL,
  ENERGY_LEVEL_COLOR,
  ENERGY_EMOJI,
  MOOD_LABEL,
  MOOD_LEVEL_COLOR,
  MOOD_EMOJI,
} from '@/lib/labels';

type ScaleKind = 'mood' | 'energy';

const SCALE = {
  mood: { emojis: MOOD_EMOJI, labels: MOOD_LABEL, colors: MOOD_LEVEL_COLOR },
  energy: { emojis: ENERGY_EMOJI, labels: ENERGY_LABEL, colors: ENERGY_LEVEL_COLOR },
} as const;

export function MoodScalePicker({
  kind,
  label,
  value,
  onChange,
}: {
  kind: ScaleKind;
  label: string;
  value: number | '';
  onChange: (v: number | '') => void;
}) {
  const { emojis, labels, colors } = SCALE[kind];

  return (
    <div>
      <div className="mb-2 text-sm font-medium">{label}</div>
      <div className="grid grid-cols-5 gap-1.5 sm:gap-2">
        {([1, 2, 3, 4, 5] as const).map((n) => {
          const selected = value === n;
          const accent = colors[n];
          return (
            <button
              key={n}
              type="button"
              className={`flex flex-col items-center gap-0.5 rounded-xl border-2 px-1 py-2 transition sm:py-2.5 ${
                selected ? 'scale-[1.02] shadow-sm' : 'border-border bg-surface hover:bg-surface-3'
              }`}
              style={
                selected
                  ? {
                      borderColor: accent,
                      backgroundColor: `${accent}22`,
                    }
                  : undefined
              }
              onClick={() => onChange(selected ? '' : n)}
              aria-pressed={selected}
              aria-label={`${labels[n]}, ${n} из 5`}
            >
              <span className="text-xl leading-none sm:text-2xl" aria-hidden>
                {emojis[n]}
              </span>
              <span
                className={`max-w-full truncate text-center text-[9px] leading-tight sm:text-[10px] ${
                  selected ? 'font-medium text-ink' : 'text-ink-muted'
                }`}
              >
                {labels[n]}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
