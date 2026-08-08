# Contributing to OneWoW Suite

Thanks for your interest in contributing! The OneWoW Suite is a multi-addon World of Warcraft Retail project. We welcome help with translations, bug fixes, and feature improvements.

## Dev environment

For the dual-root Cursor / VS Code workspace (`OneWoW_Suite` + sibling
`_OneWoW_Offline`), Python 3.12+, Lua/Ketho extensions, and pre-commit hooks:

- **In Cursor:** ask *“Set up my OneWoW development environment”* (loads the
  `onewow-dev-setup` skill).
- **Manual / details:** [devconfig/README.md](devconfig/README.md) and
  `python bin/setup_dev_env.py`.

## Before You Start

1. **Fork** this repository
2. Create a **feature branch** from `main` (e.g. `feature/my-improvement`)
3. Set up the [dev environment](#dev-environment) (workspace, extensions, pre-commit)
4. Read [OneWoW/Docs/ARCHITECTURE.md](OneWoW/Docs/ARCHITECTURE.md) for suite structure and lifecycle expectations
5. Follow existing code style in the addon you are editing

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
3. Do not hand-edit `esMX` — run `python bin/gen_esmx.py` after `esES` changes
4. **Verify before submitting:**
   - `python bin/locale_keydiff.py --scope <Scope>`
   - `python bin/locale_verify.py <path/to/Locales>` (must exit 0; also runs as the `locale-parity` pre-commit hook)

### Translation guidelines

- Every user-visible string must be localized — no English fallbacks in UI code
- Keep `%s`, `%d`, `|c…|r`, and `\n` byte-identical across all locale files
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
- New external library dependencies without discussion
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

- **Target:** WoW Retail 12.0+ — prefer `C_*` namespace APIs and `Enum.*` constants
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

## License

All contributions must be compatible with the project license. By submitting, you agree your work can be included under the same terms.

---

**Thank you for helping improve OneWoW Suite!**
