import { fetchCombatants, fetchEvents, fetchFights, fetchTable } from 'common/fetchWclApi';
import type CharacterProfile from 'parser/core/CharacterProfile';
import type { AnyEvent } from 'parser/core/Events';
import type { PlayerDetails } from 'parser/core/Player';
import type Report from 'parser/core/Report';
import type {
  AnalysisDataSource,
  EventQuery,
  ReportTableQuery,
  ReportCapabilities,
} from './AnalysisDataSource';
import type { ReportLocator } from './ReportLocator';

export class WarcraftLogsDataSource implements AnalysisDataSource {
  readonly capabilities: ReportCapabilities = {
    refresh: true,
    characterProfiles: true,
    aggregateTables: true,
    rankings: true,
    externalWclLinks: true,
    metricsUpload: true,
  };
  constructor(readonly locator: Extract<ReportLocator, { kind: 'warcraft-logs' }>) {}
  async loadReport(options?: { refresh?: boolean }): Promise<Report> {
    const report = await fetchFights(this.locator.code, options?.refresh);
    return {
      ...report,
      code: this.locator.code,
      isAnonymous: this.locator.isAnonymous,
      locator: this.locator,
    };
  }
  async loadPlayers(fightId: number): Promise<PlayerDetails[]> {
    const response = await fetch(`/api/v2/report/${this.locator.code}/fight/${fightId}/players`);
    return (await response.json()).players;
  }
  loadEvents(query: EventQuery): Promise<AnyEvent[]> {
    return fetchEvents(this.locator.code, query.start ?? 0, query.end ?? 0, query.actorId);
  }
  async loadCharacterProfile(): Promise<CharacterProfile | null> {
    return null;
  }
  loadTable<T>(query: ReportTableQuery): Promise<T> {
    return fetchTable(
      this.locator.code,
      query.fightId,
      query.fightId,
      query.name as never,
      query.sourceId,
    ) as Promise<T>;
  }
  loadCombatants(start: number, end: number) {
    return fetchCombatants(this.locator.code, start, end);
  }
}
