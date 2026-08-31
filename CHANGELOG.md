# OneWoW Suite Changelog

## Hub search
- The search box on the OneWoW title bar now follows live settings, features, and windows. Type a name or a short question (for example popup pins) to open the right page.

## Slash commands
- Some chat commands changed. If you used the old names in macros, update them.
  - Bag Bar is `/1wbb` (`/bagbar` and `/owbb` are gone)
  - Copy Text is `/1wcopytext` or `/1wct` (`/copytext` and `/ct` are gone)

## Value display
- Large gold amounts show separators (2,127,634 instead of 2127634). Value display in OneWoW Settings now applies to bags, Vendor Panel, Crafting Orders, Notes collectibles, Auto Repair, Direct Deposit, AFK, the ESC character panel, and the guild bank log.
- Value display shows a live example as you change the options. Turn thousand separators off if you want a plain number. White values apply to coin icons as well as letters, and start off so you get classic gold/silver/copper numbers.

---

# DevTool
## Errors
- `/1wdev` turns DEVMODE on or off. `/1wdt` still opens DevTools.

---

# AltTracker
- `/1wat status` and its season dialog are gone. `/1wat` still opens AltTracker.
- Added additional collection systems for AltTracker.

---

# Notes
## Unit menus
- Right-click Add Note on your player frame (or a party, raid, or nameplate) now creates or opens the note. It no longer errors.
- Add Mount Info and Match Mount show on that menu when Play Mounts is on (it is on by default).

## Zone notes
- Pinned zone windows have a minimize button on the title bar. The window shrinks to the name only, and it stays that way the next time you enter the zone. Double-click or Shift-click the title bar does the same.
- Hover checkboxes are both "show" now: Show Pins and Show Zone Notes. Checked means that pane is visible. Uncheck Show Zone Notes to keep only the pin list.
- Hide Scrollbar on that hover bar hides the pin list bar. The list still scrolls with the mouse wheel.

## Collectibles
- Opening Collectibles stays smooth when you have hundreds of items. Clicking a row no longer rebuilds the whole list.

## Display
- Pinned notes and zone windows scale from Notes settings (50% to 200%).

## OneWay Pins
- Pins can have an optional description. Hover a pin in the zone list or map legend to see title, description, and coordinates. Pins saved from Catalog Journal, Vendors, or Quests mention Catalog on the tooltip.
- The pin icon picker includes Blizzard minimap tracking icons (banker, auctioneer, mailbox, innkeeper, flight master, repair, stable master, trainers, food, reagents, and more).
- Minimap pins stay on the landmark while you walk. Pins outside the current zoom sit on the rim.
- Saving the same vendor, quest, or instance again does not create a second pin. Deleting that pin also removes leftover copies of the same location.
- Opening the world map (Pin on a vendor, or the map with pins on it) no longer errors.
- Zone defaults to This Map. The count under the list is Showing X of Y pins, so an empty list does not look like you have no pins. The list says No pins on this map when none match this zone.

---

# Trackers
## Settings
- Trackers has a Settings page. Scale all pinned lists (50% to 200%). Weekly Reset Day lives here.

## Map pins
- Minimap pins for pinned lists stay on the landmark while you walk.

---

# Catalog
## Lists
- The row you have selected shows a blue bar on the left, so it stays obvious next to type colors and in the Tradeskills list.

## Journal
- Delve cards show today's story on the type line. That name uses the Incomplete color only while you still need that variant. The count line shows remaining Stories progress until the achievement is complete. Details list each variant under Stories until that achievement is complete, with today's highlighted.
- Story names resolve for doors on another zone (Isle of Quel'Danas, Zul'Aman, The Coiled Isle), not only the zone you are standing in. Nemesis lairs still have no Stories row.
- Instance cards show Transmog, Toy, Housing, and the rest of those tags when the list first appears. Opening a card no longer takes two clicks to fill the tags or the boss and item counts.
- Quest loot rows show Completed or Not Completed. They no longer print the locale key name over the Type column.
- Long achievement names stop before Difficulty. They no longer sit on top of H, M, or M+.
- ATT Detected is a shield on the lower right of the Journal filter bar. Hover it for the extra-data note.
- Map Pin on a Delve opens that zone and marks the door. It no longer errors.

## Locations
- Vendors lists 95 more shops, and 358 extra map pins on shops Catalog already had.
- 212 more quests have a start pin.
- Journal extras added 3283 drops the Adventure Guide does not list. 8301 extra rows now have map coordinates.

## Vendors
- Zone, coordinates, Pin, and Save Pin sit on their own row under the NPC id, so long zone names no longer clip Save Pin at the minimum window width.
- Hover Pin or Save Pin for what each does. Pin opens that zone on the world map and sets a live waypoint. If the map refuses a waypoint, chat says so.
- After you save a vendor pin, Save Pin becomes Open Pin and jumps to that entry in Notes. Saving the same vendor on the same map again does not create a duplicate.

---

# Bags
## Display
- Bags, personal bank, warband bank, and guild bank each have their own window scale (50% to 200%).

---

# QoL
## Crafting Orders
- Gold is the amount you receive after the Consortium Cut. Hover Gold on a row for commission, Consortium Cut, and Your Cut (public recipe groups also show the average).
- Hover Profit / Loss on a row for that gold breakdown, each priced reward and You Provide material, and the total. Items with no price still show as Unknown. The + / - header still shows the price source (and the TSM string from QoL > Tooltips > Value).
- Compact View matches Blizzard's original row height. Icons shrink to fit. Icon size sliders apply when Compact View is off. Column width sliders still apply.
- The default view is Compact View on; columns You Provide, Cart, Profit / Loss, Time, and Craft (in that order); icons at 27; Profit / Loss prices from OneWoW; Hide unlearned recipes on; Only show mats I still need on. Gold, Customer Provides, and You Receive start hidden. Crafting Orders itself starts on. Reset in Features restores this view.
- Features has a width slider for each column you have shown. Those are maximums: columns shrink together if they do not all fit beside the order name. Hiding a column hides its slider.
- Hide list scrollbar in Features. The list still scrolls with the mouse wheel, and the bar hides when there is nothing to scroll.
- Dragging a column row in Features now changes the order. Use the handle on the right of the row.
- Cart takes no space on Craftable now (or public recipe groups) when no row can add mats.
- Time Left uses a short form (6 d 15 h 10 m) and no longer clips. Hover a row for the full duration.
- Opening professions or bag changes no longer error while Crafting Orders is on.

## Settings
- Weekly Reset Day moved to Settings > Trackers.

## Fixes
- Hovering map pins (delves, events, and similar) and trait currencies no longer errors.
- Starter profession tools (Blacksmith Hammer, Mining Pick, and the like) no longer show as uncollected transmog. Equipping them never added an appearance; the overlay stays off.
- Collections tooltip has Show status for non-collectable items (off by default). Turn it on to show gold Not Collectable on the type line for items that are not a collectible.

---

*No user-facing changes this release for Home, Shopping List, or Mail.*

---

- **Last Updated**: Aug 31, 2026
