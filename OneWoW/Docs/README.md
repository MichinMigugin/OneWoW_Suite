# OneWoW Suite — Documentation Index

Contributor and integrator documentation for the suite.

## Core hub (`OneWoW`)

| Document | Contents |
|----------|----------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Load units, lifecycle, enable model, hub UI, cross-unit sharing, GUI integration |
| [DATABASE.md](DATABASE.md) | `OneWoW_GUI.DB` — SavedVariables, defaults, migrations, scope resolution |
| [GUI.md](GUI.md) | `OneWoW_GUI` toolkit — components, themes, settings, window persistence |
| [LOCALES.md](LOCALES.md) | Localization routing, scopes, Blizzard-term alignment, tooling |
| [PREDICATE_ENGINE.md](PREDICATE_ENGINE.md) | Shared `OneWoW.PredicateEngine` — tokenizer, keywords, extension API |

## Feature addons

| Document | Contents |
|----------|----------|
| [OneWoW_Bags/Docs/README.md](../../OneWoW_Bags/Docs/README.md) | Bags architecture, categorization, search syntax, import/export, item-button API |
| [OneWoW_QoL/DEVELOPERS.md](../../OneWoW_QoL/DEVELOPERS.md) | External QoL module authoring (`module.lua`, `ModuleRegistry`, locale scope) |
| [OneWoW_QoL/MODULES.md](../../OneWoW_QoL/MODULES.md) | QoL external module catalog (34 modules by category) |
| [OneWoW_Trackers/Docs/ARCHITECTURE.md](../../OneWoW_Trackers/Docs/ARCHITECTURE.md) | Tracker lists, engine, presets, farm value |
| [OneWoW_CatalogData_Quests/Docs/ARCHITECTURE.md](../../OneWoW_CatalogData_Quests/Docs/ARCHITECTURE.md) | Catalog quest data store and scanner |

## Contributing

| Document | Contents |
|----------|----------|
| [CONTRIBUTING.md](../../CONTRIBUTING.md) | Suite-wide contribution guide (code, locales, PR process) |

## Conventions

| Location | Audience | Content |
|----------|----------|---------|
| `ADDON/README.md` | Players | What the addon does, install, slash commands |
| `ADDON/Docs/` | Contributors | Architecture, APIs, data models |
| Repo `CONTRIBUTING.md` | Contributors | How to contribute to any load unit |

The shared UI toolkit ships inside `OneWoW` (`OneWoW/GUI/`, global `OneWoW_GUI`). The separate `OneWoW_GUI` load unit is a transitional SavedVariables stub for migration only — not a user-facing dependency.
