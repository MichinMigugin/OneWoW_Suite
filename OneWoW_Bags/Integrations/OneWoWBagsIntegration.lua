local ADDON_NAME, OneWoW_Bags = ...

local db = OneWoW_Bags.db
local BagSet = OneWoW_Bags.BagSet
local BankSet = OneWoW_Bags.BankSet
local GuildBankSet = OneWoW_Bags.GuildBankSet

local pairs, pcall = pairs, pcall
local C_Timer = C_Timer

OneWoW_Bags.ItemButtonCallbacks = OneWoW_Bags.ItemButtonCallbacks or {}
local callbacks = OneWoW_Bags.ItemButtonCallbacks

function OneWoW_Bags:RegisterItemButtonCallback(name, callback)
	if not callback or type(callback) ~= "function" then
		error("InvalidCallback: callback must be a function")
		return
	end
	callbacks[name] = callback
end

function OneWoW_Bags:UnregisterItemButtonCallback(name)
	callbacks[name] = nil
end

function OneWoW_Bags:FireItemButtonCallback(button, bagID, slotID)
	local altShow = self.GUI and self.GUI:IsAltShowActive()
	if not altShow and db.global.stripJunkOverlays and button._owb_isJunk then
		local engine = _G.OneWoW and _G.OneWoW.OverlayEngine
		if engine then engine:CleanButton(button) end
		return
	end
	for name, callback in pairs(callbacks) do
		pcall(callback, button, bagID, slotID)
	end
end

function OneWoW_Bags:FireCallbacksOnAllButtons()
	if not BagSet.slots then return end

	for bagID, bagSlots in pairs(BagSet.slots) do
		for slotID, button in pairs(bagSlots) do
			if button and button:IsVisible() and button.owb_bagID and button.owb_slotID then
				self:FireItemButtonCallback(button, button.owb_bagID, button.owb_slotID)
			end
		end
	end
end

function OneWoW_Bags:FireCallbacksOnBankButtons()
	if not db.global.enableBankOverlays then return end

	if BankSet.slots then
		for bagID, bagSlots in pairs(BankSet.slots) do
			for slotID, button in pairs(bagSlots) do
				if button and button:IsVisible() and button.owb_bagID and button.owb_slotID then
					self:FireItemButtonCallback(button, button.owb_bagID, button.owb_slotID)
				end
			end
		end
	end

end

function OneWoW_Bags:ClearBankOverlays()
	local engine = _G.OneWoW and _G.OneWoW.OverlayEngine

	if BankSet.slots then
		for bagID, bagSlots in pairs(BankSet.slots) do
			for slotID, button in pairs(bagSlots) do
				if button then
					if engine then
						engine:CleanButton(button)
					end
				end
			end
		end
	end

	if GuildBankSet.slots then
		for tabID, tabSlots in pairs(GuildBankSet.slots) do
			for slotID, button in pairs(tabSlots) do
				if button then
					if engine then
						engine:CleanButton(button)
					end
				end
			end
		end
	end
end

local function HookGUIRefresh()
	local GUI = OneWoW_Bags.GUI
	if not GUI then return end

	local originalRefreshLayout = GUI.RefreshLayout
	function GUI:RefreshLayout()
		originalRefreshLayout(self)
		C_Timer.After(0.05, function()
			OneWoW_Bags:FireCallbacksOnAllButtons()
		end)
	end

	local originalBankRefresh = OneWoW_Bags.BankGUI.RefreshLayout
	function OneWoW_Bags.BankGUI:RefreshLayout()
		originalBankRefresh(self)
		if db.global.enableBankOverlays then
			C_Timer.After(0.05, function()
				OneWoW_Bags:FireCallbacksOnBankButtons()
			end)
		end
	end

	local originalGBRefresh = OneWoW_Bags.GuildBankGUI.RefreshLayout
	function OneWoW_Bags.GuildBankGUI:RefreshLayout()
		originalGBRefresh(self)
		if db.global.enableBankOverlays then
			C_Timer.After(0.05, function()
				OneWoW_Bags:FireCallbacksOnBankButtons()
			end)
		end
	end
end

local integrationEventFrame = CreateFrame("Frame")
integrationEventFrame:RegisterEvent("ADDON_LOADED")
integrationEventFrame:RegisterEvent("BANKFRAME_OPENED")
integrationEventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" and ... == ADDON_NAME then
		self:UnregisterEvent("ADDON_LOADED")
		C_Timer.After(0.5, function()
			if OneWoW_Bags.GUI then
				HookGUIRefresh()
				OneWoW_Bags:FireCallbacksOnAllButtons()
			end
		end)
	elseif event == "BANKFRAME_OPENED" then
		if db.global.enableBankOverlays then
			C_Timer.After(0.1, function()
				OneWoW_Bags:FireCallbacksOnBankButtons()
			end)
		end
	end
end)
