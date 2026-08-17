import type CharacterProfile from 'parser/core/CharacterProfile';
import type { AnyEvent } from 'parser/core/Events';
import type { PlayerDetails } from 'parser/core/Player';
import type Report from 'parser/core/Report';
import { getLocalEvents, getLocalReport } from './localReportStore';
import type { AnalysisDataSource, EventQuery, ReportCapabilities } from './AnalysisDataSource';
import { UnsupportedReportCapabilityError } from './AnalysisDataSource';
import type { ReportLocator } from './ReportLocator';

export class LocalCombatLogDataSource implements AnalysisDataSource {
  readonly capabilities: ReportCapabilities = {
    refresh: false,
    characterProfiles: false,
    aggregateTables: false,
    rankings: false,
    externalWclLinks: false,
    metricsUpload: false,
  };
  constructor(readonly locator: Extract<ReportLocator, { kind: 'local' }>) {}
  async loadReport(): Promise<Report> {
    const manifest = await getLocalReport(this.locator.id);
    if (!manifest || manifest.status !== 'ready')
      throw new Error('Local report is unavailable; import the file again.');
    return manifest.report;
  }
  async loadPlayers(fightId: number): Promise<PlayerDetails[]> {
    const manifest = await getLocalReport(this.locator.id);
    if (!manifest || manifest.status !== 'ready')
      throw new Error('Local report is unavailable; import the file again.');
    return manifest.players[fightId] ?? [];
  }
  loadEvents(query: EventQuery): Promise<AnyEvent[]> {
    return getLocalEvents(this.locator.id, query.fightId, query.start, query.end, query.actorId);
  }
  loadCharacterProfile(): Promise<CharacterProfile | null> {
    return Promise.resolve(null);
  }
  loadTable<T>(): Promise<T> {
    return Promise.reject(new UnsupportedReportCapabilityError('aggregateTables'));
  }
}
