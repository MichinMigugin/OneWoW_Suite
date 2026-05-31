# OneWoW Inspect Mog

Experimental standalone OneWoW addon for a sidecar panel on Blizzard's Inspect frame.

## Goal

When inspecting another player, show a compact list of visible gear slots with:

- equipped item name/link
- detected transmog appearance/source when available
- clear highlighting when the appearance differs from the equipped item's native look

## Why Standalone First

This is intentionally separate from `OneWoW_QoL` while the inspect/transmog API behavior is proven. Once stable, it can either remain a small standalone OneWoW addon or become a QoL overlay module.

## Current Prototype

- Creates `OneWoW_InspectMog` as an independent addon.
- Hooks the Blizzard Inspect frame.
- Requests inspect data safely through `NotifyInspect`.
- Builds rows from inspected unit equipment slots.
- Uses `C_TransmogCollection.GetInspectItemTransmogInfoList()` when available.
- Resolves transmog source names through `C_TransmogCollection.GetSourceInfo`.

## Follow-Up

- Verify exact source/appearance field names returned by Retail's inspect transmog API.
- Add OneWoW QoL registration if this graduates into the QoL module list.
- Add options UI for side, hide unchanged slots, and show empty slots.
- Add ctrl-click dressing room preview once inspected source IDs are confirmed.
