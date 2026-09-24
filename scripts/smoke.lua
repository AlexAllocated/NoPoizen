-- Offline integration only: never load this file into a live WoW client.
local root, client = arg[1] or ".", arg[2] or "retail"
local unpack = table.unpack or unpack
local now, timers, sounds, restricted = 0, {}, {}, false
local frameCount, chat = 0, {}
DEFAULT_CHAT_FRAME = {
	AddMessage = function(_, message)
		chat[#chat + 1] = message
	end,
}
local auras = { [2823] = true, [3408] = true }
local frameMethods = {}
local function Noop() end
for _, name in ipairs({
	"SetSize",
	"SetOrientation",
	"SetThumbTexture",
	"Raise",
	"StartSizing",
	"SetWidth",
	"SetHeight",
	"SetAllPoints",
	"SetFrameStrata",
	"SetClampedToScreen",
	"SetMovable",
	"RegisterForDrag",
	"EnableMouse",
	"SetMinMaxValues",
	"SetValueStep",
	"SetObeyStepOnDrag",
	"SetTextColor",
	"SetAlpha",
	"SetTexture",
	"SetHorizTile",
	"SetVertTile",
	"SetNormalTexture",
	"SetPushedTexture",
	"SetHighlightTexture",
	"SetBlendMode",
	"SetColorTexture",
	"SetScale",
	"SetFontObject",
	"SetMultiLine",
	"SetAutoFocus",
	"SetMaxLetters",
	"SetTextInsets",
	"SetJustifyH",
	"SetJustifyV",
	"SetScrollChild",
	"SetVerticalScroll",
	"HighlightText",
	"SetFocus",
	"ClearFocus",
	"StartMoving",
	"StopMovingOrSizing",
	"SetBackdrop",
	"SetBackdropColor",
	"SetBackdropBorderColor",
	"SetResizable",
	"SetResizeBounds",
	"EnableMouseWheel",
}) do
	frameMethods[name] = Noop
end
function frameMethods:IsForbidden()
	return false
end
function frameMethods:IsProtected()
	return false
end
function frameMethods:GetWidth()
	return 480
end
function frameMethods:GetHeight()
	return 320
end
function frameMethods:GetStringHeight()
	return 12
end
function frameMethods:GetVerticalScroll()
	return 0
end
function frameMethods:GetVerticalScrollRange()
	return 100
end
function frameMethods:GetFrameLevel()
	return 1
end
function frameMethods:SetScript(name, callback)
	self.scripts[name] = callback
end
function frameMethods:RegisterEvent(name)
	self.events[name] = true
	return true
end
function frameMethods:RegisterUnitEvent(name, unit)
	self.events[name] = unit
	return true
end
function frameMethods:UnregisterEvent(name)
	self.events[name] = nil
end
function frameMethods:SetPoint(...)
	self.point = { ... }
end
function frameMethods:GetPoint()
	return unpack(self.point or { "CENTER", UIParent, "CENTER", 0, 140 })
end
function frameMethods:ClearAllPoints()
	self.point = nil
end
function frameMethods:SetText(text)
	self.text = text
end
function frameMethods:GetText()
	return self.text
end
function frameMethods:SetChecked(value)
	self.checked = value
end
function frameMethods:GetChecked()
	return self.checked
end
function frameMethods:SetEnabled(value)
	self.enabled = value
end
function frameMethods:SetValue(value)
	self.value = value
	if self.scripts.OnValueChanged then
		self.scripts.OnValueChanged(self, value)
	end
end
function frameMethods:GetValue()
	return self.value
end
function frameMethods:Show()
	if self.shown then
		return
	end
	self.shown = true
	if self.scripts.OnShow then
		self.scripts.OnShow(self)
	end
end
function frameMethods:Hide()
	if not self.shown then
		return
	end
	self.shown = false
	if self.scripts.OnHide then
		self.scripts.OnHide(self)
	end
end
function frameMethods:IsShown()
	return self.shown
end
function frameMethods:SetShown(value)
	if value then
		self:Show()
	else
		self:Hide()
	end
end
function CreateFrame(kind, name, parent, template)
	frameCount = frameCount + 1
	local frame = setmetatable({ scripts = {}, events = {}, shown = false }, { __index = frameMethods })
	if template == "OptionsSliderTemplate" then
		frame.Text, frame.Low, frame.High = CreateFrame(), CreateFrame(), CreateFrame()
	end
	if name then
		_G[name] = frame
	end
	return frame
end
function frameMethods:CreateFontString()
	return CreateFrame()
end
function frameMethods:CreateTexture()
	return CreateFrame()
end
UIParent = CreateFrame()
SlashCmdList = {}
function wipe(t)
	for key in pairs(t) do
		t[key] = nil
	end
	return t
end
function GetTime()
	return now
end
function UnitClass()
	return "Rogue", "ROGUE", 4
end
function GetSpecialization()
	return 1
end
function GetSpecializationInfo()
	return 259, "Assassination"
end
function GetBuildInfo()
	return client == "retail" and "12.1.0" or "1.60.1", "test", "date", client == "retail" and 120100 or 16001
end
function InCombatLockdown()
	return restricted
end
function issecretvalue()
	return false
end
function canaccessvalue()
	return true
end
function canaccesstable()
	return true
end
function PlaySoundFile(path, channel)
	sounds[#sounds + 1] = path
	return true, #sounds
end
function geterrorhandler()
	return function(err)
		error(err)
	end
end
C_Timer = {
	After = function(delay, callback)
		timers[#timers + 1] = { at = now + delay, callback = callback }
	end,
}
C_RestrictedActions = {
	GetAddOnRestrictionState = function()
		return restricted and 2 or 0
	end,
}
Enum = {
	AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 },
	AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
	WeaponSlot = { MainHand = 0, OffHand = 1 },
}
C_SpellBook = {
	IsSpellKnown = function(id)
		return id == 2823 or id == 3408
	end,
}
C_Spell = {
	GetSpellName = function(id)
		return "Spell " .. id
	end,
	GetSpellTexture = function()
		return 134400
	end,
}
C_Secrets = {
	ShouldSpellAuraBeSecret = function()
		return restricted
	end,
}
C_UnitAuras = {
	GetPlayerAuraBySpellID = function(id)
		return auras[id] and {} or nil
	end,
}
C_AddOns = {
	GetAddOnMetadata = function()
		return "1.1.0-beta.3"
	end,
}
C_Item = {
	GetWeaponEnchantInfo = function()
		return {}
	end,
}
Settings = {
	RegisterCanvasLayoutCategory = function()
		return {
			GetID = function()
				return 1
			end,
		}
	end,
	RegisterAddOnCategory = Noop,
	OpenToCategory = Noop,
}
WOW_PROJECT_MAINLINE, WOW_PROJECT_ID = 1, client == "retail" and 1 or 2
-- Public callback bridge and a read-only foreign manager fixture.
local nativeCallbacks, nativeActive = {}, false
EventRegistry = {
	RegisterCallback = function(_, event, callback, owner)
		assert(type(owner) == "string", "only primitive callback ownership crosses the boundary")
		nativeCallbacks[event] = { callback = callback, owner = owner }
	end,
	UnregisterCallback = function(_, event, owner)
		local entry = nativeCallbacks[event]
		if entry and entry.owner == owner then
			nativeCallbacks[event] = nil
		end
	end,
}
EditModeManagerFrame = setmetatable({}, {
	__index = {
		IsForbidden = function()
			return false
		end,
		IsEditModeActive = function()
			return nativeActive
		end,
	},
	__newindex = function()
		error("addon wrote to Blizzard Edit Mode manager")
	end,
})
local function NativeEvent(event)
	nativeActive = event == "EditMode.Enter"
	local entry = nativeCallbacks[event]
	if entry then
		entry.callback(entry.owner)
	end
end
local namespace = {}
for line in io.lines(root .. "/NoPoizen.toc") do
	if line:match("%.lua$") then
		assert(loadfile(root .. "/" .. line))("NoPoizen", namespace)
	end
end
local function Advance(seconds)
	now = now + seconds
	local pending = timers
	timers = {}
	for _, timer in ipairs(pending) do
		if timer.at <= now then
			timer.callback()
		else
			timers[#timers + 1] = timer
		end
	end
end
NoPoizen:ADDON_LOADED("ADDON_LOADED", "NoPoizen")
NoPoizen:PLAYER_LOGIN()
assert(NoPoizen.isEnabled and NoPoizen.optionsCategory)
Advance(5)
assert(#sounds == 0, "initial state must be quiet")
if client == "retail" then
	assert(NoPoizen.currentPoisonState.status == "satisfied")
	auras[2823] = nil
	NoPoizen:UNIT_AURA("UNIT_AURA", "player")
	assert(NoPoizen.currentPoisonState.status == "missing" and #sounds == 1)
	assert(NoPoizen.poisonIndicatorHostFrame:IsShown())
	restricted = true
	NoPoizen:ADDON_RESTRICTION_STATE_CHANGED()
	Advance(0)
	assert(NoPoizen.currentPoisonState.status == "unknown" and #sounds == 1)
	assert(not NoPoizen.poisonIndicatorHostFrame:IsShown())
	restricted = false
	NoPoizen:ADDON_RESTRICTION_STATE_CHANGED()
	Advance(0)
	assert(NoPoizen.currentPoisonState.status == "missing" and #sounds == 1)
	auras[2823] = true
	NoPoizen:UNIT_AURA("UNIT_AURA", "player")
	assert(NoPoizen.currentPoisonState.status == "satisfied" and #sounds == 2)
else
	assert(NoPoizen.currentPoisonState.status == "unsupported")
end
assert(NoPoizen:OpenHudEditMode())
NoPoizen:SetOption("widgetScale", 1.5)
NoPoizen:EndPoisonIndicatorEditMode(false)
assert(NoPoizen.db.widgetScale == 1)
assert(NoPoizen:OpenOptionsWindow())
NativeEvent("EditMode.Enter")
assert(NoPoizen:IsPoisonIndicatorInEditMode() and not NoPoizen.poisonIndicatorEditDialog:IsShown())
NoPoizen.poisonIndicatorHostFrame.scripts.OnMouseUp(NoPoizen.poisonIndicatorHostFrame, "LeftButton")
assert(NoPoizen.poisonIndicatorEditDialog:IsShown())
NoPoizen:SetOption("widgetScale", 1.5)
NoPoizen:FinishPoisonIndicatorEditMode(true)
assert(NoPoizen:IsPoisonIndicatorInEditMode() and not NoPoizen.poisonIndicatorEditDialog:IsShown())
NoPoizen:SetOption("widgetScale", 1.8)
NativeEvent("EditMode.Exit")
assert(NoPoizen.db.widgetScale == 1.5 and not NoPoizen.poisonIndicatorEditActive)
NoPoizen:SetOption("widgetScale", 1)

local database, state, runtime, pendingTimers, soundCount =
	NoPoizen.db, NoPoizen.currentPoisonState, NoPoizen.registeredRuntimeEvents, #timers, #sounds
local liveLog = NoPoizen.diagnosticHistory
local liveEntries, liveSequence, liveDropped = liveLog.entries, liveLog.sequence, liveLog.dropped
local liveLogText = {}
for i, entry in ipairs(liveEntries) do
	liveLogText[i] = NoPoizen.LibChev.FormatEntry(entry)
end
local function AssertOriginalLog()
	assert(NoPoizen.diagnosticHistory == liveLog and liveLog.entries == liveEntries)
	assert(liveLog.sequence == liveSequence and liveLog.dropped == liveDropped and #liveEntries == #liveLogText)
	for i, entry in ipairs(liveEntries) do
		assert(NoPoizen.LibChev.FormatEntry(entry) == liveLogText[i])
	end
end
local headlessFrames = frameCount
local success, passed, failed = NoPoizen:RunTests()
assert(success and failed == 0)
assert(NoPoizen:RunTests(true))
assert(frameCount == headlessFrames and NoPoizen.diagnosticsWindow == nil, "headless tests must not create frames")
AssertOriginalLog()
SlashCmdList.NOPOIZEN("test")
local testWindow = assert(NoPoizen.diagnosticsWindow)
local controller = NoPoizen:GetDebugController()
assert(testWindow:IsShown() and controller.window == testWindow)
local summary = string.format("Test summary: %d passed, 0 failed (%d total).", passed, passed)
assert(testWindow.TextBox:GetText():find(summary, 1, true))
local _, summaryEnd = testWindow.TextBox:GetText():find(summary, 1, true)
assert(not testWindow.TextBox:GetText():find(summary, summaryEnd + 1, true), "test console must show one summary")
assert(controller:GetCategory() == "TEST")
for _, button in ipairs({ "select", "clear", "reload", "tests", "diagnostics", "log" }) do
	assert(testWindow.Buttons[button], "shared console control missing: " .. button)
end
local reportFrames = frameCount
NoPoizen:ShowDiagnostics()
assert(controller.mode == "report" and testWindow.TextBox:GetText():find("historyScope=session only", 1, true))
SlashCmdList.NOPOIZEN("test")
assert(
	NoPoizen.diagnosticsWindow == testWindow and frameCount == reportFrames,
	"slash tests must reuse the shared console"
)
assert(controller.mode == "log" and testWindow.TextBox:GetText():find(summary, 1, true))
local currentText, currentLog, currentSequence =
	testWindow.TextBox:GetText(), NoPoizen.diagnosticLog, NoPoizen.diagnosticSequence
assert(NoPoizen:RunTests())
assert(
	testWindow.TextBox:GetText() == currentText and frameCount == reportFrames,
	"headless tests must leave existing UI unchanged"
)
assert(NoPoizen.diagnosticLog == currentLog and NoPoizen.diagnosticSequence == currentSequence)
-- Shared search/category controls operate on the same addon-owned event log.
NoPoizen:LogDiagnostic("poison", "private poison observation")
SlashCmdList.NOPOIZEN("dump poison")
assert(controller:GetCategory() == "POISON")
testWindow.Search:SetText('"private poison"')
testWindow.Search.scripts.OnTextChanged(testWindow.Search, true)
assert(controller:GetSearch() == '"private poison"')
assert(testWindow.TextBox:GetText():find("private poison observation", 1, true))
controller:SetCategory("ALL")
testWindow.Buttons.tests.scripts.OnClick(testWindow.Buttons.tests)
assert(
	controller:GetCategory() == "ALL" and controller:GetSearch() == "",
	"visible ALL view must survive test presentation"
)
assert(testWindow.TextBox:GetText():find(summary, 1, true))
-- Failure injection is confined to this offline harness, never the live suite.
NoPoizen.tests["offline presentation failure"] = function()
	error("offline failure details")
end
SlashCmdList.NOPOIZEN("test")
local failureText = testWindow.TextBox:GetText()
assert(failureText:find(string.format("%d passed, 1 failed (%d total)", passed, passed + 1), 1, true))
assert(failureText:find("offline presentation failure", 1, true))
assert(failureText:find("offline failure details", 1, true))
NoPoizen.tests["offline presentation failure"] = nil
testWindow:Hide()
restricted = true
chat = {}
SlashCmdList.NOPOIZEN("test")
assert(not testWindow:IsShown() and frameCount == reportFrames, "restricted tests must not open or create UI")
local fallback = table.concat(chat, "\n")
assert(fallback:find("Debug console unavailable", 1, true))
assert(fallback:find(summary, 1, true))
restricted = false
assert(NoPoizen.db == database and NoPoizen.currentPoisonState == state and NoPoizen.registeredRuntimeEvents == runtime)
assert(#timers == pendingTimers and #sounds == soundCount, "tests must not invoke live adapters")
NoPoizen:ShowDiagnostics()
NoPoizen:LOADING_SCREEN_ENABLED()
assert(NoPoizen.currentPoisonState == nil and not NoPoizen.poisonIndicatorHostFrame:IsShown())
NoPoizen:LOADING_SCREEN_DISABLED()
NoPoizen:Disable()
assert(next(nativeCallbacks) == nil)
Advance(2)
assert(not NoPoizen.isEnabled and NoPoizen.currentPoisonState == nil)
NoPoizen:Enable()
Advance(5)
assert(NoPoizen:OpenHudEditMode())
NoPoizen:SetOption("widgetScale", 1.5)
local beforeLogout = NoPoizen.observationCount
NoPoizen:HandleHUDLifecycleEvent(NoPoizen.hudLifecycleFrame, "PLAYER_LOGOUT")
assert(NoPoizen.db.widgetScale == 1 and NoPoizen.db.enabled == true)
Advance(10)
NoPoizen:RefreshPoisonState("AFTER_LOGOUT")
assert(NoPoizen.observationCount == beforeLogout, "logout must not read more auras")
print("Offline " .. client .. " startup/UI/transition/test-isolation smoke passed.")
