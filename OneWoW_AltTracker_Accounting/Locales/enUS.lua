local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
