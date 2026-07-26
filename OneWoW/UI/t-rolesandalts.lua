local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local UI = ns.UI

local pairs, ipairs = pairs, ipairs
local sort = sort

local function GetClassColoredName(name, class)
    name = name or "?"
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return string.format("|cFF%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
    end
    return name
end

-- Small modal: a single text field + Save/Cancel. Used for New Role / Rename.
local function ShowNamePrompt(titleText, labelText, initial, onAccept)
    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_RoleNamePrompt",
        title = titleText,
        width = 380,
        height = 150,
        showBrand = false,
    })
    local dialog = result.frame
    local content = result.contentFrame

    local label = OneWoW_GUI:CreateFS(content, 12)
    label:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -14)
    label:SetText(labelText)
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local box = OneWoW_GUI:CreateEditBox(content, { width = 340, height = 26, maxLetters = 40 })
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    box:SetText(initial or "")

    local saveBtn = OneWoW_GUI:CreateFitTextButton(content, { text = SAVE, height = 28 })
    saveBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 12)

    local cancelBtn = OneWoW_GUI:CreateFitTextButton(content, { text = CANCEL, height = 28 })
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

    local function accept()
        local text = (box:GetText() or ""):trim()
        if text ~= "" then
            onAccept(text)
            dialog:Hide()
        end
    end
    saveBtn:SetScript("OnClick", accept)
    box:SetScript("OnEnterPressed", accept)
    box:SetScript("OnEscapePressed", function() dialog:Hide() end)

    OneWoW_GUI:ApplyFontToFrame(dialog)
    dialog:Show()
    box:SetFocus()
end

-- Sorted (name) list of every known character, or empty when AltTracker is
-- absent. Shape mirrors OneWoW_AltTracker_API.CollectAllCharacters.
local function GetKnownCharacters()
    if OneWoW_AltTracker_API and OneWoW_AltTracker_API.CollectAllCharacters then
        return OneWoW_AltTracker_API.CollectAllCharacters()
    end
    return nil
end

local function RoleNamesForChar(charKey)
    local names = {}
    for _, role in ipairs(ns.AltScope:GetRolesSorted()) do
        if role.members and role.members[charKey] then
            names[#names + 1] = role.name
        end
    end
    return names
end

function UI:CreateRolesAndAltsTab(parent)
    local L = ns.L or {}
    local scrollFrame, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_RolesAltsScroll" })
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    -- Purge selection persists only within one Render pass; removal reloads the UI.
    local Render

    local function BuildRolesSection(y)
        local rolesHeader = OneWoW_GUI:CreateSectionHeader(content, { title = L["ROLES_SECTION"], yOffset = y })
        y = rolesHeader.bottomY - 8

        local desc = OneWoW_GUI:CreateFS(content, 12)
        desc:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
        desc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetSpacing(3)
        desc:SetText(L["ROLES_SECTION_DESC"])
        desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        y = y - desc:GetStringHeight() - 10

        local newBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["ROLES_NEW_BTN"], height = 28 })
        newBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
        newBtn:SetScript("OnClick", function()
            ShowNamePrompt(L["ROLES_NEW_TITLE"], L["ROLES_NAME_LABEL"], "", function(name)
                ns.AltScope:CreateRole(name)
                Render()
            end)
        end)
        y = y - 40

        local roles = ns.AltScope:GetRolesSorted()
        if #roles == 0 then
            local none = OneWoW_GUI:CreateFS(content, 12)
            none:SetPoint("TOPLEFT", content, "TOPLEFT", 25, y)
            none:SetText(L["ROLES_NONE"])
            none:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            return y - 26
        end

        local characters = GetKnownCharacters()

        for _, role in ipairs(roles) do
            local roleId = role.id
            local row = OneWoW_GUI:CreateFrame(content, { height = 34, bgColor = "BG_TERTIARY", borderColor = "BORDER_SUBTLE" })
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)

            local nameFS = OneWoW_GUI:CreateFS(row, 13)
            nameFS:SetPoint("LEFT", row, "LEFT", 12, 0)
            nameFS:SetText(role.name)
            nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))

            local countFS = OneWoW_GUI:CreateFS(row, 11)
            countFS:SetPoint("LEFT", nameFS, "RIGHT", 12, 0)
            local function refreshCount()
                countFS:SetText(string.format(L["ROLES_MEMBER_COUNT"], ns.AltScope:GetRoleMemberCount(roleId)))
            end
            refreshCount()
            countFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local deleteBtn = OneWoW_GUI:CreateFitTextButton(row, { text = DELETE, height = 22 })
            deleteBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            deleteBtn:SetScript("OnClick", function()
                local confirm = OneWoW_GUI:CreateConfirmDialog({
                    title = DELETE,
                    message = string.format(L["ROLES_DELETE_CONFIRM"], role.name),
                    buttons = {
                        { text = DELETE, onClick = function(f) ns.AltScope:DeleteRole(roleId); f:Hide(); Render() end },
                        { text = CANCEL, onClick = function(f) f:Hide() end },
                    },
                })
                OneWoW_GUI:ApplyFontToFrame(confirm.frame)
                confirm.frame:Show()
            end)

            local renameBtn = OneWoW_GUI:CreateFitTextButton(row, { text = L["RENAME"], height = 22 })
            renameBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -6, 0)
            renameBtn:SetScript("OnClick", function()
                ShowNamePrompt(L["ROLES_RENAME_TITLE"], L["ROLES_NAME_LABEL"], role.name, function(name)
                    ns.AltScope:RenameRole(roleId, name)
                    Render()
                end)
            end)

            local assignBtn = OneWoW_GUI:CreateDropdown(row, { width = 130, height = 22, text = L["ROLES_ASSIGN_BTN"] })
            assignBtn:SetPoint("RIGHT", renameBtn, "LEFT", -6, 0)
            OneWoW_GUI:AttachFilterMenu(assignBtn, {
                searchable = (characters ~= nil and #characters > 8),
                buildItems = function()
                    local items = {}
                    if not characters or #characters == 0 then
                        items[#items + 1] = { type = "header", text = L["ROLES_ASSIGN_NONE"] }
                        return items
                    end
                    for _, info in ipairs(characters) do
                        local charKey = info.key
                        items[#items + 1] = {
                            type = "checkbox",
                            text = GetClassColoredName(info.name, info.class),
                            filterKey = info.name,
                            checked = ns.AltScope:IsCharInRole(roleId, charKey),
                            onToggle = function(isOn)
                                ns.AltScope:SetCharInRole(roleId, charKey, isOn)
                                refreshCount()
                            end,
                        }
                    end
                    return items
                end,
            })

            y = y - 38
        end

        return y
    end

    local function BuildCharactersSection(y)
        local charsHeader = OneWoW_GUI:CreateSectionHeader(content, { title = L["CHARS_SECTION"], yOffset = y })
        y = charsHeader.bottomY - 8

        local desc = OneWoW_GUI:CreateFS(content, 12)
        desc:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
        desc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetSpacing(3)
        desc:SetText(L["CHARS_SECTION_DESC"])
        desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        y = y - desc:GetStringHeight() - 10

        local characters = GetKnownCharacters()
        if not characters then
            local note = OneWoW_GUI:CreateFS(content, 12)
            note:SetPoint("TOPLEFT", content, "TOPLEFT", 25, y)
            note:SetText(L["CHARS_NEED_ALTTRACKER"])
            note:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            return y - 26
        end

        if #characters == 0 then
            local none = OneWoW_GUI:CreateFS(content, 12)
            none:SetPoint("TOPLEFT", content, "TOPLEFT", 25, y)
            none:SetText(L["CHARS_NONE"])
            none:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            return y - 26
        end

        local selected = {}

        local count = OneWoW_GUI:CreateFS(content, 11)
        count:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
        count:SetText(string.format(L["CHARS_COUNT"], #characters))
        count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        y = y - 22

        for i, info in ipairs(characters) do
            local charKey = info.key
            local row = OneWoW_GUI:CreateFrame(content, {
                height = 30,
                bgColor = (i % 2 == 0) and "BG_TERTIARY" or "BG_PRIMARY",
                borderColor = "BORDER_SUBTLE",
            })
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)

            local cb = OneWoW_GUI:CreateCheckbox(row, { label = "" })
            cb:SetSize(20, 20)
            cb:SetPoint("LEFT", row, "LEFT", 6, 0)
            cb:SetScript("OnClick", function(box) selected[charKey] = box:GetChecked() or nil end)

            local nameFS = OneWoW_GUI:CreateFS(row, 12)
            nameFS:SetPoint("LEFT", cb, "RIGHT", 6, 0)
            local nameStr = info.name or charKey
            if info.realm and info.realm ~= "" then nameStr = nameStr .. "-" .. info.realm end
            nameFS:SetText(nameStr)
            local classColor = info.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.class]
            if classColor then
                nameFS:SetTextColor(classColor.r, classColor.g, classColor.b)
            else
                nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            local roleNames = RoleNamesForChar(charKey)
            local roleStr = (#roleNames > 0) and (L["CHARS_ROLES_LABEL"] .. " " .. table.concat(roleNames, ", ")) or (L["CHARS_ROLES_LABEL"] .. " " .. L["CHARS_NO_ROLES"])
            local roleFS = OneWoW_GUI:CreateFS(row, 10)
            roleFS:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            roleFS:SetText(roleStr)
            roleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            y = y - 32
        end

        y = y - 6
        local removeBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["CHARS_REMOVE_BTN"], height = 30, danger = true })
        removeBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
        removeBtn:SetScript("OnClick", function()
            local keys = {}
            for k in pairs(selected) do keys[#keys + 1] = k end
            if #keys == 0 then
                print(L["ADDON_CHAT_PREFIX"] and (L["ADDON_CHAT_PREFIX"] .. " " .. L["CHARS_REMOVE_NONE_SELECTED"]) or L["CHARS_REMOVE_NONE_SELECTED"])
                return
            end
            sort(keys)
            local shown = {}
            for idx = 1, math.min(#keys, 5) do shown[#shown + 1] = keys[idx] end
            local names = table.concat(shown, ", ")
            if #keys > 5 then names = names .. " (+" .. (#keys - 5) .. ")" end

            local confirm = OneWoW_GUI:CreateConfirmDialog({
                title = L["CHARS_REMOVE_CONFIRM_TITLE"],
                message = string.format(L["CHARS_REMOVE_CONFIRM"], #keys, names),
                width = 440,
                buttons = {
                    { text = DELETE, onClick = function(f)
                        for _, k in ipairs(keys) do
                            OneWoW_AltTracker_API.PurgeCharacter(k)
                        end
                        f:Hide()
                        C_UI.Reload()
                    end },
                    { text = CANCEL, onClick = function(f) f:Hide() end },
                },
            })
            OneWoW_GUI:ApplyFontToFrame(confirm.frame)
            confirm.frame:Show()
        end)
        y = y - 40

        return y
    end

    Render = function()
        OneWoW_GUI:ClearFrame(content)
        local y = -10

        local title = OneWoW_GUI:CreateFS(content, 16)
        title:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        title:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, y)
        title:SetJustifyH("LEFT")
        title:SetText(L["ROLES_ALTS_TITLE"])
        title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        y = y - title:GetStringHeight() - 8

        OneWoW_GUI:CreateDivider(content, { yOffset = y })
        y = y - 12

        local desc = OneWoW_GUI:CreateFS(content, 12)
        desc:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        desc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, y)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetSpacing(3)
        desc:SetText(L["ROLES_ALTS_DESC"])
        desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        y = y - desc:GetStringHeight() - 16

        y = BuildRolesSection(y)
        y = y - 16
        y = BuildCharactersSection(y)

        content:SetHeight(math.abs(y) + 20)
        OneWoW_GUI:ApplyFontToFrame(content)
    end

    Render()
    parent.Activate = function() Render() end
end
