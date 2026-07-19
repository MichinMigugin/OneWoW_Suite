local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local PE = ns.PredicateEngine

local TooltipEngine = {}
ns.TooltipEngine = TooltipEngine

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

local function sortProviders()
    table.sort(sectionProviders, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
end

function TooltipEngine:RegisterProvider(provider)
    if not provider or not provider.id then
        error("TooltipEngine:RegisterProvider requires provider.id")
    end
    for i, existing in ipairs(sectionProviders) do
        if existing.id == provider.id then
            sectionProviders[i] = provider
            sortProviders()
            return
        end
    end
    table.insert(sectionProviders, provider)
    sortProviders()
end

function TooltipEngine:UnregisterProvider(id)
    if not id then return end
    for i = #sectionProviders, 1, -1 do
        if sectionProviders[i].id == id then
            tremove(sectionProviders, i)
            return
        end
    end
end

function TooltipEngine:Initialize()
    self:EnsureDefaults()
    self:HookTooltips()
    self:HookAchievementUI()
end

function TooltipEngine:EnsureDefaults()
end

function TooltipEngine:IsEnabled()
    return ns.SettingsFeatureRegistry:IsEnabled("tooltips", "general")
end

function TooltipEngine:IsFeatureEnabled(featureId)
    if not self:IsEnabled() then return false end
    return ns.SettingsFeatureRegistry:IsEnabled("tooltips", featureId)
end

-- Stand down while Blizzard still shows RETRIEVING_ITEM_INFO (or cache miss).
-- Decorating that placeholder (providers + AddLine) can leave merchant tooltips
-- stuck on Retrieving forever; TooltipDataProcessor re-fires once data lands.
-- Secret first-line text cannot be compared to RETRIEVING_ITEM_INFO; require a
-- cached itemID plus a multi-line tooltip so mid-retrieve stubs are skipped
-- without permanently blocking finished instanced-bag tooltips.
---@param tooltip GameTooltip
---@param itemID number|nil
---@return boolean
local function IsItemTooltipReady(tooltip, itemID)
    if not itemID or not C_Item.IsItemDataCachedByID(itemID) then
        return false
    end
    if not tooltip or not tooltip.GetName or not tooltip.NumLines then
        return false
    end
    local tipName = tooltip:GetName()
    local numLines = tooltip:NumLines()
    if not tipName or numLines < 1 then
        return false
    end
    local line = _G[tipName .. "TextLeft1"]
    local text = line and line:GetText()
    if not text then
        return false
    end
    if ns.Restriction.IsSecret(text) then
        return numLines >= 2
    end
    return text ~= RETRIEVING_ITEM_INFO
end

function TooltipEngine:HookTooltips()
    local HANDLED_TYPES = {
        Enum.TooltipDataType.Unit,
        Enum.TooltipDataType.Item,
        Enum.TooltipDataType.Spell,
        Enum.TooltipDataType.Mount,
        Enum.TooltipDataType.Currency,
        Enum.TooltipDataType.BattlePet,
        Enum.TooltipDataType.Achievement,
        Enum.TooltipDataType.Quest,
        Enum.TooltipDataType.Toy,
        Enum.TooltipDataType.UnitAura,
    }
    local optionalTypes = {
        "CompanionPet", "Totem", "QuestPartyProgress", "RecipeRankInfo",
        "EquipmentSet", "AzeriteEssence", "EnhancedConduit", "Outfit",
        "Macro", "Object",
    }
    for _, typeName in ipairs(optionalTypes) do
        if Enum.TooltipDataType[typeName] then
            table.insert(HANDLED_TYPES, Enum.TooltipDataType[typeName])
        end
    end
    local callback = function(tooltip, data)
        self:ProcessTooltipData(tooltip, data)
    end
    for _, dataType in ipairs(HANDLED_TYPES) do
        TooltipDataProcessor.AddTooltipPostCall(dataType, callback)
    end
end

function TooltipEngine:ProcessTooltipData(tooltip, data)
    if not self:IsEnabled() then return end
    if isProcessingTooltip then return end
    if not data or not data.type then return end
    if not Enum or not Enum.TooltipDataType then return end
    if ns.Restriction.IsSecret(data.type) then return end

    local tooltipType = tonumber(data.type)
    if not tooltipType then return end

    -- Always clear the re-entrancy flag: an error between set/clear used to
    -- permanently no-op every tooltip for the rest of the session.
    isProcessingTooltip = true
    xpcall(function()
        local context = self:BuildContext(tooltip, tooltipType, data)
        if context.type == "item" and not IsItemTooltipReady(tooltip, context.itemID) then
            return
        end
        if context.type then
            self:ProcessProviders(tooltip, context)
        end
    end, CallErrorHandler)
    isProcessingTooltip = false
end

function TooltipEngine:BuildContext(tooltip, tooltipType, data)
    local context = {
        tooltipType = tooltipType,
        data = data,
    }

    if tooltipType == Enum.TooltipDataType.Unit then
        if data.guid and not ns.Restriction.IsSecret(data.guid) then
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
        if data.id and not ns.Restriction.IsSecret(data.id) then
            context.itemID = data.id

            local itemLink
            if data.guid and not ns.Restriction.IsSecret(data.guid) then
                itemLink = C_Item.GetItemLinkByGUID(data.guid)
            end
            if not itemLink and data.hyperlink and not ns.Restriction.IsSecret(data.hyperlink)
                and type(data.hyperlink) == "string" then
                itemLink = data.hyperlink
            end
            if not itemLink and tooltip.GetItem then
                local _, linkFromTooltip = tooltip:GetItem()
                itemLink = linkFromTooltip
            end

            if itemLink and context.itemID then
                local parsed = PE:ParseItemLink(itemLink)
                local linkItemID = parsed and parsed.itemID
                if linkItemID and linkItemID ~= context.itemID then
                    itemLink = select(2, C_Item.GetItemInfo(context.itemID)) or nil
                end
            end

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
        context.type = "battlepet"
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
                local lines
                local label = "tooltip." .. (provider.id or provider.featureId or "?")
                ns.Lifecycle.SafeCall(label, function()
                    lines = provider.callback(tooltip, context)
                end)
                if lines and #lines > 0 then
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

    local _gui = OneWoW_GUI
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
            if text and not ns.Restriction.IsSecret(text) and string.find(text, "OneWoW") then
                return true
            end
        end
    end
    return false
end

function TooltipEngine:HookAchievementUI()
    local engine = self

    local function hookAchievements()
        if not AchievementTemplateMixin or not AchievementTemplateMixin.OnEnter then return end
        hooksecurefunc(AchievementTemplateMixin, "OnEnter", function(achievementFrame)
            if not engine:IsEnabled() then return end
            if not engine:IsFeatureEnabled("technicalids") then return end
            if not achievementFrame.id then return end
            if ns.SettingsFeatureRegistry:GetSetting("tooltips", "technicalids", "showAchievementID") == false then return end
            GameTooltip:SetOwner(achievementFrame, "ANCHOR_NONE")
            GameTooltip:SetPoint("TOPLEFT", achievementFrame, "TOPRIGHT", 0, 0)
            local _gui = OneWoW_GUI
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

    if C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
        hookAchievements()
    else
        ns:RegisterAddonLoadedWatcher("Blizzard_AchievementUI", function()
            hookAchievements()
        end)
    end
end

ns:RegisterCoreLoginHandler("TooltipEngine", function()
    TooltipEngine:Initialize()
end, "early")
