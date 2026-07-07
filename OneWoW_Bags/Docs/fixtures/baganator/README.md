# Baganator import fixtures

Sample export strings for manual QA and future offline decode tests.

| File | Description |
|------|-------------|
| `migration_v2.json` | Real user migration export (12 custom categories, sections, mods) — no `addon` field |
| `retail_default_v2.json` | Baganator retail default layout (empty `categories`, full `order`) |
| `v1_legacy.json` | v1 export with `_EQUIPMENT` / `_CRAFTING` section markers (migrated to `_1` / `_2`) |
| `v3_categories.bgr` | **In-game only** — export categories from Baganator's Copy button (`BGR!1!` + CBOR). Paste path is implemented; capture a string here when testing v3 decode. |

## Manual QA checklist

1. Paste `migration_v2.json` → preview shows customs + sections + mods; Warbound rule translates to `#tww`, `#armor`, `#boe` (not bare `Armor`).
2. Paste a live `BGR!1!` export → same preview as equivalent JSON.
3. **Baganator (direct)** with Baganator loaded → matches paste when config is equivalent.
4. Paste `v1_legacy.json` → `_EQUIPMENT` becomes section `_1` named `EQUIPMENT`.
5. Paste a `kind: "profile"` export → clear error, no DB mutation.
6. **Undo** restores pre-import state.
7. `migration_v2.json` modifications with `"group": "type"` preview as `groupBy: "subtype"` (Baganator type = subclass).
8. Modifications with `"group": "track"` preview as `groupBy: "track"` with no skip warning.
