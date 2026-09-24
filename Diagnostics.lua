local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end
local LibChev = NoPoizen.LibChev

-- Only sanitized primitives enter this addon-owned, session-only bounded history.
function NoPoizen:LogDiagnostic(kind, message)
	self.diagnosticHistory = self.diagnosticHistory or LibChev.NewLog()
	local now
	if self.API and type(self.API.GetTime) == "function" then
		local ok, value = pcall(self.API.GetTime)
		if ok then
			now = LibChev.Number(value)
		end
	end
	LibChev.AppendLog(self.diagnosticHistory, message, kind, now, { maxLines = 60, maxEntry = 240 })
	self.diagnosticLog = self.diagnosticHistory.entries
	self.diagnosticSequence = self.diagnosticHistory.sequence
	self.diagnosticDropped = self.diagnosticHistory.dropped
end

function NoPoizen:RecordPoisonObservation(reason, state)
	local signature = table.concat({
		self:SafeToString(state.status),
		self:SafeToString(state.reason),
		self:SafeToString(state.activeCounts and state.activeCounts.lethal),
		self:SafeToString(state.activeCounts and state.activeCounts.nonLethal),
		self:SafeToString(state.requiredCounts and state.requiredCounts.lethal),
		self:SafeToString(state.requiredCounts and state.requiredCounts.nonLethal),
	}, "/")
	self.observationCount = (self.observationCount or 0) + 1
	if signature ~= self.lastObservationSignature then
		self.lastObservationSignature = signature
		self:LogDiagnostic(reason, signature)
	end
end

function NoPoizen:BuildDiagnostics()
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
		Add("knownPoisonCount", state.knownPoisonCount)
		Add("dragonTemperedBlades", state.hasDragonTemperedBlades)
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
		for _, category in ipairs({ "lethal", "nonLethal" }) do
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
	for index, entry in ipairs(self.diagnosticLog or {}) do
		if index > 60 then
			break
		end
		Add("history." .. index, LibChev.FormatEntry(entry))
	end
	return report:Text()
end

function NoPoizen:ShowDiagnostics()
	local report = self:BuildDiagnostics()
	if self.OpenDiagnosticsWindow and self:OpenDiagnosticsWindow(report) then
		return
	end
	-- A chat report also works while Settings/Edit Mode cannot be opened.
	for line in report:gmatch("[^\n]+") do
		self:Print(line)
	end
end
