local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end
local LibChev = NoPoizen.LibChev

-- Only sanitized primitives enter this addon-owned, session-only bounded history.
function NoPoizen:LogDiagnostic(kind, message)
	self:GetDebugController():Append(message, kind)
end

function NoPoizen:RecordPoisonObservation(reason, state)
	local signature = table.concat({
		self:SafeToString(state.status),
		self:SafeToString(state.reason),
		self:SafeToString(state.activeCounts and state.activeCounts.lethal),
		self:SafeToString(state.activeCounts and state.activeCounts.nonLethal),
		self:SafeToString(state.requiredCounts and state.requiredCounts.lethal),
		self:SafeToString(state.requiredCounts and state.requiredCounts.nonLethal),
		self:SafeToString(state.activeCounts and state.activeCounts.mainHand),
		self:SafeToString(state.activeCounts and state.activeCounts.offHand),
		self:SafeToString(state.requiredCounts and state.requiredCounts.mainHand),
		self:SafeToString(state.requiredCounts and state.requiredCounts.offHand),
	}, "/")
	self.observationCount = (self.observationCount or 0) + 1
	if signature ~= self.lastObservationSignature then
		self.lastObservationSignature = signature
		self:LogDiagnostic(reason, signature)
	end
end

function NoPoizen:BuildDiagnosticReport()
	local ok, version = pcall(self.API.GetAddOnVersion, self.addonName)
	local environment = LibChev.ReadEnvironment(self.API)
	local report = LibChev.DiagnosticReport("NoPoizen", ok and version or "unknown", environment)
	local function Add(key, value)
		report:Add(key, value)
	end
	Add("historyScope", "session only")
	Add("enabled", self.isEnabled == true)
	Add("loading", self.isLoadingScreenActive == true)
	Add("audioArmed", self.audioTransitionsArmed == true)
	Add("observations", self.observationCount or 0)
	local state = self.currentPoisonState
	if state then
		Add("status", state.status)
		Add("reason", state.reason)
		Add("mode", state.detectionMode)
		Add("observable", state.observable)
		if not state.activeEnchantIDs then
			Add("knownPoisonCount", state.knownPoisonCount)
			Add("dragonTemperedBlades", state.hasDragonTemperedBlades)
		end
		local function SpellIDs(ids)
			local parts = {}
			for index, spellID in ipairs(ids or {}) do
				if index > 16 then
					break
				end
				parts[#parts + 1] = self:SafeToString(spellID)
			end
			return table.concat(parts, ",")
		end
		Add("knownSpellIDs", SpellIDs(state.knownSpellIDs))
		Add("activeSpellIDs", SpellIDs(state.activeSpellIDs))
		Add("activeEnchantIDs", SpellIDs(state.activeEnchantIDs))
		Add("trainingSpellIDs", SpellIDs(state.trainingSpellIDs))
		for _, category in ipairs({ "lethal", "nonLethal", "mainHand", "offHand" }) do
			Add(category .. "Required", state.requiredCounts and state.requiredCounts[category])
			Add(category .. "Active", state.activeCounts and state.activeCounts[category])
		end
	else
		Add("status", "No current poison observation.")
	end
	if self.GetClientCapabilityLines then
		for index, line in ipairs(self:GetClientCapabilityLines()) do
			if index > 32 then
				break
			end
			Add("capability." .. index, line)
		end
	end
	Add("historyDropped", self.diagnosticDropped or 0)
	return report:Text()
end

function NoPoizen:BuildDiagnostics()
	return self:GetDebugController():BuildDiagnosticExport()
end

function NoPoizen:ShowDiagnostics()
	return self:GetDebugController():ShowDiagnostics()
end
