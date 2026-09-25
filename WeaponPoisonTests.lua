local addon = _G.NoPoizen
if not addon then
	return
end
local Equal = addon.LibChev.AssertEqual

local function Fixture(client)
	local f = { items = { [16] = 1, [17] = 2 }, rows = { [0] = {}, [1] = {} }, known = true }
	f.secret = {}
	f.inaccessible = setmetatable({}, {
		__index = function()
			error("inaccessible row read")
		end,
	})
	f.api = {
		CanAccessValue = function(value)
			return value ~= f.secret
		end,
		CanAccessTable = function(value)
			return value ~= f.inaccessible
		end,
		CanObserve = function()
			return not f.restricted
		end,
		GetPlayerLevel = function()
			return f.level or 20
		end,
		GetInventoryItemID = function(_, slot)
			return f.items[slot]
		end,
		GetItemInfoInstant = function(id)
			return id, "", "", id == 3 and "INVTYPE_SHIELD" or "INVTYPE_WEAPON", 1, id == 3 and 4 or 2
		end,
		GetWeaponSlot = function(hand)
			return hand == "mainHand" and 0 or 1
		end,
		GetWeaponEnchants = function(slot)
			return f.rows[slot]
		end,
		GetLegacyWeaponEnchants = function()
			local m, o = f.rows[0][1] or {}, f.rows[1][1] or {}
			return m.hasEnchant, m.timeLeft, m.charges, m.enchantID, o.hasEnchant, o.timeLeft, o.charges, o.enchantID
		end,
	}
	f.detector = addon.Testables.CreateWeaponPoisonDetector(
		f.api,
		client or "forever",
		addon.weaponPoisonCatalogs[client or "forever"],
		function(id)
			if id == 1298494 then
				return f.foreverTraining == true
			end
			return f.known
		end
	)
	function f:Apply(hand, id, charges, remaining)
		self.rows[hand] =
			{ { hasEnchant = true, enchantID = id or 323, charges = charges or 60, timeLeft = remaining or 1800000 } }
	end
	function f:Evaluate()
		return self.detector:Evaluate({
			status = "unknown",
			eligible = false,
			observable = false,
			hasMissing = false,
			knownSpellIDs = {},
			indicatorRows = {},
		})
	end
	return f
end

for _, client in ipairs({ "forever", "era", "tbc", "titan" }) do
	addon:RegisterTest("weapon poisons: " .. client .. " hand identity, expiry and swaps", function()
		local f = Fixture(client)
		local state = f:Evaluate()
		Equal(state.status, "missing")
		Equal(state.missingCounts.total, 2)
		Equal(state.indicatorRows[1].category, "mainHand")
		f:Apply(0)
		Equal(f:Evaluate().missingCounts.total, 1)
		f:Apply(1, 22, 0)
		Equal(f:Evaluate().status, "satisfied")
		f.rows[0][1].timeLeft = 0
		Equal(f:Evaluate().status, "missing")
		f.items[16] = nil
		Equal(f:Evaluate().status, "satisfied")
		f.items[17] = 3
		Equal(f:Evaluate().reason, "no-equipped-weapons")
	end)
end

addon:RegisterTest("weapon poisons: Forever training and multiple coatings", function()
	local f = Fixture()
	f.known, f.foreverTraining = false, true
	f:Apply(0)
	f.rows[0][2] = { hasEnchant = true, enchantID = 1, charges = 0, timeLeft = 30000 }
	f:Apply(1, 22, 0)
	Equal(f:Evaluate().status, "satisfied")
	Equal(f:Evaluate().trainingSpellIDs[1], 1298494)
	f.rows[0][1].enchantID = 283 -- Windfury is not a rogue poison.
	Equal(f:Evaluate().status, "missing")
end)

addon:RegisterTest("weapon poisons: charges follow client data", function()
	for _, client in ipairs({ "forever", "era", "tbc", "titan" }) do
		local f = Fixture(client)
		f:Apply(0, 323, 0)
		f:Apply(1, 22, 0)
		Equal(f:Evaluate().status, (client == "tbc" or client == "titan") and "satisfied" or "missing")
	end
end)

addon:RegisterTest("weapon poisons: Forever rows may be zero based or sparse", function()
	local f = Fixture()
	f:Apply(0)
	f:Apply(1, 22, 0)
	f.rows[0] = { [0] = f.rows[0][1] }
	f.rows[1] = { [3] = f.rows[1][1] }
	Equal(f:Evaluate().status, "satisfied")
	f.rows[0][f.secret] = { hasEnchant = false }
	Equal(f:Evaluate().status, "unknown")
end)

addon:RegisterTest("weapon poisons: SoD and TBC ranks stay in their own catalogs", function()
	Equal(addon.weaponPoisonCatalogs.forever[7254], nil)
	Equal(addon.weaponPoisonCatalogs.era[7254].spellID, 439462)
	Equal(addon.weaponPoisonCatalogs.tbc[2641].spellID, 26891)
	Equal(addon.weaponPoisonCatalogs.era[2641], nil)
	local f = Fixture("era")
	f:Apply(0, 7542, 0)
	f:Apply(1, 7651, 0)
	Equal(f:Evaluate().status, "satisfied")
end)

addon:RegisterTest("weapon poisons: unknown never becomes missing", function()
	local f = Fixture()
	f.rows[0] = f.inaccessible
	Equal(f:Evaluate().status, "unknown")
	f.rows[0] = { f.inaccessible }
	Equal(f:Evaluate().observable, false)
	f:Apply(0)
	f.rows[0][1].enchantID = f.secret
	Equal(f:Evaluate().hasMissing, false)
	f:Apply(0)
	f.rows[0][1].charges = f.secret
	Equal(f:Evaluate().status, "unknown")
	f.api.GetWeaponEnchants = function()
		error("private query error")
	end
	Equal(f:Evaluate().status, "unknown")
end)

addon:RegisterTest("weapon poisons: restrictions prevent inventory reads", function()
	local f = Fixture()
	f.restricted = true
	f.api.GetInventoryItemID = function()
		error("must not query restricted inventory")
	end
	Equal(f:Evaluate().reason, "weapon-observation-restricted")
	f.api.CanObserve = function()
		return f.secret
	end
	Equal(f:Evaluate().status, "unknown")
end)

addon:RegisterTest("weapon poisons: untrained and unknown training stay quiet", function()
	local f = Fixture()
	f.known = false
	Equal(f:Evaluate().status, "ineligible")
	f.known = nil
	Equal(f:Evaluate().status, "unknown")
end)

addon:RegisterTest("weapon poisons: multi enchant queries cannot fall back to single coatings", function()
	local f = Fixture()
	f.api.GetWeaponEnchants = nil
	f:Apply(0)
	f:Apply(1)
	Equal(f:Evaluate().status, "unknown")
end)

addon:RegisterTest("weapon poisons: temporary enchant structure uses milliseconds and charges", function()
	local f = Fixture("era")
	f.api.GetTemporaryEnchantmentInfo = function(slot)
		Equal(slot == 16 or slot == 17, true)
		return { enchantID = 323, remainingTimeMs = 5000, chargesRemaining = 3, hasExpirationTime = true }
	end
	Equal(f:Evaluate().status, "satisfied")
	f.api.GetTemporaryEnchantmentInfo = function()
		return nil
	end
	Equal(f:Evaluate().status, "missing")
end)

addon:RegisterTest("weapon poisons: foreign equipment and overlong samples stay unknown", function()
	local f = Fixture()
	f.items[16] = f.secret
	Equal(f:Evaluate().status, "unknown")
	f.items[16] = 1
	for index = 1, 9 do
		f.rows[0][index] = { hasEnchant = false }
	end
	Equal(f:Evaluate().status, "unknown")
end)

addon:RegisterTest("poison clients: mechanics distinguish Forever from Era", function()
	for version, client in pairs({
		["1.60.1"] = "forever",
		["1.15.9"] = "era",
		["2.5.6"] = "tbc",
		["5.5.4"] = "mists",
		["3.80.2"] = "titan",
		["1.12.1"] = "unsupported",
	}) do
		Equal(addon.Testables.ResolvePoisonClient(version), client)
	end
end)

addon:RegisterTest("weapon poisons: Titan vendor poisons require level rather than crafting", function()
	local f = Fixture("titan")
	f.known = false
	f.level = 19
	Equal(f:Evaluate().status, "ineligible")
	f.level = 20
	Equal(f:Evaluate().status, "missing")
	f:Apply(0, 3769, 0)
	f:Apply(1, 3771, 0)
	Equal(f:Evaluate().status, "satisfied")
	f.level = f.secret
	Equal(f:Evaluate().status, "unknown")
end)
