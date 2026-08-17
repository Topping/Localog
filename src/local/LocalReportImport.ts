import { parseCombatLog, type LocalImportResult } from './LocalCombatLogParser';
import { putLocalReport } from './localReportStore';

export interface ImportProgress {
  phase: 'reading' | 'normalizing' | 'saving';
  progress: number;
}

export async function importLocalCombatLog(
  file: File,
  onProgress?: (progress: ImportProgress) => void,
  signal?: AbortSignal,
): Promise<string> {
  const id = crypto.randomUUID();
  onProgress?.({ phase: 'reading', progress: 0 });
  const text = await file.text();
  if (signal?.aborted) throw new DOMException('Import cancelled', 'AbortError');
  onProgress?.({ phase: 'normalizing', progress: 0.35 });
  const result: LocalImportResult = parseCombatLog(text, id);
  const players = Object.fromEntries(
    result.report.fights.map((fight) => [
      fight.id,
      result.actors
        .filter((actor) => actor.friendly)
        .map((actor) => ({
          id: actor.id,
          name: actor.name,
          server: '',
          region: '',
          className: actor.className ?? 'Unknown',
          specID: actor.specID,
          role: actor.role ?? 'dps',
          guid: actor.id,
          ilvl: undefined,
        })),
    ]),
  );
  const chunks = result.report.fights.map((fight) => ({
    fightId: fight.id,
    timestamp: fight.start_time,
    events: result.events.filter(
      (event) => event.timestamp >= fight.start_time && event.timestamp <= fight.end_time,
    ),
  }));
  onProgress?.({ phase: 'saving', progress: 0.7 });
  await putLocalReport(
    {
      id,
      schemaVersion: 1,
      parserVersion: 'retail-v22',
      status: 'ready',
      report: result.report,
      players,
      diagnostics: result.diagnostics,
      createdAt: Date.now(),
    },
    chunks,
  );
  onProgress?.({ phase: 'saving', progress: 1 });
  return id;
}
