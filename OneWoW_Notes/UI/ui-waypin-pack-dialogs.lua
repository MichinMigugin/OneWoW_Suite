local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local C = OneWoW_GUI.Constants

ns.UI = ns.UI or {}

local strtrim = strtrim

function ns.UI.GetWayPinExpansionOptions()
    local items = { { text = NONE, value = "" } }
    for id = 0, LE_EXPANSION_LEVEL_CURRENT do
        local name = OneWoW:GetExpansionName(id)
        if name then
            tinsert(items, { text = name, value = id })
        end
    end
    return items
end

-- Filter-menu default height (314) clips later expansions. 26px row + 2px gap.
function ns.UI.GetWayPinExpansionMenuHeight()
    return #ns.UI.GetWayPinExpansionOptions() * 28 + 8
end

local exportDialog
local exportBox
local importDialog
local importBox
local sendDialog
local sendWidgets = {}
local sendSelected = "__new"
local sendPinID

local function PrintFail(key)
    print("|cFFFF6666" .. L[key] .. "|r")
end

local function EnsureExportDialog()
    if exportDialog then
        return exportDialog
    end
    exportDialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_NotesWayPinPackExport",
        title = L["WAYPINS_EXPORT_TITLE"],
        width = 560,
        height = 360,
        buttons = {
            { text = CLOSE, onClick = function(f) f:Hide() end },
        },
    })
    local content = exportDialog.contentFrame
    local hint = OneWoW_GUI:CreateFS(content, 10)
    hint:SetPoint("TOPLEFT", 10, -6)
    hint:SetPoint("RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(L["WAYPINS_EXPORT_HINT"])
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local container = OneWoW_GUI:CreateFrame(content, {
        width = 1,
        height = 1,
        backdrop = C.BACKDROP_SOFT,
    })
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", 10, -36)
    container:SetPoint("BOTTOMRIGHT", -10, 4)
    local _, editBox = OneWoW_GUI:CreateScrollEditBox(container, { name = "OneWoW_NotesPackExportText", maxLetters = 0 })
    exportBox = editBox
    return exportDialog
end

function ns.UI.OpenWayPinPackExport(packId)
    local packed = ns.WayPinPacks:Export(packId)
    if not packed then
        return
    end
    EnsureExportDialog()
    exportBox:SetText(packed)
    exportBox:HighlightText()
    exportDialog.frame:Show()
    exportDialog.frame:Raise()
end

local function DoImport(text, replace)
    local packId, err, existing = ns.WayPinPacks:Import(text, replace)
    if packId then
        ns.UI.SelectWayPinPack(packId)
        return true
    end
    if err == "exists" and existing and not replace then
        local result = OneWoW_GUI:CreateConfirmDialog({
            title = L["WAYPINS_IMPORT_REPLACE_TITLE"],
            message = string.format(L["WAYPINS_IMPORT_REPLACE_CONFIRM"], existing.name or existing.id),
            buttons = {
                {
                    text = L["WAYPINS_IMPORT"],
                    onClick = function(dlg)
                        DoImport(text, true)
                        dlg:Hide()
                    end,
                },
                { text = CANCEL, onClick = function(dlg) dlg:Hide() end },
            },
        })
        result.frame:Show()
        return true
    end
    PrintFail("WAYPINS_IMPORT_FAILED")
    return false
end

local function EnsureImportDialog()
    if importDialog then
        return importDialog
    end
    importDialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_NotesWayPinPackImport",
        title = L["WAYPINS_IMPORT_TITLE"],
        width = 560,
        height = 360,
        buttons = {
            {
                text = L["WAYPINS_IMPORT"],
                onClick = function(f)
                    local text = strtrim(importBox:GetText() or "")
                    if text == "" then
                        return
                    end
                    if DoImport(text, false) then
                        f:Hide()
                    end
                end,
            },
            { text = CANCEL, onClick = function(f) f:Hide() end },
        },
    })
    local content = importDialog.contentFrame
    local hint = OneWoW_GUI:CreateFS(content, 10)
    hint:SetPoint("TOPLEFT", 10, -6)
    hint:SetPoint("RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(L["WAYPINS_IMPORT_HINT"])
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local container = OneWoW_GUI:CreateFrame(content, {
        width = 1,
        height = 1,
        backdrop = C.BACKDROP_SOFT,
    })
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", 10, -36)
    container:SetPoint("BOTTOMRIGHT", -10, 4)
    local _, editBox = OneWoW_GUI:CreateScrollEditBox(container, { name = "OneWoW_NotesPackImportText", maxLetters = 0 })
    importBox = editBox
    return importDialog
end

function ns.UI.OpenWayPinPackImport()
    EnsureImportDialog()
    importBox:SetText("")
    importDialog.frame:Show()
    importDialog.frame:Raise()
end

local function SyncSendNewFields()
    local show = sendSelected == "__new"
    sendWidgets.nameLabel:SetShown(show)
    sendWidgets.nameBox:SetShown(show)
    sendWidgets.expLabel:SetShown(show)
    sendWidgets.expDD:SetShown(show)
end

local function EnsureSendDialog()
    if sendDialog then
        return sendDialog
    end
    sendDialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_NotesWayPinSendToPack",
        title = L["WAYPINS_SEND_TO_PACK"],
        width = 420,
        height = 280,
        buttons = {
            {
                text = L["WAYPINS_SEND_TO_PACK"],
                onClick = function(f)
                    local packId
                    if sendSelected == "__new" then
                        local name = strtrim(sendWidgets.nameBox:GetSearchText() or "")
                        if name == "" then
                            PrintFail("WAYPINS_PACK_NAME_REQUIRED")
                            return
                        end
                        packId = ns.WayPinPacks:CreatePack({
                            name = name,
                            expansion = sendWidgets.expDD:GetValue(),
                            source = "user",
                        })
                    else
                        packId = sendSelected
                    end
                    if not packId then
                        return
                    end
                    ns.WayPinPacks:MovePinToPack(sendPinID, packId)
                    ns.UI.SelectWayPinPack(packId)
                    f:Hide()
                end,
            },
            { text = CANCEL, onClick = function(f) f:Hide() end },
        },
    })
    local content = sendDialog.contentFrame
    local hint = OneWoW_GUI:CreateFS(content, 11)
    hint:SetPoint("TOPLEFT", 14, -10)
    hint:SetPoint("RIGHT", -14, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    sendWidgets.hint = hint

    local dd = ns.UI.CreateThemedDropdown(content, L["WAYPINS_PACK_BADGE"], 280, 26)
    dd:SetPoint("TOPLEFT", 14, -48)
    sendWidgets.dd = dd

    local nameLabel = OneWoW_GUI:CreateFS(content, 11)
    nameLabel:SetPoint("TOPLEFT", 14, -88)
    nameLabel:SetText(NAME)
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    sendWidgets.nameLabel = nameLabel

    local nameBox = OneWoW_GUI:CreateEditBox(content, {
        placeholderText = L["WAYPINS_PACK_NAME_PH"],
        width = 280,
        maxLetters = 60,
    })
    nameBox:SetPoint("TOPLEFT", 14, -108)
    sendWidgets.nameBox = nameBox

    local expLabel = OneWoW_GUI:CreateFS(content, 11)
    expLabel:SetPoint("TOPLEFT", 14, -142)
    expLabel:SetText(L["EXPANSION"])
    expLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    sendWidgets.expLabel = expLabel

    local expDD = ns.UI.CreateThemedDropdown(content, "", 280, 26, ns.UI.GetWayPinExpansionMenuHeight())
    expDD:SetPoint("TOPLEFT", 14, -162)
    expDD:SetOptions(ns.UI.GetWayPinExpansionOptions())
    sendWidgets.expDD = expDD

    dd.onSelect = function(value)
        sendSelected = value
        SyncSendNewFields()
    end
    return sendDialog
end

function ns.UI.OpenWayPinSendToPack(pinID)
    local pin = pinID and ns.WayPins:GetPin(pinID)
    if not pin then
        return
    end
    local skipPackId
    if ns.WayPinPacks:IsPackPinId(pinID) then
        skipPackId = select(1, ns.WayPinPacks:ParseDisplayId(pinID))
    end
    sendPinID = pinID
    sendSelected = "__new"
    EnsureSendDialog()
    sendWidgets.hint:SetText(string.format(L["WAYPINS_SEND_TO_PACK_HINT"], pin.title or L["WAYPINS_UNTITLED"]))
    local options = { { text = L["WAYPINS_PACK_NEW"], value = "__new" } }
    for _, pack in ipairs(ns.WayPinPacks:GetAllPacks()) do
        if pack.id ~= skipPackId then
            tinsert(options, { text = pack.name, value = pack.id })
        end
    end
    sendWidgets.dd:SetOptions(options)
    sendWidgets.dd:SetSelected("__new")
    sendWidgets.nameBox:SetText("")
    sendWidgets.expDD:SetSelected("")
    SyncSendNewFields()
    sendDialog.frame:Show()
    sendDialog.frame:Raise()
end

function ns.UI.OpenWayPinPackRemove(packId)
    local pack = ns.WayPinPacks:GetPack(packId)
    if not pack then
        return
    end
    local result = OneWoW_GUI:CreateConfirmDialog({
        title = L["WAYPINS_PACK_REMOVE"],
        message = string.format(L["WAYPINS_PACK_REMOVE_CONFIRM"], pack.name or pack.id),
        width = 520,
        buttons = {
            {
                text = L["WAYPINS_PACK_REMOVE_RETURN"],
                onClick = function(dlg)
                    ns.WayPinPacks:RemovePack(packId, true)
                    dlg:Hide()
                end,
            },
            {
                text = L["WAYPINS_PACK_REMOVE_DELETE"],
                color = { 0.8, 0.2, 0.2 },
                onClick = function(dlg)
                    ns.WayPinPacks:RemovePack(packId, false)
                    dlg:Hide()
                end,
            },
            { text = CANCEL, onClick = function(dlg) dlg:Hide() end },
        },
    })
    result.frame:Show()
end

function ns.UI.OpenWayPinPackLook(packId)
    local pack = ns.WayPinPacks:GetPack(packId)
    if not pack then
        return
    end
    local seed = ns.WayPinPacks:LookForPaint(pack)
    seed.packLook = true
    seed.packId = packId
    ns.UI.OpenWayPinDialog(seed)
end

local createDialog
local createWidgets = {}

local function EnsureCreateDialog()
    if createDialog then
        return createDialog
    end
    createDialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_NotesWayPinPackCreate",
        title = L["WAYPINS_PACK_NEW"],
        width = 420,
        height = 200,
        buttons = {
            {
                text = OKAY,
                onClick = function(f)
                    local name = strtrim(createWidgets.nameBox:GetSearchText() or "")
                    if name == "" then
                        PrintFail("WAYPINS_PACK_NAME_REQUIRED")
                        return
                    end
                    local packId = ns.WayPinPacks:CreatePack({
                        name = name,
                        expansion = createWidgets.expDD:GetValue(),
                        source = "user",
                    })
                    if packId then
                        ns.UI.SelectWayPinPack(packId)
                        f:Hide()
                    end
                end,
            },
            { text = CANCEL, onClick = function(f) f:Hide() end },
        },
    })
    local content = createDialog.contentFrame
    local nameLabel = OneWoW_GUI:CreateFS(content, 11)
    nameLabel:SetPoint("TOPLEFT", 14, -10)
    nameLabel:SetText(NAME)
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local nameBox = OneWoW_GUI:CreateEditBox(content, {
        placeholderText = L["WAYPINS_PACK_NAME_PH"],
        width = 280,
        maxLetters = 60,
    })
    nameBox:SetPoint("TOPLEFT", 14, -30)
    createWidgets.nameBox = nameBox

    local expLabel = OneWoW_GUI:CreateFS(content, 11)
    expLabel:SetPoint("TOPLEFT", 14, -64)
    expLabel:SetText(L["EXPANSION"])
    expLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local expDD = ns.UI.CreateThemedDropdown(content, "", 280, 26, ns.UI.GetWayPinExpansionMenuHeight())
    expDD:SetPoint("TOPLEFT", 14, -84)
    expDD:SetOptions(ns.UI.GetWayPinExpansionOptions())
    createWidgets.expDD = expDD
    return createDialog
end

--- Create an empty user pack (name and optional expansion).
function ns.UI.OpenWayPinPackCreate()
    EnsureCreateDialog()
    createWidgets.nameBox:SetText("")
    createWidgets.expDD:SetSelected("")
    createDialog.frame:Show()
    createDialog.frame:Raise()
end
