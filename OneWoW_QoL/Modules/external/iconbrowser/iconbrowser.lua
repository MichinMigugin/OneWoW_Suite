local _, ns = ...
local M = ns.ModuleRegistry:Current()
if not M then return end

function M:OnEnable()
    M.Inject.Arm()
end

function M:OnDisable()
    M.Inject.Disarm()
end
