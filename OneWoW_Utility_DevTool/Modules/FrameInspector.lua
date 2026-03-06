local AddonName, Addon = ...

local FrameInspector = {}
Addon.FrameInspector = FrameInspector

function FrameInspector:InspectFrame(frame)
    if not frame then return end

    Addon.selectedFrame = frame

    local info = Addon:GetFrameInfo(frame)
    if not info then return end

    if Addon.FrameInspectorTab then
        Addon.FrameInspectorTab:UpdateFrameDetails(frame, info)
        Addon.FrameInspectorTab:UpdateFrameTree(frame)
    end

    self:AddToRecentFrames(frame)
end

function FrameInspector:AddToRecentFrames(frame)
    if not frame then return end

    local name = frame.GetName and frame:GetName()
    if not name then return end

    local recent = Addon.db.recentFrames

    for i, fname in ipairs(recent) do
        if fname == name then
            table.remove(recent, i)
            break
        end
    end

    table.insert(recent, 1, name)

    if #recent > 20 then
        table.remove(recent, 21)
    end
end

function FrameInspector:GetRecentFrames()
    local frames = {}
    for _, name in ipairs(Addon.db.recentFrames) do
        local frame = _G[name]
        if frame then
            table.insert(frames, frame)
        end
    end
    return frames
end

function FrameInspector:HighlightFrame(frame)
    if not frame or not frame.GetRect then return end

    if not self.highlightFrame then
        self.highlightFrame = CreateFrame("Frame", "WoWNotesDevToolsHighlight", UIParent)
        self.highlightFrame:SetFrameStrata("TOOLTIP")
        self.highlightFrame:EnableMouse(false)

        self.highlightFrame.border = {}
        for i = 1, 4 do
            self.highlightFrame.border[i] = self.highlightFrame:CreateTexture(nil, "OVERLAY")
            self.highlightFrame.border[i]:SetColorTexture(0, 1, 0, 0.8)
        end

        self.highlightFrame.border[1]:SetPoint("TOPLEFT")
        self.highlightFrame.border[1]:SetPoint("TOPRIGHT")
        self.highlightFrame.border[1]:SetHeight(2)

        self.highlightFrame.border[2]:SetPoint("BOTTOMLEFT")
        self.highlightFrame.border[2]:SetPoint("BOTTOMRIGHT")
        self.highlightFrame.border[2]:SetHeight(2)

        self.highlightFrame.border[3]:SetPoint("TOPLEFT")
        self.highlightFrame.border[3]:SetPoint("BOTTOMLEFT")
        self.highlightFrame.border[3]:SetWidth(2)

        self.highlightFrame.border[4]:SetPoint("TOPRIGHT")
        self.highlightFrame.border[4]:SetPoint("BOTTOMRIGHT")
        self.highlightFrame.border[4]:SetWidth(2)
    end

    local left, bottom, width, height = frame:GetRect()
    if not left then
        self.highlightFrame:Hide()
        return
    end

    self.highlightFrame:ClearAllPoints()
    self.highlightFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    self.highlightFrame:SetSize(width, height)
    self.highlightFrame:Show()
end

function FrameInspector:ClearHighlight()
    if self.highlightFrame then
        self.highlightFrame:Hide()
    end
end

function FrameInspector:FormatFrameDetails(frame, info)
    local lines = {}

    table.insert(lines, "NAME: " .. (info.name or "Anonymous"))
    table.insert(lines, "TYPE: " .. (info.type or "Unknown"))
    table.insert(lines, "")

    if info.name == "GossipFrame" and GossipFrameNpcNameText then
        local npcName = GossipFrameNpcNameText:GetText()
        if npcName and npcName ~= "" then
            table.insert(lines, "NPC: " .. npcName)
            table.insert(lines, "")
        end
    end

    if info.name == "QuestFrame" and QuestNPCModelNameplate then
        local npcName = QuestNPCModelNameplate:GetText()
        if npcName and npcName ~= "" then
            table.insert(lines, "NPC: " .. npcName)
            table.insert(lines, "")
        end
    end

    table.insert(lines, "STATE:")
    table.insert(lines, "  Shown: " .. (info.shown and "Yes" or "No"))
    table.insert(lines, "  Mouse Enabled: " .. (info.mouse and "Yes" or "No"))
    table.insert(lines, "  Protected: " .. (info.protected and "Yes" or "No"))
    table.insert(lines, "  Forbidden: " .. (info.forbidden and "Yes" or "No"))
    table.insert(lines, "")

    if info.strata then
        table.insert(lines, "STRATA: " .. info.strata)
    end
    if info.level then
        table.insert(lines, "LEVEL: " .. info.level)
    end
    if info.width and info.height then
        table.insert(lines, string.format("SIZE: %.1f x %.1f", info.width, info.height))
    end
    table.insert(lines, "")

    if info.points and #info.points > 0 then
        table.insert(lines, "ANCHORS:")
        for i, point in ipairs(info.points) do
            table.insert(lines, string.format("  %d: %s to %s %s (%.1f, %.1f)",
                i, point.point, point.relativeTo, point.relativePoint or "", point.x or 0, point.y or 0))
        end
        table.insert(lines, "")
    end

    if frame.GetRect then
        local left, bottom, width, height = frame:GetRect()
        if left then
            local top = bottom + height
            local right = left + width
            local centerX = left + (width / 2)
            local centerY = bottom + (height / 2)

            table.insert(lines, "SCREEN POSITION:")
            table.insert(lines, string.format("  Left: %.1f, Right: %.1f", left, right))
            table.insert(lines, string.format("  Bottom: %.1f, Top: %.1f", bottom, top))
            table.insert(lines, string.format("  Center: (%.1f, %.1f)", centerX, centerY))
            table.insert(lines, "")

            local parent = frame.GetParent and frame:GetParent()
            if parent and parent.GetRect then
                local pLeft, pBottom, pWidth, pHeight = parent:GetRect()
                if pLeft then
                    local pTop = pBottom + pHeight
                    local pRight = pLeft + pWidth
                    local pCenterX = pLeft + (pWidth / 2)
                    local pCenterY = pBottom + (pHeight / 2)

                    table.insert(lines, "RELATIVE TO PARENT:")
                    table.insert(lines, string.format("  From Left Edge: %.1f", left - pLeft))
                    table.insert(lines, string.format("  From Right Edge: %.1f", pRight - right))
                    table.insert(lines, string.format("  From Bottom Edge: %.1f", bottom - pBottom))
                    table.insert(lines, string.format("  From Top Edge: %.1f", pTop - top))
                    table.insert(lines, string.format("  From Parent Center: (%.1f, %.1f)", centerX - pCenterX, centerY - pCenterY))
                    table.insert(lines, "")
                end
            end
        end
    end

    local parent = frame.GetParent and frame:GetParent()
    if parent then
        local pname = parent.GetName and parent:GetName() or "Anonymous"
        table.insert(lines, "PARENT: " .. pname)
    else
        table.insert(lines, "PARENT: None")
    end

    local children = Addon:GetChildren(frame)
    table.insert(lines, "CHILDREN: " .. #children)

    return table.concat(lines, "\n")
end
