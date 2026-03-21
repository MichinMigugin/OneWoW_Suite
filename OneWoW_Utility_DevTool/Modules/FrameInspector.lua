local AddonName, Addon = ...

local FrameInspector = {}
Addon.FrameInspector = FrameInspector

function FrameInspector:InspectFrame(frame)
    if not frame then return end

    local info = Addon:GetFrameInfo(frame)
    if not info then return end

    if Addon.FrameInspectorTab then
        Addon.FrameInspectorTab:UpdateFrameDetails(frame, info)
        if Addon.FrameInspectorTab.frameTree then
            Addon.FrameInspectorTab.frameTree:BuildFromFrame(frame)
        end
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
            tremove(recent, i)
            break
        end
    end

    tinsert(recent, 1, name)

    if #recent > 20 then
        tremove(recent, 21)
    end
end

function FrameInspector:GetRecentFrames()
    local frames = {}
    for _, name in ipairs(Addon.db.recentFrames) do
        local frame = _G[name]
        if frame then
            tinsert(frames, frame)
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

    local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
    if not ok or not left then
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

