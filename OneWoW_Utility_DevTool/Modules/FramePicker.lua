local AddonName, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
local L = Addon.L or {}
if not OneWoW_GUI then return end

local FramePicker = {}
Addon.FramePicker = FramePicker

function FramePicker:Initialize()
    if self.overlay then return end

    self.overlay = CreateFrame("Frame", "WoWNotesDevToolsPickerOverlay", UIParent)
    self.overlay:SetFrameStrata("TOOLTIP")
    self.overlay:SetAllPoints(UIParent)
    self.overlay:EnableMouse(false)
    self.overlay:EnableKeyboard(true)
    self.overlay:Hide()

    self.currentFrame = nil
    self.lastMouseState = false

    self.overlay:SetScript("OnUpdate", function(self, elapsed)
        FramePicker:OnUpdate(elapsed)
    end)

    self.frameIndex = 1
    self.allFrames = {}

    self.overlay:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            FramePicker:Cancel()
        elseif key == "TAB" then
            FramePicker:CycleFrame()
        elseif key == "ENTER" then
            FramePicker:OnClick()
        end
    end)

    self.overlay:SetPropagateKeyboardInput(false)

    local dialogResult = OneWoW_GUI:CreateDialog({
        name = "WoWNotesDevToolsPickerInfo",
        title = L["FRAME_PICKER_TITLE"],
        width = 450,
        height = 350,
        strata = "TOOLTIP",
        movable = true,
        escClose = false,
        showBrand = false,
    })
    local infoWindow = dialogResult.frame
    infoWindow:ClearAllPoints()
    infoWindow:SetPoint("TOP", UIParent, "TOP", 0, -100)
    infoWindow:Hide()

    infoWindow.details = dialogResult.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoWindow.details:SetPoint("TOPLEFT", dialogResult.contentFrame, "TOPLEFT", 10, -10)
    infoWindow.details:SetPoint("BOTTOMRIGHT", dialogResult.contentFrame, "BOTTOMRIGHT", -10, 10)
    infoWindow.details:SetJustifyH("LEFT")
    infoWindow.details:SetJustifyV("TOP")
    infoWindow.details:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    infoWindow.details:SetText(L["FRAME_PICKER_HOVER"])

    self.infoWindow = infoWindow
end

function FramePicker:Start()
    self:Initialize()

    self.wasMainFrameShown = false

    if Addon.UI and Addon.UI.mainFrame and Addon.UI.mainFrame:IsShown() then
        self.wasMainFrameShown = true
        Addon.UI.mainFrame:Hide()
    end

    self.overlay:Show()
    self.overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    self.infoWindow:Show()

    Addon:Print(L["FRAME_PICKER_MSG_ACTIVE"])
end

function FramePicker:CycleFrame()
    if #self.allFrames <= 1 then
        Addon:Print(L["FRAME_PICKER_MSG_ONE"])
        return
    end

    self.frameIndex = (self.frameIndex % #self.allFrames) + 1
    Addon:Print((L["FRAME_PICKER_MSG_CYCLING"]):format(self.frameIndex, #self.allFrames))
end

function FramePicker:Cancel()
    if not self.overlay then return end

    self.overlay:Hide()
    self.infoWindow:Hide()
    Addon.FrameInspector:ClearHighlight()

    if self.wasMainFrameShown and Addon.UI and Addon.UI.mainFrame then
        Addon.UI.mainFrame:Show()
    end

    Addon:Print(L["FRAME_PICKER_MSG_CANCELLED"])
end

function FramePicker:GetGeometricFramesAtCursor()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale

    local framesAtCursor = {}
    local frame = EnumerateFrames()
    local checkedCount = 0
    local visibleCount = 0
    local hasRectCount = 0

    while frame do
        checkedCount = checkedCount + 1

        if frame:IsVisible() and frame:IsShown() then
            visibleCount = visibleCount + 1

            local hitResult = pcall(function()
                local l, b, w, h = frame:GetRect()
                if l and w and h and w > 0 and h > 0 then
                    hasRectCount = hasRectCount + 1
                    local right = l + w
                    local top = b + h
                    if x >= l and x <= right and y >= b and y <= top then
                        tinsert(framesAtCursor, frame)
                    end
                end
            end)
        end
        frame = EnumerateFrames(frame)
    end

    if not self.lastDebugTime or (GetTime() - self.lastDebugTime) > 2 then
        self.lastDebugTime = GetTime()
        self.debugStats = string.format("Scanned: %d | Visible: %d | HasRect: %d | AtCursor: %d",
            checkedCount, visibleCount, hasRectCount, #framesAtCursor)
    end

    local strataOrder = {
        BACKGROUND = 1,
        LOW = 2,
        MEDIUM = 3,
        HIGH = 4,
        DIALOG = 5,
        FULLSCREEN = 6,
        FULLSCREEN_DIALOG = 7,
        TOOLTIP = 8
    }

    sort(framesAtCursor, function(a, b)
        local strataA = a:GetFrameStrata()
        local strataB = b:GetFrameStrata()
        local orderA = strataOrder[strataA] or 0
        local orderB = strataOrder[strataB] or 0

        if orderA ~= orderB then
            return orderA > orderB
        end

        return a:GetFrameLevel() > b:GetFrameLevel()
    end)

    return framesAtCursor
end

function FramePicker:OnUpdate(elapsed)
    if not self.checkedAPI then
        Addon:Print(L["FRAME_PICKER_MSG_GEOMETRIC"])
        self.checkedAPI = true
    end

    local shiftHeld = IsShiftKeyDown()

    if shiftHeld then
        self.lastMouseState = IsMouseButtonDown("LeftButton")
        return
    end

    local frames = {}

    if GetMouseFoci then
        frames = GetMouseFoci() or {}
    elseif GetMouseFocus then
        local frame = GetMouseFocus()
        frames = frame and {frame} or {}
    end

    local geometricFrames = self:GetGeometricFramesAtCursor()

    local frameSet = {}
    for _, frame in ipairs(frames) do
        frameSet[frame] = true
    end

    for _, frame in ipairs(geometricFrames) do
        if not frameSet[frame] then
            tinsert(frames, frame)
            frameSet[frame] = true
        end
    end

    if #frames == 0 then
        self.currentFrame = nil
        self.allFrames = {}
        self.frameIndex = 1
        local msg = "No frames detected under cursor"
        if self.debugStats then
            msg = msg .. "\n\n" .. self.debugStats
        end
        self.infoWindow.details:SetText(msg)
        Addon.FrameInspector:ClearHighlight()
        return
    end

    local validFrames = {}
    for _, frame in ipairs(frames) do
        local isPickerUI = false

        if frame == self.overlay or frame == self.infoWindow then
            isPickerUI = true
        end

        local parent = frame.GetParent and frame:GetParent()
        if parent == self.infoWindow then
            isPickerUI = true
        end

        if not isPickerUI then
            local isForbidden = false
            pcall(function()
                isForbidden = frame:IsForbidden()
            end)

            if not isForbidden then
                tinsert(validFrames, frame)
            end
        end
    end

    self.allFrames = validFrames

    if self.frameIndex > #validFrames then
        self.frameIndex = 1
    end

    local targetFrame = validFrames[self.frameIndex]

    if targetFrame then
        self.currentFrame = targetFrame

        local name = targetFrame.GetName and targetFrame:GetName() or "Anonymous"
        local ftype = targetFrame.GetObjectType and targetFrame:GetObjectType() or "Unknown"

        local details = {}
        if #validFrames > 1 then
            tinsert(details, (L["FRAME_PICKER_FRAME_OF"]):format(self.frameIndex, #validFrames))
            tinsert(details, "")
        end
        tinsert(details, "NAME: " .. name)
        tinsert(details, "TYPE: " .. ftype)

        if targetFrame.IsShown then
            tinsert(details, "SHOWN: " .. (targetFrame:IsShown() and "Yes" or "No"))
        end

        if targetFrame.IsMouseEnabled then
            tinsert(details, "MOUSE: " .. (targetFrame:IsMouseEnabled() and "Yes" or "No"))
        end

        if targetFrame.GetParent then
            local parent = targetFrame:GetParent()
            if parent then
                local pname = parent.GetName and parent:GetName() or "Anonymous"
                tinsert(details, "PARENT: " .. pname)
            end
        end

        if targetFrame.GetWidth and targetFrame.GetHeight then
            local width = targetFrame:GetWidth()
            local height = targetFrame:GetHeight()
            tinsert(details, string.format("SIZE: %.0f x %.0f", width, height))
        end

        if targetFrame.GetFrameStrata then
            tinsert(details, "STRATA: " .. targetFrame:GetFrameStrata())
        end

        if targetFrame.GetFrameLevel then
            tinsert(details, "LEVEL: " .. targetFrame:GetFrameLevel())
        end

        if self.debugStats then
            tinsert(details, "")
            tinsert(details, "DEBUG: " .. self.debugStats)
            tinsert(details, "TOTAL FRAMES FOUND: " .. #frames)

            if #validFrames > 1 then
                tinsert(details, "")
                tinsert(details, "ALL FRAMES AT CURSOR:")
                for i = 1, math.min(8, #validFrames) do
                    local f = validFrames[i]
                    local fname = f.GetName and f:GetName() or "Anonymous"
                    local ftype = f.GetObjectType and f:GetObjectType() or "Unknown"
                    local mouse = f.IsMouseEnabled and (f:IsMouseEnabled() and "M" or "-") or "?"
                    local hasRect = "-"
                    pcall(function() if f.GetRect and select(1, f:GetRect()) ~= nil then hasRect = "R" end end)
                    local marker = (i == self.frameIndex) and ">>>" or "   "
                    tinsert(details, string.format("%s[%d] %s (%s) %s%s", marker, i, fname, ftype, mouse, hasRect))
                end
                if #validFrames > 8 then
                    tinsert(details, string.format("  ... and %d more", #validFrames - 8))
                end
            end
        end

        self.infoWindow.details:SetText(table.concat(details, "\n"))
        Addon.FrameInspector:HighlightFrame(targetFrame)
    else
        self.currentFrame = nil
        self.infoWindow.details:SetText(L["FRAME_PICKER_ALL_FILTERED"])
        Addon.FrameInspector:ClearHighlight()
    end

    local mouseDown = IsMouseButtonDown("LeftButton")
    if mouseDown and not self.lastMouseState then
        self:OnClick()
    end
    self.lastMouseState = mouseDown

    if IsMouseButtonDown("RightButton") then
        self:Cancel()
    end
end

function FramePicker:OnClick()
    if not self.currentFrame then
        Addon:Print(L["FRAME_PICKER_MSG_NO_FRAME"])
        return
    end

    local frame = self.currentFrame
    self:Cancel()

    Addon.FrameInspector:InspectFrame(frame)
    Addon:Print((L["FRAME_PICKER_MSG_SELECTED"]):format(frame.GetName and frame:GetName() or "Anonymous"))

    if Addon.UI then
        Addon.UI:Show()
    end
end
