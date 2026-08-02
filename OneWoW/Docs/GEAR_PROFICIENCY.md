# GearProficiency

Single-purpose core service: **does this class’s gear proficiency include this
item?** Owned at [`Services/GearProficiency.lua`](../Services/GearProficiency.lua),
published as `OneWoW.GearProficiency`.

## One job

Answer class weapon/armor proficiency for collection and “yours to farm” UX
(plus cloak / holdable slot rules). No SavedVariables, no events, no login
preload.

| API | Role |
| --- | --- |
| `ClassAllowsItem(itemID, classToken?)` | `true` when the class may use this gear type; `classToken` nil = current player. Non-gear / unknown → `true` |
| `GetItemFlag(itemID)` | Named-flag bit for the item, or `nil` |
| `GetFlagName(flag)` | Flag → name (debug) |
| `Flags` | `FlagsUtil.MakeFlags` table (`Cloth`, `Staff`, `Cloak`, …) |

Resolution uses `C_Item.GetItemInfoInstant`: cloaks → `Cloak`, holdables →
`Holdable`, else `Enum.ItemArmorSubclass` / `Enum.ItemWeaponSubclass` maps.
Class masks are `Flags_CreateMask` / `bit.bor` over those named flags.

## Not these APIs

| API | Different job |
| --- | --- |
| `PE:CanClassEquip` / `DoesItemContainSpec` | Loot-spec eligibility (item “for” this class/spec) |
| `C_TransmogCollection.PlayerCanCollectSource` | Blizzard transmog collectability (too broad alone — e.g. shields on cloth casters) |

Upgrade overlays keep `CanClassEquip`. Container / punch-list footers use
`GearProficiency`.

## First consumer

[`CollectiblesPunchLists.lua`](../Services/CollectiblesPunchLists.lua) filters
content-group candidates with `ClassAllowsItem` before collection status.
