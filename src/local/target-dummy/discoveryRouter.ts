import {
  decodeCombatLogLine,
  findNewestCombatLogSessionRange,
  LocalCombatLogDiscovery,
  readCombatLogLines,
  type CombatLogSourceRange,
} from '../LocalCombatLogParser';
import type { TargetDummyDiscoveryRoute } from './contracts';
import { TargetDummyActorDiscovery } from './discovery';

interface ActiveEncounterEnvelope {
  readonly encounterId: string;
  hasCombatantInfo: boolean;
}

/**
 * Feeds encounter and target-dummy discovery from the same decoded-record
 * stream, then applies genuine-encounter precedence at end of file.
 */
export class TargetDummyDiscoveryRouter {
  readonly #encounterDiscovery = new LocalCombatLogDiscovery();
  readonly #targetDummyDiscovery = new TargetDummyActorDiscovery();
  #activeEncounter: ActiveEncounterEnvelope | undefined;
  #hasUsableEncounter = false;
  #lastLine = 0;
  #wowVersion: string | undefined;

  consume(fields: string[], line: number): void {
    this.#lastLine = line;
    if ((fields[0] === 'COMBAT_LOG_VERSION' ? fields[0] : fields[1]) === 'COMBAT_LOG_VERSION') {
      this.#wowVersion = fields.find((value) => /^\d+\.\d+\.\d+$/u.test(value));
    }
    this.#targetDummyDiscovery.consume(fields);
    this.#observeEncounterEnvelope(fields);
    this.#encounterDiscovery.line(fields, line);
  }

  finish(
    sourceRange: CombatLogSourceRange = { startByte: 0, endByte: Number.MAX_SAFE_INTEGER },
  ): TargetDummyDiscoveryRoute {
    this.#encounterDiscovery.validateVersion();
    const targetDummyDiscovery = this.#targetDummyDiscovery.finish();

    if (this.#hasUsableEncounter) {
      this.#encounterDiscovery.finish(this.#lastLine || 1);
      return { type: 'encounter', discovery: this.#encounterDiscovery };
    }
    if (targetDummyDiscovery.sessions.length > 0) {
      return {
        type: 'target-dummy-input-required',
        discovery: targetDummyDiscovery,
        diagnostics: this.#encounterDiscovery.diagnostics,
        localActors: [...this.#encounterDiscovery.actors.values()],
        sourceRange,
        build: {
          gameVersion: 1,
          logVersion: 22,
          ...(this.#wowVersion === undefined ? {} : { wowVersion: this.#wowVersion }),
        },
      };
    }
    return {
      type: 'unsupported-input',
      error: {
        code: 'no-usable-encounter-or-target-dummy-session',
        message:
          'No complete encounter with combatant information or qualifying target-dummy attempt was found. Use an unmodified Retail advanced combat log and keep target-dummy activity in a standalone file or newly restarted logging session.',
        diagnostics: this.#encounterDiscovery.diagnostics,
      },
    };
  }

  #observeEncounterEnvelope(fields: readonly string[]): void {
    const event = fields[0] === 'COMBAT_LOG_VERSION' ? fields[0] : fields[1];
    if (event === 'ENCOUNTER_START') {
      this.#activeEncounter = {
        encounterId: fields[2] ?? '',
        hasCombatantInfo: false,
      };
      return;
    }
    if (event === 'COMBATANT_INFO' && this.#activeEncounter) {
      this.#activeEncounter.hasCombatantInfo = true;
      return;
    }
    if (event === 'ENCOUNTER_END') {
      if (
        this.#activeEncounter?.hasCombatantInfo &&
        this.#activeEncounter.encounterId === (fields[2] ?? '')
      ) {
        this.#hasUsableEncounter = true;
      }
      this.#activeEncounter = undefined;
    }
  }
}

async function scanCombatLogRange(
  file: File,
  range: CombatLogSourceRange,
  signal?: AbortSignal,
  progress?: (value: number) => void,
): Promise<TargetDummyDiscoveryRoute> {
  const isFullFile = range.startByte === 0 && range.endByte === file.size;
  const source = isFullFile ? file : file.slice(range.startByte, range.endByte);
  const router = new TargetDummyDiscoveryRouter();
  for await (const record of readCombatLogLines(source, signal)) {
    router.consume(decodeCombatLogLine(record.line), record.lineNumber);
    progress?.(source.size ? Math.min(1, record.bytesRead / source.size) : 1);
  }
  const result = router.finish(range);
  progress?.(1);
  return result;
}

export async function routeLocalCombatLogDiscovery(
  file: File,
  signal?: AbortSignal,
  progress?: (value: number) => void,
): Promise<TargetDummyDiscoveryRoute> {
  let lastProgress = 0;
  const reportProgress = (value: number) => {
    lastProgress = Math.max(lastProgress, Math.min(1, value));
    progress?.(lastProgress);
  };
  const fullRange = { startByte: 0, endByte: file.size };
  const latestRange = await findNewestCombatLogSessionRange(file, signal, (value) =>
    reportProgress(value * 0.05),
  );

  if (latestRange.startByte === 0) {
    return scanCombatLogRange(file, fullRange, signal, (value) =>
      reportProgress(0.05 + value * 0.95),
    );
  }

  const latestResult = await scanCombatLogRange(file, latestRange, signal, (value) =>
    reportProgress(0.05 + value * 0.45),
  );
  if (latestResult.type === 'target-dummy-input-required') {
    reportProgress(1);
    return latestResult;
  }

  return scanCombatLogRange(file, fullRange, signal, (value) => reportProgress(0.5 + value * 0.5));
}
