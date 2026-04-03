local ADDON_NAME, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH  = 1400,
        WINDOW_HEIGHT = 900,
        SCROLLBAR_W   = 10,
    }),
}

ns.L       = {}
ns.Locales = {}

function ns.RegisterLocale(lang, t)
    ns.Locales[lang] = t
end

function ns.SetLocale(lang)
    local base = ns.Locales["enUS"]
    local tbl  = ns.Locales[lang]

    wipe(ns.L)

    if base then
        for k, v in pairs(base) do
            ns.L[k] = v
        end
    end

    if tbl and lang ~= "enUS" then
        for k, v in pairs(tbl) do
            ns.L[k] = v
        end
    end
end
