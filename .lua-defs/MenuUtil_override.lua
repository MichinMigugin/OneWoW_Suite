---@meta _

---@class MenuButtonFrame : Button
---@field fontString SimpleFontString

---@alias MenuButtonDescriptionInitializer fun(button: MenuButtonFrame, elementDescription: MenuButtonDescriptionProxy, menu: MenuProxy)

---@class MenuButtonDescriptionProxy : ElementMenuDescriptionProxy
local MenuButtonDescriptionProxy = {}

---@param initializer MenuButtonDescriptionInitializer
---@param index? number
function MenuButtonDescriptionProxy:AddInitializer(initializer, index) end

---@param initializer MenuButtonDescriptionInitializer
function MenuButtonDescriptionProxy:SetFinalInitializer(initializer) end

---@class SharedMenuDescriptionProxy
local SharedMenuDescriptionProxy = {}

---@param text string
---@param callback? MenuResponder
---@param data? any
---@return MenuButtonDescriptionProxy
function SharedMenuDescriptionProxy:CreateButton(text, callback, data) end

---@class RootMenuDescriptionProxy
local RootMenuDescriptionProxy = {}

---@param text string
---@param callback? MenuResponder
---@param data? any
---@return MenuButtonDescriptionProxy
function RootMenuDescriptionProxy:CreateButton(text, callback, data) end

---@param text string
---@param callback? MenuResponder
---@param data? any
---@return MenuButtonDescriptionProxy
function MenuUtil.CreateButton(text, callback, data) end
