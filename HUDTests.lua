local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end

local function Equal(actual, expected, context)
	assert(actual == expected, context or "unexpected HUD result")
end

local function Frame()
	return {
		IsForbidden = function(self)
			return self.forbidden == true
		end,
		IsProtected = function(self)
			return self.protected == true
		end,
		StopMovingOrSizing = function(self)
			self.stopped = true
		end,
		Hide = function(self)
			self.shown = false
		end,
		Show = function(self)
			self.shown = true
		end,
		SetScript = function(self, script, callback)
			self[script] = callback
		end,
		GetPoint = function()
			return "CENTER", nil, "CENTER", 84, -12
		end,
	}
end

local function Fixture()
	local fixture = NoPoizen:CreateTestFixture()
	fixture.HUDAPI = {
		IsRestricted = function()
			return false
		end,
	}
	fixture.poisonIndicatorHostFrame = Frame()
	fixture.poisonIndicatorEditDialog = Frame()
	fixture.EnsurePoisonIndicatorWidget = function(self)
		return self.poisonIndicatorHostFrame
	end
	fixture.EndPoisonIndicatorEditMode = NoPoizen.EndPoisonIndicatorEditMode
	fixture.RefreshPoisonState = function() end
	fixture.RefreshPoisonIndicatorEditDialog = function() end
	fixture.InitializeOptionsWindow = function(self)
		self.optionsInitialized = true
	end
	fixture.RefreshPoisonIndicatorVisualState = function(self)
		self.refreshes = (self.refreshes or 0) + 1
	end
	return fixture
end

NoPoizen:RegisterTest("HUD editor refuses disabled loading and restricted states", function()
	local f = Fixture()
	f.isEnabled = false
	Equal(f:BeginPoisonIndicatorEditMode(), false)
	f.isEnabled, f.isLoadingScreenActive = true, true
	Equal(f:BeginPoisonIndicatorEditMode(), false)
	f.isLoadingScreenActive = false
	f.HUDAPI.IsRestricted = function()
		return true
	end
	Equal(f:BeginPoisonIndicatorEditMode(), false)
	Equal(f.poisonIndicatorEditSession, nil)
end)

NoPoizen:RegisterTest("HUD edit snapshot is copied and retained when reopened", function()
	local f = Fixture()
	Equal(f:BeginPoisonIndicatorEditMode(), true)
	f:SetOption("widgetScale", 1.5)
	f:SetIndicatorAnchor("TOP", "TOP", 15, -50)
	Equal(f:BeginPoisonIndicatorEditMode(), true)
	Equal(f.poisonIndicatorEditSession.saved.widgetScale, 1)
	Equal(f.poisonIndicatorEditSession.saved.anchor.point, "CENTER")
	Equal(f.poisonIndicatorEditSession.saved.anchor.y, 140)
end)

NoPoizen:RegisterTest("HUD cancel restores scale and position and stops dragging", function()
	local f = Fixture()
	f:BeginPoisonIndicatorEditMode()
	f:SetOption("widgetScale", 1.5)
	f:SetIndicatorAnchor("TOP", "TOP", 15, -50)
	f:EndPoisonIndicatorEditMode(false)
	Equal(f:GetOption("widgetScale"), 1)
	Equal(f:GetIndicatorAnchor().point, "CENTER")
	Equal(f:GetIndicatorAnchor().y, 140)
	Equal(f.poisonIndicatorEditActive, false)
	Equal(f.poisonIndicatorEditSession, nil)
	Equal(f.poisonIndicatorHostFrame.stopped, true)
	Equal(f.poisonIndicatorEditDialog.shown, false)
end)

NoPoizen:RegisterTest("HUD save retains settings and next edit snapshots them", function()
	local f = Fixture()
	f:BeginPoisonIndicatorEditMode()
	f:SetOption("widgetScale", 1.5)
	f:SetIndicatorAnchor("TOP", "TOP", 15, -50)
	f:EndPoisonIndicatorEditMode(true)
	Equal(f:GetOption("widgetScale"), 1.5)
	Equal(f:GetIndicatorAnchor().point, "TOP")
	f:BeginPoisonIndicatorEditMode()
	Equal(f.poisonIndicatorEditSession.saved.widgetScale, 1.5)
end)

NoPoizen:RegisterTest("HUD stale session cannot save or revert a replacement database", function()
	local f = Fixture()
	local originalDB = f.db
	f:BeginPoisonIndicatorEditMode()
	f:SetOption("widgetScale", 1.5)
	f.db = f:DeepCopy(f.DEFAULTS)
	f.db.widgetScale = 0.8
	f.db.indicatorAnchor.y = -75
	Equal(f:IsPoisonIndicatorInEditMode(), false)
	Equal(f:SaveIndicatorAnchorFromFrame(f.poisonIndicatorHostFrame), false)
	f:EndPoisonIndicatorEditMode(true)
	Equal(f.db.widgetScale, 0.8)
	Equal(f.db.indicatorAnchor.y, -75)
	Equal(originalDB.widgetScale, 1)
end)

NoPoizen:RegisterTest("HUD default reset can be cancelled to prior saved settings", function()
	local f = Fixture()
	f:SetOption("widgetScale", 1.5)
	f:SetIndicatorAnchor("TOP", "TOP", 15, -50)
	f:BeginPoisonIndicatorEditMode()
	f:ResetPoisonIndicatorEditSessionToDefaults()
	Equal(f:GetOption("widgetScale"), 1)
	f:EndPoisonIndicatorEditMode(false)
	Equal(f:GetOption("widgetScale"), 1.5)
	Equal(f:GetIndicatorAnchor().point, "TOP")
end)

NoPoizen:RegisterTest("HUD drag cannot persist after editor cancellation", function()
	local f = Fixture()
	f:BeginPoisonIndicatorEditMode()
	f:EndPoisonIndicatorEditMode(false)
	Equal(f:SaveIndicatorAnchorFromFrame(f.poisonIndicatorHostFrame), false)
	Equal(f:GetIndicatorAnchor().y, 140)
end)

NoPoizen:RegisterTest("HUD guards refuse forbidden protected and unreadable frames", function()
	local f, frame = Fixture(), Frame()
	Equal(f:CanMutateHUDFrame(frame), true)
	frame.forbidden = true
	frame.IsProtected = function()
		error("forbidden frame reached IsProtected")
	end
	Equal(f:CanMutateHUDFrame(frame), false)
	frame = Frame()
	frame.protected = true
	Equal(f:CanMutateHUDFrame(frame), false)
	f.CanAccessValue = function(_, value)
		return value ~= frame
	end
	frame.IsForbidden = function()
		error("inaccessible frame touched")
	end
	Equal(f:CanMutateHUDFrame(frame), false)
end)

NoPoizen:RegisterTest("HUD restriction checks fail closed on errors and unknown values", function()
	local f = Fixture()
	Equal(f:IsHUDRestricted(), false)
	f.HUDAPI.IsRestricted = function()
		error("not available")
	end
	Equal(f:IsHUDRestricted(), true)
	f.HUDAPI.IsRestricted = function()
		return nil
	end
	Equal(f:IsHUDRestricted(), true)
	f.HUDAPI.IsRestricted = function()
		return false
	end
	f.hudRestrictionTransition = true
	Equal(f:IsHUDRestricted(), true)
end)

NoPoizen:RegisterTest("HUD restriction activation cancels edits despite temporary false query", function()
	local f, listener = Fixture(), Frame()
	f:BeginPoisonIndicatorEditMode()
	f:SetOption("widgetScale", 1.5)
	f:HandleHUDLifecycleEvent(listener, "ADDON_RESTRICTION_STATE_CHANGED", 1, 1)
	Equal(f:IsHUDRestricted(), true)
	Equal(f.poisonIndicatorEditActive, false)
	Equal(f:GetOption("widgetScale"), 1)
	assert(type(listener.OnUpdate) == "function")
	listener.OnUpdate()
	Equal(listener.OnUpdate, nil)
	Equal(f:IsHUDRestricted(), false)
end)

NoPoizen:RegisterTest("HUD restriction deactivation retries settings after event dispatch", function()
	local f, listener = Fixture(), Frame()
	f.pendingOptionsRegistration = true
	f:HandleHUDLifecycleEvent(listener, "ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	Equal(f.optionsInitialized, nil)
	listener.OnUpdate()
	Equal(f.optionsInitialized, true)
	Equal(listener.OnUpdate, nil)
end)

NoPoizen:RegisterTest("HUD lifecycle callback cannot reopen disabled editor", function()
	local f, listener = Fixture(), Frame()
	f:BeginPoisonIndicatorEditMode()
	f:HandleHUDLifecycleEvent(listener, "PLAYER_REGEN_DISABLED")
	f.isEnabled = false
	listener.OnUpdate()
	Equal(f.poisonIndicatorEditActive, false)
	Equal(f.poisonIndicatorEditDialog.shown, false)
end)

NoPoizen:RegisterTest("HUD logout cancels unsaved settings before serialization", function()
	local f, listener = Fixture(), Frame()
	f:BeginPoisonIndicatorEditMode()
	f:SetOption("widgetScale", 1.5)
	f:HandleHUDLifecycleEvent(listener, "PLAYER_REGEN_ENABLED")
	assert(listener.OnUpdate)
	f:HandleHUDLifecycleEvent(listener, "PLAYER_LOGOUT")
	Equal(f:GetOption("widgetScale"), 1)
	Equal(f.poisonIndicatorEditActive, false)
	Equal(listener.OnUpdate, nil)
end)

NoPoizen:RegisterTest("HUD options opening is blocked before client API access", function()
	local f = Fixture()
	f.HUDAPI.IsRestricted = function()
		return true
	end
	f.InitializeOptionsWindow = function()
		error("should not initialize restricted options")
	end
	Equal(f:OpenOptionsWindow(), false)
	Equal(f:TryRegisterOptionsCategory(), false)
	Equal(f.pendingOptionsRegistration, true)
end)

NoPoizen:RegisterTest("HUD stale options controls cannot write a replacement database", function()
	local f = Fixture()
	f.optionControls = { database = f.db }
	Equal(f:ApplyOptionsControlValue("audioVolume", 0.7), true)
	f.db = f:DeepCopy(f.DEFAULTS)
	Equal(f:ApplyOptionsControlValue("audioVolume", 0.9), false)
	Equal(f.db.audioVolume, f.DEFAULTS.audioVolume)
end)

local function NativeFixture()
	local f = Fixture()
	local registry = { callbacks = {}, active = false, registrations = 0 }
	f.EditModeAPI = {
		Register = function(event, callback)
			registry.callbacks[event] = callback
			registry.registrations = registry.registrations + 1
			return true
		end,
		Unregister = function(event)
			registry.callbacks[event] = nil
		end,
		IsActive = function()
			return registry.active
		end,
	}
	function registry:Fire(event)
		self.active = event == "EditMode.Enter"
		local callback = self.callbacks[event]
		if callback then
			callback("private-owner")
		end
	end
	return f, registry
end

NoPoizen:RegisterTest("native Edit Mode opens preview and clicking opens settings", function()
	local f, registry = NativeFixture()
	Equal(f:TryRegisterEditModeCallbacks(), true)
	registry:Fire("EditMode.Enter")
	Equal(f:IsPoisonIndicatorInEditMode(), true)
	Equal(f.poisonIndicatorEditSession.source, "blizzard")
	Equal(f.poisonIndicatorEditDialog.shown, nil)
	f:BeginPoisonIndicatorEditMode()
	Equal(f.poisonIndicatorEditDialog.shown, true)
	f:SetOption("widgetScale", 1.5)
	registry:Fire("EditMode.Exit")
	Equal(f:GetOption("widgetScale"), 1)
	Equal(f.poisonIndicatorEditActive, false)
end)

NoPoizen:RegisterTest("native save retains changes and keeps preview editable", function()
	local f, registry = NativeFixture()
	f:TryRegisterEditModeCallbacks()
	registry:Fire("EditMode.Enter")
	f:BeginPoisonIndicatorEditMode()
	f:SetOption("widgetScale", 1.5)
	f:FinishPoisonIndicatorEditMode(true)
	Equal(f:GetOption("widgetScale"), 1.5)
	Equal(f:IsPoisonIndicatorInEditMode(), true)
	Equal(f.poisonIndicatorEditDialog.shown, false)
	f:SetOption("widgetScale", 1.8)
	registry:Fire("EditMode.Exit")
	Equal(f:GetOption("widgetScale"), 1.5)
end)

NoPoizen:RegisterTest("native cancel reverts without removing the preview", function()
	local f, registry = NativeFixture()
	f:TryRegisterEditModeCallbacks()
	registry:Fire("EditMode.Enter")
	f:SetOption("widgetScale", 1.5)
	f:FinishPoisonIndicatorEditMode(false)
	Equal(f:GetOption("widgetScale"), 1)
	Equal(f:IsPoisonIndicatorInEditMode(), true)
end)

NoPoizen:RegisterTest("native registration is idempotent and reconciles already open mode", function()
	local f, registry = NativeFixture()
	registry.active = true
	f:TryRegisterEditModeCallbacks()
	f:TryRegisterEditModeCallbacks()
	Equal(registry.registrations, 2)
	Equal(f:IsPoisonIndicatorInEditMode(), true)
end)

NoPoizen:RegisterTest("native disable unregisters and stale callbacks cannot affect a new lifetime", function()
	local f, registry = NativeFixture()
	f:TryRegisterEditModeCallbacks()
	local oldEnter, oldExit = registry.callbacks["EditMode.Enter"], registry.callbacks["EditMode.Exit"]
	registry:Fire("EditMode.Enter")
	f:SetOption("widgetScale", 1.5)
	f:Disable()
	Equal(next(registry.callbacks), nil)
	Equal(f:GetOption("widgetScale"), 1)
	oldEnter()
	Equal(f.poisonIndicatorEditActive, false)
	f.isEnabled = true
	f:TryRegisterEditModeCallbacks()
	oldExit()
	Equal(f:IsPoisonIndicatorInEditMode(), true)
end)

NoPoizen:RegisterTest("native partial registration rolls back and may retry", function()
	local f, registry = NativeFixture()
	local register = f.EditModeAPI.Register
	f.EditModeAPI.Register = function(event, callback)
		register(event, callback)
		if event == "EditMode.Exit" then
			error("partial failure")
		end
		return true
	end
	Equal(f:TryRegisterEditModeCallbacks(), false)
	Equal(next(registry.callbacks), nil)
	f.EditModeAPI.Register = register
	Equal(f:TryRegisterEditModeCallbacks(), true)
end)

NoPoizen:RegisterTest("native callbacks respect restrictions loading and disable", function()
	local f, registry = NativeFixture()
	f:TryRegisterEditModeCallbacks()
	f.HUDAPI.IsRestricted = function()
		return true
	end
	registry:Fire("EditMode.Enter")
	Equal(f.poisonIndicatorEditSession, nil)
	f.HUDAPI.IsRestricted = function()
		return false
	end
	f.isLoadingScreenActive = true
	registry:Fire("EditMode.Enter")
	Equal(f.poisonIndicatorEditSession, nil)
	f.isLoadingScreenActive, f.isEnabled = false, false
	registry:Fire("EditMode.Enter")
	Equal(f.poisonIndicatorEditSession, nil)
end)

NoPoizen:RegisterTest("native restricted registration retries after lifecycle reconciliation", function()
	local f, registry = NativeFixture()
	f.HUDAPI.IsRestricted = function()
		return true
	end
	Equal(f:TryRegisterEditModeCallbacks(), false)
	Equal(registry.registrations, 0)
	f.HUDAPI.IsRestricted = function()
		return false
	end
	local listener = Frame()
	f:HandleHUDLifecycleEvent(listener, "PLAYER_REGEN_ENABLED")
	listener.OnUpdate()
	Equal(registry.registrations, 2)
end)

NoPoizen:RegisterTest("native logout unregisters and cancels unsaved edits", function()
	local f, registry = NativeFixture()
	f:TryRegisterEditModeCallbacks()
	local enter = registry.callbacks["EditMode.Enter"]
	registry:Fire("EditMode.Enter")
	f:SetOption("widgetScale", 1.5)
	f:HandleHUDLifecycleEvent(Frame(), "PLAYER_LOGOUT")
	Equal(next(registry.callbacks), nil)
	Equal(f:GetOption("widgetScale"), 1)
	enter()
	Equal(f.poisonIndicatorEditActive, false)
end)

NoPoizen:RegisterTest("native exit leaves unrelated standalone editing alone", function()
	local f, registry = NativeFixture()
	f:TryRegisterEditModeCallbacks()
	f:BeginPoisonIndicatorEditMode()
	f:SetOption("widgetScale", 1.5)
	registry:Fire("EditMode.Exit")
	Equal(f:IsPoisonIndicatorInEditMode(), true)
	Equal(f:GetOption("widgetScale"), 1.5)
	f:FinishPoisonIndicatorEditMode(false)
	Equal(f.poisonIndicatorEditActive, false)
end)

NoPoizen:RegisterTest("native enter preserves an existing standalone snapshot", function()
	local f, registry = NativeFixture()
	f:TryRegisterEditModeCallbacks()
	f:BeginPoisonIndicatorEditMode()
	f:SetOption("widgetScale", 1.5)
	registry:Fire("EditMode.Enter")
	Equal(f.poisonIndicatorEditSession.source, "blizzard")
	registry:Fire("EditMode.Exit")
	Equal(f:GetOption("widgetScale"), 1)
end)
