local _, ns = ...
local FrameMoverModule = ns.ModuleRegistry:Current()
if not FrameMoverModule then return end

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
            if state.frame and not (OneWoW.Restriction.IsProtectedActionBlocked() and state.frame:IsProtected()) then
                state.frame:SetClampedToScreen(value)
            end
        end
    elseif toggleId == "enable_scaling" then
        FM:SetScalingEnabled(value)
    elseif toggleId == "show_modify_hud" and not value then
        local UI = ns.FrameMoverUI
        if UI and UI.HideModifyHud then
            UI:HideModifyHud()
        end
    end
end

function FrameMoverModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh)
    local UI = ns.FrameMoverUI
    if UI then
        return UI:Build(detailScrollChild, yOffset, isEnabled, registerRefresh)
    end
    return yOffset
end
