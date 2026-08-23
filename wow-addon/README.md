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

Repository work alone cannot satisfy the in-game acceptance criterion. The following observations must be collected on the supported Retail client before snapshot serialization work begins.

| Observation                                        | Status                       | Evidence required                                                                                    |
| -------------------------------------------------- | ---------------------------- | ---------------------------------------------------------------------------------------------------- |
| Runtime enum values and `Activating` ordering      | Pending in-game verification | Evidence shows Combat type `0`, Activating state `1`, and the state observed during dispatch.        |
| Helpful player auras readable at Combat/Activating | Pending in-game verification | Target-dummy evidence ends in `complete` or an understood `partial` result with a normal terminator. |
| Another restriction already active                 | Pending in-game verification | `armed_restrictions` and `capture_restrictions` show the other restriction and the capture outcome.  |
| Secret aura index behavior                         | Pending in-game verification | Evidence reports a positive `skipped_secret` count without an indexed read error.                    |

If the target-dummy attempt reports the collection as unavailable, stop CA-02 work and revise the product design. Do not weaken the secrecy checks or try to derive hidden values.

## Safety boundary

The capture handler runs directly inside `ADDON_RESTRICTION_STATE_CHANGED` for `Combat/Activating`; it does not defer work through a timer. Each indexed aura query is protected with `pcall`, and secret-capable values are checked before comparison, conversion, formatting, or storage. Only ordinary spell IDs, normalized applications, and readable source GUIDs can survive the handler.

The copied evidence deliberately excludes character names, player GUIDs, source GUIDs, and spell IDs. It includes only client/build context, map ID, restriction states and ordering, aggregate counts, and bounded failure codes.

API references used for the spike:

- [ADDON_RESTRICTION_STATE_CHANGED](https://warcraft.wiki.gg/wiki/ADDON_RESTRICTION_STATE_CHANGED)
- [Blizzard restricted-action API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
- [Blizzard secret predicate API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua)
- [Blizzard unit aura API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
