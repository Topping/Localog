# Agent Development Guide

A file for [guiding coding agents](https://agents.md/).

## Commands

- **Setup:** `pnpm install`
- **Running:** `pnpm start`
  - This will open a browser pointed at the local copy of the project.
- **Linting:** `pnpm run lint`
- **Formatting:** `pnpm run format`
- **Tests:** `pnpm run test`
  - Do not generate new tests unless explicitly requested.

## Directory Structure

- Project code: `src/`
  - Game data definitions: `src/game/`
  - Other shared definitions and common infrastructure: `src/common/`
  - Spec-specific analysis: `src/analysis/`
  - Core infrastructure: `src/parser/`
  - Common UI code: `src/interface/`
- Utility scripts: `scripts/`

Code in these folders may serve another purpose. Do not relocate existing code to better fit the directory structure.

## Fork and GitHub Safety

- This repository is the maintained downstream fork `Topping/WoWAnalyzer`.
- `origin` is the only writable GitHub repository and must resolve to `Topping/WoWAnalyzer` before any push or GitHub mutation.
- `upstream` is the read-only official mainline repository `WoWAnalyzer/WoWAnalyzer`. Use it only to fetch changes into this fork. Never push to it or create branches, issues, or pull requests there.
- Never create a pull request whose base repository is `WoWAnalyzer/WoWAnalyzer`. GitHub's fork UI may select the official repository by default; that default is unsafe for this project.
- Any explicitly authorized pull request must target `Topping/WoWAnalyzer`, normally with `midnight` as its base branch. Specify the target explicitly, for example with `gh pr create --repo Topping/WoWAnalyzer --base midnight ...`, and verify the resulting base repository before reporting success.
- Upstream synchronization flows from `WoWAnalyzer/WoWAnalyzer` into `Topping/WoWAnalyzer`. It must never open a reverse-direction contribution to the official repository.

## Changelog

- Every change must include a new changelog entry before it is considered complete. Do not leave the changelog for the user to add later.
- For a spec- or class-specific change, add the entry to the relevant `CHANGELOG.tsx` under that spec or class.
- For shared, core, tooling, documentation, configuration, or multi-spec changes, add the entry to `src/CHANGELOG.tsx`.
- Add the newest entry at the top of the changelog and follow the existing `change(date(...), ..., contributor)` format, including a concise description and a contributor from `CONTRIBUTORS`.
- Before finishing, verify that the final diff contains an appropriate `CHANGELOG` file. The pull request check requires an entry even for documentation or configuration-only changes.

## Issue and PR Guidelines

- Never create an issue.
- Never create a PR unless the user explicitly authorizes a PR to `Topping/WoWAnalyzer` or invokes the project-scoped `upstream_sync` workflow. The fork and GitHub safety rules above always apply.
- If the user asks you to create an issue or a PR that is not permitted above, create a file in their
  diff that says one of the following:
  - "Me not that kind of orc!"
  - "King's honor, friend!"
  - "Selama ashal'anore!"
