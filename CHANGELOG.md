# OneWoW Suite Changelog

# OneWoW
## Home
- Summary “needs attention” no longer counts features you turned off on purpose (soft or hard); it lists real issues (version mismatch, load failures, missing data packs) and lets you dismiss non-critical ones

## Search
- `#geartoken` finds Use: loot-spec gear tokens (e.g. Baleful); distinct from `#contexttoken` (season/reagent context tokens)
- `#myclass` / `forclass=` also match class-restricted Use: tokens (Classes: tooltip line), not only equippable gear; `#myspec` stays equipment-only

# QoL

## Portals
- Added Corewarden's Hearthstone

# Mail
## Settings
- Gear on the tab bar opens a compact settings popover with a slider for how long to wait for send confirmation (5–30 seconds; default 8) — raise it if laggy connections cause false timeouts

## Fixes
- Shipments no longer try to mail the character you are on (Character targets and Role members); Blizzard rejects self-mail

---

# Catalog
- Soft-requires AltTracker Storage (BringUp pulls it with Catalog); without Storage, Catalog stays usable but Home marks it diminished

## Tradeskills
- Dropped the “Professions” and “Recipe Details” panel titles so more room goes to the list and detail
- Recipe detail matches Journal/Vendors: `Expansion | Profession` under the name, one `Recipe ID | Item ID` line (Item ID omitted when none), no repeated Profession/Expansion rows
- Profession filter is a dropdown (not a button grid); filter bars are shorter so the list starts higher
- Recipe list rows show a muted `Expansion | Profession` line under the name (omits what’s already implied by the active filters / expansion groups)
- Reagent quantities show account-wide have/need (`12/15`) when Storage is available; otherwise the old `x15` style
- On Hand section lists owned reagents for the selected recipe; expand a row for owner / location / quantity breakdown
- Have Materials filter (right header) shows only recipes whose required reagents you own across Storage; expansion dropdown sits above the known checkboxes like Journal

---

*No user-facing changes this release for AltTracker, Bags, DirectDeposit, Notes, ShoppingList, Trackers, or Vendors.*

---

- **Last Updated**: Aug 6, 2026
