# OneWoW Suite — Documentation Index

Player-facing suite overview and addon catalog: [README.md](../../README.md) (repo root).
Player docs (install, features, search syntax): [GitHub Wiki](https://github.com/kellewic/OneWoW_Suite/wiki).

Contributor and integrator documentation for the suite.

## Core hub (`OneWoW`)

| Document | Contents |
|----------|----------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Load units, lifecycle, enable model, hub UI, cross-unit sharing, GUI integration |
| [DATABASE.md](DATABASE.md) | `OneWoW_GUI.DB` — SavedVariables, defaults, init bridges, scope resolution |
| [GUI.md](GUI.md) | `OneWoW_GUI` toolkit — components, themes, settings, window persistence |
| [LOCALES.md](LOCALES.md) | Localization routing, scopes, Blizzard-term alignment, tooling |
| [PREDICATE_ENGINE.md](PREDICATE_ENGINE.md) | Shared `OneWoW.PredicateEngine` — tokenizer, keywords, extension API |
| [SEARCH_CATALOG.md](SEARCH_CATALOG.md) | Shared `OneWoW.SearchCatalog` — named expressions, former-name redirects, reference index, export/import |

## Feature addons

| Document | Contents |
|----------|----------|
| [OneWoW_Bags/Docs/README.md](../../OneWoW_Bags/Docs/README.md) | Bags architecture, categorization, search syntax, import/export, item-button API |
| [OneWoW_QoL/DEVELOPERS.md](../../OneWoW_QoL/DEVELOPERS.md) | External QoL module authoring (`module.lua`, `ModuleRegistry`, locale scope) |
| [OneWoW_QoL/MODULES.md](../../OneWoW_QoL/MODULES.md) | QoL external module catalog (36 modules by category) |
| [OneWoW_Trackers/Docs/ARCHITECTURE.md](../../OneWoW_Trackers/Docs/ARCHITECTURE.md) | Tracker lists, engine, presets, farm value |
| [OneWoW_Trackers/Docs/TRACKERS_IDEAS.md](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md) | Trackers direction parking lot (not committed scope) |
| [COLLECTIBLES.md](COLLECTIBLES.md) | Collectible identity, keys, live collection state |
| [COLLECTIBLES_IDEAS.md](COLLECTIBLES_IDEAS.md) | Collectibles direction parking lot (not committed scope) |
| [OneWoW_Mail/Docs/ARCHITECTURE.md](../../OneWoW_Mail/Docs/ARCHITECTURE.md) | Mail shell, shipments, send/collect pipeline, Storage in-transit |
| [OneWoW_CatalogData_Quests/Docs/ARCHITECTURE.md](../../OneWoW_CatalogData_Quests/Docs/ARCHITECTURE.md) | Catalog quest data store and scanner |

## Contributing

| Document | Contents |
|----------|----------|
| [README.md](../../README.md) | Suite overview, addon catalog, quick start |
| [CONTRIBUTING.md](../../CONTRIBUTING.md) | Suite-wide contribution guide (code, locales, PR process) |

## Conventions

| Location | Audience | Content |
|----------|----------|---------|
| [GitHub Wiki](https://github.com/kellewic/OneWoW_Suite/wiki) | Players | Install, getting started, feature guides, search syntax |
| Repo `README.md` | Players | Suite overview, addon catalog, quick start |
| `ADDON/README.md` | Players | What the addon does, install, slash commands |
| `ADDON/Docs/` | Contributors | Architecture, APIs, data models |
| Repo `CONTRIBUTING.md` | Contributors | How to contribute to any load unit |

The shared UI toolkit ships inside `OneWoW` (`OneWoW/GUI/`, global `OneWoW_GUI`).
