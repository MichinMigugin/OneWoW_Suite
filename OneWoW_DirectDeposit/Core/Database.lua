local _, OneWoW_DirectDeposit = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DEFAULTS = {
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
        targetGold = 0,
        depositEnabled = false,
        withdrawEnabled = false,
        itemDepositEnabled = false,
        itemList = {},
    },
}

local CHAR_DEFAULTS = {
    directDeposit = {
        useAccountSettings = true,
        targetGold = 0,
        depositEnabled = false,
        withdrawEnabled = false,
    },
}

function OneWoW_DirectDeposit:InitializeDatabase()
    if not OneWoW_DirectDeposit_DB then
        OneWoW_DirectDeposit_DB = CopyTable(DEFAULTS)
    end
    if not OneWoW_DirectDeposit_CharDB then
        OneWoW_DirectDeposit_CharDB = CopyTable(CHAR_DEFAULTS)
    end

    self.db = {
        global = OneWoW_DirectDeposit_DB,
        char   = OneWoW_DirectDeposit_CharDB,
    }

    OneWoW_GUI.DB:MergeMissing(self.db.global, DEFAULTS)
    OneWoW_GUI.DB:MergeMissing(self.db.char, CHAR_DEFAULTS)
end
