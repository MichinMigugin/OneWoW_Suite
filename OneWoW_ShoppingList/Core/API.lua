local _, ns = ...

-- Public, cross-addon read surface for the ShoppingList hub. ns stays private.
OneWoW_ShoppingList_API = {}

--- Toggle the Shopping List main window.
function OneWoW_ShoppingList_API.Toggle()
    if ns.MainWindow and ns.MainWindow.Toggle then
        ns.MainWindow:Toggle()
    end
end

--- Show the Shopping List main window.
function OneWoW_ShoppingList_API.Show()
    if ns.MainWindow and ns.MainWindow.Show then
        ns.MainWindow:Show()
    end
end

--- Hide the Shopping List main window.
function OneWoW_ShoppingList_API.Hide()
    if ns.MainWindow and ns.MainWindow.Hide then
        ns.MainWindow:Hide()
    end
end
