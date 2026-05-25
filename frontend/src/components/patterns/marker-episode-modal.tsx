import { useState } from 'react';
import type { Pattern, PatternOption } from '@/api/types';
import { Modal, ErrorBanner } from '@/components/ui/primitives';
import { FormField } from '@/components/ui/form-field';

type Props = {
  pattern: Pattern;
  open: boolean;
  onClose: () => void;
  onSubmit: (optionId: number, note: string) => void;
  pending?: boolean;
  error?: string;
};

export function MarkerEpisodeModal({
  pattern,
  open,
  onClose,
  onSubmit,
  pending,
  error,
}: Props) {
  const negative = pattern.options.filter((o) => !o.is_success);
  const positive = pattern.options.filter((o) => o.is_success);
  const [selected, setSelected] = useState<PatternOption | null>(null);
  const [note, setNote] = useState('');

  const reset = () => {
    setSelected(null);
    setNote('');
  };

  return (
    <Modal
      open={open}
      title="Новый эпизод"
      onClose={() => {
        reset();
        onClose();
      }}
    >
      <div className="space-y-4">
        <p className="text-sm text-ink-muted">
          Зафиксируйте момент в течение дня — время подставится автоматически.
        </p>
        {error && <ErrorBanner message={error} />}

        {negative.length > 0 && (
          <section>
            <h4 className="mb-2 text-xs font-semibold uppercase tracking-wide text-red-600">
              Негативные
            </h4>
            <OptionGrid
              options={negative}
              selected={selected}
              onSelect={setSelected}
              tone="bad"
            />
          </section>
        )}

        {positive.length > 0 && (
          <section>
            <h4 className="mb-2 text-xs font-semibold uppercase tracking-wide text-emerald-600">
              Поддерживающие
            </h4>
            <OptionGrid
              options={positive}
              selected={selected}
              onSelect={setSelected}
              tone="good"
            />
          </section>
        )}

        <FormField label="Заметка" hint="Необязательно">
          <textarea
            className="input min-h-16"
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
        </FormField>

        <div className="flex justify-end gap-2">
          <button type="button" className="btn-secondary" onClick={onClose}>
            Отмена
          </button>
          <button
            type="button"
            className="btn-primary"
            disabled={!selected || pending}
            onClick={() => {
              if (selected) onSubmit(selected.id, note.trim());
              reset();
            }}
          >
            Сохранить эпизод
          </button>
        </div>
      </div>
    </Modal>
  );
}

function OptionGrid({
  options,
  selected,
  onSelect,
  tone,
}: {
  options: PatternOption[];
  selected: PatternOption | null;
  onSelect: (o: PatternOption) => void;
  tone: 'bad' | 'good';
}) {
  return (
    <div className="grid gap-2 sm:grid-cols-2">
      {options.map((o) => {
        const active = selected?.id === o.id;
        const base =
          tone === 'bad'
            ? 'border-red-500/40 hover:border-red-500'
            : 'border-emerald-500/40 hover:border-emerald-500';
        const activeRing = tone === 'bad' ? 'ring-red-500' : 'ring-emerald-500';
        return (
          <button
            key={o.id}
            type="button"
            className={`rounded-lg border px-3 py-2 text-left text-sm transition ${base} ${
              active ? `ring-2 ${activeRing}` : ''
            }`}
            onClick={() => onSelect(o)}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
