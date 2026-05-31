local _, ns = ...

ns.Catalog = {}
local Catalog = ns.Catalog

local registeredDataAddons = {}

function Catalog:RegisterDataAddon(name, dataAddon)
    registeredDataAddons[name] = dataAddon
end

function Catalog:GetDataAddon(name)
    return registeredDataAddons[name]
end

function Catalog:GetAllDataAddons()
    return registeredDataAddons
end
