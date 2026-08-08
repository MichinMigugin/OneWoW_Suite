---
name: onewow-dev-setup
description: Use when the user asks to set up their OneWoW development environment, configure the Cursor/VS Code dual-root workspace, create the _OneWoW_Offline dropzone, install Lua/Python/Markdown extensions (including Ketho WoW API), or install pre-commit tooling for OneWoW Suite.
---

# OneWoW Development Environment Setup

Onboard a developer’s machine for OneWoW Suite + sibling `_OneWoW_Offline`
analysis dropzone. Canonical manual docs: [`devconfig/README.md`](../../../devconfig/README.md).

## Trigger phrases

- “Set up my OneWoW development environment”
- Configure OneWoW Cursor workspace / Offline dropzone / Ketho / pre-commit

## Agent workflow (ask first)

Do **not** assume a greenfield machine. Probe, then ask only about gaps.

1. Confirm the open workspace includes the Suite clone (`OneWoW_Suite` repo root
   with `devconfig/` and `bin/setup_dev_env.py`).
2. Probe (read-only / light commands):
   - Python on PATH and version (`python` / `python3` / Windows `py -3`)
   - Sibling `_OneWoW_Offline/` and its `.luarc.json`
   - Parent `*.code-workspace` files (prefer `OneWoW_Workspace.code-workspace`)
   - Whether `cursor` or `code` CLI exists
3. Ask the user about anything ambiguous (multiple workspace files, overwrite
   differing Offline luarc, whether to install extensions / assist Python).
4. Run the setup script from the Suite root with flags that match their answers:

```bash
python bin/setup_dev_env.py
# after answers, common non-interactive form:
python bin/setup_dev_env.py --yes --workspace <path>
# optional skips:
python bin/setup_dev_env.py --yes --skip-extensions
python bin/setup_dev_env.py --yes --skip-python-tools
# only when user asked for assisted Python install (Win/macOS):
python bin/setup_dev_env.py --install-python
```

5. Report the script summary, validation notes, and human follow-ups:
   - Open the host workspace file (`File → Open Workspace from File…`)
   - Reload Cursor / LuaLS so Ketho can write its `Lua.workspace.library` entries
   - If Python was just installed, reopen the terminal and re-run setup

## What the script owns

| Action | Location |
| --- | --- |
| Create Offline dropzone + ignore-all `.luarc.json` | `<parent>/_OneWoW_Offline/` |
| Create/merge dual-root workspace | `<parent>/OneWoW_Workspace.code-workspace` (or chosen path) |
| Marketplace extensions | via `cursor`/`code` CLI |
| Ketho WoW API | latest VSIX from GitHub Releases |
| `pre-commit` + `bin/requirements.txt` | Suite clone |

Templates live under `devconfig/` (synced with git). Host workspace and offline
folder stay **outside** the repo.

## Merge rules (do not violate)

- Merge only dual-root `folders`, `files.exclude`, `Lua.*`, and
  `wowAPI.luals.defineKnownGlobals` / `frameXML`.
- Never write personal `editor.*`, `git.blame.*`, or similar keys from templates.
- Strip absolute `ketho.wow-api-*` library paths; keep
  `${workspaceFolder:OneWoW_Suite}/.lua-defs`. Ketho injects its own library
  after install + reload.
- Do **not** replace Suite root `.luarc.json` — it is already correct in the clone.

## Extensions

Marketplace (also `.vscode/extensions.json`):

- `bierner.github-markdown-preview`
- `sumneko.lua`
- `bierner.markdown-preview-github-styles`
- `bierner.markdown-mermaid`
- `ms-python.python`

Bundled with Cursor (do not install): `anysphere.cursorpyright`.

VSIX-only: [Ketho/vscode-wow-api releases](https://github.com/Ketho/vscode-wow-api/releases).

## Python

Require **3.12+**. Do not silently install. If missing/old, explain and only run
assisted install (`winget` / `brew`) when the user agrees. Linux: print distro
instructions only.
