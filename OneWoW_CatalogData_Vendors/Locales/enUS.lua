local addonName, ns = ...

ns.Locales = ns.Locales or {}
ns.Locales["enUS"] = {
    ["ADDON_LOADED"] = "OneWoW CatalogData: Vendor data loaded.",
    ["SCAN_COMPLETE"] = "Vendor scanned: %s (%d items)",
}

ns.L = {}
for k, v in pairs(ns.Locales["enUS"]) do ns.L[k] = v end
