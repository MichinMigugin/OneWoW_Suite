"""Parse and serialize OneWoW QuestDB Lua shards (one quest per line)."""

from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any

QUEST_START_RE = re.compile(r"^\[(\d+)\]\s*=\s*(\{.*)$")

QUEST_KEY_ORDER = [
    "id",
    "name",
    "level",
    "requiredLevel",
    "faction",
    "requiredClasses",
    "requiredRaces",
    "requiredProfessions",
    "categories",
    "flags",
    "timerSeconds",
    "sharable",
    "event",
    "expansion",
    "zoneID",
    "mapID",
    "storyline",
    "series",
    "description",
    "objectivesText",
    "objectives",
    "objectiveDetails",
    "rewardGold",
    "rewardXP",
    "rewardItems",
    "rewardChoices",
    "rewardCurrencies",
    "starts",
    "ends",
    "coords",
    "mapCandidates",
    "questGiverID",
    "questGiverName",
    "questTurnInID",
    "questTurnInName",
    "suggestedGroup",
    "classification",
    "questType",
]


class LuaParseError(ValueError):
    pass


class _LuaParser:
    def __init__(self, text: str) -> None:
        self.text = text
        self.i = 0

    def peek(self) -> str:
        return self.text[self.i] if self.i < len(self.text) else ""

    def skip_ws(self) -> None:
        while self.i < len(self.text) and self.text[self.i] in " \t\r\n":
            self.i += 1

    def parse_value(self) -> Any:
        self.skip_ws()
        ch = self.peek()
        if ch == '"':
            return self.parse_string()
        if ch == "{":
            return self.parse_table()
        if ch in "-0123456789":
            return self.parse_number()
        if self.text.startswith("true", self.i):
            self.i += 4
            return True
        if self.text.startswith("false", self.i):
            self.i += 5
            return False
        if self.text.startswith("nil", self.i):
            self.i += 3
            return None
        raise LuaParseError(f"Unexpected value at {self.i}: {self.text[self.i:self.i + 40]!r}")

    def parse_string(self) -> str:
        if self.peek() != '"':
            raise LuaParseError("expected string")
        self.i += 1
        out: list[str] = []
        while self.i < len(self.text):
            ch = self.text[self.i]
            if ch == "\\":
                self.i += 1
                if self.i >= len(self.text):
                    raise LuaParseError("unterminated escape")
                esc = self.text[self.i]
                self.i += 1
                mapping = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}
                out.append(mapping.get(esc, esc))
                continue
            if ch == '"':
                self.i += 1
                return "".join(out)
            out.append(ch)
            self.i += 1
        raise LuaParseError("unterminated string")

    def parse_number(self) -> int | float:
        start = self.i
        if self.peek() == "-":
            self.i += 1
        while self.peek().isdigit():
            self.i += 1
        if self.peek() == ".":
            self.i += 1
            while self.peek().isdigit():
                self.i += 1
        raw = self.text[start : self.i]
        if "." in raw:
            return float(raw)
        return int(raw)

    def parse_key(self) -> str | int:
        self.skip_ws()
        if self.peek() != "[":
            raise LuaParseError("expected [key]")
        self.i += 1
        self.skip_ws()
        if self.peek() == '"':
            key: str | int = self.parse_string()
        else:
            key = self.parse_number()
            if isinstance(key, float):
                raise LuaParseError("float table key")
        self.skip_ws()
        if self.peek() != "]":
            raise LuaParseError("expected ] after key")
        self.i += 1
        return key

    def parse_table(self) -> list[Any] | dict[Any, Any]:
        if self.peek() != "{":
            raise LuaParseError("expected {")
        self.i += 1
        self.skip_ws()
        if self.peek() == "}":
            self.i += 1
            return []

        # Peek whether this is a sequence or a map.
        is_map = self.peek() == "["
        if is_map:
            data: dict[Any, Any] = {}
            while True:
                self.skip_ws()
                if self.peek() == "}":
                    self.i += 1
                    return data
                key = self.parse_key()
                self.skip_ws()
                if self.peek() != "=":
                    raise LuaParseError("expected =")
                self.i += 1
                data[key] = self.parse_value()
                self.skip_ws()
                if self.peek() == ",":
                    self.i += 1
                    continue
                if self.peek() == "}":
                    self.i += 1
                    return data
                raise LuaParseError("expected , or } in map")

        seq: list[Any] = []
        while True:
            self.skip_ws()
            if self.peek() == "}":
                self.i += 1
                return seq
            seq.append(self.parse_value())
            self.skip_ws()
            if self.peek() == ",":
                self.i += 1
                continue
            if self.peek() == "}":
                self.i += 1
                return seq
            raise LuaParseError("expected , or } in sequence")


def parse_lua_value(text: str) -> Any:
    parser = _LuaParser(text)
    value = parser.parse_value()
    parser.skip_ws()
    if parser.i != len(parser.text):
        raise LuaParseError(f"trailing junk: {parser.text[parser.i:parser.i + 40]!r}")
    return value


def _brace_delta(text: str) -> int:
    """Net { minus } ignoring quoted strings."""
    delta = 0
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == '"':
            i += 1
            while i < len(text):
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if ch == "{":
            delta += 1
        elif ch == "}":
            delta -= 1
        i += 1
    return delta


def parse_questdb_file(path: Path) -> dict[int, dict[str, Any]]:
    """Load a RegisterQuestData shard into {questID: record}."""
    quests: dict[int, dict[str, Any]] = {}
    if not path.exists():
        return quests
    lines = path.read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        match = QUEST_START_RE.match(lines[i])
        if not match:
            i += 1
            continue
        quest_id = int(match.group(1))
        start_line = i + 1
        blob = match.group(2)
        i += 1
        while _brace_delta(blob) > 0 and i < len(lines):
            blob += lines[i]
            i += 1
        blob = blob.rstrip().rstrip(",")
        try:
            record = parse_lua_value(blob)
        except LuaParseError as err:
            raise LuaParseError(f"{path.name}:{start_line} quest {quest_id}: {err}") from err
        if not isinstance(record, dict):
            raise LuaParseError(f"{path.name}:{start_line} quest {quest_id} is not a table")
        quests[quest_id] = record
    return quests


def _escape_str(value: str) -> str:
    return '"' + (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    ) + '"'


def _serialize_number(value: int | float) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        if value.is_integer() and math.isfinite(value):
            return str(int(value))
        return format(value, ".14g")
    return str(int(value))


def _is_sequence(value: list[Any] | dict[Any, Any]) -> bool:
    if isinstance(value, list):
        return True
    if not value:
        return True
    keys = list(value.keys())
    return all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1))


def serialize_lua(value: Any) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return _escape_str(value)
    if isinstance(value, (int, float)):
        return _serialize_number(value)
    if isinstance(value, list):
        if not value:
            return "{}"
        return "{ " + ", ".join(serialize_lua(item) for item in value) + " }"
    if isinstance(value, dict):
        if not value:
            return "{}"
        if _is_sequence(value) and all(isinstance(k, int) for k in value):
            items = [serialize_lua(value[i]) for i in range(1, len(value) + 1)]
            return "{ " + ", ".join(items) + " }"
        parts: list[str] = []
        keys = list(value.keys())
        # Preserve insertion order for quest records (we emit in QUEST_KEY_ORDER).
        for key in keys:
            if isinstance(key, int):
                parts.append(f"[{key}] = {serialize_lua(value[key])}")
            else:
                parts.append(f"[{_escape_str(str(key))}] = {serialize_lua(value[key])}")
        return "{ " + ", ".join(parts) + " }"
    raise TypeError(f"cannot serialize {type(value).__name__}")


def serialize_quest(quest: dict[str, Any]) -> str:
    seen: set[str] = set()
    ordered: dict[str, Any] = {}

    def emit(key: str) -> None:
        if key in quest and quest[key] is not None and key not in seen:
            seen.add(key)
            ordered[key] = quest[key]

    for key in QUEST_KEY_ORDER:
        emit(key)
    for key in sorted(k for k in quest if isinstance(k, str) and k not in seen):
        if quest[key] is not None:
            emit(key)
    return serialize_lua(ordered)


def write_questdb_file(path: Path, quests: dict[int, dict[str, Any]]) -> None:
    lines = [
        "local _, ns = ...",
        "",
        "ns:RegisterQuestData({",
    ]
    for quest_id in sorted(quests):
        lines.append(f"[{quest_id}] = {serialize_quest(quests[quest_id])},")
    lines.append("})")
    lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
