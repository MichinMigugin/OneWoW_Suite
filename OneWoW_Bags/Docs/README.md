# OneWoW_Bags — Documentation Index

Contributor and integrator docs for OneWoW_Bags. These files are **not** loaded by the addon TOC.

## Architecture & behavior

| Document | Contents |
|----------|----------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Load order, layered MVC, data/layout/settings pipelines, DB schema, init bridges, performance, refresh targets |
| [CATEGORIZATION.md](CATEGORIZATION.md) | `GetItemCategory` / `ResolveBaseCategory`, tie-breaking, section layout, per-category sort/group/stack |
| [SEARCH_SYNTAX.md](SEARCH_SYNTAX.md) | Predicate expression language (`#keywords`, operators, properties, `SAVED(Name)`, `CATEGORY(Name)`) |
| [IMPORT_EXPORT.md](IMPORT_EXPORT.md) | Category/section bundle import/export, preview dialog, merge rules, undo |

## Third-party integration

| Document | Contents |
|----------|----------|
| [ITEM_BUTTON.md](ITEM_BUTTON.md) | `RegisterItemButtonCallback` API (canonical reference) |
| [../API/README.md](../API/README.md) | Quick start for addon authors |
| [../API/INTEGRATION_GUIDE.md](../API/INTEGRATION_GUIDE.md) | Step-by-step integration walkthrough |
| [../API/Examples/](../API/Examples/) | Copy-paste overlay examples |

## Related (outside this folder)

| Document | Contents |
|----------|----------|
| [../../OneWoW/Docs/PREDICATE_ENGINE.md](../../OneWoW/Docs/PREDICATE_ENGINE.md) | Shared `OneWoW.PredicateEngine` — tokenizer, `BuildProps`, caches, extension API |
| [../../OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) | Suite loader, `LoadOnDemand`, lifecycle hooks, hub integration |
| [../../CONTRIBUTING.md](../../CONTRIBUTING.md) | Suite contribution guide |
