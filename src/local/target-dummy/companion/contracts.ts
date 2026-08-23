export const COMPANION_SCHEMA_VERSION = 2;

export type CompanionSnapshotFailureCode =
  | 'COMPANION_BLOCK_MALFORMED'
  | 'COMPANION_BLOCK_TOO_LARGE'
  | 'COMPANION_SCHEMA_UNSUPPORTED'
  | 'COMPANION_CHECKSUM_MISMATCH'
  | 'COMPANION_PLAYER_MISMATCH'
  | 'COMPANION_BUILD_MISMATCH'
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

/** Combat-log rating fields captured at the same pull boundary as the aura snapshot. */
export interface CompanionCombatantStats {
  readonly strength: number;
  readonly agility: number;
  readonly stamina: number;
  readonly intellect: number;
  readonly dodge: number;
  readonly parry: number;
  readonly block: number;
  readonly critMelee: number;
  readonly critRanged: number;
  readonly critSpell: number;
  readonly speed: number;
  readonly leech: number;
  readonly hasteMelee: number;
  readonly hasteRanged: number;
  readonly hasteSpell: number;
  readonly avoidance: number;
  readonly mastery: number;
  readonly versatilityDamageDone: number;
  readonly versatilityHealingDone: number;
  readonly versatilityDamageReduction: number;
  readonly armor: number;
}

export interface CompanionSnapshot {
  readonly schema: 2;
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
  readonly stats: CompanionCombatantStats;
  readonly auras: readonly CompanionAuraSnapshotRecord[];
}

export type CompanionResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: CompanionSnapshotFailure };

export type CompanionSnapshotParseResult = CompanionResult<CompanionSnapshot | undefined>;
