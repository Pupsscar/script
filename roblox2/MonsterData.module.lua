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

-- texture ids shared by the server (bodies) and clients (tentacles)
MonsterData.Textures = {
	Meat = "93176580262165",          -- flesh_meat.png
	Veins = "110379790827308",         -- veins_overlay.png
	ListenerSkin = "127788127447980",  -- listener_skin.png
}

MonsterData.Objects = {
	["D-130"] = {
		id = "D-130",
		name = "OBJECT D-130",
		nickname = "The Watcher",
		class = "D",
		description = "A dark humanoid entity. Observes its victim from afar, then quietly closes in and attacks. "
			.. "Retreats when struck back, but always returns. Backs away from anyone who walks toward it, "
			.. "but attacks at once if you get right up close. Hit it while it is watching, or hit it three times, "
			.. "and it stops being afraid of anything: it charges and does not back off. "
			.. "Feeds on severed limbs. Follows blood trails, even long after the blood has dried. "
			.. "Imitates ambient noises and human screams.",
		traits = {"stalker", "follows blood", "eats limbs", "mimics screams", "enrages after 3 hits"},
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
	["A-013"] = {
		id = "A-013",
		name = "OBJECT A-013",
		nickname = "The Flesh",
		class = "A",
		description = "A walking heap of raw meat, veins crawling over it, white eyes staring out of black pits. "
			.. "Its tentacles lash out, catch you and drag you in. Whoever it kills does not stay dead: "
			.. "it eats the body and the victim wakes up infected. Eaten parts grow back as flesh, wounds close by themselves. "
			.. "The infected serve it and hunt the survivors.",
		traits = {"tentacles grab and drag", "infects its victims", "eats corpses", "hears everything", "commands the infected"},
		kind = "flesh",
		speedMultiplier = 0.95,
		attackRange = 5.4,
		deathCause = "FLESH",
		damageBase = 6, damagePerLevel = 4, swingCooldown = 1.3,
	},
	["C-207"] = {
		id = "C-207",
		name = "OBJECT C-207",
		nickname = "The Listener",
		class = "C",
		description = "No eyes, only a mouth. Hunts by sound and hears everything: every step, every jump, "
			.. "lying down, crawling, chat and voice, and up close even your heartbeat. "
			.. "Crawl, hold your breath, keep your distance.",
		traits = {"blind", "hears every step", "hears chat and voice", "hears your heartbeat up close"},
		kind = "listener",
		hearing = 1.6,
		speedMultiplier = 1.25,
		deathCause = "LISTENER",
		damageBase = 5, damagePerLevel = 3, swingCooldown = 1,
	},
	["E-116"] = {
		id = "E-116",
		name = "OBJECT E-116",
		nickname = "The Weaver",
		class = "E",
		description = "A spider the size of a small dog: black chitin, pale bristles, eight wet red eyes. "
			.. "It spins webs across passages and over the floor wherever it goes. Walk into one and you go down tangled "
			.. "for five seconds while every spider nearby feels you struggling. It only bites when you are right next to it. "
			.. "It climbs walls up to about ten studs high, but finds no grip on a wall you can't see. "
			.. "A swing tears a web apart.",
		traits = {"spins webs", "webs knock you down and give you away", "bites only up close", "climbs low walls", "no grip on invisible walls"},
		kind = "spider",
		speedMultiplier = 0.8,
		attackRange = 3,
		deathCause = "SPIDER",
		damageBase = 3, damagePerLevel = 2, swingCooldown = 1.2,
	},
	["A-116"] = {
		id = "A-116",
		name = "OBJECT A-116",
		nickname = "The Brood Mother",
		class = "A",
		description = "The thing E-116 comes from: a spider the size of a car, rust-red chitin, a pale sac of eggs "
			.. "hanging under her. She hunts anything that moves, climbs low walls and strings her own webs. "
			.. "When she kills she eats the whole body where it fell, and when she is done something small "
			.. "tears out of the egg sac: another E-116. Do not let her feed.",
		traits = {"eats whoever she kills", "every meal hatches an E-116", "spins webs", "climbs low walls", "bites hard"},
		kind = "spidermother",
		speedMultiplier = 1.02,
		attackRange = 5.2,
		deathCause = "SPIDERMOTHER",
		damageBase = 9, damagePerLevel = 4, swingCooldown = 1.1,
	},
	["C-310"] = {
		id = "C-310",
		name = "OBJECT C-310",
		nickname = "The Spitter",
		class = "C",
		description = "A hunched green thing with swollen, glowing acid sacs in its throat. It keeps its distance and spits: "
			.. "a direct hit burns, and the fumes keep eating your lungs for seconds after. Where it lands, a puddle hisses. "
			.. "A gas mask stops the poisoning. Get close and it claws.",
		traits = {"spits acid from range", "poisons your breathing", "leaves acid puddles", "a gas mask helps", "keeps its distance"},
		kind = "spitter",
		speedMultiplier = 0.8,
		deathCause = "ACID",
		damageBase = 5, damagePerLevel = 2, swingCooldown = 1.2,
	},
}
MonsterData.Order = {"D-130", "B-414", "A-013", "C-207", "E-116", "A-116", "C-310"}

-- health (MonsterHealth has the numbers; shown in the journal / admin panel)
MonsterData.Health = {
	["D-130"] = "200 hp - bullets do nothing, only melee",
	["B-414"] = "300 hp - 100 per limb",
	["A-013"] = "500 hp - 250 on the head, limbs grow back in 5 s",
	["C-207"] = "400 hp - 200 on the head, 250 per limb",
	["E-116"] = "75 hp - bursts when it dies",
	["A-116"] = "450 hp - bursts when she dies",
	["C-310"] = "180 hp - 80 on the head",
}

-- which object a death cause belongs to (the journal): the infected count as A-013's work
function MonsterData.ForCause(cause)
	if cause == "INFECTED" then return "A-013" end
	for id, object in pairs(MonsterData.Objects) do
		if object.deathCause == cause then return id end
	end
	return nil
end

function MonsterData.Get(id)
	return MonsterData.Objects[id]
end

function MonsterData.DangerOf(id)
	local object = MonsterData.Objects[id]
	return object and MonsterData.Danger[object.class] or nil
end

return MonsterData
