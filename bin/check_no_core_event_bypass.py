#!/usr/bin/env python3
"""Pre-commit hook: forbid registering core-owned WoW events outside their owner.

Some WoW events are funneled into a single core service (a "funnel owner") that
registers them via the core `ns.RegisterEvent` multiplexer, lazily on first
subscriber, and fans out to consumers through scan/show/closed callback
channels. No other file in the suite may register those events directly — see
OneWoW/Docs/ARCHITECTURE.md §3.10 / §8.8 and OneWoW/Docs/MERCHANT.md.

The `EVENT_OWNER` registry below maps each core-owned event name to the single
file (by basename) allowed to register it. Adding a new funnel is a one-line
registry addition (the "move the event into core, then add it to the ban list"
pattern).

What it flags: a string-literal `RegisterEvent("<owned-event>"` — matching both
`frame:RegisterEvent(...)` and the core `ns.RegisterEvent(...)` funnel-entry form
— in any in-scope file whose basename is not the registry's owner for that event.

Naturally exempt (no allowlist needed):
  - The core Events.lua multiplexer registers via a *variable*
    (`frame:RegisterEvent(event)`), never a string literal, so it never matches.
  - The funnel owners (e.g. Merchant.lua) register from a *variable* loop over an
    EVENTS table, so they don't match either; the owner entry simply permits a
    literal registration in that file if one is ever added.
  - The DevTool Constants.lua event catalog holds bare event-name strings in
    tables, not `RegisterEvent("…")` calls.

In scope: files under the `OneWoW` / `OneWoW_*` top-level dirs (`.wow_docs/` and
`Libs/` are excluded via .pre-commit-config.yaml).

Escape hatch: -- noqa: core-event-funnel on the offending line.
"""

from __future__ import annotations

import os
import re
import sys

# event name -> owning service file (basename) that may RegisterEvent it.
# Add a row when a new event is funneled into a core service.
EVENT_OWNER = {
    "MERCHANT_SHOW": "Merchant.lua",
    "MERCHANT_UPDATE": "Merchant.lua",
    "MERCHANT_CLOSED": "Merchant.lua",
    "TRADE_SKILL_SHOW": "ProfessionRecipe.lua",
    "TRADE_SKILL_LIST_UPDATE": "ProfessionRecipe.lua",
    "TRADE_SKILL_CLOSE": "ProfessionRecipe.lua",
    "NEW_RECIPE_LEARNED": "ProfessionRecipe.lua",
    "ADDON_RESTRICTION_STATE_CHANGED": "Restriction.lua",
    "BAG_UPDATE": "Inventory.lua",
    "BAG_UPDATE_DELAYED": "Inventory.lua",
    "BAG_CONTAINER_UPDATE": "Inventory.lua",
    "BAG_UPDATE_COOLDOWN": "Inventory.lua",
    "ITEM_LOCK_CHANGED": "Inventory.lua",
    "BANKFRAME_OPENED": "Inventory.lua",
    "BANKFRAME_CLOSED": "Inventory.lua",
    "BANK_TABS_CHANGED": "Inventory.lua",
    "PLAYERBANKSLOTS_CHANGED": "Inventory.lua",
    "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED": "Inventory.lua",
    "GUILDBANKFRAME_OPENED": "Inventory.lua",
    "GUILDBANKFRAME_CLOSED": "Inventory.lua",
    "GUILDBANKBAGSLOTS_CHANGED": "Inventory.lua",
    "GUILDBANK_ITEM_LOCK_CHANGED": "Inventory.lua",
    "GUILDBANK_UPDATE_TABS": "Inventory.lua",
    "GUILDBANK_UPDATE_MONEY": "Inventory.lua",
    "GUILDBANK_UPDATE_WITHDRAWMONEY": "Inventory.lua",
}

# Case-sensitive `RegisterEvent(` (capital R) so `UnregisterEvent(` /
# `UnregisterAllEvents(` (lowercase r after "Un") never match. The negative
# lookbehind rejects a larger identifier like `FooRegisterEvent`, while allowing
# `frame:RegisterEvent` / `ns.RegisterEvent`.
_EVENT_NAMES = "|".join(re.escape(e) for e in EVENT_OWNER)
FORBIDDEN_RE = re.compile(
    r"(?<![A-Za-z0-9_])RegisterEvent\s*\(\s*[\"'](" + _EVENT_NAMES + r")[\"']"
)


def normalize_path(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def in_scope(path: str) -> bool:
    norm = normalize_path(path)
    top = norm.split("/", 1)[0]
    return top == "OneWoW" or top.startswith("OneWoW_")


def strip_comments(line: str, state: str) -> tuple[str, str]:
    """Return (comment-free line, carry-over state), keeping string literals.

    Unlike the restriction hook's strip_code, string *contents* are preserved
    because the thing we detect (the event name) lives inside a string literal.
    Only `--` line comments and `--[[ ]]` block comments are removed; a `--`
    inside a string is not treated as a comment.
    """
    out: list[str] = []
    i, n = 0, len(line)
    while i < n:
        if state == "block":
            end = line.find("]]", i)
            if end == -1:
                return "".join(out), "block"
            state = "normal"
            i = end + 2
            continue

        ch = line[i]
        if ch == '"' or ch == "'":
            # Consume and keep the whole string literal.
            out.append(ch)
            i += 1
            while i < n:
                if line[i] == "\\":
                    out.append(line[i : i + 2])
                    i += 2
                    continue
                out.append(line[i])
                if line[i] == ch:
                    i += 1
                    break
                i += 1
            continue

        if line[i : i + 4] == "--[[":
            state = "block"
            i += 4
            continue
        if line[i : i + 2] == "--":
            break  # line comment: drop the rest

        out.append(ch)
        i += 1

    return "".join(out), state


def has_noqa(raw_line: str) -> bool:
    if "--" not in raw_line:
        return False
    return "noqa: core-event-funnel" in raw_line.split("--", 1)[1]


def check_file(path: str) -> list[tuple[int, str, str]]:
    """Return (line number, event, owner) for each disallowed registration."""
    if not in_scope(path):
        return []

    basename = os.path.basename(normalize_path(path))

    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: error reading file: {e}", file=sys.stderr)
        return []

    violations: list[tuple[int, str, str]] = []
    state = "normal"
    for lineno, raw in enumerate(lines, 1):
        code, state = strip_comments(raw, state)
        if not code:
            continue
        for match in FORBIDDEN_RE.finditer(code):
            event = match.group(1)
            owner = EVENT_OWNER[event]
            if basename != owner and not has_noqa(raw):
                violations.append((lineno, event, owner))

    return violations


def main(argv: list[str]) -> int:
    rc = 0
    for path in argv[1:]:
        for lineno, event, owner in check_file(path):
            print(
                f"{path}:{lineno}: RegisterEvent(\"{event}\") is owned by {owner} "
                f"- consume the core funnel instead of registering it here"
            )
            rc = 1

    if rc:
        print()
        print("Core-owned events are registered only by their funnel service and")
        print("delivered through its scan/show/closed callback channels:")
        print("  MERCHANT_* -> OneWoW.Merchant (RegisterScanCallback / RegisterShowCallback /")
        print("                RegisterClosedCallback / IsMerchantOpen). See OneWoW/Docs/MERCHANT.md.")
        print("  TRADE_SKILL_* / NEW_RECIPE_LEARNED -> OneWoW.ProfessionRecipe (RegisterScanCallback /")
        print("                RegisterOpenCallback / RegisterShowCallback / RegisterLearnedCallback /")
        print("                RegisterClosedCallback / IsTradeskillOpen). See OneWoW/Docs/PROFESSION_RECIPE.md.")
        print("  BAG_* / BANKFRAME_* / ITEM_LOCK_CHANGED / BANK_TABS_CHANGED /")
        print("  PLAYERBANKSLOTS_* / GUILDBANK* -> OneWoW.Inventory (RegisterDirtyCallback /")
        print("                RegisterDelayedCallback / RegisterBank* / RegisterGuild* /")
        print("                RegisterLockCallback / RegisterCooldownCallback / …).")
        print("                See OneWoW/Docs/INVENTORY.md.")
        print("Reference: OneWoW/Docs/ARCHITECTURE.md sections 3.10 / 8.7 / 8.8 / 8.9")
        print("Suppress (rare): add -- noqa: core-event-funnel on the line.")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
