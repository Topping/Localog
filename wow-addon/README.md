# Localog Companion

`Localog_Companion` is a standalone World of Warcraft addon for Localog's target-dummy importer. It guides combat logging, captures readable helpful player auras at the combat restriction boundary, and appends its bounded protocol v1 snapshot to a fresh SimulationCraft profile for one-copy import.

The current `0.5.1` build contains the complete version-one addon flow plus the first post-CA-06 UX cleanup, and the browser importer implements CA-05 aura materialization. **Copy for Localog** uses the strict combined-export builder: it validates the underlying character profile's checksum, inserts the exact comment-only [protocol v1](./PROTOCOL.md) block immediately before the checksum, and recalculates Adler-32 over the clipboard form. No session or character data survives `/reload`.

## Install

1. Install and enable the SimulationCraft addon.
2. Either copy `wow-addon/Localog_Companion` directly, or extract the packaged `Localog_Companion-<version>.zip`, into the Retail client's `Interface/AddOns` directory.
3. Confirm that `Interface/AddOns/Localog_Companion/Localog_Companion.toc` exists. A second nested `Localog_Companion` directory will prevent discovery.
4. Start or reload Retail World of Warcraft 12.1.
5. Confirm that both SimulationCraft and Localog Companion are enabled.

The addon declares SimulationCraft as a required dependency so its public API has deterministic load order. The minimum tested SimulationCraft addon release is `12.0.5-04`; runtime feature checks still decide whether the public export API and the separate `/simc` convenience seam are usable.

The copied addon directory is self-contained: its Lua files do not import, bundle, or symlink anything from the web application. It includes its own `README.txt`, so it can be moved to another PC without the rest of this repository. Maintainers can create the ignored distribution archive with:

```sh
pnpm run addon:package
# Dependency-free fallback when the local pnpm launcher is unavailable:
node scripts/package-localog-companion.mjs
```

The command validates the exact release file allowlist, TOC interface/version/dependency fields, and absence of web-source runtime imports before writing `dist/wow-addon/Localog_Companion-<version>.zip`. It requires the standard `zip` and `unzip` command-line tools; packaging is development-only and adds no addon runtime dependency.

## Run a practice capture

1. Stand at the target dummy while out of combat and unrestricted.
2. Run `/localog` and click **Start practice capture**.
3. Wait for **Capture armed**. The main button becomes a disabled **Capture in progress** indicator; **Abort** is a separate secondary action.
4. Begin a normal target-dummy pull. The panel guides you to leave combat normally when finished.
5. Leave combat. If Localog started logging, it stops it after restrictions clear; pre-existing logging is left alone. The panel then shows **Ready to import**.
6. Click **Copy for Localog**. The companion opens one selected edit box containing the complete character profile, one companion block, and one recalculated terminal checksum.
7. As a convenience, running `/simc` while the same snapshot is **READY** should place the same kind of combined export in SimulationCraft's own selected edit box. If that private UI seam is incompatible, `/simc` remains unchanged and the companion directs you back to **Copy for Localog**.
8. Select the intended combat log, character, and attempt in Localog, then paste the selected combined export. Localog validates the block, checksum, player, build, and the selected segment's advanced-log marker before creating a report. The selected attempt is authoritative; capture time is retained only as diagnostic provenance. If the panel says the in-memory snapshot is old, it still exports, so select the attempt that belongs to that capture or choose **New capture**.

The panel treats an unknown `LoggingCombat` result as rate limiting, shows a ten-second recovery countdown, and requires an explicit retry. It never assumes ownership after an unknown result. If an owned stop cannot be confirmed, **Stop combat logging** remains available; **Dismiss** intentionally abandons the in-memory session so logging must then be checked manually.

Slash commands:

- `/localog` opens the panel.
- `/localog start` starts the same hardware-initiated preflight as the panel button (`arm` remains an alias).
- `/localog retry` retries a rate-limited preflight or logging stop.
- `/localog cancel` cancels the session and stops only logging that this session owns (`reset` remains an alias).
- `/localog export` generates a fresh SimC profile, adds the ready snapshot, verifies and recalculates its checksum, and opens the selected combined export.
- `/localog snapshot` opens and selects the raw protocol v1 snapshot after the session reaches **READY**.
- `/localog copy` opens the same fresh combined export as `/localog export`.

## Privacy and limitations

- The addon reads only `HELPFUL` auras affecting the current player during the synchronous Combat `Activating` event. It does not collect rotations, combat events, hostile units, other players, aura durations, expiration times, health, resources, or positions.
- The snapshot exists only in Lua memory. It is never placed in SavedVariables and is cleared by `/reload`, logout, or a client crash. The addon performs no upload, networking, addon communication, filesystem read, or browser interaction.
- The combined clipboard value contains the character profile plus player/source GUIDs, aura spell IDs and stacks, client build, and capture time. Treat it as private.
- Localog parses the selected combat-log file in the browser and stores the normalized report in that browser origin's IndexedDB. The local file is not uploaded by this workflow.
- Version one supports Retail project 1, combat-log version 22, WoW 12.1.0/TOC 120100, protocol schema 1, and the matching checked-in talent snapshot. The log, companion snapshot, and SimC profile must describe the same supported build.
- Complete capture is not guaranteed. Partial captures preserve only safely readable records and report exact skip counts. An unavailable capture produces no companion block, and stale aura data is never substituted automatically.
- Localog omits aura records whose source cannot resolve uniquely in the selected log; it never fabricates the selected player as caster. Pull-time ratings, aura duration/expiration, and other unavailable metadata remain unavailable.
- The user-selected attempt is authoritative. Localog checks player and build identity but does not reject another attempt by comparing capture time; choose the matching attempt in the UI.

## CA-06 release-candidate verification

CA-06 packages the independently copyable addon and hardens the complete panel-to-browser journey. Previously supplied Retail evidence covers the core restriction boundary, both combat-log ownership paths, cancellation before combat, restricted start, rate-limit recovery, reload ownership safety, combined export, and `/simc` compatibility. Existing browser tests cover short/low-confidence attempt discovery, cancellation and stale worker messages, recoverable stale selections, exact player/profile/build binding, partial aura materialization, plain `/simc`, capture summary rendering, import, analysis, reopen, and deletion.

| Scenario             | Current evidence and expected result                                                                                                                                         |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Short attempt        | Existing discovery/import coverage accepts qualifying short windows as lower confidence; the complete companion snapshot materializes when the selected attempt is imported. |
| Cancel before combat | Retail verified; owned logging is stopped, no snapshot is kept, and CA-06 now leaves an explicit canceled-before-combat message.                                             |
| Pre-existing logging | Retail verified; the session never owns or stops it and READY states that logging remains on.                                                                                |
| Logging rate limit   | Retail verified; no false ARMED state, a countdown is shown, and retry remains explicitly user-triggered.                                                                    |
| `/reload`            | Retail verified; the snapshot and ownership are forgotten, and active logging is treated as pre-existing on the next start.                                                  |
| Partial capture      | Protocol and browser materialization paths preserve safe records and exact skip diagnostics; a natural partial Retail capture remains opportunistic.                         |
| Repeated `/simc`     | Every hook invocation rebuilds from the fresh profile and rejects already nested blocks.                                                                                     |
| Off-spec toggle      | The hook consumes the newly generated profile passed by SimulationCraft; toggling spec and reopening `/simc` must produce a fresh checksum/output.                           |
| Old snapshot         | CA-06 warns after 15 minutes without blocking export; the selected Localog attempt remains authoritative. **New capture** replaces it.                                       |
| Wrong player         | Browser binding rejects the snapshot before report creation and asks for the matching character or a new capture.                                                            |
| Wrong attempt        | Selection is intentionally authoritative; the UI and bundled README tell the user to choose the attempt belonging to the capture.                                            |
| Wrong build          | Browser binding rejects any snapshot/profile/log build or TOC mismatch before normalization.                                                                                 |

The CA-06 repository release gate passes: the standalone source/package validator and archive integrity check pass; full-repository formatting, linting, and TypeScript checks pass; 49 focused existing tests pass; the static architecture check and production build pass; and both Chromium local-import journeys pass against an isolated production preview. The build emits the repository's existing non-failing CSS and chunk-size warnings, and the analyzer fixture emits its existing non-failing jsdom canvas diagnostic. Package SHA-256 values are printed by the packaging command rather than pinned here because archive metadata can differ between packaging hosts.

## CA-05 browser test status

**CA-05 implementation is ready for browser validation.** A valid companion snapshot now seeds the synthetic `COMBATANT_INFO` event with every captured aura whose exact source GUID resolves to an actor already present in the selected combat log. Spell IDs and application counts are preserved, spell names/icons come from Localog's existing catalog when available, and unknown presentation data uses the existing fallback icon.

The importer never treats an unknown source as the selected player. Records with `-`, an absent actor, or an ambiguous actor mapping are omitted with aggregate diagnostics, and accepted source actors are attached to the synthetic fight. A complete snapshot replaces the old missing-aura warning; a partial snapshot reports the addon's exact secret/invalid skip counts plus any source-resolution omissions. Plain `/simc` imports retain the existing empty aura list and warning.

The paste field shows a compact **Pull snapshot: N auras captured** summary as soon as a structurally valid combined export and checksum are present, including complete/partial state and exact addon skip counters.

## CA-04 browser test status

**CA-04 implementation is ready for browser validation.** The importer accepts zero or one protocol v1 block. A plain `/simc` profile retains the previous target-dummy behavior; a present companion block is fail-closed and is carried through preparation only after every structural and identity check succeeds.

The browser normalizes LF/CRLF input and enforces the protocol's field order, ASCII grammar, 512-byte line limit, 64 KiB block limit, 255-aura limit, canonical aura ordering, duplicate prohibition, completeness invariants, and terminal Adler-32 checksum. It then binds the snapshot to the exact selected player, SimC client version/build/TOC, available combat-log build metadata, and the active segment's explicit `ADVANCED_LOG_ENABLED,1` marker. Capture time is retained for diagnostics but does not override the user's attempt selection.

The UI now prefers **Copy for Localog** while retaining plain `/simc` as the no-snapshot fallback. Parser and binding failures are recoverable and tell the player whether to recopy, update, choose the matching player/profile, use the same build, or record a new advanced-log attempt.

## CA-03 test status

**CA-03 decision: verified.** Retail `12.1.0.69404` testing with SimulationCraft addon `12.1.0-03` confirmed the stable button, `/localog export`, isolated `/simc` post-hook, recalculated checksum envelope, and ordinary SimC consumer compatibility.

| Observation                 | Status   | Sanitized evidence                                                                                                                           |
| --------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Integration availability    | Verified | Public profile API available; convenience hook installed; neither integration path reported an issue.                                        |
| Stable combined export      | Verified | Original checksum validated; `5,170`-byte profile plus `632`-byte snapshot produced a `5,802`-byte combined export.                          |
| Combined envelope           | Verified | Exactly one companion block and one terminal checksum; snapshot immediately preceded the checksum; every inserted line was a comment.        |
| `/simc` convenience path    | Verified | Post-hook completed with a validated input checksum and the same `5,802`-byte combined size, one companion block, and one terminal checksum. |
| SimC consumer compatibility | Verified | The combined comment-only profile was accepted through the ordinary SimulationCraft workflow.                                                |

The verified session used a complete five-aura snapshot with no secret or invalid entries and preserved pre-existing combat logging. The incompatibility branches were not forced in-game: they remain fail-closed paths that leave `/simc` unchanged or block stable export with a visible update message.

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

The verified pull did not naturally contain duplicate records, unavailable source GUIDs, secret entries, or invalid entries. Their deduplication, unknown-source, partial, and unavailable paths remain fail-closed implementation branches to confirm when suitable Retail cases occur. The raw snapshot and combined export contain the character profile, player/source GUIDs, spell IDs, build metadata, and capture time; do not share either publicly.

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
