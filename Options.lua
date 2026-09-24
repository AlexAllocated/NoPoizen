local NoPoizen = _G.NoPoizen

if not NoPoizen then
	return
end

NoPoizen.optionControls = NoPoizen.optionControls or {}

local function CreateSectionLabel(parent, text, x, y, fontObject)
	local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlight")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetText(text)
	return label
end

local function CreateCheckbox(parent, optionKey, text, tooltipText, x, y)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
	label:SetText(text)
	checkbox.Label = label

	if type(tooltipText) == "string" and tooltipText ~= "" then
		checkbox.tooltipText = tooltipText
	end

	checkbox:SetScript("OnClick", function(self)
		NoPoizen:ApplyOptionsControlValue(optionKey, self:GetChecked() == true)
		NoPoizen:RefreshOptionsWindow()
	end)

	return checkbox
end

local function SetSliderEnabled(slider, enabled)
	if not slider then
		return
	end
	slider:SetEnabled(enabled)
	if slider.Text then
		slider.Text:SetTextColor(enabled and 1 or 0.5, enabled and 0.82 or 0.5, enabled and 0 or 0.5)
	end
	if slider.Low then
		slider.Low:SetTextColor(enabled and 1 or 0.6, enabled and 1 or 0.6, enabled and 1 or 0.6)
	end
	if slider.High then
		slider.High:SetTextColor(enabled and 1 or 0.6, enabled and 1 or 0.6, enabled and 1 or 0.6)
	end
	slider:SetAlpha(enabled and 1 or 0.5)
end

function NoPoizen:RefreshOptionsWindow()
	if not self.optionControls then
		return
	end

	local controls = self.optionControls
	controls.database = self.db
	if controls.enabled then
		controls.enabled:SetChecked(self:GetOption("enabled") == true)
	end
	if controls.showVisualIndicator then
		controls.showVisualIndicator:SetChecked(self:GetOption("showVisualIndicator") == true)
	end
	if controls.playAudioIndicator then
		controls.playAudioIndicator:SetChecked(self:GetOption("playAudioIndicator") == true)
	end
	if controls.playSatisfiedAudioIndicator then
		controls.playSatisfiedAudioIndicator:SetChecked(self:GetOption("playSatisfiedAudioIndicator") == true)
	end

	local currentVolume = self:NormalizeAudioVolume(self:GetOption("audioVolume")) or self.DEFAULTS.audioVolume
	if controls.audioVolumeSlider then
		controls.audioVolumeSlider.npUpdating = true
		controls.audioVolumeSlider:SetValue(currentVolume)
		controls.audioVolumeSlider.npUpdating = false
	end
	if controls.audioVolumeValue then
		controls.audioVolumeValue:SetText(string.format("%d%%", math.floor((currentVolume * 100) + 0.5)))
	end

	local currentSatisfiedVolume = self:NormalizeAudioVolume(self:GetOption("satisfiedAudioVolume"))
		or self.DEFAULTS.satisfiedAudioVolume
	if controls.satisfiedAudioVolumeSlider then
		controls.satisfiedAudioVolumeSlider.npUpdating = true
		controls.satisfiedAudioVolumeSlider:SetValue(currentSatisfiedVolume)
		controls.satisfiedAudioVolumeSlider.npUpdating = false
	end
	if controls.satisfiedAudioVolumeValue then
		controls.satisfiedAudioVolumeValue:SetText(
			string.format("%d%%", math.floor((currentSatisfiedVolume * 100) + 0.5))
		)
	end

	local audioEnabled = self:GetOption("playAudioIndicator") == true
	SetSliderEnabled(controls.audioVolumeSlider, audioEnabled)
	local satisfiedAudioEnabled = self:GetOption("playSatisfiedAudioIndicator") == true
	SetSliderEnabled(controls.satisfiedAudioVolumeSlider, satisfiedAudioEnabled)
end

function NoPoizen:ApplyOptionsControlValue(optionKey, value)
	if not self.optionControls or self.optionControls.database ~= self.db then
		self:RefreshOptionsWindow()
		return false
	end
	return self:SetOption(optionKey, value)
end

function NoPoizen:OpenOptionsWindow()
	if self:IsHUDRestricted() then
		return false
	end
	-- Retry registration if Settings was unavailable during ADDON_LOADED.
	self:InitializeOptionsWindow()
	if not (Settings and Settings.OpenToCategory and self.optionsCategory and self.optionsCategory.GetID) then
		return false
	end
	Settings.OpenToCategory(self.optionsCategory:GetID())
	return true
end

function NoPoizen:TryRegisterOptionsCategory()
	if self.optionsCategory then
		self.pendingOptionsRegistration = nil
		return true
	end
	self.pendingOptionsRegistration = true
	if self:IsHUDRestricted() or not self.optionsFrame then
		return false
	end
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
		return false
	end
	-- Use the supported canvas registration API; never add fields to its category.
	local category = Settings.RegisterCanvasLayoutCategory(self.optionsFrame, "NoPoizen")
	if not category then
		return false
	end
	Settings.RegisterAddOnCategory(category)
	self.optionsCategory = category
	self.pendingOptionsRegistration = nil
	return true
end

function NoPoizen:InitializeOptionsWindow()
	self:EnsureHUDLifecycleFrame()
	if self:IsHUDRestricted() then
		self.pendingOptionsRegistration = true
		return
	end
	if self.optionsFrame then
		self:TryRegisterOptionsCategory()
		return
	end

	local frame = CreateFrame("Frame", "NoPoizenOptionsPanel")
	frame.name = "NoPoizen"

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
	title:SetText("NoPoizen")

	local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetText("Rogue poison reminder settings.")

	local enabled = CreateCheckbox(frame, "enabled", "Enable NoPoizen", nil, 16, -66)
	CreateSectionLabel(frame, "Indicators", 16, -108, "GameFontHighlight")

	local showVisualIndicator = CreateCheckbox(
		frame,
		"showVisualIndicator",
		"Show visual indicator when poisons are missing",
		"Show missing poison icons near the center of the screen.",
		16,
		-132
	)

	local playAudioIndicator = CreateCheckbox(
		frame,
		"playAudioIndicator",
		"Play audio indicator when poisons are missing",
		"Play the NoPoizen alert sound once when entering a missing-poison state.",
		16,
		-160
	)

	local audioVolumeSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
	audioVolumeSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 32, -212)
	audioVolumeSlider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -212)
	audioVolumeSlider:SetMinMaxValues(self.AUDIO_VOLUME_MIN, self.AUDIO_VOLUME_MAX)
	audioVolumeSlider:SetValueStep(self.AUDIO_VOLUME_STEP)
	if audioVolumeSlider.SetObeyStepOnDrag then
		audioVolumeSlider:SetObeyStepOnDrag(true)
	end
	if audioVolumeSlider.Text then
		audioVolumeSlider.Text:SetText("Audio indicator volume")
	end
	if audioVolumeSlider.Low then
		audioVolumeSlider.Low:SetText("0%")
	end
	if audioVolumeSlider.High then
		audioVolumeSlider.High:SetText("100%")
	end

	local audioVolumeValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	audioVolumeValue:SetPoint("TOP", audioVolumeSlider, "BOTTOM", 0, -4)
	audioVolumeValue:SetText("")

	audioVolumeSlider:SetScript("OnValueChanged", function(slider, value)
		local normalized = NoPoizen:NormalizeAudioVolume(value) or NoPoizen.DEFAULTS.audioVolume
		audioVolumeValue:SetText(string.format("%d%%", math.floor((normalized * 100) + 0.5)))
		if slider.npUpdating then
			return
		end
		NoPoizen:ApplyOptionsControlValue("audioVolume", normalized)
	end)

	local playSatisfiedAudioIndicator = CreateCheckbox(
		frame,
		"playSatisfiedAudioIndicator",
		"Play sound when poison requirements are satisfied",
		"Play a sound once when transitioning from missing poisons to fully satisfied.",
		16,
		-266
	)

	local satisfiedAudioVolumeSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
	satisfiedAudioVolumeSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 32, -318)
	satisfiedAudioVolumeSlider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -318)
	satisfiedAudioVolumeSlider:SetMinMaxValues(self.AUDIO_VOLUME_MIN, self.AUDIO_VOLUME_MAX)
	satisfiedAudioVolumeSlider:SetValueStep(self.AUDIO_VOLUME_STEP)
	if satisfiedAudioVolumeSlider.SetObeyStepOnDrag then
		satisfiedAudioVolumeSlider:SetObeyStepOnDrag(true)
	end
	if satisfiedAudioVolumeSlider.Text then
		satisfiedAudioVolumeSlider.Text:SetText("Satisfied sound volume")
	end
	if satisfiedAudioVolumeSlider.Low then
		satisfiedAudioVolumeSlider.Low:SetText("0%")
	end
	if satisfiedAudioVolumeSlider.High then
		satisfiedAudioVolumeSlider.High:SetText("100%")
	end

	local satisfiedAudioVolumeValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	satisfiedAudioVolumeValue:SetPoint("TOP", satisfiedAudioVolumeSlider, "BOTTOM", 0, -4)
	satisfiedAudioVolumeValue:SetText("")

	satisfiedAudioVolumeSlider:SetScript("OnValueChanged", function(slider, value)
		local normalized = NoPoizen:NormalizeAudioVolume(value) or NoPoizen.DEFAULTS.satisfiedAudioVolume
		satisfiedAudioVolumeValue:SetText(string.format("%d%%", math.floor((normalized * 100) + 0.5)))
		if slider.npUpdating then
			return
		end
		NoPoizen:ApplyOptionsControlValue("satisfiedAudioVolume", normalized)
	end)

	self.optionControls = {
		enabled = enabled,
		showVisualIndicator = showVisualIndicator,
		playAudioIndicator = playAudioIndicator,
		audioVolumeSlider = audioVolumeSlider,
		audioVolumeValue = audioVolumeValue,
		playSatisfiedAudioIndicator = playSatisfiedAudioIndicator,
		satisfiedAudioVolumeSlider = satisfiedAudioVolumeSlider,
		satisfiedAudioVolumeValue = satisfiedAudioVolumeValue,
	}
	CreateSectionLabel(
		frame,
		"Move and scale the indicator with /np edit while out of combat.",
		16,
		-382,
		"GameFontHighlightSmall"
	)

	frame:SetScript("OnShow", function()
		NoPoizen:RefreshOptionsWindow()
	end)

	self.optionsFrame = frame

	self:TryRegisterOptionsCategory()
	self:RefreshOptionsWindow()
end
