#!/usr/bin/env python3
"""
Converts old WoWNotesData_Professions static data files to new
OneWoW_CatalogData_Tradeskills compact format.

Reads from: /home/pals/w2xyz/wow/WoWNotesData_Professions/Data/*.lua
Outputs to:  /home/pals/w2xyz/wow/OneWoW_CatalogData_Tradeskills/Data/Tradeskills_*.lua
"""

import os
import re
import sys
import json

OLD_DATA_DIR = "/home/pals/w2xyz/wow/WoWNotesData_Professions/Data"
NEW_DATA_DIR = "/home/pals/w2xyz/wow/OneWoW_CatalogData_Tradeskills/Data"

PROFESSIONS = {
    "Alchemy":        {"pid": 171, "icon": 136240, "file": "Alchemy.lua"},
    "Blacksmithing":  {"pid": 164, "icon": 136241, "file": "Blacksmithing.lua"},
    "Cooking":        {"pid": 185, "icon": 133971, "file": "Cooking.lua"},
    "Enchanting":     {"pid": 333, "icon": 136244, "file": "Enchanting.lua"},
    "Engineering":    {"pid": 202, "icon": 136243, "file": "Engineering.lua"},
    "Fishing":        {"pid": 356, "icon": 136245, "file": "Fishing.lua"},
    "Herbalism":      {"pid": 182, "icon": 136246, "file": "Herbalism.lua"},
    "Inscription":    {"pid": 773, "icon": 237171, "file": "Inscription.lua"},
    "Jewelcrafting":  {"pid": 755, "icon": 134071, "file": "Jewelcrafting.lua"},
    "Leatherworking": {"pid": 165, "icon": 133611, "file": "Leatherworking.lua"},
    "Mining":         {"pid": 186, "icon": 134708, "file": "Mining.lua"},
    "Skinning":       {"pid": 393, "icon": 134366, "file": "Skinning.lua"},
    "Tailoring":      {"pid": 197, "icon": 136249, "file": "Tailoring.lua"},
}

EXPANSION_MAP = {
    "Alchemy": "Classic",
    "Blacksmithing Plans": "Classic",
    "Classic Cooking": "Classic",
    "Classic Inscription": "Classic",
    "Enchanting": "Classic",
    "Engineering": "Classic",
    "Jewelcrafting Designs": "Classic",
    "Leatherworking Patterns": "Classic",
    "Mining": "Classic",
    "Tailoring Patterns": "Classic",
    "Outland": "BurningCrusade",
    "Northrend": "WrathOfTheLichKing",
    "Cataclysm": "Cataclysm",
    "Pandaria": "MistsOfPandaria",
    "Pandaren": "MistsOfPandaria",
    "Way of the Brew": "MistsOfPandaria",
    "Way of the Grill": "MistsOfPandaria",
    "Way of the Oven": "MistsOfPandaria",
    "Way of the Pot": "MistsOfPandaria",
    "Way of the Steamer": "MistsOfPandaria",
    "Way of the Wok": "MistsOfPandaria",
    "Draenor": "WarlordsOfDraenor",
    "Broken Isles": "Legion",
    "Legion": "Legion",
    "Kul Tiran": "BattleForAzeroth",
    "Shadowlands": "Shadowlands",
    "Dragon Isles": "Dragonflight",
    "Khaz Algar": "TheWarWithin",
    "Midnight": "Midnight",
}


def normalize_expansion(exp_name, recipe_id=0):
    if not exp_name or exp_name.strip() == "":
        if recipe_id >= 1200000:
            return "Midnight"
        if recipe_id >= 400000:
            return "TheWarWithin"
        return "Unknown"
    if exp_name in EXPANSION_MAP:
        return EXPANSION_MAP[exp_name]
    for prefix, expansion in EXPANSION_MAP.items():
        if exp_name.startswith(prefix):
            return expansion
    return "Unknown"


class LuaParser:
    def __init__(self, text):
        self.text = text
        self.pos = 0
        self.length = len(text)

    def skip_ws(self):
        while self.pos < self.length:
            if self.text[self.pos] in ' \t\r\n':
                self.pos += 1
            elif self.text[self.pos:self.pos+2] == '--':
                while self.pos < self.length and self.text[self.pos] != '\n':
                    self.pos += 1
            else:
                break

    def peek(self):
        self.skip_ws()
        if self.pos >= self.length:
            return None
        return self.text[self.pos]

    def expect(self, ch):
        self.skip_ws()
        if self.pos < self.length and self.text[self.pos] == ch:
            self.pos += 1
            return True
        return False

    def parse_value(self):
        self.skip_ws()
        if self.pos >= self.length:
            return None
        ch = self.text[self.pos]
        if ch == '{':
            return self.parse_table()
        elif ch == '"':
            return self.parse_string()
        elif ch == "'":
            return self.parse_single_string()
        elif ch == '-' or ch.isdigit():
            return self.parse_number()
        elif self.text[self.pos:self.pos+4] == 'true':
            self.pos += 4
            return True
        elif self.text[self.pos:self.pos+5] == 'false':
            self.pos += 5
            return False
        elif self.text[self.pos:self.pos+3] == 'nil':
            self.pos += 3
            return None
        else:
            return None

    def parse_string(self):
        self.pos += 1  # skip opening "
        result = []
        while self.pos < self.length:
            ch = self.text[self.pos]
            if ch == '\\':
                self.pos += 1
                if self.pos < self.length:
                    esc = self.text[self.pos]
                    if esc == 'n':
                        result.append('\n')
                    elif esc == 't':
                        result.append('\t')
                    elif esc == '"':
                        result.append('"')
                    elif esc == '\\':
                        result.append('\\')
                    else:
                        result.append(esc)
                    self.pos += 1
            elif ch == '"':
                self.pos += 1
                return ''.join(result)
            else:
                result.append(ch)
                self.pos += 1
        return ''.join(result)

    def parse_single_string(self):
        self.pos += 1
        result = []
        while self.pos < self.length:
            ch = self.text[self.pos]
            if ch == '\\':
                self.pos += 1
                if self.pos < self.length:
                    result.append(self.text[self.pos])
                    self.pos += 1
            elif ch == "'":
                self.pos += 1
                return ''.join(result)
            else:
                result.append(ch)
                self.pos += 1
        return ''.join(result)

    def parse_number(self):
        start = self.pos
        if self.text[self.pos] == '-':
            self.pos += 1
        while self.pos < self.length and (self.text[self.pos].isdigit() or self.text[self.pos] == '.'):
            self.pos += 1
        num_str = self.text[start:self.pos]
        if '.' in num_str:
            return float(num_str)
        return int(num_str)

    def parse_table(self):
        self.pos += 1  # skip {
        self.skip_ws()
        is_dict = False
        is_array = True
        result_dict = {}
        result_array = []

        while True:
            self.skip_ws()
            if self.pos >= self.length:
                break
            if self.text[self.pos] == '}':
                self.pos += 1
                break

            if self.text[self.pos] == '[':
                is_dict = True
                is_array = False
                self.pos += 1  # skip [
                key = self.parse_value()
                self.skip_ws()
                if self.pos < self.length and self.text[self.pos] == ']':
                    self.pos += 1
                self.skip_ws()
                if self.pos < self.length and self.text[self.pos] == '=':
                    self.pos += 1
                val = self.parse_value()
                if key is not None and val is not None:
                    result_dict[key] = val
            else:
                val = self.parse_value()
                if val is not None:
                    if is_array:
                        result_array.append(val)

            self.skip_ws()
            if self.pos < self.length and self.text[self.pos] == ',':
                self.pos += 1

        if is_dict:
            return result_dict
        return result_array


def parse_old_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    match = re.search(r'ns\.StaticRecipeData_\w+\s*=\s*\{', content)
    if not match:
        print(f"  WARNING: Could not find table start in {filepath}")
        return {}

    table_start = match.start()
    brace_pos = content.index('{', table_start)

    parser = LuaParser(content[brace_pos:])
    data = parser.parse_table()
    return data


def convert_recipe(recipe_data, profession_name):
    if not isinstance(recipe_data, dict):
        return None

    recipe_id = recipe_data.get("recipeID")
    if recipe_id is None:
        return None

    exp_raw = recipe_data.get("expansionName")
    if not exp_raw:
        exp_raw = ""
    exp = normalize_expansion(exp_raw, recipe_id)

    rg = []
    old_reagents = recipe_data.get("reagents", [])
    if isinstance(old_reagents, list):
        for r in old_reagents:
            if isinstance(r, dict):
                item_id = r.get("itemID")
                qty = r.get("qtyRequired", 1)
                rtype = r.get("reagentType", 1)
                if item_id:
                    rg.append((int(item_id), int(qty), int(rtype)))

    sl = []
    has_multi_options = False
    old_slots = recipe_data.get("reagentSlots", [])
    if isinstance(old_slots, list):
        for s in old_slots:
            if isinstance(s, dict):
                idx = s.get("slotIndex", 0)
                qty = s.get("qtyRequired", 1)
                req = s.get("required", True)
                rtype = s.get("reagentType", 1)
                opts = []
                options = s.get("options", [])
                if isinstance(options, list):
                    for o in options:
                        if isinstance(o, dict) and "itemID" in o:
                            opts.append(int(o["itemID"]))
                if len(opts) > 1:
                    has_multi_options = True
                sl.append((int(idx), int(qty), bool(req), int(rtype), opts))

    result = {
        "id": int(recipe_id),
        "icon": int(recipe_data.get("icon", 0)),
        "cat": int(recipe_data.get("categoryID", 0)),
        "prof": profession_name,
        "exp": exp,
        "diff": int(recipe_data.get("difficulty", 0)),
        "qual": bool(recipe_data.get("supportsQualities", False)),
    }

    output_item = recipe_data.get("outputItemID") or recipe_data.get("itemID")
    if output_item:
        result["item"] = int(output_item)

    max_q = recipe_data.get("maxQuality")
    if max_q and max_q > 0:
        result["maxQ"] = int(max_q)

    prev_id = recipe_data.get("previousRecipeID")
    if prev_id:
        result["prev"] = int(prev_id)

    next_id = recipe_data.get("nextRecipeID")
    if next_id:
        result["next"] = int(next_id)

    rank = recipe_data.get("unlockedRecipeLevel")
    if rank:
        result["rank"] = int(rank)

    if rg:
        result["rg"] = rg

    if sl and has_multi_options:
        result["sl"] = sl

    return result


def lua_bool(val):
    return "true" if val else "false"


def write_lua_recipe(f, recipe_id, recipe, indent="        "):
    f.write(f"    [{recipe_id}] = {{\n")
    f.write(f"{indent}id = {recipe['id']},\n")
    if "item" in recipe:
        f.write(f"{indent}item = {recipe['item']},\n")
    f.write(f"{indent}icon = {recipe['icon']},\n")
    f.write(f"{indent}cat = {recipe['cat']},\n")
    f.write(f'{indent}prof = "{recipe["prof"]}",\n')
    f.write(f'{indent}exp = "{recipe["exp"]}",\n')
    f.write(f"{indent}diff = {recipe['diff']},\n")
    f.write(f"{indent}qual = {lua_bool(recipe['qual'])},\n")
    if "maxQ" in recipe:
        f.write(f"{indent}maxQ = {recipe['maxQ']},\n")
    if "prev" in recipe:
        f.write(f"{indent}prev = {recipe['prev']},\n")
    if "next" in recipe:
        f.write(f"{indent}next = {recipe['next']},\n")
    if "rank" in recipe:
        f.write(f"{indent}rank = {recipe['rank']},\n")

    if "rg" in recipe and recipe["rg"]:
        f.write(f"{indent}rg = {{\n")
        for itemID, qty, rtype in recipe["rg"]:
            f.write(f"{indent}    {{{itemID}, {qty}, {rtype}}},\n")
        f.write(f"{indent}}},\n")
    else:
        f.write(f"{indent}rg = {{}},\n")

    if "sl" in recipe and recipe["sl"]:
        f.write(f"{indent}sl = {{\n")
        for idx, qty, req, rtype, opts in recipe["sl"]:
            opts_str = ", ".join(str(o) for o in opts)
            f.write(f"{indent}    {{{idx}, {qty}, {lua_bool(req)}, {rtype}, {{{opts_str}}}}},\n")
        f.write(f"{indent}}},\n")

    f.write(f"    }},\n")


def write_profession_file(profession_name, prof_info, recipes):
    outpath = os.path.join(NEW_DATA_DIR, f"Tradeskills_{profession_name}.lua")
    global_name = f"OneWoWTradeskills_{profession_name}"

    sorted_recipes = sorted(recipes.items(), key=lambda x: x[0])

    with open(outpath, 'w', encoding='utf-8') as f:
        f.write(f"{global_name} = {{\n")
        f.write(f'    pid = {prof_info["pid"]},\n')
        f.write(f'    name = "{profession_name}",\n')
        f.write(f'    icon = {prof_info["icon"]},\n')
        f.write(f"    r = {{\n")

        for recipe_id, recipe in sorted_recipes:
            write_lua_recipe(f, recipe_id, recipe)

        f.write(f"    }},\n")
        f.write(f"}}\n")

    return outpath


def main():
    print("=" * 60)
    print("WoWNotesData_Professions -> OneWoW_CatalogData_Tradeskills")
    print("=" * 60)

    os.makedirs(NEW_DATA_DIR, exist_ok=True)

    total_recipes = 0
    total_files = 0
    expansion_counts = {}
    unknown_expansions = set()

    for prof_name, prof_info in sorted(PROFESSIONS.items()):
        filepath = os.path.join(OLD_DATA_DIR, prof_info["file"])
        if not os.path.exists(filepath):
            print(f"  SKIP: {filepath} not found")
            continue

        print(f"\nProcessing {prof_name}...")
        raw_data = parse_old_file(filepath)

        if not raw_data:
            print(f"  WARNING: No data parsed from {filepath}")
            continue

        recipes = {}
        for key, value in raw_data.items():
            recipe_id = int(key)
            converted = convert_recipe(value, prof_name)
            if converted:
                recipes[recipe_id] = converted
                exp = converted["exp"]
                if exp == "Unknown":
                    raw_exp = value.get("expansionName", "")
                    unknown_expansions.add(f"{prof_name}: {raw_exp}")
                expansion_counts[exp] = expansion_counts.get(exp, 0) + 1

        outpath = write_profession_file(prof_name, prof_info, recipes)
        file_size = os.path.getsize(outpath)
        total_recipes += len(recipes)
        total_files += 1

        print(f"  {len(recipes)} recipes -> {outpath}")
        print(f"  File size: {file_size:,} bytes ({file_size/1024:.1f} KB)")

    print("\n" + "=" * 60)
    print(f"SUMMARY")
    print(f"=" * 60)
    print(f"Files generated: {total_files}")
    print(f"Total recipes:   {total_recipes}")
    print(f"\nRecipes by expansion:")
    for exp in sorted(expansion_counts.keys()):
        print(f"  {exp}: {expansion_counts[exp]}")

    if unknown_expansions:
        print(f"\nWARNING - Unknown expansion names:")
        for u in sorted(unknown_expansions):
            print(f"  {u}")

    total_size = sum(
        os.path.getsize(os.path.join(NEW_DATA_DIR, f))
        for f in os.listdir(NEW_DATA_DIR) if f.endswith('.lua')
    )
    print(f"\nTotal output size: {total_size:,} bytes ({total_size/1024/1024:.1f} MB)")


if __name__ == "__main__":
    main()
