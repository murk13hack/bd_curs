import type { ReactNode } from 'react';
import { Label } from 'recharts';

const LABEL_STYLE = { fontSize: 11, fill: 'var(--ink-muted, #6b7280)' };

/** Отступы под подписи осей (не перекрывают подпись снизу карточки). */
export function statsChartMargin(opts?: {
  left?: number;
  right?: number;
  bottom?: number;
  top?: number;
}) {
  return {
    top: opts?.top ?? 12,
    right: opts?.right ?? 28,
    bottom: opts?.bottom ?? 40,
    left: opts?.left ?? 52,
  };
}

export function AxisLabelX({ value }: { value: string }) {
  return (
    <Label
      value={value}
      offset={-4}
      position="insideBottom"
      style={{ ...LABEL_STYLE, textAnchor: 'middle' }}
    />
  );
}

export function AxisLabelYLeft({ value }: { value: string }) {
  return (
    <Label
      value={value}
      angle={-90}
      position="insideLeft"
      offset={14}
      style={{ ...LABEL_STYLE, textAnchor: 'middle' }}
    />
  );
}

export function AxisLabelYRight({ value }: { value: string }) {
  return (
    <Label
      value={value}
      angle={90}
      position="insideRight"
      offset={14}
      style={{ ...LABEL_STYLE, textAnchor: 'middle' }}
    />
  );
}

/** Пояснение под графиком — вне ResponsiveContainer, не ломает вёрстку. */
export function ChartCaption({ children }: { children: ReactNode }) {
  return (
    <p className="mt-3 border-t border-border/60 pt-3 text-xs leading-relaxed text-ink-muted">
      {children}
    </p>
  );
}
