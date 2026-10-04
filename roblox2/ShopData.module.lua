-- What the supply depot sells: three sections, each item with a price, a line of text and three stat bars.
-- The window (ShopUI) shows these; the server (ShopServer) checks buys against them.
local ShopData = {}

ShopData.Currency = "$"

ShopData.Sections = {
	{
		id = "attack", title = "ATTACK", tag = "things that hit back",
		stats = {"DAMAGE", "SPEED", "REACH"},
		items = {
			{id = "pipe", name = "RUSTED PIPE", price = 40, stats = {0.35, 0.55, 0.5},
				desc = "A length of old water pipe. Heavy enough to make most things think twice."},
			{id = "knife", name = "KITCHEN KNIFE", price = 65, stats = {0.45, 0.9, 0.2},
				desc = "Short, quiet and quick. It cuts deep, but you have to get very close."},
			{id = "nailbat", name = "NAIL BAT", price = 90, stats = {0.6, 0.5, 0.55},
				desc = "Somebody drove nails through it. Somebody needed it."},
			{id = "axe", name = "FIRE AXE", price = 160, stats = {0.85, 0.3, 0.6},
				desc = "Pulled off a station wall. Splits doors, bone and anything in between."},
			{id = "flaregun", name = "FLARE GUN", price = 220, stats = {0.7, 0.2, 1},
				desc = "One shot of burning light. Most of what lives out there hates the light. Shells sold separately."},
			{id = "doublebarrel", name = "DOUBLE BARREL", price = 380, stats = {0.95, 0.25, 0.75},
				desc = "Two barrels, two shells, one very bad day for whatever is in front of it. Shells sold separately."},
		},
	},
	{
		id = "consumables", title = "CONSUMABLES", tag = "use once, live longer",
		stats = {"EFFECT", "LASTS", "USE SPEED"},
		items = {
			{id = "bandage", name = "BANDAGE ROLL", price = 15, stats = {0.3, 0.2, 0.9},
				desc = "Stops the bleeding. Doesn't fix what's broken underneath."},
			{id = "painkillers", name = "PAINKILLERS", price = 35, stats = {0.35, 0.6, 0.95},
				desc = "Dulls the pain for a while. The pain will be back."},
			{id = "splint", name = "SPLINT", price = 45, stats = {0.55, 1, 0.4},
				desc = "Two sticks and a lot of tape. Lets a broken leg carry you again."},
			{id = "flare", name = "ROAD FLARE", price = 25, stats = {0.4, 0.45, 0.8},
				desc = "Burns red for a minute. Keeps the dark, and what's in it, a step back."},
			{id = "medkit", name = "FIRST AID KIT", price = 120, stats = {0.85, 0.3, 0.25},
				desc = "Everything you need to put yourself back together. Almost everything."},
			{id = "adrenaline", name = "ADRENALINE SHOT", price = 150, stats = {0.9, 0.25, 1},
				desc = "Run now, shake later. Your heart will not thank you for it."},
		},
	},
	{
		id = "defense", title = "DEFENSE", tag = "between you and the teeth",
		stats = {"PROTECTION", "WEIGHT", "COVERAGE"},
		items = {
			{id = "jacket", name = "PADDED JACKET", price = 60, stats = {0.3, 0.2, 0.7},
				desc = "Thick layers of old quilting. A claw has to work to get through."},
			{id = "legguards", name = "LEG GUARDS", price = 80, stats = {0.45, 0.35, 0.3},
				desc = "Plates strapped over the shins. Harder to break, harder to drag away."},
			{id = "gasmask", name = "GAS MASK", price = 95, stats = {0.25, 0.25, 0.25},
				desc = "Filters out the spores. Most of them. Breathing gets loud inside."},
			{id = "helmet", name = "RIOT HELMET", price = 110, stats = {0.6, 0.4, 0.2},
				desc = "Keeps your head where it belongs. Usually."},
			{id = "vest", name = "KEVLAR VEST", price = 200, stats = {0.85, 0.7, 0.5},
				desc = "Made for bullets, not teeth. Still better than a shirt."},
			{id = "armguards", name = "ARM GUARDS", price = 70, stats = {0.35, 0.2, 0.25},
				desc = "Strapped plastic plates over the forearms. They take a bite or two, then they crack."},
		},
	},
	{
		id = "supplies", title = "SUPPLIES", tag = "ammunition and nasty surprises",
		stats = {"AMOUNT", "WEIGHT", "USE"},
		items = {
			{id = "shells12", name = "12 GA SHELLS", price = 35, stats = {0.8, 0.1, 1},
				desc = "Eight buckshot shells. Fits the double barrel."},
			{id = "flareshell", name = "FLARE SHELLS", price = 40, stats = {0.2, 0.1, 1},
				desc = "Two signal flares for the flare gun."},
			{id = "beartrap", name = "BEAR TRAP", price = 70, stats = {0.3, 0.6, 0.7},
				desc = "Set it on the floor. Whatever steps in it stays there. Anyone can pry it open again."},
		},
	},
}

local byId = {}
for _, section in ipairs(ShopData.Sections) do
	for _, item in ipairs(section.items) do
		item.section = section.id
		byId[item.id] = item
	end
end

function ShopData.Get(id)
	return byId[id]
end

return ShopData
