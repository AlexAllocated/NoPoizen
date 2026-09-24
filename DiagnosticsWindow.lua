local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end
local LibChev = NoPoizen.LibChev

-- Only addon-specific data and ownership/restriction policy live here. The
-- shared library owns the console, filters, commands and test presentation.
function NoPoizen:GetDebugUIPolicy()
	return {
		parent = UIParent,
		createFrame = CreateFrame,
		restricted = function()
			return self:IsHUDRestricted()
		end,
		canMutate = function(frame)
			return self:CanMutateHUDFrame(frame)
		end,
	}
end

function NoPoizen:CreateDebugController()
	return LibChev.NewDebugController({
		addonName = self.addonName or "NoPoizen",
		getLog = function()
			self.diagnosticHistory = self.diagnosticHistory or LibChev.NewLog()
			return self.diagnosticHistory
		end,
		commitLog = function(store)
			self.diagnosticLog = store.entries
			self.diagnosticSequence = store.sequence
			self.diagnosticDropped = store.dropped
		end,
		limits = { maxLines = 60, maxEntry = 240 },
		clock = function()
			local api = self.API or {}
			if type(api.GetTime) == "function" then
				return api.GetTime()
			end
		end,
		getTests = function()
			return self:GetTestCases()
		end,
		getVersion = function()
			local ok, version = pcall((self.API or {}).GetAddOnVersion, self.addonName)
			return ok and LibChev.Text(version, "unknown") or "unknown"
		end,
		getEnvironment = function()
			return LibChev.ReadEnvironment(self.API or {})
		end,
		buildReport = function()
			return self:BuildDiagnosticReport()
		end,
		print = function(text)
			self:Print(text)
		end,
		reload = (self.API or {}).ReloadUI,
		failureDetails = true,
		ui = self:GetDebugUIPolicy(),
		onWindow = function(frame)
			self.diagnosticsWindow = frame
		end,
	})
end

function NoPoizen:GetDebugController()
	if not self.debugController then
		self.debugController = self:CreateDebugController()
	end
	return self.debugController
end

function NoPoizen:OpenDiagnosticsWindow(text)
	return self:GetDebugController():ShowReport(text, "NoPoizen Diagnostics")
end
