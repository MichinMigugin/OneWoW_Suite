# OneWoW Development Environment

Manual and agent-assisted setup for the dual-root Cursor / VS Code workspace used
to develop OneWoW Suite.

**Quickest path:** open the Suite clone in Cursor and ask:

> Set up my OneWoW development environment

That loads the `onewow-dev-setup` skill, which probes your machine, asks about
gaps, and runs [`bin/setup_dev_env.py`](../bin/setup_dev_env.py).

This README is the full manual procedure and the source of truth for what the
script does.

## Layout after setup

Templates in this folder are **committed** with the Suite repo. Host-local files
live **outside** the clone (paths are machine-specific / sibling folders):

```
<parent>/
  OneWoW_Workspace.code-workspace   # merged from this folder's template
  _OneWoW_Offline/
    .luarc.json                     # from offline.luarc.json (ignore-all dropzone)
  OneWoW_Suite/                     # this git clone
```

`_OneWoW_Offline` is an analysis dropzone only. Its `.luarc.json` ignores every
directory so LuaLS does not index third-party trees you drop there. Suite’s own
root `.luarc.json` is already correct in the clone — do not replace it from
`devconfig/`.

## Prerequisites

- **Python 3.12+** on `PATH` (`python` / `python3`, or Windows `py -3`).
  The setup script will not silently install Python. On Windows it can offer
  `winget install -e --id Python.Python.3.12`; on macOS `brew install python@3.12`;
  on Linux it prints distro guidance only.
- **Cursor** (preferred) or VS Code, with the CLI available as `cursor` or `code`
  for extension installs.

## Automated setup

From the Suite repo root (with Python 3.12+ already available):

```bash
python bin/setup_dev_env.py
```

Useful flags (also used by the Cursor skill after questions are answered):

| Flag | Meaning |
| --- | --- |
| `--yes` | Non-interactive defaults (overwrite differing offline luarc, create workspace if missing) |
| `--workspace PATH` | Use this `.code-workspace` file instead of discovering one |
| `--skip-extensions` | Do not install marketplace or Ketho VSIX extensions |
| `--skip-python-tools` | Skip `pip install` / `pre-commit install` |
| `--install-python` | Attempt assisted Python 3.12 install when missing/old (Win/macOS only) |

The script:

1. Verifies Python ≥ 3.12 (optionally assists install).
2. Creates `<parent>/_OneWoW_Offline` and installs `offline.luarc.json`.
3. Finds or creates `<parent>/OneWoW_Workspace.code-workspace` and **merges**
   template folders / settings (never deletes unrelated personal keys; strips
   absolute `ketho.wow-api-*` library paths while keeping `.lua-defs`).
4. Installs marketplace extensions (see below) via `cursor`/`code`.
5. Downloads the latest [Ketho WoW API](https://github.com/Ketho/vscode-wow-api/releases)
   VSIX and installs it (not on the Cursor marketplace).
6. Runs `python -m pip install pre-commit -r bin/requirements.txt` and
   `python -m pre_commit install`.
7. Prints validation results and any human follow-ups (open the workspace file,
   reload Cursor / LuaLS so Ketho can write its `Lua.workspace.library` entries).

## Manual setup

### 1. Python and pre-commit

```bash
python --version   # need 3.12+
python -m pip install pre-commit -r bin/requirements.txt
python -m pre_commit install
```

### 2. Offline dropzone

Next to the Suite folder (same parent directory):

```bash
mkdir _OneWoW_Offline
cp OneWoW_Suite/devconfig/offline.luarc.json _OneWoW_Offline/.luarc.json
```

### 3. Workspace file

Copy [`OneWoW_Workspace.code-workspace`](OneWoW_Workspace.code-workspace) to the
**parent** of `OneWoW_Suite` (so the relative folder paths resolve). If you
already have a `.code-workspace` there, merge in:

- Both `folders` entries (`_OneWoW_Offline`, `OneWoW_Suite`)
- `settings.files.exclude` for `**/_OneWoW_Offline/**`
- All template `Lua.*` keys and `wowAPI.luals.defineKnownGlobals` /
  `wowAPI.luals.frameXML`

Do **not** copy personal `editor.*`, `git.blame.*`, or similar keys from someone
else’s machine. Do **not** hard-code a `ketho.wow-api-…/Annotations/Core` path;
Ketho adds its library entries after install (reload the window if they are
missing).

Open the workspace file in Cursor (`File → Open Workspace from File…`).

### 4. Extensions

Marketplace (also listed in [`.vscode/extensions.json`](../.vscode/extensions.json)):

- `bierner.github-markdown-preview`
- `sumneko.lua`
- `bierner.markdown-preview-github-styles`
- `bierner.markdown-mermaid`
- `ms-python.python`

`anysphere.cursorpyright` ships with Cursor — no separate install.

**Ketho WoW API** — download the latest `wow-api-*.vsix` from
[releases](https://github.com/Ketho/vscode-wow-api/releases), then:

```bash
cursor --install-extension /path/to/wow-api-x.y.z.vsix
# or: code --install-extension /path/to/wow-api-x.y.z.vsix
```

After install, reload the window so LuaLS picks up Ketho’s annotations. Suite
keeps `wowAPI.luals.defineKnownGlobals` and `frameXML` **false** so the
extension does not fight the repo’s `.luarc.json` globals list.

## What syncs vs what stays local

| In the Suite git clone | Outside the clone (host-local) |
| --- | --- |
| `devconfig/*` templates | `OneWoW_Workspace.code-workspace` |
| Suite `.luarc.json`, `.vscode/` | `_OneWoW_Offline/` and its `.luarc.json` |
| `bin/setup_dev_env.py`, this README | Installed extensions, Python, pre-commit hooks |

## Troubleshooting

- **Wrong Python:** ensure `python`/`python3` on PATH is 3.12+, not a leftover
  3.9/3.10 from another tool.
- **Extension CLI not found:** install the Cursor/VS Code shell command, or
  install extensions from the UI / VSIX manually.
- **LuaLS still noisy on Offline:** confirm `_OneWoW_Offline/.luarc.json` has
  `"workspace.ignoreDir": ["*"]` and that you opened the **multi-root workspace**,
  not the Suite folder alone.
- **Missing WoW API completions:** confirm `ketho.wow-api-*` exists under
  `~/.cursor/extensions/` (or `~/.vscode/extensions/`), then reload the window.
