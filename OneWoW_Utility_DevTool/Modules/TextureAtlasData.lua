local AddonName, Addon = ...

function Addon:LoadBuiltInAtlases()
    if self.cachedAtlases then
        return self.cachedAtlases
    end

    local atlases = {}

    if not self.data then
        Addon:Print("Atlas data not loaded")
        return atlases
    end

    for fileID, atlasTable in pairs(self.data) do
        for atlasName, atlasData in pairs(atlasTable) do
            if type(atlasName) == "string" then
                table.insert(atlases, atlasName)
            end
        end
    end

    table.sort(atlases)
    self.cachedAtlases = atlases

    Addon:Print("Loaded " .. #atlases .. " atlases (data from TextureAtlasViewer)")

    return atlases
end
