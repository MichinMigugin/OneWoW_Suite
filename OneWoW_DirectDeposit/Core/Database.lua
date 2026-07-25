local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
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
            warboundExcludeExpr = "",
            warboundExcludeList = {},
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

function ns:InitializeDatabase()
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
    ns.db = db

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

    -- The warband exclusion rule is a user-authored expression, so a rename or
    -- delete elsewhere in the suite can report what it would cost here.
    OneWoW.SearchCatalog:RegisterExpressionSource("directdeposit_warbound", {
        sourceLabel = "Direct Deposit — Warband Exclusions",
        Enumerate = function()
            local expr = ns.db.global.directDeposit.warboundExcludeExpr
            if type(expr) ~= "string" or expr == "" then return {} end
            return { { expression = expr, label = "Warband exclude rule" } }
        end,
    })
end
