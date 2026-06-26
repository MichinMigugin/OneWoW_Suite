# Cross-Alt Search & Duplicate-Finder — Design Notes

> Status: **all five §10 steps built.** The PredicateEngine search props, the
> Storage-side read layer (`Query.lua`: registry + Gather/Filter/Group/Query +
> duplicate finder), the Items-tab dupe view-mode, the DataManager refresh rework
> (`NotifyStorageChanged` + live refresh + dupeSpec persistence), the *default*
> Items + Bank gather routed through `Query` (with an `auction` descriptor), and the
> write-side scanner consolidation (`ContainerScan.lua`) are all in. PE props are
> verified in-client; the read layer, dupe UI, and rebuilt scanners still need
> in-client exercise. What remains is verification plus the close-out doc/comment
> pass before this design doc is deleted.
> See [Implementation status](#implementation-status) below.
> Captures the reasoning from the cross-alt dupe-search discussion as one artifact.

## 1. Goal

A user-facing "search across all my characters' bags and banks" surface, with a
**duplicate finder** built on top of it. Scope is selectable: which containers
(bags / personal bank / warband / guild / mail) and which alts to search across.
Guild bank is included as an opt-in container; it is never forced.

Two product goals sit on the same machinery:

1. **General scoped search** — "find X across these containers and these alts,"
   using the full PredicateEngine (PE) search syntax already used elsewhere.
2. **Duplicate finder** — "show me items I'm holding more than one of," where the
   user can define what "duplicate" means (same item / same item+ilvl / truly
   identical / similar gear).

## Implementation status

**Done — built, documented, verified in-client:**
- PredicateEngine **`set` prop type** (membership comparisons via `field=ID` /
  `field!=ID`) — a generic, reusable addition.
- **`forspec=ID` / `forclass=ID`** viewer-independent spec/class eligibility filters,
  via `C_Item.DoesItemContainSpec` (3-arg explicit-spec form — the 2-arg form is
  viewer-relative and was a bug). Documented in
  [`OneWoW_Bags/Docs/SEARCH_SYNTAX.md`](../../OneWoW_Bags/Docs/SEARCH_SYNTAX.md).
  Verified: `forclass=1/3/9` return distinct correct sets from one character,
  proving the class arg is honored (not the logged-in class).
- Confirmed PE already exposes every **dupe-key value** (`ilvl`, the stat set,
  `sockets`) as intrinsic props — so **no further PE work is needed** for this
  feature.
- **§10 step 1 — the Storage read layer** (`OneWoW_AltTracker_Storage/Modules/Query.lua`):
  the container-descriptor registry (bags / personal / warband / guild / mail),
  `Gather`/`Filter`/`Group`/`Query`, `GetEffectiveILvl`, and the duplicate finder
  (`BuildDupeKey` + `FindDuplicates` + the ilvl within-bucket pass + presets).
  Exposed on `OneWoW_AltTracker_Storage_API`.
- **§10 step 2 — the Items-tab dupe view-mode** (`OneWoW_AltTracker/UI/t-items.lua`):
  a "Duplicates" toggle on the filter bar swaps the Items tab into a dupe grouping
  with a controls row (preset + iLvl-mode dropdowns, primary/secondary/socket/similar
  toggles), adaptive columns, and the reused per-location expand rows — built on
  `FindDuplicates`. Additive: the default view's gather/render is untouched. Required
  completing the latent `OneWoW_GUI` `DataTable:SetColumns` so it rebuilds header
  buttons for a new column set (`OneWoW/GUI/Panels.lua`).
  - **Step 2 refinements** (all in `t-items.lua` unless noted): control tooltips
    (per-preset + checkboxes); `matchTrack` toggle + Track column (track-only split,
    off by default; `upgradeTrackStringID` key line in `Query.lua`); Stamina as a
    fallback primary (display + key, kept in sync); an **ID** column; per-copy expand
    lines showing name + `#itemID` + ilvl->ceiling + track + stats, byte-identical
    copies collapsed (`who+location+itemLink`), hover = item tooltip, sorted
    anchor-item-first then name/itemID/ilvl; and a filter bar where the search box
    flexes and the checkboxes cluster right.

- **§10 step 3 — `NotifyStorageChanged` + live refresh.** DataManager gained a
  listener registry (`RegisterStorageChanged` / `NotifyStorageChanged`); each
  `Collect*` fires `{scope, charKey}` after its SV write. **ItemIndex** dropped its
  duplicate bag/bank/guild event registrations and subscribes instead (keeps only
  `PLAYER_EQUIPMENT_CHANGED`, which DataManager doesn't own) — removing the
  read-after-write race. The **Items tab** subscribes via
  `OneWoW_AltTracker_Storage_API.RegisterStorageChanged` and live-refreshes
  (debounced 0.3s, visibility-gated), so the default and dupe views update when
  items move. Plus **dupeSpec persistence**: the last-used spec is stored in
  `OneWoW_AltTracker_DB.global.dupeSpec` (seeded from the Storage default, fields
  back-filled), so the dupe controls survive a reload/relog.

- **§10 step 4 — default Items + Bank gather migrated onto `Query`.** The Items
  tab's ~200-line hand-rolled multi-source walk is replaced by one
  `storageAPI.Gather{ chars="all", containers={bags,personal,warband,guild,mail,
  auction} }` call plus a by-itemID rollup that reconstructs the same row records
  (totalQty / locations / lastSeen / isBound) the render path expects. The Bank tab
  walks the same layer via a per-bank-type `Gather` (`GatherBankItems`; the old
  `GetBankData` + per-type slot ladder were removed). An **`auction` descriptor**
  joined the registry (it reads the Auctions sibling unit's API, not this unit's SV;
  `ctx.allChars` lets it include auction-only characters). `MakeInstance` now also
  derives `isBound` from a mail attachment's `canUse` and `texture` from `itemIcon`,
  for source parity. Behavior-preserving: same sources, labels, totals, sort, and
  the 100-item unfiltered cap. *Not* done as part of this step: gather/filter
  caching (the Items tab still re-gathers per refresh, as before — a possible
  follow-up, with the caveat that auction collection emits no `NotifyStorageChanged`
  signal to invalidate on), and the DataManager→Bank `RefreshBankDisplay` poke
  (still in place; converting it to a `RegisterStorageChanged` subscription is the
  remaining §8 cleanup). Equipped gear still has no descriptor — nothing consumes it
  through `Query` yet (the ItemIndex tooltip path reads it directly).

- **§10 step 5 — write-side scanner consolidation** (`Modules/ContainerScan.lua`).
  The `Bags` / `PersonalBank` / `WarbandBank` / `GuildBank` scanners were
  near-duplicate slot loops with drifted field sets. The duplicated parts — the slot
  iteration and the canonical record builder — now live in `ns.ContainerScan`
  (`BagSlots` for any C_Container bag; `GuildTabSlots` + link-hex quality recovery
  for guild tabs). Each scanner module keeps only its genuinely-different outer
  structure (flat bags vs. tabs, per-tab accounting, money, write path) and calls
  the shared scanner for slots. Field-drift is fixed: every slot now carries the
  same shape, so warband slots gained `isLocked`/`isBound` and bag slots are
  itemID-guarded like the bank scanners (both harmless to the read side, which
  treats missing flags as false). `Mail` stays special (its own write path).
  *Deviation from §3/§9:* this shares the builder + slot loop rather than fusing the
  write config into the `Query` read registry — the read path is live, so a single
  read+write registry was judged higher-risk than warranted; the outer container
  structures differ enough that one mega-scanner would be config-heavy. Full
  read+write registry unification remains a possible future refactor.

**Not started:** nothing — all §10 steps are built. Remaining work is in-client
verification and the close-out doc/comment pass below.

**Abandoned — dead ends, kept for the reasoning (§11):** link-based loot/drop spec
(a `lootSpec` prop was tried and reverted — the link's spec field is viewer-stamped);
`matchSpec` as a dupe-key dimension (spec moved to the filter axis above).

## Durable-doc & comment follow-ups (close-out checklist)

This design doc is **temporary** — it's deleted once the feature ships. Everything
that must outlive it is tracked here; do this pass before removing the doc. Append
to this list as new work lands.

**Durable docs to update:**
- [ ] `OneWoW/Docs/GUI.md` — document that `DataTable:SetColumns(newColumns)` now
  rebuilds the header buttons (re-runs `onHeaderCreate`, relayouts), enabling
  runtime column/view-mode switching. Previously it only swapped the array.
- [ ] `OneWoW_AltTracker_Storage/Docs/ARCHITECTURE.md` — add a **Query layer**
  section for `Modules/Query.lua`: the container-descriptor registry, the
  `OneWoWItemInstance` shape, `Gather`/`Filter`/`Group`/`Query`, the duplicate
  finder (`OneWoWDupeSpec`, presets, `BuildDupeKey`, ilvl-range pass), and the new
  public `OneWoW_AltTracker_Storage_API` surface
  (`Gather`/`Filter`/`Group`/`Query`/`FindDuplicates`/`GetEffectiveILvl`/
  `GetDupePresets`/`GetDefaultDupeSpec`/`RegisterStorageChanged`). Also update the
  DataManager section: it's now the single storage event owner emitting
  `NotifyStorageChanged`, and ItemIndex is a signal-driven subscriber (only
  `PLAYER_EQUIPMENT_CHANGED` stays on its own frame). Note the registry now has an
  **`auction`** descriptor (reads the Auctions sibling unit's API via `ctx.allChars`,
  not this unit's SV) and that the AltTracker Items + Bank tabs' default gather both
  route through `Gather` now (the Bank tab's old `ns.UI.GetBankData` was removed).
  Also document the **`ContainerScan`** module: the shared write-side slot scanner
  (`BagSlots` / `GuildTabSlots`) and canonical record builder that the four bank/bag
  scanners now delegate to, plus the now-uniform stored slot shape (warband gained
  `isLocked`/`isBound`).
- [ ] `OneWoW/Docs/PREDICATE_ENGINE.md` — confirm the **`set` prop type** and
  `forspec`/`forclass` are documented (added earlier in this effort); add if missing.
- [ ] `OneWoW_Bags/Docs/SEARCH_SYNTAX.md` — already has the spec/class section;
  re-confirm no further additions are needed (the dupe search box reuses existing PE
  syntax + `#hero`/`#veteran`/... track keywords).
- [ ] **AltTracker user doc** — there is no `OneWoW_AltTracker/Docs/`. Decide whether
  the Items-tab dupe view-mode warrants a short user-facing doc (what "duplicate"
  means, presets, the controls/columns); create it or consciously skip.

**Code-comment cleanup (avoid dangling references):**
- [ ] Several comments in `Query.lua` and `t-items.lua` cite
  `CROSS_ALT_SEARCH_DESIGN.md §N`. Replace those with self-contained explanations
  (or drop the section refs) so comments still make sense after this doc is gone.
- [ ] Otherwise inline comments were written to stand alone as features landed — a
  light skim to confirm is enough.

## 2. Data-fidelity findings that shape the design

These were verified against the current scanners and PE; they constrain the
design and kill two false constraints we initially assumed.

- **Full itemLinks are already stored, losslessly.** Every scanner captures the
  complete link (`C_Container.GetContainerItemLink` / `GetGuildBankItemLink` /
  `GetInboxItemLink`), bonus IDs and upgrade data intact, and it round-trips
  through SavedVariables unchanged. No pruning or normalization in the persist
  path. → Link-mode PE search and ilvl-aware grouping are both viable on stored
  alt data **with no schema change**.

- **`GetItemInfo(link)` returns the *effective* ilvl, not base.** Empirically
  confirmed: searching `ilvl=263` matches two copies of the same item upgraded on
  different tracks (Hero 2/6 and Champion 6/6), both displaying 263. The
  "GetItemInfo returns base ilvl" lore applies only to the **bare-itemID** call;
  with a full link it is effective. So both `PE props.ilvl` and the scanners'
  stored `itemLevel` are effective ilvl (when built from the link, which they
  are). This was an earlier mistaken assumption — corrected.

- **PE has no "current actual ilvl" beyond `ilvl`.** `props.maxLevel`
  (`GetItemUpgradeInfo().maxItemLevel`) is the **fully-upgraded ceiling**, not the
  current level; `props.upgradeLevel`/`upgradeMax` are **track steps** (e.g. 2/6),
  not ilvls. Only `props.ilvl` is the effective level. PE never calls
  `GetDetailedItemLevelInfo`. The upgrade-track props are still useful for the
  *secondary* "find upgrades for alt X" goal (`isFullyUpgraded == false`).

- **Effective ilvl is recomputable from the link.** `C_Item.GetDetailedItemLevelInfo(link)`
  gives the effective ilvl for any stored link. Use it at query time as a
  robustness backstop for cold/uncached items; the stored `itemLevel` is otherwise
  fine. Do **not** persist a separate ilvl field as the source of truth — the link
  is the durable primitive.

- **Don't persist PE props.** Most PE props are a pure function of the link
  (recompute on demand); the account-relative ones (`isAlreadyKnown`, collection
  state, class-equip) must be evaluated relative to the *searching* character, so
  freezing them at scan time is actively wrong; and persisting PE's prop table
  welds the on-disk schema to PE's evolving internal vocabulary. Store the link;
  run PE in link-mode at query time.

## 3. The unifying concept: one container model, two consumers

Today the same knowledge — "what containers exist, where their slots live, which
bag IDs, account vs per-character" — is hand-encoded **twice**: once on the
**write** side (the scanner modules) and once on the **read** side (the duplicated
if-ladders in `t-items.lua` / `t-bank.lua`). A single **container descriptor
registry** should drive both.

```lua
---@class OneWoWContainerDescriptor
---@field id        string   -- "bags"|"personal"|"warband"|"guild"|"mail"
---@field scopeType string   -- "character" | "account" | "guild"
---@field api       string   -- "container" | "guild" | "mail"
---@field tabbed    boolean
---@field setting   string   -- settings.track* gate
---@field bagIDs    fun(tab:number|nil):number      -- container/bank bag id for a tab
---@field numTabs   fun():number                    -- 0 for flat containers
---@field readPath  fun(charData,db):table|nil      -- where Gather reads slots
---@field writePath fun(charData,db,value)          -- where the scanner writes
```

- **Write side** (scanners) iterate the descriptor's tabs/slots and call one
  shared record builder.
- **Read side** (`Gather`) iterates the same descriptors to produce normalized
  instances.
- `scopeType` encodes the account/guild rule (§6): `"character"` containers are
  gated by the char list; `"account"`/`"guild"` are gated by their own flag alone.
- `setting` means Query's reachable scope is bounded by the `track*` toggles; the
  UI should disable checkboxes for untracked sources rather than show empties.

Mail is declared as a descriptor for *read* purposes (its attachments normalize
into instances), but keeps its own bespoke **write** path — its expiry,
accounting, and hook-driven lifecycle don't fit the generic container scanner.

## 4. The normalized instance record — one per occupied slot

The atom everything is built from. Aggregation is never done at gather time; it is
always a pass on top. Note this is essentially the *same shape the scanners
already write* — the goal is for the shared record builder to emit exactly this,
so the read-side re-normalization disappears.

```lua
---@class OneWoWItemInstance
---@field itemID       number
---@field itemLink     string|nil   -- FULL link; nil only for broken slots
---@field name         string|nil   -- normalized from itemName / mail name / auction name
---@field quality      number|nil   -- normalized from quality / itemRarity / link hex
---@field texture      number|string|nil
---@field count        number       -- normalized from stackCount / count / quantity (default 1)
---@field vendorPrice  number       -- sellPrice, 0 if none
---@field isBound      boolean      -- coarse container bind; false where source can't tell
---@field lastSeen     number       -- epoch secs from the source's *LastUpdate stamp
---@field where        OneWoWItemLocation
---@field _ilvl        number|nil   -- INTERNAL lazy cache; read via GetEffectiveILvl

---@class OneWoWItemLocation
---@field type      string      -- "bags"|"bank"|"warband"|"guild"|"mail"|"equipped"|"auction"
---@field charKey   string|nil  -- nil for account-scope sources (warband, guild)
---@field charName  string|nil
---@field guildName string|nil  -- set only when type=="guild"
---@field bagID     number|nil  -- drill-down coords when applicable
---@field tabIndex  number|nil
---@field slotID    number|nil
```

Effective ilvl is **lazy** — resolved on first access from the link, memoized; only
ilvl grouping and `ilvl`-referencing predicates trigger it, and only for survivors
of the predicate filter:

```lua
---@param inst OneWoWItemInstance
---@return number ilvl  -- effective; 0 if link missing/uncached
function OneWoW_AltTracker_Storage_API.GetEffectiveILvl(inst)
    if inst._ilvl then return inst._ilvl end
    inst._ilvl = (inst.itemLink and C_Item.GetDetailedItemLevelInfo(inst.itemLink)) or 0
    return inst._ilvl
end
```

## 5. Query API — layered: gather once, filter cheap

The split exists because the Bank tab already proves it: gather is scope-driven and
expensive; filter is keystroke-driven and cheap. Don't fuse them.

```lua
---@class OneWoWQueryScope
---@field chars      string|string[]  -- "all" | { "Alt-Realm", ... } (per-character containers only)
---@field containers table            -- set of booleans; omitted key = false
---@field guilds     string[]|nil     -- optional guild-name filter when containers.guild

-- EXPENSIVE, scope-driven. Walks descriptors, normalizes every slot shape into
-- OneWoWItemInstance[]. Call on scope change; cache the result.
---@param scope OneWoWQueryScope
---@return OneWoWItemInstance[]
function OneWoW_AltTracker_Storage_API.Gather(scope) end

-- CHEAP, predicate-driven. Compiles the PE expr ONCE, evaluates per instance via
-- the hyperlink itemInfo pattern (the MatchesSearch logic, now in ONE place).
---@param instances OneWoWItemInstance[]
---@param predicate string|nil  -- PE expression, e.g. "#gear & ilvl<=263"
---@return OneWoWItemInstance[]
function OneWoW_AltTracker_Storage_API.Filter(instances, predicate) end

-- Buckets instances by a key function (nil key => instance skipped). Returns nil
-- when keyFn is nil (caller uses the flat list). Dupe specs produce the keyFn via
-- BuildDupeKey; simple grouping (e.g. by itemID) is just a one-line keyFn.
---@param instances OneWoWItemInstance[]
---@param keyFn fun(inst:OneWoWItemInstance):string|nil
---@return OneWoWItemGroup[]
function OneWoW_AltTracker_Storage_API.Group(instances, keyFn) end

---@class OneWoWItemGroup
---@field key        string
---@field members    OneWoWItemInstance[]
---@field totalCount number               -- Σ member.count
---@field slotCount  number               -- #members (distinct occupied slots)
---@field ilvlSpread number[]|nil         -- sorted distinct effective ilvls (gear groups)

-- High-level one-shot for non-interactive callers (Gather -> Filter -> Group).
---@class OneWoWQueryOpts : OneWoWQueryScope
---@field predicate string|nil
---@field group     string|fun|nil  -- nil/"none" => instances[]; "itemID" or a keyFn => groups[]
---@param opts OneWoWQueryOpts
---@return OneWoWItemInstance[]|OneWoWItemGroup[]
function OneWoW_AltTracker_Storage_API.Query(opts) end

-- Dupes = Group by BuildDupeKey(spec) + keep groups with slotCount >= spec.minCount.
---@param opts table  -- OneWoWQueryScope + .predicate + .dupe (OneWoWDupeSpec)
---@return OneWoWItemGroup[]
function OneWoW_AltTracker_Storage_API.FindDuplicates(opts) end
```

### "What is a duplicate" = a spec the user composes; presets auto-fill it

Dupe identity is a set of independent "must match" toggles over an **anchor**: the
anchor is `itemID` in `"item"` mode, or `equipLoc` + armor type in `"similar"` mode
(which finds functionally-equivalent gear across *different* itemIDs). Each enabled
toggle adds a component to the key, splitting broad groups narrower. The UI exposes
these as controls; **presets are named specs that auto-fill the controls** (the user
can then tweak → "Custom"). The full link is always kept on the record; these
toggles only decide what goes into the comparison key.

```lua
---@class OneWoWDupeSpec
---@field mode           string  -- "item" (anchor=itemID) | "similar" (anchor=equipLoc+armor type)
---@field ilvlMode       string  -- "off" | "exact" | "range"
---@field ilvlTolerance  number  -- ilvlMode=="range": copies within N below the group max are redundant
---@field matchPrimary   boolean -- split by primary stat (Int/Str/Agi) from C_Item.GetItemStats
---@field matchSecondary boolean -- split by secondary-stat SET (Haste/Crit/Mastery/Vers) from GetItemStats
---@field matchSocket    boolean -- split by "has any socket" (C_Item.GetItemNumSockets > 0)
---@field matchTrack     boolean -- split by upgrade track (Hero/Veteran/...) via props.upgradeTrackStringID; level diffs stay to the ilvl-range pass
---@field minCount       number  -- a group counts as a dupe at >= this many slots (default 2)
```

**PE is the single extraction point.** It already pulls every value these toggles
need from a link in hyperlink mode — `ilvl`, `sockets`/`hasSocket`, the full stat
set (`statIntellect/Strength/Agility`, `statCrit/Haste/Mastery/Versatility`, …) via
`ResolveStats` → `C_Item.GetItemStats`, plus `equipLoc`/`classID`/`subClassID`.
These props are lazily resolved and identity-cached inside PE, so the dupe key
reuses that work and inherits the async handling for free. PE has two sides and the
two axes use different ones: the **search box** uses predicate *evaluation*
(`ilvl:200-300`, `#haste`, `quality>=4`); the **dupe key** reads prop *values*. One
extraction (`BuildProps` from the link), two consumers.

```lua
-- Reads PE prop VALUES from one BuildProps(link) call (identity-cached). ilvlMode
-- =="range" is deliberately NOT a key component (see note) -- it's a post-pass.
local function BuildDupeKey(inst, spec)
    local p = PE:BuildProps(inst.itemID, nil, nil, inst.itemLink)   -- all values, cached by identity
    local key = (spec.mode == "similar")
        and ("slot:" .. p.equipLoc .. ":" .. p.classID .. ":" .. p.subClassID)
        or  ("id:" .. inst.itemID)                                  -- floor
    if spec.ilvlMode == "exact" then key = key .. "|i"  .. (p.ilvl or 0) end
    if spec.matchPrimary        then key = key .. "|p"  .. PrimaryFrom(p) end      -- reads p.statIntellect/Strength/Agility
    if spec.matchSecondary      then key = key .. "|s"  .. SecondarySetFrom(p) end -- reads p.statCrit/Haste/Mastery/Versatility
    if spec.matchSocket         then key = key .. "|k"  .. (p.hasSocket and 1 or 0) end
    if spec.matchTrack          then key = key .. "|t"  .. (p.upgradeTrackStringID or 0) end -- track only; level -> ilvl pass
    return key
end
```

**Upgrade track is a track-only split (`matchTrack`).** Two copies can share an
effective ilvl while sitting on different tracks (Champion 3/6 ≈ Veteran 1/6) —
the higher track has upgrade headroom the other lacks, so they aren't truly
redundant. `matchTrack` splits the key by `upgradeTrackStringID` so they land in
separate groups; *level* differences within one track (1/6 vs 3/6) are left to the
ilvl-range post-pass. It defaults **off** in every preset (the ilvl pass + the
visible Track column already inform the keep-decision); toggle it on to keep
tracks apart. Non-upgradeable items share a single nil-track bucket (no split).

**ilvl range is not a key — it's a within-bucket pass.** Range matching isn't a
clean equivalence (with tolerance 3, 620≈622 and 622≈625, but 620≉625), so it can't
be a key component. Instead: group with ilvl excluded, then within each bucket
**anchor to the highest ilvl** and flag copies within `ilvlTolerance` below it as
redundant. This is exactly the "same or within a range, exclusive of each other"
intent and the most useful dupe semantic — "you have a best copy and N near-copies
you don't need." Copies further below the band surface as their own lower tier
rather than collapsing. (PE's `ilvl:200-300` is an *absolute* band filter — handy in
the search box to pre-narrow candidates — and is a different thing from this
*relative* within-N-of-the-best clustering, which can't be a static predicate.)

Presets are just toggle sets the UI loads into the controls:

| Preset | mode | iLvl | Prim | Sec | Sock | Track | meaning |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Same item | item | off | – | – | – | – | every copy of the base item |
| Same item + ilvl | item | exact | – | – | – | – | same item, same power |
| **Same gear** (initial default) | item | range | ✓ | ✓ | ✓ | – | the initial dupe check |
| Similar gear | similar | range | ✓ | ✓ | ✓ | – | functionally-equivalent across itemIDs |

All columns (incl. iLvl / Prim / Sec / Sock / Track) are shown in the dupe table
regardless of which toggles are on, so the user can see where a *different* split
would help. The expand row collapses byte-identical copies in the same place
(`who + location + itemLink`) into one `… x N` line and shows each distinct copy's
ilvl → fully-upgraded ceiling, track, and stats so differences are visible at a
glance.

The persisted setting is the last-used `OneWoWDupeSpec` (plus optional named custom
specs) — small and forward-compatible, so adding a toggle later doesn't break stored
data.

> Note on same-itemID redundancy: in `mode="item"`, `matchPrimary`/`matchSecondary`
> rarely split further (base stats are fixed per itemID); they earn their keep in
> `"similar"` mode and for items whose bonus IDs vary tertiaries. `matchSocket` *can*
> still split same-itemID copies (one socketed via bonus, one not). Kept as
> independent toggles so one control set serves both modes. A raw-link
> "byte-identical" preset (enchant/gems/source) can be added later as the strictest
> tier without changing this model.

## 6. The account/guild scope rule

`chars` filters **per-character** containers only (bags, personal, mail, equipped,
auctions). **Account-scope** (warband) and **guild-scope** (guild) containers are
gated solely by their own container flag and never by `chars` — exactly how
`RefreshItemsTab` already iterates them outside the per-char loop, and mirrored on
the write side (Warband/Guild scanners write to `DB.warbandBank` /
`DB.guildBanks[guild]`, not `charData`). In the UI, the alt multi-select does not
affect the warband/guild checkboxes; they are independent toggles (guild optionally
narrowed by `guilds`).

## 7. The three callers, against this contract

```lua
-- Bank tab: one char, one container, per-slot grid (gather once; filter on keystroke)
local insts = API.Gather{ chars = { selectedCharKey }, containers = { [bankType] = true } }
-- on keystroke: API.Filter(insts, searchText) -> DisplayOneBagGrid

-- Items tab, DEFAULT view: account-wide, aggregated by itemID (current behavior)
local groups = API.Query{ chars = "all",
    containers = { bags=true, personal=true, mail=true, warband=true, guild=true, auctions=true },
    group = "itemID" }

-- Items tab, DUPE view-mode: SAME tab, adaptive columns + dupe grouping. Toggling
-- the dupe controls switches the Items tab into this mode rather than opening a new
-- tab (AltTracker's sub-tab space is exhausted).
local dupes = API.FindDuplicates{ chars = selectedAlts,
    containers = scopeCheckboxes, predicate = searchBarText, dupe = dupeSpecFromControls }
```

The Items tab's hand-rolled `locations` / `totalQty` / `lastSeen` rollups all fall
out of `group.members` + `totalCount` + `max(member.lastSeen)`, so its ~200-line
gather collapses to a `Query` call plus row decoration. **The Items tab is the home
for the dupe feature** (no new sub-tab): its `columnsConfig` becomes view-state
driven — the default view keeps today's columns; toggling dupe controls swaps in
ilvl / primary / secondary / socket columns and switches grouping to the dupe spec.
The per-location expand rows already used in `t-items.lua` are the dupe-row UI
verbatim — they show where each copy lives.

UI lives in **`OneWoW_AltTracker`** (the UI unit); the Query engine lives in
**`OneWoW_AltTracker_Storage`** (headless data). Storage has no UI folder; keep the
seam.

## 8. Refresh & invalidation — DataManager as the single event owner

Today there are **two** independent event reactors keyed off overlapping events:

- `DataManager` registers `BAG_UPDATE_DELAYED` / `BANKFRAME_*` / `GUILDBANK_*` /
  `MAIL_*` → writes SV (debounced via `C_Timer.After`).
- `ItemIndex` registers its **own** frame for `BAG_UPDATE_DELAYED` /
  `BANKFRAME_CLOSED` / `GUILDBANKFRAME_CLOSED` / `PLAYER_EQUIPMENT_CHANGED` /
  `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` → `ScheduleRebuild` (0.8s) → reads SV.

ItemIndex rebuilds **from the SV DataManager is concurrently writing**; its 0.8s
debounce happens to land after DataManager's 0.3s collects, so it usually reads
post-write — but that ordering is coincidental, not designed. Adding a third
independent listener (Query-cache invalidation) compounds the race.

**Fix:** make `DataManager` the single event owner and emit one post-write signal.
The seed already exists (`NotifyMailChanged` pokes the UI after a mail collect);
generalize it:

```lua
-- After each successful Collect*, DataManager fires ONE signal of what changed.
DataManager:NotifyStorageChanged({ scope = "bags", charKey = charKey })
```

Then:

- **ItemIndex** drops its own event frame and subscribes → `ScheduleRebuild` fires
  *after* the SV write, deterministically. Removes the race and the duplicate
  registration.
- **Query consumers** (Advanced view; migrated Bank/Items tabs) subscribe →
  invalidate the cached instance set → re-gather, debounced, **visibility-gated**
  (the Bank tab already guards with `parent:IsVisible()`).

Because DataManager knows exactly what it collected, the signal carries
`{scope, charKey}`, enabling **partial invalidation**: a consumer re-gathers only
when the changed scope intersects its selection. A warband change on the logged-in
char doesn't force the Advanced view watching `{Alt-A bags, Alt-B personal}` to
re-gather. ItemIndex can stay coarse (full rebuild); the Query consumers benefit
from the granularity.

This also answers the current-character freshness question: DataManager keeps the
logged-in char's SV fresh on events, so `Gather` over the snapshot is near-live
(lagging only the sub-second debounce). **Drop the live-`C_Container` overlay
idea** — it buys <1s for real complexity. Stored is fine; `Gather` stays
snapshot-only and uniform.

## 9. Scanner consolidation

`Bags` / `PersonalBank` / `WarbandBank` / `GuildBank` are near-duplicates: iterate
container → `GetContainerItemInfo` → `GetContainerItemLink` → `GetItemInfo` → write
an identically-shaped slot record. The builder is copy-pasted, and the field sets
have drifted inconsistently (`isBound` only in Bags/Personal; `isLocked` absent in
Warband). They collapse to:

- **One parameterized container scanner** driven by the §3 descriptor registry
  (bag-ID range, tabbed vs flat, slot-count accounting, write path are all data).
- **One shared record builder** emitting the §4 canonical shape — which fixes the
  field-drift and makes the write shape == the read shape (eliminating read-side
  re-normalization).
- **GuildBank** is the same scanner with `api = "guild"` (guild API surface,
  itemID-from-link, quality-from-hex) instead of `api = "container"`.
- **Mail stays special.** Its expiry math, accounting side-effects, and hook-driven
  lifecycle don't fit a generic container scan. It keeps its own write path but
  exposes its attachments through the shared record builder for the read side.

`DataManager` remains the dispatcher (event → which descriptor(s) to collect),
`ItemIndex` remains a derived consumer (now signal-driven, §8).

## 10. Suggested sequencing (lowest risk first)

1. **Build the descriptor registry + `Gather`/`Filter`/`Group`/`Query`** (read side
   only). Pure addition; touches nothing shipping.
2. **Add the dupe view-mode to the Items tab** as an additive code path: a controls
   row + `FindDuplicates` + adaptive columns + reused expand rows. The default view
   keeps its existing gather untouched, so the feature ships with no regression to
   current behavior.
3. **Introduce `NotifyStorageChanged`** in DataManager; migrate `ItemIndex` to it
   and drop its event frame. Internal; observable only as fewer redundant rebuilds.
4. **Migrate the Items + Bank tabs' default gather** to `Query` (fixes the Items
   tab's per-keystroke re-gather for free). Behavior-preserving; do it once the API
   is proven by the dupe mode — never first.
5. **Consolidate the scanners** (§9) behind the shared builder + descriptor. Most
   invasive on the write side; do last, with the read side already exercising the
   canonical shape.

## 11. Open decisions

- **Spec: drop-spec is dead, *suitability* is alive — and it's a filter, not a
  key.** Two different "specs" must not be conflated:
  - **Drop spec** (which spec the item dropped *for*) lives only in the link's
    `specializationID` field, which is *viewer-relative* — it carries the linking
    character's current spec, confirmed identical across the container link and the
    `GetItemInfo` link, and flipping with the logged-in character (265 Affliction →
    73 Prot). It is unrecoverable per-copy; the `lootSpec` PE prop was reverted.
  - **Spec suitability** (which spec(s) the item is *for*) is fully
    viewer-independent via `C_Item.DoesItemContainSpec(itemInfo, classID, specID)`
    (explicit class+spec — already used in `upgrade-detection.lua` for alts, and the
    basis of PE's working `#myspec`).

  So spec lives on the **filter/predicate axis**, not the dupe-key axis. `#myspec &
  #gear` filters dupes to current-spec gear, and the **now-implemented**
  `forspec=ID` / `forclass=ID` *set-membership* props (over `DoesItemContainSpec`,
  viewer-independent — the correct analog of the failed `lootspec`) extend it to any
  spec/class, e.g. hunting an alt's dupes. (See `OneWoW_Bags/Docs/SEARCH_SYNTAX.md` →
  "Spec & Class Eligibility".) It is *not* a useful grouping-key dimension: same
  itemID ⇒ same suitability ⇒ no-op, and cross-item it largely duplicates
  primary/secondary — which is why it stays out of the dupe key but stays in the
  toolset as a filter.
- **Remaining mechanical bits** — classifying which PE stat props count as "primary"
  vs "secondary" (trivial), and the ilvl-range within-bucket anchor-to-max pass. A
  future raw-link "byte-identical" preset would add enchant/gems/source.
- **Empty / 0-itemID / secret slots** — `Gather` skips them uniformly so callers
  never branch on a nil link or a secret value.
- **`isBound` fidelity** — stored container `isBound` is coarse and only present for
  some sources; a real soulbound/BoE/BoA filter should use PE link-mode bind
  resolution at query time, not the stored flag.
- **Decided: enhance the Items tab** (was "new tab vs. enhanced tab"). AltTracker's
  sub-tab space is exhausted, so the dupe feature is a **view-mode of the Items
  tab** — adaptive columns + grouping, default view unchanged — not a new tab.
