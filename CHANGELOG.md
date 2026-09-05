# OneWoW Suite Changelog

## Home
- Catalog data stores on Home and in Manage Features are Zone Database, NPC Database, Item Database, Quest Database, Quest Archive Database, and TradeSkill Database.

---

# Catalog
## Data
- Catalog data packs are smaller, so those tabs open with less hitching. Item icons and types come from the game when you look at a row. Quest Archive no longer carries a second copy of the same generated tables.

## Item Search
- Item Search lists items Catalog already has a source for: a drop, a vendor, a quest, a recipe, or an achievement. Typing a name no longer fills the list with items we have nothing to show.
- Opening Item Search loads the Items pack so the list can fill. Choosing Drops, Vendors, Crafted, Quests, or Owned loads that pack the same way.
- Collectible details can show achievements for an item when that item is a reward or a criterion.

## Collectibles and Housing
- Catalog has Collectibles and Housing tabs next to Item Search. Collectibles lists transmog, mounts, pets, and toys with live collected status. Housing lists decor and owned, stored, and placed counts when the game reports them.
- Opening those tabs does not stall. The list stops at 50 rows, or 100 when you filter or search, then asks you to narrow it.
- Details show journal source text plus vendors, drops, quests, and a world rare when we know one. Those extra lines appear when that pack is already loaded. Click a vendor, instance, or quest to open that Catalog tab (that click loads the pack if needed). Achievements appear only when we have an id.
- Collectibles and Housing can show Collected Only or Not Collected Only. Housing uses owned decor for that.

## Vendors
- The list is people you can talk to: shops, trainers, innkeepers, repair, stables, flight masters, bankers, barbers, and quest givers. Talking to someone who is missing adds them. Click a quest giver name to open that card. Search by NPC id as well as name.

## Journal
- Extra drops that come from a quest or an achievement sit in their own groups again. Click the quest link to open that quest.

## Quests
- Show on Map uses the NPC database pin for the giver or turn-in, including object starters.
- Talking to a quest giver fills missing Catalog quest text and rewards again.
- Click the giver or turn-in name to open that person in Catalog NPCs. A quest you pick up that we did not ship is saved.

---

# AltTracker
## Data
- Quest completion from the old Catalog Quests pack is copied into the Quest Database. Vendor categories you set are copied into the NPC Database.

---

# DevTool
## Textures
- Double-click a region on a texture sheet to add its name to a collected list. Copy the whole list when you are ready, or Clear it. Double-click the same region again to take that name off the list.

---

# QoL
## Tooltips
- Item Tracker on item tooltips now has two blocks: Where it is (your copies) and Where to get it (quest, vendor, instance, profession). Those source lines appear when that Catalog pack is already loaded.

---

*No user-facing changes this release for Bags, Mail, Notes, Shopping List, or Trackers.*

---

- **Last Updated**: Sep 4, 2026
