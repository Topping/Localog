import { EventType, type AnyEvent, type CombatantInfoEvent } from 'parser/core/Events';
import type { WCLFight } from 'parser/core/Fight';
import type Report from 'parser/core/Report';

export interface LocalDiagnostic {
  line: number;
  message: string;
  severity: 'warning' | 'error';
}

export interface LocalActor {
  id: number;
  guid: string;
  name: string;
  flags: number;
  friendly: boolean;
  pet?: boolean;
  ownerId?: number;
  className?: string;
  specID?: number;
  role?: 'tank' | 'dps' | 'healer';
  combatant?: CombatantInfoEvent;
}

export interface LocalImportResult {
  report: Report;
  events: AnyEvent[];
  actors: LocalActor[];
  diagnostics: LocalDiagnostic[];
}

export class LocalCombatLogParseError extends Error {
  constructor(
    message: string,
    readonly diagnostics: LocalDiagnostic[] = [],
  ) {
    super(message);
    this.name = 'LocalCombatLogParseError';
  }
}

// Retail combat logs use CSV with quoted names and embedded commas. Keeping this decoder
// independent makes the importer usable in a worker and avoids depending on WCL's API shape.
export function decodeCsvLine(line: string): string[] {
  const fields: string[] = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < line.length; i += 1) {
    const char = line[i];
    if (char === '"') {
      if (quoted && line[i + 1] === '"') {
        field += '"';
        i += 1;
      } else {
        quoted = !quoted;
      }
    } else if (char === ',' && !quoted) {
      fields.push(field);
      field = '';
    } else {
      field += char;
    }
  }
  fields.push(field);
  return fields;
}

export function parseCombatLogTimestamp(value: string): number | null {
  const match = value.match(/^(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3})$/);
  if (!match) return null;
  const [, year, month, day, hour, minute, second, millis] = match;
  return Date.UTC(+year, +month - 1, +day, +hour, +minute, +second, +millis);
}

const n = (value: string | undefined) => (value && value !== '' ? Number(value) : undefined);
const eventType = (value: string): EventType | null => {
  const map: Record<string, EventType> = {
    SPELL_CAST_START: EventType.BeginCast,
    SPELL_CAST_SUCCESS: EventType.Cast,
    SPELL_EMPOWER_START: EventType.EmpowerStart,
    SPELL_EMPOWER_END: EventType.EmpowerEnd,
    SPELL_DAMAGE: EventType.Damage,
    SWING_DAMAGE: EventType.Damage,
    RANGE_DAMAGE: EventType.Damage,
    SPELL_MISSED: EventType.Damage,
    SWING_MISSED: EventType.Damage,
    RANGE_MISSED: EventType.Damage,
    SPELL_HEAL: EventType.Heal,
    SPELL_PERIODIC_HEAL: EventType.Heal,
    SPELL_AURA_APPLIED: EventType.ApplyBuff,
    SPELL_AURA_REMOVED: EventType.RemoveBuff,
    SPELL_AURA_APPLIED_DOSE: EventType.ApplyBuffStack,
    SPELL_AURA_REMOVED_DOSE: EventType.RemoveBuffStack,
    SPELL_AURA_REFRESH: EventType.RefreshBuff,
    SPELL_DRAIN: EventType.Drain,
    SPELL_ENERGIZE: EventType.ResourceChange,
    SPELL_INTERRUPT: EventType.Interrupt,
    SPELL_DISPEL: EventType.Dispel,
    SPELL_STOLEN: EventType.Spellsteal,
    SPELL_SUMMON: EventType.Summon,
    UNIT_DIED: EventType.Death,
    SPELL_RESURRECT: EventType.Resurrect,
  };
  return map[value] ?? null;
};

function makeEvent(fields: string[], timestamp: number): AnyEvent | null {
  const type = eventType(fields[1]);
  if (!type) return null;
  const sourceID = fields[2] ? hashActor(fields[2]) : undefined;
  const targetID = fields[5] ? hashActor(fields[5]) : undefined;
  const abilityID = n(fields[8]);
  const base = {
    type,
    timestamp,
    sourceID,
    targetID,
    ability: abilityID
      ? {
          guid: abilityID,
          name: fields[9] || '',
          type: n(fields[10]) ?? 0,
          abilityIcon: 'spell_shadow_unknown',
        }
      : undefined,
  } as AnyEvent;
  const withAmount = [
    'SPELL_DAMAGE',
    'SWING_DAMAGE',
    'RANGE_DAMAGE',
    'SPELL_HEAL',
    'SPELL_PERIODIC_HEAL',
  ].includes(fields[1]);
  if (withAmount)
    (base as AnyEvent & { amount: number }).amount =
      n(fields[fields[1].includes('HEAL') ? 12 : 12]) ?? 0;
  return base;
}

function hashActor(guid: string): number {
  let hash = 2166136261;
  for (let i = 0; i < guid.length; i += 1) hash = Math.imul(hash ^ guid.charCodeAt(i), 16777619);
  return Math.abs(hash | 0) || 1;
}

export function parseCombatLog(text: string, id = 'local'): LocalImportResult {
  const lines = text.split(/\r?\n/).filter((line) => line.trim());
  if (!lines.length) throw new LocalCombatLogParseError('The combat log is empty.');
  const diagnostics: LocalDiagnostic[] = [];
  let version = false;
  let logVersion = 0;
  const events: AnyEvent[] = [];
  const actors = new Map<number, LocalActor>();
  const fights: WCLFight[] = [];
  let active: WCLFight | undefined;
  let fightId = 1;
  let start = Number.POSITIVE_INFINITY;
  let end = 0;
  for (let index = 0; index < lines.length; index += 1) {
    const lineNumber = index + 1;
    const fields = decodeCsvLine(lines[index]);
    if (fields[1] === 'COMBAT_LOG_VERSION') {
      version =
        (fields[2] === '1' && fields[3] === '22') ||
        (fields[2] === '22' && fields[3] === '1') ||
        fields.includes('22');
      logVersion = 22;
      if (!version)
        diagnostics.push({
          line: lineNumber,
          severity: 'error',
          message: 'Only Retail advanced combat logs (project 1, format 22) are supported.',
        });
      continue;
    }
    const timestamp = parseCombatLogTimestamp(fields[0]);
    if (timestamp === null) {
      diagnostics.push({
        line: lineNumber,
        severity: 'warning',
        message: 'Skipped record with an invalid timestamp.',
      });
      continue;
    }
    start = Math.min(start, timestamp);
    end = Math.max(end, timestamp);
    if (fields[1] === 'ENCOUNTER_START') {
      if (active) {
        active.end_time = timestamp;
        active.kill = false;
        fights.push(active);
        diagnostics.push({
          line: lineNumber,
          severity: 'warning',
          message: 'Overlapping encounter closed as a wipe.',
        });
      }
      active = {
        id: fightId++,
        start_time: timestamp,
        end_time: timestamp,
        boss: Number(fields[2]) || 0,
        name: fields[3] || 'Unknown encounter',
        kill: false,
      };
      continue;
    }
    if (fields[1] === 'ENCOUNTER_END') {
      if (active) {
        active.end_time = timestamp;
        active.kill = fields[4] === '1' || fields[4] === 'SUCCESS';
        fights.push(active);
        active = undefined;
      }
      continue;
    }
    if (fields[1] === 'COMBATANT_INFO') {
      const actorId = hashActor(fields[2] || `line:${lineNumber}`);
      const actor = actors.get(actorId) ?? {
        id: actorId,
        guid: fields[2] || '',
        name: fields[3] || 'Unknown',
        flags: Number(fields[4]) || 0,
        friendly: true,
      };
      actor.combatant = {
        type: EventType.CombatantInfo,
        timestamp,
        sourceID: actorId,
        specID: n(fields[8]) ?? 0,
        expansion: 'retail',
        pin: '',
        gear: [],
        auras: [],
        faction: 0,
        strength: 0,
        agility: 0,
        stamina: 0,
        intellect: 0,
        dodge: 0,
        parry: 0,
        block: 0,
        armor: 0,
        critMelee: 0,
        critRanged: 0,
        critSpell: 0,
        speed: 0,
        leech: 0,
        hasteMelee: 0,
        hasteRanged: 0,
        hasteSpell: 0,
        avoidance: 0,
        mastery: 0,
        versatilityDamageDone: 0,
        versatilityHealingDone: 0,
        versatilityDamageReduction: 0,
        talentTree: [],
        talents: [],
        pvpTalents: [],
      };
      actors.set(actorId, actor);
      events.push(actor.combatant);
      continue;
    }
    const actorId = fields[2] ? hashActor(fields[2]) : undefined;
    if (actorId && !actors.has(actorId))
      actors.set(actorId, {
        id: actorId,
        guid: fields[2],
        name: fields[3] || 'Unknown',
        flags: Number(fields[4]) || 0,
        friendly: true,
      });
    const event = makeEvent(fields, timestamp);
    if (event) events.push(event);
    else if (!['ZONE_CHANGE', 'SPELL_AURA_BROKEN'].includes(fields[1]))
      diagnostics.push({
        line: lineNumber,
        severity: 'warning',
        message: `Skipped unknown event type ${fields[1] || '(empty)'}.`,
      });
  }
  if (active) {
    active.end_time = end;
    active.kill = false;
    fights.push(active);
    diagnostics.push({
      line: lines.length,
      severity: 'warning',
      message: 'Final encounter had no end record and was recovered as a wipe.',
    });
  }
  if (!version)
    throw new LocalCombatLogParseError(
      'This is not a supported Retail advanced combat log.',
      diagnostics,
    );
  if (!fights.length || ![...actors.values()].some((actor) => actor.combatant))
    throw new LocalCombatLogParseError(
      'The log contains no usable encounter and COMBATANT_INFO record.',
      diagnostics,
    );
  const report: Report = {
    code: id,
    locator: { kind: 'local', id },
    isAnonymous: false,
    fights,
    lang: 'en',
    friendlies: [...actors.values()]
      .filter((a) => a.friendly)
      .map((a) => ({
        id: a.id,
        name: a.name,
        guid: a.id,
        type: 'Player',
        subType: 'Player',
        icon: 'Player',
        fights: fights.map((fight) => ({ id: fight.id })),
      })),
    enemies: [],
    friendlyPets: [],
    enemyPets: [],
    phases: [],
    logVersion,
    gameVersion: 1,
    title: 'Local combat log',
    owner: '',
    start,
    end,
    zone: 0,
    exportedCharacters: [],
  };
  return { report, events, actors: [...actors.values()], diagnostics };
}
