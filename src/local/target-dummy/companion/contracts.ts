export const COMPANION_SCHEMA_VERSION = 1;
export const COMPANION_CAPTURE_TIME_TOLERANCE_MS = 10_000;

export type CompanionSnapshotFailureCode =
  | 'COMPANION_BLOCK_MALFORMED'
  | 'COMPANION_BLOCK_TOO_LARGE'
  | 'COMPANION_SCHEMA_UNSUPPORTED'
  | 'COMPANION_CHECKSUM_MISMATCH'
  | 'COMPANION_PLAYER_MISMATCH'
  | 'COMPANION_BUILD_MISMATCH'
  | 'COMPANION_CAPTURE_TIME_MISMATCH'
  | 'COMPANION_ADVANCED_LOG_REQUIRED';

export interface CompanionSnapshotFailure {
  readonly code: CompanionSnapshotFailureCode;
  readonly message: string;
  readonly recoverable: true;
  readonly suggestedAction: string;
}

export interface CompanionAuraSnapshotRecord {
  readonly spellId: number;
  readonly applications: number;
  readonly sourceGuid: string | null;
}

export interface CompanionSnapshot {
  readonly schema: 1;
  readonly addonVersion: string;
  readonly playerGuid: string;
  readonly clientVersion: string;
  readonly clientBuild: number;
  readonly clientToc: number;
  readonly capturedAt: number;
  readonly trigger: 'combat_activating';
  readonly completeness: 'complete' | 'partial';
  readonly skippedSecret: number;
  readonly skippedInvalid: number;
  readonly auras: readonly CompanionAuraSnapshotRecord[];
}

export type CompanionResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: CompanionSnapshotFailure };

export type CompanionSnapshotParseResult = CompanionResult<CompanionSnapshot | undefined>;
