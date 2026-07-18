local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

ns.AddressBook = {}
local AddressBook = ns.AddressBook

--- Normalize a mail recipient for Blizzard SendMail.
--- Same-realm "Name-OwnRealm" silently fails — strip own realm only.
---@param recipient string
---@return string
function AddressBook:NormalizeRecipient(recipient)
    if not recipient or recipient == "" then
        return ""
    end
    recipient = strtrim(recipient)
    local name, realm = strsplit("-", recipient, 2)
    if not realm or realm == "" then
        return name
    end
    local ownRealm = GetNormalizedRealmName() or GetRealmName() or ""
    ownRealm = ownRealm:gsub("%s+", "")
    local realmNorm = realm:gsub("%s+", "")
    if strlower(realmNorm) == strlower(ownRealm) then
        return name
    end
    return name .. "-" .. realm
end

--- Resolve a typed/send recipient to the canonical AltTracker charKey (`Name-Realm`).
--- Bare same-realm names use the current realm. SendMail still uses NormalizeRecipient.
---@param recipient string
---@return string|nil charKey
function AddressBook:ResolveCharKey(recipient)
    recipient = strtrim(recipient or "")
    if recipient == "" then
        return nil
    end

    local name, realm = strsplit("-", recipient, 2)
    name = strtrim(name or "")
    if name == "" then
        return nil
    end
    if not realm or strtrim(realm) == "" then
        realm = GetRealmName()
    end

    local candidate = OneWoW_GUI:GetCharacterKey(name, realm)
    local API = OneWoW_AltTracker_Character_API
    if not API or not API.GetAllCharacters then
        return nil
    end
    local chars = API.GetAllCharacters()

    if candidate and chars[candidate] then
        return candidate
    end

    if candidate then
        local wantKey = strlower(candidate)
        for charKey in pairs(chars) do
            if strlower(charKey) == wantKey then
                return charKey
            end
        end
    end

    local wantName = strlower(name)
    local wantRealm = realm and strlower((tostring(realm):gsub("%s+", ""))) or nil
    for charKey, data in pairs(chars) do
        local dName = data and (data.name or data.charName)
        local dRealm = data and (data.realm or data.realmName)
        if dName and strlower(dName) == wantName then
            if not wantRealm or (dRealm and strlower((dRealm:gsub("%s+", ""))) == wantRealm) then
                if dName and dRealm then
                    return OneWoW_GUI:GetCharacterKey(dName, dRealm) or charKey
                end
                return charKey
            end
        end
    end

    return nil
end

--- True if this recipient is a known suite character.
---@param recipient string
---@return boolean
---@return string|nil charKey canonical `Name-Realm` when known
function AddressBook:IsSuiteAlt(recipient)
    local charKey = self:ResolveCharKey(recipient)
    return charKey ~= nil, charKey
end

--- Build address suggestions: alts → favorites → recent → contacts → friends → guild.
---@return table entries { { text, source, classFile? }, ... }
function AddressBook:GetSuggestions()
    local out = {}
    local seen = {}

    local function add(text, source, classFile)
        if not text or text == "" then
            return
        end
        local key = strlower(text)
        if seen[key] then
            return
        end
        seen[key] = true
        tinsert(out, { text = text, source = source, classFile = classFile })
    end

    local playerName = UnitName("player")
    local API = OneWoW_AltTracker_Character_API
    if API and API.GetAllCharacters then
        for charKey, data in pairs(API.GetAllCharacters()) do
            local name = data and data.name
            local realm = data and (data.realm or data.realmName)
            if name and name ~= playerName then
                local display = (name and realm and OneWoW_GUI:GetCharacterKey(name, realm)) or charKey
                add(display, "alt", data.classFile or data.class)
            end
        end
    end

    local mail = ns.db.global.mail
    for _, fav in ipairs(mail.favorites or {}) do
        add(fav, "favorite")
    end
    for _, recent in ipairs(mail.recent or {}) do
        add(recent, "recent")
    end
    for _, contact in ipairs(mail.contacts or {}) do
        add(contact.name, "contact")
    end

    local n = C_FriendList.GetNumFriends()
    for i = 1, n do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name then
            add(info.name, "friend")
        end
    end

    if IsInGuild() then
        local n = GetNumGuildMembers()
        for i = 1, n do
            local name = GetGuildRosterInfo(i)
            if name then
                add(name, "guild")
            end
        end
    end

    return out
end

--- Record a successful send recipient into recent (max 20).
---@param recipient string
function AddressBook:RememberRecipient(recipient)
    recipient = self:NormalizeRecipient(recipient)
    if recipient == "" then
        return
    end
    local mail = ns.db.global.mail
    mail.lastRecipient = recipient
    local recent = mail.recent
    for i = #recent, 1, -1 do
        if strlower(recent[i]) == strlower(recipient) then
            tremove(recent, i)
        end
    end
    tinsert(recent, 1, recipient)
    while #recent > 20 do
        tremove(recent)
    end
end

--- Filter suggestions by typed prefix.
---@param prefix string
---@return table
function AddressBook:Autocomplete(prefix)
    prefix = strlower(strtrim(prefix or ""))
    -- Empty prefix is not a filter — callers must type before we suggest.
    if prefix == "" then
        return {}
    end
    local out = {}
    for _, entry in ipairs(self:GetSuggestions()) do
        if strfind(strlower(entry.text), prefix, 1, true) == 1 then
            tinsert(out, entry)
        end
    end
    return out
end
