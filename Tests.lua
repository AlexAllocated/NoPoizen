local NoPoizen = _G.NoPoizen

if not NoPoizen then
	return
end
local LibChev = NoPoizen.LibChev

NoPoizen.tests = NoPoizen.tests or {}

local function Fail(message)
	error(message or "test failed", 2)
end

local AssertEquals = LibChev.AssertEqual

local function AssertTrue(value, context)
	if not value then
		Fail((context or "assert") .. " (expected true)")
	end
end

local function FindRowByCategory(rows, category)
	for _, row in ipairs(rows or {}) do
		if row.category == category then
			return row
		end
	end
	return nil
end

function NoPoizen:RegisterTest(name, fn)
	if type(name) ~= "string" or name == "" or type(fn) ~= "function" then
		return false
	end
	self.tests[name] = fn
	return true
end

for _, case in ipairs(LibChev.SelfTests()) do
	NoPoizen:RegisterTest(case.name, case.run)
end

function NoPoizen:RunTests(reverse)
	local names, cases = {}, {}
	for name in pairs(self.tests) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		cases[#cases + 1] = { name = name, run = self.tests[name] }
	end
	local result = LibChev.RunTests(cases, {
		reverse = reverse,
		onFailure = function(failure)
			self:Print("FAIL " .. failure.name .. ": " .. failure.error)
		end,
	})
	self:Print(LibChev.TestSummary(result))
	return result.failed == 0, result.passed, result.failed
end

-- Every regression operates on a detached addon instance. No live state, frames,
-- timers, sound, saved variables or Blizzard tables are changed by /np test.
function NoPoizen:CreateTestFixture()
	local fixture = {}
	for key, value in pairs(self) do
		if type(value) == "function" or type(value) == "number" or type(value) == "string" then
			fixture[key] = value
		end
	end
	fixture.DEFAULTS = self:DeepCopy(self.DEFAULTS)
	fixture.DEFAULT_INDICATOR_ANCHOR = self:DeepCopy(self.DEFAULT_INDICATOR_ANCHOR)
	fixture.db = self:DeepCopy(self.DEFAULTS)
	fixture.runtimeEvents = self:DeepCopy(self.runtimeEvents)
	fixture.isEnabled, fixture.hasLoggedIn = true, true
	fixture.now, fixture.callbacks, fixture.sounds = 10, {}, {}
	fixture.API = {
		GetTime = function()
			return fixture.now
		end,
		Delay = function(delay, callback)
			fixture.callbacks[#fixture.callbacks + 1] = callback
		end,
		UnitClass = function()
			return "Rogue", "ROGUE"
		end,
		PlaySoundFile = function(path, channel)
			fixture.sounds[#fixture.sounds + 1] = { path = path, channel = channel }
			return true
		end,
	}
	fixture.eventFrame = {
		RegisterEvent = function()
			return true
		end,
		UnregisterEvent = function() end,
	}
	fixture.UpdatePoisonIndicator = function(f, state)
		f.lastRendered = state
	end
	fixture.RefreshPoisonIndicatorVisualState = function() end
	fixture.EnsurePoisonIndicatorWidget = function() end
	fixture.EndPoisonIndicatorEditMode = function() end
	fixture.RefreshOptionsWindow = function() end
	fixture.ApplySavedIndicatorAnchor = function() end
	fixture.Print = function(f, message)
		f.lastPrint = message
	end
	fixture.LogDiagnostic = function() end
	fixture.RecordPoisonObservation = function() end
	return fixture
end

NoPoizen:RegisterTest("required counts baseline", function()
	local counts = NoPoizen.Testables.ResolveRequiredCounts(false)
	AssertEquals(counts.lethal, 1, "baseline lethal required")
	AssertEquals(counts.nonLethal, 1, "baseline nonLethal required")
end)

NoPoizen:RegisterTest("required counts dragon tempered blades", function()
	local counts = NoPoizen.Testables.ResolveRequiredCounts(true)
	AssertEquals(counts.lethal, 2, "dtb lethal required")
	AssertEquals(counts.nonLethal, 2, "dtb nonLethal required")
end)

NoPoizen:RegisterTest("missing counts computed from active and required", function()
	local missing = NoPoizen.Testables.CalculateMissingCounts({
		lethal = 2,
		nonLethal = 1,
	}, {
		lethal = 1,
		nonLethal = 1,
	})
	AssertEquals(missing.lethal, 1, "missing lethal")
	AssertEquals(missing.nonLethal, 0, "missing nonLethal")
	AssertEquals(missing.total, 1, "missing total")
end)

NoPoizen:RegisterTest("audio does not play when disabled", function()
	local shouldPlay = NoPoizen.Testables.ShouldPlayAudio(false, true, false, 1.0)
	AssertEquals(shouldPlay, false, "audio disabled should not play")
end)

NoPoizen:RegisterTest("audio does not play when volume is zero", function()
	local shouldPlay = NoPoizen.Testables.ShouldPlayAudio(false, true, true, 0)
	AssertEquals(shouldPlay, false, "zero volume should not play")
end)

NoPoizen:RegisterTest("audio plays only on missing state transition", function()
	local first = NoPoizen.Testables.ShouldPlayAudio(false, true, true, 1.0)
	local second = NoPoizen.Testables.ShouldPlayAudio(true, true, true, 1.0)
	local recovered = NoPoizen.Testables.ShouldPlayAudio(true, false, true, 1.0)
	AssertTrue(first == true, "first transition should play")
	AssertTrue(second == false, "steady missing should not play")
	AssertTrue(recovered == false, "resolved state should not play")
end)

NoPoizen:RegisterTest("satisfied audio plays only on missing to satisfied transition", function()
	local fromMissing = NoPoizen.Testables.ShouldPlaySatisfiedAudio(true, true, true, 1.0)
	local steadySatisfied = NoPoizen.Testables.ShouldPlaySatisfiedAudio(false, true, true, 1.0)
	local stillMissing = NoPoizen.Testables.ShouldPlaySatisfiedAudio(true, false, true, 1.0)
	local disabled = NoPoizen.Testables.ShouldPlaySatisfiedAudio(true, true, false, 1.0)
	local muted = NoPoizen.Testables.ShouldPlaySatisfiedAudio(true, true, true, 0)
	AssertTrue(fromMissing == true, "transition from missing should play satisfied audio")
	AssertTrue(steadySatisfied == false, "steady satisfied should not replay")
	AssertTrue(stillMissing == false, "missing state should not play satisfied audio")
	AssertTrue(disabled == false, "disabled satisfied audio should not play")
	AssertTrue(muted == false, "muted satisfied audio should not play")
end)

NoPoizen:RegisterTest("audio arming suppresses playback before arm time", function()
	local isArmed, suppress = NoPoizen.Testables.ResolveAudioArmingState(false, 12.0, 11.9)
	AssertTrue(isArmed == false, "should remain unarmed before arm time")
	AssertTrue(suppress == true, "should suppress playback before arm time")
end)

NoPoizen:RegisterTest("audio arming seeds state at arm time without playback", function()
	local isArmed, suppress = NoPoizen.Testables.ResolveAudioArmingState(false, 12.0, 12.0)
	AssertTrue(isArmed == true, "should arm at arm time")
	AssertTrue(suppress == true, "first armed tick should still suppress playback")
end)

NoPoizen:RegisterTest("audio arming allows playback once armed", function()
	local isArmed, suppress = NoPoizen.Testables.ResolveAudioArmingState(true, 12.0, 99.0)
	AssertTrue(isArmed == true, "should stay armed")
	AssertTrue(suppress == false, "armed state should allow playback")
end)

NoPoizen:RegisterTest("indicator rows include both categories when both are missing", function()
	local rows = NoPoizen.Testables.BuildIndicatorRows({
		lethal = {
			{ spellID = 1, name = "L1", icon = 1 },
			{ spellID = 2, name = "L2", icon = 2 },
		},
		nonLethal = {
			{ spellID = 3, name = "N1", icon = 3 },
			{ spellID = 4, name = "N2", icon = 4 },
		},
	}, {
		counts = { lethal = 0, nonLethal = 0 },
		spellIDs = { lethal = {}, nonLethal = {} },
		names = { lethal = {}, nonLethal = {} },
	}, { lethal = 1, nonLethal = 1 })

	AssertEquals(#rows, 2, "should contain two rows")
	AssertEquals(rows[1].category, "lethal", "first row should be lethal")
	AssertEquals(rows[2].category, "nonLethal", "second row should be nonLethal")
	AssertEquals(#rows[1].icons, 2, "lethal icons")
	AssertEquals(#rows[2].icons, 2, "nonLethal icons")
end)

NoPoizen:RegisterTest("row disappears when category is fully applied", function()
	local rows = NoPoizen.Testables.BuildIndicatorRows({
		lethal = {
			{ spellID = 1, name = "L1", icon = 1 },
		},
		nonLethal = {
			{ spellID = 2, name = "N1", icon = 2 },
			{ spellID = 3, name = "N2", icon = 3 },
		},
	}, {
		counts = { lethal = 1, nonLethal = 0 },
		spellIDs = { lethal = { [1] = true }, nonLethal = {} },
		names = { lethal = { l1 = true }, nonLethal = {} },
	}, { lethal = 1, nonLethal = 1 })

	AssertEquals(#rows, 1, "only one row should remain")
	AssertEquals(rows[1].category, "nonLethal", "remaining row should be nonLethal")
end)

NoPoizen:RegisterTest("active poison icon is removed from category row", function()
	local rows = NoPoizen.Testables.BuildIndicatorRows({
		lethal = {
			{ spellID = 1, name = "L1", icon = 1 },
			{ spellID = 2, name = "L2", icon = 2 },
			{ spellID = 3, name = "L3", icon = 3 },
		},
		nonLethal = {
			{ spellID = 9, name = "N1", icon = 9 },
		},
	}, {
		counts = { lethal = 1, nonLethal = 0 },
		spellIDs = { lethal = { [2] = true }, nonLethal = {} },
		names = { lethal = { l2 = true }, nonLethal = {} },
	}, { lethal = 2, nonLethal = 1 })

	local lethalRow = FindRowByCategory(rows, "lethal")
	AssertTrue(lethalRow ~= nil, "lethal row should exist")
	AssertEquals(#lethalRow.icons, 2, "active lethal icon should be removed")
	AssertEquals(lethalRow.icons[1].spellID, 1, "first lethal icon")
	AssertEquals(lethalRow.icons[2].spellID, 3, "second lethal icon")
end)
