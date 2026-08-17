export type ReportLocator =
  | { kind: 'warcraft-logs'; code: string; isAnonymous: boolean }
  | { kind: 'local'; id: string };

export const isLocalLocator = (
  locator: ReportLocator | undefined,
): locator is Extract<ReportLocator, { kind: 'local' }> => locator?.kind === 'local';
