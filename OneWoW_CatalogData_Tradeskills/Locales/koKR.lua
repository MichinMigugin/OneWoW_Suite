local _, ns = ...

ns.Locales = ns.Locales or {}
ns.Locales["koKR"] = {}

if ns.Locales["enUS"] then
    for k, _ in pairs(ns.Locales["enUS"]) do
        ns.Locales["koKR"][k] = "TEST"
    end
end
