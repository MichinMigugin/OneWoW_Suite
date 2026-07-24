local _, ns = ...

ns.DataManager = {}
local DataManager = ns.DataManager

local Inventory = OneWoW.Inventory

local eventFrame = nil
local initialized = false
local inventoryArmed = false

-- Post-write storage-change subscribers (ItemIndex, the AltTracker Items tab).
local storageListeners = {}

local INVENTORY_OWNER = "AltTracker_Storage"

function DataManager:Initialize()
    if initialized then return end
    initialized = true
end

-- Bag/bank/guild WoW events route through OneWoW.Inventory. Mail / logout stay
-- on a local frame (not Inventory-owned yet).
function DataManager:RegisterEvents()
    if not inventoryArmed then
        inventoryArmed = true
        Inventory.RegisterDelayedCallback(INVENTORY_OWNER, function()
            DataManager:OnInventoryDelayed()
        end)
        Inventory.RegisterBankOpenCallback(INVENTORY_OWNER, function()
            DataManager:OnBankOpened()
        end)
        Inventory.RegisterGuildOpenCallback(INVENTORY_OWNER, function()
            DataManager:OnGuildBankOpened()
        end)
        Inventory.RegisterGuildTabsCallback(INVENTORY_OWNER, function()
            DataManager:OnGuildBankTabsUpdated()
        end)
        Inventory.RegisterGuildSlotsCallback(INVENTORY_OWNER, function()
            DataManager:OnGuildBankSlotsChanged()
        end)
    end

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    local events = {
        "MAIL_SHOW",
        "MAIL_CLOSED",
        "MAIL_INBOX_UPDATE",
        "UPDATE_PENDING_MAIL",
        "PLAYER_LOGOUT",
    }

    for _, event in ipairs(events) do
        eventFrame:RegisterEvent(event)
    end

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        DataManager:HandleEvent(event, ...)
    end)
end

function DataManager:OnEnteringWorld()
    -- On login / reload / zone, make sure the current character's mail flag reflects
    -- reality before the UI reads it. HasNewMail() is ready by this point.
    C_Timer.After(1, function()
        self:UpdateMailFlag()
    end)
end

--- Inventory delayed channel: bags always; personal/warband when those banks are usable.
function DataManager:OnInventoryDelayed()
    self:CollectBags()

    if C_Bank.CanUseBank(Enum.BankType.Character) then
        C_Timer.After(0.3, function()
            self:CollectPersonalBank()
        end)
    end

    if C_Bank.CanUseBank(Enum.BankType.Account) then
        C_Timer.After(0.3, function()
            self:CollectWarbandBank()
        end)
    end
end

--- Inventory bank-open channel: full personal (+ warband when usable) collect.
function DataManager:OnBankOpened()
    C_Timer.After(0.5, function()
        self:CollectPersonalBank()
    end)

    if C_Bank.CanUseBank(Enum.BankType.Account) then
        C_Timer.After(0.5, function()
            self:CollectWarbandBank()
        end)
    end
end

--- Inventory guild-open channel.
function DataManager:OnGuildBankOpened()
    C_Timer.After(0.5, function()
        self:CollectGuildBank()
    end)
end

--- Inventory guild-tabs channel.
function DataManager:OnGuildBankTabsUpdated()
    C_Timer.After(0.2, function()
        self:CollectGuildBank()
    end)
end

--- Inventory guild-slots channel (already coalesced ~0.2s in Inventory).
function DataManager:OnGuildBankSlotsChanged()
    C_Timer.After(0.1, function()
        self:CollectGuildBank()
    end)
end

function DataManager:HandleEvent(event)
    if event == "MAIL_SHOW" then
        C_Timer.After(0.5, function()
            self:CollectMail()
        end)

    elseif event == "MAIL_INBOX_UPDATE" then
        -- Inbox contents actually changed while the mailbox is open: full scan is safe.
        C_Timer.After(0.2, function()
            self:CollectMail()
        end)

    elseif event == "UPDATE_PENDING_MAIL" then
        -- Fires whenever the server flips the "you have new mail" indicator.
        -- This fires away from the mailbox too, so we MUST NOT do a full inbox
        -- scan here (that would return 0 items and wipe the flag). Just refresh
        -- hasNewMail from HasNewMail() and tell the UI to re-skin its icons.
        C_Timer.After(0.2, function()
            self:UpdateMailFlag()
        end)

    elseif event == "MAIL_CLOSED" then
        C_Timer.After(0.2, function()
            self:CollectMail()
        end)

    elseif event == "PLAYER_LOGOUT" then
        -- Persist final state so other alts can see "Alt X had mail at logout".
        self:UpdateMailFlag()
    end
end

function DataManager:CollectBags()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if OneWoW_AltTracker_Storage_DB.settings.trackBags then
        ns.Bags:CollectData(charKey, charData)
        self:NotifyStorageChanged("bags", charKey)
    end

    if OneWoW_AltTracker and OneWoW_AltTracker.UI and OneWoW_AltTracker.UI.BankTab then
        local bankTab = OneWoW_AltTracker.UI.BankTab
        if bankTab and bankTab:IsVisible() and OneWoW_AltTracker.UI.RefreshBankDisplay then
            C_Timer.After(0.1, function()
                OneWoW_AltTracker.UI.RefreshBankDisplay(bankTab)
            end)
        end
    end

    return true
end

function DataManager:CollectPersonalBank()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if OneWoW_AltTracker_Storage_DB.settings.trackPersonalBank then
        ns.PersonalBank:CollectData(charKey, charData)
        self:NotifyStorageChanged("personal", charKey)
    end

    if OneWoW_AltTracker and OneWoW_AltTracker.UI and OneWoW_AltTracker.UI.BankTab then
        local bankTab = OneWoW_AltTracker.UI.BankTab
        if bankTab and bankTab:IsVisible() and OneWoW_AltTracker.UI.RefreshBankDisplay then
            C_Timer.After(0.1, function()
                OneWoW_AltTracker.UI.RefreshBankDisplay(bankTab)
            end)
        end
    end

    return true
end

function DataManager:CollectWarbandBank()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if OneWoW_AltTracker_Storage_DB.settings.trackWarbandBank then
        ns.WarbandBank:CollectData(charKey, charData)
        self:NotifyStorageChanged("warband", charKey)
    end

    if OneWoW_AltTracker and OneWoW_AltTracker.UI and OneWoW_AltTracker.UI.BankTab then
        local bankTab = OneWoW_AltTracker.UI.BankTab
        if bankTab and bankTab:IsVisible() and OneWoW_AltTracker.UI.RefreshBankDisplay then
            C_Timer.After(0.1, function()
                OneWoW_AltTracker.UI.RefreshBankDisplay(bankTab)
            end)
        end
    end

    return true
end

function DataManager:CollectGuildBank()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if OneWoW_AltTracker_Storage_DB.settings.trackGuildBank then
        ns.GuildBank:CollectData(charKey, charData)
        self:NotifyStorageChanged("guild", charKey)
    end

    if OneWoW_AltTracker and OneWoW_AltTracker.UI and OneWoW_AltTracker.UI.BankTab then
        local bankTab = OneWoW_AltTracker.UI.BankTab
        if bankTab and bankTab:IsVisible() and OneWoW_AltTracker.UI.RefreshBankDisplay then
            C_Timer.After(0.1, function()
                OneWoW_AltTracker.UI.RefreshBankDisplay(bankTab)
            end)
        end
    end

    return true
end

function DataManager:CollectMail()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if OneWoW_AltTracker_Storage_DB.settings.trackMail then
        ns.Mail:CollectData(charKey, charData)
        self:NotifyStorageChanged("mail", charKey)
    end

    self:NotifyMailChanged()
    return true
end

function DataManager:UpdateMailFlag()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if ns.Mail and ns.Mail.UpdateHasNewMailFlag then
        ns.Mail:UpdateHasNewMailFlag(charKey, charData)
    end

    self:NotifyMailChanged()
    return true
end

-- Ask AltTracker's UI (if present and loaded) to re-skin any mail icons it has on
-- screen. We don't rebuild tabs here; AltTracker exposes a cheap in-place refresh.
function DataManager:NotifyMailChanged()
    local atUI = OneWoW_AltTracker and OneWoW_AltTracker.UI
    if atUI and type(atUI.RefreshMailIcons) == "function" then
        atUI.RefreshMailIcons()
    end
end

-- Subscribe to post-write storage-change signals. Listeners receive a
-- { scope, charKey } table. DataManager owns the guild/mail WoW events and the
-- post-write bus; bag/bank WoW events come from OneWoW.Inventory.
function DataManager:RegisterStorageChanged(fn)
    if type(fn) == "function" then
        storageListeners[#storageListeners + 1] = fn
    end
end

-- Fired by each Collect* after its SavedVariables write. One bad listener must
-- not stop the rest, so each call is isolated.
function DataManager:NotifyStorageChanged(scope, charKey)
    if #storageListeners == 0 then return end
    local info = { scope = scope, charKey = charKey }
    for _, fn in ipairs(storageListeners) do
        local ok, err = pcall(fn, info)
        if not ok then geterrorhandler()(err) end
    end
end

function DataManager:CollectAllData()
    self:CollectBags()

    return true
end

function DataManager:GetCharacterData(charKey)
    return ns:GetCharacterData(charKey)
end

function DataManager:GetAllCharacters()
    return ns:GetAllCharacters()
end

function DataManager:DeleteCharacter(charKey)
    return ns:DeleteCharacter(charKey)
end
