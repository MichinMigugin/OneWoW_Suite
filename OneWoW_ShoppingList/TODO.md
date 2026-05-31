# OneWoW_ShoppingList — TODO

Features that have been considered or partially scaffolded but are not yet exposed to the user. Moved here from the README so the README only describes what actually ships.

---

## Lists

### User-created sub-lists
The data model and sidebar already render arbitrary parent → child nesting, and `ShoppingList:CreateList(name, parentName)` accepts a parent argument. However, no UI affordance ever passes the second argument — every caller (`+ New List` button, profession "Make List", import paths, etc.) creates top-level lists only. As a result, the only sub-lists you'll see in practice are auto-generated **Craft Orders**.

**Suggested next step:** add a "Create sub-list under [parent]" entry to the list right-click menu (`MainWindow:ShowListContextMenu`). The data layer is already in place.

### Custom item categories / tags
Group items within a list by user-defined category (e.g. "Vendor", "Auction House", "Farm"). Not represented in the data model — items are flat `{ itemID, quantity, addedTime, notes }` records.

---

## Search

### Cross-list search
The search box currently filters only the active list (`MainWindow:RefreshItemList` walks the active `list.items`). A "global" search mode would walk `ShoppingList:GetAllLists()` and surface matches with their owning list name.

---

## Sorting

### User-selectable sort mode
Items are currently sorted by status priority (red → yellow → blue → green) with alphabetical tiebreaker — a fixed combined sort. Add a UI control to switch between alphabetical-only, priority-only, recently-added, or manual ordering.

---

## Item lifecycle

### Manual "mark complete" toggle
Status is currently auto-derived from `owned ≥ needed` in `ShoppingList:GetItemStatus`. There is `RemoveCompletedItems` (auto-strips everything green) but no per-item user toggle. A manual toggle would let users hide / strike-through items independently of the inventory math.

### Add item by name in the primary UI
`ShoppingList:AddItemByName` exists in code but the only path that calls it is the import dialog, which converts entries to `unresolvedItems` for later scanning. A dedicated "Add by name" input on the main window — resolving names live via `C_Item.GetItemInfoInstant` — would make name-based adds first-class.

---

## Notifications

### Audio alerts
No `PlaySound` calls anywhere today. Add a configurable sound (with picker in settings) when a tracked loot drop occurs.

### Visual alerts
Loot alerts only `print(...)` to chat. A toast/popup, screen flash, or item-icon flyout would be more visible.

### Per-list alert disable
Currently alerts fire for any item on any list, gated only by a global 60-second per-item cooldown. Add a `list.alertsEnabled` flag plus a context-menu toggle so users can mute alerts per list.

---

## Customization

### Resizable / scalable window
Window dimensions are fixed via `Constants.GUI.WINDOW_WIDTH` / `WINDOW_HEIGHT`. Add a resize handle (and/or a scale slider in settings) so users can fit the addon to their UI.

### Bag overlay position / scale / alpha settings
The data model already stores `overlay.position`, `overlay.scale`, `overlay.alpha`, but the settings panel only exposes the on/off checkbox. Surface those existing fields as sliders / a position picker.
