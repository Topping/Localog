import { describe, expect, it } from 'vitest';
import { decodeCsvLine, parseCombatLog, parseCombatLogTimestamp } from './LocalCombatLogParser';

describe('LocalCombatLogParser', () => {
  it('decodes quoted CSV fields and timestamps', () => {
    expect(decodeCsvLine('one,"two, still two","say ""hi"""')).toEqual([
      'one',
      'two, still two',
      'say "hi"',
    ]);
    expect(parseCombatLogTimestamp('2026/08/17 12:34:56.789')).toBe(
      Date.UTC(2026, 7, 17, 12, 34, 56, 789),
    );
  });

  it('recovers an unterminated encounter as a wipe and preserves unicode actors', () => {
    const result = parseCombatLog(
      [
        '2026/08/17 12:00:00.000,COMBAT_LOG_VERSION,1,22',
        '2026/08/17 12:00:01.000,ENCOUNTER_START,999,Razorgore',
        '2026/08/17 12:00:02.000,COMBATANT_INFO,Player-1,"Åsa",0,0,0,0,251',
        '2026/08/17 12:00:03.000,SPELL_CAST_SUCCESS,Player-1,"Åsa",0,Creature-1,Boss,0,123,Strike,1',
      ].join('\n'),
      'test-id',
    );
    expect(result.report.locator).toEqual({ kind: 'local', id: 'test-id' });
    expect(result.report.fights).toHaveLength(1);
    expect(result.report.fights[0].kill).toBe(false);
    expect(result.report.friendlies[0].name).toBe('Åsa');
    expect(result.events.some((event) => event.type === 'cast')).toBe(true);
    expect(result.diagnostics.some((diagnostic) => diagnostic.message.includes('wipe'))).toBe(true);
  });
});
