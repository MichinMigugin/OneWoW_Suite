# OneWoW Suite Changelog

## Overlays
- New icons under Bags & Items → Icon:
  - Consumables, Equipment, Reagents, Trade Goods, Profession Goods, Scrappable
  - Transmog tick, warning, and disabled
  - Loot roll transmog
- New Alt Collected overlay — shows which recipes an alt knows

## Fixes
- Item level overlay: upgrade detection and no longer appearing on items it shouldn't
- Items no longer show dimmed in the Warband bank from misaligned bank-allowed vs item-context updates

---

# Mail
## New Addon
- **OneWoW Mail** — a full mailbox replacement focused on multi-character logistics
- Opens automatically at any mailbox; also `/owmail` or `/1wmail`

## Inbox
- Collect gold and attachments selectively: All, Gold, Items, AH Sold, AH Bought, AH Cancelled, AH Expired, Other, or just the mail you checked
- Return or delete checked mail in bulk; shift-click collects one mail, ctrl-click returns it
- Expand any mail to read the message body and see every attachment
- Always keeps a configurable number of bag slots free while collecting; reagent mail can use the reagent bag

## Compose
- Address book suggestions as you type: your alts, favorites, recent recipients, contacts, friends, and guild
- Warns before mailing someone who is not one of your known alts

## Shipments
- Reusable mailing profiles that pick items from your bags with search rules (Bags search syntax)
- Per-item send rules: keep an amount on this character, cap the amount per run, or only top up what the target is missing (uses AltTracker inventory)
- Soulbound items are always excluded; stacks are split safely so exactly the planned amount is sent
- Preview shows what a shipment would send before you commit
- Preset shipments included to start from: Cloth, Leather, Metal/Ore, Herbs, Disenchantables
- Auto-run setting per shipment: Manual only, Auto with review, or Auto send immediately
  - Auto shipments send on their own when you open a mailbox
  - Review-first shipments are held on the Activity tab until you click Process

## Activity
- Shows shipments waiting for review, with Process and Discard buttons
- Session log of what was sent, skipped, or failed; errors also go to chat
- One failed mail does not stop the rest of an automatic run

## Other
- Send excess gold to your banker in one click, keeping a set amount on this character
- Tracks how much gold you collected from mail this visit

---

*No user-facing changes this release for AltTracker, Catalog, QoL, Bags, Notes, Trackers, Shopping List, Direct Deposit, or DevTool.*

---

- **Release**: TBD
- **Version**: TBD
- **Status**: Draft
