import { useState } from 'react';
import { ChevronDown, ChevronUp, Copy, GripVertical, Plus, Trash2 } from 'lucide-react';
import type { PatternStepKind, PatternStepRole, PatternType } from '@/api/types';
import { PATTERN_STEP_KIND_LABEL, PATTERN_STEP_ROLE_LABEL } from '@/lib/labels';
import { FormField } from '@/components/ui/form-field';
import {
  SCENARIO_TEMPLATES,
  blankStep,
  newClientId,
  setMarksSuccess,
  slugId,
  toStepDrafts,
  type StepDraft,
} from '@/lib/pattern-templates';

const STEP_ROLES: PatternStepRole[] = ['context', 'trigger', 'choice', 'action', 'outcome'];

type Props = {
  steps: StepDraft[];
  onChange: (steps: StepDraft[]) => void;
  patternType: PatternType;
};

export function ScenarioBuilder({ steps, onChange, patternType }: Props) {
  const [dragIndex, setDragIndex] = useState<number | null>(null);

  const applyTemplate = (templateId: string) => {
    const tpl = SCENARIO_TEMPLATES.find((t) => t.id === templateId);
    if (!tpl) return;
    onChange(toStepDrafts(tpl.steps));
  };

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-end gap-2">
        <FormField label="Стартовый шаблон" className="flex-1">
          <select
            className="select"
            defaultValue=""
            aria-label="Стартовый шаблон цепочки"
            onChange={(e) => {
              if (e.target.value) applyTemplate(e.target.value);
              e.target.value = '';
            }}
          >
            <option value="">Выберите шаблон…</option>
            {SCENARIO_TEMPLATES.map((t) => (
              <option key={t.id} value={t.id}>
                {t.label} — {t.description}
              </option>
            ))}
          </select>
        </FormField>
        <button
          type="button"
          className="btn-secondary shrink-0"
          onClick={() =>
            onChange([
              ...steps,
              { ...blankStep(), clientId: newClientId() },
            ])
          }
        >
          <Plus size={14} /> Шаг
        </button>
      </div>

      <p className="text-xs text-ink-muted">
        Тип паттерна: {patternType === 'negative' ? 'отказ' : 'полезное'}. Один шаг с ролью{' '}
        <strong>Итог</strong> или флагом «считает успех» определяет серию.
      </p>

      {steps.length === 0 ? (
        <p className="rounded-lg border border-dashed border-border p-4 text-center text-sm text-ink-muted">
          Нет шагов — добавьте вручную или выберите шаблон
        </p>
      ) : (
        <div className="space-y-3">
          {steps.map((step, index) => (
            <StepEditor
              key={step.clientId}
              step={step}
              index={index}
              total={steps.length}
              dragging={dragIndex === index}
              onDragStart={() => setDragIndex(index)}
              onDragOver={(e) => {
                e.preventDefault();
                if (dragIndex === null || dragIndex === index) return;
                onChange(reorder(steps, dragIndex, index));
                setDragIndex(index);
              }}
              onDragEnd={() => setDragIndex(null)}
              onChange={(next) =>
                onChange(steps.map((s) => (s.clientId === step.clientId ? next : s)))
              }
              onMove={(dir) => onChange(move(steps, step.clientId, dir))}
              onDuplicate={() =>
                onChange([
                  ...steps.slice(0, index + 1),
                  { ...step, clientId: newClientId(), title: `${step.title} (копия)` },
                  ...steps.slice(index + 1),
                ])
              }
              onRemove={() => onChange(steps.filter((s) => s.clientId !== step.clientId))}
              onMarksSuccess={(v) => onChange(setMarksSuccess(steps, step.clientId, v))}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function reorder(steps: StepDraft[], from: number, to: number): StepDraft[] {
  const copy = [...steps];
  const [item] = copy.splice(from, 1);
  copy.splice(to, 0, item);
  return copy;
}

function move(steps: StepDraft[], clientId: string, dir: -1 | 1): StepDraft[] {
  const idx = steps.findIndex((s) => s.clientId === clientId);
  if (idx < 0) return steps;
  const j = idx + dir;
  if (j < 0 || j >= steps.length) return steps;
  const copy = [...steps];
  [copy[idx], copy[j]] = [copy[j], copy[idx]];
  return copy;
}

function StepEditor({
  step,
  index,
  total,
  dragging,
  onDragStart,
  onDragOver,
  onDragEnd,
  onChange,
  onMove,
  onDuplicate,
  onRemove,
  onMarksSuccess,
}: {
  step: StepDraft;
  index: number;
  total: number;
  dragging: boolean;
  onDragStart: () => void;
  onDragOver: (e: React.DragEvent) => void;
  onDragEnd: () => void;
  onChange: (s: StepDraft) => void;
  onMove: (dir: -1 | 1) => void;
  onDuplicate: () => void;
  onRemove: () => void;
  onMarksSuccess: (v: boolean) => void;
}) {
  const showChoices = step.step_kind === 'single_choice';

  return (
    <div
      onDragOver={onDragOver}
      className={`rounded-lg border p-3 transition-opacity ${
        step.marks_success ? 'border-emerald-500/50 bg-emerald-500/5' : 'border-border'
      } ${dragging ? 'opacity-50' : ''}`}
    >
      <div
        draggable
        onDragStart={onDragStart}
        onDragEnd={onDragEnd}
        className="mb-2 flex cursor-grab items-center justify-between gap-2 active:cursor-grabbing"
      >
        <span className="flex items-center gap-1 text-xs font-medium text-ink-muted">
          <GripVertical size={14} className="text-ink-muted" />
          Шаг {index + 1}
          {step.marks_success && ' · итог серии'}
        </span>
        <div className="flex gap-1">
          <button type="button" className="btn-ghost px-1" disabled={index === 0} onClick={() => onMove(-1)}>
            <ChevronUp size={14} />
          </button>
          <button
            type="button"
            className="btn-ghost px-1"
            disabled={index >= total - 1}
            onClick={() => onMove(1)}
          >
            <ChevronDown size={14} />
          </button>
          <button type="button" className="btn-ghost px-1" onClick={onDuplicate}>
            <Copy size={14} />
          </button>
          <button type="button" className="btn-ghost px-1" onClick={onRemove}>
            <Trash2 size={14} />
          </button>
        </div>
      </div>

      <FormField label="Вопрос шага" className="mb-2">
        <input
          className="input"
          value={step.title}
          onChange={(e) => onChange({ ...step, title: e.target.value })}
        />
      </FormField>
      <FormField label="Подсказка" hint="Необязательно" className="mb-2">
        <input
          className="input text-sm"
          value={step.hint}
          onChange={(e) => onChange({ ...step, hint: e.target.value })}
        />
      </FormField>

      <div className="mb-2 grid gap-2 sm:grid-cols-2">
        <FormField label="Тип ответа">
          <select
            className="select text-sm"
            value={step.step_kind}
            onChange={(e) => {
              const kind = e.target.value as PatternStepKind;
              onChange({
                ...step,
                step_kind: kind,
                marks_success: kind === 'note' ? false : step.marks_success,
                choices:
                  kind === 'single_choice' && step.choices.length === 0
                    ? [
                        { id: slugId('1'), label: 'Вариант 1', is_success: false },
                        { id: slugId('2'), label: 'Вариант 2', is_success: false },
                      ]
                    : step.choices,
              });
            }}
          >
            {(Object.keys(PATTERN_STEP_KIND_LABEL) as PatternStepKind[]).map((k) => (
              <option key={k} value={k}>
                {PATTERN_STEP_KIND_LABEL[k]}
              </option>
            ))}
          </select>
        </FormField>
        <FormField label="Роль в цепочке">
          <select
            className="select text-sm"
            value={step.step_role}
            onChange={(e) =>
              onChange({
                ...step,
                step_role: e.target.value as PatternStepRole,
                marks_success: e.target.value === 'outcome' ? true : step.marks_success,
              })
            }
          >
            {STEP_ROLES.map((r) => (
              <option key={r} value={r}>
                {PATTERN_STEP_ROLE_LABEL[r]}
              </option>
            ))}
          </select>
        </FormField>
      </div>

      <div className="mb-2 flex flex-wrap gap-4 text-xs">
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={step.is_required}
            onChange={(e) => onChange({ ...step, is_required: e.target.checked })}
          />
          Обязательный
        </label>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={step.marks_success}
            onChange={(e) => onMarksSuccess(e.target.checked)}
          />
          Считает успех дня (итог)
        </label>
      </div>

      {showChoices && (
        <div className="space-y-2 rounded-md border border-border bg-surface-3/50 p-2">
          <p className="text-xs font-medium">Варианты ответа</p>
          {step.choices.map((c, ci) => (
            <div key={c.id || ci} className="flex flex-wrap items-center gap-2">
              <FormField label={`Вариант ${ci + 1}`} className="min-w-0 flex-1">
                <input
                  className="input text-sm"
                  value={c.label}
                  onChange={(e) => {
                    const choices = [...step.choices];
                    choices[ci] = { ...c, label: e.target.value };
                    onChange({ ...step, choices });
                  }}
                />
              </FormField>
              <label className="flex shrink-0 items-center gap-1 text-xs pt-5">
                <input
                  type="checkbox"
                  checked={c.is_success}
                  onChange={(e) => {
                    const choices = [...step.choices];
                    choices[ci] = { ...c, is_success: e.target.checked };
                    onChange({ ...step, choices });
                  }}
                />
                Успех дня
              </label>
              <button
                type="button"
                className="btn-ghost px-1"
                onClick={() =>
                  onChange({ ...step, choices: step.choices.filter((_, j) => j !== ci) })
                }
              >
                <Trash2 size={12} />
              </button>
            </div>
          ))}
          <button
            type="button"
            className="btn-secondary text-xs"
            onClick={() =>
              onChange({
                ...step,
                choices: [
                  ...step.choices,
                  { id: slugId('opt'), label: 'Новый вариант', is_success: false },
                ],
              })
            }
          >
            + Вариант
          </button>
        </div>
      )}
    </div>
  );
}
