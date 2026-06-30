local ADDON_NAME, ns = ...
local L = ns.L

ns.BagButton = {}
local BagButton = ns.BagButton

local function GetDB()
    return ns.db
end

local function CreateShoppingButton(parent, anchorPoint, anchorRelative)
    if not parent then return nil end

    local fieldName = "_owsl_shoppingBtn"
    if parent[fieldName] then
        parent[fieldName]:Show()
        return parent[fieldName]
    end

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(28, 28)
    btn:SetPoint(anchorPoint or "TOPLEFT", parent, anchorRelative or "TOPLEFT", 10, -35)
    btn:SetFrameLevel(parent:GetFrameLevel() + 10)
    btn:SetNormalAtlas("Perks-ShoppingCart")
    btn:SetPushedAtlas("Perks-ShoppingCart")
    btn:SetHighlightAtlas("Perks-ShoppingCart")
    btn:GetHighlightTexture():SetAlpha(0.5)

    btn:SetScript("OnClick", function()
        if ns.MainWindow then
            ns.MainWindow:Toggle()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["OWSL_BAG_BUTTON_TOOLTIP"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_BAG_BUTTON_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    parent[fieldName] = btn
    btn:Show()
    return btn
end

function BagButton:CreateButtons()
    if GetDB().global.settings.showBagButtons == false then return end
    self:CreateCombinedBagsButton()
    self:CreateBackpackButton()
end

function BagButton:UpdateVisibility()
    local show = GetDB().global.settings.showBagButtons ~= false
    if show then
        self:CreateCombinedBagsButton()
        self:CreateBackpackButton()
    else
        local function hideBtn(parent)
            if parent and parent._owsl_shoppingBtn then
                parent._owsl_shoppingBtn:Hide()
            end
        end
        hideBtn(ContainerFrameCombinedBags)
        hideBtn(ContainerFrame1)
    end
end

function BagButton:CreateCombinedBagsButton()
    if not ContainerFrameCombinedBags then return end
    CreateShoppingButton(ContainerFrameCombinedBags, "TOPLEFT", "TOPLEFT")
end

function BagButton:CreateBackpackButton()
    local backpack = ContainerFrame1
    if not backpack then return end
    CreateShoppingButton(backpack, "TOPLEFT", "TOPLEFT")
end

local ahBtn = nil

function BagButton:CreateAuctionHouseButton()
    if ahBtn then return end

    local closeBtn = AuctionHouseFrameCloseButton
    local ahFrame = AuctionHouseFrame
    if not ahFrame then return end

    -- Parent to the AH frame (not UIParent) so the cart shares the AH window's
    -- strata and is hidden/occluded with it, instead of floating on top of every
    -- other window. Frame level sits just above the close button cluster.
    local btn = CreateFrame("Button", nil, ahFrame)
    btn:SetSize(28, 28)
    btn:SetFrameLevel((closeBtn or ahFrame):GetFrameLevel() + 1)
    btn:EnableMouse(true)

    if closeBtn then
        btn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    else
        btn:SetPoint("TOPRIGHT", ahFrame, "TOPRIGHT", -56, -5)
    end

    btn:SetNormalAtlas("Perks-ShoppingCart")
    btn:SetPushedAtlas("Perks-ShoppingCart")
    btn:SetHighlightAtlas("Perks-ShoppingCart")
    btn:GetHighlightTexture():SetAlpha(0.5)

    btn:SetScript("OnClick", function()
        if ns.MainWindow then
            ns.MainWindow:Toggle()
        end
    end)

    btn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
        GameTooltip:SetText(L["OWSL_BAG_BUTTON_TOOLTIP"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_BAG_BUTTON_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ahBtn = btn
end

function BagButton:UpdateAHVisibility()
    local show = GetDB().global.settings.showAHButton ~= false
    local ahFrame = AuctionHouseFrame
    if show and ahFrame and ahFrame:IsShown() then
        self:CreateAuctionHouseButton()
        if ahBtn then ahBtn:Show() end
    else
        if ahBtn then ahBtn:Hide() end
    end
end

function BagButton:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("AUCTION_HOUSE_SHOW")
    frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_SHOW" then
            if GetDB().global.settings.showAHButton ~= false then
                BagButton:CreateAuctionHouseButton()
                if ahBtn then ahBtn:Show() end
            end
        elseif event == "AUCTION_HOUSE_CLOSED" then
            if ahBtn then ahBtn:Hide() end
        end
    end)

    local function deferCreateButtons()
        C_Timer.After(1, function()
            BagButton:CreateButtons()
        end)
    end
    OneWoW_ShoppingList:RegisterAddonLoadedWatcher("Blizzard_UIParent", deferCreateButtons)
    OneWoW_ShoppingList:RegisterAddonLoadedWatcher(ADDON_NAME, deferCreateButtons)

    if ContainerFrameCombinedBags then
        deferCreateButtons()
    end
end
