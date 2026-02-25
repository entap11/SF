export function formatDateUtc(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function parseDateStrict(input: string): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input)) {
    throw new Error(`invalid date: ${input}`);
  }
  const parsed = new Date(`${input}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`invalid date: ${input}`);
  }
  return parsed;
}

export function addDays(dateInput: string, days: number): string {
  const date = parseDateStrict(dateInput);
  date.setUTCDate(date.getUTCDate() + days);
  return formatDateUtc(date);
}

export function todayUtc(): string {
  return formatDateUtc(new Date());
}

export function yesterdayUtc(): string {
  return addDays(todayUtc(), -1);
}
