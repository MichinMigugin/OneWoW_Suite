local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local pairs, ipairs = pairs, ipairs
local sort = sort

ns.UI = ns.UI or {}

local function GetClassColoredName(name, class)
    name = name or "?"
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return string.format("|cFF%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
    end
    return name
end

-- Sorted array of every tracked character, or nil when AltTracker is absent.
local function GetCharacters()
    local api = OneWoW_AltTracker_Character_API
    if not api or not api.GetAllCharacters then return nil end
    local currentKey = api.GetCurrentCharacterKey and api.GetCurrentCharacterKey()
    local out = {}
    for charKey, data in pairs(api.GetAllCharacters() or {}) do
        if type(data) == "table" then
            out[#out + 1] = {
                key = charKey,
                name = data.name or charKey:match("^(.+)-") or charKey,
                class = data.class,
                isCurrent = (charKey == currentKey),
            }
        end
    end
    sort(out, function(a, b) return (a.name or ""):lower() < (b.name or ""):lower() end)
    return out
end

local function OpenRolesAndAltsTab()
    OneWoW.UI:Show("settings")
    OneWoW.UI:SelectSubTab("settings", "rolesandalts")
end

--- Build the inline "Alt Scope" control block used by tooltip feature panes.
--- Renders a radio (all / selected), Add Alt + Add Role multiselect dropdowns,
--- a selected-entries summary, an exclusion note, and a link to the Roles & Alts
--- tab. All state is read/written through opts.getScope / opts.saveScope so each
--- feature keeps its own storage.
---@param parent Frame scroll child / detail frame
---@param opts table { yOffset, x, getScope, saveScope, omitHeader?: boolean, width?: number, contentWidth?: number }
---@return number newYOffset
---@return table scopeControls `{ SetEnabled = fun(enabled: boolean) }`
function ns.UI.BuildAltScopeSection(parent, opts)
    local L = ns.L
    local y = opts.yOffset or 0
    local x = opts.x or 12
    -- Card builders pass contentWidth; overlays pass width. Either must be set
    -- before measuring wrapped note height — card content rects are often 0.
    local layoutWidth = tonumber(opts.width) or tonumber(opts.contentWidth)

    -- getScope must return a live table already shaped { mode, chars, roles }.
    local scope = opts.getScope()
    scope.mode  = scope.mode  or "all"
    scope.chars = scope.chars or {}
    scope.roles = scope.roles or {}

    local function persist()
        opts.saveScope(scope)
    end

    local characters = GetCharacters()

    if not opts.omitHeader then
        local header = OneWoW_GUI:CreateFS(parent, 12)
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        header:SetText(L["TIPS_SCOPE_HEADER"])
        header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
        y = y - 22
    end

    local allCb = OneWoW_GUI:CreateCheckbox(parent, { label = L["TIPS_SCOPE_ALL"] })
    allCb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    y = y - 26

    local selCb = OneWoW_GUI:CreateCheckbox(parent, { label = L["TIPS_SCOPE_SELECTED"] })
    selCb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    y = y - 28

    local addAltBtn = OneWoW_GUI:CreateDropdown(parent, { width = 130, height = 22, text = L["TIPS_SCOPE_ADD_ALT"] })
    addAltBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 18, y)

    local addRoleBtn = OneWoW_GUI:CreateDropdown(parent, { width = 130, height = 22, text = L["TIPS_SCOPE_ADD_ROLE"] })
    addRoleBtn:SetPoint("LEFT", addAltBtn, "RIGHT", 8, 0)
    y = y - 28

    local textWidth = layoutWidth and math.max(1, layoutWidth - x - 18) or nil

    local summary = OneWoW_GUI:CreateFS(parent, 11)
    summary:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 18, y)
    if textWidth then
        summary:SetWidth(textWidth)
    else
        summary:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    end
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(false)
    y = y - 20

    local note = OneWoW_GUI:CreateFS(parent, 10)
    note:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 18, y)
    if textWidth then
        note:SetWidth(textWidth)
    else
        note:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    end
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetSpacing(2)
    note:SetText(L["TIPS_SCOPE_EXCLUDE_NOTE"])
    note:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    local noteH = note:GetStringHeight() or 14
    y = y - noteH - 8

    local function RefreshSummary()
        local parts = {}
        for _, role in ipairs(OneWoW.AltScope:GetRolesSorted()) do
            if scope.roles[role.id] then
                parts[#parts + 1] = "|cFF66CCFF[" .. role.name .. "]|r"
            end
        end
        if characters then
            for _, info in ipairs(characters) do
                if scope.chars[info.key] then
                    parts[#parts + 1] = GetClassColoredName(info.name, info.class)
                end
            end
        else
            for charKey in pairs(scope.chars) do
                parts[#parts + 1] = charKey
            end
        end
        if #parts == 0 then
            summary:SetText(L["TIPS_SCOPE_NONE_SELECTED"])
            summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        else
            summary:SetText(table.concat(parts, ", "))
            summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    local function SetChildrenEnabled(enabled)
        local textColor = enabled and "TEXT_PRIMARY" or "TEXT_MUTED"
        if enabled then addAltBtn:Enable() else addAltBtn:Disable() end
        if enabled then addRoleBtn:Enable() else addRoleBtn:Disable() end
        addAltBtn._text:SetTextColor(OneWoW_GUI:GetThemeColor(textColor))
        addRoleBtn._text:SetTextColor(OneWoW_GUI:GetThemeColor(textColor))
    end

    local function ApplyMode()
        local selected = scope.mode == "selected"
        allCb:SetChecked(not selected)
        selCb:SetChecked(selected)
        SetChildrenEnabled(selected)
        RefreshSummary()
    end

    allCb:SetScript("OnClick", function()
        scope.mode = "all"
        persist()
        ApplyMode()
    end)
    selCb:SetScript("OnClick", function()
        scope.mode = "selected"
        persist()
        ApplyMode()
    end)

    OneWoW_GUI:AttachFilterMenu(addAltBtn, {
        searchable = (characters ~= nil and #characters > 8),
        buildItems = function()
            local items = {}
            if not characters or #characters == 0 then
                items[#items + 1] = { type = "header", text = L["TIPS_SCOPE_NO_ALTS"] }
                return items
            end
            for _, info in ipairs(characters) do
                local charKey = info.key
                items[#items + 1] = {
                    type = "checkbox",
                    text = GetClassColoredName(info.name, info.class),
                    checked = scope.chars[charKey] and true or false,
                    onToggle = function(isOn)
                        scope.chars[charKey] = isOn and true or nil
                        persist()
                        RefreshSummary()
                    end,
                }
            end
            return items
        end,
    })

    OneWoW_GUI:AttachFilterMenu(addRoleBtn, {
        searchable = false,
        buildItems = function()
            local items = {}
            local roles = OneWoW.AltScope:GetRolesSorted()
            if #roles == 0 then
                items[#items + 1] = { type = "header", text = L["TIPS_SCOPE_NO_ROLES"] }
                return items
            end
            for _, role in ipairs(roles) do
                local roleId = role.id
                items[#items + 1] = {
                    type = "checkbox",
                    text = role.name,
                    checked = scope.roles[roleId] and true or false,
                    onToggle = function(isOn)
                        scope.roles[roleId] = isOn and true or nil
                        persist()
                        RefreshSummary()
                    end,
                }
            end
            return items
        end,
    })

    local linkBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L["TIPS_SCOPE_MANAGE_LINK"], height = 22 })
    linkBtn.text:ClearAllPoints()
    linkBtn.text:SetPoint("LEFT", linkBtn, "LEFT", 12, 0)
    local linkArrow = linkBtn:CreateTexture(nil, "ARTWORK")
    linkArrow:SetSize(10, 10)
    linkArrow:SetPoint("LEFT", linkBtn.text, "RIGHT", 6, 0)
    linkArrow:SetAtlas("uitools-icon-chevron-right")
    linkArrow:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    linkBtn:SetWidth(math.max(linkBtn._minWidth, linkBtn.text:GetStringWidth() + 40))
    linkBtn:HookScript("OnEnter", function()
        linkArrow:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    end)
    linkBtn:HookScript("OnLeave", function()
        linkArrow:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    end)
    -- Anchor below the note so wrap height never overlaps the manage button.
    linkBtn:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -8)
    linkBtn:SetScript("OnClick", OpenRolesAndAltsTab)
    y = y - 22 - 8

    -- Master gate for callers that disable the whole alt block (e.g. Gear
    -- Upgrades when "Show alt upgrades" is off).
    local function SetSectionEnabled(enabled)
        if enabled then
            allCb:Enable()
            selCb:Enable()
            allCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            selCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            ApplyMode()
        else
            allCb:Disable()
            selCb:Disable()
            allCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            selCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            SetChildrenEnabled(false)
            summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    ApplyMode()

    return y, { SetEnabled = SetSectionEnabled }
end
