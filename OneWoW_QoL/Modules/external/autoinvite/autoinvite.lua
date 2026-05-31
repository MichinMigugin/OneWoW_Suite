-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/autoinvite/autoinvite.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local AutoInviteModule = {
    id          = "autoinvite",
    title       = "AUTOINVITE_TITLE",
    category    = "SOCIAL",
    description = "AUTOINVITE_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "from_friends", label = "AUTOINVITE_TOGGLE_FRIENDS", description = "AUTOINVITE_TOGGLE_FRIENDS_DESC", default = true },
        { id = "from_guild",   label = "AUTOINVITE_TOGGLE_GUILD",   description = "AUTOINVITE_TOGGLE_GUILD_DESC",   default = true },
        { id = "from_all",     label = "AUTOINVITE_TOGGLE_ALL",     description = "AUTOINVITE_TOGGLE_ALL_DESC",     default = false },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
}

-- Inviter name may arrive cross-realm as "Name-Realm". Compare against bare name too.
local function NameMatches(candidate, target)
    if not candidate or not target then return false end
    if candidate == target then return true end
    local bare = strsplit("-", candidate)
    return bare == target
end

local function IsWoWFriend(name)
    local num = C_FriendList.GetNumFriends()
    for i = 1, num do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and NameMatches(info.name, name) then
            return true
        end
    end
    return false
end

local function IsBNetFriend(name)
    local num = BNGetNumFriends()
    for i = 1, num do
        local acct = C_BattleNet.GetFriendAccountInfo(i)
        if acct and acct.gameAccountInfo then
            local g = acct.gameAccountInfo
            if NameMatches(g.characterName, name) then
                return true
            end
        end
    end
    return false
end

local function IsGuildMate(name)
    if not IsInGuild() then return false end
    local num = GetNumGuildMembers()
    for i = 1, num do
        local fullName = GetGuildRosterInfo(i)
        if NameMatches(fullName, name) then
            return true
        end
    end
    return false
end

function AutoInviteModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoInvite")
        self._frame:SetScript("OnEvent", function(_, event, ...)
            if event == "PARTY_INVITE_REQUEST" then
                self:PARTY_INVITE_REQUEST(...)
            end
        end)
    end
    self._frame:RegisterEvent("PARTY_INVITE_REQUEST")
end

function AutoInviteModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

function AutoInviteModule:PARTY_INVITE_REQUEST(name)
    if not name or name == "" then return end

    -- Don't auto-accept if already grouped — likely a raid-conversion situation
    -- the user should review.
    if IsInGroup() then return end

    local acceptAll = ns.ModuleRegistry:GetToggleValue("autoinvite", "from_all")
    local fromFriends = ns.ModuleRegistry:GetToggleValue("autoinvite", "from_friends")
    local fromGuild = ns.ModuleRegistry:GetToggleValue("autoinvite", "from_guild")

    local accept = false
    if acceptAll then
        accept = true
    else
        if fromFriends and (IsWoWFriend(name) or IsBNetFriend(name)) then
            accept = true
        elseif fromGuild and IsGuildMate(name) then
            accept = true
        end
    end

    if not accept then return end

    AcceptGroup()
    StaticPopup_Hide("PARTY_INVITE")
    StaticPopup_Hide("PARTY_INVITE_XREALM")
end

ns.AutoInviteModule = AutoInviteModule
