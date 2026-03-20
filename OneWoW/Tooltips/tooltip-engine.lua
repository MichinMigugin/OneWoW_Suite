local ADDON_NAME, OneWoW = ...

local TooltipEngine = {}
OneWoW.TooltipEngine = TooltipEngine

local isProcessingTooltip = false
local sectionProviders = {}

local TOOLTIP_CONFIG = {
    headerColor = {0.2, 1.0, 0.2},
    typeColor = {0.9, 0.8, 0.4},
    subHeaderColor = {0.4, 0.8, 1.0},
    textColor = {0.9, 0.9, 0.9},
    locationHeaderColor = {0.4, 0.8, 1.0},
    characterNameColor = {0.9, 0.9, 0.9},
    locationTextColor = {0.8, 0.8, 0.8},
    countColor = {0.4, 0.8, 1.0},
    learnedColor = {0.4, 0.8, 0.4},
    notLearnedColor = {0.8, 0.4, 0.4},
    junkColor = {1.0, 0.2, 0.2},
    protectedColor = {0.8, 0.2, 1.0},
    idLabelColor = {1.0, 0.9, 0.0},
    idValueColor = {1.0, 1.0, 1.0},
    expansionNameColor = {0.4, 0.6, 1.0},
    expansionVersionColor = {0.7, 0.7, 0.7},
    noteWarningColor = {1.0, 1.0, 0.5},
}

TooltipEngine.TOOLTIP_CONFIG = TOOLTIP_CONFIG

function TooltipEngine:RegisterProvider(provider)
    table.insert(sectionProviders, provider)
    table.sort(sectionProviders, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
end

function TooltipEngine:Initialize()
    if not OneWoW.db then
        C_Timer.After(2, function() self:Initialize() end)
        return
    end

    self:EnsureDefaults()
    self:HookTooltips()
    self:HookAchievementUI()
end

function TooltipEngine:EnsureDefaults()
    local db = OneWoW.db and OneWoW.db.global
    if not db then return end
    if not db.settings then db.settings = {} end
    if not db.settings.tooltips then db.settings.tooltips = {} end
    if not db.settings.tooltips.general then
        db.settings.tooltips.general = { enabled = true }
    end
    if db.settings.tooltips.general.enabled == nil then
        db.settings.tooltips.general.enabled = true
    end
end

function TooltipEngine:IsEnabled()
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    if not db or not db.tooltips then return false end
    if not db.tooltips.general then return false end
    return db.tooltips.general.enabled == true
end

function TooltipEngine:IsFeatureEnabled(featureId)
    if not self:IsEnabled() then return false end
    return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", featureId)
end

function TooltipEngine:HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
            self:ProcessTooltipData(tooltip, data)
        end)
    else
        if GameTooltip:HasScript("OnTooltipSetUnit") then
            GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
                self:OnTooltipSetUnit(tooltip)
            end)
        end

        if GameTooltip:HasScript("OnTooltipSetItem") then
            GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
                self:OnTooltipSetItem(tooltip)
            end)
        end

        if ItemRefTooltip and ItemRefTooltip.SetHyperlink then
            hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(tooltip, link)
                self:OnTooltipSetItem(tooltip, link)
            end)
        end
    end
end

function TooltipEngine:ProcessTooltipData(tooltip, data)
    if not self:IsEnabled() then return end
    if isProcessingTooltip then return end
    if not data or not data.type then return end
    if not Enum or not Enum.TooltipDataType then return end
    if issecretvalue(data.type) then return end

    local tooltipType = tonumber(data.type)
    if not tooltipType then return end

    isProcessingTooltip = true

    local context = self:BuildContext(tooltip, tooltipType, data)
    if context.type then
        self:ProcessProviders(tooltip, context)
    end

    isProcessingTooltip = false
end

function TooltipEngine:BuildContext(tooltip, tooltipType, data)
    local context = {
        tooltipType = tooltipType,
        data = data,
    }

    if tooltipType == Enum.TooltipDataType.Unit then
        if data.guid and not issecretvalue(data.guid) then
            local _, unit = tooltip:GetUnit()
            context.unit = unit
            context.isPlayer = unit and UnitIsPlayer(unit)
            local unitType = data.guid:match("%a+")
            if (unitType == "Creature" or unitType == "Vehicle") and not context.isPlayer then
                local _, _, _, _, _, npcIDStr = strsplit("-", data.guid)
                context.npcID = tonumber(npcIDStr)
            end
        end
        context.type = "unit"
    elseif tooltipType == Enum.TooltipDataType.Item then
        if data.id and tooltip.GetItem then
            local _, itemLink = tooltip:GetItem()
            context.itemID = data.id
            context.itemLink = itemLink
        end
        context.type = "item"
    elseif tooltipType == Enum.TooltipDataType.Spell then
        context.spellID = data.id
        context.type = "spell"
    elseif tooltipType == Enum.TooltipDataType.Mount then
        context.mountID = data.id
        context.type = "mount"
    elseif tooltipType == Enum.TooltipDataType.Currency then
        context.currencyID = data.id
        context.type = "currency"
    elseif tooltipType == Enum.TooltipDataType.BattlePet then
        context.petID = data.id
        context.type = "pet"
    elseif tooltipType == Enum.TooltipDataType.Achievement then
        context.achievementID = data.id
        context.type = "achievement"
    elseif tooltipType == Enum.TooltipDataType.Quest then
        context.questID = data.id
        context.type = "quest"
    elseif tooltipType == Enum.TooltipDataType.Toy then
        context.itemID = data.id
        context.type = "toy"
    elseif tooltipType == Enum.TooltipDataType.UnitAura then
        context.spellID = data.id
        context.type = "unitaura"
    elseif tooltipType == Enum.TooltipDataType.CompanionPet then
        context.petID = data.id
        context.type = "companionpet"
    elseif tooltipType == Enum.TooltipDataType.Totem then
        context.spellID = data.id
        context.type = "totem"
    elseif tooltipType == Enum.TooltipDataType.QuestPartyProgress then
        context.questID = data.id
        context.type = "questpartyprogress"
    elseif tooltipType == Enum.TooltipDataType.RecipeRankInfo then
        context.recipeID = data.id
        context.type = "recipe"
    elseif tooltipType == Enum.TooltipDataType.EquipmentSet then
        context.equipmentSetID = data.id
        context.type = "equipmentset"
    elseif tooltipType == Enum.TooltipDataType.AzeriteEssence then
        context.essenceID = data.id
        context.type = "azeriteessence"
    elseif tooltipType == Enum.TooltipDataType.EnhancedConduit then
        context.conduitID = data.id
        context.type = "conduit"
    elseif tooltipType == Enum.TooltipDataType.Outfit then
        context.outfitID = data.id
        context.type = "outfit"
    elseif tooltipType == Enum.TooltipDataType.Macro then
        context.macroID = data.id
        context.type = "macro"
    elseif tooltipType == Enum.TooltipDataType.Object then
        context.objectID = data.id
        context.type = "object"
    end

    return context
end

function TooltipEngine:ProcessProviders(tooltip, context)
    local allLines = {}

    for _, provider in ipairs(sectionProviders) do
        if self:ProviderMatchesType(provider, context.type) then
            local featureEnabled = true
            if provider.featureId then
                featureEnabled = self:IsFeatureEnabled(provider.featureId)
            end

            if featureEnabled then
                local success, lines = pcall(provider.callback, tooltip, context)
                if success and lines and #lines > 0 then
                    for _, line in ipairs(lines) do
                        table.insert(allLines, line)
                    end
                end
            end
        end
    end

    if #allLines == 0 then return end

    if self:TooltipHasOneWoWSection(tooltip) then return end

    local headerRight = nil
    local contentLines = {}
    for _, line in ipairs(allLines) do
        if line.type == "headerRight" and not headerRight then
            headerRight = line
        else
            table.insert(contentLines, line)
        end
    end

    tooltip:AddLine(" ")

    local _gui = LibStub and LibStub("OneWoW_GUI-1.0", true)
    local iconTheme = (_gui and _gui:GetSetting("minimap.theme")) or "neutral"
    local addonIcon = CreateTextureMarkup("Interface\\AddOns\\OneWoW\\Media\\OneWoWMini-" .. iconTheme, 64, 64, 16, 16, 0, 1, 0, 1)
    if headerRight then
        tooltip:AddDoubleLine(
            addonIcon .. " OneWoW",
            headerRight.text,
            TOOLTIP_CONFIG.headerColor[1], TOOLTIP_CONFIG.headerColor[2], TOOLTIP_CONFIG.headerColor[3],
            headerRight.r or 0.9, headerRight.g or 0.9, headerRight.b or 0.9
        )
    else
        tooltip:AddLine(addonIcon .. " OneWoW", TOOLTIP_CONFIG.headerColor[1], TOOLTIP_CONFIG.headerColor[2], TOOLTIP_CONFIG.headerColor[3])
    end

    for _, line in ipairs(contentLines) do
        if line.type == "text" then
            tooltip:AddLine(line.text, line.r or 0.9, line.g or 0.9, line.b or 0.9)
        elseif line.type == "header" then
            tooltip:AddLine(line.text, line.r or TOOLTIP_CONFIG.subHeaderColor[1], line.g or TOOLTIP_CONFIG.subHeaderColor[2], line.b or TOOLTIP_CONFIG.subHeaderColor[3])
        elseif line.type == "double" then
            tooltip:AddDoubleLine(
                line.left, line.right,
                line.lr or 0.9, line.lg or 0.9, line.lb or 0.9,
                line.rr or 1, line.rg or 1, line.rb or 1
            )
        end
    end

end

function TooltipEngine:ProviderMatchesType(provider, tooltipType)
    if not provider.tooltipTypes then return true end
    for _, t in ipairs(provider.tooltipTypes) do
        if t == tooltipType then return true end
    end
    return false
end

function TooltipEngine:TooltipHasOneWoWSection(tooltip)
    if not tooltip or not tooltip.NumLines then return false end
    local tooltipName = tooltip:GetName()
    if not tooltipName then return false end

    for i = 1, tooltip:NumLines() do
        local line = _G[tooltipName .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and not issecretvalue(text) and string.find(text, "OneWoW") then
                return true
            end
        end
    end
    return false
end

function TooltipEngine:OnTooltipSetUnit(tooltip)
    if not self:IsEnabled() then return end
    if isProcessingTooltip then return end

    isProcessingTooltip = true
    local _, unit = tooltip:GetUnit()
    if unit then
        local context = {
            type = "unit",
            unit = unit,
            isPlayer = UnitIsPlayer(unit),
        }
        if not context.isPlayer then
            local guid = UnitGUID(unit)
            if guid and not issecretvalue(guid) then
                local unitType, _, _, _, _, npcIDStr = strsplit("-", guid)
                if (unitType == "Creature" or unitType == "Vehicle") and npcIDStr then
                    context.npcID = tonumber(npcIDStr)
                end
            end
        end
        self:ProcessProviders(tooltip, context)
    end
    isProcessingTooltip = false
end

function TooltipEngine:OnTooltipSetItem(tooltip, link)
    if not self:IsEnabled() then return end
    if isProcessingTooltip then return end

    isProcessingTooltip = true
    local itemID, actualLink
    if link then
        itemID = tonumber(link:match("item:(%d+)"))
        actualLink = link
    else
        local _, itemLink = tooltip:GetItem()
        if itemLink then
            itemID = tonumber(itemLink:match("item:(%d+)"))
            actualLink = itemLink
        end
    end

    if itemID then
        local context = {
            type = "item",
            itemID = itemID,
            itemLink = actualLink,
        }
        self:ProcessProviders(tooltip, context)
    end
    isProcessingTooltip = false
end

function TooltipEngine:HookAchievementUI()
    local engine = self

    local function hookAchievements()
        if not AchievementTemplateMixin or not AchievementTemplateMixin.OnEnter then return end
        hooksecurefunc(AchievementTemplateMixin, "OnEnter", function(achievementFrame)
            if not engine:IsEnabled() then return end
            if not engine:IsFeatureEnabled("technicalids") then return end
            if not achievementFrame.id then return end
            local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
            local tid = db and db.tooltips and db.tooltips.technicalids
            if not tid or tid.showAchievementID == false then return end
            GameTooltip:SetOwner(achievementFrame, "ANCHOR_NONE")
            GameTooltip:SetPoint("TOPLEFT", achievementFrame, "TOPRIGHT", 0, 0)
            local _gui = LibStub and LibStub("OneWoW_GUI-1.0", true)
            local iconTheme = (_gui and _gui:GetSetting("minimap.theme")) or "neutral"
            local addonIcon = CreateTextureMarkup("Interface\\AddOns\\OneWoW\\Media\\OneWoWMini-" .. iconTheme, 64, 64, 16, 16, 0, 1, 0, 1)
            GameTooltip:AddLine(addonIcon .. " OneWoW", TOOLTIP_CONFIG.headerColor[1], TOOLTIP_CONFIG.headerColor[2], TOOLTIP_CONFIG.headerColor[3])
            GameTooltip:AddLine(string.format("  |cFFFFDD00AchievementID|r |cFFFFFFFF%d|r", achievementFrame.id), 1, 1, 1)
            GameTooltip:Show()
        end)
        hooksecurefunc(AchievementTemplateMixin, "OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
        hookAchievements()
    else
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", function(_, event, addon)
            if addon == "Blizzard_AchievementUI" then
                hookAchievements()
                frame:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end
