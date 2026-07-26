local _, ns = ...

-- Public, cross-addon read surface for the Bags hub. ns stays private.
OneWoW_Bags_API = {}

--- Register a callback invoked when Bags item buttons are painted.
---@param name string unique callback id
---@param callback fun(button: table, bagID: number, slotID: number)
function OneWoW_Bags_API.RegisterItemButtonCallback(name, callback)
    ns:RegisterItemButtonCallback(name, callback)
end

--- Remove a previously registered item-button callback.
---@param name string
function OneWoW_Bags_API.UnregisterItemButtonCallback(name)
    ns:UnregisterItemButtonCallback(name)
end

--- Repaint overlays on all visible inventory item buttons.
function OneWoW_Bags_API.FireCallbacksOnAllButtons()
    ns:FireCallbacksOnAllButtons()
end

--- Repaint overlays on all visible bank item buttons (gated by bank overlay toggle).
function OneWoW_Bags_API.FireCallbacksOnBankButtons()
    ns:FireCallbacksOnBankButtons()
end

--- Repaint overlays on all visible guild bank item buttons (gated by enableBankOverlays).
function OneWoW_Bags_API.FireCallbacksOnGuildBankButtons()
    ns:FireCallbacksOnGuildBankButtons()
end

--- True when Masque is loaded and enabled for OneWoW_Bags.
---@return boolean
function OneWoW_Bags_API.IsMasqueActive()
    return ns.Masque and ns.Masque:IsActive() == true
end

--- Optional profiler module for PredicateEngine integration.
---@return table|nil
function OneWoW_Bags_API.GetProfile()
    return ns.Profile
end

--- Live searchExpression for a custom search-mode category (display name).
--- Nil when missing, type-mode, pin-only, or builtin.
---@param name string|nil
---@return string|nil expression
---@return string|nil displayName
function OneWoW_Bags_API.GetCategorySearchExpression(name)
    return ns.CategoryRefs:FindSearchExpression(name)
end

--- Notify when custom category search rules may have changed.
---@param id string
---@param callback fun()
function OneWoW_Bags_API.RegisterCategoryRulesChanged(id, callback)
    ns.CategoryRefs:RegisterRulesChanged(id, callback)
end

---@param id string
function OneWoW_Bags_API.UnregisterCategoryRulesChanged(id)
    ns.CategoryRefs:UnregisterRulesChanged(id)
end

--- Toggle the main Bags window.
function OneWoW_Bags_API.Toggle()
    if ns.GUI and ns.GUI.Toggle then
        ns.GUI:Toggle()
    end
end

--- Show the main Bags window.
function OneWoW_Bags_API.Show()
    if ns.GUI and ns.GUI.Show then
        ns.GUI:Show()
    end
end

--- Hide the main Bags window.
function OneWoW_Bags_API.Hide()
    if ns.GUI and ns.GUI.Hide then
        ns.GUI:Hide()
    end
end

--- Open the Custom Category Manager, optionally selecting a custom category by id
--- (the `customCategoriesV2` key / SearchCatalog category entry id).
---@param catId string|nil
function OneWoW_Bags_API.OpenCategoryManager(catId)
    local ui = ns.CategoryManagerUI
    if not ui then return end
    if type(catId) == "string" and catId ~= "" then
        ui:ShowAndSelect(catId)
    else
        ui:Show()
    end
end
