#!/usr/bin/env python3
"""Set up the OneWoW dual-root Cursor / VS Code development environment.

Creates the sibling ``_OneWoW_Offline`` dropzone, merges the portable workspace
template into a host-local ``.code-workspace`` next to the Suite clone, installs
recommended extensions (including Ketho WoW API from GitHub Releases), and
installs Python tooling (pre-commit + ``bin/requirements.txt``).

Usage:
    python bin/setup_dev_env.py
    python bin/setup_dev_env.py --yes
    python bin/setup_dev_env.py --workspace /path/to/OneWoW_Workspace.code-workspace

See ``devconfig/README.md`` for the full manual procedure.
"""
from __future__ import annotations

import argparse
import json
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DEVCONFIG = REPO_ROOT / "devconfig"
TEMPLATE_WORKSPACE = DEVCONFIG / "OneWoW_Workspace.code-workspace"
TEMPLATE_OFFLINE_LUARC = DEVCONFIG / "offline.luarc.json"
DEFAULT_WORKSPACE_NAME = "OneWoW_Workspace.code-workspace"
OFFLINE_DIR_NAME = "_OneWoW_Offline"
SUITE_FOLDER_NAME = "OneWoW_Suite"
MIN_PYTHON = (3, 12)

MARKETPLACE_EXTENSIONS = [
    "bierner.github-markdown-preview",
    "sumneko.lua",
    "bierner.markdown-preview-github-styles",
    "bierner.markdown-mermaid",
    "ms-python.python",
]

# Settings keys the template owns. Personal editor/git.blame keys are never written.
TEMPLATE_SETTING_KEYS = (
    "files.exclude",
    "Lua.workspace.library",
    "wowAPI.luals.defineKnownGlobals",
    "wowAPI.luals.frameXML",
    "Lua.type.weakUnionCheck",
    "Lua.runtime.builtin",
    "Lua.runtime.version",
    "Lua.diagnostics.disable",
)

LUA_DEFS_LIBRARY = "${workspaceFolder:OneWoW_Suite}/.lua-defs"
KETHO_LIBRARY_RE = re.compile(r"ketho\.wow-api", re.IGNORECASE)
GITHUB_KETHO_RELEASES = (
    "https://api.github.com/repos/Ketho/vscode-wow-api/releases/latest"
)


class SetupError(Exception):
    """Fatal setup failure with a user-facing message."""


def eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def prompt_yes_no(question: str, *, default: bool, assume_yes: bool) -> bool:
    if assume_yes:
        return default
    suffix = " [Y/n] " if default else " [y/N] "
    while True:
        try:
            raw = input(question + suffix).strip().lower()
        except EOFError:
            return default
        if not raw:
            return default
        if raw in ("y", "yes"):
            return True
        if raw in ("n", "no"):
            return False
        print("Please answer y or n.")


def load_json(path: Path) -> Any:
    text = path.read_text(encoding="utf-8")
    # Allow trailing commas in workspace JSON (VS Code is permissive).
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def dump_json(path: Path, data: Any) -> None:
    path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def version_tuple(version: str) -> tuple[int, ...]:
    parts: list[int] = []
    for piece in version.split("."):
        digits = re.match(r"(\d+)", piece)
        if not digits:
            break
        parts.append(int(digits.group(1)))
    return tuple(parts) if parts else (0,)


def probe_python_executable(exe: str) -> tuple[str, tuple[int, ...]] | None:
    try:
        proc = subprocess.run(
            [
                exe,
                "-c",
                "import sys; print(sys.executable); "
                "print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return None
    if proc.returncode != 0:
        return None
    lines = [ln.strip() for ln in proc.stdout.splitlines() if ln.strip()]
    if len(lines) < 2:
        return None
    return lines[0], version_tuple(lines[1])


def find_python() -> tuple[str, tuple[int, ...]] | None:
    """Return (executable, version) for the best Python on PATH, preferring 3.12+."""
    candidates: list[str] = []
    if platform.system() == "Windows":
        candidates.extend(["py", "python", "python3"])
    else:
        candidates.extend(["python3", "python"])

    found: list[tuple[str, tuple[int, ...]]] = []
    for name in candidates:
        if name == "py" and platform.system() == "Windows":
            for flag in ("-3.12", "-3.13", "-3.14", "-3"):
                try:
                    proc = subprocess.run(
                        [
                            "py",
                            flag,
                            "-c",
                            "import sys; print(sys.executable); "
                            "print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')",
                        ],
                        check=False,
                        capture_output=True,
                        text=True,
                    )
                except OSError:
                    break
                if proc.returncode != 0:
                    continue
                lines = [ln.strip() for ln in proc.stdout.splitlines() if ln.strip()]
                if len(lines) >= 2:
                    found.append((lines[0], version_tuple(lines[1])))
                    if flag != "-3":
                        break
            continue
        hit = probe_python_executable(name)
        if hit:
            found.append(hit)

    if not found:
        return None
    ok = [f for f in found if f[1] >= MIN_PYTHON]
    pool = ok or found
    pool.sort(key=lambda item: item[1], reverse=True)
    return pool[0]


def print_python_install_guidance() -> None:
    system = platform.system()
    eprint(
        f"Python {MIN_PYTHON[0]}.{MIN_PYTHON[1]}+ is required for OneWoW tooling "
        "(locale scripts, pre-commit, setup)."
    )
    if system == "Windows":
        eprint("Install with winget:")
        eprint("  winget install -e --id Python.Python.3.12")
        eprint("Then reopen the terminal so PATH updates, and re-run this script.")
    elif system == "Darwin":
        eprint("Install with Homebrew:")
        eprint("  brew install python@3.12")
        eprint("Then ensure python3.12 is on PATH and re-run this script.")
    else:
        eprint("Install Python 3.12+ from your distro, for example:")
        eprint("  sudo apt install python3.12 python3.12-venv python3-pip   # Debian/Ubuntu")
        eprint("  sudo dnf install python3.12                              # Fedora")
        eprint("Then re-run this script.")


def assisted_install_python() -> bool:
    system = platform.system()
    if system == "Windows":
        cmd = ["winget", "install", "-e", "--id", "Python.Python.3.12"]
    elif system == "Darwin":
        cmd = ["brew", "install", "python@3.12"]
    else:
        eprint("Assisted Python install is not automated on Linux.")
        print_python_install_guidance()
        return False
    print(f"Running: {' '.join(cmd)}")
    try:
        proc = subprocess.run(cmd, check=False)
    except OSError as exc:
        eprint(f"Could not run installer ({exc}).")
        print_python_install_guidance()
        return False
    if proc.returncode != 0:
        eprint(f"Installer exited with code {proc.returncode}.")
        print_python_install_guidance()
        return False
    print(
        "Python installer finished. Re-open this terminal (or refresh PATH) "
        "and run setup again so the new interpreter is detected."
    )
    return True


def ensure_python(*, assume_yes: bool, install_python: bool) -> str:
    hit = find_python()
    if hit and hit[1] >= MIN_PYTHON:
        exe, ver = hit
        print(f"Python OK: {exe} ({'.'.join(str(p) for p in ver)})")
        return exe

    if hit:
        exe, ver = hit
        eprint(
            f"Found Python {'.'.join(str(p) for p in ver)} at {exe}, "
            f"but {MIN_PYTHON[0]}.{MIN_PYTHON[1]}+ is required."
        )
    else:
        eprint("No Python interpreter found on PATH.")

    print_python_install_guidance()
    want = install_python or prompt_yes_no(
        "Attempt assisted Python 3.12 install now?",
        default=False,
        assume_yes=assume_yes and install_python,
    )
    if want:
        assisted_install_python()
    raise SetupError(
        "Python 3.12+ is required. Install it, then re-run "
        "`python bin/setup_dev_env.py`."
    )


def parent_dir() -> Path:
    return REPO_ROOT.parent


def offline_dir() -> Path:
    return parent_dir() / OFFLINE_DIR_NAME


def discover_workspaces() -> list[Path]:
    parent = parent_dir()
    if not parent.is_dir():
        return []
    return sorted(parent.glob("*.code-workspace"))


def choose_workspace_path(
    *,
    explicit: Path | None,
    assume_yes: bool,
) -> Path:
    if explicit is not None:
        return explicit.resolve()

    found = discover_workspaces()
    preferred = parent_dir() / DEFAULT_WORKSPACE_NAME

    if not found:
        print(f"No workspace file found; will create {preferred}")
        return preferred

    if preferred in found and (
        assume_yes
        or prompt_yes_no(
            "Merge OneWoW defaults into this workspace file?",
            default=True,
            assume_yes=assume_yes,
        )
    ):
        print(f"Found workspace: {preferred}")
        return preferred

    if len(found) == 1:
        only = found[0]
        print(f"Found workspace: {only}")
        if assume_yes or prompt_yes_no(
            "Use this workspace file?",
            default=True,
            assume_yes=assume_yes,
        ):
            return only
        print(f"Will create {preferred} instead.")
        return preferred

    print("Multiple workspace files in the parent directory:")
    for i, path in enumerate(found, start=1):
        print(f"  {i}. {path.name}")
    if assume_yes:
        return preferred if preferred in found else found[0]
    while True:
        raw = input(
            f"Choose 1-{len(found)}, or press Enter to use/create "
            f"{DEFAULT_WORKSPACE_NAME}: "
        ).strip()
        if not raw:
            return preferred
        if raw.isdigit() and 1 <= int(raw) <= len(found):
            return found[int(raw) - 1]
        print("Invalid choice.")


def required_folders() -> list[dict[str, str]]:
    return [
        {"name": OFFLINE_DIR_NAME, "path": OFFLINE_DIR_NAME},
        {"name": SUITE_FOLDER_NAME, "path": SUITE_FOLDER_NAME},
    ]


def normalize_library(entries: Any) -> list[str]:
    if not isinstance(entries, list):
        entries = []
    out: list[str] = []
    seen: set[str] = set()
    for item in entries:
        if not isinstance(item, str):
            continue
        if KETHO_LIBRARY_RE.search(item):
            continue
        if item in seen:
            continue
        seen.add(item)
        out.append(item)
    if LUA_DEFS_LIBRARY not in seen:
        out.insert(0, LUA_DEFS_LIBRARY)
    return out


def merge_workspace(
    existing: dict[str, Any] | None,
    template: dict[str, Any],
) -> dict[str, Any]:
    result: dict[str, Any] = dict(existing) if existing else {}
    folders_in = result.get("folders")
    folders: list[dict[str, Any]] = []
    if isinstance(folders_in, list):
        folders = [f for f in folders_in if isinstance(f, dict)]

    by_name = {
        str(f.get("name")): f for f in folders if f.get("name") is not None
    }
    merged_folders: list[dict[str, Any]] = []
    for req in required_folders():
        current = by_name.pop(req["name"], None)
        if current is None:
            merged_folders.append(dict(req))
        else:
            entry = dict(current)
            entry["name"] = req["name"]
            if not entry.get("path"):
                entry["path"] = req["path"]
            merged_folders.append(entry)
    for leftover in folders:
        name = leftover.get("name")
        if name is None or name in {f["name"] for f in merged_folders}:
            continue
        merged_folders.append(leftover)
    result["folders"] = merged_folders

    settings_in = result.get("settings")
    settings: dict[str, Any] = dict(settings_in) if isinstance(settings_in, dict) else {}
    template_settings = template.get("settings")
    if not isinstance(template_settings, dict):
        raise SetupError(f"Template missing settings object: {TEMPLATE_WORKSPACE}")

    for key in TEMPLATE_SETTING_KEYS:
        if key not in template_settings:
            continue
        value = template_settings[key]
        if key == "Lua.workspace.library":
            existing_lib = settings.get(key)
            merged_lib = normalize_library(value)
            if isinstance(existing_lib, list):
                for item in existing_lib:
                    if (
                        isinstance(item, str)
                        and item not in merged_lib
                        and not KETHO_LIBRARY_RE.search(item)
                    ):
                        merged_lib.append(item)
            settings[key] = merged_lib
        elif key == "files.exclude":
            current_exclude = settings.get(key)
            exclude: dict[str, Any] = (
                dict(current_exclude) if isinstance(current_exclude, dict) else {}
            )
            if isinstance(value, dict):
                exclude.update(value)
            settings[key] = exclude
        else:
            settings[key] = value

    result["settings"] = settings
    return result


def ensure_offline_luarc(*, assume_yes: bool) -> None:
    offline = offline_dir()
    offline.mkdir(parents=True, exist_ok=True)
    target = offline / ".luarc.json"
    template = load_json(TEMPLATE_OFFLINE_LUARC)
    if target.is_file():
        try:
            current = load_json(target)
        except (OSError, json.JSONDecodeError):
            current = None
        if current == template:
            print(f"Offline luarc already correct: {target}")
            return
        if not prompt_yes_no(
            f"{target} differs from the template. Overwrite?",
            default=True,
            assume_yes=assume_yes,
        ):
            print("Leaving existing Offline .luarc.json unchanged.")
            return
    dump_json(target, template)
    print(f"Wrote {target}")


def ensure_workspace(path: Path, *, assume_yes: bool) -> None:
    template = load_json(TEMPLATE_WORKSPACE)
    existing: dict[str, Any] | None = None
    if path.is_file():
        try:
            loaded = load_json(path)
            if isinstance(loaded, dict):
                existing = loaded
            else:
                raise SetupError(f"Workspace root must be a JSON object: {path}")
        except json.JSONDecodeError as exc:
            raise SetupError(f"Invalid JSON in {path}: {exc}") from exc
        print(f"Merging defaults into {path}")
    else:
        if not assume_yes and not prompt_yes_no(
            f"Create {path}?",
            default=True,
            assume_yes=assume_yes,
        ):
            raise SetupError("Workspace file creation declined.")
        print(f"Creating {path}")

    merged = merge_workspace(existing, template)
    dump_json(path, merged)
    print(f"Wrote {path}")


def find_editor_cli() -> str | None:
    for name in ("cursor", "code"):
        path = shutil.which(name)
        if path:
            return path
    return None


def install_marketplace_extensions(editor: str) -> list[str]:
    failures: list[str] = []
    for ext_id in MARKETPLACE_EXTENSIONS:
        print(f"Installing extension {ext_id} …")
        proc = subprocess.run(
            [editor, "--install-extension", ext_id, "--force"],
            check=False,
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            failures.append(ext_id)
            eprint(proc.stdout.strip())
            eprint(proc.stderr.strip())
            eprint(f"Failed to install {ext_id} (exit {proc.returncode})")
        else:
            print(f"  OK: {ext_id}")
    return failures


def download_latest_ketho_vsix(dest_dir: Path) -> Path:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "OneWoW-setup_dev_env",
    }
    req = urllib.request.Request(GITHUB_KETHO_RELEASES, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as exc:
        raise SetupError(f"Could not query Ketho releases: {exc}") from exc

    assets = payload.get("assets") or []
    vsix_url = None
    vsix_name = None
    for asset in assets:
        name = asset.get("name") or ""
        if name.endswith(".vsix") and name.startswith("wow-api-"):
            vsix_url = asset.get("browser_download_url")
            vsix_name = name
            break
    if not vsix_url or not vsix_name:
        raise SetupError("Latest Ketho release has no wow-api-*.vsix asset.")

    dest = dest_dir / vsix_name
    print(f"Downloading {vsix_name} …")
    req = urllib.request.Request(
        vsix_url,
        headers={"User-Agent": "OneWoW-setup_dev_env"},
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp, dest.open("wb") as out:
            shutil.copyfileobj(resp, out)
    except urllib.error.URLError as exc:
        raise SetupError(f"Could not download Ketho VSIX: {exc}") from exc
    return dest


def install_ketho_vsix(editor: str) -> None:
    with tempfile.TemporaryDirectory(prefix="onewow-ketho-") as tmp:
        vsix = download_latest_ketho_vsix(Path(tmp))
        print(f"Installing {vsix.name} …")
        proc = subprocess.run(
            [editor, "--install-extension", str(vsix), "--force"],
            check=False,
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            eprint(proc.stdout.strip())
            eprint(proc.stderr.strip())
            raise SetupError(
                f"Failed to install Ketho VSIX (exit {proc.returncode}). "
                "Install manually from "
                "https://github.com/Ketho/vscode-wow-api/releases"
            )
        print(f"  OK: {vsix.name}")


def ketho_extension_dirs() -> list[Path]:
    home = Path.home()
    roots = [
        home / ".cursor" / "extensions",
        home / ".vscode" / "extensions",
    ]
    found: list[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        found.extend(sorted(root.glob("ketho.wow-api-*")))
    return found


def install_python_tools(python_exe: str) -> None:
    req = REPO_ROOT / "bin" / "requirements.txt"
    print("Installing pre-commit and bin/requirements.txt …")
    proc = subprocess.run(
        [
            python_exe,
            "-m",
            "pip",
            "install",
            "pre-commit",
            "-r",
            str(req),
        ],
        check=False,
        cwd=str(REPO_ROOT),
    )
    if proc.returncode != 0:
        raise SetupError("pip install failed.")
    print("Installing pre-commit git hooks …")
    proc = subprocess.run(
        [python_exe, "-m", "pre_commit", "install"],
        check=False,
        cwd=str(REPO_ROOT),
    )
    if proc.returncode != 0:
        raise SetupError("pre_commit install failed.")
    print("  OK: pre-commit hooks installed")


def validate(workspace_path: Path) -> list[str]:
    notes: list[str] = []
    offline_luarc = offline_dir() / ".luarc.json"
    if not offline_luarc.is_file():
        notes.append(f"Missing {offline_luarc}")
    else:
        try:
            data = load_json(offline_luarc)
            if data.get("workspace.ignoreDir") != ["*"]:
                notes.append(
                    f"{offline_luarc} does not ignore all dirs "
                    '(expected workspace.ignoreDir: ["*"])'
                )
        except (OSError, json.JSONDecodeError) as exc:
            notes.append(f"Invalid Offline luarc: {exc}")

    if not workspace_path.is_file():
        notes.append(f"Missing workspace file {workspace_path}")
    else:
        try:
            ws = load_json(workspace_path)
            names = {
                f.get("name")
                for f in ws.get("folders", [])
                if isinstance(f, dict)
            }
            for required in (OFFLINE_DIR_NAME, SUITE_FOLDER_NAME):
                if required not in names:
                    notes.append(f"Workspace missing folder named {required!r}")
            settings = ws.get("settings") or {}
            lib = settings.get("Lua.workspace.library") or []
            if LUA_DEFS_LIBRARY not in lib:
                notes.append(
                    "Workspace Lua.workspace.library missing .lua-defs entry"
                )
            if any(
                isinstance(x, str) and KETHO_LIBRARY_RE.search(x) for x in lib
            ):
                notes.append(
                    "Workspace still has an absolute ketho.wow-api library path; "
                    "re-run merge or remove it (Ketho injects its own path)"
                )
        except (OSError, json.JSONDecodeError) as exc:
            notes.append(f"Invalid workspace JSON: {exc}")

    ketho_dirs = ketho_extension_dirs()
    if not ketho_dirs:
        notes.append(
            "ketho.wow-api extension directory not found under "
            "~/.cursor/extensions or ~/.vscode/extensions "
            "(install may need a window reload, or install the VSIX manually)"
        )
    else:
        print(f"Ketho extension present: {ketho_dirs[-1]}")

    return notes


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Set up the OneWoW dual-root Cursor development environment."
        ),
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Non-interactive defaults for overwrite/create prompts.",
    )
    parser.add_argument(
        "--workspace",
        type=Path,
        default=None,
        help="Path to the host .code-workspace file to create or merge.",
    )
    parser.add_argument(
        "--skip-extensions",
        action="store_true",
        help="Skip marketplace and Ketho VSIX extension installs.",
    )
    parser.add_argument(
        "--skip-python-tools",
        action="store_true",
        help="Skip pip install / pre-commit install.",
    )
    parser.add_argument(
        "--install-python",
        action="store_true",
        help=(
            "Attempt assisted Python 3.12 install when missing or too old "
            "(Win/macOS)."
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    assume_yes = bool(args.yes)

    if not TEMPLATE_WORKSPACE.is_file() or not TEMPLATE_OFFLINE_LUARC.is_file():
        eprint(f"Missing templates under {DEVCONFIG}")
        return 1

    print(f"Suite root: {REPO_ROOT}")
    print(f"Parent dir: {parent_dir()}")

    try:
        python_exe = ensure_python(
            assume_yes=assume_yes,
            install_python=bool(args.install_python),
        )

        ensure_offline_luarc(assume_yes=assume_yes)
        workspace_path = choose_workspace_path(
            explicit=args.workspace,
            assume_yes=assume_yes,
        )
        ensure_workspace(workspace_path, assume_yes=assume_yes)

        if not args.skip_extensions:
            editor = find_editor_cli()
            if not editor:
                eprint(
                    "Neither `cursor` nor `code` found on PATH. "
                    "Skip with --skip-extensions or install the shell command, "
                    "then re-run."
                )
            else:
                print(f"Using editor CLI: {editor}")
                failures = install_marketplace_extensions(editor)
                install_ketho_vsix(editor)
                if failures:
                    eprint(
                        "Some marketplace extensions failed: "
                        + ", ".join(failures)
                    )
        else:
            print("Skipping extension installs (--skip-extensions).")

        if not args.skip_python_tools:
            install_python_tools(python_exe)
        else:
            print("Skipping Python tooling (--skip-python-tools).")

        notes = validate(workspace_path)
        print()
        print("=== Setup summary ===")
        print(f"Offline dropzone: {offline_dir()}")
        print(f"Workspace file:   {workspace_path}")
        print(
            "Open the workspace file in Cursor "
            "(File → Open Workspace from File…), then reload the window "
            "so LuaLS / Ketho can finish wiring Lua.workspace.library."
        )
        print(
            "Note: anysphere.cursorpyright ships with Cursor; "
            "ketho.wow-api is VSIX-only (handled above unless skipped)."
        )
        if notes:
            print()
            print("Validation notes:")
            for note in notes:
                print(f"  - {note}")
            return 2

        print("Validation OK.")
        return 0
    except SetupError as exc:
        eprint(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
            sys.stderr.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
        except Exception:
            pass
    raise SystemExit(main())
