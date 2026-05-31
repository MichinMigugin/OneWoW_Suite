# # InventorySlotID

`inventorySlotID`s refer to a unique ID for a specific equipment, bag, or bank slot. For equipment, character bag, and some bank slots, an `inventorySlotName` can be resolved to an `inventorySlotID` with `GetInventorySlotInfo()`.

For equipment slots, an `inventorySlotName` also doubles as a GlobalString. Most equipment `inventorySlotID`s also have a corresponding constant.

|inventorySlotName|GlobalString (enUS)|inventorySlotID|Constant|
|---|---|---|---|
|AMMOSLOT|Ammo|0|INVSLOT_AMMO|
|HEADSLOT|Head|1|INVSLOT_HEAD|
|NECKSLOT|Neck|2|INVSLOT_NECK|
|SHOULDERSLOT|Shoulders|3|INVSLOT_SHOULDER|
|SHIRTSLOT|Shirt|4|INVSLOT_BODY|
|CHESTSLOT|Chest|5|INVSLOT_CHEST|
|WAISTSLOT|Waist|6|INVSLOT_WAIST|
|LEGSSLOT|Legs|7|INVSLOT_LEGS|
|FEETSLOT|Feet|8|INVSLOT_FEET|
|WRISTSLOT|Wrist|9|INVSLOT_WRIST|
|HANDSSLOT|Hands|10|INVSLOT_HAND|
|FINGER0SLOT|Finger|11|INVSLOT_FINGER1|
|FINGER1SLOT|Finger|12|INVSLOT_FINGER2|
|TRINKET0SLOT|Trinket|13|INVSLOT_TRINKET1|
|TRINKET1SLOT|Trinket|14|INVSLOT_TRINKET2|
|BACKSLOT|Back|15|INVSLOT_BACK|
|MAINHANDSLOT|Main Hand|16|INVSLOT_MAINHAND|
|SECONDARYHANDSLOT|Off Hand|17|INVSLOT_OFFHAND|
|RANGEDSLOT|Ranged|18|INVSLOT_RANGED|
|TABARDSLOT|Tabard|19|INVSLOT_TABARD|
|PROF0TOOLSLOT|Profession Tool|20||
|PROF0GEAR0SLOT|Profession Accessory|21||
|PROF0GEAR1SLOT|Profession Accessory|22||
|PROF1TOOLSLOT|Profession Tool|23||
|PROF1GEAR0SLOT|Profession Accessory|24||
|PROF1GEAR1SLOT|Profession Accessory|25||
|COOKINGTOOLSLOT|Cooking Tool|26||
|COOKINGGEAR0SLOT|Cooking Accessory|27||
|FISHINGTOOLSLOT|Fishing Rod|28||
|FISHINGGEAR0SLOT|Fishing Accessory|29||
|FISHINGGEAR1SLOT|Fishing Accessory|30||
