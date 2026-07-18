local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local defaults = {
    global = {
        language = GetLocale(),
        theme = "green",
        mainFramePosition = {},
        minimap = {
            hide = true,
            minimapPos = 200,
            theme = "horde",
        },
        mail = {
            keepFreeSlots = 1,
            autoFillLastRecipient = false,
            excessGoldKeepCopper = 0,
            bankerTarget = "",
            lastRecipient = "",
            favorites = {},
            contacts = {}, -- { { name = "Name-Realm", note = "" }, ... }
            recent = {}, -- up to 20 "Name-Realm"
            blacklistItemIDs = {}, -- [itemID] = true
            shipments = {}, -- array of shipment tables
            selected = {}, -- selected inbox indices (session; not persisted meaningfully)
        },
    },
}

function ns:InitializeDatabase()
    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar  = "OneWoW_Mail_DB",
        defaults  = defaults,
    })
    ns.db = db

    if #db.global.mail.shipments == 0 then
        ns:EnsurePresetShipments()
    end

    for _, shipment in ipairs(db.global.mail.shipments) do
        -- Soulbound exclusion is applied at plan time; strip leftover suffixes from older saves.
        if type(shipment.match) == "string" then
            shipment.match = shipment.match:gsub("%s*&%s*!#soulbound%s*$", "")
        end
        -- Tri-state auto-run `mode` replaced the `enabled` boolean (Jul 2026).
        -- Old `enabled` only gated the bulk-run path, which auto_preview now
        -- subsumes (runs on mailbox open, user confirms before sending).
        if not shipment.mode then
            shipment.mode = shipment.enabled and "auto_preview" or "manual"
        end
        shipment.enabled = nil
    end
end

--- Seed manual-mode preset shipments once (cloth/leather/metal/herb/DE).
function ns:EnsurePresetShipments()
    local shipments = ns.db.global.mail.shipments
    if #shipments > 0 then
        return
    end

    local presets = {
        {
            id = "preset_cloth",
            name = "Cloth",
            mode = "manual",
            match = "#craftingreagentcloth",
            target = "",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = { bags = true, bank = true, guild = false },
            exclusions = {},
        },
        {
            id = "preset_leather",
            name = "Leather",
            mode = "manual",
            match = "#craftingreagentleather",
            target = "",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = { bags = true, bank = true, guild = false },
            exclusions = {},
        },
        {
            id = "preset_metal",
            name = "Metal / Ore",
            mode = "manual",
            match = "#craftingreagentmetal",
            target = "",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = { bags = true, bank = true, guild = false },
            exclusions = {},
        },
        {
            id = "preset_herb",
            name = "Herbs",
            mode = "manual",
            match = "#craftingreagentherb",
            target = "",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = { bags = true, bank = true, guild = false },
            exclusions = {},
        },
        {
            id = "preset_de",
            name = "Disenchantables",
            mode = "manual",
            match = "#disenchantable & quality<=2",
            target = "",
            keepQty = 0,
            maxQtyEnabled = false,
            maxQty = 0,
            restock = false,
            restockSources = { bags = true, bank = true, guild = false },
            exclusions = {},
        },
    }

    for _, p in ipairs(presets) do
        tinsert(shipments, p)
    end
end
