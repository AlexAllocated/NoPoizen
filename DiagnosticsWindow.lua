local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end

local function EnsureDiagnosticsWindow(owner)
	if owner.diagnosticsWindow then
		return owner.diagnosticsWindow
	end
	local frame = CreateFrame("Frame", "NoPoizenDiagnosticsWindow", UIParent)
	frame:SetSize(660, 460)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()
	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.04, 0.04, 0.04, 0.97)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 20, -18)
	title:SetText("NoPoizen Diagnostics")
	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	hint:SetText("Report selected: press Ctrl+C to copy. Use the mouse wheel to scroll.")

	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", 20, -72)
	scroll:SetPoint("BOTTOMRIGHT", -20, 54)
	scroll:EnableMouseWheel(true)
	local textBox = CreateFrame("EditBox", nil, scroll)
	textBox:SetWidth(600)
	textBox:SetHeight(1)
	textBox:SetMultiLine(true)
	textBox:SetAutoFocus(false)
	textBox:SetFontObject("ChatFontNormal")
	textBox:SetTextInsets(4, 4, 4, 4)
	scroll:SetScrollChild(textBox)
	-- All references and the read-only copy live exclusively on addon-owned objects.
	frame.TextBox, frame.Scroll = textBox, scroll
	local measure = frame:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
	measure:SetWidth(592)
	measure:Hide()
	frame.Measure = measure
	local function ScrollBy(delta)
		if not owner:CanMutateHUDFrame(scroll) then
			return
		end
		local current, maximum = scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()
		if owner:IsFiniteNumber(current) and owner:IsFiniteNumber(maximum) then
			scroll:SetVerticalScroll(math.max(0, math.min(maximum, current + delta)))
		end
	end
	scroll:SetScript("OnMouseWheel", function(_, delta)
		if owner:IsFiniteNumber(delta) then
			ScrollBy(-delta * 36)
		end
	end)
	textBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput and owner:CanMutateHUDFrame(self) then
			self:SetText(frame.reportText or "")
			self:HighlightText()
		end
	end)
	textBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	textBox:SetScript("OnEscapePressed", function()
		if owner:CanMutateHUDFrame(frame) then
			frame:Hide()
		end
	end)
	frame:SetScript("OnHide", function()
		if owner:CanMutateHUDFrame(textBox) then
			textBox:ClearFocus()
		end
	end)
	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(100, 24)
	close:SetPoint("BOTTOMRIGHT", -20, 16)
	close:SetText("Close")
	close:SetScript("OnClick", function()
		if owner:CanMutateHUDFrame(frame) then
			frame:Hide()
		end
	end)
	local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	selectAll:SetSize(120, 24)
	selectAll:SetPoint("BOTTOMLEFT", 20, 16)
	selectAll:SetText("Select Report")
	selectAll:SetScript("OnClick", function()
		if owner:CanMutateHUDFrame(textBox) then
			textBox:SetFocus()
			textBox:HighlightText()
		end
	end)
	owner.diagnosticsWindow = frame
	return frame
end

function NoPoizen:OpenDiagnosticsWindow(text)
	if self:IsHUDRestricted() or not self:CanAccessValue(text) or type(text) ~= "string" then
		return false
	end
	local frame = EnsureDiagnosticsWindow(self)
	if
		not self:CanMutateHUDFrame(frame)
		or not self:CanMutateHUDFrame(frame.TextBox)
		or not self:CanMutateHUDFrame(frame.Scroll)
	then
		return false
	end
	-- BuildDiagnostics already bounds its history; this caps even direct callers.
	frame.reportText = text:sub(1, 32768)
	frame.TextBox:SetText(frame.reportText)
	frame.Measure:SetText(frame.reportText)
	local height = frame.Measure:GetStringHeight()
	if not self:IsFiniteNumber(height) then
		return false
	end
	frame.TextBox:SetHeight(math.max(1, height + 16))
	frame:Show()
	frame.TextBox:SetFocus()
	frame.TextBox:HighlightText()
	frame.Scroll:SetVerticalScroll(0)
	return true
end
