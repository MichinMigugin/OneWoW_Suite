# Item Button API Reference

Complete API documentation for integrating with OneWoW Bags item buttons.

## Table of Contents

- [API Functions](#api-functions)
- [Callback Signature](#callback-signature)
- [When Callbacks Fire](#when-callbacks-fire)
- [Button Object](#button-object)
- [Working with Items](#working-with-items)
- [Troubleshooting](#troubleshooting)

## API Functions

### RegisterItemButtonCallback

Registers a callback function to be called when item buttons are updated.

**Signature:**
```lua
OneWoW_Bags:RegisterItemButtonCallback(name, callback)
```

**Parameters:**
- `name` (string): Unique identifier for your callback
  - Typically use your addon name: `ADDON_NAME` or `"MyAddonName"`
  - Used for logging and debugging
  - Example: `"TransmogLootHelper"`, `"MyPriceChecker"`
- `callback` (function): Function to call on item button updates
  - See [Callback Signature](#callback-signature)

**Returns:**
- Nothing

**Example:**
```lua
local ADDON_NAME = ...

if _G.OneWoW_Bags then
    function MyCallback(button, bagID, slotID)
        -- Your code here
    end

    _G.OneWoW_Bags:RegisterItemButtonCallback(ADDON_NAME, MyCallback)
end
```

**Error Handling:**
- If callback is not a function, an error is logged
- If callback throws an error, it's caught with pcall() and logged

### UnregisterItemButtonCallback

Removes a previously registered callback.

**Signature:**
```lua
OneWoW_Bags:UnregisterItemButtonCallback(name)
```

**Parameters:**
- `name` (string): The callback name you used when registering

**Returns:**
- Nothing

**Example:**
```lua
_G.OneWoW_Bags:UnregisterItemButtonCallback("MyAddonName")
```

## Callback Signature

Your callback function receives three parameters.

**Signature:**
```lua
function YourCallback(button, bagID, slotID)
```

**Parameters:**

### button (Frame Object)

The item button frame being updated.

**Properties:**
- `button.bagID` - Bag ID (integer, 0-20)
- `button.slotID` - Slot ID (integer, 1-N)
- `button.hasItem` - Boolean, true if slot contains an item
- `button:IsVisible()` - Check if button is currently visible
- `button:GetFrameLevel()` - Get button's frame strata level

**Methods:**
- `button:FullUpdate()` - Force button to update (rarely needed)
- `button:Show()` / `button:Hide()` - Show/hide button

**Your Overlay Anchor:**
```lua
if not button.MyOverlay then
    button.MyOverlay = CreateFrame("Frame", nil, button)
    button.MyOverlay:SetAllPoints(button)
end
```

### bagID (integer)

The ID of the bag containing the item.

**Valid Values:**
- `0` - Backpack
- `1` - Bag 1
- `2` - Bag 2
- `3` - Bag 3
- `4` - Bag 4
- `5` - Reagent bag
- `6-20` - Bank slots and special bags

**Usage:**
```lua
local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
```

### slotID (integer)

The slot number within the bag.

**Valid Values:**
- `1` to `N` where N is the number of slots in the bag
- Each bag can have 0-36 slots

**Usage:**
```lua
local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
```

## When Callbacks Fire

Callbacks are fired when:

1. **GUI Refresh** - When OneWoW Bags refreshes its layout (opening bags, swapping items, etc.)
2. **Visibility Change** - Only visible buttons receive callbacks
3. **Item Updates** - Whenever items are displayed or their state changes

**Important:** Callbacks fire only for buttons that are currently visible. Hidden buttons are skipped.

Callbacks fire frequently as the UI refreshes. Keep them lightweight and avoid heavy computations.

## Button Object

The button frame is a custom OneWoW_Bags button object. Don't modify its properties directly.

### Safe Operations (Read-Only)

```lua
local itemInfo = button.itemInfo
local bagID = button.bagID
local slotID = button.slotID
local hasItem = button.hasItem
local isVisible = button:IsVisible()
local frameLevel = button:GetFrameLevel()
```

### Unsafe Operations (Don't Do These)

```lua
-- BAD: Modifying button properties
button:SetSize(50, 50)
button:SetTexture(texture)
button:SetAlpha(0.5)

-- GOOD: Create a child frame instead
local overlay = CreateFrame("Frame", nil, button)
overlay:SetAllPoints(button)
overlay:SetAlpha(0.5)
```

### Adding Overlays (Correct Way)

```lua
if not button.MyOverlay then
    button.MyOverlay = CreateFrame("Frame", nil, button)
    button.MyOverlay:SetAllPoints(button)
    button.MyOverlay:SetFrameLevel(button:GetFrameLevel() + 1)
end
```

## Working with Items

### Get Item Information

```lua
local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

-- Check if item exists
if not C_Item.DoesItemExist(itemLocation) then
    -- Empty slot
    return
end

-- Get item link
local itemLink = C_Item.GetItemLink(itemLocation)

-- Get container info
local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
-- containerInfo has:
--   - iconFileID
--   - stackCount
--   - isLocked
--   - isBound
--   - quality
--   - hyperlink
--   - itemID
--   - inventoryType
--   - rarity
```

### Parse Item ID from Link

```lua
local itemLink = C_Item.GetItemLink(itemLocation)
local itemID = tonumber(itemLink:match("item:(%d+)"))
```

### Get Item Details

```lua
local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, iconFileID = GetItemInfo(itemID)
```

### Check Item Rarity

```lua
local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
local rarity = containerInfo.quality
-- 0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary, 6=Artifact, 7=Heirloom, 8=WoWToken
```

## Troubleshooting

### Callback Not Firing

**Problem:** Your callback function is never called.

**Solutions:**
1. Check that OneWoW_Bags is installed and enabled
2. Verify your integration file is loaded:
   ```lua
   if _G.OneWoW_Bags then
       print("OneWoW_Bags found!")
   else
       print("OneWoW_Bags NOT found")
   end
   ```
3. Check that your integration file is in your addon's `.toc`
4. Make sure you're registering the callback:
   ```lua
   _G.OneWoW_Bags:RegisterItemButtonCallback("MyAddon", MyCallback)
   print("Callback registered")
   ```

### Overlay Not Appearing

**Problem:** Your callback runs but overlay doesn't show.

**Solutions:**
1. Verify overlay frame is created:
   ```lua
   if not button.MyOverlay then
       button.MyOverlay = CreateFrame("Frame", nil, button)
   end
   print("Overlay created:", button.MyOverlay)
   ```
2. Check frame is anchored correctly:
   ```lua
   button.MyOverlay:SetAllPoints(button)
   print("Overlay size:", button.MyOverlay:GetSize())
   ```
3. Verify frame level is high enough:
   ```lua
   button.MyOverlay:SetFrameLevel(button:GetFrameLevel() + 1)
   ```
4. Make sure overlay is shown:
   ```lua
   button.MyOverlay:Show()
   ```

### Item Data Missing

**Problem:** `C_Item.GetItemLink()` returns nil.

**Solutions:**
1. Check if item location is valid:
   ```lua
   local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
   if not C_Item.DoesItemExist(itemLocation) then
       -- Empty slot
       button.MyOverlay:Hide()
       return
   end
   ```
2. Item data might not be cached yet. Wait and try again:
   ```lua
   local itemLink = C_Item.GetItemLink(itemLocation)
   if not itemLink then
       C_Timer.After(0.1, function()
           local itemLink = C_Item.GetItemLink(itemLocation)
           if itemLink then
               UpdateOverlay(itemLink)
           end
       end)
   end
   ```

### Performance Issues

**Problem:** OneWoW Bags is slow when your addon is enabled.

**Solutions:**
1. Keep callbacks lightweight:
   ```lua
   -- BAD: Heavy computation every callback
   function MyCallback(button, bagID, slotID)
       for i = 1, 10000 do
           local item = GetItemInfo(i)
       end
   end

   -- GOOD: Pre-compute, lookup in callback
   MyData = {}
   function OnInitialize()
       for i = 1, 10000 do
           MyData[i] = GetItemInfo(i)
       end
   end
   function MyCallback(button, bagID, slotID)
       local info = MyData[itemID]
   end
   ```
2. Avoid database lookups - cache results
3. Use pcall to prevent errors from slowing down the UI:
   ```lua
   function MyCallback(button, bagID, slotID)
       pcall(function()
           -- Your code here
       end)
   end
   ```

## Related WoW APIs

- `ItemLocation` - Create item location objects
- `C_Item.DoesItemExist()` - Check if item exists
- `C_Item.GetItemLink()` - Get item link
- `C_Item.GetItemID()` - Get item ID
- `C_Container.GetContainerItemInfo()` - Get item info
- `C_Container.GetContainerNumSlots()` - Get bag slots
- `GetItemInfo()` - Get item details by ID
- `EventUtil.ContinueOnAddOnLoaded()` - Wait for addon load

## See Also

- [INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md) - How to set up integration
- [Examples/](./Examples/) - Working code examples
