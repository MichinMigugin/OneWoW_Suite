local ADDON_NAME, OneWoW_DirectDeposit = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

local defaults = {
    global = {
        language = GetLocale(),
        theme = "green",
        mainFramePosition = {},
        minimap = {
            hide = false,
            minimapPos = 220,
            theme = "horde",
        },
        directDeposit = {
            enabled = false,
            -- targetGold omitted: nil = not configured, 0 = keep zero on character.
            -- Do NOT add targetGold = 0 here — MergeMissing would refill nil every login.
            depositEnabled = false,
            withdrawEnabled = false,
            itemDepositEnabled = false,
            itemList = {},
            tooltipEnabled = true,
            warboundAutoDeposit = false,
        },
    },
    char = {
        directDeposit = {
            useAccountSettings = true,
            -- targetGold omitted: nil = not configured, 0 = keep zero on character.
            -- Do NOT add targetGold = 0 here — MergeMissing would refill nil every login.
            depositEnabled = false,
            withdrawEnabled = false,
        },
    },
}

function OneWoW_DirectDeposit:InitializeDatabase()
    local sv = OneWoW_DirectDeposit_DB
    if sv and not sv.global and next(sv) ~= nil then
        local oldData = {}
        for k, v in pairs(sv) do
            oldData[k] = v
        end
        wipe(sv)
        sv.global = oldData
    end

    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar  = "OneWoW_DirectDeposit_DB",
        defaults  = defaults,
    })
    self.db = db

    local legacy = OneWoW_DirectDeposit_CharDB
    if legacy and not db.char._charDBMigrated then
        if type(legacy.directDeposit) == "table" then
            for k, v in pairs(legacy.directDeposit) do
                if type(v) == "table" then
                    db.char.directDeposit[k] = CopyTable(v)
                else
                    db.char.directDeposit[k] = v
                end
            end
        end
        db.char._charDBMigrated = true
    end

    DB:RunMigrations(db, {
        { version = 1, name = "item_list_default_bank_type", run = function(d)
            local list = d.global.directDeposit.itemList
            for _, itemData in pairs(list) do
                if itemData and not itemData.bankType then
                    itemData.bankType = "personal"
                end
            end
        end },
        { version = 2, name = "item_list_normalize_keys", run = function(d)
            local list = d.global.directDeposit.itemList
            local cleaned = {}
            for key, itemData in pairs(list) do
                local id = tonumber(key)
                if itemData and id and id > 0 then
                    cleaned[tostring(id)] = itemData
                end
            end
            d.global.directDeposit.itemList = cleaned
        end },
        { version = 3, name = "cleanup_legacy_root_keys", run = function(d)
            local keep = {
                global = true, chars = true, realms = true, factions = true,
                classes = true, specs = true, presets = true,
                _activePreset = true, _migrationVersion = true,
            }
            local root = d.root
            if not root then return end
            for k in pairs(root) do
                if not keep[k] then root[k] = nil end
            end
        end },
        { version = 4, name = "target_gold_unset_nil", run = function(d)
            local function clearLegacyUnsetTargetGold(dd)
                if type(dd) == "table" and dd.targetGold == 0 then
                    dd.targetGold = nil
                end
            end
            clearLegacyUnsetTargetGold(d.global.directDeposit)
            local root = d.root
            if root and root.chars then
                for _, charData in pairs(root.chars) do
                    if type(charData) == "table" then
                        clearLegacyUnsetTargetGold(charData.directDeposit)
                    end
                end
            end
        end },
    })
end
