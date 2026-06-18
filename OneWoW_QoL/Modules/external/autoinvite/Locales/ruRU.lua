local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AUTOINVITE_TITLE"] = "Автоприём приглашений в группу",
    ["AUTOINVITE_DESC"] = "Автоматически принимает приглашения в группу от людей, которым вы доверяете. Выберите ниже, какие источники разрешены.",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "От друзей",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "Принимать приглашения от друзей WoW и друзей Battle.net.",
    ["AUTOINVITE_TOGGLE_GUILD"] = "От гильдии",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "Принимать приглашения от членов вашей гильдии.",
    ["AUTOINVITE_TOGGLE_ALL"] = "От кого угодно",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "Принимать любое приглашение в группу, независимо от отправителя. При включении переопределяет другие переключатели.",
})
