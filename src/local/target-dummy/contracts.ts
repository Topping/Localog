export type TargetDummyActorKind =
  | 'player'
  | 'creature'
  | 'pet'
  | 'guardian'
  | 'vehicle'
  | 'game-object';

export interface TargetDummyActorAggregate {
  readonly guid: string;
  readonly kind: TargetDummyActorKind;
  readonly name?: string;
  /** Bitwise union of the actor flags observed for this GUID. */
  readonly flags: number;
  readonly sourceObservationCount: number;
  readonly targetObservationCount: number;
}

export interface TargetDummyPlayerCandidate extends TargetDummyActorAggregate {
  readonly kind: 'player';
  readonly recorderCandidate: boolean;
  readonly outgoingCastCount: number;
  readonly outgoingDamageCount: number;
  readonly directHostileActionCount: number;
  readonly targetInteractionCount: number;
  /** Ranking score derived only from direct hostile casts and damage. */
  readonly activityScore: number;
}

export interface TargetDummyDiscoveryRetentionSummary {
  readonly actorCount: number;
  readonly retainedRawLineCount: 0;
  readonly retainedNormalizedEventCount: 0;
}

export interface TargetDummyActorDiscoveryResult {
  readonly actors: readonly TargetDummyActorAggregate[];
  readonly players: readonly TargetDummyPlayerCandidate[];
  /** Present only when exactly one player GUID carries AFFILIATION_MINE. */
  readonly proposedRecorderGuid?: string;
  readonly recordsScanned: number;
  readonly retainedState: TargetDummyDiscoveryRetentionSummary;
}
