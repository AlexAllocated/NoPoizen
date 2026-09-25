local NoPoizen = _G.NoPoizen
if not NoPoizen then
	return
end

-- Only addon-owned adapters are replaceable in tests. Never modify C_* tables.
local function ReadMember(object, key)
	if not NoPoizen:CanAccessTable(object) then
		return nil
	end
	local value = object[key]
	if NoPoizen:CanAccessValue(value) then
		return value
	end
	return nil
end

local function ReadMethod(object, key)
	local value = ReadMember(object, key)
	if type(value) == "function" then
		return value
	end
	return nil
end

local function ReadEnum(group, key)
	return ReadMember(ReadMember(Enum, group), key)
end

local capabilityReaders = {
	playerAura = function()
		return ReadMethod(C_UnitAuras, "GetPlayerAuraBySpellID")
	end,
	spellKnown = function()
		return ReadMethod(C_SpellBook, "IsSpellKnown")
	end,
	auraSecrecy = function()
		return ReadMethod(C_Secrets, "ShouldSpellAuraBeSecret")
	end,
	weaponEnchants = function()
		return ReadMethod(C_Item, "GetWeaponEnchantInfo")
	end,
	temporaryEnchant = function()
		return ReadMethod(C_PaperDollInfo, "GetTemporaryEnchantmentInfo")
	end,
	restrictions = function()
		return ReadMethod(C_RestrictedActions, "GetAddOnRestrictionState")
	end,
	soundVolume = function()
		return ReadMethod(C_Sound, "PlaySoundWithOptions")
	end,
}

NoPoizen.ClientDiagnosticAPI = {
	CanAccessValue = function(value)
		return NoPoizen:CanAccessValue(value)
	end,
	CanAccessTable = function(value)
		return NoPoizen:CanAccessTable(value)
	end,
	IsFiniteNumber = function(value)
		return NoPoizen:IsFiniteNumber(value)
	end,
	SafeToString = function(value)
		return NoPoizen:SafeToString(value, "<unavailable>")
	end,
	GetBuildInfo = function()
		return GetBuildInfo()
	end,
	GetProjectID = function()
		return WOW_PROJECT_ID
	end,
	GetUnitClass = function()
		return UnitClass("player")
	end,
	GetSpecialization = function()
		local method = ReadMethod(C_SpecializationInfo, "GetSpecialization")
		if method then
			return method()
		end
		if NoPoizen:CanAccessValue(GetSpecialization) and type(GetSpecialization) == "function" then
			return GetSpecialization()
		end
		return nil
	end,
	GetSpecializationInfo = function(index)
		local method = ReadMethod(C_SpecializationInfo, "GetSpecializationInfo")
		if method then
			return method(index)
		end
		if NoPoizen:CanAccessValue(GetSpecializationInfo) and type(GetSpecializationInfo) == "function" then
			return GetSpecializationInfo(index)
		end
		return nil
	end,
	HasCapability = function(name)
		return capabilityReaders[name]() ~= nil
	end,
	GetWeaponSlot = function(name)
		return ReadEnum("WeaponSlot", name)
	end,
	GetWeaponEnchants = function(slot)
		local method = ReadMethod(C_Item, "GetWeaponEnchantInfo")
		if not method then
			return nil
		end
		return method(slot)
	end,
	CanSample = function()
		if NoPoizen.isLoadingScreenActive then
			return false, "loading screen"
		end
		if not NoPoizen:CanAccessValue(InCombatLockdown) or type(InCombatLockdown) ~= "function" then
			return false, "combat state unavailable"
		end
		local inCombat = InCombatLockdown()
		if not NoPoizen:CanAccessValue(inCombat) or type(inCombat) ~= "boolean" then
			return false, "combat state unavailable"
		end
		if inCombat then
			return false, "combat"
		end
		local getState = ReadMethod(C_RestrictedActions, "GetAddOnRestrictionState")
		local inactive = ReadEnum("AddOnRestrictionState", "Inactive")
		if not getState or not NoPoizen:IsFiniteNumber(inactive) then
			return false, "restriction state unavailable"
		end
		for _, name in ipairs({ "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map", "Chat" }) do
			local restriction = ReadEnum("AddOnRestrictionType", name)
			if not NoPoizen:IsFiniteNumber(restriction) then
				return false, "restriction type unavailable"
			end
			local state = getState(restriction)
			if not NoPoizen:IsFiniteNumber(state) or state ~= inactive then
				return false, name .. " restriction active or unavailable"
			end
		end
		return true
	end,
}

local function BuildClientCapabilityLines(api)
	local lines = {}
	local function Text(value)
		if not api.CanAccessValue(value) then
			return "<unavailable>"
		end
		local kind = type(value)
		if kind ~= "string" and kind ~= "number" and kind ~= "boolean" then
			return "<unavailable>"
		end
		if kind == "number" and not api.IsFiniteNumber(value) then
			return "<unavailable>"
		end
		return string.sub(api.SafeToString(value), 1, 120):gsub("[%c|]", "?")
	end
	local ok, version, build, _, interface = pcall(api.GetBuildInfo)
	if ok then
		lines[#lines + 1] = "Client: version="
			.. Text(version)
			.. " build="
			.. Text(build)
			.. " interface="
			.. Text(interface)
	else
		lines[#lines + 1] = "Client: build unavailable"
	end
	local projectOK, project = pcall(api.GetProjectID)
	lines[#lines + 1] = "Project: " .. (projectOK and Text(project) or "<unavailable>")
	local classOK, _, classFile, classID = pcall(api.GetUnitClass)
	lines[#lines + 1] = "Class: "
		.. (classOK and Text(classFile) or "<unavailable>")
		.. " id="
		.. (classOK and Text(classID) or "<unavailable>")
	local specOK, specIndex = pcall(api.GetSpecialization)
	if specOK and api.IsFiniteNumber(specIndex) and specIndex > 0 and specIndex == math.floor(specIndex) then
		local infoOK, specID, specName = pcall(api.GetSpecializationInfo, specIndex)
		lines[#lines + 1] = "Specialization: index="
			.. Text(specIndex)
			.. " id="
			.. (infoOK and Text(specID) or "<unavailable>")
			.. " name="
			.. (infoOK and Text(specName) or "<unavailable>")
	else
		lines[#lines + 1] = "Specialization: unavailable"
	end
	local function HasCapability(name)
		local success, value = pcall(api.HasCapability, name)
		return success and api.CanAccessValue(value) and value == true
	end
	local capabilities = {}
	for _, name in ipairs({
		"playerAura",
		"spellKnown",
		"auraSecrecy",
		"weaponEnchants",
		"temporaryEnchant",
		"restrictions",
		"soundVolume",
	}) do
		capabilities[#capabilities + 1] = name .. "=" .. (HasCapability(name) and "yes" or "no/unavailable")
	end
	lines[#lines + 1] = "APIs: " .. table.concat(capabilities, " ")
	if not HasCapability("weaponEnchants") then
		lines[#lines + 1] = "Weapon samples: modern multi-enchant API unavailable"
		return lines
	end
	-- Raw samples remain separate from the detector's verified enchant catalog.
	lines[#lines + 1] = "Forever poison spell/enchant mapping: client data 1.60.1.70009; live validation pending"
	local safeOK, safe, reason = pcall(api.CanSample)
	if not safeOK or not api.CanAccessValue(safe) or safe ~= true then
		lines[#lines + 1] = "Weapon samples: skipped ("
			.. (safeOK and Text(reason) or "restriction query unavailable")
			.. ")"
		return lines
	end
	for _, slotName in ipairs({ "MainHand", "OffHand" }) do
		local slotOK, slot = pcall(api.GetWeaponSlot, slotName)
		if not slotOK or not api.IsFiniteNumber(slot) or slot < 0 or slot ~= math.floor(slot) then
			lines[#lines + 1] = slotName .. ": slot enum unavailable"
		else
			local rowsOK, rows = pcall(api.GetWeaponEnchants, slot)
			if not rowsOK or not api.CanAccessTable(rows) then
				lines[#lines + 1] = slotName .. ": enchants unavailable"
			else
				local key, count = nil, 0
				for index = 1, 9 do
					local nextOK, nextKey, row = pcall(next, rows, key)
					if not nextOK or not api.CanAccessValue(nextKey) then
						lines[#lines + 1] = slotName .. ": remaining rows unavailable"
						break
					end
					if nextKey == nil then
						if count == 0 then
							lines[#lines + 1] = slotName .. ": no enchant rows"
						end
						break
					end
					if index > 8 then
						lines[#lines + 1] = slotName .. ": additional rows omitted (limit 8)"
						break
					end
					key, count = nextKey, count + 1
					if api.CanAccessTable(row) then
						lines[#lines + 1] = slotName
							.. " enum="
							.. Text(slot)
							.. " row="
							.. index
							.. " present="
							.. Text(row.hasEnchant)
							.. " type="
							.. Text(row.enchantType)
							.. " id="
							.. Text(row.enchantID)
							.. " ms="
							.. Text(row.timeLeft)
							.. " charges="
							.. Text(row.charges)
							.. " icon="
							.. Text(row.enchantIconID)
					else
						lines[#lines + 1] = slotName .. " row=" .. index .. ": unavailable"
					end
				end
			end
		end
	end
	return lines
end

NoPoizen.Testables = NoPoizen.Testables or {}
NoPoizen.Testables.BuildClientCapabilityLines = BuildClientCapabilityLines

function NoPoizen:GetClientCapabilityLines()
	return BuildClientCapabilityLines(self.ClientDiagnosticAPI)
end
