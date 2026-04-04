# OneWoW Bags API - Complete Index

Welcome to the OneWoW Bags integration API! This folder contains everything you need to integrate your addon with OneWoW Bags to add custom overlays and decorations to item buttons.

## Start Here

**New to OneWoW Bags integration?**

1. Read [README.md](./README.md) - Overview and quick start (5 min)
2. Follow [INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md) - Step-by-step setup (15 min)
3. Pick an example from [Examples/](./Examples/) - Copy and customize

**Ready to code?**

1. Copy an example file to your addon
2. Reference [ITEM_BUTTON_API.md](./ITEM_BUTTON_API.md) while coding
3. Test by opening OneWoW Bags

## File Overview

### Documentation Files

| File | Purpose | Read Time |
|------|---------|-----------|
| [README.md](./README.md) | Overview, quick start, common use cases | 5 min |
| [INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md) | Step-by-step setup and implementation guide | 15 min |
| [ITEM_BUTTON_API.md](./ITEM_BUTTON_API.md) | Complete API reference and troubleshooting | Reference |
| [INDEX.md](./INDEX.md) | This file - Navigation guide | 5 min |

### Examples

| File | Purpose | Use When |
|------|---------|----------|
| [Examples/Basic.lua](./Examples/Basic.lua) | Simple template with comments | Learning the basics |
| [Examples/TransmogLootHelper.lua](./Examples/TransmogLootHelper.lua) | Real-world working example | Making a transmog addon |
| [Examples/ColorOverlay.lua](./Examples/ColorOverlay.lua) | Colored texture overlay implementation | Highlighting items by color |
| [Examples/TextBadge.lua](./Examples/TextBadge.lua) | Text badge on items | Displaying numbers/prices |
| [Examples/README.md](./Examples/README.md) | Example descriptions and patterns | Understanding examples |

## Quick Reference

### Register a Callback

```lua
if _G.OneWoW_Bags then
    _G.OneWoW_Bags:RegisterItemButtonCallback("MyAddon", MyCallback)
end

function MyCallback(button, bagID, slotID)
    -- Your code here
end
```

### Get Item Information

```lua
local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

if C_Item.DoesItemExist(itemLocation) then
    local itemLink = C_Item.GetItemLink(itemLocation)
    local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    -- Process item
else
    -- Empty slot
end
```

### Create an Overlay

```lua
if not button.MyOverlay then
    button.MyOverlay = CreateFrame("Frame", nil, button)
    button.MyOverlay:SetAllPoints(button)
    button.MyOverlay:SetFrameLevel(button:GetFrameLevel() + 1)
end
```

## Integration Paths

### Path 1: I'm New (Recommended)

1. Read [README.md](./README.md) - 5 minutes
2. Copy [Examples/Basic.lua](./Examples/Basic.lua) to your addon
3. Follow the comments and customize
4. Reference [ITEM_BUTTON_API.md](./ITEM_BUTTON_API.md) as needed

**Total time: 20-30 minutes**

### Path 2: I Know WoW Addons

1. Skim [INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md) - 10 minutes
2. Pick a relevant [Example](./Examples/) and copy it
3. Customize based on your needs
4. Reference API docs if stuck

**Total time: 15-20 minutes**

### Path 3: I'm Making a Transmog Addon

1. Copy [Examples/TransmogLootHelper.lua](./Examples/TransmogLootHelper.lua)
2. Update function names to match your addon
3. Reference [ITEM_BUTTON_API.md](./ITEM_BUTTON_API.md) section "Working with Items"
4. Test with OneWoW Bags

**Total time: 10-15 minutes**

### Path 4: I Need Help

1. Check [ITEM_BUTTON_API.md - Troubleshooting](./ITEM_BUTTON_API.md#troubleshooting)
2. Look for a similar example in [Examples/](./Examples/)
3. Read [INTEGRATION_GUIDE.md - Best Practices](./INTEGRATION_GUIDE.md#best-practices)
4. Debug using the patterns in [Examples/README.md](./Examples/README.md#tips--tricks)

## Common Questions

### How do I get started?

Copy [Examples/Basic.lua](./Examples/Basic.lua) to your addon and follow the comments.

### Where do I find example code?

Check [Examples/](./Examples/) folder. It has four ready-to-use examples for different use cases.

### What API functions are available?

See [ITEM_BUTTON_API.md](./ITEM_BUTTON_API.md#api-functions) for the complete API reference.

### How do I debug if something doesn't work?

See [ITEM_BUTTON_API.md - Troubleshooting](./ITEM_BUTTON_API.md#troubleshooting) for common issues and solutions.

### Can I add multiple overlays?

Yes! Each addon can register its own callback. Different overlays won't conflict as long as you use unique property names (e.g., `button.MyAddonOverlay` instead of `button.overlay`).

### Is the integration automatic?

Yes! Once you add your integration file to your addon's `.toc` file, it loads and registers automatically when your addon loads.

### What if OneWoW Bags isn't installed?

The integration file checks for `_G.OneWoW_Bags` and only runs if it exists. If OneWoW Bags isn't installed, your addon continues working normally (users just won't see overlays in OneWoW Bags).

### Can I unregister my callback later?

Yes! Call:
```lua
_G.OneWoW_Bags:UnregisterItemButtonCallback("MyAddon")
```

### How often do callbacks fire?

Callbacks fire whenever OneWoW Bags updates item buttons, which is frequently as items are picked up, swapped, and displayed. Keep callbacks lightweight.

## Folder Structure

```
API/
├── README.md                          (Overview, start here)
├── INTEGRATION_GUIDE.md               (Step-by-step guide)
├── ITEM_BUTTON_API.md                 (API reference)
├── INDEX.md                           (This file)
└── Examples/
    ├── README.md                      (Example descriptions)
    ├── Basic.lua                      (Simple template)
    ├── TransmogLootHelper.lua         (Real-world example)
    ├── ColorOverlay.lua               (Colored overlay example)
    └── TextBadge.lua                  (Text badge example)
```

## Next Steps

Choose your path above and get started! You'll have a working integration in 15-30 minutes.

## Need Help?

- **API questions?** → [ITEM_BUTTON_API.md](./ITEM_BUTTON_API.md)
- **Setup questions?** → [INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md)
- **Example questions?** → [Examples/README.md](./Examples/README.md)
- **General questions?** → [README.md](./README.md)

Good luck! Welcome to the OneWoW Bags ecosystem.
