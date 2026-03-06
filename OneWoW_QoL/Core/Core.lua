-- OneWoW_QoL Addon File
-- OneWoW_QoL/Core/Core.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.Core = {}
local Core = ns.Core

function Core:Initialize()
    self.initialized = true
    self:InitializeModules()
end

function Core:InitializeModules()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db or not addon.db.global then return end
    local allModules = ns.ModuleRegistry:GetAll()
    for _, module in ipairs(allModules) do
        if ns.ModuleRegistry:IsEnabled(module.id) and module.OnEnable then
            module:OnEnable()
        end
    end
end
