local NoPoizen = _G.NoPoizen

if not NoPoizen then
	return
end

local CATEGORIES = { "lethal", "nonLethal" }
local MAX_AURA_SCAN = 1024

-- API references live in an addon-owned table. Tests construct private detector
-- instances and never replace globals, C_* members, or the live detector.
NoPoizen.PoisonAPI = {
	CanAccessValue = function(value)
		return NoPoizen:CanAccessValue(value)
	end,
	CanAccessTable = function(value)
		return NoPoizen:CanAccessTable(value)
	end,
	GetPlayerClassFile = function()
		return NoPoizen:GetPlayerClassFile()
	end,
	GetDetectionMode = function()
		local client = NoPoizen:GetPoisonClient()
		if client == "retail" or client == "mists" then
			return client .. "-aura"
		end
		if NoPoizen.weaponPoisonCatalogs[client] then
			return client .. "-weapon"
		end
		return "unsupported"
	end,
	IsSpellKnown = C_SpellBook and C_SpellBook.IsSpellKnown,
	IsPlayerSpellLegacy = IsPlayerSpell,
	IsSpellKnownLegacy = IsSpellKnown,
	GetSpellName = C_Spell and C_Spell.GetSpellName or GetSpellInfo,
	GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture,
	GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID,
	GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex,
	UnitAuraLegacy = UnitAura,
	ShouldSpellAuraBeSecret = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret,
	ShouldAurasBeSecret = C_Secrets and C_Secrets.ShouldAurasBeSecret,
	ShouldUnitAuraIndexBeSecret = C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret,
}

NoPoizen.mistsPoisonCatalog = {
	lethal = {
		{ spellID = 2823, fallbackName = "Deadly Poison" },
		{ spellID = 8679, fallbackName = "Wound Poison" },
	},
	nonLethal = {
		{ spellID = 3408, fallbackName = "Crippling Poison" },
		{ spellID = 5761, fallbackName = "Mind-numbing Poison" },
		{ spellID = 108211, fallbackName = "Leeching Poison" },
		{ spellID = 108215, fallbackName = "Paralytic Poison" },
	},
}

NoPoizen.poisonCatalog = {
	lethal = {
		{ spellID = 2823, fallbackName = "Deadly Poison" },
		{ spellID = 8679, fallbackName = "Wound Poison" },
		{ spellID = 315584, fallbackName = "Instant Poison" },
		{ spellID = 381664, fallbackName = "Amplifying Poison" },
	},
	nonLethal = {
		{ spellID = 3408, fallbackName = "Crippling Poison" },
		{ spellID = 5761, fallbackName = "Numbing Poison" },
		{ spellID = 381637, fallbackName = "Atrophic Poison" },
	},
}

local function CalculateMissingCounts(requiredCounts, activeCounts)
	local missingLethal = math.max(0, (requiredCounts.lethal or 0) - (activeCounts.lethal or 0))
	local missingNonLethal = math.max(0, (requiredCounts.nonLethal or 0) - (activeCounts.nonLethal or 0))
	return {
		lethal = missingLethal,
		nonLethal = missingNonLethal,
		total = missingLethal + missingNonLethal,
	}
end

local function ResolveRequiredCounts(hasDragonTemperedBlades)
	local extra = hasDragonTemperedBlades and 1 or 0
	return {
		lethal = 1 + extra,
		nonLethal = 1 + extra,
	}
end

local function ShouldPlayAudio(lastMissingState, currentMissingState, audioEnabled, audioVolume)
	if not audioEnabled then
		return false
	end
	if (tonumber(audioVolume) or 0) <= 0 then
		return false
	end
	if not currentMissingState then
		return false
	end
	return not lastMissingState
end

local function ShouldPlaySatisfiedAudio(lastMissingState, currentSatisfiedState, audioEnabled, audioVolume)
	if not audioEnabled then
		return false
	end
	if (tonumber(audioVolume) or 0) <= 0 then
		return false
	end
	if not currentSatisfiedState then
		return false
	end
	return lastMissingState
end

local function ResolveAudioArmingState(isArmed, armAtTime, nowTime)
	if isArmed then
		return true, false
	end

	local armAt = tonumber(armAtTime) or 0
	local now = tonumber(nowTime) or 0
	if now < armAt then
		return false, true
	end

	-- First refresh at/after arm-time seeds baseline state without firing transition audio.
	return true, true
end

local function BuildIndicatorRows(knownByCategory, activeCategoryState, requiredCounts)
	local rows = {}

	for _, category in ipairs({ "lethal", "nonLethal" }) do
		local activeCount = (activeCategoryState.counts and activeCategoryState.counts[category]) or 0
		local requiredCount = requiredCounts[category] or 0
		if activeCount < requiredCount then
			local categoryRowIcons = {}
			for _, spell in ipairs(knownByCategory[category] or {}) do
				local isActiveByID = spell.spellID
					and activeCategoryState.spellIDs
					and activeCategoryState.spellIDs[category]
					and activeCategoryState.spellIDs[category][spell.spellID]
				if not isActiveByID then
					table.insert(categoryRowIcons, {
						spellID = spell.spellID,
						name = spell.name,
						icon = spell.icon,
					})
				end
			end

			if #categoryRowIcons > 0 then
				table.insert(rows, {
					category = category,
					icons = categoryRowIcons,
				})
			end
		end
	end

	return rows
end

NoPoizen.Testables = NoPoizen.Testables or {}
NoPoizen.Testables.CalculateMissingCounts = CalculateMissingCounts
NoPoizen.Testables.ResolveRequiredCounts = ResolveRequiredCounts
NoPoizen.Testables.ShouldPlayAudio = ShouldPlayAudio
NoPoizen.Testables.ShouldPlaySatisfiedAudio = ShouldPlaySatisfiedAudio
NoPoizen.Testables.ResolveAudioArmingState = ResolveAudioArmingState
NoPoizen.Testables.BuildIndicatorRows = BuildIndicatorRows

local function CreatePoisonDetector(api, catalog, weaponAPI)
	catalog = catalog or NoPoizen.poisonCatalog
	local detector = {}

	local function CanRead(value)
		if type(api.CanAccessValue) ~= "function" then
			return false
		end
		local ok, readable = pcall(api.CanAccessValue, value)
		return ok and readable == true
	end

	local function CanReadTable(value)
		if not CanRead(value) or type(value) ~= "table" or type(api.CanAccessTable) ~= "function" then
			return false
		end
		local ok, readable = pcall(api.CanAccessTable, value)
		return ok and readable == true
	end

	local function ReadBoolean(fn, ...)
		if type(fn) ~= "function" then
			return nil, "api-unavailable"
		end
		local ok, value = pcall(fn, ...)
		if not ok then
			return nil, "api-error"
		end
		if not CanRead(value) or type(value) ~= "boolean" then
			return nil, "unreadable-result"
		end
		return value
	end

	local function IsSpellKnownSafe(spellID)
		if type(api.IsSpellKnown) == "function" then
			-- Modern spell knowledge is authoritative. Spellbook membership can
			-- include unlearned overrides, so it is not a suitable fallback.
			return ReadBoolean(api.IsSpellKnown, spellID)
		end
		local playerKnown, playerReason = ReadBoolean(api.IsPlayerSpellLegacy, spellID)
		local legacyKnown, legacyReason = ReadBoolean(api.IsSpellKnownLegacy, spellID)
		if playerKnown == true or legacyKnown == true then
			return true
		end
		if playerKnown == false and (legacyKnown == false or legacyReason == "api-unavailable") then
			return false
		end
		if legacyKnown == false and playerReason == "api-unavailable" then
			return false
		end
		return nil, playerReason or legacyReason or "spell-knowledge-unavailable"
	end

	local function GetSpellMetadata(spell)
		local name, icon = spell.fallbackName, nil
		if type(api.GetSpellName) == "function" then
			local ok, value = pcall(api.GetSpellName, spell.spellID)
			if ok and CanRead(value) and type(value) == "string" and value ~= "" then
				name = value
			end
		end
		if type(api.GetSpellTexture) == "function" then
			local ok, value = pcall(api.GetSpellTexture, spell.spellID)
			if ok and CanRead(value) then
				if type(value) == "number" and value > 0 and value < math.huge then
					icon = value
				elseif type(value) == "string" and value ~= "" then
					icon = value
				end
			end
		end
		return { spellID = spell.spellID, name = name, icon = icon }
	end

	function detector:BuildKnownPoisonSpellsByCategory()
		local known = { lethal = {}, nonLethal = {} }
		local unknownReason
		for _, category in ipairs(CATEGORIES) do
			local seen = {}
			for _, spell in ipairs(catalog[category] or {}) do
				local isKnown, reason = IsSpellKnownSafe(spell.spellID)
				if isKnown == nil then
					unknownReason = unknownReason or reason
				elseif isKnown and not seen[spell.spellID] then
					seen[spell.spellID] = true
					table.insert(known[category], GetSpellMetadata(spell))
				end
			end
		end
		return known, unknownReason
	end

	function detector:HasDragonTemperedBladesSelected()
		return IsSpellKnownSafe(NoPoizen.DRAGON_TEMPERED_BLADES_SPELL_ID)
	end

	local function CanQueryAura(spellID)
		-- RequiresNonSecretAura returns no values when blocked. Preflight is
		-- essential: a successful call returning nil alone cannot prove absence.
		local isSecret, reason
		if type(api.ShouldSpellAuraBeSecret) == "function" then
			isSecret, reason = ReadBoolean(api.ShouldSpellAuraBeSecret, spellID)
		elseif type(api.ShouldAurasBeSecret) == "function" then
			isSecret, reason = ReadBoolean(api.ShouldAurasBeSecret)
		else
			return true
		end
		if isSecret == nil then
			return false, reason
		end
		if isSecret then
			return false, "aura-restricted"
		end
		return true
	end

	local function ScanHelpfulAuras()
		local present = {}
		local incompleteReason
		local modern = type(api.GetAuraDataByIndex) == "function"
		if not modern and type(api.UnitAuraLegacy) ~= "function" then
			return present, "aura-api-unavailable"
		end
		for index = 1, MAX_AURA_SCAN do
			local skip = false
			if type(api.ShouldUnitAuraIndexBeSecret) == "function" then
				local secret, reason = ReadBoolean(api.ShouldUnitAuraIndexBeSecret, "player", index, "HELPFUL")
				if secret == nil then
					return present, reason
				elseif secret then
					skip = true
					incompleteReason = "aura-restricted"
				end
			end
			if not skip then
				local spellID
				if modern then
					local ok, aura = pcall(api.GetAuraDataByIndex, "player", index, "HELPFUL")
					if not ok then
						return present, "aura-api-error"
					elseif not CanRead(aura) then
						incompleteReason = "aura-unreadable"
					elseif aura == nil then
						return present, incompleteReason
					elseif CanReadTable(aura) then
						spellID = aura.spellId
					else
						incompleteReason = "aura-unreadable"
					end
				else
					local ok, name, _, _, _, _, _, _, _, _, legacyID =
						pcall(api.UnitAuraLegacy, "player", index, "HELPFUL")
					if not ok then
						return present, "aura-api-error"
					elseif not CanRead(name) then
						incompleteReason = "aura-unreadable"
					elseif name == nil then
						return present, incompleteReason
					else
						spellID = legacyID
					end
				end
				if CanRead(spellID) and type(spellID) == "number" and spellID > 0 and spellID < math.huge then
					present[spellID] = true
				else
					incompleteReason = incompleteReason or "aura-unreadable"
				end
			end
		end
		return present, "aura-scan-limit"
	end

	function detector:GetActivePoisonAuraState()
		local active = {
			counts = { lethal = 0, nonLethal = 0 },
			spellIDs = { lethal = {}, nonLethal = {} },
			names = { lethal = {}, nonLethal = {} },
			unknown = {},
		}
		local scanned, scanReason
		for _, category in ipairs(CATEGORIES) do
			for _, spell in ipairs(catalog[category] or {}) do
				local present, reason
				local canQuery, restrictionReason = CanQueryAura(spell.spellID)
				if not canQuery then
					reason = restrictionReason
				elseif type(api.GetPlayerAuraBySpellID) == "function" then
					local ok, aura = pcall(api.GetPlayerAuraBySpellID, spell.spellID)
					if not ok then
						reason = "aura-api-error"
					elseif not CanRead(aura) then
						reason = "aura-unreadable"
					elseif aura == nil then
						present = false
					elseif CanReadTable(aura) then
						-- The lookup establishes identity; avoid reading unrelated
						-- secret timing, stacks, names, or other AuraData fields.
						present = true
					else
						reason = "aura-unreadable"
					end
				else
					if not scanned then
						scanned, scanReason = ScanHelpfulAuras()
					end
					if scanned[spell.spellID] then
						present = true
					elseif scanReason then
						reason = scanReason
					else
						present = false
					end
				end
				if present and not active.spellIDs[category][spell.spellID] then
					active.counts[category] = active.counts[category] + 1
					active.spellIDs[category][spell.spellID] = true
				elseif present == nil then
					active.unknown[category] = active.unknown[category] or reason or "aura-unreadable"
				end
			end
		end
		return active
	end

	function detector:Evaluate()
		local state = {
			eligible = false,
			observable = false,
			status = "unknown",
			reason = "class-unavailable",
			detectionMode = "unsupported",
			knownPoisonCount = 0,
			knownSpellIDs = {},
			activeSpellIDs = {},
			requiredCounts = { lethal = 0, nonLethal = 0 },
			activeCounts = { lethal = 0, nonLethal = 0 },
			missingCounts = { lethal = 0, nonLethal = 0, total = 0 },
			indicatorRows = {},
			hasMissing = false,
			showIndicator = false,
		}
		local ok, class = pcall(api.GetPlayerClassFile)
		if not ok or not CanRead(class) or type(class) ~= "string" or class == "" then
			return state
		end
		if class ~= "ROGUE" then
			state.status, state.reason = "ineligible", "not-rogue"
			return state
		end
		local modeOK, mode = pcall(api.GetDetectionMode)
		if not modeOK or not CanRead(mode) or type(mode) ~= "string" then
			state.status, state.reason = "unsupported", "unverified-poison-mechanics"
			return state
		end
		local weaponClient = mode:match("^(%a+)%-weapon$")
		local weaponCatalog = weaponClient and NoPoizen.weaponPoisonCatalogs[weaponClient]
		if weaponCatalog and weaponAPI then
			return NoPoizen.Testables
				.CreateWeaponPoisonDetector(weaponAPI, weaponClient, weaponCatalog, IsSpellKnownSafe)
				:Evaluate(state)
		end
		if mode ~= "retail-aura" and mode ~= "mists-aura" then
			state.status, state.reason = "unsupported", "unverified-poison-mechanics"
			return state
		end
		state.detectionMode = mode
		local known, knownReason = self:BuildKnownPoisonSpellsByCategory()
		state.knownPoisonCount = #known.lethal + #known.nonLethal
		for _, category in ipairs(CATEGORIES) do
			for _, spell in ipairs(known[category]) do
				state.knownSpellIDs[#state.knownSpellIDs + 1] = spell.spellID
			end
		end
		if knownReason then
			state.reason = "spell-knowledge-unavailable"
			return state
		end
		if state.knownPoisonCount == 0 then
			state.status, state.reason = "ineligible", "no-known-poisons"
			return state
		end
		state.eligible = true
		local dragonTempered = false
		if mode == "retail-aura" then
			dragonTempered = self:HasDragonTemperedBladesSelected()
		end
		if dragonTempered == nil then
			state.reason = "talent-knowledge-unavailable"
			return state
		end
		state.hasDragonTemperedBlades = dragonTempered
		state.requiredCounts = ResolveRequiredCounts(dragonTempered)
		for _, category in ipairs(CATEGORIES) do
			-- A low-level rogue may only have learned one category. Do not warn
			-- about impossible selections, including a partially learned loadout.
			state.requiredCounts[category] = math.min(state.requiredCounts[category], #known[category])
		end
		local active = self:GetActivePoisonAuraState()
		state.activeCounts = active.counts
		for _, category in ipairs(CATEGORIES) do
			for spellID in pairs(active.spellIDs[category]) do
				state.activeSpellIDs[#state.activeSpellIDs + 1] = spellID
			end
		end
		table.sort(state.activeSpellIDs)
		for _, category in ipairs(CATEGORIES) do
			if active.counts[category] < state.requiredCounts[category] and active.unknown[category] then
				state.reason = active.unknown[category]
				return state
			end
		end
		state.observable = true
		state.missingCounts = CalculateMissingCounts(state.requiredCounts, state.activeCounts)
		state.hasMissing = state.missingCounts.total > 0
		state.status = state.hasMissing and "missing" or "satisfied"
		state.reason = state.hasMissing and "poison-missing" or "poisons-applied"
		state.indicatorRows = BuildIndicatorRows(known, active, state.requiredCounts)
		return state
	end

	return detector
end

NoPoizen.Testables.CreatePoisonDetector = CreatePoisonDetector
local liveDetector = CreatePoisonDetector(
	NoPoizen.PoisonAPI,
	NoPoizen:GetPoisonClient() == "mists" and NoPoizen.mistsPoisonCatalog or NoPoizen.poisonCatalog,
	NoPoizen.WeaponPoisonAPI
)

function NoPoizen:HasDragonTemperedBladesSelected()
	return liveDetector:HasDragonTemperedBladesSelected()
end

function NoPoizen:BuildKnownPoisonSpellsByCategory()
	return liveDetector:BuildKnownPoisonSpellsByCategory()
end

function NoPoizen:GetKnownPoisonSpellCount(knownByCategory)
	return #(knownByCategory.lethal or {}) + #(knownByCategory.nonLethal or {})
end

function NoPoizen:GetActivePoisonAuraState()
	return liveDetector:GetActivePoisonAuraState()
end

function NoPoizen:EvaluatePoisonState()
	return liveDetector:Evaluate()
end

function NoPoizen:RefreshPoisonState(reason)
	if not self.isEnabled or self.isLoggingOut then
		return
	end

	local now = 0
	if self.API and self.API.GetTime then
		now = tonumber(self.API.GetTime()) or 0
	elseif GetTime then
		now = tonumber(GetTime()) or 0
	end

	if self.isLoadingScreenActive then
		return
	end
	local holdUntil = tonumber(self.postLoadRefreshAt) or 0
	if holdUntil > 0 then
		if now < holdUntil then
			return
		end
		self.postLoadRefreshAt = 0
	end

	local state = self:EvaluatePoisonState()
	local shouldShowVisual = state.observable
		and state.eligible
		and state.hasMissing
		and (self:GetOption("showVisualIndicator") == true)
	state.showIndicator = shouldShowVisual
	self.currentPoisonState = state
	if state.status == "unsupported" and not self.reportedUnsupportedClient and self.Print then
		self.reportedUnsupportedClient = true
		self:Print(
			"Poison monitoring is not supported on this client yet. /np diagnostics can capture information for compatibility testing."
		)
	end
	if self.RecordPoisonObservation then
		self:RecordPoisonObservation(reason, state)
	end

	if self.UpdatePoisonIndicator then
		self:UpdatePoisonIndicator(state)
	end

	if not state.eligible or not state.observable then
		self.audioMissingState = false
		self.audioBaselinePending = true
		return
	end

	local previousMissingState = self.audioMissingState and true or false
	local currentMissingState = state.eligible and state.hasMissing
	local currentSatisfiedState = state.eligible and not state.hasMissing
	local nextArmedState, shouldSuppressPlayback =
		ResolveAudioArmingState(self.audioTransitionsArmed == true, self.audioTransitionsArmAt, now)
	self.audioTransitionsArmed = nextArmedState
	if shouldSuppressPlayback or self.audioBaselinePending then
		self.audioBaselinePending = false
		self.audioMissingState = currentMissingState
		return
	end

	local shouldPlayMissing = ShouldPlayAudio(
		previousMissingState,
		currentMissingState,
		self:GetOption("playAudioIndicator") == true,
		self:GetOption("audioVolume")
	)
	if shouldPlayMissing then
		self:PlayMissingPoisonSound()
	end

	local shouldPlaySatisfied = ShouldPlaySatisfiedAudio(
		previousMissingState,
		currentSatisfiedState,
		self:GetOption("playSatisfiedAudioIndicator") == true,
		self:GetOption("satisfiedAudioVolume")
	)
	if shouldPlaySatisfied and self.PlaySatisfiedPoisonSound then
		self:PlaySatisfiedPoisonSound()
	end

	self.audioMissingState = currentMissingState
end
