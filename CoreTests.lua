local NoPoizen = _G.NoPoizen
local function Equal(actual, expected)
	assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Fixture()
	local f = NoPoizen:CreateTestFixture()
	f.RefreshPoisonState = function(owner, reason)
		owner.refreshes = (owner.refreshes or 0) + 1
		owner.reason = reason
	end
	f.audioArmToken, f.postLoadRefreshToken, f.restrictionRefreshToken = 0, 0, 0
	f.postLoadRefreshAt, f.isLoadingScreenActive = 0, false
	return f
end

NoPoizen:RegisterTest("core malformed anchors and nonfinite settings are rejected", function()
	local f = Fixture()
	for _, value in ipairs({ false, "broken", math.huge, -math.huge, 0 / 0, {} }) do
		Equal(f:NormalizeWidgetScale(value), nil)
		Equal(f:NormalizeAudioVolume(value), nil)
	end
	f.db.indicatorAnchor = "corrupt"
	Equal(f:GetIndicatorAnchor().y, 140)
	f.db.indicatorAnchor = { point = "MIDDLE", relativePoint = {}, x = 0 / 0, y = 1e99 }
	Equal(f:GetIndicatorAnchor().point, "CENTER")
	Equal(f:GetIndicatorAnchor().y, 140)
	Equal(f:SetIndicatorAnchor("BAD", "CENTER", 0, 0), false)
	Equal(f:SetIndicatorAnchor("CENTER", "CENTER", math.huge, 0), false)
	Equal(f:SetOption("enabled", "false"), false)
end)

NoPoizen:RegisterTest("core baseline timer expires without waiting for next aura event", function()
	local f = Fixture()
	f:ResetAudioTransitionArming(5)
	Equal(f.audioTransitionsArmAt, 15)
	Equal(#f.callbacks, 1)
	f.now = 15
	f.callbacks[1]()
	Equal(f.refreshes, 1)
	Equal(f.reason, "AUDIO_BASELINE")
end)

NoPoizen:RegisterTest("core replaced startup and loading timers cannot run stale work", function()
	local f = Fixture()
	f:ResetAudioTransitionArming(5)
	local first = f.callbacks[1]
	f:ResetAudioTransitionArming(5)
	first()
	Equal(f.refreshes, nil)
	f:SchedulePostLoadPoisonRefresh(1)
	f.callbacks[2]()
	Equal(f.refreshes, nil)
	local loading = f.callbacks[3]
	f:Disable()
	f:Enable()
	f.refreshes = 0
	loading()
	Equal(f.refreshes, 0)
end)

NoPoizen:RegisterTest("core loading clears stale state and invalidates prior refresh", function()
	local f = Fixture()
	f.currentPoisonState = { hasMissing = true, showIndicator = true }
	f:SchedulePostLoadPoisonRefresh(1)
	local old = f.callbacks[1]
	f:LOADING_SCREEN_ENABLED()
	Equal(f.currentPoisonState, nil)
	Equal(f.isLoadingScreenActive, true)
	old()
	Equal(f.refreshes, nil)
	f:LOADING_SCREEN_DISABLED()
	Equal(f.isLoadingScreenActive, false)
	f.callbacks[#f.callbacks]()
	Equal(f.reason, "POST_LOADING_REFRESH")
end)

NoPoizen:RegisterTest("core restriction refresh coalesces and cannot survive disable", function()
	local f = Fixture()
	f:ADDON_RESTRICTION_STATE_CHANGED()
	f:ADDON_RESTRICTION_STATE_CHANGED()
	f.callbacks[1]()
	Equal(f.refreshes, nil)
	f.callbacks[2]()
	Equal(f.refreshes, 1)
	f:ADDON_RESTRICTION_STATE_CHANGED()
	f:Disable()
	f.callbacks[3]()
	Equal(f.refreshes, 1)
end)

NoPoizen:RegisterTest("core event capability failure does not abort remaining registration", function()
	local f = Fixture()
	f.eventFrame.RegisterEvent = function(_, event)
		if event == "TRAIT_CONFIG_UPDATED" then
			error("unsupported")
		end
		return true
	end
	f:RegisterRuntimeEvents()
	Equal(f.registeredRuntimeEvents.TRAIT_CONFIG_UPDATED, nil)
	Equal(f.registeredRuntimeEvents.PLAYER_REGEN_ENABLED, true)
end)

NoPoizen:RegisterTest("core foreign unit values and class failures are ignored", function()
	local f = Fixture()
	local denied = setmetatable({}, {
		__tostring = function()
			error("secret formatted")
		end,
	})
	f.CanAccessValue = function(_, value)
		return value ~= denied
	end
	f:UNIT_AURA(nil, denied)
	f:UNIT_INVENTORY_CHANGED(nil, denied)
	f:PLAYER_SPECIALIZATION_CHANGED(nil, denied)
	Equal(f.refreshes, nil)
	Equal(f:SafeToString(denied), "<unavailable>")
	f.API.UnitClass = function()
		return "Class", denied
	end
	Equal(f:GetPlayerClassFile(), nil)
	f.API.UnitClass = function()
		error("unavailable")
	end
	Equal(f:GetPlayerClassFile(), nil)
end)

NoPoizen:RegisterTest("audio each slider step selects isolated attenuation without timers", function()
	local f = Fixture()
	for percent = 5, 100, 5 do
		f.db.audioVolume = percent / 100
		Equal(f:PlayMissingPoisonSound(), true)
		Equal(
			f.sounds[#f.sounds].path,
			string.format("Interface\\AddOns\\NoPoizen\\sounds\\nopoizen-%03d.ogg", percent)
		)
	end
	Equal(#f.callbacks, 0)
	Equal(#f.sounds, 20)
	f.db.audioVolume = 0
	Equal(f:PlayMissingPoisonSound(), false)
	Equal(#f.sounds, 20)
	f.db.satisfiedAudioVolume = 0.75
	Equal(f:PlaySatisfiedPoisonSound(), true)
	Equal(f.sounds[21].path, "Interface\\AddOns\\NoPoizen\\sounds\\hahaha-075.ogg")
end)

NoPoizen:RegisterTest("audio unavailable playback is contained", function()
	local f = Fixture()
	f.API.PlaySoundFile = function()
		error("unavailable")
	end
	Equal(f:PlayMissingPoisonSound(), false)
	Equal(#f.callbacks, 0)
end)

NoPoizen:RegisterTest("diagnostics history is bounded and does not stringify foreign objects", function()
	local f = Fixture()
	f.diagnosticSequence, f.diagnosticDropped = 0, 0
	f.LogDiagnostic = NoPoizen.LogDiagnostic
	local object = setmetatable({}, {
		__tostring = function()
			error("must not stringify")
		end,
	})
	Equal(f:SafeToString(object), "<table>")
	for i = 1, 100 do
		f:LogDiagnostic("event", string.rep("x", 1000))
	end
	Equal(#f.diagnosticLog, 60)
	Equal(f.diagnosticDropped, 40)
	assert(#f.diagnosticLog[60] < 290)
end)

NoPoizen:RegisterTest("core false event registration result is not recorded as active", function()
	local f = Fixture()
	f.eventFrame.RegisterEvent = function()
		return false
	end
	f:RegisterRuntimeEvents()
	Equal(next(f.registeredRuntimeEvents), nil)
end)
