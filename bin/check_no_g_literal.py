#!/usr/bin/env python3
"""Pre-commit hook: forbid `_G.literalName` access in Lua files.

Allowed:
    UIParent                          -- bare global, the canonical form
    _G["GameTooltipTextLeft" .. i]    -- bracket access with computed key

Forbidden:
    _G.UIParent                       -- literal field access on _G

The `_G.` literal form is never necessary: either the name is known at edit
time (use it directly) or it's computed (use the bracket form). Decorating
call sites with `_G.` masks unknown-global warnings from the LSP and adds
visual noise. See .cursor/rules/OneWoW-Lua-Conventions.mdc.

Behavior:
    * Skips lines that are pure single-line comments (start with `--`).
    * Strips inline comments before checking (anything after `--`).
    * Tracks `--[[ ... ]]` block comments at line granularity.
    * Known limitation: a literal string containing `_G.foo` will produce a
      false positive. Vanishingly rare in practice; suppress with a targeted
      `-- noqa: _G` comment on the offending line if it ever happens (the
      hook treats `noqa` as an inline-comment escape via the strip step).
"""

from __future__ import annotations

import re
import sys

PATTERN = re.compile(r"_G\.[A-Za-z_]\w*")


def check_file(path: str) -> list[tuple[int, str, str]]:
    """Return list of (lineno, matched_token, full_line_stripped)."""
    violations: list[tuple[int, str, str]] = []
    in_block_comment = False

    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except (OSError, UnicodeDecodeError) as e:
        print(f"{path}: error reading file: {e}", file=sys.stderr)
        return []

    for lineno, line in enumerate(lines, 1):
        # Block comment tracking: --[[ ... ]]
        # Crude but adequate; full Lua comment grammar (long brackets with
        # =-padding like --[==[ ... ]==]) is rare in addon code.
        if in_block_comment:
            if "]]" in line:
                in_block_comment = False
            continue

        # Detect block comment start that doesn't close on the same line.
        if "--[[" in line:
            after = line.split("--[[", 1)[1]
            if "]]" not in after:
                in_block_comment = True
            # Whether or not it closes on this line, anything after --[[
            # is comment, so strip it before checking.
            line_to_check = line.split("--[[", 1)[0]
        else:
            line_to_check = line

        stripped = line_to_check.lstrip()
        if stripped.startswith("--"):
            # Pure comment line.
            continue

        # Strip inline single-line comment.
        if "--" in line_to_check:
            line_to_check = line_to_check.split("--", 1)[0]

        m = PATTERN.search(line_to_check)
        if m:
            violations.append((lineno, m.group(0), line.rstrip()))

    return violations


def main(argv: list[str]) -> int:
    rc = 0
    for path in argv[1:]:
        for lineno, token, line in check_file(path):
            print(f"{path}:{lineno}: forbidden literal access: {token}")
            print(f"    {line}")
            rc = 1

    if rc:
        print()
        print("Fix: drop the `_G.` prefix and use the bare global, or use")
        print("`_G[expr]` if the key is computed.")
        print("If the LSP flags an unknown global, add it to .luarc.json")
        print("`diagnostics.globals` (after verifying it actually exists).")
        print("Reference: .cursor/rules/OneWoW-Lua-Conventions.mdc")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
