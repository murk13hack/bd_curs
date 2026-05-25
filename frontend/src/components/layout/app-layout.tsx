import { Outlet } from 'react-router-dom';
import { NotificationHost } from '@/components/notifications/notification-host';
import { MobileNav, Sidebar } from '@/components/layout/sidebar';
import { useTheme } from '@/hooks/use-theme';

export function AppLayout() {
  useTheme();

  return (
    <div className="flex min-h-screen">
      <div className="hidden md:block">
        <Sidebar />
      </div>
      <div className="flex min-h-screen flex-1 flex-col">
        <main className="flex-1 overflow-auto p-4 md:p-6 lg:p-8">
          <Outlet />
        </main>
        <MobileNav />
        <NotificationHost />
      </div>
    </div>
  );
}
