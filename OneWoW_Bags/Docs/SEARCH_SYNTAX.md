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
| `name=Hearthstone` | Exact name match (case-insensitive) |
| `name!=Hearthstone` | Everything except items named "Hearthstone" |

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
| `#food` | Food and drink |
| `#drink` | Food and drink (same as `#food`) |
| `#flask` | Flasks and phials |
| `#elixir` | Elixirs |
| `#bandage` | Bandages |

### Equipment

| Keyword | Aliases | What it matches |
|---|---|---|
| `#gear` | `#equipment`, `#equippable` | Any equippable item |
| `#set` | `#equipmentset` | Items in an equipment set |
| `#cosmetic` | | Cosmetic armor |

### Armor Type

| Keyword | What it matches |
|---|---|
| `#cloth` | Cloth armor |
| `#leather` | Leather armor |
| `#mail` | Mail armor |
| `#plate` | Plate armor |
| `#shield` | Shields |

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

### Binding

| Keyword | Aliases | What it matches |
|---|---|---|
| `#soulbound` | `#bound`, `#bop` | Character-bound items (not account-bound) |
| `#boe` | `#bindonequip` | Bind on Equip items (not yet bound) |
| `#boa` | `#accountbound`, `#warbound` | Account/Warband-bound items |
| `#bou` | `#bindonuse` | Bind on Use items (not yet bound) |
| `#wue` | `#warbounduntilequip` | Warbound Until Equipped items |

> **Note:** Bind keywords use the game's API bind type, which may differ from
> the tooltip display text. In WoW 12.0, many items display "Warbound Until
> Equipped" in their tooltip but have an API bind type of "Bind on Equip".
> These items match `#boe`, not `#wue`.

### Expansion

Each expansion has a full name keyword and one or more short aliases.

| Keyword | Aliases |
|---|---|
| `#classic` | `#vanilla` |
| `#burningcrusade` | `#tbc` |
| `#wrath` | `#wotlk` |
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

### Transmog

| Keyword | What it matches |
|---|---|
| `#transmog` | Items with a transmog appearance |
| `#knowntransmog` | Items whose appearance you've collected |
| `#unknowntransmog` | Items whose appearance you haven't collected |

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
| `#upgradeable` | Items that can be upgraded |
| `#fullyupgraded` | Items at max upgrade level |

### Tooltip

These keywords scan the item's tooltip text. They may be slightly slower than
other keywords on first access.

| Keyword | What it matches |
|---|---|
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
| `totalvalue` | | Vendor sell price x stack size (copper) |
| `maxstack` | `stacksize` | Maximum stack size |
| `reqlevel` | `minlevel` | Required player level |
| `expansion` | `expac` | Expansion ID (0=Classic, 1=TBC, ..., 10=TWW, 11=Midnight) |
| `class` | `typeid` | Item class ID |
| `subclass` | `subtypeid` | Item subclass ID |
| `bindtype` | | Bind type ID (0=None, 1=BoP, 2=BoE, 3=BoU, 8=Warband, 9=WUE) |
| `craftedquality` | | Crafted quality tier (1-5, 0 if not crafted) |
| `upgradelevel` | | Current upgrade level |
| `upgrademax` | | Maximum upgrade level |
| `maxlevel` | | Maximum possible item level after upgrades |
| `setid` | | Equipment set ID |
| `sockets` | | Number of gem sockets |

**Examples:**

```
ilvl>=600               Items at ilvl 600+
quality>=4              Epic or better
vendorprice>0           Items worth something to a vendor
expansion==10           The War Within items
count>1                 Stacked items
sockets>0               Items with at least one socket
upgradelevel>0          Partially upgraded items
```

### String Comparisons

Syntax: `property=value` (exact), `property!=value` (not equal),
`property~value` (contains)

| Property | Aliases | What it is |
|---|---|---|
| `name` | | Item name (case-insensitive) |
| `equiploc` | | Equipment location string (e.g. `INVTYPE_HEAD`) |

**Examples:**

```
name~sword              Items with "sword" in the name
name=Hearthstone        Exact name match
equiploc=INVTYPE_HEAD   Head slot items
```

### Range Syntax

Syntax: `property:min-max`

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
| `IsBOA` | `#warbound` |
| `IsWarbound` | `#warbound` |
| `IsBOU` | `#bou` |
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
IsEquipment & !IsInEquipmentSet & quality<${RARE} & vendorprice>0
```
Equipped-type items not in a set, below rare quality, that can be sold (vendor
rule style).
