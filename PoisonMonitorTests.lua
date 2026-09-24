local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end

-- All fixtures are private Lua tables. No test changes the live addon, saved
-- variables, Blizzard globals, C_* functions, frames, or actual aura state.
local function AssertEqual(actual, expected, context)
	if actual ~= expected then
		error((context or "assertion") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function Fixture()
	local secret = {}
	local inaccessible = setmetatable({}, {
		__index = function()
			error("inaccessible aura was read")
		end,
	})
	local fixture = {
		known = { [2823] = true, [8679] = true, [3408] = true, [5761] = true },
		auras = {},
		calls = {},
		secret = secret,
		inaccessible = inaccessible,
	}
	local api = {
		CanAccessValue = function(value)
			return value ~= secret
		end,
		CanAccessTable = function(value)
			return value ~= inaccessible and value ~= secret
		end,
		GetPlayerClassFile = function()
			return "ROGUE"
		end,
		GetDetectionMode = function()
			return "retail-aura"
		end,
		IsSpellKnown = function(id)
			return fixture.known[id] == true
		end,
		GetSpellName = function(id)
			return "Spell " .. id
		end,
		GetSpellTexture = function(id)
			return id
		end,
		GetPlayerAuraBySpellID = function(id)
			fixture.calls[id] = (fixture.calls[id] or 0) + 1
			return fixture.auras[id]
		end,
		ShouldSpellAuraBeSecret = function()
			return false
		end,
	}
	fixture.api = api
	fixture.detector = NoPoizen.Testables.CreatePoisonDetector(api)
	return fixture
end

local function Register(name, test)
	NoPoizen:RegisterTest("detector: " .. name, test)
end

Register("ordinary rogue sees missing categories", function()
	local state = Fixture().detector:Evaluate()
	AssertEqual(state.status, "missing")
	AssertEqual(state.observable, true)
	AssertEqual(state.missingCounts.total, 2)
	AssertEqual(#state.indicatorRows, 2)
end)

Register("one lethal and one nonlethal satisfy baseline", function()
	local f = Fixture()
	f.auras[2823], f.auras[3408] = {}, {}
	local state = f.detector:Evaluate()
	AssertEqual(state.status, "satisfied")
	AssertEqual(state.missingCounts.total, 0)
	AssertEqual(#state.indicatorRows, 0)
end)

Register("dragon tempered blades needs second category choices", function()
	local f = Fixture()
	f.known[NoPoizen.DRAGON_TEMPERED_BLADES_SPELL_ID] = true
	f.auras[2823], f.auras[3408] = {}, {}
	local state = f.detector:Evaluate()
	AssertEqual(state.requiredCounts.lethal, 2)
	AssertEqual(state.requiredCounts.nonLethal, 2)
	AssertEqual(state.missingCounts.total, 2)
	AssertEqual(#state.indicatorRows[1].icons, 1)
	AssertEqual(#state.indicatorRows[2].icons, 1)
end)

Register("low level rogue never requires unknown category", function()
	local f = Fixture()
	f.known = { [2823] = true }
	f.auras[2823] = {}
	local state = f.detector:Evaluate()
	AssertEqual(state.requiredCounts.nonLethal, 0)
	AssertEqual(state.status, "satisfied")
end)

Register("talent count never exceeds known selections", function()
	local f = Fixture()
	f.known = { [2823] = true, [3408] = true, [NoPoizen.DRAGON_TEMPERED_BLADES_SPELL_ID] = true }
	local state = f.detector:Evaluate()
	AssertEqual(state.requiredCounts.lethal, 1)
	AssertEqual(state.requiredCounts.nonLethal, 1)
end)

Register("residual poison survives spec knowledge change", function()
	local f = Fixture()
	f.known = { [315584] = true, [3408] = true }
	f.auras[2823], f.auras[3408] = {}, {}
	local state = f.detector:Evaluate()
	AssertEqual(state.status, "satisfied")
	AssertEqual(state.activeCounts.lethal, 1)
end)

Register("all rogue loadouts use learned poison choices", function()
	for _, lethalID in ipairs({ 2823, 315584, 8679, 381664 }) do
		local f = Fixture()
		f.known = { [lethalID] = true, [381637] = true }
		f.auras[lethalID], f.auras[381637] = {}, {}
		AssertEqual(f.detector:Evaluate().status, "satisfied", "loadout " .. lethalID)
	end
end)

Register("nonrogue does not scan", function()
	local f = Fixture()
	f.api.GetPlayerClassFile = function()
		return "MAGE"
	end
	AssertEqual(f.detector:Evaluate().status, "ineligible")
	AssertEqual(next(f.calls), nil)
end)

Register("unreadable class is unknown", function()
	local f = Fixture()
	f.api.GetPlayerClassFile = function()
		return f.secret
	end
	AssertEqual(f.detector:Evaluate().status, "unknown")
	AssertEqual(next(f.calls), nil)
end)

Register("unverified client mechanics never scan or warn", function()
	local f = Fixture()
	f.api.GetDetectionMode = function()
		return "unsupported"
	end
	local state = f.detector:Evaluate()
	AssertEqual(state.status, "unsupported")
	AssertEqual(state.hasMissing, false)
	AssertEqual(next(f.calls), nil)
end)

Register("no learned poison is ineligible", function()
	local f = Fixture()
	f.known = {}
	AssertEqual(f.detector:Evaluate().reason, "no-known-poisons")
end)

Register("modern known spell result wins over legacy spellbook", function()
	local f = Fixture()
	f.known = {}
	f.api.IsPlayerSpellLegacy = function()
		error("legacy called")
	end
	f.api.IsSpellKnownLegacy = function()
		return true
	end
	AssertEqual(f.detector:Evaluate().status, "ineligible")
end)

Register("legacy spell knowledge works when modern API absent", function()
	local f = Fixture()
	f.api.IsSpellKnown = nil
	f.api.IsPlayerSpellLegacy = function(id)
		return f.known[id] == true
	end
	AssertEqual(f.detector:Evaluate().status, "missing")
end)

Register("secret known spell boolean is unknown", function()
	local f = Fixture()
	f.api.IsSpellKnown = function()
		return f.secret
	end
	AssertEqual(f.detector:Evaluate().reason, "spell-knowledge-unavailable")
end)

Register("missing spell knowledge API is unknown", function()
	local f = Fixture()
	f.api.IsSpellKnown = nil
	AssertEqual(f.detector:Evaluate().reason, "spell-knowledge-unavailable")
end)

Register("talent query failure is unknown", function()
	local f = Fixture()
	f.api.IsSpellKnown = function(id)
		if id == NoPoizen.DRAGON_TEMPERED_BLADES_SPELL_ID then
			error("unavailable")
		end
		return f.known[id] == true
	end
	AssertEqual(f.detector:Evaluate().reason, "talent-knowledge-unavailable")
end)

Register("secret metadata uses safe owned fallback", function()
	local f = Fixture()
	f.api.GetSpellName = function()
		return f.secret
	end
	f.api.GetSpellTexture = function()
		return f.secret
	end
	local state = f.detector:Evaluate()
	AssertEqual(state.indicatorRows[1].icons[1].name, "Deadly Poison")
	AssertEqual(state.indicatorRows[1].icons[1].icon, nil)
end)

Register("restricted aura is unknown before API call", function()
	local f = Fixture()
	f.api.ShouldSpellAuraBeSecret = function()
		return true
	end
	local state = f.detector:Evaluate()
	AssertEqual(state.status, "unknown")
	AssertEqual(state.reason, "aura-restricted")
	AssertEqual(state.hasMissing, false)
	AssertEqual(next(f.calls), nil)
end)

Register("known public aura can be checked during general secrecy", function()
	local f = Fixture()
	f.api.ShouldAurasBeSecret = function()
		return true
	end
	AssertEqual(f.detector:Evaluate().status, "missing")
end)

Register("broad secrecy preflight used only without spell predicate", function()
	local f = Fixture()
	f.api.ShouldSpellAuraBeSecret = nil
	f.api.ShouldAurasBeSecret = function(...)
		AssertEqual(select("#", ...), 0)
		return true
	end
	AssertEqual(f.detector:Evaluate().status, "unknown")
	AssertEqual(next(f.calls), nil)
end)

Register("secrecy predicate failure does not become absence", function()
	local f = Fixture()
	f.api.ShouldSpellAuraBeSecret = function()
		error("unavailable")
	end
	AssertEqual(f.detector:Evaluate().status, "unknown")
	AssertEqual(next(f.calls), nil)
end)

Register("direct aura error never bypasses restrictions by fallback", function()
	local f = Fixture()
	f.api.GetPlayerAuraBySpellID = function()
		error("restricted")
	end
	f.api.GetAuraDataByIndex = function()
		error("must not call fallback")
	end
	local state = f.detector:Evaluate()
	AssertEqual(state.status, "unknown")
	AssertEqual(state.reason, "aura-api-error")
end)

Register("direct nil is authoritative absence", function()
	local f = Fixture()
	f.api.GetAuraDataByIndex = function()
		error("must not scan after direct nil")
	end
	AssertEqual(f.detector:Evaluate().status, "missing")
end)

Register("inaccessible aura record is never indexed", function()
	local f = Fixture()
	f.auras[2823] = f.inaccessible
	AssertEqual(f.detector:Evaluate().reason, "aura-unreadable")
end)

Register("secret aura result never becomes present", function()
	local f = Fixture()
	f.auras[2823] = f.secret
	AssertEqual(f.detector:Evaluate().reason, "aura-unreadable")
end)

Register("direct query need not read secret fields", function()
	local f = Fixture()
	local aura = setmetatable({}, {
		__index = function()
			error("unneeded field read")
		end,
	})
	f.auras[2823], f.auras[3408] = aura, aura
	AssertEqual(f.detector:Evaluate().status, "satisfied")
end)

Register("confirmed required counts suffice despite unrelated secret poison", function()
	local f = Fixture()
	f.auras[2823], f.auras[3408], f.auras[8679] = {}, {}, f.secret
	AssertEqual(f.detector:Evaluate().status, "satisfied")
end)

Register("missing aura APIs are unknown", function()
	local f = Fixture()
	f.api.GetPlayerAuraBySpellID = nil
	AssertEqual(f.detector:Evaluate().reason, "aura-api-unavailable")
end)

Register("modern indexed fallback sees auras beyond forty", function()
	local f = Fixture()
	f.api.GetPlayerAuraBySpellID = nil
	local reads = 0
	f.api.GetAuraDataByIndex = function(_, index, filter)
		AssertEqual(filter, "HELPFUL")
		reads = reads + 1
		if index == 51 then
			return { spellId = 2823 }
		end
		if index == 52 then
			return { spellId = 3408 }
		end
		if index <= 50 then
			return { spellId = 100000 + index }
		end
	end
	AssertEqual(f.detector:Evaluate().status, "satisfied")
	AssertEqual(reads, 53, "scan performed once")
end)

Register("indexed secret id cannot prove absence", function()
	local f = Fixture()
	f.api.GetPlayerAuraBySpellID = nil
	f.api.GetAuraDataByIndex = function(_, index)
		if index == 1 then
			return { spellId = f.secret }
		end
	end
	AssertEqual(f.detector:Evaluate().status, "unknown")
end)

Register("indexed confirmed counts survive unrelated secret aura", function()
	local f = Fixture()
	f.api.GetPlayerAuraBySpellID = nil
	local rows = { { spellId = f.secret }, { spellId = 2823 }, { spellId = 3408 } }
	f.api.GetAuraDataByIndex = function(_, index)
		return rows[index]
	end
	AssertEqual(f.detector:Evaluate().status, "satisfied")
end)

Register("restricted index skipped without reading record", function()
	local f = Fixture()
	f.api.GetPlayerAuraBySpellID = nil
	f.api.ShouldUnitAuraIndexBeSecret = function(_, index)
		return index == 1
	end
	f.api.GetAuraDataByIndex = function(_, index)
		AssertEqual(index, 2)
	end
	AssertEqual(f.detector:Evaluate().status, "unknown")
end)

Register("indexed scan is bounded when end is never returned", function()
	local f = Fixture()
	f.api.GetPlayerAuraBySpellID = nil
	local reads = 0
	f.api.GetAuraDataByIndex = function()
		reads = reads + 1
		return { spellId = 99999 }
	end
	AssertEqual(f.detector:Evaluate().reason, "aura-scan-limit")
	AssertEqual(reads, 1024)
end)

Register("legacy aura fallback uses spell IDs not ambiguous names", function()
	local f = Fixture()
	f.api.GetPlayerAuraBySpellID = nil
	f.api.UnitAuraLegacy = function(_, index)
		if index == 1 then
			return "different name", nil, nil, nil, nil, nil, nil, nil, nil, 2823
		end
		if index == 2 then
			return "different name", nil, nil, nil, nil, nil, nil, nil, nil, 3408
		end
	end
	AssertEqual(f.detector:Evaluate().status, "satisfied")
end)

Register("legacy same name with wrong ID never matches poison", function()
	local f = Fixture()
	f.api.GetPlayerAuraBySpellID = nil
	f.api.UnitAuraLegacy = function(_, index)
		if index == 1 then
			return "Deadly Poison", nil, nil, nil, nil, nil, nil, nil, nil, 99999
		end
	end
	AssertEqual(f.detector:Evaluate().status, "missing")
end)

Register("duplicate catalog entries never double count active poison", function()
	local f = Fixture()
	local catalog = {
		lethal = { { spellID = 2823 }, { spellID = 2823 } },
		nonLethal = { { spellID = 3408 } },
	}
	f.auras[2823], f.auras[3408] = {}, {}
	local state = NoPoizen.Testables.CreatePoisonDetector(f.api, catalog):Evaluate()
	AssertEqual(state.knownPoisonCount, 2)
	AssertEqual(state.activeCounts.lethal, 1)
end)

local function RefreshFixture()
	local fixture = {
		RefreshPoisonState = NoPoizen.RefreshPoisonState,
		isEnabled = true,
		audioTransitionsArmed = true,
		audioMissingState = true,
		audioBaselinePending = false,
		API = {
			GetTime = function()
				return 100
			end,
		},
		sounds = 0,
		GetOption = function(_, option)
			if option == "audioVolume" or option == "satisfiedAudioVolume" then
				return 1
			end
			return true
		end,
		PlayMissingPoisonSound = function(self)
			self.sounds = self.sounds + 1
		end,
		PlaySatisfiedPoisonSound = function(self)
			self.sounds = self.sounds + 1
		end,
		UpdatePoisonIndicator = function(self, state)
			self.visible = state.showIndicator
		end,
		RecordPoisonObservation = function() end,
		EvaluatePoisonState = function(self)
			return self.nextState
		end,
	}
	return fixture
end

Register("unknown observation clears HUD without recovery sound", function()
	local f = RefreshFixture()
	f.nextState = { eligible = true, observable = false, hasMissing = false }
	f:RefreshPoisonState("TEST")
	AssertEqual(f.sounds, 0)
	AssertEqual(f.visible, false)
	AssertEqual(f.audioBaselinePending, true)
	f.nextState = { eligible = true, observable = true, hasMissing = false }
	f:RefreshPoisonState("TEST")
	AssertEqual(f.sounds, 0, "recovery is a new baseline")
	f.nextState = { eligible = true, observable = true, hasMissing = true }
	f:RefreshPoisonState("TEST")
	AssertEqual(f.sounds, 1, "later missing transition plays normally")
end)

Register("ineligible observation rebaselines returning rogue", function()
	local f = RefreshFixture()
	f.nextState = { eligible = false, observable = false, hasMissing = false }
	f:RefreshPoisonState("TEST")
	f.nextState = { eligible = true, observable = true, hasMissing = true }
	f:RefreshPoisonState("TEST")
	AssertEqual(f.sounds, 0)
	AssertEqual(f.visible, true)
end)

Register("same localized name cannot hide a different poison choice", function()
	local known = { lethal = { { spellID = 2823, name = "Same Name" } } }
	local active = {
		counts = { lethal = 0 },
		spellIDs = { lethal = { [9999] = true } },
		names = { lethal = { ["same name"] = true } },
	}
	local rows = NoPoizen.Testables.BuildIndicatorRows(known, active, { lethal = 1 })
	AssertEqual(#rows, 1)
	AssertEqual(rows[1].icons[1].spellID, 2823)
end)

Register("startup baseline allows first much later expiry warning", function()
	local f = NoPoizen:CreateTestFixture()
	f.now = 0
	f.postLoadRefreshToken, f.audioArmToken = 0, 0
	f.postLoadRefreshAt, f.isLoadingScreenActive = 0, false
	f.nextState = { eligible = true, observable = true, hasMissing = false }
	f.EvaluatePoisonState = function(self)
		return self.nextState
	end
	f:ResetAudioTransitionArming(5)
	f:RefreshPoisonState("ENABLE")
	AssertEqual(#f.sounds, 0)
	f.now = 5
	f.callbacks[1]()
	AssertEqual(f.audioTransitionsArmed, true)
	AssertEqual(#f.sounds, 0)
	f.now = 60
	f.nextState = { eligible = true, observable = true, hasMissing = true }
	f:RefreshPoisonState("UNIT_AURA")
	AssertEqual(#f.sounds, 1)
	AssertEqual(f.lastRendered.showIndicator, true)
end)
