local NoPoizen = _G.NoPoizen

if not NoPoizen then
	return
end

-- These wrappers belong to the addon. Tests use private fixtures, never client globals.
NoPoizen.HUDAPI = {
	IsRestricted = function()
		if type(InCombatLockdown) == "function" then
			local combat = InCombatLockdown()
			if not NoPoizen:CanAccessValue(combat) or (combat ~= false and combat ~= nil) then
				return true
			end
		end
		if C_RestrictedActions and Enum and Enum.AddOnRestrictionType then
			for _, name in ipairs({ "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map" }) do
				local restrictionType = Enum.AddOnRestrictionType[name]
				if not NoPoizen:CanAccessValue(restrictionType) then
					return true
				end
				if restrictionType ~= nil then
					if not NoPoizen:IsFiniteNumber(restrictionType) then
						return true
					end
					if type(C_RestrictedActions.GetAddOnRestrictionState) == "function" then
						local state = C_RestrictedActions.GetAddOnRestrictionState(restrictionType)
						if not NoPoizen:IsFiniteNumber(state) or state ~= 0 then
							return true
						end
					elseif type(C_RestrictedActions.IsAddOnRestrictionActive) == "function" then
						local active = C_RestrictedActions.IsAddOnRestrictionActive(restrictionType)
						if not NoPoizen:CanAccessValue(active) or active ~= false then
							return true
						end
					end
				end
			end
		end
		return false
	end,
}

function NoPoizen:IsHUDRestricted()
	-- IsAddOnRestrictionActive always returns false while its change event dispatches.
	if self.hudRestrictionTransition then
		return true
	end
	local ok, restricted = pcall(self.HUDAPI.IsRestricted)
	return not ok or not self:CanAccessValue(restricted) or restricted ~= false
end

function NoPoizen:CanMutateHUDFrame(frame)
	if not self:CanAccessTable(frame) then
		return false
	end
	local ok, forbidden = pcall(function()
		return frame:IsForbidden()
	end)
	if not ok or not self:CanAccessValue(forbidden) or forbidden ~= false then
		return false
	end
	local protectedOK, protected = pcall(function()
		return frame:IsProtected()
	end)
	if not protectedOK or not self:CanAccessValue(protected) then
		return false
	end
	-- Only addon-owned frames reach here. A protected frame is never a valid HUD target.
	-- This also quarantines frames made protected by an unrelated addon.
	return protected == false
end

function NoPoizen:HandleHUDLifecycleEvent(frame, eventName, restrictionType, restrictionState)
	if eventName == "PLAYER_LOGOUT" then
		self.isLoggingOut = true
		frame:SetScript("OnUpdate", nil)
		self:EndPoisonIndicatorEditMode(false)
		return
	end
	if self.isLoggingOut then
		return
	end
	if eventName == "PLAYER_REGEN_DISABLED" or eventName == "ADDON_RESTRICTION_STATE_CHANGED" then
		self.hudRestrictionTransition = true
		-- The inactive payload is safe to defer; activating/active/unknown payloads
		-- close the editor before the restriction begins. Never branch on a secret.
		local inactive = eventName == "ADDON_RESTRICTION_STATE_CHANGED"
			and self:CanAccessValue(restrictionState)
			and type(restrictionState) == "number"
			and restrictionState == 0
		if not inactive then
			self:EndPoisonIndicatorEditMode(false)
		end
	end
	-- Reconcile next frame, after the restriction event has finished dispatching.
	-- One replaceable callback avoids timers that survive teardown or stack up.
	frame:SetScript("OnUpdate", function()
		frame:SetScript("OnUpdate", nil)
		if self.isLoggingOut then
			return
		end
		self.hudRestrictionTransition = false
		if self.pendingOptionsRegistration and not self:IsHUDRestricted() then
			self:InitializeOptionsWindow()
		end
		if self.pendingIndicatorAnchor then
			self:ApplySavedIndicatorAnchor()
		end
		self:RefreshPoisonIndicatorVisualState()
	end)
end

function NoPoizen:EnsureHUDLifecycleFrame()
	if self.hudLifecycleFrame then
		return
	end
	local frame = CreateFrame("Frame")
	self.hudLifecycleFrame = frame
	frame:SetScript("OnEvent", function(_, ...)
		self:HandleHUDLifecycleEvent(frame, ...)
	end)
	for _, eventName in ipairs({
		"PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED",
		"ADDON_RESTRICTION_STATE_CHANGED",
		"PLAYER_LOGOUT",
	}) do
		-- Older supported clients may not know newer events; pcall contains registration failure.
		pcall(frame.RegisterEvent, frame, eventName)
	end
end

local function IsSnapshotEqual(owner, snapshot)
	local anchor = owner:GetIndicatorAnchor()
	return snapshot.widgetScale == owner:GetOption("widgetScale")
		and snapshot.anchor.point == anchor.point
		and snapshot.anchor.relativePoint == anchor.relativePoint
		and snapshot.anchor.x == anchor.x
		and snapshot.anchor.y == anchor.y
end

local function GetDefaultEditModeRows(owner)
	local rows = {}
	for _, category in ipairs({ "lethal", "nonLethal" }) do
		local row = { category = category, icons = {} }
		for _, spell in ipairs((owner.poisonCatalog or {})[category] or {}) do
			-- A static preview does not need to read auras or spell APIs.
			table.insert(row.icons, { icon = spell.icon or 134400 })
		end
		if #row.icons > 0 then
			table.insert(rows, row)
		end
	end
	if #rows == 0 then
		rows[1] = { category = "preview", icons = { { icon = 134400 } } }
	end
	return rows
end

local function GetCategoryLabel(category)
	if category == "lethal" then
		return "Lethal Poisons"
	elseif category == "nonLethal" then
		return "Non-Lethal Poisons"
	elseif category == "mainHand" then
		return "Main Hand"
	elseif category == "offHand" then
		return "Off Hand"
	end
	return "NoPoizen"
end

local function LayoutIndicatorRows(hostFrame, rows)
	local iconSize, columnSpacing, rowSpacing, padding = 40, 6, 10, 12
	local textureIndex, maxColumns, cursorY = 0, 0, 10
	for _, row in ipairs(rows) do
		maxColumns = math.max(maxColumns, #(row.icons or {}))
	end
	local width = math.max(1, maxColumns * iconSize + math.max(0, maxColumns - 1) * columnSpacing + padding * 2)
	for rowIndex, row in ipairs(rows) do
		local label = hostFrame.rowLabels[rowIndex]
		if not label then
			label = hostFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			hostFrame.rowLabels[rowIndex] = label
		end
		label:ClearAllPoints()
		label:SetPoint("TOP", hostFrame, "TOP", 0, -cursorY)
		label:SetText(GetCategoryLabel(row.category))
		label:Show()
		cursorY = cursorY + (label:GetStringHeight() or 12) + 2
		local count = #(row.icons or {})
		local startX = (width - count * iconSize - math.max(0, count - 1) * columnSpacing) / 2
		for columnIndex, iconData in ipairs(row.icons or {}) do
			textureIndex = textureIndex + 1
			local texture = hostFrame.iconTextures[textureIndex]
			if not texture then
				texture = hostFrame:CreateTexture(nil, "ARTWORK")
				hostFrame.iconTextures[textureIndex] = texture
			end
			texture:SetTexture(iconData.icon or 134400)
			texture:SetSize(iconSize, iconSize)
			texture:ClearAllPoints()
			texture:SetPoint(
				"TOPLEFT",
				hostFrame,
				"TOPLEFT",
				startX + (columnIndex - 1) * (iconSize + columnSpacing),
				-cursorY
			)
			texture:Show()
		end
		cursorY = cursorY + iconSize + (rowIndex < #rows and rowSpacing or 0)
	end
	for index = textureIndex + 1, #hostFrame.iconTextures do
		hostFrame.iconTextures[index]:Hide()
	end
	for index = #rows + 1, #hostFrame.rowLabels do
		hostFrame.rowLabels[index]:Hide()
	end
	hostFrame:SetSize(width, #rows > 0 and cursorY + 10 or 1)
end

function NoPoizen:IsPoisonIndicatorInEditMode()
	return self.isEnabled == true
		and self.poisonIndicatorEditActive == true
		and self.poisonIndicatorEditSession ~= nil
		and self.poisonIndicatorEditSession.database == self.db
		and not self:IsHUDRestricted()
end

function NoPoizen:ApplySavedIndicatorAnchor()
	local hostFrame = self.poisonIndicatorHostFrame
	if not hostFrame then
		return
	end
	if not self:CanMutateHUDFrame(hostFrame) then
		self.pendingIndicatorAnchor = true
		return
	end
	self.pendingIndicatorAnchor = nil
	local anchor = self:GetIndicatorAnchor()
	hostFrame:ClearAllPoints()
	hostFrame:SetPoint(anchor.point, UIParent, anchor.relativePoint, anchor.x, anchor.y)
end

function NoPoizen:SaveIndicatorAnchorFromFrame(hostFrame)
	if not self:IsPoisonIndicatorInEditMode() or not self:CanMutateHUDFrame(hostFrame) then
		return false
	end
	local point, _, relativePoint, x, y = hostFrame:GetPoint(1)
	local changed = self:SetIndicatorAnchor(point, relativePoint, x, y)
	self:RefreshPoisonIndicatorEditDialog()
	return changed
end

function NoPoizen:EnsurePoisonIndicatorWidget()
	if self.poisonIndicatorHostFrame then
		return self.poisonIndicatorHostFrame
	end
	if not self.isEnabled or not UIParent or self:IsHUDRestricted() then
		return nil
	end
	self:EnsureHUDLifecycleFrame()
	local hostFrame = CreateFrame("Frame", "NoPoizenIndicatorAnchor", UIParent)
	hostFrame:SetSize(1, 1)
	hostFrame:SetFrameStrata("MEDIUM")
	hostFrame:SetClampedToScreen(true)
	hostFrame:SetMovable(true)
	hostFrame:RegisterForDrag("LeftButton")
	hostFrame:EnableMouse(false)
	hostFrame.iconTextures, hostFrame.rowLabels = {}, {}
	local background = hostFrame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.03, 0.03, 0.03, 0.7)
	background:Hide()
	hostFrame.EditBackground = background
	local label = hostFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("BOTTOM", hostFrame, "TOP", 0, 6)
	label:SetText("NoPoizen: drag to move")
	label:Hide()
	hostFrame.EditLabel = label
	hostFrame:SetScript("OnDragStart", function(frame)
		if self:IsPoisonIndicatorInEditMode() and self:CanMutateHUDFrame(frame) then
			frame:StartMoving()
		end
	end)
	hostFrame:SetScript("OnDragStop", function(frame)
		if self:CanMutateHUDFrame(frame) then
			frame:StopMovingOrSizing()
			-- Ignore a drag callback left over from a cancelled/disabled edit session.
			self:SaveIndicatorAnchorFromFrame(frame)
		end
	end)
	hostFrame:Hide()
	self.poisonIndicatorHostFrame = hostFrame
	self:ApplySavedIndicatorAnchor()
	return hostFrame
end

local function EnsureEditDialog(owner)
	if owner.poisonIndicatorEditDialog then
		return owner.poisonIndicatorEditDialog
	end
	if owner:IsHUDRestricted() then
		return nil
	end
	local dialog = CreateFrame("Frame", "NoPoizenIndicatorSettingsDialog", UIParent)
	dialog:SetSize(360, 216)
	dialog:SetPoint("CENTER", UIParent, "CENTER", 330, 0)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetClampedToScreen(true)
	dialog:EnableMouse(true)
	dialog:Hide()
	local background = dialog:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.06, 0.06, 0.06, 0.96)
	local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	title:SetPoint("TOP", 0, -16)
	title:SetText("NoPoizen Position and Scale")
	local hint = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOP", title, "BOTTOM", 0, -10)
	hint:SetText("Drag the indicator, then save your changes.")
	local slider = CreateFrame("Slider", nil, dialog, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", 24, -84)
	slider:SetPoint("TOPRIGHT", -24, -84)
	slider:SetMinMaxValues(owner.WIDGET_SCALE_MIN, owner.WIDGET_SCALE_MAX)
	slider:SetValueStep(owner.WIDGET_SCALE_STEP)
	if slider.SetObeyStepOnDrag then
		slider:SetObeyStepOnDrag(true)
	end
	if slider.Text then
		slider.Text:SetText("Indicator Scale")
	end
	if slider.Low then
		slider.Low:SetText(string.format("%.1fx", owner.WIDGET_SCALE_MIN))
	end
	if slider.High then
		slider.High:SetText(string.format("%.1fx", owner.WIDGET_SCALE_MAX))
	end
	local valueText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	valueText:SetPoint("TOP", slider, "BOTTOM", 0, -4)
	dialog.ScaleSlider, dialog.ScaleValueText = slider, valueText
	slider:SetScript("OnValueChanged", function(_, value)
		if dialog.updatingSlider or not owner:IsPoisonIndicatorInEditMode() then
			return
		end
		local normalized = owner:NormalizeWidgetScale(value)
		if normalized then
			owner:SetOption("widgetScale", normalized)
			owner:RefreshPoisonIndicatorEditDialog()
		end
	end)
	local function AddButton(text, x, y, callback)
		local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
		button:SetSize(148, 24)
		button:SetPoint("BOTTOMLEFT", x, y)
		button:SetText(text)
		button:SetScript("OnClick", callback)
		return button
	end
	dialog.RevertButton = AddButton("Revert Changes", 24, 52, function()
		owner:RevertPoisonIndicatorEditSession()
	end)
	AddButton("Reset To Default", 188, 52, function()
		owner:ResetPoisonIndicatorEditSessionToDefaults()
	end)
	AddButton("Save", 24, 18, function()
		owner:EndPoisonIndicatorEditMode(true)
	end)
	AddButton("Cancel", 188, 18, function()
		owner:EndPoisonIndicatorEditMode(false)
	end)
	dialog:SetScript("OnHide", function()
		if owner.poisonIndicatorEditActive then
			owner:EndPoisonIndicatorEditMode(false)
		end
	end)
	owner.poisonIndicatorEditDialog = dialog
	return dialog
end

function NoPoizen:RefreshPoisonIndicatorEditDialog()
	local dialog = self.poisonIndicatorEditDialog
	if not dialog or not self:CanMutateHUDFrame(dialog) then
		return
	end
	local scale = self:NormalizeWidgetScale(self:GetOption("widgetScale")) or self.DEFAULTS.widgetScale
	dialog.updatingSlider = true
	dialog.ScaleSlider:SetValue(scale)
	dialog.ScaleValueText:SetText(string.format("%.2fx", scale))
	dialog.updatingSlider = false
	local session = self.poisonIndicatorEditSession
	dialog.RevertButton:SetEnabled(session ~= nil and not IsSnapshotEqual(self, session.saved))
end

function NoPoizen:ApplyPoisonIndicatorEditSnapshot(snapshot)
	if not snapshot then
		return
	end
	self:SetOption("widgetScale", snapshot.widgetScale)
	self:SetIndicatorAnchor(snapshot.anchor.point, snapshot.anchor.relativePoint, snapshot.anchor.x, snapshot.anchor.y)
	-- A cancelled drag may move the frame before its anchor reaches saved variables.
	self:ApplySavedIndicatorAnchor()
	self:RefreshPoisonIndicatorVisualState()
	self:RefreshPoisonIndicatorEditDialog()
end

function NoPoizen:RevertPoisonIndicatorEditSession()
	if self:IsPoisonIndicatorInEditMode() and self.poisonIndicatorEditSession then
		self:ApplyPoisonIndicatorEditSnapshot(self.poisonIndicatorEditSession.saved)
	end
end

function NoPoizen:ResetPoisonIndicatorEditSessionToDefaults()
	if not self:IsPoisonIndicatorInEditMode() then
		return
	end
	self:SetOption("widgetScale", self.DEFAULTS.widgetScale)
	self:ResetIndicatorAnchor()
	self:RefreshPoisonIndicatorVisualState()
	self:RefreshPoisonIndicatorEditDialog()
end

function NoPoizen:BeginPoisonIndicatorEditMode()
	if not self.isEnabled or self.isLoadingScreenActive or self.isLoggingOut or self:IsHUDRestricted() then
		return false
	end
	local hostFrame = self:EnsurePoisonIndicatorWidget()
	if not self:CanMutateHUDFrame(hostFrame) then
		return false
	end
	local dialog = EnsureEditDialog(self)
	if not self:CanMutateHUDFrame(dialog) then
		return false
	end
	if self.poisonIndicatorEditSession and self.poisonIndicatorEditSession.database ~= self.db then
		self:EndPoisonIndicatorEditMode(false)
	end
	if not self.poisonIndicatorEditSession then
		self.poisonIndicatorEditSession = {
			database = self.db,
			saved = {
				widgetScale = self:GetOption("widgetScale"),
				anchor = self:DeepCopy(self:GetIndicatorAnchor()),
			},
		}
	end
	self.poisonIndicatorEditActive = true
	self:RefreshPoisonIndicatorVisualState()
	self:RefreshPoisonIndicatorEditDialog()
	dialog:Show()
	return true
end

function NoPoizen:EndPoisonIndicatorEditMode(save)
	local session = self.poisonIndicatorEditSession
	self.poisonIndicatorEditActive = false
	self.poisonIndicatorEditSession = nil
	local hostFrame = self.poisonIndicatorHostFrame
	if self:CanMutateHUDFrame(hostFrame) then
		hostFrame:StopMovingOrSizing()
	end
	if self:CanMutateHUDFrame(self.poisonIndicatorEditDialog) then
		self.poisonIndicatorEditDialog:Hide()
	end
	if session and session.database ~= self.db then
		-- A stale callback must not save or roll back settings in a different DB.
		-- Cancel only the preview belonging to the original session.
		session.database.widgetScale = session.saved.widgetScale
		session.database.indicatorAnchor = self:DeepCopy(session.saved.anchor)
		self:ApplySavedIndicatorAnchor()
		self:RefreshPoisonIndicatorVisualState()
	elseif session and not save then
		self:ApplyPoisonIndicatorEditSnapshot(session.saved)
	else
		self:RefreshPoisonIndicatorVisualState()
	end
end

function NoPoizen:DeselectPoisonIndicatorAnchor()
	self:EndPoisonIndicatorEditMode(false)
end

function NoPoizen:RefreshPoisonIndicatorVisualState()
	local hostFrame = self.poisonIndicatorHostFrame
	if not hostFrame and self.isEnabled and not self.isLoadingScreenActive then
		hostFrame = self:EnsurePoisonIndicatorWidget()
	end
	if not self:CanMutateHUDFrame(hostFrame) then
		return
	end
	local editing = self:IsPoisonIndicatorInEditMode()
	local state = self.currentPoisonState or {}
	local rows = state.indicatorRows or {}
	if editing then
		rows = GetDefaultEditModeRows(self)
	end
	local visible = not self.isLoadingScreenActive
		and (editing or (self.isEnabled and state.showIndicator))
		and #rows > 0
	if visible then
		LayoutIndicatorRows(hostFrame, rows)
		hostFrame:SetScale(self:NormalizeWidgetScale(self:GetOption("widgetScale")) or self.DEFAULTS.widgetScale)
		hostFrame:Show()
	else
		hostFrame:Hide()
	end
	hostFrame:EnableMouse(editing)
	hostFrame.EditBackground:SetShown(editing and visible)
	hostFrame.EditLabel:SetShown(editing and visible)
end

function NoPoizen:UpdatePoisonIndicator(state)
	self.currentPoisonState = state
	self:RefreshPoisonIndicatorVisualState()
end
