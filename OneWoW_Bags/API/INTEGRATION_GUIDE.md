# Integration Guide: Adding Overlays to OneWoW Bags

This guide walks you through integrating your addon with OneWoW Bags to add custom overlays or decorations to item buttons.

## Table of Contents

1. [Overview](#overview)
2. [Setup](#setup)
3. [Implementation](#implementation)
4. [Best Practices](#best-practices)
5. [Examples](#examples)

## Overview

OneWoW Bags provides a **callback system** that fires every time an item button is updated or displayed. Your addon registers a callback function, and OneWoW Bags calls it with the button and item information.

### What You Get

When your callback fires, you receive:
- **button** - The item button frame object (guaranteed to be visible)
- **bagID** - Which bag the item is in (0=backpack, 1-4=bags, 5=reagent bag, etc.)
- **slotID** - Which slot in the bag

**Note:** Callbacks only fire for buttons that are currently visible in the UI. Hidden or collapsed buttons won't trigger callbacks.

With this information, you can query the item, create overlays, and add any custom UI elements you need.

## Setup

### Step 1: Create Your Integration File

Copy `Examples/Basic.lua` to your addon folder with a descriptive name:

```
YourAddon/
├── YourAddon.lua
├── YourAddon.toc
└── Integrations/
    └── OneWoWBags.lua  (your integration file)
```

### Step 2: Add to Your .toc File

In your addon's `.toc` file, add the integration file:

```
## Interface: 120000, 120001
## Title: Your Addon Name
## Version: 1.0

YourAddon.lua
Integrations/OneWoWBags.lua
```

### Step 3: Implement Your Callback

Modify the integration file to add your custom logic (see [Implementation](#implementation) below).

### Step 4: Done!

When OneWoW Bags loads, it will automatically detect and register your callback.

## Implementation

### Basic Structure

```lua
local ADDON_NAME = ...

if _G.OneWoW_Bags then
    function YourAddon_OnItemButton(button, bagID, slotID)
        -- Your custom logic here
    end

    _G.OneWoW_Bags:RegisterItemButtonCallback(ADDON_NAME, YourAddon_OnItemButton)
end
```

### Full Example: Adding an Overlay

```lua
local ADDON_NAME = ...

if _G.OneWoW_Bags then
    function MyAddon_UpdateItemButton(button, bagID, slotID)
        if not button then return end

        -- Create overlay frame on first call
        if not button.MyAddonOverlay then
            button.MyAddonOverlay = CreateFrame("Frame", nil, button)
            button.MyAddonOverlay:SetAllPoints(button)
            button.MyAddonOverlay:SetFrameLevel(button:GetFrameLevel() + 1)
        end

        -- Check if item exists at this location
        local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

        if not C_Item.DoesItemExist(itemLocation) then
            button.MyAddonOverlay:Hide()
            return
        end

        -- Get item information
        local itemLink = C_Item.GetItemLink(itemLocation)
        local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)

        if itemLink and containerInfo then
            -- Apply your custom overlay
            MyAddon_ApplyOverlay(button.MyAddonOverlay, itemLink, containerInfo)
        else
            button.MyAddonOverlay:Hide()
        end
    end

    _G.OneWoW_Bags:RegisterItemButtonCallback(ADDON_NAME, MyAddon_UpdateItemButton)
end
```

### Breaking It Down

1. **Check button exists:** Basic null check
2. **Create overlay once:** Create your frame on first call, reuse it afterward
3. **Check item exists:** Use `ItemLocation` and `C_Item.DoesItemExist()`
4. **Get item data:** Use `C_Item.GetItemLink()` and `C_Container.GetContainerItemInfo()`
5. **Apply your logic:** Update colors, textures, text, etc.
6. **Hide when empty:** Hide overlay for empty slots

**Note:** Buttons are guaranteed to be visible when your callback fires, so you don't need to check `button:IsVisible()`.

## Best Practices

### 1. Error Handling

Always use `pcall()` to prevent your callback from breaking OneWoW Bags:

```lua
function MyAddon_UpdateItemButton(button, bagID, slotID)
    if not button then return end

    pcall(function()
        -- Your code here
    end)
end
```

### 2. Frame Hierarchy

Keep your overlay as a direct child of the button:

```lua
button.MyAddonOverlay = CreateFrame("Frame", nil, button)
button.MyAddonOverlay:SetAllPoints(button)
```

### 3. Don't Modify the Button

Never modify the button's properties. Only add your own child frames:

```lua
-- GOOD: Create child frame
button.MyOverlay = CreateFrame("Frame", nil, button)

-- BAD: Modify button directly
button:SetSize(50, 50)  -- Don't do this!
```

### 4. Performance

Keep callbacks fast. Complex calculations should happen elsewhere:

```lua
-- BAD: Heavy computation in every callback
function MyAddon_UpdateItemButton(button, bagID, slotID)
    local data = ScanAllAddonsAndServers()  -- Too slow!
end

-- GOOD: Pre-compute, just lookup in callback
MyAddon_CachedData = PrecomputeOnce()
function MyAddon_UpdateItemButton(button, bagID, slotID)
    local value = MyAddon_CachedData[itemID]  -- Fast lookup
end
```

### 5. Cleanup

Hide your overlay when the item doesn't exist:

```lua
local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
if not C_Item.DoesItemExist(itemLocation) then
    button.MyAddonOverlay:Hide()
    return
end
```

## Examples

Ready-to-use examples are in the `Examples/` folder:

- **Basic.lua** - Simple overlay template
- **TransmogLootHelper.lua** - Real-world example (transmog marking)
- **ColorOverlay.lua** - Colored texture overlay
- **TextBadge.lua** - Text badge on items

See [Examples](./Examples/) for more.

## API Reference

See [ITEM_BUTTON_API.md](./ITEM_BUTTON_API.md) for:
- Complete API reference
- Callback parameters
- When callbacks fire
- How to register/unregister

## Troubleshooting

**My callback isn't firing:**
- Make sure OneWoW_Bags is loaded (check for `_G.OneWoW_Bags`)
- Verify your integration file is in your .toc file
- Check that OneWoW Bags is installed and enabled

**My overlay doesn't appear:**
- Is the button visible? Check `button:IsVisible()`
- Is the overlay being created? Add a print statement to debug
- Is the overlay frame sized correctly? Use `SetAllPoints()`
- Is the frame level high enough? Use `GetFrameLevel() + 1`

**Items aren't updating:**
- Make sure you're getting the right bagID and slotID
- Check that itemLocation is valid with `C_Item.DoesItemExist()`
- Are you calling your overlay update function?

## Next Steps

1. Copy `Examples/Basic.lua` to your addon
2. Modify it with your custom logic
3. Test by opening OneWoW Bags
4. Read [ITEM_BUTTON_API.md](./ITEM_BUTTON_API.md) for detailed API info

Happy integrating!
