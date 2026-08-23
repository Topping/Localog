import {
  COMPANION_SCHEMA_VERSION,
  type CompanionAuraSnapshotRecord,
  type CompanionResult,
  type CompanionSnapshot,
  type CompanionSnapshotFailureCode,
  type CompanionSnapshotParseResult,
} from './contracts';

const START_MARKER = '### Localog Companion Snapshot';
const END_MARKER = '### End Localog Companion Snapshot';
const FIELD_PREFIX = '# localog.';
const CHECKSUM_PATTERN = /^# Checksum: ([0-9a-fA-F]+)$/u;
const MAX_BLOCK_BYTES = 64 * 1024;
const MAX_LINE_BYTES = 512;
const MAX_AURAS = 255;
const MAX_SIGNED_INTEGER = 0x7fffffff;
const MAX_BYTE_INTEGER = 255;
const UNSIGNED_INTEGER = /^(?:0|[1-9][0-9]*)$/u;
const PLAYER_GUID = /^Player-[A-Za-z0-9-]+$/u;
const SOURCE_GUID = /^[A-Za-z0-9-]+$/u;
const ADDON_VERSION = /^([0-9]+)\.([0-9]+)\.([0-9]+)$/u;
const CLIENT_VERSION = /^([0-9]+)\.([0-9]+)(?:\.([0-9]+))?(?:\.([0-9]+))?$/u;
const ACTIVE_CHARACTER =
  /^(?:death_knight|deathknight|demon_hunter|demonhunter|druid|evoker|hunter|mage|monk|paladin|priest|rogue|shaman|warlock|warrior)=/u;
const SCALAR_KEYS = [
  'schema',
  'addon_version',
  'player_guid',
  'client_version',
  'client_build',
  'client_toc',
  'captured_at',
  'trigger',
  'completeness',
  'skipped_secret',
  'skipped_invalid',
] as const;
const KNOWN_KEYS = new Set<string>([...SCALAR_KEYS, 'aura']);

function failure(
  code: CompanionSnapshotFailureCode,
  message: string,
  suggestedAction: string,
): CompanionResult<never> {
  return { ok: false, error: { code, message, recoverable: true, suggestedAction } };
}

function malformed(message: string): CompanionResult<never> {
  return failure(
    'COMPANION_BLOCK_MALFORMED',
    message,
    'Run Copy for Localog again and paste the complete export without editing it.',
  );
}

function unsupportedSchema(): CompanionResult<never> {
  return failure(
    'COMPANION_SCHEMA_UNSUPPORTED',
    'The Localog companion snapshot uses an unsupported protocol schema or field set.',
    'Update Localog and the Localog Companion addon, then make a new capture.',
  );
}

function parseInteger(value: string, minimum: number, maximum: number): number | undefined {
  if (!UNSIGNED_INTEGER.test(value)) return undefined;
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed >= minimum && parsed <= maximum
    ? parsed
    : undefined;
}

function validVersion(value: string, pattern: RegExp): boolean {
  const match = pattern.exec(value);
  if (match === null) return false;
  return match.slice(1).every((component) => {
    if (component === undefined) return true;
    return parseInteger(component, 0, 65535) !== undefined;
  });
}

function adler32(value: string): number {
  let s1 = 1;
  let s2 = 0;
  for (const byte of new TextEncoder().encode(value)) {
    s1 = (s1 + byte) % 65521;
    s2 = (s2 + s1) % 65521;
  }
  return (s2 * 65536 + s1) >>> 0;
}

function parseAura(value: string): CompanionAuraSnapshotRecord | undefined {
  const fields = value.split(',');
  if (fields.length !== 3) return undefined;
  const spellId = parseInteger(fields[0] ?? '', 1, MAX_SIGNED_INTEGER);
  const applications = parseInteger(fields[1] ?? '', 1, MAX_BYTE_INTEGER);
  const rawSourceGuid = fields[2] ?? '';
  const sourceGuid = rawSourceGuid === '-' ? null : rawSourceGuid;
  if (
    spellId === undefined ||
    applications === undefined ||
    (sourceGuid !== null &&
      (sourceGuid.length < 3 || sourceGuid.length > 128 || !SOURCE_GUID.test(sourceGuid)))
  ) {
    return undefined;
  }
  return { spellId, applications, sourceGuid };
}

function isAscii(value: string): boolean {
  for (let index = 0; index < value.length; index += 1) {
    if (value.charCodeAt(index) > 0x7f) return false;
  }
  return true;
}

/**
 * Parses only the optional Localog comment envelope. The ordinary SimC parser
 * remains authoritative for the rest of the profile.
 */
export function parseCompanionSnapshot(text: string): CompanionSnapshotParseResult {
  const hasProtocolIndicator =
    text.includes('Localog Companion Snapshot') || text.includes(FIELD_PREFIX);
  if (!hasProtocolIndicator) return { ok: true, value: undefined };
  if (/\r(?!\n)/u.test(text)) {
    return malformed('The Localog companion export contains unsupported line endings.');
  }

  const normalized = text.replaceAll('\r\n', '\n');
  const withoutTerminalNewline = normalized.endsWith('\n') ? normalized.slice(0, -1) : normalized;
  const lines = withoutTerminalNewline.split('\n');
  const startIndexes: number[] = [];
  const endIndexes: number[] = [];
  const checksumIndexes: number[] = [];
  for (const [index, line] of lines.entries()) {
    if (
      (line.trim() === START_MARKER && line !== START_MARKER) ||
      (line.trim() === END_MARKER && line !== END_MARKER)
    ) {
      return malformed('Localog companion marker lines cannot contain surrounding whitespace.');
    }
    if (line === START_MARKER) startIndexes.push(index);
    if (line === END_MARKER) endIndexes.push(index);
    if (CHECKSUM_PATTERN.test(line)) checksumIndexes.push(index);
  }
  if (startIndexes.length !== 1 || endIndexes.length !== 1) {
    return malformed(
      'The Localog companion export must contain exactly one complete snapshot block.',
    );
  }
  if (checksumIndexes.length !== 1 || checksumIndexes[0] !== lines.length - 1) {
    return malformed(
      'The combined export must contain exactly one terminal SimulationCraft checksum.',
    );
  }

  const startIndex = startIndexes[0];
  const endIndex = endIndexes[0];
  const checksumIndex = checksumIndexes[0];
  if (startIndex >= endIndex || endIndex !== checksumIndex - 1) {
    return malformed('The Localog companion snapshot is misplaced or unterminated.');
  }
  if (!lines.slice(0, startIndex).some((line) => ACTIVE_CHARACTER.test(line))) {
    return malformed(
      'The Localog companion snapshot must follow the active character declaration.',
    );
  }
  if (
    lines
      .filter((_, index) => index < startIndex || index > endIndex)
      .some((line) => line.startsWith(FIELD_PREFIX))
  ) {
    return malformed('Localog companion fields cannot appear outside the snapshot block.');
  }

  const blockLines = lines.slice(startIndex, endIndex + 1);
  const blockText = `${blockLines.join('\n')}\n`;
  if (new TextEncoder().encode(blockText).byteLength > MAX_BLOCK_BYTES) {
    return failure(
      'COMPANION_BLOCK_TOO_LARGE',
      'The Localog companion snapshot is larger than 64 KiB.',
      'Make a new capture and paste only one unmodified combined export.',
    );
  }
  if (blockLines.some((line) => !isAscii(line))) {
    return malformed('The Localog companion protocol block must contain only ASCII text.');
  }
  if (blockLines.some((line) => new TextEncoder().encode(line).byteLength > MAX_LINE_BYTES)) {
    return failure(
      'COMPANION_BLOCK_TOO_LARGE',
      'A Localog companion protocol line is larger than 512 bytes.',
      'Make a new capture and paste only one unmodified combined export.',
    );
  }

  const fieldLines = blockLines.slice(1, -1);
  const unknownField = fieldLines.find((line) => {
    const match = /^# localog\.([a-z_]+)=/u.exec(line);
    return match?.[1] !== undefined && !KNOWN_KEYS.has(match[1]);
  });
  if (unknownField !== undefined) return unsupportedSchema();
  if (fieldLines.length < SCALAR_KEYS.length) {
    return malformed('The Localog companion snapshot is missing required fields.');
  }

  const values = new Map<string, string>();
  for (const [index, key] of SCALAR_KEYS.entries()) {
    const prefix = `${FIELD_PREFIX}${key}=`;
    const line = fieldLines[index];
    if (line === undefined || !line.startsWith(prefix)) {
      return malformed('The Localog companion fields are duplicated, missing, or out of order.');
    }
    values.set(key, line.slice(prefix.length));
  }

  const schema = parseInteger(values.get('schema') ?? '', 1, MAX_SIGNED_INTEGER);
  if (schema === undefined) {
    return malformed('The Localog companion snapshot contains an invalid schema value.');
  }
  if (schema !== COMPANION_SCHEMA_VERSION) return unsupportedSchema();
  const addonVersion = values.get('addon_version') ?? '';
  const playerGuid = values.get('player_guid') ?? '';
  const clientVersion = values.get('client_version') ?? '';
  const clientBuild = parseInteger(values.get('client_build') ?? '', 1, MAX_SIGNED_INTEGER);
  const clientToc = parseInteger(values.get('client_toc') ?? '', 1, MAX_SIGNED_INTEGER);
  const capturedAt = parseInteger(values.get('captured_at') ?? '', 1, MAX_SIGNED_INTEGER);
  const trigger = values.get('trigger');
  const completeness = values.get('completeness');
  const skippedSecret = parseInteger(values.get('skipped_secret') ?? '', 0, MAX_BYTE_INTEGER);
  const skippedInvalid = parseInteger(values.get('skipped_invalid') ?? '', 0, MAX_BYTE_INTEGER);
  if (
    !validVersion(addonVersion, ADDON_VERSION) ||
    playerGuid.length < 8 ||
    playerGuid.length > 128 ||
    !PLAYER_GUID.test(playerGuid) ||
    !validVersion(clientVersion, CLIENT_VERSION) ||
    clientBuild === undefined ||
    clientToc === undefined ||
    capturedAt === undefined ||
    trigger !== 'combat_activating' ||
    (completeness !== 'complete' && completeness !== 'partial') ||
    skippedSecret === undefined ||
    skippedInvalid === undefined ||
    (completeness === 'complete' && (skippedSecret !== 0 || skippedInvalid !== 0)) ||
    (completeness === 'partial' && skippedSecret === 0 && skippedInvalid === 0)
  ) {
    return malformed('The Localog companion snapshot contains an invalid field value.');
  }

  const auraLines = fieldLines.slice(SCALAR_KEYS.length);
  if (auraLines.length > MAX_AURAS) {
    return failure(
      'COMPANION_BLOCK_TOO_LARGE',
      'The Localog companion snapshot contains more than 255 aura records.',
      'Make a new capture with the current Localog Companion addon.',
    );
  }
  const auras: CompanionAuraSnapshotRecord[] = [];
  const auraKeys = new Set<string>();
  let previous: { spellId: number; sourceGuid: string } | undefined;
  for (const line of auraLines) {
    const prefix = `${FIELD_PREFIX}aura=`;
    if (!line.startsWith(prefix)) {
      return malformed('The Localog companion aura records are malformed or out of order.');
    }
    const aura = parseAura(line.slice(prefix.length));
    if (aura === undefined) {
      return malformed('The Localog companion snapshot contains an invalid aura record.');
    }
    const sourceGuid = aura.sourceGuid ?? '-';
    const key = `${String(aura.spellId)}\0${sourceGuid}`;
    if (auraKeys.has(key)) {
      return malformed('The Localog companion snapshot contains a duplicate aura record.');
    }
    if (
      previous !== undefined &&
      (aura.spellId < previous.spellId ||
        (aura.spellId === previous.spellId && sourceGuid < previous.sourceGuid))
    ) {
      return malformed('The Localog companion aura records are not in canonical order.');
    }
    auraKeys.add(key);
    previous = { spellId: aura.spellId, sourceGuid };
    auras.push(aura);
  }

  const checksumMatch = CHECKSUM_PATTERN.exec(lines[checksumIndex] ?? '');
  const suppliedChecksum = Number.parseInt(checksumMatch?.[1] ?? '', 16);
  const body = `${lines.slice(0, checksumIndex).join('\n')}\n`.replaceAll('||', '|');
  if (
    !Number.isSafeInteger(suppliedChecksum) ||
    suppliedChecksum < 0 ||
    suppliedChecksum > 0xffffffff ||
    suppliedChecksum !== adler32(body)
  ) {
    return failure(
      'COMPANION_CHECKSUM_MISMATCH',
      'The combined SimulationCraft checksum does not match the pasted profile.',
      'Run Copy for Localog again and copy the complete selected text.',
    );
  }

  return {
    ok: true,
    value: {
      schema: COMPANION_SCHEMA_VERSION,
      addonVersion,
      playerGuid,
      clientVersion,
      clientBuild,
      clientToc,
      capturedAt,
      trigger,
      completeness,
      skippedSecret,
      skippedInvalid,
      auras,
    } satisfies CompanionSnapshot,
  };
}
