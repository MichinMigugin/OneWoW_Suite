local AddonName, Addon = ...

local FrameTree = {}
Addon.FrameTree = FrameTree

function FrameTree:Create(parent)
    local tree = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    tree.content = CreateFrame("Frame", nil, tree)
    tree:SetScrollChild(tree.content)
    tree.content:SetSize(1, 1)

    tree.nodes = {}
    tree.nodeFrames = {}
    tree.expandedNodes = {}

    function tree:Clear()
        for _, nodeFrame in ipairs(self.nodeFrames) do
            nodeFrame:Hide()
            nodeFrame:ClearAllPoints()
        end
        self.nodes = {}
        self.nodeFrames = {}
    end

    function tree:BuildFromFrame(frame)
        self:Clear()

        if not frame then return end

        local rootNode = {
            frame = frame,
            name = frame.GetName and frame:GetName() or "Anonymous",
            type = frame.GetObjectType and frame:GetObjectType() or "Frame",
            level = 0,
            expanded = true,
        }

        local parentChain = Addon:GetParentChain(frame)
        for i = #parentChain, 1, -1 do
            local pframe = parentChain[i]
            table.insert(self.nodes, {
                frame = pframe,
                name = pframe.GetName and pframe:GetName() or "Anonymous",
                type = pframe.GetObjectType and pframe:GetObjectType() or "Frame",
                level = #parentChain - i,
                isParent = i ~= 1,
                expanded = true,
            })
        end

        self.nodes[#self.nodes].isSelected = true

        local function addChildren(parentFrame, level)
            local children = Addon:GetChildren(parentFrame)
            for _, child in ipairs(children) do
                table.insert(self.nodes, {
                    frame = child,
                    name = child.GetName and child:GetName() or "Anonymous",
                    type = child.GetObjectType and child:GetObjectType() or "Frame",
                    level = level,
                    isChild = true,
                    expanded = false,
                })
            end
        end

        addChildren(frame, #parentChain)

        self:Render()
    end

    function tree:Render()
        local yOffset = 0
        local nodeHeight = 20
        local indent = 15

        for i, node in ipairs(self.nodes) do
            local nodeFrame = self.nodeFrames[i]
            if not nodeFrame then
                nodeFrame = CreateFrame("Button", nil, self.content)
                nodeFrame:SetSize(280, nodeHeight)
                nodeFrame:SetNormalFontObject(GameFontNormal)
                nodeFrame:SetHighlightFontObject(GameFontHighlight)

                nodeFrame.bg = nodeFrame:CreateTexture(nil, "BACKGROUND")
                nodeFrame.bg:SetAllPoints()
                nodeFrame.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
                nodeFrame.bg:Hide()

                nodeFrame.text = nodeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nodeFrame.text:SetPoint("LEFT", indent, 0)
                nodeFrame.text:SetJustifyH("LEFT")

                nodeFrame:SetScript("OnEnter", function(self)
                    self.bg:Show()
                    if self.node and self.node.frame then
                        Addon.FrameInspector:HighlightFrame(self.node.frame)
                    end
                end)

                nodeFrame:SetScript("OnLeave", function(self)
                    if not self.node or not self.node.isSelected then
                        self.bg:Hide()
                    end
                    Addon.FrameInspector:ClearHighlight()
                end)

                nodeFrame:SetScript("OnClick", function(self, button)
                    if self.node and self.node.frame then
                        Addon.FrameInspector:InspectFrame(self.node.frame)
                        if button == "RightButton" then
                            Addon:CopyToClipboard(self.node.name)
                        end
                    end
                end)

                nodeFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

                self.nodeFrames[i] = nodeFrame
            end

            nodeFrame.node = node
            nodeFrame:ClearAllPoints()
            nodeFrame:SetPoint("TOPLEFT", self.content, "TOPLEFT", node.level * indent, -yOffset)

            local displayName = node.name
            if node.isParent then
                displayName = "> " .. displayName
            elseif node.isChild then
                displayName = "  - " .. displayName
            end

            if node.isSelected then
                displayName = "[" .. displayName .. "]"
                nodeFrame.bg:Show()
            else
                nodeFrame.bg:Hide()
            end

            nodeFrame.text:SetText(displayName)
            nodeFrame:Show()

            yOffset = yOffset + nodeHeight
        end

        self.content:SetHeight(math.max(yOffset, 1))
    end

    return tree
end
