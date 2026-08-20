import { describe, expect, it } from 'vitest';
import { decodeCombatLogLine } from '../LocalCombatLogParser';
import {
  classifyTargetDummyActorGuid,
  COMBATLOG_OBJECT_AFFILIATION_MINE,
  TargetDummyActorDiscovery,
} from './discovery';

const MINE = 'Player-1,"Téstknight-Realm",0x511,0x0';
const OTHER = 'Player-2,"Nearby-Realm",0x518,0x0';
const SECOND_MINE = 'Player-3,"Second-Realm",0x511,0x0';
const TARGET = 'Creature-1,"Localized Target",0xa28,0x0';

function record(second: number, event: string, payload: string): string[] {
  return decodeCombatLogLine(
    `8/14/2026 14:00:${second.toString().padStart(2, '0')}.0000  ${event},${payload}`,
  );
}

function scan(lines: readonly string[][]) {
  const discovery = new TargetDummyActorDiscovery();
  for (const line of lines) discovery.consume(line);
  return discovery.finish();
}

describe('target-dummy actor discovery', () => {
  it('classifies actors by GUID shape rather than localized names or flags', () => {
    expect(classifyTargetDummyActorGuid('Player-1')).toBe('player');
    expect(classifyTargetDummyActorGuid('Creature-1')).toBe('creature');
    expect(classifyTargetDummyActorGuid('Pet-1')).toBe('pet');
    expect(classifyTargetDummyActorGuid('Guardian-1')).toBe('guardian');
    expect(classifyTargetDummyActorGuid('Vehicle-1')).toBe('vehicle');
    expect(classifyTargetDummyActorGuid('GameObject-1')).toBe('game-object');
    expect(classifyTargetDummyActorGuid('Localized Training Dummy')).toBeUndefined();
  });

  it('deduplicates actor aggregates and ranks direct hostile player activity', () => {
    const result = scan([
      record(1, 'SPELL_CAST_SUCCESS', `${MINE},${TARGET},1,"Strike",0x1`),
      record(2, 'SPELL_DAMAGE', `${MINE},${TARGET},1,"Strike",0x1,100`),
      record(3, 'SPELL_DAMAGE', `${MINE},${TARGET},1,"Strike",0x1,100`),
      record(4, 'SPELL_CAST_SUCCESS', `${OTHER},${TARGET},2,"Other",0x1`),
      record(5, 'SPELL_HEAL', `${OTHER},${OTHER},3,"Heal",0x2,100`),
    ]);

    expect(result.actors).toHaveLength(3);
    expect(result.players.map((player) => player.guid)).toEqual(['Player-1', 'Player-2']);
    expect(result.players[0]).toMatchObject({
      guid: 'Player-1',
      name: 'Téstknight-Realm',
      flags: 0x511,
      recorderCandidate: true,
      outgoingCastCount: 1,
      outgoingDamageCount: 2,
      directHostileActionCount: 3,
      targetInteractionCount: 1,
    });
    expect(result.proposedRecorderGuid).toBe('Player-1');
    expect(result.actors.find((actor) => actor.guid === 'Creature-1')).toMatchObject({
      name: 'Localized Target',
      sourceObservationCount: 0,
      targetObservationCount: 4,
    });
  });

  it('proposes a recorder only for exactly one mine player', () => {
    const noMine = scan([record(1, 'SPELL_DAMAGE', `${OTHER},${TARGET},1,"Strike",0x1,100`)]);
    expect(noMine.proposedRecorderGuid).toBeUndefined();

    const multipleMine = scan([
      record(1, 'SPELL_DAMAGE', `${MINE},${TARGET},1,"Strike",0x1,100`),
      record(2, 'SPELL_DAMAGE', `${SECOND_MINE},${TARGET},1,"Strike",0x1,100`),
    ]);
    expect(multipleMine.players.filter((player) => player.recorderCandidate)).toHaveLength(2);
    expect(multipleMine.proposedRecorderGuid).toBeUndefined();
  });

  it('adds combatant-only players and unions flags across observations', () => {
    const result = scan([
      record(1, 'COMBATANT_INFO', 'Player-4,1,2,3'),
      record(2, 'SPELL_AURA_APPLIED', `Player-4,"Name",0x510,0x0,${MINE},1,"Buff",0x1,BUFF`),
      record(3, 'SPELL_DAMAGE', `Player-4,"Name",0x1,0x0,${TARGET},1,"Strike",0x1,100`),
    ]);
    expect(result.players.find((player) => player.guid === 'Player-4')).toMatchObject({
      name: 'Name',
      flags: 0x511,
      recorderCandidate: true,
    });
  });

  it('retains aggregate state, not source lines or normalized events', () => {
    const discovery = new TargetDummyActorDiscovery();
    for (let index = 0; index < 200; index += 1) {
      discovery.consume(record(index % 60, 'SPELL_DAMAGE', `${MINE},${TARGET},1,"Strike",0x1,100`));
    }
    const result = discovery.finish();
    expect(result.recordsScanned).toBe(200);
    expect(result.retainedState).toEqual({
      actorCount: 2,
      retainedRawLineCount: 0,
      retainedNormalizedEventCount: 0,
    });
    expect(result).not.toHaveProperty('records');
    expect(result).not.toHaveProperty('events');
    expect(COMBATLOG_OBJECT_AFFILIATION_MINE).toBe(1);
  });
});
