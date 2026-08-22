local _, ns = ...

local wipe = wipe

local queued = {}

function ns.QueueQuestData(source)
    queued[#queued + 1] = source
end

function ns.FlushQuestData()
    local api = OneWoW_CatalogData_Quests_API
    for i = 1, #queued do
        api.RegisterQuestData(queued[i])
    end
    wipe(queued)
end
