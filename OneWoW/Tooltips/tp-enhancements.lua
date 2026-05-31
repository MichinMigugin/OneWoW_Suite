local ADDON_NAME, OneWoW = ...

-- TooltipDataLineType.SellPrice == 11 (Mainline API docs). Fallback if Enum not ready at register time.
local LINE_TYPE_SELL_PRICE = (Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice) or 11

local function GetSettings()
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    if not db or not db.tooltips then return nil end
    return db.tooltips.enhancements
end

local function IsSettingEnabled(key)
    local settings = GetSettings()
    if not settings then return false end
    if settings[key] == nil then return false end
    return settings[key] == true
end

local BORDER_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}

local function ShouldSuppressBlizzardVendorSellLine()
    if not OneWoW.TooltipEngine or not OneWoW.TooltipEngine:IsEnabled() then return false end
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local enh = db and db.tooltips and db.tooltips.enhancements
    if enh and enh.removeBlizzardVendorValue == false then return false end
    return true
end

local function OnTooltipSellPriceLine(tooltip, lineData)
    if not tooltip or tooltip:IsForbidden() then return end
    if not ShouldSuppressBlizzardVendorSellLine() then return end
    if not lineData or lineData.type ~= LINE_TYPE_SELL_PRICE then return end
    -- Swallow default SellPrice handling (MoneyFrame). No replacement lines — Value feature adds vendor price in the OneWoW block.
    return true
end

function OneWoW.TooltipEnhancements_RegisterSellPriceSuppress()
    if OneWoW._sellPriceSuppressRegistered then return end
    if not (TooltipDataProcessor and TooltipDataProcessor.AddLinePreCall) then return end
    TooltipDataProcessor.AddLinePreCall(LINE_TYPE_SELL_PRICE, OnTooltipSellPriceLine)
    OneWoW._sellPriceSuppressRegistered = true
end

local enhancementsInitialized = false

local function InitEnhancements()
    if enhancementsInitialized then return end
    enhancementsInitialized = true

    if not OneWoW.TooltipEngine then return end

    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if not OneWoW.TooltipEngine:IsFeatureEnabled("enhancements") then return end
        if not IsSettingEnabled("anchorEnabled") then return end
        if tooltip and not tooltip:IsForbidden() then
            local settings = GetSettings()
            local anchor = settings and settings.anchorPosition or "ANCHOR_CURSOR_RIGHT"
            tooltip:SetOwner(parent or UIParent, anchor)
        end
    end)

    hooksecurefunc(GameTooltip, "Show", function(self)
        if not OneWoW.TooltipEngine:IsFeatureEnabled("enhancements") then return end
        if not self or self:IsForbidden() then return end
        local settings = GetSettings()
        if not settings then return end

        if settings.scaleEnabled and settings.tooltipScale then
            self:SetScale(settings.tooltipScale / 100)
        end

        if settings.hideInCombat and UnitAffectingCombat("player") then
            self:Hide()
            return
        end

        if GameTooltipStatusBarTexture then
            if settings.hideHealthbar then
                GameTooltipStatusBarTexture:SetTexture(nil)
            else
                GameTooltipStatusBarTexture:SetTexture(137014)
            end
        end

        if settings.borderOpacityEnabled and settings.borderOpacity and self.NineSlice then
            local alpha = settings.borderOpacity / 100
            for _, pieceName in ipairs(BORDER_PIECES) do
                local piece = self.NineSlice[pieceName]
                if piece then
                    piece:SetAlpha(alpha)
                end
            end
        end

        if settings.bgOpacityEnabled and settings.bgOpacity and self.NineSlice and self.NineSlice.Center then
            self.NineSlice.Center:SetAlpha(settings.bgOpacity / 100)
        end
    end)
end

local function IsPlayerHovered(tooltip)
    if not (tooltip and tooltip.GetUnit) then return false end
    local _, unit = tooltip:GetUnit()
    return unit and UnitIsPlayer(unit)
end

local function StripServerSuffix(nameText)
    if not nameText or nameText == "" then return nameText end
    return nameText:gsub("%-[^%-%s]+$", "")
end

local function EnhancementsUnitProvider(tooltip, context)
    if context.type ~= "unit" or not context.isPlayer then return nil end
    if not IsPlayerHovered(tooltip) then return nil end

    local settings = GetSettings()
    if not settings then return nil end

    local _, unit = tooltip:GetUnit()
    if not unit then return nil end

    if settings.hideServerName then
        local nameLine = _G["GameTooltipTextLeft1"]
        if nameLine then
            local text = nameLine:GetText()
            if text and text ~= "" then
                nameLine:SetText(StripServerSuffix(text))
            end
        end
    end

    if settings.hideTitles then
        local nameLine = _G["GameTooltipTextLeft1"]
        if nameLine then
            local name = UnitName(unit)
            if name and name ~= "" then
                if settings.hideServerName then
                    nameLine:SetText(name)
                else
                    local _, realm = UnitName(unit)
                    if realm and realm ~= "" then
                        nameLine:SetText(name .. "-" .. realm)
                    else
                        nameLine:SetText(name)
                    end
                end
            end
        end
    end

    if settings.removePvpTag then
        local tooltipName = tooltip:GetName()
        if tooltipName then
            for i = 2, tooltip:NumLines() do
                local leftLine = _G[tooltipName .. "TextLeft" .. i]
                if leftLine then
                    local text = leftLine:GetText()
                    if text then
                        if text == (PVP or "PvP") or text == FACTION_HORDE or text == FACTION_ALLIANCE then
                            leftLine:SetText("")
                            leftLine:Hide()
                            local rightLine = _G[tooltipName .. "TextRight" .. i]
                            if rightLine then
                                rightLine:SetText("")
                                rightLine:Hide()
                            end
                        end
                    end
                end
            end
        end
    end

    if settings.colorGuild or settings.colorParty or settings.colorFaction then
        if tooltip.NineSlice then
            local bgAlpha = 1
            if settings.bgOpacityEnabled and settings.bgOpacity then
                bgAlpha = settings.bgOpacity / 100
            end

            local guildName = GetGuildInfo(unit)
            local isInMyGuild = guildName and (GetGuildInfo("player") == guildName)

            local function applyColor(r, g, b)
                tooltip.NineSlice:SetCenterColor(r, g, b)
                if tooltip.NineSlice.Center then
                    tooltip.NineSlice.Center:SetAlpha(bgAlpha)
                end
            end

            if settings.colorParty and (UnitInParty(unit) or UnitInRaid(unit)) then
                local c = settings.partyColor or { r = 0.5, g = 0.2, b = 0.65 }
                applyColor(c.r, c.g, c.b)
            elseif settings.colorGuild and isInMyGuild then
                local c = settings.guildColor or { r = 0.2, g = 0.6, b = 0.6 }
                applyColor(c.r, c.g, c.b)
            elseif settings.colorFaction then
                local playerFaction = UnitFactionGroup("player")
                local unitFaction = UnitFactionGroup(unit)
                if unitFaction and playerFaction then
                    if unitFaction == playerFaction then
                        local c = settings.factionFriendlyColor or { r = 0.15, g = 0.15, b = 0.5 }
                        applyColor(c.r, c.g, c.b)
                    else
                        local c = settings.factionEnemyColor or { r = 0.5, g = 0.15, b = 0.12 }
                        applyColor(c.r, c.g, c.b)
                    end
                end
            end
        end
    end

    if UnitAffectingCombat("player") or InCombatLockdown() or IsInInstance() then return nil end

    local lines = {}

    if settings.classColorNames then
        local _, class = UnitClass(unit)
        if class then
            local color = RAID_CLASS_COLORS[class]
            if color then
                local nameLineFS = _G["GameTooltipTextLeft1"]
                if nameLineFS then
                    nameLineFS:SetText("|c" .. color.colorStr .. nameLineFS:GetText() .. "|r")
                end

                local guildName = GetGuildInfo(unit)
                if guildName then
                    local guildLineFS = _G["GameTooltipTextLeft2"]
                    if guildLineFS then
                        guildLineFS:SetText("|cFF9999FF" .. guildLineFS:GetText() .. "|r")
                    end
                    local classLineFS = _G["GameTooltipTextLeft4"]
                    if classLineFS then
                        classLineFS:SetText("|c" .. color.colorStr .. classLineFS:GetText() .. "|r")
                    end
                else
                    local classLineFS = _G["GameTooltipTextLeft3"]
                    if classLineFS then
                        classLineFS:SetText("|c" .. color.colorStr .. classLineFS:GetText() .. "|r")
                    end
                end
            end
        end
    end

    if settings.guildRank then
        local guildName, rank = GetGuildInfo("mouseover")
        if guildName and rank then
            local guildLineFS = _G["GameTooltipTextLeft2"]
            if guildLineFS then
                local currentText = guildLineFS:GetText()
                if currentText and not currentText:find(rank, 1, true) then
                    guildLineFS:SetText(currentText .. " - " .. rank)
                end
            end
        end
    end

    if settings.playerTarget then
        if not UnitIsUnit("player", unit) then
            local target = UnitName(unit .. "target")
            if target then
                local L = OneWoW.L
                table.insert(lines, {
                    type = "double",
                    left = "  |cFFFFDD00" .. (L["TIPS_ENHANCEMENTS_TARGET_LABEL"] or "Target") .. "|r",
                    right = "|cFFFFFFFF" .. target .. "|r",
                    lr = 1, lg = 1, lb = 1,
                    rr = 1, rg = 1, rb = 1,
                })
            end
        end
    end

    if settings.mythicScore then
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("mouseover")
        if summary and summary.currentSeasonScore then
            local score = summary.currentSeasonScore
            local color = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(score)
            local scoreText
            if color and color.r then
                scoreText = string.format("|cFF%02x%02x%02x%d|r", color.r * 255, color.g * 255, color.b * 255, score)
            else
                scoreText = string.format("|cFFFFFFFF%d|r", score)
            end
            local L = OneWoW.L
            table.insert(lines, {
                type = "double",
                left = "  |cFFFFDD00" .. (L["TIPS_ENHANCEMENTS_MPLUS_LABEL"] or "M+ Score") .. "|r",
                right = scoreText,
                lr = 1, lg = 1, lb = 1,
                rr = 1, rg = 1, rb = 1,
            })
        end
    end

    if #lines == 0 then return nil end
    return lines
end

C_Timer.After(2, function()
    if OneWoW.TooltipEngine then
        InitEnhancements()

        OneWoW.TooltipEngine:RegisterProvider({
            id = "enhancements",
            order = 5,
            featureId = "enhancements",
            tooltipTypes = {"unit"},
            callback = EnhancementsUnitProvider,
        })
    end
end)
