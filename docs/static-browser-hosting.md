# Static browser variant

This variant runs the WoWAnalyzer shell and analysis pipeline from static files. Local combat logs are parsed in a worker, normalized, chunked, and stored in IndexedDB. Warcraft Logs reports are fetched by the browser from the official WCL v2 GraphQL user API and then adapted to the same `AnalysisDataSource` contract.

Static hosting does not mean offline use. WCL reports need a WCL connection and sign-in, Wowhead tooltips and fonts may use their own networks, and the application can contain external links. A local file is not uploaded for analysis; its normalized data remains in this origin's browser storage until it is deleted or the browser evicts site data.

## Local development

```sh
pnpm install
pnpm start
```

Local-file analysis works without additional configuration. WCL is hidden by a build-time feature
flag by default. To enable it, create `.env.local`:

```dotenv
VITE_ENABLE_WCL=true
VITE_WCL_CLIENT_ID=your_public_client_id
VITE_WCL_REDIRECT_URI=http://localhost:3000/
```

Register that exact redirect URI in the [Warcraft Logs client management page](https://www.warcraftlogs.com/api/clients/). The browser uses OAuth authorization code + PKCE. Do not put a client secret in any `VITE_` variable, repository secret used by the build, or Pages artifact.

Build and preview a root deployment with `pnpm preview`. To simulate a GitHub Pages project site:

```sh
VITE_BASE_PATH=/WoWAnalyzer/ pnpm build
VITE_BASE_PATH=/WoWAnalyzer/ pnpm exec vite preview
```

The production router is hash-based. When WCL is enabled, a copied route looks like
`/WoWAnalyzer/#/report/...` and can be loaded directly from static hosting. A local report URL works
only in the same origin and browser profile where its IndexedDB record exists.

## GitHub Pages

The `pages.yml` workflow builds with `VITE_ENABLE_WCL=false`,
`VITE_BASE_PATH=/<repository-name>/`, and deploys `dist/`. While that flag is disabled, the WCL
report entry point, report route, and OAuth callback handling are omitted from the app. To enable it
later, change the workflow flag to `true` and configure these repository **Actions variables**:

- `WCL_CLIENT_ID`: the public WCL OAuth client ID; omit it for a local-file-only deployment.
- `WCL_REDIRECT_URI`: normally `https://<owner>.github.io/<repository>/` and registered exactly at WCL.

Enable GitHub Pages with **GitHub Actions** as its source. The workflow runs formatting, linting, type checking, unit tests, the production build, a static-architecture/artifact scan, and the local import/analyze/reopen/delete journey in Chromium and Firefox before deployment. Sentry, Google Analytics, advertisements, premium/account startup, metrics upload, and source maps are disabled in the static workflow.

## Supported paths and limitations

- Local imports currently target current Retail advanced combat logs. Incompatible parser/schema versions are recoverable by deleting and re-importing the report.
- A standalone target-dummy capture uses the same file picker. The optional, separately installable
  `wow-addon/Localog_Companion` addon guides advanced logging, records pull-time character stats and
  one readable aura snapshot, and produces a single Localog Companion export. After discovery,
  choose the matching player and attempt and paste that value. WoW may append multiple logging
  sessions to one physical file; stopping and restarting combat logging writes the boundary Localog
  uses to inspect the newest session first. A newest standalone target-dummy session can therefore
  be imported without parsing an older raid prefix. If the newest session is not a target-dummy
  capture, Localog falls back to whole-file encounter discovery so encounters from older sessions
  are not lost.
- Genuine encounters still take precedence within one uninterrupted logging session. To isolate a
  target-dummy capture after raiding, stop logging before beginning the capture (or rotate the file)
  and then start it again. Localog Companion does not stop logging that was already active when it
  began, so pre-existing logging must be restarted manually when this boundary is needed.
- Target-dummy preparation currently supports only Retail project 1, combat-log version 22, WoW
  12.1.0, and its checked-in talent snapshot. Character identity, spec, decoded talents, equipped
  items, exact pull-time ratings/effective attributes, and safely sourced pull-time auras come from
  the Localog Companion export. Plain `/simc` imports retain explicit zero defaults; companion stat
  capture is all-or-nothing, partial/source aura omissions are reported, and an equipped item
  without an item level blocks import. Player/build identity is enforced, while the user's selected
  attempt is authoritative.
- Target-dummy discovery and normalization stay in the browser worker. Only the selected attempt's
  analyzed window is normalized into IndexedDB, with a five-second pre-roll clamped to the source
  segment boundary. For a newest-session target-dummy import, both semantic discovery and
  normalization read that session's byte range instead of an older physical-file prefix; the source
  file is not uploaded.
- When enabled, WCL report metadata, combatant information, paginated events, filtered events, tables, and graphs use WCL v2. Access-token state is session-scoped; expiry asks the user to sign in again and does not affect local reports.
- Character, guild, premium/account, aggregate support-statistics, and remote character-profile pages are not part of the first static milestone.
- Features backed by a WCL-only aggregate are modeled as optional capabilities. A local report gets an explicit unavailable result instead of a WCL request or a fabricated zero.
- Unknown spell metadata uses the bundled catalog and a deterministic unknown-spell label/icon; there is no WoWAnalyzer server fallback.

The project remains AGPL-3.0-or-later and derives from [WoWAnalyzer](https://github.com/WoWAnalyzer/WoWAnalyzer). Fork deployments must preserve the license, upstream attribution, and a link to their corresponding modified source.
