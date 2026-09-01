# Collectibles — Ideas & Direction (scratch)

> **Status:** design notes, **not committed scope**. This is a parking lot for the
> "what serious collectors expect" direction so it does not pollute the shipped
> [`COLLECTIBLES.md`](COLLECTIBLES.md). Promote items into that doc as they land.
>
> **Cross-leg sequencing lives in [`ROADMAP.md`](ROADMAP.md)** — what to build next across all
> three legs, shared prerequisites, and the decisions log. This file owns collectibles-specific
> direction only.
>
> **See also:**
> - [`COLLECTIBLES.md`](COLLECTIBLES.md) (shipped design)
> - [`ROADMAP.md`](ROADMAP.md) (cross-leg sequencing)
> - [`ARCHITECTURE.md`](ARCHITECTURE.md) §6/§7 (core services + LOD/cross-unit model)
> - [`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md) (executable plans)
> - [`ALTTRACKER2_IDEAS.md`](ALTTRACKER2_IDEAS.md) (roster Ask / lockouts)

## The through-line

Everything today is oriented around **deterministic, purchasable acquisition**
("saw it at a vendor, here's the cost, here's why you can't buy it yet"). That is
the easy half of collecting. The hard half — **farmed / gated / planned**
acquisition and **tracking your own progress toward it** — is where the gaps are.
The unifying asset is still the collectible **key**; every idea below hangs off it.

**Three legs** (do not collapse them): Notes + `OneWoW.Collectibles` own identity
and the want list; Trackers owns executable plans; AltTracker(2) owns per-alt
snapshots and Ask. Competitive collecting addons mostly answer *different*
questions (instance log, weekly remaining, current-expansion cockpit, AH missing
scan). Steal framing; do not grow a second catalog.

A recurring pattern: **the live game data and the per-character stores already
exist** (AltTracker, AltScope, Merchant, Trackers step types, GUI copy dialogs).
What is genuinely missing is (a) a couple of small **curated data maps**, (b) a
**temporal-availability** answer (service or shared helper), (c) **Notes-side
record fields + UI**, and (d) a **Notes → Trackers handoff**. We are assembling,
not inventing.

---

## Reuse inventory (what already exists in the suite)

| Need | Already exists — reuse | Location |
| --- | --- | --- |
| Achievement info + **criteria** (x/y, completed, rewardText) | `OneWoW_AltTracker_Collections_API.GetAchievementInfo(id)` | `OneWoW_AltTracker_Collections/Modules/Achievements.lua`, `Core/API.lua` |
| Quest completion (incl. **hidden tracking quests**) | `…Collections_API.IsQuestCompleted(id)` (live, current char) + stored `GetCharacterData(charKey).quests.completed` array | `OneWoW_AltTracker_Collections/Modules/Quests.lua` |
| Reputation / faction standing | `…Collections_API.GetFactionStanding(factionID)` | same unit, `Modules/Reputations` |
| Per-alt **currencies** (+ account-wide flags) | Endgame Currencies module; `C_CurrencyInfo.GetCurrencyInfo().isAccountWide` / `isAccountTransferable` | `OneWoW_AltTracker_Endgame/Modules/Currencies.lua` |
| **Lockouts** (raid/world-boss/weekly) | AltTracker_Endgame lockouts | `OneWoW_AltTracker_Endgame/…`, `OneWoW_AltTracker/UI/t-lockouts.lua` |
| **Alt identity** token | `charKey` = `"name-realm"` | `OneWoW_AltTracker_Character_API.GetAllCharacters()` / `GetCurrentCharacterKey()` |
| **Assignment primitive** (mode/chars/roles + membership test) | `OneWoW.AltScope` — `IsCharIncluded(charKey, scope)`, roles | `OneWoW/Services/AltScope.lua` |
| **Alt multiselect UI** (all / selected + Add Alt + roles) | `ns.UI.BuildAltScopeSection(parent, opts)` | `OneWoW_QoL/UI/AltScopeSection.lua` |
| **Click-to-copy** dialog(s) | `OneWoW_GUI:ShowCopyURLDialog(title, url)` / `ShowCopyLinksDialog(...)` | `OneWoW/GUI/Panels.lua` |
| Vendor scan funnel + encyclopedia | `OneWoW.Merchant`, `OneWoW_CatDB_NPCDB_API` | core service / CatDB unit |
| Live per-offer affordability | `OneWoW.Collectibles.GetOfferAffordability(offer)` | `OneWoW/Services/Collectibles.lua` |
| Ensemble/set progress rollup | `GetEnsembleProgress` / `GetSetMembers` | same service |
| Punch-list voidcache → content itemIDs | `Collectibles.GetPunchListSummary` + curated map | `OneWoW/Services/CollectiblesPunchLists.lua` (QoL Collections tooltip footer) |
| Executable farm steps (quest, rare lock, kill, dungeon/raid boss, pin, calendar gate, collection state) | Trackers engine + `rare_quest` / `quest_account` / `kill_encounter` / mount·pet·toy·transmog via Collectibles keys | `OneWoW_Trackers` — see [`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md). `kill_encounter` is shipped (live `C_RaidLocks` for the logged-in char); skip/dim of other instance types is still P-3 |

**Genuinely new work:** curated data maps (achievement→reward, collectible→
daily-lock-quest, collectible→instance/encounter — **not** punch-lists, those
shipped), a temporal-availability helper, Notes record fields + UI (assignment,
priority, dashboard, Wowhead builder, Easy Wins sort), and the Notes→Trackers
handoff.

---

## 1. Farm / attempt plans → `OneWoW_Trackers`

A `farming`-intent collectible should spawn or focus a **Trackers** plan ("go to
Vendor A, spend 1000g" / "farm mob X"), not grow a farm engine inside Notes.
Trackers already ships lists, auto-complete, pins, `rare_quest`, `kill_encounter`, and collection
steps keyed through `OneWoW.Collectibles`.

**This doc owns:** when to hand off (intent / explicit action) and that the plan
is identified by the collectible key. **Trackers owns:** `_API`, skip/prune,
difficulty action, calendar fail-open — [`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md).
Encounter completion (`kill_encounter`) already ships on the Trackers side.

The payload of a good plan is a Collectionist-style **taskList** (live-evaluable
gates + waypoints), mapped onto existing Trackers step types, not prose in the
note body.

## 2. Daily loot-locks (Midnight per-char mount locks)

Not spawn timers (that is Rare Scanner / Silver Dragon territory) — **once-per-day
loot eligibility**: killing the same rare twice in a day yields no special loot.

- **Mechanism (reuse):** Blizzard gates these with **hidden "tracking quests"**
  that flag complete on loot and reset daily. Query
  `C_QuestLog.IsQuestFlaggedCompleted(hiddenQuestID)` — already wrapped by
  `…Collections_API.IsQuestCompleted`. Trackers already has `rare_quest` for the
  same flag. No combat-log parsing.
- **Per-alt (already shipped — consume it):**
  `OneWoW_CatDB_QuestDBCurrent_API.GetCompletedCharacters(questID)` answers this today, and
  Catalog's Quests tab already renders it. `CompletionTracker` keeps its own
  `db.completion[charKey]`, seeded from `GetAllCompletedQuestIDs()` on login and updated on
  every turn-in, falling back to the AltTracker snapshot only for characters it has never
  seen. **Do not** add a second helper or a second quest-completion store; the "is quest X in
  alt Y's completed set" work is done. The roster Ask *presentation* ("which alts still have
  loot up?") is AltTracker2, but the answer is available now.
- **Build:** a curated **collectible-key → hidden-quest-ID** map (datamined, small,
  updatable; degrade gracefully when a key has no mapping). Same maintenance shape
  as the drop-rate data we deliberately do **not** own.
- **UX (FuocoNote):** "tried this week" is **lockout + quest flag**, not a custom
  attempt ledger. Multi-rare farms are a **set** of weekly quests — the row is
  done when every NPC's quest is flagged. Surface this on a wanted key ("still
  lootable today / this reset") rather than only as a Trackers checkbox.
- **Payoff:** "which of my alts still have their daily loot up on Rare X" — a
  surface no mainstream addon presents well, and it feeds the alt view (#6).
- **Live rare pop:** Trackers can subscribe to RareScanner / SilverDragon *alerts*
  (not scan) and show this lock + missing keys on an ephemeral pin — see
  [`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md) §9. Same
  quest map; no second kill database. Uncollected loot **not** on the want list
  uses the vendor capture pattern (`off` / `prompt` / `auto`, **separate** setting,
  prompt default, combat-deferred) rather than silently treating every rare as a shop.

## 3. Non-vendor acquisition sources + achievements

`acquisition.achievements` is declared in the record shape but **never populated or
read** — dead placeholder today. Vendors are one path; most collectibles drop, are
quested, or come from achievements/events.

- **Reuse:** `…Collections_API.GetAchievementInfo(id)` already returns full
  criteria (`quantity`/`reqQuantity`/`completed`) and `rewardText`.
- **Build — "Almost Complete Achievements" roll-in:** a **scanner** for
  near-complete achievements (the API gives per-achievement info; iterating +
  thresholding + a completed-vs-total rollup is new). **Filter out** Statistics,
  Feats of Strength, and unobtainable/legacy — surfacing "1 away!" on impossible
  ones destroys trust. Pair with the unobtainable overlay (#4).
- **Build — achievement → collectible-reward map (curated data):** `rewardText` is
  a *display string*, not a key. To say "…and it grants a mount you're missing" we
  need a curated **achievementID → collectible-key** table. Worth it — it is the
  best motivator — but budget it as data, not a derivation. Keep it focused
  (only achievements whose reward is a mount/pet/toy/appearance ≈ a few hundred
  rows), and **mine** it (warehouse Sources, Wowhead achievement pages) rather than
  depending on a heavy live lib.
- **Shape check:** SecretCollectorCheck is this map in miniature (Mind-Seeker →
  17 mounts / 8 pets / 2 toys + coords + a 1–4 difficulty). Collectionist
  duplicates the same `taskList` on the achievement row *and* the reward mount —
  that cross-link is the UX we want, not a second achievement browser.
- **UX — the reverse view is stronger:** not just "this collectible comes from
  achievement X (7/8)," but "near-complete achievements, sorted by whether they
  hand you a wanted collectible." Slots into the Progress sub-tab (#4).

## 4. Progress dashboard (Collections / Progress sub-tabs)

Split the tab: **Collections** (current list) + **Progress** (KPIs). All live,
derivable from journals + the ensemble rollup we already call.

- KPIs collectors actually stare at: account-wide % per type; **nearest-to-
  completion sets** (just sort the existing ensemble rollup — highest-value item,
  turns "someday" into "2 more"); want-list size + burn-down; "collected this
  week/session"; rarest owned. Per-expansion/source breakdown is the stretch goal
  (current-expansion *filter* is the cheap version — §11).
- **Session honesty (Collection Log):** a login baseline so journal sync does not
  look like "you just collected 40 mounts." Celebrate real new collects with
  group `X/Y` when we have a containing set/log.
- **Unobtainable overlay:** curated retired / seasonal / promotion / unused
  (Collection Log `RetiredMounts` shape). Hide unobtainable in Progress and
  "almost complete," but **still show if owned**. Same trust rule as filtering
  Feats of Strength.

## 5. Priority buckets + budget rollup + Easy Wins

- **Build:** numeric `priority` on the Notes record (user content), mapped to
  High/Med/Low labels; drives sort **and** the budget rollup.
- **Reuse:** `GetOfferAffordability` per offer → aggregate across the want list:
  "Want:High needs 40k + 2,000 Tender." This quietly solves the "come back when I
  can afford it" problem — a High-priority, currency-blocked, at-a-vendor item is
  exactly that reminder.
- **Easy Wins (WarbandCollector, but from real offers):** sort/filter the want
  list by vendor-offer + currently affordable. We already capture `vendorOffers`
  and live affordability — do **not** parse journal `sourceText` for the word
  "vendor." Collectionator's "cheapest of group" is the same idea with gold
  instead of effort; useful as a sort key, not an AH tab.

Ignore lists (BountyHelper) matter less here: we do not dump the universe of
missing collectibles, so "I don't want this" is not adding it (or `delete`).

## 6. Alt assignment (replace Account/Character scope)

Drop the copied-from-template `storage` = account/character axis for collectibles
(collection is Warband-wide for most types anyway). Replace with **assignment**:
show all collectibles always; assign an entry to one **or many** alts.

- **Reuse the assignment primitive:** `OneWoW.AltScope` already models
  `{ mode, chars, roles }` and answers `IsCharIncluded(currentCharKey, scope)`.
  Store the assignment as such a scope; "is this for me" is one existing call.
- **Reuse the UI:** `ns.UI.BuildAltScopeSection` (QoL overlays) is the
  all/selected + Add-Alt-multiselect + roles control — the checkbox alt picker.
  (Confirm vs. the gear-overlay variant; prefer whichever is the shared one.)
- **Reuse identity:** assignment tokens are `charKey` (`name-realm`) from
  `OneWoW_AltTracker_Character_API` — same key AltScope, lockouts, and #2/#6 use.
- **Build — per-viewer sort + filter:** assigned-to-me floats **top**, assigned-to-
  another sinks **bottom** (still visible), unassigned in the middle; plus a "hide
  entries not for me" filter. Nothing persisted differs per viewer — pure sort key.
- **Auto-suggest (nice-to-have):** a profession-gated recipe can pre-suggest the
  alt AltTracker already knows has that profession.
- Assignment is "who does the acquiring," so it becomes moot on collection — lines
  up with the existing auto-recycle flow.
- **Not peer sharing:** Collectionist Roster (guild/BNet bitmaps of missing items)
  is a different social layer. Cross-account sharing is a declared AltTracker2 non-goal.

## 7. Requirement modeling (rep / renown / currency), per-alt

Vendor `blockReason` is a *sighting snapshot* of the current char's unmet lines.
Broader: the char that saw it may not qualify, but **another alt might**.

- **Reuse:** `GetFactionStanding(factionID)` (rep/renown) and per-alt currencies
  already collected; `C_CurrencyInfo.GetCurrencyInfo().isAccountWide` /
  `isAccountTransferable` tells us **which currencies need per-alt accounting**
  (don't hardcode a list). Collectionist hardcodes `cost` / `renown` on curated
  rows — we generalize the live capture instead of a second cost encyclopedia.
- **Build:** a first-class requirement model on the record + a resolver that
  answers "which of my alts can obtain this," reusing the currency/rep stores. The resolver
  is a **store-layer** question and does not wait for AltTracker2; AT2 Ask is only the
  roster-shaped *presentation* of it.

## 8. Temporal-availability service (generalize lockouts)

A single helper answering **"when can I next act on this key"** — lockouts,
resets, windows. Trackers and Notes both want this; put the fault line in one
place (core sibling vs Collectibles vs Trackers-local — open question on the
Trackers doc).

- **Reuse:** AltTracker_Endgame lockouts (raid/world-boss/weekly); Trackers
  `eventRequired` (calendar `eventID`); `rare_quest` / Collections quest flags.
- **Build — and keep the fault line explicit:**
  - **Deterministic (API-truth):** raid/dungeon lockouts (incl. shared legacy
    10/25 diffs), daily/weekly resets (`C_DateAndTime`), Trading Post monthly
    reset, currency-cap resets, holiday / timewalking windows (calendar). Answer
    "next available at T" exactly. **Fail-open** if the calendar has not loaded
    (`GetNumDayEvents == 0`) — do not hide event farms as if they were inactive.
  - **Stochastic (estimate only):** rare respawns — the game only knows *current*
    state (`C_VignetteInfo`), never future spawns. Return a **kind/confidence
    flag** so deterministic answers stay exact and spawns read "alive now / last
    seen Xh ago." Conflating them makes the service look like it lied.
- Ties to #2 (daily-lock is the deterministic per-char case) and the Trading Post
  as a first-class modern collectible faucet. Trackers consumes this for skip/
  prune ([`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md) §3–§4)
  and can own a monthly Perks checklist after one Post open
  ([`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md) §16).

## 9. Wowhead links (per-type builder)

- **Reuse:** `OneWoW_GUI:ShowCopyURLDialog(title, url)` — click-to-copy is right
  since chat can't carry external hyperlinks. Show the URL in a tooltip first.
  Catalog journal rows already have a Wowhead text link; collectibles still need
  the per-type builder. Collectionist / BountyHelper confirm the copy-dialog UX.
- **Build — `OneWoW.Collectibles.BuildWowheadURL(key)`** (core, sibling to
  `BuildLink`; pure derivation from the key → reusable by any consumer). The scheme
  is **per-type, not universally `item=`** — dispatch off the descriptor like
  `ResolveDisplay`:

  | type | Wowhead path | id we already hold |
  | --- | --- | --- |
  | toy / heirloom / recipe | `item=<itemID>` | the key's id *is* the itemID |
  | appearance:source | `item=<itemID>` | `C_TransmogCollection.GetSourceItemID(sourceID)` |
  | mount | `spell=<spellID>` | `spellID` from `ResolveMount` (**not** the mountID) |
  | set | `transmog-set=<setID>` | ⚠️ verify game setID == Wowhead page id |
  | pet | battle-pet page | ⚠️ verify speciesID == Wowhead page id |
  | decor | — | ⚠️ housing new; Wowhead pages may not exist |

- **Universal fallback:** for set/pet/decor and anything captured at a vendor we
  already hold a granting **itemID** (`vendorOffers[].itemID`, `sourceItemID` for
  ensembles). Contract: *type-specific link → else granting itemID → else nil*.
  `item=<itemID>` always resolves.
- **Localize the host, not the path:** base `wowhead.com` as a constant/locale key;
  pick the subdomain from `GetLocale()` (`de.`, `fr.`, `es.`, `it.`, `pt.`, `ru.`,
  `ko.`). zhCN/zhTW are hosted separately — verify before mapping; fall back to base.

---

## 10. Punch-list / container contents (content groups)

Blizzard “Contains one of the following items:” tooltips (`PUNCH_LIST_ITEM_CACHE_TOOLTIP`)
list content as **name-only** lines — no itemIDs, no NestedBlock. There is no
FrameXML / C_* API to enumerate punch-list contents (validated against `.wow_docs`
and wow-ui-source). Some chests have no punch-list at all but share the same
known loot pool.

- **Build:** shared **content groups** (e.g. Preyseeker) + `CACHE_ENTRIES`
  (`group` + `mode`: `punchList` vs `direct`). Armor/weapons only; class-filter
  via `OneWoW.GearProficiency.ClassAllowsItem` (named proficiency flags; see
  [GEAR_PROFICIENCY.md](GEAR_PROFICIENCY.md)). Not `PlayerCanCollectSource` or
  `DoesItemContainSpec`.
- **Ship:** `GetPunchListSummary` + QoL Collections footer (quality-colored
  missing names). Voidcache Prey (`269768`, punchList); Voidcache Delver's Trove
  (`268969`, punchList); Preyseeker chests (`257023` / `257026` / `262346`,
  direct); Bulging Ethereal / Winter packs (`278026` / `278027`, direct).
- **Out of scope:** loot-spec filtering; per-chest content subsets.

Nobody in the competitive set does container contents. This stays ours.

---

## 11. Product decisions (not silent scope)

Keepers from the collecting-addon pass that need an explicit yes — they are
**views over keys**, not a second want list.

**Instance-first remaining loot** (Collection Log / ICH / BountyHelper): "I am
about to run X — what collectibles still drop on this difficulty, and is the
boss dead this reset?" That wants a thin curated **key → { instanceID,
encounterID, difficultyIDs }** (Collection Log `MountDropCategories` shape), not
their raid-pack encyclopedia. **Activity UI is Catalog Journal** (`OneWoW_Catalog`
+ `OneWoW_CatDB_ZoneDB_API`, membership/difficulties from Generated Lua
Generated Lua). Journal extras now include world, holiday, and NPC drops
and already carry `itemID` + `instanceID` / `encounterID` / diffs — that is listing
truth, not a collectible-key map. `ResolveKeyFromItem` can bridge a row to a key
when we decide to. A Trackers in-instance strip is a *consumer* of those IDs, not a
second EJ. Trackers `kill_encounter` already answers “is this boss dead this reset”
for the logged-in character; it does not answer “what collectibles still drop here.”
Notes is not a loot log. **Decide the key→instance map before building the strip.**

**Current-expansion cockpit** (Collectionist): a Progress / want-list **filter**
("Midnight missing"), not a second addon. The maintenance cost is their curated
Midnight tables — we have so far refused that corpus. Cheap version: filter keys
we already hold by expansion when the journal gives one.

**Appearance unique vs source:** Collectionator "any source in the visual set"
vs "this source." We key `appearance:source` and already distinguish `bySource`.
A want-list filter ("I care about the look") is cheap and matches collectors.
Collection Log's "collected via other difficulty / shared appearance" tooltip is
the honesty rule.

**Coverage Blizzard omits:** ExtendedSets exists because `C_TransmogSets` hides
class sets, heritage, weapon arsenals. Our `set:<setID>` grammar assumes
Blizzard's list. Illusions (FuocoNote) have **no** key type today. Only pursue
if "sets/illusions the wardrobe does not list" is a collector expectation we
want to meet.

**Half-declared key types — decide in the same pass.** Two forms are already in the grammar
with no resolution behind them: `campsite:` is in `TYPES` but returns nil from
`ResolveDisplay` / `GetCollectionState`, and `appearance:ima:` appears in the grammar comment
with no branch either. Half-declared is worse than absent, because a caller can build a key
that silently resolves to nothing. Settle these alongside the `illusion:` in-or-out question.

---

## Suggested priority

**Ordering now lives in [`ROADMAP.md`](ROADMAP.md).** It sequences all three legs together and
names the shared prerequisites — notably that the curated key → hidden-quest map (roadmap P-1)
gates three separate ideas across two docs, and that cross-alt quest completion (P-2) already
ships, which moves #2 from "waiting on a roster UI" to "buildable now."

Collectibles-side items, for orientation: handoff (#1) · daily loot-lock (#2 + #8) · Easy Wins
(#5, Notes-only and parallelizable) · unobtainable overlay + achievement→reward map (#3–#4) ·
Wowhead builder (#9).

---

## Out of scope (integrate, don't build)

- **3D model / dressing-room preview** — AllTheThings / Wowhead / wardrobe territory.
- **Owning a drop-rate / instance-loot encyclopedia** — consume a source if needed;
  own the *tracking* (attempts/locks), not the numbers. (Collection Log packs,
  FuocoNote `droplist`, BountyHelper chances, MRP data addon.)
- **Rare spawn scanning** — RareScanner / SilverDragon already do this well.
  Trackers may *subscribe* to their alerts ([`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md) §9);
  we do not register `VIGNETTE_*` to discover rares. NPC portrait on that pin is
  a tracker header, not wardrobe 3D preview.
- **AH buy / replicate tabs** — Collectionator's scanners are the only lesson
  (live "don't have this" predicates); we are not an auction addon.
- **Rebuilding Blizzard Collections** (WarbandCollector as a product). Easy Wins
  transfers; source-text heuristics do not.
- **Guild / BNet missing-item bitmaps** (Collectionist Roster).
- **Pathfinding / travel-item routing** (MRP) — Trackers pins + skip; see Trackers ideas.

## Open questions

- Achievement→reward + collectible→daily-lock-quest (+ optional instance) maps:
  mine from warehouse Sources / Wowhead, or is there a currently-maintained lib worth a
  dependency? (Prefer a small vendored, mineable table over a heavy live
  dependency.)
- ~~Confirm which alt-multiselect component is the shared one (AltScopeSection vs. the
  gear-overlay picker).~~ **Answered:** `ns.UI.BuildAltScopeSection` is the shared one; the
  gear overlay already reuses it rather than shipping a competing picker.
- ~~Per-alt daily-lock freshness: is a "last seen" snapshot acceptable UX?~~ **Largely
  answered:** `CompletionTracker` maintains its own per-character completion map, refreshed on
  login and on every turn-in, so most alts are fresher than an AltTracker collection snapshot.
  Only never-seen characters fall back to "last seen."
- Instance-first remaining loot: Catalog Journal is the EJ UI; Trackers strip
  consumes Journal IDs; listing extras now include world/holiday/NPC drops with
  itemID + instance/encounter/diffs. Remaining work is the curated key→instance
  map (optionally via `ResolveKeyFromItem`), not which addon browses bosses.
  Trackers `kill_encounter` covers “boss dead this reset” for the logged-in char.
- Temporal helper: core service vs Collectibles vs Trackers-local (Trackers doc).
- `illusion:` key type / ExtendedSets coverage: in or out?

## Competitive set (offline)

`_OneWoW_Offline/Collecting/` — Collection Log, Collectionist, FuocoNote,
InstanceCollectionHelper, Mount Route Planner, BountyHelper, WarbandCollector,
Collectionator (missing-predicates only), SecretCollectorCheck, ExtendedSets.

Steal: remaining-attempt framing, Easy Wins from real vendor offers, taskList as
Trackers payload, unobtainable overlay, calendar fail-open, achievement↔reward
cross-link, unique-vs-source appearance filter.

Do not steal: drop encyclopedias, AH buy, peer bitmaps, journal rebuilds, spawn
scanners, MRP pathfinding.
