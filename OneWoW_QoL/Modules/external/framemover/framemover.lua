local addonName, ns = ...

local FrameMoverModule = {
    id             = "framemover",
    title          = "FRAMEMOVER_TITLE",
    category       = "INTERFACE",
    description    = "FRAMEMOVER_DESC",
    version        = "1.0",
    author         = "Ricky",
    contact        = "ricky@wow2.xyz",
    link           = "https://www.wow2.xyz",
    toggles        = {
        { id = "require_shift",  label = "FRAMEMOVER_TOGGLE_REQUIRE_SHIFT",  default = false, group = "FRAMEMOVER_GROUP_BEHAVIOR" },
        { id = "clamp_to_screen",label = "FRAMEMOVER_TOGGLE_CLAMP_SCREEN",   default = true,  group = "FRAMEMOVER_GROUP_BEHAVIOR" },
        { id = "enable_scaling", label = "FRAMEMOVER_TOGGLE_ENABLE_SCALING", default = true,  group = "FRAMEMOVER_GROUP_BEHAVIOR" },
        { id = "save_positions", label = "FRAMEMOVER_TOGGLE_SAVE_POSITIONS", default = true,  group = "FRAMEMOVER_GROUP_SAVING" },
        { id = "save_scales",    label = "FRAMEMOVER_TOGGLE_SAVE_SCALES",    default = true,  group = "FRAMEMOVER_GROUP_SAVING" },
    },
    preview        = false,
    defaultEnabled = false,
}

function FrameMoverModule:OnEnable()
    local FM = ns.FrameMoverCore
    if FM then FM:Initialize() end
end

function FrameMoverModule:OnDisable()
    local FM = ns.FrameMoverCore
    if FM then FM:Shutdown() end
end

function FrameMoverModule:OnToggle(toggleId, value)
    local FM = ns.FrameMoverCore
    if not FM or not FM.active then return end

    if toggleId == "clamp_to_screen" then
        for _, state in pairs(FM.frameStates) do
            if state.frame and not (InCombatLockdown() and state.frame:IsProtected()) then
                state.frame:SetClampedToScreen(value)
            end
        end
    elseif toggleId == "enable_scaling" then
        FM:SetScalingEnabled(value)
    end
end

function FrameMoverModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh)
    local UI = ns.FrameMoverUI
    if UI then
        return UI:Build(detailScrollChild, yOffset, isEnabled, registerRefresh)
    end
    return yOffset
end

ns.FrameMoverModule = FrameMoverModule
