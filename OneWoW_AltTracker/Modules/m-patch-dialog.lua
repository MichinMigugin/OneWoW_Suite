local addonName, ns = ...
local OneWoWAltTracker = OneWoW_AltTracker
local L = ns.L
local T = ns.T
local S = ns.S

ns.PatchDialog = ns.PatchDialog or {}
local PatchDialog = ns.PatchDialog

local DISCORD_LINK = "https://discord.gg/6vnabDVnDu"
local COFFEE_LINK = "https://buymeacoffee.com/migugin"

local SUPPORTER_NAMES = {
    "MacMode macmodex",
    "SnerkDevil snerkdevil",
    "tiradox tiradox."
}

local BETA_TESTER_NAMES = {
    "Ashlayah ashlaya",
    "Clew clewdm",
    "DuelingOgresPodcast duelingogrespodcast",
    "Proto topproto",
    "Shy nisashy",
    "ThomMonster thomaseak"
}

function PatchDialog:Initialize()
    if self.initialized then return end
    self.initialized = true

    if not OneWoWAltTracker.db.global.patchDialog then
        OneWoWAltTracker.db.global.patchDialog = {
            lastShownVersion = nil
        }
    end
end

function PatchDialog:ShouldShowWelcome()
    self:Initialize()

    if not OneWoWAltTracker.db.global.patchDialog then
        return true
    end

    local currentVersion = ns.GetVersionString()
    local lastShown = OneWoWAltTracker.db.global.patchDialog.lastShownVersion

    if not lastShown or lastShown ~= currentVersion then
        return true
    end

    return false
end

function PatchDialog:Show()
    self:Initialize()

    if _G["OneWoWAltTrackerPatchDialog"] and _G["OneWoWAltTrackerPatchDialog"]:IsShown() then
        _G["OneWoWAltTrackerPatchDialog"]:Raise()
        return
    end

    local RELATED_ADDONS = {
        {name = L["PATCH_DIALOG_ADDON_CATALOG"], url = "https://www.curseforge.com/wow/addons/wownotes-catalog"},
        {name = L["PATCH_DIALOG_ADDON_BAGS"], url = "https://www.curseforge.com/wow/addons/wownotes-bags"},
        {name = L["PATCH_DIALOG_ADDON_SHOPPING"], url = "https://www.curseforge.com/wow/addons/wownotes-shopping-list"},
        {name = L["PATCH_DIALOG_ADDON_DEPOSIT"], url = "https://www.curseforge.com/wow/addons/wownotes-direct-item-deposit"},
        {name = L["PATCH_DIALOG_ADDON_DEVTOOLS"], url = "https://www.curseforge.com/wow/addons/wownotes-dev-tools"}
    }

    local dialog = CreateFrame("Frame", "OneWoWAltTrackerPatchDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(700, 600)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")

    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dialog:SetBackdropColor(T("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local titleBg = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    titleBg:SetPoint("TOPLEFT", dialog, "TOPLEFT", S("XS"), -S("XS"))
    titleBg:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -S("XS"), -S("XS"))
    titleBg:SetHeight(40)
    titleBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    titleBg:SetBackdropColor(T("TITLEBAR_BG"))
    titleBg:SetFrameLevel(dialog:GetFrameLevel() + 1)

    local title = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleBg, "LEFT", S("SM"), 0)
    title:SetText(L["PATCH_DIALOG_TITLE"] .. " " .. L["PATCH_DIALOG_VERSION"] .. " " .. ns.GetVersionString())
    title:SetTextColor(T("TEXT_PRIMARY"))

    local closeButton = ns.UI.CreateButton(nil, titleBg, "X", 20, 20)
    closeButton:SetPoint("RIGHT", titleBg, "RIGHT", -S("XS")/2, 0)
    closeButton:SetScript("OnClick", function()
        OneWoWAltTracker.db.global.patchDialog.lastShownVersion = ns.GetVersionString()
        dialog:Hide()
    end)

    local contentFrame = CreateFrame("Frame", nil, dialog)
    contentFrame:SetPoint("TOPLEFT", titleBg, "BOTTOMLEFT", S("XS"), -S("SM"))
    contentFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -S("XS"), S("XS")*2 + 40)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame)
    scrollFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -2, 0)
    scrollFrame:EnableMouseWheel(true)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(scrollFrame:GetWidth() - 20)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(self, width, height)
        scrollContent:SetWidth(width - 20)
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 40))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
    end)

    local yOffset = -10

    local discordLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    discordLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    discordLabel:SetText(L["PATCH_DIALOG_DISCORD"])
    discordLabel:SetTextColor(T("TEXT_ACCENT"))
    yOffset = yOffset - 22

    local discordBox = ns.UI.CreateEditBox(nil, scrollContent, 650, 24)
    discordBox:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    discordBox:SetText(DISCORD_LINK)
    discordBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    discordBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    discordBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    discordBox:SetScript("OnMouseDown", function(self) self:SetFocus() self:HighlightText() end)
    yOffset = yOffset - 40

    local coffeeLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coffeeLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    coffeeLabel:SetText(L["PATCH_DIALOG_SUPPORT"])
    coffeeLabel:SetTextColor(T("TEXT_ACCENT"))
    yOffset = yOffset - 22

    local coffeeBox = ns.UI.CreateEditBox(nil, scrollContent, 650, 24)
    coffeeBox:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    coffeeBox:SetText(COFFEE_LINK)
    coffeeBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    coffeeBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    coffeeBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    coffeeBox:SetScript("OnMouseDown", function(self) self:SetFocus() self:HighlightText() end)
    yOffset = yOffset - 40

    local thanksHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    thanksHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    thanksHeader:SetText(L["PATCH_DIALOG_SPECIAL_THANKS"])
    thanksHeader:SetTextColor(T("TEXT_ACCENT"))
    yOffset = yOffset - 22

    local thanksDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    thanksDesc:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    thanksDesc:SetText(L["PATCH_DIALOG_SPECIAL_THANKS_DESC"])
    thanksDesc:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - 22

    yOffset = yOffset - 15

    local supporterHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    supporterHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    supporterHeader:SetText(L["PATCH_DIALOG_SPECIAL_THANKS"])
    supporterHeader:SetTextColor(T("TEXT_ACCENT"))

    local betaHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    betaHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 330, yOffset)
    betaHeader:SetText(L["PATCH_DIALOG_BETA_TESTERS"])
    betaHeader:SetTextColor(T("TEXT_ACCENT"))
    yOffset = yOffset - 22

    local supporterDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    supporterDesc:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    supporterDesc:SetText(L["PATCH_DIALOG_SPECIAL_THANKS_DESC"])
    supporterDesc:SetTextColor(T("TEXT_PRIMARY"))

    local betaDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    betaDesc:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 330, yOffset)
    betaDesc:SetText(L["PATCH_DIALOG_BETA_TESTERS_DESC"])
    betaDesc:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - 22

    local supporterYOffset = yOffset
    local betaYOffset = yOffset

    for _, name in ipairs(SUPPORTER_NAMES) do
        local firstName = strsplit(" ", name)
        local supporterText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        supporterText:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 20, supporterYOffset)
        supporterText:SetText("• " .. firstName)
        supporterText:SetTextColor(T("TEXT_PRIMARY"))
        supporterYOffset = supporterYOffset - 20
    end

    for _, name in ipairs(BETA_TESTER_NAMES) do
        local firstName = strsplit(" ", name)
        local betaTesterText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        betaTesterText:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 350, betaYOffset)
        betaTesterText:SetText("• " .. firstName)
        betaTesterText:SetTextColor(T("TEXT_PRIMARY"))
        betaYOffset = betaYOffset - 20
    end

    yOffset = math.min(supporterYOffset, betaYOffset) - 15

    yOffset = yOffset - 15

    local addonsHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addonsHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    addonsHeader:SetText(L["PATCH_DIALOG_ADDONS"])
    addonsHeader:SetTextColor(T("TEXT_ACCENT"))
    yOffset = yOffset - 22

    for _, addon in ipairs(RELATED_ADDONS) do
        local addonLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        addonLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        addonLabel:SetText(addon.name)
        addonLabel:SetTextColor(T("TEXT_ACCENT"))
        yOffset = yOffset - 22

        local addonBox = ns.UI.CreateEditBox(nil, scrollContent, 650, 24)
        addonBox:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        addonBox:SetText(addon.url)
        addonBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        addonBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        addonBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        addonBox:SetScript("OnMouseDown", function(self) self:SetFocus() self:HighlightText() end)
        yOffset = yOffset - 35
    end

    yOffset = yOffset - 10

    local copyTip = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    copyTip:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    copyTip:SetText(L["PATCH_DIALOG_COPY_TIP"])
    copyTip:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - 25

    scrollContent:SetHeight(math.abs(yOffset) + 30)

    local closeBtn = ns.UI.CreateButton(nil, dialog, L["PATCH_DIALOG_CLOSE"], 120, 28)
    closeBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 0, S("SM"))
    closeBtn:SetScript("OnClick", function()
        OneWoWAltTracker.db.global.patchDialog.lastShownVersion = ns.GetVersionString()
        dialog:Hide()
    end)

    dialog:Show()
end

function PatchDialog:CheckAndShow()
    if self:ShouldShowWelcome() then
        C_Timer.After(0.5, function()
            self:Show()
        end)
    end
end
