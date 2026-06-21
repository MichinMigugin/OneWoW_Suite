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

OneWoW_Catalog_API = {}

--- Registers a public data-store API with Catalog.
---@param name string
---@param dataAPI table
function OneWoW_Catalog_API.RegisterDataAddon(name, dataAPI)
    Catalog:RegisterDataAddon(name, dataAPI)
end

--- Returns a registered public data-store API.
---@param name string
---@return table|nil dataAPI
function OneWoW_Catalog_API.GetDataAddon(name)
    return Catalog:GetDataAddon(name)
end

--- Returns Catalog's shared asynchronous item-data loader.
---@return table loader
function OneWoW_Catalog_API.GetItemDataLoader()
    return ns.GetItemDataLoader()
end

--- Creates an asynchronous item-data loader backed by the provided database.
---@param dbTable table
---@return table loader
function OneWoW_Catalog_API.CreateItemDataLoader(dbTable)
    return OneWoW_Catalog:CreateItemDataLoader(dbTable)
end
