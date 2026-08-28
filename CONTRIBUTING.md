# Contributing to OneWoW Suite

Thanks for your interest in contributing! The OneWoW Suite is a multi-addon World of Warcraft Retail project. We welcome help with translations, bug fixes, and feature improvements.

## Dev environment

Public product code lives in this repo. Locale tools, pre-commit checkers,
Cursor skills, and setup scripts live in the private parent repo **OneWoW_Workspace**.
This Suite clone is nested at `OneWoW_Workspace/OneWoW_Suite`. Open the
**OneWoW_Workspace** Cursor workspace only — do not add Suite as a second
workspace root.

- **In Cursor (with OneWoW_Workspace open):** ask *“Set up my OneWoW development
  environment”* or *“Fix Split Repo”*.
- **Manual:** from `OneWoW_Workspace`, run `python bin/setup_dev_env.py`.

Line-ending hooks run from this repo. Lua and locale gates run through
`bin/run_devs.py` when OneWoW_Workspace is the parent of this clone
(`ONEWOW_DEVS` still works as a fallback).

## Before You Start

1. **Fork** this repository on GitHub **to send a pull request**. Forks are for contributing back, not for publishing a modified OneWoW.
2. Create a **feature branch** from `main` (e.g. `feature/my-improvement`)
3. Set up the [dev environment](#dev-environment) (workspace, extensions, pre-commit)
4. Read [OneWoW/Docs/ARCHITECTURE.md](OneWoW/Docs/ARCHITECTURE.md) for suite structure and lifecycle expectations
5. Follow existing code style in the addon you are editing
6. Read [LICENSE.md](LICENSE.md). Private personal tweaks are fine. Do not distribute a modified suite.

## Translation Contributions (Localizations)

The easiest way to help is by improving translations or filling in machine-drafted locale files.

**Authoritative guide:** [OneWoW/Docs/LOCALES.md](OneWoW/Docs/LOCALES.md) — routing decision, scopes, Blizzard-term alignment, tooling.

### Quick summary

The suite supports **11 locales** (TOC order): `enUS`, `koKR`, `frFR`, `deDE`, `zhCN`, `esES`, `zhTW`, `esMX`, `ruRU`, `ptBR`, `itIT`.

Before adding a key, check in order:

1. **Bare Blizzard global** — use `ADD`, `CLOSE`, `SETTINGS`, etc. at the call site with no locale key
2. **`shared` scope** — grep `OneWoW/Locales/Shared/enUS.lua` and reuse via `L["KEY"]`
3. **Addon / module scope** — only for text unique to that load unit (`<Addon>/Locales/`)

QoL external modules use per-module locale scopes — see [OneWoW_QoL/DEVELOPERS.md](OneWoW_QoL/DEVELOPERS.md).

### Workflow

1. Add or edit keys in **`enUS.lua` first** for the target scope
2. Add the **same key to all 11 locale files** in that scope
3. Do not hand-edit `esMX` — from OneWoW_Workspace run `python bin/gen_esmx.py` after `esES` changes
4. **Verify before submitting** (from OneWoW_Workspace, paths relative to Suite):
   - `python bin/locale_keydiff.py --scope <Scope>`
   - `python bin/locale_verify.py <path/to/Locales>` (must exit 0; also the `locale-parity` pre-commit hook)
   - `python bin/check_locale_encoding.py <path/to/Locales>` (must exit 0; also the `locale-encoding` pre-commit hook)

### Translation guidelines

- Every user-visible string must be localized — no English fallbacks in UI code
- Keep `%s`, `%d`, `|c…|r`, and `\n` byte-identical across all locale files
- Locale **values** use ASCII punctuation (`>>`, `...`, ` - `); see `OneWoW/Docs/LOCALES.md`. CJK fullwidth punctuation is allowed. Comments are out of scope.
- Align game terminology to Blizzard GlobalStrings (see LOCALES.md §4)
- Test in-game with the client set to your target language

## Code Contributions

### What we accept

- Bug fixes
- Performance improvements
- UI/UX enhancements that fit the addon's scope
- Code quality improvements

### What we don't accept

- Hard-coded English user-facing text (must use locale strings or Blizzard globals)
- Breaking changes to shared suite APIs without discussion
- New external library dependencies without discussion **and** a
  [THIRD_PARTY.md](THIRD_PARTY.md) (or font license) row in the same change
- Edits inside embedded `Libs/` folders (third-party vendored code)

### Before submitting

1. Test thoroughly in-game
2. Run locale verification if you touched any `Locales/` files
3. Follow existing patterns in the addon you modified
4. Use **LF line endings only** (enforced by `.gitattributes` and pre-commit)
5. Install pre-commit: `python -m pre_commit install`, then `python -m pre_commit run --all-files` before pushing

### Submit your pull request

- Describe what the change does and why
- Include testing details (locales exercised, in-game scenarios)
- Reference related issues when applicable

**Note:** All submissions require approval before merging.

## Code Standards

- **Target:** WoW Retail 12.1+ — prefer `C_*` namespace APIs and `Enum.*` constants
- **Localization:** `L["STRING_KEY"]` for scoped strings; bare globals for Blizzard terms; see LOCALES.md
- **SavedVariables:** use `OneWoW_GUI.DB` — see [OneWoW/Docs/DATABASE.md](OneWoW/Docs/DATABASE.md)
- **UI:** use `OneWoW_GUI` components — see [OneWoW/Docs/GUI.md](OneWoW/Docs/GUI.md)
- **Media:** ship textures/fonts/sounds under `OneWoW/Media/` only (`no-per-addon-media` pre-commit hook)
- **Lifecycle:** suite load units use orchestrator hooks, not per-file `ADDON_LOADED` for init — see ARCHITECTURE.md §3
- **Stores / Manage Features:** keep `ModuleManifest.stores` (ownership) and `FirstRun.CATALOG.datastores` (consumer pulls) in sync when adding packs — `manifest-catalog-alignment` pre-commit; see ARCHITECTURE.md §4.1
- **Comments:** add only where logic is not self-evident
- **Style:** match surrounding code; localize frequently-used globals at file top

## Questions?

- **Issues:** GitHub Issues for bug reports
- **Discussions:** GitHub Discussions for questions and ideas

## QoL modules

Original drop-in modules under `OneWoW_QoL/Modules/external/<id>/` are welcome.
Follow [OneWoW_QoL/DEVELOPERS.md](OneWoW_QoL/DEVELOPERS.md). Submit them as a
pull request so they can be reviewed and shipped with the suite.

Set `author` in `module.lua` to **your name** (plain text). Players see it in
the module's Details dialog. Leave it empty only if the module is OneWoW team
work — empty means the OneWoW Development Team.

Submitting does **not** give OneWoW exclusive ownership. The OneWoW
Development Team may change, modify, or edit the shipped module at any time.
Your name stays on Details until a complete rewrite; then you keep
**concept** credit in [MODULE_CREDITS.md](MODULE_CREDITS.md).

If you want your own terms, put a `LICENSE` in the module folder (must still
be compatible with official OneWoW). If you do not, the module is a
contribution to the OneWoW Development Team and that copy becomes OneWoW
codebase ([LICENSE.md](LICENSE.md)).

## License

See [LICENSE.md](LICENSE.md). Copyright the OneWoW Development Team except
third-party files in [THIRD_PARTY.md](THIRD_PARTY.md) and community modules
in [MODULE_CREDITS.md](MODULE_CREDITS.md) that name their own license.

By submitting a pull request you grant the team the right to include,
modify, and ship your work as part of official OneWoW. A named license is
**non-exclusive** (you keep your rights elsewhere). Unlicensed
contributions become part of the OneWoW codebase under LICENSE.md.

---

**Thank you for helping improve OneWoW Suite!**
