local _, ns = ...

local ShortNames = {}
ns.PortalData_ShortNames = ShortNames

function ShortNames:Get(spellID)
	return ns.PortalData:GetShortName(spellID)
end
