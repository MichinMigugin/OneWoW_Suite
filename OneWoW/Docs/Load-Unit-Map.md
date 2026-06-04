# OneWoW Suite — Load-Unit Map

> **Status:** design proposal, partially implemented. Describes how the suite is
> partitioned into *load units* (addons / TOCs) and how plain `## LoadOnDemand: 1`
> + a **core-driven load lifecycle** (the orchestrator loads each unit, then calls
> its `OnAddonLoaded()` hook — §5) wires them together so that the **"true core" +
> per-module enable/disable/unload** model survives consolidation into a single
> distributable package. (`LoadWith` / `LoadManagers` were evaluated and retired —
> see §5 and §8.1.)
>
> **Key decisions captured here:** `OneWoW_GUI` and `LibCopyPaste` are absorbed
> into the always-loaded `OneWoW` core unit and stop using LibStub (§6.1);
> `OneWoW_GUI` is published as a plain global, `LibCopyPaste` becomes the
> `OneWoW.CopyPaste` service; `OneWoW_Bags` and `OneWoW_Utility_DevTool` are
> promoted to `RequiredDeps: OneWoW`. LibStub itself is retained **only** for the
> vendored Ace libs (`LibDataBroker-1.1`, `LibDBIcon-1.0`, `CallbackHandler-1.0`).

---

## 1. The core tension this solves

The grand vision wants a *single* OneWoW suite. The existing **Manage Features**
screen (`Core/FirstRunWizard.lua`) lets the user *truly unload* heavy modules and
data via `C_AddOns.DisableAddOn` + `ReloadUI`.

These pull in opposite directions:

- **One literal TOC** → WoW parses **every** file at login. "Disabling" a module
  can only mean a *runtime* skip; the Lua and the multi-MB data tables
  (`CatalogData_*`, `AltTracker_*`, DevTool atlases/sounds) stay resident every
  session. **True unload is lost.**
- **Per-module TOCs** → `DisableAddOn` keeps those files out of memory entirely.
  This is what we have today, and it is *load-bearing for a shipping feature.*

**Resolution:** the thing that became "too much to track" was **separate
CurseForge pages**, not separate TOCs. Those are different axes:

| Axis | Old | Now | Target |
|---|---|---|---|
| Distribution (CurseForge pages) | many | one package (+ DevTool) | **one package** (DevTool folded in) |
| Install footprint | many installs | one install, expands to folders | one install |
| **Load units (TOCs)** | many | many | **stay many** |
| Namespace / branding | scattered | unified | unified |

So **"Single TOC for the whole suite" is reinterpreted as "single package /
single install / unified hub, with the core as one always-loaded addon and
heavy or optional modules as their own load-units."**

---

## 2. Load-unit tiers

| Tier | Load unit(s) | Loads | Mechanism |
|---|---|---|---|
| **0 — Foundation (inside core)** | `OneWoW_GUI` files + `CopyPaste` service | Always, first within core | **Folded into the `OneWoW` load unit** (§6.1). Not a separate addon. `OneWoW_GUI` published as a plain global; `CopyPaste` as `OneWoW.CopyPaste`. No LibStub. |
| **1 — Core hub** | `OneWoW` | Always | **No `RequiredDeps`** (it *contains* the foundation). Engines (overlay/tooltip/toast), `ModuleRegistry`, Manage Features, hub UI, cheap shared `Services`, plus the GUI toolkit + CopyPaste. |
| **2 — Feature modules** | `OneWoW_AltTracker`, `OneWoW_Catalog`, `OneWoW_Notes`, `OneWoW_Trackers`, `OneWoW_QoL`, `OneWoW_ShoppingList`, `OneWoW_DirectDeposit`, `OneWoW_Bags` | On demand | `RequiredDeps: OneWoW` + `LoadOnDemand: 1` (DBM idiom). Core's orchestrator calls `C_AddOns.LoadAddOn`, then the unit's `OnAddonLoaded()` hook (§5). |
| **3 — Data sub-units** | `OneWoW_AltTracker_{Storage,Character,Collections,Endgame,Accounting,Professions,Auctions}`, `OneWoW_CatalogData_{Journal,Quests,Vendors,Tradeskills}` | On demand, after their parent | `RequiredDeps: …, <parent>` + `LoadOnDemand: 1`. Listed under the parent in `ModuleManifest.stores`; the orchestrator loads each explicitly after the parent (§5), driving its `OnAddonLoaded()` hook. Cross-module consumers read guarded (§4). |
| **4 — Utility (in-suite, off by default)** | `OneWoW_Utility_DevTool` | On demand / opt-in | Ships inside the package as a managed sub-addon. `RequiredDeps: OneWoW` + `LoadManagers: OneWoW`; excluded from the "recommended" preset so it stays disabled unless a developer opts in. |

### Why these tiers

- **GUI is absorbed into core (not a separate LibStub library).** The only thing
  LibStub bought was version negotiation across independently-shipped *embedded*
  copies — which never applies to a suite-internal toolkit shipped exactly once.
  Once every consumer `RequiredDeps: OneWoW`, there are no out-of-band consumers
  left, so GUI folds into the `OneWoW` unit and is published as the `OneWoW_GUI`
  global. Cross-load-unit modules still reach it through that global (the real
  invariant is the load-unit boundary, not LibStub). See §6.1.
- **Engines stay in Tier 1 (always loaded).** Overlay/tooltip/toast are
  multi-consumer infrastructure (Bags, Notes, DirectDeposit already use them) and
  their config UI floats into the optional QoL module — so the core must own the
  engine *and* a fallback config home even when QoL is unloaded (it already does;
  see `GUI/t-settings.lua:BuildSettingsTabs`).
- **Bags is no longer semi-standalone.** It is promoted to `RequiredDeps: OneWoW`:
  a GUI-only Bags is a degraded shell (overlays, upgrade detection, tooltip
  engines are all core), and once GUI lives in core there is no "GUI without core"
  to run against anyway. Its only remaining optional edge is the guarded
  `OneWoW_AltTracker_Character_API` read.

---

## 3. Per-unit TOC recipe

### Tier 0 — Foundation (folded into `OneWoW`)

There is **no** standalone `OneWoW_GUI` TOC in the target. The GUI files and the
`CopyPaste` service become source folders inside the `OneWoW` addon, listed first
in its TOC (foundation loads before consumers). See §6.1 for the global-publish
mechanics, de-LibStub, and load ordering.

### Tier 1 — `OneWoW` (self-contained core; gains a load orchestrator)

```
## OptionalDeps: Auctionator, TradeSkillMaster
## Group: OneWoW
```

> No `RequiredDeps` — core *is* the foundation now. The vendored Ace libs
> (`LibStub`, `LibDataBroker-1.1`, `LibDBIcon-1.0`, `CallbackHandler-1.0`) still
> load first inside this unit's TOC, since `LibDataBroker`/`LibDBIcon` require
> LibStub.

### Tier 2 — Feature modules

Add one directive; deps simplify to just `OneWoW` (GUI lives in core now). Example
(`OneWoW_AltTracker`):

```
## RequiredDeps: OneWoW
## LoadOnDemand: 1
## Group: OneWoW_AltTracker
```

`OneWoW_Bags` is **promoted to `RequiredDeps: OneWoW`** (no longer semi-standalone):

```
## RequiredDeps: OneWoW
## OptionalDeps: OneWoW_AltTracker, OneWoW_ShoppingList, TradeSkillMaster, Baganator, Masque
## LoadOnDemand: 1
## Group: OneWoW
```

> Plain `## LoadOnDemand: 1` (the DBM idiom), not `LoadManagers: OneWoW`: every
> unit `RequiredDeps: OneWoW`, so the core is always present and owns loading via
> the orchestrator (§5) — there is no "manager-absent ⇒ auto-load" case to cover.

### Tier 3 — Data sub-units

**Stores are plain `## LoadOnDemand: 1`; the core orchestrator loads each after
its parent.** `LoadWith` was tried and retired (§5/§8.1): auto-loading a store
inside its parent's load eats the store's own `ADDON_LOADED`, so its DB never
initialized. Instead each store is listed under its parent in
`ModuleManifest.stores`, and the orchestrator `EnsureLoaded`s it explicitly —
driving its `OnAddonLoaded()` hook deterministically. `RequiredDeps` on the parent
still guarantees ordering (and the disabled-parent cascade). The cross-trace (§4)
proves every cross-module/cross-family access is optional and nil-guarded.

`OneWoW_AltTracker_Storage` (and every other `AltTracker_*` store):

```
## RequiredDeps: OneWoW, OneWoW_GUI, OneWoW_AltTracker
## LoadOnDemand: 1
## Group: OneWoW_AltTracker
```

All four `CatalogData_*`:

```
## RequiredDeps: OneWoW, OneWoW_GUI, OneWoW_Catalog
## LoadOnDemand: 1
## Group: OneWoW_Catalog
```

> `RequiredDeps` is kept on Tier-3 units for *ordering* (parent loads before child)
> and for the disabled-parent dependency cascade; the **orchestrator** is what
> triggers the load (no `LoadWith` auto-load).

**Why orchestrate instead of multi-consumer `LoadWith`?** Even parent-only
`LoadWith` had the eaten-`ADDON_LOADED` problem; multi-consumer would also force a
store's `RequiredDeps` chain into memory for unrelated consumers. Since every
consumer already tolerates the store's absence, the orchestrator loads each store
once, after its parent. For the case where a consumer wants a store *even when the
owner module is disabled* (e.g. Catalog AH scan → `AltTracker_Auctions`), use lazy
`EnsureLoaded` on demand (§5.1).

### Tier 4 — `OneWoW_Utility_DevTool` (now a managed sub-addon)

DevTool folds into the suite package. It is `LoadManagers: OneWoW` like a feature
module, but the `FirstRunWizard` "recommended" preset already excludes the
`utility` group, so it stays disabled until a developer opts in.

```
## RequiredDeps: OneWoW
## OptionalDeps: !BugGrabber
## LoadManagers: OneWoW
## Group: OneWoW
```

> Promoted to `RequiredDeps: OneWoW` — with GUI absorbed into core, the toolkit it
> needs lives in `OneWoW`, so requiring core is both correct and gives it access
> to `OneWoW.CopyPaste` (which it uses). Dropping its standalone CurseForge page
> means one less thing to track; users who don't develop simply leave it off.

---

## 4. Cross-trace — who actually touches each store

Traced by searching every store's global identifiers (`*_DB`, `*_API`, table
globals) across the whole suite, then reading each call site to classify it.
Legend: **P** = parent (the orchestrator loads the store after it) · **M** = other
feature module (guarded, not a load trigger) · **F** = cross-family data addon
(guarded) · **C** = core, always loaded (must be nil-guarded; never a load trigger).

| Store | P (parent) | M / F consumers (guarded) | C core refs (guarded) | Access |
|---|---|---|---|---|
| `AltTracker_Storage` | AltTracker | Catalog, ShoppingList, Bags(`StorageAPI`) | `tp-itemtracker` | `_DB`, `_API` |
| `AltTracker_Character` | AltTracker | Bags(`_API`), Notes(`_DB`) | `t-overlays`, `upgrade-detection`, `tp-recipeknowledge`, `tp-gearupgrades` | `_DB`, `_API` |
| `AltTracker_Professions` | AltTracker | Catalog, QoL/professionspanel | `tp-recipeknowledge`, `RecipeKnownUtil` | `_DB` |
| `AltTracker_Collections` | AltTracker | **F:** CatalogData_Quests(`_API`) | dashboards | `_API` |
| `AltTracker_Endgame` | AltTracker | — | dashboards | `_DB` |
| `AltTracker_Accounting` | AltTracker | **F(intra):** Storage/Mail | `t-financials`(parent) | `_DB` |
| `AltTracker_Auctions` | AltTracker | Catalog (**lazy**, AH scan); **F(intra):** Storage/ItemIndex | `ItemPrices`, `t-tooltips`, `tp-pets` | `_DB`, table |
| `CatalogData_Journal` | Catalog | — | `t-tooltips`, `tp-itemtracker`, `toast-instance`, `portalhub-esc-panels` | `_DB` |
| `CatalogData_Quests` | Catalog | Notes/t-npcs; **F:** AltTracker(MigrationFix, t-settings) | dashboards | `_DB` |
| `CatalogData_Vendors` | Catalog | — | `ContextMenus`, `t-tooltips`, `tp-itemtracker` | `_DB` |
| `CatalogData_Tradeskills` | Catalog | ShoppingList, QoL/professionspanel | — | `_DB` |

> **Not WoW load units (excluded):** `OneWoW_AccountSync` (Go desktop companion),
> `bin/audit-tools`, `.luarc.json`, `README.md`, `summary.json`.

### 4.1 Findings from the cross-trace

1. **Every cross-module read is guarded — confirmed at the call site.** Examples:
   `OneWoW_Bags/GUI/BagsBar.lua:293` (`if not OneWoW_AltTracker_Character_API then … return`),
   `OneWoW_Notes/UI/t-players.lua:101` (`IsAddOnLoaded("OneWoW_AltTracker_Character")`),
   `OneWoW_Catalog/Modules/m-itemsearch.lua:27/95/176` (`if not profsDB`/`if not sdb`/`if adb and …`),
   `OneWoW_QoL/.../professionspanel.lua:184/205`,
   `OneWoW_CatalogData_Quests/Modules/CompletionTracker.lua:20` (`if not altApi … return`).
   ⇒ **No store needs a non-parent `LoadWith`; nothing breaks if a store is absent.**

2. **Stores expose two globals:** `OneWoW_<X>_DB` (raw SavedVariable) and
   `OneWoW_<X>_API` (function table). Cross-module consumers should prefer the
   `_API` surface; treat `_DB` as private. (Bags already uses `_API`; ShoppingList
   and Catalog still poke `_DB` directly — a refactor target, not a load issue.)

3. **`FirstRunWizard` datastore mapping was stale for ShoppingList — FIXED.** The
   catalog mapped `OneWoW_ShoppingList → {Storage, Professions}`, but the code
   actually reads `OneWoW_AltTracker_Storage` **and `OneWoW_CatalogData_Tradeskills`**
   (not `Professions`) — see `OneWoW_ShoppingList/Modules/DataAccess.lua:12,153`.
   `FirstRunWizard.CATALOG` now lists `{Storage, CatalogData_Tradeskills}`.
   Caveat: both stores still need their *parent* feature enabled to load
   (`Storage`→AltTracker, `Tradeskills`→Catalog), since the auto-follow only
   toggles data addons, not the parent modules they `RequiredDeps`. The
   `LoadManagers`/orchestrator work in §5 is what fully resolves that.

4. **Cross-*family* optional deps exist** and are fine because they're guarded:
   `CatalogData_Quests → AltTracker_Collections`, and `AltTracker → CatalogData_Quests`.
   These would create a `LoadWith` cycle risk if wired declaratively — another
   reason to keep `LoadWith` parent-only and rely on graceful degradation.

5. **Intra-family store-to-store reads** (`Storage → Accounting`, `Storage → Auctions`)
   need no special wiring: all `AltTracker_*` stores share the parent and are
   loaded together by the orchestrator right after `OneWoW_AltTracker`.

6. **Core (`OneWoW`) reads many stores opportunistically** (tooltips, overlays,
   upgrade detection, dashboards). Because core is always loaded and stores are
   not, **every one of these must stay nil-guarded** and must never be expressed as
   a dependency that would force a store to load.

---

## 5. Two-level enable model (ModuleRegistry)

With Tier-2/4 as plain `## LoadOnDemand: 1`, modules **do not auto-load**; the core
decides. This yields two distinct toggles, mapping cleanly to the grand-vision
`Enable / Disable / Unload / Pin`:

| Action | Mechanism | Reload? |
|---|---|---|
| **Enable** | core `C_AddOns.LoadAddOn(name)` | **No** |
| **Disable (not yet loaded this session)** | core soft-flag in SavedVariables; simply never `LoadAddOn` | **No** |
| **Unload (already loaded this session)** | WoW cannot unload in-session → `DisableAddOn` + `ReloadUI` | **Yes** |
| **Pin / load at login** | core `LoadAddOn`s it during its own `ADDON_LOADED` (before `PLAYER_LOGIN`) | n/a |

Net effect: **reloads become rare** — only when turning *off* a module that was
already loaded this session. Today every change prompts a reload.

Keep the existing **hard disable** path (`DisableAddOn`) available for "I never
want this loaded" — it guarantees the files stay off disk-to-memory even if core
has a bug.

### Load phases (new `ModuleRegistry` field)

A module must declare *when* it needs to load if enabled, because some modules
have passive behavior that must be live before any window is opened:

- **`login`** — must be in memory before `PLAYER_LOGIN` if enabled (the core
  pulls it during its own `ADDON_LOADED`). Use for modules that register tooltip
  providers, overlays, toasts, or auto-actions that fire without the hub being
  open (e.g. QoL automations, Trackers overlays).
- **`lazy`** — load the first time its hub tab / window is opened. Use for
  pure-window modules with no passive hooks (e.g. a browser-style panel).

Suggested `RegisterModule` extension:

```lua
OneWoW:RegisterModule({
    name      = "alttracker",
    addonName = "OneWoW_AltTracker",
    loadPhase = "login",   -- "login" | "lazy"
    order     = 2,
})
```

The core's load orchestrator (`Core/AddonLoader.lua`, `OneWoW.LoadOrchestrator`)
runs `RunStartupPhase()` at the **end of core's own `ADDON_LOADED`** (not
`PLAYER_LOGIN`) and:

1. iterates the authoritative `OneWoW.ModuleManifest` (also in `AddonLoader.lua`),
2. calls `OneWoW:EnsureLoaded(addon)` (§5.2) for every `loadPhase == "login"` entry,
3. defers `lazy` entries until their tab is selected (`EnsureModuleForTab`, hooked
   in `MainWindow`'s `SelectModuleTab` — dormant while all entries are `login`).

**Why `ADDON_LOADED`, not `PLAYER_LOGIN` (the critical timing decision):**
`PLAYER_LOGIN` is a one-shot event. If the core `LoadAddOn`-ed a module *during*
`PLAYER_LOGIN`, that module would load *after* the event already fired and would
miss its own `PLAYER_LOGIN` entirely. So the orchestrator runs at the end of
core's `ADDON_LOADED` (which fires before `PLAYER_LOGIN`), and each freshly-loaded
module is in memory in time to receive its own one-shot `PLAYER_LOGIN`.

**Core-driven init via `OnAddonLoaded` (corrects an earlier, disproven assumption).**
An earlier draft assumed a module force-loaded during core's `ADDON_LOADED` would
*also* receive its **own** `ADDON_LOADED` and could self-initialize there. In-game
this proved false: when `C_AddOns.LoadAddOn` runs *inside* another addon's
`ADDON_LOADED` dispatch, WoW does **not** deliver the loaded module's own
`ADDON_LOADED` to its frames (diagnostics showed `OneWoW_Notes` never saw
`arg1 == "OneWoW_Notes"`, while its `PLAYER_LOGIN` did fire). The module's DB-setup
branch never ran, `ns.db` stayed nil, and its `PLAYER_LOGIN` enable code crashed —
cascading into a dead hub.

The fix: **core drives init explicitly.** Every load unit exposes a standardized,
one-shot `OnAddonLoaded()` hook (the old `ADDON_LOADED`/DB-setup work). The loader
(`OneWoW:EnsureLoaded`) calls `_G[name]:OnAddonLoaded()` synchronously right after
a successful `LoadAddOn`, in core-controlled order, all before `PLAYER_LOGIN`.
Units drop their own `ADDON_LOADED` registration but **keep** their `PLAYER_LOGIN`
handler (they are loaded pre-login, so it fires normally) for enable/passive
arming, with an idempotent `OnAddonLoaded()` safety call at its top. This is
strictly better than relying on event order: init runs **before** `PLAYER_LOGIN`
in **core-controlled order**, so cross-unit reads at login (providers before
consumers) are deterministic, not order-of-registration luck.

> **Precedent — DBM.** DBM (the canonical core + load-on-demand-mods addon) does
> exactly this: a mod TOC is plain `## LoadOnDemand: 1` + `## RequiredDeps: DBM-Core`
> (no `LoadWith`/`LoadManagers`); `DBM:LoadMod` calls `C_AddOns.LoadAddOn(modId)`
> and then **the core itself** calls `self:LoadModOptions(...)` (the
> SavedVariables/options init) right after — core-driven post-load init, exactly
> our `OnAddonLoaded` hook.

Blizzard's per-character enable state is honored for free: a module disabled for
the current character fails `EnsureLoaded` with `"DISABLED"` and is silently
skipped, exactly like the built-in addon manager.

**Stores are orchestrated explicitly, not via `LoadWith`.** `LoadWith` would
auto-load a store when its parent loads, but that auto-load happens *inside* the
parent's load (i.e. during core's `ADDON_LOADED` dispatch) and the store's own
`ADDON_LOADED` is eaten the same way. So `LoadWith` is retired: each parent's
stores are listed in `OneWoW.ModuleManifest` (`stores = { … }`), and after the
orchestrator `EnsureLoaded`s a parent it iterates that parent's stores and
`EnsureLoaded`s each — driving every store's `OnAddonLoaded` hook deterministically.
Stores become plain `## LoadOnDemand: 1`. The orchestrator and the on-demand path
(§5.1) share the **same** `EnsureLoaded` primitive — there is one loader in the
codebase, not two.

### 5.1 Lazy cross-module data load (optional consumers)

Some modules need *another module's* data store only for an occasional action,
and degrade gracefully without it. `LoadWith` is the wrong tool here — it would
force the whole dependency chain into memory for everyone. Instead, the consumer
loads the store on demand at the point of use, **via the core API in §5.2** — not
a hand-rolled local function:

```lua
-- Catalog, when the user requests an AH scan:
OneWoW:WithAddon("OneWoW_AltTracker_Auctions",
    function() OneWoW_AltTracker_Auctions.FullAHScanner:StartScan(...) end,
    function() print(L["ITEMSEARCH_ALTTRACKER_AUCTIONS_REQUIRED"]) end)
```

Applies today to **Catalog → `OneWoW_AltTracker_Auctions`** (AH scanning). Note
`EnsureLoaded` pulls the store's own `RequiredDeps` (`OneWoW_AltTracker`) with it,
so one call arms the whole chain. If the store is hard-disabled it fails and the
`onFail` branch shows the "feature unavailable" message.

The cross-trace (§4.1) shows **all** cross-module consumers already nil-guard, so
this opt-in load is purely additive: without it they degrade gracefully; with it
they can actively pull a store the user hasn't otherwise enabled. Reserve it for
*explicit user actions* (a scan button, an "Add Alts" click) — do not call it
speculatively on tab open, or you defeat the memory savings.

### 5.2 `OneWoW:EnsureLoaded` — the shared on-demand loader

**Decision:** centralize on-demand loading in one core API instead of letting each
addon hand-roll an `EnsureAuctions`-style local. Lives in `Core/` (e.g.
`Core/AddonLoader.lua`, or folded into `ModuleRegistry`), exposed on the `OneWoW`
global. It has no GUI dependency, so it can load early — before the §5
orchestrator that uses it.

```lua
-- OneWoW:EnsureLoaded(name [, opts]) -> ok:boolean, reason:string|nil
-- Idempotent; pulls the addon's RequiredDeps chain; returns the raw failure token.
function OneWoW:EnsureLoaded(name, opts)
    if C_AddOns.IsAddOnLoaded(name) then return true end
    if opts and opts.deferInCombat and InCombatLockdown() then
        -- queue to PLAYER_REGEN_ENABLED, then run the pending callback
        return false, "COMBAT"
    end
    local ok, reason = C_AddOns.LoadAddOn(name)
    if not ok then return false, reason end  -- "DISABLED" | "MISSING" | "DEP_DISABLED" | ...
    return true
end

-- Removes the if/else at the call site entirely.
function OneWoW:WithAddon(name, onReady, onFail, opts)
    local ok, reason = self:EnsureLoaded(name, opts)
    if ok then
        if onReady then onReady() end
    elseif onFail then
        onFail(reason)
    end
    return ok
end
```

Rules and rationale:

- **Naming:** `EnsureLoaded`, not `LoadAddon` — the value-add is "ensure present +
  interpret failure," and `LoadAddon` would clash with Blizzard's `LoadAddOn`
  casing. It also loads Blizzard addons, so it isn't module-specific
  (`RequireModule` would mislead).
- **Return the raw token; localize separately.** Keep `(ok, reason)` returning the
  `LoadAddOn` token, and add `OneWoW:GetLoadFailureText(reason)` mapping tokens →
  localized strings (fall back to Blizzard `_G["ADDON_"..reason]` constants). Keeps
  the "unavailable because X" messaging consistent instead of per-call hardcoding.
- **One loader, two entry points.** The §5 login orchestrator and the §5.1
  on-demand path both call this primitive. Do not build a second loader.
- **Combat:** the bare form is synchronous; the opt-in `{ deferInCombat = true }`
  queues to `PLAYER_REGEN_ENABLED` for modules that build secure frames. Callers
  don't re-implement combat handling.
- **Don't spam failures.** `LoadAddOn` fails fast, so re-calling per click is fine
  functionally, but cache the *"already told the user"* state inside the helper so
  the error isn't reprinted on every attempt.
- **Subsumes existing raw calls.** The scattered Blizzard-addon loads
  (`map_world_tools-battlefield.lua:287`, `inspectmog.lua:273`,
  `EJLiveLoot.lua:251`, `LuaSyntax.lua:366`) should migrate to
  `OneWoW:EnsureLoaded("Blizzard_…")`, dropping their ad-hoc
  `if C_AddOns and C_AddOns.LoadAddOn … elseif UIParentLoadAddOn` fallbacks (the
  helper does that once).

### 5.3 Addon enable-state API — shared by both settings surfaces

**Decision:** the two settings surfaces that read/write Blizzard's per-addon
enable flag — the **Home tab** (`GUI/t-home.lua`) and **Manage Features**
(`Core/FirstRunWizard.lua`) — share one implementation in `Core/AddonLoader.lua`
instead of hand-rolling parallel `GetAddOnEnableState` / `EnableAddOn` /
`DisableAddOn` helpers. GUI-free, so it co-loads with the rest of the loader.

```lua
-- Read enable state; perCharacter selects the scope.
function OneWoW:IsAddonEnabled(name, perCharacter)         -> boolean
-- Write enable state in the requested scope (takes effect on next reload/relog).
function OneWoW:SetAddonEnabled(name, enabled, perCharacter)
-- Classify for status display: "not_found" | "disabled" | "enabled" | "warning".
function OneWoW:GetAddonStatus(name, perCharacter)         -> status, reason?
```

Rules and rationale:

- **`perCharacter` is the scope, chosen per call site — not a default.** The Home
  tab passes `false` (account-wide / all characters); Manage Features passes
  `true` (a current-character override). These are intentionally complementary:
  disable account-wide on Home, then re-enable for your main on Manage Features →
  enabled on main, disabled on alts. Blizzard already resolves the per-character
  setting on top of the account-wide one, so "per-character wins" needs no code.
- **The two surfaces *should* read differently once an override is set.** Home
  reflects the all-characters picture, Manage Features the current character's —
  that divergence is the feature, not a bug. Each reads in the same scope it
  writes, so each stays internally consistent.
- **`GetAddonStatus` treats loaded / `DEMAND_LOADED` as healthy.** Every suite
  unit is `LoadOnDemand: 1` and force-loaded by the orchestrator (§5), so
  `C_AddOns.GetAddOnInfo` reports `loadable=false, reason="DEMAND_LOADED"` *even
  while the unit is loaded and working*. The status helper short-circuits on
  `IsAddOnLoaded` and ignores the `DEMAND_LOADED` token, so the Home tab no longer
  mislabels loaded LoD units as an "unknown load error."
- **Reason text localization stays separate.** Like `GetLoadFailureText` (§5.2),
  the raw status/reason is returned uninterpreted; each tab maps it to its own
  icons/strings (`t-home.lua:GetReasonText`).
- **Relationship graphs are *not* unified here.** Manage Features' consumer graph
  (`FirstRun.CATALOG[].datastores` — which stores a *consumer* feature needs, used
  by the auto-follow disable logic) is a different relation than the orchestrator's
  ownership graph (`ModuleManifest.stores` — the stores a parent *owns*), so they
  remain distinct sources of truth. Only the read/write/status primitives are shared.

---

## 6. Cross-unit sharing model

Because modules are **separate load units**, they cannot share core's private
`ns` table. The rule:

- **Within a load unit:** `local _, ns = ...` (private upvalue table).
- **Across load units:** plain globals published by core — `_G.OneWoW` (set in
  `OneWoW.lua:3`), the `OneWoW_GUI` toolkit global, and members like
  `OneWoW.CopyPaste`. **Not LibStub** (see §6.1).
- **Optional modern alternative:** a unit may expose its namespace via
  `## AllowAddOnTableAccess: 1` and let consumers read it with
  `C_AddOns.GetAddOnLocalTable(name)` instead of leaking a global. Consider for
  data stores so they don't each plant a `_G` table.

Do **not** assume the diagram's single-`ns` model; that only holds inside one
addon.

### 6.1 GUI absorption, de-LibStub, and the `CopyPaste` service

**Decision:** fold `OneWoW_GUI` and `LibCopyPaste` into the `OneWoW` core load
unit and stop routing our own code through LibStub. LibStub's only value is
version negotiation across independently-embedded copies of a library; nothing in
the suite is shipped that way once everything requires core.

**LibStub is retained — but only for the vendored Ace libs.**
`LibDataBroker-1.1`, `LibDBIcon-1.0`, and `CallbackHandler-1.0` genuinely require
it (`assert(LibStub, …)` / `LibStub:NewLibrary`). Those are off-limits embedded
libs, so `LibStub.lua` stays as their loader. We only stop using it for
*our own* code (`OneWoW_GUI`, `LibCopyPaste`).

#### `OneWoW_GUI` → published as a plain global

- Entry file changes `LibStub:NewLibrary("OneWoW_GUI-1.0", N)` → `OneWoW_GUI = OneWoW_GUI or {}`.
  **No version field** is needed for non-LibStub code.
- The library keeps the **global name `OneWoW_GUI`** (not `OneWoW.GUI`) — read as
  "OneWoW's GUI, built from OneWoW_GUI." This makes the ~200-site consumer
  migration a pure handle swap with no method renaming:

```lua
-- before
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

-- after
local OneWoW_GUI = OneWoW_GUI
```

- **No defensive guard.** Once GUI is core and everything `RequiredDeps: OneWoW`,
  the global is guaranteed present before any consumer file loads (TOC order
  within core; dependency order across units). Never write `_G.OneWoW_GUI` —
  explicit `_G` access trips the pre-commit style rules.
- **Mandatory companion edit:** add `"OneWoW_GUI"` to `diagnostics.globals` in
  `.luarc.json`. Today the local is defined from a LibStub *return* (no global
  read), so it isn't allowlisted; a bare global read would otherwise raise
  `undefined-global` (Warning, all files) on every consumer.

#### `LibCopyPaste` → `OneWoW.CopyPaste` (core service)

- It has **no true GUI components** today — it builds a raw Blizzard frame with
  hardcoded backdrop/colors and only uses `CreateFrame`/font objects. So it is a
  *service*, not a GUI widget, and becomes `OneWoW.CopyPaste`.
- It must be **relocated into the `OneWoW` load unit**, because `OneWoW.CopyPaste`
  can only be assigned once the `OneWoW` namespace exists — and the old
  `OneWoW_GUI` unit loaded *before* core. Defining it in place would index a nil
  `OneWoW`. Do this as part of the absorption, not before.
- Drop LibStub + version: `LibStub:NewLibrary("LibCopyPaste-1.0", 9)` →
  `OneWoW.CopyPaste = {}`. Method API (`:Copy`, `:Paste`) is unchanged.
- **No `.luarc.json` change needed** — `OneWoW` is already allowlisted, and field
  access on an untyped global table isn't flagged. (A reason to prefer
  `OneWoW.X` for small utilities over minting new top-level globals.)
- Consumers (`OneWoW_Bags` ×3, `OneWoW_Utility_DevTool` ×1 — note that one is the
  non-silent `LibStub("LibCopyPaste-1.0")`, `OneWoW_QoL` copytext/coords) swap to
  `OneWoW.CopyPaste:Copy(...)`. In Bags' `if not Serializer or not LibCopyPaste`
  guard, only the `LibCopyPaste` half is now dead — **keep the `Serializer`
  check** (separate optional dep).

#### TODO — restyle `LibCopyPaste` to use `OneWoW_GUI` for its UI

Once it is first-party `OneWoW.CopyPaste`, **we should rebuild its UI with
`OneWoW_GUI` helpers** instead of the current raw frame: themed backdrop +
`GetThemeColor` instead of the hardcoded gold `(1, 0.82, 0)`, `CreateFS`/scroll
helpers, and a localized button label instead of the literal `"Close"`. This
brings it in line with the OneWoW_GUI-First UI policy and the no-hardcoded-colors
/ no-static-strings rules (promotion from a vendored lib removes the
"don't touch embedded libs" shield).

> **Ordering consequence:** restyling makes `CopyPaste` depend on `OneWoW_GUI`, so
> within the core TOC the GUI files must load **before** `CopyPaste`. That's fine
> (GUI is the foundation, listed first) and introduces no cycle — GUI never
> consumes CopyPaste. But `CopyPaste` is then no longer a "depends-on-nothing"
> service; order it after the GUI block.

---

## 7. Caveats / gotchas

- **Unload always needs a reload.** WoW cannot evict a loaded addon mid-session.
  The win is reload-free *enabling* and reload-free *disabling of not-yet-loaded*
  modules — not magic unloading.
- **SavedVariables of an LoD addon load when the addon loads.** Enabling a module
  mid-session loads its SVs at that point, not at login. Module init runs through
  the core-invoked `OnAddonLoaded()` hook (§5), which the loader calls right after
  `LoadAddOn` — so SVs are present when init runs regardless of when it loads.
- **`LoadAddOn` failure when hard-disabled.** If a module is `DisableAddOn`'d in
  Blizzard's list, `OneWoW:EnsureLoaded` (§5.2) returns `false, "DISABLED"` —
  surface that in Manage Features (offer "re-enable + reload").
- **Combat.** Don't `LoadAddOn` during combat for modules that build secure
  frames; use `OneWoW:EnsureLoaded(name, { deferInCombat = true })` (§5.2), which
  queues to `PLAYER_REGEN_ENABLED`.
- **Modules/stores are plain `## LoadOnDemand: 1`** (the DBM idiom), not
  `LoadManagers`/`LoadWith`. They do not auto-load; the core orchestrator owns
  loading (and init, via `OnAddonLoaded`). Confirm in-game that each unit is
  genuinely deferred until the orchestrator pulls it (check `C_AddOns.IsAddOnLoaded`
  is false before the orchestrator runs, true after).
- **Every unit exposes a one-shot `OnAddonLoaded()`** that the loader calls after
  `LoadAddOn`. It must be idempotent (guarded) — the unit's own `PLAYER_LOGIN`
  handler calls it again as a safety net.

---

## 8. Migration order (incremental, low-risk)

1. **Data stores first (Tier 3). ✅ IMPLEMENTED — then superseded by step 3's
   core-driven lifecycle.** Initially parent-only `LoadWith` was added to all 11
   stores (7 `AltTracker_*`, 4 `CatalogData_*`). **`LoadWith` was subsequently
   retired**: auto-loading a store inside its parent's load (during core's
   `ADDON_LOADED` dispatch) eats the store's own `ADDON_LOADED`, so its DB never
   initialized. Stores are now plain `## LoadOnDemand: 1` + `RequiredDeps: OneWoW,
   OneWoW_GUI, OneWoW_<Parent>`, listed under their parent in
   `OneWoW.ModuleManifest.stores` and loaded explicitly by the orchestrator (which
   then drives each store's `OnAddonLoaded` hook). Every cross-consumer already
   nil-guards (§4.1). `RequiredDeps` deliberately still lists `OneWoW_GUI`; dropping
   it is step 6. (The stale `FirstRunWizard` ShoppingList datastore mapping was also
   corrected — `Professions` → `CatalogData_Tradeskills`, finding §4.1.3.)
   *Verified in-game (LoadWith era): disabling `OneWoW_AltTracker` / `OneWoW_Catalog`
   lists every one of their data stores as "dependency disabled"; the `RequiredDeps`
   on the parent keeps that cascade under `LoadOnDemand` too.*
2. **Add `OneWoW:EnsureLoaded` / `WithAddon` + the load orchestrator** (§5.2),
   plus `loadPhase` in `ModuleRegistry`, reading the existing enable state. **✅
   IMPLEMENTED & verified in-game.** New `Core/AddonLoader.lua` hosts
   `OneWoW:EnsureLoaded` / `WithAddon` / `GetLoadFailureText` (+ a
   `PLAYER_REGEN_ENABLED` combat-defer queue) and `OneWoW.LoadOrchestrator`;
   `ModuleRegistry` gained `loadPhase` (default `login`); a dormant
   `SelectModuleTab` hook handles future `lazy` modules. Migrated
   `map_world_tools-battlefield`, `inspectmog`, and `EJLiveLoot` to `EnsureLoaded`,
   and the Catalog AH-scan guard to an on-demand
   `EnsureLoaded("OneWoW_AltTracker_Auctions")`. *Deferred:* `LuaSyntax` waits for
   step 5 (DevTool still `RequiredDeps: OneWoW_GUI` only). No `EnsureAuctions`
   local existed — Catalog read the store directly; that read is now the migrated
   on-demand call. At this step the orchestrator was a validated no-op harness
   (modules still auto-loaded); step 3 makes it authoritative.
3. **Core-driven load lifecycle (Tier-2 modules + Tier-3 stores). ✅ IMPLEMENTED.**
   All 8 Tier-2 module TOCs and all 11 store TOCs now carry plain
   `## LoadOnDemand: 1` (the DBM idiom — `LoadManagers`/`LoadWith` retired), so
   nothing auto-loads and the core owns load **and** init order. `OneWoW_Bags` is
   `RequiredDeps: OneWoW`. The orchestrator (`OneWoW.LoadOrchestrator:RunStartupPhase`
   in `Core/AddonLoader.lua`) runs at the **end of core's `ADDON_LOADED`** (before
   `PLAYER_LOGIN`): it iterates `OneWoW.ModuleManifest`, `EnsureLoaded`s every
   `loadPhase == "login"` module, then iterates that entry's `stores = { … }` and
   `EnsureLoaded`s each store. `OneWoW:EnsureLoaded` calls `_G[name]:OnAddonLoaded()`
   right after a fresh `LoadAddOn`, so every unit's DB-setup runs synchronously, in
   dependency order, before any `PLAYER_LOGIN`. Each unit (the 8 modules + the
   shared `DB:BootSubModule` covering all 11 stores) now exposes a one-shot
   `OnAddonLoaded()` hook, dropped its `ADDON_LOADED` registration, and keeps its
   `PLAYER_LOGIN` handler (with an idempotent `OnAddonLoaded()` safety call).
   `OneWoW_AltTracker_Auctions` is an **eager startup store** (live AH monitoring),
   listed in the manifest alongside the other AltTracker stores. The load banner
   reads the same `ModuleManifest`. Disabled/per-character-disabled modules fail
   `EnsureLoaded` with `"DISABLED"` and are skipped (their stores too).
   **Follow-ups (✅, verified in-game):** secondary integration listeners that
   waited on a *force-loaded* unit's own `ADDON_LOADED` were migrated to
   `PLAYER_LOGIN` (that event is eaten by the orchestrator's `LoadAddOn`) —
   `OneWoW_Bags/Integrations/OneWoWBagsIntegration.lua` (overlay refresh hooks) and
   `OneWoW_AltTracker/Modules/alttracker/actionbars-compat.lua`; and the Home-tab
   status check + the shared enable-state API (§5.3) were added so loaded
   `LoadOnDemand` units stop showing as an "unknown load error."
4. **Rewire Manage Features** to the two-level model in §5 (soft toggle =
   `LoadAddOn` / skip; hard disable retained as an "advanced / fully remove"
   option). *Partially done:* the **state layer** is now shared with the Home tab
   via the §5.3 API (`IsAddonEnabled` / `SetAddonEnabled` / `GetAddonStatus`,
   per-character scope here, account-wide on Home). *Remaining:* the soft-vs-hard
   two-level toggle UX itself.
5. **DevTool** — fold it into the suite package, promote to `RequiredDeps: OneWoW`,
   add `LoadManagers: OneWoW`, tag it `utility` so it stays off in the recommended
   preset, and retire its standalone CurseForge page. Confirm it loads only when a
   developer enables it.
6. **Absorb `OneWoW_GUI` into core + de-LibStub** (§6.1). Move GUI files into the
   `OneWoW` unit (listed first), switch the entry point to `OneWoW_GUI = OneWoW_GUI or {}`,
   find/replace the ~200 `LibStub("OneWoW_GUI-1.0", true)` sites to
   `local OneWoW_GUI = OneWoW_GUI` (drop the guard), add `"OneWoW_GUI"` to
   `.luarc.json` `diagnostics.globals` **in the same commit**, and drop
   `RequiredDeps: OneWoW_GUI` from every other unit (they keep `RequiredDeps: OneWoW`).
   Keep LibStub for the vendored Ace libs.
7. **Relocate `LibCopyPaste` → `OneWoW.CopyPaste`** (§6.1). Move it into core, drop
   LibStub + version, repoint the ~6 consumers, then (follow-up) restyle its UI
   with `OneWoW_GUI` helpers and localized strings.
8. **Update the rules + skills last.** Once GUI is collapsed, revise
   `.cursor/rules/WoW-Lua-Addon-Development.mdc` (§2.3) and the `onewow-gui-ui` /
   `onewow-database-api` skills so new code uses `local OneWoW_GUI = OneWoW_GUI`
   instead of the LibStub block.

---

## 9. Quick reference — final directive per unit

| Load unit | Key directives |
|---|---|
| `OneWoW_GUI` | *(no longer a load unit — folded into `OneWoW`, published as the `OneWoW_GUI` global, §6.1)* |
| `OneWoW` | *(no `RequiredDeps`; contains GUI + `OneWoW.CopyPaste` + Ace libs)* · `OptionalDeps: Auctionator, TradeSkillMaster` |
| `OneWoW_AltTracker` | `RequiredDeps: OneWoW` · `LoadOnDemand: 1` · manifest `stores` (7) |
| `OneWoW_Catalog` | `RequiredDeps: OneWoW` · `LoadOnDemand: 1` · manifest `stores` (4) |
| `OneWoW_Notes` | `RequiredDeps: OneWoW` · `LoadOnDemand: 1` |
| `OneWoW_Trackers` | `RequiredDeps: OneWoW` · `LoadOnDemand: 1` |
| `OneWoW_QoL` | `RequiredDeps: OneWoW` · `LoadOnDemand: 1` |
| `OneWoW_ShoppingList` | `RequiredDeps: OneWoW` · `LoadOnDemand: 1` |
| `OneWoW_DirectDeposit` | `RequiredDeps: OneWoW` · `LoadOnDemand: 1` |
| `OneWoW_Bags` | `RequiredDeps: OneWoW` · `OptionalDeps: OneWoW_AltTracker, …` · `LoadOnDemand: 1` |
| `OneWoW_AltTracker_Storage` | `RequiredDeps: OneWoW, OneWoW_GUI, OneWoW_AltTracker` · `LoadOnDemand: 1` (orchestrated store; Catalog / ShoppingList / Bags read it guarded) |
| `OneWoW_AltTracker_Character` | `RequiredDeps: …, OneWoW_AltTracker` · `LoadOnDemand: 1` (orchestrated store; Bags / Notes read it guarded) |
| `OneWoW_AltTracker_Professions` | `RequiredDeps: …, OneWoW_AltTracker` · `LoadOnDemand: 1` (orchestrated store; Catalog / QoL read it guarded) |
| `OneWoW_AltTracker_Collections` | `RequiredDeps: …, OneWoW_AltTracker` · `LoadOnDemand: 1` (orchestrated store; CatalogData_Quests reads it guarded) |
| `OneWoW_AltTracker_Endgame` | `RequiredDeps: …, OneWoW_AltTracker` · `LoadOnDemand: 1` (orchestrated store) |
| `OneWoW_AltTracker_Accounting` | `RequiredDeps: …, OneWoW_AltTracker` · `LoadOnDemand: 1` (orchestrated store) |
| `OneWoW_AltTracker_Auctions` | `RequiredDeps: …, OneWoW_AltTracker` · `LoadOnDemand: 1` (**eager** startup store — live AH monitoring; Catalog also lazy-loads it on demand) |
| `OneWoW_CatalogData_Journal` | `RequiredDeps: …, OneWoW_Catalog` · `LoadOnDemand: 1` (orchestrated store) |
| `OneWoW_CatalogData_Quests` | `RequiredDeps: …, OneWoW_Catalog` · `LoadOnDemand: 1` (orchestrated store; Notes reads it guarded) |
| `OneWoW_CatalogData_Vendors` | `RequiredDeps: …, OneWoW_Catalog` · `LoadOnDemand: 1` (orchestrated store) |
| `OneWoW_CatalogData_Tradeskills` | `RequiredDeps: …, OneWoW_Catalog` · `LoadOnDemand: 1` (orchestrated store; ShoppingList / QoL read it guarded) |
| `OneWoW_Utility_DevTool` | `RequiredDeps: OneWoW` · `LoadManagers: OneWoW` (in-suite, `utility` group, off by default) |

---

## 10. Taxonomy, layering & promotion (carried-over design concepts)

This section captures an earlier single-addon design vision, translated onto the
**separate-load-unit** decision in §§1–9. Where the original notes said *Module*
(an addon embedded into OneWoW), read **sub-addon** (a separate TOC/load unit kept
that way for real enable/disable/unload).

### 10.0 The substrate change (read this first)

The original vision assumed **one addon, one Lua namespace** (`OneWoW.Modules.X`,
`OneWoW.Services.Foo`) — cross-references were table lookups, and lint caught bad
ones by matching namespace strings. The load-unit decision changes the shared
substrate to **globals + `OneWoW:EnsureLoaded` (§5.2)**, not one namespace tree.
Two consequences ripple through everything below:

- **Enforcement shifts** from *"a cross-module import won't compile"* to *"lint
  forbids it + runtime nil-guards it"* — weaker on paper, but it matches reality:
  every cross-consumer already nil-guards (§4.1). The load-unit boundary makes
  "another unit's namespace can be nil" the **default**, not a corner case, which
  *strengthens* the original lifecycle argument for the no-cross-import rule.
- **"Promote to `Services/`" retargets** to *"promote into the OneWoW **core
  addon** and publish on `_G.OneWoW`"* — because the only thing every sub-addon
  shares is `RequiredDeps: OneWoW`. This is exactly the `LibCopyPaste →
  OneWoW.CopyPaste` move already locked in (§6.1): the promotion path is proven,
  not theoretical.

### 10.1 Taxonomy

| Term | Meaning under the load-unit model |
|---|---|
| **Module → sub-addon** | Top-level user-facing unit; own load unit (TOC), hub tab and/or contextual window, own SavedVariables. Clean 1:1 rename. |
| **Feature** | A toggleable capability *inside* a sub-addon. This is `SettingsFeatureRegistry` today (e.g. QoL's AutoMount, FastLoot). "Graduates to a sub-addon" when it grows its own TOC + SV + settings page (a heavier, rarer move now). |
| **Provider** | A headless data source with lifecycle — i.e. the **Tier-3 stores** (`OneWoW_AltTracker_Storage`, `CatalogData_Tradeskills`), bound to a parent and loaded by the orchestrator after it (§3/§5). Registers with `DataManager` (§10.3); consumers subscribe via events, never hold a direct ref. |
| **Service** | A reusable, (near-)stateless utility. Lives **inside the core addon** on `_G.OneWoW` (e.g. `OneWoW.CopyPaste`), since that is the one dependency every sub-addon shares. |

### 10.2 Hub vs. contextual surfaces (carry over wholesale)

Orthogonal to the load mechanism — a pure UX taxonomy, unchanged:

- **Hub** surfaces are tabs inside the OneWoW window (AltTracker, Catalog, Notes,
  Trackers, QoL, Settings).
- **Contextual** surfaces open their own window, summoned in a gameplay context
  (Bags at inventory, ShoppingList at the AH, DirectDeposit at the mailbox/bank,
  DevTool for development).
- The distinction is **not binary**: a sub-addon may register both. The **Pin
  pattern** (already in `ModuleRegistry`) is the one shared mechanism for promoting
  a hub item to a small standalone window — user-controlled, not reinvented per
  module. All windows share the theme and GUI primitives so contextual surfaces
  still read as part of the suite.

### 10.3 `DataManager:Query` — the sanctioned cross-unit data path

**Adopt this** — it is the principled fix for the §4.1 wart where consumers reach
directly into another store's internals (e.g. `OneWoW_AltTracker_Storage._DB`).

A core-level broker answers cross-unit data questions and **degrades gracefully**
when the target store isn't loaded or is disabled:

```lua
-- Consumer (e.g. Bags) asks for another unit's data without referencing it:
local sources = OneWoW.DataManager:Query("catalog.itemSource", itemID)
-- returns {} (or nil) when CatalogData isn't loaded — caller already nil-guards
```

- Providers **register** a query key on load (`DataManager:RegisterProvider(
  "catalog.itemSource", handler)`); `DataManager` holds the handler, never the
  consumer — same ignorance that makes any unit safe to disable (rule 2 below).
- For **passive reads**, `Query` returns empty when the provider is absent.
- For **explicit user actions**, `Query` may pair with `OneWoW:EnsureLoaded`
  (§5.2) to pull the provider on demand — the same opt-in load described in §5.1.
- Migration is incremental: route **new** cross-unit reads through `DataManager`,
  and convert the fragile direct `_DB` reads found in §4.1 to it over time. No
  big-bang rewrite.

### 10.4 Layering & dependency rules (intent kept, heuristics rewritten)

Dependency flow stays strictly one-directional — `sub-addons → core (GUI / Services
/ DataManager / EventBus) → Libs`. Nothing flows upward. The three rules:

1. **No sub-addon references another sub-addon's namespace/store directly.** The
   load-unit boundary enforces this naturally (separate `ns`, may be unloaded).
   Shared constants lift to core; shared pure functions lift to core Services — so
   nothing legitimate is left to reach across for. Lint heuristic (rewritten): a
   file in one sub-addon folder must not read another family's store global
   (e.g. `OneWoW_AltTracker_*` outside the AltTracker family).
2. **Inverse dependencies flow through callbacks/events, not direct calls.** Core
   fires an event (`ITEM_DATA_UPDATED`) and holds no consumer list — that
   ignorance is what lets any sub-addon be disabled without breaking core. This is
   the EventBus / `EventRegistry` story.
3. **Cross-unit data routes through `DataManager` (§10.3)**, never a direct
   unit-to-unit reference.

### 10.5 Promotion discipline

Trigger: **second consumer → promote to core.** Destination retargeted per §10.0.

- **Provider vs. Service decides the folder.** `Providers/`-shaped if it's a
  registered data source with lifecycle/SV (plugs into `DataManager`);
  `Services/`-shaped (on `_G.OneWoW`) if it's a (near-)stateless utility. Boundary
  cases default to Service.
- **Don't promote prematurely.** Private duplication is the safe valve while a
  shape stabilizes — the cross-unit lint catches the *bad* option (silent
  coupling), so duplication is fine. Rule of Three: the third consumer usually
  reveals the real abstraction.
- **Checklist (retargeted):**
  1. Move `OneWoW_X/Foo.lua` → core addon `Services/Foo.lua` (or `Providers/`).
  2. Publish as `OneWoW.Foo` on the global (drop any LibStub/`ns`-private form).
  3. Update internal callers in sub-addon X to the global.
  4. If it held SV state, migrate the SV schema/namespace.
  5. Document it — promoted things become API surface with a stability expectation.
  - `LibCopyPaste → OneWoW.CopyPaste` (§6.1) is a worked example of all five steps.

### 10.6 Core addon's internal directory layout

The original single-tree suite layout is **dropped** — it conflicts with the
separate-folder sub-addons and is precisely what the load-unit decision traded away
for real unloading (§1). But the **internal** layout is the right organization for
the **OneWoW core addon's own contents** after GUI absorption (§6.1):

```
OneWoW/
├── Core/         # engine layer — no UI, no game-domain logic
│   ├── ModuleRegistry/   # lifecycle: Enable / Disable / Unload / Pin (+ EnsureLoaded, §5.2)
│   ├── DataManager/      # provider registration + query broker (§10.3)
│   ├── Database/         # SV scopes, schema versioning, migrations
│   ├── EventBus/         # shared frame, event dispatch
│   └── Search/           # cross-unit search coordinator
├── GUI/          # shared rendering primitives (was the OneWoW_GUI library, §6.1)
│   ├── Widgets/  Tooltip/  Toast/  Overlay/  Theme/
├── UI/           # OneWoW's own shell — hub window, tab + sidebar orchestration
├── UIKit/        # OneWoW-specific composite UI (not primitive-grade)
├── Services/     # cross-unit utilities published on _G.OneWoW (e.g. CopyPaste)
├── Integrations/ Locales/ Media/ Libs/   # external hooks, L10n, assets, true 3rd-party libs
```

### 10.7 Enforcement (pre-commit, rewritten checks)

Builds on the existing `pre-commit` infra (alongside `check_no_g_literal.py`). The
original namespace-string checks don't match the global/load-unit world; translate
to:

- **No cross-family store global reads.** A file under one sub-addon folder must
  not reference another family's store global (e.g. `OneWoW_AltTracker_*` outside
  AltTracker, `OneWoW_CatalogData_*` outside Catalog) — must go through
  `DataManager:Query` or `EnsureLoaded`.
- **Core stays consumer-agnostic.** No file under the core addon's `Core/` or
  `Services/` may reference any `OneWoW_*` sub-addon global (mechanizes rule 2).

Add both now; they are no-ops until the first migration and then prevent layering
rot silently. *(Caveat: vs. the original single-namespace model these are
lint-time, not compile-time, guarantees — runtime nil-guards remain the backstop,
§10.0.)*

### 10.8 Enforcement ramp — turning "over time" into a finish line

`DataManager` (§10.3) is **additive on day one**, not a rule. But "convert the
fragile `_DB` reads over time" stays aspirational unless the cutover has a
concrete trigger. The ramp below mirrors how `OneWoW_GUI` went from one embedded
lib → "nearly everything requires it" → safe to absorb: the rule hardens *as call
sites converge on it*, never before.

**Mechanism: an allowlist that shrinks to zero.** Grandfather today's §4.1 direct
reads in an explicit allowlist, then delete entries as each is migrated. When the
list is empty, flip to hard-fail. No big-bang, and progress is measurable (lines
remaining in the allowlist).

| Phase | Lint behavior | Allowlist | Exit code |
|---|---|---|---|
| **1 — now** | warn-only: prints each cross-family read, but passes | every §4.1 direct `_DB` read listed (grandfathered) | `0` (never blocks) |
| **2 — migrating** | warn on allowlisted reads; **fail** on any *new* read not on the list | shrinks as each read moves to `DataManager:Query` | `1` only for off-list violations |
| **3 — rule** | hard-fail on every cross-family read | empty → removed from the script | `1` (matches `check_no_g_literal.py`) |

**How it fits the existing infra** (implemented — `bin/check_no_data_manager_bypass.py`,
hook id `no-data-manager-bypass`):

- Same shape as the `no-g-literal-access` hook in `.pre-commit-config.yaml` — a
  `repo: local` hook, `entry: python bin/check_no_data_manager_bypass.py`,
  `language: python`, `types: [lua]`, **reusing the exact same `exclude` block**
  (`Libs/`, `.lua-defs/`, `.wow_docs/`, `.vscode/`, `.releases/`,
  `OneWoW_Bags/API/Examples/`).
- `check_no_g_literal.py` is **pure hard-fail** today (exit `0`/`1`, `# noqa: _G`
  inline escape, `--no-verify` blunt override). This hook adds the *phasing* `_G`
  never needed: a `WARN_ONLY` flag (Phase 1) and an `ALLOWLIST` set keyed by
  **`path::symbol`** (Phase 2). Per-line keys (`path:lineno`) were rejected — they
  go stale as soon as lines shift; `path::symbol` only changes when the file moves
  or the read is actually migrated. Both collapse at Phase 3 into a script
  structurally identical to `check_no_g_literal.py`.
- **Family model, not a flat name list.** A file's family comes from its top-level
  addon folder; a symbol's family from its name prefix (`OneWoW_Catalog` also owns
  `OneWoW_CatalogData_*`). A read is a violation when the two families differ. This
  one rule subsumes *both* §10.7 checks: cross-family store reads **and** core
  staying consumer-agnostic (core's family owns no sub-addon global). The shared
  surface `OneWoW` / `OneWoW_GUI` is always allowed (the bare `OneWoW` global never
  matches; `OneWoW_GUI` is explicitly ignored).
- **Strings are stripped before matching**, so `OneWoW:EnsureLoaded("OneWoW_…")`
  and the loader's TOC-name lists are *not* flagged — only bareword global access
  is (catches both `OneWoW_AltTracker_Storage` and `_G.OneWoW_AltTracker_Storage`).
  Comment handling (`--`, inline `--`, `--[[ ]]`) is borrowed from the `_G` hook;
  the printed footer points at `DataManager:Query` / `EnsureLoaded` and this doc.

**Allowlist seed.** Phase 1 prints a ready-to-paste `path::symbol` seed block at
the end of its warn output, so flipping to Phase 2 is copy-paste. The §4.1 direct
reads are the seed (e.g. ShoppingList's `DataAccess.lua` already warns on
`OneWoW_AltTracker_Storage`, `OneWoW_AltTracker_Storage_DB`, and
`OneWoW_CatalogData_Tradeskills`). Each migration PR deletes its key(s); the day
the `ALLOWLIST` is empty is the day the rule is real — paid for incrementally,
exactly like the GUI absorption.
