local AddonName, Addon = ...

local FrameTree = {}
Addon.FrameTree = FrameTree

local safeGet, safeGetMulti
local NODE_HEIGHT = 20
local INDENT_PX = 15
local MAX_DEPTH = 20

local function ensureHelpers()
    if not safeGet then
        safeGet = Addon.safeGet
        safeGetMulti = Addon.safeGetMulti
    end
end

local function resolveNameValue(val)
    if type(val) == "string" then return val end
    if val and type(val) == "table" then
        local ok, text = pcall(function() return val.GetText and val:GetText() end)
        if ok and type(text) == "string" then return text end
    end
    return nil
end

local function getNodeName(frame)
    ensureHelpers()
    local name
    if safeGet then
        name = resolveNameValue(safeGet(frame, "GetName"))
        if not name or name == "" then
            name = resolveNameValue(safeGet(frame, "GetDebugName"))
        end
    else
        local ok, result = pcall(frame.GetName, frame)
        name = ok and resolveNameValue(result)
        if not name or name == "" then
            ok, result = pcall(frame.GetDebugName, frame)
            name = ok and resolveNameValue(result)
        end
    end
    return name or "Anonymous"
end

local function getNodeType(frame)
    ensureHelpers()
    if safeGet then
        return safeGet(frame, "GetObjectType") or "Unknown"
    end
    local ok, result = pcall(frame.GetObjectType, frame)
    return (ok and result) or "Unknown"
end

local function makeNodeId(frame)
    return tostring(frame)
end

function FrameTree:Create(parentContent, scrollFrame)
    local tree = {}
    tree.parentContent = parentContent
    tree.scrollFrame = scrollFrame
    tree.rootNodes = {}
    tree.nodeFramePool = {}
    tree.expandedNodes = {}
    tree.selectedNodeId = nil
    tree.pendingScroll = false
    tree.visibleCount = 0

    function tree:Clear()
        for _, nf in ipairs(self.nodeFramePool) do
            nf:Hide()
        end
        self.rootNodes = {}
        self.expandedNodes = {}
        self.selectedNodeId = nil
        self.pendingScroll = false
        self.visibleCount = 0
    end

    local function buildChildNodes(frame, depth)
        if depth > MAX_DEPTH then return nil end
        local children = {}

        if frame.GetChildren then
            local ok, childList = pcall(function() return { frame:GetChildren() } end)
            if ok and childList then
                for _, child in ipairs(childList) do
                    local node = {
                        id = makeNodeId(child),
                        text = getNodeName(child) .. " |cFF808080(" .. getNodeType(child) .. ")|r",
                        data = child,
                        children = nil,
                        isRegion = false,
                        depth = depth,
                    }
                    tinsert(children, node)
                end
            end
        end

        if frame.GetRegions then
            local ok, regionList = pcall(function() return { frame:GetRegions() } end)
            if ok and regionList then
                for _, region in ipairs(regionList) do
                    local node = {
                        id = makeNodeId(region),
                        text = getNodeName(region) .. " |cFF808080(" .. getNodeType(region) .. ")|r",
                        data = region,
                        children = {},
                        isRegion = true,
                        depth = depth,
                    }
                    tinsert(children, node)
                end
            end
        end

        return #children > 0 and children or {}
    end

    function tree:ExpandNode(node)
        if node.isRegion then return end
        if node.children == nil and node.data then
            node.children = buildChildNodes(node.data, node.depth + 1)
        end
        self.expandedNodes[node.id] = true
        self:Render()
    end

    function tree:CollapseNode(node)
        self.expandedNodes[node.id] = false
        self:Render()
    end

    function tree:ToggleNode(node)
        if self.expandedNodes[node.id] then
            self:CollapseNode(node)
        else
            self:ExpandNode(node)
        end
    end

    function tree:BuildFromFrame(frame)
        self:Clear()
        if not frame then return end

        local parentChain = {}
        local current = frame
        while current do
            tinsert(parentChain, 1, current)
            if current.GetParent then
                current = current:GetParent()
            else
                break
            end
        end

        local rootNode
        local prevNode

        for i, pf in ipairs(parentChain) do
            local node = {
                id = makeNodeId(pf),
                text = getNodeName(pf) .. " |cFF808080(" .. getNodeType(pf) .. ")|r",
                data = pf,
                children = nil,
                isRegion = false,
                depth = i - 1,
            }

            if pf == frame then
                self.selectedNodeId = node.id
                self.pendingScroll = true
                node.children = buildChildNodes(pf, i)
                self.expandedNodes[node.id] = true
            else
                self.expandedNodes[node.id] = true
            end

            if i == 1 then
                rootNode = node
                tinsert(self.rootNodes, node)
            else
                if prevNode.children == nil then
                    prevNode.children = buildChildNodes(prevNode.data, prevNode.depth + 1)
                end

                for ci, child in ipairs(prevNode.children) do
                    if child.id == node.id then
                        prevNode.children[ci] = node
                        break
                    end
                end
            end
            prevNode = node
        end

        self:Render()
    end

    local function getOrCreateNodeFrame(pool, index, parent)
        local nf = pool[index]
        if nf then return nf end

        nf = CreateFrame("Button", nil, parent)
        nf:SetHeight(NODE_HEIGHT)
        nf:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        nf.bg = nf:CreateTexture(nil, "BACKGROUND")
        nf.bg:SetAllPoints()
        nf.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        nf.bg:Hide()

        nf.toggle = nf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nf.toggle:SetPoint("LEFT", 0, 0)
        nf.toggle:SetWidth(14)
        nf.toggle:SetJustifyH("CENTER")

        nf.label = nf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nf.label:SetPoint("LEFT", nf.toggle, "RIGHT", 2, 0)
        nf.label:SetPoint("RIGHT", nf, "RIGHT", -2, 0)
        nf.label:SetJustifyH("LEFT")

        nf:SetScript("OnEnter", function(self)
            self.bg:Show()
            if self.nodeData and self.nodeData.data then
                Addon.FrameInspector:HighlightFrame(self.nodeData.data)
            end
        end)

        nf:SetScript("OnLeave", function(self)
            if not self.isSelectedStyle then
                self.bg:Hide()
            end
            Addon.FrameInspector:ClearHighlight()
        end)

        nf:SetScript("OnClick", function(self, button)
            if not self.nodeData then return end
            if button == "RightButton" then
                Addon:CopyToClipboard(getNodeName(self.nodeData.data))
                return
            end
            if self.isToggleHit then
                tree:ToggleNode(self.nodeData)
            else
                if self.nodeData.data then
                    Addon.FrameInspector:InspectFrame(self.nodeData.data)
                end
            end
        end)

        nf:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                local cursorX = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                local frameLeft = self:GetLeft() * scale
                local toggleEnd = frameLeft + (self.nodeData and self.nodeData.depth or 0) * INDENT_PX * scale + 14 * scale
                self.isToggleHit = cursorX < toggleEnd
            end
        end)

        pool[index] = nf
        return nf
    end

    function tree:Render()
        local visibleNodes = {}

        local function walkNodes(nodes)
            if not nodes then return end
            for _, node in ipairs(nodes) do
                tinsert(visibleNodes, node)
                if self.expandedNodes[node.id] and node.children and #node.children > 0 then
                    walkNodes(node.children)
                end
            end
        end

        walkNodes(self.rootNodes)
        self.visibleCount = #visibleNodes

        for i = #visibleNodes + 1, #self.nodeFramePool do
            if self.nodeFramePool[i] then
                self.nodeFramePool[i]:Hide()
            end
        end

        for i, node in ipairs(visibleNodes) do
            local nf = getOrCreateNodeFrame(self.nodeFramePool, i, self.parentContent)
            nf.nodeData = node
            nf:ClearAllPoints()
            nf:SetPoint("TOPLEFT", self.parentContent, "TOPLEFT", node.depth * INDENT_PX, -(i - 1) * NODE_HEIGHT)
            nf:SetPoint("RIGHT", self.parentContent, "RIGHT", 0, 0)

            local hasChildren = not node.isRegion and (node.children == nil or (node.children and #node.children > 0))
            if hasChildren then
                nf.toggle:SetText(self.expandedNodes[node.id] and "-" or "+")
            else
                nf.toggle:SetText(node.isRegion and "-" or " ")
            end

            local isSelected = node.id == self.selectedNodeId
            nf.isSelectedStyle = isSelected
            if isSelected then
                nf.bg:Show()
                nf.label:SetText("|cFF00FF00" .. node.text .. "|r")
            else
                nf.bg:Hide()
                nf.label:SetText(node.text)
            end

            nf:Show()
        end

        local totalHeight = math.max(#visibleNodes * NODE_HEIGHT, 1)
        self.parentContent:SetHeight(totalHeight)

        if self.scrollFrame and self.selectedNodeId and self.pendingScroll then
            self.pendingScroll = false
            for i, node in ipairs(visibleNodes) do
                if node.id == self.selectedNodeId then
                    local selectedY = (i - 1) * NODE_HEIGHT
                    local scrollHeight = self.scrollFrame:GetHeight()
                    local targetScroll = selectedY - (scrollHeight / 2) + (NODE_HEIGHT / 2)
                    targetScroll = math.max(0, math.min(targetScroll, totalHeight - scrollHeight))
                    self.scrollFrame:SetVerticalScroll(targetScroll)
                    break
                end
            end
        end
    end

    function tree:SerializeToText()
        local lines = {}

        local function walkForText(nodes, prefix)
            if not nodes then return end
            for _, node in ipairs(nodes) do
                local indent = string.rep("  ", node.depth)
                local marker = node.isRegion and "- " or ""
                local name = node.data and getNodeName(node.data) or "?"
                local objType = node.data and getNodeType(node.data) or "?"
                local sel = (node.id == self.selectedNodeId) and "[" or ""
                local selEnd = (node.id == self.selectedNodeId) and "]" or ""
                tinsert(lines, indent .. marker .. sel .. name .. " (" .. objType .. ")" .. selEnd)
                if self.expandedNodes[node.id] and node.children then
                    walkForText(node.children, prefix)
                end
            end
        end

        walkForText(self.rootNodes, "")
        return table.concat(lines, "\n")
    end

    return tree
end
