local OneWoW_GUI = OneWoW_GUI

-- ============================================================================
-- EntityIdField
-- ============================================================================
-- Numeric ID input plus a resolved-name line. Optional load units populate
-- resolvers via RegisterEntityResolver so OneWoW_GUI never depends on Catalog
-- (or any other unit). Unregistered kinds stay a plain edit box at the call
-- site (HasEntityResolver).
--
-- Resolve(id) -> name, icon, quality, link
-- RequestAsync(id, cb) -> cb(id, { name, icon, quality, link }|nil)
-- Async paints are token-guarded so a reused or hidden field never takes a
-- late write.
-- ============================================================================

local CreateFrame = CreateFrame
local tonumber = tonumber
local format = format

local NAME_ICON_SIZE = 16
local NAME_GAP = 2
local BOX_HEIGHT = 22

local resolvers = {}

--- Register a name resolver for an entity kind (`item`, `quest`, `npc`, ...).
---@param kind string
---@param spec table { Resolve, RequestAsync }
function OneWoW_GUI:RegisterEntityResolver(kind, spec)
    resolvers[kind] = spec
end

---@param kind string|nil
---@return boolean
function OneWoW_GUI:HasEntityResolver(kind)
    return kind ~= nil and resolvers[kind] ~= nil
end

local function ShowEntityTooltip(owner, kind, id, info)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if info.link and info.link ~= "" then
        GameTooltip:SetHyperlink(info.link)
    elseif kind == "item" or kind == "toy" then
        GameTooltip:SetItemByID(id)
    elseif kind == "spell" then
        GameTooltip:SetSpellByID(id)
    elseif kind == "currency" then
        GameTooltip:SetCurrencyByID(id)
    elseif kind == "achievement" then
        local link = GetAchievementLink(id)
        if link then
            GameTooltip:SetHyperlink(link)
        else
            GameTooltip:SetText(info.name or "", 1, 1, 1)
        end
    elseif kind == "quest" then
        GameTooltip:SetHyperlink("quest:" .. id)
    elseif kind == "npc" then
        GameTooltip:SetHyperlink(format("unit:Creature-0-0-0-0-%d-0000000000", id))
    else
        GameTooltip:SetText(info.name or "", 1, 1, 1)
    end
    GameTooltip:Show()
end

--- Numeric ID box plus resolved-name line. Caller checks HasEntityResolver.
---@param parent Frame
---@param options table { width, height, placeholderText, maxLetters, kind, onTextChanged }
---@return Frame field
function OneWoW_GUI:CreateEntityIdField(parent, options)
    options = options or {}
    local width = options.width or 160
    local boxHeight = options.height or BOX_HEIGHT
    local kind = options.kind
    local resolver = resolvers[kind]

    local field = CreateFrame("Frame", nil, parent)
    field:SetSize(width, boxHeight + NAME_GAP + NAME_ICON_SIZE)
    field._kind = kind
    field._id = nil
    field._info = nil
    field._resolveToken = nil

    local box = OneWoW_GUI:CreateEditBox(field, {
        width = width,
        height = boxHeight,
        placeholderText = options.placeholderText,
        maxLetters = options.maxLetters or 12,
        showClear = width >= 80,
        onTextChanged = function(text)
            field:Refresh()
            if options.onTextChanged then options.onTextChanged(text) end
        end,
    })
    box:SetPoint("TOPLEFT", field, "TOPLEFT", 0, 0)
    field._box = box

    local icon = field:CreateTexture(nil, "ARTWORK")
    icon:SetSize(NAME_ICON_SIZE, NAME_ICON_SIZE)
    icon:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -NAME_GAP)
    icon:Hide()
    field._icon = icon

    local nameFS = OneWoW_GUI:CreateFS(field, 10)
    nameFS:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    nameFS:SetPoint("RIGHT", field, "RIGHT", 0, 0)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetText("")
    field._nameFS = nameFS

    local hover = CreateFrame("Frame", nil, field)
    hover:SetPoint("TOPLEFT", icon, "TOPLEFT")
    hover:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT")
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(myself)
        if field._info and field._id then
            ShowEntityTooltip(myself, field._kind, field._id, field._info)
        end
    end)
    hover:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    field._hover = hover

    local function ApplyResolved(info)
        field._info = info
        nameFS:SetText(info.name)
        if info.quality then
            nameFS:SetTextColor(OneWoW_GUI:GetItemQualityColor(info.quality))
        else
            nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        end
        if info.icon then
            icon:SetTexture(info.icon)
            icon:Show()
        else
            icon:Hide()
        end
    end

    local function ApplyLoading()
        field._info = nil
        icon:Hide()
        nameFS:SetText(RETRIEVING_DATA)
        nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    end

    local function ApplyInvalid()
        field._info = nil
        icon:Hide()
        nameFS:SetText("")
        nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end

    local function ApplyEmpty()
        field._id = nil
        field._info = nil
        icon:Hide()
        nameFS:SetText("")
    end

    function field:Refresh()
        local raw = box:GetSearchText()
        local id = tonumber(raw)
        if not id or id <= 0 then
            local token = {}
            self._resolveToken = token
            ApplyEmpty()
            return
        end
        self._id = id

        local token = {}
        self._resolveToken = token

        local name, iconFile, quality, link = resolver.Resolve(id)
        if name then
            ApplyResolved({ name = name, icon = iconFile, quality = quality, link = link })
            return
        end

        ApplyLoading()
        resolver.RequestAsync(id, function(loadedID, info)
            if self._resolveToken ~= token then return end
            if not self:IsShown() then return end
            if loadedID ~= id then return end
            if info and info.name then
                ApplyResolved(info)
            else
                ApplyInvalid()
            end
        end)
    end

    function field:SetText(text)
        box:SetText(text or "")
        if text and text ~= "" and text ~= box.placeholderText then
            box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        self:Refresh()
    end

    function field:GetText()
        return box:GetSearchText()
    end

    function field:GetSearchText()
        return box:GetSearchText()
    end

    return field
end
