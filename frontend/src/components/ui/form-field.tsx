import type { ReactNode } from 'react';

type FormFieldProps = {
  label: string;
  children: ReactNode;
  hint?: string;
  className?: string;
  htmlFor?: string;
};

/** Подпись над полем ввода или выбора */
export function FormField({ label, hint, children, className = '', htmlFor }: FormFieldProps) {
  return (
    <div className={className}>
      <label
        htmlFor={htmlFor}
        className="mb-1 block text-xs font-medium text-ink-muted"
      >
        {label}
      </label>
      {children}
      {hint ? <p className="mt-1 text-xs text-ink-muted">{hint}</p> : null}
    </div>
  );
}

type FieldGroupProps = {
  legend: string;
  children: ReactNode;
  className?: string;
};

/** Группа связанных переключателей (период, вкладки фильтров) */
export function FieldGroup({ legend, children, className = '' }: FieldGroupProps) {
  return (
    <fieldset className={`min-w-0 border-0 p-0 ${className}`}>
      <legend className="mb-1.5 block text-xs font-medium text-ink-muted">{legend}</legend>
      {children}
    </fieldset>
  );
}
