local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end

-- Only sanitized primitives enter this addon-owned, session-only bounded history.
function NoPoizen:LogDiagnostic(kind, message)
	self.diagnosticLog = self.diagnosticLog or {}
	self.diagnosticSequence = (self.diagnosticSequence or 0) + 1
	local entry = string.format(
		"%d %s: %s",
		self.diagnosticSequence,
		self:SafeToString(kind):sub(1, 32),
		self:SafeToString(message):sub(1, 240)
	)
	table.insert(self.diagnosticLog, entry)
	if #self.diagnosticLog > 60 then
		table.remove(self.diagnosticLog, 1)
		self.diagnosticDropped = (self.diagnosticDropped or 0) + 1
	end
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
	local lines =
		{ "NoPoizen " .. (ok and self:SafeToString(version, "unknown") or "unknown") .. " diagnostics (session only)" }
	local function Add(key, value)
		lines[#lines + 1] = key .. "=" .. self:SafeToString(value)
	end
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
		lines[#lines + 1] = "No current poison observation."
	end
	if self.GetClientCapabilityLines then
		for _, line in ipairs(self:GetClientCapabilityLines()) do
			lines[#lines + 1] = line
		end
	end
	Add("historyDropped", self.diagnosticDropped or 0)
	for _, entry in ipairs(self.diagnosticLog or {}) do
		lines[#lines + 1] = entry
	end
	return table.concat(lines, "\n")
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
