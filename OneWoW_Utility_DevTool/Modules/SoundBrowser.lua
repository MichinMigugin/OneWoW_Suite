local _, Addon = ...

local SB = {}
Addon.SoundBrowser = SB

local format = format
local sort, tinsert, wipe = sort, tinsert, wipe
local pairs = pairs
local type, tonumber = type, tonumber
local strfind = string.find

local ALL_SEARCH_MIN_LENGTH = 3
local ALL_SEARCH_CHUNK_SIZE = 4000
local ALL_SEARCH_TICK_SECONDS = 0.01

SB.filtered = {}
SB.selectedTop = nil
SB.selectedSub = nil
SB.filterText = ""
SB.favoritesOnly = false
SB.searchScope = "current"

SB._topKeysCache = nil
SB._subKeysCache = nil
SB._subKeysCacheTop = nil
SB._isRebuilding = false
SB._searchTicker = nil
SB._searchGeneration = 0
SB._filteredReadyCallback = nil

local function getEntryString(entryRef)
    if type(entryRef) == "number" then
        return Addon._SoundEntries and Addon._SoundEntries[entryRef]
    end
    if type(entryRef) == "string" then
        return entryRef
    end
    return nil
end

local function parseEntry(entryRef)
    local entry = getEntryString(entryRef)
    if type(entry) ~= "string" then
        return nil
    end
    local top, sub, tail, fdidStr = entry:match("^([^;]*);([^;]*);(.+);([^;]+)$")
    if not top then
        return nil
    end
    return entry, top, sub, tail, fdidStr
end

local function compareEntryRefs(a, b)
    local _, aTop, aSub, aTail, aFdid = parseEntry(a)
    local _, bTop, bSub, bTail, bFdid = parseEntry(b)
    if aTail ~= bTail then
        return aTail < bTail
    end
    if aTop ~= bTop then
        return aTop < bTop
    end
    if aSub ~= bSub then
        return aSub < bSub
    end
    return aFdid < bFdid
end

local function cancelActiveSearch(self)
    if self._searchTicker then
        self._searchTicker:Cancel()
        self._searchTicker = nil
    end
    self._isRebuilding = false
end

local function notifyFilteredReady(self)
    local callback = self._filteredReadyCallback
    if type(callback) == "function" then
        callback()
    end
end

function SB:IsDataAvailable()
    return type(Addon._SoundEntries) == "table" and type(Addon._SoundSlices) == "table"
end

function SB:ResetAfterAssetUnload()
    self:CancelSearch()
    self._topKeysCache = nil
    self._subKeysCache = nil
    self._subKeysCacheTop = nil
    self._isRebuilding = false
    self.selectedTop = nil
    self.selectedSub = nil
    self.filterText = ""
    self.favoritesOnly = false
    self.searchScope = "current"
    wipe(self.filtered)
    self._filteredReadyCallback = nil
end

function SB:SetFilteredReadyCallback(callback)
    self._filteredReadyCallback = callback
end

function SB:IsRebuilding()
    return self._isRebuilding
end

function SB:GetAllSearchMinLength()
    return ALL_SEARCH_MIN_LENGTH
end

function SB:CancelSearch()
    self._searchGeneration = self._searchGeneration + 1
    cancelActiveSearch(self)
end

function SB:GetTopKeys()
    if not self:IsDataAvailable() then
        return {}
    end
    if self._topKeysCache then
        return self._topKeysCache
    end
    local keys = {}
    for top in pairs(Addon._SoundSlices) do
        if type(top) == "string" then
            tinsert(keys, top)
        end
    end
    sort(keys)
    self._topKeysCache = keys
    return keys
end

function SB:GetSubKeys(top)
    local branch = top and Addon._SoundSlices and Addon._SoundSlices[top]
    if type(branch) ~= "table" then
        return {}
    end
    if self._subKeysCacheTop == top and self._subKeysCache then
        return self._subKeysCache
    end
    local keys = {}
    for sub in pairs(branch) do
        if type(sub) == "string" then
            tinsert(keys, sub)
        end
    end
    sort(keys)
    self._subKeysCache = keys
    self._subKeysCacheTop = top
    return keys
end

function SB:EnsureDefaultCategory()
    if not self:IsDataAvailable() then
        return
    end
    if self.selectedTop and self.selectedSub then
        local slice = Addon._SoundSlices[self.selectedTop] and Addon._SoundSlices[self.selectedTop][self.selectedSub]
        if type(slice) == "table" and type(slice[1]) == "number" and type(slice[2]) == "number" then
            return
        end
    end
    local tops = self:GetTopKeys()
    if #tops == 0 then
        return
    end
    self.selectedTop = tops[1]
    local subs = self:GetSubKeys(self.selectedTop)
    self.selectedSub = subs[1]
end

function SB:SetCategory(top, sub)
    self.selectedTop = top
    if sub ~= nil then
        self.selectedSub = sub
    elseif top then
        local subs = self:GetSubKeys(top)
        self.selectedSub = subs[1]
    else
        self.selectedSub = nil
    end
    self:RebuildFiltered()
end

function SB:SetFilterText(text)
    self.filterText = (text or ""):lower():gsub("%s+", "")
    self:RebuildFiltered()
end

function SB:SetFavoritesOnly(on)
    self.favoritesOnly = on and true or false
    self:RebuildFiltered()
end

function SB:SetSearchScope(scope)
    if scope == "all" then
        self.searchScope = "all"
    else
        self.searchScope = "current"
    end
    self:RebuildFiltered()
end

function SB:IsSearchingAll()
    return self.searchScope == "all"
end

function SB:NeedsSearchTerm()
    return self:IsSearchingAll() and #(self.filterText or "") < ALL_SEARCH_MIN_LENGTH
end

function SB:RebuildFiltered()
    self:CancelSearch()
    wipe(self.filtered)
    if not self:IsDataAvailable() then
        return
    end

    local filter = self.filterText or ""
    local entries = Addon._SoundEntries
    local bookmarks = Addon.db.global.soundBookmarks
    local favoritesOnly = self.favoritesOnly
    local searchingAll = self:IsSearchingAll()

    if searchingAll and self:NeedsSearchTerm() then
        return
    end

    local function maybeAppend(index)
        local entry = entries[index]
        if type(entry) ~= "string" then
            return
        end
        if favoritesOnly and not (bookmarks and bookmarks[entry]) then
            return
        end
        if filter ~= "" then
            if searchingAll then
                if not strfind(entry, filter, 1, true) then
                    return
                end
            else
                local _, _, _, tail, fdidStr = parseEntry(entry)
                if not tail then
                    return
                end
                if not strfind(tail, filter, 1, true) and not strfind(fdidStr, filter, 1, true) then
                    return
                end
            end
        end
        tinsert(self.filtered, index)
    end

    if searchingAll then
        self._isRebuilding = true
        local generation = self._searchGeneration
        local total = #entries
        local nextIndex = 1

        self._searchTicker = C_Timer.NewTicker(ALL_SEARCH_TICK_SECONDS, function(ticker)
            if generation ~= self._searchGeneration then
                ticker:Cancel()
                return
            end

            local lastIndex = nextIndex + ALL_SEARCH_CHUNK_SIZE - 1
            if lastIndex > total then
                lastIndex = total
            end

            for index = nextIndex, lastIndex do
                maybeAppend(index)
            end

            nextIndex = lastIndex + 1
            if nextIndex <= total then
                return
            end

            ticker:Cancel()
            self._searchTicker = nil
            self._isRebuilding = false
            sort(self.filtered, compareEntryRefs)
            notifyFilteredReady(self)
        end)
        return
    end

    local top = self.selectedTop
    local sub = self.selectedSub
    if not top or not sub then
        return
    end

    local slice = Addon._SoundSlices[top] and Addon._SoundSlices[top][sub]
    if type(slice) ~= "table" then
        return
    end

    local first = slice[1]
    local last = slice[2]
    if type(first) ~= "number" or type(last) ~= "number" then
        return
    end

    for index = first, last do
        maybeAppend(index)
    end
end

function SB:GetFilteredCount()
    return #self.filtered
end

function SB:GetFilteredEntry(index)
    return self.filtered[index]
end

function SB:GetBookmarkKey(entryRef)
    return getEntryString(entryRef)
end

function SB:GetEntryInfo(entryRef)
    local entry, top, sub, tail, fdidStr = parseEntry(entryRef)
    if not entry then
        return nil
    end
    return top, sub, tail, fdidStr, entry
end

function SB:GetFileName(entryRef)
    local _, _, _, tail = parseEntry(entryRef)
    return tail or ""
end

function SB:GetCategoryLabel(entryRef)
    local _, top, sub = parseEntry(entryRef)
    if not top then
        return ""
    end
    return format("%s / %s", top, sub)
end

function SB:GetDisplayName(entryRef)
    local _, top, sub, tail = parseEntry(entryRef)
    if not tail then
        return ""
    end
    if self:IsSearchingAll() then
        return format("%s  [%s/%s]", tail, top, sub)
    end
    return tail
end

function SB:GetFullPath(entryRef)
    local _, top, sub, tail = parseEntry(entryRef)
    if not tail then
        return ""
    end
    return Addon.RebuildSoundFilePath(top, sub, tail)
end

function SB:GetFileDataIdString(entryRef)
    local _, _, _, _, fdidStr = parseEntry(entryRef)
    return fdidStr or ""
end

function SB:GetFileDataIdNumber(entryRef)
    local _, _, _, _, fdidStr = parseEntry(entryRef)
    if not fdidStr then
        return nil
    end
    return tonumber(fdidStr)
end

function SB:GetPlaySoundFileSnippet(entryRef, channel)
    channel = channel or "SFX"
    local id = self:GetFileDataIdNumber(entryRef)
    if not id then
        return ""
    end
    local L = Addon.L or {}
    local fmt = L["SOUND_SNIPPET_PLAY_SOUND_FILE"]
    return format(fmt, id, channel)
end

function SB:GetPlaySoundSnippet(soundKitId, channel)
    channel = channel or "SFX"
    if type(soundKitId) ~= "number" then
        return ""
    end
    local L = Addon.L or {}
    local fmt = L["SOUND_SNIPPET_PLAY_SOUND"]
    return format(fmt, soundKitId, channel)
end

function SB:IsBookmarked(entryRef)
    local key = self:GetBookmarkKey(entryRef)
    if not key then
        return false
    end
    return Addon.db.global.soundBookmarks[key] and true or false
end

function SB:ToggleBookmark(entryRef)
    local key = self:GetBookmarkKey(entryRef)
    if not key then
        return false
    end

    local g = Addon.db.global
    if g.soundBookmarks[key] then
        g.soundBookmarks[key] = nil
        return false
    end
    g.soundBookmarks[key] = true
    return true
end

function SB:ParseSoundKitKeyInput(raw)
    raw = strtrim(raw or "")
    if raw == "" then
        return nil, "empty"
    end
    local key = raw:match("^SOUNDKIT%.(.+)$") or raw
    local sk = rawget(_G, "SOUNDKIT")
    if type(sk) ~= "table" then
        return nil, "nosoundkit"
    end
    local value = sk[key]
    if type(value) ~= "number" then
        return nil, "unknown"
    end
    return value, nil
end
