local addonName, ns = ...

local Panel = {}
ns.Panel = Panel

local ROW_HEIGHT = 42
local PANEL_WIDTH = 360
local PANEL_HEIGHT = 530
local PAD = 10

local function ThemeColor(key, fallbackR, fallbackG, fallbackB, fallbackA)
    if ns.GUI and ns.GUI.GetThemeColor then
        local r, g, b, a = ns.GUI:GetThemeColor(key)
        if r then
            return r, g, b, a
        end
    end

    return fallbackR, fallbackG, fallbackB, fallbackA or 1
end

local function CreateFontString(parent, size)
    if ns.GUI and ns.GUI.CreateFS then
        return ns.GUI:CreateFS(parent, size)
    end

    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(STANDARD_TEXT_FONT, size or 12)
    return fs
end

local function AnchorToInspect(frame)
    frame:ClearAllPoints()

    local side = ns.db and ns.db.attachSide or "RIGHT"
    if InspectFrame and side == "LEFT" then
        frame:SetPoint("TOPRIGHT", InspectFrame, "TOPLEFT", -6, 0)
    elseif InspectFrame then
        frame:SetPoint("TOPLEFT", InspectFrame, "TOPRIGHT", 6, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 340, 0)
    end
end

local function SetRowText(row, snapshotRow)
    local itemName = snapshotRow.itemName or snapshotRow.itemLink or "Empty"
    local appearanceName =
        snapshotRow.appearanceName
        or (
            snapshotRow.appearanceSourceID
            and ("Source #" .. tostring(snapshotRow.appearanceSourceID))
        )
        or "Native appearance"

    row.slot:SetText(snapshotRow.slotName)
    row.item:SetText(itemName)
    row.appearance:SetText(appearanceName)

    if snapshotRow.texture then
        row.icon:SetTexture(snapshotRow.texture)
    else
        row.icon:SetTexture(134400)
    end

    if snapshotRow.isChanged then
        row.appearance:SetTextColor(0.4, 1, 0.45)
    else
        row.appearance:SetTextColor(0.7, 0.7, 0.7)
    end
end

function Panel:IsShownForInspect()
    return self.frame and self.frame:IsShown()
end

function Panel:EnsureFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "OneWoWInspectMogPanel", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local bgR, bgG, bgB, bgA = ThemeColor("BG_PRIMARY", 0.03, 0.05, 0.04, 0.95)
    local brR, brG, brB, brA = ThemeColor("BORDER_DEFAULT", 0.16, 0.32, 0.18, 1)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(brR, brG, brB, brA)

    local title = CreateFontString(frame, 13)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -PAD)
    title:SetJustifyH("LEFT")
    title:SetText("Inspect Transmog")
    title:SetTextColor(0.35, 0.9, 0.45)
    frame.title = title

    local sub = CreateFontString(frame, 10)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -4)
    sub:SetJustifyH("LEFT")
    sub:SetTextColor(0.7, 0.7, 0.7)
    frame.subtitle = sub

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -48)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, PAD)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetSize(PANEL_WIDTH - 42, 100)
    scrollFrame:SetScrollChild(child)

    frame.scrollFrame = scrollFrame
    frame.scrollChild = child
    frame.rows = {}

    self.frame = frame
    AnchorToInspect(frame)
    frame:Hide()
end

function Panel:GetRow(index)
    local frame = self.frame
    local row = frame.rows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, frame.scrollChild)
    row:SetSize(PANEL_WIDTH - 48, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.slot = CreateFontString(row, 10)
    row.slot:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
    row.slot:SetWidth(82)
    row.slot:SetJustifyH("LEFT")
    row.slot:SetTextColor(0.7, 0.7, 0.7)

    row.item = CreateFontString(row, 11)
    row.item:SetPoint("TOPLEFT", row.slot, "TOPRIGHT", 8, 0)
    row.item:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -2)
    row.item:SetJustifyH("LEFT")
    row.item:SetWordWrap(false)
    row.item:SetTextColor(1, 1, 1)

    row.appearance = CreateFontString(row, 11)
    row.appearance:SetPoint("TOPLEFT", row.item, "BOTTOMLEFT", 0, -4)
    row.appearance:SetPoint("TOPRIGHT", row.item, "BOTTOMRIGHT", 0, -4)
    row.appearance:SetJustifyH("LEFT")
    row.appearance:SetWordWrap(false)

    frame.rows[index] = row
    return row
end

function Panel:Refresh(unit)
    self:EnsureFrame()
    AnchorToInspect(self.frame)

    local snapshot =
        ns.Scanner
        and ns.Scanner.BuildInspectSnapshot
        and ns.Scanner:BuildInspectSnapshot(unit)

    if not snapshot then
        self.frame.subtitle:SetText("No inspect data available.")
        for _, row in ipairs(self.frame.rows) do
            row:Hide()
        end
        return
    end

    self.frame.subtitle:SetText(snapshot.name or "Inspected player")

    for i, data in ipairs(snapshot.rows) do
        local row = self:GetRow(i)
        SetRowText(row, data)
        row.data = data
        row:SetScript("OnEnter", function(self)
            if self.data and self.data.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.data.itemLink)
                if self.data.appearanceSourceID then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Appearance source: " .. tostring(self.data.appearanceSourceID), 0.4, 1, 0.45)
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:Show()
    end

    for i = #snapshot.rows + 1, #self.frame.rows do
        self.frame.rows[i]:Hide()
    end

    self.frame.scrollChild:SetHeight(math.max(100, #snapshot.rows * ROW_HEIGHT))
end

function Panel:Show()
    self:EnsureFrame()
    AnchorToInspect(self.frame)
    self.frame:Show()

    if ns.Scanner and ns.Scanner.Request then
        ns.Scanner:Request()
    end
end

function Panel:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Panel:Initialize()
    self:EnsureFrame()

    local function LoadInspectUI()
        if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then
            return true
        end

        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_InspectUI")
        elseif LoadAddOn then
            pcall(LoadAddOn, "Blizzard_InspectUI")
        end

        if C_AddOns and C_AddOns.IsAddOnLoaded then
            return C_AddOns.IsAddOnLoaded("Blizzard_InspectUI")
        end

        return InspectFrame ~= nil
    end

    local function HookInspectFrame()
        if self.inspectHooked or not InspectFrame then
            return
        end

        self.inspectHooked = true

        InspectFrame:HookScript("OnShow", function()
            if ns.db and ns.db.enabled then
                Panel:Show()
            end
        end)

        InspectFrame:HookScript("OnHide", function()
            Panel:Hide()
        end)

        if InspectFrame:IsShown() and ns.db and ns.db.enabled then
            Panel:Show()
        end
    end

    LoadInspectUI()
    HookInspectFrame()

    if InspectFrame then
        return
    end

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(_, _, loadedAddon)
        if loadedAddon == "Blizzard_InspectUI" then
            HookInspectFrame()
            loader:UnregisterAllEvents()
        end
    end)
end
