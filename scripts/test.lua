-- Offline-only stand-ins. This file is deliberately excluded from the TOC.
local root = arg[1] or "."
_G.CreateFrame = function()
	return { SetScript = function() end, RegisterEvent = function() end, UnregisterEvent = function() end }
end
_G.wipe = function(t)
	for key in pairs(t) do
		t[key] = nil
	end
	return t
end
local namespace = {}
for line in io.lines(root .. "/NoPoizen.toc") do
	if line:match("%.lua$") then
		assert(loadfile(root .. "/" .. line))("NoPoizen", namespace)
	end
end
local ok = NoPoizen:RunTests(arg[2] == "reverse")
if not ok then
	os.exit(1)
end

-- Stock Lua supports this NaN fixture; the game VM can throw instead. Keep it
-- outside the TOC and do not include these checks in the in-game suite count.
local nan = 0 / 0
assert(nan ~= nan, "offline interpreter must supply a real NaN; never silently skip this coverage")
local fixture = NoPoizen:CreateTestFixture()
assert(not fixture:IsFiniteNumber(nan))
assert(fixture:ToFiniteNumber(nan) == nil)
assert(fixture:NormalizeWidgetScale(nan) == nil)
assert(fixture:NormalizeAudioVolume(nan) == nil)
assert(not fixture:SetIndicatorAnchor("CENTER", "CENTER", nan, 0))
fixture.db.indicatorAnchor = { point = "CENTER", relativePoint = "CENTER", x = nan, y = nan }
assert(fixture:GetIndicatorAnchor().x == fixture.DEFAULT_INDICATOR_ANCHOR.x)
assert(fixture:GetIndicatorAnchor().y == fixture.DEFAULT_INDICATOR_ANCHOR.y)
assert(NoPoizen.LibChev.Number(nan) == nil)
local clockReads = 0
fixture.API.GetTime = function()
	clockReads = clockReads + 1
	return nan
end
NoPoizen.LogDiagnostic(fixture, "failure", "NaN clock value")
assert(clockReads == 1 and fixture.diagnosticLog[1].elapsed == nil)
assert(fixture.diagnosticLog[1].text == "NaN clock value")
local api = {}
for key, value in pairs(NoPoizen.ClientDiagnosticAPI) do
	api[key] = value
end
local slotReads, enchantReads = 0, 0
api.CanSample = function()
	return true
end
api.HasCapability = function()
	return true
end
api.GetWeaponSlot = function()
	slotReads = slotReads + 1
	return nan
end
api.GetWeaponEnchants = function()
	enchantReads = enchantReads + 1
	return {}
end
local report = table.concat(NoPoizen.Testables.BuildClientCapabilityLines(api), "\n")
assert(slotReads == 2 and enchantReads == 0)
assert(report:find("MainHand: slot enum unavailable", 1, true))
print("Offline-only NaN rejection checks passed (excluded from in-game test count).")
