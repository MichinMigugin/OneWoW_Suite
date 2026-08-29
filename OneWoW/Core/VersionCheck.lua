local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

-- ============================================================================
-- VersionCheck
-- ============================================================================
-- Peer TOC-version exchange for the core load unit only. Other OneWoW clients
-- announce on hidden addon chat; a strictly newer R#.#.# trips chat, a popup,
-- and a Home attention row. There is no HTTP / CurseForge probe.
--
-- Protocol (prefix ONEWOW_VER):
--   V\t<tocVersion>  announce
--   ?                query; reply with V (whisper / BN when the target is usable)
--
-- Channels: current group (PARTY / RAID / INSTANCE_CHAT), GUILD, YELL once
-- per session, Battle.net Retail friends (staggered). No SAY / CHANNEL.
--
-- Nearby report (REPORT_NEARBY below) is a code-only switch. It ships false
-- so players never see it. Set true to print a chat line when another OneWoW
-- is heard on group / raid / instance / guild / yell / Battle.net.
-- ============================================================================

local C_BattleNet = C_BattleNet
local C_ChatInfo = C_ChatInfo
local C_Timer = C_Timer
local format = string.format
local ipairs = ipairs
local pairs = pairs
local strmatch = string.match
local strsplit = strsplit
local wipe = wipe

-- Dev-only: set true to print nearby OneWoW users in chat. Ships false.
local REPORT_NEARBY = false

local PREFIX = "ONEWOW_VER"
local DOWNLOAD_URL = "https://onewow.net/"
local ANNOUNCE_DELAY = 10
local LOCKDOWN_RETRY = 5
local BN_STAGGER = 0.75
local LOGIN_POPUP_DELAY = 5

local LOCKDOWN = Enum.SendAddonMessageResult.AddOnMessageLockdown

local VersionCheck = {}
ns.VersionCheck = VersionCheck

local announcePending = false
local lockdownRetryPending = false
local sessionWideDone = false
local chatPrinted = false
local popupShownFor = nil
local groupSize = 0
local activeDialog = nil
local bnQueue = {}
-- [kind] = { [id] = true } unique peers heard this session (REPORT_NEARBY).
local nearbySeen = {}

local NEARBY_LABEL = {
    PARTY = "group",
    RAID = "raid",
    INSTANCE_CHAT = "instance",
    GUILD = "guild",
    YELL = "yell range",
    WHISPER = "whisper",
    BN = "Battle.net",
}

--- Parse shipped core TOC versions (`R6.2608.2805`). Unparseable strings
--- (Unknown, Git, hashes) return nil so they never count as newer.
---@param version string|nil
---@return number|nil major
---@return number|nil yymm
---@return number|nil patch
local function ParseVersion(version)
    if type(version) ~= "string" then return nil end
    local major, yymm, patch = strmatch(version, "^R(%d+)%.(%d+)%.(%d+)")
    if not major then return nil end
    return tonumber(major), tonumber(yymm), tonumber(patch)
end

--- True when `remote` is a parseable TOC string strictly greater than `localVer`.
---@param remote string|nil
---@param localVer string|nil
---@return boolean
function VersionCheck.IsNewer(remote, localVer)
    local r1, r2, r3 = ParseVersion(remote)
    local l1, l2, l3 = ParseVersion(localVer)
    if not r1 or not l1 then return false end
    if r1 ~= l1 then return r1 > l1 end
    if r2 ~= l2 then return r2 > l2 end
    return r3 > l3
end

---@return string|nil version nil when missing or unparseable
local function LocalVersion()
    local ver = ns:GetAddonVersion(ADDON_NAME)
    if not ver or not ParseVersion(ver) then return nil end
    return ver
end

local function PruneIfUpdated()
    local localVer = LocalVersion()
    local seen = ns.db.global.remoteUpdateLatestSeen
    if seen == "" or not localVer then return end
    if not VersionCheck.IsNewer(seen, localVer) then
        ns.db.global.remoteUpdateLatestSeen = ""
        ns.db.global.remoteUpdatePopupDismissedVersion = ""
    end
end

---@return boolean
local function WizardPending()
    return ns.FirstRun and ns.FirstRun:ShouldShowWizard()
end

---@param remote string
local function ApplyPopupDismiss(checkbox, remote)
    if not checkbox or remote == "" then return end
    if checkbox:GetChecked() then
        ns.db.global.remoteUpdatePopupDismissedVersion = remote
    elseif ns.db.global.remoteUpdatePopupDismissedVersion == remote then
        ns.db.global.remoteUpdatePopupDismissedVersion = ""
    end
end

---@param remote string
local function ShowPopup(remote)
    if activeDialog and activeDialog.frame and activeDialog.frame:IsShown() then
        return
    end

    local L = ns.L
    local localVer = LocalVersion() or ""
    local result
    local preferenceApplied = false
    local function FinishDialog()
        if preferenceApplied then return end
        preferenceApplied = true
        ApplyPopupDismiss(result and result.checkbox, remote)
        activeDialog = nil
    end

    result = OneWoW_GUI:CreateConfirmDialog({
        name = "OneWoW_VersionCheck",
        addonTitle = "OneWoW",
        title = L["VERSION_CHECK_POPUP_TITLE"],
        message = format(L["VERSION_CHECK_POPUP_BODY"], localVer, remote),
        width = 480,
        showBrand = true,
        checkbox = {
            label = L["VERSION_CHECK_DONT_SHOW"],
            wrap = true,
        },
        buttons = {
            {
                text = CLOSE,
                color = { 0.2, 0.6, 0.2 },
                onClick = function(dialog)
                    FinishDialog()
                    dialog:Hide()
                end,
            },
        },
        onClose = function()
            FinishDialog()
        end,
    })

    if result and result.checkbox then
        result.checkbox:SetChecked(ns.db.global.remoteUpdatePopupDismissedVersion == remote)
    end

    if result and result.frame then
        local downloadBtn = OneWoW_GUI:CreateFitTextButton(result.frame, {
            text = L["VERSION_CHECK_DOWNLOAD_BTN"],
            height = 28,
            minWidth = 80,
        })
        downloadBtn:SetPoint("BOTTOMLEFT", result.frame, "BOTTOMLEFT", 10, 10)
        downloadBtn:SetScript("OnClick", function()
            OneWoW_GUI:ShowCopyURLDialog(L["VERSION_CHECK_DOWNLOAD_BTN"], DOWNLOAD_URL)
        end)

        result.frame:HookScript("OnHide", function()
            FinishDialog()
        end)
    end

    activeDialog = result
    if result and result.frame then
        result.frame:Show()
        result.frame:Raise()
    end
end

---@param remote string
---@param delay number|nil
local function TryPopup(remote, delay)
    if popupShownFor == remote then return end
    if ns.db.global.remoteUpdatePopupDismissedVersion == remote then return end
    if WizardPending() then return end

    local function open()
        if popupShownFor == remote then return end
        if ns.db.global.remoteUpdatePopupDismissedVersion == remote then return end
        if WizardPending() then return end
        popupShownFor = remote
        ShowPopup(remote)
    end

    if delay and delay > 0 then
        C_Timer.After(delay, open)
    else
        open()
    end
end

--- Chat once per session; popup once per remote version this session unless dismissed.
---@param remote string
---@param popupDelay number|nil
local function Notify(remote, popupDelay)
    local L = ns.L
    if not chatPrinted then
        chatPrinted = true
        print("|cFF00FF00OneWoW|r: " .. format(L["VERSION_CHECK_CHAT"], remote))
    end
    TryPopup(remote, popupDelay)
end

---@param remote string
---@param popupDelay number|nil
local function AcceptRemote(remote, popupDelay)
    local localVer = LocalVersion()
    if not localVer or not VersionCheck.IsNewer(remote, localVer) then
        return
    end

    local prev = ns.db.global.remoteUpdateLatestSeen
    if prev == "" or VersionCheck.IsNewer(remote, prev) then
        ns.db.global.remoteUpdateLatestSeen = remote
        EventRegistry:TriggerEvent("ns.FeatureStateChanged", "remote_update")
    end

    Notify(remote, popupDelay)
end

local function ScheduleLockdownRetry()
    if lockdownRetryPending then return end
    lockdownRetryPending = true
    C_Timer.After(LOCKDOWN_RETRY, function()
        lockdownRetryPending = false
        sessionWideDone = false
        ns.VersionCheck.Announce()
    end)
end

---@param result number
---@return boolean lockdown
local function NoteSendResult(result)
    if result == LOCKDOWN then
        ScheduleLockdownRetry()
        return true
    end
    return false
end

---@param message string
---@param chatType string
---@param target string|nil
local function SendChat(message, chatType, target)
    local result = C_ChatInfo.SendAddonMessage(PREFIX, message, chatType, target)
    NoteSendResult(result)
end

---@param message string
local function SendGroup(message)
    if IsInRaid() then
        local instanceOnly = not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)
        SendChat(message, instanceOnly and "INSTANCE_CHAT" or "RAID")
    elseif IsInGroup() then
        local instanceOnly = not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
        SendChat(message, instanceOnly and "INSTANCE_CHAT" or "PARTY")
    end
end

---@param message string
local function SendGuild(message)
    if IsInGuild() then
        SendChat(message, "GUILD")
    end
end

---@param gameAccountID number
---@param message string
local function SendBNAccount(gameAccountID, message)
    local result = C_BattleNet.SendGameData(gameAccountID, PREFIX, message)
    if NoteSendResult(result) then
        sessionWideDone = false
    end
end

---@param message string
local function SendBN(message)
    wipe(bnQueue)
    local myGUID = UnitGUID("player")
    local numFriends = BNGetNumFriends()
    for i = 1, numFriends do
        local numAccounts = C_BattleNet.GetFriendNumGameAccounts(i)
        for j = 1, numAccounts do
            local info = C_BattleNet.GetFriendGameAccountInfo(i, j)
            if info and info.isOnline and info.gameAccountID and info.gameAccountID > 0
                and info.clientProgram == "WoW"
                and (not info.wowProjectID or info.wowProjectID == WOW_PROJECT_ID)
                and info.playerGuid ~= myGUID
            then
                bnQueue[#bnQueue + 1] = info.gameAccountID
            end
        end
    end

    for index, gameAccountID in ipairs(bnQueue) do
        local delay = (index - 1) * BN_STAGGER
        local accountID = gameAccountID
        C_Timer.After(delay, function()
            SendBNAccount(accountID, message)
        end)
    end
end

--- Broadcast this client's parseable TOC version.
function VersionCheck.Announce()
    local ver = LocalVersion()
    if not ver then return end

    local payload = "V\t" .. ver
    SendGroup(payload)
    SendGuild(payload)

    if not sessionWideDone then
        sessionWideDone = true
        SendChat(payload, "YELL")
        SendBN(payload)
    end
end

local function ScheduleAnnounce()
    if announcePending then return end
    announcePending = true
    C_Timer.After(ANNOUNCE_DELAY, function()
        announcePending = false
        VersionCheck.Announce()
    end)
end

--- Chat line when a new OneWoW peer is heard on a channel. Names are not
--- printed (instance senders can be secret). Secret / missing ids collapse
--- to one slot per channel so the count is "at least one".
---@param kindKey string PARTY / RAID / INSTANCE_CHAT / GUILD / YELL / WHISPER / BN
---@param peerID string|nil
local function NoteNearby(kindKey, peerID)
    if not REPORT_NEARBY then return end
    local label = NEARBY_LABEL[kindKey]
    if not label then return end

    local id = peerID
    if not id or id == "" or ns.Restriction.IsSecretValue(id) then
        id = "?"
    end

    local bucket = nearbySeen[kindKey]
    if not bucket then
        bucket = {}
        nearbySeen[kindKey] = bucket
    end
    if bucket[id] then return end
    bucket[id] = true

    local n = 0
    for _ in pairs(bucket) do
        n = n + 1
    end
    print("|cFF00FF00OneWoW|r: Nearby: " .. label .. " (" .. n .. ")")
end

---@param sender string|nil
---@return boolean
local function IsSelfChatSender(sender)
    if not sender or sender == "" then return false end
    if ns.Restriction.IsSecretValue(sender) then return false end
    local name, realm = strsplit("-", sender, 2)
    local myName = UnitName("player")
    if name ~= myName then return false end
    if not realm or realm == "" then return true end
    local norm = GetNormalizedRealmName()
    local raw = GetRealmName()
    return realm == norm or realm == raw
end

---@param text string
---@param reply fun(message: string)
---@param kindKey string
---@param peerID string|nil
local function HandlePayload(text, reply, kindKey, peerID)
    NoteNearby(kindKey, peerID)

    if text == "?" then
        local ver = LocalVersion()
        if ver then
            reply("V\t" .. ver)
        end
        return
    end

    local remote = strmatch(text, "^V\t(.+)$")
    if remote then
        AcceptRemote(remote)
    end
end

local function OnChatAddon(_, prefix, text, channel, sender)
    if prefix ~= PREFIX or not text then return end
    if IsSelfChatSender(sender) then return end

    HandlePayload(text, function(message)
        if sender and sender ~= "" and not ns.Restriction.IsSecretValue(sender) then
            SendChat(message, "WHISPER", sender)
        elseif channel and channel ~= "" then
            SendChat(message, channel)
        end
    end, channel, sender)
end

local function OnBNChatAddon(_, prefix, text, _, senderID)
    if prefix ~= PREFIX or not text then return end
    local peerID = senderID and senderID > 0 and tostring(senderID) or nil
    HandlePayload(text, function(message)
        if senderID and senderID > 0 then
            SendBNAccount(senderID, message)
        end
    end, "BN", peerID)
end

local function OnGroupRoster()
    local num = GetNumGroupMembers()
    if num > 1 and num > groupSize then
        ScheduleAnnounce()
    end
    groupSize = num
end

local function NotifyPersisted()
    local seen = ns.db.global.remoteUpdateLatestSeen
    local localVer = LocalVersion()
    if seen ~= "" and localVer and VersionCheck.IsNewer(seen, localVer) then
        Notify(seen, LOGIN_POPUP_DELAY)
    end
end

ns:RegisterCoreLoginHandler("VersionCheck", function()
    PruneIfUpdated()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    ns.RegisterEvent("CHAT_MSG_ADDON", "VersionCheck", OnChatAddon)
    ns.RegisterEvent("BN_CHAT_MSG_ADDON", "VersionCheck", OnBNChatAddon)
    ns.RegisterEvent("GROUP_ROSTER_UPDATE", "VersionCheck", OnGroupRoster)
    groupSize = GetNumGroupMembers()
    NotifyPersisted()
end)

ns:RegisterCoreEnteringWorldHandler("VersionCheck", function()
    ScheduleAnnounce()
end)
