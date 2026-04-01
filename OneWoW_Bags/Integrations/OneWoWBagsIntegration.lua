local ADDON_NAME, OneWoW_Bags = ...

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
	local db = self.db
	local altShow = self.GUI and self.GUI.IsAltShowActive and self.GUI:IsAltShowActive()
	if not altShow and db and db.global and db.global.stripJunkOverlays and button._owb_isJunk then
		local engine = _G.OneWoW and _G.OneWoW.OverlayEngine
		if engine then engine:CleanButton(button) end
		return
	end
	for name, callback in pairs(callbacks) do
		pcall(callback, button, bagID, slotID)
	end
end

function OneWoW_Bags:FireCallbacksOnAllButtons()
	local BagSet = self.BagSet
	if not BagSet or not BagSet.slots then return end

	for bagID, bagSlots in pairs(BagSet.slots) do
		for slotID, button in pairs(bagSlots) do
			if button and button:IsVisible() and button.owb_bagID and button.owb_slotID then
				self:FireItemButtonCallback(button, button.owb_bagID, button.owb_slotID)
			end
		end
	end
end

function OneWoW_Bags:FireCallbacksOnBankButtons()
	local db = self.db
	if not db or not db.global or not db.global.enableBankOverlays then return end

	local BankSet = self.BankSet
	if BankSet and BankSet.slots then
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

	local BankSet = self.BankSet
	if BankSet and BankSet.slots then
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

	local GBSet = self.GuildBankSet
	if GBSet and GBSet.slots then
		for tabID, tabSlots in pairs(GBSet.slots) do
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
	if not GUI or not GUI.RefreshLayout then return end

	local originalRefreshLayout = GUI.RefreshLayout
	function GUI:RefreshLayout()
		originalRefreshLayout(self)
		C_Timer.After(0.05, function()
			OneWoW_Bags:FireCallbacksOnAllButtons()
		end)
	end

	local BankGUI = OneWoW_Bags.BankGUI
	if BankGUI and BankGUI.RefreshLayout then
		local originalBankRefresh = BankGUI.RefreshLayout
		function BankGUI:RefreshLayout()
			originalBankRefresh(self)
			local db = OneWoW_Bags.db
			if db and db.global and db.global.enableBankOverlays then
				C_Timer.After(0.05, function()
					OneWoW_Bags:FireCallbacksOnBankButtons()
				end)
			end
		end
	end

	local GuildBankGUI = OneWoW_Bags.GuildBankGUI
	if GuildBankGUI and GuildBankGUI.RefreshLayout then
		local originalGBRefresh = GuildBankGUI.RefreshLayout
		function GuildBankGUI:RefreshLayout()
			originalGBRefresh(self)
			local db = OneWoW_Bags.db
			if db and db.global and db.global.enableBankOverlays then
				C_Timer.After(0.05, function()
					OneWoW_Bags:FireCallbacksOnBankButtons()
				end)
			end
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
		local db = OneWoW_Bags.db
		if db and db.global and db.global.enableBankOverlays then
			C_Timer.After(0.1, function()
				OneWoW_Bags:FireCallbacksOnBankButtons()
			end)
		end
	end
end)
