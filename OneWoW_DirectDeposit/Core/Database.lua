local ADDON_NAME, OneWoW_DirectDeposit = ...

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
            targetGold = 0,
            depositEnabled = false,
            withdrawEnabled = false,
            itemDepositEnabled = false,
            itemList = {}
        }
    },
    char = {
        directDeposit = {
            useAccountSettings = true,
            targetGold = 0,
            depositEnabled = false,
            withdrawEnabled = false
        }
    }
}

function OneWoW_DirectDeposit:InitializeDatabase()
    if not OneWoW_DirectDeposit_DB then
        OneWoW_DirectDeposit_DB = CopyTable(defaults.global)
    end

    if not OneWoW_DirectDeposit_CharDB then
        OneWoW_DirectDeposit_CharDB = CopyTable(defaults.char)
    end

    self.db = {
        global = OneWoW_DirectDeposit_DB,
        char = OneWoW_DirectDeposit_CharDB
    }

    if not self.db.global.directDeposit.itemDepositEnabled then
        self.db.global.directDeposit.itemDepositEnabled = false
    end

    if not self.db.global.directDeposit.itemList then
        self.db.global.directDeposit.itemList = {}
    end

    if not self.db.global.language then
        self.db.global.language = GetLocale()
    end

    if not self.db.global.theme then
        self.db.global.theme = "green"
    end

    if not self.db.global.minimap then
        self.db.global.minimap = {}
    end
    if self.db.global.minimap.hide == nil then
        self.db.global.minimap.hide = false
    end
    if self.db.global.minimap.minimapPos == nil then
        self.db.global.minimap.minimapPos = 220
    end
    if not self.db.global.minimap.theme then
        self.db.global.minimap.theme = "horde"
    end
end
