# OneWoW Bags Integration Examples

Ready-to-use examples for integrating your addon with OneWoW Bags.

## Quick Guide

1. **[Basic.lua](#basiclua)** - Start here if you're new
2. **[TransmogLootHelper.lua](#transmogloothelplua)** - Real-world working example
3. **[ColorOverlay.lua](#coloroverlaylua)** - Add colored overlays to items
4. **[TextBadge.lua](#textbadgelua)** - Display text badges on items

## Basic.lua

**What it does:** Simple template with comments explaining each step.

**Use this if:** You're just starting and want to understand the integration process.

**Key features:**
- Minimal, well-commented code
- Clear function names with `YourAddon_` prefix
- Shows the basic structure

**To use:**
1. Copy to your addon: `YourAddon/Integrations/OneWoWBags.lua`
2. Replace `YourAddon_` with your addon's name
3. Implement `YourAddon_ApplyOverlay()` with your logic
4. Add to your .toc file

## TransmogLootHelper.lua

**What it does:** Complete working integration for the TransmogLootHelper addon.

**Use this if:** You're making a transmog overlay addon or want a real-world example.

**Key features:**
- Real addon integration
- Uses the app's existing `ApplyItemOverlay()` function
- Production-ready code

**To use:**
1. Copy to: `TransmogLootHelper/Integrations/OneWoWBags.lua`
2. Add to .toc: `Integrations\OneWoWBags.lua`
3. Done! No additional setup needed.

## ColorOverlay.lua

**What it does:** Adds a colored texture overlay to items based on rarity.

**Use this if:** You want to highlight items by color (by rarity, by type, by status, etc.)

**Key features:**
- Creates colored texture layers
- Uses vertex colors for efficiency
- Shows how to create and cache frame elements
- Includes rarity color definitions

**Example use cases:**
- Highlight items by rarity
- Mark items by quality threshold
- Color code items by type (armor, weapons, etc.)
- Highlight items matching your criteria

**To use:**
1. Copy to your addon: `YourAddon/Integrations/OneWoWBags.lua`
2. Modify the `RARITY_COLORS` table with your colors
3. Customize `YourAddon_ApplyColorOverlay()` with your logic
4. Add to your .toc file

**Customization example:**
```lua
local MY_COLORS = {
    ["transmog"] = { r = 1.00, g = 0.50, b = 0.00 },  -- Orange
    ["collect"] = { r = 0.00, g = 0.80, b = 1.00 },  -- Cyan
    ["vendor"] = { r = 1.00, g = 1.00, b = 0.00 },  -- Yellow
}
```

## TextBadge.lua

**What it does:** Displays a text badge on the corner of items.

**Use this if:** You want to show numerical data (prices, counts, values, etc.)

**Key features:**
- Creates a badge frame in corner of button
- Displays text data
- Shows frame hierarchy best practices
- Easy to customize colors and positioning

**Example use cases:**
- Display item price
- Show quantity available on other characters
- Display transmog count
- Show collection progress
- Display item level or stats

**To use:**
1. Copy to your addon: `YourAddon/Integrations/OneWoWBags.lua`
2. Implement `YourAddon_GetItemValue()` to return your data
3. Customize badge styling (color, size, position)
4. Add to your .toc file

**Customization example:**
```lua
function YourAddon_GetItemValue(itemLink)
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    -- Look up value from your database
    return MyValueDatabase[itemID]
end
```

**Badge positioning options:**
```lua
-- Bottom right (default)
overlayFrame.badgeFrame:SetPoint("BOTTOMRIGHT", overlayFrame, "BOTTOMRIGHT", -2, 2)

-- Top right
overlayFrame.badgeFrame:SetPoint("TOPRIGHT", overlayFrame, "TOPRIGHT", -2, -2)

-- Bottom left
overlayFrame.badgeFrame:SetPoint("BOTTOMLEFT", overlayFrame, "BOTTOMLEFT", 2, 2)

-- Top left
overlayFrame.badgeFrame:SetPoint("TOPLEFT", overlayFrame, "TOPLEFT", 2, -2)
```

## Common Patterns

### Creating an Overlay Frame

```lua
if not button.MyAddonOverlay then
    button.MyAddonOverlay = CreateFrame("Frame", nil, button)
    button.MyAddonOverlay:SetAllPoints(button)
    button.MyAddonOverlay:SetFrameLevel(button:GetFrameLevel() + 1)
end
```

### Getting Item Information

```lua
local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

if C_Item.DoesItemExist(itemLocation) then
    local itemLink = C_Item.GetItemLink(itemLocation)
    local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    -- Use itemLink and containerInfo
else
    -- Empty slot
    button.MyAddonOverlay:Hide()
end
```

### Caching Frame Elements

```lua
-- Create once on first update
if not overlayFrame.myTexture then
    overlayFrame.myTexture = overlayFrame:CreateTexture(nil, "OVERLAY")
    overlayFrame.myTexture:SetAllPoints(overlayFrame)
end

-- Reuse on subsequent updates
overlayFrame.myTexture:SetVertexColor(r, g, b, a)
```

### Button Visibility

Buttons passed to callbacks are **always visible**. You can safely assume:
- `button:IsVisible()` returns true
- The button is currently displayed in the UI
- The button has valid size and position

You don't need to check visibility in your callback.

### Hiding Empty Slots

```lua
local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

if not C_Item.DoesItemExist(itemLocation) then
    overlayFrame:Hide()
    return
end

-- Item exists, update overlay
```

## Tips & Tricks

### Performance

- Create frame elements once, reuse them
- Don't do heavy computation in callbacks
- Cache frequently-used data

### Debugging

Add debug prints to trace execution:
```lua
function YourAddon_UpdateItemButton(button, bagID, slotID)
    print(string.format("Button: bag=%d, slot=%d, hasItem=%s", bagID, slotID, tostring(button.hasItem)))
    -- Rest of code
end
```

### Styling

Use these common textures:
- `Interface\Buttons\WHITE8x8` - Solid color overlay
- `Interface\Buttons\CheckButtonHilight` - Highlight effect
- `Interface\AddOns\YourAddon\Textures\MyTexture` - Custom texture

### Frame Hierarchy

Keep it simple:
```
Button
├── Your Overlay Frame
│   ├── Texture (background)
│   ├── Texture (highlight)
│   └── FontString (text)
```

## Next Steps

1. Choose the example that matches your needs
2. Copy it to your addon
3. Customize for your use case
4. Read [ITEM_BUTTON_API.md](../ITEM_BUTTON_API.md) for detailed API info
5. Read [INTEGRATION_GUIDE.md](../INTEGRATION_GUIDE.md) for best practices

Happy integrating!
