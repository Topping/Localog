# Localog Companion

`Localog_Companion` is a standalone World of Warcraft addon under development for Localog's target-dummy importer. The eventual addon will guide combat logging, capture readable helpful player auras at the combat restriction boundary, and append the snapshot to a SimulationCraft addon profile.

This first implementation is the **CA-00 evidence spike only**. It does not control combat logging or modify `/simc` output yet. It retains all observations in memory and never saves character or aura data to SavedVariables.

## Install the evidence spike

1. Install and enable the SimulationCraft addon.
2. Copy `wow-addon/Localog_Companion` into the Retail client's `Interface/AddOns` directory.
3. Start or reload Retail World of Warcraft 12.1.
4. Confirm that both SimulationCraft and Localog Companion are enabled.

The addon declares SimulationCraft as a required dependency so its eventual public API integration has deterministic load order.

## Run the target-dummy probe

1. Stand at the target dummy and leave combat.
2. Run `/localog`, then click **Arm probe**.
3. Begin a normal target-dummy pull.
4. When the Combat restriction activates, the addon synchronously inspects only `HELPFUL` auras on `player`.
5. After the pull, click **Copy evidence** and retain the sanitized result for updating the CA-00 observation table below.

The development probe may be armed while a non-Combat restriction (such as a map restriction) is already active. This is intentional for CA-00 evidence gathering. It never reads an aura index that `C_Secrets.ShouldUnitAuraIndexBeSecret` declares secret. A failed secrecy predicate, indexed API error, inaccessible terminator, or exhausted 255-entry bound makes the whole snapshot unavailable.

Slash commands:

- `/localog` opens the probe panel.
- `/localog arm` arms the probe.
- `/localog copy` opens and selects the sanitized evidence.
- `/localog reset` discards the in-memory observation.

## CA-00 evidence status

**Go decision:** a target-dummy attempt on Retail `12.1.0.69404` (TOC `120100`, map `2393`) confirmed that helpful player auras remain readable during the synchronous `Combat/Activating` dispatch. Snapshot capture and serialization work may proceed without weakening the safety model.

| Observation                                        | Status                       | Sanitized evidence                                                                                                    |
| -------------------------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Runtime enum values and `Activating` ordering      | Verified                     | Combat type `0`; Activating state `1`; the handler observed Combat state `1` during dispatch.                         |
| Helpful player auras readable at Combat/Activating | Verified                     | `complete`; 6 readable auras; 0 secret; 0 invalid; normal terminator at index 7; `ShouldAurasBeSecret=false`.         |
| Another restriction already active                 | Pending in-game verification | The verified attempt had every restriction inactive when armed and only Combat Activating during capture.             |
| Secret aura index behavior                         | Pending in-game verification | The verified attempt contained no secret aura index. A future naturally occurring case must confirm the skip counter. |

The verified capture also reported `InCombatLockdown=false`, matching the expected pre-enforcement boundary, and detected the public SimulationCraft API. A future supported-build regression that makes the collection unavailable is a new no-go signal: stop capture work and revise the product design rather than weakening secrecy checks or deriving hidden values.

## Safety boundary

The capture handler runs directly inside `ADDON_RESTRICTION_STATE_CHANGED` for `Combat/Activating`; it does not defer work through a timer. Each indexed aura query is protected with `pcall`, and secret-capable values are checked before comparison, conversion, formatting, or storage. Only ordinary spell IDs, normalized applications, and readable source GUIDs can survive the handler.

The copied evidence deliberately excludes character names, player GUIDs, source GUIDs, and spell IDs. It includes only client/build context, map ID, restriction states and ordering, aggregate counts, and bounded failure codes.

API references used for the spike:

- [ADDON_RESTRICTION_STATE_CHANGED](https://warcraft.wiki.gg/wiki/ADDON_RESTRICTION_STATE_CHANGED)
- [Blizzard restricted-action API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
- [Blizzard secret predicate API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua)
- [Blizzard unit aura API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
