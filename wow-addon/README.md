# Localog Companion

`Localog_Companion` is a standalone World of Warcraft addon under development for Localog's target-dummy importer. It guides combat logging, captures readable helpful player auras at the combat restriction boundary, and serializes a bounded protocol v1 snapshot. A later implementation slice will append that snapshot to a SimulationCraft profile for one-copy import.

The current `0.3.0` build implements CA-02: a memory-only recording session, ownership-safe combat log control, synchronous pull-boundary aura reduction, deterministic normalization, and the exact comment-only snapshot block defined by [the canonical protocol](./PROTOCOL.md). It does not yet generate the combined `/simc` export. No session or character data survives `/reload`.

## Install

1. Install and enable the SimulationCraft addon.
2. Copy `wow-addon/Localog_Companion` into the Retail client's `Interface/AddOns` directory.
3. Start or reload Retail World of Warcraft 12.1.
4. Confirm that both SimulationCraft and Localog Companion are enabled.

The addon declares SimulationCraft as a required dependency so its public API has deterministic load order.

## Run a practice capture

1. Stand at the target dummy while out of combat and unrestricted.
2. Run `/localog` and click **Start practice capture**.
3. Confirm that the panel reaches **ARMED** and shows advanced logging, combat logging, and the SimulationCraft API as available.
4. Begin a normal target-dummy pull. The panel should change to **CAPTURED** at the pull boundary.
5. Leave combat normally. If Localog started logging, the panel will stop it after restrictions clear and then show **READY**. If logging was already active, Localog leaves it active and says so.
6. In **READY**, click **Copy snapshot block** to inspect the complete protocol v1 block. Use **Copy evidence** for a sanitized CA-02 result that omits character and aura identifiers.

The panel treats an unknown `LoggingCombat` result as rate limiting, shows a ten-second recovery countdown, and requires an explicit retry. It never assumes ownership after an unknown result. If an owned stop cannot be confirmed, **Stop combat logging** remains available; **Dismiss** intentionally abandons the in-memory session so logging must then be checked manually.

Slash commands:

- `/localog` opens the panel.
- `/localog start` starts the same hardware-initiated preflight as the panel button (`arm` remains an alias).
- `/localog retry` retries a rate-limited preflight or logging stop.
- `/localog cancel` cancels the session and stops only logging that this session owns (`reset` remains an alias).
- `/localog snapshot` opens and selects the raw protocol v1 snapshot after the session reaches **READY**.
- `/localog copy` opens and selects sanitized evidence (`evidence` is an alias).

## CA-02 test build

CA-02 needs Retail verification before it is complete. Test a normal attempt with both self-cast and externally sourced helpful auras if practical:

1. Reach **READY**, click **Copy snapshot block**, and confirm it begins and ends with the exact protocol markers.
2. Confirm scalar fields appear once and in documented order, followed only by zero or more aura lines.
3. Confirm aura lines are numerically sorted by spell ID; equal spell IDs must sort by source GUID and must not repeat the same `(spell ID, source GUID)` pair.
4. Confirm missing/zero application counts appear as `1`, all counts are in `1..255`, and unavailable sources appear as `-`.
5. Use **Copy evidence** and confirm `protocol_serialized=true`, `capture_status=complete` or `partial`, and sensible aura/byte/skip counts.

The raw snapshot contains the player GUID, source GUIDs, spell IDs, build metadata, and capture time. Redact those identifiers before sharing it publicly. Combined SimulationCraft export and checksum handling arrive in CA-03.

## CA-01 evidence status

**CA-01 decision: verified.** Retail `12.1.0.69404` testing confirmed both normal ownership paths, cancellation, reload safety, restricted-start refusal, and rate-limit recovery. The logging controller and guided state UI meet the CA-01 acceptance criteria.

| Scenario                   | Status   | Sanitized evidence                                                                                                                               |
| -------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Companion starts logging   | Verified | `logging_started_by_session=true`; owned stop confirmed by `logging_active=false`; final state `ready`; complete snapshot with 9 readable auras. |
| Logging was already active | Verified | `logging_was_preexisting=true`; `logging_owned=false`; logging remained active in final state `ready`; complete snapshot with 6 readable auras.  |
| Cancel before combat       | Verified | An owned logger returned to off and the panel returned to `idle`.                                                                                |
| Reload with logging active | Verified | Reload cleared ownership; a new preflight treated the active logger as pre-existing and did not stop it.                                         |
| Start while in combat      | Verified | Preflight entered `limited` with `session_issue=restricted_combat`; logging remained unknown and unowned; retry remained available.              |
| Rate-limit recovery        | Verified | The stop action remained disabled during the countdown, became manually retryable, and completed without automatic API polling.                  |

The owned attempt observed Combat `Activating` 2.824 seconds after arming and Combat `Inactive` 27.835 seconds after arming. The pre-existing attempt observed the same transition sequence at 1.659 and 9.658 seconds. In both attempts, the capture ran during Combat state `Activating`, reported `InCombatLockdown=false`, skipped no secret or invalid entries, and terminated aura iteration normally.

The evidence block contains state, ownership, advanced-logging status, retry status, restriction transitions, and aggregate aura results. It excludes character names, player GUIDs, source GUIDs, and spell IDs.

## CA-00 evidence status

**Go decision:** a target-dummy attempt on Retail `12.1.0.69404` (TOC `120100`, map `2393`) confirmed that helpful player auras remain readable during the synchronous `Combat/Activating` dispatch. Snapshot capture and serialization work may proceed without weakening the safety model.

| Observation                                        | Status                       | Sanitized evidence                                                                                                    |
| -------------------------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Runtime enum values and `Activating` ordering      | Verified                     | Combat type `0`; Activating state `1`; the handler observed Combat state `1` during dispatch.                         |
| Helpful player auras readable at Combat/Activating | Verified                     | `complete`; 6 readable auras; 0 secret; 0 invalid; normal terminator at index 7; `ShouldAurasBeSecret=false`.         |
| Another restriction already active                 | Pending in-game verification | The verified attempt had every restriction inactive when armed and only Combat Activating during capture.             |
| Secret aura index behavior                         | Pending in-game verification | The verified attempt contained no secret aura index. A future naturally occurring case must confirm the skip counter. |

The verified capture also reported `InCombatLockdown=false`, matching the expected pre-enforcement boundary, and detected the public SimulationCraft API. A future supported-build regression that makes the collection unavailable is a new no-go signal: stop capture work and revise the product design rather than weakening secrecy checks or deriving hidden values.

## Safety and ownership boundaries

The capture handler runs directly inside `ADDON_RESTRICTION_STATE_CHANGED` for `Combat/Activating`; it does not defer work through a timer. Each indexed aura query is protected with `pcall`, and secret-capable values are checked before comparison, conversion, formatting, or storage. Only ordinary spell IDs, normalized applications, and readable source GUIDs can survive the handler.

The start button refuses preflight if any supported addon restriction is active or a restriction state is unknown. It enables `advancedCombatLogging` when necessary and leaves that preference enabled. Combat logging calls use a local five-calls-per-ten-seconds budget in addition to handling the API's shared rate limit. Automatic stop is permitted only after the same in-memory session observed logging off and received a confirmed `true` result when enabling it. Reloaded or pre-existing logging is never claimed or automatically stopped.

API references:

- [LoggingCombat](https://warcraft.wiki.gg/wiki/API:LoggingCombat)
- [ADDON_RESTRICTION_STATE_CHANGED](https://warcraft.wiki.gg/wiki/ADDON_RESTRICTION_STATE_CHANGED)
- [Blizzard restricted-action API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
- [Blizzard secret predicate API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua)
- [Blizzard unit aura API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
