# Localog Companion

`Localog_Companion` is a standalone World of Warcraft addon under development for Localog's target-dummy importer. It guides combat logging and captures readable helpful player auras at the combat restriction boundary. A later implementation slice will append that snapshot to a SimulationCraft profile for one-copy import.

The current `0.2.0` build implements CA-01: a memory-only recording session, advanced-combat-logging preflight, ownership-safe combat log control, the proven CA-00 aura capture, and a guided status panel. It does not yet generate the combined `/simc` export. No session or character data survives `/reload`.

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
6. Click **Copy evidence** and share the sanitized CA-01 result when testing this build.

The panel treats an unknown `LoggingCombat` result as rate limiting, shows a ten-second recovery countdown, and requires an explicit retry. It never assumes ownership after an unknown result. If an owned stop cannot be confirmed, **Stop combat logging** remains available; **Dismiss** intentionally abandons the in-memory session so logging must then be checked manually.

Slash commands:

- `/localog` opens the panel.
- `/localog start` starts the same hardware-initiated preflight as the panel button (`arm` remains an alias).
- `/localog retry` retries a rate-limited preflight or logging stop.
- `/localog cancel` cancels the session and stops only logging that this session owns (`reset` remains an alias).
- `/localog copy` opens and selects sanitized evidence.

## CA-01 evidence status

**Core ownership decision: verified.** Two Retail `12.1.0.69404` attempts confirmed the normal logging controller paths. Both reached `ready` after a complete pull-boundary snapshot, with advanced logging and the SimulationCraft public API confirmed.

| Scenario                   | Status   | Sanitized evidence                                                                                                                                                |
| -------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Companion starts logging   | Verified | `logging_started_by_session=true`; owned stop confirmed by `logging_active=false`; final state `ready`; complete snapshot with 9 readable auras.                  |
| Logging was already active | Verified | `logging_was_preexisting=true`; `logging_owned=false`; logging remained active in final state `ready`; complete snapshot with 6 readable auras.                   |
| Cancel before combat       | Pending  | Verify that an owned logger returns to off and the panel returns to `idle`.                                                                                       |
| Reload with logging active | Pending  | Verify that the reloaded addon initially reports unknown state, then treats logging as pre-existing during a new preflight and never stops it.                    |
| Rate-limit recovery        | Pending  | If a rate-limit result occurs naturally, verify that the action stays disabled during the countdown and becomes manually retryable without automatic API polling. |

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
