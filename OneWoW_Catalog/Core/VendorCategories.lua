local _, ns = ...

-- ============================================================================
-- VendorCategories
-- ============================================================================
-- User-assignable vendor types ("Quartermaster / Renown", "Mount Vendor",
-- etc.) used by the Vendors tab for display and filtering.
--
-- The category KEY is the stable identifier stored on
-- OneWoW_CatalogData_Vendors_DB.global.vendors[npcID].category.
-- The label is resolved through ns.L at runtime so it stays localized.
-- ============================================================================

ns.VendorCategories = ns.VendorCategories or {}
local VC = ns.VendorCategories

local tinsert, sort = tinsert, sort

-- Master list of valid keys. Display ordering is produced by GetSortedKeys()
-- which sorts by the current localized label, so this raw order is irrelevant
-- to the UI.
VC.ORDER = {
    "auction_house",
    "banker",
    "barbershop",
    "bmah",
    "catalyst",
    "class_trainer",
    "currency",
    "decor",
    "delve",
    "fishing",
    "flight_master",
    "food",
    "general",
    "guild_vendor",
    "heirloom",
    "holiday",
    "innkeeper",
    "item_upgrade",
    "mailbox",
    "mount",
    "other",
    "pet",
    "profession_supplies",
    "profession_trainer",
    "pvp",
    "quartermaster",
    "reagent",
    "repair",
    "reputation",
    "stable_master",
    "tabard",
    "timewalking",
    "toy",
    "transmog",
    "void_storage",
}

local LOCALE_KEYS = {
    auction_house        = "VENDORS_CATEGORY_AUCTION_HOUSE",
    banker               = "VENDORS_CATEGORY_BANKER",
    barbershop           = "VENDORS_CATEGORY_BARBERSHOP",
    bmah                 = "VENDORS_CATEGORY_BMAH",
    catalyst             = "VENDORS_CATEGORY_CATALYST",
    class_trainer        = "VENDORS_CATEGORY_CLASS_TRAINER",
    currency             = "VENDORS_CATEGORY_CURRENCY",
    decor                = "VENDORS_CATEGORY_DECOR",
    delve                = "VENDORS_CATEGORY_DELVE",
    fishing              = "VENDORS_CATEGORY_FISHING",
    flight_master        = "VENDORS_CATEGORY_FLIGHT_MASTER",
    food                 = "VENDORS_CATEGORY_FOOD",
    general              = "VENDORS_CATEGORY_GENERAL",
    guild_vendor         = "VENDORS_CATEGORY_GUILD_VENDOR",
    heirloom             = "VENDORS_CATEGORY_HEIRLOOM",
    holiday              = "VENDORS_CATEGORY_HOLIDAY",
    innkeeper            = "VENDORS_CATEGORY_INNKEEPER",
    item_upgrade         = "VENDORS_CATEGORY_ITEM_UPGRADE",
    mailbox              = "VENDORS_CATEGORY_MAILBOX",
    mount                = "VENDORS_CATEGORY_MOUNT",
    other                = "VENDORS_CATEGORY_OTHER",
    pet                  = "VENDORS_CATEGORY_PET",
    profession_supplies  = "VENDORS_CATEGORY_PROFESSION_SUPPLIES",
    profession_trainer   = "VENDORS_CATEGORY_PROFESSION_TRAINER",
    pvp                  = "VENDORS_CATEGORY_PVP",
    quartermaster        = "VENDORS_CATEGORY_QUARTERMASTER",
    reagent              = "VENDORS_CATEGORY_REAGENT",
    repair               = "VENDORS_CATEGORY_REPAIR",
    reputation           = "VENDORS_CATEGORY_REPUTATION",
    stable_master        = "VENDORS_CATEGORY_STABLE_MASTER",
    tabard               = "VENDORS_CATEGORY_TABARD",
    timewalking          = "VENDORS_CATEGORY_TIMEWALKING",
    toy                  = "VENDORS_CATEGORY_TOY",
    transmog             = "VENDORS_CATEGORY_TRANSMOG",
    void_storage         = "VENDORS_CATEGORY_VOID_STORAGE",
}

function VC:GetLabel(key)
    if not key or key == "" then
        return ns.L["VENDORS_CATEGORY_NONE"]
    end
    local localeKey = LOCALE_KEYS[key]
    if localeKey and ns.L and ns.L[localeKey] then
        return ns.L[localeKey]
    end
    return key
end

function VC:IsValid(key)
    if not key then return false end
    return LOCALE_KEYS[key] ~= nil
end

-- Returns the category keys sorted alphabetically by their CURRENT localized
-- label, so the dropdown order respects the active language. Called fresh
-- each time the dropdown menu is opened.
function VC:GetSortedKeys()
    local keys = {}
    for _, key in ipairs(self.ORDER) do
        tinsert(keys, key)
    end
    sort(keys, function(a, b)
        return self:GetLabel(a):lower() < self:GetLabel(b):lower()
    end)
    return keys
end
