local LibCopyPaste = LibStub:NewLibrary("LibCopyPaste-1.0", 9)
if not LibCopyPaste then return end

local IsControlKeyDown = IsControlKeyDown

local CopyPasteFrame = {}
CopyPasteFrame.__index = CopyPasteFrame

function CopyPasteFrame:Create()
	local obj = {}
	setmetatable(obj, CopyPasteFrame)

	local frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
	frame:SetFrameStrata("DIALOG")
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	frame:SetBackdropColor(0.1, 0.1, 0.1, 1.0)
	frame:SetBackdropBorderColor(1, 0.82, 0, 1)

	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	obj.button = button
	button:SetSize(100, 25)
	button:SetPoint("BOTTOM", 0, 10)
	button:SetText("Close")
	button:SetNormalFontObject("GameFontNormal")
	button:SetHighlightFontObject("GameFontHighlight")
	button:SetScript("OnClick", function()
		obj:Hide()
	end)

	frame:EnableMouse(true)
	frame:EnableKeyboard(true)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -10)
	title:SetTextColor(1, 0.82, 0)
	title:Show()

	local contentFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -35)
	contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 50)
	contentFrame:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = true,
		tileSize = 16,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	contentFrame:SetBackdropColor(0.1, 0.1, 0.1, 1.0)

	local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame, "ScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 5, -5)
	scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -25, 5)
	scrollFrame:Show()

	local editBox = CreateFrame("EditBox", nil, scrollFrame)
	editBox:SetMaxLetters(999999)
	editBox:SetSize(600, 300)
	editBox:SetFont(ChatFontNormal:GetFont())
	editBox:SetAutoFocus(true)
	editBox:SetMultiLine(true)
	editBox:Show()
	editBox:SetScript("OnEscapePressed", function()
		obj:Hide()
	end)

	scrollFrame:SetScrollChild(editBox)

	obj.frame = frame
	obj.editBox = editBox
	obj.title = title
	return obj
end

function CopyPasteFrame:ResetPosition()
	self.frame:SetSize(700, 450)
	self.frame:ClearAllPoints()
	self.frame:SetPoint("CENTER", self.frame:GetParent() or UIParent, "CENTER", 0, 0)
end

function CopyPasteFrame:Show()
	self:ResetPosition()
	self.frame:Show()
	self.editBox:SetFocus()
end

function CopyPasteFrame:SetTitle(title)
	self.title:SetText(title)
end

function CopyPasteFrame:SetText(text)
	self.editBox:SetText(text)
	self.editBox:HighlightText()
end

function CopyPasteFrame:SetAutoHide(autoHide)
	if autoHide then
		local hideQueued = false
		self.editBox:SetScript("OnKeyDown", function(_, key)
			if key == "C" and IsControlKeyDown() then
				hideQueued = true
			end
		end)
		self.editBox:SetScript("OnKeyUp", function(_, key)
			if hideQueued and (key == "C" or key == "LCTRL" or key == "RCTRL") then
				self:Hide()
			end
		end)
	else
		self.editBox:SetScript("OnKeyUp", nil)
		self.editBox:SetScript("OnKeyDown", nil)
	end
end

function CopyPasteFrame:GetTitle()
	return self.title:GetText()
end

function CopyPasteFrame:GetText()
	return self.editBox:GetText()
end

function CopyPasteFrame:IsOpen()
	return self.frame:IsShown()
end

function CopyPasteFrame:SetCallback(callback)
	self.button:SetScript("OnClick", function()
		if callback then
			callback(self:GetText())
		end
		self:Hide()
	end)
end

function CopyPasteFrame:SetReadOnly(readOnly)
	self.readOnly = readOnly
	if readOnly then
		local text = self.editBox:GetText()
		self.editBox:SetScript("OnTextChanged", function(editBox)
			editBox:SetText(text)
			editBox:HighlightText()
		end)
	else
		self.editBox:SetScript("OnTextChanged", nil)
	end
end

function CopyPasteFrame:SetOptions(options)
	if options.frameStrata then
		self.frame:SetFrameStrata(options.frameStrata)
	end
	if options.readOnly ~= nil or self.readOnly ~= nil then
		self:SetReadOnly(options.readOnly)
	end
	self:SetAutoHide(options.autoHide)
end

function CopyPasteFrame:Hide()
	self:SetTitle("")
	self:SetText("")
	self:SetCallback(nil)
	self.frame:SetFrameStrata("DIALOG")
	self:SetOptions({
		readOnly = false,
		autoHide = false,
	})
	self.frame:Hide()
end

local frame

function LibCopyPaste:Copy(title, text, options)
	assert(type(title) == "string" and type(text) == "string",
		"title and text are required and must be strings. Usage: Copy(title, text)")
	if not frame then frame = CopyPasteFrame:Create() end
	frame:Hide()
	frame:SetTitle(title)
	frame:SetText(text)
	if options then
		frame:SetOptions(options)
	end
	frame:Show()
end

function LibCopyPaste:Paste(title, callback, options)
	assert(type(title) == "string" and type(callback) == "function",
		"title and callback are required. title must be a string and callback must be a function. Usage: Copy(title, callback)")
	if not frame then frame = CopyPasteFrame:Create() end
	frame:Hide()
	frame:SetTitle(title)
	frame:SetCallback(callback)
	if options then
		frame:SetOptions(options)
	end
	frame:Show()
end
