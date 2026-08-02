# Collectibles — Ideas & Direction (scratch)

> **Status:** design notes, **not committed scope**. This is a parking lot for the
> "what serious collectors expect" direction so it does not pollute the shipped
> [`COLLECTIBLES.md`](COLLECTIBLES.md). Promote items into that doc as they land.
>
> **See also:** [`COLLECTIBLES.md`](COLLECTIBLES.md) (shipped design),
> [`ARCHITECTURE.md`](ARCHITECTURE.md) §6/§7 (core services + LOD/cross-unit model).

## The through-line

Everything today is oriented around **deterministic, purchasable acquisition**
("saw it at a vendor, here's the cost, here's why you can't buy it yet"). That is
the easy half of collecting. The hard half — **farmed / gated / planned**
acquisition and **tracking your own progress toward it** — is where the gaps are.
The unifying asset is still the collectible **key**; every idea below hangs off it.

A recurring pattern in the reuse analysis: **the live game data and the
per-character stores already exist in the suite** (AltTracker, AltScope, Merchant,
GUI copy dialogs). What is genuinely missing is (a) a couple of small **curated
data maps**, (b) a **temporal-availability service**, and (c) **Notes-side record
fields + UI** (assignment, priority, dashboard). We are assembling, not inventing.

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
| Vendor scan funnel + encyclopedia | `OneWoW.Merchant`, `OneWoW_CatalogData_Vendors_API` | core service / CatalogData unit |
| Live per-offer affordability | `OneWoW.Collectibles.GetOfferAffordability(offer)` | `OneWoW/Services/Collectibles.lua` |
| Ensemble/set progress rollup | `GetEnsembleProgress` / `GetSetMembers` | same service |
| Punch-list voidcache → content itemIDs | `Collectibles.GetPunchListSummary` + curated map | `OneWoW/Services/CollectiblesPunchLists.lua` (QoL Collections tooltip footer) |

**Genuinely new work:** curated data maps (achievement→reward, collectible→
daily-lock-quest, **punch-list cache→content itemIDs**), a temporal-availability
service, and Notes record fields + UI (assignment, priority, dashboard, Wowhead
builder).

---

## 1. Farm / attempt plans → `OneWoW_Trackers`

A `farming`-intent collectible should spawn a **Trackers** plan ("go to Vendor A,
spend 1000g" / "farm mob X"), not grow a farm engine inside Notes. Trackers is
already the "executable plans keyed by these strings" unit. **Deferred** — Trackers
needs its own pass first (tracked separately). Notes just needs to hand off the key.

## 2. Daily loot-locks (Midnight per-char mount locks)

Not spawn timers (that is Rare Scanner / Silver Dragon territory) — **once-per-day
loot eligibility**: killing the same rare twice in a day yields no special loot.

- **Mechanism (reuse):** Blizzard gates these with **hidden "tracking quests"**
  that flag complete on loot and reset daily. Query
  `C_QuestLog.IsQuestFlaggedCompleted(hiddenQuestID)` — already wrapped by
  `…Collections_API.IsQuestCompleted`. No combat-log parsing.
- **Per-alt (reuse w/ caveat):** each alt's completed-quest set is stored
  (`GetCharacterData(charKey).quests.completed`). **Caveat:** the existing
  `IsQuestCompleted` is *live, current-character only*; other alts answer from a
  **last-seen snapshot** (accurate as of that alt's last data collection). Document
  the freshness limit; add a small "is quest X in alt Y's stored completed set"
  helper.
- **Build:** a curated **collectible-key → hidden-quest-ID** map (datamined, small,
  updatable; degrade gracefully when a key has no mapping). Same maintenance shape
  as the drop-rate data we deliberately do **not** own.
- **Payoff:** "which of my alts still have their daily loot up on Rare X" — a
  surface no mainstream addon presents well, and it feeds the alt view (#6).

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
  ones destroys trust.
- **Build — achievement → collectible-reward map (curated data):** `rewardText` is
  a *display string*, not a key. To say "…and it grants a mount you're missing" we
  need a curated **achievementID → collectible-key** table. Worth it — it is the
  best motivator — but budget it as data, not a derivation. Keep it focused
  (only achievements whose reward is a mount/pet/toy/appearance ≈ a few hundred
  rows), and **mine** it (ATT reward data, Wowhead achievement pages) rather than
  depending on a heavy live lib.
- **UX — the reverse view is stronger:** not just "this collectible comes from
  achievement X (7/8)," but "near-complete achievements, sorted by whether they
  hand you a wanted collectible." Slots into the Progress sub-tab (#4).

## 4. Progress dashboard (Collections / Progress sub-tabs)

Split the tab: **Collections** (current list) + **Progress** (KPIs). All live,
derivable from journals + the ensemble rollup we already call.

- KPIs collectors actually stare at: account-wide % per type; **nearest-to-
  completion sets** (just sort the existing ensemble rollup — highest-value item,
  turns "someday" into "2 more"); want-list size + burn-down; "collected this
  week/session"; rarest owned. Per-expansion/source breakdown is the stretch goal.

## 5. Priority buckets + budget rollup

- **Build:** numeric `priority` on the Notes record (user content), mapped to
  High/Med/Low labels; drives sort **and** the budget rollup.
- **Reuse:** `GetOfferAffordability` per offer → aggregate across the want list:
  "Want:High needs 40k + 2,000 Tender." This quietly solves the "come back when I
  can afford it" problem — a High-priority, currency-blocked, at-a-vendor item is
  exactly that reminder.

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

## 7. Requirement modeling (rep / renown / currency), per-alt

Vendor `blockReason` is a *sighting snapshot* of the current char's unmet lines.
Broader: the char that saw it may not qualify, but **another alt might**.

- **Reuse:** `GetFactionStanding(factionID)` (rep/renown) and per-alt currencies
  already collected; `C_CurrencyInfo.GetCurrencyInfo().isAccountWide` /
  `isAccountTransferable` tells us **which currencies need per-alt accounting**
  (don't hardcode a list).
- **Build:** a first-class requirement model on the record + a resolver that
  answers "which of my alts can obtain this," reusing the currency/rep stores.

## 8. Temporal-availability service (generalize lockouts)

A single service answering **"when can I next act on this key"** — lockouts,
resets, spawns, windows.

- **Reuse:** AltTracker_Endgame lockouts (raid/world-boss/weekly).
- **Build — and keep the fault line explicit:**
  - **Deterministic (API-truth):** raid/dungeon lockouts, daily/weekly resets
    (`C_DateAndTime`), Trading Post monthly reset, currency-cap resets, holiday
    event windows (calendar). Answer "next available at T" exactly.
  - **Stochastic (estimate only):** rare respawns — the game only knows *current*
    state (`C_VignetteInfo`), never future spawns. Return a **kind/confidence
    flag** so deterministic answers stay exact and spawns read "alive now / last
    seen Xh ago." Conflating them makes the service look like it lied.
- Ties to #2 (daily-lock is the deterministic per-char case) and the Trading Post
  as a first-class modern collectible faucet.

## 9. Wowhead links (per-type builder)

- **Reuse:** `OneWoW_GUI:ShowCopyURLDialog(title, url)` — click-to-copy is right
  since chat can't carry external hyperlinks. Show the URL in a tooltip first.
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

## 10. Punch-list / voidcache contents (curated map)

Blizzard “Contains one of the following items:” tooltips (`PUNCH_LIST_ITEM_CACHE_TOOLTIP`)
list content as **name-only** lines — no itemIDs, no NestedBlock. There is no
FrameXML / C_* API to enumerate punch-list contents (validated against `.wow_docs`
and wow-ui-source).

- **Build:** curated **cache itemID → content itemIDs** (armor/weapons only;
  rings/necks/trinkets are not transmog-collectible and stay off the map).
  Locale-safe match via `C_Item.GetItemNameByID` against stripped tooltip lines.
- **Ship:** `OneWoW.Collectibles.GetPunchListSummary` + QoL Collections tooltip
  footer (“Not Collected:” or “All items collected from …” under the OneWoW
  block). First entry: Nebulous Voidcache: Prey (`269768`).
- **Out of scope:** ATT-scale loot encyclopedia — keep the map narrow and
  extend one cache at a time.

---

## Out of scope (integrate, don't build)

- **3D model / dressing-room preview** — ATT / Wowhead / wardrobe territory.
- **Owning a drop-rate database** — consume a source if needed; own the *tracking*
  (attempts/locks), not the numbers.
- **Rare spawn scanning** — Rare Scanner / Silver Dragon already do this well.

## Open questions

- Achievement→reward + collectible→daily-lock-quest maps: mine from ATT/Wowhead, or
  is there a currently-maintained lib worth a dependency? (Prefer a small vendored,
  mineable table over a heavy live dependency.)
- Confirm which alt-multiselect component is the shared one (AltScopeSection vs. the
  gear-overlay picker) and consolidate on it.
- Per-alt daily-lock freshness: is a "last seen" snapshot acceptable UX, or do we
  want a login-time refresh nudge?
