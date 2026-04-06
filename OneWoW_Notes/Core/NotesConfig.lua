-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/NotesConfig.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

ns.NotesConfig = {}

ns.NotesConfig.PIN_COLORS = {
    ["sync"] = {
        name = "OneWoW Sync",
        background = {0.15, 0.25, 0.15},
        border = {0.2, 0.6, 0.2},
        titleBar = {0.1, 0.2, 0.1},
        listItem = {0.15, 0.25, 0.15, 0.5}
    },
    ["hunter"] = {
        name = L["NOTES_PIN_COLOR_HUNTER_GREEN"],
        background = {0.15, 0.25, 0.15},
        border = {0.2, 0.6, 0.2},
        titleBar = {0.1, 0.2, 0.1},
        listItem = {0.15, 0.25, 0.15, 0.5}
    },
    ["warrior"] = {
        name = L["NOTES_PIN_COLOR_WARRIOR_TAN"],
        background = {0.25, 0.2, 0.15},
        border = {0.78, 0.61, 0.43},
        titleBar = {0.2, 0.15, 0.1},
        listItem = {0.25, 0.2, 0.15, 0.5}
    },
    ["priest"] = {
        name = L["NOTES_PIN_COLOR_PRIEST_WHITE"],
        background = {0.25, 0.25, 0.25},
        border = {0.8, 0.8, 0.8},
        titleBar = {0.2, 0.2, 0.2},
        listItem = {0.25, 0.25, 0.25, 0.5}
    },
    ["warlock"] = {
        name = L["NOTES_PIN_COLOR_WARLOCK_PURPLE"],
        background = {0.25, 0.15, 0.25},
        border = {0.58, 0.51, 0.79},
        titleBar = {0.2, 0.1, 0.2},
        listItem = {0.25, 0.15, 0.25, 0.5}
    },
    ["mage"] = {
        name = L["NOTES_PIN_COLOR_MAGE_BLUE"],
        background = {0.15, 0.2, 0.35},
        border = {0.25, 0.4, 0.85},
        titleBar = {0.1, 0.15, 0.25},
        listItem = {0.15, 0.2, 0.35, 0.5}
    },
    ["rogue"] = {
        name = L["NOTES_PIN_COLOR_ROGUE_YELLOW"],
        background = {0.25, 0.25, 0.08},
        border = {1.0, 0.96, 0.41},
        titleBar = {0.2, 0.2, 0.05},
        listItem = {0.25, 0.25, 0.08, 0.5}
    },
    ["druid"] = {
        name = L["NOTES_PIN_COLOR_DRUID_ORANGE"],
        background = {0.25, 0.2, 0.08},
        border = {1.0, 0.49, 0.04},
        titleBar = {0.2, 0.15, 0.05},
        listItem = {0.25, 0.2, 0.08, 0.5}
    },
    ["paladin"] = {
        name = L["NOTES_PIN_COLOR_PALADIN_PINK"],
        background = {0.3, 0.2, 0.25},
        border = {0.96, 0.55, 0.73},
        titleBar = {0.25, 0.15, 0.2},
        listItem = {0.3, 0.2, 0.25, 0.5}
    },
    ["shaman"] = {
        name = L["NOTES_PIN_COLOR_SHAMAN_BLUE"],
        background = {0.08, 0.2, 0.25},
        border = {0.0, 0.44, 0.87},
        titleBar = {0.05, 0.15, 0.2},
        listItem = {0.08, 0.2, 0.25, 0.5}
    },
    ["deathknight"] = {
        name = L["NOTES_PIN_COLOR_DEATHKNIGHT_RED"],
        background = {0.25, 0.15, 0.15},
        border = {0.6, 0.2, 0.2},
        titleBar = {0.2, 0.1, 0.1},
        listItem = {0.25, 0.15, 0.15, 0.5}
    },
    ["monk"] = {
        name = L["NOTES_PIN_COLOR_MONK_JADE"],
        background = {0.15, 0.25, 0.22},
        border = {0.0, 1.0, 0.59},
        titleBar = {0.1, 0.2, 0.17},
        listItem = {0.15, 0.25, 0.22, 0.5}
    },
    ["demonhunter"] = {
        name = L["NOTES_PIN_COLOR_DEMONHUNTER_PURPLE"],
        background = {0.25, 0.08, 0.29},
        border = {0.64, 0.19, 0.79},
        titleBar = {0.2, 0.05, 0.24},
        listItem = {0.25, 0.08, 0.29, 0.5}
    },
    ["evoker"] = {
        name = L["NOTES_PIN_COLOR_EVOKER_TEAL"],
        background = {0.08, 0.22, 0.25},
        border = {0.2, 0.58, 0.5},
        titleBar = {0.05, 0.17, 0.2},
        listItem = {0.08, 0.22, 0.25, 0.5}
    },
    ["darkiron"] = {
        name = L["NOTES_PIN_COLOR_DARKIRON"],
        background = {0.2, 0.2, 0.25},
        border = {0.35, 0.35, 0.45},
        titleBar = {0.15, 0.15, 0.2},
        listItem = {0.2, 0.2, 0.25, 0.5}
    }
}

-- Theme mapping: OneWoW theme names to PIN_COLORS keys
ns.NotesConfig.THEME_TO_COLOR = {
    ["green"] = "hunter",
    ["blue"] = "mage",
    ["purple"] = "warlock",
    ["red"] = "deathknight",
    ["orange"] = "druid",
    ["teal"] = "evoker",
    ["gold"] = "warrior",
    ["pink"] = "paladin",
    ["dark"] = "priest",
    ["amber"] = "warrior",
    ["cyan"] = "shaman",
    ["slate"] = "priest",
    ["voidblack"] = "priest",
    ["charcoal"] = "warrior",
    ["forestnight"] = "druid",
    ["obsidian"] = "priest",
    ["monochrome"] = "priest",
    ["twilight"] = "mage",
    ["neon"] = "warlock",
    ["glassmorphic"] = "mage",
    ["lightmode"] = "mage",
    ["retro"] = "warrior",
    ["fantasy"] = "paladin",
    ["nightfae"] = "druid",
}

-- Font color mapping for theme sync
ns.NotesConfig.THEME_TO_FONT_COLOR = ns.NotesConfig.THEME_TO_COLOR

function ns.NotesConfig:GetResolvedColorConfig(pinColorKey)
    if pinColorKey == "sync" then
        local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
        local currentTheme = (OneWoW_GUI and OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("theme")) or "green"
        local colorKey = self.THEME_TO_COLOR[currentTheme] or "hunter"
        return self.PIN_COLORS[colorKey] or self.PIN_COLORS["hunter"]
    else
        return self.PIN_COLORS[pinColorKey] or self.PIN_COLORS["hunter"]
    end
end

function ns.NotesConfig:GetResolvedFontColor(fontColorKey, pinColorKey)
    if fontColorKey == "sync" then
        local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
        local currentTheme = (OneWoW_GUI and OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("theme")) or "green"
        local colorKey = self.THEME_TO_FONT_COLOR[currentTheme] or "hunter"
        local colorConfig = self.PIN_COLORS[colorKey]
        if colorConfig then return colorConfig.border end
        return self.PIN_COLORS["hunter"].border
    elseif fontColorKey == "match" then
        local colorConfig = self:GetResolvedColorConfig(pinColorKey)
        return colorConfig.border
    elseif fontColorKey == "white" then
        return {1, 1, 1}
    elseif fontColorKey == "black" then
        return {0, 0, 0}
    else
        local fontConfig = self.PIN_COLORS[fontColorKey]
        if fontConfig then return fontConfig.border end
        local pinConfig = self:GetResolvedColorConfig(pinColorKey)
        return pinConfig.border
    end
end

function ns.NotesConfig:ResolveFontPath(fontKey)
    local GUI = LibStub("OneWoW_GUI-1.0", true)
    if fontKey and fontKey ~= "default" and GUI and GUI.GetFontByKey then
        local path = GUI:GetFontByKey(fontKey)
        if path then return path end
    end
    if GUI and GUI.GetFont then
        local globalPath = GUI:GetFont()
        if globalPath then return globalPath end
    end
    return "Fonts\\FRIZQT__.TTF"
end

function ns.NotesConfig:GetFontOptions()
    local GUI = LibStub("OneWoW_GUI-1.0", true)
    local opts = {}
    if GUI and GUI.GetFontList then
        for _, fontInfo in ipairs(GUI:GetFontList()) do
            opts[#opts + 1] = { text = fontInfo.label, value = fontInfo.key }
        end
    else
        opts[#opts + 1] = { text = "WoW Default", value = "default" }
    end
    return opts
end

-- Shared alias so all code can use ns.Config.PIN_COLORS
ns.Config = ns.NotesConfig
