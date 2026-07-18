# OneWoW Mail — Architecture

Standalone LoD load unit that replaces the Blizzard mailbox UI with a OneWoW_GUI shell and adds logistics **Shipments** powered by `OneWoW.PredicateEngine`.

## Load & lifecycle

- TOC: `OneWoW_Mail.toc` (`RequiredDeps: OneWoW`, `LoadOnDemand: 1`)
- Manifest: `OneWoW/Core/AddonLoader.lua` (`/1wmail`)
- FirstRun: standalone catalog entry with datastores Storage, Character, Professions
- Init: `OneWoW_Mail:OnAddonLoaded` / `OnPlayerLogin` (no suite lifecycle `RegisterEvent`)
- Gameplay: `MAIL_SHOW` / `MAIL_CLOSED` / `MAIL_INBOX_UPDATE` on the Shell frame

## Modules

| Area | Role |
|------|------|
| `UI/Shell.lua` | Hide Blizzard `MailFrame`, tab host (Inbox / Compose / Shipments / Other) |
| `UI/Inbox.lua` | Filtered collect buttons, selection, Shift-loot / Ctrl-return |
| `UI/Compose.lua` | OneWoW Compose chrome; hidden native `SendMailFrame` via NativeSend |
| `Engine/NativeSend.lua` | Activate/deactivate `SetSendMailShowing` + park Blizzard send frame |
| `UI/Shipments.lua` | Shipment editor (PE match, keep/max/restock) |
| `UI/Other.lua` | DE dump, excess gold, session rake |
| `Engine/Collect.lua` | `C_Mail.IsCommandPending` paced take; COD/GM skip |
| `Engine/MailClassify.lua` | AH invoice + subject classification |
| `Engine/AddressBook.lua` | Alts (all realms) + normalize + suggestions |
| `Engine/ShipmentEvaluator.lua` | PE match + keepQty/maxQty/restock → jobs |
| `Engine/SendQueue.lua` | Sequential `SendMail` jobs |
| `Engine/InTransit.lua` | Writes recipient Storage in-transit on suite-alt send |

## Cross-unit

- `OneWoW.Disenchant` — `#disenchantable` / `#de` (PE keyword)
- `OneWoW_AltTracker_Storage_API` — `AddInTransitShipment` / `GetInTransitShipments` / `ClearInTransitBySubject` (recipient key via `AddressBook:ResolveCharKey` → `OneWoW_GUI:GetCharacterKey`)
- Accounting / Storage loot hooks left intact (TakeInbox* still classified there)

## Branding

- TOC / Manage Features: `Interface\Icons\achievement_guildperk_gmail`
- UI atlas: `Crosshair_mail_*`
