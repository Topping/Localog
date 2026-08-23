# Localog Companion

`Localog_Companion` is a standalone World of Warcraft addon under development for Localog's target-dummy importer. It guides combat logging, captures readable helpful player auras at the combat restriction boundary, and appends its bounded protocol v1 snapshot to a fresh SimulationCraft profile for one-copy import.

The current `0.4.0` test build implements CA-03. Both **Copy for Localog** and the optional `/simc` convenience hook use the same strict combined-export builder. It validates SimulationCraft's original checksum, inserts the exact comment-only [protocol v1](./PROTOCOL.md) block immediately before the checksum, and recalculates Adler-32 over the clipboard form. No session or character data survives `/reload`.

## Install

1. Install and enable the SimulationCraft addon.
2. Copy `wow-addon/Localog_Companion` into the Retail client's `Interface/AddOns` directory.
3. Start or reload Retail World of Warcraft 12.1.
4. Confirm that both SimulationCraft and Localog Companion are enabled.

The addon declares SimulationCraft as a required dependency so its public API has deterministic load order. The minimum tested SimulationCraft addon release is `12.0.5-04`; runtime feature checks still decide whether the public export API and the separate `/simc` convenience seam are usable.

## Run a practice capture

1. Stand at the target dummy while out of combat and unrestricted.
2. Run `/localog` and click **Start practice capture**.
3. Confirm that the panel reaches **ARMED** and shows advanced logging, combat logging, and the SimulationCraft API as available.
4. Begin a normal target-dummy pull. The panel should change to **CAPTURED** at the pull boundary.
5. Leave combat normally. If Localog started logging, the panel will stop it after restrictions clear and then show **READY**. If logging was already active, Localog leaves it active and says so.
6. In **READY**, click **Copy for Localog**. The companion opens one selected edit box containing the complete SimC profile, one companion block, and one recalculated terminal checksum.
7. As a convenience, running `/simc` while the same snapshot is **READY** should place the same kind of combined export in SimulationCraft's own selected edit box. If that private UI seam is incompatible, `/simc` remains unchanged and the companion directs you back to **Copy for Localog**.
8. Use **Copy evidence** for a sanitized CA-03 result that omits the profile, character identifiers, and aura identifiers.

The panel treats an unknown `LoggingCombat` result as rate limiting, shows a ten-second recovery countdown, and requires an explicit retry. It never assumes ownership after an unknown result. If an owned stop cannot be confirmed, **Stop combat logging** remains available; **Dismiss** intentionally abandons the in-memory session so logging must then be checked manually.

Slash commands:

- `/localog` opens the panel.
- `/localog start` starts the same hardware-initiated preflight as the panel button (`arm` remains an alias).
- `/localog retry` retries a rate-limited preflight or logging stop.
- `/localog cancel` cancels the session and stops only logging that this session owns (`reset` remains an alias).
- `/localog export` generates a fresh SimC profile, adds the ready snapshot, verifies and recalculates its checksum, and opens the selected combined export.
- `/localog snapshot` opens and selects the raw protocol v1 snapshot after the session reaches **READY**.
- `/localog copy` opens and selects sanitized evidence (`evidence` is an alias).

## CA-03 test status

**CA-03 decision: awaiting in-game verification.** The stable public-API export and isolated `/simc` post-hook are implemented in `0.4.0`. The addon fails closed if profile generation reports an error, the input checksum does not validate, the terminal checksum is missing or duplicated, a companion block is already present, or the named `/simc` edit box no longer matches the profile passed to its frame method.

The stable path and convenience path degrade independently. A missing public API blocks **Copy for Localog** and asks for a SimulationCraft update without blocking aura capture. A missing private UI seam leaves `/simc` untouched while the stable public-API path remains available. The adapter does not replace `/simc`, overwrite `GetSimcProfile`, or modify SimulationCraft saved variables.

## CA-02 evidence status

**CA-02 decision: verified.** Retail `12.1.0.69404` testing produced a complete, deterministic protocol v1 block from a target-dummy capture. The normal capture and serialization path meets the CA-02 acceptance criteria, so combined SimulationCraft export work may proceed in CA-03.

| Observation                     | Status   | Sanitized evidence                                                                                                   |
| ------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------- |
| Envelope and scalar field order | Verified | Exact start/end markers; schema `1`; every required scalar appeared once in protocol order.                          |
| Capture identity and timing     | Verified | Client `12.1.0.69404`, TOC `120100`; capture time aligned with Combat `Activating` 1.784 seconds after arming.       |
| Aura normalization and order    | Verified | Five unique records, ascending numeric spell IDs, application count `1`, readable self-source GUIDs, no duplicates.  |
| Complete snapshot invariants    | Verified | `completeness=complete`, both skipped counters `0`, normal terminator at index `6`, and no inaccessible aura values. |
| Serializer bounds               | Verified | `protocol_serialized=true`; the complete block was `632` bytes against the 64 KiB limit.                             |

The verified pull did not naturally contain duplicate records, unavailable source GUIDs, secret entries, or invalid entries. Their deduplication, unknown-source, partial, and unavailable paths remain fail-closed implementation branches to confirm when suitable Retail cases occur. The raw snapshot and combined export contain the SimC character profile, player/source GUIDs, spell IDs, build metadata, and capture time; do not share either publicly. The **Copy evidence** output is the sanitized test artifact.

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

- [SimulationCraft addon's current profile, checksum, public API, and frame implementation](https://github.com/simulationcraft/simc-addon/blob/master/core.lua)
- [LoggingCombat](https://warcraft.wiki.gg/wiki/API:LoggingCombat)
- [ADDON_RESTRICTION_STATE_CHANGED](https://warcraft.wiki.gg/wiki/ADDON_RESTRICTION_STATE_CHANGED)
- [Blizzard restricted-action API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
- [Blizzard secret predicate API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua)
- [Blizzard unit aura API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
