local _, ns = ...

local wipe = wipe

local queued = {}

function ns.QueueZoneMembership(source)
    queued[#queued + 1] = source
end

function ns.FlushZoneMembership()
    local api = OneWoW_CatalogData_Journal_API
    for i = 1, #queued do
        api.RegisterZoneMembership(queued[i])
    end
    wipe(queued)
end
