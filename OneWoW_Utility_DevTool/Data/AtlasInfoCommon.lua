local _, Addon = ...

local format = format

--- True when the running client matches expectedVersion (e.g. "12.0.1.66527" from GetBuildInfo parts).
function Addon.ValidateAtlasInfoGameBuild(expectedVersion)
	local buildVersion, buildNumber = GetBuildInfo()
	local gameVersion = buildVersion .. "." .. buildNumber
	if gameVersion ~= expectedVersion then
		print(format("Game version %s doesn't match AtlasInfo version %s", gameVersion, expectedVersion))
		return false
	end
	return true
end
