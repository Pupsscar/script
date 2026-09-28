local MonsterData = {}

MonsterData.Danger = {
	F = {label = "HARMLESS", color = Color3.fromRGB(150, 150, 146), rank = 1},
	E = {label = "LOW", color = Color3.fromRGB(120, 170, 120), rank = 2},
	D = {label = "MEDIUM", color = Color3.fromRGB(215, 170, 60), rank = 3},
	C = {label = "HIGH", color = Color3.fromRGB(225, 110, 40), rank = 4},
	B = {label = "SEVERE", color = Color3.fromRGB(220, 40, 40), rank = 5},
	A = {label = "CATASTROPHIC", color = Color3.fromRGB(170, 60, 230), rank = 6},
}
MonsterData.DangerOrder = {"F", "E", "D", "C", "B", "A"}

MonsterData.Objects = {
	["D-130"] = {
		id = "D-130",
		name = "OBJECT D-130",
		nickname = "The Watcher",
		class = "D",
		description = "A dark humanoid entity. Observes its victim from afar, then quietly closes in and attacks. "
			.. "Retreats when struck back, but always returns. Backs away from anyone who walks toward it, "
			.. "but attacks at once if you get right up close. "
			.. "Feeds on severed limbs. Follows blood trails, even long after the blood has dried. "
			.. "Imitates ambient noises and human screams.",
		traits = {"stalker", "follows blood", "eats limbs", "mimics screams", "retreats when hit"},
		kind = "stalker",
		speedMultiplier = 1.3,
		approachSpeed = 17.5,
		deathCause = "D130",
		damageBase = 4, damagePerLevel = 3, swingCooldown = 1.15,
	},
	["B-414"] = {
		id = "B-414",
		name = "OBJECT B-414",
		nickname = "Skinwalker",
		class = "B",
		description = "A pale grey thing with a face that is wrong. It has no skin of its own: it kills, eats the body "
			.. "and returns wearing the victim's skin. In disguise it never speaks and makes no sound, "
			.. "it only copies you: steps when you step, stops when you stop, jumps when you jump. "
			.. "Drops the disguise when you are alone with it or stare at it too long. Hitting it only makes it angrier.",
		traits = {"no skin of its own", "wears its victims", "copies your movements", "silent in disguise", "does not retreat"},
		kind = "skinwalker",
		speedMultiplier = 1.35,
		attackRange = 5.2,
		deathCause = "SKINWALKER",
		damageBase = 5, damagePerLevel = 3, swingCooldown = 1.05,
	},
}
MonsterData.Order = {"D-130", "B-414"}

function MonsterData.Get(id)
	return MonsterData.Objects[id]
end

function MonsterData.DangerOf(id)
	local object = MonsterData.Objects[id]
	return object and MonsterData.Danger[object.class] or nil
end

return MonsterData
