import type CharacterProfile from 'parser/core/CharacterProfile';
import type { AnyEvent } from 'parser/core/Events';
import type { PlayerDetails } from 'parser/core/Player';
import type Report from 'parser/core/Report';
import type { ReportLocator } from './ReportLocator';

export interface EventQuery {
  fightId: number;
  start?: number;
  end?: number;
  actorId?: number;
}

export interface ReportTableQuery {
  fightId: number;
  name: string;
  sourceId?: number;
}

export interface ReportCapabilities {
  refresh: boolean;
  characterProfiles: boolean;
  aggregateTables: boolean;
  rankings: boolean;
  externalWclLinks: boolean;
  metricsUpload: boolean;
}

export class UnsupportedReportCapabilityError extends Error {
  readonly capability: keyof ReportCapabilities;
  constructor(capability: keyof ReportCapabilities) {
    super(`This report does not provide the ${capability} capability.`);
    this.name = 'UnsupportedReportCapabilityError';
    this.capability = capability;
  }
}

export interface AnalysisDataSource {
  readonly locator: ReportLocator;
  readonly capabilities: ReportCapabilities;
  loadReport(options?: { refresh?: boolean }): Promise<Report>;
  loadPlayers(fightId: number): Promise<PlayerDetails[]>;
  loadEvents(query: EventQuery): Promise<AnyEvent[]>;
  loadCharacterProfile(player: PlayerDetails): Promise<CharacterProfile | null>;
  loadTable<T>(query: ReportTableQuery): Promise<T>;
}
