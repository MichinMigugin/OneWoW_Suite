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
- Auto-collect Gold and/or Items when the mailbox opens (before shipments); toggles persist account-wide
- Return or delete checked mail in bulk; shift-click collects one mail, ctrl-click returns it
- Expand any mail to read the message body and see every attachment
- Always keeps a configurable number of bag slots free while collecting; reagent mail can use the reagent bag

## Compose
- Address book suggestions as you type: your alts, favorites, recent recipients, contacts, friends, and guild
- Warns before mailing someone who is not one of your known alts

## Shipments
- Reusable mailing profiles for items or gold (each shipment is one or the other)
- Item profiles pick bag items with search rules (Bags search syntax)
  - Per-item send rules: keep an amount on this character, cap the amount per run, or only top up what the target is missing (uses AltTracker inventory, including mail still in transit)
  - Soulbound items are always excluded; stacks are split safely so exactly the planned amount is sent
- Gold profiles send excess gold with leave-on-character, send-up-to cap, and until-target-has top-up (uses AltTracker gold plus mail still in transit)
- Preview shows what a shipment would send before you commit; item names use quality colors
- Preset item shipments included to start from: Cloth, Leather, Metal/Ore, Herbs, Disenchantables
- Auto-run setting per shipment: Manual only, Auto with review, or Auto send immediately
  - Frequency: once per game session (default, retries until success) or every mailbox open
  - Auto shipments send on their own when you open a mailbox
  - Review-first shipments are held on the Activity tab until you click Process

## Activity
- Shows shipments waiting for review, with Process and Discard buttons
- Closing the mailbox with pending review asks whether to Process, Exit, or Go Back
- Session log of what was sent, skipped, or failed — expandable rows with timeout vs item vs server detail; errors also go to chat
- Auto-run logs an info line when a shipment has nothing to send (for example the target already has enough gold), with the reason
- One failed mail does not stop the rest of an automatic run

---

# AltTracker
## Summary
- Account Overview gold includes suite mail gold still in transit (so mailing an alt does not undercount the account total)
  - Tooltip breaks out Characters, Warband, and In Transit
- Gold column shows last-known wallet gold; a gold status dot appears when that character has gold in transit
  - Hover shows on-character, in-transit, and virtual total
- Summary roster and the mail detail popup refresh when in-transit mail is collected or updated

## Financials
- Each gold event is stored as its own ledger row (no more merging same-category mail or other activity within a few minutes)

---

*No user-facing changes this release for Catalog, QoL, Bags, Notes, Trackers, Shopping List, Direct Deposit, or DevTool.*

---

- **Release**: TBD
- **Version**: TBD
- **Status**: Draft
