local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end
local LibChev = NoPoizen.LibChev

function NoPoizen:OpenDiagnosticsWindow(text)
	return LibChev.OpenReportWindow(self, text, {
		title = "NoPoizen Diagnostics",
		parent = UIParent,
		createFrame = CreateFrame,
		restricted = function()
			return self:IsHUDRestricted()
		end,
		canMutate = function(frame)
			return self:CanMutateHUDFrame(frame)
		end,
	})
end
