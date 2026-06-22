local _, ns = ...

-- Public, cross-addon read surface for the DirectDeposit hub. ns stays private.
OneWoW_DirectDeposit_API = {}

--- Toggle the Direct Deposit main window.
function OneWoW_DirectDeposit_API.Toggle()
    if ns.GUI and ns.GUI.Toggle then
        ns.GUI:Toggle()
    end
end

--- Show the Direct Deposit main window.
function OneWoW_DirectDeposit_API.Show()
    if ns.GUI and ns.GUI.Show then
        ns.GUI:Show()
    end
end

--- Hide the Direct Deposit main window.
function OneWoW_DirectDeposit_API.Hide()
    if ns.GUI and ns.GUI.Hide then
        ns.GUI:Hide()
    end
end

--- Run a manual gold/item deposit pass.
function OneWoW_DirectDeposit_API.ManualDeposit()
    if ns.DirectDeposit and ns.DirectDeposit.ManualDeposit then
        ns.DirectDeposit:ManualDeposit()
    end
end

--- Add or toggle the hovered item on the deposit list for the given bank type.
---@param bankType string "personal" | "warband" | "guild"
function OneWoW_DirectDeposit_API.AddHoveredItemToList(bankType)
    if ns.AddHoveredItemToList then
        ns:AddHoveredItemToList(bankType)
    end
end
