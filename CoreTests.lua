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

local function TestReportFixture()
	local f = Fixture()
	f.tests = { passing = function() end }
	f.messages = {}
	f.Print = function(owner, message)
		owner.messages[#owner.messages + 1] = message
	end
	f.API.GetAddOnVersion = function()
		return "fixture-version"
	end
	return f
end

NoPoizen:RegisterTest("welcome login keeps monitoring active announces once and routes addon feedback", function()
	local f = TestReportFixture()
	local handler
	f.Enable = function(owner)
		owner.isEnabled = true
	end
	f.GetWelcomeUIPolicy = f.GetDebugUIPolicy
	f.RegisterWelcomeLink = function(_, kind, callback)
		Equal(kind, "nopoizenfeedback")
		handler = callback
		return true
	end
	f:OnLogin()
	f:OnLogin()
	Equal(f.hasLoggedIn, true)
	Equal(f.isEnabled, true)
	Equal(#f.messages, 1)
	assert(f.messages[1]:find("vfixture-version loaded!", 1, true))
	assert(f.messages[1]:find("Type /np for settings.", 1, true))
	handler("nopoizenfeedback:curseforge")
	Equal(f.messages[2], "Feedback: https://www.curseforge.com/wow/addons/nopoizen")
	handler("nopoizenfeedback:github")
	Equal(f.messages[3], "Feedback: https://github.com/AlexAllocated/NoPoizen")
	f.GetWelcomeController = function()
		error("welcome unavailable")
	end
	f:OnLogin()
	Equal(f.isEnabled, true)
	Equal(#f.messages, 3)
end)

NoPoizen:RegisterTest("test runner remains headless with unchanged returns and order", function()
	local f = TestReportFixture()
	local order = {}
	f.tests = {
		a = function()
			order[#order + 1] = "a"
		end,
		b = function()
			order[#order + 1] = "b"
		end,
	}
	local function CheckReturns(...)
		Equal(select("#", ...), 3)
		local ok, passed, failed = ...
		Equal(ok, true)
		Equal(passed, 2)
		Equal(failed, 0)
	end
	CheckReturns(f:RunTests())
	Equal(table.concat(order), "ab")
	order = {}
	CheckReturns(f:RunTests(true))
	Equal(table.concat(order), "ba")
	Equal(f.diagnosticsWindow, nil)
	Equal(f.debugController, nil)
	Equal(f.diagnosticHistory, nil)
end)

NoPoizen:RegisterTest("slash test replaces test history with current shared results", function()
	local f = TestReportFixture()
	f:HandleSlashCommand("test")
	local controller = f:GetDebugController()
	local report = controller:GetText("TEST", "")
	assert(report:find("NoPoizen", 1, true))
	assert(report:find("fixture-version", 1, true))
	assert(report:find("libchev", 1, true))
	assert(report:find("1 passed, 0 failed", 1, true))
	f.tests.second = function() end
	f:HandleSlashCommand("TEST")
	Equal(f:GetDebugController(), controller)
	report = controller:GetText("TEST", "")
	assert(report:find("2 passed, 0 failed", 1, true))
	assert(not report:find("1 passed, 0 failed", 1, true))
end)

NoPoizen:RegisterTest("slash test includes failure names and details under addon policy", function()
	local f = TestReportFixture()
	f.tests.broken = function()
		error("fixture failure detail")
	end
	f:HandleSlashCommand("test")
	local report = f:GetDebugController():GetText("TEST", "")
	assert(report:find("1 passed, 1 failed", 1, true))
	assert(report:find("broken", 1, true))
	assert(report:find("fixture failure detail", 1, true))
	local ok, passed, failed = f:ShowTestResults()
	Equal(ok, false)
	Equal(passed, 1)
	Equal(failed, 1)
end)

for _, mode in ipairs({ "blocked", "missing", "throwing" }) do
	local unavailable = mode
	NoPoizen:RegisterTest("slash test chat fallback when UI is " .. unavailable, function()
		local f = TestReportFixture()
		f.GetDebugUIPolicy = function()
			return {
				restricted = function()
					return unavailable == "blocked"
				end,
				canMutate = function()
					return true
				end,
				createFrame = unavailable ~= "missing" and function()
					error("opening failed")
				end or nil,
			}
		end
		f.tests.broken = function()
			error("fallback failure detail")
		end
		f:HandleSlashCommand("test")
		local chat = table.concat(f.messages, "\n")
		assert(chat:find("1 passed, 1 failed", 1, true))
		assert(chat:find("broken", 1, true))
		assert(chat:find("fallback failure detail", 1, true))
		Equal(f.diagnosticsWindow, nil)
	end)
end

NoPoizen:RegisterTest("shared debug filters and commands use private consumer history", function()
	local f = TestReportFixture()
	f.LogDiagnostic = NoPoizen.LogDiagnostic
	f:LogDiagnostic("poison", "private poison observation")
	f:LogDiagnostic("audio", "private sound observation")
	local controller = f:GetDebugController()
	controller:SetCategory("POISON")
	controller:SetSearch("observation")
	local text = controller:GetText()
	assert(text:find("private poison observation", 1, true))
	assert(not text:find("private sound observation", 1, true))
	f:HandleSlashCommand("dump clear")
	Equal(#f.diagnosticLog, 0)
	Equal(controller:GetCategory(), "ALL")
	Equal(controller:GetSearch(), "")
end)

NoPoizen:RegisterTest("core malformed anchors and nonfinite settings are rejected", function()
	local f = Fixture()
	-- Use constants supported by the game VM; NaN cases live in the offline harness.
	for _, value in ipairs({ false, "broken", math.huge, -math.huge, {} }) do
		Equal(f:NormalizeWidgetScale(value), nil)
		Equal(f:NormalizeAudioVolume(value), nil)
	end
	f.db.indicatorAnchor = "corrupt"
	Equal(f:GetIndicatorAnchor().y, 140)
	f.db.indicatorAnchor = { point = "MIDDLE", relativePoint = {}, x = math.huge, y = 1e99 }
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
	assert(#f.diagnosticLog[60].text <= 240)
end)

NoPoizen:RegisterTest("core false event registration result is not recorded as active", function()
	local f = Fixture()
	f.eventFrame.RegisterEvent = function()
		return false
	end
	f:RegisterRuntimeEvents()
	Equal(next(f.registeredRuntimeEvents), nil)
end)

NoPoizen:RegisterTest("diagnostics structured histories remain detached between fixtures", function()
	local first, second = Fixture(), Fixture()
	first.LogDiagnostic, second.LogDiagnostic = NoPoizen.LogDiagnostic, NoPoizen.LogDiagnostic
	first:LogDiagnostic("test event", "first")
	second:LogDiagnostic("test event", "second")
	Equal(first.diagnosticLog[1].text, "first")
	Equal(second.diagnosticLog[1].text, "second")
	Equal(first.diagnosticLog[1].sequence, 1)
	Equal(first.diagnosticLog[1].category, "TEST_EVENT")
	Equal(first.diagnosticLog[1].elapsed, first.now)
	assert(first.diagnosticLog ~= second.diagnosticLog)
end)

NoPoizen:RegisterTest("diagnostics throwing and nonfinite clocks preserve error reporting", function()
	local f = Fixture()
	f.LogDiagnostic = NoPoizen.LogDiagnostic
	f.API.GetTime = function()
		error("clock unavailable")
	end
	f:LogDiagnostic("failure", "original failure")
	Equal(f.diagnosticLog[1].elapsed, nil)
	Equal(f.diagnosticLog[1].text, "original failure")
	f.API.GetTime = function()
		return math.huge
	end
	f:LogDiagnostic("failure", "nonfinite clock value")
	Equal(f.diagnosticLog[2].elapsed, nil)
	Equal(f.diagnosticLog[2].text, "nonfinite clock value")
end)

NoPoizen:RegisterTest("diagnostics common header and history use only private adapters", function()
	local f = Fixture()
	f.API.GetAddOnVersion = function()
		return "test-version"
	end
	f.API.GetBuildInfo = function()
		return "test-client", "test-build", "date", 120100
	end
	f.API.GetLocale = function()
		return "test-locale"
	end
	f.GetClientCapabilityLines = function()
		return { "private client observation" }
	end
	f.LogDiagnostic = NoPoizen.LogDiagnostic
	f:LogDiagnostic("test event", "private log message")
	assert(
		not f:BuildDiagnosticReport():find("private log message", 1, true),
		"domain callback must omit generic history"
	)
	local report = f:BuildDiagnostics()
	assert(report:find("addon=NoPoizen", 1, true))
	assert(report:find("version=test-version", 1, true))
	assert(report:find("client.locale=test-locale", 1, true))
	assert(report:find("capability.1=private client observation", 1, true))
	assert(report:find("[TEST_EVENT]", 1, true))
	assert(report:find("private log message", 1, true))
	local _, copies = report:gsub("private log message", "")
	Equal(copies, 1)
end)

NoPoizen:RegisterTest("diagnostics combined report has one overall character bound", function()
	local f = Fixture()
	f.API.GetAddOnVersion = function()
		return "test-version"
	end
	f.GetClientCapabilityLines = function()
		local rows = {}
		for i = 1, 1000 do
			rows[i] = string.rep("x", 5000)
		end
		return rows
	end
	f.LogDiagnostic = NoPoizen.LogDiagnostic
	for index = 1, 60 do
		f:LogDiagnostic("history", string.rep("x", 220) .. " recent event " .. index)
	end
	local report = f:BuildDiagnostics()
	assert(#report <= 32768)
	assert(report:find("[diagnostics truncated]", 1, true))
	assert(report:find("[older events omitted]", 1, true))
	assert(report:find("recent event 60", 1, true), "oversized domain report must retain newest history")
end)
