-- OneWoW_QoL Addon File
-- OneWoW_QoL/UI/t-toggles.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local CATEGORY_ORDER = {
    "GAMEPLAY", "INTERFACE", "NAMEPLATES", "COMBAT_TEXT",
    "CAMERA", "CHAT", "AUDIO", "GRAPHICS", "NETWORK",
}

local CVAR_DATA = {
    -- GAMEPLAY
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoLootDefault",               name = "TOGGLE_NAME_autoLootDefault",               desc = "TOGGLE_DESC_autoLootDefault" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoSelfCast",                  name = "TOGGLE_NAME_autoSelfCast",                  desc = "TOGGLE_DESC_autoSelfCast" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoDismount",                  name = "TOGGLE_NAME_autoDismount",                  desc = "TOGGLE_DESC_autoDismount" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoDismountFlying",            name = "TOGGLE_NAME_autoDismountFlying",            desc = "TOGGLE_DESC_autoDismountFlying" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoStand",                     name = "TOGGLE_NAME_autoStand",                     desc = "TOGGLE_DESC_autoStand" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoUnshift",                   name = "TOGGLE_NAME_autoUnshift",                   desc = "TOGGLE_DESC_autoUnshift" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "assistAttack",                  name = "TOGGLE_NAME_assistAttack",                  desc = "TOGGLE_DESC_assistAttack" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "ActionButtonUseKeyDown",        name = "TOGGLE_NAME_ActionButtonUseKeyDown",        desc = "TOGGLE_DESC_ActionButtonUseKeyDown" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "deselectOnClick",               name = "TOGGLE_NAME_deselectOnClick",               desc = "TOGGLE_DESC_deselectOnClick" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "stopAutoAttackOnTargetChange",  name = "TOGGLE_NAME_stopAutoAttackOnTargetChange",  desc = "TOGGLE_DESC_stopAutoAttackOnTargetChange" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "lootUnderMouse",                name = "TOGGLE_NAME_lootUnderMouse",                desc = "TOGGLE_DESC_lootUnderMouse" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "lootLeftmostBag",               name = "TOGGLE_NAME_lootLeftmostBag",               desc = "TOGGLE_DESC_lootLeftmostBag" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "interactOnLeftClick",           name = "TOGGLE_NAME_interactOnLeftClick",           desc = "TOGGLE_DESC_interactOnLeftClick" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autointeract",                  name = "TOGGLE_NAME_autointeract",                  desc = "TOGGLE_DESC_autointeract" },
    { cat = "GAMEPLAY", widget = "checkbox", cvar = "autoClearAFK",                  name = "TOGGLE_NAME_autoClearAFK",                  desc = "TOGGLE_DESC_autoClearAFK" },

    -- INTERFACE
    { cat = "INTERFACE", widget = "checkbox", cvar = "countdownForCooldowns",               name = "TOGGLE_NAME_countdownForCooldowns",               desc = "TOGGLE_DESC_countdownForCooldowns" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "displaySpellActivationOverlays",      name = "TOGGLE_NAME_displaySpellActivationOverlays",      desc = "TOGGLE_DESC_displaySpellActivationOverlays" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "alwaysShowActionBars",                name = "TOGGLE_NAME_alwaysShowActionBars",                desc = "TOGGLE_DESC_alwaysShowActionBars" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "lockActionBars",                      name = "TOGGLE_NAME_lockActionBars",                      desc = "TOGGLE_DESC_lockActionBars" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "bottomLeftActionBar",                 name = "TOGGLE_NAME_bottomLeftActionBar",                 desc = "TOGGLE_DESC_bottomLeftActionBar" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "bottomRightActionBar",                name = "TOGGLE_NAME_bottomRightActionBar",                desc = "TOGGLE_DESC_bottomRightActionBar" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "rightActionBar",                      name = "TOGGLE_NAME_rightActionBar",                      desc = "TOGGLE_DESC_rightActionBar" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "rightTwoActionBar",                   name = "TOGGLE_NAME_rightTwoActionBar",                   desc = "TOGGLE_DESC_rightTwoActionBar" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "displayFreeBagSlots",                 name = "TOGGLE_NAME_displayFreeBagSlots",                 desc = "TOGGLE_DESC_displayFreeBagSlots" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "buffDurations",                       name = "TOGGLE_NAME_buffDurations",                       desc = "TOGGLE_DESC_buffDurations" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "showTargetOfTarget",                  name = "TOGGLE_NAME_showTargetOfTarget",                  desc = "TOGGLE_DESC_showTargetOfTarget" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "showTargetCastbar",                   name = "TOGGLE_NAME_showTargetCastbar",                   desc = "TOGGLE_DESC_showTargetCastbar" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "fullSizeFocusFrame",                  name = "TOGGLE_NAME_fullSizeFocusFrame",                  desc = "TOGGLE_DESC_fullSizeFocusFrame" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "breakUpLargeNumbers",                 name = "TOGGLE_NAME_breakUpLargeNumbers",                 desc = "TOGGLE_DESC_breakUpLargeNumbers" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "alwaysCompareItems",                  name = "TOGGLE_NAME_alwaysCompareItems",                  desc = "TOGGLE_DESC_alwaysCompareItems" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "missingTransmogSourceInItemTooltips", name = "TOGGLE_NAME_missingTransmogSourceInItemTooltips", desc = "TOGGLE_DESC_missingTransmogSourceInItemTooltips" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "autoQuestWatch",                      name = "TOGGLE_NAME_autoQuestWatch",                      desc = "TOGGLE_DESC_autoQuestWatch" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "autoQuestProgress",                   name = "TOGGLE_NAME_autoQuestProgress",                   desc = "TOGGLE_DESC_autoQuestProgress" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "mapFade",                             name = "TOGGLE_NAME_mapFade",                             desc = "TOGGLE_DESC_mapFade" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "rotateMinimap",                       name = "TOGGLE_NAME_rotateMinimap",                       desc = "TOGGLE_DESC_rotateMinimap" },
    { cat = "INTERFACE", widget = "checkbox", cvar = "useUiScale",                          name = "TOGGLE_NAME_useUiScale",                          desc = "TOGGLE_DESC_useUiScale" },
    { cat = "INTERFACE", widget = "slider",   cvar = "uiScale",    name = "TOGGLE_NAME_uiScale",    desc = "TOGGLE_DESC_uiScale",    min = 0.64, max = 1.0,  step = 0.01 },

    -- NAMEPLATES
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowEnemies",              name = "TOGGLE_NAME_nameplateShowEnemies",              desc = "TOGGLE_DESC_nameplateShowEnemies" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowFriends",              name = "TOGGLE_NAME_nameplateShowFriends",              desc = "TOGGLE_DESC_nameplateShowFriends" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplateShowSelf",                 name = "TOGGLE_NAME_nameplateShowSelf",                 desc = "TOGGLE_DESC_nameplateShowSelf" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplatePersonalShowAlways",       name = "TOGGLE_NAME_nameplatePersonalShowAlways",       desc = "TOGGLE_DESC_nameplatePersonalShowAlways" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "nameplatePersonalShowInCombat",     name = "TOGGLE_NAME_nameplatePersonalShowInCombat",     desc = "TOGGLE_DESC_nameplatePersonalShowInCombat" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "ShowClassColorInNameplate",         name = "TOGGLE_NAME_ShowClassColorInNameplate",         desc = "TOGGLE_DESC_ShowClassColorInNameplate" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "ShowClassColorInFriendlyNameplate", name = "TOGGLE_NAME_ShowClassColorInFriendlyNameplate", desc = "TOGGLE_DESC_ShowClassColorInFriendlyNameplate" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "ShowNamePlateLoseAggroFlash",       name = "TOGGLE_NAME_ShowNamePlateLoseAggroFlash",       desc = "TOGGLE_DESC_ShowNamePlateLoseAggroFlash" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "namePlateEnemyClickThrough",        name = "TOGGLE_NAME_namePlateEnemyClickThrough",        desc = "TOGGLE_DESC_namePlateEnemyClickThrough" },
    { cat = "NAMEPLATES", widget = "checkbox", cvar = "namePlateFriendlyClickThrough",     name = "TOGGLE_NAME_namePlateFriendlyClickThrough",     desc = "TOGGLE_DESC_namePlateFriendlyClickThrough" },
    { cat = "NAMEPLATES", widget = "slider", cvar = "nameplateMaxDistance",  name = "TOGGLE_NAME_nameplateMaxDistance",  desc = "TOGGLE_DESC_nameplateMaxDistance",  min = 10,  max = 60,  step = 1    },
    { cat = "NAMEPLATES", widget = "slider", cvar = "nameplateGlobalScale",  name = "TOGGLE_NAME_nameplateGlobalScale",  desc = "TOGGLE_DESC_nameplateGlobalScale",  min = 0.5, max = 2.0, step = 0.05 },
    { cat = "NAMEPLATES", widget = "slider", cvar = "namePlateEnemySize",    name = "TOGGLE_NAME_namePlateEnemySize",    desc = "TOGGLE_DESC_namePlateEnemySize",    min = 0.5, max = 2.0, step = 0.05 },
    { cat = "NAMEPLATES", widget = "slider", cvar = "namePlateFriendlySize", name = "TOGGLE_NAME_namePlateFriendlySize", desc = "TOGGLE_DESC_namePlateFriendlySize", min = 0.5, max = 2.0, step = 0.05 },

    -- COMBAT_TEXT
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "enableFloatingCombatText",         name = "TOGGLE_NAME_enableFloatingCombatText",         desc = "TOGGLE_DESC_enableFloatingCombatText" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "enableCombatText",                 name = "TOGGLE_NAME_enableCombatText",                 desc = "TOGGLE_DESC_enableCombatText" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "fctCombatState",                   name = "TOGGLE_NAME_fctCombatState",                   desc = "TOGGLE_DESC_fctCombatState" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatDamage",   name = "TOGGLE_NAME_floatingCombatTextCombatDamage",   desc = "TOGGLE_DESC_floatingCombatTextCombatDamage" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatHealing",  name = "TOGGLE_NAME_floatingCombatTextCombatHealing",  desc = "TOGGLE_DESC_floatingCombatTextCombatHealing" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextCombatState",    name = "TOGGLE_NAME_floatingCombatTextCombatState",    desc = "TOGGLE_DESC_floatingCombatTextCombatState" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextAuras",          name = "TOGGLE_NAME_floatingCombatTextAuras",          desc = "TOGGLE_DESC_floatingCombatTextAuras" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextDodgeParryMiss", name = "TOGGLE_NAME_floatingCombatTextDodgeParryMiss", desc = "TOGGLE_DESC_floatingCombatTextDodgeParryMiss" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextHonorGains",     name = "TOGGLE_NAME_floatingCombatTextHonorGains",     desc = "TOGGLE_DESC_floatingCombatTextHonorGains" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextRepChanges",     name = "TOGGLE_NAME_floatingCombatTextRepChanges",     desc = "TOGGLE_DESC_floatingCombatTextRepChanges" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextEnergyGains",    name = "TOGGLE_NAME_floatingCombatTextEnergyGains",    desc = "TOGGLE_DESC_floatingCombatTextEnergyGains" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextComboPoints",    name = "TOGGLE_NAME_floatingCombatTextComboPoints",    desc = "TOGGLE_DESC_floatingCombatTextComboPoints" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextReactives",      name = "TOGGLE_NAME_floatingCombatTextReactives",      desc = "TOGGLE_DESC_floatingCombatTextReactives" },
    { cat = "COMBAT_TEXT", widget = "checkbox", cvar = "floatingCombatTextPetMeleeDamage", name = "TOGGLE_NAME_floatingCombatTextPetMeleeDamage", desc = "TOGGLE_DESC_floatingCombatTextPetMeleeDamage" },

    -- CAMERA
    { cat = "CAMERA", widget = "checkbox", cvar = "cameraBobbing",        name = "TOGGLE_NAME_cameraBobbing",        desc = "TOGGLE_DESC_cameraBobbing" },
    { cat = "CAMERA", widget = "checkbox", cvar = "cameraWaterCollision", name = "TOGGLE_NAME_cameraWaterCollision", desc = "TOGGLE_DESC_cameraWaterCollision" },
    { cat = "CAMERA", widget = "checkbox", cvar = "flightAngleLookAhead", name = "TOGGLE_NAME_flightAngleLookAhead", desc = "TOGGLE_DESC_flightAngleLookAhead" },
    { cat = "CAMERA", widget = "checkbox", cvar = "cameraDynamicPitch",   name = "TOGGLE_NAME_cameraDynamicPitch",   desc = "TOGGLE_DESC_cameraDynamicPitch" },
    { cat = "CAMERA", widget = "slider", cvar = "cameraDistanceMaxZoomFactor", name = "TOGGLE_NAME_cameraDistanceMaxZoomFactor", desc = "TOGGLE_DESC_cameraDistanceMaxZoomFactor", min = 1.0,   max = 2.6,   step = 0.1   },
    { cat = "CAMERA", widget = "slider", cvar = "cameraYawMoveSpeed",          name = "TOGGLE_NAME_cameraYawMoveSpeed",          desc = "TOGGLE_DESC_cameraYawMoveSpeed",          min = 0.005, max = 0.025, step = 0.001 },
    { cat = "CAMERA", widget = "slider", cvar = "cameraPitchMoveSpeed",        name = "TOGGLE_NAME_cameraPitchMoveSpeed",        desc = "TOGGLE_DESC_cameraPitchMoveSpeed",        min = 0.005, max = 0.025, step = 0.001 },
    { cat = "CAMERA", widget = "slider", cvar = "cameraZoomSpeed",             name = "TOGGLE_NAME_cameraZoomSpeed",             desc = "TOGGLE_DESC_cameraZoomSpeed",             min = 1,     max = 50,    step = 1     },

    -- CHAT
    { cat = "CHAT", widget = "checkbox", cvar = "chatBubbles",           name = "TOGGLE_NAME_chatBubbles",           desc = "TOGGLE_DESC_chatBubbles" },
    { cat = "CHAT", widget = "checkbox", cvar = "chatBubblesParty",      name = "TOGGLE_NAME_chatBubblesParty",      desc = "TOGGLE_DESC_chatBubblesParty" },
    { cat = "CHAT", widget = "checkbox", cvar = "colorChatNamesByClass", name = "TOGGLE_NAME_colorChatNamesByClass", desc = "TOGGLE_DESC_colorChatNamesByClass" },
    { cat = "CHAT", widget = "checkbox", cvar = "blockTrades",           name = "TOGGLE_NAME_blockTrades",           desc = "TOGGLE_DESC_blockTrades" },
    { cat = "CHAT", widget = "checkbox", cvar = "blockChannelInvites",   name = "TOGGLE_NAME_blockChannelInvites",   desc = "TOGGLE_DESC_blockChannelInvites" },
    { cat = "CHAT", widget = "checkbox", cvar = "guildMemberNotify",     name = "TOGGLE_NAME_guildMemberNotify",     desc = "TOGGLE_DESC_guildMemberNotify" },
    { cat = "CHAT", widget = "checkbox", cvar = "removeChatDelay",       name = "TOGGLE_NAME_removeChatDelay",       desc = "TOGGLE_DESC_removeChatDelay" },
    { cat = "CHAT", widget = "checkbox", cvar = "chatMouseScroll",       name = "TOGGLE_NAME_chatMouseScroll",       desc = "TOGGLE_DESC_chatMouseScroll" },
    { cat = "CHAT", widget = "checkbox", cvar = "profanityFilter",       name = "TOGGLE_NAME_profanityFilter",       desc = "TOGGLE_DESC_profanityFilter" },
    { cat = "CHAT", widget = "dropdown", cvar = "chatStyle",
        name = "TOGGLE_NAME_chatStyle", desc = "TOGGLE_DESC_chatStyle",
        options   = { "classic", "im" },
        optLabels = { "TOGGLE_OPT_chatStyle_classic", "TOGGLE_OPT_chatStyle_im" } },

    -- AUDIO
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableAllSound",  name = "TOGGLE_NAME_Sound_EnableAllSound",  desc = "TOGGLE_DESC_Sound_EnableAllSound" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableMusic",     name = "TOGGLE_NAME_Sound_EnableMusic",     desc = "TOGGLE_DESC_Sound_EnableMusic" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableSFX",       name = "TOGGLE_NAME_Sound_EnableSFX",       desc = "TOGGLE_DESC_Sound_EnableSFX" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableDialog",    name = "TOGGLE_NAME_Sound_EnableDialog",    desc = "TOGGLE_DESC_Sound_EnableDialog" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnableAmbience",  name = "TOGGLE_NAME_Sound_EnableAmbience",  desc = "TOGGLE_DESC_Sound_EnableAmbience" },
    { cat = "AUDIO", widget = "checkbox", cvar = "Sound_EnablePetSounds", name = "TOGGLE_NAME_Sound_EnablePetSounds", desc = "TOGGLE_DESC_Sound_EnablePetSounds" },
    { cat = "AUDIO", widget = "checkbox", cvar = "FootstepSounds",        name = "TOGGLE_NAME_FootstepSounds",        desc = "TOGGLE_DESC_FootstepSounds" },
    { cat = "AUDIO", widget = "slider", cvar = "Sound_MasterVolume", name = "TOGGLE_NAME_Sound_MasterVolume", desc = "TOGGLE_DESC_Sound_MasterVolume", min = 0.0, max = 1.0, step = 0.05 },
    { cat = "AUDIO", widget = "slider", cvar = "Sound_MusicVolume",  name = "TOGGLE_NAME_Sound_MusicVolume",  desc = "TOGGLE_DESC_Sound_MusicVolume",  min = 0.0, max = 1.0, step = 0.05 },
    { cat = "AUDIO", widget = "slider", cvar = "Sound_SFXVolume",    name = "TOGGLE_NAME_Sound_SFXVolume",    desc = "TOGGLE_DESC_Sound_SFXVolume",    min = 0.0, max = 1.0, step = 0.05 },

    -- GRAPHICS
    { cat = "GRAPHICS", widget = "checkbox", cvar = "ffxDeath",                    name = "TOGGLE_NAME_ffxDeath",                    desc = "TOGGLE_DESC_ffxDeath" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "ffxGlow",                     name = "TOGGLE_NAME_ffxGlow",                     desc = "TOGGLE_DESC_ffxGlow" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "ffxNether",                   name = "TOGGLE_NAME_ffxNether",                   desc = "TOGGLE_DESC_ffxNether" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "emphasizeMySpellEffects",     name = "TOGGLE_NAME_emphasizeMySpellEffects",     desc = "TOGGLE_DESC_emphasizeMySpellEffects" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "doNotFlashLowHealthWarning",  name = "TOGGLE_NAME_doNotFlashLowHealthWarning",  desc = "TOGGLE_DESC_doNotFlashLowHealthWarning" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "hdPlayerModels",              name = "TOGGLE_NAME_hdPlayerModels",              desc = "TOGGLE_DESC_hdPlayerModels" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "findYourselfAnywhere",        name = "TOGGLE_NAME_findYourselfAnywhere",        desc = "TOGGLE_DESC_findYourselfAnywhere" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "gxVSync",                     name = "TOGGLE_NAME_gxVSync",                     desc = "TOGGLE_DESC_gxVSync" },
    { cat = "GRAPHICS", widget = "checkbox", cvar = "gxTripleBuffer",              name = "TOGGLE_NAME_gxTripleBuffer",              desc = "TOGGLE_DESC_gxTripleBuffer" },
    { cat = "GRAPHICS", widget = "slider", cvar = "particleDensity",   name = "TOGGLE_NAME_particleDensity",   desc = "TOGGLE_DESC_particleDensity",   min = 0,   max = 100, step = 5    },
    { cat = "GRAPHICS", widget = "slider", cvar = "maxFPS",            name = "TOGGLE_NAME_maxFPS",            desc = "TOGGLE_DESC_maxFPS",            min = 0,   max = 200, step = 10   },
    { cat = "GRAPHICS", widget = "slider", cvar = "maxFPSBk",          name = "TOGGLE_NAME_maxFPSBk",          desc = "TOGGLE_DESC_maxFPSBk",          min = 0,   max = 60,  step = 5    },
    { cat = "GRAPHICS", widget = "slider", cvar = "gxMaxFrameLatency", name = "TOGGLE_NAME_gxMaxFrameLatency", desc = "TOGGLE_DESC_gxMaxFrameLatency", min = 1,   max = 6,   step = 1    },
    { cat = "GRAPHICS", widget = "slider", cvar = "RenderScale",       name = "TOGGLE_NAME_RenderScale",       desc = "TOGGLE_DESC_RenderScale",       min = 0.5, max = 2.0, step = 0.05 },
    { cat = "GRAPHICS", widget = "dropdown", cvar = "graphicsQuality",
        name = "TOGGLE_NAME_graphicsQuality", desc = "TOGGLE_DESC_graphicsQuality",
        options   = { "1","2","3","4","5","6","7","8","9","10" },
        optLabels = { "TOGGLE_OPT_graphicsQuality_1","TOGGLE_OPT_graphicsQuality_2","TOGGLE_OPT_graphicsQuality_3","TOGGLE_OPT_graphicsQuality_4","TOGGLE_OPT_graphicsQuality_5","TOGGLE_OPT_graphicsQuality_6","TOGGLE_OPT_graphicsQuality_7","TOGGLE_OPT_graphicsQuality_8","TOGGLE_OPT_graphicsQuality_9","TOGGLE_OPT_graphicsQuality_10" } },
    { cat = "GRAPHICS", widget = "dropdown", cvar = "ffxAntiAliasingMode",
        name = "TOGGLE_NAME_ffxAntiAliasingMode", desc = "TOGGLE_DESC_ffxAntiAliasingMode",
        options   = { "0","1","2","3" },
        optLabels = { "TOGGLE_OPT_ffxAntiAliasingMode_0","TOGGLE_OPT_ffxAntiAliasingMode_1","TOGGLE_OPT_ffxAntiAliasingMode_2","TOGGLE_OPT_ffxAntiAliasingMode_3" } },
    { cat = "GRAPHICS", widget = "dropdown", cvar = "colorblindMode",
        name = "TOGGLE_NAME_colorblindMode", desc = "TOGGLE_DESC_colorblindMode",
        options   = { "0","1","2","3" },
        optLabels = { "TOGGLE_OPT_colorblindMode_0","TOGGLE_OPT_colorblindMode_1","TOGGLE_OPT_colorblindMode_2","TOGGLE_OPT_colorblindMode_3" } },

    -- NETWORK
    { cat = "NETWORK", widget = "checkbox", cvar = "disableServerNagle",  name = "TOGGLE_NAME_disableServerNagle",  desc = "TOGGLE_DESC_disableServerNagle" },
    { cat = "NETWORK", widget = "checkbox", cvar = "gxFixLag",            name = "TOGGLE_NAME_gxFixLag",            desc = "TOGGLE_DESC_gxFixLag" },
    { cat = "NETWORK", widget = "checkbox", cvar = "reducedLagTolerance", name = "TOGGLE_NAME_reducedLagTolerance", desc = "TOGGLE_DESC_reducedLagTolerance" },
    { cat = "NETWORK", widget = "slider", cvar = "SpellQueueWindow", name = "TOGGLE_NAME_SpellQueueWindow", desc = "TOGGLE_DESC_SpellQueueWindow", min = 0, max = 400, step = 10 },
}

ns.GetCVarList = function() return CVAR_DATA end

local selectedEntry = nil
local selectedRow   = nil
local split_ref     = nil

local function FormatSliderVal(value, step)
    if not step or step >= 1 then
        return tostring(math.floor(value + 0.5))
    elseif step >= 0.01 then
        return string.format("%.2f", value)
    else
        return string.format("%.3f", value)
    end
end

local function GetRowDisplay(entry)
    local val = C_CVar.GetCVar(entry.cvar)
    if val == nil then return "N/A", nil end
    if entry.widget == "checkbox" then
        return nil, val == "1"
    elseif entry.widget == "slider" then
        local num = tonumber(val)
        if num then return FormatSliderVal(num, entry.step), nil end
        return val, nil
    elseif entry.widget == "dropdown" then
        if entry.options and entry.optLabels then
            for i, opt in ipairs(entry.options) do
                if val == tostring(opt) then
                    return L[entry.optLabels[i]] or entry.optLabels[i], nil
                end
            end
        end
        return val, nil
    end
    return val, nil
end

local function UpdateRowIndicator(row, entry)
    if not row then return end
    local displayText, isOn = GetRowDisplay(entry)
    if entry.widget == "checkbox" then
        if row.indicator then
            if isOn == true then
                row.indicator:SetVertexColor(0.35, 0.70, 0.35, 1.0)
            else
                row.indicator:SetVertexColor(0.70, 0.30, 0.30, 1.0)
            end
        end
    else
        if row.indicatorText then
            row.indicatorText:SetText(displayText or "")
        end
    end
end

local function ClearDetailPanel(child)
    for _, c in ipairs({ child:GetChildren() }) do
        c:Hide()
        c:SetParent(nil)
    end
    for _, r in ipairs({ child:GetRegions() }) do
        r:Hide()
    end
end

local function ApplyBtnHover(btn)
    if btn.isActive then
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end
end

local function ApplyBtnNormal(btn)
    if btn.isActive then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

local function ShowToggleDetail(split, entry)
    local child = split.detailScrollChild
    local fw = split.detailScrollFrame:GetWidth()
    if fw > 0 then child:SetWidth(fw) end
    ClearDetailPanel(child)

    local cw   = child:GetWidth() - 24
    local yOfs = -10

    local nameLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameLabel:SetPoint("TOPLEFT",  child, "TOPLEFT",  12, yOfs)
    nameLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", -12, yOfs)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetText(L[entry.name] or entry.name)
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOfs = yOfs - nameLabel:GetStringHeight() - 6

    local cvarLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cvarLabel:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOfs)
    cvarLabel:SetText(L["TOGGLES_CVAR_LABEL"] .. " " .. entry.cvar)
    cvarLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOfs = yOfs - cvarLabel:GetStringHeight() - 10

    local div1 = child:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT",  child, "TOPLEFT",  12, yOfs)
    div1:SetPoint("TOPRIGHT", child, "TOPRIGHT", -12, yOfs)
    div1:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOfs = yOfs - 10

    local descText = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descText:SetPoint("TOPLEFT",  child, "TOPLEFT",  12, yOfs)
    descText:SetPoint("TOPRIGHT", child, "TOPRIGHT", -12, yOfs)
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    descText:SetSpacing(3)
    descText:SetText(L[entry.desc] or entry.desc)
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOfs = yOfs - descText:GetStringHeight() - 12

    local div2 = child:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT",  child, "TOPLEFT",  12, yOfs)
    div2:SetPoint("TOPRIGHT", child, "TOPRIGHT", -12, yOfs)
    div2:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOfs = yOfs - 14

    local curVal = C_CVar.GetCVar(entry.cvar)

    if entry.widget == "checkbox" then
        local isOn = (curVal == "1")

        local onBtn  = OneWoW_GUI:CreateButton(nil, child, L["TOGGLES_ON"],  64, 28)
        local offBtn = OneWoW_GUI:CreateButton(nil, child, L["TOGGLES_OFF"], 64, 28)
        onBtn:SetPoint( "TOPLEFT", child, "TOPLEFT", 12, yOfs)
        offBtn:SetPoint("LEFT",    onBtn, "RIGHT",   6, 0)

        local statusLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusLabel:SetPoint("LEFT", offBtn, "RIGHT", 12, 0)

        local capturedEntry = entry

        local function RefreshCheckbox(val)
            if val == "1" then
                onBtn.isActive  = true
                offBtn.isActive = false
                onBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                onBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                onBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                offBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                offBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                offBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                statusLabel:SetText(L["TOGGLES_ON"])
                statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                offBtn.isActive = true
                onBtn.isActive  = false
                offBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                offBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                offBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                onBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                onBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                onBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                statusLabel:SetText(L["TOGGLES_OFF"])
                statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
        end

        RefreshCheckbox(curVal)

        onBtn:HookScript("OnEnter",   function(s) ApplyBtnHover(s)  end)
        onBtn:HookScript("OnLeave",   function(s) ApplyBtnNormal(s) end)
        onBtn:HookScript("OnMouseUp", function(s) ApplyBtnNormal(s) end)
        offBtn:HookScript("OnEnter",   function(s) ApplyBtnHover(s)  end)
        offBtn:HookScript("OnLeave",   function(s) ApplyBtnNormal(s) end)
        offBtn:HookScript("OnMouseUp", function(s) ApplyBtnNormal(s) end)

        onBtn:SetScript("OnClick", function()
            C_CVar.SetCVar(capturedEntry.cvar, "1")
            RefreshCheckbox("1")
            UpdateRowIndicator(selectedRow, capturedEntry)
        end)
        offBtn:SetScript("OnClick", function()
            C_CVar.SetCVar(capturedEntry.cvar, "0")
            RefreshCheckbox("0")
            UpdateRowIndicator(selectedRow, capturedEntry)
        end)

        yOfs = yOfs - 28 - 8

    elseif entry.widget == "slider" then
        local numVal = tonumber(curVal) or entry.min
        numVal = math.max(entry.min, math.min(entry.max, numVal))

        local valLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        valLabel:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOfs)
        valLabel:SetText(L["TOGGLES_VALUE_LABEL"] .. " " .. FormatSliderVal(numVal, entry.step))
        valLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        yOfs = yOfs - valLabel:GetStringHeight() - 8

        local slider = CreateFrame("Slider", nil, child)
        slider:SetSize(cw, 18)
        slider:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOfs)
        slider:SetMinMaxValues(entry.min, entry.max)
        slider:SetValue(numVal)
        if entry.step then
            slider:SetValueStep(entry.step)
            slider:SetObeyStepOnDrag(true)
        end
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button")

        local trackBg = slider:CreateTexture(nil, "BACKGROUND")
        trackBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        trackBg:SetVertexColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        trackBg:SetPoint("TOPLEFT",     slider, "TOPLEFT",     8, -6)
        trackBg:SetPoint("BOTTOMRIGHT", slider, "BOTTOMRIGHT", -8, 6)

        local capturedEntry = entry
        slider:SetScript("OnValueChanged", function(self, value)
            local fmt = FormatSliderVal(value, capturedEntry.step)
            valLabel:SetText(L["TOGGLES_VALUE_LABEL"] .. " " .. fmt)
            C_CVar.SetCVar(capturedEntry.cvar, fmt)
            UpdateRowIndicator(selectedRow, capturedEntry)
        end)

        yOfs = yOfs - 18 - 6

        local minLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        minLabel:SetPoint("TOPLEFT", child, "TOPLEFT", 12, yOfs)
        minLabel:SetText(FormatSliderVal(entry.min, entry.step))
        minLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local maxLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        maxLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", -12, yOfs)
        maxLabel:SetText(FormatSliderVal(entry.max, entry.step))
        maxLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        yOfs = yOfs - minLabel:GetStringHeight() - 8

    elseif entry.widget == "dropdown" then
        local n      = #entry.options
        local gap    = 4
        local avail  = cw
        local bw     = math.max(30, math.floor((avail - gap * (n - 1)) / n))
        local optBtns = {}
        local xPos    = 12
        local rowY    = yOfs

        for i, opt in ipairs(entry.options) do
            local lbl = L[entry.optLabels[i]] or entry.optLabels[i]
            local btn = OneWoW_GUI:CreateButton(nil, child, lbl, bw, 26)
            btn:SetPoint("TOPLEFT", child, "TOPLEFT", xPos, rowY)
            btn.optValue = tostring(opt)
            btn.isActive = (tostring(opt) == tostring(curVal))
            if btn.isActive then
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
            table.insert(optBtns, btn)

            xPos = xPos + bw + gap
            if i < n and (xPos + bw) > (child:GetWidth() - 12) then
                xPos = 12
                rowY = rowY - 30
            end
        end

        yOfs = rowY - 26 - 10

        local capturedEntry = entry
        for _, btn in ipairs(optBtns) do
            btn:HookScript("OnEnter",   function(s) ApplyBtnHover(s)  end)
            btn:HookScript("OnLeave",   function(s) ApplyBtnNormal(s) end)
            btn:HookScript("OnMouseUp", function(s) ApplyBtnNormal(s) end)
            btn:SetScript("OnClick", function(self)
                C_CVar.SetCVar(capturedEntry.cvar, self.optValue)
                for _, ob in ipairs(optBtns) do
                    ob.isActive = (ob.optValue == self.optValue)
                    ApplyBtnNormal(ob)
                end
                UpdateRowIndicator(selectedRow, capturedEntry)
            end)
        end
    end

    child:SetHeight(math.abs(yOfs) + 20)
    split.UpdateDetailThumb()
end

local function BuildTogglesList(split, filterText)
    local child = split.listScrollChild
    for _, c in ipairs({ child:GetChildren() }) do c:Hide(); c:SetParent(nil) end
    for _, r in ipairs({ child:GetRegions() }) do r:Hide() end
    selectedRow   = nil
    selectedEntry = nil

    local filter    = (filterText and #filterText > 0) and filterText:lower() or nil
    local shownCount = 0

    local yOfs = -5
    local rowH = 30

    for _, cat in ipairs(CATEGORY_ORDER) do
        local catEntries = {}
        for _, entry in ipairs(CVAR_DATA) do
            if entry.cat == cat then
                if not filter or (L[entry.name] or entry.name):lower():find(filter, 1, true) then
                    table.insert(catEntries, entry)
                end
            end
        end

        if #catEntries > 0 then
            local catLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            catLabel:SetPoint("TOPLEFT",  child, "TOPLEFT",  8, yOfs)
            catLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOfs)
            catLabel:SetJustifyH("LEFT")
            catLabel:SetText(L["TOGGLE_CAT_" .. cat] or cat)
            catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            yOfs = yOfs - catLabel:GetStringHeight() - 4

            for _, entry in ipairs(catEntries) do
                local capturedEntry = entry
                local row = CreateFrame("Button", nil, child, "BackdropTemplate")
                row:SetPoint("TOPLEFT",  child, "TOPLEFT",  4, yOfs)
                row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, yOfs)
                row:SetHeight(rowH)
                row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

                if entry.widget == "checkbox" then
                    local dot = row:CreateTexture(nil, "OVERLAY")
                    dot:SetSize(8, 8)
                    dot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                    dot:SetTexture("Interface\\Buttons\\WHITE8x8")
                    row.indicator = dot

                    local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    rowLabel:SetPoint("LEFT",  row, "LEFT",  8,   0)
                    rowLabel:SetPoint("RIGHT", row, "RIGHT", -24, 0)
                    rowLabel:SetJustifyH("LEFT")
                    rowLabel:SetText(L[entry.name] or entry.name)
                    rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    row.rowLabel = rowLabel
                else
                    local valText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    valText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                    valText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    valText:SetJustifyH("RIGHT")
                    row.indicatorText = valText

                    local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    rowLabel:SetPoint("LEFT",  row, "LEFT",    8, 0)
                    rowLabel:SetPoint("RIGHT", valText, "LEFT", -4, 0)
                    rowLabel:SetJustifyH("LEFT")
                    rowLabel:SetText(L[entry.name] or entry.name)
                    rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    row.rowLabel = rowLabel
                end

                UpdateRowIndicator(row, entry)

                shownCount = shownCount + 1

                row:SetScript("OnClick", function(self)
                    if selectedRow and selectedRow ~= self then
                        selectedRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                        selectedRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                        if selectedRow.rowLabel then
                            selectedRow.rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                        end
                    end
                    selectedRow   = self
                    selectedEntry = capturedEntry
                    ShowToggleDetail(split, capturedEntry)
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                    self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                    if self.rowLabel then
                        self.rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                    end
                    if split.rightStatusText then
                        local curVal = C_CVar.GetCVar(capturedEntry.cvar)
                        local display = curVal or "?"
                        if capturedEntry.widget == "dropdown" and capturedEntry.options then
                            for i, opt in ipairs(capturedEntry.options) do
                                if curVal == tostring(opt) then
                                    display = L[capturedEntry.optLabels[i]] or capturedEntry.optLabels[i]
                                    break
                                end
                            end
                        end
                        split.rightStatusText:SetText((L[capturedEntry.name] or capturedEntry.name) .. ": " .. display)
                    end
                end)
                row:SetScript("OnEnter", function(self)
                    if selectedEntry ~= capturedEntry then
                        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                        if self.rowLabel then self.rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
                    end
                end)
                row:SetScript("OnLeave", function(self)
                    if selectedEntry ~= capturedEntry then
                        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                        if self.rowLabel then self.rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
                    end
                end)

                yOfs = yOfs - rowH - 3
            end

            yOfs = yOfs - 8
        end
    end

    child:SetHeight(math.abs(yOfs) + 10)
    split.UpdateListThumb()

    if split.leftStatusText then
        if filter then
            split.leftStatusText:SetText(string.format(L["TOGGLES_STATUS_FILTERED"], shownCount, #CVAR_DATA))
        else
            split.leftStatusText:SetText(string.format(L["TOGGLES_STATUS_ALL"], shownCount))
        end
    end
end

function ns.UI.CreateTogglesTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, { showSearch = true })
    split_ref = split

    split.listTitle:SetText(L["TOGGLES_LIST_TITLE"])
    split.detailTitle:SetText(L["TOGGLES_DETAIL_TITLE"])

    if split.searchBox then
        split.searchBox:SetText(L["SEARCH_HINT"])
        split.searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        split.searchBox:HookScript("OnEditFocusGained", function(self)
            if self:GetText() == L["SEARCH_HINT"] then
                self:SetText("")
                self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)
        split.searchBox:HookScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then
                self:SetText(L["SEARCH_HINT"])
                self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end)
        split.searchBox:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            if text == L["SEARCH_HINT"] then text = "" end
            BuildTogglesList(split, text)
            if split.rightStatusText and selectedEntry == nil then
                split.rightStatusText:SetText("")
            end
        end)
    end

    C_Timer.After(0.1, function()
        BuildTogglesList(split, "")

        local detailChild = split.detailScrollChild
        local placeholder = detailChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        placeholder:SetPoint("TOP", detailChild, "TOP", 0, -40)
        placeholder:SetWidth(detailChild:GetWidth() - 20)
        placeholder:SetText(L["TOGGLES_NO_SELECTION"])
        placeholder:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        placeholder:SetJustifyH("CENTER")
        detailChild:SetHeight(100)
        split.UpdateDetailThumb()
    end)
end
