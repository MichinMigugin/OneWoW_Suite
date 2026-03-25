local _, Addon = ...

local format = format
local table_concat = table.concat

local SOUND_UNCAT = "uncategorized"
local SOUND_PATH_PREFIX = (Addon.Constants and Addon.Constants.SOUND_PATH_PREFIX) or "sound/"

function Addon.ValidateDataBuildGameBuild(expectedVersion)
	local buildVersion, buildNumber = GetBuildInfo()
	local gameVersion = buildVersion .. "." .. buildNumber
	if type(expectedVersion) == "string" then
		if gameVersion == expectedVersion then
			return true
		end
		print(format("Game version %s doesn't match Data version %s", gameVersion, expectedVersion))
		return false
	end
	if type(expectedVersion) == "table" then
		local allowed = {}
		for _, version in ipairs(expectedVersion) do
			if type(version) == "string" then
				if gameVersion == version then
					return true
				end
				allowed[#allowed + 1] = version
			end
		end
		if #allowed > 0 then
			print(format("Game version %s doesn't match Data versions %s", gameVersion, table_concat(allowed, ", ")))
			return false
		end
	end
	print(format("Game version %s doesn't match Data version %s", gameVersion, tostring(expectedVersion)))
	return false
end

function Addon.RebuildSoundFilePath(top, sub, tail)
	if not tail or tail == "" then
		return tail
	end
	if top == SOUND_UNCAT and sub == SOUND_UNCAT then
		if string.find(tail, "/", 1, true) then
			return tail
		end
		return SOUND_PATH_PREFIX .. tail
	end
	if sub == SOUND_UNCAT then
		return SOUND_PATH_PREFIX .. top .. "/" .. tail
	end
	return SOUND_PATH_PREFIX .. top .. "/" .. sub .. "/" .. tail
end
