export function confirmDelete(label = 'эту запись'): boolean {
  return window.confirm(`Удалить ${label}? Это действие нельзя отменить.`);
}
