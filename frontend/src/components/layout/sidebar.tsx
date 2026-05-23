import { NavLink } from 'react-router-dom';
import {
  BarChart3,
  BookOpen,
  Calendar,
  CheckSquare,
  LayoutDashboard,
  Repeat,
  Settings,
  Target,
  Timer,
} from 'lucide-react';
import { NAV_ITEMS } from '@/lib/labels';

const ICONS = {
  LayoutDashboard,
  CheckSquare,
  BookOpen,
  Repeat,
  Calendar,
  BarChart3,
  Target,
  Timer,
  Settings,
} as const;

export function Sidebar() {
  return (
    <aside className="flex h-full w-64 shrink-0 flex-col border-r border-border bg-surface-2">
      <div className="border-b border-border px-5 py-5">
        <div className="text-lg font-bold tracking-tight">ПТТ</div>
        <div className="text-xs text-ink-muted">Персональный таск-трекер</div>
      </div>
      <nav className="flex-1 space-y-1 p-3">
        {NAV_ITEMS.map((item) => {
          const Icon = ICONS[item.icon];
          return (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-accent-soft text-accent'
                    : 'text-ink-muted hover:bg-surface-3 hover:text-ink'
                }`
              }
            >
              <Icon size={18} />
              {item.label}
            </NavLink>
          );
        })}
      </nav>
      <div className="border-t border-border p-4 text-xs text-ink-muted">
        Курсовая · БД · UNN
      </div>
    </aside>
  );
}

export function MobileNav() {
  return (
    <nav className="flex gap-1 overflow-x-auto border-t border-border bg-surface-2 p-2 md:hidden">
      {NAV_ITEMS.slice(0, 6).map((item) => {
        const Icon = ICONS[item.icon];
        return (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            className={({ isActive }) =>
              `flex min-w-[4.5rem] flex-col items-center gap-1 rounded-lg px-2 py-2 text-[10px] ${
                isActive ? 'text-accent' : 'text-ink-muted'
              }`
            }
          >
            <Icon size={18} />
            {item.label}
          </NavLink>
        );
      })}
    </nav>
  );
}
