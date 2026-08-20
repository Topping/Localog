# Target-dummy local import implementation status

This tracker is the durable handoff between implementation chats. The authoritative product and
architecture specification is [`target-dummy-local-import.md`](target-dummy-local-import.md).

## Working agreement

Each implementation chat should:

1. read the specification and this tracker;
2. inspect the working tree and recent commits;
3. implement only one work item unless the user explicitly expands the scope;
4. run the verification listed for that item;
5. update this tracker with results, deviations, and the next unblocked item;
6. leave the repository at a reviewable commit boundary.

Do not mark an item complete when required verification is failing or deferred. Record unexpected
product decisions under **Decision log** and return them to the user instead of silently changing the
specification.

## Status values

- **Pending:** not started.
- **In progress:** implementation has begun but acceptance criteria are not satisfied.
- **Blocked:** cannot proceed without a product decision or external input.
- **Complete:** acceptance criteria and required verification pass.

## Work items

| ID     | Status   | Outcome                                                                                   | Depends on     |
| ------ | -------- | ----------------------------------------------------------------------------------------- | -------------- |
| TD-00A | Complete | Add reviewed compact fixtures and provenance notes for default tests.                     | —              |
| TD-00B | Complete | Prove the minimal analysis path, `boss: -1`, five-second pre-roll, and untouched targets. | TD-00A         |
| TD-01A | Pending  | Implement discovery contracts, actor aggregation, and recorder selection.                 | TD-00B         |
| TD-01B | Pending  | Implement ownership, sessionization, cleave grouping, confidence, and boundaries.         | TD-01A         |
| TD-01C | Pending  | Route one discovery pass automatically to the existing or synthetic path.                 | TD-01B         |
| TD-02A | Pending  | Implement the bounded official-addon SimC parser.                                         | TD-00B         |
| TD-02B | Pending  | Add the verified talent snapshot, generator, and talent decoder.                          | TD-02A         |
| TD-02C | Pending  | Build and validate normalized `CombatantInfoEvent` objects.                               | TD-02B         |
| TD-03A | Pending  | Add worker/controller pause and resume for session and SimC input.                        | TD-01C, TD-02C |
| TD-03B | Pending  | Normalize and persist the prepared synthetic fight through the local report store.        | TD-03A         |
| TD-04A | Pending  | Add character, session, and SimC states behind the existing single file picker.           | TD-03B         |
| TD-04B | Pending  | Add cancellation, recovery, diagnostics, and successful navigation behavior.              | TD-04A         |
| TD-05A | Pending  | Add end-to-end coverage for automatic encounter and synthetic routing.                    | TD-04B         |
| TD-05B | Pending  | Run capture-wide performance, architecture, and release verification.                     | TD-05A         |

## Work-item acceptance and verification

### TD-00A — compact fixtures

- Add only minimized, reviewed fixtures needed by default tests.
- Include provenance and sanitization notes.
- Do not make tests depend on the sibling transformer checkout.
- Keep the 28.9 MB capture out of the default test suite.

### TD-00B — minimal hypothesis

- A prepared target-dummy fight is visible and navigable with `boss: -1`.
- Core fight eligibility and the raid catalog remain unchanged.
- A complete normalized combatant-info event reaches a supported specialization analyzer.
- Original target GUIDs, names, NPC IDs, flags, map IDs, timestamps, and payload values survive.
- The analyzed fight begins at the clamped `TARGET_DUMMY_PRE_ROLL_MS = 5_000` boundary.
- Focused parser and UI tests pass.

Stop and request a product decision if `boss: -1` requires a core semantic change.

### TD-01A through TD-01C — discovery and routing

- Discovery retains aggregates, not complete source lines or normalized event collections.
- Actor identity uses GUIDs and flags; names are display metadata only.
- Ownership evidence follows the priority defined in the specification.
- Activity is grouped per player and preserves multiple targets.
- Genuine encounters take precedence for the entire source file.
- Normal encounter fixtures continue without requesting session or SimC input.
- Standalone dummy fixtures enter synthetic preparation.
- Unsupported inputs return typed, actionable errors.

### TD-02A through TD-02C — SimC and combatant info

- Accept only the bounded official addon-export subset.
- Bind character name, class, spec, and talents to the selected log player.
- Support only Retail project 1, log version 22, WoW 12.1.0, and the verified talent snapshot.
- Preserve equipment slot indexes and authentic empty slots.
- Block equipped items that have no item level.
- Default unavailable stats and auras without inference.
- Insert a normalized `CombatantInfoEvent`; do not create an intermediate transformed log.
- Unit tests cover success, structural validation, bounded inputs, and typed failures.

### TD-03A and TD-03B — worker import and storage

- Keep one file picker and one logical import operation.
- Native encounter import behavior remains unchanged.
- Synthetic discovery can pause for user input and resume safely.
- Cancellation and stale messages cannot persist a ready report.
- Import rescans the original file and streams batches with backpressure.
- The local manifest records `importKind: 'target-dummy'` without changing shared report contracts.
- Reopen and delete behavior works through the existing local data source and store.

### TD-04A and TD-04B — user interface

- No manual encounter/dummy mode switch is introduced.
- Character and session choices appear only for the synthetic route.
- SimC validation errors and defaulted-field warnings are actionable.
- Progress, cancellation, retry, start-over, and storage warnings remain coherent.
- Successful import navigates to the prepared fight and player when unambiguous.

### TD-05A and TD-05B — release confidence

- End-to-end tests cover both routes from the same upload entry point.
- Synthetic reports can be analyzed, refreshed, reopened, and deleted.
- Capture-wide discovery remains bounded and responsive.
- Formatting, linting, typechecking, focused tests, static checks, production build, and local-import
  browser tests pass.
- Final review finds no target-dummy behavior in shared analyzers or the raid encounter catalog.

## Decision log

| Date       | Decision                                                                                                  |
| ---------- | --------------------------------------------------------------------------------------------------------- |
| 2026-08-20 | Use one upload entry point and route automatically from parsed encounter/combatant metadata.              |
| 2026-08-20 | If any usable genuine encounter exists, only genuine encounters count; dummy activity must be standalone. |
| 2026-08-20 | Try the local-only `boss: -1` sentinel without changing core eligibility.                                 |
| 2026-08-20 | Preserve target identities and payloads; add compatibility rewrites only after a proven failure.          |
| 2026-08-20 | Do not infer unavailable combatant stats or auras.                                                        |
| 2026-08-20 | Preserve legitimate empty slots and block equipped items without item level.                              |
| 2026-08-20 | Support only the exact verified Retail 12.1.0/project 1/log 22 synthetic schema initially.                |
| 2026-08-20 | Start synthetic fights five seconds before detected activity, clamped at hard/segment boundaries.         |

## Implementation record

Add one entry when a work item changes state.

| Date       | Work item | Status change      | Commit      | Verification and notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ---------- | --------- | ------------------ | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-08-20 | TD-00A    | Pending → Complete | this commit | Added four compact, integrity-tested fixtures (15 records / 2,836 bytes) with source-revision provenance, purpose, sanitization, and hashes; no full capture was copied. `./node_modules/.bin/vitest run src/local/target-dummy/test-fixtures.test.ts` passed (4 tests); `./node_modules/.bin/oxfmt --check src/local/target-dummy/test-fixtures.test.ts src/local/target-dummy/test-fixtures/README.md` passed; `./node_modules/.bin/oxlint --max-warnings 0 --deny-warnings src/local/target-dummy/test-fixtures.test.ts` passed with 0 warnings/errors; `./node_modules/.bin/tsc --noEmit` passed; `git diff --check` passed; `cmp` of each synthetic fixture against its sibling-repository source passed. `pnpm test …` could not start because the local pnpm launcher attempted an unavailable registry signature fetch, so the checked-in Vitest binary was used directly.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 2026-08-20 | TD-00B    | Pending → Complete | this commit | Added the named `TARGET_DUMMY_PRE_ROLL_MS = 5_000` boundary and a test-only prepared fight from the compact Retail fixture. The focused spike proved `boss: -1` remains eligible, grouped, URL-safe, and renderable without a raid-catalog/core eligibility change; a pre-roll event survives the boundary clamp; current v22 empty equipment slots normalize as positional item-0 placeholders; original player/target GUIDs, names, NPC ID, flags, map ID, timestamp, spell, damage, and resource snapshot remain intact; and the maintained Frost Death Knight parser reaches generated results with zero unknown-ability errors. `./node_modules/.bin/vitest run src/local/target-dummy/minimalHypothesis.test.tsx src/local/target-dummy/test-fixtures.test.ts src/local/LocalCombatLogParser.test.ts` passed (15 tests); `./node_modules/.bin/oxfmt --check src/local/target-dummy/constants.ts src/local/target-dummy/minimalHypothesis.test.tsx docs/specs/target-dummy-implementation-status.md` passed; `./node_modules/.bin/oxlint --max-warnings 0 --deny-warnings src/local/target-dummy/constants.ts src/local/target-dummy/minimalHypothesis.test.tsx` passed with 0 warnings/errors; `./node_modules/.bin/tsc --noEmit` passed; `node scripts/check-static-architecture.mjs` passed; `git diff --check` passed. Vitest emitted the repository's non-failing jsdom canvas diagnostic while importing analyzer chart code and React Router v7 future-flag warnings. No compatibility rewrite was needed. |

## Next recommended work

Start **TD-01A**. Implement discovery contracts, GUID/flag-based actor aggregation, and recorder
selection without retaining complete source lines or normalized event collections.
