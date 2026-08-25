# OneWoW Suite Changelog

# Home
- The website link now opens onewow.net.
- Map waypoints from Trackers, vendors, NPCs, and hearth now place on maps that allow them.

---

# Trackers
- Kill a Dungeon or Raid Boss tracks Adventure Guide encounters. Fill from current encounter during the fight or just after you win.
- Fill from target cannot read creatures or NPCs inside a dungeon or raid. The editor tells you to use Kill a Dungeon or Raid Boss, or to fill the ID in the open world.
- Restore Examples brings back the Dusting for Moths collection list.
- The step editor groups optional fields into collapsible sections.
- The step editor can build every tracker type the addon ships, including nested objectives, Great Vault and profession tasks, loot, timers, campaigns, and exploration.
- Typing a quest, item, NPC, or collectible ID in the editor shows its name.
- Faction, profession, and holiday gates hide steps that do not apply to you. Steps that require other steps cannot be checked off until those are done.
- A step with several objectives completes when every objective is done.
- New List, step types, and editor dialogs use your game language instead of English.
- Tracker category folders show in your game language, sorted alphabetically for that language.
- Checking off steps and scrolling a long tracker list feels snappier.
- Pin a list from the pin icon next to its title. List actions and Hide completed sit on the row under the title.
- Drag a section header or a step to reorder, including dropping a step onto another section. Right-click no longer has Move Up or Move Down.
- Hover a section or step for add, edit, and delete. Counts stay on the right; a divider sits above the section list.
- Tracker cards show type, category, and author.
- Farm value lists keep that pin icon next to the title.
- Finished tracker steps use a darker row fill so the done text stays readable.
- Step descriptions wrap to the panel width instead of truncating until the window is resized.
- Farm value details send pricing to QoL Tooltips Value, use dropdowns for session and list mode, and add watchlist items with the usual dropzone.
- Farm value lists put Delete next to Duplicate, with no gap for unused Reset or Add Section.
- Tracker list cards put the name and type up top, with progress along the bottom, so long titles no longer overlap.
- Repeating lists reset after a custom number of hours you set when creating or editing the list.
- Custom Timer steps stay checked off until their interval runs out, instead of clearing themselves right away.
- Tracker categories are topic folders: singular names, no Dailies or Weeklies, and mounts, pets, toys, and transmog sit under Collection.
- Clear on the Tracker tab also resets type, category, and Hide Done.

---

# Catalog
## Fixes
- Catalog no longer errors when you log in.
- Catalog no longer errors when you browse older expansion quests.
- Catalog no longer freezes when you move between tabs, open Journal quest items, or look at your quest log.
- Clicking a quest card highlights that card the same way Journal, Vendors, and Item Search do.

## Quests
- Quest list cards use that expansion's Adventure Guide background, with a border for Campaign, Story, Legendary, and other quest types.
- Opening a quest no longer hitches while reward names and NPC names load. Names fill in a moment later.
- Picking an expansion or changing completion filters no longer freezes the list. Completed and warband matches appear as they are found.
- Quest Chain on the detail pane is a numbered list that wraps with the panel. The quest you have open is highlighted. Other steps stay clickable links; completion is not scanned for the whole chain.
- Opening a quest in a chain lists the whole chain on the left, in step order. Clicking another step keeps that list. The open quest stays in its place instead of jumping to the top.
- The Quests pack is Midnight and The War Within. Classic through Dragonflight load from Quest Archive when you browse those expansions, search all quests, or look up rewards.
- Quest Archive is one addon for Classic through Dragonflight.
- Midnight, The War Within, Dragonflight, and Shadowlands lists have the pins and text we have. Battle for Azeroth through Classic will get that same fill soon.
- Midnight search now includes 12.1 Coiled Isle / Ula'tek quests (about 400 new entries). Older Midnight pins and text were kept.
- About 100 more Midnight quests now have giver pins, and more of them show quest text.
- About 280 more Dragonflight quests, and more of them have giver pins.
- About 270 more Shadowlands quests, and more of them have giver pins.
- A quest only appears in one expansion. Burning Crusade quests sit under Burning Crusade.
- More quests show a turn-in pin when we already know that NPC's location.

## Journal
- Zone, city, and other cards without their own art now use that expansion's Adventure Guide background. Classic Silvermoon uses Classic; Midnight Silvermoon uses Midnight.
- Cards use a type-colored border for raid, dungeon, world, zone, city, Delve, and bountiful Delve.
- Logging in no longer stalls on Journal.
- Opening the Journal tab no longer rebuilds every dungeon and raid. Reloading in a dungeon or Delve stays responsive. Opening a dungeon or raid card no longer hitches while every item loads.
- Loot names and quality colors show the first time you open a card, instead of turning up after you click away and back. Item Search also matches every Adventure Guide loot name, including items the client has never seen.
- Has uncollected no longer freezes the game while it checks every card. Matching cards appear as they are found.
- Journal data is about 23 MB smaller, so it loads faster and uses far less memory. Item Search drops, item detail drop lists, and the item tooltip's instance lines are unchanged.
- Opening the first card in an expansion is quicker. The Journal no longer sifts the whole expansion to find extra drops.
- The item count on a card no longer changes when you open it, and World cards show their real item count instead of 0.
- Loot on a card now matches the Adventure Guide. Extra drops with a known boss or rare sit on that encounter, including bosses or rares OneWoW did not already list. Unplaced extras stay under General Loot.
- Extra drops now include world drops, expansion-feature loot, and holiday or world-event items that belong on a zone or World card, not only dungeon trash and outdoor rares.
- Dungeon, raid, and zone cards pick up more NPC drops the Adventure Guide never listed. More outdoor rares now sit on the zone they live in.
- World cards list World Bosses and World Rares, each with their own loot, and show a rares count next to bosses (for example 4 Bosses | 13 Rares). A drop that comes from several rares is listed on each rare. World cards also include that expansion's exploration achievements (Explore, Adventurer, Treasures). Source icons on encounters and loot mark Adventure Guide (WoW) or shipped OneWoW data.
- Zone and city cards now list that place's Explore achievement, Skyriding Glyphs when the title names the city, and world rares we already shipped with a known map.
- When AllTheThings is loaded, the Journal filter bar shows ATT Detected and can add anything AllTheThings has live.
- Instance Type includes World. Classic through Cataclysm get a World card; later expansions use the Adventure Guide outdoor hubs.
- Instance Type also lists Zones and Cities. The World hub stays the full list for that expansion. A pin on a rare, boss, or achievement opens that place's card when we know the zone. Cities and outdoor zones for every expansion ship with Journal, including City of Threads, Tazavesh, and Midnight's Quel'Thalas zones (Eversong Woods, Silvermoon City, Harandar, Voidstorm, Isle of Quel'Danas, Zul'Aman, The Coiled Isle).
- Instance cards get a map pin next to the favorite star, and the same pin sits on the details toolbar. Click it to open the world map and drop a waypoint at the entrance. Gold pins are Wowhead locations for doors the client has not published yet. Siege of Niuzao Temple, Blackwing Lair, The MOTHERLODE!!, Operation: Mechagon, and Blackrock Depths now have pins.
- Journal cards and details show a dungeon, raid, or Delve icon next to the type. Bountiful delves use the bountiful icon. Delve cards use the official entrance background.
- Instance Type now includes Delves (The War Within and Midnight). Show Bountiful sits next to Has uncollected and keeps only this week's bountiful doors; it clears when you close Catalog or press Clear. Bountiful cards use a gold border when the filter is off.
- Details list achievements above items, and the section collapses like loot. Cards show the achievement count next to bosses and items. Status uses a check, Warband mark, and X. The check is green when you earned it; the Warband icon stays its normal color when the Warband has it and a grey account mark when it does not; the X is soft orange when it is still incomplete. Click a row to open it in Achievements.
- Delves keep the Difficulty dropdown on the details toolbar so the map pin lines up with dungeons and raids. It stays disabled.
- Dungeons and raids get an Adventure Guide button on the details toolbar.

## Vendors
- The Vendors tab lists shops from Classic through Midnight before you visit them: stock, costs, and map pins when we have them. Opening a merchant still fills gaps.
- Shops you have not opened yet show Unseen on the details pane. Visit that NPC to add their portrait and live prices.
- Names, zones, and item names fill in as you look at a vendor. Type and price lines only show when we know them.
- Housing shops ship as Decor. Quartermaster, PvP, Guild, and Delve shops get those types when we can tell. A quartermaster who also sells housing stays Quartermaster.
- Opening a merchant can fill Uncategorized or General, and can upgrade a type we set to one of those specials. Types you pick yourself stick unless you leave them Uncategorized or General.
- Normal shop items show their gold price. Token and reputation costs still come from the merchant when we do not already have them.
- Filter vendors by expansion, like Quests.
- Quartermaster / Renown and Quest Giver cards use a matching border. Other vendor types stay on the usual edge.

---

# DevTool
- The Sounds tab lists game audio again.

---

# AltTracker
## Auctions
- Search sits on its own row and stretches across the bar so alt, realm, and filter buttons no longer hang off the window.

---

# Bags
- Search settings use ASCII punctuation for the Search Shortcuts note so it shows in every suite font.

---

# QoL
## Vendor Panel
- Saved filters and the gear button add items and switch to the sell list so you can sell right away.

---

*No user-facing changes this release for Mail, Shopping List, Notes, or Direct Deposit.*

---

- **Last Updated**: Aug 25, 2026
