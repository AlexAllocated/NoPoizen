local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end

-- Public notifications only. No manager mutation, internal hooks, template
-- overrides, or insertion into Blizzard's registeredSystemFrames.
local OWNER = "NoPoizen.EditMode"
local function GetRegistry()
	if not NoPoizen:CanAccessTable(EventRegistry) then
		return nil
	end
	if type(EventRegistry.RegisterCallback) ~= "function" or type(EventRegistry.UnregisterCallback) ~= "function" then
		return nil
	end
	return EventRegistry
end

NoPoizen.EditModeAPI = {
	Register = function(event, callback)
		local registry = GetRegistry()
		if not registry then
			return false
		end
		registry:RegisterCallback(event, callback, OWNER)
		return true
	end,
	Unregister = function(event)
		local registry = GetRegistry()
		if registry then
			registry:UnregisterCallback(event, OWNER)
		end
	end,
	IsActive = function()
		local frame = EditModeManagerFrame
		if not NoPoizen:CanAccessTable(frame) then
			return false
		end
		local forbidden = frame:IsForbidden()
		if not NoPoizen:CanAccessValue(forbidden) or forbidden ~= false then
			return false
		end
		if type(frame.IsEditModeActive) ~= "function" then
			return false
		end
		local active = frame:IsEditModeActive()
		return NoPoizen:CanAccessValue(active) and active == true
	end,
}

function NoPoizen:OnBlizzardEditModeEnter()
	if not self.isEnabled or self.isLoggingOut or self.isLoadingScreenActive or self:IsHUDRestricted() then
		return
	end
	self.blizzardEditModeActive = true
	self:BeginPoisonIndicatorEditMode("blizzard", false)
end

function NoPoizen:OnBlizzardEditModeExit()
	self.blizzardEditModeActive = false
	local session = self.poisonIndicatorEditSession
	if session and session.source == "blizzard" then
		self:EndPoisonIndicatorEditMode(false)
	end
end

function NoPoizen:TryRegisterEditModeCallbacks()
	if self.editModeCallbacksRegistered then
		return true
	end
	if not self.EditModeAPI or not self.isEnabled or self.isLoggingOut or self:IsHUDRestricted() then
		return false
	end
	self.editModeCallbackGeneration = (self.editModeCallbackGeneration or 0) + 1
	local generation = self.editModeCallbackGeneration
	local function Current()
		return self.isEnabled and not self.isLoggingOut and self.editModeCallbackGeneration == generation
	end
	local enterOK, enter = pcall(self.EditModeAPI.Register, "EditMode.Enter", function()
		if Current() then
			self:OnBlizzardEditModeEnter()
		end
	end)
	local exitOK, leave = pcall(self.EditModeAPI.Register, "EditMode.Exit", function()
		if Current() then
			self:OnBlizzardEditModeExit()
		end
	end)
	if not enterOK or enter ~= true or not exitOK or leave ~= true then
		self:UnregisterEditModeCallbacks()
		return false
	end
	self.editModeCallbacksRegistered = true
	-- Enabling while Edit Mode is already open does not emit another Enter event.
	local ok, active = pcall(self.EditModeAPI.IsActive)
	if ok and self:CanAccessValue(active) and active == true then
		self:OnBlizzardEditModeEnter()
	end
	return true
end

function NoPoizen:UnregisterEditModeCallbacks()
	-- Invalidate closures first, including partial registration and queued delivery.
	self.editModeCallbackGeneration = (self.editModeCallbackGeneration or 0) + 1
	self.editModeCallbacksRegistered = false
	self.blizzardEditModeActive = false
	if self.EditModeAPI then
		pcall(self.EditModeAPI.Unregister, "EditMode.Enter")
		pcall(self.EditModeAPI.Unregister, "EditMode.Exit")
	end
end
