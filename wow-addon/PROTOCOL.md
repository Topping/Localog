# Localog companion snapshot protocol

Status: protocol version 1

Last updated: 2026-08-23

This document defines the text contract between `Localog_Companion` and Localog's target-dummy importer. Version 1 carries the player's readable helpful auras at the instant WoW announces that the combat addon restriction is activating.

The companion block is embedded in a SimulationCraft addon profile immediately before its terminal checksum. Every companion line is a SimulationCraft comment, so consumers that do not understand the extension can ignore it.

The key words **MUST**, **MUST NOT**, **SHOULD**, and **MAY** are normative.

## Complete example

```text
# Frostbyte - Frost - 2026-08-23 14:05 - EU/example
# SimC Addon 12.1.0-01
# WoW 12.1.0.69299, TOC 120100
# Requires SimulationCraft 1000-01 or newer

death_knight="Frostbyte"
level=90
race=human
region=eu
server=example
role=attack
spec=frost
talents=BYEA...

# ...ordinary SimulationCraft equipment and comments...

### Localog Companion Snapshot
# localog.schema=1
# localog.addon_version=0.3.0
# localog.player_guid=Player-1234-0ABCDEF0
# localog.client_version=12.1.0
# localog.client_build=69299
# localog.client_toc=120100
# localog.captured_at=1787493902
# localog.trigger=combat_activating
# localog.completeness=complete
# localog.skipped_secret=0
# localog.skipped_invalid=0
# localog.aura=465,1,Player-1234-0ABCDEF0
# localog.aura=6673,1,Player-5678-01234567
# localog.aura=383648,3,-
### End Localog Companion Snapshot
# Checksum: 1a2b3c4d
```

The checksum above is illustrative, not the checksum of the abbreviated example.

## Envelope

The exact marker lines are:

```text
### Localog Companion Snapshot
### End Localog Companion Snapshot
```

Requirements:

- A combined profile MUST contain zero or one companion block.
- When present, the block MUST occur after the active character declaration and immediately before the terminal SimulationCraft checksum, with no non-blank line between the end marker and checksum.
- Marker and field lines MUST begin in column zero. Leading or trailing whitespace is forbidden.
- Line endings MAY be LF or CRLF on input. The parser normalizes them to LF before validating the logical structure.
- Blank lines inside the block are forbidden.
- The exporter MUST emit fields in the order shown below.
- The parser MUST reject a nested, duplicated, unterminated, or misplaced block.
- Comments outside the envelope are not part of this protocol.

## Field grammar

Each scalar field uses:

```text
# localog.<key>=<value>
```

Each aura uses:

```text
# localog.aura=<spell_id>,<applications>,<source_guid>
```

Protocol text is ASCII. Numeric fields are unsigned base-10 integers with no sign, decimal point, exponent, grouping, or leading zero except the value `0` itself.

The fields MUST appear in this order:

| Field             |  Count | Grammar and meaning                                                                                                     |
| ----------------- | -----: | ----------------------------------------------------------------------------------------------------------------------- |
| `schema`          |      1 | Exact value `1`.                                                                                                        |
| `addon_version`   |      1 | SemVer core `MAJOR.MINOR.PATCH`; each component is `0..65535`. No prerelease/build suffix in v1.                        |
| `player_guid`     |      1 | Readable `UnitGUID("player")`; `Player-` prefix followed by ASCII letters, digits, or hyphens; 8..128 characters total. |
| `client_version`  |      1 | Dot-separated numeric WoW version with 2..4 components, each `0..65535`.                                                |
| `client_build`    |      1 | Positive integer `1..2147483647`.                                                                                       |
| `client_toc`      |      1 | Positive integer `1..2147483647`.                                                                                       |
| `captured_at`     |      1 | `GetServerTime()` Unix seconds, positive and no later than the time export is generated.                                |
| `trigger`         |      1 | Exact value `combat_activating`.                                                                                        |
| `completeness`    |      1 | `complete` or `partial`.                                                                                                |
| `skipped_secret`  |      1 | Integer `0..255`.                                                                                                       |
| `skipped_invalid` |      1 | Integer `0..255`.                                                                                                       |
| `aura`            | 0..255 | One normalized aura record. Repeated only in this contiguous section.                                                   |

Unknown fields are unsupported in schema 1 and MUST cause a typed unsupported-protocol failure. A future schema version can define compatible extension rules explicitly.

The complete block, including markers and LF line separators but excluding the SimulationCraft checksum line, MUST be no larger than 64 KiB. Every protocol line MUST be no larger than 512 bytes. These limits sit inside the SimC parser's existing whole-profile bounds.

## Aura records

An aura record has exactly three comma-separated fields:

```text
<spell_id>,<applications>,<source_guid>
```

### `spell_id`

- MUST be an ordinary, non-secret integer in `1..2147483647`.
- Identifies the helpful aura spell active on the player at capture.

### `applications`

- MUST be an integer in `1..255`.
- The addon normalizes WoW's absent or zero application count to `1`.
- Represents the pull-boundary stack/application count, not a duration.

### `source_guid`

- Is either `-` for unavailable or an ordinary readable WoW GUID.
- A GUID MUST contain only ASCII letters, digits, and hyphens and be `3..128` characters.
- `-` means unknown. It MUST NOT be interpreted as self-cast.
- Version 1 intentionally does not include a source name or unit token.

The exporter MUST sort records by numeric `spell_id`, then lexicographically by `source_guid`. Duplicate `(spell_id, source_guid)` pairs are forbidden. If capture returns duplicates, the exporter collapses them to one record with the largest `applications` value before sorting.

The importer MUST reject records that are unsorted, duplicated, malformed, out of bounds, or not helpful according to the version 1 contract. The importer MAY omit a structurally valid aura whose source cannot be represented safely in the analysis actor model, but it MUST emit a diagnostic and MUST NOT substitute the selected player as caster.

## Completeness

`complete` means the addon completed the bounded helpful-aura scan and did not skip an inaccessible or invalid entry:

```text
# localog.completeness=complete
# localog.skipped_secret=0
# localog.skipped_invalid=0
```

`partial` means the addon safely enumerated the collection but skipped one or more individual entries:

```text
# localog.completeness=partial
# localog.skipped_secret=2
# localog.skipped_invalid=0
```

Rules:

- `complete` requires both skipped counters to be zero.
- `partial` requires at least one skipped counter to be non-zero.
- A scan whose collection, count/iteration mechanism, or terminator is secret/inaccessible is not a partial snapshot. The addon MUST treat it as unavailable and MUST NOT emit a snapshot block.
- Hitting the iteration bound before observing a normal end is unavailable, not partial.
- The addon MUST NOT emit the previous session's snapshot when the current capture is unavailable.

The absence of a block means only that no usable companion snapshot was supplied. The browser keeps its current `/simc`-only behavior and does not infer an empty aura set was observed.

## SimulationCraft checksum

The combined export retains SimulationCraft's checksum contract rather than adding a second checksum.

Generation algorithm:

1. Obtain a fresh SimulationCraft addon profile.
2. Require exactly one terminal line matching `# Checksum: [0-9a-fA-F]+`.
3. Remove that line, preserving every byte in the preceding body.
4. Append the companion block. The resulting pre-checksum body ends with LF.
5. Convert every doubled pipe `||` in that full body to a single pipe `|`, matching what reaches the clipboard.
6. Compute Adler-32 as defined by RFC 1950 over the UTF-8 bytes of that clipboard-form body, with initial `s1 = 1`, `s2 = 0`, modulus `65521`, and result `(s2 << 16) + s1` as an unsigned 32-bit value.
7. Append `# Checksum: ` plus the lowercase hexadecimal value with no `0x` prefix and no required zero-padding.

The browser MUST validate the terminal checksum when a companion block is present. Checksum mismatch is a recoverable input error: ask the player to generate and copy the export again. Plain profiles without a companion block retain the existing checksum behavior until checksum validation is deliberately generalized.

The addon MUST NOT append a block if it cannot recognize or reproduce the current SimulationCraft checksum contract.

## Binding to a local combat-log attempt

Before materializing auras, Localog MUST validate the snapshot against the selected target-dummy input:

- `player_guid` exactly equals the selected player GUID.
- `client_version`, `client_build`, and `client_toc` agree with the SimulationCraft provenance and the selected log metadata wherever each value is available.
- The selected log segment's `COMBAT_LOG_VERSION` metadata explicitly contains `ADVANCED_LOG_ENABLED,1`.

`captured_at` remains diagnostic provenance. The importer does not reject a structurally valid snapshot based on its capture time: the user-selected target-dummy attempt is authoritative. This avoids false mismatches from the combat log's timezone-free wall clock and allows a recent snapshot to be reused when the precise pre-pull aura boundary is not analytically significant.

A player, build, TOC, or advanced-log mismatch is a hard, recoverable preparation failure. The UI should ask the user to choose the matching player/profile or make a new capture. It must not silently discard a mismatched block and proceed as if no snapshot was supplied.

## Import result

For a valid record that has a safely resolvable source, the synthesized `CombatantInfoEvent.auras` entry receives:

- aura ability/spell ID from `spell_id`;
- stack count from `applications`;
- source actor ID resolved from `source_guid`;
- the synthetic combatant-info timestamp already used by the target-dummy importer.

Names and icons are presentation metadata resolved by the browser's existing spell data. They are not trusted from the addon.

Durations, expiration, instance identity, and whether the aura was applied shortly before the pull are deliberately unknown. Protocol version 1 asserts only that the readable helpful aura was present at the `combat_activating` boundary.

## Error handling

Recommended typed failure groups:

| Failure                              | Suggested user action                                                         |
| ------------------------------------ | ----------------------------------------------------------------------------- |
| Block malformed/duplicated/oversized | Run the combined export again and paste it without editing.                   |
| Schema unsupported                   | Update Localog or the companion addon so their protocol versions agree.       |
| Combined checksum mismatch           | Copy the complete export again.                                               |
| Player mismatch                      | Select the character used for this capture.                                   |
| Build/TOC mismatch                   | Use the log and export from the same client session/build.                    |
| Advanced log marker absent/disabled  | Enable advanced logging and record a new attempt.                             |
| Partial snapshot                     | Continue with captured auras and show exact skipped counts as a warning.      |
| No block                             | Continue with current empty-aura behavior and explain the optional companion. |

Parsing must be fail-closed and linear in input size. Error messages must not echo the entire pasted profile or unbounded attacker-controlled values.

## Versioning

`localog.schema` versions the data contract, independently of `localog.addon_version`.

- Any field removal, reordering, grammar change, or semantic change requires a new schema integer.
- Adding a field also requires a new schema until an extension mechanism is defined.
- Importers MUST reject unknown schema versions with an update message.
- Exporters MUST emit only one schema version per block.
- The addon version is diagnostic and does not override schema parsing.
