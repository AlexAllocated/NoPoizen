local addon = _G.NoPoizen
if not addon then
	return
end

addon.Testables = addon.Testables or {}

-- Client family selects mechanics, never permission/restriction policy. The
-- adapter separately tests API availability and every foreign result.
local function ResolvePoisonClient(version)
	if type(version) ~= "string" then
		return "unsupported"
	end
	if version:match("^1%.60%.") then
		return "forever"
	end
	if version:match("^1%.15%.") then
		return "era"
	end
	if version:match("^2%.5%.") then
		return "tbc"
	end
	if version:match("^5%.5%.") then
		return "mists"
	end
	if version:match("^3%.80%.") then
		return "titan"
	end
	return "unsupported"
end
addon.Testables.ResolvePoisonClient = ResolvePoisonClient

function addon:GetPoisonClient()
	local ok, version = pcall(self.API.GetBuildInfo)
	if ok and self:CanAccessValue(version) then
		local client = ResolvePoisonClient(version)
		if client ~= "unsupported" then
			return client
		end
	end
	if
		self:CanAccessValue(WOW_PROJECT_ID)
		and WOW_PROJECT_MAINLINE ~= nil
		and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
	then
		return "retail"
	end
	return "unsupported"
end

addon.WeaponPoisonAPI = {
	CanAccessValue = function(value)
		return addon:CanAccessValue(value)
	end,
	CanAccessTable = function(value)
		return addon:CanAccessTable(value)
	end,
	CanObserve = function()
		return not addon:IsHUDRestricted()
	end,
	GetPlayerLevel = function()
		return UnitLevel("player")
	end,
	GetInventoryItemID = GetInventoryItemID,
	GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,
	GetWeaponEnchants = C_Item and C_Item.GetWeaponEnchantInfo,
	GetTemporaryEnchantmentInfo = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo,
	GetLegacyWeaponEnchants = GetWeaponEnchantInfo,
	IsEngravingEnabled = C_Engraving and C_Engraving.IsEngravingEnabled,
	GetRuneForEquipmentSlot = C_Engraving and C_Engraving.GetRuneForEquipmentSlot,
	GetWeaponSlot = function(hand)
		if not addon:CanAccessTable(Enum) or not addon:CanAccessTable(Enum.WeaponSlot) then
			return nil
		end
		return Enum.WeaponSlot[hand == "mainHand" and "MainHand" or "OffHand"]
	end,
}

local function CreateWeaponPoisonDetector(api, client, catalog, isKnown)
	local detector = {}
	local function Read(value)
		local ok, readable = pcall(api.CanAccessValue, value)
		return ok and readable == true
	end
	local function Table(value)
		if not Read(value) or type(value) ~= "table" then
			return false
		end
		local ok, readable = pcall(api.CanAccessTable, value)
		return ok and readable == true
	end
	local function Number(value)
		return Read(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
	end
	local function Query(fn, ...)
		if type(fn) ~= "function" then
			return false
		end
		return pcall(fn, ...)
	end
	local function IsWeapon(slot)
		local ok, item = Query(api.GetInventoryItemID, "player", slot)
		if not ok or not Read(item) then
			return nil
		end
		if item == nil then
			return false
		end
		if not Number(item) or item <= 0 then
			return nil
		end
		local infoOK, _, _, _, equipLoc, _, class = Query(api.GetItemInfoInstant, item)
		if not infoOK or not Number(class) or not Read(equipLoc) or type(equipLoc) ~= "string" then
			return nil
		end
		-- Shields, holdables and unequipped slots do not require a coating.
		return class == 2
			and (
				equipLoc == "INVTYPE_WEAPON"
				or equipLoc == "INVTYPE_WEAPONMAINHAND"
				or equipLoc == "INVTYPE_WEAPONOFFHAND"
				or equipLoc == "INVTYPE_2HWEAPON"
			)
	end
	local function HasDeadlyBrew()
		if client ~= "era" or type(api.IsEngravingEnabled) ~= "function" then
			return false
		end
		local ok, enabled = Query(api.IsEngravingEnabled)
		if not ok or not Read(enabled) or type(enabled) ~= "boolean" then
			return nil
		end
		if not enabled then
			return false
		end
		local runeOK, rune = Query(api.GetRuneForEquipmentSlot, 5) -- INVSLOT_CHEST
		if not runeOK or not Read(rune) then
			return nil
		end
		if rune == nil then
			return false
		end
		if not Table(rune) or not Number(rune.itemEnchantmentID) then
			return nil
		end
		-- Era SpellEffect 400080 -> enchant 6708 -> ability 399969/399965.
		-- Check the equipped rune, not whether its engraving recipe was learned.
		return rune.itemEnchantmentID == 6708
	end
	local function Classify(hasEnchant, id, remaining, charges)
		if not Read(hasEnchant) then
			return nil
		end
		if hasEnchant == false or hasEnchant == nil then
			return false
		end
		if hasEnchant ~= true or not Number(id) then
			return nil
		end
		local poison = catalog[id]
		if not poison then
			return false
		end
		if not Number(remaining) or remaining < 0 then
			return nil
		end
		if remaining == 0 then
			return false
		end
		if poison.usesCharges then
			if not Number(charges) or charges < 0 then
				return nil
			end
			if charges == 0 then
				return false
			end
		end
		return true, id
	end
	local function ObserveHand(hand, slot)
		if client == "forever" then
			local slotOK, weaponSlot = Query(api.GetWeaponSlot, hand)
			if not slotOK or not Number(weaponSlot) or weaponSlot < 0 or weaponSlot ~= math.floor(weaponSlot) then
				return nil
			end
			local ok, rows = Query(api.GetWeaponEnchants, weaponSlot)
			if not ok or not Table(rows) then
				return nil
			end
			local found, foundID, unknown = false, nil, false
			-- Blizzard iterates these rows with pairs: they need not be a dense
			-- one-based array. Gate the container and every key before advancing;
			-- next avoids invoking a foreign __pairs metamethod.
			local key
			for index = 1, 9 do
				local nextOK, nextKey, row = Query(next, rows, key)
				if not nextOK or not Read(nextKey) then
					return nil
				end
				if nextKey == nil then
					if found then
						return true, foundID
					end
					if unknown then
						return nil
					end
					return false
				end
				if type(nextKey) ~= "string" and not Number(nextKey) then
					return nil
				end
				key = nextKey
				if index == 9 or not Table(row) then
					return nil
				end
				if not Read(row.hasEnchant) or type(row.hasEnchant) ~= "boolean" then
					return nil
				end
				local active, id = Classify(row.hasEnchant, row.enchantID, row.timeLeft, row.charges)
				if active then
					found, foundID = true, id
				elseif active == nil then
					unknown = true
				end
			end
			return nil
		end
		if type(api.GetTemporaryEnchantmentInfo) == "function" then
			local ok, row = Query(api.GetTemporaryEnchantmentInfo, slot)
			if not ok or not Read(row) then
				return nil
			end
			if row == nil then
				return false
			end
			if not Table(row) then
				return nil
			end
			return Classify(true, row.enchantID, row.remainingTimeMs, row.chargesRemaining)
		end
		local ok, mh, mt, mc, mi, oh, ot, oc, oi = Query(api.GetLegacyWeaponEnchants)
		if not ok then
			return nil
		end
		if hand == "mainHand" then
			return Classify(mh, mi, mt, mc)
		end
		return Classify(oh, oi, ot, oc)
	end

	function detector:Evaluate(state)
		state.detectionMode = client .. "-weapon"
		state.requiredCounts = { mainHand = 0, offHand = 0 }
		state.activeCounts = { mainHand = 0, offHand = 0 }
		state.missingCounts = { mainHand = 0, offHand = 0, total = 0 }
		state.activeEnchantIDs = {}
		state.trainingSpellIDs = {}
		local safeOK, safe = Query(api.CanObserve)
		if not safeOK or not Read(safe) or safe ~= true then
			state.reason = "weapon-observation-restricted"
			return state
		end
		local deadlyBrew = HasDeadlyBrew()
		if deadlyBrew == nil then
			state.reason = "rune-observation-unavailable"
			return state
		end
		state.deadlyBrew = deadlyBrew
		local trained, knowledgeUnknown = deadlyBrew, false
		-- Wrath-derived Titan poisons are purchased rather than crafted. The
		-- first usable coating (Instant Poison) requires level 20 in its data.
		if client == "titan" then
			local levelOK, level = Query(api.GetPlayerLevel)
			if not levelOK or not Number(level) then
				state.reason = "level-unavailable"
				return state
			end
			if level < 20 then
				state.status, state.reason = "ineligible", "poisons-not-available"
				return state
			end
			trained = true
		end
		local training = client == "forever" and { 2842, 1298494 } or { 2842 }
		for _, spellID in ipairs(training) do
			local known = isKnown(spellID)
			if known then
				trained = true
				state.trainingSpellIDs[#state.trainingSpellIDs + 1] = spellID
			elseif known == nil then
				knowledgeUnknown = true
			end
		end
		if not trained then
			state.status = knowledgeUnknown and "unknown" or "ineligible"
			state.reason = knowledgeUnknown and "spell-knowledge-unavailable" or "poisons-not-learned"
			return state
		end
		state.eligible = true
		local unknown, weapons = false, 0
		for index, hand in ipairs({ "mainHand", "offHand" }) do
			local slot = index + 15
			local equipped = IsWeapon(slot)
			if equipped == nil then
				unknown = true
			end
			if equipped then
				weapons = weapons + 1
				state.requiredCounts[hand] = 1
				local active, id
				if deadlyBrew then
					active = true
				else
					active, id = ObserveHand(hand, slot)
				end
				if active == nil then
					unknown = true
				end
				if active then
					state.activeCounts[hand] = 1
					if id then
						state.activeEnchantIDs[#state.activeEnchantIDs + 1] = id
					end
				elseif active == false then
					state.missingCounts[hand] = 1
					state.missingCounts.total = state.missingCounts.total + 1
					state.indicatorRows[#state.indicatorRows + 1] =
						{ category = hand, icons = { { icon = 132273, name = "Weapon poison" } } }
				end
			end
		end
		if unknown then
			state.reason, state.indicatorRows = "weapon-observation-unavailable", {}
			return state
		end
		if weapons == 0 then
			state.status, state.reason, state.eligible = "ineligible", "no-equipped-weapons", false
			return state
		end
		state.observable = true
		state.hasMissing = state.missingCounts.total > 0
		state.status = state.hasMissing and "missing" or "satisfied"
		state.reason = state.hasMissing and "weapon-poison-missing" or "weapons-poisoned"
		return state
	end
	return detector
end
addon.Testables.CreateWeaponPoisonDetector = CreateWeaponPoisonDetector

function addon:StartWeaponPoisonPolling()
	if not self.weaponPoisonCatalogs or not self.weaponPoisonCatalogs[self:GetPoisonClient()] then
		return
	end
	self.weaponPollElapsed = 0
	self.eventFrame:SetScript("OnUpdate", function(_, elapsed)
		if
			not self.isEnabled
			or self.isLoggingOut
			or self.isLoadingScreenActive
			or not self:IsFiniteNumber(elapsed)
		then
			return
		end
		self.weaponPollElapsed = self.weaponPollElapsed + math.max(0, elapsed)
		if self.weaponPollElapsed >= 1 then
			self.weaponPollElapsed = 0
			self:RefreshPoisonState("WEAPON_POLL")
		end
	end)
end

function addon:StopWeaponPoisonPolling()
	if self.eventFrame and self.eventFrame.SetScript then
		self.eventFrame:SetScript("OnUpdate", nil)
	end
	self.weaponPollElapsed = 0
end
