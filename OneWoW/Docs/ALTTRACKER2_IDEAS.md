# AltTracker2 — Redesign Ideas & Architecture

> **Status:** Planning / exploration. The **load unit** `OneWoW_AltTracker2/` is gitignored
> while we prototype; this **design doc** lives in core `OneWoW/Docs/` so it is tracked,
> backed up, and reachable from the other two legs. AltTracker2 registers a hub tab as
> **AltTracker2** during development and will eventually replace / rename to **AltTracker**.
>
> **Audience:** Design + implementation notes for agents and humans. Not player-facing wiki.
>
> **See also (three legs):** this file (roster / Ask / lockouts) ·
> [`COLLECTIBLES_IDEAS.md`](COLLECTIBLES_IDEAS.md) (want list,
> keys, assignment, daily loot-locks) ·
> [`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md)
> (executable farm plans). Do not collapse ownership.
>
> **Cross-leg sequencing lives in [`ROADMAP.md`](ROADMAP.md)** — what to build next across
> all three legs, and which shared prerequisites unblock more than one of them. The phases
> in §8 below are AltTracker2's *internal* product sequencing; the roadmap references them
> where another leg is waiting on one.

---

## 1. Why AltTracker2

Current AltTracker (`OneWoW_AltTracker`) is a **10-tab, character-row matrix farm**
(Summary, Progress, Bank, Equipment, Professions, Auctions, Financials, Items, Action Bars,
Lockouts + Settings). It is strong on data breadth and search syntax, but crowded: every
domain competes as a peer tab, Progress nests four more apps, and wide tables (Equipment ~
20 cols, Progress season matrices) fight the hub chrome.

The redesign is large enough that a parallel unit is safer than in-place surgery:

- Ship / iterate behind hub tab **AltTracker2** next to legacy AltTracker.
- Reuse existing companion stores (`OneWoW_AltTracker_*`) via public `_API` — do not fork data.
- When ready, rename the product surface to AltTracker (folder / manifest / display) via a
  **single naming constant** (see §3).

Because legacy AltTracker is **deleted** at cutover, treat it as **feature-frozen** from
here: bug fixes only. Anything added there is thrown away at Phase 8 and widens the parity
checklist that gates the cutover. Store-side accuracy that AT2 will read anyway is the
exception (Progress raid-kill counting from lockouts + Adventure Guide, currency ID fixes,
tracking picks moved into Options). Do not grow interim roster UI there.

### Design thesis

Players do two different jobs:

1. **One alt at a time** — inspect, bank, gear, professions, “should I log this toon?”
2. **Ask the roster** — who has item X, who’s free of lockout, which Bankers have AH fodder,
   who still needs weekly Y.

Today’s UI mostly forces job (1) into job (2)’s matrix shape. AltTracker2 splits them
explicitly and keeps matrices **where they earn it**.

Inspiration (interaction patterns, not Blizzard skinning):

- **OneWoW Home** — cards as nav + status, not data dumps.
- **AltVault** — list → detail dossier, dense attention rows, orthogonal domain/facet nav.
- **AlterEgo / AltManager / Kronon / Frudi** — weekly ops glance, vault visual language.
- **Altoholic** — Ask/search, dataset×alt grids, smart filters, ambient answers (selectively).

OneWoW theming stays minimalist (`OneWoW_GUI`). Borrow ideas; do not mimic PortraitFrame /
parchment chrome.

---

## 2. Goals & non-goals

### Goals

- Uncrowd the primary nav; alt cards/rows → one-alt detail.
- First-class **Ask** surface for cross-alt questions (incl. **Roles & Alts** scoping).
- Keep / improve **matrix views** for comparison and weekly ops.
- Reuse suite stores, SearchExpand / PredicateEngine, QoL ItemIndex tooltips, Restriction.
- Actionable empty states and honest data freshness.
- Parallel development without breaking legacy AltTracker users mid-flight.

### Non-goals (for v1 of AltTracker2)

- Replacing companion data stores or inventing a second character database.
- Full Altoholic coverage (garrison architect, covenant soulbinds, archaeology grids, …).
- Blizzard-default visual skin.
- Cross-account data sharing (Altoholic AccountSharing) — revisit later if demanded.
- Rebuilding item-location tooltips from scratch (QoL `tp-itemtracker` + Storage ItemIndex
  already own this).

---

## 3. Naming constant (rename-ready)

All user-facing and registration strings that say “AltTracker2” today must resolve through
one place so the eventual rename is a constant flip, not a repo-wide hunt.

```lua
-- Suggested: OneWoW_AltTracker2/Core/Constants.lua (or Manifest)
local ADDON = {
    -- Folder / TOC / load-unit id (must match disk until rename day)
    LOAD_UNIT       = "OneWoW_AltTracker2",

    -- Hub module key passed to OneWoW.UI / ModuleManifest
    MODULE_KEY      = "alttracker2",

    -- Hub tab label (locale key preferred; fallback display)
    DISPLAY_NAME    = "AltTracker2",   -- → later "AltTracker"
    DISPLAY_NAME_KEY = "MODULE_TITLE", -- L["MODULE_TITLE"]

    -- Slash / search path prefixes if needed
    SLASH_TOKEN     = "at2",           -- temporary; retire or alias on rename
    -- Suite slash prefix is `/1w` (legacy AltTracker is `/1wat`). On cutover,
    -- either share `/1wat` or pick `/1wat2` until rename. See open decision #5.
}
```

**Rules:**

- Never hardcode `"AltTracker2"` in UI labels, changelog bullets destined for players, or
  search paths — use `ADDON.DISPLAY_NAME` / locale.
- `LOAD_UNIT` / folder name change is a **cutover** step (TOC, RequiredDeps, gitignore,
  Manifest), not day-one churn.
- Legacy `OneWoW_AltTracker` remains until cutover; both may register hub tabs during overlap.

---

## 4. Information architecture

### 4.1 Top-level surfaces

| Surface | Job | Legacy tabs absorbed |
|---|---|---|
| **Home** | Roster of alt cards/rows; attention; pick an alt | Summary overview / favorites pinning |
| **Ask** | Cross-alt questions + role-scoped queries | Items search, Lockouts “who’s free”, Progress filters, quest ownership |
| **Ops / Compare** | Matrices that earn horizontal/vertical scan | Progress (M+/Raids/Weekly/Currencies), Lockouts, Equipment compare |
| **Economy** | Account money tools (not “an alt”) | Auctions, Financials |
| **Setup** | Backup / DB / pointers | Action Bars, Settings |

**Alt dossier** is not a top-level peer tab — it is **Home → select alt → detail**, with
internal domain sections (Character, Storage, Professions, Progress/Vault, …).

Optional flatter IA if Economy/Setup feel heavy:

```
Home | Ask | Ops | More… (Economy + Setup)
```

### 4.2 Home — alt cards / dense rows

Cards are **navigation + attention**, same philosophy as OneWoW Home.

Suggested row payload (conditional icons only when true — textures/atlases, not Unicode):

- Class icon / color name, level, iLvl
- Realm (and faction if multi-faction roster)
- Gold (optional / hideable)
- **Attention:** mail waiting, vault reward ready, free of tracked lockout, weekly remaining,
  rested, AH ending soon, profession CD ready (subset, configurable)
- Favorite star; pin **current character** above scroll (AltVault pattern)
- Role chips or filter (see §6) — e.g. show only `Banker` / `Crafter` / `Main`

Sort / filter:

- Realm × faction presets, class, level, iLvl, gold, last played, attention score
- Favorites as a **sort partition** (favorites first), not a filter that empties the list
- Empty-filter guard (revert + explain if zero results)

### 4.3 Alt dossier (one-alt detail)

Scrollable character page or thin section nav — **not** a recreation of 10 hub tabs.

Suggested sections (daily-use order):

1. **Status** — level/XP/rest, location/hearth, mail summary, gold, last played
2. **To-do** — vault slots, tracked weeklies, lockout free/busy, currency shortfalls
3. **Gear** — paperdoll / slot grid (quality borders); expand for enchants/gems/durability
4. **Storage** — bags / personal bank / mail for *this* alt (dim-on-search, not hide)
5. **Professions** — skills, concentration, tools; recipe drill-down panel
6. **Progress** — M+ score/key, raid bosses, currencies (season data as data packs)
7. **Setup** (secondary) — action-bar sets for this char

Patterns to steal:

- Orthogonal **facet rail** inside Character (General / Guild / M+ / PvP) if the section
  gets dense — keep top dossier nav short.
- Great Vault as progressive overlay / button, not a permanent peer tab.
- Self-expiring weekly panels (`dataExpires` at weekly reset) + actionable empty states
  (“Visit the bank on this character to populate Storage”).

### 4.4 Ask — cross-alt brain

One search / preset surface that answers questions instead of teaching five tab UIs.

**Example questions (v1 candidates):**

| Question | Data source (existing) | Notes |
|---|---|---|
| Which alts have daily/weekly work left? | Endgame weeklies + Collections active quests | Curated weeklies + real quest flags |
| Which alts aren’t on lockout X / any raid lockout? | Endgame raids.lockouts | Wants the Endgame lockout `_API` (see §5.2) |
| Which alts have item X? | Storage ItemIndex / Gather | Already strong in Items |
| Which alts need / are on quest X? | `OneWoW_CatDB_QuestDBCurrent_API` | **Already answered today** — see note below |
| Who still needs Great Vault slots? | Endgame vault | Visual + coaching |
| Who is below N of currency Y / crest cap? | Endgame currencies | Remaining-to-cap |
| Who has profession CD / concentration ready? | Professions store | |
| Who has mail / AH ending soon? | Storage mail + Auctions | |
| Who holds duplicates of X? | Storage FindDuplicates | Items mode today |

**Quest ownership is already solved elsewhere — do not rebuild it.**
`OneWoW_CatDB_QuestDBCurrent_API.GetCompletedCharacters(questID)` and
`GetActiveCharacters(questID)` are public today, and Catalog's Quests tab already renders
per-character completion. `CompletionTracker` keeps its own `db.completion[charKey]`, seeded
from `GetAllCompletedQuestIDs()` on login and updated on every turn-in, falling back to the
AltTracker snapshot only for characters it has never seen. Ask should **consume that `_API`**
(and deep-link to Catalog), not grow a second quest-completion store. This also settles
open decision #9.

**Roles-powered asks** (see §6) — examples:

- Which **Banker** has sellable / AH-fodder items I should list?
- Which **Crafter** still needs this week’s treatise / has concentration?
- Which **Main** still has vault slots / isn’t raid locked?
- Gold on **Bankers** only; ignore parked alts
- Items of quality ≥ Rare on role `Banker` with `#novendor` / auctionable predicates

Implementation lean: SearchExpand / PredicateEngine + scope `{ mode, chars, roles }` via
`OneWoW.AltScope` (same shape QoL tooltips already use).

Presets / chips: “Vault incomplete”, “Lockout free”, “Mails expiring”, “Fully rested”,
“Role: Banker + sellable”, “Crests short of cap”.

Results: list of alts (and/or items) → click opens dossier (scrolled to section) or a
focused matrix slice.

### 4.5 Ops / Compare — matrices that stay

Do **not** abandon matrices. Promote the best ones:

| View | Orientation | Inspiration |
|---|---|---|
| Weekly ops board | Characters as **columns** (or dual toggle) | AltManager, Kronon, Frudi |
| Progress M+ / Raids / Currencies | Character rows *or* dungeon/boss rows × alts | AlterEgo transpose, Altoholic Grids |
| Lockouts | Who’s free / saved | Existing Lockouts + denser raid difficulty grid |
| Equipment compare | Character rows, fewer columns + expand | Slim vs today’s ~20 cols |
| Craft army (phase later) | Role `Crafter` × treatise/quest/concentration | CraftingArmyManager |
| Dataset grids (phase later) | Thing × alts (rep, quest, achievement) | Altoholic `RegisterGrid` |

**Vault visual language:** pips / R·M·W cells, unclaimed highlight, “N more to unlock”,
crest `(+# to cap)` — Progress should feel like a **todo board**, not only a ledger.

**Stale / reset hygiene:** period IDs, grey “old week”, preserve unclaimed vault across
reset, honest “last scanned” where it matters.

### 4.6 Economy & Setup

Keep as sibling account tools — do not bury inside alt cards:

- **Auctions** — listing × character (entity-centric)
- **Financials** — ledger + dashboard metrics
- **Action Bars** — backup/restore product
- **Settings** — DB manager, purge, progress overrides; pointer to core **Roles & Alts**

---

## 5. Architecture (suite fit)

### 5.1 Load unit

```
OneWoW_AltTracker2/          # gitignored until graduation (this doc lives in OneWoW/Docs/)
  OneWoW_AltTracker2.toc
  OneWoW_AltTracker2.lua     # hub module register (MODULE_KEY, DISPLAY_NAME)
  Core/
    Constants.lua            # ADDON naming table (§3)
    ...
  UI/
    Home.lua                 # roster cards/rows
    Ask.lua
    Dossier.lua              # one-alt detail shell + sections
    Ops/                     # matrix views
    Economy/                 # thin rehosts or shared panels
    ...
```

- `RequiredDeps: OneWoW` (and store deps as needed via Manifest / EnsureLoaded).
- Register hub module with `tabOrder` near legacy AltTracker (exact order TBD).
- Prefer **shared Framework helpers** extracted from legacy UI only when both need them;
  avoid copy-paste forever — discuss before extracting shared surface (Fix Quality rule).

### 5.2 Data — reuse, don’t fork

| Store | Use for |
|---|---|
| `OneWoW_AltTracker_Character` | Identity, gear, playtime, location, action bars |
| `OneWoW_AltTracker_Storage` | Bags/bank/warband/guild/mail; ItemIndex; Gather |
| `OneWoW_AltTracker_Endgame` | M+, raids/lockouts, vault, currencies, weeklies |
| `OneWoW_AltTracker_Professions` | Skills, recipes, concentration, tools, CDs |
| `OneWoW_AltTracker_Accounting` | Gold transactions / Financials |
| `OneWoW_AltTracker_Auctions` | AH listings / bids |
| `OneWoW_AltTracker_Collections` | Quests active/completed, mounts/pets/achievements/reps |

Cross-unit rules: `_API` only; `RegisterDataReadyWatcher` for sticky UI; ephemeral tooltips
nil-guard at call time. No foreign SV bypass.

**Endgame lockouts still need a public read surface.** Endgame exposes only
`GetCharacterData(charKey)`; there is no `GetLockouts` / `IsSavedTo`. Consumers currently
walk `charData.raids.lockouts` themselves. Legacy Progress now counts raid kills from those
stored lockouts plus the Adventure Guide **inside** Endgame's Raids module (`C_RaidLocks`
for the live char, blob walk for snapshots) — that is not a public `_API` and does not
replace this work. Both Trackers (lockout skip for `enter_instance` / `kill_creature`) and
AT2 Ops want the store surface. Trackers' shipped `kill_encounter` answers live lockout
for the logged-in character only (`C_RaidLocks.IsEncounterComplete`). **Decided:** add a
raw read (`GetLockouts(charKey)`) with a predicate on top (`IsSavedTo(charKey, instanceID,
difficultyID)`), so the difficulty-matching rules — including shared legacy 10/25 pairing —
and the “last seen” freshness stamp live in the store rather than in every consumer.
`OneWoW_CatDB_QuestDBCurrent`' `CompletionTracker` is the precedent to follow. Sequenced in
[`ROADMAP.md`](ROADMAP.md).

### 5.3 Shared suite services

- `OneWoW_GUI` — theme, cards/panels/tables, filter bars, split panels
- `OneWoW.AltScope` — roles + scope inclusion (`IsCharIncluded`, `GetRolesSorted`, …)
- `OneWoW.SearchExpand` / `PredicateEngine` — Ask + Items/Bank search
- `OneWoW.Restriction` — any bank-pull / secure actions
- `OneWoW.Location` — player map, waypoint, hearth (legacy Summary already consumes it)
- QoL tooltip ItemIndex consumer — ambient “where is this item”
- Catalog — quest browsing **and cross-alt quest completion**
  (`OneWoW_CatDB_QuestDBCurrent_API`); Ask consumes and deep-links rather than duplicating
- `OneWoW.Collectibles` — live collection state; Notes owns want records (assignment
  via AltScope). AT2 does **not** grow a collections journal.
- `OneWoW_Trackers` — farm plans; AT2 supplies lockout / quest-snapshot `_API` reads
  for “who still has loot up,” not the route UI. WeeklyRewards-style char×column
  matrices and MidnightRoutine’s warband board are **Ops / Ask**, not Trackers.
  Trackers may show a thin “N alts still need X” strip that click-throughs here
  ([`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md) §15).

Collectibles daily-lock and “which alts still have Rare X up” are **Ask
presets** over quest-completion reads + Endgame lockouts
([`COLLECTIBLES_IDEAS.md`](COLLECTIBLES_IDEAS.md) §2 / §6).
  Trackers evaluates the logged-in character first
  ([`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md) §3).

**Data now, UI later.** When another leg defers something “to AltTracker2,” check which half
it means. The per-alt *data* (lockouts, quest completion, currencies, professions) is
readable through companion `_API` today and is **not** blocked by AT2. Only the roster-shaped
*rendering* — Ask, Ops matrices, the account rollup board — waits for this unit.

### 5.4 Component strategy

| Need | Prefer |
|---|---|
| Home roster | Dense rows or compact cards (`CreateCard` / custom row); not mega DataTable |
| Dossier | Split or sectioned scroll; Catalog-like list/detail where recipes need it |
| Ops matrices | `CreateDataTable` and/or new char-column board widget (discuss before new shared API) |
| Ask | Filter bar + result list/table; preset chips |
| Inventory | Dim non-matches; reuse Inventory / Bank patterns |

Any **new shared `OneWoW_GUI` primitive** (e.g. character-column matrix, attention-row) is
an expansive fix — **discuss before implementing** in shared GUI.

---

## 6. Roles & Alts integration

Core already owns roles on `OneWoW_DB.global.roles` via `OneWoW.AltScope`
(`OneWoW/Services/AltScope.lua`). Settings UI: hub **Settings → Roles & Alts**.

**Role shape:** `roles[id] = { id, name, members = { [charKey] = true } }`  
**Scope shape:** `{ mode = "all"|"selected", chars = {...}, roles = {...} }`  
A character is included in `selected` mode if listed **or** member of any selected role.
Characters may belong to many roles (Banker + Crafter + Main).

### 6.1 Use in AltTracker2

| Surface | Role usage |
|---|---|
| Home | Filter roster by role; badge role names on rows (optional, low noise) |
| Ask | Scope every query: All / Selected chars / Selected roles |
| Ops | Filter matrix columns/rows to a role (“Crafters only”) |
| Economy | Financials/Auctions scoped to Bankers |
| Dossier | Show roles on header; quick “Ask within this role” |

Do **not** fork a second role system. Point settings at existing Roles & Alts (same pattern
as legacy AltTracker settings pointer).

### 6.2 Role-flavored Ask examples

Assuming player-defined roles such as `Banker`, `Crafter`, `Main`, `PvP`, `Parked`:

- Which **Banker** has sellable / auctionable items (PredicateEngine auctionable / quality /
  `#novendor` style predicates)?
- Which **Banker** holds the most free bag space / warband-deposit candidates?
- Which **Crafter** needs treatises / has concentration full / knows recipe R?
- Which **Main** has vault incomplete or is lockout-free for tonight’s raid?
- Total gold on **Bankers** vs all alts
- Mails expiring on **Mains** only
- Crests remaining-to-cap on **Mains**
- Duplicates of reagent X on non-Crafter roles (cleanup)

Roles turn Ask from “scan 40 alts” into “scan the alts that matter for this job.”

---

## 7. Competitive takeaways (short)

### Borrow early

1. List → detail + attention-only icons (AltVault, Home cards; Home’s collector row
   now also has optional Mail / Settings / Portals tiles)
2. Dual matrix orientations + vault coaching (AlterEgo / Kronon / Altism / Frudi)
3. Smart Ask presets (Altoholic Misc filters)
4. Dim-on-search for grids; actionable empty states; weekly self-expiry
5. Favorites partition; pin current character
6. Role/group scoping (suite Roles > Altoholic Alt Groups)

### Borrow later

- Craft army ops (CraftingArmyManager)
- Agenda / expiry warning engine (Altoholic)
- Vendor/AH recipe color coding; mail autocomplete; currency tooltip overlay
- Dataset grids: reputations, achievements, quest completion
- Expansion facet on Items (ItemEra)
- Chat-link reconstructed dungeon score / keystone (AlterEgo)

### Do not chase

- Altoholic garrison/covenant/archaeology dead weight
- AltsLedger as a Financials model (it’s a tiny roster, despite the name)
- Fixed Blizzard-skinned window
- Tooltip item locations as a new AltTracker feature (already QoL + ItemIndex)

---

## 8. Priority & phases

AltTracker2's **internal** sequencing. Cross-leg ordering — and which of these phases another
leg is waiting on — lives in [`ROADMAP.md`](ROADMAP.md).

Priorities: **P0** must land for a usable AltTracker2 tab; **P1** makes it competitive;
**P2** differentiates; **P3** polish / suite-ambient.

### Phase 0 — Scaffold (P0)

- [ ] Load unit + TOC + `Constants` naming table
- [ ] Hub module register (`MODULE_KEY`, `DISPLAY_NAME`, tabOrder)
- [ ] Empty Home / Ask / Ops / Economy / Setup shells (or Home + placeholder)
- [ ] Wire `_API` reads for character list (sorted, favorites, current pin)
- [ ] Document store deps in Manifest / FirstRun as required for BringUp

### Phase 1 — Home + Dossier MVP (P0)

- [ ] Dense alt rows/cards with core fields (class, level, iLvl, realm, gold optional)
- [ ] Favorites + current-character pin + basic sort/filter
- [ ] Click → Dossier shell with Status + Gear (paperdoll or compact slots)
- [ ] Storage section for selected alt (bags at minimum)
- [ ] Attention icons: mail, vault ready (minimal set)
- [ ] Role filter on Home via `AltScope`

**Exit criteria:** Player can browse alts and inspect one without opening legacy AltTracker
for those jobs.

### Phase 2 — Ask v1 + Roles (P0/P1)

- [ ] Ask box + result list (item location via ItemIndex)
- [ ] Scope control: All / chars / **roles** (shared scope widget if possible)
- [ ] Presets: lockout-free, vault incomplete, has item (search), mails waiting
- [ ] Role ask: **Banker + sellable/auctionable items** (flagship example)
- [ ] Result → open Dossier or highlight alt on Home

**Exit criteria:** “Which Banker has AH fodder?” and “Who has item X?” work end-to-end.

### Phase 3 — Ops / Progress matrices (P1)

- [ ] Rehome Progress energy: Weekly + Vault coaching (pips / remaining)
- [ ] Lockouts matrix (who’s free) with optional char-column mode
- [ ] M+ / Raids compare (start character-row; add transpose or char-column if needed)
- [ ] Currencies with remaining-to-cap where caps exist
- [ ] Stale-week / unclaimed vault hygiene

**Exit criteria:** Weekly ops players prefer Ops over legacy Progress for “what’s left.”

### Phase 4 — Economy + Setup parity (P1)

- [ ] Auctions + Financials reachable (reuse/adapt legacy panels or thin wrappers)
- [ ] Action Bars entry from Setup / Dossier
- [ ] Settings: DB manager pointer, Roles & Alts pointer, AT2-specific toggles
  (attention icon set, hide gold, default Home sort)

### Phase 5 — Dossier depth (P1/P2)

- [ ] Professions + recipe detail panel
- [ ] To-do section (weeklies, lockouts, vault) on dossier
- [ ] Mail detail; bank / warband / guild for selected alt
- [ ] Dim-on-search in storage grids
- [ ] Actionable empty states everywhere

### Phase 6 — Ask v2 + coaching (P2)

- [ ] Quest ownership asks — consume `OneWoW_CatDB_QuestDBCurrent_API`, deep-link to Catalog
- [ ] Crest sources / “what’s left” coaching copy
- [ ] Profession CD / concentration presets
- [ ] Saved Ask presets (user-defined)
- [ ] Smart filters: fully rested, AH ending soon, duplicates by role

### Phase 7 — Differentiators (P2/P3)

- [ ] Craft-army matrix for role `Crafter` (treatise/quest/concentration)
- [ ] Dataset-major grids: reputations / achievements / weeklies (generic registry)
- [ ] Agenda-lite: aggregated expiries (mail, lockout, profession CD) + optional nags
- [ ] Ambient: vendor recipe tint, currency tooltip alts, mail autocomplete (may live in
      QoL/core — discuss ownership)
- [ ] Expansion facet on Items/Ask
- [ ] Affix schedule / key announce (seasonal; optional)

### Phase 8 — Cutover (P3)

- [ ] Feature parity checklist vs legacy AltTracker (accept intentional drops)
- [ ] Flip `DISPLAY_NAME` → AltTracker; migrate hub key / folder as planned
- [ ] Remove or soft-deprecate legacy `OneWoW_AltTracker` UI module
- [ ] Player docs / wiki / changelog; search paths; slash aliases
- [ ] Remove `OneWoW_AltTracker2/` from `.gitignore` when graduating to the real tree
      (or rename path and track as `OneWoW_AltTracker`)
- [ ] Decide whether this doc stays in `OneWoW/Docs/` or moves beside the graduated unit

---

## 9. Open decisions

Record answers here as they land:

1. **Home visual:** compact rows (AltVault density) vs Home-style larger cards vs both
   (width breakpoint)?
2. **Ops default orientation:** character rows (legacy) vs character columns (ops) vs
   toggle?
3. **Economy placement:** top-level vs under More…?
4. **Shared GUI primitives:** new matrix/attention-row in `OneWoW_GUI` vs local AT2 widgets
   until proven?
5. **Legacy coexistence:** how long both tabs stay; shared slash `/1wat` behavior?
   Suite slash prefix is now `/1w` (legacy is `/1wat`). AT2 should not invent a
   non-`/1w` alias.
6. **Season content packs:** keep overrides in data files; never bake season columns into
   chrome.
7. **Attention score:** exact badge set and sort weight for Home?
8. **Banker sellable definition:** PredicateEngine expression? quality threshold? exclude
   soulbound / reagents / junk?
9. ~~**Quest Ask ownership:** AltTracker2 vs Catalog cross-link?~~ **Answered:** Catalog owns
   it. `OneWoW_CatDB_QuestDBCurrent_API.GetCompletedCharacters` / `GetActiveCharacters` are
   public and the Quests tab already renders per-character completion. Ask consumes and
   deep-links (§4.4).
10. **Craft army:** in Ops vs Professions dossier vs deferred entirely?

---

## 10. Risks

| Risk | Mitigation |
|---|---|
| Scope balloon to “full Altoholic” | Phases + non-goals; grids only with registry pattern |
| Dossier-only UX kills comparison | Ops surface mandatory by Phase 3 |
| Dual UI maintenance burden | AT2 reads stores only; legacy feature-frozen; extract shared UI late |
| New shared GUI without discussion | Stop-and-discuss per Fix Quality |
| Rename day breakage | Naming constant from day one; checklist in Phase 8 |
| Role asks without good role hygiene | Deep-link Roles & Alts; empty-state “create a Banker role” |
| Season hardcoding in UI | Data packs / overrides; UI consumes lists |
| Other legs blocked waiting on AT2 | Split data vs UI deferrals (§5.3); ship store `_API` early |

---

## 11. Success metrics (qualitative)

- Opening AltTracker2 for “check one alt” feels as light as Home cards.
- Opening Ask answers a real question in one screen (esp. role-scoped).
- Weekly ops does not require decoding a 20-column table.
- No need to keep legacy AltTracker enabled for day-to-day (cutover ready).
- Suite stays coherent: same theme, Roles, search syntax, Restriction, tooltips.

---

## 12. Reference map

### Internal

- Legacy UI tabs: `OneWoW_AltTracker/UI/t-*.lua`
- Roles API: `OneWoW/Services/AltScope.lua`
- Roles UI: `OneWoW/UI/t-rolesandalts.lua`
- Item index: `OneWoW_AltTracker_Storage/Modules/ItemIndex.lua`
- Duplicates: `OneWoW_AltTracker_Storage_API.FindDuplicates` (Query layer, not ItemIndex)
- Cross-alt quest completion: `OneWoW_CatDB_QuestDBCurrent` CompletionTracker
- QoL tooltip consumer: `OneWoW_QoL/Tooltips/tp-itemtracker.lua`
- Home cards pattern: `OneWoW/UI/t-home.lua`
- Architecture: `OneWoW/Docs/ARCHITECTURE.md`
- Cross-leg roadmap: [`ROADMAP.md`](ROADMAP.md)
- Collectibles direction: [`COLLECTIBLES_IDEAS.md`](COLLECTIBLES_IDEAS.md)
- Trackers direction: [`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md)

### Offline competitive set

`_OneWoW_Offline/Alts/` — AltVault, Altoholic, AlterEgo, AltManager, AltismManager,
FrudiTrack, KrononAlts, WeeklyAltTracker, CraftingArmyManager, ItemEra, AlterCurrencies,
LockoutsManyAltsHandleIT, SimpleAltTracker, XBuildAlts, ZohTracker, AltsLedger.

---

## 13. Changelog discipline

Player-felt AT2 UI is changelog material when it ships in a tracked load unit. While
gitignored / prototype-only, keep notes here; on graduation follow `OneWoW-Changelog.mdc`
and `onewow-changelog` skill. Wiki updates when player docs should describe the new IA
(`onewow-wiki`).
