# Search & Expression Syntax

OneWoW Bags uses a single expression engine for the search bar, custom category
rules, and (in the future) vendor sell rules. Everything described here works in
all three contexts.

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
| `#knowledge` | Profession knowledge study items |

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

---

## Keywords

Keywords start with `#` and test a specific item property or category.
All keywords are case-insensitive.

### Quality

| Keyword | Aliases |
|---|---|
| `#poor` | `#junk`, `#grey`, `#gray`, `#trash` |
| `#common` | `#white` |
| `#uncommon` | `#green` |
| `#rare` | `#blue` |
| `#epic` | `#purple` |
| `#legendary` | `#orange` |
| `#artifact` | |
| `#heirloom` | |

### Item Type

| Keyword | Aliases | What it matches |
|---|---|---|
| `#weapon` | | All weapons |
| `#armor` | | All armor |
| `#consumable` | | All consumables |
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
| `#cosmetic` | | Cosmetic armor |
| `#myclass` | | Equipment your class can use |
| `#myspec` | | Equipment usable by your current spec (universal gear included) |

### Armor Subtype

| Keyword | What it matches |
|---|---|
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
| `#wand` | |
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

### Housing Subtype

| Keyword | Aliases |
|---|---|
| `#decor` | |
| `#dye` | `#housingdye` |
| `#room` | |
| `#roomcustomization` | |
| `#exteriorcustomization` | |
| `#serviceitem` | |

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

### Miscellaneous Subtypes

| Keyword | What it matches |
|---|---|
| `#holiday` | Holiday items |
| `#companionpet` | Companion pet items |
| `#mountequipment` | Mount equipment |

### Reagent Subtypes

| Keyword | What it matches |
|---|---|
| `#contexttoken` | Context tokens |

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

| Keyword | Aliases |
|---|---|
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

### Collectibles

| Keyword | What it matches |
|---|---|
| `#toy` | Toys |
| `#mount` | Mounts |
| `#pet` | Battle pets (alias: `#battlepet`) |
| `#collected` | Toys/mounts/pets you already own |
| `#uncollected` | Toys/mounts/pets you don't own |
| `#alreadyknown` | Recipes/items marked "Already Known" |

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
| `#transmog` | Items with a transmog appearance |
| `#knowntransmog` | Items whose appearance you've collected |
| `#unknowntransmog` | Items whose appearance you haven't collected |

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
| `#usable` | Items you can use (alias: `#use`) |
| `#unusable` | Items you cannot use |
| `#locked` | Locked items |
| `#charges` | Items with charges |
| `#unique` | Unique-equipped items |
| `#socket` | Items with gem sockets |
| `#equipped` | Items currently equipped |

### Vendor / Value

| Keyword | What it matches |
|---|---|
| `#sellable` | Items with a vendor price |
| `#unsellable` | Items that cannot be sold |

### Crafting

| Keyword | What it matches |
|---|---|
| `#craftingreagent` | Crafting reagents |
| `#crafted` | Player-crafted items (has a crafted quality) |
| `#professionequipment` | Profession tools and accessories |

### Upgrades

| Keyword | What it matches |
|---|---|
| `#upgrade` | Items flagged as an upgrade for your character (via OneWoW upgrade detection) |
| `#upgradeable` | Items that can be upgraded |
| `#fullyupgraded` | Items at max upgrade level |

### Tooltip

These keywords scan the item's tooltip text. They may be slightly slower than
other keywords on first access.

| Keyword | What it matches |
|---|---|
| `#onuse` | Items with a `Use:` tooltip effect |
| `#onequip` | Items with an `Equip:` tooltip effect |
| `#uniqueequipped` | Unique-equipped items |
| `#reputation` | Items with "Reputation" in the tooltip |
| `#tradeableloot` | Loot still in the trade window |
| `#openable` | Containers you can right-click to open |

### Special

| Keyword | What it matches |
|---|---|
| `#hearthstone` | Hearthstone and all hearthstone toy variants |
| `#keystone` | Mythic Keystones |
| `#tierset` | Items belonging to a tier set |

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
| `quality` | | Quality as a number (0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary) |
| `count` | `stacks` | Stack size in the slot |
| `vendorprice` | `price`, `unitvalue` | Vendor sell price per unit (copper) |
| `totalvalue` | | Vendor sell price × stack size (copper) |
| `maxstack` | `stacksize` | Maximum stack size |
| `reqlevel` | `minlevel` | Required player level |
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
| `craftedquality` | | Crafted quality tier (1–5, 0 if not crafted) |
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

> **`#armor` vs `armor>=N`:** The keyword `#armor` matches any item in the
> Armor item class. The property `armor` in a comparison like `armor>=100`
> checks the item's armor *stat value*. These are independent.

**Examples:**

```
ilvl>=600               Items at ilvl 600+
quality>=4              Epic or better
vendorprice>0           Items worth something to a vendor
expansion==10           The War Within items
count>1                 Stacked items
sockets>0               Items with at least one socket
upgradelevel>0          Partially upgraded items
haste>=200              Items with 200+ haste rating
crit>0                  Items with any crit (same as #crit)
pettype=8               Beast battle pets
petlevel:1-10           Low-level pets
petquality>=4           Epic or better pets
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

## Shorthand for Item Level

Because item level searches are so common, there are shortcuts that don't
require typing `ilvl`:

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
| `IsJunk` | `#junk` |
| `IsUpgrade` | (OneWoW upgrade detection) |
| `IsToy` | `#toy` |
| `IsMount` | `#mount` |
| `IsPet` | `#pet` |
| `IsCosmetic` | `#cosmetic` |
| `IsLocked` | `#locked` |
| `IsUnsellable` | `#unsellable` |
| `HasCharges` | `#charges` |
| `IsUnique` | `#unique` |
| `IsUniqueEquipped` | `#uniqueequipped` |
| `IsQuestItem` | `#quest` |
| `IsTierSet` | `#tierset` |
| `IsAppearanceCollected` | `#knowntransmog` |
| `IsUnknownAppearance` | `#unknowntransmog` |
| `HasAppearance` | `#transmog` |
| `IsUpgradeable` | `#upgradeable` |
| `IsFullyUpgraded` | `#fullyupgraded` |
| `IsProfessionEquipment` | `#professionequipment` |
| `IsEquipped` | `#equipped` |
| `IsEquippable` | `#gear` |
| `IsCraftingReagent` | `#craftingreagent` |
| `HasUseAbility` | (tooltip: has a "Use:" effect) |
| `IsAlreadyKnown` | `#alreadyknown` |
| `IsTradeableLoot` | `#tradeableloot` |
| `HasSocket` | `#socket` |
| `IsKnowledge` | `#knowledge` |

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
#pet & (#pethumanoid || #petbeast)
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
(#potion || #food || #flask) & count>5
```
Consumables with more than 5 in the stack.

```
#gear & #unknowntransmog & !#cosmetic
```
Equippable items with uncollected appearances, excluding cosmetics.

```
#hearthstone || (#armor & #junk) || #food
```
Hearthstones, junk armor, or food.

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
