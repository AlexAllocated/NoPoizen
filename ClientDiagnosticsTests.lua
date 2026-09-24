local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end

-- Private fixtures exercise the diagnostic boundary without replacing any
-- Blizzard global, API table, secret predicate, frame, or live addon adapter.
local function Fixture()
	local hidden = setmetatable({}, {
		__index = function()
			error("inaccessible table was read")
		end,
		__tostring = function()
			error("inaccessible value was formatted")
		end,
	})
	local calls = { slots = {} }
	local api = {
		CanAccessValue = function(value)
			return value ~= hidden
		end,
		CanAccessTable = function(value)
			return value ~= hidden and type(value) == "table"
		end,
		IsFiniteNumber = function(value)
			return type(value) == "number" and value == value and value > -math.huge and value < math.huge
		end,
		SafeToString = tostring,
		GetBuildInfo = function()
			return "1.60.1", "69977", "date", 16001
		end,
		GetProjectID = function()
			return 2
		end,
		GetUnitClass = function()
			return "Rogue", "ROGUE", 4
		end,
		GetSpecialization = function()
			return nil
		end,
		GetSpecializationInfo = function()
			error("no specialization selected")
		end,
		HasCapability = function()
			return true
		end,
		CanSample = function()
			return true
		end,
		GetWeaponSlot = function(name)
			return name == "MainHand" and 0 or 1
		end,
		GetWeaponEnchants = function(slot)
			calls.slots[#calls.slots + 1] = slot
			return {}
		end,
	}
	return api, calls, hidden
end

local function Report(api)
	local lines = NoPoizen.Testables.BuildClientCapabilityLines(api)
	return table.concat(lines, "\n"), lines
end

local function Contains(text, expected)
	assert(text:find(expected, 1, true), "expected diagnostic text: " .. expected)
end

NoPoizen:RegisterTest("client diagnostics use weapon enums and preserve empty samples", function()
	local api, calls = Fixture()
	local report = Report(api)
	assert(
		#calls.slots == 2 and calls.slots[1] == 0 and calls.slots[2] == 1,
		"must query enum slots, not inventory slots"
	)
	Contains(report, "interface=16001")
	Contains(report, "MainHand: no enchant rows")
	Contains(report, "OffHand: no enchant rows")
	Contains(report, "mapping: unverified")
end)

NoPoizen:RegisterTest("client diagnostics skip samples under restrictions", function()
	local api, calls = Fixture()
	api.CanSample = function()
		return false, "Encounter restriction active or unavailable"
	end
	local report = Report(api)
	assert(#calls.slots == 0, "restriction must prevent weapon API reads")
	Contains(report, "Weapon samples: skipped")
end)

NoPoizen:RegisterTest("client diagnostics skip samples when restriction query fails", function()
	local api, calls = Fixture()
	api.CanSample = function()
		error("private failure")
	end
	Contains(Report(api), "restriction query unavailable")
	assert(#calls.slots == 0, "failed restriction query must prevent weapon API reads")
end)

NoPoizen:RegisterTest("client diagnostics do not index inaccessible enchant tables", function()
	local api, _, hidden = Fixture()
	api.GetWeaponEnchants = function()
		return hidden
	end
	Contains(Report(api), "MainHand: enchants unavailable")
	api.GetWeaponEnchants = function()
		return { hidden }
	end
	Contains(Report(api), "MainHand row=1: unavailable")
end)

NoPoizen:RegisterTest("client diagnostics do not format inaccessible scalar fields", function()
	local api, _, hidden = Fixture()
	api.GetBuildInfo = function()
		return hidden, hidden, "date", hidden
	end
	api.GetWeaponEnchants = function()
		return {
			{
				hasEnchant = true,
				enchantType = 3,
				enchantID = hidden,
				timeLeft = hidden,
				charges = 0,
				enchantIconID = hidden,
			},
		}
	end
	local report = Report(api)
	Contains(report, "version=<unavailable>")
	Contains(report, "id=<unavailable> ms=<unavailable> charges=0 icon=<unavailable>")
end)

NoPoizen:RegisterTest("client diagnostics retain multiple coating rows without poison classification", function()
	local api = Fixture()
	api.GetWeaponEnchants = function()
		return {
			{ hasEnchant = true, enchantType = 2, enchantID = 100, timeLeft = 1000, charges = 0, enchantIconID = 1 },
			{ hasEnchant = true, enchantType = 3, enchantID = 200, timeLeft = 2000, charges = 40, enchantIconID = 2 },
		}
	end
	local report = Report(api)
	Contains(report, "id=100 ms=1000 charges=0")
	Contains(report, "id=200 ms=2000 charges=40")
	Contains(report, "weapon samples do not establish poison coverage")
end)

NoPoizen:RegisterTest("client diagnostics bound oversized enchant observations", function()
	local api = Fixture()
	api.GetWeaponEnchants = function()
		local rows = {}
		for i = 1, 1000 do
			rows[i] = {}
		end
		return rows
	end
	local report, lines = Report(api)
	assert(#lines <= 24, "diagnostic rows must be bounded")
	Contains(report, "additional rows omitted (limit 8)")
end)

NoPoizen:RegisterTest("client diagnostics expose only readable class and specialization details", function()
	local api, _, hidden = Fixture()
	Contains(Report(api), "Specialization: unavailable")
	api.GetSpecialization = function()
		return 1
	end
	api.GetSpecializationInfo = function()
		return 259, "Assassination"
	end
	local report = Report(api)
	Contains(report, "Class: ROGUE id=4")
	Contains(report, "Specialization: index=1 id=259 name=Assassination")
	api.GetUnitClass = function()
		return hidden, hidden, hidden
	end
	api.GetSpecialization = function()
		return hidden
	end
	report = Report(api)
	Contains(report, "Class: <unavailable> id=<unavailable>")
	Contains(report, "Specialization: unavailable")
end)

NoPoizen:RegisterTest("client diagnostics sanitize untrusted build text and invalid enums", function()
	local api, calls = Fixture()
	api.GetBuildInfo = function()
		return "1\n|Hlink|h", "69977", "date", 16001
	end
	api.GetWeaponSlot = function()
		-- Return a nonfinite value successfully; do not test the throwing-API path.
		return math.huge
	end
	local report = Report(api)
	Contains(report, "version=1??Hlink?h")
	Contains(report, "MainHand: slot enum unavailable")
	assert(#calls.slots == 0, "invalid slot must never reach weapon API")
end)
