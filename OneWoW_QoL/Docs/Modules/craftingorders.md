# Crafting Orders Overlay

Module id: `craftingorders` · Folder: `Modules/external/craftingorders/`

Replaces Blizzard's right-hand crafter order table on the profession Crafting
Orders page. Left recipe list, Search, Favorites, Back, and public claims
remaining stay Blizzard.

## Browse

Hook `SetCraftingOrderType`, `ShowGeneric`, and `SendOrderRequest` on the
`OrdersPage` instance (XML mixin copies those methods; mixin-table hooks after
`Blizzard_Professions` loads do not fire). Hide `BrowseFrame.OrderList` while
the overlay is shown. Patron / Guild / Personal are always a flat order list.

- **Tabs:** Public, Guild, Personal, Patron (`Enum.CraftingOrderType`).
- **Buckets:** Craftable now, Missing mats, and Recipe Unlearned. Public search
  results stay bucketed until you drill into a recipe; Ready/Missing is exact on
  flat lists. Unlearned never sits in Missing mats. Features can hide the
  Recipe Unlearned section.
  Rows use the same striped `BACKDROP_INNER` chrome as Catalog lists.
  Column headers share the same right-edge lanes as the row widgets.
  Each You Provide / Customer Provides / You Receive cluster is a fixed-width
  lane packed left-to-right, so unused slots cannot slide icons into the next
  column. Features owns the layout: show, hide, and reorder those lanes
  (Order name stays pinned left). Gold and Profit / Loss start hidden.
  Icon sizes and "only mats I still need" are sliders and a checkbox on the
  same panel. Reset restores the default view.
  The layout applies in place (no frame rebuilds): slider changes resize
  the existing icons live via `ApplyOverlayLayout`. Icon lanes reserve
  width only for the icon slots the current entry list actually uses
  (`SetLaneCounts`, derived on each refresh, min-width floor for header
  labels); hidden columns cost zero width. Slider values are the
  preference and render as-is while the visible columns fit the row.
  When they do not (many columns, large icons), `IconSizes` scales every
  icon - lanes and product - down by one shared factor, exactly enough
  that every visible column fits with the Order name at its minimum
  width (binary search over the factor; `SIZE_MIN` floor). No column
  ever hides or clips in normal use; the per-row clipping host
  (`LaneStripBudget`) exists only as a last-resort guard below the size
  floor. The overlay reports its interior width via `SetRowContentWidth`
  on create/show/resize.
- **Mats:** You Provide vs Customer Provides icon columns. Customer Provides is
  every reagent already allocated on the order (`order.reagents` covers that
  slot). You Provide is required recipe slots with no allocation. Owned count
  is bags + character bank + reagent bank + warband bank. Rewards are
  item/currency/gold icons with counts. Optional Gold shows the commission as
  a money string. Optional Profit / Loss is tip minus consortium cut, plus
  valued reward items, minus valued You Provide reagents (customer mats are
  not subtracted). Prices come from `OneWoW.ItemPrices` (TSM, Auctionator, or
  OneWoW scan). A missing price skips that term; nothing is invented.
  Its header reads `+ / -` (identical in every locale) with the price
  source's icon flush right: TSM / Auctionator show their addon icon,
  OneWoW shows the suite icon (`FACTION_ICONS.neutral`). The full
  "Profit / Loss" name stays on the Features panel.
- **Cart:** one shopping-cart control per row that still needs crafter mats
  (Missing mats and Recipe Unlearned), in its own column.
- **Default off:** the overlay is off until you turn the module on in QoL
  Features. That On/Off is account-wide (every character).
- **Incompatible addons:** if PatronOffers or PublicOrdersReagentsColumn
  (No Mats No Make) is enabled, Crafting Orders cannot be turned on. Features
  names the addon and asks you to disable it and try again. Off fully
  restores Blizzard's list.
- **WoW UI:** a **WoW UI** / **One UI** button sits on the order-type tab row
  (and a Features toggle) to swap back to Blizzard's table without disabling
  the module. A gear beside it opens this module in QoL Features.
- **Craftable now:** recipe learned and every crafter-provided required reagent
  is in bags, bank, reagent bank, or warband bank. Fully customer-supplied
  counts as now.
- **Patron sort:** knowledge points, then Artisan's Acuity, then gold.
- **Personal:** right-click Decline matches Blizzard (`RejectOrder`).

Weekly "Services Requested" quest IDs live in `rewards.lua` (Midnight first,
Khaz Algar fallback). Public claims use `GetOrderClaimInfo`, not the weekly.

## Cross-unit

- Shopping List: `OneWoW_ShoppingList_API` (`AddItems`, `CreateNamedList`,
  active list). Call-time presence plus `RegisterDataReadyWatcher`. No
  `OptionalDeps`.
- Item prices: `OneWoW.ItemPrices:GetUnitAHPriceFrom` for the Profit / Loss
  column. No direct TSM / Auctionator calls and no `OptionalDeps` for those
  addons.
- Storage elsewhere: hover a You Provide icon; uses
  `OneWoW_AltTracker_Storage_API.GetItemIndex()` after data-ready, then
  `RegisterStorageChanged`.

## Magic button

Click-mirrors Blizzard Start / Create / Complete via
`InsecureActionButtonTemplate` and a short `/click` chain. The inner click
target stays shown (alpha 0) because `/click` ignores hidden frames. The
visible button stays on `OrderInfo` (left) for Start, Craft, and Complete so
the mouse does not move. It wears the standard suite button chrome by hand
(`BACKDROP_INNER`, `BTN_NORMAL`/`BTN_HOVER`/`BTN_PRESSED`, themed border,
muted label when disabled) since it cannot be a `CreateFitTextButton`.
Concentration is an icon beside Craft, tooltip only.
Does not call `ClaimOrder` from Lua. Create-time attributes go through
`RunWhenUnrestricted`; PreClick sets `clickbutton` only when unprotected.
`OrderView:SetOverrideCastBarActive` is no-op'd while the module is on (restore
on disable) so the stock override bar does not fight secrets.
