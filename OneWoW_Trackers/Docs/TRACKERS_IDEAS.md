# Trackers — Ideas & Direction (scratch)

> **Status:** design notes, **not committed scope**. Parking lot for Trackers-specific
> direction so collectibles and AltTracker2 ideas stay in their own docs. Promote
> items into [`ARCHITECTURE.md`](ARCHITECTURE.md) as they land.
>
> **Cross-leg sequencing lives in [`ROADMAP.md`](../../OneWoW/Docs/ROADMAP.md)** — what to
> build next across all three legs, shared prerequisites, and the decisions log. This file
> owns Trackers-specific direction only.
>
> **See also:**
> - [`ARCHITECTURE.md`](ARCHITECTURE.md) (shipped Trackers design)
> - [`ROADMAP.md`](../../OneWoW/Docs/ROADMAP.md) (cross-leg sequencing)
> - [`COLLECTIBLES.md`](../../OneWoW/Docs/COLLECTIBLES.md) (LOD: identity vs plans)
> - [`COLLECTIBLES_IDEAS.md`](../../OneWoW/Docs/COLLECTIBLES_IDEAS.md) (want list, keys, temporal)
> - [`ALTTRACKER2_IDEAS.md`](../../OneWoW/Docs/ALTTRACKER2_IDEAS.md) (roster Ask / lockouts)
> - [`JOURNAL_DATA.md`](../../OneWoW_CatalogData_Journal/Docs/JOURNAL_DATA.md) (Catalog Journal + DB2 membership)

## The three legs

These products share keys, lockouts, and alts; they do not share ownership.

| Leg | Owns | Does not own |
| --- | --- | --- |
| **`OneWoW.Collectibles` + Notes** | Identity (`type:id` keys), live collected?, user want/intent, vendor sightings | Executable steps, route order |
| **`OneWoW_Trackers`** | Lists / sections / steps, auto-complete, pinned overlays, map pins | Collection truth, per-alt SavedVariables, “what don’t I have” |
| **AltTracker / AltTracker2** | Per-alt snapshots (quests, lockouts, currencies, professions), Ask the roster | Farm routes, collectible records |

**Instance / encounter / loot listing is not a fourth leg.** Catalog (`OneWoW_Catalog` Journal tab) is the EJ interface; `OneWoW_CatalogData_Journal` is the store (`OneWoW_CatalogData_Journal_API`); listing and valid difficulties come from Generated Lua mined from `.warehouse/Sources/Wago` (`JournalTierXInstance`, `MapDifficulty`, `JournalEncounter` → `DungeonEncounter`). QoL already consumes `GetInstanceByMapID` for toasts / ESC. Trackers and Collectibles **read those IDs**; they do not overlay Blizzard’s Encounter Journal or ship a parallel instance encyclopedia.

A `farming`-intent collectible in Notes should **hand a key to Trackers**, not grow a farm engine. Trackers already is “executable plans.” The remaining work is the handoff contract, skip/prune against live game state, and a few step types — not a second addon.

---

## What already ships (reuse first)

Do not invent parallel track types. The engine already evaluates:

| Need | Already exists |
| --- | --- |
| Collection truth for mount / pet / toy / appearance | `TrackerEngine` → `OneWoW.Collectibles.GetCollectionState` + `BuildKey` |
| Hidden daily/weekly rare lock | `rare_quest` — **display name only**, see caveat below |
| Account-wide quest flag | `quest_account` |
| “N of these quests” | `quest_pool` / `quest_pool_account` |
| Kill / loot / talk / enter instance / dungeon-raid boss | `kill_creature`, `loot_item`, `npc_interact`, `enter_instance`, `kill_encounter` |
| Map pin on a step | `mapID` + `coordX`/`coordY` + `TrackerMap` |
| Step gating | `professionRequired`, `eventRequired` (calendar `eventID`), `faction` hide; `requiresSteps` dims **and** blocks user check-off (`TD:CanCompleteStep`); editor picker; still does not hide |
| Per-alt “who has done this step” | `rosterMode` (current char stamped into an account roster) |
| Cross-alt quest completion | `OneWoW_CatalogData_Quests_API.GetCompletedCharacters` / `GetActiveCharacters` — public, with UI in Catalog |
| Collectible-shaped preset | Dusting for Moths (`TrackerPresets` — `quest_account` + coords + renown gates) |
| Hide completed | `pinnedHideCompleted` (persisted, per list) — the hub filter is a different thing, see caveat |
| Interval timer step | `custom_timer` (`trackParams.interval` in seconds; reset reads `sp.lastCompleted`) |
| Instance / map / difficulty identity | `OneWoW_CatalogData_Journal_API` (`GetInstanceByMapID`, live EJ merge); Generated `JournalMapDifficulties` / `JournalInstanceMeta` |
| Row reorder (suite) | `OneWoW_GUI:CreateReorderDrag` — bags, hub pins, Tracker hub detail (sections + steps; drop a step on a header). `TD:MoveStepToSection` migrates the progress blob |

**Caveats on the rows above** — verified against the code, do not re-derive from the older text:

- **`rare_quest` is a literal alias of `quest`.** Same evaluator body, same
  `C_QuestLog.IsQuestFlaggedCompleted`, no distinct reset semantics. It is a label, not a
  daily-lock capability. The real capability needs the curated key → hidden-quest map
  ([`ROADMAP.md`](../../OneWoW/Docs/ROADMAP.md) P-1) plus a daily-reset list.
- **`kill_encounter` is live lockout for the logged-in character**, not the Endgame store
  `_API` (P-3) and not skip/dim for `enter_instance` / `kill_creature`. See §12 / §3.
- **`requiresSteps` dims a hub row and blocks user check-off** via `TD:CanCompleteStep`
  (hub + pin). It does not hide the step or feed `IsStepVisible`. The step editor has a
  sibling picker. Markup still does not parse it — serialize/import plus the editor. §2's
  ordered prereqs and §6's prune both assume more than this.
- **`hideCompleted` and `pinnedHideCompleted` are not a pair.** `pinnedHideCompleted` is a
  persisted per-list field honored by the pin and hub detail. The hub-side "Hide completed"
  is a session filter over the left rail that hides fully complete *lists*.
- **Picker is type-family, not one card per engine type.** Quest scopes
  (`quest` / `quest_account` / `quest_world` / `quest_active` / `rare_quest`) share one
  card; vault slots and profession tasks share one card each. `rare_quest` is a **label**,
  not its own card (same evaluator as `quest`). Remaining singles have their own cards
  (loot, timer, zone, campaign, quest progress, exploration, `kill_encounter`). Nested
  objectives reuse the same schema. Dusting for Moths is authorable in the UI. See
  [`ROADMAP.md`](../../OneWoW/Docs/ROADMAP.md) P-4 (shipped); `kill_encounter` shipped
  after P-4 as sequence 7b.
- **`custom_timer` reset uses `sp.lastCompleted` plus `trackParams.interval` (seconds).**
  The step editor collects the interval in hours. Objective rows still show seconds.
- **Objective roll-up:** a step with an `objectives` array completes when every objective is
  done (`EvaluateStep`), regardless of the parent `trackType`. `faction` (`alliance` /
  `horde` / `both`) hides steps and sections; profession and calendar event gates also hide.

**Gaps vs the design sentence in `COLLECTIBLES.md`:** lists are **not** keyed by collectible key today. There is no Notes → Trackers `_API` to spawn or focus a plan. There is no “set instance difficulty” step. (`eventRequired` fail-open **shipped** — see §4.) Lockouts: `kill_encounter` already answers live lockout for the logged-in character via `C_RaidLocks.IsEncounterComplete`. `enter_instance` / `kill_creature` still do not consult lockouts, and there is no Endgame store `_API` for stored / cross-alt reads (roadmap P-3).

**Gaps vs the rest of the suite UI:** the engine and pin overlay are usable; the hub **Tracker** tab is a mid-modernization authoring surface (see Hub tab UI below). Notes handoff lands in that tab.

---

## Hub tab UI (audit)

Three layers, not one screen: **data** (`TrackerData` — lists → sections → steps), **engine** (`TrackerEngine` — evaluate, pins, map), **UI** (hub tab author / browse, editor dialogs, pinned overlay, farm value). `/1wt` opens the hub tab. `_API` today is show/hide.

**Chrome, left list, and detail reorder use `OneWoW_GUI`. Section/step rows stay custom.**

| Uses the toolkit | Rolls its own |
| --- | --- |
| Panels, `CreateScrollFrame`, `CreateFitTextButton`, `CreateDropdown` + `AttachFilterMenu`, `CreateEditBox`, `CreateCheckbox`, `CreateProgressBar`, `CreateFavoriteToggleButton`, `CreateIconButton`, `CreateDivider`, `CreateLayoutFrame`, `CreateReorderDrag`, `CreateListRowBasic` (left rail compose), `CreateVirtualizer` (left rail, 56px), `CreateFS`, `GetThemeColor`, hub `LEFT_PANEL_WIDTH` / `PANEL_GAP`, `CreateDialog` | Detail section/step rows (`t-tracker.lua` 910, 1026): raw `CreateFrame("Button", …, "BackdropTemplate")`. **Declined, not blocked** — they need collapse chrome, a hover icon strip, checkboxes, and a complete frame list for the drag controller. |
| Theme / language callbacks on the lifecycle root. Editor quick-start + import cards on `CreateListRowBasic`; farm detail editor on `CreateFrame` + `CreateItemListEditor` | Expanding step-category card (`ui-tracker-editor.lua` 2217): accordion with active state, always-visible description, embedded field row. **Declined** — see §0. |
| Pinned overlay shell: `CreateFrame` + `CreateTitleBar` + `CreateFS` | Pinned overlay rows: pooled raw frames (section `BackdropTemplate` at 36, steps plain Buttons) plus its farm rows (`ui-tracker-farmvalue.lua` 375, reached from `RenderPinned`). Reasonable for a float; **not part of §0**. |

**No detail-tree virtualizer, and therefore no `CreateReorderDrag` data-index API.** Both
declined — see §0. `ShowDetail` is structure-only (select, collapse, add/delete, reorder,
hide-completed); progress and scan bind the open detail in place, and collapsed sections build
no step rows, so row counts stay well under what windowing would earn.

**Shipped hub chrome:** sticky pin + title, list-action strip + Hide completed under the title, author on left cards, account-wide / progress / hover hint in the scroll, divider above the section tree. Section/step add-edit-delete icons reveal on row hover (collapse plus/minus always visible); counts stay on the right, icons to their left. Drag is the only reorder chrome (two `CreateReorderDrag` controllers; section headers are drop targets for steps, not Attached to the step controller). Step right-click is Edit / mark complete / Delete. `TD:MoveSection` / `MoveStep` / `MoveStepToSection` stay as data.

**Shipped left rail:** `CreateListRowBasic` (56px) plus type icon, meta, progress, favorite; adopted scroll on `CreateVirtualizer`. `CreateCard` / `CreateCardStack` stay settings accordions, not list tiles (dense compose; closed).

**Shipped editor locales:** wizard, quick-start, step categories, field labels, and hub leftovers (`Untitled`, waypoint print, default section `Tasks`) go through Trackers locale keys. Reused `SAVE` / `CANCEL` / `CLOSE` and existing `TRACKER_*` titles. Category folders render through `TD:GetCategoryDisplayName` (Blizzard globals where the client ships the term, shared bare-words, four Trackers keys); the stored `list.category` stays canonical English data.

The pin overlay is the **play** surface; the hub tab is the **authoring** surface. §0 covers the
authoring surface only.

---

## Where to start

**Ordering now lives in [`ROADMAP.md`](../../OneWoW/Docs/ROADMAP.md).** It sequences all three
legs together and names the shared prerequisites, which is not something this doc can see on
its own. Trackers' own slices, for orientation:

| Slice | State |
| --- | --- |
| **0** — hub tab GUI-first (§0) | **Shipped**; the surface every later idea sits on |
| **0b** — calendar fail-open (§4) | **Shipped** |
| **1** — collectible-key handoff (§1) | Next |
| **2** — lockout skip for `enter_instance` / `kill_creature` (§3) | Blocked on the Endgame lockout `_API` (roadmap P-3). `kill_encounter` already does live lockout for the logged-in char |

Slice 0 has no remaining items. Everything once listed under §0 is now either shipped or
recorded as declined (detail-tree virtualizer, the `CreateReorderDrag` data-index API it needed,
detail rows and the step-category card staying custom) or out of scope (pinned overlay restyle
and its farm rows, dwell-expand during drag). See §0 for the reasoning. Not a new product.
`kill_encounter` (§12) also shipped — fill from the current encounter plus live raid-lock
evaluation. That does not unblock §3 skip/dim for other instance types.

Do not start with AltTracker2, rare subscribe, chore encyclopedias, detach windows, or
instance-first loot. Those hang off contracts we do not have yet. Notes handoff is next and
lands on the shipped authoring tab.

---

## Ideas

### 0. Hub tab GUI-first pass

Finish the **authoring tab** so it matches bags / hub pins. Engine and pinned overlay stay.
Scope is the hub tab and its editor dialogs — nothing else. This slice has an ending; see
Remaining below.

**Shipped:** `CreateReorderDrag` on section headers and steps (including drop onto another
section). List/section/step actions are `CreateIconButton` (`EDIT` / `DELETE` / `RESET` /
`L[]`, textures/atlases). No header arrows, no step-menu Move Up/Down. `MoveSection` /
`MoveStep` / `MoveStepToSection` remain data-only. Detail chrome restack (sticky pin/title +
action strip; hover-reveal row actions; counts on the right). Left rail: `CreateListRowBasic`
compose + `CreateVirtualizer` 56px. Editor/hub English replaced with locale keys.
Progress/scan binds the open detail in place (`ShowDetail` is structure-only).
`UI/Framework.lua` is gone.

**Remaining:** none. §0 is shipped.

The last three items closed together: the editor quick-start and import cards moved to
`CreateListRowBasic` compose (gaining the 1px `BORDER_SUBTLE` edge the old borderless
`BACKDROP_SIMPLE` never drew), and all 15 category folders now render localized through
`TD:GetCategoryDisplayName` / `GetCategoryOptions` while the stored `list.category` stays
canonical English, so filtering, import normalization, and `RemapStoredCategories` keep
comparing one vocabulary.

**Declined — decided, do not re-litigate:**

- **Expanding step-category card stays custom** (`ui-tracker-editor.lua` 2217). An inline
  accordion carrying a selected/active state, an always-visible description, and an embedded
  field row plus Save/Fill buttons. `CreateCard` has no active state and hides its content when
  collapsed; `CreateSelectableCard` is checkbox-backed. Not worth expanding shared GUI for one
  consumer.

- **Detail-tree virtualizer.** Lists do not get big enough to earn it. `ShowDetail` is
  structure-only (rebuild on select / collapse / add / delete / reorder / hide-completed, not
  on progress ticks, which bind in place), and collapsed sections build no step rows at all,
  so the worst case is the visible steps of one expanded list.
- **`CreateReorderDrag` data-index API.** Only the virtualizer wanted it. `CreateReorderDrag`
  takes a *complete* frame list through `getItems` and reorders by index into it; a windowed
  pool would hand it pool indices, not data indices. Fixing that is a shared-GUI change
  affecting bags and hub pins for the benefit of one consumer that no longer needs it. Cross-
  section drag compounds it — the step controller deliberately flattens headers and steps into
  one item list so a step can be dropped on a header, and a windowed pool cannot guarantee the
  target is realized.
- **Detail section/step rows stay custom `BackdropTemplate`** (`t-tracker.lua` 910, 1026).
  Not blocked — chosen. They need collapse chrome, a hover icon strip, checkboxes, and a
  complete frame list for the drag controller, none of which `CreateListRowBasic` offers.
- **`CreateCard` vs dense-row for the left rail.** Dense compose on `CreateListRowBasic` won;
  do not extend the shared helper for this.

**Not part of §0:**

- **Pinned overlay restyle.** `ui-tracker-pinned.lua` rows are pooled raw frames (section rows
  `BackdropTemplate` at 36; steps plain Buttons) under a toolkit shell. The overlay is the play
  surface, not the authoring surface — its own pass if it ever happens.
- **Farm-value item rows.** `AcquireFarmRow` (`ui-tracker-farmvalue.lua` ~375) is reached only
  from `TFV:RenderPinned`, called by the pinned overlay — so it belongs to the row above, not to
  the tab. The tab's own farm surface is `TFV:RenderDetailEditor`, already built on
  `CreateFrame` + `CreateItemListEditor`. An earlier revision of this doc listed it as §0 work
  by mistake.
- **Dwell-expand during drag.** Hovering a collapsed section header mid-drag to auto-expand it.
  Today a step dropped on a header lands at position 1, which is all a collapsed section can
  offer since its step rows are never built. A drag-UX enhancement, not GUI-first work.
- Inventing a second Trackers product.

### 1. Collectible-key handoff

Notes `farming` (and maybe `want` with a “make a plan” action) should `BringUp("OneWoW_Trackers")` and upsert or focus a list whose stable id is the collectible key (`mount:2240`, …).

- **Reuse:** existing list/section/step model; collection steps already speak Collectibles keys.
- **Build:** a thin `_API` (`EnsureCollectiblePlan(key)` / `ShowCollectiblePlan(key)`). Do not duplicate the want record. When the key becomes collected, the plan can auto-complete the collection step and/or prompt archive — collection truth stays live in core.
- **Contract lives here;** Notes only stores the key + intent. Detail: [`COLLECTIBLES_IDEAS.md`](../../OneWoW/Docs/COLLECTIBLES_IDEAS.md) §1.

### 2. Acquisition `taskList` → existing step types

Collectionist-style rows are a checklist of live-evaluable gates (quest, achievement criteria, item count, species, waypoint), not source-text. Map that onto types we already have; click the **first incomplete** step (they already do this).

| Their gate | Our step |
| --- | --- |
| quest / tracking quest | `quest` / `rare_quest` / `quest_account` |
| achievement / criteriaID | `achievement` |
| itemCount | `item` / `loot_item` |
| speciesID / mountID / toy | `pet` / `mount` / `toy` |
| coords | `coordinates` + map pin |
| renown / currency cost | `renown` / `currency` |
| ordered prereqs | `requiresSteps` |

Do **not** own Collectionist’s Midnight encyclopedia. A plan’s steps are either user-authored, a bundled preset (moths), or a small curated map hanging off a key — same maintenance shape collectibles already accepted for daily-lock quests.

### 3. Remaining-attempt / lockout skip

FuocoNote / ICH / BountyHelper / MRP all answer “is this still lootable this reset?” from `GetSavedInstance*` (and shared 10/25 diffs). We already store lockouts in AltTracker_Endgame. `kill_encounter` already answers live lockout for the **logged-in** character via `C_RaidLocks.IsEncounterComplete` (redirected difficulty) — that is not this slice.

- **Build:** when a step names `enter_instance` / `kill_creature`, evaluate **stored** lockout and **skip or dim** — do not invent an attempt ledger. “Tried this week” is lockout + `rare_quest`, not a custom counter. `kill_encounter` already self-completes on the live raid lock; this slice is the other instance types plus a shared skip/dim policy.
- **Roster read:** the *data* is available today and is **not** blocked by AltTracker2 — lockouts come from Endgame (via the `_API` in roadmap P-3) and cross-alt quest completion from `OneWoW_CatalogData_Quests_API.GetCompletedCharacters`. Only the Ask-the-roster *UI* waits for AltTracker2. Trackers evaluates the logged-in char first either way.
- Collectibles-side framing: [`COLLECTIBLES_IDEAS.md`](../../OneWoW/Docs/COLLECTIBLES_IDEAS.md) §2 / §8.

### 4. Calendar fail-open

**Shipped.** `eventRequired` hides holiday / timewalking steps. FuocoNote’s rule: if the calendar has not arrived (`GetNumDayEvents == 0`), **keep the step visible**. Hiding a TW vendor farm because the calendar is empty looks like the addon lied.

The engine fail-opens until `CALENDAR_UPDATE_EVENT_LIST`, then fail-closes when the event is known inactive (`TrackerEngine.IsEventActive`). Unknown → show; inactive → hide. Ties to the collectibles temporal service; the step gate is Trackers’ consumer.

### 5. Difficulty as an action

ICH’s product is one-click `SetDungeonDifficultyID` / `SetRaidDifficultyID` / `SetLegacyRaidDifficultyID` from the collectible row, disabled when owned or lockout-complete.

- **Build:** a step type (or step action) “set difficulty D.” Gate with `OneWoW.Restriction` (protected / restricted as appropriate) — never raw `InCombatLockdown`. Not a Notes control.

### 6. Adaptive prune (World Tour / MRP skip)

ICH World Tour and MRP prune stops when nothing left is lootable (owned **or** lockout-blocked). Trackers already has ordered steps and hide-completed.

- **Build:** evaluate collected (Collectibles) + lockout (#3) + calendar (#4) and skip. That is “smart route” without owning MRP pathfinding, travel-item graphs, or a continent nearest-neighbor solver.
- Bundled “world tour” presets are data, like moths — optional, expansion-scoped, not a new list type unless `guide` is insufficient.

### 7. In-instance remaining strip

ICH’s mini-window: current map + current difficulty → remaining collectibles for this run, desaturate if the encounter is done.

- **Reuse:** `GetInstanceByMapID` (same path as QoL instance toasts) + Generated difficulties. Activity UI stays Catalog Journal.
- **Build:** a pinned list (or a filter on the current plan) scoped to that `instanceID` / current difficulty. The thin key → `{ instanceID, encounterID, difficultyIDs }` map is a collectibles product decision ([`COLLECTIBLES_IDEAS.md`](../../OneWoW/Docs/COLLECTIBLES_IDEAS.md) §11); Trackers does not grow a loot encyclopedia.

### 8. Rare packs as a set of `rare_quest`s

FuocoNote models a multi-rare farm as **one row done when every NPC’s weekly quest is flagged**. `rare_quest` + `questIDs` / a section of steps already covers this. The curated collectible → hidden-quest map lives with collectibles; Trackers just evaluates the flags.

### 9. RareScanner / SilverDragon — consume alerts, don’t scan

When they pop a rare, we already know how to answer “do I still need anything from this NPC?” and “is today’s loot lock burned?” Scanning vignettes ourselves stays out of scope ([`COLLECTIBLES_IDEAS.md`](../../OneWoW/Docs/COLLECTIBLES_IDEAS.md) out-of-scope). This is a **subscriber**.

**SilverDragon is the first-class hook.** AceAddon + CallbackHandler on the `SilverDragon` global, documented for other addons (`SilverDragon.NAMESPACE = ns`). Subscribe after `RegisterAddonLoadedWatcher("SilverDragon", …)` (idempotent). Prefer **`Announce`** (post-filter: they already dropped ignored / dead / “nothing notable”) over raw **`Seen`**. Payload: `id` (npcID), `zone`, `x`, `y`, `is_dead`, `source`, `unit`, GUID, vignetteGUID. Loot tables and quest ids live on `SilverDragon.NAMESPACE` (`Loot.GetLootTable(id)`, `mobdb[id].quest`). `MobIsNotable` is their filter, not our collection truth — re-resolve itemIDs through `OneWoW.Collectibles.ResolveKeyFromItem` + `GetCollectionState`.

**RareScanner is second-class.** No public callback bus. Alerts funnel through `scanner_button:SimulateRareFound` on the named frame `RARESCANNER_BUTTON`. A `hooksecurefunc` there is the least-bad adapter; treat it as fragile. Loot / killed state (`RSNpcDB`) is an internal lib — do **not** read their SavedVariables. If both addons are loaded, debounce on `npcID` so we fire once.

**Two settings, same vocabulary as vendor capture — do not share the vendor dropdown.**

Vendor capture is `off | prompt | auto` on a merchant scan (you walked up; items are actually for sale; dialog is `"Add %d vendor collectible(s) to your want list?"`). A rare pop is ambient, often in combat, and the loot table is *possible* drops, not a shop. Reuse the **pattern**, not the same SavedVariables key (`collectibleCaptureMode` default `off`).

| Concern | Setting | Default |
| --- | --- | --- |
| Pin / toast when a rare is up | `off` / `alert` / `auto-pin` | off until they opt into RS/SD |
| Missing loot **not** on the want list | `off` / `prompt` / `auto` (Notes capture) | **prompt** (same three-way as vendors) |

**Pin/alert** only needs a reason to care: at least one **wanted** key drops here, or the player just accepted a capture prompt. If everything on the table is already collected or already on the want list, no capture dialog (idempotent, same as `HasVendorOffer` skipping a known vendor).

**Capture prompt** (the vendor analog): when the rare has uncollected collectibles that are **not** yet Notes records, StaticPopup `"Add %d collectible(s) from [Rare] to your want list?"` YES = upsert `want` (and then pin). NO = ignore this npcID until it pops again with *new* keys (or a session “don’t ask again for this rare”). Guard `StaticPopup_Visible` so RS+SD debounce plus re-alerts do not stack. **Defer while `OneWoW.Restriction.IsInCombat()`** — vendor dialogs happen at a merchant; rare dialogs otherwise fight the kill.

**Do not default `auto`.** A Midnight rare with a dozen appearances would dump the want list the way vendor-auto does for a transmog vendor, without the player having chosen to shop. Prompt is the honest default; auto is for collectors who already live on vendor-auto and want the same for rares.

**Add-all is correct for the prompt** (vendor does the same). Picking per-item on a combat rare is more UI than the StaticPopup is worth; they can delete from Notes after. Optional later: type filter on capture (mount/pet/toy only vs appearances) if auto/prompt feels loud.

Want-list-only vs “any missing” is then just capture `off` (pin only if already wanted) vs `prompt`/`auto`. No fourth enum.

**Ephemeral tracker shape:**

- Header: rare **portrait** (`PlayerModel` / `ModelScene:SetCreature(npcID)` — display only, not wardrobe preview; not a Restriction issue) + name. Same idea as RareScanner’s miniature / SilverDragon’s popup model, on *our* pin.
- Body: missing collectible rows (`mount` / `pet` / `toy` / `transmog` steps we already evaluate). Hide or check off owned.
- Status line: **loot lock** from hidden tracking quest (`rare_quest` / Collections `IsQuestCompleted`) — “already killed today, no special loot.” Do **not** invent a kill ledger or copy RareScanner’s `rares_killed` table. Session `kill_creature` on the open pin can bump “you just killed it”; daily truth stays the quest flag. Other alts: AltTracker snapshot (freshness = last seen).
- Dedup: one pin per `npcID`; refresh if the same rare re-alerts. Dismiss / leave range / all collected / lock burned → drop the pin. Optional “save as list” later.

**Load:** `RegisterAddonLoadedWatcher("SilverDragon" / "RareScanner", …)` — they load on their own; we subscribe. Do not TOC-`OptionalDeps` them (that would `LoadAddOn` them with Trackers). Never RequiredDeps. Suite-internal units never go in `OptionalDeps`; the loader owns that.

**Loot source policy:** consume SD (and later a thin curated `npcID → collectible keys` if we outgrow them). Filter through Collectibles keys. Do not maintain a parallel rare-loot encyclopedia.

---

## Weekly / chore addon pass (`_OneWoW_Offline/Trackers/`)

Four addons, mostly “remember your weeklies.” We already ship that as `weekly` lists + presets (Great Vault, Midnight weeklies, Prey, renown, moths). Steal **framing and a few step kinds**, not a second chore encyclopedia or a roster spreadsheet.

| Addon | What it actually is | Overlap |
| --- | --- | --- |
| **MidnightRoutine** | Live-scanned Midnight module dashboard + warband board + detachable panels | Presets + `rosterMode`; warband matrix is AltTracker2 |
| **ChoreTracker** | Declarative expansion-pack chores + interval world-event timers | `quest_pool`, `eventRequired`, hide-completed |
| **WeeklyRewards** | Multi-character weekly *rewards* matrix + loot attribution | AltTracker2 Ops; loot→step is Trackers-shaped |
| **MidnightHelper** (tracker slice only) | Season ops hub: reset routine, account rollups, Trading Post, nudges | Planning UX; skip combat/keybinds/guides |

### 10. Rotating pools and “what’s live this week”

ChoreTracker `pick = N` and WeeklyRewards `maxCompletion` / `pick` / `rollover` are the same object as `quest_pool`. MidnightRoutine computes vault buckets and Prey hunt counts live.

- **Build:** keep `quest_pool`; refresh **preset content** (Spark, Special Assignment pick-2, Prey ID ranges, Void assaults) from these DBs instead of owning a forever DF→Midnight chore corpus.
- World-boss **rotation** (Routine `WORLD_BOSS_ROTATION`, Helper `WorldBoss.lua`) is “active now / next,” not a static quest id — a preset that swaps the live id, not a new list type.

### 11. Interval world events + map POI (not rares)

ChoreTracker `Data/Timers/*.lua`: `interval`, `duration`, `offset` from weekly reset, optional `uiMapId` + `areaPois` (Curse Surge sites). Theater Troupe / Nightfall / Beledar-style clocks.

- **Reuse:** `custom_timer` + `eventRequired` + `TrackerMap`.
- **Build:** a timer step that can bind **AreaPOI ids** so the pin follows the live site this week. Still not a vignette scanner (§9).

### 12. Encounter-linked steps (Catalog / Journal, not an EJ overlay)

**Shipped (the step):** `kill_encounter` auto-completes on Adventure Guide encounter defeat. Unit GUIDs are secret in instances, so open-world `kill_creature` fill cannot work there. Completion uses `ENCOUNTER_END`'s combat encounter ID plus live `C_RaidLocks.IsEncounterComplete` (nil while the lock is still open so a session latch is not wiped). Fill uses the current pull or last successful kill this session (`Fill from current encounter`), not the targeted unit. Schema params: journal `encounterID`, plus `dungeonEncounterID` / `mapID` / optional `difficultyID` filled from the snapshot or `EJ_GetEncounterInfo`. Editor card is its own picker. See `Core/Encounter.lua` and Trackers [`ARCHITECTURE.md`](ARCHITECTURE.md).

MidnightRoutine’s *idea* was right: a weekly can complete on EJ encounters + difficulty, not only a quest flag. Their *authoring* is still wrong for us — they overlay Blizzard’s Encounter Journal. We already have that interface: Catalog Journal + `OneWoW_CatalogData_Journal`.

- **Reuse (shipped):** live EJ for fill and lock; combat ID from `ENCOUNTER_*`. Valid diffs still come from Generated `JournalMapDifficulties` when a step needs them.
- **Still to build:** ShoppingList-style “pick a row in Catalog, emit a Trackers step” — `RegisterAddonLoadedWatcher("OneWoW_Catalog", …)`, not a FrameXML overlay. Consume `OneWoW_CatalogData_Journal_API` the suite way: data-ready for sticky UI, `EnsureLoaded` / `WithAddon` only on an explicit pick action, call-time `_API` for one-shot reads. Never `## OptionalDeps: OneWoW_*`. Difficulty *action* (`SetDungeonDifficultyID` …) stays §5. Skip/dim of `enter_instance` / `kill_creature` stays §3 (P-3).
- **Do not** clone Routine’s EJ overlay, walk a third-party instance dump for membership, or hand-maintain a boss list Trackers-side. Listing truth stays Generated + live EJ merge ([`JOURNAL_DATA.md`](../../OneWoW_CatalogData_Journal/Docs/JOURNAL_DATA.md)).

### 13. Detach a section, not a second product

Routine `DetachedWindows`: one module → its own floating window (size/pos). We already pin whole lists.

- **Build:** “detach this section” as a complement to pin-the-list (vault pips on one float, Prey on another) without cloning Routine’s warband board.

### 14. Reset routine as an ordered weekly list

MidnightHelper `ResetRoutine`: post-reset pickup order (vault → hub → trainers), **omit a step if the signal is unverified** (“never lie”). VaultReminder is a reset-day *nudge*, not scoring.

- **Build:** a bundled weekly list with hide-when-unknown (same honesty as calendar fail-open §4). Optional map-pin sequence. Claim-nudge can be a dismissable card on the pinned list, not login spam.
- **Do not** steal VaultAdvisor / Pawn / AltOverview — AltTracker2.

### 15. Account rollup strip (thin)

Helper `AccountWeeklyChecklist`: “N alts still need SA / Trove.” WeeklyRewards is the full char×column spreadsheet.

- **Build:** one summary row on a weekly list (`rosterMode` already stamps who did a step). Click-through to AltTracker2 Ask is enough — note that is a **UI deferral**, so the strip itself should not wait on AT2. Do **not** rebuild WeeklyRewards as Trackers UI.

### 16. Trading Post month checklist

Helper `TradingPost`: cache Perks wares after the player opens the post once; Tender + owned/purchased. Collectibles already named TP as a faucet.

- **Build:** account-wide monthly list from `C_PerksProgram` (live after one open — no static DB). Wishlist / afford / owned as steps. Identity of a ware that is a collectible still hangs on the Collectibles key.

### 17. Holiday packs + never-lie profession weeklies

Routine/ChoreTracker/WeeklyRewards all ship Darkmoon / Timewalking / bonus-event quest tables gated on calendar. Helper `ProfessionNextStep` only shows **unspent KP + verified trainer quests** — no fake knowledge fractions.

- **Reuse:** `eventRequired` (§4 fail-open), `prof_knowledge` / `prof_concentration`.
- **Build:** holiday **preset packs** (enable when the event is known active). Profession plans stay verified-id only; the full knowledge-treasure map is optional curated data, not a Trackers encyclopedia.

### 18. Narrow loot-attribution (optional)

WeeklyRewards `SelectableLootScanner` / `AtomicContainerLootScanner` credit a weekly when a specific item/currency drops (container toast, world loot).

- **Build only if a preset needs it** (delve map, KP treasure). `loot_item` already exists; wire toast/container if evaluation is blind today. Not a general loot logger.

### 19. No-quest weeklies: omit, don’t invent a ledger

Helper’s Gilded Stash has **no live API**; they infer progress from a Delve Log of T11+ bountiful runs. Trovehunter’s Bounty, by contrast, is a real quest flag (`86371`).

- **Reuse:** `quest` / `rare_quest` whenever Blizzard flags it.
- **Build:** same honesty as ResetRoutine and calendar fail-open — if we cannot read a Blizzard signal (quest, currency cap, `C_UIWidgetManager` widget), **omit the step**. Do not copy the inferred-run ledger. A widget-backed step type is discuss-first if a preset actually needs it.

### Skip from this set

| Skip | Owner |
| --- | --- |
| Warband / concentration / currency matrix | AltTracker2 |
| Combat coaches, keybinds, layouts, dungeon live tips | MidnightHelper-as-guide, not us |
| Forever-porting DF/TWW chore files | Consume IDs into thin Midnight presets |
| AJ auto-accept of chores | Opt-in at most; suite prefers explicit action |
| WeeklyRewards spreadsheet as hub UI | Lists + pins stay the product |
| MidnightRoutine Encounter Journal overlay | Catalog Journal tab + Journal `_API` / DB2 Generated |

---

## Out of scope (integrate, don’t build)

- **Owning a drop-rate / instance-loot encyclopedia** (Collection Log packs, FuocoNote `droplist`, BountyHelper chances, MRP’s external data addon). Consume a source if a preset needs it; do not maintain the corpus.
- **Pathfinding / travel-item routing** (MRP). Pins + skip are enough.
- **TomTom as a RequiredDep.** Blizzard waypoint + `TrackerMap` already exist. If we ever subscribe, use a loaded-watcher — do not TOC-OptionalDep it to pull it in with Trackers.
- **Rare spawn scanning.** Subscribe to RareScanner / SilverDragon alerts (§9); do not register `VIGNETTE_*` ourselves to discover rares.
- **AH buy flows** (Collectionator). Farm value pricing stays the only AH touch.
- **Guild / BNet missing-item bitmaps** (Collectionist Roster). Cross-account sharing is a declared AltTracker2 non-goal.
- **Rebuilding Blizzard Collections** as a Trackers UI.

---

## Open questions

Cross-leg questions (temporal helper, instance→collectible map, one-list-per-key) are tracked
in [`ROADMAP.md`](../../OneWoW/Docs/ROADMAP.md) so they get one answer, not three.

- ~~Detail-tree virtualizer (§0): blocked on `CreateReorderDrag` addressing by data index?~~ **Answered:** declined. Lists do not get big enough, and the shared data-index API it needed is declined with it. Left rail dense compose is closed.
- ~~Handoff: auto-spawn a plan on `farming` intent, or only on an explicit “Track this”?~~ **Answered:** explicit “Track this” for v1.
- ~~Rare capture: share vendor `off|prompt|auto` UI chrome but a separate SV key?~~ **Answered:** separate SV key, same vocabulary.
- ~~Encounter authoring: Catalog Journal picker vs fill-from-combat?~~ **Answered for v1:** fill from the current or last-ended encounter. Catalog “pick a row, emit a step” is still optional later (§12 remaining).
- **Rare alerts (§9): do the two settings compose?** Pin mode defaults `off` but capture mode defaults `prompt`. If capture is independent, installing SilverDragon produces StaticPopups the player never opted into — the exact vendor-auto failure §9 argues against. Recommended: gate capture on pin mode being non-`off`.
- `SetDifficulty` step vs a button on `enter_instance` steps only?
- Rare alerts: NPCs only, or also SilverDragon `AnnounceLoot` / RareScanner containers?
- Weekly presets: consume Routine/ChoreTracker/WeeklyRewards Midnight IDs as data, or keep hand-maintained `TrackerPresets` only?
- Detach-section (§13) vs pin-the-whole-list — worth a second window type?

---

## Competitive set (offline)

`_OneWoW_Offline/Collecting/` — Collectionist (`taskList`, waypoints), InstanceCollectionHelper (difficulty, World Tour), FuocoNote (weekly remaining, rare-quest packs, calendar), Mount Route Planner (skip collected/lockout — steal prune, not pathfinding), Collection Log (instance-first log — collectibles product decision, not a Trackers rewrite), BountyHelper (lockout companion).

Rare alert hosts (offline root): `SilverDragon/` (CallbackHandler `Announce` / `NAMESPACE` loot), `RareScanner/` (named-button funnel, no public bus).

`_OneWoW_Offline/Trackers/` — MidnightRoutine (modules, detach, custom encounter *evaluation*, warband board — steal detach + encounter-complete steps, **not** the EJ overlay or the matrix), ChoreTracker (`pick` pools, calendar packs, interval+AreaPOI timers), WeeklyRewards (char×reward spreadsheet + loot scanners — steal pack IDs and narrow loot-credit, not the grid), MidnightHelper tracker slice (reset routine, account rollup, Trading Post, never-lie KP; skip combat/guides **and** inferred Gilded Stash ledgers).
