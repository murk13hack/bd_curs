import { useEffect, useId, useState } from 'react';
import { FormField } from '@/components/ui/form-field';

/** Палитра без системного color-picker — не уезжает за экран. */
export const PRESET_COLORS = [
  '#3B82F6',
  '#6366F1',
  '#8B5CF6',
  '#A855F7',
  '#EC4899',
  '#EF4444',
  '#F97316',
  '#EAB308',
  '#22C55E',
  '#14B8A6',
  '#06B6D4',
  '#64748B',
] as const;

function normalizeHex(raw: string): string | null {
  let v = raw.trim();
  if (!v) return null;
  if (!v.startsWith('#')) v = `#${v}`;
  if (/^#[0-9A-Fa-f]{6}$/.test(v)) return v.toUpperCase();
  return null;
}

type Props = {
  label?: string;
  value: string;
  onChange: (hex: string) => void;
  hint?: string;
};

export function ColorField({ label = 'Цвет', value, onChange, hint }: Props) {
  const id = useId();
  const [draft, setDraft] = useState(value);

  useEffect(() => {
    setDraft(value);
  }, [value]);

  const applyDraft = () => {
    const n = normalizeHex(draft);
    if (n) {
      onChange(n);
      setDraft(n);
    } else {
      setDraft(value);
    }
  };

  return (
    <FormField
      label={label}
      htmlFor={id}
      hint={hint ?? 'Выберите образец или введите код #RRGGBB'}
      className="w-full min-w-0"
    >
      <div
        className="flex flex-wrap gap-1.5"
        role="listbox"
        aria-label="Палитра цветов"
      >
        {PRESET_COLORS.map((c) => {
          const selected = value.toUpperCase() === c;
          return (
            <button
              key={c}
              type="button"
              role="option"
              aria-selected={selected}
              title={c}
              className={`h-8 w-8 shrink-0 rounded-md border-2 transition ${
                selected
                  ? 'border-accent ring-2 ring-accent/40 scale-110'
                  : 'border-border hover:scale-105'
              }`}
              style={{ backgroundColor: c }}
              onClick={() => {
                onChange(c);
                setDraft(c);
              }}
            />
          );
        })}
      </div>
      <div className="mt-2 flex min-w-0 items-center gap-2">
        <span
          className="h-10 w-10 shrink-0 rounded-lg border border-border shadow-inner"
          style={{ backgroundColor: normalizeHex(value) ?? value }}
          aria-hidden
        />
        <input
          id={id}
          className="input min-w-0 flex-1 font-mono text-sm"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onBlur={applyDraft}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              applyDraft();
            }
          }}
          placeholder="#3B82F6"
          spellCheck={false}
          maxLength={7}
        />
      </div>
    </FormField>
  );
}
