# Search & Expression Syntax

> **See also:** [Docs index](README.md) · [Categorization](CATEGORIZATION.md) (how rules assign categories) · [Import/export](IMPORT_EXPORT.md) (translating foreign dialects) · [Architecture](ARCHITECTURE.md) (search filter pipeline)

OneWoW Bags uses a single expression engine for the search bar, custom category
rules, and (in the future) vendor sell rules. Everything described here works in
all three contexts.

The engine itself is published by `OneWoW` as `OneWoW.PredicateEngine`.
The canonical set of **built-in** `#` keywords, property names, and verbose
`Is…` flags is defined in
[`OneWoW/Services/PredicateEngine.lua`](../../OneWoW/Services/PredicateEngine.lua) (use
`OneWoW.PredicateEngine:GetAllKeywords()` at runtime to list every keyword
currently registered, including any added via `RegisterKeyword` from other
addons). For the public API, caches, and extension points, see
[`OneWoW/Docs/PREDICATE_ENGINE.md`](../../OneWoW/Docs/PREDICATE_ENGINE.md).

> **Keywords are English-only.** All `#...` keywords (e.g. `#armor`, `#epic`,
> `#soulbound`) are canonical English tokens regardless of the client locale.
> If you paste rules from another addon that uses localized keywords, run them
> through `Import from...` so they are translated to the canonical form. See
> [`IMPORT_EXPORT.md`](IMPORT_EXPORT.md) for details.

## Contents

- [Quick Start](#quick-start)
- [Saved Search Shortcuts](#saved-search-shortcuts)
- [Category Search Shortcuts](#category-search-shortcuts)
- [Text Search](#text-search)
- [Keywords](#keywords)
- [Operators](#operators)
- [Property Comparisons](#property-comparisons)
- [Shorthand for Item Level](#shorthand-for-item-level)
- [Boolean Flags (Verbose Syntax)](#boolean-flags-verbose-syntax)
- [Named Constants](#named-constants)
- [PredicateEngine.lua (file map)](#predicateenginelua-file-map)
- [Combining Everything](#combining-everything)
- [Item overlays (Overlays 2.0)](#item-overlays-overlays-20)

---

## Quick Start

| You type | What it finds |
|---|---|
| `sword` | Items with "sword" in the name |
| `#weapon` | All weapons |
| `#epic` | All epic-quality items |
| `#armor & #epic` | Epic armor |
| `#food or #potion` | Food or potions |
| `ilvl>=600` | Items at item level 600 or above |
| `>600` | Same thing (shorthand) |
| `200-300` | Items with item level between 200 and 300 |
| `#haste & ilvl>=600` | Items with haste at ilvl 600+ |
| `haste>=200` | Items with 200+ haste rating |
| `vendorprice>100g` | Items that sell for more than 100 gold |
| `>50s` | Same thing, for any price above 50 silver (shorthand) |
| `#knowledge` | Profession knowledge study items |
| `SAVED(Collected Toys)` | Expands a user-saved search shortcut before evaluation |
| `CATEGORY(My Decks)` | Expands a custom search-category's rule before evaluation |

---

## Saved Search Shortcuts

Named expressions use `SAVED(Name)` anywhere the suite evaluates a user search
expression (Bags search bar, custom category rules, Mail shipments, overlays,
AltTracker search, etc.). Manage them in **OneWoW Settings → Search Shortcuts**;
Bags keeps a Save button on the search bar and a Settings breadcrumb that opens
the hub tab.

Syntax:

```text
SAVED(Name)
```

Example:

```text
SAVED(Collected Toys)
```

If `Collected Toys` is saved as `#toy & #collected`, the expression above is
expanded by `OneWoW.SearchExpand` to that predicate string before
`OneWoW.PredicateEngine` compiles or evaluates it. Nested saved searches are
supported with a small recursion limit.

Saved search name rules:

- Names may contain letters, numbers, spaces, hyphen (`-`), underscore (`_`),
  and plus (`+`).
- Lookup is case-insensitive, but the saved display casing is preserved.
- Missing, invalid, or cyclic references fail closed by expanding to a
  never-match predicate instead of matching everything.

Stored in core SavedVariables as `saved`-kind entries in
`OneWoW_DB.global.searchCatalog`. User tokens (`#decks` → `#combinable`) are
`token`-kind entries in the same catalog; PredicateEngine resolves an unknown
`#token` through a callback on first use rather than being handed a map on
login, so a token body may be any expression, not just one built-in keyword.
Renaming either kind keeps the old name working: the catalog retains former
names and resolves them to the same entry, so no stored expression is rewritten.

---

## Category Search Shortcuts

Custom categories that use a **search** rule can be referenced by display name
anywhere suite SearchExpand runs (Bags, Mail, QoL, …). Bags contributes its
categories to `OneWoW.SearchCatalog` as the `category` kind through a registered
provider, so resolution is live and the records stay in Bags SavedVariables.
`OneWoW_Bags_API.GetCategorySearchExpression` reads through the same catalog.
With Bags unloaded the kind is empty and every `CATEGORY(...)` fails closed.

Syntax:

```text
CATEGORY(Name)
```

Example:

```text
CATEGORY(My Decks)
```

If the custom category `My Decks` has search expression `#combinable`, the
token expands to `(#combinable)` before PredicateEngine compiles it.
`!CATEGORY(My Decks)` therefore negates that rule.

**Semantics:** `CATEGORY(Name)` matches items that satisfy that category's
**search expression**. It does **not** mean “this item would be assigned to
that category in the bag layout” — assignment still considers priority, pins,
overlays, and first-winner order among overlapping rules.

Eligibility:

- **Custom** categories only (not builtins like Toys / Recent Items).
- Only when the category's filter mode is **search** with a non-empty
  `searchExpression`.
- Type-mode, pin-only, and builtin categories fail closed (never match).

Name rules:

- Uses the category's **display name** as the user typed it (any language /
  characters the category manager accepts). Lookup is case-insensitive;
  display casing is preserved on rename rewrites.
- Missing, ineligible, or cyclic references fail closed.
- Nested `CATEGORY(...)` and `SAVED(...)` are expanded together with a shared
  recursion limit.
- When Bags is not loaded yet, `CATEGORY` fails closed until Bags registers
  the resolver.

---

## Text Search

Any bare word that isn't a keyword, operator, property, or flag is treated as a
**name substring match** (case-insensitive).

| Example | Matches |
|---|---|
| `sword` | "Greatsword of the Firelands", "Sword of Justice", etc. |
| `brittle` | Any item with "brittle" in its name |

You can also use the explicit name property with the contains operator:

| Example | Matches |
|---|---|
| `name~sword` | Same as bare `sword` |
| `name~"two words"` | Name contains the phrase `two words` |
| `~"two words"` | Shorthand for `name~"two words"` |
| `name=Hearthstone` | Exact name match (case-insensitive) |
| `name!=Hearthstone` | Everything except items named "Hearthstone" |

Multiple terms must be joined with an explicit operator. There is no implicit
AND between adjacent tokens, so write `#armor & #epic`, not `#armor #epic`.

Bare numbers such as `623` or `>600` are **item level** shorthands (see
[Shorthand for Item Level](#shorthand-for-item-level)), not item IDs. Use
`id=6948` or `itemid=6948` to match by item ID.

---

## Keywords

Keywords start with `#` and test a specific item property or category.
All keywords are case-insensitive.

### Quality

These keywords match **Blizzard item quality** only.

| Keyword | Aliases |
|---|---|
| `#poor` | `#grey`, `#gray` |
| `#common` | `#white` |
| `#uncommon` | `#green` |
| `#rare` | `#blue` |
| `#epic` | `#purple` |
| `#legendary` | `#orange` |
| `#artifact` | |
| `#heirloom` | |

### Junk and trash

| Keyword | Aliases | What it matches |
|---|---|---|
| `#junk` | `#trash` | The same flag as property `isjunk` and the **1W Junk** category: Poor-quality items **or** items marked junk by OneWoW **ItemStatus** (when loaded). |

> **Behavior change:** `#junk` and `#trash` used to be aliases of `#poor` (gray quality only). For **gray quality only**, use `#poor`, `#grey`, or `#gray`.

### Item Type

| Keyword | Aliases | What it matches |
|---|---|---|
| `#weapon` | | All weapons |
| `#armor` | | All armor |
| `#consumable` | | Consumables (excludes mis-tagged profession recipes reclassified as `#recipe` via `ItemIDOverrides`) |
| `#container` | `#bag` | Bags and containers |
| `#gem` | | Gems |
| `#reagent` | | Reagents |
| `#tradegoods` | `#tradegood` | Trade goods |
| `#enhancement` | `#itemenhancement` | Item enhancements (enchants, etc.) |
| `#recipe` | | Recipes |
| `#tradeskill` | `#profession` | Profession items |
| `#key` | | Keys |
| `#miscellaneous` | `#misc` | Miscellaneous items |
| `#glyph` | | Glyphs |
| `#housing` | | Housing items |
| `#quest` | `#questitem` | Quest items |
| `#projectile` | | Projectiles |
| `#quiver` | | Quivers |
| `#wowtoken` | | WoW Tokens |

### Glyph (class) Subtype

These match the **Glyph** item class with a **class-specific** subclass (as in
`PredicateEngine.lua`). They are finer-grained than `#glyph` alone.

| Keyword | Class |
|---|---|
| `#warriorglyph` | Warrior |
| `#paladinglyph` | Paladin |
| `#hunterglyph` | Hunter |
| `#rogueglyph` | Rogue |
| `#priestglyph` | Priest |
| `#deathknightglyph` | Death Knight |
| `#shamanglyph` | Shaman |
| `#mageglyph` | Mage |
| `#warlockglyph` | Warlock |
| `#monkglyph` | Monk |
| `#druidglyph` | Druid |
| `#demonhunterglyph` | Demon Hunter |

### Consumable Subtypes

| Keyword | What it matches |
|---|---|
| `#potion` | Potions, elixirs, and flasks |
| `#food` | Food and drink (alias: `#drink`) |
| `#flask` | Flasks and phials |
| `#elixir` | Elixirs |
| `#bandage` | Bandages |
| `#scroll` | Scrolls |
| `#vantusrune` | Vantus Runes |
| `#utilitycurio` | Utility Curios |
| `#combatcurio` | Combat Curios |
| `#curio` | All curios (utility + combat) |
| `#explosive` | Explosives and generic consumables |
| `#knowledge` | Profession knowledge study items (items whose Use spell uses the shared knowledge-study spell icons) |

> **`#knowledge`:** Matching is based on the spell tied to the item (via
> `C_Item.GetItemSpell` and that spell’s icon), not on scanning tooltip text.
> Items without an item spell never match.

### Equipment

| Keyword | Aliases | What it matches |
|---|---|---|
| `#gear` | `#equipment`, `#equippable` | Any equippable item |
| `#set` | `#equipmentset` | Items in an equipment set |
| `#myclass` | | Items your class can use — equippable gear via spec API, or any item with a Classes: tooltip restriction that includes you |
| `#myspec` | | Equipment usable by your current spec (universal gear included; equippable only) |
| `#needsrepair` | | Current durability differs from max (requires bag/slot context; see note below) |
| `#broken` | | Zero durability (`durability==0`; requires bag/slot context) |

> **`#myclass` / `#myspec`:** Items in the **Profession** item class never match (profession tools/recipes are handled by `#myprofs` instead).

> **Durability keywords:** Values come from `C_Container.GetContainerItemDurability`
> when the item is built from a real `bagID`/`slotID`. Without that, `#needsrepair`
> and `#broken` stay false and numeric `durability` / `maxdurability` comparisons
> treat missing durability as `0`.

### Armor Subtype

| Keyword | What it matches |
|---|---|
| `#cosmetic` | Cosmetic armor (armor subclass) |
| `#cloth` | Cloth armor |
| `#leather` | Leather armor |
| `#mail` | Mail armor |
| `#plate` | Plate armor |
| `#shield` | Shields |
| `#libram` | Librams |
| `#idol` | Idols |
| `#totem` | Totems |
| `#sigil` | Sigils |
| `#relic` | Relics |

### Weapon Subtype

Individual weapon types:

| Keyword | Aliases |
|---|---|
| `#1haxe` | `#onehandaxe` |
| `#2haxe` | `#twohandaxe` |
| `#1hsword` | `#onehandsword` |
| `#2hsword` | `#twohandsword` |
| `#1hmace` | `#onehandmace` |
| `#2hmace` | `#twohandmace` |
| `#dagger` | `#daggers` |
| `#staff` | `#staves` |
| `#polearm` | |
| `#bow` | `#bows` |
| `#gun` | `#guns` |
| `#crossbow` | |
| `#warglaive` | `#glaive` |
| `#fist` | `#fistweapon` |
| `#thrown` | Thrown weapons |
| `#fishingpole` | Fishing poles |

Composite weapon keywords match both 1H and 2H variants:

| Keyword | What it matches |
|---|---|
| `#axe` | 1H and 2H axes |
| `#sword` | 1H and 2H swords |
| `#mace` | 1H and 2H maces |

Handedness keywords:

| Keyword | Aliases | What it matches |
|---|---|---|
| `#2h` | `#twohand` | 2H axes, swords, maces, polearms, staves |
| `#1h` | `#onehand` | 1H axes, swords, maces, daggers, fist weapons, warglaives |

### Equipment Slot

| Keyword | Aliases |
|---|---|
| `#head` | `#helm`, `#helmet` |
| `#neck` | `#necklace`, `#amulet` |
| `#shoulder` | `#shoulders` |
| `#chest` | (matches chest and robe) |
| `#robe` | |
| `#waist` | `#belt` |
| `#legs` | `#pants` |
| `#feet` | `#boots` |
| `#wrist` | `#bracers`, `#bracer` |
| `#hands` | `#gloves` |
| `#finger` | `#ring` |
| `#trinket` | |
| `#back` | `#cloak`, `#cape` |
| `#mainhand` | |
| `#offhand` | (off-hand weapons and holdable items) |
| `#holdable` | |
| `#ranged` | |
| `#wand` | `#wands` |
| `#tabard` | |
| `#shirt` | |

### Gem Subtype

| Keyword | Aliases |
|---|---|
| `#intgem` | `#intellectgem` |
| `#agigem` | `#agilitygem` |
| `#strgem` | `#strengthgem` |
| `#stagem` | `#staminagem` |
| `#critgem` | `#criticalgem` |
| `#masterygem` | |
| `#hastegem` | |
| `#versgem` | `#versatilitygem` |
| `#multigem` | (multi-stat gems) |
| `#artifactrelic` | Artifact relic sockets (gem subclass) |

### Housing Subtype

| Keyword | Aliases |
|---|---|
| `#decor` | |
| `#housingdecor` | `#itemdecor` | Housing-class items **or** any item `C_Item.IsDecorItem` recognizes (e.g. redeemable furniture drops). Classification only — use `#collected` / `#collectionmissing` for ownership |
| `#dye` | `#housingdye` |
| `#room` | |
| `#roomcustomization` | |
| `#exteriorcustomization` | |
| `#serviceitem` | |

Decor items (`#decor`) additionally expose four **numeric properties** (`decorstorage`, `decorplaced`, `decorredeemable`, `decortotal`) from the housing catalog; see [Numeric comparisons](#numeric-comparisons).

### Profession Reagent Subtype

These match items with the Profession item class and a specific profession subclass.

| Keyword | What it matches |
|---|---|
| `#blacksmithing` | Blacksmithing reagents |
| `#leatherworking` | Leatherworking reagents |
| `#alchemy` | Alchemy reagents |
| `#herbalism` | Herbalism reagents |
| `#cooking` | Cooking reagents |
| `#mining` | Mining reagents |
| `#tailoring` | Tailoring reagents |
| `#engineering` | Engineering reagents |
| `#enchanting` | Enchanting reagents |
| `#fishing` | Fishing reagents |
| `#skinning` | Skinning reagents |
| `#jewelcrafting` | Jewelcrafting reagents |
| `#inscription` | Inscription reagents |
| `#archaeology` | Archaeology reagents |

### Trade Goods — Crafting reagent (subtype)

These match the **Trade Goods** item class with a **crafting reagent** subclass
(`Enum.ItemTradeGoodsSubclass` values wired in the engine). They are separate
from the [Profession reagent](#profession-reagent-subtype) family above (which
uses the **Profession** item class).

| Keyword | Aliases |
|---|---|
| `#craftingreagentparts` | |
| `#craftingreagentjewelcrafting` | |
| `#craftingreagentcloth` | |
| `#craftingreagentleather` | |
| `#craftingreagentmetal` | `#craftingreagentstone` |
| `#craftingreagentcooking` | |
| `#craftingreagentherb` | |
| `#craftingreagentelemental` | |
| `#craftingreagentother` | |
| `#craftingreagentenchanting` | |
| `#craftingreagentinscription` | |
| `#craftingreagentoptional` | |
| `#craftingreagentfinishing` | |

### Character profession filter

| Keyword | Aliases | What it matches |
|---|---|---|
| `#myprofs` | `#myprofession`, `#myprofessions` | Profession-class **tools** and **recipes** whose profession matches a trade skill the current character has learned (skill line IDs from `GetProfessions` / `GetProfessionInfo`). Other item types do not match. |

The known-profession set is cached until
`OneWoW.PredicateEngine:InvalidateKnownProfessions()` runs. OneWoW Bags listens for
`SKILL_LINES_CHANGED` and calls it automatically.

### Miscellaneous Subtypes

| Keyword | What it matches |
|---|---|
| `#holiday` | Holiday items |
| `#companionpet` | Companion pet items |
| `#mountequipment` | Mount equipment |

### Reagent Subtypes

| Keyword | What it matches |
|---|---|
| `#contexttoken` | Context tokens (Reagent.ContextToken — season/upgrade tokens). Not the same as `#geartoken` |

### Recipe Subtypes

| Keyword | What it matches |
|---|---|
| `#alchemyrecipe` | Alchemy recipes |
| `#blacksmithingrecipe` | Blacksmithing recipes |
| `#cookingrecipe` | Cooking recipes |
| `#enchantingrecipe` | Enchanting recipes |
| `#engineeringrecipe` | Engineering recipes |
| `#inscriptionrecipe` | Inscription recipes |
| `#jewelcraftingrecipe` | Jewelcrafting recipes |
| `#leatherworkingrecipe` | Leatherworking recipes |
| `#tailoringrecipe` | Tailoring recipes |
| `#fishingrecipe` | Fishing recipes |
| `#firstaidrecipe` | First Aid recipes |
| `#bookrecipe` | Book recipes |

### Binding

| Keyword | Aliases | What it matches |
|---|---|---|
| `#soulbound` | `#bound`, `#bop` | Character-bound items (not account-bound) |
| `#boe` | `#bindonequip` | Bind on Equip items (not yet bound) |
| `#boa` | `#accountbound`, `#warbound` | Account/Warband-bound items |
| `#bou` | `#bindonuse` | Bind on Use items (not yet bound) |
| `#wue` | `#warbounduntilequip` | Warbound Until Equipped items |

> **Note:** Bind keywords use **tooltip-based detection** (reading the bind
> line from `C_TooltipInfo`), not the item's API `bindType` field. This means
> they reflect the item's *current* binding state as displayed in the tooltip.
> For example, an item that *was* BoE but has since been equipped will match
> `#soulbound`, not `#boe`. The separate `bindtype` numeric property (used in
> property comparisons like `bindtype=2`) still reflects the item definition's
> bind type from the API. Use `currentbind` to compare the tooltip-derived
> bind enum value numerically.

### Expansion

Each expansion has a full name keyword and one or more short aliases.
`#currentexpansion` is a meta-keyword that always matches items from the
client's current expansion (resolved from `LE_EXPANSION_LEVEL_CURRENT` at load
time). Use it in saved searches and category rules when you want them to track
the live expansion without editing the rule each patch.

| Keyword | Aliases |
|---|---|
| `#currentexpansion` | |
| `#classic` | `#vanilla` |
| `#burningcrusade` | `#tbc` |
| `#wrath` | `#wotlk`, `#northrend` |
| `#cataclysm` | `#cata` |
| `#mistsofpandaria` | `#mists`, `#mop`, `#pandaria` |
| `#draenor` | `#wod`, `#warlords` |
| `#legion` | |
| `#battleforazeroth` | `#bfa` |
| `#shadowlands` | `#sl` |
| `#dragonflight` | `#df` |
| `#warwithin` | `#tww`, `#thewarwithin` |
| `#midnight` | |
| `#lasttitan` | `#titan` |

### Item source (creation context)

These keywords classify items using the **item creation context** embedded in the
item link (`Enum.ItemCreationContext`), grouped into broad source categories.
They only apply when the engine can parse a full item link for the slot; items
without link data never match.

| Keyword | What it matches |
|---|---|
| `#raid` | Raid drops and raid-tagged sources |
| `#dungeon` | Dungeon and similar instanced PvE sources |
| `#delves` | Delve-related sources |
| `#worldquest` | World quest and open-world mission rewards |
| `#pvp` | PvP and rated rewards |
| `#store` | Shop / store sources |

> **Implementation note:** Each keyword maps a fixed set of
> `Enum.ItemCreationContext` numeric values in the engine. Blizzard may add new
> context IDs in patches; unlisted values do not match any of these keywords.

### Collectibles

Collection ownership keywords all read through `OneWoW.Collectibles.GetItemCollectionStatus`
(key resolution + live journal state). Recipe items may need bag/slot or live tooltip
context for legacy books where `GetItemByID` omits player-evaluated lines.

| Keyword | What it matches |
|---|---|
| `#toy` | Toys |
| `#mount` | Mounts |
| `#pet` | Battle pets (alias: `#battlepet`) |
| `#ensemble` | Transmog ensemble items (`set:<setID>` via Collectibles; not saved equipment sets — use `#set` / `#equipmentset` for those) |
| `#collected` | Collectibles you already own (alias: `#collectionknown`) — toys, mounts, pets, recipes, decor, ensembles, appearances |
| `#uncollected` | Collectible-shaped items you are missing on the logged-in character (alias: `#collectionmissing`); **not** true on non-collectibles |
| `#altcollected` | Recipe items known by a scoped alt but not by you (uses Recipe Knowledge alt scope; meaningful for `#recipe` only) |
| `#altuncollected` | Collectible-shaped recipes nobody in the Recipe Knowledge alt scope knows (neither you nor scoped alts) |
| `#collectionknown` | Alias of `#collected` |
| `#collectionmissing` | Alias of `#uncollected` |

**`#uncollected` behavior:** Only true on collectible-shaped items you lack. Bare
`!#collected` no longer matches random gear — combine with a type keyword when you
want “missing toys” (`#toy & #uncollected`), not “everything I don't own.”

**`#alreadyknown` vs `#collected`:** These answer different questions and are **not**
aliases.

| Keyword | Layer | Meaning |
|---|---|---|
| `#alreadyknown` | Tooltip (lazy) | Tooltip body contains Blizzard `ITEM_SPELL_KNOWN` (“Already known”). May also be set for `#recipe` items when `RecipeKnownUtil` resolves learn state but the tooltip line is absent (legacy books). |
| `#collected` | Collectibles | You own/learned this collectible per `GetItemCollectionStatus` (mount journal, toy box, recipe known, decor owned, transmog set, etc.). |

For recipe toasts and overlays, prefer `#recipe & !#collected` over
`#recipe & !#alreadyknown`. Non-collectibles can show “Already known” without
being a Collectibles key.

**Overlay presets:** `knownitems` → `#collectionknown`; `altcollected` →
`#altcollected`; `unknownitems` → `#collectionmissing and !#altcollected`.
See [Item overlays (Overlays 2.0)](#item-overlays-overlays-20).

### Battle Pet Type

These keywords are intended to pair naturally with `#pet`.

| Keyword | What it matches |
|---|---|
| `#pethumanoid` | Humanoid battle pets |
| `#petdragonkin` | Dragonkin battle pets |
| `#petflying` | Flying battle pets |
| `#petundead` | Undead battle pets |
| `#petcritter` | Critter battle pets |
| `#petmagic` | Magic battle pets |
| `#petelemental` | Elemental battle pets |
| `#petbeast` | Beast battle pets |
| `#petaquatic` | Aquatic battle pets |
| `#petmechanical` | Mechanical battle pets |
| `#wildpet` | Wild battle pets (`C_PetJournal` wild flag) |
| `#petcanbattle` | Pets that can battle |
| `#pettradeable` | Tradable pets |

**Examples:**

```
#pet & #petbeast
#pet & (#pethumanoid | #petdragonkin)
```

> **Pet quality:** There are no separate `#pet*quality*` keywords. Use the
> normal quality keywords instead, for example `#pet & #epic`.

### Transmog

| Keyword | What it matches |
|---|---|
| `#transmog` | Items with a wardrobe appearance you can collect |
| `#ensemble` | Items that teach a transmog set (`Collectibles` key `set:<setID>`) |
| `#knowntransmog` | Items whose appearance you've collected |
| `#unknowntransmog` | Items whose appearance you haven't collected |
| `#catalyst` | **TransmogUpgradeMaster:** first boolean from `IsAppearanceMissing(hyperlink)` is true |
| `#catalystupgrade` | **TransmogUpgradeMaster:** second boolean from `IsAppearanceMissing(hyperlink)` is true |

> **`#catalyst` / `#catalystupgrade`:** The keywords always exist in the engine.
> `BuildProps` sets both flags from
> [TransmogUpgradeMaster](https://www.curseforge.com/wow/addons/transmog-upgrade-master)'s
> `TransmogUpgradeMaster_API.IsAppearanceMissing` when that API is present; otherwise
> they stay false. A full item hyperlink is required for the API call—items built
> without link data never match.

### Stats

Stat keywords match items that have any amount of the given stat (value > 0).
For threshold checks, use the property comparison syntax (`haste>=200`).

**Primary:**

| Keyword | Aliases |
|---|---|
| `#intellect` | `#int` |
| `#agility` | `#agi` |
| `#strength` | `#str` |
| `#stamina` | `#stam` |

**Secondary:**

| Keyword | Aliases |
|---|---|
| `#crit` | `#criticalstrike` |
| `#haste` | |
| `#mastery` | |
| `#versatility` | `#vers` |

**Tertiary:**

| Keyword | What it matches |
|---|---|
| `#speed` | Items with the Speed tertiary stat |
| `#leech` | Items with the Leech tertiary stat |
| `#avoidance` | Items with the Avoidance tertiary stat |

### Socket Type

These keywords match items that have at least one socket of the given type.
Socket type data is resolved lazily via `C_Item.GetItemStats`.

| Keyword | What it matches |
|---|---|
| `#prismatic` | Items with a prismatic socket |
| `#metasocket` | Items with a meta socket |
| `#redsocket` | Items with a red socket |
| `#yellowsocket` | Items with a yellow socket |
| `#bluesocket` | Items with a blue socket |
| `#cogwheel` | Items with a cogwheel socket |
| `#tinkersocket` | Items with a tinker socket |
| `#dominationsocket` | Items with a domination socket |
| `#primordial` | Items with a primordial socket |

> **`#socket` vs socket type keywords:** The keyword `#socket` (in Item State
> below) matches any item with *any* socket. The socket type keywords above
> match items with a *specific* socket type.

### Item State

| Keyword | What it matches |
|---|---|
| `#usable` | Character can use the item — `IsUsableItem` in accessible bags; bank/warband fallback: combine items (Darkmoon decks, …) match when every reagent is owned; teachable collectibles match while still learnable (uncollected, or a pet below its cap); recipes and non-collectible teach items don't match; everything else needs a direct `Use:` tooltip with no red unmet requirements |
| `#combinable` | Item whose Use: effect is a combine/craft spell with required reagents (Darkmoon decks, fractured sparks, torn recipe scraps, …). Structural via `GetItemSpell` → recipe schematic — not tooltip text. Enchant scrolls (`ItemEnhancement`) and trivial single-reagent qty-1 schematics (Baleful tokens and similar Use: items) are excluded. Does **not** check whether you own the reagents |
| `#combineready` | Shorthand for `#combinable & #usable` — combine-type item and you own every required reagent (ready to combine now) |
| `#unusable` | Items the logged-in character cannot use |
| `#new` | Items Blizzard marks as new in the bag slot (`C_NewItems.IsNewItem`), via the shared PredicateEngine `BuildProps` (may lag real client state until the props cache is invalidated) |
| `#locked` | Bag slot is server-locked (`ContainerItemInfo.isLocked`) — item on cursor, in trade/mail/AH, or pending a move; **not** lockbox lockpicking state |
| `#hasloot` | Loot containers (`ContainerItemInfo.hasLoot`) — lockboxes, junk boxes, clam shells, etc.; true for locked and unlocked lockboxes; requires bag/slot context (false without it) |
| `#socket` | Items with gem sockets |
| `#equipped` | Items currently equipped |
| `#refundable` | Items still eligible for a full vendor refund (same window as the in-game refund indicator) |
| `#enchanted` | Items whose link includes a permanent enchant (enchant ID in the parsed item link) |
| `#scrappable` | Items `C_Item.CanScrapItem` reports as scrappable for the bag slot (`ItemLocation` must be valid); always false without a real bag/slot |
| `#disenchantable` | `#de` | Items that can be disenchanted. Owned by `OneWoW.Disenchant` (Molinari-style heuristic + curated allow/block lists). Bind-agnostic — combine with `!#soulbound` when mailing. Does **not** require the current character to know Disenchant. Quality caps belong in the expression (`#disenchantable & quality<=2`), not the keyword. |

> **`#usable` vs `#onuse` vs `#combinable` vs `#combineready`:** `#usable` / `#unusable` are character-eligibility (`IsUsableItem` in bags; bank fallback: combine items match when all reagents are owned, teachable collectibles while still learnable, others need a direct `Use:` tooltip — not recipes/non-collectible teach items). `#onuse` means the tooltip has a **Use:** effect — independent of whether you meet the requirements. `#combinable` means the item is a combine-type item (has a multi-reagent or multi-qty schematic); it does **not** check whether you own the reagents. Trivial single-reagent qty-1 Use: tokens are not `#combinable` and use the normal `#usable` path. `#combineready` is shorthand for `#combinable & #usable` (ready to combine). `#use` is not a registered keyword (use `#usable` or `#onuse` explicitly).

For `#knowledge`, see **Consumable Subtypes** (same predicate).

### Recent (OneWoW Bags)

| Keyword | What it matches |
|---|---|
| `#recent` | Same rule as the **Recent Items** category: item GUID is in `db.global.recentItems` and still within **Recent item duration** (bag settings). GUIDs are stamped when a coalesced bag update sees the slot as Blizzard-new (`C_NewItems.IsNewItem`); classification does **not** use cached `BuildProps.isNew`. While the main bags window is open, expired GUIDs are also swept on a short ticker. Registered from Bags' `Data/Categories.lua`, not the shared engine (the ticker and GUID map are Bags-specific). |

### Shopping List

| Keyword | Aliases | What it matches |
|---|---|---|
| `#shoppinglist` | `#shoplist` | Item is on any resolved Shopping List (`items` table). Unresolved name-only imports do not match. Registered from Shopping List at login; unknown if that unit is disabled. |
| `#shoppinglistneeded` | | On a Shopping List **and** at least one list still has owned < needed. Same registration as `#shoppinglist`. |

### Vendor / Value

| Keyword | What it matches |
|---|---|
| `#sellable` | Items with a vendor price |
| `#unsellable` | Items that cannot be sold |

### Crafting

| Keyword | What it matches |
|---|---|
| `#craftingreagent` | Crafting reagents |
| `#crafted` | Items whose item link carries a **crafter GUID** (player-crafted instances) |
| `#professionequipment` | Profession tools and accessories |

> **`craftedquality` vs `reagentquality`:** Profession tier numbers read from the
> item link (0 when the API returns nil). `craftedquality` uses
> `C_TradeSkillUI.GetItemCraftedQualityByItemInfo` — quality stars on
> **player-crafted** outputs. `reagentquality` uses
> `C_TradeSkillUI.GetItemReagentQualityByItemInfo` — tier diamonds on
> **profession reagents** (herbs, ore, leather, etc.). These are independent of
> Blizzard item `quality` (rarity) and of each other; an item may have one, both,
> or neither.
>
> **`#crafted` vs `craftedquality`:** `#crafted` follows **crafter presence in the
> link**, not the crafted-quality stars. `craftedquality` is separate from that
> keyword (see above). An item can have a non-zero `craftedquality` without
> matching `#crafted`, or match `#crafted` with `craftedquality==0`, depending on
> the item and link data. `reagentquality` is likewise independent of
> `#craftingreagent` (class/subclass keywords only describe item type, not tier).

### Upgrades

| Keyword | What it matches |
|---|---|
| `#upgrade` | Items flagged as an upgrade for your character (OneWoW upgrade-detection registers this with `PE:RegisterKeyword` at runtime; if that module is not loaded, `#upgrade` is unknown and matches nothing) |
| `#upgradeable` | Items that can be upgraded (`C_Item.GetItemUpgradeInfo`) |
| `#fullyupgraded` | Items at max upgrade level |
| `#upgradetrack` | Items on any upgrade track (Explorer through Myth); includes fully upgraded track gear. Not the same as `#upgradeable` (room left on track) or `#upgrade` (character-relative upgrade) |
| `#explorer` | Items on the Explorer upgrade track |
| `#adventurer` | Items on the Adventurer upgrade track |
| `#veteran` | Items on the Veteran upgrade track |
| `#champion` | Items on the Champion upgrade track |
| `#hero` | Items on the Hero upgrade track |
| `#myth` | Items on the Myth upgrade track |
| `#currentseason` | Items tagged for the **current PvE season** (alias: `#activeseason`). Expansion guard rejects wrong-expansion items without tooltip work. Equipment: current-season bonus IDs on the link and/or upgrade-track tooltip heuristics. All types: tooltip lines mentioning the active display season label (`EXPANSION_SEASON_NAME`, e.g. `Midnight Season 2` on tokens, or embedded in use text like socket items). Gray/outdated season lines are ignored. Not the same as `#currentexpansion` — older seasons within the same expansion do not match. Not the same as `#midnights1` / `#midnights2`, which stay pinned to Midnight Season 1 / 2. |
| `#activeseason` | Alias of `#currentseason` (Baganator/Syndicator import compatibility) |
| `#midnights1` | Midnight **Season 1** PvE track gear (bonus list IDs on the link) and items whose tooltip mentions `Midnight Season 1`, including gray leftover headers. Alias: `#midnightseason1`. Does not move when a new season starts. |
| `#midnights2` | Midnight **Season 2** PvE track gear and `Midnight Season 2` tooltip mentions (including gray headers). Alias: `#midnightseason2`. While S2 is live this overlaps `#currentseason` on track gear; it is not an alias. |

> **`#currentseason` maintenance:** update `CURRENT_SEASON_BONUS_IDS` in `PredicateEngine.lua` each season when Blizzard adds new crafted/voidforged bonus IDs. At the start of a **new expansion**, also add that expansion's first global M+ season ID to `EXPANSION_FIRST_GLOBAL_MPLUS_SEASON` (`DisplaySeason.Season` for ordinal 1; Midnight = 17). Debug tooltip/season matching in-game with `/petooltip`.
>
> **Named Midnight seasons:** list IDs are generated (`python bin/season_bonus_list_ids.py generate` from OneWoW_Workspace). Adding Midnight S3 is a new group block in that mapping plus `#midnights3`, not a change to `#midnights1` / `#midnights2`.

**Related properties:** `upgradelevel` and `upgrademax` are numeric comparisons from
`C_Item.GetItemUpgradeInfo` (current and max upgrade tier). `maxlevel` is the
maximum possible **item level** after upgrades — a different field. `#upgradetrack`,
`#upgradeable`, and `#fullyupgraded` are boolean keywords derived from the same
upgrade info (`trackStringID` present, level below max, and level at max).

### Tooltip

These keywords scan the item's tooltip text (or tooltip-derived fields filled by that scan). They may be slightly slower than other keywords on first access.

| Keyword | What it matches |
|---|---|
| `#teachable` | Tooltip has an `ItemSpellTriggerLearn` line (“Use: Teaches you …”) — recipe plans, profession books, mount/pet/toy teaching items, etc. Independent of whether you already own the taught collectible |
| `#charges` | Charge pattern in the tooltip (`ITEM_SPELL_CHARGES`–based detection) |
| `#unique` | Tooltip **Unique** / **Unique-Equipped**, **or** unique battle pets (`isPetUnique` from the journal) |
| `#onuse` | Items with a `Use:` tooltip effect |
| `#onequip` | Items with an `Equip:` tooltip effect |
| `#uniqueequipped` | Unique-equipped items |
| `#alreadyknown` | Tooltip shows Blizzard “Already known” (see [Collectibles](#collectibles) — not an alias of `#collected`) |
| `#reputation` | Items with "Reputation" in the tooltip |
| `#tradeableloot` | Loot still in the trade window |
| `#openable` | Containers you can right-click to open now (bag tooltip includes `ITEM_OPENABLE`); subset of `#hasloot` — excludes locked lockboxes and other containers you cannot open yet |

> **`#hasloot` vs `#openable` vs `#locked`:** `#hasloot` is API-based (`hasLoot` on the
> container slot). `#openable` is tooltip-based and means *openable right now* (see
> `#openable` above). `#locked` is the unrelated inventory-slot lock flag, not
> “Requires Lockpicking”. Example: `#hasloot & !#openable` finds lockboxes still
> needing lockpicking; `#hasloot & #openable` finds containers ready to loot.

### Shop / battle.net item

| Keyword | What it matches |
|---|---|
| `#battlepay` | Items flagged as Battle.net / shop purchases (`C_Container.IsBattlePayItem` for bag/slot items) |

### Special

| Keyword | What it matches |
|---|---|
| `#hearthstone` | Hearthstone and all hearthstone toy variants |
| `#keystone` | Mythic Keystones |
| `#tierset` | Items belonging to a tier set |
| `#geartoken` | Use: creates soulbound gear for your loot specialization (Baleful and similar). Curated ID set — not `#contexttoken` |
| `#currency` | Currency items (hyperlink resolves via `C_CurrencyInfo.GetCurrencyInfoFromLink`) |

---

## Operators

Operators combine keywords and conditions. Evaluated from highest to lowest
precedence:

| Operator | Meaning | Example |
|---|---|---|
| `!` or `not` | NOT (negate) | `!#junk` or `not #junk` |
| `&` or `and` | AND (both must match) | `#armor & #epic` or `#armor and #epic` |
| `\|` or `or` | OR (either can match) | `#food \| #potion` or `#food or #potion` |
| `( )` | Grouping | `#hearthstone \| (#armor & #junk)` |

In bags search bars and category rule edit boxes, type **single-character**
operators (`|`, `&`, `!`). Word aliases (`or`, `and`, `not`) work too, but are
optional alternatives — not replacements for `|` and `&`.

### Precedence

`!` binds tightest, then `&`, then `|`/`or`. Use parentheses to override.

| Expression | Evaluated as |
|---|---|
| `#armor & #epic \| #legendary` | `(#armor & #epic) \| #legendary` |
| `#armor & (#epic \| #legendary)` | Armor that is epic or legendary |
| `!#junk & #sellable` | Not-junk items that are sellable |

---

## Property Comparisons

Compare an item's numeric or string property against a value.

### Numeric Comparisons

Syntax: `property>=value`, `property<=value`, `property>value`, `property<value`,
`property=value`, `property==value`, `property!=value`

| Property | Aliases | What it is |
|---|---|---|
| `ilvl` | `itemlevel`, `level` | Item level |
| `id` | `itemid` | Item ID |
| `quality` | | Quality as a number (0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary, 6=Artifact, 7=Heirloom) |
| `count` | `stacks` | Stack size in the slot |
| `vendorprice` | `price`, `unitvalue` | Vendor sell price per unit (copper; accepts `g`/`s`/`c` notation) |
| `totalvalue` | | Vendor sell price × stack size (copper; accepts `g`/`s`/`c` notation) |
| `maxstack` | `stacksize` | Maximum stack size |
| `reqlevel` | `minlevel` | Required player level |
| `mylevel` | | Current player level (`UnitLevel("player")`); useful with property-vs-property compares (e.g. `reqlevel<=mylevel`) |
| `expansion` | `expac` | Expansion ID (0=Classic, 1=TBC, ..., 10=TWW, 11=Midnight, 12=Last Titan) |
| `class` | `typeid` | Item class ID |
| `subclass` | `subtypeid` | Item subclass ID |
| `pettype` | | Battle pet type ID (1=Humanoid, 2=Dragonkin, 3=Flying, 4=Undead, 5=Critter, 6=Magic, 7=Elemental, 8=Beast, 9=Aquatic, 10=Mechanical) |
| `petquality` | | Battle pet quality tier |
| `petlevel` | | Battle pet level |
| `petmaxhealth` | | Battle pet max health |
| `petpower` | | Battle pet power |
| `petspeed` | | Battle pet speed |
| `bindtype` | | Bind type ID from item data (0=None, 1=BoP, 2=BoE, 3=BoU, 8=Warband, 9=WUE) |
| `currentbind` | | Current tooltip bind state (from `Enum.TooltipDataItemBinding`). Reflects actual binding, not item definition. |
| `craftedquality` | | Crafted quality tier from `C_TradeSkillUI.GetItemCraftedQualityByItemInfo` (1–5, or 0 if none); player-crafted outputs; independent of `#crafted` (see Crafting keywords) |
| `reagentquality` | | Reagent quality tier from `C_TradeSkillUI.GetItemReagentQualityByItemInfo` (tier 1–N per item, or 0 if none); profession reagent diamonds; independent of `#craftingreagent` and `craftedquality` (see Crafting keywords) |
| `upgradelevel` | | Current upgrade level |
| `upgrademax` | | Maximum upgrade level |
| `maxlevel` | | Maximum possible item level after upgrades |
| `setid` | | Equipment set ID |
| `sockets` | | Number of gem sockets |
| `armor` | | Armor stat value |
| `intellect` | `int` | Intellect stat value |
| `agility` | `agi` | Agility stat value |
| `strength` | `str` | Strength stat value |
| `stamina` | `stam` | Stamina stat value |
| `crit` | | Critical Strike rating |
| `haste` | | Haste rating |
| `mastery` | | Mastery rating |
| `versatility` | `vers` | Versatility rating |
| `speed` | | Speed tertiary stat |
| `leech` | | Leech tertiary stat |
| `avoidance` | | Avoidance tertiary stat |
| `petcollected` | | Number of that battle pet species already collected |
| `petlimit` | | Max allowed copies for that species (pet journal) |
| `durability` | | Current durability (bag/slot items; otherwise treated as `0` for comparisons) |
| `maxdurability` | | Maximum durability for the slot |
| `durabilitypct` | | `current / max * 100` when the slot has durability from `C_Container.GetContainerItemDurability`; otherwise the field is unset and numeric comparisons treat it as `0` |
| `decorstorage` | | In-storage quantity for housing **decor** items (`C_HousingCatalog.GetCatalogEntryInfoByItem`, `totalNumStored`) |
| `decorplaced` | | Number of placed instances |
| `decorredeemable` | | Remaining redeemable count |
| `decortotal` | | Sum of storage, placed, and redeemable |

> **`#decor` vs `decorstorage>=1`:** The keyword `#decor` matches the Housing · Decor **item subclass**. Numeric `decor*` properties count catalog state for that item and are independent of `#decor` wording overlap.

> **Housing decor counts:** During identity-tier `PopulateBaseProps`, Housing · Decor items (`#decor`) call `C_HousingCatalog.GetCatalogEntryInfoByItem` (hyperlink or item ID). When the API returns entry info, `decorNumStorage`, `decorNumPlaced`, `decorNumRedeemable`, and `decorNumTotal` are set synchronously before `BuildProps` returns. If housing is unavailable or the item has no catalog entry, those fields stay unset and numeric comparisons treat them as `0` (same `props[field] or 0` rule as other numerics). Counts are identity-tier and refresh on `InvalidatePropsCache` (e.g. `BAG_UPDATE_DELAYED`).


> **`#armor` vs `armor>=N`:** The keyword `#armor` matches any item in the
> Armor item class. The property `armor` in a comparison like `armor>=100`
> checks the item's armor *stat value*. These are independent.

**Property-vs-property comparisons:** If the right-hand side is the **lowercased
name of another numeric property** in the table (for example `ilvl>=reqlevel`), the
engine compares the two live property values instead of parsing a numeric literal.
Other examples: `petpower>=petspeed`, `petlevel:1-25` still uses numeric bounds only
(the range syntax does not accept property names).

**Money notation (money-typed properties only):** `vendorprice` and `totalvalue`
accept values written as combinations of `g` (gold), `s` (silver), and `c`
(copper) instead of raw copper. Units may be combined and decimals are allowed.
Under the hood the literal is converted to copper at parse time — so every
operator, range, and bare shorthand works unchanged.

| You type | Means |
|---|---|
| `vendorprice>100g` | Over 100 gold per unit |
| `price>=2g50s` | At least 2 gold, 50 silver |
| `totalvalue:10g-50g` | Stack total value between 10 and 50 gold |
| `price==1.5g` | Exactly 1.5 gold (equivalent to `1g50s`) |
| `totalvalue!=0c` | Items with non-zero stack value |
| `>100g`, `<50s` | Bare shorthand — auto-routes to `vendorprice` |
| `100g` | Exact `vendorprice==100g` (bare shorthand) |
| `10s-50s` | Bare range `vendorprice:1000-5000` |

Units other than `g`/`s`/`c` are not recognised. Money notation is only parsed
on money-typed properties; `ilvl==100g` is rejected (it is not a money prop).

**Examples:**

```
ilvl>=600               Items at ilvl 600+
quality>=4              Epic or better
vendorprice>0           Items worth something to a vendor
vendorprice>=1g         Items worth at least 1 gold each
totalvalue:10g-50g      Stack value between 10g and 50g
expansion==10           The War Within items
expansion==${CURRENTEXPANSION}  Current-expansion items (updates each patch)
count>1                 Stacked items
sockets>0               Items with at least one socket
upgradelevel>0          Partially upgraded items
#upgradetrack & #gear   Items on any upgrade track
haste>=200              Items with 200+ haste rating
crit>0                  Items with any crit (same as #crit)
pettype=8               Beast battle pets
petlevel:1-10           Low-level pets
petquality>=4           Epic or better pets
reagentquality>=3       Profession reagents at tier 3+
craftedquality>=2       Player-crafted items at crafted tier 2+
ilvl>=reqlevel          Item level at or above required level (property vs property)
reqlevel<=mylevel       Items the current character meets the level requirement for
durabilitypct<100       Damaged gear (bag/slot only; see durability note above)
#decor & decorplaced>=1 Housing decor you've placed at least once (see housing-decor notes above)
```


### String Comparisons

Syntax: `property=value` (exact), `property!=value` (not equal),
`property==value` (exact), `property~value` (literal contains),
`property~~value` (Lua pattern contains)

String matching is case-insensitive. Values may be unquoted single tokens or
quoted strings when you need spaces or explicit delimiters.

`~~` uses Lua pattern syntax, not full regex syntax. `~` remains plain literal
contains and does not treat pattern characters specially.

| Property | Aliases | What it is |
|---|---|---|
| `name` | | Item name (case-insensitive) |
| `equiploc` | | Equipment location string (e.g. `INVTYPE_HEAD`) |
| `tooltip` | | Concatenated tooltip text (case-insensitive) |

**Examples:**

```
name~sword              Items with "sword" in the name
name~"two words"        Name contains the phrase "two words"
name~~"^gleaming"       Name starts with "gleaming"
name=Hearthstone        Exact name match
name=="two words"       Exact multi-word name match
name!="two words"       Exclude an exact multi-word name
equiploc=INVTYPE_HEAD   Head slot items
tooltip~"binds when picked up"
tooltip~~"classes:.+monk"
~"stone"
!(tooltip~~"classes:.+monk")
```

Use either quote style for the wrapper:

- `name=="O'Brien"`
- `tooltip~'Say "hi"'`

Backslash escaping is not supported in v1. If your text contains one quote
character, wrap the value in the other quote style.

For Lua pattern searches with `~~`, escape pattern metacharacters with `%` when
you want a literal match. For example:

- `name~"a.b"` matches the literal text `a.b`
- `name~~"a%.b"` uses Lua pattern escaping to match a literal dot
- `tooltip~~"[unterminated"` is treated as a safe non-match instead of an error

### Range Syntax

Syntax: `property:min-max`

Range syntax is intended for numeric properties.

```
ilvl:200-300            Items with ilvl between 200 and 300
reqlevel:70-80          Items requiring level 70-80
```

---

### Spec & Class Eligibility (set membership)

`forspec` and `forclass` test whether an item is **eligible** for a given
specialization or class — i.e. whether that spec/class would be offered the item
as loot (or, for class-restricted Use: tokens, whether the Classes: line lists
that class). They are **viewer-independent**: the result depends only on the
item, not on which character you are logged into (unlike the item link's
specialization field, which always reflects the *current* character).

**Equippable gear** uses `C_Item.DoesItemContainSpec` (same primitive behind
`#myspec`). **Non-equippable items** with a tooltip `Classes:` line
(`ITEM_CLASSES_ALLOWED`) also populate `forclass` / `#myclass` via tooltip
parse; they do **not** populate `forspec` / `#myspec`.

Because an item can be eligible for **several** specs and classes at once, these
are *membership* tests, not numeric comparisons:

| You type | Operator | Meaning |
|---|---|---|
| `forspec=269` | `=` / `==` | eligible for spec 269 (Windwalker Monk) |
| `forspec!=269` | `!=` | NOT eligible for spec 269 |
| `forclass=1` | `=` / `==` | eligible for class 1 (Warrior) |
| `forclass!=2` | `!=` | NOT eligible for class 2 (Paladin) |

Ordered comparators (`>`, `<`, `>=`, `<=`) and range syntax (`forspec:1-100`) are
**not** supported — spec and class IDs are identifiers, not magnitudes.

Specialization IDs are listed at <https://warcraft.wiki.gg/wiki/SpecializationID>.
Class IDs are 1–13 in the usual order: 1 Warrior, 2 Paladin, 3 Hunter, 4 Rogue,
5 Priest, 6 Death Knight, 7 Shaman, 8 Mage, 9 Warlock, 10 Monk, 11 Druid,
12 Demon Hunter, 13 Evoker.

```
forspec=269                Gear a Windwalker Monk could roll on
#gear & forclass=9         All gear usable by a Warlock
#geartoken & #myclass      Loot-spec tokens your class can use (e.g. Baleful)
#epic & forspec=270        Epic gear for Mistweaver Monk
#gear & forspec!=265       Gear NOT for Affliction Warlock
```

---

## Shorthand for Item Level

Because item level searches are so common, there are shortcuts that don't
require typing `ilvl`. These bind to **item level**, not item ID — use `id=`
for ID matching.

| Shorthand | Equivalent |
|---|---|
| `623` | `ilvl=623` |
| `200-300` | `ilvl:200-300` |
| `>600` | `ilvl>600` |
| `>=600` | `ilvl>=600` |
| `<200` | `ilvl<200` |

---

## Boolean Flags (Verbose Syntax)

For vendor rules and advanced expressions, verbose `IsProperty` flags are
available as an alternative to `#keyword` syntax. They work the same way but
read more like natural conditions.

| Flag | Equivalent keyword |
|---|---|
| `IsEquipment` | `#gear` |
| `IsSoulbound` | `#soulbound` |
| `IsBOE` | `#boe` |
| `IsBindOnEquip` | `#boe` |
| `IsBOA` | — (strict account-bound only; see note) |
| `IsWarbound` | `#warbound` |
| `IsAccountBound` | `#warbound` |
| `IsBOU` | `#bou` |
| `IsBindOnUse` | `#bou` |
| `IsWUE` | `#wue` |
| `IsWarboundUntilEquip` | `#wue` |
| `IsInEquipmentSet` | `#set` |
| `IsCollected` | `#collected` |
| `IsUsable` | `#usable` |
| `IsNew` | `#new` |
| `IsJunk` | `#junk`, `#trash` |
| `IsScrappable` | `#scrappable` |
| `IsDisenchantable` | `#disenchantable`, `#de` (via `OneWoW.Disenchant`) |
| `IsToy` | `#toy` |
| `IsMount` | `#mount` |
| `IsPet` | `#pet` |
| `IsWildPet` | `#wildpet` |
| `CanPetBattle` | `#petcanbattle` |
| `IsPetTradeable` | `#pettradeable` |
| `IsCosmetic` | `#cosmetic` |
| `IsLocked` | `#locked` |
| `HasLoot` | `#hasloot` |
| `IsUnsellable` | `#unsellable` |
| `HasCharges` | `#charges` |
| `IsUnique` | `#unique` |
| `IsUniqueEquipped` | `#uniqueequipped` |
| `IsQuestItem` | `#quest` |
| `IsTierSet` | `#tierset` |
| `IsGearToken` | `#geartoken` |
| `IsAppearanceCollected` | `#knowntransmog` |
| `HasAppearance` | `#transmog` |
| `IsEnsemble` | `#ensemble` |
| `IsUpgradeable` | `#upgradeable` |
| `IsFullyUpgraded` | `#fullyupgraded` |
| `IsUpgradeTrack` | `#upgradetrack` |
| `IsCurrentSeason` | `#currentseason` |
| `IsActiveSeason` | `#activeseason` |
| `IsMidnightS1` | `#midnights1` |
| `IsMidnightSeason1` | `#midnightseason1` |
| `IsMidnightS2` | `#midnights2` |
| `IsMidnightSeason2` | `#midnightseason2` |
| `IsProfessionEquipment` | `#professionequipment` |
| `IsEquipped` | `#equipped` |
| `IsEquippable` | `#gear` |
| `IsCraftingReagent` | `#craftingreagent` |
| `HasUseAbility` | `#onuse` |
| `HasEquipAbility` | `#onequip` |
| `IsAlreadyKnown` | `#alreadyknown` |
| `IsTradeableLoot` | `#tradeableloot` |
| `HasSocket` | `#socket` |
| `IsKnowledge` | `#knowledge` |
| `IsRefundable` | `#refundable` |
| `IsEnchanted` | `#enchanted` |

> **`IsBOA` vs `#boa`:** The `IsBOA` flag checks the strict `isBOA` property —
> true only for items whose tooltip shows account-bound binding (not Warbound
> Until Equipped). The `#boa` keyword (and its aliases `#accountbound`,
> `#warbound`) is broader: it matches both account-bound **and** WUE items
> (`isBOA or isWUE`). To match all warbound items in flag syntax, use
> `IsWarbound` or `IsAccountBound`. To match strict account-bound only, use
> `IsBOA`.

**Example (vendor rule style):**

```
IsEquipment & IsSoulbound & !IsInEquipmentSet & ilvl<600
```

---

## Named Constants

In vendor rules, `${NAME}` tokens are replaced with numeric values before
evaluation. This allows rule templates with adjustable thresholds.

### Quality Constants

| Constant | Value |
|---|---|
| `${POOR}` | 0 |
| `${COMMON}` | 1 |
| `${UNCOMMON}` | 2 |
| `${RARE}` | 3 |
| `${EPIC}` | 4 |
| `${LEGENDARY}` | 5 |
| `${ARTIFACT}` | 6 |
| `${HEIRLOOM}` | 7 |

### Expansion Constants

| Constant | Value |
|---|---|
| `${CURRENTEXPANSION}` | Client current expansion ID (`LE_EXPANSION_LEVEL_CURRENT`) |
| `${CLASSIC}` | 0 |
| `${TBC}` | 1 |
| `${WRATH}` | 2 |
| `${CATA}` | 3 |
| `${MOP}` | 4 |
| `${WOD}` | 5 |
| `${LEGION}` | 6 |
| `${BFA}` | 7 |
| `${SHADOWLANDS}` | 8 |
| `${DRAGONFLIGHT}` | 9 |
| `${WARWITHIN}` | 10 |
| `${MIDNIGHT}` | 11 |
| `${LASTTITAN}` | 12 |

**Example:**

```
quality>=${EPIC} & expansion==${WARWITHIN}
```

---

## PredicateEngine.lua (file map)

This is a structural index of
[`OneWoW/Services/PredicateEngine.lua`](../../OneWoW/Services/PredicateEngine.lua) for
anyone cross-checking behavior or diffs. User-facing behavior is also summarized
in this document; full API and extension notes are in
[`PREDICATE_ENGINE.md`](../../OneWoW/Docs/PREDICATE_ENGINE.md).

| Area | What lives there (approx.) |
|---|---|
| Caches | `propsCache`, `tooltipCache`, `compiledCache` — keyed by expression string and `bagID:slotID` where applicable. |
| Overrides | `ns.ItemIDOverrides` (`Services/PredicateEngine/item-overrides.lua`) — small `itemID → classID/subClassID` fixes for mis-tagged recipes/items. Programmatic callers outside bag search should use `OneWoW.PredicateEngine:IsRecipeItem` instead of raw `GetItemInfoInstant` class checks. |
| Data / patterns | Curated ID sets under `Services/PredicateEngine/` (`HearthstoneIDs`, generated `GearTokenIDs`); knowledge-study icon set (`KNOWLEDGE_ICONS`), `ITEM_CONTEXT_CATEGORY` → `#raid` / `#dungeon` / `#delves` / `#worldquest` / `#pvp` / `#store`, locale patterns for charges / tradeable / unique-equip, `CLASS_ID` (including Evoker, for `CanClassEquip` alt checks); `C_HousingCatalog.GetCatalogEntryInfoByItem` in `PopulateBaseProps` for decor quantity fields. |
| `CONSTANT_MAP` | `${POOR}` … `${HEIRLOOM}` and expansion `${CURRENTEXPANSION}`, `${CLASSIC}` … `${LASTTITAN}` for `ResolveParams` / vendor templates. |
| `PROP_REGISTRY` | Built-in numeric and string property names and aliases (including money units on `vendorprice` / `totalvalue` and housing decor counts: `decorstorage`, `decorplaced`, `decorredeemable`, `decortotal`). Exposed to callers via `RegisterProperty` merges. |
| `FLAG_REGISTRY` | Lowercased `IsEquipment`-style words → `props` field names (vendor-style verbose rules). |
| `KEYWORD_MAP` | All `#` keywords via `RegisterKeyword` (quality, class, subtypes, stats, context, etc.). |
| `BuildProps` | Layer 1: `itemID` + optional slot → flat `props` (lazy tooltip/binds/stats on access). |
| `ParseItemLink` (internal) | Decomposes retail item link fields (context, bonuses, craft GUID, quality prefix, etc.). |
| `Tokenize` | Layer 2 input: `&` `and` `\|` `or` `!` `not` `#keyword`, comparisons, flags, `()` , bare `ilvl` / money shorthands, quoted `~` name shorthand, text fallback. Tokenizer also accepts `||` as OR for SV/import strings; users type single `\|` in EditBoxes. |
| Parser | `ParseExpression` → `ParseAnd` → `ParseNot` → `ParsePrimary` (precedence: `!` tightest, then `&`, then `|` / `or`). |
| Public `PE:` API | `Compile`, `SafeEvaluate`, `CheckItem`, `BuildProps`, `ResolveParams`, `RegisterKeyword`, `RegisterProperty`, `SetKeywordResolver`, `InvalidateKeywordTokens`, `IsBuiltinKeyword`, `GetAllKeywords`, `GetMatchingKeywords`, `InvalidateCache`, `InvalidatePropsCache`, `InvalidateKnownProfessions`, `GetBattlePetData`, `GetItemCacheKey`, `GetItemIdentityKey`, `ParseItemLink`, `CanClassEquip`, `GetTooltipText`, `GetExpansionID`, `GetExpansionName`. User `#token` entries are not engine state — see `OneWoW.SearchExpand:GetTokens` / `GetMatchingTokens`. |
| `PE` fields | `ParseMoney`, `BattlePetTypes`, `ClassID`, `BATTLE_PET_CAGE_ID`. |

`#upgrade` is not hardcoded: it is registered at runtime (see
`PREDICATE_ENGINE.md`). `#recent` is a OneWoW Bags–registered keyword.
`#shoppinglist` / `#shoppinglistneeded` are registered by Shopping List.
None of those three live in the core engine file.

---

## Combining Everything

Expressions can be as simple or as complex as needed.

```
#food
```
All food items.

```
#weapon & #epic & ilvl>=620
```
Epic weapons at ilvl 620 or above.

```
#pet & (#pethumanoid | #petbeast)
```
Pets that are either Humanoid or Beast.

```
#pet & #epic & petlevel>=25
```
Epic pets at level 25 or above.

```
#armor & #tww & !#set & #boe
```
TWW armor that's not in an equipment set and is still bind-on-equip.

```
(#potion | #food | #flask) & count>5
```
Consumables with more than 5 in the stack.

```
#gear & #unknowntransmog & !#cosmetic
```
Equippable items with uncollected appearances, excluding cosmetics.

```
#hearthstone | (#armor & #junk) | #food
```
Hearthstones, armor that matches `#junk` (Poor or 1W-marked junk), or food.

```
#2hsword & #epic & ilvl>=620
```
Epic two-handed swords at ilvl 620+.

```
#haste & #vers & #gear
```
Equippable items with both haste and versatility.

```
#gem & #hastegem
```
Haste gems.

```
IsEquipment & !IsInEquipmentSet & quality<${RARE} & vendorprice>0
```
Equipped-type items not in a set, below rare quality, that can be sold (vendor
rule style).

---

## Item overlays (Overlays 2.0)

OneWoW **item icon overlays** (bags, bank, vendor, AH, etc.) are driven by the same
PredicateEngine expressions documented here. Each enabled overlay is a compiled PE
rule evaluated once per item button (`OneWoW.OverlayEngine` / `Overlays2/`).

Built-in overlay presets map to canned expressions in
[`OneWoW/Services/Overlays2/definitions.lua`](../../OneWoW/Services/Overlays2/definitions.lua).
Users can enable presets from QoL → Overlays or author fully custom rules with the
same syntax as bag search.

| Preset ID | Expression | Notes |
|---|---|---|
| `junk` | `#junk` or `#markedjunk` | `#markedjunk` when “include grey items” is off |
| `protected` | `#protected` | ItemStatus protected mark |
| `consumables` | `#consumable` | Excludes mis-tagged recipes reclassified as `#recipe` |
| `housingdecor` | `#housingdecor` | Classification only, not collection |
| `knownitems` | `#collectionknown` | Alias of `#collected` |
| `altcollected` | `#altcollected` | Recipe known by scoped alt, not you |
| `unknownitems` | `#collectionmissing and !#altcollected` | Missing on you; excludes alt-known recipes |
| `transmog` | `#transmog and #unknowntransmog` | Uncollected appearances |
| `mounts` | `#mount` | |
| `pets` | `#pet` | |
| `quest` | `#quest` | |
| `reagents` | `#tradegoods` | |
| `recipe` | `#recipe and #teachable` | Profession plans with a teach line (not raw class alone) |
| `soulbound` | `#soulbound` | |
| `toys` | `#toy` | |
| `warbound` | `#warbound` or `#warbound and !#wue` | Optional WUE exclusion |
| `wue` | `#wue` | |
| `boe` | `#boe` | |
| `shoppinglist` | `#shoppinglist` or `#shoppinglistneeded` | `#shoppinglistneeded` when “only when still needed” is on. Registered by Shopping List. |

**Not expression presets:** `itemlevel` and `qualityborder` are rendered separately
(no icon slot, no max-4 overlay cap).

**Custom overlays:** Stored in `db.global.overlays.userOverlays`. Each entry is either
`preset = "<id>"` (inherits the catalog expression) or a freeform `expression` string.
Up to four icon overlays paint per button; item level and quality border do not count
toward the cap.

**Examples:**

```
#recipe and #teachable and #collectionmissing
#housingdecor and #uncollected
#consumable and !#potion
```
