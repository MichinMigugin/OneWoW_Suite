local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local format = format
local tinsert = tinsert
local sort = sort
local ipairs = ipairs
local type = type
local pcall = pcall

local FB = {}
Addon.FontBrowser = FB

FB.masterList = {}
FB.filteredList = {}
FB.filterText = ""
FB.favoritesOnly = false
FB.catalogBuilt = false

local WIDGET_SIZE_PT = {
    [0] = 10,
    [1] = 14,
    [2] = 18,
    [3] = 24,
    [4] = 12,
}

FB.WIDGET_SIZE_PT = WIDGET_SIZE_PT

local function isFontObject(obj)
    if not obj then return false end
    local ok, result = pcall(function()
        if type(obj) == "table" and obj.GetFont then
            local f = obj:GetFont()
            return f ~= nil
        end
        return false
    end)
    return ok and result
end

function FB:BuildCatalog()
    if self.catalogBuilt then return end
    self.catalogBuilt = true

    local seen = {}
    local list = {}

    local staticNames = Addon.FontObjectNames or {}
    for _, name in ipairs(staticNames) do
        if not seen[name] then
            seen[name] = true
            tinsert(list, name)
        end
    end

    local ok, runtimeFonts = pcall(GetFonts)
    if ok and type(runtimeFonts) == "table" then
        for _, fontObj in ipairs(runtimeFonts) do
            if type(fontObj) == "table" then
                local nameOk, fontName = pcall(function() return fontObj:GetName() end)
                if nameOk and fontName and not seen[fontName] then
                    seen[fontName] = true
                    tinsert(list, fontName)
                end
            end
        end
    end

    local valid = {}
    for _, name in ipairs(list) do
        local obj = _G[name]
        if isFontObject(obj) then
            tinsert(valid, name)
        end
    end

    sort(valid)
    self.masterList = valid
    self:RebuildFiltered()
end

function FB:RebuildFiltered()
    local result = {}
    local filter = self.filterText:upper()
    local bookmarks = Addon.db.global.fontBookmarks

    for _, name in ipairs(self.masterList) do
        local pass = true

        if self.favoritesOnly then
            if not (bookmarks and bookmarks[name]) then
                pass = false
            end
        end

        if pass and filter ~= "" then
            if not name:upper():find(filter, 1, true) then
                pass = false
            end
        end

        if pass then
            tinsert(result, name)
        end
    end

    self.filteredList = result
end

function FB:SetFilterText(text)
    self.filterText = text or ""
    self:RebuildFiltered()
end

function FB:SetFavoritesOnly(on)
    self.favoritesOnly = on
    self:RebuildFiltered()
end

function FB:GetFilteredCount()
    return #self.filteredList
end

function FB:GetFilteredEntry(idx)
    return self.filteredList[idx]
end

function FB:IsBookmarked(name)
    return Addon.db.global.fontBookmarks[name] or false
end

function FB:ToggleBookmark(name)
    if not name then return end
    local g = Addon.db.global
    if g.fontBookmarks[name] then
        g.fontBookmarks[name] = nil
        return false
    else
        g.fontBookmarks[name] = true
        return true
    end
end

function FB:GetFontInfo(name)
    local obj = _G[name]
    if not obj then return nil end

    local info = { name = name }

    local ok, path, height, flags = pcall(obj.GetFont, obj)
    if ok then
        info.path = path
        info.height = height
        info.flags = flags or ""
    end

    ok = pcall(function()
        local r, g, b, a = obj:GetTextColor()
        info.textColor = { r = r, g = g, b = b, a = a }
    end)

    pcall(function()
        local r, g, b, a = obj:GetShadowColor()
        info.shadowColor = { r = r, g = g, b = b, a = a }
    end)

    pcall(function()
        local x, y = obj:GetShadowOffset()
        info.shadowOffset = { x = x, y = y }
    end)

    pcall(function() info.justifyH = obj:GetJustifyH() end)
    pcall(function() info.justifyV = obj:GetJustifyV() end)
    pcall(function() info.spacing = obj:GetSpacing() end)
    pcall(function() info.indentedWordWrap = obj:GetIndentedWordWrap() end)
    pcall(function() info.alpha = obj:GetAlpha() end)

    return info
end

function FB:GetInheritanceChain(name)
    local chain = {}
    local obj = _G[name]
    if not obj then return chain end

    local visited = { [name] = true }
    local current = obj
    local limit = 20

    while limit > 0 do
        limit = limit - 1
        local ok, parent = pcall(function() return current:GetFontObject() end)
        if not ok or not parent then break end
        local parentName
        pcall(function() parentName = parent:GetName() end)
        if not parentName then break end
        if visited[parentName] then break end
        visited[parentName] = true
        tinsert(chain, parentName)
        current = parent
    end

    return chain
end

function FB:FormatRGBA(c)
    if not c then return "?" end
    return format("%.2f, %.2f, %.2f, %.2f", c.r or 0, c.g or 0, c.b or 0, c.a or 1)
end

function FB:GenerateCopyName(name)
    return name or ""
end

function FB:GenerateSetFontObject(name)
    if not name then return "" end
    return format("fs:SetFontObject(%s)", name)
end

function FB:GenerateSetFont(name, overrides)
    local info = self:GetFontInfo(name)
    if not info then return "" end

    local path = (overrides and overrides.path) or info.path or "Fonts\\FRIZQT__.TTF"
    local height = (overrides and overrides.height) or info.height or 12
    local flags = (overrides and overrides.flags) or info.flags or ""

    if flags == "" then
        return format('fs:SetFont("%s", %s)', path, tostring(height))
    end
    return format('fs:SetFont("%s", %s, "%s")', path, tostring(height), flags)
end

function FB:GenerateSnippet(name, overrides)
    if not name then return "" end
    local info = self:GetFontInfo(name)
    if not info then return "" end

    local lines = {}
    tinsert(lines, format('local fs = parent:CreateFontString(nil, "OVERLAY")'))
    tinsert(lines, format("fs:SetFontObject(%s)", name))

    if overrides then
        if overrides.height or overrides.flags then
            local path = overrides.path or info.path or "Fonts\\FRIZQT__.TTF"
            local h = overrides.height or info.height or 12
            local f = overrides.flags or info.flags or ""
            if f == "" then
                tinsert(lines, format('fs:SetFont("%s", %s)', path, tostring(h)))
            else
                tinsert(lines, format('fs:SetFont("%s", %s, "%s")', path, tostring(h), f))
            end
        end

        if overrides.textColor then
            local c = overrides.textColor
            tinsert(lines, format("fs:SetTextColor(%.2f, %.2f, %.2f, %.2f)", c.r, c.g, c.b, c.a))
        end
        if overrides.shadowColor then
            local c = overrides.shadowColor
            tinsert(lines, format("fs:SetShadowColor(%.2f, %.2f, %.2f, %.2f)", c.r, c.g, c.b, c.a))
        end
        if overrides.shadowOffset then
            tinsert(lines, format("fs:SetShadowOffset(%s, %s)", tostring(overrides.shadowOffset.x), tostring(overrides.shadowOffset.y)))
        end
        if overrides.justifyH then
            tinsert(lines, format('fs:SetJustifyH("%s")', overrides.justifyH))
        end
        if overrides.justifyV then
            tinsert(lines, format('fs:SetJustifyV("%s")', overrides.justifyV))
        end
        if overrides.spacing then
            tinsert(lines, format("fs:SetSpacing(%s)", tostring(overrides.spacing)))
        end
        if overrides.alpha then
            tinsert(lines, format("fs:SetAlpha(%.2f)", overrides.alpha))
        end
    end

    return table.concat(lines, "\n")
end

function FB:GenerateCreateFont(name, overrides)
    if not name then return "" end
    local info = self:GetFontInfo(name)
    if not info then return "" end

    local lines = {}
    tinsert(lines, format('local myFont = CreateFont("MyAddon_%s")', name))
    tinsert(lines, format("myFont:CopyFontObject(%s)", name))

    if overrides then
        if overrides.height or overrides.flags then
            local path = overrides.path or info.path or "Fonts\\FRIZQT__.TTF"
            local h = overrides.height or info.height or 12
            local f = overrides.flags or info.flags or ""
            if f == "" then
                tinsert(lines, format('myFont:SetFont("%s", %s)', path, tostring(h)))
            else
                tinsert(lines, format('myFont:SetFont("%s", %s, "%s")', path, tostring(h), f))
            end
        end
        if overrides.textColor then
            local c = overrides.textColor
            tinsert(lines, format("myFont:SetTextColor(%.2f, %.2f, %.2f, %.2f)", c.r, c.g, c.b, c.a))
        end
        if overrides.shadowColor then
            local c = overrides.shadowColor
            tinsert(lines, format("myFont:SetShadowColor(%.2f, %.2f, %.2f, %.2f)", c.r, c.g, c.b, c.a))
        end
        if overrides.shadowOffset then
            tinsert(lines, format("myFont:SetShadowOffset(%s, %s)", tostring(overrides.shadowOffset.x), tostring(overrides.shadowOffset.y)))
        end
    end

    return table.concat(lines, "\n")
end
