local addonName, addonTable = ...

local NoPoizen = addonTable or {}
_G.NoPoizen = NoPoizen

NoPoizen.addonName = addonName or "NoPoizen"
NoPoizen.MISSING_SOUND_FILE_PATH = "Interface\\AddOns\\NoPoizen\\nopoizen.wav"
NoPoizen.SATISFIED_SOUND_FILE_PATH = "Interface\\AddOns\\NoPoizen\\hahaha.wav"
NoPoizen.DRAGON_TEMPERED_BLADES_SPELL_ID = 381801

NoPoizen.WIDGET_SCALE_MIN = 0.6
NoPoizen.WIDGET_SCALE_MAX = 2.0
NoPoizen.WIDGET_SCALE_STEP = 0.05
NoPoizen.AUDIO_VOLUME_MIN = 0
NoPoizen.AUDIO_VOLUME_MAX = 1
NoPoizen.AUDIO_VOLUME_STEP = 0.05
NoPoizen.AUDIO_TRANSITION_ARM_DELAY_SECONDS = 5.0
NoPoizen.POST_LOAD_POISON_REFRESH_DELAY_SECONDS = 1.5

NoPoizen.DEFAULT_INDICATOR_ANCHOR = {
	point = "CENTER",
	relativePoint = "CENTER",
	x = 0,
	y = 140,
}

NoPoizen.DEFAULTS = {
	enabled = true,
	showVisualIndicator = true,
	playAudioIndicator = true,
	audioVolume = 0.5,
	playSatisfiedAudioIndicator = true,
	satisfiedAudioVolume = 0.5,
	widgetScale = 1.0,
	indicatorAnchor = {
		point = "CENTER",
		relativePoint = "CENTER",
		x = 0,
		y = 140,
	},
}

NoPoizen.isInitialized = NoPoizen.isInitialized or false
NoPoizen.hasLoggedIn = NoPoizen.hasLoggedIn or false
NoPoizen.isEnabled = NoPoizen.isEnabled or false
NoPoizen.audioMissingState = NoPoizen.audioMissingState or false
NoPoizen.audioTransitionsArmed = NoPoizen.audioTransitionsArmed or false
NoPoizen.audioTransitionsArmAt = NoPoizen.audioTransitionsArmAt or 0
NoPoizen.isLoadingScreenActive = NoPoizen.isLoadingScreenActive or false
NoPoizen.postLoadRefreshAt = NoPoizen.postLoadRefreshAt or 0
NoPoizen.postLoadRefreshToken = NoPoizen.postLoadRefreshToken or 0

NoPoizen.runtimeEvents = {
	"PLAYER_ENTERING_WORLD",
	"LOADING_SCREEN_ENABLED",
	"LOADING_SCREEN_DISABLED",
	"UNIT_AURA",
	"SPELLS_CHANGED",
	"PLAYER_TALENT_UPDATE",
	"ACTIVE_TALENT_GROUP_CHANGED",
	"PLAYER_SPECIALIZATION_CHANGED",
	"TRAIT_CONFIG_UPDATED",
	"TRAIT_CONFIG_LIST_UPDATED",
	"PLAYER_REGEN_ENABLED",
	"PLAYER_ALIVE",
	"PLAYER_EQUIPMENT_CHANGED",
	"UNIT_INVENTORY_CHANGED",
	"ADDON_RESTRICTION_STATE_CHANGED",
}

NoPoizen.API = NoPoizen.API
	or {
		Delay = function(delaySeconds, callbackFn)
			if C_Timer and C_Timer.After then
				C_Timer.After(delaySeconds, callbackFn)
			end
		end,
		GetAddOnVersion = function(addon)
			if C_AddOns and C_AddOns.GetAddOnMetadata then
				return C_AddOns.GetAddOnMetadata(addon, "Version")
			end
		end,
		UnitClass = function(unit)
			return UnitClass(unit)
		end,
		PlaySoundFile = function(path, channel)
			return PlaySoundFile(path, channel)
		end,
		GetTime = function()
			return GetTime and GetTime() or 0
		end,
	}

-- These gates run before comparisons, indexing or formatting foreign values.
-- pcall contains API errors; it does not make tainted data secure.
function NoPoizen:CanAccessValue(value)
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret then
			return false
		end
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	return true
end

function NoPoizen:CanAccessTable(value)
	if not self:CanAccessValue(value) or type(value) ~= "table" then
		return false
	end
	if type(canaccesstable) == "function" then
		local ok, accessible = pcall(canaccesstable, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	return true
end

function NoPoizen:IsFiniteNumber(value)
	return self:CanAccessValue(value)
		and type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

function NoPoizen:ToFiniteNumber(value)
	if not self:CanAccessValue(value) then
		return nil
	end
	if type(value) ~= "number" and type(value) ~= "string" then
		return nil
	end
	local number = tonumber(value)
	return self:IsFiniteNumber(number) and number or nil
end

function NoPoizen:SafeToString(value, fallback)
	if not self:CanAccessValue(value) then
		return "<unavailable>"
	end
	if value == nil then
		return fallback or ""
	end
	local kind = type(value)
	if kind ~= "string" and kind ~= "number" and kind ~= "boolean" then
		return "<" .. kind .. ">"
	end
	return tostring(value)
end

function NoPoizen:DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in pairs(value) do
		copy[key] = self:DeepCopy(item)
	end
	return copy
end

function NoPoizen:ApplyDefaults(destination, defaults)
	if type(destination) ~= "table" or type(defaults) ~= "table" then
		return destination
	end

	for key, defaultValue in pairs(defaults) do
		if destination[key] == nil then
			destination[key] = self:DeepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(destination[key]) == "table" then
			self:ApplyDefaults(destination[key], defaultValue)
		end
	end

	return destination
end

function NoPoizen:Print(message)
	local text = "|cffff4f4fNoPoizen|r: " .. self:SafeToString(message)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(text)
	else
		print("NoPoizen:", self:SafeToString(message))
	end
end

function NoPoizen:GetPlayerClassFile()
	local ok, _, classFile = pcall(self.API.UnitClass, "player")
	if ok and self:CanAccessValue(classFile) and type(classFile) == "string" then
		return classFile
	end
	return nil
end

function NoPoizen:IsPlayerRogue()
	return self:GetPlayerClassFile() == "ROGUE"
end

function NoPoizen:NormalizeWidgetScale(value)
	local numberValue = self:ToFiniteNumber(value)
	if not numberValue then
		return nil
	end
	local step = self.WIDGET_SCALE_STEP
	numberValue = math.floor((numberValue / step) + 0.5) * step
	numberValue = math.floor((numberValue * 100) + 0.5) / 100
	if numberValue < self.WIDGET_SCALE_MIN or numberValue > self.WIDGET_SCALE_MAX then
		return nil
	end
	return numberValue
end

function NoPoizen:NormalizeAudioVolume(value)
	local numberValue = self:ToFiniteNumber(value)
	if not numberValue then
		return nil
	end
	local step = self.AUDIO_VOLUME_STEP
	numberValue = math.floor((numberValue / step) + 0.5) * step
	numberValue = math.floor((numberValue * 100) + 0.5) / 100
	if numberValue < self.AUDIO_VOLUME_MIN or numberValue > self.AUDIO_VOLUME_MAX then
		return nil
	end
	return numberValue
end

function NoPoizen:GetEffectiveAudioVolume(value)
	local normalized = self:NormalizeAudioVolume(value)
	if not normalized then
		normalized = self:NormalizeAudioVolume(self:GetOption("audioVolume")) or self.DEFAULTS.audioVolume
	end
	return normalized
end

function NoPoizen:ResetAudioTransitionArming(delaySeconds)
	local delay = self:ToFiniteNumber(delaySeconds)
	if not delay or delay < 0 then
		delay = self.AUDIO_TRANSITION_ARM_DELAY_SECONDS
	end

	local now = 0
	if self.API and self.API.GetTime then
		now = tonumber(self.API.GetTime()) or 0
	elseif GetTime then
		now = tonumber(GetTime()) or 0
	end

	self.audioMissingState = false
	self.audioTransitionsArmed = false
	self.audioTransitionsArmAt = now + delay
	self.audioArmToken = (self.audioArmToken or 0) + 1
	local token, lifetime = self.audioArmToken, self.postLoadRefreshToken
	self.API.Delay(delay, function()
		if
			self.isEnabled
			and not self.isLoggingOut
			and token == self.audioArmToken
			and lifetime == self.postLoadRefreshToken
			and not self.isLoadingScreenActive
		then
			self:RefreshPoisonState("AUDIO_BASELINE")
		end
	end)
end

function NoPoizen:SchedulePostLoadPoisonRefresh(delaySeconds)
	local delay = self:ToFiniteNumber(delaySeconds)
	if not delay or delay < 0 then
		delay = self.POST_LOAD_POISON_REFRESH_DELAY_SECONDS
	end

	local now = 0
	if self.API and self.API.GetTime then
		now = tonumber(self.API.GetTime()) or 0
	elseif GetTime then
		now = tonumber(GetTime()) or 0
	end

	self.postLoadRefreshAt = now + delay
	self.postLoadRefreshToken = (self.postLoadRefreshToken or 0) + 1
	local scheduledToken = self.postLoadRefreshToken

	self.audioArmToken = (self.audioArmToken or 0) + 1
	-- Arm transition audio no earlier than the first post-loading refresh.
	self.audioTransitionsArmed = false
	self.audioTransitionsArmAt = self.postLoadRefreshAt

	if self.API and self.API.Delay then
		self.API.Delay(delay, function()
			if scheduledToken ~= self.postLoadRefreshToken then
				return
			end
			if not self.isEnabled or self.isLoggingOut or self.isLoadingScreenActive then
				return
			end
			if self.RefreshPoisonState then
				self:RefreshPoisonState("POST_LOADING_REFRESH")
			end
		end)
	end
end

function NoPoizen:InitializeDatabase()
	if type(_G.NoPoizenDBChar) ~= "table" then
		_G.NoPoizenDBChar = {}
	end
	self.db = _G.NoPoizenDBChar
	self:ApplyDefaults(self.db, self.DEFAULTS)

	self.db.widgetScale = self:NormalizeWidgetScale(self.db.widgetScale) or self.DEFAULTS.widgetScale
	self.db.audioVolume = self:NormalizeAudioVolume(self.db.audioVolume) or self.DEFAULTS.audioVolume
	self.db.satisfiedAudioVolume = self:NormalizeAudioVolume(self.db.satisfiedAudioVolume)
		or self.DEFAULTS.satisfiedAudioVolume
	for _, key in ipairs({ "enabled", "showVisualIndicator", "playAudioIndicator", "playSatisfiedAudioIndicator" }) do
		if type(self.db[key]) ~= "boolean" then
			self.db[key] = self.DEFAULTS[key]
		end
	end
	self.db.indicatorAnchor = self:GetIndicatorAnchor()
end

function NoPoizen:GetOption(optionKey)
	if not self.db then
		return nil
	end
	return self.db[optionKey]
end

function NoPoizen:SetOption(optionKey, value)
	if not self.db then
		return false
	end

	local normalizedValue = value
	if
		optionKey == "showVisualIndicator"
		or optionKey == "playAudioIndicator"
		or optionKey == "playSatisfiedAudioIndicator"
		or optionKey == "enabled"
	then
		if not self:CanAccessValue(value) or type(value) ~= "boolean" then
			return false
		end
		normalizedValue = value
	elseif optionKey == "widgetScale" then
		normalizedValue = self:NormalizeWidgetScale(value)
		if not normalizedValue then
			return false
		end
	elseif optionKey == "audioVolume" or optionKey == "satisfiedAudioVolume" then
		normalizedValue = self:NormalizeAudioVolume(value)
		if not normalizedValue then
			return false
		end
	else
		return false
	end

	local oldValue = self.db[optionKey]
	if oldValue == normalizedValue then
		return true
	end
	self.db[optionKey] = normalizedValue

	if optionKey == "enabled" then
		if normalizedValue then
			self:Enable()
		else
			self:Disable()
		end
	else
		if self.RefreshPoisonState then
			self:RefreshPoisonState("OPTION_CHANGED")
		end
		if self.RefreshPoisonIndicatorVisualState then
			self:RefreshPoisonIndicatorVisualState()
		end
	end

	if self.RefreshOptionsWindow then
		self:RefreshOptionsWindow()
	end

	return true
end

local anchorPoints = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}

function NoPoizen:IsAnchorPoint(point)
	return self:CanAccessValue(point) and type(point) == "string" and anchorPoints[point] == true
end

function NoPoizen:GetIndicatorAnchor()
	local anchor = self.db and self.db.indicatorAnchor
	if not self:CanAccessTable(anchor) then
		anchor = self.DEFAULT_INDICATOR_ANCHOR
	end
	local x, y = self:ToFiniteNumber(anchor.x), self:ToFiniteNumber(anchor.y)
	return {
		point = self:IsAnchorPoint(anchor.point) and anchor.point or self.DEFAULT_INDICATOR_ANCHOR.point,
		relativePoint = self:IsAnchorPoint(anchor.relativePoint) and anchor.relativePoint
			or self.DEFAULT_INDICATOR_ANCHOR.relativePoint,
		x = x and math.abs(x) <= 10000 and x or self.DEFAULT_INDICATOR_ANCHOR.x,
		y = y and math.abs(y) <= 10000 and y or self.DEFAULT_INDICATOR_ANCHOR.y,
	}
end

function NoPoizen:SetIndicatorAnchor(point, relativePoint, x, y)
	if not self.db then
		return false
	end
	if not self:IsAnchorPoint(point) or not self:IsAnchorPoint(relativePoint) then
		return false
	end

	local roundedX = self:ToFiniteNumber(x)
	local roundedY = self:ToFiniteNumber(y)
	if not roundedX or not roundedY or math.abs(roundedX) > 10000 or math.abs(roundedY) > 10000 then
		return false
	end
	if roundedX >= 0 then
		roundedX = math.floor(roundedX + 0.5)
	else
		roundedX = math.ceil(roundedX - 0.5)
	end
	if roundedY >= 0 then
		roundedY = math.floor(roundedY + 0.5)
	else
		roundedY = math.ceil(roundedY - 0.5)
	end

	local existing = self:GetIndicatorAnchor()
	local changed = existing.point ~= point
		or existing.relativePoint ~= relativePoint
		or existing.x ~= roundedX
		or existing.y ~= roundedY
	if not changed then
		return false
	end

	self.db.indicatorAnchor = {
		point = point,
		relativePoint = relativePoint,
		x = roundedX,
		y = roundedY,
	}
	if self.ApplySavedIndicatorAnchor then
		self:ApplySavedIndicatorAnchor()
	end
	return true
end

function NoPoizen:ResetIndicatorAnchor()
	return self:SetIndicatorAnchor(
		self.DEFAULT_INDICATOR_ANCHOR.point,
		self.DEFAULT_INDICATOR_ANCHOR.relativePoint,
		self.DEFAULT_INDICATOR_ANCHOR.x,
		self.DEFAULT_INDICATOR_ANCHOR.y
	)
end

-- Custom file playback has no documented volume override. Select pre-attenuated
-- addon assets instead of changing a shared sound-channel CVar and restoring later.
function NoPoizen:GetAlertSoundPath(soundFilePath, volume)
	local stem
	if soundFilePath == self.MISSING_SOUND_FILE_PATH then
		stem = "nopoizen"
	elseif soundFilePath == self.SATISFIED_SOUND_FILE_PATH then
		stem = "hahaha"
	else
		return nil
	end
	local normalized = self:NormalizeAudioVolume(volume)
	if not normalized or normalized <= 0 then
		return nil
	end
	return string.format("Interface\\AddOns\\NoPoizen\\sounds\\%s-%03d.ogg", stem, math.floor(normalized * 100 + 0.5))
end

function NoPoizen:PlayAlertSound(soundFilePath, volumeOptionKey)
	local path = self:GetAlertSoundPath(soundFilePath, self:GetEffectiveAudioVolume(self:GetOption(volumeOptionKey)))
	if not path then
		return false
	end
	local ok, willPlay = pcall(self.API.PlaySoundFile, path, "Master")
	local played = ok and self:CanAccessValue(willPlay) and willPlay == true
	self:LogDiagnostic("audio", played and "played" or "unavailable")
	return played
end

function NoPoizen:PlayMissingPoisonSound()
	return self:PlayAlertSound(self.MISSING_SOUND_FILE_PATH, "audioVolume")
end

function NoPoizen:PlaySatisfiedPoisonSound()
	return self:PlayAlertSound(self.SATISFIED_SOUND_FILE_PATH, "satisfiedAudioVolume")
end

function NoPoizen:RegisterRuntimeEvents()
	self.registeredRuntimeEvents = self.registeredRuntimeEvents or {}
	wipe(self.registeredRuntimeEvents)

	for _, eventName in ipairs(self.runtimeEvents) do
		local ok, registered
		if
			(eventName == "UNIT_AURA" or eventName == "UNIT_INVENTORY_CHANGED") and self.eventFrame.RegisterUnitEvent
		then
			ok, registered = pcall(self.eventFrame.RegisterUnitEvent, self.eventFrame, eventName, "player")
		else
			ok, registered = pcall(self.eventFrame.RegisterEvent, self.eventFrame, eventName)
		end
		if ok and self:CanAccessValue(registered) and registered == true then
			self.registeredRuntimeEvents[eventName] = true
		else
			self:LogDiagnostic("event-unavailable", eventName)
		end
	end
end

function NoPoizen:UnregisterRuntimeEvents()
	for eventName in pairs(self.registeredRuntimeEvents or {}) do
		self.eventFrame:UnregisterEvent(eventName)
	end
	if self.registeredRuntimeEvents then
		wipe(self.registeredRuntimeEvents)
	end
end

function NoPoizen:Enable()
	if not self.db then
		return false
	end
	self.db.enabled = true

	if not self.hasLoggedIn then
		return true
	end
	if self.isEnabled then
		return true
	end

	self:RegisterRuntimeEvents()
	self.isEnabled = true
	self.isLoadingScreenActive = false
	self.postLoadRefreshAt = 0
	self.postLoadRefreshToken = (self.postLoadRefreshToken or 0) + 1
	self:ResetAudioTransitionArming()

	if self.EnsurePoisonIndicatorWidget then
		self:EnsurePoisonIndicatorWidget()
	end
	if self.RefreshPoisonState then
		self:RefreshPoisonState("ENABLE")
	end
	if self.RefreshPoisonIndicatorVisualState then
		self:RefreshPoisonIndicatorVisualState()
	end
	return true
end

function NoPoizen:Disable()
	if not self.db then
		return false
	end
	self.db.enabled = false

	self.isEnabled = false
	if self.EndPoisonIndicatorEditMode then
		self:EndPoisonIndicatorEditMode(false)
	end
	self.currentPoisonState = nil
	self:UnregisterRuntimeEvents()
	self.isLoadingScreenActive = false
	self.postLoadRefreshAt = 0
	self.postLoadRefreshToken = (self.postLoadRefreshToken or 0) + 1
	self.audioMissingState = false
	self.audioTransitionsArmed = false
	self.audioTransitionsArmAt = 0
	self.audioBaselinePending = true
	if self.RefreshPoisonIndicatorVisualState then
		self:RefreshPoisonIndicatorVisualState()
	end
	return true
end

function NoPoizen:OpenHudEditMode()
	return self.BeginPoisonIndicatorEditMode and self:BeginPoisonIndicatorEditMode() or false
end

function NoPoizen:InitializeSlashCommands()
	SLASH_NOPOIZEN1 = "/nopoizen"
	SLASH_NOPOIZEN2 = "/np"
	SlashCmdList.NOPOIZEN = function(input)
		NoPoizen:HandleSlashCommand(input or "")
	end
end

function NoPoizen:HandleSlashCommand(input)
	local command = string.match(input or "", "^(%S+)") or ""
	command = string.lower(command)

	if command == "" or command == "options" then
		if not self:OpenOptionsWindow() then
			self:Print("Options are unavailable right now.")
		end
		return
	end
	if command == "edit" then
		if not self:OpenHudEditMode() then
			self:Print("Position editor unavailable while disabled, loading, or restricted.")
		end
		return
	end
	if command == "diagnostics" or command == "diag" then
		self:ShowDiagnostics()
		return
	end
	if command == "test" then
		if self.RunTests then
			self:RunTests()
		else
			self:Print("Tests are unavailable.")
		end
		return
	end
	if command == "enable" then
		self:SetOption("enabled", true)
		self:Print("NoPoizen enabled.")
		return
	end
	if command == "disable" then
		self:SetOption("enabled", false)
		self:Print("NoPoizen disabled.")
		return
	end

	self:Print("Commands: /nopoizen options | edit | enable | disable | test | diagnostics")
end

function NoPoizen:OnInitialize()
	self:InitializeDatabase()
	self:InitializeSlashCommands()
	if self.InitializeOptionsWindow then
		self:InitializeOptionsWindow()
	end
	self.isInitialized = true
end

function NoPoizen:OnLogin()
	self.hasLoggedIn = true
	if self:GetOption("enabled") then
		self:Enable()
	else
		self:Disable()
	end
end

function NoPoizen:ADDON_LOADED(_, loadedAddonName)
	if loadedAddonName ~= self.addonName then
		return
	end
	if not self.isInitialized then
		self:OnInitialize()
	end
end

function NoPoizen:PLAYER_LOGIN()
	if not self.isInitialized then
		self:OnInitialize()
	end
	self:OnLogin()
end

function NoPoizen:PLAYER_ENTERING_WORLD()
	if self.isEnabled then
		if self.isLoadingScreenActive or (tonumber(self.postLoadRefreshAt) or 0) > 0 then
			return
		end
		self:ResetAudioTransitionArming()
	end
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("PLAYER_ENTERING_WORLD")
	end
end

function NoPoizen:LOADING_SCREEN_ENABLED()
	if not self.isEnabled then
		return
	end
	self.isLoadingScreenActive = true
	if self.EndPoisonIndicatorEditMode then
		self:EndPoisonIndicatorEditMode(false)
	end
	self.currentPoisonState = nil
	if self.RefreshPoisonIndicatorVisualState then
		self:RefreshPoisonIndicatorVisualState()
	end
	self.postLoadRefreshAt = 0
	self.postLoadRefreshToken = (self.postLoadRefreshToken or 0) + 1
	self:ResetAudioTransitionArming()
end

function NoPoizen:LOADING_SCREEN_DISABLED()
	if not self.isEnabled then
		return
	end
	self.isLoadingScreenActive = false
	self:SchedulePostLoadPoisonRefresh()
end

function NoPoizen:UNIT_AURA(_, unitToken)
	if not self.isEnabled or not self:CanAccessValue(unitToken) or unitToken ~= "player" then
		return
	end
	if self.RefreshPoisonState then
		self:RefreshPoisonState("UNIT_AURA")
	end
end

function NoPoizen:PLAYER_TALENT_UPDATE()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("PLAYER_TALENT_UPDATE")
	end
end

function NoPoizen:SPELLS_CHANGED()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("SPELLS_CHANGED")
	end
end

function NoPoizen:ACTIVE_TALENT_GROUP_CHANGED()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("ACTIVE_TALENT_GROUP_CHANGED")
	end
end

function NoPoizen:PLAYER_SPECIALIZATION_CHANGED(_, unitToken)
	if not self:CanAccessValue(unitToken) or unitToken ~= "player" then
		return
	end
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("PLAYER_SPECIALIZATION_CHANGED")
	end
end

function NoPoizen:TRAIT_CONFIG_UPDATED()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("TRAIT_CONFIG_UPDATED")
	end
end

function NoPoizen:TRAIT_CONFIG_LIST_UPDATED()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("TRAIT_CONFIG_LIST_UPDATED")
	end
end

function NoPoizen:PLAYER_REGEN_ENABLED()
	if self.isEnabled then
		self:RefreshPoisonState("PLAYER_REGEN_ENABLED")
	end
end

function NoPoizen:PLAYER_ALIVE()
	if self.isEnabled then
		self:RefreshPoisonState("PLAYER_ALIVE")
	end
end

function NoPoizen:PLAYER_EQUIPMENT_CHANGED()
	if self.isEnabled then
		self:RefreshPoisonState("PLAYER_EQUIPMENT_CHANGED")
	end
end

function NoPoizen:UNIT_INVENTORY_CHANGED(_, unit)
	if self.isEnabled and self:CanAccessValue(unit) and unit == "player" then
		self:RefreshPoisonState("UNIT_INVENTORY_CHANGED")
	end
end

function NoPoizen:ADDON_RESTRICTION_STATE_CHANGED()
	-- Restriction queries report false during event dispatch: defer the observation.
	if not self.isEnabled then
		return
	end
	self.restrictionRefreshToken = (self.restrictionRefreshToken or 0) + 1
	local token, lifetime = self.restrictionRefreshToken, self.postLoadRefreshToken
	self.API.Delay(0, function()
		if
			self.isEnabled
			and not self.isLoggingOut
			and token == self.restrictionRefreshToken
			and lifetime == self.postLoadRefreshToken
		then
			self:RefreshPoisonState("ADDON_RESTRICTION_STATE_CHANGED")
		end
	end)
end

local function DispatchEvent(_, eventName, ...)
	local handler = NoPoizen[eventName]
	if type(handler) ~= "function" then
		return
	end
	local ok, err = pcall(handler, NoPoizen, eventName, ...)
	if not ok then
		NoPoizen:LogDiagnostic("event-error", eventName .. ": " .. NoPoizen:SafeToString(err))
		if type(geterrorhandler) == "function" then
			geterrorhandler()(err)
		end
	end
end

NoPoizen.eventFrame = NoPoizen.eventFrame or CreateFrame("Frame")
NoPoizen.eventFrame:SetScript("OnEvent", DispatchEvent)
NoPoizen.eventFrame:RegisterEvent("ADDON_LOADED")
NoPoizen.eventFrame:RegisterEvent("PLAYER_LOGIN")
