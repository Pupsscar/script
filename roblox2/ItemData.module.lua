-- Every item in the game: what it is, what it weighs, what it does, what it sells for.
-- Shared by the server (Inventory, Weapons) and the clients (the wheel, the crosshair, the shop).
-- kinds:
--   melee      held and swung (LMB)                         damage / reach / cooldown / stun / bleed
--   gun        held, aimed (RMB) and fired (LMB), reloaded (R) spread in degrees, pellets, ammo type
--   heal       used with a short mini-game                   hp / stopBleed / fixLegs / painkill / boost
--   light      held, gives light                             (the road flare)
--   armor      worn on the body                              slot, protection, durability
--   ammo       stacks, loaded into guns
--   trap       placed on the ground
-- No long dashes in any text here: plain "-" only.
local ItemData = {}

ItemData.MaxSlots = 12
ItemData.SellRate = 0.45 -- the trader pays this much of the price back

-- body parts armor can cover (the same keys as the Injury_ attributes)
ItemData.PartSlots = {
	Head = {"head", "face"},
	Torso = {"torso", "torso_under"},
	LeftArm = {"arms"}, RightArm = {"arms"},
	LeftLeg = {"legs"}, RightLeg = {"legs"},
}
-- slots: one item each. An item can take more than one slot (a full helmet also covers the face).
ItemData.SlotNames = {head = "HEAD", face = "FACE", torso = "BODY ARMOR", torso_under = "JACKET", arms = "ARMS", legs = "LEGS"}

ItemData.Items = {
	-- ===== melee =====
	pipe = {name = "RUSTED PIPE", kind = "melee", price = 40, weight = 2.5, pose = "melee",
		damage = 22, reach = 7, cooldown = 0.85, sound = "metal"},
	knife = {name = "KITCHEN KNIFE", kind = "melee", price = 65, weight = 0.6, pose = "knife",
		damage = 18, reach = 5.5, cooldown = 0.45, bleed = true, sound = "blade"},
	nailbat = {name = "NAIL BAT", kind = "melee", price = 90, weight = 2, pose = "melee",
		damage = 30, reach = 7, cooldown = 0.95, bleed = true, sound = "wood"},
	axe = {name = "FIRE AXE", kind = "melee", price = 160, weight = 3.5, pose = "melee",
		damage = 44, reach = 7.5, cooldown = 1.25, limbMult = 1.6, sound = "blade"},
	shockbaton = {name = "SHOCK BATON", kind = "melee", price = 0, adminOnly = true, weight = 1.4, pose = "melee",
		damage = 20, reach = 7, cooldown = 0.9, stun = 1.6, sound = "shock",
		desc = "SCG issue. Black rubber, a live tip. Drops people, stops things."},

	-- ===== guns =====
	flaregun = {name = "FLARE GUN", kind = "gun", price = 220, weight = 1.2, pose = "pistol",
		ammo = "flareshell", magazine = 1, pellets = 1, damage = 55, headMult = 1.5, spread = 2.5, aimSpread = 0.8,
		rpm = 60, reload = 1.6, range = 220, recoil = 5, fire = true, sound = "flare"},
	doublebarrel = {name = "DOUBLE BARREL", kind = "gun", price = 380, weight = 3.6, pose = "long",
		ammo = "shells12", magazine = 2, pellets = 8, damage = 11, headMult = 1.6, spread = 7, aimSpread = 4.2,
		rpm = 240, reload = 2.4, reloadPerShell = false, range = 110, recoil = 11, knockback = 30, sound = "shotgun",
		desc = "Two barrels, two shells, one very bad day for whatever is in front of it."},
	warden870 = {name = "WARDEN 870", kind = "gun", price = 0, adminOnly = true, weight = 4.2, pose = "long",
		ammo = "shells12", magazine = 6, pellets = 9, damage = 12, headMult = 1.6, spread = 6, aimSpread = 3.2,
		rpm = 70, reload = 0.55, reloadPerShell = true, pump = true, range = 130, recoil = 10, knockback = 34,
		sound = "shotgun", desc = "SCG pump-action riot gun. Six in the tube, pump between every shot."},

	-- ===== ammo =====
	shells12 = {name = "12 GA SHELLS", kind = "ammo", price = 35, weight = 0.05, stack = 48, buyAmount = 8,
		desc = "Eight buckshot shells. Fits the double barrel and the Warden 870."},
	flareshell = {name = "FLARE SHELLS", kind = "ammo", price = 40, weight = 0.1, stack = 12, buyAmount = 2,
		desc = "Two signal flares for the flare gun."},

	-- ===== healing (a short mini-game when used) =====
	bandage = {name = "BANDAGE ROLL", kind = "heal", price = 15, weight = 0.2, stack = 5, pose = "item",
		useTime = 2.2, game = "wrap", hp = 8, stopBleed = true, sound = "cloth"},
	painkillers = {name = "PAINKILLERS", kind = "heal", price = 35, weight = 0.2, stack = 3, pose = "item",
		useTime = 1.2, game = "none", hp = 12, painkill = 60, sound = "pills"},
	splint = {name = "SPLINT", kind = "heal", price = 45, weight = 0.8, stack = 2, pose = "item",
		useTime = 3, game = "set", fixLegs = true, hp = 5, sound = "cloth"},
	medkit = {name = "FIRST AID KIT", kind = "heal", price = 120, weight = 1.6, stack = 1, pose = "item",
		useTime = 3.6, game = "stitch", hp = 45, stopBleed = true, fixOne = true, sound = "spray"},
	adrenaline = {name = "ADRENALINE SHOT", kind = "heal", price = 150, weight = 0.1, stack = 2, pose = "item",
		useTime = 1, game = "none", hp = 15, boost = 20, sound = "syringe"},

	-- ===== light =====
	flare = {name = "ROAD FLARE", kind = "light", price = 25, weight = 0.3, stack = 4, pose = "item", burn = 60},

	-- ===== traps =====
	beartrap = {name = "BEAR TRAP", kind = "trap", price = 70, weight = 3, stack = 3, pose = "item",
		damage = 25, monsterDamage = 70, hold = 4, stun = 3.5,
		desc = "Set it on the floor. Whatever steps in it stays there. Anyone can pry it open again."},

	-- ===== armor =====
	jacket = {name = "PADDED JACKET", kind = "armor", price = 60, weight = 2, slots = {"torso_under"},
		covers = {Torso = 0.15, LeftArm = 0.1, RightArm = 0.1}, durability = 140},
	legguards = {name = "LEG GUARDS", kind = "armor", price = 80, weight = 3, slots = {"legs"},
		covers = {LeftLeg = 0.35, RightLeg = 0.35}, durability = 160},
	armguards = {name = "ARM GUARDS", kind = "armor", price = 70, weight = 1.6, slots = {"arms"},
		covers = {LeftArm = 0.3, RightArm = 0.3}, durability = 90, fragile = true,
		desc = "Strapped plastic plates over the forearms. They take a bite or two, then they crack."},
	gasmask = {name = "GAS MASK", kind = "armor", price = 95, weight = 1, slots = {"face"},
		covers = {Head = 0.05}, durability = 120, filter = true},
	helmet = {name = "RIOT HELMET", kind = "armor", price = 110, weight = 2, slots = {"head"},
		covers = {Head = 0.45}, durability = 180},
	vest = {name = "KEVLAR VEST", kind = "armor", price = 200, weight = 5, slots = {"torso"},
		covers = {Torso = 0.45}, durability = 260},

	-- SCG: 07 Sector Control Guard. Admin issue only, handed out piece by piece.
	scg_helmet = {name = "SCG HELMET", kind = "armor", price = 0, adminOnly = true, weight = 4, slots = {"head", "face"},
		covers = {Head = 0.65}, durability = 420, filter = true, set = "scg",
		desc = "Full black helmet with a sealed visor and a built-in filter. 07 SECTOR CONTROL GUARD."},
	scg_vest = {name = "SCG PLATE CARRIER", kind = "armor", price = 0, adminOnly = true, weight = 11, slots = {"torso", "torso_under"},
		covers = {Torso = 0.7}, durability = 600, set = "scg",
		desc = "Heavy plates front and back, collar and groin guard. SCG on the chest."},
	scg_arms = {name = "SCG ARM PLATES", kind = "armor", price = 0, adminOnly = true, weight = 4, slots = {"arms"},
		covers = {LeftArm = 0.55, RightArm = 0.55}, durability = 300, set = "scg"},
	scg_legs = {name = "SCG LEG PLATES", kind = "armor", price = 0, adminOnly = true, weight = 6, slots = {"legs"},
		covers = {LeftLeg = 0.6, RightLeg = 0.6}, durability = 360, set = "scg"},
}

-- the order items show up in lists (admin panel, sell list)
ItemData.Order = {
	"pipe", "knife", "nailbat", "axe", "flaregun", "doublebarrel",
	"shells12", "flareshell",
	"bandage", "painkillers", "splint", "medkit", "adrenaline", "flare", "beartrap",
	"jacket", "armguards", "legguards", "gasmask", "helmet", "vest",
	"shockbaton", "warden870", "scg_helmet", "scg_vest", "scg_arms", "scg_legs",
}
ItemData.SCG_SET = {"scg_helmet", "scg_vest", "scg_arms", "scg_legs", "warden870", "shockbaton"}

for id, item in pairs(ItemData.Items) do
	item.id = id
	item.stack = item.stack or 1
	item.weight = item.weight or 1
	item.sell = item.sell or math.floor((item.price or 0) * ItemData.SellRate)
end

function ItemData.Get(id)
	return ItemData.Items[id]
end

-- Roblox's own public sound effects (the Pro Sound Effects library on the Creator Store)
ItemData.Sounds = {
	Shotgun = {9114726695, 9114727327},
	ShellDrop = {9113630798, 9113110376, 9113631440},
	ShellIn = 9113110376,
	Rack = 9116761017,
	Click = 9120095742,
	Flare = 9113052249,
	Sizzle = 9114428855,
	Swing = {9126284289, 9120741675},
	MetalHit = 9116745544,
	Shock = {9114249288, 9114247505},
	ShockWhoosh = 9114265998,
	TrapSet = 9116550084,
	TrapSnap = 9116546593,
	Splat = {9120572970, 9114615843},
	Explosion = 9119701508,
	Cloth = 9113824106,
	Plate = 9116761017,
	Spray = 9119525258,
	Rattle = 9114890677,
	Flesh = {9113607285, 9113607822},
	BloodHit = {9116485156, 9116485127, 9116485130},
	Bone = {9113542694, 9113542645, 9113542856},
}

function ItemData.Sound(name)
	local s = ItemData.Sounds[name]
	if typeof(s) == "table" then s = s[math.random(1, #s)] end
	return s and ("rbxassetid://" .. tostring(s)) or nil
end

-- pellet directions for a shot: the same seed gives the same pattern on the client (tracers)
-- and on the server (damage)
function ItemData.Pellets(item, lookCFrame, seed, spreadDeg)
	local rng = Random.new(seed)
	local list = {}
	for i = 1, item.pellets or 1 do
		-- a disc, a little denser towards the middle
		local r = math.rad(spreadDeg) * math.sqrt(rng:NextNumber()) * (i == 1 and 0.35 or 1)
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = (lookCFrame * CFrame.Angles(math.sin(a) * r, math.cos(a) * r, 0)).LookVector
		list[i] = dir
	end
	return list
end

return ItemData
