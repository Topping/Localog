import type {
  TargetDummyActorAggregate,
  TargetDummyActorDiscoveryResult,
  TargetDummyActorKind,
  TargetDummyPlayerCandidate,
} from './contracts';

export const COMBATLOG_OBJECT_AFFILIATION_MINE = 0x00000001;

interface MutableActorAggregate {
  guid: string;
  kind: TargetDummyActorKind;
  name?: string;
  flags: number;
  sourceObservationCount: number;
  targetObservationCount: number;
}

interface MutablePlayerAggregate extends MutableActorAggregate {
  kind: 'player';
  outgoingCastCount: number;
  outgoingDamageCount: number;
  directHostileActionCount: number;
  targetGuids: Set<string>;
}

interface ActorObservation {
  guid: string;
  kind: TargetDummyActorKind;
  name?: string;
  flags: number;
}

const CAST_EVENTS = new Set(['SPELL_CAST_START', 'SPELL_CAST_SUCCESS']);
const DIRECT_DAMAGE_EVENTS = new Set([
  'RANGE_DAMAGE',
  'RANGE_MISSED',
  'SPELL_DAMAGE',
  'SPELL_MISSED',
  'SWING_DAMAGE',
  'SWING_MISSED',
]);

export function classifyTargetDummyActorGuid(guid: string): TargetDummyActorKind | undefined {
  if (guid.startsWith('Player-')) return 'player';
  if (guid.startsWith('Creature-')) return 'creature';
  if (guid.startsWith('Pet-')) return 'pet';
  if (guid.startsWith('Guardian-')) return 'guardian';
  if (guid.startsWith('Vehicle-')) return 'vehicle';
  if (guid.startsWith('GameObject-')) return 'game-object';
  return undefined;
}

function parseFlags(value: string | undefined): number {
  if (!value) return 0;
  const flags = Number.parseInt(value, value.startsWith('0x') ? 16 : 10);
  return Number.isFinite(flags) ? flags : 0;
}

function actorObservation(
  fields: readonly string[],
  guidIndex: number,
): ActorObservation | undefined {
  const guid = fields[guidIndex];
  const kind = guid ? classifyTargetDummyActorGuid(guid) : undefined;
  if (!guid || !kind) return undefined;
  const name = fields[guidIndex + 1];
  return {
    guid,
    kind,
    ...(name && name !== 'nil' ? { name } : {}),
    flags: parseFlags(fields[guidIndex + 2]),
  };
}

function targetGuidIndex(fields: readonly string[]): number {
  return classifyTargetDummyActorGuid(fields[6] ?? '') ? 6 : 5;
}

function isNonPlayer(actor: ActorObservation | undefined): actor is ActorObservation {
  return actor !== undefined && actor.kind !== 'player';
}

function publicActor(actor: MutableActorAggregate): TargetDummyActorAggregate {
  return {
    guid: actor.guid,
    kind: actor.kind,
    ...(actor.name === undefined ? {} : { name: actor.name }),
    flags: actor.flags,
    sourceObservationCount: actor.sourceObservationCount,
    targetObservationCount: actor.targetObservationCount,
  };
}

/**
 * Bounded pass-one actor aggregation. The scanner retains counters and GUID
 * sets only; callers can discard each decoded record immediately after consume.
 */
export class TargetDummyActorDiscovery {
  readonly #actors = new Map<string, MutableActorAggregate>();
  readonly #players = new Map<string, MutablePlayerAggregate>();
  #recordsScanned = 0;

  consume(fields: readonly string[]): void {
    this.#recordsScanned += 1;
    const event = fields[1];
    if (!event) return;

    if (event === 'COMBATANT_INFO') {
      const guid = fields[2];
      if (guid && classifyTargetDummyActorGuid(guid) === 'player') {
        this.#observe({ guid, kind: 'player', flags: 0 }, 'source');
      }
      return;
    }

    const source = actorObservation(fields, 2);
    const target = actorObservation(fields, targetGuidIndex(fields));
    this.#observe(source, 'source');
    this.#observe(target, 'target');

    if (source?.kind !== 'player' || !isNonPlayer(target)) return;
    const player = this.#players.get(source.guid);
    if (!player) return;

    const cast = CAST_EVENTS.has(event);
    const damage = DIRECT_DAMAGE_EVENTS.has(event);
    if (!cast && !damage) return;

    player.outgoingCastCount += Number(cast);
    player.outgoingDamageCount += Number(damage);
    player.directHostileActionCount += 1;
    player.targetGuids.add(target.guid);
  }

  finish(): TargetDummyActorDiscoveryResult {
    const actors = [...this.#actors.values()]
      .map(publicActor)
      .sort((left, right) => left.guid.localeCompare(right.guid));
    const players = [...this.#players.values()]
      .map(
        (player): TargetDummyPlayerCandidate => ({
          ...publicActor(player),
          kind: 'player',
          recorderCandidate: (player.flags & COMBATLOG_OBJECT_AFFILIATION_MINE) !== 0,
          outgoingCastCount: player.outgoingCastCount,
          outgoingDamageCount: player.outgoingDamageCount,
          directHostileActionCount: player.directHostileActionCount,
          targetInteractionCount: player.targetGuids.size,
          activityScore: player.outgoingDamageCount * 2 + player.outgoingCastCount,
        }),
      )
      .sort(
        (left, right) =>
          right.activityScore - left.activityScore || left.guid.localeCompare(right.guid),
      );
    const recorderCandidates = players.filter((player) => player.recorderCandidate);

    return {
      actors,
      players,
      ...(recorderCandidates.length === 1
        ? { proposedRecorderGuid: recorderCandidates[0].guid }
        : {}),
      recordsScanned: this.#recordsScanned,
      retainedState: {
        actorCount: actors.length,
        retainedRawLineCount: 0,
        retainedNormalizedEventCount: 0,
      },
    };
  }

  #observe(actor: ActorObservation | undefined, role: 'source' | 'target'): void {
    if (!actor) return;
    const existing = this.#actors.get(actor.guid);
    if (existing) {
      existing.name ??= actor.name;
      existing.flags |= actor.flags;
      existing.sourceObservationCount += Number(role === 'source');
      existing.targetObservationCount += Number(role === 'target');
      return;
    }

    if (actor.kind === 'player') {
      const player: MutablePlayerAggregate = {
        ...actor,
        kind: 'player',
        sourceObservationCount: Number(role === 'source'),
        targetObservationCount: Number(role === 'target'),
        outgoingCastCount: 0,
        outgoingDamageCount: 0,
        directHostileActionCount: 0,
        targetGuids: new Set(),
      };
      this.#actors.set(actor.guid, player);
      this.#players.set(actor.guid, player);
      return;
    }
    this.#actors.set(actor.guid, {
      ...actor,
      sourceObservationCount: Number(role === 'source'),
      targetObservationCount: Number(role === 'target'),
    });
  }
}
