local ADDON_NAME, OneWoW_ShoppingList = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_ShoppingList.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH  = 820,
        WINDOW_HEIGHT = 580,
        SIDEBAR_WIDTH = 300,
        ROW_HEIGHT    = 38,
        ROW_GAP       = 2,
        SCROLLBAR_W   = 10,
    }),
}

OneWoW_ShoppingList.L       = {}
OneWoW_ShoppingList.Locales = {}

function OneWoW_ShoppingList.RegisterLocale(lang, t)
    OneWoW_ShoppingList.Locales[lang] = t
end

function OneWoW_ShoppingList.SetLocale(lang)
    local base = OneWoW_ShoppingList.Locales["enUS"]
    local tbl  = OneWoW_ShoppingList.Locales[lang]

    wipe(OneWoW_ShoppingList.L)

    if base then
        for k, v in pairs(base) do
            OneWoW_ShoppingList.L[k] = v
        end
    end

    if tbl and lang ~= "enUS" then
        for k, v in pairs(tbl) do
            OneWoW_ShoppingList.L[k] = v
        end
    end
end
