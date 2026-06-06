# OneWoW Suite — Remaining migration

Active checklist for work not yet complete. **Implemented architecture** lives in
[`ARCHITECTURE.md`](ARCHITECTURE.md) — read that first.

Delete this file when all steps below are done and their target-state details are
folded into `ARCHITECTURE.md`.

---

## 5. DevTool (partial)

**Done:** `RequiredDeps: OneWoW` (no longer `OneWoW_GUI` only). Lifecycle hooks
from core when loaded.

**Remaining:**

- Fold into the suite package branding (single distributable).
- Tag `utility` in Manage Features so the recommended preset keeps it off.
- Retire standalone CurseForge page.
- **Decide:** convert to `LoadOnDemand: 1` like feature modules (orchestrator skip,
  explicit enable) vs. stay auto-load when Blizzard-enabled.

**Current TOC:**

```
## RequiredDeps: OneWoW
## OptionalDeps: !BugGrabber
```

---

## 6. Absorb `OneWoW_GUI` into core + de-LibStub

Move GUI files into the `OneWoW` load unit (listed first in core TOC). Publish
`OneWoW_GUI` as a plain global instead of a LibStub library.

### Entry point change

```lua
-- before (OneWoW_GUI addon)
LibStub:NewLibrary("OneWoW_GUI-1.0", N)

-- after (inside OneWoW core TOC)
OneWoW_GUI = OneWoW_GUI or {}
```

Keep the global name **`OneWoW_GUI`** (not `OneWoW.GUI`) — consumer migration is a
handle swap only:

```lua
-- before
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

-- after
local OneWoW_GUI = OneWoW_GUI
```

No defensive `if not OneWoW_GUI` guard once everything `RequiredDeps: OneWoW`.

### Same-commit requirements

- Add `"OneWoW_GUI"` to `.luarc.json` `diagnostics.globals`.
- Drop `RequiredDeps: OneWoW_GUI` from every other unit (they keep `RequiredDeps: OneWoW`).
- **Keep LibStub** for vendored Ace libs (`LibDataBroker-1.1`, `LibDBIcon-1.0`,
  `CallbackHandler-1.0`).

### Target TOC shape (post-step-6)

| Load unit | Key directives |
|---|---|
| `OneWoW` | *(no `RequiredDeps`)* · contains GUI + `OneWoW.CopyPaste` + Ace libs · `OptionalDeps: Auctionator, TradeSkillMaster` |
| Feature modules | `RequiredDeps: OneWoW` · `LoadOnDemand: 1` |
| Data stores | `RequiredDeps: OneWoW, OneWoW_<Parent>` · `LoadOnDemand: 1` |

(`OneWoW_GUI` is no longer a separate load unit.)

---

## 7. Relocate `LibCopyPaste` → `OneWoW.CopyPaste`

- Move into the `OneWoW` core addon (after GUI files in TOC — `CopyPaste` may use
  GUI helpers after restyle).
- Drop LibStub + version: `OneWoW.CopyPaste = {}`. Method API (`:Copy`, `:Paste`)
  unchanged.
- Repoint consumers (`OneWoW_Bags` ×3, `OneWoW_Utility_DevTool`, QoL copytext/coords).
- **Follow-up:** restyle UI with `OneWoW_GUI` helpers and localized strings (replace
  hardcoded backdrop/colors and literal `"Close"`).

---

## 8. Update rules + skills + enforcement

### Done

- [x] `bin/check_suite_lifecycle.py` + pre-commit hook `no-suite-lifecycle-events`
- [x] `bin/check_toc_optional_deps.py` + pre-commit hook `no-suite-internal-optionaldeps`
- [x] `.cursor/rules/OneWoW-Suite-Architecture.mdc`
- [x] `.cursor/skills/onewow-suite-architecture/SKILL.md`
- [x] `WoW-Lua-Addon-Development.mdc` suite override blurb (§4.2) + specialist skill entry

### Remaining (after step 6)

- [ ] Revise `.cursor/rules/WoW-Lua-Addon-Development.mdc` §2.3 and the
  `onewow-gui-ui` / `onewow-database-api` skills: `local OneWoW_GUI = OneWoW_GUI`
  instead of the LibStub block.

### `DataManager` enforcement ramp

`bin/check_no_data_manager_bypass.py` (hook `no-data-manager-bypass`) phases direct
cross-family store reads toward `DataManager:Query` (see `ARCHITECTURE.md` §8).

| Phase | Lint behavior | Allowlist | Exit code |
|---|---|---|---|
| **1 — now** | warn-only on cross-family reads | all §4.1 grandfathered reads listed | `0` |
| **2 — migrating** | warn on allowlisted; **fail** on new off-list reads | shrinks per migration PR | `1` for off-list only |
| **3 — rule** | hard-fail on every cross-family read | empty (removed) | `1` |

- [ ] Phase 2: populate `ALLOWLIST` from warn output, set `WARN_ONLY = False`
- [ ] Phase 3: empty allowlist, hard-fail all cross-family reads

Each migration PR deletes allowlist `path::symbol` keys. When the allowlist is
empty, flip to Phase 3.
