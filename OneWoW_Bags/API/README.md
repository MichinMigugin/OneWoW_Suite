# OneWoW Bags API & Integration Guide

Welcome! This folder contains everything you need to integrate your addon with OneWoW Bags.

## Quick Navigation

- **[START HERE](./INTEGRATION_GUIDE.md)** - How to integrate with OneWoW Bags
- **[API Reference](./ITEM_BUTTON_API.md)** - Complete API documentation
- **[Examples](./Examples/)** - Working code examples

## What is This?

OneWoW Bags provides a callback system that lets your addon add overlays, decorations, or custom UI elements to item buttons displayed in the OneWoW Bags interface.

## Who Should Read This?

- Addon developers who want to add overlays to OneWoW Bags items
- Authors of transmog tools, loot helpers, or any addon that marks items
- Anyone integrating with OneWoW Bags

## Five-Minute Quick Start

1. Copy `Examples/Basic.lua` to your addon folder
2. Rename it and add your custom logic
3. Add it to your addon's `.toc` file
4. Done! Your callback will fire when items appear

See [INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md) for detailed instructions.

## Common Use Cases

- **Transmog Overlays** - Mark items that match appearances you're looking for
- **Loot Filters** - Highlight items matching your criteria
- **Item Pricing** - Display market prices on items
- **Collection Status** - Show which mounts/pets you already have
- **Quest Items** - Mark quest-related items
- **Rarity Highlighting** - Custom rarity color schemes

## Support

Questions? Check the examples or read the full API reference.
