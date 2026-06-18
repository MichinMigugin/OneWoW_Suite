local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AUTOINVITE_TITLE"] = "Gruppeneinladungen automatisch annehmen",
    ["AUTOINVITE_DESC"] = "Nimmt automatisch Gruppeneinladungen von Personen an, denen du vertraust. Wähle unten, welche Quellen erlaubt sind.",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "Von Freunden",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "Einladungen von WoW-Freunden und Battle.net-Freunden annehmen.",
    ["AUTOINVITE_TOGGLE_GUILD"] = "Von Gilde",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "Einladungen von Mitgliedern deiner Gilde annehmen.",
    ["AUTOINVITE_TOGGLE_ALL"] = "Von jedem",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "Jede Gruppeneinladung annehmen, unabhängig davon, wer sie gesendet hat. Überschreibt die anderen Schalter, wenn aktiviert.",
})
