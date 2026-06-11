local _, ns = ...

ns.PortalHubEquip = ns.PortalHubEquip or {}
local EquipManager = ns.PortalHubEquip

local equippedItems = {}
local pendingEquip = {}

function EquipManager:IsItemEquippable(itemId)
	if not ns.PortalData then return false end
	return ns.PortalData:IsItemEquippable(itemId)
end

function EquipManager:IsItemEquipped(itemId)
	if not ns.PortalData then return false end
	return ns.PortalData:IsItemEquipped(itemId)
end

function EquipManager:GetItemSlot(itemId)
	if not ns.PortalData then return nil end
	return ns.PortalData:GetItemSlot(itemId)
end

function EquipManager:EquipItem(itemId)
	local slot = self:GetItemSlot(itemId)
	if not slot then return false end

	local currentItem = GetInventoryItemID("player", slot)
	if currentItem then
		equippedItems[slot] = {
			itemId = currentItem,
			slot = slot,
			timestamp = GetTime()
		}
	end

	C_Item.EquipItemByName(itemId)
	pendingEquip[itemId] = {slot = slot, timestamp = GetTime()}

	return true
end

function EquipManager:UseEquippedItem(itemId, slot)
	if not slot then
		slot = self:GetItemSlot(itemId)
	end

	if self:IsItemEquipped(itemId) then
		UseInventoryItem(slot)
		C_Timer.After(0.5, function()
			self:ReequipOriginalItem(slot)
		end)
		return true
	end

	return false
end

function EquipManager:ReequipOriginalItem(slot)
	if equippedItems[slot] then
		local originalItem = equippedItems[slot]
		if C_Item.GetItemCount(originalItem.itemId) > 0 then
			C_Item.EquipItemByName(originalItem.itemId)
		end
		equippedItems[slot] = nil
	end
end

function EquipManager:HandleEquippableItemClick(itemId)
	if self:IsItemEquipped(itemId) then
		return self:UseEquippedItem(itemId)
	else
		return self:EquipItem(itemId)
	end
end

function EquipManager:IsItemPendingEquip(itemId)
	return pendingEquip[itemId] ~= nil
end

function EquipManager:ClearPendingEquip(itemId)
	pendingEquip[itemId] = nil
end

local equipFrame = CreateFrame("Frame")
equipFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
equipFrame:SetScript("OnEvent", function(_, event, slot)
	if event == "PLAYER_EQUIPMENT_CHANGED" then
		for itemId, data in pairs(pendingEquip) do
			if data.slot == slot then
				C_Timer.After(0.1, function()
					if EquipManager:IsItemEquipped(itemId) then
						EquipManager:ClearPendingEquip(itemId)
					end
				end)
			end
		end
	end
end)
