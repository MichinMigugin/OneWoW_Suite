local ADDON_NAME, ns = ...
local L = ns.L

ns.BagButton = {}
local BagButton = ns.BagButton

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
    local db = _G.OneWoW_ShoppingList_DB
    if db and db.global and db.global.settings.showBagButtons == false then return end
    self:CreateCombinedBagsButton()
    self:CreateBackpackButton()
end

function BagButton:UpdateVisibility()
    local db = _G.OneWoW_ShoppingList_DB
    local show = not (db and db.global and db.global.settings.showBagButtons == false)
    if show then
        self:CreateCombinedBagsButton()
        self:CreateBackpackButton()
    else
        local function hideBtn(parent)
            if parent and parent._owsl_shoppingBtn then
                parent._owsl_shoppingBtn:Hide()
            end
        end
        hideBtn(_G.ContainerFrameCombinedBags)
        hideBtn(_G.ContainerFrame1)
    end
end

function BagButton:CreateCombinedBagsButton()
    if not _G.ContainerFrameCombinedBags then return end
    CreateShoppingButton(_G.ContainerFrameCombinedBags, "TOPLEFT", "TOPLEFT")
end

function BagButton:CreateBackpackButton()
    local backpack = _G.ContainerFrame1
    if not backpack then return end
    CreateShoppingButton(backpack, "TOPLEFT", "TOPLEFT")
end

local ahBtn = nil

function BagButton:CreateAuctionHouseButton()
    if ahBtn then return end

    local closeBtn = _G.AuctionHouseFrameCloseButton
    local ahFrame = _G.AuctionHouseFrame
    if not closeBtn and not ahFrame then return end

    local btn = CreateFrame("Button", nil, UIParent)
    btn:SetSize(28, 28)
    btn:SetFrameStrata("HIGH")
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

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
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
    local db = _G.OneWoW_ShoppingList_DB
    local show = not (db and db.global and db.global.settings.showAHButton == false)
    local ahFrame = _G.AuctionHouseFrame
    if show and ahFrame and ahFrame:IsShown() then
        self:CreateAuctionHouseButton()
        if ahBtn then ahBtn:Show() end
    else
        if ahBtn then ahBtn:Hide() end
    end
end

function BagButton:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("AUCTION_HOUSE_SHOW")
    frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    frame:SetScript("OnEvent", function(self, event, addon)
        if event == "ADDON_LOADED" then
            if addon == "Blizzard_UIParent" or addon == ADDON_NAME then
                C_Timer.After(1, function()
                    BagButton:CreateButtons()
                end)
            end
        elseif event == "AUCTION_HOUSE_SHOW" then
            local db = _G.OneWoW_ShoppingList_DB
            if not (db and db.global and db.global.settings.showAHButton == false) then
                BagButton:CreateAuctionHouseButton()
                if ahBtn then ahBtn:Show() end
            end
        elseif event == "AUCTION_HOUSE_CLOSED" then
            if ahBtn then ahBtn:Hide() end
        end
    end)

    if _G.ContainerFrameCombinedBags then
        C_Timer.After(1, function()
            BagButton:CreateButtons()
        end)
    end
end
