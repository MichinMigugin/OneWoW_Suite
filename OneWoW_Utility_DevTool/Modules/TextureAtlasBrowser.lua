local _, Addon = ...

local TextureAtlasBrowser = {}
Addon.TextureAtlasBrowser = TextureAtlasBrowser

local sort, tinsert, wipe = sort, tinsert, wipe
local pairs, ipairs = pairs, ipairs
local type, tonumber, tostring, format = type, tonumber, tostring, format

local VIEW_TEXTURE = "texture"
local VIEW_ATLAS = "atlas"

function TextureAtlasBrowser:IsDataAvailable()
    return Addon._AtlasInfo ~= nil and type(Addon._AtlasInfo) == "table"
end

function TextureAtlasBrowser:EnsureIndices()
    if self._indicesBuilt then
        return
    end
    self._indicesBuilt = true

    self.textureEntries = {}
    self.atlasEntries = {}
    self.atlasPrimaryTexture = {}

    if not self:IsDataAvailable() then
        return
    end

    local AI = Addon._AtlasInfo
    for texKey, atlasTable in pairs(AI) do
        local displayName = texKey
        if type(texKey) == "string" and texKey:match("^Interface/") then
            local _path, fn = texKey:match("(.+)/([^/]+)$")
            if fn then
                displayName = fn:gsub("(%l)(%u)", "%1 %2")
            end
        end

        tinsert(self.textureEntries, {
            textureKey = texKey,
            displayName = displayName,
            sortKey = (displayName:lower() .. "\0" .. tostring(texKey)),
        })

        for atlasName, row in pairs(atlasTable) do
            if type(atlasName) == "string" and type(row) == "table" then
                if not self.atlasPrimaryTexture[atlasName] then
                    self.atlasPrimaryTexture[atlasName] = texKey
                end
                tinsert(self.atlasEntries, {
                    atlasName = atlasName,
                    textureKey = texKey,
                    sortKey = (atlasName:lower() .. "\0" .. tostring(texKey)),
                })
            end
        end
    end

    sort(self.textureEntries, function(a, b)
        return a.sortKey < b.sortKey
    end)
    sort(self.atlasEntries, function(a, b)
        return a.sortKey < b.sortKey
    end)
end

--- Value suitable for Texture:SetTexture — file ID when resolvable, else a path string.
function TextureAtlasBrowser:TextureKeyForAPI(texKey)
    if type(texKey) == "number" then
        return texKey
    end
    if type(texKey) == "string" and texKey:match("^%d+$") then
        return tonumber(texKey)
    end
    if type(texKey) ~= "string" then
        return texKey
    end
    local slash = texKey
    local backslash = texKey:find("/", 1, true) and texKey:gsub("/", "\\") or texKey
    if C_Texture.GetFileIDFromPath then
        local fid = C_Texture.GetFileIDFromPath(backslash)
        if type(fid) == "number" and fid > 0 then
            return fid
        end
        if backslash ~= slash then
            fid = C_Texture.GetFileIDFromPath(slash)
            if type(fid) == "number" and fid > 0 then
                return fid
            end
        end
    end
    return backslash
end

function TextureAtlasBrowser:RawRowToInfo(row, textureKey)
    if not row or type(row) ~= "table" then
        return nil
    end
    return {
        width = row[1],
        height = row[2],
        leftTexCoord = row[3],
        rightTexCoord = row[4],
        topTexCoord = row[5],
        bottomTexCoord = row[6],
        tilesHorizontally = row[7],
        tilesVertically = row[8],
        file = textureKey,
    }
end

function TextureAtlasBrowser:ResolveAtlasInfo(atlasName, textureKey)
    if not atlasName then
        return nil, nil
    end
    local api = C_Texture.GetAtlasInfo(atlasName)
    if api and api.width and api.width > 0 then
        local du = (api.rightTexCoord or 0) - (api.leftTexCoord or 0)
        local dv = (api.bottomTexCoord or 0) - (api.topTexCoord or 0)
        if du > 0 and dv > 0 then
            return api, "api"
        end
    end

    local key = textureKey or self.atlasPrimaryTexture[atlasName]
    if key and Addon._AtlasInfo[key] and Addon._AtlasInfo[key][atlasName] then
        local info = self:RawRowToInfo(Addon._AtlasInfo[key][atlasName], key)
        if info then
            info.missing = not api
            return info, "data"
        end
    end

    return nil, nil
end

function TextureAtlasBrowser:GetAtlasesForTexture(texKey)
    local t = Addon._AtlasInfo and Addon._AtlasInfo[texKey]
    if not t then
        return {}
    end
    local names = {}
    for k in pairs(t) do
        if type(k) == "string" then
            tinsert(names, k)
        end
    end
    sort(names)

    local out = {}
    for _, name in ipairs(names) do
        local info, src = self:ResolveAtlasInfo(name, texKey)
        tinsert(out, {
            atlasName = name,
            info = info,
            source = src,
        })
    end
    return out
end

function TextureAtlasBrowser:ComputeSheetPixelSize(textureKey)
    local atlases = self:GetAtlasesForTexture(textureKey)
    for _, row in ipairs(atlases) do
        local info = row.info
        if info and info.width and info.width > 0 then
            local du = (info.rightTexCoord or 0) - (info.leftTexCoord or 0)
            local dv = (info.bottomTexCoord or 0) - (info.topTexCoord or 0)
            if du > 0 and dv > 0 then
                return info.width / du, info.height / dv
            end
        end
    end
    return 256, 256
end

--- filter is already lowercased by SetFilterText.
local function textureMatchesFilter(texKey, displayName, filter)
    if filter == "" then
        return true
    end
    if displayName:lower():find(filter, 1, true) then
        return true
    end
    if tostring(texKey):lower():find(filter, 1, true) then
        return true
    end
    local t = Addon._AtlasInfo[texKey]
    if t then
        for k in pairs(t) do
            if type(k) == "string" and k:lower():find(filter, 1, true) then
                return true
            end
        end
    end
    return false
end

--- filter is already lowercased by SetFilterText.
local function atlasMatchesFilter(atlasName, texKey, filter)
    if filter == "" then
        return true
    end
    if atlasName:lower():find(filter, 1, true) then
        return true
    end
    if tostring(texKey):lower():find(filter, 1, true) then
        return true
    end
    return false
end

function TextureAtlasBrowser:TextureHasBookmarkedAtlas(texKey, bookmarks)
    local t = Addon._AtlasInfo[texKey]
    if not t or not bookmarks then
        return false
    end
    for k in pairs(t) do
        if type(k) == "string" and bookmarks[k] then
            return true
        end
    end
    return false
end

function TextureAtlasBrowser:ResetFilterState()
    self.viewMode = VIEW_TEXTURE
    self.filterText = ""
    self.favoritesOnly = false
    self.filtered = {}
end

function TextureAtlasBrowser:SetViewMode(mode)
    if mode ~= VIEW_TEXTURE and mode ~= VIEW_ATLAS then
        return
    end
    self.viewMode = mode
    self:RebuildFiltered()
end

function TextureAtlasBrowser:SetFilterText(text)
    self.filterText = (text or ""):lower():gsub("%s+", "")
    self:RebuildFiltered()
end

function TextureAtlasBrowser:SetFavoritesOnly(on)
    self.favoritesOnly = on and true or false
    self:RebuildFiltered()
end

function TextureAtlasBrowser:RebuildFiltered()
    if not self.filtered then
        self.filtered = {}
    else
        wipe(self.filtered)
    end

    if not self:IsDataAvailable() then
        return
    end
    self:EnsureIndices()

    local filter = self.filterText or ""
    local fav = self.favoritesOnly
    local bookmarks = Addon.db and Addon.db.textureBookmarks

    if self.viewMode == VIEW_TEXTURE then
        for _, e in ipairs(self.textureEntries) do
            if not fav or self:TextureHasBookmarkedAtlas(e.textureKey, bookmarks) then
                if textureMatchesFilter(e.textureKey, e.displayName, filter) then
                    tinsert(self.filtered, {
                        kind = "texture",
                        textureKey = e.textureKey,
                        displayName = e.displayName,
                    })
                end
            end
        end
    else
        for _, e in ipairs(self.atlasEntries) do
            if not fav or (bookmarks and bookmarks[e.atlasName]) then
                if atlasMatchesFilter(e.atlasName, e.textureKey, filter) then
                    tinsert(self.filtered, {
                        kind = "atlas",
                        atlasName = e.atlasName,
                        textureKey = e.textureKey,
                        displayName = e.atlasName,
                    })
                end
            end
        end
    end
end

function TextureAtlasBrowser:GetFilteredCount()
    return self.filtered and #self.filtered or 0
end

function TextureAtlasBrowser:GetFilteredEntry(index)
    return self.filtered and self.filtered[index]
end

function TextureAtlasBrowser:GetViewMode()
    return self.viewMode or VIEW_TEXTURE
end

function TextureAtlasBrowser:GetSetAtlasSnippet(atlasName)
    local L = Addon.L or {}
    local fmt = L["TEXTURE_SNIPPET_SETATLAS"] or 'tex:SetAtlas("%s")'
    return format(fmt, atlasName)
end

function TextureAtlasBrowser:GetCoordsCopyLine(info)
    if not info then
        return ""
    end
    return format(
        "%.6f, %.6f, %.6f, %.6f",
        info.leftTexCoord or 0,
        info.rightTexCoord or 1,
        info.topTexCoord or 0,
        info.bottomTexCoord or 1
    )
end

function TextureAtlasBrowser:FormatDetailLines(atlasName, info, textureKey, L)
    L = L or Addon.L or {}
    local lines = {}
    if not info then
        tinsert(lines, L["TEXTURE_MSG_NO_INFO"] or "No atlas info available.")
        return lines
    end

    tinsert(lines, (L["LABEL_NAME"] or "NAME:") .. " " .. tostring(atlasName))
    tinsert(lines, (L["LABEL_WIDTH"] or "Width:") .. " " .. tostring(info.width or 0))
    tinsert(lines, (L["LABEL_HEIGHT"] or "Height:") .. " " .. tostring(info.height or 0))
    tinsert(lines, (L["LABEL_FILE"] or "File:") .. " " .. tostring(info.file or textureKey or L["LABEL_UNKNOWN"] or "Unknown"))
    tinsert(lines, "")
    tinsert(lines, L["LABEL_TEX_COORDS"] or "Texture Coordinates:")
    tinsert(lines, format((L["LABEL_LEFT"] or "Left:") .. " %.6f", info.leftTexCoord or 0))
    tinsert(lines, format((L["LABEL_RIGHT"] or "Right:") .. " %.6f", info.rightTexCoord or 1))
    tinsert(lines, format((L["LABEL_TOP"] or "Top:") .. " %.6f", info.topTexCoord or 0))
    tinsert(lines, format((L["LABEL_BOTTOM"] or "Bottom:") .. " %.6f", info.bottomTexCoord or 1))

    if info.tilesHorizontally or info.tilesVertically then
        tinsert(lines, "")
        tinsert(lines, format(
            L["LABEL_TILES"] or "Tiles: %s x %s",
            tostring(info.tilesHorizontally or false),
            tostring(info.tilesVertically or false)
        ))
    end

    if info.missing then
        tinsert(lines, "")
        tinsert(lines, L["TEXTURE_MSG_FALLBACK_DATA"] or "(Using shipped atlas data; API entry missing or incomplete.)")
    end

    return lines
end

TextureAtlasBrowser.VIEW_TEXTURE = VIEW_TEXTURE
TextureAtlasBrowser.VIEW_ATLAS = VIEW_ATLAS
