# Roadmap — Collectibles · Trackers · AltTracker2

> **Status:** living document. Expect it to change mid-stream as we learn; that is the point.
> This file owns **cross-leg sequencing only** — what to build next across the three legs,
> which prerequisites unblock more than one of them, and which decisions are settled.
>
> It does **not** restate what each leg owns or why. That lives in the three ideas docs,
> which are reference material and change rarely:
>
> - [`COLLECTIBLES_IDEAS.md`](COLLECTIBLES_IDEAS.md) — identity, keys, want list, daily loot-locks
> - [`TRACKERS_IDEAS.md`](../../OneWoW_Trackers/Docs/TRACKERS_IDEAS.md) — executable farm plans
> - [`ALTTRACKER2_IDEAS.md`](ALTTRACKER2_IDEAS.md) — roster / Ask / Ops (internal phases in its §8)
>
> Shipped design (not ideas): [`COLLECTIBLES.md`](COLLECTIBLES.md),
> [`ARCHITECTURE.md`](ARCHITECTURE.md), `OneWoW_Trackers/Docs/ARCHITECTURE.md`.

---

## The three legs (one line each)

| Leg | Owns |
| --- | --- |
| `OneWoW.Collectibles` + Notes | Identity (`type:id` keys), live collected?, user want/intent, vendor sightings |
| `OneWoW_Trackers` | Lists / sections / steps, auto-complete, pinned overlays, map pins |
| AltTracker → AltTracker2 | Per-alt snapshots, Ask the roster, Ops matrices |

Full boundary tables — including what each leg explicitly does **not** own — are in the
ideas docs. Do not collapse ownership to make a slice easier.

---

## Data vs UI deferrals (read this before deferring anything)

When one leg defers work "to AltTracker2," it means one of two very different things:

- **Data deferral — usually false.** Per-alt lockouts, quest completion, currencies, and
  professions are readable through companion `_API` **today**. AltTracker2 is a UI redesign
  over the same stores, so it does not gate any of this.
- **UI deferral — real.** The roster-shaped *rendering* — Ask, Ops matrices, the account
  rollup board — genuinely waits for AltTracker2.

Tag deferrals accordingly. Legacy AltTracker is feature-frozen (it is deleted at AT2
cutover), so building an interim roster UI there is throwaway work that also widens the
Phase 8 parity checklist.

---

## Shared prerequisites

The highest-leverage work, because each item unblocks more than one leg. No single ideas doc
can see these, which is why they live here.

### P-1 · Curated collectible-key → hidden-quest-ID map

**Shipped (this slice):** generated lock table on core `OneWoW.Collectibles`
(`GetRareLockByNpc` / `GetRareLockByKey` / `GetRareLocks` / `IsRareLockCompleted`).
Trackers Rare Quest can fill from your target or search by name. Midnight
zone-rares preset builds at create time from the table. Cadence (`daily` /
`weekly`) is on the mined row, not QuestV2. Completion is live current-character
`IsQuestFlaggedCompleted` — do not use CompletionTracker snapshots as loot-lock
truth (append-only).

**Still deferred:** Notes “still lootable today” on a wanted key; RareScanner /
SilverDragon subscribe (Trackers §9).

Blizzard gates once-per-day loot with hidden tracking quests. Coverage churn is
new rares and rare Midnight-beta rebuilds — regenerate the table, do not ask
players to remine. Degrade gracefully when a key has no mapping.

### P-2 · Cross-alt quest completion — already shipped, consume it

`OneWoW_CatDB_QuestDBCurrent_API.GetCompletedCharacters(questID)` and
`GetActiveCharacters(questID)` are public today, and Catalog's Quests tab already renders
per-character completion. `CompletionTracker` maintains its own `db.completion[charKey]`,
seeded from `GetAllCompletedQuestIDs()` on login and updated on every turn-in, falling back
to the AltTracker snapshot only for characters it has never seen.

**Consequence:** the headline payoff of Collectibles §2 — "which of my alts still have their
daily loot up on Rare X" — needs only P-1. Not AltTracker2, not a new helper, not a
freshness compromise. Do not build a second quest-completion store.

### P-3 · Endgame lockout read surface

**Unblocks:** Trackers §3 (lockout skip / dim), AltTracker2 Ops lockout matrix.

`OneWoW_AltTracker_Endgame` still exposes only `GetCharacterData(charKey)`; there is no
`GetLockouts` / `IsSavedTo` on the public `_API`. Consumers that need stored lockouts still
walk `charData.raids.lockouts` by hand.

That is **not** the same surface as Trackers' shipped `kill_encounter` evaluator, which
answers live lockout for the **logged-in** character via `C_RaidLocks.IsEncounterComplete`
(with redirected difficulty). Skip/dim for `enter_instance` / `kill_creature`, and AT2's
roster matrix, still need the store `_API`. Legacy Progress now counts raid kills from
stored lockouts plus the Adventure Guide **inside** Endgame's Raids module — still a blob
walk, not a public read.

**Decided:** add a raw read (`GetLockouts(charKey)`) with a predicate on top
(`IsSavedTo(charKey, instanceID, difficultyID)`). The predicate covers Trackers' skip/dim
need; the raw read covers AT2's matrix. Keeping both in the store puts the difficulty-matching
rules — including shared legacy 10/25 pairing — and the "last seen" freshness stamp in one
place instead of in every consumer. `CompletionTracker` is the precedent.

This is a shared-store surface change, so it is discuss-first under the Fix Quality rule.
It has been discussed and approved in principle; record the final shape in
`OneWoW_AltTracker_Endgame/Docs/` when it lands.

### P-4 · Step-type authorability

**Shipped.** The step editor can author every shipped track type, including nested
objectives and gates. `rare_quest` remains a quest-scope **label** on the quest card, not
its own picker row. Dusting for Moths (`quest_account` + coords + renown) is reproducible
in the UI.

Phases (0–7):

0. Shared location service — see **P-4b**
1. Engine semantics: objective roll-up, `requiresSteps` user check-off gate, faction
   visibility, latched `exploration`
2. Type field schema registry, explicit max / `noMax`, "Tracked as" fallback
3. `CreateEntityIdField` + resolver registry (quest/npc from Catalog as they load)
4. Picker parity: vault, profession, quest scopes + `questIDs`, description, step-level
   waypoint on any type
5. Gates in the editor: faction, profession, calendar event, `requiresSteps`
6. Nested objectives editor
7. Remaining picker types: loot, timer, zone, campaign, quest progress, exploration

After P-4, `kill_encounter` shipped as its own picker (fill from the current or last-ended
Adventure Guide encounter + live `C_RaidLocks`). See sequence **7b**. That does not reopen
P-4.

### P-4b · Shared location service (`OneWoW.Location`)

**Shipped.** Suite-wide map helpers (`ToFraction` / `ToPercent`, `GetPlayerMapID`,
`GetPlayerLocation`, `SetWaypoint` with `CanSetUserWaypointOnMap` and
`opts.format` / `openMap` / `superTrack`, `DistanceMapPercent`, `IsWithinRadius`). No pin
rendering (OneWay Pins and `TrackerMap` own that). Consumed by Trackers, Catalog Navigation
(waypoint half), Catalog quest scanner, Notes NPCs and OneWay Pins, Vendors, AltTracker
hearth, and QoL coords / map-world tools. See [ARCHITECTURE.md](ARCHITECTURE.md) core
service roster.

---

## Sequence

One ordered list, replacing the per-doc priority sections. Each item names its owning leg.
Items marked **parallel** have no dependency on the item above them.

| # | Work | Leg | Depends on |
| --- | --- | --- | --- |
| 0 | Hub tab GUI-first pass (§0) | Trackers | — · **shipped** |
| 0b | Calendar fail-open | Trackers | — · **shipped** |
| 1 | Easy Wins sort of the want list (§5) | Notes | — · **parallel** |
| 2 | Curated key → hidden-quest map (P-1) | Collectibles data | — · **parallel** |
| 3 | Endgame lockout `_API` (P-3) | Endgame store | — · **parallel** |
| 4 | Collectible-key handoff `_API` + "Track this" (§1) | Trackers ← Notes | 0 |
| 5 | Lockout skip / dim for `enter_instance` / `kill_creature` (§3) | Trackers | 3 |
| 6 | Daily loot-lock on a wanted key (§2 + §8) | Collectibles | 2, and 5 for the lockout half |
| 7a | Shared location service (`OneWoW.Location`) (P-4b) | Core | — · **shipped** |
| 7 | Step-type authorability (P-4) | Trackers | 0, 7a · **shipped** |
| 7b | Encounter step (`kill_encounter`) (Trackers §12) | Trackers | 7 · **shipped** |
| 8 | Unobtainable overlay + achievement→reward map (§3–§4) | Collectibles | — |
| 9 | Wowhead URL builder (§9) | Collectibles | — |
| 10 | AltTracker2 Phase 0–2 (scaffold → Home/Dossier → Ask v1) | AltTracker2 | 3 for lockout asks |
| 11 | Roster Ask presets: "which alts still have loot up" | AltTracker2 | 2, 3, 10 |
| 12 | AltTracker2 Phase 3 (Ops matrices) | AltTracker2 | 10 |

With 0 shipped, items 1, 2 and 3 are the ones to start in parallel: none of them touches the
authoring tab, and each unblocks something downstream.

**Not yet** (hang off contracts we do not have): RS/SD rare subscribe, Trading Post
checklist, detach-section, account rollup, chore-preset refresh, in-instance remaining
strip. Encounter steps shipped as `kill_encounter` (7b); Catalog Journal "pick a row, emit
a step" and skip/dim of other instance types are still ideas (Trackers §12 remaining / §3).

---

## Decisions log

Settled items, so they stop reappearing as open questions.

| Decision | Outcome |
| --- | --- |
| Quest Ask ownership — AT2 vs Catalog | **Catalog.** Store and UI both already live there; other legs consume `OneWoW_CatDB_QuestDBCurrent_API` and deep-link. |
| Endgame lockout access | **Raw read + predicate on the store** (P-3), not per-consumer blob walks. |
| Roster deferrals | **Split data vs UI.** Data is available now; only rendering waits for AT2. |
| Interim roster UI in legacy AltTracker | **No.** Legacy is feature-frozen and deleted at cutover. |
| Notes → Trackers handoff trigger | **Explicit "Track this"** for v1, not auto-spawn on `farming` intent. |
| Calendar gating | **Fail-open until `CALENDAR_UPDATE_EVENT_LIST`**, fail-closed after. Shipped. |
| Rare capture setting | **Separate SV key** from vendor capture, same `off`/`prompt`/`auto` vocabulary. |
| AltTracker2 design doc location | **`OneWoW/Docs/`** while the load unit is gitignored, so the design is tracked and reachable. |

---

## Open questions that cross legs

Single-leg questions stay in that leg's ideas doc. These need more than one leg to answer.

- **Rare-alert setting composition.** Trackers §9 defines pin mode (`off`/`alert`/`auto-pin`,
  default off) and capture mode (`off`/`prompt`/`auto`, default prompt) but never says whether
  one gates the other. If capture is independent, installing SilverDragon produces StaticPopups
  the player never opted into — the exact vendor-auto failure that section argues against.
  Recommended: gate capture on pin mode being non-`off`, and say so.
- **Temporal-availability helper** (Collectibles §8): core service, part of
  `OneWoW.Collectibles`, or Trackers-local? Both Notes and Trackers want the answer, so the
  fault line needs deciding before either builds a local version.
- **Instance → collectible map** (Collectibles §11, Trackers §7): needed before the
  in-instance remaining strip. Listing/IDs come from Catalog Journal; the curated key map is a
  Collectibles product decision.
- **Half-declared key types.** `campsite:` is in the `TYPES` grammar with no resolution branch,
  and `appearance:ima:` appears in the grammar comment with no branch either. Collectibles §11
  asks whether `illusion:` is in or out — decide all three in the same pass, since
  half-declared is worse than absent.
- **One list per collectible key vs one "Collectibles" list with a section per key** (Trackers
  §1). Affects what the handoff `_API` returns.

---

## Corrections applied from the 2026-08 review

Recorded so the same claims do not get re-derived from the older text:

- `rare_quest` is a **literal alias** of `quest` — identical evaluator, identical
  `IsQuestFlaggedCompleted` call, no distinct reset semantics. It is a display name, not a
  daily-lock capability. The capability still needs P-1 plus a daily-reset list.
- `requiresSteps` exists and evaluates. It **dims** a hub row and **blocks user check-off**
  (`TD:CanCompleteStep` on hub + pin). It does not hide the step or feed `IsStepVisible`.
  The step editor has a sibling picker. Markup still does not parse it.
- `hideCompleted` and `pinnedHideCompleted` are **not a pair**. `pinnedHideCompleted` is a
  persisted per-list field honored by the pin and hub detail; the hub-side "Hide completed" is
  a session filter over the left rail that hides fully complete *lists*.
- Cross-alt quest completion **ships** (P-2). Two docs described it as missing.

### Bugs found during the review — fixed

- **`custom_timer` interval reset.** `Core/Resets.lua` read `sp.lastComplete` while every
  writer sets `sp.lastCompleted`, so the read was always nil, `now - 0 >= interval` was always
  true, and a completed timer step cleared on the next reconcile. Reachable by players today
  through list import. Fixed by reading the field the writers actually set. Trackers §11
  (interval world events) can now build on this type.
- **Dead distance helpers.** `TM:GetDistanceToStep` *and* `TM:GetDistanceToCoordinate`
  (`TrackerMap.lua`) both had zero callers, and the former was a nil-guarded wrapper around the
  latter. Removed rather than left as speculative surface. `Evaluators/Location.lua` already
  owns the shipped "am I near this point" math for the `coordinates` type; when §6 prune or §11
  POI pins need distance, add the helper the consumer actually wants — `git log` has these two
  if the old shape turns out to be right.

### Corrections applied 2026-08-29 (week away)

- **Encounter steps shipped** as `kill_encounter` (sequence 7b). Live `C_RaidLocks` for the
  logged-in character is **not** P-3. P-3 remains the Endgame store `_API`.
- **P-3 is still unshipped.** `GetLockouts` / `IsSavedTo` do not exist. Legacy Progress now
  counts raid kills from stored lockouts plus the Adventure Guide inside Endgame Raids —
  still an in-module blob walk.
- **Location consumers grew.** OneWay Pins, Catalog quest scanner, QoL coords / map-world
  tools also call `OneWoW.Location`. Pin rendering stays out of the service.
- Sequence "Not yet" no longer lists encounter steps. Next parallel work is still 1, 2, 3.
