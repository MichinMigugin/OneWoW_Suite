**OneWoW Mail** replaces the default mailbox UI with a OneWoW-styled shell and adds **Shipments** — planned sends to characters or roles using the same search language as Bags.

**Requires:** [OneWoW](Home) core. Enable **Mail** under [Manage Features](Getting-Started) when it is in your package. Companion Storage / Character data helps alt addressing and in-transit tracking.

**Open:** `/1wmail` · `/owmail` (see [Slash commands](Slash-Commands))

---

## What you get

### Mailbox shell

* Inbox with filtered collect actions (selection, Shift-loot / Ctrl-return style workflows)
* Compose with OneWoW chrome and address suggestions (alts across realms)
* Activity / run log for send and collect results
* Auction House mail can show richer invoice breakdown where supported

### Shipments

Define reusable shipment plans:

* Target a **character** or a **role** (roles are suite-wide alt groups)
* Match bag items with [search expressions](Bags-Search-Syntax) (keep / max / restock style rules)
* Distribute across role members (fill first, round-robin, or equal split)
* Auto-run can skip members already successfully shipped this session

### Other helpers

Extras such as disenchantable dumps and excess-gold style utilities live on supporting tabs — explore the shell once Mail is enabled.

---

## Tips

* Practice a simple character shipment before role-wide distributes.
* Shipment match rules use English `#` keywords like Bags — see [Search syntax](Bags-Search-Syntax).
* Open the mailbox at a mailbox NPC; Mail takes over the Blizzard frame while enabled.

## Related

* [Bags search syntax](Bags-Search-Syntax)
* [AltTracker](AltTracker)
* [Slash commands](Slash-Commands)

### Sources

* [OneWoW_Mail/Docs/ARCHITECTURE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Mail/Docs/ARCHITECTURE.md) — engineering reference (no separate player README yet)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
