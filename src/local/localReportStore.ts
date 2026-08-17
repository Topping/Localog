import type { AnyEvent } from 'parser/core/Events';
import type { PlayerDetails } from 'parser/core/Player';
import type Report from 'parser/core/Report';
import type { LocalDiagnostic } from './LocalCombatLogParser';

export const LOCAL_DB_NAME = 'wowanalyzer-local-reports';
export const LOCAL_DB_VERSION = 1;

export interface LocalManifest {
  id: string;
  schemaVersion: number;
  parserVersion: string;
  status: 'importing' | 'ready';
  report: Report;
  players: Record<number, PlayerDetails[]>;
  diagnostics: LocalDiagnostic[];
  createdAt: number;
}

interface EventRecord {
  key: string;
  reportId: string;
  fightId: number;
  timestamp: number;
  events: AnyEvent[];
}

const request = <T>(req: IDBRequest<T>) =>
  new Promise<T>((resolve, reject) => {
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
const transactionComplete = (tx: IDBTransaction) =>
  new Promise<void>((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error ?? new Error('IndexedDB transaction aborted'));
  });

export function openLocalReportDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(LOCAL_DB_NAME, LOCAL_DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains('manifests'))
        db.createObjectStore('manifests', { keyPath: 'id' });
      if (!db.objectStoreNames.contains('events')) {
        const events = db.createObjectStore('events', { keyPath: 'key' });
        events.createIndex('report-fight-time', ['reportId', 'fightId', 'timestamp']);
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function putLocalReport(
  manifest: LocalManifest,
  events: Iterable<{ fightId: number; timestamp: number; events: AnyEvent[] }>,
) {
  const db = await openLocalReportDb();
  const tx = db.transaction(['manifests', 'events'], 'readwrite');
  tx.objectStore('manifests').put(manifest);
  for (const chunk of events) {
    const record: EventRecord = {
      ...chunk,
      reportId: manifest.id,
      key: `${manifest.id}:${chunk.fightId}:${chunk.timestamp}`,
    };
    tx.objectStore('events').put(record);
  }
  await transactionComplete(tx);
  db.close();
}

export async function getLocalReport(id: string): Promise<LocalManifest | undefined> {
  const db = await openLocalReportDb();
  const result = await request(db.transaction('manifests').objectStore('manifests').get(id));
  db.close();
  return result;
}

export async function getLocalEvents(
  id: string,
  fightId: number,
  start = -Infinity,
  end = Infinity,
  actorId?: number,
): Promise<AnyEvent[]> {
  const db = await openLocalReportDb();
  const records = await request(
    db
      .transaction('events')
      .objectStore('events')
      .index('report-fight-time')
      .getAll(IDBKeyRange.bound([id, fightId, start], [id, fightId, end])),
  );
  db.close();
  return (records as EventRecord[]).flatMap((record) =>
    actorId === undefined
      ? record.events
      : record.events.filter((event) => {
          const candidate = event as AnyEvent & { sourceID?: number; targetID?: number };
          return candidate.sourceID === actorId || candidate.targetID === actorId;
        }),
  );
}

export async function listLocalReports(): Promise<LocalManifest[]> {
  const db = await openLocalReportDb();
  const result = await request(db.transaction('manifests').objectStore('manifests').getAll());
  db.close();
  return (result as LocalManifest[]).filter((manifest) => manifest.status === 'ready');
}

export async function removeLocalReport(id: string): Promise<void> {
  const db = await openLocalReportDb();
  const events = await request(
    db
      .transaction('events')
      .objectStore('events')
      .index('report-fight-time')
      .getAll(IDBKeyRange.bound([id, -Infinity, -Infinity], [id, Infinity, Infinity])),
  );
  const tx = db.transaction(['manifests', 'events'], 'readwrite');
  tx.objectStore('manifests').delete(id);
  for (const event of events as EventRecord[]) tx.objectStore('events').delete(event.key);
  await transactionComplete(tx);
  db.close();
}

export async function recoverLocalReports(): Promise<void> {
  const manifests = await listAllManifests();
  await Promise.all(
    manifests
      .filter((manifest) => manifest.status !== 'ready')
      .map((manifest) => removeLocalReport(manifest.id)),
  );
}

async function listAllManifests(): Promise<LocalManifest[]> {
  const db = await openLocalReportDb();
  const result = await request(db.transaction('manifests').objectStore('manifests').getAll());
  db.close();
  return result as LocalManifest[];
}
