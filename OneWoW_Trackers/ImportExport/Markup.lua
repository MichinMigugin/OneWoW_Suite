local _, ns = ...

-- ============================================================================
-- Tracker markup import
-- ============================================================================
-- Parse a markdown-ish guide into list/section/step/objective tables, then
-- CreateListFromParsed writes them through TrackerData CRUD. Methods stay on
-- ns.TrackerData. See OneWoW_Trackers/Docs/ARCHITECTURE.md.
-- ============================================================================

local TD = ns.TrackerData
local Schema = ns.TrackerTypeSchema

local ipairs, tonumber = ipairs, tonumber
local tinsert, wipe = tinsert, wipe
local strsplit, strtrim = strsplit, strtrim

function TD:ParseMarkup(text, opts)
    if not text or text == "" then return nil end
    opts = opts or {}

    local list = {
        title = opts.title or "Imported Guide",
        description = "",
        listType = opts.listType or "guide",
        category = TD:NormalizeCategory(opts.category),
        sections = {},
    }

    local currentSection = nil
    local currentStep = nil
    local descLines = {}

    for line in text:gmatch("[^\r\n]+") do
        line = strtrim(line)

        if line:sub(1, 2) == "# " and line:sub(1, 3) ~= "## " then
            list.title = strtrim(line:sub(3))

        elseif line:sub(1, 4) == "### " then
            if not currentSection then
                currentSection = {
                    key = TD.GenerateKey("sec"),
                    label = "Steps",
                    steps = {},
                }
                tinsert(list.sections, currentSection)
            end

            if currentStep and #descLines > 0 then
                currentStep.description = table.concat(descLines, "\n")
                wipe(descLines)
            end

            currentStep = {
                key = TD.GenerateKey("stp"),
                label = strtrim(line:sub(5)),
                description = "",
                trackType = "manual",
                trackParams = {},
                max = 1,
                objectives = {},
            }
            tinsert(currentSection.steps, currentStep)

        elseif line:sub(1, 3) == "## " then
            if currentStep and #descLines > 0 then
                currentStep.description = table.concat(descLines, "\n")
                wipe(descLines)
            end
            currentStep = nil

            local secLine = strtrim(line:sub(4))
            local secProfReq = nil
            local secEventReq = nil
            local profMatch = secLine:match("@prof:(%d+)")
            if profMatch then
                secProfReq = tonumber(profMatch)
                secLine = strtrim(secLine:gsub("@prof:%d+", ""))
            end
            local eventMatch = secLine:match("@event:(%d+)")
            if eventMatch then
                secEventReq = tonumber(eventMatch)
                secLine = strtrim(secLine:gsub("@event:%d+", ""))
            end

            currentSection = {
                key = TD.GenerateKey("sec"),
                label = secLine,
                steps = {},
                professionRequired = secProfReq,
                eventRequired = secEventReq,
            }
            tinsert(list.sections, currentSection)

        elseif line:sub(1, 2) == "> " then
            local descText = strtrim(line:sub(3))
            if currentStep then
                tinsert(descLines, descText)
            else
                if list.description ~= "" then
                    list.description = list.description .. "\n"
                end
                list.description = list.description .. descText
            end

        elseif line:sub(1, 1) == "[" then
            local bracket, rest = line:match("^(%b[])%s*(.*)")
            if bracket and currentStep then
                local inner = bracket:sub(2, -2)
                local objType, paramStr = strsplit(":", inner, 2)
                objType = strtrim(objType)

                local obj = {
                    key = TD.GenerateKey("obj"),
                    type = TD:IsValidTrackType(objType) and objType or "manual",
                    description = rest or "",
                    params = {},
                }

                if paramStr then
                    obj.params = Schema.ParseParams(obj.type, paramStr)
                end

                tinsert(currentStep.objectives, obj)
            end

        elseif line ~= "" and currentStep then
            if line:sub(1, 2) == "- " then
                local obj = {
                    key = TD.GenerateKey("obj"),
                    type = "manual",
                    description = strtrim(line:sub(3)),
                    params = {},
                }
                tinsert(currentStep.objectives, obj)
            else
                tinsert(descLines, line)
            end
        end
    end

    if currentStep and #descLines > 0 then
        currentStep.description = table.concat(descLines, "\n")
    end

    if #list.sections == 0 then
        return nil
    end

    return list
end

function TD:CreateListFromParsed(parsed)
    if not parsed then return nil end

    local list = self:CreateList({
        title = parsed.title,
        description = parsed.description,
        listType = parsed.listType or "guide",
        category = parsed.category,
    })
    if not list then return nil end

    for _, parsedSec in ipairs(parsed.sections) do
        local sec = self:AddSection(list.id, {
            label = parsedSec.label,
            resetOverride = parsedSec.resetOverride,
            professionRequired = parsedSec.professionRequired,
            eventRequired = parsedSec.eventRequired,
        })
        if sec then
            for _, parsedStep in ipairs(parsedSec.steps or {}) do
                local step = self:AddStep(list.id, sec.key, {
                    label = parsedStep.label,
                    description = parsedStep.description,
                    trackType = parsedStep.trackType,
                    trackParams = parsedStep.trackParams,
                    max = parsedStep.max,
                    noMax = parsedStep.noMax,
                    optional = parsedStep.optional,
                    faction = parsedStep.faction,
                    mapID = parsedStep.mapID,
                    coordX = parsedStep.coordX,
                    coordY = parsedStep.coordY,
                    waypointRadius = parsedStep.waypointRadius,
                })
                if step then
                    for _, parsedObj in ipairs(parsedStep.objectives or {}) do
                        self:AddObjective(list.id, sec.key, step.key, {
                            type = parsedObj.type,
                            description = parsedObj.description,
                            params = parsedObj.params,
                        })
                    end
                end
            end
        end
    end

    return list
end
