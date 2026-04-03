local _, OneWoW_Bags = ...

function OneWoW_Bags:ConfigEnum(sourceEnum, config, autoRegisterMissing)
    if type(sourceEnum) ~= "table" then
       error("sourceEnum must be a table")
    end
 
    if type(config) ~= "table" then
       error("config must be a table")
    end
 
    local enumTable = {}
 
    for name, value in pairs(sourceEnum) do
       name = name:lower()
       local synonyms = config[name]
 
       if synonyms then
          local keep_key = synonyms[#synonyms]
 
          if keep_key then
             enumTable[name] = value
          end
 
          for i=1, #synonyms - 1 do
             enumTable[synonyms[i]] = value
          end
       else
          if autoRegisterMissing then
             enumTable[name] = value
          end
       end
    end
 
    return enumTable
 end
 