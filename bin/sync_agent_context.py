#!/usr/bin/env python3
"""Sync cross-agent context from canonical .cursor/ sources.

Generates (never hand-edit these):
  - .agents/skills/<name>/SKILL.md   Codex discovery stubs (redirect to canonical)
  - .claude/skills/<name>/SKILL.md   Claude discovery stubs (optional `paths:`)
  - AGENTS.md generated regions       rules-globs table + skills index (between markers)

Canonical sources (hand-edited; this script only reads them):
  - .cursor/rules/*.mdc               rule frontmatter (description, globs, alwaysApply)
  - .cursor/skills/*/SKILL.md         skill frontmatter (name, description)
  - .cursor/agent-context.yaml        manifest: Claude `paths:` per skill

Usage:
  python bin/sync_agent_context.py            # write generated files
  python bin/sync_agent_context.py --check    # exit 1 if anything is stale (no writes)
  python bin/sync_agent_context.py --dry-run  # print diffs, write nothing
"""
from __future__ import annotations

import argparse
import difflib
import re
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
CURSOR = REPO_ROOT / ".cursor"
SKILLS_DIR = CURSOR / "skills"
RULES_DIR = CURSOR / "rules"
MANIFEST = CURSOR / "agent-context.yaml"
AGENTS_MD = REPO_ROOT / "AGENTS.md"
AGENTS_SKILLS = REPO_ROOT / ".agents" / "skills"
CLAUDE_SKILLS = REPO_ROOT / ".claude" / "skills"

NAME_MAX = 64       # Agent Skills spec
DESC_MAX = 1024     # Codex limit

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)

STUB_BODY = (
    "# Stub \u2014 not the source of truth\n"
    "\n"
    "Read and follow the canonical skill before doing any work:\n"
    "\n"
    "`.cursor/skills/{name}/SKILL.md`\n"
    "\n"
    "Apply all instructions from that file. This stub exists only for agent "
    "skill discovery.\n"
)


class SyncError(Exception):
    """Raised on any canonical-source or manifest problem."""


def read_text(path: Path) -> str:
    """Read a file and normalize all line endings to LF."""
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")


def frontmatter_block(path: Path) -> str:
    """Return the raw frontmatter block (between the leading --- fences).

    A tolerant line parser is used instead of a YAML loader because Cursor
    `.mdc` files store globs unquoted (e.g. ``globs: **/*.lua``), which is not
    valid YAML (``*`` begins an alias). The fields we need (name, description,
    globs, alwaysApply) are all single-line scalars.
    """
    text = read_text(path)
    m = FRONTMATTER_RE.match(text)
    if not m:
        raise SyncError(f"{path}: missing frontmatter")
    return m.group(1)


def field(block: str, key: str) -> str | None:
    """Extract a single-line scalar value for ``key`` from a frontmatter block."""
    m = re.search(rf"^{re.escape(key)}:[ \t]*(.*)$", block, re.MULTILINE)
    if not m:
        return None
    val = m.group(1).strip()
    if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
        inner = val[1:-1]
        if val[0] == '"':
            inner = inner.replace('\\"', '"').replace("\\\\", "\\")
        return inner
    return val


def yaml_dq(value: str) -> str:
    """Render a value as a double-quoted YAML scalar (handles quotes/backslashes)."""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def load_skills() -> list[dict]:
    if not SKILLS_DIR.is_dir():
        raise SyncError(f"Missing skills dir: {SKILLS_DIR}")
    skills: list[dict] = []
    for d in sorted(p for p in SKILLS_DIR.iterdir() if p.is_dir()):
        skill_file = d / "SKILL.md"
        if not skill_file.is_file():
            continue
        block = frontmatter_block(skill_file)
        name = field(block, "name")
        desc = field(block, "description")
        if not name or not desc:
            raise SyncError(f"{skill_file}: 'name' and 'description' are required")
        if name != d.name:
            raise SyncError(
                f"{skill_file}: name '{name}' must equal parent dir '{d.name}'"
            )
        if len(name) > NAME_MAX:
            raise SyncError(f"{skill_file}: name exceeds {NAME_MAX} chars")
        if len(desc) > DESC_MAX:
            raise SyncError(
                f"{skill_file}: description is {len(desc)} chars (max {DESC_MAX})"
            )
        skills.append({"name": name, "description": desc})
    if not skills:
        raise SyncError(f"No skills found under {SKILLS_DIR}")
    return skills


def load_manifest(skill_names: list[str]) -> dict[str, list[str] | None]:
    if not MANIFEST.is_file():
        raise SyncError(f"Missing manifest: {MANIFEST}")
    data = yaml.safe_load(read_text(MANIFEST)) or {}
    entries = data.get("skills") or {}
    if not isinstance(entries, dict):
        raise SyncError(f"{MANIFEST}: 'skills' must be a mapping")
    canonical = set(skill_names)
    listed = set(entries.keys())
    missing = canonical - listed
    extra = listed - canonical
    if missing:
        raise SyncError(f"Manifest missing skills: {sorted(missing)}")
    if extra:
        raise SyncError(f"Manifest lists unknown skills: {sorted(extra)}")
    paths: dict[str, list[str] | None] = {}
    for name, cfg in entries.items():
        cfg = cfg or {}
        value = cfg.get("claude_paths")
        if value is not None and not isinstance(value, list):
            raise SyncError(f"Manifest {name}: claude_paths must be a list or null")
        paths[name] = value
    return paths


def load_rules() -> list[dict]:
    rules: list[dict] = []
    for f in sorted(RULES_DIR.glob("*.mdc")):
        block = frontmatter_block(f)
        always = (field(block, "alwaysApply") or "false").strip().lower() == "true"
        rules.append(
            {
                "file": f.name,
                "globs": field(block, "globs"),
                "alwaysApply": always,
            }
        )
    return rules


def codex_stub(name: str, desc: str) -> str:
    return (
        "---\n"
        f"name: {name}\n"
        f"description: {yaml_dq(desc)}\n"
        "metadata:\n"
        f"  canonical: .cursor/skills/{name}/SKILL.md\n"
        "  stub-for: codex\n"
        "---\n" + STUB_BODY.format(name=name)
    )


def claude_stub(name: str, desc: str, paths: list[str] | None) -> str:
    lines = ["---", f"name: {name}", f"description: {yaml_dq(desc)}"]
    if paths:
        lines.append("paths:")
        lines.extend(f"  - {yaml_dq(p)}" for p in paths)
    lines.append("---")
    return "\n".join(lines) + "\n" + STUB_BODY.format(name=name)


def render_rules_globs(rules: list[dict]) -> str:
    groups: dict[str, list[str]] = {}
    for r in rules:
        if r["alwaysApply"] or not r["globs"]:
            continue
        groups.setdefault(str(r["globs"]), []).append(r["file"])
    lines = ["| Glob(s) | Rule(s) |", "| --- | --- |"]
    for globs in sorted(groups):
        tokens = [t.strip() for t in globs.split(",") if t.strip()]
        glob_cell = ", ".join(f"`{t}`" for t in tokens)
        rule_cell = ", ".join(f"`{rf}`" for rf in sorted(groups[globs]))
        lines.append(f"| {glob_cell} | {rule_cell} |")
    return "\n".join(lines)


def render_skills_index(skills: list[dict]) -> str:
    lines = ["| Skill | Use when | Canonical file |", "| --- | --- | --- |"]
    for s in skills:
        lines.append(
            f"| `{s['name']}` | {s['description']} | "
            f"`.cursor/skills/{s['name']}/SKILL.md` |"
        )
    return "\n".join(lines)


def replace_region(text: str, tag: str, body: str) -> str:
    begin = f"<!-- BEGIN GENERATED: {tag} -->"
    end = f"<!-- END GENERATED: {tag} -->"
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.DOTALL)
    if not pattern.search(text):
        raise SyncError(f"AGENTS.md missing markers for '{tag}'")
    replacement = f"{begin}\n{body}\n{end}"
    return pattern.sub(lambda _m: replacement, text)


def build_agents_md(skills: list[dict], rules: list[dict]) -> str:
    if not AGENTS_MD.is_file():
        raise SyncError(f"Missing {AGENTS_MD} (create it with generated markers first)")
    text = read_text(AGENTS_MD)
    text = replace_region(text, "rules-globs", render_rules_globs(rules))
    text = replace_region(text, "skills", render_skills_index(skills))
    if not text.endswith("\n"):
        text += "\n"
    return text


def process(path: Path, content: str, *, check: bool, dry_run: bool,
            changed: list[Path]) -> None:
    existing = read_text(path) if path.exists() else None
    if existing == content:
        return
    changed.append(path)
    rel = path.relative_to(REPO_ROOT)
    if check:
        print(f"STALE: {rel}")
        return
    if dry_run:
        print(f"--- would update {rel} ---")
        diff = difflib.unified_diff(
            (existing or "").splitlines(),
            content.splitlines(),
            fromfile=f"a/{rel}",
            tofile=f"b/{rel}",
            lineterm="",
        )
        print("\n".join(diff))
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    print(f"wrote {rel}")


def prune_orphans(base: Path, names: set[str], *, check: bool, dry_run: bool,
                  changed: list[Path]) -> None:
    """Remove stub dirs whose skill no longer exists in .cursor/skills/."""
    if not base.exists():
        return
    for d in sorted(p for p in base.iterdir() if p.is_dir()):
        if d.name in names:
            continue
        changed.append(d)
        rel = d.relative_to(REPO_ROOT)
        if check:
            print(f"ORPHAN: {rel}")
        elif dry_run:
            print(f"would remove {rel}")
        else:
            for f in sorted(d.rglob("*"), reverse=True):
                if f.is_file():
                    f.unlink()
                else:
                    f.rmdir()
            d.rmdir()
            print(f"removed {rel}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Sync cross-agent context files.")
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if any generated file is stale (no writes)")
    ap.add_argument("--dry-run", action="store_true",
                    help="print diffs without writing")
    args = ap.parse_args()

    try:
        skills = load_skills()
        names = [s["name"] for s in skills]
        manifest = load_manifest(names)
        rules = load_rules()
        agents_md = build_agents_md(skills, rules)
    except SyncError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    changed: list[Path] = []
    for s in skills:
        name, desc = s["name"], s["description"]
        process(AGENTS_SKILLS / name / "SKILL.md", codex_stub(name, desc),
                check=args.check, dry_run=args.dry_run, changed=changed)
        process(CLAUDE_SKILLS / name / "SKILL.md",
                claude_stub(name, desc, manifest.get(name)),
                check=args.check, dry_run=args.dry_run, changed=changed)

    name_set = set(names)
    prune_orphans(AGENTS_SKILLS, name_set, check=args.check, dry_run=args.dry_run,
                  changed=changed)
    prune_orphans(CLAUDE_SKILLS, name_set, check=args.check, dry_run=args.dry_run,
                  changed=changed)

    process(AGENTS_MD, agents_md, check=args.check, dry_run=args.dry_run,
            changed=changed)

    if args.check:
        if changed:
            print(f"\n{len(changed)} file(s) out of date. "
                  f"Run: python bin/sync_agent_context.py")
            return 1
        print("ok: all generated files up to date")
        return 0
    if not changed:
        print("ok: nothing to update")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
