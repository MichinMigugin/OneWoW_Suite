# Cursor Enhancer — Situations Model

Module id: `cursorenhancer` · Folder: `Modules/external/cursorenhancer/`

Cursor Enhancer draws a cursor ring (outer/middle/marker), optional trail, GCD/cast
swipe circles, on-ring swipes, and class resource pips. **When** those pieces appear
and **how loud** they look is driven by **situation cards** inside the active
profile — not by overlapping “show OOC / only in instances / visibility” toggles.

## Mental model

```
place × combat  →  pick winning situation  →  show set + optional look overrides
                                              (+ optional mouse-look gate)
```

1. **Global look & feel** — shared geometry (size, offsets, opacity, mouse look),
   then inset look groups for Outer / Middle / Center Marker / Trail (colors and
   styles). GCD/cast/swipe/pips defaults live in their own sections below.
2. **Situations** — ordered cards. Each says: in this **place** and **combat**
   context, **show** these pieces; optionally **override** look (and mouse look).
3. Pieces not listed in the winning card’s `show` table are hidden.

Features-panel marker toggles (outer/middle/marker/trail) and the Resource Pips
“default for new situations” checkbox write **global** template defaults used when
adding a new card. Runtime visibility still comes from the winning situation’s
`show` set (including `pips` for class power on the ring). Center Marker style
**None** always suppresses the marker even when a situation has it On.

Resource pips read player class power (Soul Shards via `UnitPowerDisplayMod` for
Warlocks, Holy Power, combo points, Chi, Essence, Arcane Charges, runes). Empty
slots stay visible when pips are enabled; Destruction fragment progress tints the
next pip. Global look for pips: size, color / class color, X/Y offset from the
ring arc, and fill direction (left-to-right by default). Situation cards still
only gate show/hide.

## Place kinds

| Place | Detection |
|---|---|
| `everywhere` | Always |
| `open_world` | `not IsInInstance()` |
| `any_instance` | `IsInInstance()` |
| `dungeon` | `party` and not ChallengeMode |
| `mythic_plus` | `party` + `OneWoW.Restriction.IsTypeActive(ChallengeMode)` |
| `raid` | `raid` |
| `scenario` | `scenario` (includes Delves) |
| `arena` / `battleground` | `arena` / `pvp` |

Specificity (higher wins): everywhere `0` → open_world / any_instance `1` →
dungeon/raid/scenario/arena/battleground `2` → mythic_plus `3`.

Restriction types are read only through `OneWoW.Restriction.IsTypeActive`. State
changes arrive via `RegisterStateCallback` — never register
`ADDON_RESTRICTION_STATE_CHANGED` on a module frame (core-event-funnel).

## Combat context

`in` / `out` / `either`, matched with
`OneWoW.Restriction.IsInCombat() or UnitAffectingCombat("player")`.

## Match algorithm

Among **enabled** cards that match place and combat:

1. Highest place specificity wins.
2. Ties → **list order** (earlier / higher in the list wins). Drag with
   `OneWoW_GUI:CreateReorderDrag` to reorder.

Identical place×combat among enabled cards is a **config conflict**: danger tint +
alert. Runtime still uses list order; fix by dragging, changing place/combat, or
disabling a card.

Disabled cards stay editable (dimmed) but do not match and do not count toward
conflicts.

## Overrides

- Each piece group has a mode dropdown: **Off**, **On** (Global Look), or
  **Custom** (snapshot + editable look for this situation only).
- **Look & Feel** is two-state: **Use Global** or **Custom**. Custom overrides
  ring size, offsets, opacity, and mouse look for this situation.
- GCD / cast / swipe **presence** stays show-driven (`enabled` is set from
  `show.*` in Resolve); Custom editors only change look fields (e.g. fill,
  radius, color).
- Effective mouse look: situation Look & Feel Custom if set, else global
  `onlyWhileMouseLook`.

Situation card groups follow the same order and titles as Global Look (minus
the word “Global”): Look & Feel, Outer/Middle/Marker/Trail, Ring Swipes,
Resource Pips, Global Cooldown, Cast Bar.

## Default situations (shipped)

| # | Place | Combat | Shows | Teaching override |
|---|---|---|---|---|
| 1 | open_world | out | outer, marker | alpha 0.35 |
| 2 | open_world | in | outer, marker | alpha 1.0 |
| 3 | any_instance | out | outer, marker, gcd | alpha 0.55 |
| 4 | any_instance | in | outer, middle, marker, gcd, cast, pips | alpha 1.0 |

## Profiles & migration

Situations live on `profile.situations` inside the Cursor Enhancer profile bag
(`ModuleRegistry` module bucket → `cedata.profiles`). Copying a profile copies
situations.

On first load of a legacy profile (no `situations`), defaults are created and
legacy keys are mapped once (`visibility`, `showOutOfCombat`, `showInInstance`,
`combatAlpha` / `outOfCombatAlpha`, `onlyWhenHidden` → `onlyWhileMouseLook`).
Orphan legacy keys are left in SV but no longer read. The situations list is
**not** index-merged from defaults on later loads — deletes stick; teaching
cards are only re-seeded when the list is missing or empty.

## Files

| File | Role |
|---|---|
| `module.lua` | Metadata + Features toggles |
| `cursorenhancer-situations.lua` | Place/combat, match, resolve, defaults, migration |
| `cursorenhancer.lua` | Render engine |
| `cursorenhancer-ui.lua` | Global + situation card options |
| `Locales/*.lua` | Module strings |

## Related suite APIs

- `OneWoW.Restriction.IsTypeActive` / `RegisterStateCallback` —
  [`OneWoW/Docs/ARCHITECTURE.md`](../../../OneWoW/Docs/ARCHITECTURE.md) §8.6
- `OneWoW_GUI:CreateReorderDrag` — shared list reorder helper
