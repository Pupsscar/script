-- ONE-CLICK INSTALLER (items, weapons, armor, the Spitter, anti-cheat fixes).
-- Option A: Studio -> Plugins tab -> Plugins Folder -> put this file there -> restart Studio ->
--   Plugins tab -> "Install scripts" button.
-- Option B: paste the whole file into View -> Command Bar and press Enter (may lag for a few seconds).
-- A script with the same name and type in its own place is overwritten; a missing one is created:
--   Modules      -> ReplicatedStorage.Modules
--   ServerStorage -> ServerStorage (GS_ItemService)
--   ServerScriptService / StarterPlayerScripts as named.
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SCRIPTS = {
	{name = "AdminPanel", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
local Players = game:GetService("Players")
local function isNpc(x)
	return type(x) == "table" and x.IsNpc == true
end

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local waited = 0
while not player:GetAttribute("IsAdmin") and waited < 15 do
	waited += task.wait(0.25)
end
if not player:GetAttribute("IsAdmin") then return end

local remote = ReplicatedStorage:WaitForChild("AdminAction")

local CONFIG = {
	Key = Enum.KeyCode.F2,
	Font = Enum.Font.SpecialElite,
}

local INK = Color3.fromRGB(232, 230, 226)
local MID = Color3.fromRGB(150, 148, 144)
local DIM = Color3.fromRGB(80, 79, 77)
local LINE = Color3.fromRGB(58, 58, 56)
local BG = Color3.fromRGB(7, 7, 7)
local CELL = Color3.fromRGB(18, 18, 18)

local function create(className, props, children)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do obj[key] = value end
	for _, child in ipairs(children or {}) do child.Parent = obj end
	return obj
end

local gui = create("ScreenGui", {
	Name = "AdminPanel", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3000, Enabled = true,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 540),
	BackgroundColor3 = BG, BackgroundTransparency = 0.03, BorderSizePixel = 0, Visible = false, Parent = gui,
}, {
	create("UIStroke", {Color = LINE, Thickness = 1}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(24, 24, 23), Color3.fromRGB(0, 0, 0))}),
})

create("TextLabel", {
	Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(400, 26), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "A D M I N   P A N E L", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = INK, Parent = panel,
})
create("Frame", {
	Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -40, 0, 1), BackgroundColor3 = LINE, BorderSizePixel = 0, Parent = panel,
})

local status = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -10), Size = UDim2.new(1, -40, 0, 20),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = "select a player", TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MID, Parent = panel,
})

local function sectionTitle(text, x, y, parent)
	return create("TextLabel", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(200, 16), BackgroundTransparency = 1,
		Font = CONFIG.Font, Text = text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DIM, Parent = parent or panel,
	})
end

local function button(text, x, y, w, h, parent, callback)
	local b = create("TextButton", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = CELL,
		BorderSizePixel = 0, AutoButtonColor = false, Font = CONFIG.Font, Text = text, TextSize = 15,
		TextColor3 = MID, Parent = parent or panel,
	}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40, 40, 39), TextColor3 = Color3.new(1, 1, 1)}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = CELL, TextColor3 = MID}):Play()
	end)
	if callback then b.Activated:Connect(callback) end
	return b
end

sectionTitle("PLAYERS", 20, 54)
local listFrame = create("ScrollingFrame", {
	Position = UDim2.fromOffset(20, 74), Size = UDim2.fromOffset(200, 290), BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = MID, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
}, {
	create("UIStroke", {Color = LINE, Thickness = 1}),
	create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.Name}),
	create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)}),
})

local selectedPlayer = nil
local selectedPart = nil
local playerButtons = {}

local function refreshPlayerButtons()
	for plr, b in pairs(playerButtons) do
		local selected = plr == selectedPlayer
		b.BackgroundColor3 = selected and Color3.fromRGB(45, 45, 44) or CELL
		b.TextColor3 = selected and Color3.new(1, 1, 1) or MID
	end
end

local function characterOf(sel)
	if not sel then return nil end
	if isNpc(sel) then
		local folder = workspace:FindFirstChild("NPCs")
		return folder and folder:FindFirstChild("NPC_" .. tostring(-sel.UserId))
	end
	return sel.Character
end

local function addPlayer(plr)
	if playerButtons[plr] then return end
	local b = create("TextButton", {
		Name = plr.DisplayName:lower(), Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = CELL, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "", Parent = listFrame,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -12, 0, 18), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = plr.DisplayName, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -12, 0, 14), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = isNpc(plr) and "npc" or ("@" .. plr.Name), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
	})
	b.Activated:Connect(function()
		selectedPlayer = plr
		refreshPlayerButtons()
		status.Text = "selected: " .. plr.DisplayName
	end)
	playerButtons[plr] = b
	refreshPlayerButtons()
end
for _, plr in ipairs(Players:GetPlayers()) do addPlayer(plr) end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(plr)
	if playerButtons[plr] then playerButtons[plr]:Destroy() playerButtons[plr] = nil end
	if selectedPlayer == plr then selectedPlayer = nil end
end)

local npcEntries = {}
local npcRegistry = ReplicatedStorage:WaitForChild("NPCs", 20)
local function addNpc(config)
	if not config:IsA("Configuration") or npcEntries[config] then return end
	local entry = {
		IsNpc = true,
		UserId = config:GetAttribute("Id"),
		DisplayName = config:GetAttribute("DisplayName") or "NPC",
		Name = "npc",
	}
	npcEntries[config] = entry
	addPlayer(entry)
end
local function removeNpc(config)
	local entry = npcEntries[config]
	if not entry then return end
	npcEntries[config] = nil
	if playerButtons[entry] then playerButtons[entry]:Destroy() playerButtons[entry] = nil end
	if selectedPlayer == entry then selectedPlayer = nil end
end
if npcRegistry then
	for _, config in ipairs(npcRegistry:GetChildren()) do addNpc(config) end
	npcRegistry.ChildAdded:Connect(addNpc)
	npcRegistry.ChildRemoved:Connect(removeNpc)
end

local npcNameBox = create("TextBox", {
	Position = UDim2.fromOffset(20, 372), Size = UDim2.fromOffset(200, 26), BackgroundColor3 = CELL, BorderSizePixel = 0,
	Font = CONFIG.Font, PlaceholderText = "npc name (empty = random)", PlaceholderColor3 = DIM, Text = "",
	TextSize = 14, TextColor3 = INK, ClearTextOnFocus = false, Parent = panel,
}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})

local RIGHT_X = 240
sectionTitle("BODY", RIGHT_X, 54)
local body = create("Frame", {
	Position = UDim2.fromOffset(RIGHT_X, 76), Size = UDim2.fromOffset(160, 200), BackgroundTransparency = 1, Parent = panel,
})
local U = 26
local BODY = {
	Head     = {Vector2.new(1.5, 0), Vector2.new(1, 1)},
	Torso    = {Vector2.new(1, 1.08), Vector2.new(2, 2)},
	LeftArm  = {Vector2.new(0, 1.08), Vector2.new(0.94, 2)},
	RightArm = {Vector2.new(3.06, 1.08), Vector2.new(0.94, 2)},
	LeftLeg  = {Vector2.new(1, 3.16), Vector2.new(0.97, 2.2)},
	RightLeg = {Vector2.new(2.03, 3.16), Vector2.new(0.97, 2.2)},
}
local LEVEL_COLOR = {
	[0] = Color3.fromRGB(38, 38, 37),
	[1] = Color3.fromRGB(110, 110, 108),
	[2] = Color3.fromRGB(215, 213, 210),
	[3] = Color3.fromRGB(0, 0, 0),
}
local partButtons = {}
for name, spec in pairs(BODY) do
	local b = create("TextButton", {
		Position = UDim2.fromOffset(spec[1].X * U, spec[1].Y * U), Size = UDim2.fromOffset(spec[2].X * U, spec[2].Y * U),
		BackgroundColor3 = LEVEL_COLOR[0], BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = body,
	})
	local stroke = create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b})
	b.Activated:Connect(function()
		selectedPart = name
		status.Text = "part: " .. name
	end)
	partButtons[name] = {button = b, stroke = stroke}
end

local WORLD = {Night = true, Weather = true, NpcCreate = true, Shop = true, Pvp = true}
local function send(action, a, b)
	if not WORLD[action] and not selectedPlayer then
		status.Text = "no player"
		return
	end
	remote:FireServer(action, selectedPlayer and selectedPlayer.UserId or 0, a, b)
end

local function setInjury(level)
	if not selectedPart then
		status.Text = "no part"
		return
	end
	send("SetInjury", selectedPart, level)
end

button("SPAWN NPC", 20, 402, 200, 28, panel, function()
	send("NpcCreate", npcNameBox.Text)
	npcNameBox.Text = ""
end)

local INJ_X = RIGHT_X
button("HEAL", INJ_X, 312, 78, 30, panel, function() setInjury(0) end)
button("DAMAGE", INJ_X + 84, 312, 78, 30, panel, function() setInjury(1) end)
button("BREAK", INJ_X, 348, 78, 30, panel, function() setInjury(2) end)
button("SEVER", INJ_X + 84, 348, 78, 30, panel, function() setInjury(3) end)
button("EXPLODE", INJ_X, 384, 78, 30, panel, function()
	if not selectedPart then status.Text = "no part" return end
	send("ExplodePart", selectedPart)
end)
button("RESTORE", INJ_X + 84, 384, 78, 30, panel, function()
	if not selectedPart then status.Text = "no part" return end
	send("RestorePart", selectedPart)
end)

local ACT_X = 440
sectionTitle("ACTIONS", ACT_X, 54)
local actions = {
	{"RAGDOLL 3s", function() send("Ragdoll", 3) end},
	{"RAGDOLL 10s", function() send("Ragdoll", 10) end},
	{"DAMAGE 25", function() send("Damage", 25) end},
	{"HEAL ALL", function() send("HealAll") end},
	{"KILL", function() send("Kill") end},
	{"TEAR APART", function() send("Gib") end},
	{"BLEED", function() send("Bleed") end},
	{"HEAD POP", function() send("HeadPop") end},
	{"LOBOTOMY", function() send("Lobotomy") end},
	{"NPC AI", function() send("NpcAI") end},
	{"DELETE NPC", function() send("NpcDelete") end},
	{"RESPAWN", function() send("Respawn") end},
	{"INFECT I", function() send("Infect", 1) end},
	{"INFECT II", function() send("Infect", 2) end},
	{"INFECT III", function() send("Infect", 3) end},
	{"CURE", function() send("Infect", 0) end},
}
-- three columns so the infection stages fit above WORLD
for i, entry in ipairs(actions) do
	local col = (i - 1) % 3
	local rowIndex = math.floor((i - 1) / 3)
	local b = button(entry[1], ACT_X + col * 81, 74 + rowIndex * 36, 77, 30, panel, entry[2])
	b.TextSize = 12
	if string.find(entry[1], "INFECT") or entry[1] == "CURE" then
		b.TextColor3 = Color3.fromRGB(215, 70, 70)
		b.MouseLeave:Connect(function() task.delay(0.16, function() b.TextColor3 = Color3.fromRGB(215, 70, 70) end) end)
	end
end

sectionTitle("WORLD", ACT_X, 296)
local nightLabel = create("TextLabel", {
	Position = UDim2.fromOffset(ACT_X + 70, 296), Size = UDim2.fromOffset(170, 16), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = MID, Parent = panel,
})
button("NIGHT ON", ACT_X, 316, 117, 30, panel, function() send("Night", true) end)
button("NIGHT OFF", ACT_X + 123, 316, 117, 30, panel, function() send("Night", false) end)
local WEATHER = {"Clear", "Rain", "Storm", "Wind", "Fog"}
for i, kind in ipairs(WEATHER) do
	if i <= 3 then
		button(kind:upper(), ACT_X + (i - 1) * 82, 352, 76, 30, panel, function() send("Weather", kind) end)
	else
		button(kind:upper(), ACT_X + (i - 4) * 123, 388, 117, 30, panel, function() send("Weather", kind) end)
	end
end

-- money for the selected player (Economy script on the server)
local cashTitle = sectionTitle("CASH", 20, 440)
cashTitle.Size = UDim2.fromOffset(400, 16)
local cashBox = create("TextBox", {
	Position = UDim2.fromOffset(20, 460), Size = UDim2.fromOffset(96, 28), BackgroundColor3 = CELL, BorderSizePixel = 0,
	Font = CONFIG.Font, PlaceholderText = "amount", PlaceholderColor3 = DIM, Text = "", TextSize = 14, TextColor3 = INK,
	ClearTextOnFocus = false, Parent = panel,
}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
local function cashAmount()
	local n = tonumber((string.gsub(cashBox.Text, "[^%d]", "")))
	if not n or n <= 0 then
		status.Text = "type an amount"
		return nil
	end
	return math.floor(n)
end
local function sendCash(amount)
	if selectedPlayer and isNpc(selectedPlayer) then status.Text = "npcs have no money" return end
	send("Cash", amount)
end
button("GIVE", 122, 460, 64, 28, panel, function() local n = cashAmount() if n then sendCash(n) end end)
button("TAKE", 190, 460, 64, 28, panel, function() local n = cashAmount() if n then sendCash(-n) end end)
button("+100", 258, 460, 58, 28, panel, function() sendCash(100) end)
button("+1000", 320, 460, 70, 28, panel, function() sendCash(1000) end)

-- the supply depot
local shopLabel = create("TextLabel", {
	Position = UDim2.fromOffset(ACT_X, 424), Size = UDim2.fromOffset(60, 30), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "SHOP", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM, Parent = panel,
})
local shopOpen = button("OPEN", ACT_X + 44, 424, 96, 30, panel, function() send("Shop", true) end)
local shopClose = button("CLOSE", ACT_X + 144, 424, 96, 30, panel, function() send("Shop", false) end)
shopOpen.TextColor3 = Color3.fromRGB(220, 170, 60)
shopOpen.MouseLeave:Connect(function() task.delay(0.16, function() shopOpen.TextColor3 = Color3.fromRGB(220, 170, 60) end) end)

local MonsterData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MonsterData"))

local mainPage = create("Frame", {Name = "PlayersPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = panel})
for _, child in ipairs(panel:GetChildren()) do
	local keep = child == mainPage or child == status or child:IsA("UIStroke") or child:IsA("UIGradient")
		or (child:IsA("GuiObject") and child.Position.Y.Offset < 50 and child.Position.Y.Scale == 0)
	if not keep then child.Parent = mainPage end
end
local entitiesPage = create("Frame", {Name = "EntitiesPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = panel})
local bansPage = create("Frame", {Name = "BansPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = panel})
local acPage = create("Frame", {Name = "AntiCheatPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = panel})
local itemsPage = create("Frame", {Name = "ItemsPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = panel})
local onTabSelected = {}

local tabButtons = {}
local function selectTab(name)
	mainPage.Visible = name == "PLAYERS"
	entitiesPage.Visible = name == "ENTITIES"
	bansPage.Visible = name == "BANS"
	acPage.Visible = name == "ANTICHEAT"
	itemsPage.Visible = name == "ITEMS"
	if onTabSelected[name] then task.spawn(onTabSelected[name]) end
	for tabName, b in pairs(tabButtons) do
		local active = tabName == name
		b.TextColor3 = active and INK or DIM
		b:FindFirstChild("Underline").Visible = active
	end
end
for i, tabName in ipairs({"PLAYERS", "ENTITIES", "ITEMS", "BANS", "ANTICHEAT"}) do
	local b = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20 - (5 - i) * 86, 0, 14), Size = UDim2.fromOffset(84, 24),
		BackgroundTransparency = 1, AutoButtonColor = false, Font = CONFIG.Font, Text = tabName, TextSize = 13,
		TextColor3 = DIM, Parent = panel,
	})
	create("Frame", {
		Name = "Underline", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.new(0.8, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(190, 30, 30), BorderSizePixel = 0, Visible = false, Parent = b,
	})
	b.Activated:Connect(function() selectTab(tabName) end)
	tabButtons[tabName] = b
end
selectTab("PLAYERS")

sectionTitle("OBJECTS", 20, 54, entitiesPage)
local objectList = create("ScrollingFrame", {
	Position = UDim2.fromOffset(20, 74), Size = UDim2.fromOffset(200, 400), BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = MID, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = entitiesPage,
}, {
	create("UIStroke", {Color = LINE, Thickness = 1}),
	create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
	create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}),
})

local DETAIL_X = 240
local detail = create("Frame", {
	Position = UDim2.fromOffset(DETAIL_X, 54), Size = UDim2.fromOffset(440, 360), BackgroundTransparency = 1, Parent = entitiesPage,
})
local detailTitle = create("TextLabel", {
	Size = UDim2.fromOffset(440, 28), BackgroundTransparency = 1, Font = CONFIG.Font, Text = "", TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, Parent = detail,
})
local detailNick = create("TextLabel", {
	Position = UDim2.fromOffset(0, 28), Size = UDim2.fromOffset(440, 18), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MID, Parent = detail,
})

create("TextLabel", {
	Position = UDim2.fromOffset(0, 56), Size = UDim2.fromOffset(200, 16), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "DANGER CLASS", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM, Parent = detail,
})
local classBadge = create("TextLabel", {
	Position = UDim2.fromOffset(0, 76), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = CELL, BorderSizePixel = 0,
	Font = CONFIG.Font, Text = "", TextSize = 34, TextColor3 = INK, Parent = detail,
}, {create("UIStroke", {Color = LINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
local classLabel = create("TextLabel", {
	Position = UDim2.fromOffset(56, 78), Size = UDim2.fromOffset(200, 22), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, Parent = detail,
})
local scaleCells = {}
for i, letter in ipairs(MonsterData.DangerOrder) do
	local info = MonsterData.Danger[letter]
	scaleCells[letter] = create("TextLabel", {
		Position = UDim2.fromOffset(56 + (i - 1) * 30, 102), Size = UDim2.fromOffset(26, 20), BackgroundColor3 = info.color,
		BackgroundTransparency = 0.8, BorderSizePixel = 0, Font = CONFIG.Font, Text = letter, TextSize = 14,
		TextColor3 = MID, Parent = detail,
	})
end
local detailDesc = create("TextLabel", {
	Position = UDim2.fromOffset(0, 134), Size = UDim2.fromOffset(440, 110), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "", TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(200, 198, 194), Parent = detail,
})
local detailTraits = create("TextLabel", {
	Position = UDim2.fromOffset(0, 246), Size = UDim2.fromOffset(440, 18), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM, TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = detail,
})
local activeLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(440, 4), Size = UDim2.fromOffset(160, 18), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = MID, Parent = detail,
})

local selectedObject = nil
local objectCards = {}
local function selectObject(id)
	selectedObject = id
	local data = MonsterData.Get(id)
	local danger = MonsterData.DangerOf(id)
	detailTitle.Text = data.name
	detailNick.Text = "\"" .. data.nickname .. "\"  ·  code " .. data.id
	classBadge.Text = data.class
	classBadge.TextColor3 = danger.color
	classBadge.UIStroke.Color = danger.color
	classLabel.Text = danger.label
	classLabel.TextColor3 = danger.color
	for letter, cell in pairs(scaleCells) do
		local on = letter == data.class
		cell.BackgroundTransparency = on and 0.1 or 0.82
		cell.TextColor3 = on and Color3.new(0, 0, 0) or MID
	end
	detailDesc.Text = data.description
	detailTraits.Text = table.concat(data.traits, "  ·  ")
	for cardId, card in pairs(objectCards) do
		card.UIStroke.Color = cardId == id and Color3.new(1, 1, 1) or LINE
	end
	status.Text = string.format("selected: %s  ·  danger %s (%s)", data.id, data.class, danger.label)
end

for i, id in ipairs(MonsterData.Order) do
	local data = MonsterData.Get(id)
	local danger = MonsterData.DangerOf(id)
	local card = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = CELL, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		LayoutOrder = i, Parent = objectList,
	}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -60, 0, 24), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = data.id, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, Parent = card,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 27), Size = UDim2.new(1, -60, 0, 16), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = data.nickname, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM, Parent = card,
	})
	create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = danger.color, BackgroundTransparency = 0.15, BorderSizePixel = 0, Font = CONFIG.Font,
		Text = data.class, TextSize = 24, TextColor3 = Color3.new(0, 0, 0), Parent = card,
	})
	card.Activated:Connect(function() selectObject(id) end)
	objectCards[id] = card
end
if MonsterData.Order[1] then selectObject(MonsterData.Order[1]) end

local BTN_Y = 274
button("SPAWN NEAR ME", DETAIL_X, 54 + BTN_Y, 214, 30, entitiesPage, function()
	if not selectedObject then status.Text = "no object" return end
	remote:FireServer("MonsterSpawn", 0, selectedObject, 0)
end)
button("SPAWN NEAR TARGET", DETAIL_X + 226, 54 + BTN_Y, 214, 30, entitiesPage, function()
	if not selectedObject then status.Text = "no object" return end
	if not selectedPlayer then status.Text = "select a target on the PLAYERS tab" return end
	remote:FireServer("MonsterSpawn", 0, selectedObject, selectedPlayer.UserId)
end)
button("REMOVE ALL", DETAIL_X, 54 + BTN_Y + 36, 214, 30, entitiesPage, function()
	remote:FireServer("MonsterClear", 0)
end)
button("SHOW BLOOD TRAIL", DETAIL_X + 226, 54 + BTN_Y + 36, 214, 30, entitiesPage, function()
	remote:FireServer("TrailView", 0)
end)

RunService.Heartbeat:Connect(function()
	if not entitiesPage.Visible then return end
	local monstersFolder = workspace:FindFirstChild("Monsters")
	local count = monstersFolder and monstersFolder:GetAttribute("Count") or 0
	activeLabel.Text = string.format("active: %d", count)
end)

remote.OnClientEvent:Connect(function(kind, message)
	status.Text = (kind == "ok" and "✓ " or "× ") .. tostring(message)
	status.TextColor3 = kind == "ok" and INK or MID
end)

local open = false
local function setOpen(value)
	open = value
	panel.Visible = value
	player:SetAttribute("UIOpen", value)
	if value then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == CONFIG.Key and not UserInputService:GetFocusedTextBox() then
		setOpen(not open)
	end
end)

RunService.RenderStepped:Connect(function()
	if not open then return end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	nightLabel.Text = (workspace:GetAttribute("Night") and "NIGHT" or "DAY") .. " · " .. string.upper(workspace:GetAttribute("Weather") or "Clear")
	if selectedPlayer and not isNpc(selectedPlayer) then
		cashTitle.Text = string.format("CASH  -  %s has $%d", selectedPlayer.DisplayName, selectedPlayer:GetAttribute("Cash") or 0)
	else
		cashTitle.Text = "CASH"
	end
	local shopState = workspace:GetAttribute("ShopState")
	shopLabel.Text = shopState and ("SHOP\n" .. string.lower(shopState)) or "SHOP"

	local character = characterOf(selectedPlayer)
	for name, data in pairs(partButtons) do
		local level = character and (character:GetAttribute("Injury_" .. name) or 0) or 0
		data.button.BackgroundColor3 = LEVEL_COLOR[level] or LEVEL_COLOR[0]
		data.stroke.Color = name == selectedPart and Color3.new(1, 1, 1) or (level >= 3 and MID or LINE)
		data.stroke.Thickness = name == selectedPart and 2 or 1
	end
end)

-- ===================== BANS / ANTICHEAT =====================
local acAdmin = ReplicatedStorage:WaitForChild("ACAdmin", 30)
local acAlert = ReplicatedStorage:WaitForChild("ACAlert", 30)

local function setStatus(ok, message)
	status.Text = (ok and "✓ " or "× ") .. tostring(message)
	status.TextColor3 = ok and INK or MID
end

local function call(action, ...)
	if not acAdmin then
		setStatus(false, "anti-cheat is not running")
		return false
	end
	local args = table.pack(...)
	local ok, result, payload = pcall(function() return acAdmin:InvokeServer(action, table.unpack(args, 1, args.n)) end)
	if not ok then
		setStatus(false, "request failed")
		return false
	end
	return result, payload
end

local function textBox(placeholder, x, y, w, parent)
	return create("TextBox", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 26), BackgroundColor3 = CELL, BorderSizePixel = 0,
		Font = CONFIG.Font, PlaceholderText = placeholder, PlaceholderColor3 = DIM, Text = "", TextSize = 14,
		TextColor3 = INK, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
	}, {
		create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
		create("UIPadding", {PaddingLeft = UDim.new(0, 6)}),
	})
end

local function listBox(x, y, w, h, parent)
	return create("ScrollingFrame", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = MID, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = parent,
	}, {
		create("UIStroke", {Color = LINE, Thickness = 1}),
		create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}),
		create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)}),
	})
end

local function clearList(list)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiButton") then child:Destroy() end
	end
end

-- round avatar head-shot for any user id (works for players who are offline too)
local function avatar(userId, size, position, parent, zIndex)
	local image = create("ImageLabel", {
		Position = position, Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.fromRGB(28, 28, 27),
		BorderSizePixel = 0, ZIndex = zIndex or 1, Parent = parent,
		Image = tonumber(userId) and tonumber(userId) > 0 and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", tonumber(userId)) or "",
	}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
	return image
end

local function listRow(list, order, top, bottom, onClick, userId)
	local row = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = CELL, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		LayoutOrder = order, Parent = list,
	})
	local x = 8
	if userId then
		avatar(userId, 32, UDim2.fromOffset(4, 4), row)
		x = 42
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(x, 3), Size = UDim2.new(1, -x - 4, 0, 18), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = top, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(x, 21), Size = UDim2.new(1, -x - 4, 0, 14), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = bottom, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	row.Activated:Connect(function()
		for _, other in ipairs(list:GetChildren()) do
			if other:IsA("GuiButton") then other.BackgroundColor3 = CELL end
		end
		row.BackgroundColor3 = Color3.fromRGB(45, 45, 44)
		onClick()
	end)
	return row
end

local function when(unix)
	return os.date("%d.%m %H:%M", unix)
end

-- does a record match what was typed in a search box (nick, display name, user id, reason)
local function matches(query, ...)
	query = string.lower((query or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if query == "" then return true end
	for _, value in ipairs({...}) do
		if value ~= nil and string.find(string.lower(tostring(value)), query, 1, true) then return true end
	end
	return false
end

-- ----- BANS -----
sectionTitle("BANS", 20, 54, bansPage)
local banSearch = textBox("search: nick, user id or reason", 20, 74, 380, bansPage)
local banList = listBox(20, 106, 380, 268, bansPage)
local selectedBan = nil
local banCache = {}

local function drawBans()
	clearList(banList)
	selectedBan = nil
	local shown = 0
	for i, entry in ipairs(banCache) do
		if not matches(banSearch.Text, entry.name, entry.userId, entry.reason, entry.by) then continue end
		shown += 1
		local active = entry.active and (entry.expires == -1 or os.time() < entry.expires)
		local expires = not entry.active and ("unbanned by " .. tostring(entry.unbannedBy or "?"))
			or (entry.expires == -1 and "permanent" or ((active and "until " or "expired ") .. when(entry.expires)))
		local top = string.format("%s%s  ·  %d", active and "" or "(inactive) ", tostring(entry.name), entry.userId)
		local bottom = string.format("%s — by %s — %s%s", tostring(entry.reason), tostring(entry.by or entry.source or "?"),
			expires, entry.allDevices and " — ALL DEVICES" or "")
		listRow(banList, i, top, bottom, function()
			selectedBan = entry
			setStatus(true, string.format("%s: %s (banned %s)", tostring(entry.name), tostring(entry.reason), when(entry.at)))
		end, entry.userId)
	end
	return shown
end

local function refreshBans()
	local ok, list = call("ListBans")
	if not ok then setStatus(false, list or "could not load bans") return end
	banCache = list
	local shown = drawBans()
	setStatus(true, string.format("%d ban record(s)%s", #list, shown ~= #list and string.format(", %d shown", shown) or ""))
end
banSearch:GetPropertyChangedSignal("Text"):Connect(drawBans)
onTabSelected.BANS = refreshBans

button("REFRESH", 300, 50, 100, 22, bansPage, refreshBans)
button("UNBAN SELECTED", 20, 382, 185, 30, bansPage, function()
	if not selectedBan then setStatus(false, "select a ban first") return end
	setStatus(true, "unbanning " .. tostring(selectedBan.name) .. "…")
	local ok, message = call("Unban", selectedBan.userId)
	setStatus(ok, message)
	if ok then refreshBans() end
end)

local FORM_X = 420
sectionTitle("NEW BAN", FORM_X, 54, bansPage)
local targetBox = textBox("username or user id", FORM_X, 74, 260, bansPage)
button("USE SELECTED PLAYER", FORM_X, 104, 260, 26, bansPage, function()
	if not selectedPlayer or isNpc(selectedPlayer) then setStatus(false, "select a player on the PLAYERS tab") return end
	targetBox.Text = tostring(selectedPlayer.UserId)
end)
local suggestBox = create("Frame", {
	Position = UDim2.fromOffset(FORM_X, 101), Size = UDim2.fromOffset(260, 0), BackgroundColor3 = Color3.fromRGB(12, 12, 12),
	BorderSizePixel = 0, Visible = false, ZIndex = 20, AutomaticSize = Enum.AutomaticSize.Y, Parent = bansPage,
}, {
	create("UIStroke", {Color = MID, Thickness = 1}),
	create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}),
})
local searchToken = 0
local function showSuggestions(results)
	for _, child in ipairs(suggestBox:GetChildren()) do
		if child:IsA("GuiButton") then child:Destroy() end
	end
	suggestBox.Visible = #results > 0
	for i, user in ipairs(results) do
		local row = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 0,
			AutoButtonColor = true, Font = CONFIG.Font, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = INK, ZIndex = 21, LayoutOrder = i, TextTruncate = Enum.TextTruncate.AtEnd,
			Text = string.format("         %s  @%s  ·  %s", tostring(user.displayName or user.name), tostring(user.name), tostring(user.source)),
			Parent = suggestBox,
		})
		avatar(user.userId, 24, UDim2.fromOffset(4, 3), row, 22)
		row.Activated:Connect(function()
			targetBox.Text = tostring(user.userId)
			suggestBox.Visible = false
			searchToken += 1
			setStatus(true, string.format("target: %s (@%s) · %d", tostring(user.displayName or user.name), tostring(user.name), user.userId))
		end)
	end
end
targetBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchToken += 1
	local my = searchToken
	local query = targetBox.Text
	if not targetBox:IsFocused() or query:gsub("%s", "") == "" or query:match("^%d+$") and #query > 6 then
		suggestBox.Visible = false
		return
	end
	task.delay(0.35, function()
		if my ~= searchToken then return end
		local ok, results = call("SearchUsers", query)
		if my ~= searchToken or not ok then return end
		showSuggestions(results)
	end)
end)
targetBox.FocusLost:Connect(function()
	task.delay(0.25, function() suggestBox.Visible = false end)
end)
local reasonBox = textBox("reason", FORM_X, 138, 260, bansPage)
local durationBox = textBox("duration: 30m / 12h / 7d / 2w / perm", FORM_X, 172, 260, bansPage)
local allDevices = true
local devicesButton
devicesButton = button("ALL DEVICES: ON", FORM_X, 206, 260, 28, bansPage, function()
	allDevices = not allDevices
	devicesButton.Text = allDevices and "ALL DEVICES: ON" or "ALL DEVICES: OFF"
end)
button("BAN", FORM_X, 244, 127, 30, bansPage, function()
	local ok, message = call("Ban", targetBox.Text, reasonBox.Text, durationBox.Text ~= "" and durationBox.Text or "perm", allDevices)
	setStatus(ok, message)
	if ok then refreshBans() end
end)
button("KICK", FORM_X + 133, 244, 127, 30, bansPage, function()
	local ok, message = call("Kick", targetBox.Text, reasonBox.Text)
	setStatus(ok, message)
end)
button("AC PUNISH", FORM_X, 280, 127, 30, bansPage, function()
	local ok, message = call("Punish", targetBox.Text)
	setStatus(ok, message)
end)
button("RECORD REPLAY", FORM_X + 133, 280, 127, 30, bansPage, function()
	local ok, message = call("Record", targetBox.Text)
	setStatus(ok, message)
end)
button("UNBAN THIS NAME / ID", FORM_X, 382, 260, 30, bansPage, function()
	if targetBox.Text:gsub("%s", "") == "" then setStatus(false, "type a nick or user id first") return end
	setStatus(true, "unbanning " .. targetBox.Text .. "…")
	local ok, message = call("Unban", targetBox.Text)
	setStatus(ok, message)
	if ok then refreshBans() end
end)
create("TextLabel", {
	Position = UDim2.fromOffset(FORM_X, 316), Size = UDim2.fromOffset(260, 60), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "ALL DEVICES also bans alt accounts Roblox links to the same device. AC PUNISH paralyses, lobotomises, kills, then bans.",
	TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = DIM, Parent = bansPage,
})

-- ----- ANTICHEAT: incidents (replays) and dossiers (every server) -----
sectionTitle("INCIDENTS / DOSSIERS", 20, 54, acPage)
local acSearch = textBox("search by nick or user id", 20, 74, 236, acPage)
local incidentList = listBox(20, 106, 400, 306, acPage)
local selectedIncident = nil
local selectedDossier = nil
local acMode = "incidents"  -- "incidents" | "dossiers" | "player" (one player's incidents from the dossier)
local incidentCache, dossierCache, playerIncidents = {}, {}, {}
local modeButtons = {}

local detailAvatar = avatar(0, 44, UDim2.fromOffset(440, 74), acPage)
detailAvatar.Visible = false
local detailName = create("TextLabel", {
	Position = UDim2.fromOffset(492, 74), Size = UDim2.fromOffset(188, 44), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "", TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, Parent = acPage,
})
local detailText = create("TextLabel", {
	Position = UDim2.fromOffset(440, 124), Size = UDim2.fromOffset(240, 160), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "select an incident", TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(200, 198, 194), Parent = acPage,
})

local function showPerson(userId, name)
	detailAvatar.Visible = userId ~= nil
	if userId then detailAvatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", userId) end
	detailName.Text = name or ""
end

local function clearDetail(text)
	selectedIncident, selectedDossier = nil, nil
	showPerson(nil, "")
	detailText.Text = text
end

local function showIncident(meta)
	selectedIncident = meta
	showPerson(meta.userId, tostring(meta.name))
	detailText.Text = string.format("user id: %s\nwhen: %s\naction: %s   score: %s\n\nreason: %s\n\nflags: %s\n\nserver: %s%s",
		tostring(meta.userId), when(meta.at or 0), tostring(meta.action), tostring(meta.score), tostring(meta.reason),
		tostring(meta.flags or "—"), string.sub(tostring(meta.server), 1, 8),
		meta.verdict and ("\nverdict: " .. string.upper(meta.verdict) .. " by " .. tostring(meta.verdictBy)) or "")
end

local function showDossier(summary)
	selectedDossier = summary
	showPerson(summary.userId, string.format("%s\n@%s", tostring(summary.displayName or summary.name), tostring(summary.name)))
	detailText.Text = "loading dossier…"
	local ok, data = call("GetDossier", summary.userId)
	if selectedDossier ~= summary then return end
	if not ok or not data then detailText.Text = tostring(data or "could not load the dossier") return end
	local d = data.dossier or {}
	local flags = {}
	for kind, n in pairs(d.flags or {}) do table.insert(flags, {kind, n}) end
	table.sort(flags, function(x, y) return x[2] > y[2] end)
	local flagText = {}
	for i, f in ipairs(flags) do
		if i > 8 then break end
		table.insert(flagText, f[1] .. " ×" .. f[2])
	end
	local banText = data.banActive and ("BANNED: " .. tostring(data.ban and data.ban.reason)) or (d.banned == false and #(d.bans or {}) > 0 and "unbanned" or "not banned")
	detailText.Text = string.format(
		"user id: %s\n%s%s\n\nfirst noticed: %s\nlast noticed: %s\nflags total: %d   peak score: %s\nservers: %d   incidents: %d\n\n%s\n\n%s",
		tostring(summary.userId), banText, data.online and ("   ·   ONLINE here, score " .. tostring(data.liveScore)) or "",
		d.firstAt and when(d.firstAt) or "—", d.lastAt and when(d.lastAt) or "—", d.totalFlags or 0, tostring(d.maxScore or 0),
		#(d.servers or {}), #(d.incidents or {}), #flagText > 0 and table.concat(flagText, ", ") or "no flags",
		(d.verdicts and d.verdicts[1]) and ("last verdict: " .. string.upper(tostring(d.verdicts[1].verdict)) .. " by " .. tostring(d.verdicts[1].by)) or "")
	playerIncidents = d.incidents or {}
end

local function drawList()
	clearList(incidentList)
	local query = acSearch.Text
	local shown = 0
	if acMode == "dossiers" then
		for i, summary in ipairs(dossierCache) do
			if matches(query, summary.name, summary.displayName, summary.userId) then
				shown += 1
				listRow(incidentList, i, string.format("%s  @%s%s", tostring(summary.displayName or summary.name), tostring(summary.name),
					summary.banned and "  [BANNED]" or ""),
					string.format("last %s · %d flags · %d incidents · %d servers%s", when(summary.lastAt or 0), summary.totalFlags or 0,
						summary.incidents or 0, summary.servers or 0, summary.topFlag and (" · mostly " .. summary.topFlag) or ""),
					function() showDossier(summary) end, summary.userId)
			end
		end
	else
		local list = acMode == "player" and playerIncidents or incidentCache
		for i, meta in ipairs(list) do
			if acMode == "player" or matches(query, meta.name, meta.userId, meta.reason) then
				shown += 1
				listRow(incidentList, i, string.format("%s — %s", tostring(meta.name or (selectedDossier and selectedDossier.name)), tostring(meta.reason)),
					string.format("%s%s · %s · score %s · %s", meta.verdict and ("[" .. string.upper(meta.verdict) .. "] ") or "",
						when(meta.at or 0), tostring(meta.action), tostring(meta.score), tostring(meta.flags or meta.server or "")),
					function()
						if acMode == "player" and selectedDossier then
							meta.userId = meta.userId or selectedDossier.userId
							meta.name = meta.name or selectedDossier.name
						end
						showIncident(meta)
					end, meta.userId or (selectedDossier and selectedDossier.userId))
			end
		end
	end
	return shown
end

local playButton, banButton, deleteButton
local function setMode(mode)
	acMode = mode
	for name, b in pairs(modeButtons) do
		b.TextColor3 = (name == mode or (name == "dossiers" and mode == "player")) and INK or DIM
	end
	playButton.Text = mode == "dossiers" and "SHOW THEIR INCIDENTS" or "PLAY REPLAY"
	deleteButton.Text = mode == "dossiers" and "UNBAN THIS PLAYER" or "DELETE"
	if mode ~= "player" then clearDetail(mode == "dossiers" and "select a player" or "select an incident") end
	local shown = drawList()
	setStatus(true, string.format("%d %s", shown, mode == "dossiers" and "dossier(s)" or "incident(s)"))
end

local function refreshIncidents()
	if acMode == "dossiers" or acMode == "player" then
		local ok, list = call("ListDossiers")
		if not ok then setStatus(false, list or "could not load dossiers") return end
		dossierCache = list
		setMode("dossiers")
	else
		local ok, list = call("ListIncidents")
		if not ok then setStatus(false, list or "could not load incidents") return end
		incidentCache = list
		setMode("incidents")
	end
end
onTabSelected.ANTICHEAT = refreshIncidents
acSearch:GetPropertyChangedSignal("Text"):Connect(function()
	if acMode == "player" then acMode = "dossiers" end
	drawList()
end)

modeButtons.incidents = button("INCIDENTS", 262, 74, 76, 26, acPage, function()
	acMode = "incidents"
	refreshIncidents()
end)
modeButtons.dossiers = button("DOSSIERS", 344, 74, 76, 26, acPage, function()
	acMode = "dossiers"
	refreshIncidents()
end)
for _, b in pairs(modeButtons) do b.TextSize = 12 end
button("REFRESH", 320, 50, 100, 22, acPage, refreshIncidents)

local playReplay
playButton = button("PLAY REPLAY", 440, 290, 240, 30, acPage, function()
	if acMode == "dossiers" then
		if not selectedDossier then setStatus(false, "select a player first") return end
		acMode = "player"
		local shown = drawList()
		for name, b in pairs(modeButtons) do b.TextColor3 = name == "dossiers" and INK or DIM end
		playButton.Text = "PLAY REPLAY"
		deleteButton.Text = "BACK TO DOSSIERS"
		setStatus(true, string.format("%d incident(s) of %s, from every server", shown, tostring(selectedDossier.name)))
		return
	end
	if not selectedIncident then setStatus(false, "select an incident first") return end
	local ok, data = call("GetIncident", selectedIncident.id)
	if not ok then setStatus(false, data or "replay not found") return end
	playReplay(data)
end)
banButton = button("BAN THIS PLAYER", 440, 326, 240, 30, acPage, function()
	local target = selectedIncident or selectedDossier
	if not target then setStatus(false, "select an incident or a player first") return end
	targetBox.Text = tostring(target.userId)
	reasonBox.Text = "Exploiting (" .. tostring(selectedIncident and selectedIncident.reason or (selectedDossier and selectedDossier.topFlag) or "anti-cheat") .. ")"
	selectTab("BANS")
end)
deleteButton = button("DELETE", 440, 362, 240, 30, acPage, function()
	if acMode == "player" then
		setMode("dossiers")
		return
	end
	if acMode == "dossiers" then
		if not selectedDossier then setStatus(false, "select a player first") return end
		local ok, message = call("Unban", selectedDossier.userId)
		setStatus(ok, message)
		return
	end
	if not selectedIncident then setStatus(false, "select an incident first") return end
	local ok, message = call("DeleteIncident", selectedIncident.id)
	setStatus(ok, message)
	if ok then refreshIncidents() end
end)

if acAlert then
	acAlert.OnClientEvent:Connect(function(kind, message)
		if kind == "incidents" then
			if acPage.Visible then refreshIncidents() end
			return
		end
		setStatus(true, message)
		status.TextColor3 = Color3.fromRGB(235, 60, 60)
	end)
end

-- ----- replay viewer -----
local replayGui = create("ScreenGui", {
	Name = "ACReplay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3001, Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})
local bar = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(760, 150),
	BackgroundColor3 = BG, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = replayGui,
}, {create("UIStroke", {Color = LINE, Thickness = 1})})
local replayTitle = create("TextLabel", {
	Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(736, 20), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, TextTruncate = Enum.TextTruncate.AtEnd, Parent = bar,
})
local seek = create("TextButton", {
	Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(736, 14), BackgroundColor3 = CELL, BorderSizePixel = 0,
	AutoButtonColor = false, Text = "", Parent = bar,
}, {create("UIStroke", {Color = LINE, Thickness = 1})})
local seekFill = create("Frame", {
	Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(150, 30, 30), BorderSizePixel = 0, Parent = seek,
})
local timeLabel = create("TextLabel", {
	Position = UDim2.fromOffset(12, 50), Size = UDim2.fromOffset(200, 18), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MID, Parent = bar,
})
local eventLog = create("TextLabel", {
	Position = UDim2.fromOffset(12, 70), Size = UDim2.fromOffset(470, 74), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
	TextColor3 = Color3.fromRGB(200, 198, 194), Parent = bar,
})

local replay = nil
local ghostFolder = nil

local function ghostPart(model, name, size, color, transparency, ball)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Shape = ball and Enum.PartType.Ball or Enum.PartType.Block
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = transparency
	part.Parent = model
	return part
end

local function buildGhost(entity)
	local color = entity.suspect and Color3.fromRGB(225, 40, 40)
		or (entity.kind == "monster" and Color3.fromRGB(25, 25, 28))
		or (entity.kind == "npc" and Color3.fromRGB(140, 165, 140))
		or Color3.fromRGB(200, 200, 205)
	local model = Instance.new("Model")
	model.Name = "AC_Ghost"
	local parts = {
		torso = ghostPart(model, "Torso", Vector3.new(2, 2, 1), color, 0.2),
		head = ghostPart(model, "Head", Vector3.new(1.2, 1.2, 1.2), color, 0.2, true),
		larm = ghostPart(model, "LeftArm", Vector3.new(1, 2, 1), color, 0.25),
		rarm = ghostPart(model, "RightArm", Vector3.new(1, 2, 1), color, 0.25),
		lleg = ghostPart(model, "LeftLeg", Vector3.new(1, 2, 1), color, 0.25),
		rleg = ghostPart(model, "RightLeg", Vector3.new(1, 2, 1), color, 0.25),
	}
	local tag = create("BillboardGui", {
		Name = "AC_Label", Adornee = parts.head, Size = UDim2.fromOffset(220, 34), StudsOffset = Vector3.new(0, 2, 0),
		AlwaysOnTop = true, LightInfluence = 0, Parent = model,
	})
	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = CONFIG.Font, Text = entity.name, TextSize = 13,
		TextColor3 = entity.suspect and Color3.fromRGB(255, 90, 90) or INK, TextStrokeTransparency = 0.3, Parent = tag,
	})
	if entity.suspect then
		create("Highlight", {Name = "AC_Highlight", FillColor = color, FillTransparency = 0.6, OutlineColor = color, Parent = model})
	end
	model.Parent = ghostFolder
	return {model = model, parts = parts, label = label, phase = 0, entity = entity}
end

local function frameAt(t)
	local frames = replay.frames
	local lo, hi = 1, #frames
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if frames[mid][1] <= t then lo = mid else hi = mid - 1 end
	end
	return lo
end

local function entityIn(frame, index)
	for i = 2, #frame do
		if frame[i][1] == index then return frame[i] end
	end
	return nil
end

local function poseGhost(ghost, e0, e1, alpha, dt)
	local function lerp(a, b) return a + (b - a) * alpha end
	local x, y, z = lerp(e0[2], e1[2]), lerp(e0[3], e1[3]), lerp(e0[4], e1[4])
	local yaw0, yaw1 = e0[5], e1[5]
	local dyaw = (yaw1 - yaw0 + math.pi) % (2 * math.pi) - math.pi
	local yaw = yaw0 + dyaw * alpha
	local state = alpha < 0.5 and e0[6] or e1[6]
	local speed = Vector3.new(e1[2] - e0[2], 0, e1[4] - e0[4]).Magnitude * 10
	ghost.phase += dt * math.clamp(speed, 0, 30) * 0.6
	local swing = math.sin(ghost.phase) * 0.7 * math.clamp(speed / 16, 0, 1)
	local root = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	if state >= 2 then root = CFrame.new(x, y - 2, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-90), 0, 0) end
	local p = ghost.parts
	p.torso.CFrame = root
	p.head.CFrame = root * CFrame.new(0, 1.6, 0)
	p.larm.CFrame = root * CFrame.new(-1.5, 1, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
	p.rarm.CFrame = root * CFrame.new(1.5, 1, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
	p.lleg.CFrame = root * CFrame.new(-0.5, -1, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
	p.rleg.CFrame = root * CFrame.new(0.5, -1, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
	local hp = alpha < 0.5 and e0[7] or e1[7]
	ghost.label.Text = string.format("%s  ·  %d%%%s", ghost.entity.name, hp, state == 3 and "  · DEAD" or (state == 2 and "  · DOWN" or ""))
end

local function followGhost(index)
	local ghost = replay and replay.ghosts[index]
	if not ghost then return end
	replay.follow = index
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = ghost.parts.head
end

local function stopReplay()
	if not replay then return end
	replay = nil
	replayGui.Enabled = false
	if ghostFolder then ghostFolder:Destroy() ghostFolder = nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then camera.CameraSubject = humanoid end
end

function playReplay(data)
	stopReplay()
	local r = data.replay
	if not r or not r.frames or #r.frames < 2 then setStatus(false, "replay is empty") return end
	ghostFolder = Instance.new("Folder")
	ghostFolder.Name = "AC_ReplayGhosts"
	ghostFolder.Parent = workspace
	replay = {frames = r.frames, events = r.events or {}, entities = r.entities, length = r.frames[#r.frames][1],
		t = 0, speed = 1, playing = true, ghosts = {}, follow = 1, meta = data.meta}
	local suspectIndex = 1
	for i, entity in ipairs(r.entities) do
		replay.ghosts[i] = buildGhost(entity)
		if entity.suspect then suspectIndex = i end
	end
	for _, child in ipairs(seek:GetChildren()) do
		if child.Name == "Marker" then child:Destroy() end
	end
	for _, ev in ipairs(replay.events) do
		local color = ev[3] == "flag" and Color3.fromRGB(255, 60, 60) or (ev[3] == "death" and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 120))
		create("Frame", {
			Name = "Marker", Position = UDim2.new(ev[1] / replay.length, 0, 0, 0), Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 2, Parent = seek,
		})
	end
	replayTitle.Text = string.format("REPLAY  ·  %s  ·  %s  ·  %s", tostring(data.meta.name), tostring(data.meta.reason), when(data.meta.at))
	replayGui.Enabled = true
	setOpen(false)
	followGhost(suspectIndex)
end

local pauseButton
pauseButton = button("PAUSE", 500, 52, 80, 26, bar, function()
	if not replay then return end
	replay.playing = not replay.playing
	pauseButton.Text = replay.playing and "PAUSE" or "PLAY"
end)
local speedButton
speedButton = button("x1", 586, 52, 50, 26, bar, function()
	if not replay then return end
	replay.speed = replay.speed >= 2 and 0.25 or replay.speed * 2
	speedButton.Text = "x" .. tostring(replay.speed)
end)
button("RESTART", 642, 52, 106, 26, bar, function()
	if replay then replay.t = 0 end
end)
local function verdict(kind)
	if not replay or not replay.meta then return end
	local ok, message = call("Verdict", replay.meta.id, kind)
	setStatus(ok, message)
	replayTitle.Text = (ok and (kind == "cheat" and "BANNED  ·  " or "CLEARED  ·  ") or "") .. replayTitle.Text
end
local cheatButton = button("CHEATS: PERM BAN", 500, 116, 120, 26, bar, function() verdict("cheat") end)
cheatButton.TextColor3 = Color3.fromRGB(235, 70, 70)
cheatButton.TextSize = 12
local legitButton = button("LEGIT: RELEASE", 628, 116, 120, 26, bar, function() verdict("legit") end)
legitButton.TextSize = 12
button("NEXT VIEW", 500, 84, 120, 26, bar, function()
	if not replay then return end
	followGhost(replay.follow % #replay.ghosts + 1)
end)
button("CLOSE", 628, 84, 120, 26, bar, stopReplay)
seek.Activated:Connect(function()
	if not replay then return end
	local mouse = UserInputService:GetMouseLocation()
	local alpha = math.clamp((mouse.X - seek.AbsolutePosition.X) / seek.AbsoluteSize.X, 0, 1)
	replay.t = alpha * replay.length
end)

RunService.RenderStepped:Connect(function(dt)
	if not replay then return end
	if replay.playing then
		replay.t = math.min(replay.t + dt * replay.speed, replay.length)
		if replay.t >= replay.length then
			replay.playing = false
			pauseButton.Text = "PLAY"
		end
	end
	local t = replay.t
	local i = frameAt(t)
	local f0 = replay.frames[i]
	local f1 = replay.frames[math.min(i + 1, #replay.frames)]
	local span = f1[1] - f0[1]
	local alpha = span > 0 and math.clamp((t - f0[1]) / span, 0, 1) or 0
	for index, ghost in ipairs(replay.ghosts) do
		local e0 = entityIn(f0, index)
		local e1 = entityIn(f1, index) or e0
		if e0 then
			if not ghost.model.Parent then ghost.model.Parent = ghostFolder end
			poseGhost(ghost, e0, e1, alpha, dt * replay.speed)
		elseif ghost.model.Parent then
			ghost.model.Parent = nil
		end
	end
	seekFill.Size = UDim2.fromScale(t / replay.length, 1)
	timeLabel.Text = string.format("%05.1fs / %05.1fs", t, replay.length)
	local lines = {}
	for _, ev in ipairs(replay.events) do
		if ev[1] <= t then
			local entity = replay.entities[ev[2]]
			table.insert(lines, string.format("%05.1fs  %s  %s: %s", ev[1], entity and entity.name or "?", ev[3], tostring(ev[4])))
		end
	end
	eventLog.Text = table.concat(lines, "\n", math.max(1, #lines - 4), #lines)
end)

-- ===================== small screens and touch =====================
local panelScale = create("UIScale", {Parent = panel})
local barScale = create("UIScale", {Parent = bar})
local function rescale()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local size = camera.ViewportSize
	panelScale.Scale = math.clamp(math.min((size.X - 16) / 700, (size.Y - 16) / 540), 0.4, 1)
	barScale.Scale = math.clamp((size.X - 16) / 760, 0.4, 1)
end
rescale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(rescale)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

-- touch: an ADMIN button under the HUD and TAB buttons, drawn like them
if UserInputService.TouchEnabled then
	local adminButton = create("TextButton", {
		Name = "AdminButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.36, 76), Size = UDim2.fromOffset(64, 30),
		BackgroundColor3 = Color3.fromRGB(8, 6, 6), BackgroundTransparency = 0.25, AutoButtonColor = false, Font = CONFIG.Font,
		Text = "ADMIN", TextSize = 14, TextColor3 = Color3.fromRGB(135, 124, 118), Parent = gui,
	}, {create("UIStroke", {Color = Color3.fromRGB(70, 12, 12), Thickness = 1})})
	adminButton.Activated:Connect(function() setOpen(not open) end)
	RunService.RenderStepped:Connect(function()
		adminButton.Visible = player:GetAttribute("InMenu") ~= true
	end)
end


-- ===================== ITEMS: give anything, the SCG set, PvP =====================
do
	local ItemData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemData"))
	local ShopModels = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ShopModels"))
	sectionTitle("ITEMS", 20, 54, itemsPage)
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 74), Size = UDim2.fromOffset(260, 400), BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = MID, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = itemsPage,
	}, {
		create("UIStroke", {Color = LINE, Thickness = 1}),
		create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}),
		create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)}),
	})
	local X = 300
	local view = create("ViewportFrame", {
		Position = UDim2.fromOffset(X, 74), Size = UDim2.fromOffset(160, 120), BackgroundColor3 = Color3.fromRGB(14, 13, 13),
		BorderSizePixel = 0, Ambient = Color3.fromRGB(125, 115, 110), LightColor = Color3.fromRGB(255, 236, 222),
		LightDirection = Vector3.new(-0.6, -1, -0.4), Parent = itemsPage,
	}, {create("UIStroke", {Color = LINE, Thickness = 1})})
	local viewCam = create("Camera", {FieldOfView = 30, Parent = view})
	view.CurrentCamera = viewCam
	local nameLabel = create("TextLabel", {
		Position = UDim2.fromOffset(X + 170, 74), Size = UDim2.fromOffset(210, 22), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = itemsPage,
	})
	local descLabel = create("TextLabel", {
		Position = UDim2.fromOffset(X + 170, 98), Size = UDim2.fromOffset(210, 96), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = "", TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = MID, Parent = itemsPage,
	})
	local amountBox = create("TextBox", {
		Position = UDim2.fromOffset(X, 206), Size = UDim2.fromOffset(80, 30), BackgroundColor3 = CELL, BorderSizePixel = 0,
		Font = CONFIG.Font, PlaceholderText = "amount", PlaceholderColor3 = DIM, Text = "1", TextSize = 14, TextColor3 = INK,
		ClearTextOnFocus = false, Parent = itemsPage,
	}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})

	local selectedItem = nil
	local rows = {}
	local function preview(id)
		for _, c in ipairs(view:GetChildren()) do
			if c:IsA("Model") or c:IsA("WorldModel") then c:Destroy() end
		end
		local model = ShopModels.Build(id)
		model.Parent = view
		local cf, size = model:GetBoundingBox()
		model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot())
		local radius = size.Magnitude / 2
		viewCam.CFrame = CFrame.lookAt(Vector3.new(radius * 0.6, radius * 0.5, -radius / math.tan(math.rad(15))), Vector3.zero)
	end
	for i, id in ipairs(ItemData.Order) do
		local item = ItemData.Get(id)
		local row = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = CELL, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
			LayoutOrder = i, Parent = list,
		})
		create("TextLabel", {
			Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -80, 1, 0), BackgroundTransparency = 1, Font = CONFIG.Font,
			Text = item.name, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
		})
		create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(70, 30),
			BackgroundTransparency = 1, Font = CONFIG.Font, Text = item.adminOnly and "SCG" or ("$" .. item.price), TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = item.adminOnly and Color3.fromRGB(235, 70, 70) or Color3.fromRGB(220, 170, 60), Parent = row,
		})
		row.Activated:Connect(function()
			selectedItem = id
			for rid, r in pairs(rows) do r.BackgroundColor3 = rid == id and Color3.fromRGB(45, 45, 44) or CELL end
			nameLabel.Text = item.name
			local extra = ""
			if item.kind == "armor" then extra = string.format("  %d durability, %.1f kg.", item.durability, item.weight)
			elseif item.kind == "gun" then extra = string.format("  %d x %d dmg, %d rounds.", item.pellets, item.damage, item.magazine) end
			descLabel.Text = (item.desc or "") .. extra
			preview(id)
		end)
		rows[id] = row
	end

	local function amount()
		return math.clamp(math.floor(tonumber(amountBox.Text) or 1), 1, 200)
	end
	local give = button("GIVE TO SELECTED", X + 90, 206, 150, 30, itemsPage, function()
		if not selectedItem then status.Text = "pick an item" return end
		if not selectedPlayer or isNpc(selectedPlayer) then status.Text = "select a player on the PLAYERS tab" return end
		send("GiveItem", selectedItem, amount())
	end)
	give.TextSize = 13
	local toMe = button("GIVE TO ME", X + 246, 206, 134, 30, itemsPage, function()
		if not selectedItem then status.Text = "pick an item" return end
		remote:FireServer("GiveItem", player.UserId, selectedItem, amount())
	end)
	toMe.TextSize = 13
	local scg = button("SCG SET -> SELECTED", X, 246, 186, 30, itemsPage, function()
		if not selectedPlayer or isNpc(selectedPlayer) then status.Text = "select a player on the PLAYERS tab" return end
		send("GiveItem", "scg_set", 1)
	end)
	scg.TextColor3 = Color3.fromRGB(235, 70, 70)
	scg.TextSize = 13
	local scgMe = button("SCG SET -> ME", X + 194, 246, 186, 30, itemsPage, function()
		remote:FireServer("GiveItem", player.UserId, "scg_set", 1)
	end)
	scgMe.TextColor3 = Color3.fromRGB(235, 70, 70)
	scgMe.TextSize = 13
	button("EMPTY SELECTED'S BAG", X, 286, 380, 30, itemsPage, function()
		if not selectedPlayer or isNpc(selectedPlayer) then status.Text = "select a player on the PLAYERS tab" return end
		send("ClearBag")
	end).TextSize = 13

	sectionTitle("PVP BETWEEN PLAYERS", X, 336, itemsPage)
	local pvpLabel = create("TextLabel", {
		Position = UDim2.fromOffset(X + 200, 336), Size = UDim2.fromOffset(180, 16), BackgroundTransparency = 1,
		Font = CONFIG.Font, Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = MID, Parent = itemsPage,
	})
	local pvpOn = button("PVP ON", X, 358, 186, 34, itemsPage, function() send("Pvp", true) end)
	pvpOn.TextColor3 = Color3.fromRGB(235, 70, 70)
	button("PVP OFF", X + 194, 358, 186, 34, itemsPage, function() send("Pvp", false) end)
	create("TextLabel", {
		Position = UDim2.fromOffset(X, 400), Size = UDim2.fromOffset(380, 60), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = "PvP off: guns, melee and traps never hurt other survivors (the infected can always be hurt). "
			.. "SCG items can only be given here, never bought.",
		TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = DIM, Parent = itemsPage,
	})
	local function refreshPvp()
		local on = workspace:GetAttribute("GS_PvP") == true
		pvpLabel.Text = on and "ON - players can hurt each other" or "OFF"
		pvpLabel.TextColor3 = on and Color3.fromRGB(235, 70, 70) or MID
	end
	workspace:GetAttributeChangedSignal("GS_PvP"):Connect(refreshPvp)
	refreshPvp()
end
]=]},
	{name = "AdminServer", class = "Script", where = "ServerScriptService", source = [=[
local Players = game:GetService("Players")
local function isNpc(x)
	return type(x) == "table" and x.IsNpc == true
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))

local ADMINS = {
	[1666069865] = "Owner",
}

local function isAdmin(player)
	return ADMINS[player.UserId] ~= nil
end

local remote = ReplicatedStorage:FindFirstChild("AdminAction")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "AdminAction"
	remote.Parent = ReplicatedStorage
end

local PARTS = {Head = true, Torso = true, RightArm = true, LeftArm = true, RightLeg = true, LeftLeg = true}

local function reply(player, ok, message)
	remote:FireClient(player, ok and "ok" or "error", message)
end

local npcRegistry = ReplicatedStorage:FindFirstChild("NPCs")
if not npcRegistry then
	npcRegistry = Instance.new("Folder")
	npcRegistry.Name = "NPCs"
	npcRegistry.Parent = ReplicatedStorage
end
local npcFolder = workspace:FindFirstChild("NPCs")
if not npcFolder then
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "NPCs"
	npcFolder.Parent = workspace
end

local NPC_NAMES = {
	"Jacob", "Ethan", "Mason", "Walter", "Arthur", "Victor", "Ivan", "Dmitri", "Oleg", "Henry",
	"Anna", "Maria", "Sofia", "Emma", "Olga", "Clara", "Martha", "Nikolai", "Leon", "Harold",
}
local NPC_ANIMS = {
	idle = {"rbxassetid://180435571", true, Enum.AnimationPriority.Idle},
	walk = {"rbxassetid://180426354", true, Enum.AnimationPriority.Movement},
	jump = {"rbxassetid://125750702", false, Enum.AnimationPriority.Movement},
	fall = {"rbxassetid://180436148", true, Enum.AnimationPriority.Movement},
	climb = {"rbxassetid://180436334", true, Enum.AnimationPriority.Movement},
}
local NPC_WALK_SPEED = 16
local LEG_SPEED = {OneDamaged = 0.85, BothDamaged = 0.75, OneBroken = 0.6, BrokenAndDamaged = 0.5}
local npcs = {}
local nextNpcId = -1

local function buildNpc(entry)
	entry.tracks = nil
	entry.current = nil
	entry.goal = nil
	entry.downUntil = nil
	local desc = Instance.new("HumanoidDescription")
	local grey = Color3.fromRGB(163, 162, 165)
	desc.HeadColor, desc.TorsoColor = grey, grey
	desc.LeftArmColor, desc.RightArmColor = grey, grey
	desc.LeftLegColor, desc.RightLegColor = grey, grey
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then return nil, "could not build rig" end
	model.Name = "NPC_" .. tostring(-entry.id)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") then d:Destroy() end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then model:Destroy() return nil, "bad rig" end
	humanoid.DisplayName = entry.name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model:SetAttribute("NpcId", entry.id)
	model:SetAttribute("DisplayName", entry.name)
	model:PivotTo(entry.cframe)
	model.Parent = npcFolder
	pcall(function() root:SetNetworkOwner(nil) end)
	entry.model = model
	entry.config:SetAttribute("Alive", true)
	task.spawn(FallDamageController.Setup, model)
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	entry.tracks = true
	entry.home = root.Position
	entry.nextThink = os.clock() + 3.5 + math.random() * 3
	entry.stuckTime = 0
	entry.nextWince = os.clock() + 5
	humanoid.Died:Connect(function()
		if entry.model == model then
			entry.config:SetAttribute("Alive", false)
			local r = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
			if r then entry.cframe = CFrame.new(r.Position + Vector3.new(0, 3, 0)) end
		end
	end)
	return model
end

local function createNpc(name, cframe)
	local id = nextNpcId
	nextNpcId -= 1
	if typeof(name) ~= "string" or name:gsub("%s", "") == "" then
		name = NPC_NAMES[math.random(1, #NPC_NAMES)]
	end
	name = name:sub(1, 24)
	local config = Instance.new("Configuration")
	config.Name = tostring(-id)
	config:SetAttribute("Id", id)
	config:SetAttribute("DisplayName", name)
	config:SetAttribute("Alive", false)
	config.Parent = npcRegistry
	local entry = {id = id, name = name, cframe = cframe, config = config}
	npcs[id] = entry
	local model, err = buildNpc(entry)
	if not model then
		config:Destroy()
		npcs[id] = nil
		return nil, err
	end
	return entry
end

local function deleteNpc(entry)
	if entry.model and entry.model.Parent then entry.model:Destroy() end
	entry.config:Destroy()
	npcs[entry.id] = nil
end

local function getTarget(targetUserId)
	if typeof(targetUserId) ~= "number" then return nil end
	if targetUserId < 0 then
		local entry = npcs[targetUserId]
		if not entry then return nil end
		local character = entry.model and entry.model.Parent and entry.model or nil
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local target = {DisplayName = entry.name, UserId = entry.id, IsNpc = true, Entry = entry}
		return target, character, humanoid
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then return nil end
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return target, character, humanoid
end

local ACTIONS = {}

ACTIONS.SetInjury = function(admin, target, character, humanoid, part, level)
	if not character or not humanoid or humanoid.Health <= 0 then return false, "target has no living character" end
	if not PARTS[part] or typeof(level) ~= "number" then return false, "bad part" end
	level = math.clamp(math.floor(level), 0, 3)
	if part == "Torso" and level == 3 then level = 2 end
	local current = character:GetAttribute("Injury_" .. part) or 0
	if current >= 3 and level < 3 then return false, "can't reattach a severed part — respawn the player" end
	character:SetAttribute("Injury_" .. part, level)
	local names = {[0] = "healed", "damaged", "broken", "severed"}
	return true, string.format("%s: %s %s", target.DisplayName, part, names[level])
end

ACTIONS.HealAll = function(admin, target, character, humanoid)
	if not character or not humanoid or humanoid.Health <= 0 then return false, "target has no living character" end
	for part in pairs(PARTS) do
		if (character:GetAttribute("Injury_" .. part) or 0) < 3 then
			character:SetAttribute("Injury_" .. part, 0)
		end
	end
	humanoid.Health = humanoid.MaxHealth
	FallDamageController.StopBleeding(character)
	return true, target.DisplayName .. " healed"
end

ACTIONS.Damage = function(admin, target, character, humanoid, amount)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	amount = typeof(amount) == "number" and math.clamp(amount, 1, 1000) or 25
	humanoid:TakeDamage(amount)
	return true, string.format("%s took %d damage", target.DisplayName, amount)
end

ACTIONS.Bleed = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	FallDamageController.AddBleeding(character, 1, 30)
	return true, target.DisplayName .. " is bleeding"
end

ACTIONS.Kill = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is already dead" end
	humanoid.Health = 0
	return true, target.DisplayName .. " killed"
end

ACTIONS.Gib = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is already dead" end
	character:SetAttribute("Gibbed", true)
	character:SetAttribute("LastDamageCause", "FALL")
	character:SetAttribute("LastDamageTime", workspace:GetServerTimeNow())
	humanoid.Health = 0
	return true, target.DisplayName .. " torn apart"
end

ACTIONS.ExplodePart = function(admin, target, character, humanoid, part)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	if not PARTS[part] then return false, "bad part" end
	local ok, err = FallDamageController.ExplodePart(character, part)
	if not ok then return false, err or "failed" end
	return true, string.format("%s: %s exploded", target.DisplayName, part)
end

ACTIONS.RestorePart = function(admin, target, character, humanoid, part)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	if not PARTS[part] then return false, "bad part" end
	local ok, err = FallDamageController.RestorePart(character, part)
	if not ok then return false, err or "failed" end
	return true, string.format("%s: %s restored", target.DisplayName, part)
end

ACTIONS.Lobotomy = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	local value = not character:GetAttribute("Lobotomized")
	character:SetAttribute("Lobotomized", value)
	return true, target.DisplayName .. (value and " lobotomized" or ": lobotomy removed")
end

ACTIONS.NpcAI = function(admin, target)
	if not isNpc(target) then return false, "not an npc" end
	local entry = target.Entry
	entry.aiOff = not entry.aiOff
	entry.config:SetAttribute("AI", not entry.aiOff)
	if entry.aiOff and entry.model and entry.model.Parent then
		local humanoid = entry.model:FindFirstChildOfClass("Humanoid")
		local root = entry.model:FindFirstChild("HumanoidRootPart")
		if humanoid and root then humanoid:MoveTo(root.Position) end
		entry.goal = nil
	end
	return true, entry.name .. (entry.aiOff and ": AI off" or ": AI on")
end

ACTIONS.HeadPop = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is already dead" end
	if not FallDamageController.ExplodeHead(character) then return false, "no head" end
	return true, target.DisplayName .. "'s head exploded"
end

ACTIONS.Weather = function(admin, _, _, _, kind)
	local allowed = {Clear = true, Rain = true, Storm = true, Wind = true, Fog = true}
	if not allowed[kind] then return false, "bad weather" end
	workspace:SetAttribute("WeatherLock", os.clock())
	workspace:SetAttribute("Weather", kind)
	return true, "weather: " .. kind
end

ACTIONS.Ragdoll = function(admin, target, character, humanoid, duration)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	duration = typeof(duration) == "number" and math.clamp(duration, 0.5, 60) or 3
	FallDamageController.Ragdoll(character, duration, 0.4)
	return true, string.format("%s ragdolled for %ds", target.DisplayName, duration)
end

ACTIONS.Respawn = function(admin, target)
	if isNpc(target) then
		local entry = target.Entry
		if entry.model and entry.model.Parent then entry.model:Destroy() end
		local model, err = buildNpc(entry)
		if not model then return false, err end
		return true, entry.name .. " respawned"
	end
	target:LoadCharacter()
	return true, target.DisplayName .. " respawned"
end

ACTIONS.NpcCreate = function(admin, _, _, _, name)
	local character = admin.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local cframe = root and (root.CFrame * CFrame.new(0, 0, -6)) or CFrame.new(0, 10, 0)
	cframe = CFrame.new(cframe.Position) * CFrame.Angles(0, math.atan2(-(root and root.CFrame.LookVector.X or 0), -(root and root.CFrame.LookVector.Z or 1)) + math.pi, 0)
	local entry, err = createNpc(name, cframe)
	if not entry then return false, err end
	return true, "npc created: " .. entry.name
end

ACTIONS.NpcDelete = function(admin, target)
	if not isNpc(target) then return false, "not an npc" end
	deleteNpc(target.Entry)
	return true, target.DisplayName .. " deleted"
end

ACTIONS.Night = function(admin, _, _, _, enabled)
	workspace:SetAttribute("Night", enabled == true)
	return true, enabled and "night started" or "night ended"
end

local ServerStorage = game:GetService("ServerStorage")
local function monsterControl(...)
	local control = ServerStorage:FindFirstChild("GS_MonsterControl") or ServerStorage:WaitForChild("GS_MonsterControl", 5)
	if not control then return false, "monster system is not running" end
	return control:Invoke(...)
end

ACTIONS.MonsterSpawn = function(admin, _, _, _, id, whereUserId)
	if typeof(id) ~= "string" then return false, "no object selected" end
	local anchorCharacter = admin.Character
	if typeof(whereUserId) == "number" and whereUserId ~= 0 then
		local _, character = getTarget(whereUserId)
		anchorCharacter = character or anchorCharacter
	end
	local root = anchorCharacter and anchorCharacter:FindFirstChild("HumanoidRootPart")
	if not root then return false, "no position (spawn your character first)" end
	return monsterControl("Spawn", id, root.Position)
end

ACTIONS.MonsterClear = function()
	return monsterControl("Clear")
end

ACTIONS.TrailView = function(admin)
	local ok, points = monsterControl("Trail")
	if not ok then return false, points end
	local fx = ReplicatedStorage:FindFirstChild("MonsterFX")
	if fx then fx:FireClient(admin, nil, "Trail", points) end
	return true, string.format("blood trail: %d points (shown for 15s)", #points)
end

-- infection: 1-3 = that stage (turns them on the spot if they're human), 0 = cure
ACTIONS.Infect = function(admin, target, character, humanoid, stage)
	if isNpc(target) then return false, "npcs can't be infected" end
	return monsterControl("SetInfection", target, stage)
end

-- the supply depot: open = true raises it, false sends it back under (ShopServer does the work)
ACTIONS.Shop = function(admin, _, _, _, open)
	local control = game:GetService("ServerStorage"):FindFirstChild("GS_ShopControl")
	if not control then return false, "no shop in this place" end
	return control:Invoke(open == true)
end

-- money (Economy script): a positive amount gives, a negative one takes
ACTIONS.Cash = function(admin, target, character, humanoid, amount)
	if isNpc(target) then return false, "npcs have no money" end
	local economy = game:GetService("ServerStorage"):FindFirstChild("GS_Economy")
	if not economy then return false, "no economy" end
	if typeof(amount) ~= "number" or amount ~= amount or amount == 0 or math.abs(amount) > 1000000 then return false, "bad amount" end
	amount = math.floor(amount)
	local ok, cash = economy:Invoke("add", target, amount)
	if not ok then return false, tostring(cash) end
	return true, string.format("%s  %s$%d  -  now $%d", target.DisplayName, amount >= 0 and "+" or "-", math.abs(amount), cash)
end

-- items (Inventory script): give any item or the whole SCG set, empty a bag
local function itemAdmin(...)
	local api = game:GetService("ServerStorage"):FindFirstChild("GS_ItemAdmin")
	if not api then return false, "the Inventory script is not running" end
	return api:Invoke(...)
end
ACTIONS.GiveItem = function(admin, target, character, humanoid, itemId, amount)
	if isNpc(target) then return false, "npcs don't carry things" end
	if typeof(itemId) ~= "string" then return false, "no item" end
	return itemAdmin("give", target, itemId, amount)
end
ACTIONS.ClearBag = function(admin, target)
	if isNpc(target) then return false, "npcs don't carry things" end
	return itemAdmin("clear", target)
end
ACTIONS.Pvp = function(admin, _, _, _, enabled)
	return itemAdmin("pvp", enabled == true)
end

local WORLD_ACTIONS = {Night = true, Weather = true, NpcCreate = true, MonsterSpawn = true, MonsterClear = true, TrailView = true, Shop = true, Pvp = true}
local lastUse = {}

remote.OnServerEvent:Connect(function(player, action, targetUserId, a, b)
	if not isAdmin(player) then return end
	local now = os.clock()
	if now - (lastUse[player] or 0) < 0.15 then return end
	lastUse[player] = now
	local handler = typeof(action) == "string" and ACTIONS[action]
	if not handler then return reply(player, false, "unknown action") end
	local target, character, humanoid
	if not WORLD_ACTIONS[action] then
		target, character, humanoid = getTarget(targetUserId)
		if not target then return reply(player, false, "player not found") end
	end
	local ok, result, message = pcall(handler, player, target, character, humanoid, a, b)
	if not ok then
		reply(player, false, "error: " .. tostring(result))
	else
		reply(player, result, message)
	end
end)

local function onPlayer(player)
	if isAdmin(player) then
		player:SetAttribute("IsAdmin", true)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
Players.PlayerRemoving:Connect(function(player) lastUse[player] = nil end)

local resetRemote = ReplicatedStorage:FindFirstChild("ResetRequest")
if not resetRemote then
	resetRemote = Instance.new("RemoteEvent")
	resetRemote.Name = "ResetRequest"
	resetRemote.Parent = ReplicatedStorage
end
local lastReset = {}
resetRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastReset[player] or 0) < 2 then return end
	lastReset[player] = now
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if not FallDamageController.ExplodeHead(character) then
		humanoid.Health = 0
	end
end)
Players.PlayerRemoving:Connect(function(player) lastReset[player] = nil end)

local RunService = game:GetService("RunService")
local npcParams = RaycastParams.new()
npcParams.FilterType = Enum.RaycastFilterType.Exclude

local function playTrack() end
local function stopTracks() end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, entry in pairs(npcs) do
		local model = entry.model
		local humanoid = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
		local root = model and model.Parent and model:FindFirstChild("HumanoidRootPart")
		if humanoid and root and entry.tracks and humanoid.Health > 0 then
			if model:GetAttribute("Ragdolled") then
				stopTracks(entry)
				humanoid:Move(Vector3.zero)
			else
				local r = model:GetAttribute("Injury_RightLeg") or 0
				local l = model:GetAttribute("Injury_LeftLeg") or 0
				local hi, lo = math.max(r, l), math.min(r, l)
				local mult = 1
				local cantWalk = hi >= 3 or (r >= 2 and l >= 2)
				if hi == 2 then mult = lo == 1 and LEG_SPEED.BrokenAndDamaged or LEG_SPEED.OneBroken
				elseif hi == 1 then mult = lo == 1 and LEG_SPEED.BothDamaged or LEG_SPEED.OneDamaged end
				local bleeding = model:GetAttribute("Bleeding") or 0
				mult *= math.clamp(1 - bleeding * 0.2, 0.6, 1)
				if entry.flinchUntil and now < entry.flinchUntil then mult *= 0.15 end
				humanoid.WalkSpeed = cantWalk and NPC_WALK_SPEED * 0.2 or NPC_WALK_SPEED * mult
				humanoid.JumpPower = cantWalk and 0 or 50 * math.sqrt(mult)
				local moving = root.AssemblyLinearVelocity.Magnitude > 2
				if hi >= 1 and hi < 3 and moving and now > entry.nextWince then
					entry.nextWince = now + (hi == 2 and (4 + math.random() * 5) or (10 + math.random() * 8))
					entry.flinchUntil = now + (hi == 2 and 0.9 or 0.4)
					model:SetAttribute("Wince", (hi == 2 and 1 or 0.4) + math.random() * 0.01)
				end
				if entry.aiOff then
					entry.goal = nil
				else
					if now >= entry.nextThink then
						entry.nextThink = now + 3 + math.random() * 7
						if math.random() < 0.35 then
							entry.goal = nil
							humanoid:Move(Vector3.zero)
						else
							local angle = math.random() * math.pi * 2
							local dist = 6 + math.random() * 22
							local target = entry.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
							npcParams.FilterDescendantsInstances = {model}
							local hit = workspace:Raycast(target + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), npcParams)
							if hit then
								entry.goal = hit.Position
								humanoid:MoveTo(hit.Position)
							end
						end
					end
					if entry.goal and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(entry.goal.X, 0, entry.goal.Z)).Magnitude < 2 then
						entry.goal = nil
					end
				end
				local velocity = root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if entry.goal and humanoid.WalkSpeed > 0 then
					if speed < 0.6 then
						entry.stuckTime += dt
						if entry.stuckTime > 0.8 then
							humanoid.Jump = true
							entry.stuckTime = 0
						end
					else
						entry.stuckTime = 0
					end
				end
				local state = humanoid:GetState()
				if state == Enum.HumanoidStateType.Jumping then
					playTrack(entry, "jump")
				elseif state == Enum.HumanoidStateType.Freefall then
					playTrack(entry, "fall")
				elseif state == Enum.HumanoidStateType.Climbing then
					playTrack(entry, "climb", math.clamp(math.abs(velocity.Y) / 8, 0.1, 2))
				elseif speed > 0.8 then
					playTrack(entry, "walk", math.clamp(speed / 14.5, 0.3, 1.6))
				else
					playTrack(entry, "idle")
				end
			end
		end
	end
end)

task.spawn(function()
	local desc = Instance.new("HumanoidDescription")
	local black = Color3.fromRGB(8, 8, 10)
	desc.HeadColor, desc.TorsoColor = black, black
	desc.LeftArmColor, desc.RightArmColor = black, black
	desc.LeftLegColor, desc.RightLegColor = black, black
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("shadow template failed: " .. tostring(model))
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Decal") or d:IsA("Clothing") or d:IsA("Accessory") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Color = black
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = humanoid end
	end
	local head = model:FindFirstChild("Head")
	if head then
		for _, x in ipairs({-0.22, 0.22}) do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Size = Vector3.new(0.14, 0.06, 0.05)
			eye.Material = Enum.Material.Neon
			eye.Color = Color3.fromRGB(235, 225, 215)
			eye.CanCollide, eye.CanQuery, eye.CanTouch, eye.CastShadow, eye.Massless = false, false, false, false, true
			eye.CFrame = head.CFrame * CFrame.new(x, 0.12, -head.Size.Z / 2 - 0.01)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = eye
			weld.Parent = eye
			eye.Parent = head
		end
	end
	model.Name = "GS_ShadowTemplate"
	model.Parent = ReplicatedStorage
end)

local hauntRemote = ReplicatedStorage:FindFirstChild("HauntEvent")
if not hauntRemote then
	hauntRemote = Instance.new("RemoteEvent")
	hauntRemote.Name = "HauntEvent"
	hauntRemote.Parent = ReplicatedStorage
end
local lastHaunt = {}
local HAUNT_LIMBS = {RightArm = true, LeftArm = true, RightLeg = true, LeftLeg = true, Head = true}
hauntRemote.OnServerEvent:Connect(function(player, kind, arg)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not character:GetAttribute("Lobotomized") then return end
	local now = os.clock()
	if now - (lastHaunt[player] or 0) < 0.6 then return end
	lastHaunt[player] = now
	if kind == "Hit" then
		if typeof(arg) ~= "string" or not HAUNT_LIMBS[arg] then return end
		local level = character:GetAttribute("Injury_" .. arg) or 0
		if level >= 3 then return end
		character:SetAttribute("LastDamageCause", "HAUNTED")
		character:SetAttribute("LastDamageTime", workspace:GetServerTimeNow())
		humanoid:TakeDamage(4 + (level + 1) * 3)
		if humanoid.Health <= 0 then
			character:SetAttribute("DeathCause", "HAUNTED")
			return
		end
		if level + 1 >= 3 and arg == "Head" then
			character:SetAttribute("DeathCause", "HAUNTED")
		end
		FallDamageController.Injure(character, arg, level + 1)
	elseif kind == "Eat" then
		if typeof(arg) ~= "Instance" then return end
		local folder = workspace:FindFirstChild("SeveredLimbs")
		if not folder or not arg:IsDescendantOf(folder) then return end
		local model = arg:IsA("Model") and arg or arg:FindFirstAncestorOfClass("Model")
		if not model or model.Parent ~= folder then return end
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("BasePart") and d:GetAttribute("SeveredFrom") == character.Name then
				model:Destroy()
				return
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(player) lastHaunt[player] = nil end)
]=]},
	{name = "Animation", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- (GS: holding items and guns, carrying weight, bear traps and webs are handled here too:
--   GS_HoldPose / GS_Aim / GS_ReloadAt / GS_RecoilAt / GS_UseStart pose the arms, GS_CarrySpeed slows you by the weight
--   you carry, GS_Trapped holds you in place, GS_WebStun puts you down in the threads and you get up slowly as it runs out)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
end)

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ScreenEffects = require(Modules:WaitForChild("ScreenEffects"))
local LimbPose = require(Modules:WaitForChild("LimbPose"))

local event = ReplicatedStorage:WaitForChild("CharacterVisualSync")
local fallReport = ReplicatedStorage:WaitForChild("FallReport")
local remoteData = {}
local SEND_INTERVAL = 1 / 20
local sendTimer = 0

local FALL_RAGDOLL_SPEED = 65
local FALL_DAMAGE_MAX_SPEED = 160
local RAGDOLL_DURATION = 2.5
local LANDING_MIN_SPEED = 55

local ANIMATIONS = {
	idle = {
		id = "rbxassetid://91036027758402",
		priority = Enum.AnimationPriority.Idle,
		looped = true,
		speed = 1,
	},
	walk = {
		id = "rbxassetid://99045916736745",
		priority = Enum.AnimationPriority.Movement,
		looped = true,
		speed = 0.8,
	},
	jump = {
		id = "rbxassetid://74104429078784",
		priority = Enum.AnimationPriority.Action,
		looped = false,
		speed = 1,
	},

	climb = {
		id = "rbxassetid://180436334",
		priority = Enum.AnimationPriority.Movement,
		looped = true,
		speed = 1,
	},
}

local ANIM_FADE = 0.15
local MOVE_SPEED_THRESHOLD = 0.5
local BACKWARD_DOT_THRESHOLD = -0.3

local BODY_TURN_SMOOTH = 4
local HEAD_MAX_YAW = math.rad(80)
local HEAD_MAX_PITCH = math.rad(75)
local HEAD_SMOOTH = 4

local LIMB_SMOOTH = 10
local LEAN_SMOOTH = 6

local LEG_MAX_LIFT = math.rad(70)
local VOID_EXTRA = 0.35
local HERON_PITCH = math.rad(-30)
local HERON_ROLL = math.rad(-10)
local HERON_WEIGHT = 0.9
local SLOPE_ALIGN = 0.55
local SLOPE_MAX = math.rad(25)

local BALANCE_ROLL = math.rad(75)
local BALANCE_PITCH = math.rad(30)
local GUARD_DISTANCE = 2.0
local GUARD_IDLE_DISTANCE = 1.1
local GUARD_ROLL = math.rad(-42)
local GUARD_MIN_PITCH = math.rad(30)
local GUARD_MAX_PITCH = math.rad(105)
local SIDE_REACH = 1.9
local SIDE_PITCH = math.rad(12)
local LEDGE_REACH = 2.4
local LEDGE_MIN = -1.0
local LEDGE_MAX = 1.9
local LEDGE_HAND_SPREAD = 0.75
local FALL_SPREAD_SPEED = 22
local FALL_ARMS_ROLL = math.rad(78)
local FALL_ARMS_PITCH = math.rad(18)
local FLAIL_SPEED = 80

local STRAFE_ENABLED = false
local BODY_STRAFE_YAW = math.rad(45)
local LIMB_LIFT_SCALE = 0.8

local LEG_SPEED = {
	OneDamaged = 0.85,
	BothDamaged = 0.75,
	OneBroken = 0.6,
	BrokenAndDamaged = 0.5,
}
local LEG_JUMP = {
	OneDamaged = 0.85,
	BothDamaged = 0.7,
	OneBroken = 0.45,
	BrokenAndDamaged = 0.35,
}

local CRAWL_SPEED_MUL = 0.2
local PRONE_CAMERA_DROP = 2.2
local CRAWL_STRIDE = 1.6
local CRAWL_TURN_RATE = math.rad(110)

local GETUP_TIME = 1.1
local SPAWN_GETUP_TIME = 3.2

local STRAFE_ENTER = 0.5
local STRAFE_EXIT = 0.3
local STRAFE_ROLL = math.rad(24)
local STRAFE_SWING = math.rad(26)
local STRAFE_LIFT = math.rad(18)
local STRAFE_CROSS_FORWARD = 0.9
local STRAFE_STRIDE = 6.5
local STRAFE_MIN_HZ = 0.9
local STRAFE_MAX_HZ = 2.1
local STRAFE_LEAN = 0.05
local STRAFE_ARM_ROLL = math.rad(9)
local STRAFE_ARM_ROLL_SWING = math.rad(12)
local STRAFE_ARM_PITCH_SWING = math.rad(18)

local CROUCH_KEYS = {
	[Enum.KeyCode.LeftControl] = true,
	[Enum.KeyCode.RightControl] = true,
	[Enum.KeyCode.C] = true,
}
local CROUCH_TOGGLE = false
local CROUCH_SPEED_MUL = 0.45
local CROUCH_CAMERA_DROP = 1.3
local CROUCH_STRIDE = 3.2

local CLIMB_ANIM_SCALE = 5
local CLIMB_ARM_BASE = math.rad(148)
local CLIMB_ARM_SWING = math.rad(22)
local CLIMB_LEG_BASE = math.rad(8)
local CLIMB_LEG_LIFT = math.rad(40)
local CLIMB_STRIDE = 1.6
local CLIMB_TURN_SPEED = 14
local CLIMB_RELEASE_GRACE = 0.35

local ICE_SLIDE_ENABLED = true
local SURFACE_DEFAULT = {speed = 1, anim = 1, slide = 0, balance = 0, lift = 0, lean = 0, wobble = 0}
local SURFACES = {}
local function surface(materials, profile)
	for key, value in pairs(SURFACE_DEFAULT) do
		if profile[key] == nil then profile[key] = value end
	end
	for _, material in ipairs(materials) do
		SURFACES[material] = profile
	end
end
surface({Enum.Material.Ice, Enum.Material.Glacier},
{speed = 1.05, anim = 0.9, slide = 0.85, balance = math.rad(20), wobble = 0.6})
surface({Enum.Material.Sand}, {speed = 0.82, anim = 0.85, lift = math.rad(9), lean = 0.05})
surface({Enum.Material.Snow}, {speed = 0.8, anim = 0.82, lift = math.rad(12), lean = 0.06})
surface({Enum.Material.Mud}, {speed = 0.7, anim = 0.72, lift = math.rad(14), lean = 0.08, wobble = 0.2})
surface({Enum.Material.Ground}, {speed = 0.93, anim = 0.93, lift = math.rad(4)})
surface({Enum.Material.Grass, Enum.Material.LeafyGrass}, {speed = 0.97, anim = 0.97, lift = math.rad(3)})
surface({Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.Pebble,
	Enum.Material.CrackedLava, Enum.Material.Cobblestone, Enum.Material.Limestone,
	Enum.Material.Sandstone, Enum.Material.Salt},
{speed = 0.95, anim = 0.95, wobble = 0.3})
surface({Enum.Material.Metal, Enum.Material.DiamondPlate, Enum.Material.CorrodedMetal},
{speed = 1, anim = 1.05})
do
	local soft = {Enum.Material.Fabric}
	local ok, carpet = pcall(function() return Enum.Material.Carpet end)
	if ok and carpet then table.insert(soft, carpet) end
	surface(soft, {speed = 0.96, anim = 0.95})
end

local SHIFT_LOCK_KEY = Enum.KeyCode.LeftShift
local SHOULDER_OFFSET = Vector3.new(1.75, 0.25, 0)
local CAMERA_OFFSET_SMOOTH = 8
local CURSOR_SIZE = 16
local SHIFT_LOCK_SENSITIVITY = 0.45
local SHIFT_LOCK_PITCH_LIMIT = math.rad(55)

local ShiftLockEnabled = false
local currentHumanoid = nil
local crouchHeld = false

local function approach(current, target, dt, speed)
	return current + (target - current) * math.min(dt * speed, 1)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Ctrl / C on keyboard, B on gamepad, a CRAWL toggle button on touch screens
local ContextActionService = game:GetService("ContextActionService")
local crouchKeys = {Enum.KeyCode.ButtonB}
for key in pairs(CROUCH_KEYS) do table.insert(crouchKeys, key) end
ContextActionService:BindAction("GS_Crawl", function(_, state, input)
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	local touch = input.UserInputType == Enum.UserInputType.Touch
	if state == Enum.UserInputState.Begin then
		if CROUCH_TOGGLE or touch then
			crouchHeld = not crouchHeld
		else
			crouchHeld = true
		end
	elseif state == Enum.UserInputState.End and not CROUCH_TOGGLE and not touch then
		crouchHeld = false
	end
	return Enum.ContextActionResult.Sink
end, false, table.unpack(crouchKeys))
-- phones: the HUD's own CRAWL button (Controls script) toggles it through this event
task.spawn(function()
	local action = player:WaitForChild("GS_ClientAction", 30)
	if not action then return end
	action.Event:Connect(function(kind)
		if kind == "crawl" then crouchHeld = not crouchHeld end
	end)
end)

local function CreateUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShiftLockUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 2147483647
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local reticle = Instance.new("Frame")
	reticle.Name = "Reticle"
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Position = UDim2.new(0.5, 0, 0.5, 0)
	reticle.Size = UDim2.fromOffset(22, 22)
	reticle.BackgroundTransparency = 1
	reticle.ZIndex = 2147483647
	reticle.Visible = false
	reticle.Parent = screenGui
	for _, spec in ipairs({
		{UDim2.fromScale(0.5, 0), UDim2.fromOffset(2, 6), Vector2.new(0.5, 0)},
		{UDim2.fromScale(0.5, 1), UDim2.fromOffset(2, 6), Vector2.new(0.5, 1)},
		{UDim2.fromScale(0, 0.5), UDim2.fromOffset(6, 2), Vector2.new(0, 0.5)},
		{UDim2.fromScale(1, 0.5), UDim2.fromOffset(6, 2), Vector2.new(1, 0.5)},
		}) do
		local line = Instance.new("Frame")
		line.Position = spec[1]
		line.Size = spec[2]
		line.AnchorPoint = spec[3]
		line.BackgroundColor3 = Color3.fromRGB(225, 220, 215)
		line.BackgroundTransparency = 0.25
		line.BorderSizePixel = 0
		line.ZIndex = 2147483647
		line.Parent = reticle
	end
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(3, 3)
	dot.BackgroundColor3 = Color3.fromRGB(200, 20, 20)
	dot.BorderSizePixel = 0
	dot.ZIndex = 2147483647
	dot.Parent = reticle

	local cursor = Instance.new("Frame")
	cursor.Name = "Cursor"
	cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	cursor.Size = UDim2.fromOffset(CURSOR_SIZE, CURSOR_SIZE)
	cursor.BackgroundTransparency = 1
	cursor.ZIndex = 2147483647
	cursor.Parent = screenGui
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = cursor
	local ring = Instance.new("UIStroke")
	ring.Thickness = 1.5
	ring.Color = Color3.fromRGB(230, 225, 220)
	ring.Transparency = 0.15
	ring.Parent = cursor
	local center = Instance.new("Frame")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(4, 4)
	center.BackgroundColor3 = Color3.fromRGB(190, 15, 15)
	center.BorderSizePixel = 0
	center.ZIndex = 2147483647
	center.Parent = cursor
	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = UDim.new(1, 0)
	centerCorner.Parent = center

	return reticle, cursor
end

local reticle, cursor = CreateUI()

UserInputService.MouseIconEnabled = false

local function UpdateShiftLockState()
	UserInputService.MouseDeltaSensitivity = ShiftLockEnabled and SHIFT_LOCK_SENSITIVITY or 1
	if ShiftLockEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		reticle.Visible = true
		cursor.Visible = false
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		reticle.Visible = false
		cursor.Visible = true
	end
end

local function DesiredAutoRotate(character)
	return not ShiftLockEnabled
		and not character:GetAttribute("FirstPersonCameraActive")
		and not character:GetAttribute("Ragdolled")
		and not character:GetAttribute("Climbing")
end

local function SetShiftLock(enabled)
	ShiftLockEnabled = enabled
	player:SetAttribute("GS_ShiftLock", enabled or nil)
	if currentHumanoid and currentHumanoid.Parent then
		local character = currentHumanoid.Parent
		if not character:GetAttribute("Ragdolled")
			and not character:GetAttribute("FirstPersonCameraActive")
			and not character:GetAttribute("Climbing") then
			currentHumanoid.AutoRotate = not enabled
		end
	end
	UpdateShiftLockState()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == SHIFT_LOCK_KEY then
		SetShiftLock(not ShiftLockEnabled)
	end
end)

local uiWasOpen = false
RunService.RenderStepped:Connect(function()
	if UserInputService.MouseIconEnabled then UserInputService.MouseIconEnabled = false end
	local uiOpen = player:GetAttribute("UIOpen") == true
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		-- phones and tablets: no fake mouse cursor
		cursor.Visible = false
	elseif not ShiftLockEnabled or uiOpen then
		local pos = UserInputService:GetMouseLocation()
		cursor.Position = UDim2.new(0, pos.X, 0, pos.Y)
	end
	if ShiftLockEnabled then
		cursor.Visible = uiOpen
		reticle.Visible = not uiOpen
		if uiWasOpen and not uiOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end
	-- a gun in the hand: its own spread circle takes over from the cursor and the dot
	if player:GetAttribute("GS_Crosshair") and not uiOpen then
		cursor.Visible = false
		reticle.Visible = false
	elseif not ShiftLockEnabled and not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		cursor.Visible = true
	end
	uiWasOpen = uiOpen
end)

UpdateShiftLockState()

RunService:BindToRenderStep("PlayerSystem_ShiftLockClamp", Enum.RenderPriority.Camera.Value + 2, function()
	if not ShiftLockEnabled or not currentHumanoid or not currentHumanoid.Parent then return end
	if currentHumanoid.Parent:GetAttribute("FirstPersonCameraActive") then return end
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Custom then return end
	local look = cam.CFrame.LookVector
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	if math.abs(pitch) <= SHIFT_LOCK_PITCH_LIMIT then return end
	local focus = cam.Focus.Position
	local distance = (cam.CFrame.Position - focus).Magnitude
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then return end
	flat = flat.Unit
	local clamped = math.clamp(pitch, -SHIFT_LOCK_PITCH_LIMIT, SHIFT_LOCK_PITCH_LIMIT)
	local newLook = flat * math.cos(clamped) + Vector3.new(0, math.sin(clamped), 0)
	local position = focus - newLook * distance
	cam.CFrame = CFrame.lookAt(position, position + newLook)
end)

local function LoadTrack(animator, config)
	if not config or config.id == "" then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = config.id
	local track = animator:LoadAnimation(anim)
	track.Priority = config.priority
	track.Looped = config.looped
	return track
end

local function NewParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

local REMOTE_CLIP_DISTANCE = 80
local MODE_INDEX = 21
local CROUCH_INDEX = 22

local function SetupRemoteCharacter(plr, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end
	local rig = LimbPose.CreateRig(character)
	if not rig then return end
	character:GetAttributeChangedSignal("RigVersion"):Connect(function()
		task.wait(0.1)
		LimbPose.RefreshRig(rig)
	end)
	local params = NewParams(character)

	local entry = {target = nil, current = table.create(LimbPose.FIELD_COUNT, 0), wasPosed = false}
	remoteData[plr] = entry

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not character.Parent then
			connection:Disconnect()
			if remoteData[plr] == entry then remoteData[plr] = nil end
			return
		end
		if character:GetAttribute("Ragdolled") or humanoid.Health <= 0 then
			if entry.wasPosed then
				entry.wasPosed = false
				LimbPose.Reset(rig)
				entry.current = table.create(LimbPose.FIELD_COUNT, 0)
			end
			return
		end
		local target = entry.target
		if not target then return end
		entry.wasPosed = true

		local cur = entry.current
		local alpha = math.min(dt * LIMB_SMOOTH, 1)
		for i = 1, LimbPose.FIELD_COUNT do
			cur[i] += (target[i] - cur[i]) * alpha
		end
		cur[MODE_INDEX] = target[MODE_INDEX]

		LimbPose.ApplyNeck(rig, cur[1], cur[2])
		LimbPose.ApplyLean(rig, cur[3], cur[4], cur[CROUCH_INDEX], cur[23], cur[24])
		LimbPose.Assign(rig, cur)

		local near = camera and (camera.CFrame.Position - rig.torso.Position).Magnitude < REMOTE_CLIP_DISTANCE
		LimbPose.Apply(rig, {
			antiClip = near and cur[MODE_INDEX] == 0,
			params = params,
		})
	end)
end

event.OnClientEvent:Connect(function(plr, packet)
	local entry = remoteData[plr]
	if entry then
		local values = LimbPose.Unpack(packet)
		if values then
			entry.target = values
		end
	end
end)

local function SetupCharacter(character, opts)
	opts = opts or {}
	local puppet = opts.puppet == true
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end

	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end

	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	local torso = character:WaitForChild("Torso", 10)
	local headPart = character:WaitForChild("Head", 10)
	if not rootPart or not torso or not headPart then return end

	local defaultAnimate = character:FindFirstChild("Animate")
	if defaultAnimate then
		defaultAnimate.Disabled = true
	end

	local animator = humanoid:WaitForChild("Animator", 10)
	if not animator then
		if not puppet then return end
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local rig = LimbPose.CreateRig(character)
	if not rig then return end
	local limbs = rig.limbs
	character:GetAttributeChangedSignal("RigVersion"):Connect(function()
		task.wait(0.1)
		LimbPose.RefreshRig(rig)
	end)
	local ARMS = {"rightArm", "leftArm"}
	local LEGS = {"rightLeg", "leftLeg"}

	local moveTracks = {}
	for name, config in pairs(ANIMATIONS) do

		for _ = 1, 4 do
			local ok, track = pcall(LoadTrack, animator, config)
			if ok and track then
				moveTracks[name] = track
				break
			end
			task.wait(0.5)
		end
	end

	if moveTracks.idle then
		moveTracks.idle:Play(0, 1, ANIMATIONS.idle.speed)
	end

	local currentState = "idle"

	local function SetMoveState(newState)
		if newState == currentState then
			return
		end
		local oldTrack = moveTracks[currentState]
		local newTrack = moveTracks[newState]
		local newConfig = ANIMATIONS[newState]
		if oldTrack then
			oldTrack:Stop(ANIM_FADE)
		end
		if newTrack then
			newTrack:Play(ANIM_FADE, 1, newConfig and newConfig.speed or 1)
		end
		currentState = newState
	end

	if not puppet then
		currentHumanoid = humanoid
		if DesiredAutoRotate(character) then humanoid.AutoRotate = true end
		humanoid.CameraOffset = Vector3.zero
	end
	local isRagdolled = false
	local flightEffectActive = false
	local params = NewParams(character)

	local baseWalkSpeed = humanoid.WalkSpeed
	local baseJumpPower = humanoid.JumpPower
	local baseJumpHeight = humanoid.JumpHeight
	local lastJumpScale = 1
	local writtenWalkSpeed = nil
	local walkSpeedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if writtenWalkSpeed == nil or math.abs(humanoid.WalkSpeed - writtenWalkSpeed) > 1e-3 then
			baseWalkSpeed = humanoid.WalkSpeed
			writtenWalkSpeed = nil
		end
	end)

	local function stopFlightEffect()
		if flightEffectActive then
			flightEffectActive = false
			ScreenEffects.ResetFlightEffect()
		end
	end

	local neckYaw, neckPitch = 0, 0
	local leanForward, leanRight = 0, 0
	local bodyYaw = 0
	local strafeAmount, strafePhase = 0, 0
	local strafing, strafeSide = false, 1
	local crouchAmount, crouchPhase = 0, 0
	local proneAmount, crawlPhase = 0, 0
	local wriggleActive = false
	local torsoSlick, torsoProps = false, nil
	local crawlSteering = false
	local getUpStart = opts.noGetUp and -math.huge or os.clock()
	local getUpDuration = SPAWN_GETUP_TIME
	local spawnGetUp = true
	local jumpEnabled = true
	local climbPhase = 0
	local climbing = false
	local climbYaw = nil
	local climbReleasedAt = -math.huge
	local surfaceState = table.clone(SURFACE_DEFAULT)
	local airMinVelocity = 0
	local wasAirborne = false
	local slideVelocity = nil
	local lastWrittenSlide = nil
	local grounded = true
	local balanceWobble = 0

	local function resetPose()
		LimbPose.Reset(rig)
		neckYaw, neckPitch, leanForward, leanRight = 0, 0, 0, 0
		bodyYaw = 0
		strafeAmount, strafing, crouchAmount = 0, false, 0
	end

	local function syncRagdoll()
		local enabled = character:GetAttribute("Ragdolled") == true
		if enabled == isRagdolled then return end
		isRagdolled = enabled
		if enabled then
			stopFlightEffect()
			for _, track in pairs(moveTracks) do track:Stop(0.1) end
			currentState = ""
			resetPose()
			slideVelocity = nil
			wasAirborne, airMinVelocity = false, 0
			if puppet then return end
			humanoid.AutoRotate = false
			humanoid.PlatformStand = true
			if humanoid.Health > 0 then
				local duration = character:GetAttribute("RagdollDuration") or RAGDOLL_DURATION
				ScreenEffects.Knockout(duration, character:GetAttribute("RagdollSeverity") or 0.6)

				player:SetAttribute("AdrenalineUntil", workspace:GetServerTimeNow() + duration + 8)
			end
		else
			getUpStart = os.clock()
			getUpDuration = GETUP_TIME
			spawnGetUp = false
			if puppet then return end
			humanoid.PlatformStand = false
			if humanoid.Health > 0 then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
			if DesiredAutoRotate(character) then
				humanoid.AutoRotate = true
			end
		end
	end
	local ragdollConnection = character:GetAttributeChangedSignal("Ragdolled"):Connect(syncRagdoll)
	syncRagdoll()

	local function FindLadderYaw()
		local look = rootPart.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then return nil end
		local hit = workspace:Raycast(rootPart.Position, flat.Unit * 3, params)
		if hit and math.abs(hit.Normal.Y) < 0.5 then
			return math.atan2(hit.Normal.X, hit.Normal.Z)
		end
		return nil
	end

	local function setClimbing(value)
		if value == climbing then return end
		climbing = value
		if puppet then
			climbYaw = value and (FindLadderYaw() or select(2, rootPart.CFrame:ToOrientation())) or nil
			return
		end
		character:SetAttribute("Climbing", value)
		if value then
			humanoid.AutoRotate = false
			climbYaw = FindLadderYaw() or select(2, rootPart.CFrame:ToOrientation())
		else
			climbYaw = nil
			climbReleasedAt = os.clock()
			if not isRagdolled and DesiredAutoRotate(character) then
				humanoid.AutoRotate = true
			end
		end
	end

	local slideConnection = RunService.Heartbeat:Connect(function(dt)
		if puppet or not ICE_SLIDE_ENABLED or isRagdolled or climbing or not grounded or surfaceState.slide < 0.05 then
			slideVelocity, lastWrittenSlide = nil, nil
			return
		end
		local v = rootPart.AssemblyLinearVelocity
		local horizontal = Vector3.new(v.X, 0, v.Z)
		if not slideVelocity then
			slideVelocity = horizontal
		end
		if lastWrittenSlide and (horizontal - lastWrittenSlide).Magnitude > 10 then
			slideVelocity = horizontal
		end
		local desired = humanoid.MoveDirection * humanoid.WalkSpeed
		local accel = lerp(40, 2.2, surfaceState.slide)
		slideVelocity = slideVelocity:Lerp(desired, 1 - math.exp(-accel * dt))
		rootPart.AssemblyLinearVelocity = Vector3.new(slideVelocity.X, v.Y, slideVelocity.Z)
		lastWrittenSlide = slideVelocity
	end)

	local fallTracking = false
	local fallStartY = rootPart.Position.Y
	local fallLastGroundY = rootPart.Position.Y
	local fallMaxSpeed = 0
	local fallConnection = RunService.Heartbeat:Connect(function()
		if puppet then return end
		local state = humanoid:GetState()
		local y = rootPart.Position.Y
		if isRagdolled or humanoid.Health <= 0 or humanoid.Sit
			or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then
			fallTracking, fallMaxSpeed, fallLastGroundY = false, 0, y
			return
		end
		local vy = rootPart.AssemblyLinearVelocity.Y
		local inAir = humanoid.FloorMaterial == Enum.Material.Air
			or state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
		if inAir then
			if not fallTracking then
				fallTracking = true
				fallStartY = fallLastGroundY
				fallMaxSpeed = 0
			end
			fallMaxSpeed = math.max(fallMaxSpeed, -vy)
			return
		end
		fallLastGroundY = y
		if fallTracking then
			fallTracking = false
			local height = fallStartY - y
			if height >= 4 then
				fallReport:FireServer(height, fallMaxSpeed)
			end
			fallMaxSpeed = 0
		end
	end)

	local LIMB_KEYS = {"LeftArm", "RightArm", "LeftLeg", "RightLeg"}
	local lastGroundedAt = os.clock()
	local jumpStartedAt = -math.huge
	local function limbTrouble()
		for _, key in ipairs(LIMB_KEYS) do
			if (character:GetAttribute("Injury_" .. key) or 0) >= 2 then return true end
		end
		return false
	end
	local function groundBelow()
		local leg = character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
		local reach = rootPart.Size.Y * 0.5 + humanoid.HipHeight + (leg and leg.Size.Y or 2) + 1.2
		return workspace:Raycast(rootPart.Position, Vector3.new(0, -reach, 0), params) ~= nil
	end
	local jumpGuardConnection = humanoid.StateChanged:Connect(function(_, new)
		if puppet then return end
		if new == Enum.HumanoidStateType.Jumping then

			if os.clock() - lastGroundedAt > 0.2 and not groundBelow() then
				local v = rootPart.AssemblyLinearVelocity
				rootPart.AssemblyLinearVelocity = Vector3.new(v.X, math.min(v.Y, 0), v.Z)
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			else
				jumpStartedAt = os.clock()
				if limbTrouble() then

					local v = rootPart.AssemblyLinearVelocity
					local jumpV = math.sqrt(2 * workspace.Gravity * math.max(humanoid.JumpHeight, 0))
					rootPart.AssemblyLinearVelocity = Vector3.new(v.X, jumpV, v.Z)
					humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
				end
			end
		end
	end)
	local stabilizeConnection = RunService.Heartbeat:Connect(function()
		if puppet or isRagdolled or humanoid.Health <= 0 then return end
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed
			or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then
			lastGroundedAt = os.clock()
		end
		if state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then return end
		if not limbTrouble() then return end
		local v = rootPart.AssemblyLinearVelocity
		local jumpV = math.sqrt(2 * workspace.Gravity * math.max(humanoid.JumpHeight, 1))
		local maxUp = jumpV * 1.05 + 1
		if os.clock() - jumpStartedAt > 0.45 then

			maxUp = 14
		end
		local vy = v.Y
		if vy > maxUp then vy = maxUp end
		if state == Enum.HumanoidStateType.Jumping and os.clock() - jumpStartedAt > 0.04 then

			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		local flat = Vector3.new(v.X, 0, v.Z)
		local maxFlat = math.max(humanoid.WalkSpeed, 4) + 7
		if proneAmount > 0.5 then

			maxFlat = humanoid.WalkSpeed * 1.25 + 0.75
		end
		if flat.Magnitude > maxFlat then flat = flat.Unit * maxFlat end
		if vy ~= v.Y or flat.X ~= v.X or flat.Z ~= v.Z then
			rootPart.AssemblyLinearVelocity = Vector3.new(flat.X, vy, flat.Z)
		end
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
			local w = rootPart.AssemblyAngularVelocity
			if w.Magnitude > 12 then rootPart.AssemblyAngularVelocity = w.Unit * 12 end
		end
	end)

	local function aimArm(joint, worldPoint)
		local v = torso.CFrame:PointToObjectSpace(worldPoint) - joint.base.Position
		if v.Magnitude < 1e-3 then return 0, 0 end
		local dir = v.Unit
		local roll = math.asin(math.clamp(dir.X, -1, 1))
		local pitch = math.atan2(-dir.Z, -dir.Y)
		return pitch, roll * joint.side
	end

	local function FindLedge(flatFacing)
		local shoulder = torso.CFrame:PointToWorldSpace(Vector3.new(0, 0.5, 0))
		local wall = workspace:Raycast(shoulder, flatFacing * LEDGE_REACH, params)
		if not wall or wall.Normal:Dot(flatFacing) > -0.5 then
			return nil, wall
		end
		local top = shoulder.Y + LEDGE_MAX + 0.3
		local origin = Vector3.new(wall.Position.X, top, wall.Position.Z) + flatFacing * 0.4
		local down = workspace:Raycast(origin, Vector3.new(0, -(LEDGE_MAX - LEDGE_MIN + 0.6), 0), params)
		if down and down.Normal.Y > 0.7 then
			local relative = down.Position.Y - shoulder.Y
			if relative >= LEDGE_MIN and relative <= LEDGE_MAX and relative < (LEDGE_MAX + 0.25) then
				return {point = down.Position, distance = wall.Distance}, wall
			end
		end
		return nil, wall
	end

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not character.Parent or humanoid.Health <= 0 then
			fallConnection:Disconnect()
			jumpGuardConnection:Disconnect()
			stabilizeConnection:Disconnect()
			stopFlightEffect()
			connection:Disconnect()
			ragdollConnection:Disconnect()
			walkSpeedConnection:Disconnect()
			slideConnection:Disconnect()
			for _, track in pairs(moveTracks) do track:Stop(0) end
			if character.Parent and not puppet then character:SetAttribute("Climbing", false) end
			if currentHumanoid == humanoid then
				currentHumanoid = nil
			end
			return
		end

		if not camera then return end
		if puppet and (camera.CFrame.Position - rootPart.Position).Magnitude > (opts.maxDistance or 160) then return end
		if isRagdolled then
			stopFlightEffect()
			setClimbing(false)
			return
		end

		local velocity = rootPart.AssemblyLinearVelocity
		local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		local horizontalSpeed = horizontalVelocity.Magnitude
		local isMoving = horizontalSpeed > MOVE_SPEED_THRESHOLD

		local humanoidState = humanoid:GetState()
		local isAirborne = humanoidState == Enum.HumanoidStateType.Jumping
			or humanoidState == Enum.HumanoidStateType.Freefall
		setClimbing(humanoidState == Enum.HumanoidStateType.Climbing)
		grounded = not isAirborne and not climbing and humanoid.FloorMaterial ~= Enum.Material.Air

		local injury = {
			rightArm = character:GetAttribute("Injury_RightArm") or 0,
			leftArm = character:GetAttribute("Injury_LeftArm") or 0,
			rightLeg = character:GetAttribute("Injury_RightLeg") or 0,
			leftLeg = character:GetAttribute("Injury_LeftLeg") or 0,
		}
		local legGone = injury.rightLeg >= 3 or injury.leftLeg >= 3
		local crawlForced = legGone or (injury.rightLeg >= 2 and injury.leftLeg >= 2)

		local proneVoluntary = not puppet and crouchHeld and not crawlForced and not climbing
		local crawling = crawlForced or proneVoluntary

		-- caught in a web: flat in the threads, then up on the knees, then standing, as the timer runs out
		-- (no ragdoll and no concussion any more)
		local serverTime = workspace:GetServerTimeNow()
		local webLeft = (character:GetAttribute("GS_WebStun") or 0) - serverTime
		local webStunned = webLeft > 0 and not climbing and humanoid.Health > 0
		local webP = 1
		if webStunned then
			webP = math.clamp(1 - webLeft / math.max(character:GetAttribute("GS_WebStunDur") or 5, 0.5), 0, 1)
		end
		local trapUntil = character:GetAttribute("GS_Trapped")
		local trapped = typeof(trapUntil) == "number" and trapUntil > serverTime

		local getUp = (os.clock() - getUpStart) / getUpDuration
		local gettingUp = getUp >= 0 and getUp < 1
		local proneTarget = (crawling and not climbing) and 1 or 0
		if webStunned then
			local webProne = webP < 0.35 and 1 or math.clamp(1 - (webP - 0.35) / 0.35, 0, 1)
			proneAmount = approach(proneAmount, math.max(webProne, crawlForced and 1 or 0), dt, webP < 0.35 and 6 or 3)
		elseif gettingUp and not crawlForced then
			proneAmount = math.clamp(1 - getUp / 0.4, 0, 1)
		else
			proneAmount = approach(proneAmount, proneTarget, dt, 4)
		end

		local slick = not puppet and proneAmount > 0.5
		if slick ~= torsoSlick then
			torsoSlick = slick
			if slick then
				torsoProps = torso.CustomPhysicalProperties
				torso.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 100, 100)
			else
				torso.CustomPhysicalProperties = torsoProps
			end
		end
		local wantJump = proneAmount < 0.5 and not gettingUp and not webStunned and not trapped
		if not puppet and wantJump ~= jumpEnabled then
			jumpEnabled = wantJump
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, wantJump)
		end

		-- monsters feeding, and infected players holding E over remains, hunch down over the meat
		local crouchWanted = (puppet and (character:GetAttribute("GS_EatUntil") or 0) > os.clock())
			or (character:GetAttribute("GS_EatServer") or 0) > workspace:GetServerTimeNow()
		local crouchTarget = (crouchWanted and grounded and not climbing and proneAmount < 0.5) and 1 or 0
		if gettingUp and not crawlForced then
			local getUpCrouch = getUp < 0.45 and 1 or math.clamp(1 - (getUp - 0.45) / 0.55, 0, 1)
			crouchAmount = math.max(approach(crouchAmount, crouchTarget, dt, 9), getUpCrouch)
		else
			crouchAmount = approach(crouchAmount, crouchTarget, dt, 9)
		end
		if webStunned and webP >= 0.35 and not crawlForced then
			-- on the knees for a moment, then straightening up
			crouchAmount = math.max(crouchAmount, webP < 0.6 and 1 or math.clamp(1 - (webP - 0.6) / 0.4, 0, 1))
		end

		local inFirstPerson = not puppet and character:GetAttribute("FirstPersonCameraActive") == true
		if not puppet then
			local targetOffset = ShiftLockEnabled and not inFirstPerson and SHOULDER_OFFSET or Vector3.zero
			if not inFirstPerson then
				targetOffset += Vector3.new(0, -CROUCH_CAMERA_DROP * crouchAmount * (1 - proneAmount) - PRONE_CAMERA_DROP * proneAmount, 0)
			end
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetOffset, math.min(dt * CAMERA_OFFSET_SMOOTH, 1))
		end

		local profile = SURFACES[humanoid.FloorMaterial] or SURFACE_DEFAULT
		if not grounded then profile = surfaceState end
		for key, value in pairs(profile) do
			surfaceState[key] = approach(surfaceState[key], value, dt, 5)
		end

		local legState = nil
		do
			local hi = math.max(injury.rightLeg, injury.leftLeg)
			local lo = math.min(injury.rightLeg, injury.leftLeg)
			if hi == 2 then
				legState = lo == 1 and "BrokenAndDamaged" or "OneBroken"
			elseif hi == 1 then
				legState = lo == 1 and "BothDamaged" or "OneDamaged"
			end
		end
		local injurySpeed = crawling and CRAWL_SPEED_MUL or (legState and LEG_SPEED[legState] or 1)
		if crawling then

			local pullers = (injury.rightArm < 2 and 1 or 0) + (injury.leftArm < 2 and 1 or 0)
			local pushers = (injury.rightLeg < 2 and 0.5 or 0) + (injury.leftLeg < 2 and 0.5 or 0)
			local power = pullers + pushers
			if power <= 0 then
				wriggleActive = true
				local surge = math.max(0, math.sin(os.clock() * 5.5))
				injurySpeed *= 0.12 + 0.28 * surge * surge
			else
				wriggleActive = false
				injurySpeed *= power >= 2 and 1 or (power >= 1 and 0.6 or 0.4)
			end

			local move = humanoid.MoveDirection
			local look = rootPart.CFrame.LookVector
			local flatMove, facing = Vector3.new(move.X, 0, move.Z), Vector3.new(look.X, 0, look.Z)
			if flatMove.Magnitude > 0.1 and facing.Magnitude > 1e-3 then
				local d = flatMove.Unit:Dot(facing.Unit)
				injurySpeed *= d > 0.3 and 1 or (d > -0.6 and 0.7 or 0.55)
			end
		else
			wriggleActive = false
		end
		local jumpScale = legState and LEG_JUMP[legState] or 1
		jumpScale *= math.clamp(character:GetAttribute("DebuffSpeed") or 1, 0.6, 1)
		if not puppet and math.abs(jumpScale - lastJumpScale) > 0.001 then
			lastJumpScale = jumpScale
			humanoid.JumpPower = baseJumpPower * math.sqrt(jumpScale)
			humanoid.JumpHeight = baseJumpHeight * jumpScale
		end
		if gettingUp then injurySpeed = math.min(injurySpeed, (spawnGetUp and getUp < 0.75) and 0 or 0.25) end
		injurySpeed *= character:GetAttribute("DebuffSpeed") or 1

		if grounded and not puppet then
			-- threads from a web still clinging after you get up: slowed until they fall off
			local webbed = (character:GetAttribute("GS_Webbed") or 0) > serverTime
			-- the heavier the load (armor, guns), the slower; a trap or a web holds you in place; aiming is a slow walk
			local carry = math.clamp(tonumber(character:GetAttribute("GS_CarrySpeed")) or 1, 0.4, 1.3)
			local held = (trapped or webStunned) and 0 or 1
			local aimWalk = character:GetAttribute("GS_Aim") and 0.6 or 1
			local want = baseWalkSpeed * surfaceState.speed * lerp(1, CROUCH_SPEED_MUL, crouchAmount) * injurySpeed * (webbed and 0.4 or 1)
				* carry * held * aimWalk
			if math.abs(humanoid.WalkSpeed - want) > 0.01 then
				writtenWalkSpeed = want
				humanoid.WalkSpeed = want
			end
		end

		if isAirborne then
			wasAirborne = true
			airMinVelocity = math.min(airMinVelocity, velocity.Y)
		elseif wasAirborne then
			wasAirborne = false
			local impact = -airMinVelocity
			airMinVelocity = 0
			if impact >= LANDING_MIN_SPEED and not puppet then
				ScreenEffects.Landing(math.clamp((impact - 40) / 110, 0.05, 1))
			end
		end

		local facing = rootPart.CFrame.LookVector
		local flatFacing = Vector3.new(facing.X, 0, facing.Z)
		flatFacing = flatFacing.Magnitude > 1e-3 and flatFacing.Unit or Vector3.new(0, 0, -1)
		local rightVector = rootPart.CFrame.RightVector
		local moveDir = isMoving and horizontalVelocity.Unit or Vector3.zero
		local forwardDot = moveDir:Dot(flatFacing)
		local sideDot = moveDir:Dot(rightVector)

		local sideAbs = math.abs(sideDot)
		if STRAFE_ENABLED and isMoving and grounded and not climbing and crouchAmount < 0.5 then
			if strafing then
				strafing = sideAbs > STRAFE_EXIT
			else
				strafing = sideAbs > STRAFE_ENTER
			end
		else
			strafing = false
		end
		strafeAmount = approach(strafeAmount, strafing and 1 or 0, dt, 10)
		if strafing and sideAbs > 0.2 then
			strafeSide = sideDot >= 0 and 1 or -1
		end

		local climbTrack = moveTracks.climb
		local climbTrackOK = climbTrack ~= nil and climbTrack.Length > 0
		if climbing then
			SetMoveState("climb")
			if climbTrack then
				local speed = math.clamp(velocity.Y / CLIMB_ANIM_SCALE, -2.5, 2.5)
				climbTrack:AdjustSpeed(math.abs(speed) < 0.05 and 0 or speed)
			end
		elseif isAirborne and moveTracks.jump then
			SetMoveState("jump")
		elseif proneAmount > 0.3 then
			SetMoveState("crawl")
		elseif crouchAmount > 0.5 then
			SetMoveState("crouch")
		elseif isMoving and strafing then
			SetMoveState("strafe")
		elseif isMoving then
			SetMoveState("walk")
			if moveTracks.walk then
				local baseSpeed = ANIMATIONS.walk.speed * surfaceState.anim
				local speed = (forwardDot < BACKWARD_DOT_THRESHOLD) and -baseSpeed or baseSpeed
				moveTracks.walk:AdjustSpeed(speed)
			end
		else
			SetMoveState("idle")
		end

		local fallSpeed = math.max(0, -velocity.Y)
		local falling = humanoidState == Enum.HumanoidStateType.Freefall
		if falling and fallSpeed >= FALL_RAGDOLL_SPEED and not puppet then
			flightEffectActive = true
			ScreenEffects.FlightEffect(fallSpeed, FALL_RAGDOLL_SPEED, FALL_DAMAGE_MAX_SPEED, inFirstPerson)
		else
			stopFlightEffect()
		end

		local camLook = camera.CFrame.LookVector
		if puppet then
			local target = opts.lookTarget and opts.lookTarget(character)
			if target then
				local d = target - headPart.Position
				camLook = d.Magnitude > 0.01 and d.Unit or rootPart.CFrame.LookVector
			else
				camLook = rootPart.CFrame.LookVector
			end
		end
		local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
		local currentYaw = select(2, rootPart.CFrame:ToOrientation())
		local targetBodyYaw = currentYaw
		if flatLook.Magnitude > 0.001 then
			flatLook = flatLook.Unit
			targetBodyYaw = math.atan2(-flatLook.X, -flatLook.Z)
		end
		local yawDiff = math.atan2(math.sin(targetBodyYaw - currentYaw), math.cos(targetBodyYaw - currentYaw))

		if crawlSteering and (puppet or proneAmount <= 0.5 or climbing) then
			crawlSteering = false
			if not puppet and not climbing and DesiredAutoRotate(character) then humanoid.AutoRotate = true end
		end
		if climbing and puppet then
			climbYaw = FindLadderYaw() or climbYaw
		elseif climbing then

			humanoid.AutoRotate = false
			local ladderYaw = FindLadderYaw()
			if ladderYaw then climbYaw = ladderYaw end
			if climbYaw then
				local diff = math.atan2(math.sin(climbYaw - currentYaw), math.cos(climbYaw - currentYaw))
				if math.abs(diff) > 1e-3 then
					local newYaw = currentYaw + diff * math.min(dt * CLIMB_TURN_SPEED, 1)
					rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, newYaw, 0)
				end
			end
		elseif not puppet and proneAmount > 0.5 and not webStunned then

			crawlSteering = true
			humanoid.AutoRotate = false
			local desiredYaw = nil
			if ShiftLockEnabled or inFirstPerson then
				desiredYaw = targetBodyYaw
			else
				local move = humanoid.MoveDirection
				local flatMove = Vector3.new(move.X, 0, move.Z)
				if flatMove.Magnitude > 0.1 then
					flatMove = flatMove.Unit
					local look = rootPart.CFrame.LookVector
					local facing = Vector3.new(look.X, 0, look.Z)
					facing = facing.Magnitude > 1e-3 and facing.Unit or flatMove

					local camFlat = Vector3.new(camLook.X, 0, camLook.Z)
					local backward = facing:Dot(flatMove) < -0.6 and camFlat.Magnitude > 1e-3 and facing:Dot(camFlat.Unit) > 0.3
					if not backward then
						desiredYaw = math.atan2(-flatMove.X, -flatMove.Z)
					end
				end
			end
			if desiredYaw then
				local diff = math.atan2(math.sin(desiredYaw - currentYaw), math.cos(desiredYaw - currentYaw))
				local step = math.clamp(diff, -CRAWL_TURN_RATE * dt, CRAWL_TURN_RATE * dt)
				if math.abs(step) > 1e-4 then
					rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, currentYaw + step, 0)
				end
			end
		elseif not puppet and ShiftLockEnabled and not inFirstPerson and os.clock() - climbReleasedAt > CLIMB_RELEASE_GRACE then
			local newYaw = currentYaw + yawDiff * math.min(dt * BODY_TURN_SMOOTH, 1)
			rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, newYaw, 0)
		end

		-- the head follows where you look in first person too (everyone else sees it turn and nod)
		do
			local targetNeckYaw = math.clamp(yawDiff, -HEAD_MAX_YAW, HEAD_MAX_YAW)
			local targetNeckPitch = -math.asin(math.clamp(camLook.Y, -1, 1))
			targetNeckPitch = math.clamp(targetNeckPitch, -HEAD_MAX_PITCH, HEAD_MAX_PITCH)
			neckYaw = approach(neckYaw, targetNeckYaw, dt, HEAD_SMOOTH)
			neckPitch = approach(neckPitch, targetNeckPitch, dt, HEAD_SMOOTH)
		end

		local headPitch = neckPitch - proneAmount * 1.25
		do
			local targetYaw = 0
			if not puppet and not humanoid.AutoRotate and grounded and not climbing and proneAmount < 0.3 and horizontalSpeed > 2
				and not character:GetAttribute("Ragdolled") then
				local rel = rootPart.CFrame:VectorToObjectSpace(horizontalVelocity)
				local a = math.atan2(-rel.X, -rel.Z)
				if math.abs(a) > math.pi / 2 then
					a -= math.sign(a) * math.pi
				end
				targetYaw = math.clamp(a, -BODY_STRAFE_YAW, BODY_STRAFE_YAW) * math.clamp((horizontalSpeed - 2) / 4, 0, 1)
			end
			bodyYaw = approach(bodyYaw, targetYaw, dt, 7)
		end
		LimbPose.ApplyNeck(rig, (neckYaw - bodyYaw) * (1 - proneAmount * 0.5), headPitch)

		local targets = {}
		for name, joint in pairs(limbs) do
			targets[name] = {pitchAdd = 0, roll = 0, weight = 0, pitchAbs = 0}
			joint.skipClip = false
		end
		local targetLeanForward, targetLeanRight = 0, 0
		local t = os.clock()
		local hasTool = character:FindFirstChildOfClass("Tool") ~= nil
		local mode = 0

		local function armFree(name)
			return not (hasTool and name == "rightArm")
		end

		if climbing then
			mode = 1
			for _, joint in pairs(limbs) do joint.skipClip = true end
			if not climbTrackOK then

				climbPhase += dt * (velocity.Y / CLIMB_STRIDE) * math.pi
				local s = math.sin(climbPhase)
				for name, target in pairs(targets) do
					local joint = limbs[name]
					target.weight = 1
					if joint.isLeg then
						local lift = joint.side > 0 and math.max(0, -s) or math.max(0, s)
						target.pitchAbs = CLIMB_LEG_BASE + CLIMB_LEG_LIFT * lift
						target.roll = math.rad(4)
					else
						target.pitchAbs = CLIMB_ARM_BASE + CLIMB_ARM_SWING * s * joint.side
						target.roll = math.rad(8)
					end
				end
				targetLeanForward = 0.1
			end

		elseif not grounded then

			local downSpeed = -velocity.Y
			local spread = math.clamp((downSpeed - FALL_SPREAD_SPEED) / 30, 0, 1)
			local flail = math.clamp((downSpeed - FLAIL_SPEED) / 25, 0, 1)
			if spread > 0 then
				mode = 1
				for name, joint in pairs(limbs) do
					local target = targets[name]
					joint.skipClip = true
					local s = joint.side
					if joint.isLeg then
						local calmPitch = math.rad(10) + math.rad(8) * math.sin(t * 2 + s)
						local kickPitch = math.rad(38) * math.sin(t * 9 + (s > 0 and 0 or math.pi))
						target.weight = spread * 0.9
						target.pitchAbs = lerp(calmPitch, kickPitch, flail)
						target.roll = math.rad(8) + math.rad(10) * flail * (0.5 + 0.5 * math.sin(t * 7 + s))
					elseif armFree(name) then
						local calmPitch = FALL_ARMS_PITCH + math.noise(t * 3, s * 4.1) * math.rad(12)
						local calmRoll = FALL_ARMS_ROLL + math.noise(t * 3.3, s * 2.7) * math.rad(10)

						local flailPitch = math.rad(85) + math.rad(95) * math.sin(t * 11 + (s > 0 and 0 or 1.9))
						local flailRoll = math.rad(55) + math.rad(35) * math.sin(t * 8.5 + s * 1.3)
						target.weight = spread
						target.pitchAbs = lerp(calmPitch, flailPitch, flail)
						target.roll = lerp(calmRoll, flailRoll, flail)
					end
				end
				targetLeanForward = -0.12 * flail
				targetLeanRight = math.sin(t * 5) * 0.08 * flail
			end

		else
			local idleFactor = 1 - math.clamp(horizontalSpeed / 3, 0, 1)
			local balanceSide = nil
			local balanceAmount = 0

			if proneAmount > 0.01 then
				mode = 1
				local moving = math.clamp(horizontalSpeed / 1.5, 0, 1)
				crawlPhase += dt * 2 * math.pi * math.clamp(horizontalSpeed / CRAWL_STRIDE, 0, 1.4)
				local s = math.sin(crawlPhase)
				for name, joint in pairs(limbs) do
					local target = targets[name]
					joint.skipClip = true
					if joint.isLeg and proneVoluntary and injury[name] < 2 then

						target.weight = proneAmount
						target.pitchAbs = math.rad(4) + math.rad(12) * s * joint.side * moving
						target.roll = math.rad(8) + math.rad(4) * math.max(0, s * joint.side) * moving
					elseif joint.isLeg then

						local drag = math.sin(crawlPhase * 0.5 + joint.side * 1.6)
						target.weight = proneAmount
						target.pitchAbs = math.rad(2) + math.rad(2) * drag * moving
						target.roll = math.rad(6) + math.rad(2.5) * drag * moving
					elseif armFree(name) then

						target.weight = proneAmount
						target.pitchAbs = math.rad(158) + math.rad(24) * s * joint.side * moving
						target.roll = math.rad(20) - math.rad(6) * s * joint.side * moving
					end
				end
				targetLeanRight += 0.05 * s * moving * proneAmount
				if wriggleActive then

					targetLeanRight += 0.22 * math.sin(os.clock() * 5.5) * moving * proneAmount
				end
			end
			if webStunned then
				for i, name in ipairs(ARMS) do
					local joint = limbs[name]
					if injury[name] < 3 then
						local target = targets[name]
						target.weight = 1
						joint.skipClip = true
						if webP < 0.35 then
							-- tangled: the arms jerk against the threads
							target.pitchAbs = math.rad(135) + math.noise(t * 3, i * 2.3) * math.rad(40)
							target.roll = math.rad(22) + math.noise(t * 2.5, i * 5.1) * math.rad(22)
						else
							-- pushing up off the floor
							target.pitchAbs = lerp(math.rad(120), math.rad(10), math.clamp((webP - 0.35) / 0.5, 0, 1))
							target.roll = math.rad(12)
						end
					end
				end
				if webP < 0.35 then
					for i, name in ipairs(LEGS) do
						local joint = limbs[name]
						local target = targets[name]
						joint.skipClip = true
						target.weight = proneAmount
						target.pitchAbs = math.rad(4) + math.noise(t * 3.4, i * 7.7) * math.rad(16)
						target.roll = math.rad(8)
					end
				end
			end
			if gettingUp and not crawlForced then

				for _, name in ipairs(ARMS) do
					local joint = limbs[name]
					if armFree(name) then
						local target = targets[name]
						target.weight = 1
						target.pitchAbs = lerp(math.rad(120), math.rad(10), math.clamp(getUp / 0.8, 0, 1))
						target.roll = math.rad(12)
						joint.skipClip = true
					end
				end
			end

			if crouchAmount > 0.01 and proneAmount < 0.3 then
				mode = crouchAmount > 0.5 and 1 or mode
				local moving = math.clamp(horizontalSpeed / 3, 0, 1)
				crouchPhase += dt * 2 * math.pi * math.clamp(horizontalSpeed / CROUCH_STRIDE, 0, 1.8)
				local s = math.sin(crouchPhase)

				local swap = math.tanh(2.6 * s) / math.tanh(2.6)
				local c = math.cos(crouchPhase)
				for name, joint in pairs(limbs) do
					local target = targets[name]
					if joint.isLeg then

						local kneel = joint.side > 0 and math.rad(66) or math.rad(-58)

						local walk = math.rad(64) * swap * joint.side
						local lift = math.max(0, c * joint.side)
						target.weight = crouchAmount
						target.pitchAbs = lerp(kneel, walk, moving)
						target.roll = math.rad(5) + math.rad(7) * lift * moving
						joint.skipClip = true
					elseif armFree(name) then

						target.weight = crouchAmount * 0.85
						target.pitchAbs = math.rad(32) - math.rad(22) * swap * joint.side * moving
						target.roll = math.rad(5)
					end
				end
				targetLeanForward += (0.3 + 0.04 * math.abs(s) * moving) * crouchAmount
				targetLeanRight += 0.03 * swap * moving * crouchAmount
			end

			if idleFactor > 0.01 and crouchAmount < 0.5 and proneAmount < 0.3 then
				local info = {}
				local voidCount = 0
				for _, name in ipairs(LEGS) do
					local joint = limbs[name]
					local g, hit = LimbPose.GroundDistance(rig, joint, params, 1.5)
					local void = g > joint.length + VOID_EXTRA
					if void then voidCount += 1 end
					info[name] = {g = g, hit = hit, void = void}
				end
				for _, name in ipairs(LEGS) do
					local joint = limbs[name]
					local data = info[name]
					local target = targets[name]
					local L = joint.length
					if data.void and voidCount == 1 then

						target.weight = math.max(target.weight, HERON_WEIGHT * idleFactor)
						target.pitchAbs = HERON_PITCH
						target.roll = HERON_ROLL
						balanceSide = -joint.side
						balanceAmount = idleFactor
						targetLeanRight += -joint.side * 0.05 * idleFactor
					elseif data.void then

						target.pitchAdd += math.rad(10) * idleFactor
						target.roll += math.rad(6) * idleFactor
					elseif data.hit then

						local lift = 0
						if data.g < L - 0.06 then
							lift = math.min(math.acos(math.clamp(data.g / L, 0, 1)), LEG_MAX_LIFT)
						end
						local n = torso.CFrame:VectorToObjectSpace(data.hit.Normal)
						local alignPitch = math.clamp(math.atan2(n.Z, n.Y), -SLOPE_MAX, SLOPE_MAX)
						local alignRoll = math.clamp(math.asin(math.clamp(-n.X, -1, 1)), -SLOPE_MAX, SLOPE_MAX) * joint.side
						target.pitchAdd += (lift + alignPitch * SLOPE_ALIGN) * idleFactor
						target.roll += alignRoll * SLOPE_ALIGN * idleFactor
					end
				end
			end

			if isMoving and strafeAmount < 0.5 and crouchAmount < 0.5 then
				for _, name in ipairs(LEGS) do
					local joint = limbs[name]
					local animPitch = LimbPose.AnimPitch(joint)
					targets[name].pitchAdd += surfaceState.lift * math.clamp(animPitch / 0.45, 0, 1)
					if surfaceState.wobble > 0.01 then
						targets[name].roll += math.noise(t * 3, joint.side * 7.3) * math.rad(6) * surfaceState.wobble
					end
				end
				targetLeanForward += surfaceState.lean
				if surfaceState.wobble > 0.01 then
					targetLeanRight += math.noise(t * 1.7, 3.1) * 0.06 * surfaceState.wobble
				end
				local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -4.5, 0), params)
				if hit then
					local uphill = -hit.Normal:Dot(moveDir)
					targetLeanForward += math.clamp(uphill * 0.5, -0.1, 0.18)
				end
			end

			if strafeAmount > 0.01 then
				local hz = math.clamp(horizontalSpeed / STRAFE_STRIDE, STRAFE_MIN_HZ, STRAFE_MAX_HZ)
				strafePhase = (strafePhase + dt * 2 * math.pi * hz) % (2 * math.pi)
				local s = math.sin(strafePhase)
				local c = math.cos(strafePhase)
				local lateral = math.clamp(sideAbs, 0, 1)
				local forward = math.clamp(forwardDot, -1, 1)
				local amount = strafeAmount
				for _, name in ipairs(LEGS) do
					local joint = limbs[name]
					local target = targets[name]

					local roll = STRAFE_ROLL * lateral * s

					local lift = math.max(0, strafeSide * joint.side * c)

					local cross = math.max(0, -roll) * STRAFE_CROSS_FORWARD
					local swing = forward * STRAFE_SWING * s * joint.side
					target.weight = math.max(target.weight, amount)
					target.pitchAbs = swing + STRAFE_LIFT * lift * lateral + cross
					target.pitchAdd = 0
					target.roll = roll
				end
				for _, name in ipairs(ARMS) do
					local joint = limbs[name]
					if armFree(name) then
						local target = targets[name]

						target.weight = math.max(target.weight, amount)
						target.pitchAbs = STRAFE_ARM_PITCH_SWING * s * joint.side * (0.6 + 0.4 * lateral)
						- forward * STRAFE_SWING * 0.5 * s * joint.side
						target.roll = STRAFE_ARM_ROLL - STRAFE_ARM_ROLL_SWING * s * lateral
					end
				end
				targetLeanRight += (strafeSide * STRAFE_LEAN + 0.03 * math.sin(strafePhase * 2)) * lateral * amount
				targetLeanForward += forward * 0.04 * amount
			end

			local moveInput = humanoid.MoveDirection
			local towardWall = moveInput.Magnitude > 0.1 and moveInput.Unit:Dot(flatFacing) > 0.3
			local ledge, frontWall = FindLedge(flatFacing)
			local frontFacing = frontWall and frontWall.Normal:Dot(flatFacing) < -0.5
			local wallDistance = frontFacing and frontWall.Distance or math.huge
			local awayFromLedge = moveInput.Magnitude > 0.1 and moveInput.Unit:Dot(flatFacing) < -0.3

			for _, name in ipairs(ARMS) do
				local joint = limbs[name]
				if armFree(name) and crouchAmount < 0.5 and proneAmount < 0.3 and not gettingUp then
					local target = targets[name]
					local handled = false

					if ledge and not awayFromLedge and ledge.distance < LEDGE_REACH then
						local grip = ledge.point + rightVector * joint.side * LEDGE_HAND_SPREAD + Vector3.new(0, 0.12, 0)
						local pitch, roll = aimArm(joint, grip)
						target.weight = 1
						target.pitchAbs = pitch
						target.roll = roll
						joint.skipClip = true
						handled = true

					elseif frontFacing and wallDistance < GUARD_DISTANCE
						and (towardWall or wallDistance < GUARD_IDLE_DISTANCE) then
						local reach = joint.length * math.cos(math.abs(GUARD_ROLL))
						local room = wallDistance - LimbPose.HALF_DEPTH - 0.05
						local pitch = room >= reach and GUARD_MAX_PITCH
							or math.max(GUARD_MIN_PITCH, math.asin(math.clamp(room / reach, 0, 1)))
						target.weight = 1
						target.pitchAbs = pitch
						target.roll = GUARD_ROLL
						joint.skipClip = true
						handled = true
						if name == "rightArm" then targetLeanForward -= 0.03 end
					end

					if not handled then
						local dS = LimbPose.Probe(rig, joint, Vector3.new(joint.side, 0, 0), {0.3, joint.length * 0.6}, 2.3, params)
						if dS < SIDE_REACH then
							if dS > 0.55 then
								target.weight = isMoving and 0.8 or 1
								target.pitchAbs = SIDE_PITCH
								target.roll = math.asin(math.clamp((dS - 0.5) / joint.length, 0, 1))
								joint.skipClip = true
							else
								target.weight = 0.8
								target.pitchAbs = math.rad(4)
								target.roll = math.rad(-8)
							end
						end
					end

					if balanceSide == joint.side and balanceAmount > 0 then
						balanceWobble = math.noise(t * 4, 9.1)
						target.weight = math.max(target.weight, balanceAmount)
						target.pitchAbs = BALANCE_PITCH + math.rad(10) * balanceWobble
						target.roll = BALANCE_ROLL + math.rad(12) * balanceWobble
						joint.skipClip = true
					end

					if surfaceState.balance > 0.01 and not handled then
						local wobble = 1 + math.noise(t * 2.3, joint.side) * 0.4
						target.roll += surfaceState.balance * wobble * (isMoving and 1 or 0.5)
					end
				end
			end
		end

		local talkUntil = character:GetAttribute("TalkUntil")
		if talkUntil and os.clock() < talkUntil and not climbing and proneAmount < 0.3 then
			local fade = math.clamp((talkUntil - os.clock()) / 0.4, 0, 1)
			for i, name in ipairs(ARMS) do
				if injury[name] < 2 and not (hasTool and name == "rightArm") then
					local joint = limbs[name]
					local target = targets[name]
					local phase = t * (i == 1 and 5.1 or 4.3) + i * 1.7
					local active = i == 1 and 1 or (0.55 + 0.45 * math.sin(t * 0.9))
					target.weight = math.max(target.weight, 0.6 * fade * active)
					target.pitchAbs = math.rad(28) + math.rad(20) * math.sin(phase) + math.rad(8) * math.sin(phase * 2.3)
					target.roll = math.rad(6) + math.rad(7) * math.sin(phase * 0.7)
					joint.skipClip = false
				end
			end
		end

		if not climbing then
			local limpPhase = t * math.clamp(horizontalSpeed / 2.2, 2, 7)
			for _, name in ipairs(LEGS) do
				local joint = limbs[name]
				if injury[name] == 2 and proneAmount < 0.3 then
					local target = targets[name]
					joint.skipClip = true
					if not grounded then
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(8)
						target.roll = math.rad(3)
					elseif isMoving then
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(-8) + math.rad(3) * math.sin(limpPhase * 0.5)
						target.roll = math.rad(4)
						targetLeanRight += -joint.side * (0.07 + 0.04 * math.abs(math.sin(limpPhase)))
						targetLeanForward += 0.06
					else

						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(12)
						target.roll = math.rad(4)
						targetLeanRight += -joint.side * 0.07
					end
				end
			end
			for _, name in ipairs(ARMS) do
				local joint = limbs[name]
				if injury[name] == 2 and proneAmount < 0.3 then

					local target = targets[name]
					joint.skipClip = false
					target.weight = 1
					target.pitchAbs = math.rad(3) + math.rad(5) * math.sin(t * 2.3 + joint.side) * math.clamp(horizontalSpeed / 8, 0.2, 1)
					target.roll = math.rad(-3)
					target.pitchAdd = 0
				end
			end
		end

		if not climbing and proneAmount < 0.3 and not gettingUp then
			for name, target in pairs(targets) do
				if injury[name] ~= 2 then
					target.pitchAbs *= LIMB_LIFT_SCALE
					target.pitchAdd *= LIMB_LIFT_SCALE
				end
			end
		end

		if (puppet or character:GetAttribute("GS_AttackStart") or character:GetAttribute("GS_EatServer")) and not climbing then
			local now = os.clock()
			local attackStart = character:GetAttribute("GS_AttackStart")
			local eatUntil = puppet and character:GetAttribute("GS_EatUntil") or nil

			local attackServer = character:GetAttribute("GS_AttackServer")
			if attackServer then
				local local0 = now - (workspace:GetServerTimeNow() - attackServer)
				if not attackStart or local0 > attackStart then attackStart = local0 end
			end
			local eatServer = character:GetAttribute("GS_EatServer")
			if eatServer then
				local local1 = now + (eatServer - workspace:GetServerTimeNow())
				if not eatUntil or local1 > eatUntil then eatUntil = local1 end
			end
			if attackStart and now - attackStart < 0.6 then
				local p = (now - attackStart) / 0.6
				local pitch
				if p < 0.4 then
					pitch = lerp(math.rad(20), math.rad(165), p / 0.4)
				else
					pitch = lerp(math.rad(165), math.rad(10), math.clamp((p - 0.4) / 0.35, 0, 1))
				end
				for i, name in ipairs(ARMS) do
					if injury[name] < 3 then
						local target = targets[name]
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = pitch - (i == 2 and math.rad(18) or 0)
						target.roll = math.rad(-12)
						limbs[name].skipClip = true
					end
				end
				targetLeanForward += p < 0.4 and -0.12 or 0.3
			elseif eatUntil and now < eatUntil then
				for i, name in ipairs(ARMS) do
					if injury[name] < 3 then
						local target = targets[name]
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(75) + math.rad(22) * math.sin(now * 13 + i * 1.9)
						target.roll = math.rad(-28)
						limbs[name].skipClip = true
					end
				end
				targetLeanForward += 0.35
			elseif puppet and character:GetAttribute("GS_Twitch") then

				for i, name in ipairs(ARMS) do
					if injury[name] < 3 then
						local target = targets[name]
						local jerk = math.noise(now * 7, i * 3.1) * math.rad(35)
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(95) + jerk
						target.roll = math.rad(-8) + math.noise(now * 5, i) * math.rad(20)
						limbs[name].skipClip = true
					end
				end
				targetLeanForward += 0.28 + math.noise(now * 3, 7.7) * 0.1
				targetLeanRight += math.noise(now * 9, 1.3) * 0.12
			end
		end

		-- what's in the hand: guns up to the eye when aiming, low ready otherwise; melee at the side; kits in front
		local holdPose = character:GetAttribute("GS_HoldPose")
		if holdPose and not climbing and not webStunned and proneAmount < 0.3 then
			local clock = os.clock()
			local aimPitch = math.clamp(math.asin(math.clamp(camLook.Y, -1, 1)), math.rad(-60), math.rad(70))
			local aimingNow = character:GetAttribute("GS_Aim") == true
			local reloadAt = character:GetAttribute("GS_ReloadAt")
			local reloading = reloadAt and clock - reloadAt < (character:GetAttribute("GS_ReloadDur") or 2.4)
			local recoilAt = character:GetAttribute("GS_RecoilAt")
			local recoil = recoilAt and math.clamp(1 - (clock - recoilAt) / 0.18, 0, 1) or 0
			local pumpAt = character:GetAttribute("GS_PumpAt")
			local pump = pumpAt and clock - pumpAt < 0.3 and math.sin((clock - pumpAt) / 0.3 * math.pi) or 0
			local attackAt = character:GetAttribute("GS_AttackStart")
			local swingP = attackAt and (clock - attackAt) / 0.45 or 2
			local useAt = character:GetAttribute("GS_UseStart")
			local using = useAt and serverTime - useAt < 12
			local drawAt = character:GetAttribute("GS_DrawAt")
			local draw = drawAt and math.clamp((serverTime - drawAt) / 0.3, 0, 1) or 1
			local r, l = targets.rightArm, targets.leftArm
			local rightOk = limbs.rightArm and injury.rightArm < 3
			local leftOk = limbs.leftArm and injury.leftArm < 3
			local function pose(target, joint, pitch, roll, weight)
				if not target or not joint then return end
				target.weight = (weight or 1) * draw
				target.pitchAdd = 0
				target.pitchAbs = pitch
				target.roll = roll
				joint.skipClip = true
			end
			if holdPose == "long" then
				if reloading then
					-- gun broken open / tipped across the body, the other hand feeding shells
					if rightOk then pose(r, limbs.rightArm, math.rad(42), math.rad(-32)) end
					if leftOk then pose(l, limbs.leftArm, math.rad(48) + math.sin(clock * 9) * math.rad(14), math.rad(-50)) end
				elseif aimingNow then
					if rightOk then pose(r, limbs.rightArm, math.rad(90) + aimPitch + recoil * math.rad(14), math.rad(-14)) end
					if leftOk then pose(l, limbs.leftArm, math.rad(92) + aimPitch + recoil * math.rad(10) - pump * math.rad(12), math.rad(-55)) end
					targetLeanForward += 0.05 - recoil * 0.08
				else
					if rightOk then pose(r, limbs.rightArm, math.rad(58) + aimPitch * 0.35 + recoil * math.rad(18), math.rad(-12)) end
					if leftOk then pose(l, limbs.leftArm, math.rad(66) + aimPitch * 0.35 - pump * math.rad(12), math.rad(-48)) end
				end
			elseif holdPose == "pistol" then
				if reloading then
					if rightOk then pose(r, limbs.rightArm, math.rad(50), math.rad(-25)) end
					if leftOk then pose(l, limbs.leftArm, math.rad(55), math.rad(-40)) end
				elseif aimingNow then
					if rightOk then pose(r, limbs.rightArm, math.rad(90) + aimPitch + recoil * math.rad(22), math.rad(-8)) end
					if leftOk then pose(l, limbs.leftArm, math.rad(86) + aimPitch + recoil * math.rad(16), math.rad(-45)) end
				else
					if rightOk then pose(r, limbs.rightArm, math.rad(62) + aimPitch * 0.5 + recoil * math.rad(24), math.rad(-6)) end
				end
			elseif holdPose == "melee" or holdPose == "knife" then
				if swingP < 1 and rightOk then
					if holdPose == "knife" then
						-- a quick stab forward
						local s = math.sin(math.clamp(swingP, 0, 1) * math.pi)
						pose(r, limbs.rightArm, math.rad(40) + s * math.rad(60) + aimPitch * 0.5, math.rad(-10) - s * math.rad(10))
						if l and limbs.leftArm then
							-- (one hand is enough: the other one stays down instead of the two-handed overhead swing)
							l.weight, l.pitchAbs, l.pitchAdd, l.roll = 0, 0, 0, 0
							limbs.leftArm.skipClip = false
						end
						targetLeanForward += s * 0.12
					else
						-- wind up over the shoulder, then chop down across
						local up = swingP < 0.35
						local k = up and swingP / 0.35 or math.clamp((swingP - 0.35) / 0.4, 0, 1)
						local pitch = up and lerp(math.rad(25), math.rad(160), k) or lerp(math.rad(160), math.rad(30), k)
						local roll = up and lerp(math.rad(5), math.rad(28), k) or lerp(math.rad(28), math.rad(-28), k)
						pose(r, limbs.rightArm, pitch, roll)
						if leftOk and holdPose == "melee" then pose(l, limbs.leftArm, pitch - math.rad(10), math.rad(-30)) end
						targetLeanForward += up and -0.08 or 0.22 * k
					end
				elseif rightOk and not (attackAt and clock - attackAt < 0.6) then
					pose(r, limbs.rightArm, holdPose == "knife" and math.rad(32) or math.rad(22), math.rad(4), isMoving and 0.8 or 1)
				end
			elseif holdPose == "item" then
				if using then
					-- both hands busy in front of the chest (wrapping, stitching, setting a splint)
					local jitter = math.sin(clock * 8) * math.rad(8)
					if rightOk then pose(r, limbs.rightArm, math.rad(58) + jitter, math.rad(-28)) end
					if leftOk then pose(l, limbs.leftArm, math.rad(52) - jitter, math.rad(-30)) end
					targetLeanForward += 0.12
				elseif character:GetAttribute("GS_FlareLit") and rightOk then
					-- a lit flare held up high to see by
					pose(r, limbs.rightArm, math.rad(110) + aimPitch * 0.3, math.rad(10))
				elseif rightOk then
					pose(r, limbs.rightArm, math.rad(34), math.rad(-6), isMoving and 0.8 or 1)
				end
			end
		end

		local alpha = math.min(dt * LIMB_SMOOTH, 1)
		for name, joint in pairs(limbs) do
			local target = targets[name]
			if joint.weight < 0.05 then
				joint.pitchAbs = target.pitchAbs
			else
				joint.pitchAbs += (target.pitchAbs - joint.pitchAbs) * alpha
			end
			joint.pitchAdd += (target.pitchAdd - joint.pitchAdd) * alpha
			joint.roll += (target.roll - joint.roll) * alpha
			joint.weight += (target.weight - joint.weight) * alpha
		end
		if not climbing and proneAmount < 0.3 then
			for _, name in ipairs(LEGS) do
				if injury[name] == 2 then
					local joint = limbs[name]
					joint.weight = 1
					joint.pitchAdd = 0
					joint.pitchAbs = math.clamp(joint.pitchAbs, math.rad(-12), math.rad(14))
				end
			end
			for _, name in ipairs(ARMS) do
				if injury[name] == 2 then
					local joint = limbs[name]
					joint.weight = 1
					joint.pitchAdd = 0
				end
			end
		end
		leanForward = approach(leanForward, math.clamp(targetLeanForward, -0.35, 0.35), dt, LEAN_SMOOTH)
		leanRight = approach(leanRight, math.clamp(targetLeanRight, -0.35, 0.35), dt, LEAN_SMOOTH)

		LimbPose.ApplyLean(rig, leanForward, leanRight, crouchAmount, proneAmount, bodyYaw)
		LimbPose.Apply(rig, {antiClip = true, params = params})

		sendTimer += dt
		if not puppet and sendTimer >= SEND_INTERVAL then
			sendTimer = 0
			local values = LimbPose.Collect(rig, (neckYaw - bodyYaw) * (1 - proneAmount * 0.5), headPitch, leanForward, leanRight, mode, crouchAmount, proneAmount, bodyYaw)
			event:FireServer(LimbPose.Pack(values))
		end
	end)
end

if player.Character then
	task.spawn(SetupCharacter, player.Character)
end
player.CharacterAdded:Connect(SetupCharacter)

local function WatchPlayer(plr)
	if plr == player then return end
	if plr.Character then
		task.spawn(SetupRemoteCharacter, plr, plr.Character)
	end
	plr.CharacterAdded:Connect(function(char)
		SetupRemoteCharacter(plr, char)
	end)
end

for _, plr in ipairs(Players:GetPlayers()) do
	WatchPlayer(plr)
end
Players.PlayerAdded:Connect(WatchPlayer)
Players.PlayerRemoving:Connect(function(plr)
	remoteData[plr] = nil
end)

local function nearestPlayerHead(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local best, bestDist = nil, 45
	for _, plr in ipairs(Players:GetPlayers()) do
		local head = plr.Character and plr.Character:FindFirstChild("Head")
		if head then
			local d = (head.Position - root.Position).Magnitude
			if d < bestDist then best, bestDist = head.Position, d end
		end
	end
	return best
end

local function localPlayerHead(character)
	local look = character:GetAttribute("GS_LookAt")
	if typeof(look) == "Vector3" then return look end
	local head = player.Character and player.Character:FindFirstChild("Head")
	return head and head.Position or nil
end

local function watchFolder(folderName, lookTarget)
	task.spawn(function()
		local folder = workspace:WaitForChild(folderName, 120)
		if not folder then return end
		local function add(model)
			if model:IsA("Model") then
				task.spawn(SetupCharacter, model, {puppet = true, lookTarget = lookTarget})
			end
		end
		for _, model in ipairs(folder:GetChildren()) do add(model) end
		folder.ChildAdded:Connect(add)
	end)
end

watchFolder("NPCs", nearestPlayerHead)

local function monsterLook(character)
	local look = character:GetAttribute("GS_LookAt")
	if typeof(look) == "Vector3" then return look end
	local value = character:FindFirstChild("GS_Target")
	local target = value and value.Value
	local head = target and target.Parent and (target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart"))
	if head then return head.Position end
	return nearestPlayerHead(character)
end
watchFolder("Monsters", monsterLook)
task.spawn(function()
	local folder = workspace:WaitForChild("GS_Hallucinations", 120)
	if not folder then return end
	local function add(model)
		if model:IsA("Model") then
			task.spawn(SetupCharacter, model, {puppet = true, noGetUp = true, lookTarget = localPlayerHead})
		end
	end
	for _, model in ipairs(folder:GetChildren()) do add(model) end
	folder.ChildAdded:Connect(add)
end)
]=]},
	{name = "AntiCheat", class = "Script", where = "ServerScriptService", source = [=[
-- Server anti-cheat: movement checks, account screening, bans, incident replays, punishment.
-- Everything a player sees from here is in English.
-- Fewer false kicks and bans (this version):
--   * only proof a normal client can never produce bans on its own: a honeypot remote, an admin remote
--   * what the client reports about itself (hooks, log traces, ESP, movers, lighting, camera, collision) and the
--     decoys are evidence for the admins (an incident with a replay), never a kick or a ban by themselves
--   * movement oddities rubberband the player; only a long run of them kicks, and a kick never turns into a ban
--   * lag is not cheating: catching up after a freeze, fast falls, knockback, traps and webs are allowed for
--   * the heartbeat only kicks a client that keeps moving while its anti-cheat is silent (a phone put in the
--     background, or a slow load, is left alone)
--   * automatic bans last AutoBanSeconds; the admin makes it permanent (or clears it) on the replay
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))

local CONFIG = {
	Admins = {[1666069865] = true},

	-- account screening (admins are never screened)
	ScreenAccounts = true,
	MinAccountAgeDays = 3,
	MinFriends = 5,
	MinBadges = 20,
	-- Roblox blocks HttpService calls to roblox.com, so badges go through a public proxy.
	-- Needs "Allow HTTP Requests" on. If the request fails the badge check is skipped, never a kick.
	BadgeApi = "https://badges.roproxy.com/v1/users/%d/badges?limit=25&sortOrder=Desc",
	UserSearchApi = "https://users.roproxy.com/v1/users/search?keyword=%s&limit=10",
	ScreenWhitelist = {},
	SuspiciousMessage = "Suspicious account",

	-- movement
	SampleInterval = 0.1,
	SpeedAllowanceMult = 1.6,
	SpeedAllowanceFlat = 8,
	SpeedStrikes = 4, -- samples in a row over the limit before it counts (a burst of knockback never does)
	TeleportDistance = 40,
	HoverTime = 2,
	MaxRise = 14,
	FlingAngular = 200,
	DesyncDistance = 25,
	RemoteSpamPerSecond = 120,
	HeartbeatTimeout = 60,
	FirstHeartbeatTimeout = 180,
	SilentMoveDistance = 150, -- a silent client must also move this far before it is kicked

	-- scoring: every flag adds points, points decay over time
	ScoreDecayPerSecond = 0.35,
	IncidentScore = 8,
	PunishScore = 25, -- hard proof (honeypot / admin remote): paralyse, kill, ban
	KickScore = 45, -- movement only: a kick, never a ban
	Points = {
		speed = 2, teleport = 5, fly = 4, noclip = 4, desync = 3, fling = 8, humanoid = 30, remotespam = 10,
		hook = 6, esp = 5, lighting = 1, gravity = 5, walkspeed = 5, jumppower = 5, injected = 8,
		honeypot = 30, remoteabuse = 12, launch = 5, inside = 3, bodymover = 8, collision = 5, camera = 3, decoy = 6,
	},

	-- punishment
	PunishKillDelay = 20,
	AutoBanSeconds = 7 * 86400, -- the admin makes it permanent (or clears it) with the verdict on the replay
	AutoBanAllDevices = true,

	-- replays
	RecordSeconds = 90,
	ReplayBefore = 30,
	ReplayAfter = 8,
	ReplayRadius = 150,
	ReplayMaxEntities = 12,
}

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local reportRemote = ensure(ReplicatedStorage, "RemoteEvent", "ACReport")
local alertRemote = ensure(ReplicatedStorage, "RemoteEvent", "ACAlert")
local adminRemote = ensure(ReplicatedStorage, "RemoteFunction", "ACAdmin")
local worldInfo = ensure(ReplicatedStorage, "Configuration", "AC_World")
local strikeRemote = ReplicatedStorage:WaitForChild("PlayerStrike", 30)

local banStore, incidentStore, dossierStore
pcall(function() banStore = DataStoreService:GetDataStore("AC_Bans_v1") end)
pcall(function() incidentStore = DataStoreService:GetDataStore("AC_Incidents_v1") end)
pcall(function() dossierStore = DataStoreService:GetDataStore("AC_Dossier_v1") end)
local BAN_TOPIC = "AC_Bans_v1"

-- DataStore calls fail now and then; bans and dossiers must not be lost to a hiccup
local function retry(fn, attempts)
	for i = 1, attempts or 3 do
		local ok, result = pcall(fn)
		if ok then return true, result end
		if i < (attempts or 3) then task.wait(0.6 * i) end
	end
	return false, nil
end

local function serverNow() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end

-- admins (and the place owner) are never checked, flagged, punished or banned by the anti-cheat
local function isAdminId(userId)
	userId = tonumber(userId)
	if not userId then return false end
	if CONFIG.Admins[userId] then return true end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == userId
end

local function isAdmin(player)
	return isAdminId(player.UserId) or player:GetAttribute("IsAdmin") == true
end

local function forAdmins(fn)
	for _, plr in ipairs(Players:GetPlayers()) do
		if isAdmin(plr) then fn(plr) end
	end
end

-- ===================== bans =====================

local function formatDuration(seconds)
	if seconds < 0 then return "permanent" end
	if seconds >= 86400 then return string.format("%dd", math.floor(seconds / 86400)) end
	if seconds >= 3600 then return string.format("%dh", math.floor(seconds / 3600)) end
	return string.format("%dm", math.max(1, math.floor(seconds / 60)))
end

local function parseDuration(text)
	if typeof(text) == "number" then return text end
	if typeof(text) ~= "string" then return nil end
	text = text:lower():gsub("%s", "")
	if text == "" or text == "perm" or text == "permanent" or text == "-1" then return -1 end
	local total = 0
	for amount, unit in text:gmatch("(%d+)(%a*)") do
		local n = tonumber(amount)
		local mult = ({s = 1, m = 60, h = 3600, d = 86400, w = 604800, y = 31536000, [""] = 86400})[unit]
		if not mult then return nil end
		total += n * mult
	end
	return total > 0 and total or nil
end

local function banMessage(entry)
	local expires = entry.expires == -1 and "never" or os.date("!%Y-%m-%d %H:%M UTC", entry.expires)
	return string.format("You are banned.\nReason: %s\nExpires: %s", entry.reason or "no reason", expires)
end

local function banActive(entry)
	return entry and entry.active and (entry.expires == -1 or os.time() < entry.expires)
end

local function updateIndex(entry)
	if not banStore then return end
	pcall(function()
		banStore:UpdateAsync("index", function(list)
			list = list or {}
			for i = #list, 1, -1 do
				if list[i].userId == entry.userId then table.remove(list, i) end
			end
			table.insert(list, 1, entry)
			while #list > 300 do table.remove(list) end
			return list
		end)
	end)
end

local recordDossier
local function ban(userId, name, reason, seconds, allDevices, by, source, incidentId)
	local online = Players:GetPlayerByUserId(userId)
	if isAdminId(userId) or (online and isAdmin(online)) then
		warn("[AntiCheat] refused to ban admin " .. tostring(name or userId))
		return nil
	end
	local entry = {
		userId = userId, name = name or tostring(userId), reason = reason, by = by, source = source,
		at = os.time(), expires = seconds < 0 and -1 or os.time() + seconds, duration = seconds,
		allDevices = allDevices, incident = incidentId, active = true,
	}
	local saved = banStore and retry(function() banStore:SetAsync("u_" .. userId, entry) end, 4)
	updateIndex(entry)
	-- Roblox's own ban API: works in live servers (not in Studio) and adds alt-account detection
	entry.robloxBan = pcall(function()
		Players:BanAsync({
			UserIds = {userId}, ApplyToUniverse = true, Duration = seconds < 0 and -1 or seconds,
			DisplayReason = string.sub(reason, 1, 380), PrivateReason = string.sub(source .. " / " .. tostring(by) .. ": " .. reason, 1, 900),
			ExcludeAltAccounts = not allDevices,
		})
	end)
	-- every other server kicks them right now too
	pcall(function() MessagingService:PublishAsync(BAN_TOPIC, {op = "ban", userId = userId, message = banMessage(entry)}) end)
	if recordDossier then task.spawn(recordDossier, userId, name, nil, {ban = {at = entry.at, reason = reason, by = by, expires = entry.expires}}) end
	if not saved then warn("[AntiCheat] ban for " .. tostring(userId) .. " could not be saved to the DataStore") end
	if online then online:Kick(banMessage(entry)) end
	forAdmins(function(admin)
		alertRemote:FireClient(admin, "ban", string.format("%s banned (%s) — %s", entry.name, formatDuration(seconds), reason))
	end)
	return entry
end

local function robloxUnban(userId)
	-- Studio silently skips UnbanAsync ("will succeed on production game servers"), so there it never counts
	if RunService:IsStudio() then return false end
	return (pcall(function() Players:UnbanAsync({UserIds = {userId}, ApplyToUniverse = true}) end))
end

local function unban(userId, by)
	local entry
	if banStore then
		retry(function() entry = banStore:GetAsync("u_" .. userId) end)
	end
	entry = entry or {userId = userId, name = tostring(userId), reason = "?", at = os.time(), expires = -1}
	entry.active = false
	entry.unbannedBy = by
	entry.unbannedAt = os.time()
	-- Roblox's own ban can only be lifted from a live server; if that fails here, live servers finish the job
	entry.robloxUnbanPending = not robloxUnban(userId) or nil
	local saved = banStore and retry(function() banStore:SetAsync("u_" .. userId, entry) end, 4)
	updateIndex(entry)
	pcall(function() MessagingService:PublishAsync(BAN_TOPIC, {op = "unban", userId = userId}) end)
	if recordDossier then task.spawn(recordDossier, userId, entry.name, nil, {unban = {at = entry.unbannedAt, by = by}}) end
	return entry, saved
end

-- read a ban record, retrying; nil + false when the DataStore could not be reached
local function readBan(userId)
	if not banStore then return nil, false end
	local ok, entry = retry(function() return banStore:GetAsync("u_" .. userId) end, 3)
	return entry, ok
end

-- ===================== account screening =====================

local function screenAccount(player)
	if not CONFIG.ScreenAccounts or isAdmin(player) or CONFIG.ScreenWhitelist[player.UserId] then return end
	if player.AccountAge < CONFIG.MinAccountAgeDays then
		player:Kick(CONFIG.SuspiciousMessage)
		return
	end
	local okFriends, count = pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		local n = #pages:GetCurrentPage()
		while n < CONFIG.MinFriends and not pages.IsFinished do
			pages:AdvanceToNextPageAsync()
			n += #pages:GetCurrentPage()
		end
		return n
	end)
	if okFriends and count < CONFIG.MinFriends then
		player:Kick(CONFIG.SuspiciousMessage)
		return
	end
	local okBadges, badges = pcall(function()
		local body = HttpService:GetAsync(string.format(CONFIG.BadgeApi, player.UserId))
		local data = HttpService:JSONDecode(body)
		if typeof(data) ~= "table" or typeof(data.data) ~= "table" then error("bad reply") end
		if #data.data >= CONFIG.MinBadges or data.nextPageCursor then return math.huge end
		return #data.data
	end)
	if okBadges and badges < CONFIG.MinBadges and player.Parent then
		player:Kick(CONFIG.SuspiciousMessage)
	end
end

-- ===================== recording (replays) =====================

local frames = {}
local events = {}
local entityInfo = {}
local monsterIds = 0

local function entityIdFor(model)
	local plr = Players:GetPlayerFromCharacter(model)
	if plr then
		entityInfo["P" .. plr.UserId] = {name = plr.DisplayName .. " (@" .. plr.Name .. ")", kind = "player", userId = plr.UserId}
		return "P" .. plr.UserId
	end
	local id = model:GetAttribute("AC_Id")
	if not id then
		monsterIds += 1
		local isNpc = model.Parent and model.Parent.Name == "NPCs"
		id = (isNpc and "N" or "M") .. monsterIds
		model:SetAttribute("AC_Id", id)
		entityInfo[id] = {name = isNpc and (model:GetAttribute("DisplayName") or model.Name) or model.Name, kind = isNpc and "npc" or "monster"}
	end
	return id
end

local function logEvent(model, kind, text)
	if not model then return end
	table.insert(events, {t = serverNow(), id = entityIdFor(model), kind = kind, text = text})
	local cutoff = serverNow() - CONFIG.RecordSeconds
	while events[1] and events[1].t < cutoff do table.remove(events, 1) end
end

local function stateCode(model, humanoid)
	if not humanoid or humanoid.Health <= 0 then return 3 end
	if model:GetAttribute("Ragdolled") then return 2 end
	if humanoid.FloorMaterial == Enum.Material.Air then return 1 end
	return 0
end

local function recordFrame()
	local entities = {}
	local function add(model)
		local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
		if not root or not root:IsA("BasePart") then return end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local look = root.CFrame.LookVector
		local hp = humanoid and humanoid.MaxHealth > 0 and math.floor(humanoid.Health / humanoid.MaxHealth * 100) or 0
		local p = root.Position
		entities[entityIdFor(model)] = {r1(p.X), r1(p.Y), r1(p.Z), r1(math.atan2(-look.X, -look.Z)), stateCode(model, humanoid), hp}
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then add(plr.Character) end
	end
	for _, folderName in ipairs({"Monsters", "NPCs"}) do
		local f = workspace:FindFirstChild(folderName)
		if f then
			for _, model in ipairs(f:GetChildren()) do
				-- (decoys have no MonsterId and never show up in replays)
				if model:IsA("Model") and (folderName ~= "Monsters" or model:GetAttribute("MonsterId")) then add(model) end
			end
		end
	end
	table.insert(frames, {t = serverNow(), e = entities})
	local cutoff = serverNow() - CONFIG.RecordSeconds
	while frames[1] and frames[1].t < cutoff do table.remove(frames, 1) end
end

local rememberPlayer
local incidentCache = {}

-- ===================== seen players (for name suggestions) =====================
local seenStore
pcall(function() seenStore = DataStoreService:GetDataStore("AC_Seen_v1") end)
local seenCache, seenCacheAt = nil, -math.huge

function rememberPlayer(player)
	if not seenStore then return end
	local entry = {userId = player.UserId, name = player.Name, displayName = player.DisplayName, last = os.time()}
	pcall(function()
		seenStore:UpdateAsync("index", function(list)
			list = list or {}
			for i = #list, 1, -1 do
				if list[i].userId == entry.userId then table.remove(list, i) end
			end
			table.insert(list, 1, entry)
			while #list > 1500 do table.remove(list) end
			return list
		end)
	end)
	seenCacheAt = -math.huge
end

local function seenPlayers()
	if seenCache and os.clock() - seenCacheAt < 60 then return seenCache end
	local list
	if seenStore then pcall(function() list = seenStore:GetAsync("index") end) end
	seenCache, seenCacheAt = list or seenCache or {}, os.clock()
	return seenCache
end
local incidentIndexCache = {}

local function buildReplay(suspectId, fromT, toT)
	local relevant = {[suspectId] = true}
	local count = 1
	for _, frame in ipairs(frames) do
		if frame.t >= fromT and frame.t <= toT then
			local s = frame.e[suspectId]
			if s then
				for id, e in pairs(frame.e) do
					if not relevant[id] and count < CONFIG.ReplayMaxEntities then
						local d = Vector3.new(e[1] - s[1], e[2] - s[2], e[3] - s[3]).Magnitude
						if d < CONFIG.ReplayRadius then
							relevant[id] = true
							count += 1
						end
					end
				end
			end
		end
	end
	local order, index = {}, {}
	for id in pairs(relevant) do
		local info = entityInfo[id] or {name = id, kind = "?"}
		table.insert(order, {id = id, name = info.name, kind = info.kind, suspect = id == suspectId})
		index[id] = #order
	end
	local outFrames = {}
	for _, frame in ipairs(frames) do
		if frame.t >= fromT and frame.t <= toT then
			local row = {math.floor((frame.t - fromT) * 100 + 0.5) / 100}
			for id, e in pairs(frame.e) do
				local i = index[id]
				if i then table.insert(row, {i, e[1], e[2], e[3], e[4], e[5], e[6]}) end
			end
			table.insert(outFrames, row)
		end
	end
	local outEvents = {}
	for _, ev in ipairs(events) do
		if ev.t >= fromT and ev.t <= toT and index[ev.id] then
			table.insert(outEvents, {math.floor((ev.t - fromT) * 100 + 0.5) / 100, index[ev.id], ev.kind, ev.text})
		end
	end
	return {entities = order, frames = outFrames, events = outEvents, length = toT - fromT}
end

local function saveIncident(meta, replay)
	incidentCache[meta.id] = {meta = meta, replay = replay}
	table.insert(incidentIndexCache, 1, meta)
	while #incidentIndexCache > 150 do table.remove(incidentIndexCache) end
	if not incidentStore then return end
	pcall(function() incidentStore:SetAsync("i_" .. meta.id, {meta = meta, replay = replay}) end)
	pcall(function()
		incidentStore:UpdateAsync("index", function(list)
			list = list or {}
			table.insert(list, 1, meta)
			while #list > 150 do table.remove(list) end
			return list
		end)
	end)
end

-- ===================== per-player state =====================

local states = {}

local function newState(player)
	return {
		player = player, score = 0, window = {}, flagLast = {}, flagCounts = {},
		lastIncidentAt = -math.huge, joinedAt = os.clock(), key = HttpService:GenerateGUID(false),
		lastBeat = nil, seq = 0, desyncStrikes = 0, remoteCount = 0, remoteWindowStart = os.clock(),
	}
end

local createIncident
local punish

-- Hard proof: things only an exploit ever does (a remote nothing in the game fires, an admin remote from a
-- non-admin). That alone may ban.
local HARD_FLAGS = {honeypot = true, remoteabuse = true}
-- Evidence only: the client reports these about itself (a slow phone, an odd GPU driver, other software in the
-- log can all trip them) and the decoys can be walked into by chance. They go to the admins as incidents with
-- a replay and never kick or ban by themselves.
local EVIDENCE_ONLY = {
	hook = true, esp = true, lighting = true, gravity = true, walkspeed = true, jumppower = true, injected = true,
	bodymover = true, collision = true, camera = true, decoy = true,
}

local function flag(player, kind, detail)
	local st = states[player]
	if not st or st.punishing then return end
	if isAdmin(player) then return end -- admins are never flagged
	local now = os.clock()
	if now - (st.flagLast[kind] or -math.huge) < 0.45 then return end
	st.flagLast[kind] = now
	st.flagCounts[kind] = (st.flagCounts[kind] or 0) + 1
	local points = (CONFIG.Points[kind] or 3) * (st.trusted and 0.5 or 1)
	st.dossierFlags = st.dossierFlags or {}
	st.dossierFlags[kind] = (st.dossierFlags[kind] or 0) + 1
	local text = kind .. (detail and (": " .. detail) or "")
	logEvent(player.Character, "flag", text)
	st.lastReason = text
	if EVIDENCE_ONLY[kind] then
		st.evidence = (st.evidence or 0) + points
		if st.evidence >= CONFIG.IncidentScore and now - st.lastIncidentAt > 90 then
			st.lastIncidentAt = now
			st.evidence = 0
			createIncident(player, text, "recorded")
		end
		return
	end
	if HARD_FLAGS[kind] then st.hardFlag = kind end
	st.score += points
	st.maxScore = math.max(st.maxScore or 0, st.score)
	if st.hardFlag and st.score >= CONFIG.PunishScore then
		punish(player, text)
	elseif st.score >= CONFIG.KickScore then
		punish(player, text)
	elseif st.score >= CONFIG.IncidentScore and now - st.lastIncidentAt > 60 then
		st.lastIncidentAt = now
		createIncident(player, text, "recorded")
	end
end

function createIncident(player, reason, action)
	local st = states[player]
	local counts = {}
	for kind, n in pairs(st and st.flagCounts or {}) do table.insert(counts, kind .. " x" .. n) end
	local meta = {
		id = string.sub(HttpService:GenerateGUID(false), 1, 8), userId = player.UserId,
		name = player.DisplayName .. " (@" .. player.Name .. ")", reason = reason, flags = table.concat(counts, ", "),
		score = st and math.floor(st.score) or 0, at = os.time(), server = game.JobId, action = action,
	}
	if recordDossier then
		task.spawn(recordDossier, player.UserId, player.Name, player.DisplayName,
			{incident = {id = meta.id, reason = reason, action = action, at = meta.at, server = string.sub(game.JobId, 1, 8), score = meta.score}})
	end
	local flagT = serverNow()
	local suspectId = "P" .. player.UserId
	entityInfo[suspectId] = {name = meta.name, kind = "player", userId = player.UserId}
	forAdmins(function(admin)
		alertRemote:FireClient(admin, "incident", string.format("[AC] %s — %s (%s)", meta.name, reason, action))
	end)
	task.delay(CONFIG.ReplayAfter, function()
		local replay = buildReplay(suspectId, flagT - CONFIG.ReplayBefore, flagT + CONFIG.ReplayAfter)
		saveIncident(meta, replay)
		forAdmins(function(admin) alertRemote:FireClient(admin, "incidents") end)
	end)
	return meta
end

-- confident: paralyse, lobotomise, kill, then ban. Leaving or resetting just bans sooner.
function punish(player, reason)
	local st = states[player]
	if not st or st.punishing or isAdmin(player) then return end
	-- movement-only evidence: pull them out of the server, never a ban (the kicks are counted in the dossier,
	-- the admins see the replays and can ban by hand)
	if not st.hardFlag then
		st.punishing = true
		local meta = createIncident(player, reason, "kicked")
		if recordDossier then
			task.spawn(recordDossier, player.UserId, player.Name, player.DisplayName, {kick = {at = os.time(), reason = reason, id = meta.id}})
		end
		task.delay(1, function()
			if player.Parent then
				player:Kick("Disconnected by the anti-cheat: " .. reason .. "\nIf this was a mistake, just rejoin.")
			end
		end)
		return
	end
	st.punishing = true
	local token = {}
	st.punishToken = token
	player:SetAttribute("AC_Punished", true)
	local meta = createIncident(player, reason, "punished")
	local function doBan()
		if st.banned or st.punishToken ~= token then return end
		st.banned = true
		local why = reason
		ban(player.UserId, player.Name, "Exploiting (" .. why .. ")", CONFIG.AutoBanSeconds, CONFIG.AutoBanAllDevices,
			"AntiCheat", "anticheat", meta.id)
	end
	st.doBan = doBan
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		doBan()
		return
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	character:SetAttribute("Injury_Torso", 2)
	character:SetAttribute("Lobotomized", true)
	humanoid.Died:Connect(function()
		task.wait(3)
		doBan()
	end)
	task.delay(CONFIG.PunishKillDelay, function()
		if st.punishToken ~= token then return end
		if humanoid.Parent and humanoid.Health > 0 then
			if not FallDamageController.ExplodeHead(character) then humanoid.Health = 0 end
		end
		task.wait(5)
		doBan()
	end)
end

-- ===================== movement checks =====================

local function worldParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local ignore = {character}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(ignore, plr.Character) end
	end
	for _, name in ipairs({"Monsters", "NPCs", "Corpses", "SeveredLimbs", "GS_Hallucinations"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(ignore, f) end
	end
	params.FilterDescendantsInstances = ignore
	-- walls the player's collision group passes through are not walls for this player
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then pcall(function() params.CollisionGroup = root.CollisionGroup end) end
	return params
end

local function groundParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = false
	params.FilterDescendantsInstances = {character}
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then pcall(function() params.CollisionGroup = root.CollisionGroup end) end
	return params
end

-- is a point truly inside a solid block (checked against the part's real, rotated shape)?
local function pointInsideSolid(point, character, margin)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = worldParams(character).FilterDescendantsInstances
	overlap.RespectCanCollide = true
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then pcall(function() overlap.CollisionGroup = root.CollisionGroup end) end
	for _, part in ipairs(workspace:GetPartBoundsInRadius(point, 0.1, overlap)) do
		-- only plain blocks: wedges, meshes and unions have shapes a bounding box can't describe
		if part.Anchored and part.CanCollide and part.ClassName == "Part" and part.Shape == Enum.PartType.Block then
			local size = part.Size
			if math.min(size.X, size.Y, size.Z) > margin * 2 + 0.4 then
				local p = part.CFrame:PointToObjectSpace(point)
				if math.abs(p.X) < size.X / 2 - margin and math.abs(p.Y) < size.Y / 2 - margin and math.abs(p.Z) < size.Z / 2 - margin then
					return part
				end
			end
		end
	end
	return nil
end

local function rubberband(st, root)
	if not st.lastGood then return end
	root.CFrame = st.lastGood
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	st.graceUntil = os.clock() + 0.35
	st.window = {}
	st.air = nil
	st.lastPos = st.lastGood.Position
	logEvent(st.player.Character, "rubberband", "pulled back")
end

local function exempt(character, humanoid)
	if character:GetAttribute("Ragdolled") or character:GetAttribute("Paralyzed") then return true end
	if humanoid.Sit or humanoid.SeatPart or humanoid.PlatformStand then return true end
	local now = serverNow()
	local tp = character:GetAttribute("AC_TeleportAt")
	if tp and now - tp < 3 then return true end
	-- held in place by the game: a bear trap, a web, a baton shock
	local trapped = character:GetAttribute("GS_Trapped")
	if typeof(trapped) == "number" and trapped > now - 1 then return true end
	if (character:GetAttribute("GS_WebStun") or 0) > now - 1 then return true end
	local shocked = character:GetAttribute("GS_Shocked")
	if shocked and now - shocked < 3 then return true end
	return false
end

local function checkPlayer(player, st, now)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or st.punishing then
		st.lastPos, st.window, st.air, st.lastGood = nil, {}, nil, nil
		return
	end
	local pos = root.Position
	if now < (st.graceUntil or 0) or exempt(character, humanoid) then
		st.lastPos, st.window, st.air = pos, {}, nil
		st.lastGood = root.CFrame
		return
	end
	local lastPos = st.lastPos or pos
	st.lastPos = pos
	local delta = pos - lastPos
	local violated = false
	local walk = math.max(humanoid.WalkSpeed, 16) * math.max(1, tonumber(character:GetAttribute("GS_CarrySpeed")) or 1)

	-- lag: a client that froze (no new positions) catches up in one jump. That is only as far as it could have
	-- walked in the time it was frozen, and the speed window starts over afterwards.
	local frozenFor = now - (st.lastMovedAt or now)
	if delta.Magnitude > 0.05 then
		st.lastMovedAt = now
		if frozenFor > 0.5 then st.window = {} end
	end
	local catchUp = walk * CONFIG.SpeedAllowanceMult * (frozenFor + CONFIG.SampleInterval) + CONFIG.SpeedAllowanceFlat

	-- teleport
	if flat(delta).Magnitude > math.max(CONFIG.TeleportDistance, catchUp) or delta.Y > 25 then
		flag(player, "teleport", string.format("%.0f studs in one tick", delta.Magnitude))
		rubberband(st, root)
		return
	end

	-- noclip: passing through, or standing inside, solid geometry
	if delta.Magnitude > 0.3 then
		local params = worldParams(character)
		local forward = workspace:Raycast(lastPos, delta, params)
		if forward and forward.Instance.Anchored then
			local back = workspace:Raycast(pos, -delta, params)
			local inside = false
			if not back then
				inside = pointInsideSolid(pos, character, 0.3) == forward.Instance
			end
			if back or inside then
				flag(player, "noclip", forward.Instance:GetFullName())
				rubberband(st, root)
				return
			end
		end
	end

	-- standing inside a wall for several ticks in a row (noclip that never "passes" a surface)
	-- (the body's centre, not its edges: lying down, crawling under things or brushing a wall never count)
	do
		local head = character:FindFirstChild("Head")
		local wall = pointInsideSolid(root.Position, character, 0.35)
		if wall and head then
			-- the head must be buried too, and in the same wall
			wall = pointInsideSolid(head.Position, character, 0.2) == wall and wall or nil
		end
		st.insideTicks = wall and (st.insideTicks or 0) + 1 or 0
		if st.insideTicks >= 10 then
			st.insideTicks = 0
			flag(player, "inside", "inside " .. wall:GetFullName())
			rubberband(st, root)
			return
		end
	end

	-- shooting straight up far faster than any jump can
	do
		local jumpV = humanoid.UseJumpPower and humanoid.JumpPower or math.sqrt(2 * workspace.Gravity * math.max(humanoid.JumpHeight, 0))
		local vy = root.AssemblyLinearVelocity.Y
		if vy > jumpV * 1.6 + 25 then
			st.launchTicks = (st.launchTicks or 0) + 1
			if st.launchTicks >= 3 then
				st.launchTicks = 0
				flag(player, "launch", string.format("rising at %.0f studs/s", vy))
				violated = true
			end
		else
			st.launchTicks = 0
		end
	end

	-- speed over a one second window
	table.insert(st.window, {t = now, p = pos})
	while st.window[1] and now - st.window[1].t > 1.05 do table.remove(st.window, 1) end
	local oldest = st.window[1]
	local span = now - oldest.t
	if span > 0.9 then
		local dist = flat(pos - oldest.p).Magnitude
		local allowed = (walk * CONFIG.SpeedAllowanceMult + CONFIG.SpeedAllowanceFlat) * span
		if dist > allowed then
			st.speedStrikes = (st.speedStrikes or 0) + 1
			if st.speedStrikes >= CONFIG.SpeedStrikes then
				st.speedStrikes = 0
				flag(player, "speed", string.format("%.0f studs/s", dist / span))
				violated = true
			end
		else
			st.speedStrikes = 0
		end
	end

	-- fly / hover / rising without ground
	local state = humanoid:GetState()
	local climbing = state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming
	if not climbing then
		for _, part in ipairs(workspace:GetPartBoundsInRadius(pos, 3)) do
			if part:IsA("TrussPart") then climbing = true break end
		end
	end
	-- a box cast, not a single ray: standing on an edge or someone's head still counts as ground
	local ground = workspace:Blockcast(root.CFrame, Vector3.new(2.4, 1, 1.6), Vector3.new(0, -(2.5 + humanoid.HipHeight + 4), 0), groundParams(character)) ~= nil
	if ground or climbing then
		st.air = nil
	else
		if not st.air then
			st.air = {start = now, startY = pos.Y, history = {}}
		end
		local air = st.air
		table.insert(air.history, {t = now, y = pos.Y})
		while air.history[1] and now - air.history[1].t > CONFIG.HoverTime do table.remove(air.history, 1) end
		local first = air.history[1]
		if now - air.start > CONFIG.HoverTime and first and now - first.t > CONFIG.HoverTime * 0.9 and pos.Y >= first.y - 1 then
			flag(player, "fly", string.format("airborne %.1fs without falling", now - air.start))
			violated = true
		elseif pos.Y - air.startY > CONFIG.MaxRise then
			flag(player, "fly", string.format("rose %.0f studs in the air", pos.Y - air.startY))
			violated = true
		end
	end

	-- spin-fling exploits
	if root.AssemblyAngularVelocity.Magnitude > CONFIG.FlingAngular then
		flag(player, "fling", string.format("spin %.0f", root.AssemblyAngularVelocity.Magnitude))
		root.AssemblyAngularVelocity = Vector3.zero
		violated = true
	end

	if violated then
		rubberband(st, root)
	elseif ground then
		st.lastGood = root.CFrame
	end
end

local function watchCharacter(player, character)
	local st = states[player]
	if not st then return end
	st.lastPos, st.window, st.air, st.lastGood = nil, {}, nil, nil
	st.graceUntil = os.clock() + 3
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if lastHealth - health >= 5 then
			logEvent(character, "damage", string.format("-%d hp (%s)", math.floor(lastHealth - health), tostring(character:GetAttribute("LastDamageCause") or "?")))
		end
		lastHealth = health
	end)
	humanoid.Died:Connect(function()
		logEvent(character, "death", tostring(character:GetAttribute("DeathCause") or "died"))
	end)
	character.ChildRemoved:Connect(function(child)
		-- deleting the humanoid client-side is the classic god-mode trick
		-- (a body the game itself is swapping out is gone or replaced a moment later: that one doesn't count)
		if child == humanoid and character.Parent and player.Character == character and lastHealth > 0 then
			task.delay(1.5, function()
				if character.Parent and player.Character == character and not character:FindFirstChildOfClass("Humanoid") then
					flag(player, "humanoid", "Humanoid removed")
				end
			end)
		end
	end)
end

local function onPlayerAdded(player)
	-- bans first (retried; if the DataStore is down the periodic sweep checks again)
	local entry, reached = readBan(player.UserId)
	if banActive(entry) then
		if isAdmin(player) then
			-- an admin can never stay banned: clear whatever banned them
			task.spawn(unban, player.UserId, "auto (admin)")
		else
			player:Kick(banMessage(entry))
			return
		end
	end
	if not reached then player:SetAttribute("AC_BanUnchecked", true) end
	states[player] = newState(player)
	-- how many times the anti-cheat already kicked them (from every server) decides kick vs ban
	task.spawn(function()
		if not dossierStore or isAdmin(player) then return end
		local d
		retry(function() d = dossierStore:GetAsync("d_" .. player.UserId) end)
		local st = states[player]
		if st and d then st.priorKicks = d.kicks or 0 end
	end)
	task.spawn(rememberPlayer, player)
	task.spawn(screenAccount, player)
	player.CharacterAdded:Connect(function(character) watchCharacter(player, character) end)
	if player.Character then task.spawn(watchCharacter, player, player.Character) end
	reportRemote:FireClient(player, "key", states[player].key)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end

Players.PlayerRemoving:Connect(function(player)
	local st = states[player]
	if st and st.punishing and st.doBan then
		-- left before the punishment finished
		st.doBan()
	end
	if st and st.dossierFlags and next(st.dossierFlags) and recordDossier then
		local userId, name, displayName = player.UserId, player.Name, player.DisplayName
		task.spawn(recordDossier, userId, name, displayName, nil)
	end
	states[player] = nil
end)

-- ===================== client reports & heartbeat =====================

local CLIENT_FLAGS = {
	hook = true, esp = true, lighting = true, gravity = true, walkspeed = true, jumppower = true, injected = true,
	bodymover = true, collision = true, camera = true,
}

reportRemote.OnServerEvent:Connect(function(player, kind, a, b, c)
	local st = states[player]
	if not st then return end
	if kind == "hello" then
		reportRemote:FireClient(player, "key", st.key)
	elseif kind == "hb" then
		if a ~= st.key or typeof(b) ~= "number" or b <= st.seq then return end
		st.seq = b
		st.lastBeat = os.clock()
		-- desync: where the client says it is vs where the server has it
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if typeof(c) == "Vector3" and root and humanoid and humanoid.Health > 0 and not exempt(character, humanoid)
			and os.clock() > (st.graceUntil or 0) then
			local allowedGap = CONFIG.DesyncDistance + root.AssemblyLinearVelocity.Magnitude * 0.6
			if (c - root.Position).Magnitude > allowedGap then
				st.desyncStrikes += 1
				if st.desyncStrikes >= 3 then
					st.desyncStrikes = 0
					flag(player, "desync", string.format("client %.0f studs from server", (c - root.Position).Magnitude))
					rubberband(st, root)
					pcall(function() root:SetNetworkOwner(nil) end)
					task.delay(2, function()
						if root.Parent and player.Parent and not st.punishing then
							pcall(function() root:SetNetworkOwner(player) end)
						end
					end)
				end
			else
				st.desyncStrikes = 0
			end
		end
	elseif kind == "flag" then
		if typeof(a) ~= "string" or not CLIENT_FLAGS[a] then return end
		flag(player, a, typeof(b) == "string" and string.sub(b, 1, 120) or nil)
	end
end)

-- remote flooding across every RemoteEvent in the game
local function watchRemote(remote)
	if not remote:IsA("RemoteEvent") or remote == reportRemote then return end
	remote.OnServerEvent:Connect(function(player)
		local st = states[player]
		if not st then return end
		local now = os.clock()
		if now - st.remoteWindowStart >= 1 then
			st.remoteWindowStart = now
			st.remoteCount = 0
		end
		st.remoteCount += 1
		if st.remoteCount == CONFIG.RemoteSpamPerSecond then
			flag(player, "remotespam", remote.Name)
		end
	end)
end
for _, d in ipairs(ReplicatedStorage:GetDescendants()) do watchRemote(d) end
ReplicatedStorage.DescendantAdded:Connect(watchRemote)

if strikeRemote then
	strikeRemote.OnServerEvent:Connect(function(player)
		logEvent(player.Character, "strike", "swing")
	end)
end

-- ===================== honeypots & remote abuse =====================
-- Remotes the game never uses, named like the ones exploit scripts go looking for.
-- Only a remote spy / exploit script ever fires them.
local HONEYPOTS = {"AdminRemote", "GiveMoney", "DamagePlayer", "KillPlayer", "SetWalkSpeed", "TeleportRemote", "BanPlayer"}
local honeypotFolder = ensure(ReplicatedStorage, "Folder", "Remotes")
for _, name in ipairs(HONEYPOTS) do
	local remote = ensure(honeypotFolder, "RemoteEvent", name)
	remote.OnServerEvent:Connect(function(player)
		if not isAdmin(player) then flag(player, "honeypot", name) end
	end)
	local fn = ensure(honeypotFolder, "RemoteFunction", name .. "Function")
	fn.OnServerInvoke = function(player)
		if not isAdmin(player) then flag(player, "honeypot", fn.Name) end
		return nil
	end
end
-- the admin remotes: a normal player's client never shows the admin UI, so it never fires them
task.spawn(function()
	local adminAction = ReplicatedStorage:WaitForChild("AdminAction", 30)
	if adminAction then
		adminAction.OnServerEvent:Connect(function(player)
			if not isAdmin(player) then flag(player, "remoteabuse", "AdminAction") end
		end)
	end
end)

-- ===================== anti-ESP decoys =====================
-- Roblox can't hide an instance from one client and not another, and ESP drawn through the executor's
-- own UI can't be seen by any script (DevForum consensus). What we can do is poison what ESP shows:
-- invisible fake creatures, named exactly like the real ones, wander the map inside the Monsters folder.
-- A normal player never sees them; an ESP user sees creatures everywhere and can't tell which are real.
-- Anyone who walks right up to a decoy again and again is following something only ESP shows.
local DECOY_COUNT = 5
local decoys = {}
local okData, MonsterDataModule = pcall(require, Modules:WaitForChild("MonsterData", 10))
local DECOY_NAMES = okData and MonsterDataModule and MonsterDataModule.Order or {"D-130", "B-414", "A-013", "C-207"}

local function decoyGround(center, radius)
	for _ = 1, 8 do
		local angle = math.random() * math.pi * 2
		local r = math.random() * radius
		local origin = center + Vector3.new(math.cos(angle) * r, 200, math.sin(angle) * r)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = {}
		for _, name in ipairs({"Monsters", "NPCs", "Corpses", "SeveredLimbs"}) do
			local f = workspace:FindFirstChild(name)
			if f then table.insert(ignore, f) end
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then table.insert(ignore, plr.Character) end
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
		if hit then return hit.Position + Vector3.new(0, 3, 0) end
	end
	return nil
end

local function buildDecoy(name)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then return nil end
	model.Name = name
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Decal") or d:IsA("Accessory") or d:IsA("Clothing") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Transparency = 1
			d.Anchored = true
			d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
	end
	return model
end

task.spawn(function()
	local monstersFolder = workspace:WaitForChild("Monsters", 120)
	if not monstersFolder then return end
	local center = Vector3.zero
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
	if spawn then center = spawn.Position end
	while true do
		for i = 1, DECOY_COUNT do
			local d = decoys[i]
			if not d or not d.model.Parent then
				local model = buildDecoy(DECOY_NAMES[(i - 1) % #DECOY_NAMES + 1])
				local spot = model and decoyGround(center, 350)
				if model and spot then
					model:PivotTo(CFrame.new(spot))
					model.Parent = monstersFolder
					decoys[i] = {model = model, goal = spot, near = {}}
				elseif model then
					model:Destroy()
				end
			end
			d = decoys[i]
			if d and d.model.Parent then
				-- wander like a creature would
				local pos = d.model:GetPivot().Position
				if (d.goal - pos).Magnitude < 3 or math.random() < 0.02 then
					d.goal = decoyGround(pos, 60) or d.goal
				end
				local step = d.goal - pos
				local move = step.Magnitude > 0 and step.Unit * math.min(step.Magnitude, 5) or Vector3.zero
				local nextPos = pos + move
				local flatMove = Vector3.new(move.X, 0, move.Z)
				d.model:PivotTo(flatMove.Magnitude > 0.01 and CFrame.lookAt(nextPos, nextPos + flatMove) or CFrame.new(nextPos))
				-- who keeps ending up right next to something nobody can see?
				for _, plr in ipairs(Players:GetPlayers()) do
					local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if root and not isAdmin(plr) and (root.Position - nextPos).Magnitude < 6 then
						local last = d.near[plr]
						if not last or os.clock() - last > 20 then
							d.near[plr] = os.clock()
							local st = states[plr]
							if st then
								st.decoyTouches = (st.decoyTouches or 0) + 1
								if st.decoyTouches >= 4 then
									st.decoyTouches = 0
									flag(plr, "decoy", "kept walking up to invisible decoys")
								end
							end
						end
					end
				end
			end
		end
		task.wait(0.5)
	end
end)

-- ===================== bans across servers =====================
-- live servers lift any Roblox-level ban that ever landed on an admin
if not RunService:IsStudio() then
	task.spawn(function()
		local ids = {}
		for id in pairs(CONFIG.Admins) do table.insert(ids, id) end
		if game.CreatorType == Enum.CreatorType.User then table.insert(ids, game.CreatorId) end
		for _, id in ipairs(ids) do robloxUnban(id) end
	end)
end
pcall(function()
	MessagingService:SubscribeAsync(BAN_TOPIC, function(message)
		local data = message.Data
		if typeof(data) ~= "table" or data.op ~= "ban" then return end
		local plr = Players:GetPlayerByUserId(tonumber(data.userId) or 0)
		if plr then plr:Kick(typeof(data.message) == "string" and data.message or "You are banned.") end
	end)
end)

-- every minute: re-check everyone online (catches bans made while a message got lost or the DataStore
-- was down when they joined) and finish Roblox-level unbans that could not run in Studio
task.spawn(function()
	while true do
		task.wait(60)
		for _, plr in ipairs(Players:GetPlayers()) do
			if not isAdmin(plr) then
				local entry, reached = readBan(plr.UserId)
				if banActive(entry) then
					plr:Kick(banMessage(entry))
				elseif reached then
					plr:SetAttribute("AC_BanUnchecked", nil)
				end
			end
		end
		if banStore and not RunService:IsStudio() then
			local list
			pcall(function() list = banStore:GetAsync("index") end)
			for _, entry in ipairs(list or {}) do
				if entry.robloxUnbanPending and robloxUnban(entry.userId) then
					entry.robloxUnbanPending = nil
					pcall(function() banStore:SetAsync("u_" .. entry.userId, entry) end)
					updateIndex(entry)
				end
			end
		end
	end
end)

-- ===================== dossiers: everything the anti-cheat ever noticed about a player, from every server =====================
local DOSSIER_INCIDENTS = 40

function recordDossier(userId, name, displayName, extra)
	if not dossierStore or not userId or isAdminId(userId) then return end
	local plr = Players:GetPlayerByUserId(userId)
	local st = plr and states[plr]
	local flags = st and st.dossierFlags or nil
	local maxScore = st and st.maxScore or 0
	if st then st.dossierFlags, st.maxScore = nil, 0 end
	local hasFlags = flags and next(flags) ~= nil
	if not hasFlags and not extra then return end
	local summary
	retry(function()
		dossierStore:UpdateAsync("d_" .. userId, function(d)
			d = d or {userId = userId, flags = {}, incidents = {}, bans = {}, servers = {}, totalFlags = 0, firstAt = os.time()}
			d.name = name or d.name
			d.displayName = displayName or d.displayName or d.name
			d.lastAt = os.time()
			for kind, n in pairs(flags or {}) do
				d.flags[kind] = (d.flags[kind] or 0) + n
				d.totalFlags += n
			end
			d.maxScore = math.max(d.maxScore or 0, math.floor(maxScore))
			local server = string.sub(game.JobId ~= "" and game.JobId or "studio", 1, 8)
			if hasFlags and not table.find(d.servers, server) then
				table.insert(d.servers, 1, server)
				while #d.servers > 20 do table.remove(d.servers) end
			end
			if extra and extra.incident then
				table.insert(d.incidents, 1, extra.incident)
				while #d.incidents > DOSSIER_INCIDENTS do table.remove(d.incidents) end
			end
			if extra and extra.ban then
				table.insert(d.bans, 1, extra.ban)
				d.banned = true
			end
			if extra and extra.unban then
				table.insert(d.bans, 1, {at = extra.unban.at, reason = "unbanned", by = extra.unban.by, unban = true})
				d.banned = false
			end
			if extra and extra.kick then
				d.kicks = (d.kicks or 0) + 1
				table.insert(d.bans, 1, {at = extra.kick.at, reason = "kicked: " .. tostring(extra.kick.reason), by = "AntiCheat", kick = true})
			end
			if extra and extra.verdict then
				d.verdicts = d.verdicts or {}
				table.insert(d.verdicts, 1, extra.verdict)
				while #d.verdicts > 20 do table.remove(d.verdicts) end
			end
			while #d.bans > 20 do table.remove(d.bans) end
			local top, topN = nil, 0
			for kind, n in pairs(d.flags) do if n > topN then top, topN = kind, n end end
			summary = {
				userId = userId, name = d.name, displayName = d.displayName, lastAt = d.lastAt, totalFlags = d.totalFlags,
				incidents = #d.incidents, banned = d.banned, topFlag = top, servers = #d.servers, kicks = d.kicks or 0,
			}
			return d
		end)
	end, 3)
	if not summary then return end
	retry(function()
		dossierStore:UpdateAsync("index", function(list)
			list = list or {}
			for i = #list, 1, -1 do
				if list[i].userId == userId then table.remove(list, i) end
			end
			table.insert(list, 1, summary)
			while #list > 500 do table.remove(list) end
			return list
		end)
	end, 3)
end

-- flags pile up in memory and are written every 30 seconds (and when the player leaves)
task.spawn(function()
	while true do
		task.wait(30)
		for plr, st in pairs(states) do
			if st.dossierFlags and next(st.dossierFlags) then
				task.spawn(recordDossier, plr.UserId, plr.Name, plr.DisplayName, nil)
			end
		end
	end
end)

-- ===================== world snapshot for the client lighting check =====================

local function snapshotWorld()
	worldInfo:SetAttribute("ClockTime", Lighting.ClockTime)
	worldInfo:SetAttribute("Brightness", Lighting.Brightness)
	worldInfo:SetAttribute("Ambient", Lighting.Ambient)
	worldInfo:SetAttribute("OutdoorAmbient", Lighting.OutdoorAmbient)
	worldInfo:SetAttribute("GlobalShadows", Lighting.GlobalShadows)
	worldInfo:SetAttribute("FogEnd", Lighting.FogEnd)
	worldInfo:SetAttribute("FogStart", Lighting.FogStart)
	worldInfo:SetAttribute("ExposureCompensation", Lighting.ExposureCompensation)
	worldInfo:SetAttribute("Gravity", workspace.Gravity)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	worldInfo:SetAttribute("AtmosphereDensity", atmosphere and atmosphere.Density or -1)
	worldInfo:SetAttribute("AtmosphereHaze", atmosphere and atmosphere.Haze or -1)
	local names = {}
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then table.insert(names, child.Name) end
	end
	worldInfo:SetAttribute("Effects", table.concat(names, ","))
end

-- ===================== main loop =====================

local accumulator = 0
local worldTimer = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	worldTimer += dt
	if worldTimer >= 0.5 then
		worldTimer = 0
		snapshotWorld()
	end
	if accumulator < CONFIG.SampleInterval then return end
	accumulator = 0
	local now = os.clock()
	recordFrame()
	for player, st in pairs(states) do
		st.score = math.max(0, st.score - CONFIG.ScoreDecayPerSecond * CONFIG.SampleInterval)
		st.evidence = math.max(0, (st.evidence or 0) - CONFIG.ScoreDecayPerSecond * 0.5 * CONFIG.SampleInterval)
		local ok, err = pcall(checkPlayer, player, st, now)
		if not ok then warn("[AntiCheat] " .. tostring(err)) end
		-- the client anti-cheat must keep beating. A phone in the background or a slow load stops everything,
		-- the body too: only a client that keeps moving while its anti-cheat is silent has switched it off.
		if not isAdmin(player) then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local silent = (st.lastBeat and now - st.lastBeat > CONFIG.HeartbeatTimeout)
				or (not st.lastBeat and now - st.joinedAt > CONFIG.FirstHeartbeatTimeout)
			if silent and root then
				if st.silentFrom then
					st.silentMoved = (st.silentMoved or 0) + flat(root.Position - st.silentFrom).Magnitude
				end
				st.silentFrom = root.Position
				if (st.silentMoved or 0) > CONFIG.SilentMoveDistance then
					player:Kick(st.lastBeat and "Anti-cheat stopped responding (AC-01)" or "Anti-cheat did not start (AC-02)")
				end
			else
				st.silentFrom, st.silentMoved = nil, 0
			end
		end
	end
end)

-- ===================== admin =====================

local function readBanIndex()
	local list
	if banStore then pcall(function() list = banStore:GetAsync("index") end) end
	return list or {}
end

local function readIncidentIndex()
	local list
	if incidentStore then pcall(function() list = incidentStore:GetAsync("index") end) end
	list = list or {}
	local seen = {}
	for _, meta in ipairs(list) do seen[meta.id] = true end
	for _, meta in ipairs(incidentIndexCache) do
		if not seen[meta.id] then table.insert(list, 1, meta) end
	end
	return list
end

local ADMIN = {}

-- a player in this server by user id, username or display name
local function findOnline(target)
	local id = tonumber(target)
	if id then return Players:GetPlayerByUserId(id) end
	if typeof(target) ~= "string" or target == "" then return nil end
	local lower = target:lower()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Name:lower() == lower or plr.DisplayName:lower() == lower then return plr end
	end
	return nil
end

function ADMIN.ListBans()
	return true, readBanIndex()
end

function ADMIN.Ban(admin, target, reason, durationText, allDevices)
	local seconds = parseDuration(durationText)
	if not seconds then return false, "bad duration (use 30m, 12h, 7d, 2w or perm)" end
	if typeof(reason) ~= "string" or reason:gsub("%s", "") == "" then reason = "No reason given" end
	local userId, name = tonumber(target), nil
	if not userId then
		if typeof(target) ~= "string" or target == "" then return false, "no target" end
		local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(target) end)
		if not ok or not id then return false, "user not found" end
		userId, name = id, target
	end
	if CONFIG.Admins[userId] then return false, "can't ban an admin" end
	if not name then
		local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		name = ok and n or tostring(userId)
	end
	local entry = ban(userId, name, reason, seconds, allDevices == true, admin.Name, "admin")
	return true, string.format("%s banned for %s", entry.name, formatDuration(seconds))
end

function ADMIN.Unban(admin, target)
	local userId = tonumber(target)
	if not userId and typeof(target) == "string" and target ~= "" then
		local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(target) end)
		if ok then userId = id end
	end
	if not userId then return false, "user not found" end
	local entry, saved = unban(userId, admin.Name)
	if not saved then return false, "could not reach the ban DataStore — try again" end
	local note = entry.robloxUnbanPending
		and (RunService:IsStudio()
			and " in the game's list. Roblox's own ban can't be lifted from Studio: Creator Hub > your game > Moderation > Bans > Unban, or it is lifted by the next live server"
			or " (Roblox-level unban queued)")
		or ""
	return true, (entry.name or tostring(userId)) .. " unbanned" .. note
end

function ADMIN.ListDossiers()
	local list
	if dossierStore then retry(function() list = dossierStore:GetAsync("index") end) end
	return true, list or {}
end

function ADMIN.GetDossier(admin, target)
	local userId = tonumber(target)
	if not userId then return false, "bad user id" end
	for plr, st in pairs(states) do
		if plr.UserId == userId and st.dossierFlags and next(st.dossierFlags) then
			recordDossier(userId, plr.Name, plr.DisplayName, nil)
		end
	end
	local d
	if dossierStore then retry(function() d = dossierStore:GetAsync("d_" .. userId) end) end
	local entry = readBan(userId)
	local online = Players:GetPlayerByUserId(userId)
	local live = online and states[online]
	return true, {
		dossier = d, ban = entry, banActive = banActive(entry) == true,
		online = online ~= nil, liveScore = live and math.floor(live.score) or nil,
	}
end

function ADMIN.Kick(admin, userId, reason)
	local plr = findOnline(userId)
	if not plr then return false, "player is not in this server" end
	plr:Kick(typeof(reason) == "string" and reason ~= "" and reason or "Kicked by an admin")
	return true, plr.Name .. " kicked"
end

function ADMIN.ListIncidents()
	return true, readIncidentIndex()
end

function ADMIN.GetIncident(admin, id)
	if typeof(id) ~= "string" then return false, "bad id" end
	local cached = incidentCache[id]
	if cached then return true, cached end
	local data
	if incidentStore then pcall(function() data = incidentStore:GetAsync("i_" .. id) end) end
	if not data then return false, "incident not found" end
	return true, data
end

function ADMIN.DeleteIncident(admin, id)
	if typeof(id) ~= "string" then return false, "bad id" end
	incidentCache[id] = nil
	for i = #incidentIndexCache, 1, -1 do
		if incidentIndexCache[i].id == id then table.remove(incidentIndexCache, i) end
	end
	if incidentStore then
		pcall(function() incidentStore:RemoveAsync("i_" .. id) end)
		pcall(function()
			incidentStore:UpdateAsync("index", function(list)
				list = list or {}
				for i = #list, 1, -1 do
					if list[i].id == id then table.remove(list, i) end
				end
				return list
			end)
		end)
	end
	return true, "incident deleted"
end

function ADMIN.Record(admin, userId)
	local plr = findOnline(userId)
	if not plr or not states[plr] then return false, "player is not in this server" end
	createIncident(plr, "manual recording by " .. admin.Name, "recorded")
	return true, "recording saved in " .. CONFIG.ReplayAfter .. "s"
end

function ADMIN.Punish(admin, userId)
	local plr = findOnline(userId)
	if not plr or not states[plr] then return false, "player is not in this server" end
	if isAdmin(plr) then return false, "can't punish an admin" end
	punish(plr, "manual by " .. admin.Name)
	return true, plr.Name .. " is being punished"
end

-- name suggestions while typing: online players, everyone seen before, ban records, then Roblox itself
function ADMIN.SearchUsers(admin, query)
	if typeof(query) ~= "string" then return false, "bad query" end
	query = query:gsub("^%s+", ""):gsub("%s+$", "")
	if query == "" then return true, {} end
	local lower = query:lower()
	local results, seen = {}, {}
	local function consider(userId, name, displayName, source)
		if not userId or seen[userId] then return end
		local n, d = tostring(name or ""):lower(), tostring(displayName or ""):lower()
		local score
		if n == lower or tostring(userId) == query then score = 5
		elseif n:sub(1, #lower) == lower then score = 4
		elseif d:sub(1, #lower) == lower then score = 3
		elseif n:find(lower, 1, true) or d:find(lower, 1, true) then score = 2
		elseif tostring(userId):sub(1, #query) == query then score = 1 end
		if not score then return end
		if source == "online" then score += 0.5 end
		seen[userId] = true
		table.insert(results, {userId = userId, name = name, displayName = displayName, source = source, score = score})
	end
	for _, plr in ipairs(Players:GetPlayers()) do consider(plr.UserId, plr.Name, plr.DisplayName, "online") end
	for _, entry in ipairs(seenPlayers()) do consider(entry.userId, entry.name, entry.displayName, "seen") end
	for _, entry in ipairs(readBanIndex()) do consider(entry.userId, entry.name, entry.name, "banned") end
	if #results < 8 and #query >= 3 then
		pcall(function()
			local url = string.format(CONFIG.UserSearchApi, HttpService:UrlEncode(query))
			local data = HttpService:JSONDecode(HttpService:GetAsync(url))
			for _, user in ipairs(data.data or {}) do consider(user.id, user.name, user.displayName, "roblox") end
		end)
		if not seen[query] then
			local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(query) end)
			if ok and id then consider(id, query, query, "roblox") end
		end
	end
	table.sort(results, function(a, b) return a.score > b.score end)
	while #results > 8 do table.remove(results) end
	return true, results
end

local function updateIncidentMeta(id, fields)
	local function apply(meta)
		if meta and meta.id == id then
			for k, v in pairs(fields) do meta[k] = v end
		end
	end
	local cached = incidentCache[id]
	if cached then apply(cached.meta) end
	for _, meta in ipairs(incidentIndexCache) do apply(meta) end
	if not incidentStore then return end
	pcall(function()
		incidentStore:UpdateAsync("i_" .. id, function(data)
			if data then apply(data.meta) end
			return data
		end)
	end)
	pcall(function()
		incidentStore:UpdateAsync("index", function(list)
			for _, meta in ipairs(list or {}) do apply(meta) end
			return list
		end)
	end)
end

local function findIncidentMeta(id)
	local cached = incidentCache[id]
	if cached then return cached.meta end
	for _, meta in ipairs(readIncidentIndex()) do
		if meta.id == id then return meta end
	end
	return nil
end

-- the admin watched the replay and decided
function ADMIN.Verdict(admin, id, verdict)
	if typeof(id) ~= "string" then return false, "bad id" end
	local meta = findIncidentMeta(id)
	if not meta then return false, "incident not found" end
	if recordDossier then
		task.spawn(recordDossier, meta.userId, nil, nil, {verdict = {id = id, verdict = verdict, by = admin.Name, at = os.time()}})
	end
	if verdict == "cheat" then
		ban(meta.userId, meta.name, "Cheating (confirmed on replay)", -1, true, admin.Name, "admin", id)
		updateIncidentMeta(id, {verdict = "cheat", verdictBy = admin.Name})
		return true, meta.name .. ": permanent ban on all devices"
	elseif verdict == "legit" then
		local plr = Players:GetPlayerByUserId(meta.userId)
		local st = plr and states[plr]
		if st then
			-- stop a punishment that is still running and undo it
			st.punishToken = nil
			st.punishing = false
			st.banned = false
			st.doBan = nil
			st.score = 0
			st.flagCounts = {}
			st.trusted = true
			plr:SetAttribute("AC_Punished", nil)
			local character = plr.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				character:SetAttribute("Lobotomized", false)
				character:SetAttribute("Injury_Torso", 0)
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
			end
		end
		local entry
		if banStore then pcall(function() entry = banStore:GetAsync("u_" .. meta.userId) end) end
		if banActive(entry) and entry.source == "anticheat" then unban(meta.userId, admin.Name) end
		updateIncidentMeta(id, {verdict = "legit", verdictBy = admin.Name})
		return true, meta.name .. " cleared as legit" .. (st and " and released" or "")
	end
	return false, "bad verdict"
end

local lastAdminCall = {}
adminRemote.OnServerInvoke = function(player, action, ...)
	if not isAdmin(player) then
		flag(player, "remoteabuse", "ACAdmin")
		return false, "not an admin"
	end
	local now = os.clock()
	if now - (lastAdminCall[player] or 0) < 0.2 then return false, "slow down" end
	lastAdminCall[player] = now
	local handler = typeof(action) == "string" and ADMIN[action]
	if not handler then return false, "unknown action" end
	local ok, result, payload = pcall(handler, player, ...)
	if not ok then return false, "error: " .. tostring(result) end
	return result, payload
end
Players.PlayerRemoving:Connect(function(player) lastAdminCall[player] = nil end)
]=]},
	{name = "CombatFX", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- Combat effects, drawn on every client:
--   * creature blood by kind: black (almost everything), green goo (the spiders), acid (C-310)
--   * limbs coming off, stumps bubbling while they grow back (A-013), bodies dropping into a pool
--   * spiders bursting: a green splash where they died, the legs left twitching on the floor for a while
--   * C-310: the gurgle before it spits, the arc of the spit, acid puddles, and the splash on your own screen
--   * items: armor breaking into bits, putting things on and taking them off, traps, heals (sounds for everyone)
--   * a thin health bar over a creature for a moment after it's hit
--   * your own state: caught in a web (getting up, with a timer), leg in a trap, acid fumes, shocked
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local GameSettings = require(Modules:WaitForChild("GameSettings"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.SpecialElite
local INK = Color3.fromRGB(236, 230, 222)
local DIM = Color3.fromRGB(120, 112, 106)
local LINE = Color3.fromRGB(70, 60, 56)
local PANEL = Color3.fromRGB(8, 6, 6)
local BRIGHT = Color3.fromRGB(225, 40, 40)
local AMBER = Color3.fromRGB(232, 164, 52)
local ACID_UI = Color3.fromRGB(170, 214, 60)

-- blood by kind: {main, dark, reflectance, glow}
local PALETTES = {
	black = {Color3.fromRGB(18, 14, 16), Color3.fromRGB(3, 2, 3), 0.14},
	green = {Color3.fromRGB(108, 172, 38), Color3.fromRGB(46, 90, 16), 0.2},
	acid = {Color3.fromRGB(190, 230, 56), Color3.fromRGB(118, 158, 26), 0.25, true},
	red = {Color3.fromRGB(92, 4, 4), Color3.fromRGB(55, 2, 2), 0.05},
}
local function paletteOf(kind) return PALETTES[kind or "black"] or PALETTES.black end

local CHITIN = Color3.fromRGB(30, 23, 21)
local JOINT = Color3.fromRGB(58, 42, 36)

local rng = Random.new()
local function now() return workspace:GetServerTimeNow() end
local function low() return GameSettings.Get("LowGraphics") == true end

local function create(className, props, children)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	return obj
end
local function tween(obj, t, goal, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local fxFolder = workspace:FindFirstChild("GS_FX") or create("Folder", {Name = "GS_FX", Parent = workspace})
local gooFolder = create("Folder", {Name = "GS_Goo", Parent = fxFolder})

-- ===== sounds (Roblox's public library, see ItemData.Sounds) =====
local function sound(name, parent, volume, speed, maxDist)
	local id = ItemData.Sound(name)
	if not id or not parent then return nil end
	local s = create("Sound", {
		SoundId = id, Volume = volume or 0.7, PlaybackSpeed = speed or 1, RollOffMaxDistance = maxDist or 200,
		RollOffMinDistance = 8, Parent = parent,
	})
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	Debris:AddItem(s, 10)
	return s
end
local function anchorAt(position, life)
	local p = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Parent = fxFolder,
	})
	Debris:AddItem(p, life or 6)
	return p
end
local function soundAt(name, position, volume, speed, maxDist)
	if typeof(position) ~= "Vector3" then return end
	sound(name, anchorAt(position), volume, speed, maxDist)
end

-- ===== droplets and stains =====
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
params.RespectCanCollide = true
local function refreshFilter()
	local list = {fxFolder}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(list, plr.Character) end
	end
	for _, name in ipairs({"Monsters", "NPCs", "GS_Gibs", "PS_Blood", "GS_Items", "GS_Traps", "SpiderWebs", "GS_SpiderLegs", "GS_Tentacles"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(list, f) end
	end
	params.FilterDescendantsInstances = list
end
refreshFilter()
task.spawn(function()
	while true do
		task.wait(2)
		refreshFilter()
	end
end)

local function newPart(size, color, reflect)
	return create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.SmoothPlastic, Color = color, Size = size, Reflectance = reflect or 0,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
	})
end

local splats = {}
local function maxSplats() return low() and 60 or 180 end
local function addSplat(position, normal, diameter, grow, pal, life)
	while #splats >= maxSplats() do
		local old = table.remove(splats, 1)
		if old.Parent then old:Destroy() end
	end
	local up = normal.Unit
	local tangent = up:Cross(Vector3.new(0, 1, 0))
	if tangent.Magnitude < 0.1 then tangent = up:Cross(Vector3.new(1, 0, 0)) end
	tangent = tangent.Unit
	local cf = CFrame.fromMatrix(position + up * 0.035, up, tangent) * CFrame.Angles(rng:NextNumber(0, math.pi * 2), 0, 0)
	local splat = newPart(Vector3.new(0.04, 0.2, 0.2), pal[1]:Lerp(pal[2], rng:NextNumber(0, 0.6)), pal[3])
	splat.Shape = Enum.PartType.Cylinder
	splat.CFrame = cf
	splat.Parent = gooFolder
	table.insert(splats, splat)
	tween(splat, grow or 0.25, {Size = Vector3.new(0.04, diameter, diameter * rng:NextNumber(0.75, 1.1))})
	task.delay(life or 50, function()
		if splat.Parent then
			tween(splat, 4, {Transparency = 1}).Completed:Wait()
			splat:Destroy()
		end
	end)
	return splat
end

local function addPool(position, size, time, pal, life)
	local hit = workspace:Raycast(position + Vector3.new(0, 1.5, 0), Vector3.new(0, -9, 0), params)
	if not hit then return end
	for i = 1, 5 do
		local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size * 0.25
		task.delay((i - 1) * 0.15, function()
			addSplat(hit.Position + offset, hit.Normal, size * rng:NextNumber(0.5, 0.9), time, pal, life)
		end)
	end
end

local droplets = {}
local function maxDroplets() return low() and 70 or 240 end
local function spawnDroplets(origin, count, speed, spread, bias, pal)
	if typeof(origin) ~= "Vector3" then return end
	if low() then count = math.ceil(count * 0.4) end
	for _ = 1, count do
		if #droplets >= maxDroplets() then break end
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1))
		if bias then dir += bias end
		if dir.Magnitude < 1e-3 then dir = Vector3.new(0, 1, 0) end
		dir = dir.Unit
		local size = rng:NextNumber(0.12, 0.3)
		local drop = newPart(Vector3.new(size, size, size), pal[1], pal[3])
		drop.Shape = Enum.PartType.Ball
		if pal[4] then drop.Material = Enum.Material.Neon drop.Transparency = 0.25 end
		drop.Position = origin
		drop.Parent = fxFolder
		table.insert(droplets, {
			part = drop, position = origin, life = 0, size = size, pal = pal,
			velocity = dir * speed * rng:NextNumber(0.4, 1) + Vector3.new(0, rng:NextNumber(0, spread), 0),
		})
	end
end

RunService.Heartbeat:Connect(function(dt)
	for i = #droplets, 1, -1 do
		local d = droplets[i]
		d.life += dt
		local newVelocity = d.velocity + Vector3.new(0, -workspace.Gravity * 0.8, 0) * dt
		local step = (d.velocity + newVelocity) * 0.5 * dt
		local hit = workspace:Raycast(d.position, step, params)
		if hit then
			addSplat(hit.Position, hit.Normal, d.size * rng:NextNumber(3, 6), 0.15, d.pal)
			d.part:Destroy()
			table.remove(droplets, i)
		elseif d.life > 4 then
			d.part:Destroy()
			table.remove(droplets, i)
		else
			d.velocity = newVelocity
			d.position += step
			d.part.CFrame = CFrame.lookAt(d.position, d.position + newVelocity)
			local stretch = math.clamp(newVelocity.Magnitude / 40, 1, 2.5)
			d.part.Size = Vector3.new(d.size, d.size, d.size * stretch)
			local shape = stretch > 1.2 and Enum.PartType.Block or Enum.PartType.Ball
			if d.part.Shape ~= shape then d.part.Shape = shape end
		end
	end
end)

-- a stream of drops out of a wound for a while
local function spurt(part, localOffset, duration, perTick, pal, bias)
	if not part or not part.Parent then return end
	task.spawn(function()
		local t = 0
		while t < duration and part.Parent do
			local cf = part.CFrame
			spawnDroplets(cf:PointToWorldSpace(localOffset), perTick, 8, 3, bias or cf.UpVector * 0.5, pal)
			task.wait(0.12)
			t += 0.12
		end
	end)
end

-- swelling bubbles that pop (stumps growing back, acid puddles)
local function bubble(position, size, pal, life)
	local b = newPart(Vector3.one * 0.05, pal[1]:Lerp(pal[2], rng:NextNumber()), 0.3)
	b.Shape = Enum.PartType.Ball
	if pal[4] then b.Material = Enum.Material.Neon b.Transparency = 0.3 end
	b.Position = position
	b.Parent = fxFolder
	tween(b, life or 0.6, {Size = Vector3.one * size, Position = position + Vector3.new(0, size * 0.4, 0)}, Enum.EasingStyle.Sine)
	task.delay(life or 0.6, function()
		if not b.Parent then return end
		b:Destroy()
		if rng:NextNumber() < 0.5 then spawnDroplets(position + Vector3.new(0, size * 0.4, 0), 2, 3, 2, nil, pal) end
	end)
end

-- ===== the screen =====
local screen = create("ScreenGui", {Name = "GS_CombatScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 27, Parent = playerGui})
local tint = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = ACID_UI, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = screen})
-- green creeping in from the edges (fumes): two soft bands, faded together
local vignette = create("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Parent = screen})
for _, rotation in ipairs({0, 90}) do
	create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 130, 18), BorderSizePixel = 0, Parent = vignette}, {
		create("UIGradient", {
			Rotation = rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.22, 1), NumberSequenceKeypoint.new(0.78, 1), NumberSequenceKeypoint.new(1, 0.1),
			}),
		}),
	})
end
local flashFrame = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(210, 230, 255), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = screen})

-- goo on the lens: blobs that slide down slowly and fade (acid, spider goo)
local function screenGoo(count, pal, sizeScale, life)
	for _ = 1, count do
		local x = rng:NextNumber(0.08, 0.92)
		local y = rng:NextNumber(0.05, 0.75)
		local size = rng:NextInteger(70, 200) * (sizeScale or 1)
		local color = pal[1]:Lerp(pal[2], rng:NextNumber(0, 0.5))
		local blob = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(size, size * rng:NextNumber(0.7, 1.25)),
			Rotation = rng:NextNumber(0, 360), BackgroundColor3 = color, BackgroundTransparency = 0.12, BorderSizePixel = 0, Parent = screen,
		}, {
			create("UICorner", {CornerRadius = UDim.new(1, 0)}),
			create("UIGradient", {
				Rotation = rng:NextNumber(0, 360),
				Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.2), NumberSequenceKeypoint.new(1, 0.85)}),
			}),
		})
		-- a glossy highlight so it reads as wet
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.35, 0.32), Size = UDim2.fromScale(0.22, 0.14),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = blob,
		}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
		-- runs: a couple of drips hanging off the bottom
		for _ = 1, rng:NextInteger(1, 3) do
			local drip = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(rng:NextNumber(0.3, 0.7), 0.75), Size = UDim2.new(0, rng:NextInteger(8, 16), 0, 0),
				BackgroundColor3 = color, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = blob,
			}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
			tween(drip, rng:NextNumber(2.5, 5), {Size = UDim2.new(0, drip.Size.X.Offset, 0, rng:NextInteger(40, 140))}, Enum.EasingStyle.Sine)
		end
		local lifeNow = (life or 6) * rng:NextNumber(0.8, 1.2)
		tween(blob, lifeNow, {Position = UDim2.fromScale(x, y + rng:NextNumber(0.04, 0.14))}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		task.delay(lifeNow * 0.6, function()
			for _, d in ipairs(blob:GetDescendants()) do
				if d:IsA("Frame") then tween(d, lifeNow * 0.4, {BackgroundTransparency = 1}) end
			end
			tween(blob, lifeNow * 0.4, {BackgroundTransparency = 1})
		end)
		Debris:AddItem(blob, lifeNow + 0.2)
	end
end

-- the status card: web, trap, fumes (middle, a little below the crosshair)
local card = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(280, 58),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false, Parent = screen,
}, {create("UIStroke", {Color = LINE, Thickness = 1})})
local cardTitle = create("TextLabel", {
	Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18), BackgroundTransparency = 1, Font = FONT, TextSize = 16,
	TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = card,
})
local cardTime = create("TextLabel", {
	Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18), BackgroundTransparency = 1, Font = FONT, TextSize = 16,
	TextColor3 = AMBER, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = card,
})
local cardHint = create("TextLabel", {
	Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -24, 0, 14), BackgroundTransparency = 1, Font = FONT, TextSize = 12,
	TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = card,
})
local barBack = create("Frame", {
	Position = UDim2.new(0, 12, 1, -12), Size = UDim2.new(1, -24, 0, 4), BackgroundColor3 = Color3.fromRGB(30, 24, 22), BorderSizePixel = 0, Parent = card,
})
local barFill = create("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = AMBER, BorderSizePixel = 0, Parent = barBack})

local notice = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, -30), Size = UDim2.fromOffset(460, 22),
	BackgroundTransparency = 1, Font = FONT, TextSize = 18, TextColor3 = BRIGHT, TextStrokeTransparency = 0.4, TextTransparency = 1, Text = "", Parent = screen,
})
local noticeToken = 0
local function say(text, color)
	noticeToken += 1
	local my = noticeToken
	notice.Text = text
	notice.TextColor3 = color or BRIGHT
	notice.TextTransparency = 0
	task.delay(2.2, function()
		if my == noticeToken then tween(notice, 0.6, {TextTransparency = 1}) end
	end)
end

local function flash(color, strength, t)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - (strength or 0.5)
	tween(flashFrame, t or 0.35, {BackgroundTransparency = 1})
end

-- ===== creature health bars (a moment after each hit) =====
local bars = {}
local function showBar(model)
	if typeof(model) ~= "Instance" or not model.Parent then return end
	local maxHp = model:GetAttribute("GS_MaxHP")
	if not maxHp then return end
	local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not head then return end
	local entry = bars[model]
	if not entry or not entry.gui.Parent then
		local gui = create("BillboardGui", {
			Name = "GS_HPBar", Size = UDim2.fromOffset(90, 8), StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0), AlwaysOnTop = false,
			LightInfluence = 0, MaxDistance = 90, Adornee = head, Parent = fxFolder,
		})
		local back = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = PANEL, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = gui},
			{create("UIStroke", {Color = LINE, Thickness = 1})})
		local lag = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 100, 90), BorderSizePixel = 0, Parent = back})
		local fill = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BRIGHT, BorderSizePixel = 0, Parent = back})
		entry = {gui = gui, back = back, fill = fill, lag = lag, token = 0}
		bars[model] = entry
	end
	entry.token += 1
	local my = entry.token
	local hp = math.max(0, model:GetAttribute("GS_HP") or maxHp)
	local frac = math.clamp(hp / maxHp, 0, 1)
	entry.gui.Enabled = true
	entry.back.BackgroundTransparency = 0.2
	entry.fill.BackgroundTransparency = 0
	entry.lag.BackgroundTransparency = 0
	entry.fill.Size = UDim2.fromScale(frac, 1)
	tween(entry.lag, 0.6, {Size = UDim2.fromScale(frac, 1)})
	task.delay(3, function()
		if entry.token ~= my or not entry.gui.Parent then return end
		for _, f in ipairs({entry.back, entry.fill, entry.lag}) do tween(f, 0.6, {BackgroundTransparency = 1}) end
		task.delay(0.65, function() if entry.token == my then entry.gui.Enabled = false end end)
	end)
end
local function dropBar(model)
	local entry = bars[model]
	if entry then
		entry.gui:Destroy()
		bars[model] = nil
	end
end

-- ===== spider remains =====
local function segment(a, b, width, color)
	local length = math.max((b - a).Magnitude, 0.05)
	local p = create("Part", {
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate, Color = color, Size = Vector3.new(length, width, width),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		CanCollide = true, CanQuery = false, CanTouch = false, CastShadow = true,
	})
	return p
end
local function ball(position, size, color, material)
	return create("Part", {
		Shape = Enum.PartType.Ball, Material = material or Enum.Material.Slate, Color = color, Size = Vector3.one * size,
		CFrame = CFrame.new(position), CanCollide = false, CanQuery = false, CanTouch = false, Massless = true,
	})
end

-- a torn-off leg: flies out, lands, twitches for a bit, lies there, then fades
local function deadLeg(hip, center, scale, stay)
	local out = hip - center
	out = Vector3.new(out.X, 0, out.Z)
	out = out.Magnitude > 0.05 and out.Unit or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
	local up = Vector3.yAxis
	local upperLen, lowerLen = 2.1 * scale, 2.6 * scale
	local knee = hip + out * upperLen * 0.7 + up * upperLen * 0.6
	local foot = knee + out * lowerLen * 0.5 - up * lowerLen * 0.85
	local model = create("Model", {Name = "GS_SpiderLeg"})
	local upper = segment(hip, knee, 0.22 * scale, CHITIN)
	local lower = segment(knee, foot, 0.15 * scale, CHITIN)
	upper.Parent, lower.Parent = model, model
	local kneeBall = ball(knee, 0.3 * scale, JOINT)
	local tip = ball(foot, 0.16 * scale, JOINT)
	local torn = ball(hip, 0.26 * scale, PALETTES.green[1], Enum.Material.SmoothPlastic) -- the wet torn end
	for _, p in ipairs({kneeBall, tip, torn}) do p.Parent = model end
	for _, p in ipairs({lower, kneeBall, tip, torn}) do
		create("WeldConstraint", {Part0 = upper, Part1 = p, Parent = p})
	end
	model.PrimaryPart = upper
	model.Parent = gooFolder
	upper.AssemblyLinearVelocity = out * rng:NextNumber(12, 26) * math.sqrt(scale) + up * rng:NextNumber(14, 26)
	upper.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 14
	task.spawn(function()
		-- a dribble of goo while it flies
		for _ = 1, 6 do
			task.wait(0.12)
			if not torn.Parent then return end
			spawnDroplets(torn.Position, 1, 3, 1, nil, PALETTES.green)
		end
		task.wait(0.9)
		if not upper.Parent then return end
		-- settled: pin it down (no tripping over it), then the last twitches
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false end
		end
		local base = model:GetPivot()
		local pivotAt = torn.Position
		local t0 = os.clock()
		local twitchFor = rng:NextNumber(3, 7)
		while os.clock() - t0 < twitchFor and model.Parent do
			local fade = 1 - (os.clock() - t0) / twitchFor
			local jerk = rng:NextNumber() < 0.35 and rng:NextNumber(-1, 1) * math.rad(14) * fade or 0
			if jerk ~= 0 then
				local around = CFrame.new(pivotAt) * CFrame.Angles(0, 0, jerk) * CFrame.Angles(jerk * 0.5, 0, 0) * CFrame.new(-pivotAt)
				model:PivotTo(around * base)
				task.wait(0.06)
				model:PivotTo(base)
			end
			task.wait(rng:NextNumber(0.15, 0.6))
		end
		task.wait(stay)
		if not model.Parent then return end
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then tween(p, 2, {Transparency = 1}) end
		end
		task.wait(2.1)
		model:Destroy()
	end)
end

local function spiderBurst(position, legs, scale, mother)
	scale = tonumber(scale) or 1
	local pal = PALETTES.green
	local anchor = anchorAt(position, 8)
	sound("Splat", anchor, mother and 1 or 0.8, mother and 0.7 or 1, 160)
	sound("Explosion", anchor, mother and 0.55 or 0.25, mother and 1.1 or 1.7, mother and 220 or 120)
	sound("Flesh", anchor, 0.7, 0.8, 120)
	-- the pop: a wet green ball swelling and gone
	local pop = ball(position, 0.5 * scale, pal[1], Enum.Material.SmoothPlastic)
	pop.Anchored = true
	pop.Transparency = 0.2
	pop.Parent = fxFolder
	tween(pop, 0.18, {Size = Vector3.one * (mother and 9 or 4) * scale, Transparency = 1})
	Debris:AddItem(pop, 0.3)
	spawnDroplets(position, mother and 150 or 70, (mother and 30 or 22) * math.sqrt(scale), 14, Vector3.new(0, 0.6, 0), pal)
	-- the goo where it burst
	task.delay(0.25, function()
		addPool(position, (mother and 8 or 3.6) * scale, 1.4, pal, 70)
		local hit = workspace:Raycast(position + Vector3.new(0, 1.5, 0), Vector3.new(0, -9, 0), params)
		if hit then
			for _ = 1, mother and 12 or 6 do
				local r = rng:NextNumber(1, (mother and 7 or 3.5) * scale)
				local a = rng:NextNumber(0, math.pi * 2)
				local spot = hit.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				local down = workspace:Raycast(spot + Vector3.new(0, 2, 0), Vector3.new(0, -5, 0), params)
				if down then addSplat(down.Position, down.Normal, rng:NextNumber(0.6, 1.8) * scale, 0.4, pal, 70) end
			end
			-- it keeps bubbling a little
			task.spawn(function()
				for _ = 1, mother and 18 or 8 do
					task.wait(rng:NextNumber(0.2, 0.5))
					local o = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 1.5 * scale
					bubble(hit.Position + o, rng:NextNumber(0.2, 0.45) * scale, pal, 0.7)
				end
			end)
		end
	end)
	if typeof(legs) == "table" then
		for _, hip in ipairs(legs) do
			if typeof(hip) == "Vector3" then deadLeg(hip, position, scale, mother and 26 or 16) end
		end
	end
	-- too close: some of it lands on you
	local head = player.Character and player.Character:FindFirstChild("Head")
	if head and (head.Position - position).Magnitude < (mother and 14 or 7) * scale then
		screenGoo(mother and 6 or 3, pal, 0.9, 5)
	end
end

-- ===== C-310's spit =====
local spitParams = RaycastParams.new()
spitParams.FilterType = Enum.RaycastFilterType.Exclude
spitParams.IgnoreWater = true
local function spitFlight(origin, velocity, gravity, t0)
	if typeof(origin) ~= "Vector3" or typeof(velocity) ~= "Vector3" then return end
	gravity = tonumber(gravity) or 40
	local pal = PALETTES.acid
	local g = Vector3.new(0, -gravity, 0)
	-- catch up with the server: it left a moment ago
	local late = math.clamp(now() - (tonumber(t0) or now()), 0, 0.4)
	local pos = origin + velocity * late + 0.5 * g * late * late
	local vel = velocity + g * late
	local blob = create("Part", {
		Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = pal[1], Transparency = 0.1, Size = Vector3.one * 0.7,
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, CFrame = CFrame.new(pos), Parent = fxFolder,
	})
	local a0 = create("Attachment", {Position = Vector3.new(0, 0.25, 0), Parent = blob})
	local a1 = create("Attachment", {Position = Vector3.new(0, -0.25, 0), Parent = blob})
	create("Trail", {
		Attachment0 = a0, Attachment1 = a1, Lifetime = 0.25, LightEmission = 0.4, FaceCamera = true,
		Color = ColorSequence.new(pal[1], pal[2]), Transparency = NumberSequence.new(0.2, 1),
		WidthScale = NumberSequence.new(1, 0.2), Parent = blob,
	})
	create("PointLight", {Color = pal[1], Range = 7, Brightness = 1.2, Parent = blob})
	-- (unlike the stains, the spit stops on people: the server's arc does too)
	spitParams.FilterDescendantsInstances = {fxFolder, workspace:FindFirstChild("Monsters")}
	local elapsed = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local newVel = vel + g * dt
		local step = (vel + newVel) * 0.5 * dt
		local hit = workspace:Raycast(pos, step, spitParams)
		if hit or elapsed > 3 then
			conn:Disconnect()
			blob:Destroy()
			return
		end
		pos += step
		vel = newVel
		local wobble = 1 + math.sin(elapsed * 30) * 0.12
		blob.Size = Vector3.new(0.7 * wobble, 0.7 / wobble, 0.7 * wobble)
		blob.CFrame = CFrame.lookAt(pos, pos + vel)
		if rng:NextNumber() < 0.25 then spawnDroplets(pos, 1, 1, 0.5, nil, pal) end
	end)
end

-- a puddle of acid: hisses, bubbles, glows faintly, then dries up
local function acidPuddle(position, life, radius)
	if typeof(position) ~= "Vector3" then return end
	life = tonumber(life) or 7
	radius = tonumber(radius) or 3
	local pal = PALETTES.acid
	local puddle = newPart(Vector3.new(0.05, 0.3, 0.3), pal[1], 0.2)
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Material = Enum.Material.Neon
	puddle.Transparency = 0.45
	puddle.CFrame = CFrame.new(position + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90))
	puddle.Parent = fxFolder
	local rim = newPart(Vector3.new(0.04, 0.3, 0.3), pal[2], 0.1)
	rim.Shape = Enum.PartType.Cylinder
	rim.CFrame = CFrame.new(position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
	rim.Parent = fxFolder
	tween(puddle, 0.5, {Size = Vector3.new(0.05, radius * 1.8, radius * 1.7)})
	tween(rim, 0.6, {Size = Vector3.new(0.04, radius * 2.1, radius * 2)})
	local light = create("PointLight", {Color = pal[1], Range = radius * 2.5, Brightness = 0.6, Parent = puddle})
	local hiss = create("Sound", {
		SoundId = ItemData.Sound("Sizzle") or "", Volume = 0.45, Looped = true, RollOffMaxDistance = 60, RollOffMinDistance = 5,
		PlaybackSpeed = rng:NextNumber(0.9, 1.1), Parent = puddle,
	})
	hiss:Play()
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < life and puddle.Parent do
			local r = rng:NextNumber(0, radius * 0.8)
			local a = rng:NextNumber(0, math.pi * 2)
			bubble(position + Vector3.new(math.cos(a) * r, 0.05, math.sin(a) * r), rng:NextNumber(0.15, 0.4), pal, 0.5)
			task.wait(low() and 0.45 or 0.18)
		end
		if not puddle.Parent then return end
		tween(hiss, 1.2, {Volume = 0})
		tween(light, 1.5, {Brightness = 0})
		tween(puddle, 1.5, {Transparency = 1, Size = Vector3.new(0.05, radius * 1.2, radius * 1.1)})
		tween(rim, 1.8, {Transparency = 1})
		task.wait(1.9)
		puddle:Destroy()
		rim:Destroy()
	end)
end

-- ===== creature events =====
local hitRemote = ReplicatedStorage:WaitForChild("GS_MonsterHit", 60)
if hitRemote then
	hitRemote.OnClientEvent:Connect(function(kind, a, b, c, d, e)
		if kind == "hit" then
			local model, position, blood, amount = a, b, c, tonumber(d) or 10
			if typeof(position) ~= "Vector3" then return end
			local pal = paletteOf(blood)
			spawnDroplets(position, math.clamp(math.floor(amount * 0.7), 4, 28), 8 + math.min(amount, 60) * 0.18, 5, nil, pal)
			soundAt("BloodHit", position, 0.45, rng:NextNumber(0.85, 1.1), 70)
			if amount >= 25 then
				task.delay(0.3, function() addPool(position, math.clamp(amount / 22, 1, 2.6), 1, pal) end)
			end
			showBar(model)
		elseif kind == "sever" then
			local model, position, blood, limbName = a, b, c, d
			if typeof(position) ~= "Vector3" then return end
			local pal = paletteOf(blood)
			spawnDroplets(position, 55, 20, 9, nil, pal)
			soundAt("Bone", position, 0.8, rng:NextNumber(0.8, 0.95), 120)
			soundAt("Flesh", position, 0.8, 0.9, 120)
			task.delay(0.4, function() addPool(position, 3, 2, pal) end)
			-- the stump pumps for a while
			local torso = typeof(model) == "Instance" and model:FindFirstChild("Torso")
			if torso then
				local offset = torso.CFrame:PointToObjectSpace(position)
				offset = Vector3.new(math.clamp(offset.X, -1.2, 1.2), math.clamp(offset.Y, -1.2, 1.2), 0)
				spurt(torso, offset, limbName == "Head" and 6 or 4, 2, pal)
			end
			-- and so does the piece that came off
			task.delay(0.15, function()
				local gibs = workspace:FindFirstChild("GS_Gibs")
				local best, bestD = nil, 12
				for _, holder in ipairs(gibs and gibs:GetChildren() or {}) do
					if holder.Name == "GS_Limb_" .. tostring(limbName) then
						local part = holder:FindFirstChild(tostring(limbName))
						if part and (part.Position - position).Magnitude < bestD then best, bestD = part, (part.Position - position).Magnitude end
					end
				end
				if best then spurt(best, Vector3.new(0, best.Size.Y * 0.45, 0), 3, 1, pal) end
			end)
		elseif kind == "regrow" then
			local position = b
			if typeof(position) ~= "Vector3" then return end
			local pal = PALETTES.black
			soundAt("Flesh", position, 0.8, 0.6, 90)
			task.delay(0.35, function() soundAt("Bone", position, 0.5, 0.7, 70) end)
			for i = 1, 10 do
				task.delay(i * 0.07, function()
					local o = Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6))
					bubble(position + o, rng:NextNumber(0.3, 0.6), pal, 0.45)
				end)
			end
			spawnDroplets(position, 16, 7, 4, nil, pal)
		elseif kind == "immune" then
			local position = b
			if typeof(position) ~= "Vector3" then return end
			soundAt("MetalHit", position, 0.35, rng:NextNumber(1.3, 1.6), 80)
			-- the round just flattens on it: a puff of grit
			for _ = 1, 6 do
				local bit = newPart(Vector3.one * 0.12, Color3.fromRGB(70, 66, 62), 0)
				bit.Position = position
				bit.Parent = fxFolder
				local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)).Unit
				tween(bit, 0.35, {Position = position + dir * rng:NextNumber(0.8, 1.8), Transparency = 1})
				Debris:AddItem(bit, 0.4)
			end
		elseif kind == "death" then
			local model, position, blood = a, b, c
			if typeof(position) ~= "Vector3" then return end
			local pal = paletteOf(blood)
			soundAt("Flesh", position, 0.9, 0.75, 140)
			spawnDroplets(position, 40, 12, 7, nil, pal)
			task.delay(1.2, function() addPool(position, 5.5, 5, pal, 70) end)
			dropBar(model)
		elseif kind == "spiderdeath" then
			local model, position, legs, scale, mother = a, b, c, d, e
			if typeof(position) ~= "Vector3" then return end
			dropBar(model)
			spiderBurst(position, legs, scale, mother == true)
		elseif kind == "spitwindup" then
			local model = a
			local head = typeof(model) == "Instance" and model:FindFirstChild("Head")
			if not head then return end
			sound("Flesh", head, 0.8, 0.5, 90)
			local glow = create("PointLight", {Color = PALETTES.acid[1], Range = 6, Brightness = 0, Parent = head})
			tween(glow, 0.5, {Brightness = 2.2})
			Debris:AddItem(glow, 0.7)
			for i = 1, 4 do
				task.delay(i * 0.1, function()
					if head.Parent then spawnDroplets(head.Position - Vector3.new(0, 0.4, 0), 1, 1.5, 0.5, Vector3.new(0, -1, 0), PALETTES.acid) end
				end)
			end
		elseif kind == "spit" then
			local model, origin, velocity, gravity, t0 = a, b, c, d, e
			local head = typeof(model) == "Instance" and model:FindFirstChild("Head")
			if head then
				sound("Spray", head, 0.5, 1.4, 100)
				sound("Flesh", head, 0.6, 1.3, 100)
			end
			spitFlight(origin, velocity, gravity, t0)
		elseif kind == "spitsplat" then
			local position, normal = a, b
			if typeof(position) ~= "Vector3" then return end
			normal = typeof(normal) == "Vector3" and normal or Vector3.yAxis
			local pal = PALETTES.acid
			soundAt("Splat", position, 0.7, 1.1, 110)
			soundAt("Sizzle", position, 0.6, 1.2, 70)
			spawnDroplets(position + normal * 0.2, 26, 12, 5, normal * 0.8, pal)
			addSplat(position, normal, rng:NextNumber(1.6, 2.4), 0.2, pal, 20)
		elseif kind == "acidpuddle" then
			acidPuddle(a, b, c)
		elseif kind == "acidscreen" then
			-- a direct hit, on my own face
			local filtered = b == true
			if filtered then
				-- the mask's glass takes it: you see it running down the visor
				screenGoo(3, PALETTES.acid, 0.8, 3.5)
				say("the mask took it", ACID_UI)
				flash(ACID_UI, 0.15, 0.3)
			else
				screenGoo(rng:NextInteger(6, 9), PALETTES.acid, 1.25, 7)
				flash(ACID_UI, 0.45, 0.8)
				tint.BackgroundTransparency = 0.72
				tween(tint, 5, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
				say("IT BURNS", ACID_UI)
			end
			local head = player.Character and player.Character:FindFirstChild("Head")
			if head then
				sound("Sizzle", head, 0.8, 1, 30)
				sound("Splat", head, 0.7, 1.2, 30)
			end
		end
	end)
end

-- ===== item events (sounds and bits for everyone; the owner's own texts are in InventoryUI) =====
local SLOT_PART = {head = "Head", face = "Head", torso = "Torso", torso_under = "Torso", arms = "Right Arm", legs = "Right Leg"}
local function wornPart(character, id)
	local item = ItemData.Get(id)
	local slot = item and item.slots and item.slots[1] or (item and item.slot)
	return character:FindFirstChild(SLOT_PART[slot or "torso"] or "Torso") or character:FindFirstChild("Torso")
end
local function heavy(id)
	local item = ItemData.Get(id)
	return item and ((item.weight or 0) >= 3 or tostring(id):find("helmet") ~= nil or tostring(id):find("vest") ~= nil)
end

local itemFx = ReplicatedStorage:WaitForChild("GS_ItemFX", 60)
if itemFx then
	itemFx.OnClientEvent:Connect(function(kind, character, id, extra)
		if kind == "toast" or typeof(character) ~= "Instance" then return end
		local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
		local item = ItemData.Get(id)
		local mine = character == player.Character
		if kind == "draw" then
			if item and item.kind == "gun" then
				sound("Click", head, 0.5, 0.9, 40)
				if item.pump then task.delay(0.2, function() sound("Rack", head, 0.45, 1.1, 50) end) end
			elseif item and item.kind == "melee" then
				sound("Swing", head, 0.2, 0.7, 30)
			else
				sound("Cloth", head, 0.35, 1.2, 30)
			end
		elseif kind == "stow" or kind == "pickup" or kind == "drop" then
			sound("Cloth", head, 0.35, kind == "drop" and 0.9 or 1.1, 35)
		elseif kind == "wear" or kind == "unwear" then
			sound("Cloth", head, 0.5, kind == "wear" and 1 or 1.15, 35)
			if heavy(id) then task.delay(0.15, function() sound("Plate", head, 0.35, 1.3, 40) end) end
		elseif kind == "armorbreak" then
			local part = wornPart(character, id)
			if not part then return end
			sound("MetalHit", part, 0.9, 0.7, 90)
			sound("Bone", part, 0.4, 1.4, 60)
			-- chips of the broken piece
			local color = Color3.fromRGB(40, 40, 42)
			for _ = 1, low() and 4 or 9 do
				local chip = create("Part", {
					Size = Vector3.new(rng:NextNumber(0.1, 0.35), rng:NextNumber(0.05, 0.12), rng:NextNumber(0.1, 0.3)),
					Color = color:Lerp(Color3.fromRGB(90, 86, 80), rng:NextNumber()), Material = Enum.Material.Metal,
					CFrame = part.CFrame * CFrame.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)),
					CanCollide = true, CanQuery = false, CanTouch = false, Parent = fxFolder,
				})
				chip.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1), rng:NextNumber(-1, 1)) * rng:NextNumber(10, 20)
				chip.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 20
				task.delay(4, function() if chip.Parent then tween(chip, 1, {Transparency = 1}) end end)
				Debris:AddItem(chip, 5.2)
			end
			if mine then
				say(((item and item.name) or "ARMOR") .. " BROKE", BRIGHT)
				flash(Color3.new(1, 1, 1), 0.2, 0.25)
			end
		elseif kind == "usebegin" then
			if item and item.id == "painkillers" then
				sound("Rattle", head, 0.5, 1, 30)
			elseif item and item.id == "adrenaline" then
				sound("Click", head, 0.4, 1.4, 25)
			elseif item and item.kind == "heal" then
				sound("Cloth", head, 0.5, 0.8, 30)
			end
		elseif kind == "used" then
			if item and item.id == "adrenaline" then
				sound("Spray", head, 0.3, 1.8, 25)
			elseif item and item.kind == "heal" then
				sound("Cloth", head, 0.45, 1.3, 30)
			end
		elseif kind == "trapset" then
			local model = character -- (the trap model)
			local pivot = model:IsA("Model") and model:GetPivot().Position or nil
			if pivot then soundAt("TrapSet", pivot, 0.7, 1, 50) end
		elseif kind == "trapopen" then
			local pivot = character:IsA("Model") and character:GetPivot().Position or nil
			if pivot then soundAt("TrapSet", pivot, 0.6, 1.2, 50) end
		elseif kind == "trapsnap" then
			local pivot = character:IsA("Model") and character:GetPivot().Position or nil
			if pivot then
				soundAt("TrapSnap", pivot, 1, 1, 140)
				soundAt("Bone", pivot, 0.7, 0.9, 90)
			end
			local victim = id
			if typeof(victim) == "Instance" and victim == player.Character then
				flash(Color3.fromRGB(160, 10, 10), 0.35, 0.5)
			end
		end
	end)
end

-- ===== burning creatures (flare rounds) =====
local burning = {}
RunService.Heartbeat:Connect(function()
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then return end
	local t = now()
	for _, model in ipairs(folder:GetChildren()) do
		local on = (model:GetAttribute("GS_Burning") or 0) > t and not model:GetAttribute("GS_Dead")
		if on and not burning[model] then
			local torso = model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")
			if torso then
				local fire = create("Fire", {Size = 5, Heat = 9, Color = Color3.fromRGB(255, 110, 40), SecondaryColor = Color3.fromRGB(120, 20, 10), Parent = torso})
				local light = create("PointLight", {Color = Color3.fromRGB(255, 120, 50), Range = 12, Brightness = 1.5, Parent = torso})
				local crackle = sound("Sizzle", torso, 0.35, 0.7, 60)
				if crackle then crackle.Looped = true end
				burning[model] = {fire, light, crackle}
			end
		elseif not on and burning[model] then
			for _, obj in ipairs(burning[model]) do if obj then obj:Destroy() end end
			burning[model] = nil
		end
	end
	for model, objs in pairs(burning) do
		if not model.Parent then
			for _, obj in ipairs(objs) do if obj then obj:Destroy() end end
			burning[model] = nil
		end
	end
end)

-- ===== my own state: web, trap, fumes, shock =====
local lastShock = nil
local cardWas = nil
RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		card.Visible = false
		vignette.GroupTransparency = 1
		return
	end
	local t = now()
	local shown = nil
	-- caught in a web: down in the threads, getting up slowly (no concussion, just the timer)
	local webUntil = character:GetAttribute("GS_WebStun") or 0
	local trapUntil = character:GetAttribute("GS_Trapped") or 0
	if webUntil > t then
		local dur = math.max(character:GetAttribute("GS_WebStunDur") or 5, 0.5)
		local left = webUntil - t
		local p = math.clamp(1 - left / dur, 0, 1)
		shown = "web"
		cardTitle.Text = p < 0.35 and "CAUGHT IN THE WEB" or "GETTING UP"
		cardTime.Text = string.format("%.1f", left)
		cardHint.Text = p < 0.35 and "the threads hold you down" or "pulling free of the threads"
		barFill.BackgroundColor3 = INK
		barFill.Size = UDim2.fromScale(p, 1)
	elseif typeof(trapUntil) == "number" and trapUntil > t then
		local left = trapUntil - t
		shown = "trap"
		cardTitle.Text = "LEG IN A TRAP"
		cardTime.Text = string.format("%.1f", left)
		cardHint.Text = "the jaws let go soon - someone can pry it open"
		barFill.BackgroundColor3 = BRIGHT
		barFill.Size = UDim2.fromScale(math.clamp(1 - left / 4, 0, 1), 1)
	elseif (character:GetAttribute("GS_Poison") or 0) > t then
		local left = character:GetAttribute("GS_Poison") - t
		shown = "acid"
		cardTitle.Text = "ACID FUMES"
		cardTime.Text = string.format("%.1f", left)
		cardHint.Text = character:GetAttribute("GS_Filter") and "the filter is clearing it" or "a gas mask would stop this"
		barFill.BackgroundColor3 = ACID_UI
		barFill.Size = UDim2.fromScale(math.clamp(left / 6, 0, 1), 1)
	end
	if shown ~= cardWas then
		cardWas = shown
		if shown then
			card.Visible = true
			card.BackgroundTransparency = 1
			tween(card, 0.2, {BackgroundTransparency = 0.15})
		else
			card.Visible = false
		end
	end
	-- the fumes: the edges of the screen go green and throb
	if shown == "acid" then
		vignette.GroupTransparency = 0.45 + 0.25 * math.sin(os.clock() * 4)
	elseif vignette.GroupTransparency < 1 then
		vignette.GroupTransparency = math.min(1, vignette.GroupTransparency + 0.02)
	end
	-- a shock baton hit: a white flash and a buzz
	local shock = character:GetAttribute("GS_Shocked")
	if shock and shock ~= lastShock then
		lastShock = shock
		if t - shock < 1 then
			flash(Color3.fromRGB(200, 225, 255), 0.7, 0.6)
			local torso = character:FindFirstChild("Torso")
			if torso then sound("Shock", torso, 0.7, 1, 40) end
		end
	end
end)

-- everyone's sparks when someone gets shocked
local function watchShock(character)
	character:GetAttributeChangedSignal("GS_Shocked"):Connect(function()
		local torso = character:FindFirstChild("Torso")
		if not torso then return end
		local att = create("Attachment", {Parent = torso})
		local sparks = create("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(170, 210, 255)),
			LightEmission = 1, Size = NumberSequence.new(0.35, 0), Lifetime = NumberRange.new(0.15, 0.35), Speed = NumberRange.new(6, 14),
			SpreadAngle = Vector2.new(180, 180), Rate = 0, Parent = att,
		})
		sparks:Emit(low() and 12 or 30)
		local light = create("PointLight", {Color = Color3.fromRGB(170, 210, 255), Range = 10, Brightness = 3, Parent = att})
		tween(light, 0.5, {Brightness = 0})
		Debris:AddItem(att, 1)
	end)
end
local function onPlayer(plr)
	if plr.Character then watchShock(plr.Character) end
	plr.CharacterAdded:Connect(watchShock)
end
for _, plr in ipairs(Players:GetPlayers()) do onPlayer(plr) end
Players.PlayerAdded:Connect(onPlayer)
]=]},
	{name = "Controls", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- The action HUD for everyone:
--  * keyboard: an ability panel (bottom-right) showing what each key does, with cooldowns. The infected also see
--    their stage, kills to the next stage and whether they are close to the Mother.
--  * touch: real on-screen buttons (HIT, CRAWL, GRAB for the infected) that never sit on the jump button.
--    Survivors also get BAG (the item wheel) and, with something in the hand, USE / FIRE, AIM, RELOAD and AWAY.
--  * an editor (the HUD button at the top): drag any button or panel, change its size and opacity, reset it.
--    The layout is saved on the server per device kind, so it comes back next time.
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local prefsRemote = ReplicatedStorage:WaitForChild("GS_Prefs", 30)

local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local DEVICE = TOUCH and "touch" or "desktop"

local STYLE = {
	Font = Enum.Font.SpecialElite,
	Ink = Color3.fromRGB(228, 220, 212),
	Dim = Color3.fromRGB(135, 124, 118),
	Faint = Color3.fromRGB(80, 72, 68),
	Panel = Color3.fromRGB(8, 6, 6),
	Blood = Color3.fromRGB(150, 12, 16),
	BloodBright = Color3.fromRGB(220, 34, 34),
	Ready = Color3.fromRGB(205, 40, 40),
}

local function create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do inst[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	return inst
end

-- the local event the gameplay scripts listen to (MonsterClient: strike / grab, Animation: crawl)
local clientAction = player:FindFirstChild("GS_ClientAction")
if not clientAction then
	clientAction = Instance.new("BindableEvent")
	clientAction.Name = "GS_ClientAction"
	clientAction.Parent = player
end

local gui = create("ScreenGui", {
	Name = "GS_Controls", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
})

-- ===== state helpers =====
local function character() return player.Character end
local function alive()
	local c = character()
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
local function infected()
	local c = character()
	return player:GetAttribute("Infected") == true and c ~= nil and c:GetAttribute("Infected") == true
end
local function stage()
	local c = character()
	return math.clamp((c and c:GetAttribute("InfectStage")) or 1, 1, 3)
end
local function inMenu()
	return player:GetAttribute("InMenu") == true or player:GetAttribute("UIOpen") == true
end
-- seconds left on the local swing (MonsterClient stamps GS_AttackStart with os.clock on every swing).
-- The infected claw every 0.7 s; a survivor's shove every 1.5 s.
local function strikeCooldown()
	local c = character()
	return (c and c:GetAttribute("Infected")) and 0.7 or 1.5
end
local function strikeLeft()
	local c = character()
	local t = c and c:GetAttribute("GS_AttackStart")
	return typeof(t) == "number" and math.max(0, strikeCooldown() - (os.clock() - t)) or 0
end
local function grabLeft()
	local c = character()
	return math.max(0, ((c and c:GetAttribute("GS_GrabReadyAt")) or 0) - workspace:GetServerTimeNow())
end

-- ===== movable elements: everything the editor can move =====
-- each: {id, name, frame, scalable, fadable, defaultPos (UDim2, top-left), getAlpha/setAlpha}
local movables = {}
local layout = {} -- id -> {x, y, s, a}

-- AbsolutePosition leaves out the top-bar inset while a Position inside a ScreenGui that ignores the inset
-- counts from the very top of the screen, so every conversion goes through the containers' own AbsolutePosition
local function relativeTo(container, point)
	local origin, size = container.AbsolutePosition, container.AbsoluteSize
	return (point.X - origin.X) / math.max(size.X, 1), (point.Y - origin.Y) / math.max(size.Y, 1)
end

local function applyEntry(m)
	local e = layout[m.id]
	local scale = m.frame:FindFirstChild("GS_LayoutScale")
	if not scale then
		scale = create("UIScale", {Name = "GS_LayoutScale", Parent = m.frame})
	end
	scale.Scale = e and e.s or 1
	if m.external then
		m.frame:SetAttribute("GS_LayoutPos", e and UDim2.fromScale(e.x, e.y) or nil)
	else
		m.frame.AnchorPoint = Vector2.new(0, 0)
		m.frame.Position = e and UDim2.fromScale(e.x, e.y) or m.defaultPos()
	end
	if m.setAlpha then m.setAlpha(e and e.a or 0) end
end

local function register(m)
	table.insert(movables, m)
	applyEntry(m)
end

-- ===== the keyboard ability panel =====
local abilityPanel = create("Frame", {
	Name = "Abilities", Size = UDim2.fromOffset(246, 10), BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.Y, Parent = gui, Visible = false,
})
create("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = abilityPanel})

-- infected header: stage, progress to the next stage, and the Mother
local header = create("Frame", {
	Name = "Header", Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = STYLE.Panel, BackgroundTransparency = 0.2,
	BorderSizePixel = 0, LayoutOrder = 0, Parent = abilityPanel,
}, {create("UIStroke", {Color = Color3.fromRGB(70, 8, 10), Thickness = 1})})
create("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = STYLE.Blood, BorderSizePixel = 0, Parent = header})
local stageText = create("TextLabel", {
	Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -18, 0, 18), BackgroundTransparency = 1, Font = STYLE.Font,
	TextSize = 15, TextColor3 = STYLE.BloodBright, TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})
local stageBarBack = create("Frame", {
	Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 3), BackgroundColor3 = Color3.fromRGB(40, 10, 10),
	BorderSizePixel = 0, Parent = header,
})
local stageBar = create("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = STYLE.BloodBright, BorderSizePixel = 0, Parent = stageBarBack})
local motherText = create("TextLabel", {
	Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -18, 0, 15), BackgroundTransparency = 1, Font = STYLE.Font,
	TextSize = 12, TextColor3 = STYLE.Dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})

local cards = {}
local function card(order, key, name, desc, id)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = STYLE.Panel, BackgroundTransparency = 0.25,
		BorderSizePixel = 0, LayoutOrder = order, Parent = abilityPanel,
	}, {create("UIStroke", {Color = Color3.fromRGB(45, 10, 10), Thickness = 1})})
	local keyBox = create("TextLabel", {
		Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromRGB(16, 4, 5),
		BorderSizePixel = 0, Font = STYLE.Font, Text = key, TextSize = #key > 1 and 11 or 18, TextColor3 = STYLE.Ink, Rotation = -3,
		ClipsDescendants = true, Parent = frame,
	})
	local keyStroke = create("UIStroke", {Color = STYLE.Blood, Thickness = 1.5, Parent = keyBox})
	-- cooldown: a dark curtain over the key that drains away
	local curtain = create("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 2, Parent = keyBox,
	})
	local title = create("TextLabel", {
		Position = UDim2.fromOffset(46, 5), Size = UDim2.new(1, -52, 0, 18), BackgroundTransparency = 1, Font = STYLE.Font,
		Text = name, TextSize = 15, TextColor3 = STYLE.Ink, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame,
	})
	local sub = create("TextLabel", {
		Position = UDim2.fromOffset(46, 23), Size = UDim2.new(1, -52, 0, 15), BackgroundTransparency = 1, Font = STYLE.Font,
		Text = desc, TextSize = 12, TextColor3 = STYLE.Dim, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame,
	})
	local status = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(60, 16),
		BackgroundTransparency = 1, Font = STYLE.Font, Text = "", TextSize = 12, TextColor3 = STYLE.Ready,
		TextXAlignment = Enum.TextXAlignment.Right, Parent = frame,
	})
	local c = {frame = frame, keyBox = keyBox, keyStroke = keyStroke, curtain = curtain, title = title, sub = sub, status = status}
	cards[id or key] = c
	return c
end
card(1, "F", "HIT", "shove whoever is in front")
card(2, "C", "LAY DOWN", "hold - lie down and crawl")
card(3, "E", "EAT", "hold next to remains")
card(4, "R", "GRAB", "tentacles drag a survivor in")
-- the bag and whatever is in the hand (InventoryUI / WeaponClient do the work)
card(5, "Q", "BAG", "hold - point at an item, let go", "bag")
card(6, "LMB", "USE", "", "use")
card(7, "RMB", "AIM", "hold - tighter spread, slow walk", "aim")
card(8, "R", "RELOAD", "shells from your bag", "reload")
card(9, "H", "PUT AWAY", "G - drop it for someone else", "away")
local USE_TEXT = {
	gun = {"FIRE", "the circle is where the shot goes"},
	melee = {"SWING", "aim for the head, or a limb"},
	heal = {"TREAT", "hit the green to do it right"},
	light = {"LIGHT IT", "a flare burns for a minute"},
	trap = {"SET IT", "on the floor, at your feet"},
}

local function setCard(c, visible, ready, left, total, locked, lockText)
	c.frame.Visible = visible
	if not visible then return end
	local frac = (left > 0 and total > 0) and math.clamp(left / total, 0, 1) or 0
	c.curtain.Size = UDim2.fromScale(1, locked and 1 or frac)
	if locked then
		c.status.Text = lockText or "locked"
		c.status.TextColor3 = STYLE.Faint
		c.title.TextColor3 = STYLE.Faint
		c.keyStroke.Color = Color3.fromRGB(50, 14, 14)
	elseif left > 0 then
		c.status.Text = string.format("%.1fs", left)
		c.status.TextColor3 = STYLE.Dim
		c.title.TextColor3 = STYLE.Dim
		c.keyStroke.Color = Color3.fromRGB(70, 18, 18)
	else
		c.status.Text = ready and "ready" or ""
		c.status.TextColor3 = STYLE.Ready
		c.title.TextColor3 = STYLE.Ink
		c.keyStroke.Color = STYLE.Blood
	end
end

if not TOUCH then
	register({
		id = "abilities", name = "ABILITIES", frame = abilityPanel, scalable = true,
		defaultPos = function()
			local size = gui.AbsoluteSize
			return UDim2.fromOffset(size.X - 246 - 18, size.Y - abilityPanel.AbsoluteSize.Y - 18)
		end,
		setAlpha = function(a) abilityPanel:SetAttribute("GS_Alpha", a) end,
	})
end

-- ===== touch buttons =====
local buttons = {}
local function jumpRect()
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump.AbsoluteSize.X > 0 then
		return jump.AbsolutePosition, jump.AbsoluteSize
	end
	-- the standard spot when the jump button isn't built yet
	local size = gui.AbsoluteSize
	local s = math.min(size.X, size.Y) > 500 and 120 or 70
	return gui.AbsolutePosition + Vector2.new(size.X - s - (s == 120 and 95 or 25), size.Y - s - (s == 120 and 90 or 20)), Vector2.new(s, s)
end

local function overlaps(p1, s1, p2, s2, pad)
	pad = pad or 0
	return p1.X < p2.X + s2.X + pad and p2.X < p1.X + s1.X + pad and p1.Y < p2.Y + s2.Y + pad and p2.Y < p1.Y + s1.Y + pad
end

-- never on top of the jump button: slide left (then up) until clear
local function keepOffJump(frame)
	local jp, js = jumpRect()
	for _ = 1, 40 do
		local p, s = frame.AbsolutePosition, frame.AbsoluteSize
		if not overlaps(p, s, jp, js, 6) then return end
		local pos = frame.Position
		frame.Position = UDim2.new(pos.X.Scale, pos.X.Offset - 12, pos.Y.Scale, pos.Y.Offset)
		if frame.AbsolutePosition.X < 8 then
			frame.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset - 12)
		end
	end
end

local function touchButton(id, label, size, action, defaultPos)
	local holder = create("Frame", {
		Name = "Btn_" .. id, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = gui, Visible = false,
	})
	local b = create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 6, 6), BackgroundTransparency = 0.25,
		AutoButtonColor = false, Text = "", Parent = holder,
	}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
	local ring = create("UIStroke", {Color = STYLE.Blood, Thickness = 2.5, Parent = b})
	-- cooldown: a dark disc growing over the button
	local shade = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 2, Parent = b,
	}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
	local text = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = STYLE.Font, Text = label,
		TextScaled = true, TextColor3 = STYLE.Ink, ZIndex = 3, Parent = b,
	}, {create("UIPadding", {PaddingLeft = UDim.new(0.2, 0), PaddingRight = UDim.new(0.2, 0),
		PaddingTop = UDim.new(0.32, 0), PaddingBottom = UDim.new(0.32, 0)})})
	local inner = create("UIScale", {Scale = 1, Parent = b})
	local btn = {id = id, holder = holder, button = b, ring = ring, shade = shade, text = text, alpha = 0}
	b.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if btn.editing then return end
		TweenService:Create(inner, TweenInfo.new(0.07), {Scale = 0.88}):Play()
		ring.Color = STYLE.BloodBright
		clientAction:Fire(action)
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		TweenService:Create(inner, TweenInfo.new(0.12, Enum.EasingStyle.Back), {Scale = 1}):Play()
		ring.Color = STYLE.Blood
	end)
	buttons[id] = btn
	register({
		id = id, name = label, frame = holder, scalable = true,
		defaultPos = defaultPos,
		setAlpha = function(a)
			btn.alpha = a
			b.BackgroundTransparency = 0.25 + a * 0.75
			ring.Transparency = a
			text.TextTransparency = a
		end,
	})
	return btn
end

if TOUCH then
	local function besideJump(dx, dy, size)
		return function()
			local jp, js = jumpRect()
			jp -= gui.AbsolutePosition
			return UDim2.fromOffset(jp.X + dx - size, jp.Y + js.Y / 2 - size / 2 + dy)
		end
	end
	touchButton("hit", "HIT", 78, "strike", besideJump(-18, 0, 78))
	touchButton("crawl", "LAY", 58, "crawl", besideJump(-112, 26, 58))
	touchButton("grab", "GRAB", 66, "grab", besideJump(-24, -96, 66))
	-- the bag and what's in the hand
	touchButton("bag", "BAG", 56, "inventory", besideJump(-100, -170, 56))
	touchButton("use", "USE", 84, "use", besideJump(-100, -80, 84))
	touchButton("aim", "AIM", 60, "aim", besideJump(-190, -60, 60))
	touchButton("reload", "LOAD", 54, "reload", besideJump(-180, 20, 54))
	touchButton("away", "AWAY", 48, "away", besideJump(-20, -170, 48))
end

-- ===== the editor =====
local editButton = create("TextButton", {
	Name = "EditHUD", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.36, 0),
	Size = TOUCH and UDim2.fromOffset(64, 30) or UDim2.fromOffset(58, 26),
	BackgroundColor3 = STYLE.Panel, BackgroundTransparency = 0.25, AutoButtonColor = false, Font = STYLE.Font,
	Text = "HUD", TextSize = 14, TextColor3 = STYLE.Dim, Parent = gui,
}, {create("UIStroke", {Color = Color3.fromRGB(70, 12, 12), Thickness = 1})})

local editorGui = create("ScreenGui", {
	Name = "GS_HUDEditor", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false, Parent = playerGui,
})
create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Parent = editorGui})
create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(460, 50),
	BackgroundTransparency = 1, Font = STYLE.Font, TextSize = 16, TextColor3 = STYLE.Dim, TextWrapped = true,
	Text = "drag anything with a red frame - tap it to pick it, then change size and opacity below", Parent = editorGui,
})

local toolbar = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(560, 88),
	BackgroundColor3 = STYLE.Panel, BackgroundTransparency = 0.05, BorderSizePixel = 0, Parent = editorGui,
}, {create("UIStroke", {Color = STYLE.Blood, Thickness = 1.5})})
local selectedLabel = create("TextLabel", {
	Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 20), BackgroundTransparency = 1, Font = STYLE.Font,
	TextSize = 16, TextColor3 = STYLE.BloodBright, TextXAlignment = Enum.TextXAlignment.Left, Text = "nothing picked", Parent = toolbar,
})
local valueLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 6), Size = UDim2.fromOffset(240, 20),
	BackgroundTransparency = 1, Font = STYLE.Font, TextSize = 13, TextColor3 = STYLE.Dim,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = toolbar,
})
local function toolButton(text, x, w, y, callback, accent)
	local b = create("TextButton", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 30), BackgroundColor3 = Color3.fromRGB(18, 10, 10),
		AutoButtonColor = true, Font = STYLE.Font, Text = text, TextSize = 14,
		TextColor3 = accent and STYLE.BloodBright or STYLE.Ink, Parent = toolbar,
	}, {create("UIStroke", {Color = accent and STYLE.Blood or Color3.fromRGB(60, 16, 16), Thickness = 1})})
	b.Activated:Connect(callback)
	return b
end

local selected = nil
local handles = {}
local handleConnections = {}
local dirty = false

local function entryFor(m)
	local e = layout[m.id]
	if not e then
		local x, y = relativeTo(m.frame.Parent, m.frame.AbsolutePosition)
		e = {x = x, y = y, s = 1, a = 0}
		layout[m.id] = e
	end
	return e
end

local function refreshValues()
	if not selected then
		selectedLabel.Text = "nothing picked"
		valueLabel.Text = ""
		return
	end
	local e = layout[selected.id]
	selectedLabel.Text = selected.name
	valueLabel.Text = string.format("size %d%%   opacity %d%%", math.floor((e and e.s or 1) * 100 + 0.5),
		math.floor((1 - (e and e.a or 0)) * 100 + 0.5))
end

local function nudge(field, delta, lo, hi)
	if not selected then return end
	local e = entryFor(selected)
	e[field] = math.clamp(math.floor((e[field] + delta) * 100 + 0.5) / 100, lo, hi)
	applyEntry(selected)
	dirty = true
	refreshValues()
end

toolButton("SIZE -", 14, 76, 32, function() nudge("s", -0.1, 0.5, 2) end)
toolButton("SIZE +", 94, 76, 32, function() nudge("s", 0.1, 0.5, 2) end)
toolButton("OPACITY -", 180, 96, 32, function() nudge("a", 0.1, 0, 0.9) end)
toolButton("OPACITY +", 280, 96, 32, function() nudge("a", -0.1, 0, 0.9) end)
toolButton("RESET", 440, 106, 66, function()
	if not selected then return end
	layout[selected.id] = nil
	applyEntry(selected)
	dirty = true
	refreshValues()
end)

local function saveLayout()
	if not dirty or not prefsRemote then return end
	dirty = false
	task.spawn(function() pcall(function() prefsRemote:InvokeServer("setLayout", DEVICE, layout) end) end)
end

local function closeEditor()
	editorGui.Enabled = false
	for _, h in pairs(handles) do h:Destroy() end
	table.clear(handles)
	for _, conn in ipairs(handleConnections) do conn:Disconnect() end
	table.clear(handleConnections)
	for _, btn in pairs(buttons) do btn.editing = false end
	selected = nil
	saveLayout()
end

toolButton("RESET ALL", 14, 110, 66, function()
	table.clear(layout)
	for _, m in ipairs(movables) do applyEntry(m) end
	dirty = true
	selected = nil
	refreshValues()
end)
toolButton("DONE", 440, 106, 32, closeEditor, true)
toolbar.Size = UDim2.fromOffset(560, 100)

local function makeHandle(m)
	local h = create("TextButton", {
		BackgroundColor3 = STYLE.Blood, BackgroundTransparency = 0.8, AutoButtonColor = false, Text = "", ZIndex = 5,
		Parent = editorGui,
	}, {create("UIStroke", {Color = STYLE.BloodBright, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
	create("TextLabel", {
		Position = UDim2.new(0, 0, 0, -16), Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = STYLE.Font,
		Text = m.name, TextSize = 12, TextColor3 = STYLE.Ink, TextStrokeTransparency = 0.3, ZIndex = 6, Parent = h,
	})
	local dragging, startInput, startPos
	h.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		selected = m
		refreshValues()
		dragging = input
		startInput = Vector2.new(input.Position.X, input.Position.Y)
		startPos = m.frame.AbsolutePosition
	end)
	table.insert(handleConnections, UserInputService.InputChanged:Connect(function(input)
		if not dragging or not editorGui.Enabled then return end
		if input ~= dragging and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local now = Vector2.new(input.Position.X, input.Position.Y)
		local p = startPos + (now - startInput)
		-- kept on screen
		local screenPos, screen = gui.AbsolutePosition, gui.AbsoluteSize
		local s = m.frame.AbsoluteSize
		p = Vector2.new(math.clamp(p.X, screenPos.X, screenPos.X + screen.X - s.X), math.clamp(p.Y, screenPos.Y, screenPos.Y + screen.Y - s.Y))
		local e = entryFor(m)
		-- positions are kept as a fraction of the container, so they fit any screen size
		e.x, e.y = relativeTo(m.frame.Parent, p)
		applyEntry(m)
		dirty = true
	end))
	table.insert(handleConnections, UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
			if buttons[m.id] then
				keepOffJump(m.frame)
				-- store where it ended up after being pushed off the jump button
				local e = entryFor(m)
				e.x, e.y = relativeTo(m.frame.Parent, m.frame.AbsolutePosition)
			end
		end
	end))
	handles[m] = h
	return h
end

local function openEditor()
	if editorGui.Enabled then return end
	editorGui.Enabled = true
	for _, btn in pairs(buttons) do btn.editing = true end
	for _, m in ipairs(movables) do
		if m.frame.Parent then makeHandle(m) end
	end
	selected = nil
	refreshValues()
end
editButton.Activated:Connect(function()
	if editorGui.Enabled then closeEditor() else openEditor() end
end)

-- the vitals and body panels from the HealthBar script join the editor once they exist
task.spawn(function()
	local healthGui = playerGui:WaitForChild("HorrorHealthUI", 30)
	if not healthGui then return end
	for _, name in ipairs({"HealthPanel", "BodyStatus"}) do
		local frame = healthGui:WaitForChild(name, 10)
		if frame then
			register({id = name == "HealthPanel" and "vitals" or "body", name = frame:GetAttribute("GS_Movable") or name,
				frame = frame, scalable = true, external = true})
		end
	end
end)

-- the money panel (MoneyHUD script) too
task.spawn(function()
	local moneyGui = playerGui:WaitForChild("GS_MoneyHUD", 30)
	local frame = moneyGui and moneyGui:WaitForChild("Money", 10)
	if frame then
		register({id = "cash", name = "CASH", frame = frame, scalable = true, external = true})
	end
end)

-- load the saved layout for this kind of device
task.spawn(function()
	if not prefsRemote then return end
	local ok, data = pcall(function() return prefsRemote:InvokeServer("get") end)
	if ok and typeof(data) == "table" and typeof(data.layout) == "table" and typeof(data.layout[DEVICE]) == "table" then
		layout = data.layout[DEVICE]
		for _, m in ipairs(movables) do applyEntry(m) end
	end
end)

-- ===== every frame: what is shown, cooldowns, keep handles on their elements =====
local ROMAN = {"I", "II", "III"}
local NEXT = {3, 5}
RunService.RenderStepped:Connect(function()
	local playing = alive() and not inMenu()
	local inf = infected()
	local st = inf and stage() or 0
	local c = character()

	editButton.Visible = playing or editorGui.Enabled

	-- keyboard panel
	if not TOUCH then
		abilityPanel.Visible = playing
		if not layout.abilities then
			-- default: bottom-right corner, growing upward as cards appear
			local size = gui.AbsoluteSize
			abilityPanel.Position = UDim2.fromOffset(size.X - 246 - 18, size.Y - abilityPanel.AbsoluteSize.Y - 18)
		end
		header.Visible = inf
		if inf then
			local kills = player:GetAttribute("InfectKills") or 0
			local nextAt = NEXT[st]
			local prev = st == 1 and 0 or NEXT[st - 1]
			stageText.Text = nextAt and string.format("STAGE %s  -  %d / %d kills", ROMAN[st], kills, nextAt)
				or string.format("STAGE %s  -  %d kills", ROMAN[st], kills)
			stageBar.Size = UDim2.fromScale(nextAt and math.clamp((kills - prev) / (nextAt - prev), 0, 1) or 1, 1)
			local link = c and c:GetAttribute("GS_Boss")
			local dist = c and c:GetAttribute("GS_BossDist") or -1
			if link == "near" then
				motherText.Text = string.format("the Mother is %d m away", dist)
				motherText.TextColor3 = STYLE.Dim
			elseif link == "far" then
				motherText.Text = string.format("too far from the Mother (%d m) - weakened", dist)
				motherText.TextColor3 = STYLE.BloodBright
			else
				motherText.Text = "no Mother - weakened until one appears"
				motherText.TextColor3 = STYLE.BloodBright
			end
		end
		local strike = strikeLeft()
		setCard(cards.F, true, true, strike, strikeCooldown())
		cards.F.sub.Text = inf and "claw a survivor - long reach" or "shove whoever is in front"
		setCard(cards.C, not inf, false, 0, 1)
		setCard(cards.E, inf, false, 0, 1)
		local grab = grabLeft()
		setCard(cards.R, inf, true, grab, 7, st < 3, "stage III")
		local heldKind = player:GetAttribute("GS_HeldKind")
		local useText = USE_TEXT[heldKind or ""]
		setCard(cards.bag, not inf, false, 0, 1)
		setCard(cards.use, not inf and useText ~= nil, false, 0, 1)
		if useText then
			cards.use.title.Text = useText[1]
			cards.use.sub.Text = useText[2]
		end
		setCard(cards.aim, not inf and heldKind == "gun", false, 0, 1)
		setCard(cards.reload, not inf and heldKind == "gun", false, 0, 1)
		setCard(cards.away, not inf and heldKind ~= nil, false, 0, 1)
		-- fade (editor opacity)
		local a = abilityPanel:GetAttribute("GS_Alpha") or 0
		for _, cardData in pairs(cards) do
			cardData.frame.BackgroundTransparency = 0.25 + a * 0.75
			cardData.title.TextTransparency = a
			cardData.sub.TextTransparency = a
			cardData.status.TextTransparency = a
			cardData.keyBox.TextTransparency = a
			cardData.keyBox.BackgroundTransparency = a
		end
		header.BackgroundTransparency = 0.2 + a * 0.8
		stageText.TextTransparency = a
		motherText.TextTransparency = a
	end

	-- touch buttons
	local heldKind = player:GetAttribute("GS_HeldKind")
	for id, btn in pairs(buttons) do
		local wanted = true
		if id == "grab" then wanted = inf and st >= 3
		elseif id == "bag" then wanted = not inf
		elseif id == "use" then wanted = not inf and USE_TEXT[heldKind or ""] ~= nil
		elseif id == "aim" or id == "reload" then wanted = not inf and heldKind == "gun"
		elseif id == "away" then wanted = not inf and heldKind ~= nil end
		local show = (playing or editorGui.Enabled) and (wanted or editorGui.Enabled)
		btn.holder.Visible = show
		if id == "use" then
			local label = USE_TEXT[heldKind or ""]
			btn.text.Text = label and (label[1] == "LIGHT IT" and "LIGHT" or label[1] == "SET IT" and "SET" or label[1]) or "USE"
		elseif id == "aim" then
			btn.ring.Color = (c and c:GetAttribute("GS_Aim")) and STYLE.BloodBright or STYLE.Blood
		end
		local left, total = 0, 1
		if id == "hit" then left, total = strikeLeft(), strikeCooldown()
		elseif id == "grab" then left, total = grabLeft(), 7 end
		local f = left > 0 and math.clamp(left / total, 0, 1) or 0
		btn.shade.Size = UDim2.fromScale(f, f)
		if id == "crawl" then
			local crouching = c and (c:GetAttribute("GS_Crouch") or c:GetAttribute("GS_Prone"))
			btn.ring.Color = crouching and STYLE.BloodBright or STYLE.Blood
		end
	end

	-- editor handles follow their element
	if editorGui.Enabled then
		for m, h in pairs(handles) do
			local p, s = m.frame.AbsolutePosition - editorGui.AbsolutePosition, m.frame.AbsoluteSize
			h.Position = UDim2.fromOffset(p.X - 3, p.Y - 3)
			h.Size = UDim2.fromOffset(s.X + 6, s.Y + 6)
			h.Visible = m.frame.Visible or buttons[m.id] ~= nil or m.id == "abilities"
			h.BackgroundTransparency = selected == m and 0.6 or 0.85
		end
	end
end)

-- make sure buttons are off the jump button once it has been built (and after the screen turns)
if TOUCH then
	task.delay(2, function()
		-- the jump button exists by now: redo the default spots around it
		for _, m in ipairs(movables) do
			if buttons[m.id] and not layout[m.id] then
				applyEntry(m)
				keepOffJump(m.frame)
			end
		end
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		for _, m in ipairs(movables) do applyEntry(m) end
	end)
end
]=]},
	{name = "DeathScreen", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SoundConfig = require(Modules:WaitForChild("SoundConfig"))
local spawnRequest = ReplicatedStorage:WaitForChild("SpawnRequest")
local player = Players.LocalPlayer

local CONFIG = {
	Font = Enum.Font.SpecialElite,
	Ink = Color3.fromRGB(225, 222, 218),
	Mid = Color3.fromRGB(150, 146, 142),
	Dim = Color3.fromRGB(80, 78, 76),
	Red = Color3.fromRGB(175, 12, 12),
	Causes = {
		FALL = {
			"You fell %d studs. The spine gave way first.",
			"A %d stud drop. Nobody heard the landing.",
			"You hit the ground after %d studs. Bones snapped like dry wood.",
		},
		GIBBED = {
			"You fell %d studs. There was not much left to identify.",
			"A %d stud drop tore your body apart.",
		},
		DECAPITATED = {
			"Your head was found several meters away.",
			"Decapitated. It was quick, at least.",
		},
		HAUNTED = {
			"They took you apart piece by piece. Then they ate what was left.",
			"Nobody else saw them. That didn't stop them.",
			"They were hungry. You were there.",
		},
		D130 = {
			"Object D-130 watched you for a long time before it came closer.",
			"It followed your blood. It always does.",
			"You heard someone screaming nearby. It wasn't someone.",
		},
		SKINWALKER = {
			"It looked just like someone you trusted. Right up until it didn't.",
			"It was typing something. It never finished the message.",
			"Tomorrow it will be wearing your face.",
		},
		HEAD_EXPLODED = {
			"Your head burst open. There was nothing left to bury above the neck.",
			"Something inside your skull gave way. All at once.",
			"They found pieces of you on the walls.",
		},
		BLEEDING = {
			"You bled out. Nobody came to stop it.",
			"Your blood soaked into the ground. Then everything went quiet.",
		},
		FLESH = {
			"It ate you. You are still in there.",
			"The flesh does not let go of what it eats.",
		},
		LISTENER = {
			"It heard you breathing.",
			"You ran. It was the loudest thing in the cave.",
		},
		SPIDER = {
			"You walked into the web. It felt you struggling.",
			"Eight red eyes were the last thing you saw.",
			"It was waiting in the dark corner the whole time.",
		},
		SPIDERMOTHER = {
			"She was bigger than the door. She ate you slowly.",
			"Something small crawled out of her afterwards. It has your smell.",
			"The brood is fed.",
		},
		INFECTED = {
			"Someone you knew tore you apart. Their eyes were gone.",
			"The infected don't stop to talk.",
		},
		BEATEN = {
			"Beaten to death by another survivor.",
		},
		SHOT = {
			"Buckshot. You never saw who pulled the trigger.",
			"Somebody down here decided you were a threat.",
			"Shot. The echo went on longer than you did.",
		},
		ACID = {
			"C-310 spat. The acid ate through everything, then through you.",
			"You breathed it in. Your lungs gave up before your legs did.",
			"A gas mask would have bought you a minute. Maybe two.",
		},
		TRAP = {
			"The jaws closed on your leg. Something heard the snap.",
			"Someone set that trap for a monster. It caught you instead.",
		},
		UNKNOWN = {
			"Something found you first.",
			"Cause of death: unknown.",
		},
	},
	Epitaphs = {
		"the cave remembers you",
		"you were not the first",
		"something is still coming",
		"nobody came looking",
	},
}

local rng = Random.new()

local function create(className, props, children)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do obj[key] = value end
	for _, child in ipairs(children or {}) do child.Parent = obj end
	return obj
end

local function tween(object, time, props, style)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local gui = create("ScreenGui", {
	Name = "DeathScreen", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900,
	Enabled = false, Parent = player:WaitForChild("PlayerGui"),
})

local black = create("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 1, Parent = gui,
})
local redFlash = create("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 0, 0), BackgroundTransparency = 1,
	BorderSizePixel = 0, ZIndex = 20, Parent = gui,
})

local card = create("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(620, 470),
	BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 5, Parent = black,
})

-- shrink the record card on phones
do
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local function rescale()
		local camera = workspace.CurrentCamera
		if camera then scale.Scale = math.clamp(math.min((camera.ViewportSize.X - 16) / 620, (camera.ViewportSize.Y - 16) / 520), 0.45, 1) end
	end
	rescale()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end
end

local header = create("TextLabel", {
	Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "— RECORD OF DEATH —", TextSize = 14, TextColor3 = CONFIG.Dim, ZIndex = 6, Parent = card,
})
local titleShadow = create("TextLabel", {
	Position = UDim2.fromOffset(3, 30), Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "YOU DIED", TextSize = 72, TextColor3 = CONFIG.Red, TextTransparency = 0.35, ZIndex = 6, Parent = card,
})
local title = create("TextLabel", {
	Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "YOU DIED", TextSize = 72, TextColor3 = CONFIG.Ink, ZIndex = 7, Parent = card,
})
local nameLabel = create("TextLabel", {
	Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "", TextSize = 16, TextColor3 = CONFIG.Mid, ZIndex = 6, Parent = card,
})
create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.fromOffset(460, 1),
	BackgroundColor3 = CONFIG.Dim, BorderSizePixel = 0, ZIndex = 6, Parent = card,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
})})})
local causeLabel = create("TextLabel", {
	Position = UDim2.fromOffset(20, 154), Size = UDim2.new(1, -40, 0, 48), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "", TextSize = 20, TextWrapped = true, TextColor3 = CONFIG.Ink, ZIndex = 6, Parent = card,
})

local statsFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 214), Size = UDim2.fromOffset(440, 150),
	BackgroundTransparency = 1, ZIndex = 6, Parent = card,
}, {create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})})

local function statRow(order)
	local row = create("Frame", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = order, Parent = statsFrame})
	local key = create("TextLabel", {
		Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, Font = CONFIG.Font, Text = "", TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = CONFIG.Dim, ZIndex = 6, Parent = row,
	})
	local value = create("TextLabel", {
		Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = CONFIG.Ink,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6, Parent = row,
	})
	create("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.fromRGB(30, 30, 29), BorderSizePixel = 0, ZIndex = 6, Parent = row,
	})
	return row, key, value
end
local statRows = {}
for i = 1, 6 do
	local row, key, value = statRow(i)
	statRows[i] = {row = row, key = key, value = value}
end

local epitaph = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(600, 20),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = "", TextSize = 14, TextColor3 = Color3.fromRGB(90, 20, 20),
	TextTransparency = 1, ZIndex = 6, Parent = black,
})

local question = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 378), Size = UDim2.fromOffset(600, 24),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = "try again?", TextSize = 20, TextColor3 = CONFIG.Mid,
	ZIndex = 6, Parent = card,
})

local buttonRow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 412), Size = UDim2.fromOffset(520, 44),
	BackgroundTransparency = 1, ZIndex = 6, Parent = card,
}, {create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 60),
})})

local busy = false
local buttonsEnabled = false

local function hideDeathInfo()
	card.Visible = false
	epitaph.Visible = false
	question.Visible = false
	buttonRow.Visible = false
end
local function showDeathInfo()
	card.Visible = true
	epitaph.Visible = true
	question.Visible = true
end

local function makeButton(text, callback)
	local button = create("TextButton", {
		Size = UDim2.fromOffset(200, 40), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 7,
		Parent = buttonRow,
	})
	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(0, 1),
		BackgroundColor3 = CONFIG.Red, BorderSizePixel = 0, ZIndex = 7, Parent = button,
	})
	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = CONFIG.Font, Text = text, TextSize = 24,
		TextColor3 = CONFIG.Mid, ZIndex = 8, Parent = button,
	})
	button.MouseEnter:Connect(function()
		if not buttonsEnabled then return end
		SoundConfig.PlayOnce("MenuHover", SoundService)
		label.Text = "> " .. text .. " <"
		tween(label, 0.15, {TextColor3 = Color3.fromRGB(235, 30, 30)})
		tween(bar, 0.2, {Size = UDim2.fromOffset(180, 1)})
	end)
	button.MouseLeave:Connect(function()
		label.Text = text
		tween(label, 0.2, {TextColor3 = CONFIG.Mid})
		tween(bar, 0.2, {Size = UDim2.fromOffset(0, 1)})
	end)
	button.Activated:Connect(function()
		if player:GetAttribute("InfectPending") then
			-- the flesh has you: nothing on this screen works any more
			SoundConfig.PlayOnce("FearHit", SoundService, {Volume = 0.5, PlaybackSpeed = rng:NextNumber(0.6, 0.8)})
			label.Text = "NO"
			label.TextColor3 = CONFIG.Red
			task.delay(0.35, function() label.Text = text label.TextColor3 = CONFIG.Mid end)
			return
		end
		if busy or not buttonsEnabled then return end
		busy = true
		SoundConfig.PlayOnce("MenuClick", SoundService)
		callback()
	end)
end

local life = {start = os.clock(), distance = 0, falls = 0, highestFall = 0}
local showing = false
local token = 0

local function formatTime(seconds)
	seconds = math.floor(seconds)
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local function typeText(label, text, speed, my, silent)
	label.Text = ""
	for i = 1, #text do
		if my ~= token then return end
		label.Text = string.sub(text, 1, i)
		local ch = string.sub(text, i, i)
		if ch ~= " " then
			task.wait(speed)
		end
	end
end

local function injuriesText(character)
	if not character then return "unknown" end
	if character:GetAttribute("Gibbed") then return "body torn apart" end
	local names = {Head = "skull", Torso = "spine", RightArm = "right arm", LeftArm = "left arm", RightLeg = "right leg", LeftLeg = "left leg"}
	local list = {}
	for _, key in ipairs({"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}) do
		local level = character:GetAttribute("Injury_" .. key) or 0
		if level >= 3 then
			table.insert(list, names[key] .. " torn off")
		elseif level == 2 then
			table.insert(list, "broken " .. names[key])
		end
	end
	return #list > 0 and table.concat(list, ", ") or "none recorded"
end

local function resolveCause(character)
	if not character then return "UNKNOWN" end
	if character:GetAttribute("Gibbed") then return "GIBBED" end
	local cause = character:GetAttribute("DeathCause")
	if cause and CONFIG.Causes[cause] then return cause end
	local last = character:GetAttribute("LastDamageCause")
	if last and CONFIG.Causes[last] then return last end
	return "UNKNOWN"
end

local function showDeath(character)
	if showing then return end
	showing = true
	token += 1
	local my = token
	busy = true
	buttonsEnabled = false
	local aliveFor = os.clock() - life.start

	gui.Enabled = true
	showDeathInfo()
	black.BackgroundTransparency = 1
	card.GroupTransparency = 1
	epitaph.TextTransparency = 1
	question.TextTransparency = 1
	buttonRow.Visible = false

	redFlash.BackgroundTransparency = 0.15
	SoundConfig.PlayOnce("Impact", SoundService, {PlaybackSpeed = 0.7, Volume = 0.9})
	SoundConfig.PlayOnce("FearHit", SoundService, {Volume = 0.7})
	task.delay(0.9, function()
		if my == token then SoundConfig.PlayOnce("DeathBoom", SoundService, {PlaybackSpeed = 0.85}) end
	end)
	tween(black, 0.9, {BackgroundTransparency = 0}, Enum.EasingStyle.Sine)
	tween(redFlash, 1.3, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine)
	task.wait(1.2)
	if my ~= token then return end

	title.TextTransparency = 0
	nameLabel.Text = string.format("%s  ·  @%s", player.DisplayName, player.Name)
	causeLabel.Text = ""
	for _, r in ipairs(statRows) do r.key.Text = "" r.value.Text = "" end
	tween(card, 0.8, {GroupTransparency = 0})
	task.spawn(function()
		while showing and my == token do
			title.Position = UDim2.fromOffset(rng:NextInteger(-1, 1), 28 + rng:NextInteger(-1, 1))
			titleShadow.Position = UDim2.fromOffset(3 + rng:NextInteger(-2, 2), 30)
			title.TextTransparency = rng:NextNumber() < 0.03 and 0.5 or 0
			task.wait(0.05)
		end
	end)
	task.wait(0.8)
	if my ~= token then return end

	local ok, cause, height = pcall(function()
		local key = resolveCause(character)
		local h = character and (character:GetAttribute("LastFallHeight") or 0) or 0
		return key, h
	end)
	if not ok then cause, height = "UNKNOWN", 0 end
	local variants = CONFIG.Causes[cause] or CONFIG.Causes.UNKNOWN
	local text = variants[rng:NextInteger(1, #variants)]
	if string.find(text, "%%d") then text = string.format(text, height) end
	typeText(causeLabel, text, 0.028, my)
	task.wait(0.3)
	if my ~= token then return end

	local okStats, rows = pcall(function()
		local bloodLost = character and (character:GetAttribute("BloodLost") or 0) or 0
		local highest = math.max(life.highestFall, (cause == "FALL" or cause == "GIBBED") and height or 0)
		return {
			{"time survived", formatTime(aliveFor)},
			{"distance walked", string.format("%d studs", math.floor(life.distance))},
			{"falls survived", tostring(life.falls)},
			{"highest fall", string.format("%d studs", math.floor(highest))},
			{"blood lost", string.format("%d%%", math.clamp(math.floor(bloodLost), 0, 100))},
			{"injuries", injuriesText(character)},
		}
	end)
	if not okStats then
		rows = {{"time survived", formatTime(aliveFor)}}
	end
	for i, r in ipairs(statRows) do
		local data = rows[i]
		r.row.Visible = data ~= nil
		if data then
			r.key.Text = data[1]
			SoundConfig.PlayOnce(SoundConfig.Random("TapeClick"), SoundService, {Volume = 0.3, PlaybackSpeed = rng:NextNumber(1, 1.2)})
			typeText(r.value, data[2], 0.015, my, true)
			if my ~= token then return end
		end
	end

	local infected = player:GetAttribute("InfectPending") == true
	epitaph.Text = infected and "KILL THE SURVIVORS" or CONFIG.Epitaphs[rng:NextInteger(1, #CONFIG.Epitaphs)]
	question.Text = infected and "THE FLESH IS YOUR MASTER" or "try again?"
	question.TextColor3 = infected and CONFIG.Red or CONFIG.Mid
	tween(epitaph, 2, {TextTransparency = 0.2})
	task.wait(0.4)
	if my ~= token then return end
	tween(question, 0.8, {TextTransparency = 0})
	buttonRow.Visible = true
	buttonsEnabled = true
	busy = false
end

local rewind = create("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 6, 8), BackgroundTransparency = 1,
	BorderSizePixel = 0, ZIndex = 30, Visible = false, Parent = gui,
})
local rewindLines = {}
for i = 1, 18 do
	rewindLines[i] = create("Frame", {
		Size = UDim2.new(1, 0, 0, rng:NextInteger(2, 7)), BackgroundColor3 = Color3.fromRGB(210, 210, 215),
		BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 31, Parent = rewind,
	})
end
local rewindGrain = {}
for i = 1, 90 do
	rewindGrain[i] = create("Frame", {
		Size = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 31, Parent = rewind,
	})
end
local rewindLabel = create("TextLabel", {
	Position = UDim2.fromOffset(48, 40), Size = UDim2.fromOffset(300, 34), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "◄◄ REWIND", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(230, 230, 225), ZIndex = 32, Parent = rewind,
})
local rewindCounter = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -48, 0, 44), Size = UDim2.fromOffset(240, 28),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = "", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(230, 230, 225), ZIndex = 32, Parent = rewind,
})
local rewinding = false
local rewindSound = nil

local function startRewind(aliveFor)
	rewinding = true
	rewind.Visible = true
	rewind.BackgroundTransparency = 0
	rewindLabel.Text = "◄◄ REWIND"
	rewindSound = SoundConfig.Make("TapeRewind", SoundService, {Looped = true})
	rewindSound:Play()
	local counter = aliveFor
	task.spawn(function()
		while rewinding do
			counter = math.max(0, counter - rng:NextNumber(3, 9))
			local sec = math.floor(counter)
			rewindCounter.Text = string.format("%02d:%02d:%02d", sec // 3600, (sec // 60) % 60, sec % 60)
			for _, line in ipairs(rewindLines) do
				line.Position = UDim2.fromScale(0, rng:NextNumber())
				line.BackgroundTransparency = rng:NextNumber(0.55, 0.9)
			end
			for _, dot in ipairs(rewindGrain) do
				dot.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
				dot.BackgroundTransparency = rng:NextNumber(0.3, 0.9)
			end
			rewindLabel.TextTransparency = (os.clock() % 0.6) < 0.3 and 0 or 0.4
			task.wait(0.04)
		end
	end)
end

local function stopRewind()
	if not rewinding then return end
	rewinding = false
	if rewindSound then
		local s = rewindSound
		rewindSound = nil
		tween(s, 0.3, {Volume = 0})
		task.delay(0.35, function() s:Destroy() end)
	end
	SoundConfig.PlayOnce(SoundConfig.Random("TapeClick"), SoundService, {Volume = 0.6})
	rewindLabel.Text = "PLAY ►"
	rewindLabel.TextTransparency = 0
	rewindCounter.Text = "00:00:00"
	for _, line in ipairs(rewindLines) do line.BackgroundTransparency = 1 end
	task.delay(0.3, function()
		if rewinding then return end
		rewind.Visible = false
		rewind.BackgroundTransparency = 0
		rewindCounter.TextTransparency = 0
	end)
end

makeButton("TRY AGAIN", function()
	buttonsEnabled = false
	SoundConfig.PlayOnce(SoundConfig.Random("TapeClick"), SoundService, {Volume = 0.6})
	startRewind(os.clock() - life.start)
	hideDeathInfo()
	card.GroupTransparency = 1
	epitaph.TextTransparency = 1
	question.TextTransparency = 1
	buttonRow.Visible = false
	task.delay(0.4, function()
		spawnRequest:FireServer()
	end)
	task.delay(10, function()
		if showing then
			stopRewind()
			busy = false
			buttonsEnabled = true
			showDeathInfo()
			buttonRow.Visible = true
			tween(card, 0.4, {GroupTransparency = 0})
		end
	end)
end)

makeButton("MAIN MENU", function()
	SoundConfig.PlayOnce(SoundConfig.Random("TapeClick"), SoundService, {Volume = 0.6})
	showing = false
	token += 1
	hideDeathInfo()
	gui.Enabled = false
	busy = false
	player:SetAttribute("OpenMenu", os.clock())
end)

local function onCharacter(character)
	life = {start = os.clock(), distance = 0, falls = 0, highestFall = 0}
	if showing then
		showing = false
		token += 1
		local my = token
		buttonsEnabled = false
		hideDeathInfo()
		black.BackgroundTransparency = 0
		card.GroupTransparency = 1
		epitaph.TextTransparency = 1
		question.TextTransparency = 1
		stopRewind()
		task.delay(0.35, function()
			if my ~= token then return end
			TweenService:Create(black, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 1}):Play()
		end)
		task.delay(2, function()
			if my ~= token then return end
			if not showing then gui.Enabled = false end
			busy = false
		end)
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then return end

	local lastPosition = root.Position
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not root.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			return
		end
		local delta = root.Position - lastPosition
		lastPosition = root.Position
		local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if horizontal < 5 and humanoid.FloorMaterial ~= Enum.Material.Air then
			life.distance += horizontal
		end
	end)

	character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		if character:GetAttribute("Ragdolled") and humanoid.Health > 0 then
			life.falls += 1
		end
	end)
	character:GetAttributeChangedSignal("LastFallHeight"):Connect(function()
		life.highestFall = math.max(life.highestFall, character:GetAttribute("LastFallHeight") or 0)
	end)

	humanoid.Died:Connect(function()
		task.spawn(showDeath, character)
	end)
end

if player.Character then task.spawn(onCharacter, player.Character) end
player.CharacterAdded:Connect(onCharacter)

local resetRemote = ReplicatedStorage:WaitForChild("ResetRequest", 20)
if resetRemote then
	local StarterGui = game:GetService("StarterGui")
	local resetEvent = Instance.new("BindableEvent")
	resetEvent.Event:Connect(function()
		resetRemote:FireServer()
	end)
	task.spawn(function()
		for _ = 1, 30 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", resetEvent)
			end)
			if ok then break end
			task.wait(1)
		end
	end)
end
]=]},
	{name = "GS_ItemService", class = "ModuleScript", where = "ServerStorage", source = [=[
-- Everything a player carries, holds and wears, kept on the server. Other server scripts require this
-- module (ShopServer buys and sells, Weapons fires, Monsters asks the armor how much a bite really hurts).
-- The client only asks (the GS_Inventory remote) and is told the result (GS_InvSync).
--
-- An entry: {uid, id, n = count, dur = durability (armor), ammo = rounds loaded (guns), worn = true}
-- Kept across servers for 5 minutes after leaving, like the cash (MemoryStore).
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local ShopModels = require(Modules:WaitForChild("ShopModels"))
local Wearables = require(Modules:WaitForChild("Wearables"))
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))

local Svc = {}
Svc.ItemData = ItemData

local KEEP_SECONDS = 5 * 60
local DROP_LIFETIME = 600
local TRAP_ARM_TIME = 1.5
local TRAP_OWNER_GRACE = 3

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local syncRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_InvSync")
local fxRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_ItemFX")
local dropFolder = ensure(workspace, "Folder", "GS_Items")
local trapFolder = ensure(workspace, "Folder", "GS_Traps")
Svc.SyncRemote, Svc.FxRemote = syncRemote, fxRemote

local store
pcall(function() store = MemoryStoreService:GetSortedMap("GS_Inventory") end)

local states = {}
local function serverNow() return workspace:GetServerTimeNow() end
local function newUid() return string.sub(HttpService:GenerateGUID(false), 1, 8) end

local function economy(kind, player, amount)
	local api = ServerStorage:FindFirstChild("GS_Economy")
	if not api then return false, "no economy" end
	return api:Invoke(kind, player, amount)
end

function Svc.PvP()
	return workspace:GetAttribute("GS_PvP") == true
end

-- ===================== state =====================
local function stateOf(player)
	local st = states[player]
	if not st then
		st = {items = {}, held = nil, loaded = false}
		states[player] = st
	end
	return st
end
Svc.State = stateOf

local function find(st, uid)
	for i, e in ipairs(st.items) do
		if e.uid == uid then return e, i end
	end
	return nil
end
Svc.Find = function(player, uid) return find(stateOf(player), uid) end

local function weightOf(st)
	local w = 0
	for _, e in ipairs(st.items) do
		local item = ItemData.Get(e.id)
		if item then w += item.weight * (item.stack > 1 and e.n or 1) end
	end
	return w
end

-- heavier = slower. A light kit costs nothing, full SCG plate costs about a quarter of your speed.
local function speedFor(weight)
	return math.clamp(1 - math.max(0, weight - 10) * 0.012, 0.55, 1)
end

local function snapshot(st)
	local list = {}
	for _, e in ipairs(st.items) do
		table.insert(list, {uid = e.uid, id = e.id, n = e.n, dur = e.dur, ammo = e.ammo, worn = e.worn})
	end
	local w = weightOf(st)
	return {items = list, held = st.held, weight = math.floor(w * 10 + 0.5) / 10, speed = speedFor(w), max = ItemData.MaxSlots}
end

local saveQueued = {}
local function save(player)
	local st = states[player]
	if not store or not st or not st.loaded then return end
	local data = {}
	for _, e in ipairs(st.items) do
		table.insert(data, {id = e.id, n = e.n, dur = e.dur, ammo = e.ammo, worn = e.worn})
	end
	pcall(function()
		if #data > 0 then
			store:SetAsync("u" .. player.UserId, HttpService:JSONEncode(data), KEEP_SECONDS)
		else
			store:RemoveAsync("u" .. player.UserId)
		end
	end)
end

local refreshBody
local function sync(player)
	local st = states[player]
	if not st or not player.Parent then return end
	local snap = snapshot(st)
	syncRemote:FireClient(player, snap)
	local character = player.Character
	if character then
		local boost = (character:GetAttribute("GS_BoostUntil") or 0) > serverNow() and 1.2 or 1
		character:SetAttribute("GS_CarrySpeed", snap.speed * boost)
		character:SetAttribute("GS_Weight", snap.weight)
	end
	if not saveQueued[player] then
		saveQueued[player] = true
		task.delay(5, function()
			saveQueued[player] = nil
			save(player)
		end)
	end
end
Svc.Sync = sync

local function load(player)
	local st = stateOf(player)
	if store then
		local ok, raw = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if ok and typeof(raw) == "string" then
			local okJson, data = pcall(function() return HttpService:JSONDecode(raw) end)
			if okJson and typeof(data) == "table" then
				for _, e in ipairs(data) do
					if ItemData.Get(e.id) and #st.items < ItemData.MaxSlots then
						table.insert(st.items, {uid = newUid(), id = e.id, n = math.max(1, math.floor(tonumber(e.n) or 1)),
							dur = tonumber(e.dur), ammo = tonumber(e.ammo), worn = e.worn == true})
					end
				end
			end
		end
	end
	st.loaded = true
	if player.Character then refreshBody(player) end
	sync(player)
end

-- ===================== giving and taking =====================
function Svc.Give(player, id, amount)
	local item = ItemData.Get(id)
	if not item then return false, "unknown item" end
	local st = stateOf(player)
	amount = math.max(1, math.floor(amount or 1))
	local left = amount
	-- top up stacks first
	if item.stack > 1 then
		for _, e in ipairs(st.items) do
			if e.id == id and e.n < item.stack then
				local add = math.min(item.stack - e.n, left)
				e.n += add
				left -= add
				if left <= 0 then break end
			end
		end
	end
	while left > 0 and #st.items < ItemData.MaxSlots do
		local n = math.min(item.stack, left)
		table.insert(st.items, {
			uid = newUid(), id = id, n = n,
			dur = item.kind == "armor" and item.durability or nil,
			ammo = item.kind == "gun" and 0 or nil,
		})
		left -= n
	end
	sync(player)
	if left == amount then return false, "your bag is full" end
	return true, left > 0 and "bag full - some was left behind" or nil, left
end

function Svc.CountOf(player, id)
	local total = 0
	for _, e in ipairs(stateOf(player).items) do
		if e.id == id and not e.worn then total += e.n end
	end
	return total
end

-- take `amount` of an item id from any stacks (ammo)
function Svc.TakeId(player, id, amount)
	local st = stateOf(player)
	local left = amount
	for i = #st.items, 1, -1 do
		local e = st.items[i]
		if e.id == id and not e.worn and left > 0 then
			local take = math.min(e.n, left)
			e.n -= take
			left -= take
			if e.n <= 0 then table.remove(st.items, i) end
		end
	end
	sync(player)
	return amount - left
end

local unequip
local function removeEntry(player, uid, amount)
	local st = stateOf(player)
	local e, i = find(st, uid)
	if not e then return nil end
	amount = math.clamp(math.floor(amount or e.n), 1, e.n)
	if st.held == uid and amount >= e.n then unequip(player, true) end
	if e.worn and amount >= e.n then Svc.Unwear(player, uid, true) end
	local taken = {id = e.id, n = amount, dur = e.dur, ammo = e.ammo}
	e.n -= amount
	if e.n <= 0 then table.remove(st.items, i) end
	sync(player)
	return taken
end
Svc.Remove = removeEntry

-- ===================== the body: held item, worn armor =====================
local HAND = CFrame.new(0, -1, 0) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0))
local BACK = CFrame.new(0, 0.1, 0.62) * CFrame.Angles(0, math.rad(180), math.rad(-55))

local function weldModel(model, part, cf, scale)
	if scale and scale ~= 1 then pcall(function() model:ScaleTo(scale) end) end
	model:PivotTo(cf)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
			local w = Instance.new("WeldConstraint")
			w.Part0 = part
			w.Part1 = p
			w.Parent = p
		end
	end
end

local function clearHeldModel(character)
	for _, name in ipairs({"GS_Held", "GS_Holstered"}) do
		local old = character:FindFirstChild(name)
		if old then old:Destroy() end
	end
end

local function buildHeld(character, id)
	local arm = character:FindFirstChild("Right Arm")
	if not arm then return nil end
	local model = ShopModels.Build(id)
	model.Name = "GS_Held"
	local scale = ShopModels.HeldScale[id] or 0.6
	local grip = ShopModels.Grip[id] or CFrame.new()
	grip = grip - grip.Position + grip.Position * scale
	model.Parent = character
	weldModel(model, arm, arm.CFrame * HAND * grip:Inverse(), scale)
	model:SetAttribute("ItemId", id)
	return model
end

-- long guns ride on the back while put away
local function buildHolstered(character, id)
	local item = ItemData.Get(id)
	local torso = character:FindFirstChild("Torso")
	if not item or item.pose ~= "long" or not torso then return end
	local model = ShopModels.Build(id)
	model.Name = "GS_Holstered"
	model.Parent = character
	weldModel(model, torso, torso.CFrame * BACK, ShopModels.HeldScale[id] or 0.8)
end

local function setHoldAttributes(character, item)
	character:SetAttribute("GS_Hold", item and item.id or nil)
	character:SetAttribute("GS_HoldPose", item and (item.pose or "item") or nil)
end

function unequip(player, instant)
	local st = stateOf(player)
	local character = player.Character
	local uid = st.held
	st.held = nil
	if character then
		local e = uid and find(st, uid)
		setHoldAttributes(character, nil)
		character:SetAttribute("GS_StowAt", serverNow())
		local function finish()
			if st.held ~= nil then return end
			clearHeldModel(character)
			local holster
			for _, other in ipairs(st.items) do
				local item = ItemData.Get(other.id)
				if item and item.pose == "long" then holster = other.id break end
			end
			if holster then buildHolstered(character, holster) end
		end
		if instant then finish() else task.delay(0.35, finish) end
		if e and ItemData.Get(e.id) then
			fxRemote:FireAllClients("stow", character, e.id)
		end
	end
	sync(player)
end
Svc.Unequip = unequip

function Svc.Equip(player, uid)
	local st = stateOf(player)
	local e = find(st, uid)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not e or not humanoid or humanoid.Health <= 0 then return false, "can't" end
	if character:GetAttribute("Infected") then return false, "your hands are not yours any more" end
	local item = ItemData.Get(e.id)
	if not item or item.kind == "armor" or item.kind == "ammo" then return false, "that can't be held" end
	if st.held == uid then return true end
	st.held = uid
	clearHeldModel(character)
	buildHeld(character, e.id)
	setHoldAttributes(character, item)
	character:SetAttribute("GS_DrawAt", serverNow())
	fxRemote:FireAllClients("draw", character, e.id)
	sync(player)
	return true
end

function Svc.Held(player)
	local st = stateOf(player)
	if not st.held then return nil end
	local e = find(st, st.held)
	if not e then
		st.held = nil
		return nil
	end
	return e, ItemData.Get(e.id)
end

-- hats and hair hide under a helmet
local function hideHeadgear(character, hide)
	for _, acc in ipairs(character:GetChildren()) do
		if acc:IsA("Accessory") then
			local ok, t = pcall(function() return acc.AccessoryType end)
			local onHead = ok and (t == Enum.AccessoryType.Hat or t == Enum.AccessoryType.Hair or t == Enum.AccessoryType.Face)
			local handle = acc:FindFirstChild("Handle")
			if onHead and handle then
				if hide then
					if handle:GetAttribute("GS_Transparency") == nil then handle:SetAttribute("GS_Transparency", handle.Transparency) end
					handle.Transparency = 1
				else
					local was = handle:GetAttribute("GS_Transparency")
					if was ~= nil then handle.Transparency = was handle:SetAttribute("GS_Transparency", nil) end
				end
			end
		end
	end
end

-- rebuilds everything on the body from the state (after a respawn, a load, or wearing / removing)
function refreshBody(player)
	local character = player.Character
	local st = states[player]
	if not character or not st then return end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model") and child.Name:sub(1, 8) == "GS_Wear_" then child:Destroy() end
	end
	local headCovered = false
	local filter = false
	for _, e in ipairs(st.items) do
		if e.worn then
			local item = ItemData.Get(e.id)
			Wearables.Attach(e.id, character)
			if item and table.find(item.slots or {}, "head") then headCovered = true end
			if item and item.filter then filter = true end
		end
	end
	hideHeadgear(character, headCovered)
	character:SetAttribute("GS_Filter", filter)
	-- the held item
	clearHeldModel(character)
	local e = st.held and find(st, st.held)
	if e and not character:GetAttribute("Infected") then
		buildHeld(character, e.id)
		setHoldAttributes(character, ItemData.Get(e.id))
	else
		st.held = nil
		setHoldAttributes(character, nil)
		for _, other in ipairs(st.items) do
			local item = ItemData.Get(other.id)
			if item and item.pose == "long" then buildHolstered(character, other.id) break end
		end
	end
end
Svc.RefreshBody = refreshBody

function Svc.Wear(player, uid)
	local st = stateOf(player)
	local e = find(st, uid)
	local character = player.Character
	if not e or not character then return false, "can't" end
	local item = ItemData.Get(e.id)
	if not item or item.kind ~= "armor" then return false, "that isn't worn" end
	if e.worn then return true end
	-- one piece per slot: whatever sits there now comes off first
	for _, other in ipairs(st.items) do
		if other.worn and other ~= e then
			local o = ItemData.Get(other.id)
			for _, slot in ipairs(item.slots) do
				if o and table.find(o.slots, slot) then other.worn = false end
			end
		end
	end
	if st.held == uid then unequip(player, true) end
	e.worn = true
	refreshBody(player)
	fxRemote:FireAllClients("wear", character, e.id)
	sync(player)
	return true
end

function Svc.Unwear(player, uid, silent)
	local st = stateOf(player)
	local e = find(st, uid)
	if not e or not e.worn then return false end
	e.worn = false
	refreshBody(player)
	if not silent and player.Character then fxRemote:FireAllClients("unwear", player.Character, e.id) end
	sync(player)
	return true
end

-- ===================== armor against damage =====================
-- damage to one body part: worn armor takes a share of it (and wears down). Returns the damage that
-- gets through and whether the armor stopped the wound itself (no broken bone this time).
function Svc.Absorb(character, partKey, damage, damageType)
	local player = Players:GetPlayerFromCharacter(character)
	local st = player and states[player]
	if not st then return damage, false end
	local slots = ItemData.PartSlots[partKey]
	if not slots then return damage, false end
	local best, bestProt = nil, 0
	for _, e in ipairs(st.items) do
		if e.worn then
			local item = ItemData.Get(e.id)
			local prot = item and item.covers and item.covers[partKey]
			if prot and prot > bestProt then best, bestProt = e, prot end
		end
	end
	if not best then return damage, false end
	local item = ItemData.Get(best.id)
	if damageType == "acid" then bestProt *= 0.5 end
	local absorbed = damage * bestProt
	best.dur = (best.dur or item.durability) - absorbed * (item.fragile and 2.2 or 1.2)
	local blocked = math.random() < bestProt
	if best.dur <= 0 then
		-- it breaks and falls off
		local _, i = find(st, best.uid)
		if i then table.remove(st.items, i) end
		refreshBody(player)
		fxRemote:FireAllClients("armorbreak", character, best.id)
	end
	sync(player)
	return damage - absorbed, blocked
end

function Svc.HasFilter(character)
	return character:GetAttribute("GS_Filter") == true
end

-- ===================== buying and selling =====================
function Svc.Buy(player, id)
	local item = ItemData.Get(id)
	if not item or item.adminOnly or (item.price or 0) <= 0 then return false, "not for sale" end
	local cash = economy("get", player) or 0
	if cash < item.price then return false, "not enough money" end
	local amount = item.buyAmount or 1
	-- room check before taking money
	local st = stateOf(player)
	local room = (ItemData.MaxSlots - #st.items) * item.stack
	if item.stack > 1 then
		for _, e in ipairs(st.items) do
			if e.id == id then room += item.stack - e.n end
		end
	end
	if room < amount then return false, "your bag is full" end
	local ok = economy("add", player, -item.price)
	if not ok then return false, "the trader refused" end
	Svc.Give(player, id, amount)
	return true
end

function Svc.Sell(player, uid, amount)
	local st = stateOf(player)
	local e = find(st, uid)
	if not e then return false, "you don't have that" end
	local item = ItemData.Get(e.id)
	if not item or item.adminOnly then return false, "the trader won't touch that" end
	amount = math.clamp(math.floor(amount or e.n), 1, e.n)
	local each = item.sell
	if item.kind == "ammo" and item.buyAmount then each = item.sell / item.buyAmount end
	if item.kind == "armor" and e.dur and item.durability then each = each * math.clamp(e.dur / item.durability, 0.2, 1) end
	local pay = math.max(1, math.floor(each * amount + 0.5))
	removeEntry(player, uid, amount)
	economy("add", player, pay)
	return true, pay
end

-- ===================== dropping for someone else =====================
local function prompt(parent, action, object, hold)
	local p = Instance.new("ProximityPrompt")
	p.Name = "GS_ItemPrompt"
	p.Style = Enum.ProximityPromptStyle.Custom
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0.3
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = parent
	return p
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(position, ignore)
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), groundParams)
	return hit and hit.Position or nil
end

local function bodiesAndFolders()
	local list = {dropFolder, trapFolder}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(list, plr.Character) end
	end
	for _, name in ipairs({"Monsters", "NPCs", "Corpses", "SeveredLimbs"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(list, f) end
	end
	return list
end

function Svc.SpawnDrop(entry, position, droppedBy)
	local item = ItemData.Get(entry.id)
	if not item then return nil end
	local model = ShopModels.Build(entry.id)
	model.Name = "GS_Drop_" .. entry.id
	pcall(function() model:ScaleTo(ShopModels.HeldScale[entry.id] or 0.6) end)
	local ground = groundBelow(position, bodiesAndFolders()) or position
	local _, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(ground + Vector3.new(0, size.Y / 2 + 0.05, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	local base
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = true
			base = base or p
		end
	end
	if not base then model:Destroy() return nil end
	model:SetAttribute("Entry", HttpService:JSONEncode({id = entry.id, n = entry.n, dur = entry.dur, ammo = entry.ammo}))
	model:SetAttribute("DroppedBy", droppedBy)
	local label = item.name .. ((entry.n or 1) > 1 and ("  x" .. entry.n) or "")
	local p = prompt(base, "Pick up", label, 0.35)
	model.Parent = dropFolder
	p.Triggered:Connect(function(who)
		if not model.Parent then return end
		local data = HttpService:JSONDecode(model:GetAttribute("Entry"))
		local ok, _, left = Svc.Give(who, data.id, data.n)
		if not ok then
			fxRemote:FireClient(who, "toast", "your bag is full")
			return
		end
		-- keep the durability / loaded rounds of what was picked up
		local st = stateOf(who)
		for i = #st.items, 1, -1 do
			local e = st.items[i]
			if e.id == data.id then
				if data.dur then e.dur = data.dur end
				if data.ammo then e.ammo = data.ammo end
				break
			end
		end
		sync(who)
		fxRemote:FireAllClients("pickup", who.Character, data.id)
		if left and left > 0 then
			data.n = left
			model:SetAttribute("Entry", HttpService:JSONEncode(data))
		else
			model:Destroy()
		end
	end)
	task.delay(DROP_LIFETIME, function() if model.Parent then model:Destroy() end end)
	return model
end

function Svc.Drop(player, uid, amount)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local taken = removeEntry(player, uid, amount)
	if not taken then return false end
	Svc.SpawnDrop(taken, root.Position + root.CFrame.LookVector * 2.5, player.Name)
	fxRemote:FireAllClients("drop", character, taken.id)
	return true
end

-- ===================== using things =====================
function Svc.UseBegin(player, uid)
	local st = stateOf(player)
	local e = find(st, uid)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not e or not humanoid or humanoid.Health <= 0 then return false end
	local item = ItemData.Get(e.id)
	if not item or item.kind ~= "heal" then return false end
	st.using = {uid = uid, t0 = os.clock()}
	character:SetAttribute("GS_UseStart", serverNow())
	character:SetAttribute("GS_UseItem", e.id)
	fxRemote:FireAllClients("usebegin", character, e.id)
	return true, item.useTime
end

function Svc.UseCancel(player)
	local st = stateOf(player)
	st.using = nil
	if player.Character then
		player.Character:SetAttribute("GS_UseStart", nil)
		player.Character:SetAttribute("GS_UseItem", nil)
	end
end

function Svc.UseFinish(player, uid, quality)
	local st = stateOf(player)
	local using = st.using
	st.using = nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character then
		character:SetAttribute("GS_UseStart", nil)
		character:SetAttribute("GS_UseItem", nil)
	end
	if not using or using.uid ~= uid or not humanoid or humanoid.Health <= 0 then return false end
	local e = find(st, uid)
	local item = e and ItemData.Get(e.id)
	if not item then return false end
	-- a finished mini-game can't be quicker than a real hand
	if os.clock() - using.t0 < item.useTime * 0.6 then return false, "too fast" end
	quality = math.clamp(tonumber(quality) or 0.5, 0, 1)
	local strength = 0.55 + 0.45 * quality
	if item.hp then humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + item.hp * strength) end
	if item.stopBleed and quality > 0.2 then FallDamageController.StopBleeding(character) end
	if item.fixLegs then
		for _, key in ipairs({"LeftLeg", "RightLeg"}) do
			local level = character:GetAttribute("Injury_" .. key) or 0
			if level > 0 and level < 3 then character:SetAttribute("Injury_" .. key, quality > 0.5 and 0 or 1) end
		end
	end
	if item.fixOne then
		local worst, worstLevel = nil, 0
		for _, key in ipairs({"LeftArm", "RightArm", "LeftLeg", "RightLeg", "Torso", "Head"}) do
			local level = character:GetAttribute("Injury_" .. key) or 0
			if level > worstLevel and level < 3 then worst, worstLevel = key, level end
		end
		if worst then character:SetAttribute("Injury_" .. worst, math.max(0, worstLevel - (quality > 0.6 and 2 or 1))) end
	end
	if item.painkill then
		-- a slow steady heal while the pills work
		task.spawn(function()
			for _ = 1, 12 do
				task.wait(1)
				if humanoid.Health <= 0 then break end
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 1)
			end
		end)
	end
	if item.boost then
		character:SetAttribute("GS_BoostUntil", serverNow() + item.boost)
		task.delay(item.boost + 0.1, function() if player.Parent then sync(player) end end)
	end
	removeEntry(player, uid, 1)
	fxRemote:FireAllClients("used", character, item.id, quality)
	return true
end

-- the road flare: light it in the hand, it burns for a minute and is gone
function Svc.LightFlare(player, uid)
	local st = stateOf(player)
	local e = find(st, uid)
	local character = player.Character
	if not e or e.id ~= "flare" or st.held ~= uid or not character then return false end
	if e.lit then return false end
	e.lit = true
	local held = character:FindFirstChild("GS_Held")
	local tip = held and held:FindFirstChildWhichIsA("BasePart")
	if tip then
		local light = Instance.new("PointLight")
		light.Name = "GS_FlareLight"
		light.Color = Color3.fromRGB(255, 70, 50)
		light.Range = 26
		light.Brightness = 2.4
		light.Shadows = true
		light.Parent = tip
		local fire = Instance.new("ParticleEmitter")
		fire.Name = "GS_FlareFire"
		fire.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 90, 60), Color3.fromRGB(255, 200, 120))
		fire.LightEmission = 1
		fire.Size = NumberSequence.new(0.25, 0)
		fire.Lifetime = NumberRange.new(0.3, 0.6)
		fire.Rate = 60
		fire.Speed = NumberRange.new(2, 5)
		fire.SpreadAngle = Vector2.new(25, 25)
		fire.Parent = tip
	end
	character:SetAttribute("GS_FlareLit", serverNow())
	task.delay(ItemData.Get("flare").burn, function()
		if find(st, uid) then removeEntry(player, uid, 1) end
		if character.Parent then character:SetAttribute("GS_FlareLit", nil) end
	end)
	return true
end

-- ===================== bear traps =====================
local traps = {}

local function setJaws(model, closed)
	for _, name in ipairs({"JawA", "JawB"}) do
		local jaw = model:FindFirstChild(name)
		if jaw then
			local side = name == "JawA" and -1 or 1
			local pivot = model:GetAttribute("BaseCF")
			if typeof(pivot) == "CFrame" then
				-- open: flat on the ground; shut: raised up to meet in the middle
				local angle = closed and math.rad(82) * -side or 0
				local base = jaw:GetAttribute("OpenCF")
				if typeof(base) ~= "CFrame" then
					base = jaw:GetPivot()
					jaw:SetAttribute("OpenCF", base)
				end
				local hinge = pivot * CFrame.Angles(angle, 0, 0)
				jaw:PivotTo(hinge * (pivot:Inverse() * base))
			end
		end
	end
end

local releaseTrap
local function buildTrap(position, owner)
	local model = ShopModels.Build("beartrap")
	model.Name = "GS_BearTrap"
	pcall(function() model:ScaleTo(0.9) end)
	local ground = groundBelow(position, bodiesAndFolders()) or position
	local cf = CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	model:PivotTo(cf)
	model:SetAttribute("BaseCF", cf)
	local base
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			base = base or p
		end
	end
	for _, name in ipairs({"JawA", "JawB"}) do
		local jaw = model:FindFirstChild(name)
		if jaw then jaw:SetAttribute("OpenCF", jaw:GetPivot()) end
	end
	model.Parent = trapFolder
	local entry = {model = model, base = base, center = ground, owner = owner, armedAt = os.clock() + TRAP_ARM_TIME, placedAt = os.clock()}
	entry.prompt = prompt(base, "Pick up", "BEAR TRAP", 0.8)
	entry.prompt.Triggered:Connect(function(who)
		if entry.victim then
			releaseTrap(entry)
			return
		end
		if not model.Parent then return end
		local ok = Svc.Give(who, "beartrap", 1)
		if ok then
			model:Destroy()
			entry.dead = true
		end
	end)
	table.insert(traps, entry)
	fxRemote:FireAllClients("trapset", model)
	return entry
end

function releaseTrap(entry)
	if entry.weld then entry.weld:Destroy() entry.weld = nil end
	local victim = entry.victim
	entry.victim = nil
	if victim and victim.Parent then
		victim:SetAttribute("GS_Trapped", nil)
		victim:SetAttribute("AC_TeleportAt", serverNow())
	end
	if entry.prompt then
		entry.prompt.ActionText = "Pick up"
		entry.prompt.HoldDuration = 0.8
	end
	setJaws(entry.model, false)
	entry.armedAt = math.huge -- sprung: it has to be picked up and set again
	fxRemote:FireAllClients("trapopen", entry.model)
end

function Svc.PlaceTrap(player, uid)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local e = find(stateOf(player), uid)
	if not root or not e or e.id ~= "beartrap" then return false end
	removeEntry(player, uid, 1)
	buildTrap(root.Position + root.CFrame.LookVector * 3, player)
	return true
end

local function snap(entry, victim, isMonster)
	entry.armedAt = math.huge
	setJaws(entry.model, true)
	fxRemote:FireAllClients("trapsnap", entry.model, victim)
	local item = ItemData.Get("beartrap")
	if isMonster then
		local health = ServerStorage:FindFirstChild("GS_MonsterHealth")
		if health then
			pcall(function() health:Invoke("damage", victim, "LeftLeg", item.monsterDamage, "trap", entry.owner) end)
		end
		local control = ServerStorage:FindFirstChild("GS_MonsterControl")
		if control then pcall(function() control:Invoke("Stun", victim, item.stun) end) end
		task.delay(item.stun, function() if entry.model.Parent then setJaws(entry.model, false) end end)
		return
	end
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end
	victim:SetAttribute("LastDamageCause", "TRAP")
	victim:SetAttribute("LastDamageTime", serverNow())
	local dmg = Svc.Absorb(victim, "LeftLeg", item.damage, "trap")
	humanoid:TakeDamage(dmg)
	local leg = math.random() < 0.5 and "LeftLeg" or "RightLeg"
	local level = victim:GetAttribute("Injury_" .. leg) or 0
	if level < 2 and humanoid.Health > 0 then FallDamageController.Injure(victim, leg, 2) end
	-- held in place until the jaws are pried open or the timer runs out
	entry.victim = victim
	victim:SetAttribute("GS_Trapped", serverNow() + item.hold)
	victim:SetAttribute("AC_TeleportAt", serverNow())
	local w = Instance.new("WeldConstraint")
	w.Part0 = entry.base
	w.Part1 = root
	w.Parent = entry.base
	entry.weld = w
	entry.prompt.ActionText = "Pry open"
	entry.prompt.HoldDuration = 1.5
	task.delay(item.hold, function() if entry.victim == victim then releaseTrap(entry) end end)
end

local function trapTargets(entry, now)
	local list = {}
	local pvp = Svc.PvP()
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if c and h and h.Health > 0 and not c:GetAttribute("GS_Trapped") then
			local mine = plr == entry.owner
			local allowed = c:GetAttribute("Infected") or pvp or mine
			if allowed and not (mine and now - entry.placedAt < TRAP_OWNER_GRACE) then
				table.insert(list, {c, false})
			end
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	for _, npc in ipairs(npcs and npcs:GetChildren() or {}) do
		if npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart") then table.insert(list, {npc, false}) end
	end
	local monsters = workspace:FindFirstChild("Monsters")
	for _, m in ipairs(monsters and monsters:GetChildren() or {}) do
		if m:IsA("Model") and m:GetAttribute("MonsterId") and not m:GetAttribute("GS_Dead") then table.insert(list, {m, true}) end
	end
	return list
end

task.spawn(function()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for i = #traps, 1, -1 do
			local entry = traps[i]
			if entry.dead or not entry.model.Parent then
				table.remove(traps, i)
			elseif now >= entry.armedAt then
				for _, t in ipairs(trapTargets(entry, now)) do
					local root = t[1]:FindFirstChild("HumanoidRootPart")
					if root then
						local d = Vector3.new(root.Position.X - entry.center.X, 0, root.Position.Z - entry.center.Z).Magnitude
						local dy = root.Position.Y - entry.center.Y
						if d < 1.9 and dy > -1 and dy < 5 then
							snap(entry, t[1], t[2])
							break
						end
					end
				end
			end
		end
	end
end)

-- ===================== players coming and going =====================
local function onCharacter(player, character)
	character:WaitForChild("Humanoid", 10)
	task.wait(0.2)
	if states[player] then
		refreshBody(player)
		sync(player)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			local st = states[player]
			if st then
				st.held = nil
				st.using = nil
			end
		end)
	end
	-- the infected drop what's in their hands
	character:GetAttributeChangedSignal("Infected"):Connect(function()
		if character:GetAttribute("Infected") and states[player] and states[player].held then unequip(player, true) end
	end)
end

local function onPlayer(player)
	stateOf(player)
	player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
	task.spawn(load, player)
end

-- this module is required by several scripts: hook the players only once
if not _G.GS_ItemServiceStarted then
	_G.GS_ItemServiceStarted = true
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, player) end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		states[player] = nil
		saveQueued[player] = nil
	end)
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do task.spawn(save, player) end
		task.wait(2)
	end)
	-- the adrenaline boost wears off on its own; keep everyone's speed attribute honest
	task.spawn(function()
		while true do
			task.wait(2)
			for player, st in pairs(states) do
				local c = player.Character
				if c and (c:GetAttribute("GS_BoostUntil") or 0) > 0 and (c:GetAttribute("GS_BoostUntil") or 0) < serverNow() then
					c:SetAttribute("GS_BoostUntil", nil)
					sync(player)
				end
			end
		end
	end)
end

return Svc
]=]},
	{name = "Inventory", class = "Script", where = "ServerScriptService", source = [=[
-- The bag: what the item wheel (InventoryUI) asks the server to do, checked here and carried out by
-- ServerStorage.GS_ItemService. Admins give items through ServerStorage.GS_ItemAdmin (the admin panel).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Svc = require(ServerStorage:WaitForChild("GS_ItemService"))
local ItemData = Svc.ItemData

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local remote = ensure(ReplicatedStorage, "RemoteFunction", "GS_Inventory")
local adminApi = ensure(ServerStorage, "BindableFunction", "GS_ItemAdmin")

local function alive(player)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and not c:GetAttribute("Ragdolled")
end

local ACTIONS = {}

ACTIONS.get = function(player)
	return true, nil
end

ACTIONS.equip = function(player, uid)
	if not alive(player) then return false, "not now" end
	local e = Svc.Find(player, uid)
	if not e then return false, "you don't have that" end
	local item = ItemData.Get(e.id)
	if item.kind == "armor" then return Svc.Wear(player, uid) end
	if item.kind == "ammo" then return false, "ammo goes into a gun" end
	return Svc.Equip(player, uid)
end

ACTIONS.holster = function(player)
	Svc.Unequip(player, false)
	return true
end

ACTIONS.wear = function(player, uid)
	if not alive(player) then return false, "not now" end
	return Svc.Wear(player, uid)
end

ACTIONS.unwear = function(player, uid)
	return Svc.Unwear(player, uid)
end

ACTIONS.drop = function(player, uid, amount)
	if not player.Character then return false end
	return Svc.Drop(player, uid, amount)
end

ACTIONS.usebegin = function(player, uid)
	if not alive(player) then return false, "not now" end
	local e = Svc.Find(player, uid)
	if not e then return false end
	local item = ItemData.Get(e.id)
	if item.kind == "trap" then return Svc.PlaceTrap(player, uid) end
	if item.kind == "light" then
		if Svc.State(player).held ~= uid then Svc.Equip(player, uid) end
		return Svc.LightFlare(player, uid)
	end
	return Svc.UseBegin(player, uid)
end

ACTIONS.usefinish = function(player, uid, quality)
	return Svc.UseFinish(player, uid, quality)
end

ACTIONS.usecancel = function(player)
	Svc.UseCancel(player)
	return true
end

-- selling happens at the shop counter (ShopServer checks the distance and calls Svc.Sell itself);
-- the wheel only lists what could be sold
ACTIONS.sellprices = function(player)
	local list = {}
	for _, e in ipairs(Svc.State(player).items) do
		local item = ItemData.Get(e.id)
		if item and not item.adminOnly then
			local each = item.sell
			if item.kind == "ammo" and item.buyAmount then each = item.sell / item.buyAmount end
			list[e.uid] = math.max(1, math.floor(each * e.n + 0.5))
		end
	end
	return true, list
end

local last = {}
remote.OnServerInvoke = function(player, action, ...)
	local now = os.clock()
	if now - (last[player] or 0) < 0.08 then return false, "slow down" end
	last[player] = now
	local handler = typeof(action) == "string" and ACTIONS[action]
	if not handler then return false, "unknown" end
	local ok, a, b = pcall(handler, player, ...)
	if not ok then
		warn("[Inventory] " .. tostring(a))
		return false, "error"
	end
	Svc.Sync(player)
	return a, b
end
Players.PlayerRemoving:Connect(function(player) last[player] = nil end)

-- ===== admin: give items, the SCG set, PvP =====
adminApi.OnInvoke = function(action, target, id, amount)
	if action == "give" then
		if typeof(target) ~= "Instance" or not target:IsA("Player") then return false, "player not found" end
		if id == "scg_set" then
			for _, piece in ipairs(ItemData.SCG_SET) do Svc.Give(target, piece, 1) end
			Svc.Give(target, "shells12", 24)
			return true, target.DisplayName .. " got the SCG set"
		end
		local item = ItemData.Get(id)
		if not item then return false, "unknown item" end
		local ok, message = Svc.Give(target, id, math.clamp(math.floor(tonumber(amount) or 1), 1, 200))
		return ok, ok and string.format("%s got %s x%d", target.DisplayName, item.name, math.floor(tonumber(amount) or 1)) or message
	elseif action == "clear" then
		if typeof(target) ~= "Instance" or not target:IsA("Player") then return false, "player not found" end
		local st = Svc.State(target)
		Svc.Unequip(target, true)
		table.clear(st.items)
		Svc.RefreshBody(target)
		Svc.Sync(target)
		return true, target.DisplayName .. "'s bag emptied"
	elseif action == "pvp" then
		workspace:SetAttribute("GS_PvP", target == true)
		return true, target == true and "PvP on: players can hurt each other" or "PvP off"
	end
	return false, "unknown"
end
workspace:SetAttribute("GS_PvP", workspace:GetAttribute("GS_PvP") == true)
]=]},
	{name = "InventoryUI", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- The bag, as a wheel. Same look as the rest of the game: black cards, thin frames, typewriter type, blood red.
--   Q (hold)     open the wheel; point at an item and let go to take it (or wear it / take it off)
--   Q (tap)      open it and click: LMB take in hand / wear / take off, RMB drop it on the ground for someone else
--   centre       put away what's in your hand
--   H            put away, G drop what's in your hand
--   touch        the BAG button opens it; tap an item, then the buttons in the middle
-- Holding a medical item, LMB (or USE) starts a short mini-game: hit the green arc when the needle crosses it.
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local ShopModels = require(Modules:WaitForChild("ShopModels"))
local SoundConfig = require(Modules:WaitForChild("SoundConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local invRemote = ReplicatedStorage:WaitForChild("GS_Inventory", 60)
local syncRemote = ReplicatedStorage:WaitForChild("GS_InvSync", 60)
local itemFx = ReplicatedStorage:WaitForChild("GS_ItemFX", 60)
if not invRemote or not syncRemote then return end

local clientAction = player:WaitForChild("GS_ClientAction", 30)

local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local FONT = Enum.Font.SpecialElite
local INK = Color3.fromRGB(236, 230, 222)
local MID = Color3.fromRGB(190, 184, 178)
local DIM = Color3.fromRGB(120, 112, 106)
local LINE = Color3.fromRGB(70, 60, 56)
local PANEL = Color3.fromRGB(8, 6, 6)
local BLOOD = Color3.fromRGB(150, 12, 16)
local BRIGHT = Color3.fromRGB(225, 40, 40)
local AMBER = Color3.fromRGB(232, 164, 52)
local GREEN = Color3.fromRGB(110, 200, 90)

local SLOTS = ItemData.MaxSlots
local RADIUS = 200
local CARD = 78

local function create(className, props, children)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	return obj
end
local function tween(obj, t, goal, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function sfx(name, volume, speed)
	pcall(function() SoundConfig.PlayOnce(name, SoundService, {Volume = volume or 0.4, PlaybackSpeed = speed or 1}) end)
end
local function itemSound(name, volume, speed)
	local id = ItemData.Sound(name)
	if not id then return end
	local s = create("Sound", {SoundId = id, Volume = volume or 0.5, PlaybackSpeed = speed or 1, Parent = SoundService})
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	task.delay(6, function() if s.Parent then s:Destroy() end end)
end

-- ===== state from the server =====
local bag = {items = {}, weight = 0, speed = 1, max = SLOTS}
local function entryByUid(uid)
	for _, e in ipairs(bag.items) do
		if e.uid == uid then return e end
	end
	return nil
end
local function heldEntry()
	return bag.held and entryByUid(bag.held) or nil
end

local function ask(action, ...)
	local args = table.pack(...)
	local ok, a, b = pcall(function() return invRemote:InvokeServer(action, table.unpack(args, 1, args.n)) end)
	if not ok then return false end
	return a, b
end

-- ===== the wheel =====
local gui = create("ScreenGui", {
	Name = "GS_ItemWheel", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 45, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
})
local shade = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = gui})
local wheel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(RADIUS * 2 + CARD + 20, RADIUS * 2 + CARD + 20),
	BackgroundTransparency = 1, Parent = gui,
})
local wheelScale = create("UIScale", {Parent = wheel})
-- a faint ring the cards sit on
create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(RADIUS * 2, RADIUS * 2),
	BackgroundTransparency = 1, Parent = wheel,
}, {
	create("UICorner", {CornerRadius = UDim.new(1, 0)}),
	create("UIStroke", {Color = LINE, Thickness = 1, Transparency = 0.3}),
})

-- the centre: the pointed-at item, or the load you carry
local center = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(250, 250),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, Parent = wheel,
}, {
	create("UICorner", {CornerRadius = UDim.new(1, 0)}),
	create("UIStroke", {Color = BLOOD, Thickness = 1.5}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 6, 6), Color3.fromRGB(0, 0, 0))}),
})
local function label(parent, props)
	local base = {BackgroundTransparency = 1, Font = FONT, TextColor3 = INK, TextSize = 14, Parent = parent}
	for k, v in pairs(props) do base[k] = v end
	return create("TextLabel", base)
end
local cName = label(center, {Position = UDim2.fromOffset(20, 40), Size = UDim2.fromOffset(210, 26), TextSize = 20, TextWrapped = true})
local cKind = label(center, {Position = UDim2.fromOffset(20, 68), Size = UDim2.fromOffset(210, 16), TextSize = 12, TextColor3 = DIM})
local cInfo = label(center, {Position = UDim2.fromOffset(30, 88), Size = UDim2.fromOffset(190, 64), TextSize = 12, TextColor3 = MID,
	TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
local durBack = create("Frame", {
	Position = UDim2.fromOffset(45, 156), Size = UDim2.fromOffset(160, 6), BackgroundColor3 = Color3.fromRGB(40, 12, 12),
	BorderSizePixel = 0, Parent = center,
})
local durFill = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0, Parent = durBack})
local durText = label(center, {Position = UDim2.fromOffset(45, 164), Size = UDim2.fromOffset(160, 14), TextSize = 11, TextColor3 = DIM})
local cHint = label(center, {Position = UDim2.fromOffset(20, 184), Size = UDim2.fromOffset(210, 30), TextSize = 12, TextColor3 = BRIGHT,
	TextWrapped = true})
local cLoad = label(center, {Position = UDim2.fromOffset(20, 214), Size = UDim2.fromOffset(210, 16), TextSize = 11, TextColor3 = DIM})

-- touch: action buttons in the middle once an item is tapped
local touchBar = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 186), Size = UDim2.fromOffset(220, 30),
	BackgroundTransparency = 1, Visible = false, Parent = center,
}, {create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6)})})
local function touchButton(text, width)
	return create("TextButton", {
		Size = UDim2.fromOffset(width, 30), BackgroundColor3 = Color3.fromRGB(18, 8, 8), AutoButtonColor = true, Font = FONT,
		Text = text, TextSize = 14, TextColor3 = INK, Parent = touchBar,
	}, {create("UIStroke", {Color = BLOOD, Thickness = 1})})
end
local primaryBtn = touchButton("TAKE", 110)
local dropBtn = touchButton("DROP", 90)

-- the twelve cards
local cards = {}
for i = 1, SLOTS do
	local angle = math.rad(-90 + (i - 1) * (360 / SLOTS))
	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(CARD, CARD), BackgroundColor3 = Color3.fromRGB(12, 11, 11),
		BackgroundTransparency = 0.05, BorderSizePixel = 0,
		Position = UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS), Parent = wheel,
	}, {create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 30, 30), Color3.fromRGB(6, 6, 6))})})
	local stroke = create("UIStroke", {Color = LINE, Thickness = 1, Parent = holder})
	local scale = create("UIScale", {Parent = holder})
	local view = create("ViewportFrame", {
		Size = UDim2.new(1, -8, 1, -22), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(125, 115, 110), LightColor = Color3.fromRGB(255, 236, 222), LightDirection = Vector3.new(-0.6, -1, -0.4),
		Parent = holder,
	})
	local cam = create("Camera", {FieldOfView = 30, Parent = view})
	view.CurrentCamera = cam
	local nameText = label(holder, {Position = UDim2.new(0, 3, 1, -18), Size = UDim2.new(1, -6, 0, 16), TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = MID})
	local count = label(holder, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(40, 14),
		TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right})
	local tag = label(holder, {Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(50, 14), TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = AMBER})
	local dur = create("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -18), Size = UDim2.new(1, -8, 0, 3),
		BackgroundColor3 = GREEN, BorderSizePixel = 0, Visible = false, Parent = holder,
	})
	cards[i] = {holder = holder, stroke = stroke, scale = scale, view = view, cam = cam, name = nameText, count = count, tag = tag,
		dur = dur, angle = angle, id = nil}
end

local function durColor(frac)
	if frac > 0.6 then return GREEN end
	if frac > 0.3 then return AMBER end
	return BRIGHT
end

local function setView(card, id)
	if card.id == id then return end
	card.id = id
	for _, c in ipairs(card.view:GetChildren()) do
		if c:IsA("Model") then c:Destroy() end
	end
	if not id then return end
	local model = ShopModels.Build(id)
	model.Parent = card.view
	local cf, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot())
	local radius = size.Magnitude / 2
	card.cam.CFrame = CFrame.lookAt(Vector3.new(radius * 0.5, radius * 0.45, -radius / math.tan(math.rad(15)) * 1.05), Vector3.zero)
end

local hovered = nil -- card index
local picked = nil -- touch: the tapped card

local function actionFor(e)
	local item = e and ItemData.Get(e.id)
	if not item then return nil end
	if item.kind == "armor" then return e.worn and "TAKE OFF" or "WEAR" end
	if item.kind == "ammo" then return nil end
	if bag.held == e.uid then return "PUT AWAY" end
	return "TAKE"
end

local function describe(e)
	local item = e and ItemData.Get(e.id)
	durBack.Visible, durText.Visible = false, false
	touchBar.Visible = false
	if not item then
		local h = heldEntry()
		local hi = h and ItemData.Get(h.id)
		cName.Text = hi and ("IN HAND: " .. hi.name) or "YOUR BAG"
		cKind.Text = string.format("%d / %d slots", #bag.items, bag.max or SLOTS)
		cInfo.Text = hi and "point at the middle and click to put it away" or "point at something"
		cHint.Text = TOUCH and "" or (hi and "[LMB] PUT AWAY" or "")
		return
	end
	cName.Text = item.name
	local kinds = {melee = "MELEE", gun = "FIREARM", heal = "MEDICAL", light = "LIGHT", armor = "ARMOR", ammo = "AMMUNITION", trap = "TRAP"}
	local kindText = kinds[item.kind] or ""
	if item.kind == "armor" then
		local slots = {}
		for _, s in ipairs(item.slots or {}) do table.insert(slots, ItemData.SlotNames[s] or s) end
		kindText = kindText .. "  -  " .. table.concat(slots, " + ") .. (e.worn and "  -  WORN" or "")
	end
	cKind.Text = kindText .. string.format("  -  %.1f kg", item.weight * (item.stack > 1 and e.n or 1))
	local info = item.desc or ""
	if item.kind == "gun" then
		info = string.format("%d / %d loaded, %d spare. ", e.ammo or 0, item.magazine, 0) .. info
		local spare = 0
		for _, other in ipairs(bag.items) do
			if other.id == item.ammo then spare += other.n end
		end
		info = string.format("%d / %d loaded  -  %d spare\n", e.ammo or 0, item.magazine, spare) .. (item.desc or "")
	elseif item.kind == "melee" then
		info = string.format("%d damage%s\n", item.damage, item.stun and " + shock" or (item.bleed and " + bleeding" or "")) .. info
	elseif e.n > 1 then
		info = "x" .. e.n .. "\n" .. info
	end
	cInfo.Text = info
	if item.kind == "armor" and e.dur and item.durability then
		local frac = math.clamp(e.dur / item.durability, 0, 1)
		durBack.Visible, durText.Visible = true, true
		durFill.Size = UDim2.fromScale(frac, 1)
		durFill.BackgroundColor3 = durColor(frac)
		durText.Text = string.format("DURABILITY %d%%%s", math.floor(frac * 100 + 0.5), item.fragile and "  -  fragile" or "")
	end
	local action = actionFor(e)
	if TOUCH then
		cHint.Text = ""
		touchBar.Visible = picked ~= nil
		primaryBtn.Visible = action ~= nil
		primaryBtn.Text = action or ""
	else
		cHint.Text = (action and ("[LMB] " .. action .. "   ") or "") .. "[RMB] DROP"
	end
end

local function refreshCards()
	for i, card in ipairs(cards) do
		local e = bag.items[i]
		setView(card, e and e.id or nil)
		local item = e and ItemData.Get(e.id)
		card.name.Text = item and item.name or ""
		card.count.Text = (e and e.n > 1) and ("x" .. e.n) or ""
		if item and item.kind == "gun" then card.count.Text = string.format("%d/%d", e.ammo or 0, item.magazine) end
		card.tag.Text = e and (e.worn and "WORN" or (bag.held == e.uid and "HAND" or "")) or ""
		card.tag.TextColor3 = e and e.worn and BRIGHT or AMBER
		card.holder.BackgroundTransparency = e and 0.05 or 0.55
		card.dur.Visible = item ~= nil and item.kind == "armor" and e.dur ~= nil
		if card.dur.Visible then
			local frac = math.clamp(e.dur / item.durability, 0, 1)
			card.dur.Size = UDim2.new(frac, -8 * frac, 0, 3)
			card.dur.BackgroundColor3 = durColor(frac)
		end
	end
	cLoad.Text = string.format("LOAD %.1f kg  -  speed %d%%", bag.weight or 0, math.floor((bag.speed or 1) * 100 + 0.5))
	cLoad.TextColor3 = (bag.speed or 1) < 0.85 and BRIGHT or DIM
end

local function setHovered(i)
	if hovered == i then return end
	if hovered and cards[hovered] then
		tween(cards[hovered].scale, 0.12, {Scale = 1})
		cards[hovered].stroke.Color = LINE
		cards[hovered].stroke.Thickness = 1
	end
	hovered = i
	if i and cards[i] then
		tween(cards[i].scale, 0.12, {Scale = 1.14}, Enum.EasingStyle.Back)
		cards[i].stroke.Color = INK
		cards[i].stroke.Thickness = 1.5
		if bag.items[i] then sfx(SoundConfig.Random("TapeClick"), 0.18, 1.3) end
	end
	describe(i and bag.items[i] or nil)
end

-- ===== open / close =====
local isOpen = false
local openedAt = 0
local heldQ = false
local function fit()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local size = camera.ViewportSize
	wheelScale.Scale = math.clamp(math.min(size.X, size.Y) / (RADIUS * 2 + CARD + 60), 0.45, 1)
end

local function canOpen()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0 and not player:GetAttribute("InMenu") and not c:GetAttribute("Infected")
		and not (player:GetAttribute("UIOpen") and not isOpen)
end

local function setOpen(value)
	if value == isOpen then return end
	if value and not canOpen() then return end
	isOpen = value
	player:SetAttribute("UIOpen", value)
	player:SetAttribute("GS_WheelOpen", value)
	if value then
		openedAt = os.clock()
		fit()
		refreshCards()
		picked = nil
		setHovered(nil)
		gui.Enabled = true
		shade.BackgroundTransparency = 1
		tween(shade, 0.2, {BackgroundTransparency = 0.45})
		wheelScale.Scale *= 0.9
		local target = wheelScale.Scale / 0.9
		tween(wheelScale, 0.22, {Scale = target}, Enum.EasingStyle.Back)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		sfx(SoundConfig.Random("TapeClick"), 0.35)
		itemSound("Cloth", 0.25, 1.3)
	else
		gui.Enabled = false
		setHovered(nil)
		picked = nil
	end
end

-- ===== actions =====
local toastLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -140), Size = UDim2.fromOffset(500, 24),
	BackgroundTransparency = 1, Font = FONT, TextSize = 18, TextColor3 = INK, TextStrokeTransparency = 0.4, TextTransparency = 1,
	Parent = create("ScreenGui", {Name = "GS_ItemToast", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 44, Parent = playerGui}),
})
local toastToken = 0
local function toast(text, color)
	toastToken += 1
	local my = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or INK
	toastLabel.TextTransparency = 0
	task.delay(1.8, function()
		if my == toastToken then tween(toastLabel, 0.5, {TextTransparency = 1}) end
	end)
end

local function primary(e)
	local item = e and ItemData.Get(e.id)
	if not item then
		if bag.held then
			ask("holster")
			sfx("MenuClick", 0.35)
		end
		return
	end
	if item.kind == "armor" then
		local ok, why = ask(e.worn and "unwear" or "wear", e.uid)
		if ok then
			itemSound(item.set == "scg" and "Plate" or "Cloth", 0.5)
			toast((e.worn and "took off " or "put on ") .. item.name, AMBER)
		elseif why then toast(tostring(why), BRIGHT) end
	elseif item.kind == "ammo" then
		toast("load it: take the gun and press R", DIM)
	elseif bag.held == e.uid then
		ask("holster")
	else
		local ok, why = ask("equip", e.uid)
		if not ok and why then toast(tostring(why), BRIGHT) end
	end
end

local function drop(e)
	if not e then return end
	local item = ItemData.Get(e.id)
	local ok = ask("drop", e.uid)
	if ok then
		toast("dropped " .. (item and item.name or "it") .. " - anyone can pick it up", DIM)
		sfx(SoundConfig.Random("TapeClick"), 0.3, 0.8)
	end
end

primaryBtn.Activated:Connect(function()
	local e = picked and bag.items[picked]
	primary(e)
	setOpen(false)
end)
dropBtn.Activated:Connect(function()
	local e = picked and bag.items[picked]
	drop(e)
	setOpen(false)
end)

-- which card the pointer is over (or the centre)
local function pointerIndex(pos)
	local abs = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
	local offset = pos - abs
	local r = offset.Magnitude / math.max(wheelScale.Scale, 0.1)
	if r < 125 then return 0 end
	if r > RADIUS + CARD then return nil end
	local angle = math.deg(math.atan2(offset.Y, offset.X)) + 90
	angle = (angle + 360 / SLOTS / 2) % 360
	return math.floor(angle / (360 / SLOTS)) + 1
end

UserInputService.InputBegan:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Q and not processed then
		if isOpen then
			setOpen(false)
		else
			heldQ = true
			setOpen(true)
		end
		return
	end
	if not isOpen then
		if processed then return end
		if input.KeyCode == Enum.KeyCode.H and bag.held then
			ask("holster")
		elseif input.KeyCode == Enum.KeyCode.G and bag.held then
			drop(heldEntry())
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		setOpen(false)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not TOUCH then
		local i = pointerIndex(UserInputService:GetMouseLocation())
		if i == 0 then
			primary(nil)
			setOpen(false)
		elseif i and bag.items[i] then
			primary(bag.items[i])
			setOpen(false)
		elseif not i then
			setOpen(false)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not TOUCH then
		local i = pointerIndex(UserInputService:GetMouseLocation())
		if i and i > 0 and bag.items[i] then
			drop(bag.items[i])
			setOpen(false)
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		local i = pointerIndex(Vector2.new(input.Position.X, input.Position.Y))
		if i == 0 then
			if not picked then
				primary(nil)
				setOpen(false)
			end
		elseif i and bag.items[i] then
			picked = i
			setHovered(nil)
			setHovered(i)
		elseif not i then
			setOpen(false)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.Q or not heldQ then return end
	heldQ = false
	-- a hold: letting go picks what the pointer is on. A quick tap leaves the wheel open for clicking.
	if isOpen and os.clock() - openedAt > 0.3 then
		local i = pointerIndex(UserInputService:GetMouseLocation())
		if i == 0 then
			primary(nil)
		elseif i and bag.items[i] then
			primary(bag.items[i])
		end
		setOpen(false)
	end
end)

if clientAction then
	clientAction.Event:Connect(function(action)
		if action == "inventory" then
			setOpen(not isOpen)
		elseif action == "away" and bag.held then
			ask("holster")
		end
	end)
end

RunService.RenderStepped:Connect(function()
	if not isOpen then return end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	if not canOpen() and isOpen then
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 then setOpen(false) return end
	end
	if not TOUCH then
		local i = pointerIndex(UserInputService:GetMouseLocation())
		setHovered((i and i > 0 and bag.items[i]) and i or nil)
	end
	-- the hovered item turns slowly
	local card = hovered and cards[hovered]
	if card then
		local model = card.view:FindFirstChildOfClass("Model")
		if model then model:PivotTo(CFrame.Angles(0, os.clock() * 0.8, 0) * CFrame.new(model:GetPivot().Position)) end
	end
end)

-- ===== the heal mini-game =====
local mg = create("ScreenGui", {
	Name = "GS_HealGame", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 46, Enabled = false, Parent = playerGui,
})
local mgCard = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(250, 270),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.08, Parent = mg,
}, {
	create("UIStroke", {Color = BLOOD, Thickness = 1.5}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 6, 6), Color3.fromRGB(0, 0, 0))}),
})
local mgScale = create("UIScale", {Parent = mgCard})
local mgTitle = label(mgCard, {Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 22), TextSize = 18})
local mgSub = label(mgCard, {Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = DIM})
local DIAL = 150
local dial = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(DIAL, DIAL),
	BackgroundTransparency = 1, Parent = mgCard,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)}), create("UIStroke", {Color = LINE, Thickness = 2})})
-- the green arc: a row of small dots around the dial
local zoneDots = {}
for i = 1, 14 do
	zoneDots[i] = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = GREEN, BorderSizePixel = 0, Parent = dial,
	}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
end
local needle = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, DIAL / 2 - 4),
	BackgroundColor3 = BRIGHT, BorderSizePixel = 0, Parent = dial,
})
create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
	BackgroundColor3 = INK, BorderSizePixel = 0, Parent = dial,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
local mgDots = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 214), Size = UDim2.fromOffset(200, 12), BackgroundTransparency = 1,
	Parent = mgCard,
}, {create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8)})})
local mgHint = label(mgCard, {Position = UDim2.fromOffset(10, 236), Size = UDim2.new(1, -20, 0, 20), TextSize = 12, TextColor3 = BRIGHT,
	Text = TOUCH and "TAP when the needle is in the green" or "[LMB] / [SPACE] when the needle is in the green"})

local GAMES = {
	wrap = {title = "WRAP THE WOUND", sub = "keep the bandage tight", hits = 3, zone = 60, speed = 260},
	set = {title = "SET THE BONE", sub = "straighten it, then tie it", hits = 2, zone = 44, speed = 200},
	stitch = {title = "CLEAN AND STITCH", sub = "steady hands", hits = 4, zone = 50, speed = 300},
	none = {title = "", sub = "", hits = 0},
}

local game_ = nil
local function hitDots(n, needed)
	for _, c in ipairs(mgDots:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for i = 1, needed do
		create("Frame", {
			Size = UDim2.fromOffset(12, 12), BackgroundColor3 = i <= n and GREEN or Color3.fromRGB(40, 36, 34), BorderSizePixel = 0,
			Parent = mgDots,
		}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
	end
end

local function placeZone()
	local g = game_
	g.zoneAt = math.random(0, 359)
	for i, dot in ipairs(zoneDots) do
		local a = math.rad(g.zoneAt - g.def.zone / 2 + (i - 1) * g.def.zone / (#zoneDots - 1) - 90)
		dot.Position = UDim2.new(0.5, math.cos(a) * (DIAL / 2 - 10), 0.5, math.sin(a) * (DIAL / 2 - 10))
	end
end

local function endGame(cancelled)
	local g = game_
	if not g then return end
	game_ = nil
	mg.Enabled = false
	player:SetAttribute("GS_Minigame", nil)
	if cancelled then
		ask("usecancel")
		return
	end
	local quality = g.def.hits > 0 and math.clamp(g.hits / g.def.hits - g.misses * 0.12, 0, 1) or 1
	-- a real hand can't do it faster than the item takes
	local waitMore = g.useTime * 0.7 - (os.clock() - g.started)
	if waitMore > 0 then task.wait(waitMore) end
	local ok = ask("usefinish", g.uid, quality)
	local item = ItemData.Get(g.id)
	if ok then
		toast((item and item.name or "done") .. (quality >= 0.8 and " - done right" or (quality >= 0.4 and " - it'll hold" or " - sloppy")),
			quality >= 0.4 and GREEN or AMBER)
	end
end

local function startGame(e)
	local item = ItemData.Get(e.id)
	local ok, useTime = ask("usebegin", e.uid)
	if not ok then return end
	local def = GAMES[item.game or "none"] or GAMES.none
	game_ = {uid = e.uid, id = e.id, def = def, hits = 0, misses = 0, angle = 0, started = os.clock(), useTime = useTime or item.useTime}
	player:SetAttribute("GS_Minigame", true)
	if item.sound == "spray" then itemSound("Spray", 0.4) elseif item.sound == "pills" then itemSound("Rattle", 0.4, 1.6)
	else itemSound("Cloth", 0.45) end
	if def.hits == 0 then
		-- pills and the shot: just a moment
		mg.Enabled = true
		mgTitle.Text = item.name
		mgSub.Text = "..."
		dial.Visible = false
		mgDots.Visible = false
		mgHint.Text = ""
		task.delay(game_.useTime, function() endGame(false) end)
		return
	end
	dial.Visible = true
	mgDots.Visible = true
	mgHint.Text = TOUCH and "TAP when the needle is in the green" or "[LMB] / [SPACE] when the needle is in the green"
	mgTitle.Text = def.title
	mgSub.Text = def.sub
	hitDots(0, def.hits)
	placeZone()
	mg.Enabled = true
	mgScale.Scale = 0.85
	tween(mgScale, 0.2, {Scale = 1}, Enum.EasingStyle.Back)
end

local function press()
	local g = game_
	if not g or g.def.hits == 0 then return end
	local diff = math.abs(((g.angle - g.zoneAt) + 180) % 360 - 180)
	if diff <= g.def.zone / 2 then
		g.hits += 1
		itemSound(g.id == "medkit" and "Spray" or "Cloth", 0.35, 1 + g.hits * 0.08)
		hitDots(g.hits, g.def.hits)
		if g.hits >= g.def.hits then
			endGame(false)
			return
		end
		placeZone()
	else
		g.misses += 1
		sfx("FearHit", 0.15, 1.8)
		mgCard.Position = UDim2.new(0.5, 6, 0.62, 0)
		tween(mgCard, 0.15, {Position = UDim2.new(0.5, 0, 0.62, 0)})
	end
end

RunService.RenderStepped:Connect(function(dt)
	local g = game_
	if not g or g.def.hits == 0 then return end
	g.angle = (g.angle + g.def.speed * dt) % 360
	needle.Rotation = g.angle
	-- too long: the game ends by itself (worse result)
	if os.clock() - g.started > g.useTime * 3 then endGame(false) end
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 or c:GetAttribute("Ragdolled") then endGame(true) end
end)

-- ===== using what's in the hand (LMB / USE button) =====
local function useHeld()
	if isOpen or game_ then
		if game_ then press() end
		return
	end
	local e = heldEntry()
	local item = e and ItemData.Get(e.id)
	if not item then return end
	if item.kind == "heal" then
		startGame(e)
	elseif item.kind == "light" then
		if ask("usebegin", e.uid) then itemSound("Sizzle", 0.5, 1.2) toast("the flare hisses into light", AMBER) end
	elseif item.kind == "trap" then
		if ask("usebegin", e.uid) then itemSound("TrapSet", 0.6) toast("trap set - keep your feet out of it", AMBER) end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space and game_ then
		if input.KeyCode == Enum.KeyCode.Space and not game_ then return end
		local e = heldEntry()
		local item = e and ItemData.Get(e.id)
		if game_ or (item and (item.kind == "heal" or item.kind == "light" or item.kind == "trap")) then useHeld() end
	elseif input.UserInputType == Enum.UserInputType.Touch and game_ then
		press()
	elseif input.KeyCode == Enum.KeyCode.Escape and game_ then
		endGame(true)
	end
end)
if clientAction then
	clientAction.Event:Connect(function(action)
		if action == "use" then
			local e = heldEntry()
			local item = e and ItemData.Get(e.id)
			if game_ or (item and (item.kind == "heal" or item.kind == "light" or item.kind == "trap")) then useHeld() end
		end
	end)
end

-- ===== the server's word =====
syncRemote.OnClientEvent:Connect(function(snap)
	if typeof(snap) ~= "table" then return end
	bag = snap
	local e = heldEntry()
	local item = e and ItemData.Get(e.id)
	player:SetAttribute("GS_HeldKind", item and item.kind or nil)
	player:SetAttribute("GS_HeldId", item and item.id or nil)
	if isOpen then
		refreshCards()
		describe(hovered and bag.items[hovered] or (picked and bag.items[picked]) or nil)
	end
	if game_ and not entryByUid(game_.uid) then
		game_ = nil
		mg.Enabled = false
	end
end)
if itemFx then
	itemFx.OnClientEvent:Connect(function(kind, a)
		if kind == "toast" then toast(tostring(a), BRIGHT) end
	end)
end
task.spawn(function() ask("get") end)

player.CharacterAdded:Connect(function()
	setOpen(false)
	if game_ then
		game_ = nil
		mg.Enabled = false
	end
end)
]=]},
	{name = "ItemData", class = "ModuleScript", where = "Modules", source = [=[
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
]=]},
	{name = "MoneyHUD", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- Your money on screen (top right), drawn like the vitals panel. When it changes the number rolls to the new
-- value, a "+100" / "-40" floats up out of it, the $ jumps and the frame flashes (gold for money in, red for
-- money out). The HUD editor (Controls) can move and resize it like the other panels ("CASH").
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSettings = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSettings"))

local player = Players.LocalPlayer
local FONT = Enum.Font.SpecialElite
local GOLD = Color3.fromRGB(232, 164, 52)
local INK = Color3.fromRGB(236, 230, 222)
local RED = Color3.fromRGB(225, 40, 40)
local DIM = Color3.fromRGB(120, 34, 30)
local BORDER = Color3.fromRGB(70, 6, 6)
local W, H = 176, 50

local function create(className, props, children)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	return obj
end
local function tween(obj, t, goal, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

-- 1234567 -> "1,234,567"
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local gui = create("ScreenGui", {
	Name = "GS_MoneyHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 41,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui"),
})
local panel = create("Frame", {
	Name = "Money", Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(4, 3, 3), BackgroundTransparency = 0.08,
	BorderSizePixel = 0, Visible = false, Parent = gui,
}, {
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 4, 4), Color3.fromRGB(0, 0, 0))}),
})
panel:SetAttribute("GS_Movable", "CASH")
local stroke = create("UIStroke", {Color = BORDER, Thickness = 1, Transparency = 0.25, Parent = panel})
create("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Color3.fromRGB(150, 12, 16), BorderSizePixel = 0, Parent = panel})

-- a plain dollar sign in the game's typewriter type (it still jumps when the money changes)
local coin = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(28, H / 2 + 1), Size = UDim2.fromOffset(30, 40),
	BackgroundTransparency = 1, Font = FONT, Text = "$", TextSize = 38, TextColor3 = GOLD,
	TextStrokeColor3 = Color3.fromRGB(60, 30, 4), TextStrokeTransparency = 0.5, Parent = panel,
})
local coinScale = create("UIScale", {Parent = coin})

create("TextLabel", {
	Position = UDim2.fromOffset(52, 5), Size = UDim2.new(1, -60, 0, 14), BackgroundTransparency = 1, Font = FONT,
	Text = "CASH", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM, Parent = panel,
})
local amount = create("TextLabel", {
	Position = UDim2.fromOffset(52, 18), Size = UDim2.new(1, -60, 0, 28), BackgroundTransparency = 1, Font = FONT,
	Text = "0", TextSize = 25, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK,
	TextTruncate = Enum.TextTruncate.AtEnd, Parent = panel,
})

-- where it sits: top right under the top bar, unless the HUD editor moved it
local function defaultPosition()
	local inset = GuiService:GetGuiInset().Y
	return UDim2.new(1, -W - 14, 0, inset + 10)
end
local function place()
	local pos = panel:GetAttribute("GS_LayoutPos")
	panel.Position = typeof(pos) == "UDim2" and pos or defaultPosition()
end
panel:GetAttributeChangedSignal("GS_LayoutPos"):Connect(place)
place()

-- ===== the number and its animations =====
local shown = player:GetAttribute("Cash") or 0
local value = create("NumberValue", {Value = shown})
amount.Text = commas(shown)
value.Changed:Connect(function(v) amount.Text = commas(v) end)

local coinSound = create("Sound", {
	SoundId = "rbxassetid://9113849583", Volume = 0.35, PlaybackSpeed = 1.15, Parent = gui,
})
pcall(function() coinSound.SoundGroup = GameSettings.GetGroup("SFX") end)

local function popup(delta)
	local gain = delta > 0
	local label = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 14), Size = UDim2.fromOffset(120, 24),
		BackgroundTransparency = 1, Font = FONT, Text = (gain and "+" or "-") .. "$" .. commas(math.abs(delta)), TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = gain and GOLD or RED, TextStrokeTransparency = 0.4,
		ZIndex = 5, Parent = panel,
	})
	tween(label, 1.1, {Position = UDim2.new(1, -8, 1, gain and -H - 26 or 10)})
	task.delay(0.45, function() tween(label, 0.65, {TextTransparency = 1, TextStrokeTransparency = 1}) end)
	task.delay(1.2, function() label:Destroy() end)
end

local rollToken = 0
local function changed()
	local new = player:GetAttribute("Cash") or 0
	local delta = new - shown
	shown = new
	if delta == 0 then return end
	rollToken += 1
	local gain = delta > 0
	tween(value, math.clamp(0.35 + math.log10(math.abs(delta) + 1) * 0.2, 0.35, 1.2), {Value = new})
	if panel.Visible then
		popup(delta)
		-- the frame flashes, the coin jumps
		stroke.Color = gain and GOLD or RED
		stroke.Transparency = 0
		amount.TextColor3 = gain and GOLD or RED
		task.delay(0.15, function()
			tween(stroke, 0.8, {Color = BORDER, Transparency = 0.25})
			tween(amount, 0.8, {TextColor3 = INK})
		end)
		coinScale.Scale = gain and 1.35 or 0.75
		tween(coinScale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
		coin.Rotation = gain and -20 or 12
		tween(coin, 0.5, {Rotation = 0}, Enum.EasingStyle.Back)
		coinSound.PlaybackSpeed = gain and 1.15 or 0.8
		coinSound:Play()
	end
end
player:GetAttributeChangedSignal("Cash"):Connect(changed)

-- only in the game itself (not in the menu), and it slides in the first time it appears
RunService.RenderStepped:Connect(function()
	local want = player:GetAttribute("InMenu") ~= true and player:GetAttribute("Cash") ~= nil
	if want and not panel.Visible then
		panel.Visible = true
		place()
		local target = panel.Position
		panel.Position = target + UDim2.fromOffset(0, -20)
		panel.BackgroundTransparency = 1
		tween(panel, 0.4, {Position = target, BackgroundTransparency = 0.08}, Enum.EasingStyle.Back)
	elseif not want and panel.Visible then
		panel.Visible = false
	end
end)
]=]},
	{name = "MonsterData", class = "ModuleScript", where = "Modules", source = [=[
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
]=]},
	{name = "MonsterHealth", class = "Script", where = "ServerScriptService", source = [=[
-- Creatures can finally be hurt and killed. Every creature in workspace.Monsters (with a MonsterId) gets a
-- health pool and, for the ones with arms and legs, a pool per limb:
--   hit a limb hard enough and it comes off (the head: that's the end of it); A-013's limbs grow back.
-- ServerStorage.GS_MonsterHealth:Invoke("damage", model, partName, amount, kind, attacker)
--   -> dealt, killed, severedPart, headshot
-- kinds: bullet, fire, melee, shock, trap, acid. D-130 shrugs off bullets and flares: only melee works.
-- Blood: black for everything except the spiders (green) and the spitter (acid yellow-green).
-- The clients draw the blood, the goo and the spider bursts (CombatFX).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RagdollController = require(Modules:WaitForChild("RagdollController"))

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local api = ensure(ServerStorage, "BindableFunction", "GS_MonsterHealth")
local fxRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_MonsterHit")
local gibFolder = ensure(workspace, "Folder", "GS_Gibs")

-- health per creature; limbs = hp of each limb that can come off. Bounty = cash for the kill.
local STATS = {
	["D-130"] = {hp = 200, blood = "black", immune = {bullet = true, fire = true}, bounty = 60,
		limbs = {Head = 90, ["Left Arm"] = 70, ["Right Arm"] = 70, ["Left Leg"] = 80, ["Right Leg"] = 80}},
	["B-414"] = {hp = 300, blood = "black", bounty = 80,
		limbs = {Head = 100, ["Left Arm"] = 100, ["Right Arm"] = 100, ["Left Leg"] = 100, ["Right Leg"] = 100}},
	["A-013"] = {hp = 500, blood = "black", bounty = 150, regrow = 5,
		limbs = {Head = 250, ["Left Arm"] = 120, ["Right Arm"] = 120, ["Left Leg"] = 140, ["Right Leg"] = 140}},
	["C-207"] = {hp = 400, blood = "black", bounty = 100,
		limbs = {Head = 200, ["Left Arm"] = 250, ["Right Arm"] = 250, ["Left Leg"] = 250, ["Right Leg"] = 250}},
	["E-116"] = {hp = 75, blood = "green", bounty = 15, spider = true},
	["A-116"] = {hp = 450, blood = "green", bounty = 120, spider = true, mother = true},
	["C-310"] = {hp = 180, blood = "acid", bounty = 50,
		limbs = {Head = 80, ["Left Arm"] = 60, ["Right Arm"] = 60, ["Left Leg"] = 70, ["Right Leg"] = 70}},
}
local DEFAULT = {hp = 250, blood = "black", bounty = 40}

local MOTORS = {["Left Arm"] = "Left Shoulder", ["Right Arm"] = "Right Shoulder", ["Left Leg"] = "Left Hip",
	["Right Leg"] = "Right Hip", Head = "Neck"}

local pools = {}

local function serverNow() return workspace:GetServerTimeNow() end

local function poolOf(model)
	local pool = pools[model]
	if pool then return pool end
	local id = model:GetAttribute("MonsterId")
	if not id then return nil end
	local stats = STATS[id] or DEFAULT
	pool = {stats = stats, hp = stats.hp, limbs = {}, templates = {}, damageBy = {}}
	for name, hp in pairs(stats.limbs or {}) do
		pool.limbs[name] = hp
		-- A-013 grows its limbs back: remember what they looked like
		if stats.regrow and name ~= "Head" then
			local part = model:FindFirstChild(name)
			local torso = model:FindFirstChild("Torso")
			local motor = torso and torso:FindFirstChild(MOTORS[name])
			if part and motor and motor:IsA("Motor6D") then
				local ok, copy = pcall(function()
					part.Archivable = true
					for _, d in ipairs(part:GetDescendants()) do d.Archivable = true end
					return part:Clone()
				end)
				if ok and copy then pool.templates[name] = {part = copy, c0 = motor.C0, c1 = motor.C1} end
			end
		end
	end
	pools[model] = pool
	model:SetAttribute("GS_HP", pool.hp)
	model:SetAttribute("GS_MaxHP", stats.hp)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then pools[model] = nil end
	end)
	return pool
end

local function control(...)
	local c = ServerStorage:FindFirstChild("GS_MonsterControl")
	if c then pcall(c.Invoke, c, ...) end
end

-- ===== losing a limb =====
local function sever(model, pool, name)
	local part = model:FindFirstChild(name)
	local torso = model:FindFirstChild("Torso")
	if not part or not torso then return end
	local motor = torso:FindFirstChild(MOTORS[name])
	if motor then motor:Destroy() end
	for _, w in ipairs(part:GetChildren()) do
		if w:IsA("JointInstance") or w:IsA("WeldConstraint") then w:Destroy() end
	end
	local holder = Instance.new("Model")
	holder.Name = "GS_Limb_" .. name
	-- everything welded onto the limb (veins, lumps, armor bits) comes off with it
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WeldConstraint") and (d.Part0 == part or d.Part1 == part) then
			local other = d.Part0 == part and d.Part1 or d.Part0
			if other and other ~= torso and other.Parent and other:IsDescendantOf(model) and other.Name ~= "HumanoidRootPart" then
				other.Parent = holder
			end
		end
	end
	part.Parent = holder
	part.CanCollide = true
	holder.Parent = gibFolder
	pcall(function() part:SetNetworkOwner(nil) end)
	part.AssemblyLinearVelocity = (part.Position - torso.Position).Unit * 18 + Vector3.new(0, 14, 0)
	part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
	Debris:AddItem(holder, 40)
	pool.limbs[name] = nil
	fxRemote:FireAllClients("sever", model, part.Position, pool.stats.blood, name)
	-- A-013: the stump bubbles and the limb grows back
	local template = pool.templates[name]
	if pool.stats.regrow and template then
		task.delay(pool.stats.regrow, function()
			if not model.Parent or model:GetAttribute("GS_Dead") or model:FindFirstChild(name) then return end
			local torsoNow = model:FindFirstChild("Torso")
			if not torsoNow then return end
			local newPart = template.part:Clone()
			newPart.CFrame = torsoNow.CFrame * template.c0 * template.c1:Inverse()
			newPart.Parent = model
			local newMotor = Instance.new("Motor6D")
			newMotor.Name = MOTORS[name]
			newMotor.Part0 = torsoNow
			newMotor.Part1 = newPart
			newMotor.C0 = template.c0
			newMotor.C1 = template.c1
			newMotor.Parent = torsoNow
			pool.limbs[name] = (pool.stats.limbs or {})[name] or 100
			model:SetAttribute("RigVersion", (model:GetAttribute("RigVersion") or 0) + 1)
			fxRemote:FireAllClients("regrow", model, newPart.Position, name)
		end)
	end
end

-- ===== dying =====
local function payBounty(model, pool)
	local best, bestDamage = nil, 0
	for player, dmg in pairs(pool.damageBy) do
		if player.Parent and dmg > bestDamage then best, bestDamage = player, dmg end
	end
	if not best then return end
	local economy = ServerStorage:FindFirstChild("GS_Economy")
	if economy then pcall(economy.Invoke, economy, "add", best, pool.stats.bounty or 0) end
end

local function kill(model, pool, attacker)
	if model:GetAttribute("GS_Dead") then return end
	model:SetAttribute("GS_Dead", true)
	model:SetAttribute("GS_HP", 0)
	control("Kill", model)
	payBounty(model, pool)
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then pcall(function() humanoid:Move(Vector3.zero) humanoid.WalkSpeed = 0 end) end
	if pool.stats.spider then
		-- the spider bursts: green goo everywhere, the legs are left lying about, the body flies apart
		local legs = {}
		if root then
			for _, a in ipairs(root:GetChildren()) do
				if a:IsA("Attachment") and a.Name:match("^Leg%d") then table.insert(legs, a.WorldPosition) end
			end
		end
		fxRemote:FireAllClients("spiderdeath", model, root and root.Position or model:GetPivot().Position, legs,
			model:GetAttribute("SpiderScale") or 1, pool.stats.mother == true)
		local center = root and root.Position or model:GetPivot().Position
		local pieces = Instance.new("Model")
		pieces.Name = "GS_SpiderRemains"
		pieces.Parent = gibFolder
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and p ~= root then
				for _, w in ipairs(p:GetChildren()) do
					if w:IsA("WeldConstraint") or w:IsA("JointInstance") then w:Destroy() end
				end
				p.Anchored = false
				p.CanCollide = p.Size.Magnitude > 0.6
				p.Massless = false
				p.Parent = pieces
				local dir = p.Position - center
				dir = dir.Magnitude > 0.05 and dir.Unit or Vector3.new(0, 1, 0)
				p.AssemblyLinearVelocity = dir * math.random(20, 42) + Vector3.new(0, math.random(12, 28), 0)
				p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 30
			end
		end
		Debris:AddItem(pieces, 25)
		model:Destroy()
		return
	end
	-- everything else falls down where it stood and lies there for a while
	fxRemote:FireAllClients("death", model, root and root.Position or model:GetPivot().Position, pool.stats.blood)
	local okRagdoll = pcall(function() RagdollController.Enable(model) end)
	if not okRagdoll then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") then d:Destroy() end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("AlignOrientation") then d.Enabled = false end
	end
	task.delay(30, function()
		if model.Parent then model:Destroy() end
	end)
end

-- ===== taking damage =====
local function damage(model, partName, amount, kind, attacker)
	if typeof(model) ~= "Instance" or not model.Parent or model:GetAttribute("GS_Dead") then return 0, false end
	local pool = poolOf(model)
	if not pool then return 0, false end
	amount = math.max(0, tonumber(amount) or 0)
	if pool.stats.immune and pool.stats.immune[kind] then
		local where = model:FindFirstChild(partName or "") or model:FindFirstChild("HumanoidRootPart")
		fxRemote:FireAllClients("immune", model, where and where.Position or model:GetPivot().Position)
		return 0, false
	end
	local attackerPlayer = typeof(attacker) == "Instance" and (attacker:IsA("Player") and attacker or Players:GetPlayerFromCharacter(attacker))
	if attackerPlayer then pool.damageBy[attackerPlayer] = (pool.damageBy[attackerPlayer] or 0) + amount end
	local part = model:FindFirstChild(partName or "")
	if not part or not part:IsA("BasePart") then part = model:FindFirstChild("HumanoidRootPart") end
	local name = part and part.Name or "Torso"
	if name == "HumanoidRootPart" then name = "Torso" end
	local headshot = name == "Head"
	pool.hp -= amount
	model:SetAttribute("GS_HP", math.max(0, math.floor(pool.hp)))
	model:SetAttribute("GS_HitAt", serverNow())
	fxRemote:FireAllClients("hit", model, part and part.Position or model:GetPivot().Position, pool.stats.blood, amount, name)
	local severed = nil
	if pool.limbs[name] then
		pool.limbs[name] -= amount
		if pool.limbs[name] <= 0 then
			if name == "Head" then
				sever(model, pool, name)
				kill(model, pool, attacker)
				return amount, true, name, true
			end
			sever(model, pool, name)
			severed = name
		end
	end
	if pool.hp <= 0 then
		kill(model, pool, attacker)
		return amount, true, severed, headshot
	end
	-- let the creature know who is hurting it
	if attackerPlayer and attackerPlayer.Character then control("Struck", model, attackerPlayer.Character) end
	return amount, false, severed, headshot
end

api.OnInvoke = function(action, ...)
	if action == "damage" then
		return damage(...)
	elseif action == "hp" then
		local model = ...
		local pool = poolOf(model)
		return pool and pool.hp or 0, pool and pool.stats.hp or 0
	end
	return false
end

-- give every creature its pool as soon as it appears (so the clients can show the bar right away)
task.spawn(function()
	local folder = workspace:WaitForChild("Monsters", 120)
	if not folder then return end
	local function onModel(model)
		if not model:IsA("Model") then return end
		task.wait(0.5)
		if model.Parent and model:GetAttribute("MonsterId") then poolOf(model) end
	end
	for _, m in ipairs(folder:GetChildren()) do task.spawn(onModel, m) end
	folder.ChildAdded:Connect(onModel)
end)
]=]},
	{name = "Monsters", class = "Script", where = "ServerScriptService", source = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))
local Skeletons = require(Modules:WaitForChild("Skeletons"))
local boneHolders = setmetatable({}, {__mode = "k"}) -- corpse -> the skeleton its eaten pieces leave behind
local MonsterData = require(Modules:WaitForChild("MonsterData"))

local HUMAN_SPEED = 16
local SIGHT_RANGE = 160
local WATCH_MIN, WATCH_MAX = 42, 72
local WATCH_TIME = {7, 15}
local SNEAK_SPEED = 5.5
local WALK_SPEED = 10
local ATTACK_RANGE = 4.6
local SWING_COOLDOWN = 1.15
local RETREAT_TIME = {7, 12}
local LOST_TIMEOUT = 7
local BLOOD_SPLAT_LIFETIME = 60
local TRAIL_EXTRA_LIFETIME = 300
local TRAIL_LIFETIME = BLOOD_SPLAT_LIFETIME + TRAIL_EXTRA_LIFETIME
local TRAIL_STEP = 1.6
local TRAIL_MAX = 4000
local CLOSE_AGGRO = 7
-- Upload the PNGs from roblox/textures (Asset Manager → Bulk Import or Create → Decal) and paste their ids here.
-- Leave empty and the monsters still get 3D veins and coloured flesh, just without the painted texture.
local TEXTURES = MonsterData.Textures or {
	Meat = "93176580262165",          -- flesh_meat.png
	Veins = "110379790827308",         -- veins_overlay.png
	ListenerSkin = "127788127447980",  -- listener_skin.png
}
local SKIN_BARE = Color3.fromRGB(226, 224, 218)
local PATH_SETTINGS = {
	AgentRadius = 1.8, AgentHeight = 5.2, AgentCanJump = true, AgentCanClimb = true,
	WaypointSpacing = 3, Costs = {Water = 25},
}

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local fxRemote = ensure(ReplicatedStorage, "RemoteEvent", "MonsterFX")
local strikeRemote = ensure(ReplicatedStorage, "RemoteEvent", "PlayerStrike")
local control = ensure(ServerStorage, "BindableFunction", "GS_MonsterControl")
local folder = ensure(workspace, "Folder", "Monsters")

local rng = Random.new()
local function randRange(range) return rng:NextNumber(range[1], range[2]) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function aliveCharacter(character)
	if not character or not character.Parent then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

local function isInfected(character)
	return character ~= nil and character:GetAttribute("Infected") == true
end

-- everything the monsters hunt; infected players belong to the flesh and are left alone
local function livingTargets()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if aliveCharacter(plr.Character) and not isInfected(plr.Character) then table.insert(list, plr.Character) end
	end
	local npcFolder = workspace:FindFirstChild("NPCs")
	if npcFolder then
		for _, model in ipairs(npcFolder:GetChildren()) do
			if model:IsA("Model") and aliveCharacter(model) then table.insert(list, model) end
		end
	end
	return list
end

local trail = {}
local lastTrailPos = {}
local scent = {}
local lastScentPos = {}
local SCENT_LIFETIME = 90
local SENSE_RADIUS = 170
local senseRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_InfectedSense")
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

local function refreshGroundFilter()
	local ignore = {folder}
	for _, c in ipairs(livingTargets()) do table.insert(ignore, c) end
	local severed = workspace:FindFirstChild("SeveredLimbs")
	if severed then table.insert(ignore, severed) end
	groundParams.FilterDescendantsInstances = ignore
end

task.spawn(function()
	while true do
		task.wait(0.35)
		local now = os.clock()

		local cut = 0
		for i = 1, #trail do
			if now - trail[i].t > TRAIL_LIFETIME then cut = i else break end
		end
		if cut > 0 then
			local n = #trail
			table.move(trail, cut + 1, n, 1)
			for i = n - cut + 1, n do trail[i] = nil end
		end
		refreshGroundFilter()
		for _, character in ipairs(livingTargets()) do
			local bleeding = character:GetAttribute("Bleeding") or 0
			local root = character:FindFirstChild("HumanoidRootPart")
			if bleeding > 0.02 and root then
				local last = lastTrailPos[character]
				if not last or (root.Position - last).Magnitude >= TRAIL_STEP then
					lastTrailPos[character] = root.Position
					local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), groundParams)
					local pos = hit and hit.Position or (root.Position - Vector3.new(0, 3, 0))
					table.insert(trail, {pos = pos, t = now})
					if #trail > TRAIL_MAX then table.remove(trail, 1) end
				end
			end
		end
		for character in pairs(lastTrailPos) do
			if not character.Parent then lastTrailPos[character] = nil end
		end
		-- footprints every survivor leaves (only infected eyes ever see them)
		while scent[1] and now - scent[1].t > SCENT_LIFETIME do table.remove(scent, 1) end
		for _, character in ipairs(livingTargets()) do
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local last = lastScentPos[character]
				if not last or (root.Position - last).Magnitude >= 2.5 then
					lastScentPos[character] = root.Position
					local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), groundParams)
					if hit then
						table.insert(scent, {pos = hit.Position, t = now})
						if #scent > 3000 then table.remove(scent, 1) end
					end
				end
			end
		end
		for character in pairs(lastScentPos) do
			if not character.Parent then lastScentPos[character] = nil end
		end
	end
end)

-- stage 2+ infected: every second, send them the tracks and blood around them
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, plr in ipairs(Players:GetPlayers()) do
			local character = plr.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and character:GetAttribute("Infected") and (character:GetAttribute("InfectStage") or 1) >= 3 then
				local blood, prints = {}, {}
				for i = #trail, 1, -1 do
					local p = trail[i]
					if now - p.t > 240 or #blood >= 250 then break end
					if (p.pos - root.Position).Magnitude < SENSE_RADIUS then table.insert(blood, {p.pos, now - p.t}) end
				end
				for i = #scent, 1, -1 do
					local p = scent[i]
					if #prints >= 300 then break end
					if (p.pos - root.Position).Magnitude < SENSE_RADIUS then table.insert(prints, {p.pos, now - p.t}) end
				end
				senseRemote:FireClient(plr, blood, prints)
			end
		end
	end
end)

local monsters = {}

local function getTemplate()
	return ReplicatedStorage:FindFirstChild("GS_ShadowTemplate") or ReplicatedStorage:WaitForChild("GS_ShadowTemplate", 15)
end

local function describe(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local ok, desc = pcall(function() return humanoid:GetAppliedDescription() end)
	if not ok or not desc then return nil end
	local plr = Players:GetPlayerFromCharacter(character)
	return {
		desc = desc,
		name = plr and plr.DisplayName or (character:GetAttribute("DisplayName") or character.Name),
		user = plr and ("@" .. plr.Name) or "npc",
		pitch = character:GetAttribute("VoicePitch") or rng:NextNumber(),
	}
end

-- ===== Skinwalker body =====
-- Its own form: pale grey, no clothes, no hair, and a face that is wrong.
local BODY_COLOR_KEYS = {"HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3"}

local function bareDescription()
	local desc = Instance.new("HumanoidDescription")
	for _, key in ipairs({"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"}) do
		desc[key] = SKIN_BARE
	end
	return desc
end

local function facePart(folder, head, radius, x, y, size, color, inset, roll, neon)
	local angle = math.asin(math.clamp(x / radius, -0.95, 0.95))
	local normal = Vector3.new(math.sin(angle), 0, -math.cos(angle))
	local point = Vector3.new(radius * math.sin(angle), y, -radius * math.cos(angle))
	local localCF = CFrame.lookAt(point, point + normal) * CFrame.new(0, 0, inset) * CFrame.Angles(0, 0, roll or 0)
	local part = Instance.new("Part")
	part.Name = "GS_FacePart"
	part.Size = size
	part.Color = color
	part.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow, part.Massless = false, false, false, false, true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.CFrame = head.CFrame * localCF
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local function buildCreepyFace(head)
	local old = head:FindFirstChild("GS_CreepyFace")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "GS_CreepyFace"
	folder.Parent = head
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	local radius = mesh and head.Size.Z * mesh.Scale.Z * 0.48 or head.Size.Z * 0.5
	local black = Color3.fromRGB(6, 4, 4)
	local bruise = Color3.fromRGB(48, 6, 6)
	local bone = Color3.fromRGB(222, 212, 184)
	local pupil = Color3.fromRGB(255, 236, 214)

	-- mismatched hollow eye sockets with pinprick pupils looking in different directions
	facePart(folder, head, radius, -0.2, 0.13, Vector3.new(0.24, 0.3, 0.22), black, 0.06, math.rad(-8))
	facePart(folder, head, radius, 0.22, 0.09, Vector3.new(0.3, 0.38, 0.22), black, 0.06, math.rad(10))
	facePart(folder, head, radius, -0.18, 0.11, Vector3.new(0.055, 0.055, 0.055), pupil, -0.05, 0, true)
	facePart(folder, head, radius, 0.19, 0.14, Vector3.new(0.045, 0.045, 0.045), pupil, -0.05, 0, true)
	-- dark streaks running down from the eyes
	facePart(folder, head, radius, -0.21, -0.07, Vector3.new(0.05, 0.3, 0.08), bruise, 0.02)
	facePart(folder, head, radius, 0.23, -0.1, Vector3.new(0.06, 0.34, 0.08), bruise, 0.02)

	-- a grin stretched far past where a mouth should end
	local function mouthY(x) return -0.24 + 0.55 * x * x end
	for i = -3, 3 do
		local x = i * 0.12
		facePart(folder, head, radius, x, mouthY(x), Vector3.new(0.2, 0.12, 0.16), black, 0.05)
	end
	for _, side in ipairs({-1, 1}) do
		facePart(folder, head, radius, side * 0.44, -0.1, Vector3.new(0.16, 0.05, 0.12), black, 0.04, side * math.rad(35))
	end
	for i = -4, 4 do
		local x = i * 0.065
		local y = mouthY(x)
		facePart(folder, head, radius, x, y + 0.035, Vector3.new(0.045, rng:NextNumber(0.04, 0.07), 0.04), bone, -0.02)
		facePart(folder, head, radius, x + 0.03, y - 0.035, Vector3.new(0.04, rng:NextNumber(0.035, 0.06), 0.04), bone, -0.02)
	end
end

local function scrubHead(head)
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("Decal") or d:IsA("FaceControls") or d:IsA("SurfaceAppearance") or d.Name == "GS_RedEye" then
			d:Destroy()
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
	end
	if head:IsA("MeshPart") then pcall(function() head.TextureID = "" end) end
end

-- while it is in its own skin nothing may paint a face back onto the head
local faceGuards = {}
local function guardFace(model, head)
	local guard = faceGuards[model]
	if guard and guard.head == head then return end
	if guard then guard.conn:Disconnect() end
	local conn = head.ChildAdded:Connect(function(child)
		if model:GetAttribute("Revealed") ~= true then return end
		if child:IsA("Decal") or child:IsA("FaceControls") or child:IsA("SurfaceAppearance") then
			task.defer(function() if child.Parent then child:Destroy() end end)
		end
	end)
	faceGuards[model] = {head = head, conn = conn}
end

local function applyBareLook(model)
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Accessory") or d:IsA("CharacterMesh") then
			d:Destroy()
		elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Color = SKIN_BARE
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		for _, key in ipairs(BODY_COLOR_KEYS) do bodyColors[key] = SKIN_BARE end
	end
	local head = model:FindFirstChild("Head")
	if head then
		scrubHead(head)
		buildCreepyFace(head)
		guardFace(model, head)
	end
end

local function buildBareModel()
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(bareDescription(), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then return nil end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") then d:Destroy() end
	end
	return model
end

local FLESH_COLORS = {
	Color3.fromRGB(132, 30, 34), Color3.fromRGB(110, 22, 28), Color3.fromRGB(150, 52, 52),
	Color3.fromRGB(88, 14, 20), Color3.fromRGB(160, 78, 72),
}

local paintPart
local function weldBlob(parent, part, localCF, size, color, reflect, texture)
	local blob = Instance.new("Part")
	blob.Name = "GS_Blob"
	blob.Color = color
	blob.Material = Enum.Material.SmoothPlastic
	blob.Reflectance = reflect or 0.1
	blob.CanCollide, blob.CanQuery, blob.CanTouch, blob.CastShadow, blob.Massless = false, false, false, false, true
	if texture then
		-- textures only render on real part shapes, not on SpecialMesh spheres
		blob.Shape = Enum.PartType.Ball
		local d = math.max(size.X, size.Y, size.Z)
		blob.Size = Vector3.new(d, d, d)
		paintPart(blob, texture, math.max(1, d * 1.6))
	else
		blob.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = blob
	end
	blob.CFrame = part.CFrame * localCF
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = blob
	weld.Parent = blob
	blob.Parent = parent
	return blob
end

local function coloredModel(color)
	local desc = Instance.new("HumanoidDescription")
	for _, key in ipairs({"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"}) do
		desc[key] = color
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then return nil end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Decal") then d:Destroy() end
	end
	return model
end

local function assetId(id)
	if id == nil or id == "" then return nil end
	if tostring(id):match("^%d+$") then return "rbxassetid://" .. id end
	return id
end

-- tile a texture over every face of a body part
function paintPart(part, id, studs, transparency)
	local texture = assetId(id)
	if not texture then return end
	for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
		local t = Instance.new("Texture")
		t.Name = "GS_Tex"
		t.Texture = texture
		t.Face = face
		t.StudsPerTileU = studs
		t.StudsPerTileV = studs
		t.OffsetStudsU = rng:NextNumber(0, studs)
		t.OffsetStudsV = rng:NextNumber(0, studs)
		t.Transparency = transparency or 0
		t.Parent = part
	end
end

-- raised 3D veins crawling over the faces of a part
local FACES = {
	{n = Vector3.new(0, 0, -1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 1, 0)},
	{n = Vector3.new(0, 0, 1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 1, 0)},
	{n = Vector3.new(1, 0, 0), u = Vector3.new(0, 0, 1), v = Vector3.new(0, 1, 0)},
	{n = Vector3.new(-1, 0, 0), u = Vector3.new(0, 0, 1), v = Vector3.new(0, 1, 0)},
}
local function addVeins(holder, part, count, color, thickness)
	local half = part.Size / 2
	for _ = 1, count do
		local face = FACES[rng:NextInteger(1, #FACES)]
		local hu = math.abs(face.u:Dot(half)) - 0.08
		local hv = math.abs(face.v:Dot(half)) - 0.08
		local hn = math.abs(face.n:Dot(half)) + 0.015
		local a, b = rng:NextNumber(-hu, hu), rng:NextNumber(-hv, hv)
		local angle = rng:NextNumber(0, math.pi * 2)
		local width = thickness * rng:NextNumber(0.8, 1.25)
		for _ = 1, rng:NextInteger(6, 10) do
			local step = rng:NextNumber(0.22, 0.38)
			local na = math.clamp(a + math.cos(angle) * step, -hu, hu)
			local nb = math.clamp(b + math.sin(angle) * step, -hv, hv)
			local p0 = face.n * hn + face.u * a + face.v * b
			local p1 = face.n * hn + face.u * na + face.v * nb
			local length = (p1 - p0).Magnitude
			if length > 0.05 then
				local seg = Instance.new("Part")
				seg.Name = "GS_Vein"
				seg.Shape = Enum.PartType.Cylinder
				seg.Size = Vector3.new(length + width, width, width)
				seg.Color = color
				seg.Material = Enum.Material.SmoothPlastic
				seg.Reflectance = 0.08
				seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow, seg.Massless = false, false, false, false, true
				local mid = (p0 + p1) / 2
				seg.CFrame = part.CFrame * CFrame.lookAt(mid, p1) * CFrame.Angles(0, math.pi / 2, 0)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part
				weld.Part1 = seg
				weld.Parent = seg
				seg.Parent = holder
			end
			a, b = na, nb
			angle += rng:NextNumber(-0.7, 0.7)
			width = math.max(0.035, width * 0.9)
		end
	end
end

-- white pinprick eyes glowing out of black pits
local function addEye(holder, part, localCF, size)
	weldBlob(holder, part, localCF * CFrame.new(0, 0, 0.04), Vector3.new(size * 1.35, size * 1.1, size * 0.8), Color3.fromRGB(4, 2, 2), 0)
	local eye = weldBlob(holder, part, localCF * CFrame.new(0, 0, -size * 0.12), Vector3.new(size * 0.55, size * 0.55, size * 0.4),
		Color3.fromRGB(245, 245, 240), 0)
	eye.Material = Enum.Material.Neon
	return eye
end

-- A SpecialMesh head can't show tiled textures, so monster heads become real balls:
-- then the skin texture covers the whole head, not just the face.
local function roundHead(model, diameter)
	local head = model:FindFirstChild("Head")
	if not head then return end
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("SpecialMesh") or d:IsA("Decal") or d:IsA("FaceControls") then d:Destroy() end
	end
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(diameter, diameter, diameter)
end

-- A-013: a walking heap of raw meat. Veins everywhere, white eyes in black pits, tentacles (drawn by clients).
local function buildFleshModel()
	local model = coloredModel(FLESH_COLORS[1])
	if not model then return nil end
	roundHead(model, 1.35)
	local holder = Instance.new("Folder")
	holder.Name = "GS_Body"
	holder.Parent = model
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = FLESH_COLORS[rng:NextInteger(1, 3)]
			part.Material = Enum.Material.SmoothPlastic
			part.Reflectance = 0.14
			paintPart(part, TEXTURES.Meat, part.Name == "Head" and 1.2 or 2.5)
			paintPart(part, TEXTURES.Veins, part.Name == "Head" and 1.5 or 3, 0.1)
			if part.Name ~= "Head" then
				addVeins(holder, part, part.Name == "Torso" and 5 or 3, Color3.fromRGB(58, 6, 32), 0.1)
			end
			local count = part.Name == "Torso" and 8 or (part.Name == "Head" and 4 or 3)
			for _ = 1, count do
				local half = part.Size / 2
				if part.Name == "Head" then half = Vector3.new(0.4, 0.45, 0.35) end
				local offset = Vector3.new(rng:NextNumber(-half.X, half.X), rng:NextNumber(-half.Y, half.Y), rng:NextNumber(-half.Z, half.Z))
				if part.Name == "Head" then offset = Vector3.new(offset.X, offset.Y, math.abs(offset.Z)) end -- lumps on the back, face stays readable
				local r = rng:NextNumber(0.45, part.Name == "Torso" and 1.2 or 0.8)
				weldBlob(holder, part, CFrame.new(offset), Vector3.new(r, r * rng:NextNumber(0.7, 1.2), r),
					FLESH_COLORS[rng:NextInteger(1, #FLESH_COLORS)], rng:NextNumber(0.1, 0.3), TEXTURES.Meat)
			end
		end
	end
	local head = model:FindFirstChild("Head")
	if head then
		-- (the face decal is already gone in roundHead; Texture is a Decal subclass, so no Decal sweep here)
		addEye(holder, head, CFrame.new(-0.22, 0.14, -0.56), 0.26)
		addEye(holder, head, CFrame.new(0.24, 0.1, -0.56), 0.3)
		addEye(holder, head, CFrame.new(0.05, 0.36, -0.5), 0.16)
		-- a torn vertical maw full of teeth
		weldBlob(holder, head, CFrame.new(0, -0.2, -0.55), Vector3.new(0.34, 0.6, 0.3), Color3.fromRGB(16, 0, 2), 0.35)
		for i = 1, 7 do
			local y = -0.46 + i * 0.07
			for _, side in ipairs({-1, 1}) do
				local tooth = weldBlob(holder, head, CFrame.new(side * 0.12, y, -0.66) * CFrame.Angles(0, 0, side * math.rad(80)),
					Vector3.new(0.05, 0.13, 0.05), Color3.fromRGB(226, 214, 186), 0.05)
				tooth.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	-- extra eyes where eyes should not be
	local torso = model:FindFirstChild("Torso")
	if torso then
		for _ = 1, 4 do
			local x, y = rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.7, 0.8)
			addEye(holder, torso, CFrame.new(x, y, -0.52), rng:NextNumber(0.14, 0.24))
		end
	end
	for _, name in ipairs({"Left Arm", "Right Arm"}) do
		local arm = model:FindFirstChild(name)
		if arm then addEye(holder, arm, CFrame.new(0, rng:NextNumber(-0.5, 0.6), -0.53), 0.15) end
	end
	local grab = Instance.new("ObjectValue")
	grab.Name = "GS_GrabTarget"
	grab.Parent = model
	return model
end

-- C-207: blind. Smooth skin where the eyes should be, a mouth that splits the head, veins everywhere.
local function buildListenerModel()
	local skin = Color3.fromRGB(150, 152, 158)
	local model = coloredModel(skin)
	if not model then return nil end
	roundHead(model, 1.3)
	local holder = Instance.new("Folder")
	holder.Name = "GS_Body"
	holder.Parent = model
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.SmoothPlastic
			part.Color = skin
			paintPart(part, TEXTURES.ListenerSkin, part.Name == "Head" and 1.3 or 3)
			if part.Name ~= "Head" then
				addVeins(holder, part, part.Name == "Torso" and 6 or 4, Color3.fromRGB(62, 42, 96), 0.08)
			end
		end
	end
	local head = model:FindFirstChild("Head")
	if head then
		local dark = Color3.fromRGB(96, 92, 104)
		-- sealed-over eyes: sunken skin, stitched shut
		for _, side in ipairs({-1, 1}) do
			weldBlob(holder, head, CFrame.new(side * 0.22, 0.16, -0.55), Vector3.new(0.3, 0.16, 0.12), dark, 0)
			for i = -1, 1 do
				local stitch = weldBlob(holder, head, CFrame.new(side * 0.22 + i * 0.08, 0.16, -0.61) * CFrame.Angles(0, 0, math.rad(90)),
					Vector3.new(0.02, 0.14, 0.02), Color3.fromRGB(20, 14, 14), 0)
				stitch.Material = Enum.Material.SmoothPlastic
			end
		end
		-- huge mouth, cheek to cheek, rows of needle teeth
		weldBlob(holder, head, CFrame.new(0, -0.2, -0.5), Vector3.new(0.95, 0.42, 0.34), Color3.fromRGB(10, 2, 4), 0.2)
		weldBlob(holder, head, CFrame.new(0, -0.2, -0.47), Vector3.new(1.02, 0.5, 0.3), Color3.fromRGB(88, 18, 30), 0.25)
		for i = -5, 5 do
			local x = i * 0.075
			local curve = 0.05 * (x * x) / 0.15
			for _, row in ipairs({{0.11, 1}, {-0.13, -1}}) do
				weldBlob(holder, head, CFrame.new(x, -0.2 + row[1] - row[2] * curve, -0.64 + math.abs(x) * 0.25),
					Vector3.new(0.035, rng:NextNumber(0.1, 0.17), 0.035), Color3.fromRGB(232, 226, 205), 0.1)
			end
		end
	end
	return model
end

-- E-116 "The Weaver": a dog-sized spider. The server builds the body (thorax, abdomen, head, eyes, fangs);
-- the eight legs are drawn and animated by every client (SpiderClient) from the Leg1..Leg8 attachments.
local SPIDER_HIP = 1.5
local SPIDER_SCALE = 0.65 -- the whole body is built at full size, then shrunk
local function spiderBlob(model, root, name, size, localCF, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Reflectance = 0.06
	part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, true
	if shape then
		part.Shape = shape
	else
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.CFrame = root.CFrame * localCF
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- mother = A-116: the same body plan at car size, rust-red, with an egg sac under the abdomen
local MOTHER_SCALE = 1.35
local function buildSpiderModel(mother)
	local scale = mother and MOTHER_SCALE or SPIDER_SCALE
	local model = Instance.new("Model")
	local chitin = mother and Color3.fromRGB(58, 22, 16) or Color3.fromRGB(30, 23, 21)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2.6, 1, 3.4)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new(0, 10, 0)
	root.Parent = model
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- not an R6 body: the character animator leaves it alone
	humanoid.RequiresNeck = false
	humanoid.HipHeight = SPIDER_HIP
	humanoid.Parent = model

	local thorax = spiderBlob(model, root, "Torso", Vector3.new(2.2, 1.25, 2.3), CFrame.new(0, 0.15, -0.3), chitin, Enum.Material.Slate)
	thorax.Reflectance = 0.1
	local abdomen = spiderBlob(model, root, "Abdomen", mother and Vector3.new(3.3, 2.7, 4) or Vector3.new(2.9, 2.3, 3.4),
		CFrame.new(0, 0.75, mother and 2.5 or 2.2) * CFrame.Angles(math.rad(14), 0, 0),
		mother and Color3.fromRGB(46, 16, 12) or Color3.fromRGB(24, 18, 17), Enum.Material.Slate)
	if mother then
		-- the egg sac: a pale, lumpy bundle slung under the abdomen, with dark shapes inside
		for _ = 1, 14 do
			local r = rng:NextNumber(0.55, 0.9)
			local egg = spiderBlob(model, root, "GS_Egg", Vector3.new(r, r * 0.9, r),
				CFrame.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.55, -0.1), rng:NextNumber(1.9, 3.6)),
				Color3.fromRGB(214, 206, 180), Enum.Material.SmoothPlastic)
			egg.Transparency = 0.15
			egg.Reflectance = 0.15
		end
		for _ = 1, 5 do
			spiderBlob(model, root, "GS_Embryo", Vector3.new(0.3, 0.22, 0.34),
				CFrame.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.45, -0.2), rng:NextNumber(2.1, 3.3)),
				Color3.fromRGB(40, 20, 16), Enum.Material.SmoothPlastic)
		end
	end
	-- pale bristles on the back
	for _ = 1, mother and 30 or 16 do
		local x, z = rng:NextNumber(-1.1, 1.1), rng:NextNumber(1, 3.4)
		spiderBlob(model, root, "GS_Bristle", Vector3.new(0.05, 0.45, 0.05),
			CFrame.new(x, 1.7 - math.abs(x) * 0.5, z) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.6, 0.6)),
			Color3.fromRGB(120, 105, 92), nil, Enum.PartType.Block)
	end

	local head = spiderBlob(model, root, "Head", Vector3.new(1.35, 1.05, 1.2), CFrame.new(0, 0.2, -1.75), Color3.fromRGB(34, 26, 24), Enum.Material.Slate)
	-- eight eyes: two big, six small, all a wet red
	local EYES = {
		{-0.2, 0.18, 0.2}, {0.2, 0.18, 0.2},
		{-0.42, 0.28, 0.12}, {0.42, 0.28, 0.12}, {-0.1, 0.38, 0.11}, {0.1, 0.38, 0.11},
		{-0.52, 0.08, 0.1}, {0.52, 0.08, 0.1},
	}
	for _, e in ipairs(EYES) do
		local eye = spiderBlob(model, root, "GS_Eye", Vector3.new(e[3], e[3], e[3]),
			CFrame.new(0, 0.2, -1.75) * CFrame.new(e[1], e[2], -0.52), Color3.fromRGB(200, 12, 16), Enum.Material.Neon, Enum.PartType.Ball)
		eye.Reflectance = 0.3
	end
	-- fangs hanging under the head
	for _, side in ipairs({-1, 1}) do
		spiderBlob(model, root, "GS_Chelicera", Vector3.new(0.34, 0.5, 0.34),
			CFrame.new(0, 0.2, -1.75) * CFrame.new(side * 0.24, -0.4, -0.42), Color3.fromRGB(40, 28, 26), Enum.Material.Slate)
		spiderBlob(model, root, "GS_Fang", Vector3.new(0.09, 0.45, 0.09),
			CFrame.new(0, 0.2, -1.75) * CFrame.new(side * 0.24, -0.78, -0.5) * CFrame.Angles(math.rad(-20), 0, side * math.rad(-12)),
			Color3.fromRGB(215, 200, 170), nil, Enum.PartType.Block)
		-- palps
		spiderBlob(model, root, "GS_Palp", Vector3.new(0.14, 0.14, 0.7),
			CFrame.new(0, 0.2, -1.75) * CFrame.new(side * 0.55, -0.3, -0.5) * CFrame.Angles(math.rad(-30), side * math.rad(-20), 0),
			chitin, nil, Enum.PartType.Block)
	end

	-- where the legs join the thorax, for the clients' leg rig
	local LEGS = {
		{-1, -1.05}, {-1, -0.4}, {-1, 0.25}, {-1, 0.8},
		{1, -1.05}, {1, -0.4}, {1, 0.25}, {1, 0.8},
	}
	for i, l in ipairs(LEGS) do
		local a = Instance.new("Attachment")
		a.Name = "Leg" .. i
		a.Position = Vector3.new(l[1] * 0.95, 0.25, l[2] - 0.3)
		a.Parent = root
	end
	model:SetAttribute("SpiderRig", true)
	pcall(function() model:ScaleTo(scale) end)
	humanoid.HipHeight = SPIDER_HIP * scale
	model:SetAttribute("SpiderHip", SPIDER_HIP * scale)
	model:SetAttribute("SpiderScale", scale)
	return model
end

local function buildModel(id, cframe)
	local data = MonsterData.Get(id)
	if not data then return nil, "unknown object" end
	local model
	if data.kind == "skinwalker" then
		model = buildBareModel()
		if not model then return nil, "could not build the body" end
	elseif data.kind == "flesh" then
		model = buildFleshModel()
		if not model then return nil, "could not build the body" end
	elseif data.kind == "listener" then
		model = buildListenerModel()
		if not model then return nil, "could not build the body" end
	elseif data.kind == "spider" or data.kind == "spidermother" then
		model = buildSpiderModel(data.kind == "spidermother")
	else
		local template = getTemplate()
		if not template then return nil, "shadow template missing" end
		model = template:Clone()
	end
	model.Name = id
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if not humanoid or not root or not head then
		model:Destroy()
		return nil, "bad template"
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = 1e6
	humanoid.Health = 1e6
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 45
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	if data.kind == "skinwalker" then
		-- starts without a skin; it only gets one by killing someone
		model:SetAttribute("DisguiseName", "")
		model:SetAttribute("DisguiseUser", "")
		model:SetAttribute("VoicePitch", rng:NextNumber())
		model:SetAttribute("Revealed", true)
		model:SetAttribute("GS_Twitch", true)
		model:SetAttribute("Typing", false)
		applyBareLook(model)
	elseif data.kind == "listener" then
		model:SetAttribute("GS_Twitch", true)
	elseif data.kind == "stalker" then

		for _, part in ipairs(head:GetChildren()) do
			if part:IsA("BasePart") and part.Name == "Eye" then
				part.Color = Color3.fromRGB(205, 215, 225)
			end
		end
		local glow = Instance.new("PointLight")
		glow.Range = 4
		glow.Brightness = 0.35
		glow.Color = Color3.fromRGB(190, 200, 215)
		glow.Parent = head
	end
	model:SetAttribute("MonsterId", id)
	model:SetAttribute("DangerClass", data.class)

	local faceAttachment = Instance.new("Attachment")
	faceAttachment.Name = "GS_FaceAttachment"
	faceAttachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "GS_Face"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = faceAttachment
	align.MaxTorque = 1e6
	align.Responsiveness = 18
	align.Enabled = false
	align.Parent = root
	local targetValue = Instance.new("ObjectValue")
	targetValue.Name = "GS_Target"
	targetValue.Parent = model
	model:PivotTo(cframe)
	model.Parent = folder
	pcall(function() root:SetNetworkOwner(nil) end)
	return model
end

local function groundSpot(center, minDist, maxDist)
	refreshGroundFilter()
	for _ = 1, 12 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(minDist, maxDist)
		local p = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local hit = workspace:Raycast(p + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), groundParams)
		if hit and hit.Normal.Y > 0.6 then return hit.Position + Vector3.new(0, 3, 0) end
	end
	return center + Vector3.new(0, 3, 0)
end

local function serverNow() return workspace:GetServerTimeNow() end

local function fx(brain, kind, extra)
	if brain.model.Parent then fxRemote:FireAllClients(brain.model, kind, extra) end
end

local function setState(brain, state)
	if brain.state == state then return end
	brain.state = state
	brain.stateSince = os.clock()
	brain.model:SetAttribute("State", state)
	brain.waypoints = nil
end

local function setTarget(brain, character)
	brain.target = character
	local value = brain.model:FindFirstChild("GS_Target")
	if value then value.Value = character end
	if character then brain.lastSeen = os.clock() end
end

local function sightParams(brain, extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {folder}
	if extra then table.insert(ignore, extra) end
	local severed = workspace:FindFirstChild("SeveredLimbs")
	if severed then table.insert(ignore, severed) end
	local hallucinations = workspace:FindFirstChild("GS_Hallucinations")
	if hallucinations then table.insert(ignore, hallucinations) end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function canSee(brain, character)
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not head then return false end
	local origin = brain.head.Position
	local offset = head.Position - origin
	if offset.Magnitude > SIGHT_RANGE then return false end
	return workspace:Raycast(origin, offset, sightParams(brain, character)) == nil
end

local function pickTarget(brain)
	local visible = {}
	for _, character in ipairs(livingTargets()) do
		if canSee(brain, character) then table.insert(visible, character) end
	end
	if #visible == 0 then return nil end
	return visible[rng:NextInteger(1, #visible)]
end

-- Movement: straight line when the way is clear, otherwise async pathfinding.
-- Never jumps blindly — only on path jump waypoints or when a low obstacle is ahead.
local moveParams = RaycastParams.new()
moveParams.FilterType = Enum.RaycastFilterType.Exclude
moveParams.IgnoreWater = true
local moveParamsTime = -math.huge

local function getMoveParams()
	local now = os.clock()
	if now - moveParamsTime > 0.5 then
		moveParamsTime = now
		local ignore = {folder}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then table.insert(ignore, plr.Character) end
		end
		for _, name in ipairs({"NPCs", "SeveredLimbs", "Corpses", "GS_Hallucinations"}) do
			local f = workspace:FindFirstChild(name)
			if f then table.insert(ignore, f) end
		end
		moveParams.FilterDescendantsInstances = ignore
	end
	return moveParams
end

local function groundAt(pos, depth)
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -(depth or 40), 0), getMoveParams())
	return hit and hit.Position or nil
end

-- true when a humanoid can simply walk from `fromPos` (root height) to `toPos`
local function walkableLine(fromPos, toPos)
	local params = getMoveParams()
	local offset = flat(toPos - fromPos)
	local dist = offset.Magnitude
	if dist < 0.5 then return true end
	for _, h in ipairs({-1.9, 1.2}) do
		local o = fromPos + Vector3.new(0, h, 0)
		if workspace:Raycast(o, offset, params) then return false end
	end
	local steps = math.min(math.floor(dist / 4), 14)
	local floorY = fromPos.Y - 3
	for i = 1, steps do
		local g = groundAt(fromPos + offset * (i / (steps + 1)), 14)
		if not g or g.Y < floorY - 4.5 or g.Y > floorY + 1.6 then return false end
		floorY = g.Y
	end
	return true
end

-- where to run to reach a character: its ground position, slightly led by its velocity
local function chasePoint(brain, character)
	local troot = character:FindFirstChild("HumanoidRootPart")
	if not troot then return brain.root.Position end
	local p = troot.Position
	local g = groundAt(p, 40)
	if g and p.Y - g.Y > 3.6 then p = g + Vector3.new(0, 3, 0) end
	local vel = flat(troot.AssemblyLinearVelocity)
	if vel.Magnitude > 1 then
		local lead = math.clamp(flat(p - brain.root.Position).Magnitude / 30, 0, 0.45)
		local led = p + vel * lead
		if walkableLine(p, led) then p = led end
	end
	return p
end

local function requestPath(brain, goal)
	brain.pathBusy = true
	brain.pathDirty = false
	local from = brain.root.Position
	task.spawn(function()
		local path = PathfindingService:CreatePath(PATH_SETTINGS)
		local ok = pcall(function() path:ComputeAsync(from, goal) end)
		brain.pathBusy = false
		if not brain.model.Parent then return end
		brain.pathGoal, brain.pathTime = goal, os.clock()
		if brain.pathConn then brain.pathConn:Disconnect() brain.pathConn = nil end
		if ok and path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			brain.waypoints = waypoints
			brain.waypointIndex = math.min(2, #waypoints)
			brain.pathFailed = 0
			brain.pathConn = path.Blocked:Connect(function(index)
				if brain.waypoints == waypoints and index >= (brain.waypointIndex or 1) then brain.pathDirty = true end
			end)
		else
			brain.waypoints = nil
			brain.pathFailed = (brain.pathFailed or 0) + 1
		end
	end)
end

local function followWaypoints(brain)
	local humanoid, pos = brain.humanoid, brain.root.Position
	local waypoints = brain.waypoints
	local i = brain.waypointIndex or 1
	while i < #waypoints do
		local wp = waypoints[i]
		if flat(wp.Position - pos).Magnitude < 2 and math.abs(wp.Position.Y - (pos.Y - 3)) < 3.5 then
			if waypoints[i + 1].Action == Enum.PathWaypointAction.Jump and humanoid.FloorMaterial ~= Enum.Material.Air then
				humanoid.Jump = true
			end
			i += 1
		else
			break
		end
	end
	-- skip a waypoint when the next one is on the same level and in plain reach
	local nextWp = waypoints[i + 1]
	if nextWp and waypoints[i].Action ~= Enum.PathWaypointAction.Jump and nextWp.Action ~= Enum.PathWaypointAction.Jump
		and math.abs(nextWp.Position.Y - (pos.Y - 3)) < 1.2 and walkableLine(pos, nextWp.Position + Vector3.new(0, 3, 0)) then
		i += 1
	end
	brain.waypointIndex = i
	local wp = waypoints[i]
	if wp.Action == Enum.PathWaypointAction.Jump and flat(wp.Position - pos).Magnitude < 3.5
		and humanoid.FloorMaterial ~= Enum.Material.Air then
		humanoid.Jump = true
	end
	humanoid:MoveTo(wp.Position)
	if i >= #waypoints and flat(wp.Position - pos).Magnitude < 2 then brain.waypoints = nil end
end

local function handleStuck(brain, now, goal)
	local humanoid, root = brain.humanoid, brain.root
	local pos = root.Position
	if not brain.progressPos or now - brain.progressTime > 0.7 then
		local moved = brain.progressPos and flat(pos - brain.progressPos).Magnitude or math.huge
		brain.progressPos, brain.progressTime = pos, now
		local targetRoot = brain.target and brain.target:FindFirstChild("HumanoidRootPart")
		local nearTarget = targetRoot and flat(targetRoot.Position - pos).Magnitude < 5
		if moved > 1.2 or nearTarget then
			brain.stuckCount = 0
			return
		end
		brain.stuckCount = (brain.stuckCount or 0) + 1
		brain.pathDirty = true
		local dir = humanoid.MoveDirection.Magnitude > 0.1 and flat(humanoid.MoveDirection).Unit or flat(goal - pos)
		if dir.Magnitude < 0.1 then return end
		dir = dir.Unit
		local params = getMoveParams()
		local lowHit = workspace:Raycast(pos + Vector3.new(0, -1.9, 0), dir * 3, params)
		local highHit = workspace:Raycast(pos + Vector3.new(0, 2.6, 0), dir * 3.5, params)
		if lowHit and not highHit and humanoid.FloorMaterial ~= Enum.Material.Air then
			humanoid.Jump = true
		elseif brain.stuckCount >= 3 then
			local side = Vector3.new(-dir.Z, 0, dir.X) * (rng:NextNumber() < 0.5 and -1 or 1)
			brain.sidestepGoal = pos + side * 5 - dir * 1.5
			brain.sidestepUntil = now + 0.7
			brain.stuckCount = 0
			brain.waypoints = nil
		end
	end
end

local releaseFacing
-- returns arrived, reachable
local function goTo(brain, goal, speed)
	local humanoid, root = brain.humanoid, brain.root
	if releaseFacing then releaseFacing(brain) end
	humanoid.WalkSpeed = speed
	local now = os.clock()
	local pos = root.Position

	if brain.sidestepUntil and now < brain.sidestepUntil then
		humanoid:MoveTo(brain.sidestepGoal)
		return false, true
	end

	local goalGround = groundAt(goal, 30) or (goal - Vector3.new(0, 3, 0))
	local myGround = pos.Y - 3
	local dy = goalGround.Y - myGround
	local flatDist = flat(goal - pos).Magnitude
	if flatDist < 1.5 and math.abs(dy) < 3 then
		humanoid:Move(Vector3.zero)
		brain.waypoints = nil
		return true, true
	end

	if math.abs(dy) < 2.5 and flatDist < 70 and walkableLine(pos, Vector3.new(goal.X, pos.Y, goal.Z)) then
		brain.waypoints = nil
		brain.pathFailed = 0
		humanoid:MoveTo(Vector3.new(goal.X, goalGround.Y + 3, goal.Z))
		handleStuck(brain, now, goal)
		return false, true
	end

	local needPath = brain.pathDirty or not brain.waypoints or not brain.pathGoal
		or (brain.pathGoal - goalGround).Magnitude > 5 or now - (brain.pathTime or 0) > 1.5
	if needPath and not brain.pathBusy then requestPath(brain, goalGround) end

	local reachable = (brain.pathFailed or 0) < 2
	if brain.waypoints then
		followWaypoints(brain)
		handleStuck(brain, now, goal)
	elseif math.abs(dy) < 2.5 then
		humanoid:MoveTo(goal)
		handleStuck(brain, now, goal)
	elseif flatDist > 6 then
		-- target is somewhere we can't climb yet: close in on the ground, but don't hop around under it
		humanoid:MoveTo(Vector3.new(goal.X, pos.Y, goal.Z))
	else
		humanoid:Move(Vector3.zero)
	end
	return false, reachable
end

local function stop(brain)
	brain.humanoid:Move(Vector3.zero)
	brain.humanoid.WalkSpeed = 0
	brain.waypoints = nil
	brain.progressPos = nil
end

local function face(brain, position)
	local root = brain.root
	local look = flat(position - root.Position)
	if look.Magnitude < 0.1 then return end
	local align = brain.align
	if align then
		align.CFrame = CFrame.lookAt(Vector3.zero, look)
		align.Enabled = true
		brain.humanoid.AutoRotate = false
		brain.facing = true
	end
end

function releaseFacing(brain)
	if brain.facing then
		brain.facing = false
		if brain.align then brain.align.Enabled = false end
		brain.humanoid.AutoRotate = true
	end
end

local function awayPoint(brain, from, distance)
	local dir = flat(brain.root.Position - from)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
	local sideways = Vector3.new(-dir.Z, 0, dir.X) * rng:NextNumber(-0.4, 0.4)
	local p = brain.root.Position + (dir + sideways).Unit * distance
	local hit = workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), sightParams(brain))
	return hit and hit.Position or p
end

local function approachingMe(brain, character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local toMe = flat(brain.root.Position - root.Position)
	if toMe.Magnitude < 0.1 then return false end
	local closing = flat(root.AssemblyLinearVelocity):Dot(toMe.Unit)
	return closing > 5
end

local foodPiece
local CORPSE_ORDER = {"Left Arm", "Right Arm", "Left Leg", "Right Leg", "Head", "Torso"}

local function isCorpseModel(model)
	return model:GetAttribute("Corpse") == true or (model.Parent ~= nil and model.Parent.Name == "Corpses")
end

function foodPiece(food)
	if not food or not food.Parent then return nil end
	if isCorpseModel(food) then
		for _, name in ipairs(CORPSE_ORDER) do
			local part = food:FindFirstChild(name)
			if part and part:IsA("BasePart") then return part end
		end
		for _, child in ipairs(food:GetChildren()) do
			if child:IsA("BasePart") then return child end
		end
		return nil
	end
	return food.PrimaryPart or food:FindFirstChildWhichIsA("BasePart")
end

local function nearestFood(brain, maxDist)
	local best, bestDist = nil, maxDist
	for _, folderName in ipairs({"SeveredLimbs", "Corpses"}) do
		local foodFolder = workspace:FindFirstChild(folderName)
		if foodFolder then
			for _, model in ipairs(foodFolder:GetChildren()) do
				if model:IsA("Model") and not model:GetAttribute("GS_BeingEaten") then
					local part = foodPiece(model)
					if part then
						local d = (part.Position - brain.root.Position).Magnitude
						if d < bestDist then best, bestDist = model, d end
					end
				end
			end
		end
	end
	return best
end

local function freshestTrailPoint(brain, radius)
	local pos = brain.root.Position
	for i = #trail, 1, -1 do
		local point = trail[i]
		if point.t <= brain.trailFloor then break end
		if (point.pos - pos).Magnitude < radius then
			return point
		end
	end
	return nil
end

local LIMB_WEIGHTS = {LeftArm = 3, RightArm = 3, LeftLeg = 3, RightLeg = 3, Head = 1}
local onFleshKill
local function hitVictim(brain, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local choices, total = {}, 0
	for part, weight in pairs(LIMB_WEIGHTS) do
		if (character:GetAttribute("Injury_" .. part) or 0) < 3 then
			table.insert(choices, {part, weight})
			total += weight
		end
	end
	fx(brain, "Hit")
	if brain.data.kind == "skinwalker" then
		-- remember the skin before the blow lands; worn after the kill
		brain.lastHitLook = describe(character) or brain.lastHitLook
		brain.lastHitVictim = character
		brain.lastHitTime = os.clock()
	end
	local cause = brain.data.deathCause or "D130"
	character:SetAttribute("LastDamageCause", cause)
	character:SetAttribute("LastDamageTime", serverNow())
	if total <= 0 then
		humanoid:TakeDamage(12)
		if humanoid.Health <= 0 then
			character:SetAttribute("DeathCause", cause)
			if brain.data.kind == "flesh" and onFleshKill then onFleshKill(brain, character) end
		end
		return
	end
	local roll = rng:NextNumber(0, total)
	local part = choices[#choices][1]
	for _, c in ipairs(choices) do
		roll -= c[2]
		if roll <= 0 then part = c[1] break end
	end
	local level = (character:GetAttribute("Injury_" .. part) or 0) + 1
	if level == 2 and part ~= "Head" and (character:GetAttribute("InfectStage") or 0) >= 2 then
		-- fully grown infected: bones don't break, but a limb hit hard enough twice still comes off
		local key = "GS_Wounds_" .. part
		local wounds = (character:GetAttribute(key) or 0) + 1
		character:SetAttribute(key, wounds < 2 and wounds or 0)
		level = wounds >= 2 and 3 or 1
	end
	local raw = (brain.data.damageBase or 4) + level * (brain.data.damagePerLevel or 3)
	local dealt, blocked = raw, false
	do -- worn armor (ServerStorage.GS_ItemService) takes a share and may stop the wound
		local okSvc, svc = pcall(function() return require(game:GetService("ServerStorage"):FindFirstChild("GS_ItemService")) end)
		if okSvc and svc and svc.Absorb then dealt, blocked = svc.Absorb(character, part, raw, "claw") end
	end
	humanoid:TakeDamage(dealt)
	if humanoid.Health > 0 and not blocked then
		FallDamageController.Injure(character, part, level)
		if level >= 3 then
			brain.eatPriorityUntil = os.clock() + 20
		end
	end
	task.defer(function()
		if humanoid.Health > 0 then return end
		if not character:GetAttribute("DeathCause") or character:GetAttribute("DeathCause") == "UNKNOWN" then
			character:SetAttribute("DeathCause", cause)
		end
		if brain.data.kind == "flesh" and onFleshKill then onFleshKill(brain, character) end
	end)
end

-- chase + swing shared by both monsters; returns false while the target can't be reached
local function attackStep(brain, now, targetRoot, speed, stateName, cooldown, windup)
	local root = brain.root
	local range = brain.data.attackRange or ATTACK_RANGE
	local offset = targetRoot.Position - root.Position
	local distance = flat(offset).Magnitude
	local dy = math.abs(offset.Y)
	local reachable = true
	if distance > 2.6 or dy > 3 then
		local _, ok = goTo(brain, chasePoint(brain, brain.target), speed)
		reachable = ok ~= false
	else
		stop(brain)
		face(brain, targetRoot.Position)
	end
	if distance <= range and dy < 4.5 and now >= brain.nextSwing then
		brain.nextSwing = now + cooldown
		brain.model:SetAttribute("GS_AttackServer", serverNow())
		if distance > 0.1 then
			root.AssemblyLinearVelocity += flat(offset).Unit * 12
		end
		local victim = brain.target
		task.delay(windup, function()
			if brain.state == stateName and brain.target == victim and victim.Parent then
				local vr = victim:FindFirstChild("HumanoidRootPart")
				if vr and (vr.Position - brain.root.Position).Magnitude <= range + 2.4 then
					hitVictim(brain, victim)
				end
			end
		end)
	end
	if reachable then
		brain.unreachableSince = nil
	elseif not brain.unreachableSince then
		brain.unreachableSince = now
	end
	return reachable
end

local function nearestVisible(brain, radius)
	local best, bestDist = nil, radius
	for _, character in ipairs(livingTargets()) do
		local d = (character.HumanoidRootPart.Position - brain.root.Position).Magnitude
		if d < bestDist and canSee(brain, character) then best, bestDist = character, d end
	end
	return best
end

-- ===== Hearing: every monster hears what players do =====
-- Each character has a noise radius right now: how far away a monster can hear it.
-- Steps, jumps, landings, lying down, crawling, talking in chat or voice, fighting, pain,
-- and at point blank even a heartbeat.
local noiseRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_Noise")
local noiseEvents = {}

local function makeNoise(character, radius, duration)
	if not character then return end
	local now = os.clock()
	local current = noiseEvents[character]
	if current and current.untilT > now and current.radius >= radius then return end
	noiseEvents[character] = {radius = radius, untilT = now + (duration or 1)}
end

local function noiseRadius(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return 0 end
	local vel = root.AssemblyLinearVelocity
	local speed = flat(vel).Magnitude
	-- a heartbeat, louder when hurt: only audible right next to you
	local radius = humanoid.Health < humanoid.MaxHealth * 0.5 and 6.5 or 4.5
	if (character:GetAttribute("Bleeding") or 0) > 0.05 then radius = math.max(radius, 9) end -- ragged breathing
	if speed > 0.8 then
		if character:GetAttribute("GS_Prone") then
			radius = math.max(radius, 9 + speed * 0.6)       -- dragging yourself along the floor
		elseif character:GetAttribute("GS_Crouch") then
			radius = math.max(radius, 11 + speed * 0.8)
		else
			radius = math.max(radius, 18 + speed * 1.7)      -- every footstep
		end
	end
	if vel.Y > 8 then radius = math.max(radius, 40) end
	if character:GetAttribute("Ragdolled") then radius = math.max(radius, 42) end
	local event = noiseEvents[character]
	if event and event.untilT > os.clock() then radius = math.max(radius, event.radius) end
	return radius
end

-- the loudest thing this monster can hear right now
local function hear(brain)
	local mult = brain.data.hearing or 1
	local best, bestMargin, bestPos = nil, 0, nil
	for _, character in ipairs(livingTargets()) do
		local d = (character.HumanoidRootPart.Position - brain.root.Position).Magnitude
		local margin = noiseRadius(character) * mult - d
		if margin > bestMargin then best, bestMargin, bestPos = character, margin, character.HumanoidRootPart.Position end
	end
	return best, bestPos
end

-- walk towards whatever it heard; returns the character it hears right now (if any)
local function followNoise(brain, now, speed)
	local who, pos = hear(brain)
	if who then brain.noisePos, brain.noiseAt = pos, now end
	if brain.noisePos then
		if now - (brain.noiseAt or 0) > 8 then
			brain.noisePos = nil
		elseif goTo(brain, brain.noisePos, speed) or flat(brain.noisePos - brain.root.Position).Magnitude < 3 then
			brain.noisePos = nil
		end
	end
	return who
end

local function hookNoisePlayer(plr)
	plr.Chatted:Connect(function()
		makeNoise(plr.Character, 70, 2.5)
	end)
	plr.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then return end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			if last - health >= 4 then makeNoise(character, 65, 1.5) end -- screaming in pain
			last = health
		end)
		for _, attribute in ipairs({"GS_Prone", "GS_Crouch"}) do
			character:GetAttributeChangedSignal(attribute):Connect(function()
				makeNoise(character, 16, 1) -- lying down / getting up
			end)
		end
		character:GetAttributeChangedSignal("LastFallHeight"):Connect(function()
			makeNoise(character, 55, 1.5) -- a body hitting the ground
		end)
	end)
end
for _, plr in ipairs(Players:GetPlayers()) do hookNoisePlayer(plr) end
Players.PlayerAdded:Connect(hookNoisePlayer)

-- voice: each client measures its own microphone (new audio API) and reports how loud it is
local lastVoice = {}
noiseRemote.OnServerEvent:Connect(function(plr, kind, level)
	if kind ~= "voice" or typeof(level) ~= "number" then return end
	local now = os.clock()
	if now - (lastVoice[plr] or 0) < 0.2 then return end
	lastVoice[plr] = now
	level = math.clamp(level, 0, 1)
	makeNoise(plr.Character, 30 + level * 60, 0.7)
end)
Players.PlayerRemoving:Connect(function(plr)
	lastVoice[plr] = nil
	if plr.Character then noiseEvents[plr.Character] = nil end
end)
task.spawn(function()
	while true do
		task.wait(10)
		for character in pairs(noiseEvents) do
			if not character.Parent then noiseEvents[character] = nil end
		end
	end
end)

local function abortEat(brain)
	if brain.food and brain.food.Parent then brain.food:SetAttribute("GS_BeingEaten", nil) end
	if brain.eatingPiece and brain.eatingPiece.Parent then
		pcall(function() brain.eatingPiece.Anchored = false end)
	end
	brain.food, brain.eatingPiece, brain.eatingUntil = nil, nil, nil
	brain.model:SetAttribute("GS_EatServer", nil)
end

local skinwalkerStruck
local ENRAGE_HITS = 3
local ENRAGE_TIME = 90
local function onStruck(brain, striker)
	if brain.data.kind == "skinwalker" and skinwalkerStruck then
		skinwalkerStruck(brain, striker)
		return
	end
	local now = os.clock()
	local strikerRoot = striker:FindFirstChild("HumanoidRootPart")
	local away = strikerRoot and flat(brain.root.Position - strikerRoot.Position) or Vector3.zero
	away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
	brain.hitsTaken = (brain.hitsTaken or 0) + 1

	if brain.data.kind ~= "stalker" then
		-- the flesh and the listener don't run: a short flinch, then they turn on whoever hit them
		fx(brain, "Hurt")
		brain.staggerUntil = now + 0.45
		brain.root.AssemblyLinearVelocity += away * 10
		if aliveCharacter(striker) and not isInfected(striker) then
			if brain.state == "eat" then abortEat(brain) end
			setTarget(brain, striker)
			brain.lastSeen, brain.lastHeard = now, now
			if strikerRoot then brain.noisePos = strikerRoot.Position end
			setState(brain, brain.data.kind == "flesh" and "chase" or "hunt")
		end
		return
	end

	-- D-130: hit it while it is only watching you, or hit it three times, and it stops being afraid
	local provoked = brain.state ~= "attack" and brain.state ~= "retreat"
	if brain.enraged or provoked or brain.hitsTaken >= ENRAGE_HITS then
		brain.enraged = true
		brain.enragedUntil = now + ENRAGE_TIME
		brain.model:SetAttribute("Enraged", true)
		if brain.state == "eat" then abortEat(brain) end
		if aliveCharacter(striker) then setTarget(brain, striker) end
		brain.lastSeen = now
		brain.staggerUntil = now + 0.2
		fx(brain, "Shriek")
		setState(brain, "attack")
		return
	end
	brain.threat = striker
	brain.retreatUntil = os.clock() + randRange(RETREAT_TIME)
	setState(brain, "retreat")
	fx(brain, "Hurt")
	local root = striker:FindFirstChild("HumanoidRootPart")
	if root then
		local dir = flat(brain.root.Position - root.Position)
		dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
		brain.root.AssemblyLinearVelocity += dir * 28 + Vector3.new(0, 12, 0)
	end
end

local function ambientSounds(brain, now)
	if now < brain.nextSound then return end
	local state = brain.state
	if state == "attack" then
		brain.nextSound = now + rng:NextNumber(2.5, 4.5)
		fx(brain, "Growl")
		return
	end
	if state == "eat" or state == "retreat" then
		brain.nextSound = now + rng:NextNumber(3, 6)
		return
	end
	brain.nextSound = now + rng:NextNumber(7, 16)
	local r = rng:NextNumber()
	if state == "watch" or state == "stalk" then

		if r < 0.35 then fx(brain, "Mimic") elseif r < 0.8 then fx(brain, "Ambient") else fx(brain, "Growl") end
	else
		if r < 0.2 then fx(brain, "Mimic") elseif r < 0.65 then fx(brain, "Ambient") else fx(brain, "Growl") end
	end
end

local onCorpseEaten
local hatchBrood
local tentacleGrab
local function eatStep(brain, now, nextState)
	local model, root = brain.model, brain.root
	local food = brain.food
	local piece = foodPiece(food)
	local isCorpse = food and isCorpseModel(food)
	local function finish()
		brain.eatingUntil = nil
		brain.eatPriorityUntil = 0
		if isCorpse and food and onCorpseEaten then onCorpseEaten(brain, food) end
		if food and food.Parent then food:Destroy() end
		brain.food = nil
		setState(brain, nextState())
	end
	if not piece then
		finish()
	elseif not brain.eatingUntil then
		local urgent = now < (brain.eatPriorityUntil or 0)
		if goTo(brain, piece.Position, urgent and HUMAN_SPEED * 1.05 or WALK_SPEED) or (piece.Position - root.Position).Magnitude < 3.4 then
			stop(brain)
			face(brain, piece.Position)
			food:SetAttribute("GS_BeingEaten", true)
			pcall(function() piece.Anchored = true end)
			local duration = isCorpse and 2.6 or 3.4
			brain.eatingPiece = piece
			brain.eatingUntil = now + duration
			model:SetAttribute("GS_EatServer", serverNow() + duration)
			fx(brain, "Eat")
		elseif now - brain.stateSince > 15 then
			food:SetAttribute("GS_BeingEaten", nil)
			brain.food = nil
			setState(brain, "roam")
		end
	elseif now >= brain.eatingUntil then
		brain.eatingUntil = nil
		local eaten = brain.eatingPiece
		brain.eatingPiece = nil
		if isCorpse then

			if eaten and eaten.Parent then
				fx(brain, "Hit")
				local list = food:GetAttribute("EatenParts")
				food:SetAttribute("EatenParts", (list and list ~= "" and (list .. ",") or "") .. eaten.Name)
				-- every piece eaten leaves its bones where it lay
				boneHolders[food] = Skeletons.FromPart(eaten, boneHolders[food])
			end
			if foodPiece(food) then
				brain.stateSince = now
			else
				finish()
			end
		else
			if eaten and eaten.Parent then Skeletons.FromPart(eaten) end
			finish()
		end
	end
end

local function think(brain)
	local now = os.clock()
	local model = brain.model
	if not model.Parent then return false end
	local root = brain.root

	if brain.target and not aliveCharacter(brain.target) then
		setTarget(brain, nil)
		if brain.state ~= "eat" and brain.state ~= "retreat" then setState(brain, "roam") end
	end

	local seesTarget = brain.target and canSee(brain, brain.target)
	if seesTarget then brain.lastSeen = now end

	if now < (brain.staggerUntil or 0) then
		stop(brain)
		return true
	end
	-- the rage fades after a while without being hit
	if brain.enraged and now > (brain.enragedUntil or 0) and brain.state ~= "attack" then
		brain.enraged = false
		brain.hitsTaken = 0
		model:SetAttribute("Enraged", nil)
	end
	-- enraged: no watching, no backing off, no retreating — straight at you
	if brain.enraged and brain.target and aliveCharacter(brain.target)
		and (brain.state == "watch" or brain.state == "stalk" or brain.state == "avoid" or brain.state == "retreat") then
		setState(brain, "attack")
	end

	if brain.state ~= "eat" and brain.state ~= "retreat" and not (brain.enraged and brain.state == "attack") then
		local wantsFood = now < (brain.eatPriorityUntil or 0) or brain.state ~= "attack"
		if wantsFood then
			local limb = nearestFood(brain, now < (brain.eatPriorityUntil or 0) and 60 or 40)
			if limb then
				brain.food = limb
				brain.resumeState = brain.target and "attack" or "roam"
				setState(brain, "eat")
			end
		end
	end

	-- walking right up to it is a mistake: point blank it stops watching and attacks
	if brain.state ~= "attack" and now > (brain.aggroCooldownUntil or 0)
		and (brain.state ~= "retreat" or now - brain.stateSince > 1.2) then
		local close = nearestVisible(brain, CLOSE_AGGRO)
		if close then
			if brain.state == "eat" then abortEat(brain) end
			setTarget(brain, close)
			fx(brain, "Shriek")
			setState(brain, "attack")
		end
	end

	local state = brain.state
	local targetRoot = brain.target and brain.target:FindFirstChild("HumanoidRootPart")
	local distance = targetRoot and flat(targetRoot.Position - root.Position).Magnitude or math.huge

	if state == "roam" or state == "track" then
		local found = pickTarget(brain)
		if found then
			setTarget(brain, found)
			brain.watchUntil = now + randRange(WATCH_TIME)
			if brain.enraged then
				fx(brain, "Shriek")
				setState(brain, "attack")
			else
				setState(brain, "watch")
			end
		else
			local heard = followNoise(brain, now, WALK_SPEED + 3)
			local point = not brain.noisePos and freshestTrailPoint(brain, 140) or nil
			if heard and (heard.HumanoidRootPart.Position - root.Position).Magnitude < CLOSE_AGGRO then
				setTarget(brain, heard)
				fx(brain, "Shriek")
				setState(brain, "attack")
			elseif brain.noisePos then
				if state ~= "track" then setState(brain, "track") end
			elseif point then
				if state ~= "track" then setState(brain, "track") end
				brain.trailPoint = point
				if goTo(brain, point.pos, WALK_SPEED + 2) or (point.pos - root.Position).Magnitude < 4 then
					brain.trailFloor = point.t
				end
			else
				if state ~= "roam" then setState(brain, "roam") end
				if not brain.roamGoal or now > brain.roamUntil then
					brain.roamGoal = groundSpot(root.Position, 20, 55)
					brain.roamUntil = now + rng:NextNumber(6, 11)
				end
				if goTo(brain, brain.roamGoal, WALK_SPEED * 0.8) then brain.roamUntil = now end
			end
		end

	elseif state == "watch" then
		if not targetRoot or now - brain.lastSeen > LOST_TIMEOUT then
			setTarget(brain, nil)
			setState(brain, "track")
		elseif approachingMe(brain, brain.target) and distance < 50 then
			brain.avoidUntil = now + rng:NextNumber(2.5, 4)
			setState(brain, "avoid")
		elseif distance > WATCH_MAX then
			goTo(brain, targetRoot.Position + flat(root.Position - targetRoot.Position).Unit * (WATCH_MIN + 10), SNEAK_SPEED + 2)
		elseif distance < WATCH_MIN - 10 then
			goTo(brain, awayPoint(brain, targetRoot.Position, 14), WALK_SPEED + 2)
		else
			stop(brain)
			face(brain, targetRoot.Position)
			if now > brain.watchUntil then setState(brain, "stalk") end
		end

	elseif state == "stalk" then
		if not targetRoot or now - brain.lastSeen > LOST_TIMEOUT + 2 then
			setTarget(brain, nil)
			setState(brain, "track")
		elseif approachingMe(brain, brain.target) and distance < 30 and distance > 9 then
			brain.avoidUntil = now + rng:NextNumber(2, 3.5)
			setState(brain, "avoid")
		elseif distance < 11 then
			fx(brain, "Shriek")
			setState(brain, "attack")
		else
			goTo(brain, targetRoot.Position, brain.data.approachSpeed or SNEAK_SPEED)
		end

	elseif state == "avoid" then
		if not targetRoot then
			setState(brain, "track")
		elseif now > brain.avoidUntil or distance > 55 then
			brain.watchUntil = math.max(brain.watchUntil or 0, now + 3)
			setState(brain, "watch")
		else
			goTo(brain, awayPoint(brain, targetRoot.Position, 14), WALK_SPEED + 3)
		end

	elseif state == "attack" then
		if not targetRoot then
			setState(brain, "track")
		elseif now - brain.lastSeen > LOST_TIMEOUT then
			setState(brain, "track")
		else
			local speed = HUMAN_SPEED * (brain.data.speedMultiplier or 1.12)
			attackStep(brain, now, targetRoot, speed, "attack", brain.data.swingCooldown or SWING_COOLDOWN, 0.24)
			if brain.unreachableSince and now - brain.unreachableSince > 6 and not brain.enraged then
				-- can't get up there: back off and wait for the victim to come down
				brain.unreachableSince = nil
				brain.aggroCooldownUntil = now + 6
				brain.watchUntil = now + randRange(WATCH_TIME)
				setState(brain, "watch")
			end
		end

	elseif state == "retreat" then
		local threatRoot = brain.threat and brain.threat:FindFirstChild("HumanoidRootPart")
		local threatDist = threatRoot and flat(threatRoot.Position - root.Position).Magnitude or math.huge
		if threatRoot and threatDist < 38 and now - brain.stateSince < 6 then
			goTo(brain, awayPoint(brain, threatRoot.Position, 18), HUMAN_SPEED * (brain.data.speedMultiplier or 1.12))
		else
			stop(brain)
			if threatRoot then face(brain, threatRoot.Position) end
			if now > brain.retreatUntil then

				if brain.target and aliveCharacter(brain.target) then
					setState(brain, "stalk")
				else
					setState(brain, "roam")
				end
			end
		end

	elseif state == "eat" then
		eatStep(brain, now, function()
			if brain.target and aliveCharacter(brain.target) then return brain.resumeState or "attack" end
			return "roam"
		end)
	end
	ambientSounds(brain, now)
	return true
end

-- sheds the borrowed skin: back to its own pale body and face
local function reveal(brain)
	local model = brain.model
	if model:GetAttribute("Revealed") then return end
	model:SetAttribute("Revealed", true)
	model:SetAttribute("GS_Twitch", true)
	model:SetAttribute("Typing", false)
	fx(brain, "Reveal")
	pcall(function() brain.humanoid:ApplyDescription(bareDescription()) end)
	brain.head = model:FindFirstChild("Head") or brain.head
	applyBareLook(model)
end

-- puts on the skin of someone it killed
local function disguise(brain, look)
	local model = brain.model
	if not look or not look.desc then return false end
	model:SetAttribute("Revealed", false)
	model:SetAttribute("GS_Twitch", false)
	model:SetAttribute("Typing", false)
	local oldHead = model:FindFirstChild("Head")
	local faceFolder = oldHead and oldHead:FindFirstChild("GS_CreepyFace")
	if faceFolder then faceFolder:Destroy() end
	pcall(function() brain.humanoid:ApplyDescription(look.desc) end)
	local head = model:FindFirstChild("Head") or brain.head
	brain.head = head
	local painted = head:IsA("MeshPart") and head.TextureID ~= ""
	if not painted and not head:FindFirstChildWhichIsA("Decal") then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = head
	end
	model:SetAttribute("DisguiseName", look.name)
	model:SetAttribute("DisguiseUser", look.user)
	model:SetAttribute("VoicePitch", look.pitch)
	return true
end

local function playersNear(position, radius, except)
	local count = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		local character = plr.Character
		if character ~= except and aliveCharacter(character) then
			if (character.HumanoidRootPart.Position - position).Magnitude < radius then count += 1 end
		end
	end
	return count
end

local function seenByAnyone(brain)
	for _, character in ipairs(livingTargets()) do
		if canSee(brain, character) then return true end
	end
	return false
end

-- the skinwalker prefers someone on their own; failing that, whoever has the fewest people around them
local function pickLonely(brain)
	local best, bestGroup, bestDist = nil, math.huge, math.huge
	for _, character in ipairs(livingTargets()) do
		if canSee(brain, character) then
			local pos = character.HumanoidRootPart.Position
			local group = playersNear(pos, 35, character)
			local d = (pos - brain.root.Position).Magnitude
			if group < bestGroup or (group == bestGroup and d < bestDist) then
				best, bestGroup, bestDist = character, group, d
			end
		end
	end
	return best
end

-- someone staring at it while it feeds: looking its way and nothing in between
local function watcherOf(brain)
	local best, bestDist = nil, 60
	for _, character in ipairs(livingTargets()) do
		local head = character:FindFirstChild("Head")
		if head then
			local offset = brain.head.Position - head.Position
			local d = offset.Magnitude
			if d < bestDist and d > 0.1 and head.CFrame.LookVector:Dot(offset.Unit) > 0.82 and canSee(brain, character) then
				best, bestDist = character, d
			end
		end
	end
	return best
end

function skinwalkerStruck(brain, striker)
	local now = os.clock()
	if not brain.model:GetAttribute("Revealed") then
		setTarget(brain, striker)
		brain.revealUntil = now + 0.9
		setState(brain, "reveal")
		reveal(brain)
		return
	end

	brain.staggerUntil = now + 0.45
	fx(brain, "Hurt")
	local root = striker:FindFirstChild("HumanoidRootPart")
	if root then
		local dir = flat(brain.root.Position - root.Position)
		dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
		brain.root.AssemblyLinearVelocity += dir * 14
	end
	if aliveCharacter(striker) then setTarget(brain, striker) end
end

-- while wearing a skin it copies the victim like a reflection: steps when they step,
-- stops when they stop, jumps when they jump. Silent the whole time.
local function mimicMove(brain, targetRoot, distance)
	local root, humanoid = brain.root, brain.humanoid
	local tvel = flat(targetRoot.AssemblyLinearVelocity)

	local tGround = groundAt(targetRoot.Position, 14)
	local tAir = not tGround or targetRoot.Position.Y - tGround.Y > 3.8
	if tAir and not brain.targetWasAir and targetRoot.AssemblyLinearVelocity.Y > 6 then
		task.delay(rng:NextNumber(0.1, 0.28), function()
			if brain.state == "mimic" and humanoid.FloorMaterial ~= Enum.Material.Air then humanoid.Jump = true end
		end)
	end
	brain.targetWasAir = tAir

	local axis = flat(root.Position - targetRoot.Position)
	axis = axis.Magnitude > 0.1 and axis.Unit or Vector3.new(1, 0, 0)
	if distance > 16 then
		goTo(brain, targetRoot.Position + axis * 7, distance > 30 and HUMAN_SPEED or math.max(12, tvel.Magnitude + 2))
		return
	end
	if tvel.Magnitude < 1.5 then
		if distance < 4 then
			goTo(brain, awayPoint(brain, targetRoot.Position, 4), 8)
		else
			stop(brain)
			face(brain, targetRoot.Position)
		end
		return
	end
	local radial = tvel:Dot(axis)
	local move = (tvel - axis * radial) - axis * radial
	if distance < 5 and move:Dot(-axis) > 0 then move -= -axis * move:Dot(-axis) end
	if distance > 11 then move += -axis * 4 end
	if move.Magnitude < 0.5 then
		stop(brain)
		face(brain, targetRoot.Position)
		return
	end
	local dir = move.Unit
	if walkableLine(root.Position, root.Position + dir * 4) then
		releaseFacing(brain)
		brain.waypoints = nil
		humanoid.WalkSpeed = math.clamp(move.Magnitude, 4, HUMAN_SPEED + 2)
		humanoid:Move(dir, false)
	else
		goTo(brain, targetRoot.Position + axis * 7, math.clamp(tvel.Magnitude, 6, HUMAN_SPEED))
	end
end

local function thinkSkinwalker(brain)
	local now = os.clock()
	local model = brain.model
	if not model.Parent then return false end
	local root = brain.root
	local revealed = model:GetAttribute("Revealed") == true
	local speed = HUMAN_SPEED * (brain.data.speedMultiplier or 1.35)
	if model:GetAttribute("Typing") then model:SetAttribute("Typing", false) end

	if brain.target and not aliveCharacter(brain.target) then
		local victim = brain.target
		if victim == brain.lastHitVictim and brain.lastHitLook and now - (brain.lastHitTime or 0) < 8 then
			-- its own kill: the body is stripped to the bone where it fell, and it walks off wearing them
			local look = brain.lastHitLook
			victim:SetAttribute("GS_NoCorpse", true)
			task.delay(1.1, function()
				if victim.Parent and not victim:GetAttribute("GS_Skeletonized") then Skeletons.FromModel(victim, true) end
			end)
			brain.lastHitVictim, brain.lastHitLook = nil, nil
			setTarget(brain, nil)
			stop(brain)
			fx(brain, "Eat")
			if disguise(brain, look) then
				brain.killedLook, brain.killPos, brain.killTime = nil, nil, nil
				brain.trailFloor = -math.huge
				setState(brain, "roam")
				return true
			end
			brain.killedLook = look
		end
		-- the body turns into a corpse a few seconds after death: stay for the meal
		local deadRoot = brain.target:FindFirstChild("HumanoidRootPart") or brain.target:FindFirstChild("Torso")
		brain.killPos = deadRoot and deadRoot.Position or root.Position
		brain.killTime = now
		brain.lastHitVictim, brain.lastHitLook = nil, nil
		setTarget(brain, nil)
		if brain.state == "mimic" or brain.state == "hunt" or brain.state == "reveal" then
			setState(brain, revealed and "track" or "roam")
		end
	end
	if brain.target and canSee(brain, brain.target) then brain.lastSeen = now end

	if revealed and brain.state ~= "eat" and brain.state ~= "hunt" and brain.state ~= "reveal" and brain.state ~= "withdraw" then
		local food = nearestFood(brain, 60)
		if food then
			brain.food = food
			setState(brain, "eat")
		elseif brain.killPos and now - (brain.killTime or 0) < 9 then
			-- waiting over the body until it can be eaten (still hunting anyone who comes close)
			local near = pickLonely(brain)
			if near and (near.HumanoidRootPart.Position - root.Position).Magnitude < 25 then
				setTarget(brain, near)
				setState(brain, "hunt")
				fx(brain, "Shriek")
			else
				if (brain.killPos - root.Position).Magnitude > 4 then goTo(brain, brain.killPos, WALK_SPEED + 2) else stop(brain) end
				return true
			end
		elseif brain.killedLook then
			-- killed someone and nothing left to eat: go somewhere quiet and put their skin on
			setState(brain, "withdraw")
		end
	end

	local state = brain.state
	local targetRoot = brain.target and brain.target:FindFirstChild("HumanoidRootPart")
	local distance = targetRoot and flat(targetRoot.Position - root.Position).Magnitude or math.huge

	if now < (brain.staggerUntil or 0) then
		stop(brain)
		return true
	end

	if state == "roam" or state == "track" then
		local found = pickLonely(brain)
		if found then
			setTarget(brain, found)
			if revealed then
				setState(brain, "hunt")
				fx(brain, "Shriek")
			else
				brain.mimicSince = now
				brain.stareTime = 0
				brain.targetWasAir = false
				setState(brain, "mimic")
			end
		else
			local heard = followNoise(brain, now, revealed and speed * 0.8 or WALK_SPEED + 2)
			local point = not brain.noisePos and freshestTrailPoint(brain, 140) or nil
			if heard and (heard.HumanoidRootPart.Position - root.Position).Magnitude < 8 then
				setTarget(brain, heard)
				if revealed then
					setState(brain, "hunt")
					fx(brain, "Shriek")
				else
					brain.mimicSince = now
					brain.stareTime = 0
					brain.targetWasAir = false
					setState(brain, "mimic")
				end
			elseif brain.noisePos then
				if state ~= "track" then setState(brain, "track") end
			elseif point then
				if state ~= "track" then setState(brain, "track") end
				if goTo(brain, point.pos, revealed and speed * 0.8 or WALK_SPEED + 2) or (point.pos - root.Position).Magnitude < 4 then
					brain.trailFloor = point.t
				end
			else
				if state ~= "roam" then setState(brain, "roam") end
				if not brain.roamGoal or now > brain.roamUntil then
					brain.roamGoal = groundSpot(root.Position, 20, 55)
					brain.roamUntil = now + rng:NextNumber(6, 11)
				end
				if goTo(brain, brain.roamGoal, WALK_SPEED) then brain.roamUntil = now end
			end
		end

	elseif state == "mimic" then

		if not targetRoot or now - brain.lastSeen > 8 then
			setTarget(brain, nil)
			setState(brain, "roam")
		else
			mimicMove(brain, targetRoot, distance)

			local look = flat(targetRoot.CFrame.LookVector)
			local toMe = flat(root.Position - targetRoot.Position)
			if distance < 9 and look.Magnitude > 0.1 and toMe.Magnitude > 0.1 and look.Unit:Dot(toMe.Unit) > 0.93 then
				brain.stareTime = (brain.stareTime or 0) + 0.1
			else
				brain.stareTime = math.max(0, (brain.stareTime or 0) - 0.05)
			end
			local alone = playersNear(targetRoot.Position, 40, brain.target) == 0
			local mimicFor = now - (brain.mimicSince or now)
			-- eye contact at point blank: no more pretending, it throws itself at you
			local eyeContact = false
			local theirHead = brain.target:FindFirstChild("Head")
			if theirHead and distance < 5.5 then
				local toFace = brain.head.Position - theirHead.Position
				eyeContact = toFace.Magnitude > 0.1 and theirHead.CFrame.LookVector:Dot(toFace.Unit) > 0.86
			end
			local shouldReveal = eyeContact or brain.stareTime > 2.6
				or (alone and distance < 10 and mimicFor > 15 and rng:NextNumber() < 0.05)
				or (mimicFor > 120 and distance < 14)
			if shouldReveal then
				brain.lungeOnReveal = eyeContact
				brain.revealUntil = now + (eyeContact and 0.35 or 1.3)
				setState(brain, "reveal")
				stop(brain)
				reveal(brain)
			end
		end

	elseif state == "reveal" then
		stop(brain)
		if targetRoot then face(brain, targetRoot.Position) end
		if now > (brain.revealUntil or 0) then
			fx(brain, "Shriek")
			if brain.lungeOnReveal and targetRoot then
				-- the lunge: straight at their face, and the first swing comes at once
				local dir = flat(targetRoot.Position - root.Position)
				if dir.Magnitude > 0.1 then root.AssemblyLinearVelocity = dir.Unit * 42 + Vector3.new(0, 14, 0) end
				brain.nextSwing = 0
			end
			brain.lungeOnReveal = nil
			setState(brain, targetRoot and "hunt" or "track")
		end

	elseif state == "hunt" then
		if not targetRoot or now - brain.lastSeen > 10 then
			setState(brain, "track")
		else
			attackStep(brain, now, targetRoot, speed, "hunt", brain.data.swingCooldown or 0.95, 0.2)
			if now >= (brain.nextGrowl or 0) then
				brain.nextGrowl = now + rng:NextNumber(2.5, 4)
				fx(brain, "Growl")
			end
		end

	elseif state == "eat" then
		-- it eats the whole body, but not with an audience: anyone watching the meal is next
		local watcher = watcherOf(brain)
		if watcher then
			abortEat(brain)
			brain.killPos, brain.killTime = nil, nil
			setTarget(brain, watcher)
			fx(brain, "Shriek")
			setState(brain, "hunt")
			return true
		end
		eatStep(brain, now, function()
			brain.killPos, brain.killTime = nil, nil
			if brain.target and aliveCharacter(brain.target) then return "hunt" end
			return brain.killedLook and "withdraw" or "roam"
		end)

	elseif state == "withdraw" then
		if not brain.killedLook then
			setState(brain, "roam")
			return true
		end
		local nearest, nearestDist = nil, math.huge
		for _, character in ipairs(livingTargets()) do
			local d = (character.HumanoidRootPart.Position - root.Position).Magnitude
			if d < nearestDist then nearest, nearestDist = character, d end
		end
		local hidden = not seenByAnyone(brain)
		if hidden then
			brain.hiddenFor = (brain.hiddenFor or 0) + 0.1
		else
			brain.hiddenFor = 0
		end
		if (brain.hiddenFor or 0) > 2.5 or now - brain.stateSince > 20 then
			stop(brain)
			disguise(brain, brain.killedLook)
			brain.killedLook = nil
			brain.hiddenFor = 0
			brain.trailFloor = -math.huge
			setState(brain, "roam")
		elseif nearest then
			goTo(brain, awayPoint(brain, nearest.HumanoidRootPart.Position, 20), HUMAN_SPEED)
		else
			stop(brain)
		end
	end

	return true
end

-- ===== A-013 "The Flesh" and infection =====
local PART_KEY = {Head = "Head", Torso = "Torso", ["Left Arm"] = "LeftArm", ["Right Arm"] = "RightArm",
	["Left Leg"] = "LeftLeg", ["Right Leg"] = "RightLeg"}
local PART_NAME = {Head = "Head", Torso = "Torso", LeftArm = "Left Arm", RightArm = "Right Arm",
	LeftLeg = "Left Leg", RightLeg = "Right Leg"}
local INFECT_FALLBACK = 30
local pendingInfection = {}

local function splitList(text)
	local out = {}
	for item in string.gmatch(text or "", "[^,]+") do out[item] = true end
	return out
end

local function reviveInfected(plr, partSet, position)
	if not plr.Parent then return end
	if aliveCharacter(plr.Character) then
		plr:SetAttribute("InfectPending", nil)
		return
	end
	pendingInfection[plr] = nil
	local keys = {}
	for key in pairs(partSet) do table.insert(keys, key) end
	plr:SetAttribute("Infected", true)
	plr:SetAttribute("InfectPending", true)
	plr:SetAttribute("FleshParts", table.concat(keys, ","))
	plr:SetAttribute("InfectSpawn", position)
	plr:LoadCharacter()
end

-- killed by the flesh: the respawn menu stops working the moment you die
function onFleshKill(brain, character)
	local plr = Players:GetPlayerFromCharacter(character)
	if not plr or plr:GetAttribute("InfectPending") then return end
	plr:SetAttribute("InfectPending", true)
	local lost = {}
	for key in pairs(PART_NAME) do
		if (character:GetAttribute("Injury_" .. key) or 0) >= 3 then lost[key] = true end
	end
	local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
	local token = {}
	pendingInfection[plr] = token
	local position = root and root.Position or brain.root.Position
	brain.eatPriorityUntil = os.clock() + 25
	task.delay(INFECT_FALLBACK, function()
		-- the flesh never got to the body: bring them back anyway
		if pendingInfection[plr] == token then reviveInfected(plr, lost, position) end
	end)
end

function onCorpseEaten(brain, corpse)
	if brain.data.kind == "spidermother" then
		hatchBrood(brain)
		return
	end
	if brain.data.kind ~= "flesh" then return end
	local userId = corpse:GetAttribute("CorpseUserId")
	local plr = userId and Players:GetPlayerByUserId(userId)
	if not plr or aliveCharacter(plr.Character) then return end
	local parts = splitList(corpse:GetAttribute("LostParts"))
	for name in pairs(splitList(corpse:GetAttribute("EatenParts"))) do
		if PART_KEY[name] then parts[PART_KEY[name]] = true end
	end
	-- whatever is left of the corpse right now also counts as taken
	for _, child in ipairs(corpse:GetChildren()) do
		if child:IsA("BasePart") and PART_KEY[child.Name] then parts[PART_KEY[child.Name]] = true end
	end
	reviveInfected(plr, parts, brain.root.Position + brain.root.CFrame.LookVector * 3)
end

-- the body under the meat disappears completely, so no package mesh, layered clothing or odd body shape
-- can poke out of it (works for R6 and R15 bodies alike)
local function hideUnderShell(part)
	if part.Transparency < 1 then
		part:SetAttribute("GS_ShellHidT", part.Transparency)
		part.Transparency = 1
	end
	for _, d in ipairs(part:GetChildren()) do
		if (d:IsA("Decal") and not d:IsA("Texture")) or d:IsA("SurfaceAppearance") or d:IsA("FaceControls") then d:Destroy() end
	end
end

local function fleshShellPart(part)
	if not part or not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then return end
	local isHead = part.Name == "Head"
	local old = part:FindFirstChild("GS_FleshShell")
	if old then old:Destroy() end
	hideUnderShell(part)
	local holder = Instance.new("Folder")
	holder.Name = "GS_FleshShell"
	holder.Parent = part
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	-- a little bigger than the part it hides; thin R15 pieces get a minimum thickness
	local size = part.Size
	shell.Size = Vector3.new(math.max(size.X * 1.08, 0.5), math.max(size.Y * 1.04, 0.5), math.max(size.Z * 1.08, 0.5))
	shell.Color = FLESH_COLORS[rng:NextInteger(1, 3)]
	shell.Material = Enum.Material.SmoothPlastic
	shell.Reflectance = 0.14
	shell.CanCollide, shell.CanQuery, shell.CanTouch, shell.CastShadow, shell.Massless = false, false, false, false, true
	if isHead then
		-- a ball, not a head mesh: only real shapes show the meat texture all the way round
		shell.Shape = Enum.PartType.Ball
		local d = math.max(1.5, size.Y * 1.25)
		shell.Size = Vector3.new(d, d, d)
	end
	paintPart(shell, TEXTURES.Meat, isHead and 1.2 or 2.5)
	paintPart(shell, TEXTURES.Veins, isHead and 1.5 or 3, 0.1)
	shell.CFrame = part.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = shell
	weld.Parent = shell
	shell.Parent = holder
	local big = part.Name == "Torso" or part.Name == "UpperTorso"
	for _ = 1, big and 5 or 3 do
		local half = part.Size / 2
		if isHead then half = Vector3.new(0.45, 0.45, 0.45) end
		local offset = Vector3.new(rng:NextNumber(-half.X, half.X), rng:NextNumber(-half.Y, half.Y), rng:NextNumber(-half.Z, half.Z))
		local r = rng:NextNumber(0.3, 0.7)
		weldBlob(holder, part, CFrame.new(offset), Vector3.new(r, r, r), FLESH_COLORS[rng:NextInteger(1, #FLESH_COLORS)], 0.2, TEXTURES.Meat)
	end
end

local function fleshShell(character, key)
	fleshShellPart(character:FindFirstChild(PART_NAME[key]))
end

local function coverBody(character)
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then fleshShellPart(part) end
	end
end

-- ===== infected progression: kills make the meat stronger =====
-- stage 1 (just turned): long reach, eats remains, infects whoever it kills, sees in the dark
-- stage 2 (3 kills): 225 hp, bones never break, a lost limb grows back every 15 seconds
-- stage 3 (5 kills): tentacles (R), A-013's eyes and teeth, sees through fog, sees survivors' tracks and blood
-- They move like A-013 does (a little slower than a survivor), whatever the stage.
local INFECT_SPEED = {15, 15, 15}
local INFECT_REACH = {9, 10, 11.5}
local STAGE_KILLS = {3, 5}
local function infectStage(character)
	return character and character:GetAttribute("InfectStage") or 1
end

-- stage 3: the same white pinprick eyes in black pits and the torn toothy maw as A-013, on the meat head
local function addInfectedFace(character)
	local head = character:FindFirstChild("Head")
	if not head or head:FindFirstChild("GS_FleshFace") then return end
	local holder = Instance.new("Folder")
	holder.Name = "GS_FleshFace"
	holder.Parent = head
	-- the meat shell on the head is a 1.5 ball: its front surface sits about 0.7 in front of the centre
	local z = -0.66
	addEye(holder, head, CFrame.new(-0.24, 0.16, z), 0.28)
	addEye(holder, head, CFrame.new(0.26, 0.12, z), 0.32)
	addEye(holder, head, CFrame.new(0.05, 0.4, z + 0.08), 0.17)
	weldBlob(holder, head, CFrame.new(0, -0.22, z + 0.02), Vector3.new(0.36, 0.64, 0.3), Color3.fromRGB(16, 0, 2), 0.35)
	for i = 1, 7 do
		local y = -0.5 + i * 0.075
		for _, side in ipairs({-1, 1}) do
			weldBlob(holder, head, CFrame.new(side * 0.13, y, z - 0.1) * CFrame.Angles(0, 0, side * math.rad(80)),
				Vector3.new(0.05, 0.14, 0.05), Color3.fromRGB(226, 214, 186), 0.05)
		end
	end
	-- and eyes where eyes should not be
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if torso then
		for _ = 1, 3 do
			addEye(holder, torso, CFrame.new(rng:NextNumber(-0.7, 0.7), rng:NextNumber(-0.6, 0.7), -torso.Size.Z / 2 - 0.08),
				rng:NextNumber(0.14, 0.22))
		end
	end
end

local function removeInfectedFace(character)
	local head = character:FindFirstChild("Head")
	local face = head and head:FindFirstChild("GS_FleshFace")
	if face then face:Destroy() end
end

local function applyInfectStage(plr, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local kills = plr:GetAttribute("InfectKills") or 0
	local stage = kills >= STAGE_KILLS[2] and 3 or (kills >= STAGE_KILLS[1] and 2 or 1)
	local old = character:GetAttribute("InfectStage") or 0
	character:SetAttribute("InfectStage", stage)
	humanoid.WalkSpeed = INFECT_SPEED[stage]
	character:SetAttribute("SpeedCap", math.ceil(INFECT_SPEED[stage] * 1.45))
	-- every infected sees in the dark; from stage 2 the fog thins out too (client: InfectedSenses)
	character:SetAttribute("InfectVision", true)
	if stage >= 3 then
		if not character:FindFirstChild("GS_GrabTarget") then
			local grab = Instance.new("ObjectValue")
			grab.Name = "GS_GrabTarget"
			grab.Parent = character
		end
		addInfectedFace(character)
	else
		local grab = character:FindFirstChild("GS_GrabTarget")
		if grab then grab:Destroy() end
		removeInfectedFace(character)
	end
	if stage >= 2 and old < 2 then
		humanoid.MaxHealth = 225
		humanoid.Health = math.min(225, humanoid.Health + 75)
	elseif stage < 2 and old >= 2 then
		humanoid.MaxHealth = 150
		humanoid.Health = math.min(humanoid.Health, 150)
	end
	if stage > old and old > 0 then
		fxRemote:FireAllClients(character, "Shriek")
	end
end

local function infectCharacter(plr, character)
	local spawnAt = plr:GetAttribute("InfectSpawn")
	character:SetAttribute("Infected", true)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then return end
	if typeof(spawnAt) == "Vector3" then
		character:SetAttribute("AC_TeleportAt", serverNow())
		character:PivotTo(CFrame.new(spawnAt + Vector3.new(0, 3, 0)))
	end
	if not plr:HasAppearanceLoaded() then
		local done = false
		local conn = plr.CharacterAppearanceLoaded:Connect(function() done = true end)
		local waited = 0
		while not done and waited < 5 do waited += task.wait(0.1) end
		conn:Disconnect()
	end
	if plr.Character ~= character then return end
	humanoid.MaxHealth = 150
	humanoid.Health = 150
	-- the infected are meat from head to toe: hair, hats, layered clothing and body-package meshes go,
	-- the body underneath turns invisible and every part (R6 or R15) gets a flesh shell
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") or item:IsA("CharacterMesh") or item:IsA("ShirtGraphic") then item:Destroy() end
	end
	coverBody(character)
	-- anything the avatar loader adds later is covered too
	character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") or child:IsA("CharacterMesh") then
			task.defer(function() if child.Parent then child:Destroy() end end)
		elseif child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and not child:FindFirstChild("GS_FleshShell") then
			task.defer(fleshShellPart, child)
		end
	end)
	-- (no INFECTED label over the head: you have to recognise them by the meat)
	plr:SetAttribute("InfectPending", nil)
	plr:SetAttribute("InfectSpawn", nil)
	-- (an admin can hand out a stage: it arrives as InfectStartKills)
	plr:SetAttribute("InfectKills", plr:GetAttribute("InfectStartKills") or 0)
	plr:SetAttribute("InfectStartKills", nil)
	applyInfectStage(plr, character)

	-- stage 2+ bones don't break: a fracture is only ever a wound
	for key in pairs(PART_NAME) do
		if key ~= "Head" then
			character:GetAttributeChangedSignal("Injury_" .. key):Connect(function()
				if (character:GetAttribute("InfectStage") or 1) >= 2 and character:GetAttribute("Injury_" .. key) == 2 then
					character:SetAttribute("Injury_" .. key, 1)
				end
			end)
		end
	end

	-- the flesh mends itself: every injury closes 30s after it happened, torn limbs grow back as meat,
	-- and the body regains 2 hp every 10 seconds. Stage 3 regrows a lost limb every 15s, one at a time.
	task.spawn(function()
		local since = {}
		local ticks = 0
		local lastRegrow = -math.huge
		while plr.Character == character and character.Parent and humanoid.Health > 0 do
			task.wait(1)
			ticks += 1
			local stage = character:GetAttribute("InfectStage") or 1
			-- (cut off from the Mother the flesh does not mend at all)
			if ticks % 10 == 0 and character:GetAttribute("GS_Boss") == "near" then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (stage >= 2 and 4 or 2))
			end
			local anyInjury = false
			local regrew = false
			for key in pairs(PART_NAME) do
				local level = character:GetAttribute("Injury_" .. key) or 0
				if level <= 0 then
					since[key] = nil
				else
					anyInjury = true
					since[key] = since[key] or os.clock()
					local limb = key ~= "Head" and key ~= "Torso"
					if stage >= 2 and level >= 3 and limb then
						if not regrew and os.clock() - since[key] >= 15 and os.clock() - lastRegrow >= 15 then
							regrew = true
							lastRegrow = os.clock()
							since[key] = nil
							local ok = FallDamageController.RestorePart(character, key)
							if ok then
								fleshShell(character, key)
								-- clients play the limb growing back out of the stump
								character:SetAttribute("GS_Regrow_" .. key, serverNow())
							end
						end
					elseif os.clock() - since[key] >= 30 then
						since[key] = nil
						if level >= 3 and limb then
							local ok = FallDamageController.RestorePart(character, key)
							if ok then
								fleshShell(character, key)
								character:SetAttribute("GS_Regrow_" .. key, serverNow())
							end
						else
							character:SetAttribute("Injury_" .. key, 0)
						end
					end
				end
			end
			if not anyInjury and (character:GetAttribute("Bleeding") or 0) > 0 then
				FallDamageController.StopBleeding(character)
			end
		end
	end)
	humanoid.Died:Connect(function()
		-- the infection dies with the body
		if plr.Character == character then
			plr:SetAttribute("Infected", nil)
			plr:SetAttribute("FleshParts", nil)
			plr:SetAttribute("InfectKills", nil)
		end
	end)
end

local function onPlayerCharacter(plr, character)
	if plr:GetAttribute("Infected") and plr:GetAttribute("InfectSpawn") then
		infectCharacter(plr, character)
	else
		plr:SetAttribute("Infected", nil)
		plr:SetAttribute("FleshParts", nil)
		plr:SetAttribute("InfectPending", nil)
		plr:SetAttribute("InfectKills", nil)
		pendingInfection[plr] = nil
	end
end

-- someone the infected killed (or whose body they ate) comes back as one of them
local INFECTED_REVIVE_DELAY = 7
local function infectVictim(victim, position)
	local plr = Players:GetPlayerFromCharacter(victim)
	if not plr or plr:GetAttribute("InfectPending") then return end
	plr:SetAttribute("InfectPending", true)
	local lost = {}
	for key in pairs(PART_NAME) do
		if (victim:GetAttribute("Injury_" .. key) or 0) >= 3 then lost[key] = true end
	end
	local token = {}
	pendingInfection[plr] = token
	task.delay(INFECTED_REVIVE_DELAY, function()
		if pendingInfection[plr] == token then reviveInfected(plr, lost, position) end
	end)
end

local function countInfectedKill(killer)
	local plr = Players:GetPlayerFromCharacter(killer)
	if not plr or not isInfected(killer) then return end
	plr:SetAttribute("InfectKills", (plr:GetAttribute("InfectKills") or 0) + 1)
	applyInfectStage(plr, killer)
end

-- ===== the Mother: the infected are bound to A-013 =====
-- Stay within BOSS_RADIUS of the nearest A-013 and nothing happens. Stray further, or have no Mother alive at
-- all, and the flesh weakens: slower, half-strength hits, no mending, and it withers down to 30% health.
-- Clients mark the Mother for the infected (GS_BossRef) and show the state (GS_Boss = near / far / none).
local BOSS_RADIUS = 90
local BOSS_WITHER = 1 -- hp per second while cut off
local BOSS_WITHER_FLOOR = 0.3
local BOSS_SLOW = 0.75
task.spawn(function()
	while true do
		task.wait(1)
		local mothers = {}
		for model, brain in pairs(monsters) do
			if brain.data.kind == "flesh" and model.Parent then table.insert(mothers, brain) end
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			local character = plr.Character
			if character and isInfected(character) and aliveCharacter(character) then
				local root = character.HumanoidRootPart
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local nearest, dist = nil, math.huge
				for _, mother in ipairs(mothers) do
					local d = (mother.root.Position - root.Position).Magnitude
					if d < dist then nearest, dist = mother, d end
				end
				local state = not nearest and "none" or (dist <= BOSS_RADIUS and "near" or "far")
				character:SetAttribute("GS_Boss", state)
				character:SetAttribute("GS_BossDist", nearest and math.floor(dist) or -1)
				local ref = character:FindFirstChild("GS_BossRef")
				if not ref then
					ref = Instance.new("ObjectValue")
					ref.Name = "GS_BossRef"
					ref.Parent = character
				end
				ref.Value = nearest and nearest.model or nil
				local weak = state ~= "near"
				local speed = INFECT_SPEED[infectStage(character)] * (weak and BOSS_SLOW or 1)
				-- (0 means ragdolled / paralysed: leave that alone)
				if humanoid.WalkSpeed > 0 and math.abs(humanoid.WalkSpeed - speed) > 0.01 then humanoid.WalkSpeed = speed end
				if weak and humanoid.Health > humanoid.MaxHealth * BOSS_WITHER_FLOOR then
					humanoid.Health = math.max(humanoid.MaxHealth * BOSS_WITHER_FLOOR, humanoid.Health - BOSS_WITHER)
				end
			end
		end
	end
end)

local function watchPlayer(plr)
	plr.CharacterAdded:Connect(function(character) onPlayerCharacter(plr, character) end)
end
for _, plr in ipairs(Players:GetPlayers()) do watchPlayer(plr) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(plr) pendingInfection[plr] = nil end)

-- tentacles: lash out, catch, ragdoll and reel the victim in. Clients draw the tentacles.
local GRAB_REACH = 26
function tentacleGrab(brain, victim)
	local now = os.clock()
	local model = brain.model
	brain.nextGrab = now + rng:NextNumber(7, 11)
	brain.grabUntil = now + 1.6
	local value = model:FindFirstChild("GS_GrabTarget")
	if value then value.Value = victim end
	model:SetAttribute("GS_GrabHit", false)
	model:SetAttribute("GS_GrabAt", serverNow())
	fx(brain, "Shriek")
	task.delay(0.35, function()
		local vr = victim:FindFirstChild("HumanoidRootPart")
		if not model.Parent or not aliveCharacter(victim) or not vr then return end
		if (vr.Position - brain.root.Position).Magnitude > GRAB_REACH or not canSee(brain, victim) then return end
		model:SetAttribute("GS_GrabHit", true)
		fx(brain, "Hit")
		makeNoise(victim, 60, 1.5)
		victim:SetAttribute("AC_TeleportAt", serverNow())
		FallDamageController.Ragdoll(victim, 2.4, 0.55)
		local torso = victim:FindFirstChild("Torso") or vr
		local started = os.clock()
		while os.clock() - started < 1 and model.Parent and aliveCharacter(victim) do
			local offset = brain.root.Position + brain.root.CFrame.LookVector * 3 - torso.Position
			if offset.Magnitude < 3.5 then break end
			local pull = offset.Unit * math.min(offset.Magnitude * 3.2, 48) + Vector3.new(0, 6, 0)
			for _, part in ipairs(victim:GetChildren()) do
				if part:IsA("BasePart") and not part.Anchored then part.AssemblyLinearVelocity = pull end
			end
			task.wait(0.05)
		end
		victim:SetAttribute("AC_TeleportAt", serverNow())
	end)
	task.delay(1.6, function()
		if value and value.Value == victim then value.Value = nil end
	end)
end

local function thinkFlesh(brain)
	local now = os.clock()
	local model = brain.model
	if not model.Parent then return false end
	local root = brain.root
	local speed = HUMAN_SPEED * (brain.data.speedMultiplier or 0.95)

	if brain.target and not aliveCharacter(brain.target) or (brain.target and isInfected(brain.target)) then
		setTarget(brain, nil)
		if brain.state == "chase" then setState(brain, "roam") end
	end
	if brain.target and canSee(brain, brain.target) then brain.lastSeen = now end
	if now < (brain.staggerUntil or 0) then
		stop(brain)
		return true
	end

	local targetRoot = brain.target and brain.target:FindFirstChild("HumanoidRootPart")
	local distance = targetRoot and flat(targetRoot.Position - root.Position).Magnitude or math.huge
	if brain.state ~= "eat" and (distance > 35 or now < (brain.eatPriorityUntil or 0)) then
		local food = nearestFood(brain, now < (brain.eatPriorityUntil or 0) and 120 or 80)
		if food then
			brain.food = food
			setState(brain, "eat")
		end
	end

	local state = brain.state
	if state == "roam" or state == "track" then
		local found = pickTarget(brain)
		if found then
			setTarget(brain, found)
			setState(brain, "chase")
			fx(brain, "Shriek")
		else
			local heard = followNoise(brain, now, WALK_SPEED + 3)
			local point = not brain.noisePos and freshestTrailPoint(brain, 160) or nil
			if heard and (heard.HumanoidRootPart.Position - root.Position).Magnitude < 10 then
				setTarget(brain, heard)
				setState(brain, "chase")
				fx(brain, "Shriek")
			elseif brain.noisePos then
				if state ~= "track" then setState(brain, "track") end
			elseif point then
				if state ~= "track" then setState(brain, "track") end
				if goTo(brain, point.pos, WALK_SPEED + 2) or (point.pos - root.Position).Magnitude < 4 then
					brain.trailFloor = point.t
				end
			else
				if state ~= "roam" then setState(brain, "roam") end
				if not brain.roamGoal or now > brain.roamUntil then
					brain.roamGoal = groundSpot(root.Position, 20, 55)
					brain.roamUntil = now + rng:NextNumber(6, 11)
				end
				if goTo(brain, brain.roamGoal, WALK_SPEED * 0.8) then brain.roamUntil = now end
			end
		end
	elseif state == "chase" then
		if not targetRoot or now - brain.lastSeen > 12 then
			setState(brain, "track")
		else
			local grabbing = brain.grabUntil and now < brain.grabUntil
			if not grabbing and distance > 7 and distance < 24 and now >= (brain.nextGrab or 0)
				and not brain.target:GetAttribute("Ragdolled") and canSee(brain, brain.target) then
				tentacleGrab(brain, brain.target)
			elseif grabbing then
				stop(brain)
				face(brain, targetRoot.Position)
			else
				attackStep(brain, now, targetRoot, speed, "chase", brain.data.swingCooldown or 1.3, 0.32)
			end
		end
	elseif state == "eat" then
		eatStep(brain, now, function()
			if brain.target and aliveCharacter(brain.target) then return "chase" end
			return "roam"
		end)
	end

	if now >= (brain.nextSound or 0) then
		brain.nextSound = now + rng:NextNumber(3, 7)
		fx(brain, brain.state == "chase" and "Growl" or "Ambient")
	end
	return true
end

-- ===== C-207 "The Listener": blind, hunts by sound =====
local function thinkListener(brain)
	local now = os.clock()
	local model = brain.model
	if not model.Parent then return false end
	local root = brain.root
	if brain.target and (not aliveCharacter(brain.target) or isInfected(brain.target)) then setTarget(brain, nil) end
	if now < (brain.staggerUntil or 0) then
		stop(brain)
		return true
	end

	local heard, heardPos = hear(brain)
	if heard then
		brain.noisePos = heardPos
		brain.lastHeard = now
		if brain.target ~= heard then setTarget(brain, heard) end
	end
	local targetRoot = brain.target and brain.target:FindFirstChild("HumanoidRootPart")
	local distance = targetRoot and flat(targetRoot.Position - root.Position).Magnitude or math.huge
	local state = brain.state

	if state == "roam" then
		if heard then
			setState(brain, distance < 14 and "hunt" or "investigate")
			fx(brain, "Growl")
		else
			if not brain.roamGoal or now > brain.roamUntil then
				brain.roamGoal = groundSpot(root.Position, 15, 45)
				brain.roamUntil = now + rng:NextNumber(7, 13)
			end
			if goTo(brain, brain.roamGoal, WALK_SPEED * 0.6) then brain.roamUntil = now end
		end
	elseif state == "investigate" then
		if heard and distance < 14 then
			setState(brain, "hunt")
		elseif not brain.noisePos then
			setState(brain, "roam")
		else
			local arrived = goTo(brain, brain.noisePos, HUMAN_SPEED * 1.1)
			if arrived or flat(brain.noisePos - root.Position).Magnitude < 4 then setState(brain, "listen") end
		end
	elseif state == "hunt" then
		if not targetRoot then
			setState(brain, "listen")
		elseif now - (brain.lastHeard or 0) > 1.5 then
			-- they froze: it can't find them any more
			setState(brain, "listen")
		else
			attackStep(brain, now, targetRoot, HUMAN_SPEED * (brain.data.speedMultiplier or 1.25), "hunt", brain.data.swingCooldown or 1, 0.22)
		end
	elseif state == "listen" then
		stop(brain)
		if brain.noisePos then face(brain, brain.noisePos) end
		if heard then
			setState(brain, distance < 14 and "hunt" or "investigate")
		elseif now - brain.stateSince > rng:NextNumber(4, 6) then
			brain.noisePos = nil
			setTarget(brain, nil)
			setState(brain, "roam")
		end
	end

	if now >= (brain.nextSound or 0) then
		brain.nextSound = now + rng:NextNumber(4, 9)
		if brain.state ~= "hunt" then fx(brain, "Ambient") end
	end
	return true
end

-- players hitting players: the infected hunt survivors, survivors fight back
local function strikeCharacter(striker, victim)
	local infected = isInfected(striker)
	local stage = infected and infectStage(striker) or 0
	local fake = {
		model = striker,
		data = {kind = "player", deathCause = infected and "INFECTED" or "BEATEN", damagePerLevel = 3,
			-- far from the Mother an infected hits at half strength
			damageBase = (infected and striker:GetAttribute("GS_Boss") ~= "near") and 2 or 4 + stage},
	}
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	local wasAlive = humanoid and humanoid.Health > 0
	local root = victim:FindFirstChild("HumanoidRootPart") or victim:FindFirstChild("Torso")
	local position = root and root.Position
	hitVictim(fake, victim)
	if infected and wasAlive then
		task.delay(0.1, function()
			if humanoid.Health > 0 then return end
			countInfectedKill(striker)
			if Players:GetPlayerFromCharacter(victim) and not isInfected(victim) and position then
				infectVictim(victim, position)
			end
		end)
	end
end

-- a survivor's punch doesn't wound anyone: it shoves them back a few steps
local SHOVE_SPEED = 44
local function shoveCharacter(striker, victim)
	local root = victim:FindFirstChild("HumanoidRootPart")
	local from = striker:FindFirstChild("HumanoidRootPart")
	if not root or not from then return end
	local dir = flat(root.Position - from.Position)
	if dir.Magnitude < 0.1 then dir = flat(from.CFrame.LookVector) end
	if dir.Magnitude < 0.1 then return end
	local push = dir.Unit * SHOVE_SPEED + Vector3.new(0, 16, 0)
	victim:SetAttribute("AC_TeleportAt", serverNow()) -- the anticheat lets the sudden slide through
	fxRemote:FireAllClients(victim, "Shoved")
	makeNoise(victim, 30, 1)
	local plr = Players:GetPlayerFromCharacter(victim)
	if plr then
		fxRemote:FireClient(plr, victim, "Shove", push) -- players move their own bodies
	else
		root.AssemblyLinearVelocity = push
	end
end

-- ===== the infected eat remains: walk up to a body or a torn-off limb and hold E =====
-- Every piece of meat lying around carries a ProximityPrompt (custom style, drawn by the EatPrompt client
-- script, shown only to the infected). One completed hold = one piece eaten.
do -- eating and the infected grab (in a block: the script is close to Luau's 200-local limit)
	local EAT_HOLD = 1.1
	local EAT_REACH = 11
	local eatPrompts = {}

	local function consumePiece(character, food, piece)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local isCorpse = isCorpseModel(food)
		if isCorpse then
			local list = food:GetAttribute("EatenParts")
			food:SetAttribute("EatenParts", (list and list ~= "" and (list .. ",") or "") .. piece.Name)
		end
		local where = piece.Position
		-- what is eaten leaves its bones behind
		if isCorpse then
			boneHolders[food] = Skeletons.FromPart(piece, boneHolders[food])
		else
			Skeletons.FromPart(piece)
		end
		fxRemote:FireAllClients(character, "Bite")
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (isCorpse and 25 or 15))
		if (character:GetAttribute("Bleeding") or 0) > 0 then FallDamageController.StopBleeding(character) end
		if not foodPiece(food) or not isCorpse then
			-- a player's body picked clean: they get up as one of us
			if isCorpse then
				local userId = food:GetAttribute("CorpseUserId")
				local plr = userId and Players:GetPlayerByUserId(userId)
				if plr and not aliveCharacter(plr.Character) and not plr:GetAttribute("InfectPending") then
					plr:SetAttribute("InfectPending", true)
					local root = character:FindFirstChild("HumanoidRootPart")
					reviveInfected(plr, splitList(food:GetAttribute("LostParts")), root and root.Position + root.CFrame.LookVector * 3 or where)
				end
			end
			if food.Parent then food:Destroy() end
		end
	end

	local function canEat(plr, food)
		local character = plr.Character
		if not aliveCharacter(character) or not isInfected(character) or character:GetAttribute("Ragdolled") then return nil end
		-- a creature already chewing on it keeps it
		if not food.Parent or food:GetAttribute("GS_BeingEaten") then return nil end
		local piece = foodPiece(food)
		local root = character:FindFirstChild("HumanoidRootPart")
		if not piece or not root or (piece.Position - root.Position).Magnitude > EAT_REACH then return nil end
		return character, piece
	end

	local function placeEatPrompt(food)
		local piece = foodPiece(food)
		local prompt = eatPrompts[food]
		if not piece then
			if prompt then prompt:Destroy() end
			eatPrompts[food] = nil
			return
		end
		-- (a prompt goes down with the piece it sat on; the next piece gets a fresh one)
		if not prompt or not prompt.Parent then
			if prompt then pcall(function() prompt:Destroy() end) end
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "GS_EatPrompt"
			prompt.ActionText = "Eat"
			local owner = food:GetAttribute("CorpseUserId") and Players:GetPlayerByUserId(food:GetAttribute("CorpseUserId"))
			prompt.ObjectText = isCorpseModel(food) and (owner and (owner.DisplayName .. "'s body") or "A body") or "Torn-off meat"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
			prompt.HoldDuration = EAT_HOLD
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt:SetAttribute("GS_Eat", true)
			prompt.PromptButtonHoldBegan:Connect(function(plr)
				local character = canEat(plr, food)
				if not character then return end
				-- crouch over it and tear at it while the key is held
				character:SetAttribute("GS_EatServer", serverNow() + EAT_HOLD + 0.3)
				fxRemote:FireAllClients(character, "Chew")
			end)
			prompt.PromptButtonHoldEnded:Connect(function(plr)
				local character = plr.Character
				if character and (character:GetAttribute("GS_EatServer") or 0) > serverNow() + 0.35 then
					character:SetAttribute("GS_EatServer", nil)
				end
			end)
			prompt.Triggered:Connect(function(plr)
				local character, piece = canEat(plr, food)
				if not character then return end
				character:SetAttribute("GS_EatServer", serverNow() + 0.3)
				consumePiece(character, food, piece)
				if food.Parent then placeEatPrompt(food) end
			end)
			eatPrompts[food] = prompt
		end
		-- a body keeps its prompt on the torso (the middle of it) until the torso itself is all that is left
		local torso = food:FindFirstChild("Torso")
		local anchor = (torso and torso:IsA("BasePart")) and torso or piece
		if prompt.Parent ~= anchor then prompt.Parent = anchor end
	end

	local function anyInfectedAlive()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character and isInfected(plr.Character) and aliveCharacter(plr.Character) then return true end
		end
		return false
	end

	-- prompts exist only while someone infected is walking around
	task.spawn(function()
		while true do
			task.wait(0.5)
			local wanted = anyInfectedAlive()
			local seen = {}
			if wanted then
				for _, folderName in ipairs({"SeveredLimbs", "Corpses"}) do
					local foodFolder = workspace:FindFirstChild(folderName)
					for _, model in ipairs(foodFolder and foodFolder:GetChildren() or {}) do
						if model:IsA("Model") then
							seen[model] = true
							placeEatPrompt(model)
						end
					end
				end
			end
			for food, prompt in pairs(eatPrompts) do
				if not seen[food] or not food.Parent then
					prompt:Destroy()
					eatPrompts[food] = nil
				end
			end
		end
	end)

	-- stage 2+: the tentacles lash out at a survivor further away and drag them in
	local PLAYER_GRAB_REACH = 22
	local playerGrabReady = {}
	local function infectedGrab(character, victim)
		local now = os.clock()
		if now < (playerGrabReady[character] or 0) then return false end
		local root = character:FindFirstChild("HumanoidRootPart")
		local vr = victim:FindFirstChild("HumanoidRootPart")
		local value = character:FindFirstChild("GS_GrabTarget")
		if not root or not vr or not value then return false end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {character, victim, folder}
		if workspace:Raycast(root.Position, vr.Position - root.Position, params) then return false end
		playerGrabReady[character] = now + 7
		character:SetAttribute("GS_GrabReadyAt", serverNow() + 7)
		character:SetAttribute("GS_GrabPoint", nil)
		value.Value = victim
		character:SetAttribute("GS_GrabHit", false)
		character:SetAttribute("GS_GrabAt", serverNow())
		fxRemote:FireAllClients(character, "Shriek")
		task.delay(0.35, function()
			if not aliveCharacter(victim) or not aliveCharacter(character) then return end
			if (vr.Position - root.Position).Magnitude > PLAYER_GRAB_REACH + 2 then return end
			character:SetAttribute("GS_GrabHit", true)
			fxRemote:FireAllClients(character, "Hit")
			makeNoise(victim, 60, 1.5)
			victim:SetAttribute("AC_TeleportAt", serverNow())
			FallDamageController.Ragdoll(victim, 2, 0.5)
			local torso = victim:FindFirstChild("Torso") or vr
			local started = os.clock()
			while os.clock() - started < 1 and aliveCharacter(victim) and aliveCharacter(character) do
				local offset = root.Position + root.CFrame.LookVector * 3 - torso.Position
				if offset.Magnitude < 3.5 then break end
				local pull = offset.Unit * math.min(offset.Magnitude * 3.2, 48) + Vector3.new(0, 6, 0)
				for _, part in ipairs(victim:GetChildren()) do
					if part:IsA("BasePart") and not part.Anchored then part.AssemblyLinearVelocity = pull end
				end
				task.wait(0.05)
			end
			victim:SetAttribute("AC_TeleportAt", serverNow())
		end)
		task.delay(1.6, function()
			if value.Parent and value.Value == victim then value.Value = nil end
		end)
		return true
	end
	Players.PlayerRemoving:Connect(function(plr)
		if plr.Character then playerGrabReady[plr.Character] = nil end
	end)

	-- R (stage 2+): throw the tentacles at whoever is in front and in reach; a miss still lashes out
	local grabRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_InfectedGrab")
	local GRAB_CONE = 0.35
	grabRemote.OnServerEvent:Connect(function(player)
		local character = player.Character
		if not aliveCharacter(character) or not isInfected(character) or infectStage(character) < 3 then return end
		if character:GetAttribute("Ragdolled") or (character:GetAttribute("GS_EatServer") or 0) > serverNow() then return end
		local now = os.clock()
		if now < (playerGrabReady[character] or 0) then return end
		local root = character.HumanoidRootPart
		local look = flat(root.CFrame.LookVector).Unit
		local best, bestScore = nil, -math.huge
		for _, plr in ipairs(Players:GetPlayers()) do
			local other = plr.Character
			if other ~= character and aliveCharacter(other) and not isInfected(other) and not other:GetAttribute("Ragdolled") then
				local offset = other.HumanoidRootPart.Position - root.Position
				local d = offset.Magnitude
				local dir = flat(offset)
				if d <= PLAYER_GRAB_REACH and dir.Magnitude > 0.1 then
					local dot = look:Dot(dir.Unit)
					-- closest to the centre of the aim wins, nearer breaks ties
					local score = dot * 2 - d / PLAYER_GRAB_REACH
					if dot >= GRAB_CONE and score > bestScore then best, bestScore = other, score end
				end
			end
		end
		if best and infectedGrab(character, best) then return end
		-- missed: the tentacles whip out at the air in front and come back
		playerGrabReady[character] = now + 1.5
		character:SetAttribute("GS_GrabReadyAt", serverNow() + 1.5)
		local value = character:FindFirstChild("GS_GrabTarget")
		if value then value.Value = nil end
		character:SetAttribute("GS_GrabPoint", root.Position + look * (PLAYER_GRAB_REACH * 0.8) + Vector3.new(0, 1, 0))
		character:SetAttribute("GS_GrabHit", false)
		character:SetAttribute("GS_GrabAt", serverNow())
		fxRemote:FireAllClients(character, "Shriek")
	end)
end

-- ===== E-116 "The Weaver": webs, point-blank bites, low climbing =====
local webs = {}
local breakWeb, spinWeb
do -- (in a block: the script is close to Luau's 200-local limit)
	local webFolder = ensure(workspace, "Folder", "SpiderWebs")
	local WEB_MAX = 30
	local WEB_LIFE = 360
	local WEB_HOLD = 5 -- ragdolled and stuck this long
	local WEB_SLOW = 3 -- then the threads still cling: slowed for this long
	local WEB_COLOR = Color3.fromRGB(222, 222, 216)

	local function webThread(parent, a, b, width)
		local length = (b - a).Magnitude
		if length < 0.05 then return end
		local part = Instance.new("Part")
		part.Name = "Thread"
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.SmoothPlastic
		part.Color = WEB_COLOR
		part.Transparency = 0.3
		part.Reflectance = 0.15
		part.Size = Vector3.new(length, width, width)
		part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		part.Parent = parent
	end

	-- a round web in the plane of cf (its X and Y axes), w wide and h tall. tight = the rim touches the edges
	-- (a web strung across a passage); otherwise the rim is a little ragged
	local function buildWeb(cf, w, h, tight)
		local model = Instance.new("Model")
		model.Name = "Web"
		local spokes = 12
		local rim = {}
		for i = 1, spokes do
			local a = (i / spokes) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
			local reach = tight and 1 or rng:NextNumber(0.88, 1)
			rim[i] = Vector3.new(math.cos(a) * w / 2 * reach, math.sin(a) * h / 2 * reach, 0)
			webThread(model, cf.Position, cf:PointToWorldSpace(rim[i]), 0.07)
		end
		for _, f in ipairs({0.18, 0.36, 0.54, 0.72, 0.88, 1}) do
			for i = 1, spokes do
				local j = i % spokes + 1
				webThread(model, cf:PointToWorldSpace(rim[i] * f), cf:PointToWorldSpace(rim[j] * f), f == 1 and 0.07 or 0.05)
			end
		end
		local trigger = Instance.new("Part")
		trigger.Name = "Trigger"
		trigger.Anchored, trigger.CanCollide, trigger.CanQuery, trigger.CanTouch = true, false, false, false
		trigger.Transparency = 1
		trigger.Size = Vector3.new(w, h, 1.6)
		trigger.CFrame = cf
		trigger.Parent = model
		model.PrimaryPart = trigger
		model.Parent = webFolder
		local entry = {model = model, trigger = trigger, expires = os.clock() + WEB_LIFE}
		table.insert(webs, entry)
		while #webs > WEB_MAX do
			local old = table.remove(webs, 1)
			if old.model.Parent then old.model:Destroy() end
		end
		return entry
	end

	function breakWeb(entry)
		local index = table.find(webs, entry)
		if index then table.remove(webs, index) end
		if entry.model.Parent then entry.model:Destroy() end
	end

	-- the floor under a whole round web: flat, solid and with nothing sticking up through it. Returns the floor point.
	local function flatFloor(centre, radius, params)
		local mid = workspace:Raycast(centre + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), params)
		if not mid or mid.Normal.Y < 0.92 then return nil end
		local y = mid.Position.Y
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			for _, f in ipairs({0.55, 1}) do
				local p = Vector3.new(mid.Position.X + math.cos(a) * radius * f, y, mid.Position.Z + math.sin(a) * radius * f)
				local hit = workspace:Raycast(p + Vector3.new(0, 2.5, 0), Vector3.new(0, -3.3, 0), params)
				if not hit or math.abs(hit.Position.Y - y) > 0.25 then return nil end
			end
		end
		return mid.Position
	end

	-- spin across a passage if there is one, otherwise flat on a patch of open floor
	function spinWeb(brain)
		local root = brain.root
		local params = getMoveParams()
		local ground = groundAt(root.Position, 12)
		if not ground then return end
		local look = flat(root.CFrame.LookVector)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
		local side = Vector3.new(-look.Z, 0, look.X)
		local mid = ground + Vector3.new(0, 2.6, 0)
		local left = workspace:Raycast(mid, -side * 13, params)
		local right = workspace:Raycast(mid, side * 13, params)
		if left and right and math.abs(left.Normal.Y) < 0.3 and math.abs(right.Normal.Y) < 0.3 then
			local width = (right.Position - left.Position).Magnitude
			if width >= 4 and width <= 24 then
				local across = flat(right.Position - left.Position).Unit
				local centre = (left.Position + right.Position) / 2
				local floor = workspace:Raycast(Vector3.new(centre.X, mid.Y, centre.Z), Vector3.new(0, -6, 0), params)
				if floor and floor.Normal.Y > 0.9 then
					local ceiling = workspace:Raycast(Vector3.new(centre.X, mid.Y, centre.Z), Vector3.new(0, 11, 0), params)
					local height = math.clamp(ceiling and (ceiling.Position.Y - floor.Position.Y - 0.3) or 10, 5, 11)
					-- the plane runs wall to wall, standing straight up, with its lowest threads just off the floor
					local c = Vector3.new(centre.X, floor.Position.Y + 0.25 + height / 2, centre.Z)
					buildWeb(CFrame.fromMatrix(c, across, Vector3.yAxis), width, height, true)
					return
				end
			end
		end
		-- on the floor: try a few spots around the spider for one where the whole web lies flat
		for _, size in ipairs({rng:NextNumber(9, 12), 7}) do
			for attempt = 1, 7 do
				local offset = attempt == 1 and -look * 3
					or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * rng:NextNumber(2, 9)
				local spot = flatFloor(ground + offset, size / 2, params)
				if spot then
					-- spin it about the vertical first, then lay it down: the plane stays perfectly level
					buildWeb(CFrame.new(spot + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
						* CFrame.Angles(math.rad(-90), 0, 0), size, size)
					return
				end
			end
		end
		brain.nextWeb = os.clock() + 4 -- nowhere good here: look again soon
	end

	-- anything alive that walks into a web sticks for a moment, and every spider nearby feels it
	local webOverlap = OverlapParams.new()
	webOverlap.FilterType = Enum.RaycastFilterType.Include
	task.spawn(function()
		while true do
			task.wait(0.15)
			if #webs > 0 then
				local bodies = {}
				for _, plr in ipairs(Players:GetPlayers()) do
					if aliveCharacter(plr.Character) then table.insert(bodies, plr.Character) end
				end
				webOverlap.FilterDescendantsInstances = bodies
				local now = os.clock()
				for i = #webs, 1, -1 do
					local entry = webs[i]
					if not entry.model.Parent or now > entry.expires then
						table.remove(webs, i)
						if entry.model.Parent then entry.model:Destroy() end
					elseif not entry.tearing and #bodies > 0 then
						for _, part in ipairs(workspace:GetPartBoundsInBox(entry.trigger.CFrame, entry.trigger.Size, webOverlap)) do
							local character = part:FindFirstAncestorOfClass("Model")
							if character and aliveCharacter(character) then
								entry.tearing = true
								character:SetAttribute("GS_Webbed", serverNow() + WEB_HOLD + WEB_SLOW)
								-- caught: down in the threads until the web tears
								character:SetAttribute("AC_TeleportAt", serverNow())
								-- no ragdoll, no concussion: stuck down in the threads, getting up slowly (Animation)
								character:SetAttribute("GS_WebStunDur", WEB_HOLD)
								character:SetAttribute("GS_WebStun", serverNow() + WEB_HOLD)
								makeNoise(character, 40, 1)
								for _, brain in pairs(monsters) do
									if (brain.data.kind == "spider" or brain.data.kind == "spidermother") and (brain.root.Position - entry.trigger.Position).Magnitude < 140 then
										brain.webAlert = {victim = character, at = now}
									end
								end
								-- the web holds them, then tears
								task.delay(WEB_HOLD, function() breakWeb(entry) end)
								break
							end
						end
					end
				end
			end
		end
	end)
end

-- climbing: straight up a wall of up to 10 studs, never up a wall you can't see
local BROOD_MAX = 8 -- A-116 stops hatching once this many E-116 are about
local thinkSpider
do
	local SPIDER_CLIMB_MAX = 10
	local function tryClimb(brain, towards)
		local now = os.clock()
		if brain.climbing or now < (brain.nextClimbCheck or 0) then return false end
		brain.nextClimbCheck = now + 0.25
		local root = brain.root
		local dir = flat(towards - root.Position)
		if dir.Magnitude < 1.5 then return false end
		dir = dir.Unit
		local params = getMoveParams()
		local hit = workspace:Raycast(root.Position - Vector3.new(0, 0.6, 0), dir * 3.4, params)
		if not hit or math.abs(hit.Normal.Y) > 0.35 then return false end
		local wall = hit.Instance
		if not wall:IsA("BasePart") or wall.Transparency >= 0.5 then return false end -- no grip on what isn't there
		local hip = brain.humanoid.HipHeight + root.Size.Y / 2
		local groundY = root.Position.Y - hip
		local topHit = workspace:Raycast(hit.Position - hit.Normal * 1.6 + Vector3.new(0, SPIDER_CLIMB_MAX + 0.6, 0),
			Vector3.new(0, -(SPIDER_CLIMB_MAX + 1.2), 0), params)
		if not topHit or topHit.Normal.Y < 0.6 then return false end
		local height = topHit.Position.Y - groundY
		if height < 2.2 or height > SPIDER_CLIMB_MAX then return false end
		-- room to stand up there?
		if workspace:Raycast(topHit.Position + Vector3.new(0, 0.3, 0), Vector3.new(0, 3, 0), params) then return false end

		brain.climbing = true
		stop(brain)
		if brain.align then brain.align.Enabled = false end
		local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
		root.Anchored = true
		fx(brain, "Skitter")
		task.spawn(function()
			local function glide(from, to, duration)
				local t0 = os.clock()
				while true do
					local a = math.clamp((os.clock() - t0) / duration, 0, 1)
					if not root.Parent then return false end
					root.CFrame = from:Lerp(to, a * a * (3 - 2 * a))
					if a >= 1 then return true end
					RunService.Heartbeat:Wait()
				end
			end
			-- belly to the wall, head up
			local base = hit.Position + normal * (root.Size.Y / 2 + 0.9)
			base = Vector3.new(base.X, groundY + 1.6, base.Z)
			local onWall = CFrame.lookAt(base, base + Vector3.yAxis, normal)
			local okay = glide(root.CFrame, onWall, 0.3)
			local topPos = Vector3.new(base.X, topHit.Position.Y + 0.4, base.Z)
			okay = okay and glide(onWall, CFrame.lookAt(topPos, topPos + Vector3.yAxis, normal), math.max(0.4, (topPos.Y - base.Y) / 7))
			local stand = topHit.Position - normal * 1.2 + Vector3.new(0, hip + 0.1, 0)
			okay = okay and glide(root.CFrame, CFrame.lookAt(stand, stand - normal), 0.35)
			if root.Parent then
				root.Anchored = false
				root.AssemblyLinearVelocity = Vector3.zero
				pcall(function() root:SetNetworkOwner(nil) end)
			end
			brain.waypoints = nil
			brain.climbing = false
		end)
		return true
	end

	local SPIDER_SENSE = 16 -- it notices you this close even when it can't see you
	local SPIDER_SIGHT = 45
	-- (BROOD_MAX lives above: hatchBrood needs it)

	-- the nearest whole body lying around (A-116 only eats corpses, not loose limbs)
	local function nearestCorpse(brain, maxDist)
		local best, bestDist = nil, maxDist
		local corpses = workspace:FindFirstChild("Corpses")
		for _, model in ipairs(corpses and corpses:GetChildren() or {}) do
			if model:IsA("Model") and not model:GetAttribute("GS_BeingEaten") then
				local part = foodPiece(model)
				if part then
					local d = (part.Position - brain.root.Position).Magnitude
					if d < bestDist then best, bestDist = model, d end
				end
			end
		end
		return best
	end

	function thinkSpider(brain)
		local now = os.clock()
		local model = brain.model
		if not model.Parent then return false end
		if brain.climbing then return true end
		local root = brain.root
		local mother = brain.data.kind == "spidermother"
		local sense = mother and 22 or SPIDER_SENSE
		local sight = mother and 60 or SPIDER_SIGHT
		if brain.target and (not aliveCharacter(brain.target) or isInfected(brain.target)) then
			if mother and not aliveCharacter(brain.target) then
				-- her kill: the body becomes a corpse a few seconds later, and she stays for it
				local deadRoot = brain.target:FindFirstChild("HumanoidRootPart") or brain.target:FindFirstChild("Torso")
				if deadRoot and (deadRoot.Position - root.Position).Magnitude < 20 then
					brain.killPos, brain.killTime = deadRoot.Position, now
				end
			end
			setTarget(brain, nil)
			if brain.state == "hunt" then setState(brain, "roam") end
		end
		if now < (brain.staggerUntil or 0) then
			stop(brain)
			return true
		end

		-- A-116 feeding: nothing distracts her except someone walking right up to her
		if mother and brain.state == "eat" then
			for _, character in ipairs(livingTargets()) do
				if (character.HumanoidRootPart.Position - root.Position).Magnitude < 12 then
					abortEat(brain)
					setTarget(brain, character)
					setState(brain, "hunt")
					fx(brain, "Hiss")
					return true
				end
			end
			eatStep(brain, now, function()
				brain.killPos, brain.killTime = nil, nil
				return "roam"
			end)
			return true
		end

		-- something is struggling in one of the webs
		local alert = brain.webAlert
		if alert and now - alert.at < 12 and aliveCharacter(alert.victim) and not isInfected(alert.victim) then
			brain.webAlert = nil
			setTarget(brain, alert.victim)
			setState(brain, "hunt")
			fx(brain, "Skitter")
		end
		if not brain.target then
			local best, bestDist = nil, math.huge
			for _, character in ipairs(livingTargets()) do
				local d = (character.HumanoidRootPart.Position - root.Position).Magnitude
				if d < bestDist and (d < sense or (d < sight and canSee(brain, character))) then
					best, bestDist = character, d
				end
			end
			if best then
				setTarget(brain, best)
				setState(brain, "hunt")
				fx(brain, "Hiss")
			end
		end

		-- A-116 with nobody to chase: go and eat
		if mother and not brain.target then
			local food = nearestCorpse(brain, 55)
			if food then
				brain.food = food
				setState(brain, "eat")
				return true
			elseif brain.killPos and now - (brain.killTime or 0) < 9 then
				if (brain.killPos - root.Position).Magnitude > 5 then goTo(brain, brain.killPos, WALK_SPEED) else stop(brain) end
				return true
			end
		end

		local targetRoot = brain.target and brain.target:FindFirstChild("HumanoidRootPart")
		if brain.state == "hunt" then
			local distance = targetRoot and (targetRoot.Position - root.Position).Magnitude or math.huge
			if targetRoot and (distance < sense or canSee(brain, brain.target)) then brain.lastSeen = now end
			if not targetRoot or distance > (mother and 90 or 70) or now - (brain.lastSeen or 0) > 9 then
				setTarget(brain, nil)
				setState(brain, "roam")
			else
				local speed = HUMAN_SPEED * (brain.data.speedMultiplier or 0.8)
				if not tryClimb(brain, targetRoot.Position) then
					-- it only bites at point blank: attackStep swings only inside attackRange
					attackStep(brain, now, targetRoot, speed, "hunt", brain.data.swingCooldown or 1.2, 0.16)
				end
			end
		else
			if brain.state ~= "roam" then setState(brain, "roam") end
			if now >= (brain.nextWeb or 0) then
				brain.nextWeb = now + (mother and rng:NextNumber(35, 60) or rng:NextNumber(18, 32))
				stop(brain)
				fx(brain, "Skitter")
				spinWeb(brain)
			elseif not brain.roamGoal or now > brain.roamUntil then
				brain.roamGoal = groundSpot(root.Position, 12, 40)
				brain.roamUntil = now + rng:NextNumber(6, 12)
			else
				if not tryClimb(brain, brain.roamGoal) then
					if goTo(brain, brain.roamGoal, WALK_SPEED * 0.75) then brain.roamUntil = now end
				end
			end
		end

		if now >= (brain.nextSound or 0) then
			brain.nextSound = now + rng:NextNumber(4, 9)
			fx(brain, brain.state == "hunt" and "Hiss" or "Skitter")
		end
		return true
	end
end

local THINK = {skinwalker = thinkSkinwalker, flesh = thinkFlesh, listener = thinkListener, spider = thinkSpider,
	spidermother = thinkSpider}

local function startBrain(model, id)
	local brain = {
		model = model,
		id = id,
		data = MonsterData.Get(id),
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		root = model:FindFirstChild("HumanoidRootPart"),
		head = model:FindFirstChild("Head"),
		align = model.HumanoidRootPart:FindFirstChild("GS_Face"),
		state = "",
		stateSince = os.clock(),
		lastSeen = 0,
		watchUntil = 0,
		retreatUntil = 0,
		avoidUntil = 0,
		nextSwing = 0,
		nextSound = os.clock() + rng:NextNumber(2, 5),
		pathTime = 0,
		trailFloor = -math.huge,
	}
	monsters[model] = brain
	setState(brain, "roam")
	task.spawn(function()
		local nextOwnerCheck = 0
		while model.Parent and monsters[model] do
			-- keep physics on the server; a client owning the body makes it stutter and fall behind
			if os.clock() > nextOwnerCheck then
				nextOwnerCheck = os.clock() + 1
				pcall(function()
					if brain.root:GetNetworkOwner() ~= nil or brain.root:GetNetworkOwnershipAuto() then
						brain.root:SetNetworkOwner(nil)
					end
				end)
			end
			local ok, alive
			if (brain.stunUntil or 0) > os.clock() then
				ok, alive = true, true
				pcall(stop, brain)
			else
				ok, alive = pcall(THINK[brain.data.kind] or think, brain)
			end
			if not ok then
				warn("[Monsters] " .. tostring(alive))
			elseif not alive then
				break
			end
			task.wait(0.1)
		end
		monsters[model] = nil
		if brain.pathConn then brain.pathConn:Disconnect() end
		local guard = faceGuards[model]
		if guard then guard.conn:Disconnect() faceGuards[model] = nil end
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then monsters[model] = nil end
	end)
	return brain
end

-- A-116 finished a body: the egg sac splits and a new E-116 crawls out next to her
function hatchBrood(brain)
	local count = 0
	for _, other in pairs(monsters) do
		if other.data.kind == "spider" then count += 1 end
	end
	if count >= BROOD_MAX then return end
	local root = brain.root
	local back = root.CFrame * CFrame.new(rng:NextNumber(-2, 2), 0, 5)
	local ground = groundAt(back.Position, 12)
	local spot = (ground or back.Position) + Vector3.new(0, 2, 0)
	local model = buildModel("E-116", CFrame.lookAt(spot, spot + flat(root.CFrame.LookVector)))
	if not model then return end
	local baby = startBrain(model, "E-116")
	fx(brain, "Hiss")
	fx(baby, "Skitter")
	-- a newborn scurries off before it starts hunting
	baby.nextWeb = os.clock() + rng:NextNumber(8, 15)
end


local lastStrike = {}
strikeRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local character = player.Character
	if not aliveCharacter(character) or character:GetAttribute("Ragdolled") then return end
	-- the infected claw fast; a survivor's shove needs a breath between swings
	if now - (lastStrike[player] or 0) < (isInfected(character) and 0.65 or 1.4) then return end
	lastStrike[player] = now
	local left = character:GetAttribute("Injury_LeftArm") or 0
	local right = character:GetAttribute("Injury_RightArm") or 0
	if left >= 2 and right >= 2 then return end
	local root = character.HumanoidRootPart
	makeNoise(character, 45, 1)
	-- a swing tears any web right in front of you
	do
		local reachPoint = root.Position + flat(root.CFrame.LookVector) * 2
		for i = #webs, 1, -1 do
			local entry = webs[i]
			if entry.model.Parent and not entry.tearing then
				local p = entry.trigger.CFrame:PointToObjectSpace(reachPoint)
				local size = entry.trigger.Size
				if math.abs(p.X) < size.X / 2 + 1.5 and math.abs(p.Y) < size.Y / 2 + 1.5 and math.abs(p.Z) < 3.2 then
					breakWeb(entry)
				end
			end
		end
	end
	local infected = isInfected(character)
	if infected and (character:GetAttribute("GS_EatServer") or 0) > serverNow() then return end
	-- the infected reach further and swing wider
	local stage = infected and infectStage(character) or 0
	local reach = infected and INFECT_REACH[stage] or 6
	local arc = infected and -0.15 or 0.2
	local function inFront(position, range, minDot)
		local offset = position - root.Position
		return offset.Magnitude < range and flat(offset).Magnitude > 0.1 and flat(root.CFrame.LookVector):Dot(flat(offset).Unit) > (minDot or 0.2)
	end
	if not infected then
		for _, brain in pairs(monsters) do
			if inFront(brain.root.Position, 7) then onStruck(brain, character) end
		end
	end
	-- one victim per swing: the closest person in front
	local best, bestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local other = plr.Character
		if other ~= character and aliveCharacter(other) and isInfected(other) ~= infected then
			local d = (other.HumanoidRootPart.Position - root.Position).Magnitude
			if d < bestDist and inFront(other.HumanoidRootPart.Position, reach, arc) then best, bestDist = other, d end
		end
	end
	if infected then
		local npcFolder = workspace:FindFirstChild("NPCs")
		for _, npc in ipairs(npcFolder and npcFolder:GetChildren() or {}) do
			if npc:IsA("Model") and aliveCharacter(npc) then
				local d = (npc.HumanoidRootPart.Position - root.Position).Magnitude
				if d < bestDist and inFront(npc.HumanoidRootPart.Position, reach, arc) then best, bestDist = npc, d end
			end
		end
		-- (eating is on E and the tentacle grab on R: F only ever hits)
	end
	if best then task.delay(0.2, function()
			if not aliveCharacter(best) or not aliveCharacter(character) then return end
			if infected then strikeCharacter(character, best) else shoveCharacter(character, best) end
		end) end
end)
Players.PlayerRemoving:Connect(function(player)
	lastStrike[player] = nil
end)

control.OnInvoke = function(action, ...)
	if action == "Spawn" then
		local id, near = ...
		if not MonsterData.Get(id) then return false, "unknown object" end
		if typeof(near) ~= "Vector3" then return false, "no position" end
		local spot = groundSpot(near, 30, 45)
		local look = flat(near - spot)
		local cframe = look.Magnitude > 0.1 and CFrame.lookAt(spot, spot + look) or CFrame.new(spot)
		if MonsterData.Get(id).kind == "spitter" then
			local spitter = game:GetService("ServerStorage"):FindFirstChild("GS_SpitterControl")
			if not spitter then return false, "the Spitter script is not running" end
			return spitter:Invoke("Spawn", cframe)
		end
		local model, err = buildModel(id, cframe)
		if not model then return false, err end
		startBrain(model, id)
		local danger = MonsterData.DangerOf(id)
		return true, string.format("%s spawned · class %s (%s)", id, MonsterData.Get(id).class, danger and danger.label or "?")
	elseif action == "Clear" then
		local count = 0
		for model in pairs(monsters) do
			monsters[model] = nil
			if model.Parent then model:Destroy() end
			count += 1
		end
		for _, model in ipairs(folder:GetChildren()) do model:Destroy() end
		return true, string.format("%d object(s) removed", count)
	elseif action == "SetInfection" then
		-- admin panel: 0 cures, 1-3 infects (or re-stages) the player right where they stand
		local plr, stage = ...
		if typeof(plr) ~= "Instance" or not plr:IsA("Player") then return false, "player not found" end
		stage = math.clamp(math.floor(tonumber(stage) or 0), 0, 3)
		local character = plr.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local where = root and root.CFrame
		if stage == 0 then
			if not plr:GetAttribute("Infected") then return false, plr.DisplayName .. " is not infected" end
			pendingInfection[plr] = nil
			for _, key in ipairs({"Infected", "FleshParts", "InfectKills", "InfectPending", "InfectSpawn", "InfectStartKills"}) do
				plr:SetAttribute(key, nil)
			end
			plr:LoadCharacter()
			if where and plr.Character then
				plr.Character:SetAttribute("AC_TeleportAt", serverNow())
				plr.Character:PivotTo(where)
			end
			return true, plr.DisplayName .. " cured"
		end
		local kills = ({0, STAGE_KILLS[1], STAGE_KILLS[2]})[stage]
		if aliveCharacter(character) and isInfected(character) then
			plr:SetAttribute("InfectKills", kills)
			applyInfectStage(plr, character)
			return true, string.format("%s is now infected, stage %d", plr.DisplayName, stage)
		end
		pendingInfection[plr] = nil
		plr:SetAttribute("Infected", true)
		plr:SetAttribute("InfectPending", true)
		plr:SetAttribute("FleshParts", "")
		plr:SetAttribute("InfectStartKills", kills)
		local spawnPart = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		local fallback = spawnPart and spawnPart.Position or Vector3.new(0, 5, 0)
		plr:SetAttribute("InfectSpawn", where and where.Position - Vector3.new(0, 3, 0) or fallback)
		plr:LoadCharacter()
		return true, string.format("%s turned, stage %d", plr.DisplayName, stage)
	elseif action == "Strike" then
		-- server-only testing hook: hit a monster by model name on behalf of a character
		local name, character = ...
		for model, brain in pairs(monsters) do
			if model.Name == name and typeof(character) == "Instance" then
				onStruck(brain, character)
				return true, brain.state, brain.enraged == true, brain.hitsTaken
			end
		end
		return false, "not found"
	elseif action == "Struck" then
		-- a weapon hit (Weapons / MonsterHealth): the creature reacts like it was struck
		local model, character = ...
		local brain = monsters[model]
		if brain and typeof(character) == "Instance" and character:IsA("Model") then onStruck(brain, character) end
		return true
	elseif action == "Kill" then
		-- MonsterHealth took the last of its health: the brain stops
		local model = ...
		local brain = monsters[model]
		if brain then
			monsters[model] = nil
			pcall(stop, brain)
		end
		return true
	elseif action == "Stun" then
		local model, seconds = ...
		local brain = monsters[model]
		local untilT = os.clock() + (tonumber(seconds) or 1)
		if brain then brain.stunUntil = math.max(brain.stunUntil or 0, untilT) end
		-- creatures with a brain of their own (the Spitter) read it from the model
		if typeof(model) == "Instance" then model:SetAttribute("GS_StunUntil", untilT) end
		return true
	elseif action == "Noise" then
		-- gunshots and the like, for every creature's ears
		local character, radius, duration = ...
		if typeof(character) == "Instance" then makeNoise(character, tonumber(radius) or 40, tonumber(duration) or 1) end
		return true
	elseif action == "Count" then
		local count = 0
		for _ in pairs(monsters) do count += 1 end
		return true, count
	elseif action == "Trail" then
		local points = {}
		local now = os.clock()
		for i = math.max(1, #trail - 1500), #trail do
			local p = trail[i]
			table.insert(points, {p.pos, now - p.t})
		end
		return true, points
	end
	return false, "unknown action"
end

RunService.Heartbeat:Connect(function()
	local count = 0
	for _ in pairs(monsters) do count += 1 end
	if folder:GetAttribute("Count") ~= count then folder:SetAttribute("Count", count) end
end)

-- ===== the journal: still copies of every object for the menu's 3D view (ReplicatedStorage.GS_Journal) =====
-- A-013 also gets the three stages of what it turns people into.
task.spawn(function()
	local journal = ReplicatedStorage:FindFirstChild("GS_Journal")
	if journal then journal:Destroy() end
	journal = Instance.new("Folder")
	journal.Name = "GS_Journal"

	local function limb(model, a, b, width, color)
		local length = (b - a).Magnitude
		if length < 0.05 then return end
		local part = Instance.new("Part")
		part.Name = "GS_PreviewLeg"
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.Slate
		part.Color = color
		part.Size = Vector3.new(length, width, width)
		part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		part.Parent = model
		local joint = Instance.new("Part")
		joint.Name = "GS_PreviewJoint"
		joint.Shape = Enum.PartType.Ball
		joint.Material = Enum.Material.Slate
		joint.Color = color:Lerp(Color3.new(1, 1, 1), 0.08)
		joint.Size = Vector3.one * width * 1.4
		joint.CFrame = CFrame.new(b)
		joint.Parent = model
	end

	-- the legs are normally drawn by each client; the preview gets a fixed standing pose
	local function staticLegs(model)
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local scale = model:GetAttribute("SpiderScale") or 1
		local hipHeight = model:GetAttribute("SpiderHip") or 1
		local color = model:FindFirstChild("Torso") and model.Torso.Color or Color3.fromRGB(30, 23, 21)
		for i = 1, 8 do
			local hip = root:FindFirstChild("Leg" .. i)
			if hip then
				local side = hip.Position.X < 0 and -1 or 1
				local from = hip.WorldPosition
				local foot = root.CFrame:PointToWorldSpace(Vector3.new(side * 3.1 * scale, -(hipHeight + root.Size.Y / 2), hip.Position.Z * 1.7))
				local knee = (from + foot) / 2 + root.CFrame.UpVector * 1.5 * scale + root.CFrame.RightVector * side * 0.5 * scale
				limb(model, from, knee, 0.22 * scale, color)
				limb(model, knee, foot, 0.15 * scale, color)
			end
		end
	end

	local function freeze(model)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			end
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	end

	local function body(id)
		local data = MonsterData.Get(id)
		if not data then return nil end
		local model
		if data.kind == "skinwalker" then
			model = buildBareModel()
			if model then applyBareLook(model) end
		elseif data.kind == "flesh" then
			model = buildFleshModel()
		elseif data.kind == "listener" then
			model = buildListenerModel()
		elseif data.kind == "spider" or data.kind == "spidermother" then
			model = buildSpiderModel(data.kind == "spidermother")
			staticLegs(model)
		else
			local template = getTemplate()
			model = template and template:Clone()
			local head = model and model:FindFirstChild("Head")
			for _, part in ipairs(head and head:GetChildren() or {}) do
				if part:IsA("BasePart") and part.Name == "Eye" then part.Color = Color3.fromRGB(205, 215, 225) end
			end
		end
		return model
	end

	for _, id in ipairs(MonsterData.Order) do
		local ok, model = pcall(body, id)
		if ok and model then
			freeze(model)
			model.Name = id
			model.Parent = journal
		else
			warn("[Journal] no preview for " .. id .. ": " .. tostring(model))
		end
	end

	-- A-013's victims: I - just turned (the eaten limbs came back as meat), II - the meat has taken the whole body,
	-- III - the eyes, the teeth and the tentacles
	local SKIN = Color3.fromRGB(196, 150, 120)
	for stage = 1, 3 do
		local ok, model = pcall(function()
			local m = coloredModel(SKIN)
			if not m then return nil end
			local bodyColors = m:FindFirstChildOfClass("BodyColors")
			for _, name in ipairs({"Torso", "Left Leg", "Right Leg"}) do
				local part = m:FindFirstChild(name)
				if part then part.Color = name == "Torso" and Color3.fromRGB(58, 60, 64) or Color3.fromRGB(38, 42, 56) end
			end
			if bodyColors then
				bodyColors.TorsoColor3 = Color3.fromRGB(58, 60, 64)
				bodyColors.LeftLegColor3 = Color3.fromRGB(38, 42, 56)
				bodyColors.RightLegColor3 = Color3.fromRGB(38, 42, 56)
			end
			if stage == 1 then
				fleshShellPart(m:FindFirstChild("Left Arm"))
				fleshShellPart(m:FindFirstChild("Right Leg"))
			else
				coverBody(m)
			end
			if stage == 3 then
				-- the eyes and the teeth; the tentacles are drawn (and move) in the journal itself
				addInfectedFace(m)
			end
			return m
		end)
		if ok and model then
			freeze(model)
			model.Name = "A-013_Stage" .. stage
			model.Parent = journal
		else
			warn("[Journal] stage " .. stage .. ": " .. tostring(model))
		end
	end
	journal.Parent = ReplicatedStorage
end)
]=]},
	{name = "ShopData", class = "ModuleScript", where = "Modules", source = [=[
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
]=]},
	{name = "ShopModels", class = "ModuleScript", where = "Modules", source = [=[
-- The supply depot's items as little part models (shown turning in the shop window).
-- Every model is built around the origin; the long ones lie along X, the front of anything with a face looks at -Z.
local ShopModels = {}
local INK = Color3.fromRGB(245, 243, 240)
local M = Enum.Material
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local function mk(model, size, cf, color, material, shape, transparency)
	local p = Instance.new(shape == "wedge" and "WedgePart" or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape and shape ~= "wedge" then p.Shape = shape end
	if transparency then p.Transparency = transparency end
	p.Parent = model
	return p
end
local A = CFrame.Angles
local R = math.rad
local STEEL, STEEL_L, DARK = Color3.fromRGB(70, 72, 75), Color3.fromRGB(165, 168, 172), Color3.fromRGB(28, 28, 30)
local WOOD, RUST, OLIVE = Color3.fromRGB(110, 78, 50), Color3.fromRGB(112, 70, 44), Color3.fromRGB(72, 82, 52)

local BUILD = {}
BUILD.pipe = function(m)
	local c = A(0, 0, R(25))
	mk(m, Vector3.new(4, 0.36, 0.36), c, RUST, M.CorrodedMetal, CYL)
	for _, x in ipairs({-1.85, 1.85}) do mk(m, Vector3.new(0.4, 0.48, 0.48), c * CFrame.new(x, 0, 0), Color3.fromRGB(80, 60, 44), M.Metal, CYL) end
	mk(m, Vector3.new(0.5, 0.4, 0.4), c * CFrame.new(0.4, 0, 0), Color3.fromRGB(80, 60, 44), M.Metal, CYL)
end
-- a chef's knife: straight edge, the spine sweeping down to the point, riveted wooden handle
BUILD.knife = function(m)
	local c = A(0, 0, R(18))
	local blade = Color3.fromRGB(176, 180, 186)
	mk(m, Vector3.new(1.7, 0.44, 0.06), c * CFrame.new(0.85, 0, 0), blade, M.Metal)
	mk(m, Vector3.new(0.06, 0.44, 0.75), c * CFrame.new(2.075, 0, 0) * A(0, R(-90), 0), blade, M.Metal, "wedge")
	-- the ground edge, a lighter strip along the bottom
	mk(m, Vector3.new(1.7, 0.07, 0.064), c * CFrame.new(0.85, -0.19, 0), Color3.fromRGB(222, 225, 230), M.Metal)
	mk(m, Vector3.new(0.064, 0.07, 0.74), c * CFrame.new(2.07, -0.19, 0) * A(0, R(-90), 0), Color3.fromRGB(222, 225, 230), M.Metal)
	mk(m, Vector3.new(0.14, 0.5, 0.13), c * CFrame.new(-0.07, 0.01, 0), Color3.fromRGB(60, 62, 66), M.Metal)
	mk(m, Vector3.new(1.15, 0.36, 0.17), c * CFrame.new(-0.72, -0.02, 0), Color3.fromRGB(62, 40, 26), M.Wood)
	mk(m, Vector3.new(0.2, 0.36, 0.17), c * CFrame.new(-1.33, -0.02, 0), Color3.fromRGB(62, 40, 26), M.Wood, BALL)
	for _, x in ipairs({-0.35, -0.72, -1.09}) do
		mk(m, Vector3.new(0.19, 0.08, 0.08), c * CFrame.new(x, -0.02, 0) * A(0, R(90), 0), Color3.fromRGB(200, 202, 206), M.Metal, CYL)
	end
end
BUILD.nailbat = function(m)
	local c = A(0, 0, R(28))
	mk(m, Vector3.new(1.3, 0.26, 0.26), c * CFrame.new(-1.6, 0, 0), Color3.fromRGB(60, 40, 28), M.Fabric, CYL)
	mk(m, Vector3.new(1.3, 0.36, 0.36), c * CFrame.new(-0.4, 0, 0), WOOD, M.Wood, CYL)
	mk(m, Vector3.new(1.6, 0.5, 0.5), c * CFrame.new(1.0, 0, 0), WOOD, M.Wood, CYL)
	mk(m, Vector3.new(0.12, 0.36, 0.36), c * CFrame.new(-2.3, 0, 0), Color3.fromRGB(60, 40, 28), M.Wood, CYL)
	for i = 0, 9 do
		local a = i * 2.4
		mk(m, Vector3.new(0.45, 0.05, 0.05), c * CFrame.new(0.4 + (i % 5) * 0.28, 0, 0) * A(a, 0, 0) * CFrame.new(0, 0.3, 0) * A(0, 0, R(90)),
			STEEL_L, M.Metal, CYL)
	end
end
-- a fire axe: red head, a clean silver edge, a short pick at the back, wooden haft with a rubber grip
BUILD.axe = function(m)
	local c = A(0, 0, R(-22))
	local red = Color3.fromRGB(176, 26, 20)
	local wood = Color3.fromRGB(150, 108, 66)
	local steel = Color3.fromRGB(205, 208, 212)
	mk(m, Vector3.new(0.22, 3.3, 0.18), c * CFrame.new(0, -0.1, 0), wood, M.Wood)
	mk(m, Vector3.new(0.27, 0.95, 0.23), c * CFrame.new(0, -1.35, 0), Color3.fromRGB(26, 26, 28), M.Rubber)
	mk(m, Vector3.new(0.3, 0.12, 0.26), c * CFrame.new(0, -1.78, 0), Color3.fromRGB(26, 26, 28), M.Rubber)
	mk(m, Vector3.new(0.26, 0.14, 0.2), c * CFrame.new(0, 1.72, 0), wood, M.Wood)
	-- head: the eye round the haft, one clean red cheek out to a silver ground edge
	mk(m, Vector3.new(0.44, 0.62, 0.3), c * CFrame.new(0, 1.42, 0), red, M.Metal)
	mk(m, Vector3.new(0.66, 0.7, 0.18), c * CFrame.new(0.52, 1.42, 0), red, M.Metal)
	mk(m, Vector3.new(0.12, 0.78, 0.1), c * CFrame.new(0.91, 1.42, 0), steel, M.Metal)
	mk(m, Vector3.new(0.5, 0.04, 0.19), c * CFrame.new(0.5, 1.42, 0), Color3.fromRGB(120, 16, 12), M.Metal)
	-- the pick: a short even point out of the back of the eye (two wedges, one turned over)
	local back, backDown = A(0, R(90), 0), A(R(180), 0, 0) * A(0, R(90), 0)
	mk(m, Vector3.new(0.16, 0.16, 0.5), c * CFrame.new(-0.47, 1.5, 0) * back, red, M.Metal, "wedge")
	mk(m, Vector3.new(0.16, 0.16, 0.5), c * CFrame.new(-0.47, 1.34, 0) * backDown, red, M.Metal, "wedge")
end
-- a flare pistol: fat orange barrel with a dark bore, hinged breech, hammer, ribbed grip and a trigger guard
BUILD.flaregun = function(m)
	local orange = Color3.fromRGB(232, 98, 22)
	local deep = Color3.fromRGB(190, 70, 14)
	local black = Color3.fromRGB(24, 24, 26)
	mk(m, Vector3.new(1.55, 0.62, 0.62), CFrame.new(0.55, 0.28, 0), orange, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.14, 0.7, 0.7), CFrame.new(1.28, 0.28, 0), deep, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.05, 0.44, 0.44), CFrame.new(1.36, 0.28, 0), black, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.16, 0.7, 0.7), CFrame.new(-0.16, 0.28, 0), deep, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(1.2, 0.06, 0.1), CFrame.new(0.55, 0.61, 0), deep, M.SmoothPlastic)
	mk(m, Vector3.new(0.06, 0.1, 0.06), CFrame.new(1.2, 0.66, 0), black, M.SmoothPlastic)
	-- breech block, hinge pin and the hammer on top at the back
	mk(m, Vector3.new(0.6, 0.7, 0.48), CFrame.new(-0.5, 0.22, 0), orange, M.SmoothPlastic)
	mk(m, Vector3.new(0.52, 0.14, 0.14), CFrame.new(-0.24, -0.06, 0) * A(0, R(90), 0), black, M.Metal, CYL)
	mk(m, Vector3.new(0.12, 0.26, 0.14), CFrame.new(-0.74, 0.62, 0) * A(0, 0, R(25)), black, M.Metal)
	mk(m, Vector3.new(0.14, 0.08, 0.18), CFrame.new(-0.8, 0.74, 0) * A(0, 0, R(25)), black, M.Metal)
	-- grip under the back of the breech, leaning back, with dark ribbed panels
	local grip = CFrame.new(-0.72, -0.5, 0) * A(0, 0, R(14))
	mk(m, Vector3.new(0.5, 1.15, 0.44), grip, orange, M.SmoothPlastic)
	for _, z in ipairs({-0.23, 0.23}) do
		mk(m, Vector3.new(0.36, 0.85, 0.03), grip * CFrame.new(0, -0.05, z), black, M.SmoothPlastic)
		for i = -2, 2 do
			mk(m, Vector3.new(0.3, 0.04, 0.04), grip * CFrame.new(0, i * 0.15, z * 1.08), Color3.fromRGB(46, 46, 48), M.SmoothPlastic)
		end
	end
	mk(m, Vector3.new(0.54, 0.1, 0.46), grip * CFrame.new(0, -0.6, 0), deep, M.SmoothPlastic)
	mk(m, Vector3.new(0.06, 0.16, 0.16), grip * CFrame.new(0, -0.7, 0) * A(0, R(90), 0), black, M.Metal, CYL)
	-- trigger and its guard
	mk(m, Vector3.new(0.07, 0.26, 0.07), CFrame.new(-0.3, -0.24, 0) * A(0, 0, R(-12)), black, M.Metal)
	mk(m, Vector3.new(0.46, 0.06, 0.09), CFrame.new(-0.28, -0.42, 0), deep, M.SmoothPlastic)
	mk(m, Vector3.new(0.06, 0.32, 0.09), CFrame.new(-0.05, -0.27, 0), deep, M.SmoothPlastic)
end
BUILD.bandage = function(m)
	mk(m, Vector3.new(0.7, 1.1, 1.1), A(0, R(30), 0), Color3.fromRGB(226, 220, 206), M.Fabric, CYL)
	mk(m, Vector3.new(0.72, 0.4, 0.4), A(0, R(30), 0), Color3.fromRGB(160, 150, 130), M.Fabric, CYL)
	mk(m, Vector3.new(0.6, 0.04, 1.4), A(0, R(30), 0) * CFrame.new(0, -0.53, -0.6) * A(R(-12), 0, 0), Color3.fromRGB(226, 220, 206), M.Fabric)
	mk(m, Vector3.new(0.2, 0.05, 0.4), A(0, R(30), 0) * CFrame.new(0, -0.55, -1.2), Color3.fromRGB(150, 30, 26), M.Fabric)
end
BUILD.painkillers = function(m)
	local b = mk(m, Vector3.new(1.2, 0.7, 0.7), A(0, 0, R(90)), Color3.fromRGB(210, 110, 30), M.Glass, CYL, 0.25)
	b.Reflectance = 0
	mk(m, Vector3.new(0.3, 0.78, 0.78), A(0, 0, R(90)) * CFrame.new(0.72, 0, 0), Color3.fromRGB(235, 232, 225), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.5, 0.72, 0.72), A(0, 0, R(90)) * CFrame.new(-0.05, 0, 0), Color3.fromRGB(240, 236, 228), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.22, 0.04, 0.3), CFrame.new(0, -0.05, -0.37), Color3.fromRGB(170, 24, 24), M.SmoothPlastic)
	for i = 0, 3 do mk(m, Vector3.new(0.16, 0.08, 0.16), CFrame.new(0.3 + i * 0.15, -0.56, -0.5 + i * 0.1), INK, M.SmoothPlastic, BALL) end
end
BUILD.splint = function(m)
	local c = A(0, 0, R(18))
	for _, z in ipairs({-0.3, 0.3}) do mk(m, Vector3.new(3, 0.12, 0.3), c * CFrame.new(0, 0, z), Color3.fromRGB(150, 118, 78), M.Wood) end
	for _, x in ipairs({-1, 0, 1}) do mk(m, Vector3.new(0.3, 0.25, 0.86), c * CFrame.new(x, 0, 0), Color3.fromRGB(205, 200, 185), M.Fabric) end
	mk(m, Vector3.new(0.08, 0.25, 0.25), c * CFrame.new(1.3, 0.1, 0.7) * A(0, R(40), 0), Color3.fromRGB(205, 200, 185), M.Fabric)
end
BUILD.flare = function(m)
	local c = A(0, 0, R(60))
	mk(m, Vector3.new(2, 0.34, 0.34), c, Color3.fromRGB(190, 30, 24), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.35, 0.38, 0.38), c * CFrame.new(1.1, 0, 0), DARK, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.5, 0.35, 0.35), c * CFrame.new(-0.4, 0, 0), Color3.fromRGB(235, 225, 200), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.12, 0.3, 0.3), c * CFrame.new(-1.05, 0, 0), Color3.fromRGB(255, 110, 60), M.Neon, CYL)
end
-- a first aid case: red box with rounded edges, a white panel with a red cross, latches and a carry handle
BUILD.medkit = function(m)
	local red = Color3.fromRGB(178, 28, 28)
	local dark = Color3.fromRGB(110, 16, 16)
	mk(m, Vector3.new(1.84, 1.3, 0.72), CFrame.new(), red, M.SmoothPlastic)
	mk(m, Vector3.new(2.0, 1.14, 0.72), CFrame.new(), red, M.SmoothPlastic)
	for _, x in ipairs({-0.92, 0.92}) do
		for _, y in ipairs({-0.57, 0.57}) do
			mk(m, Vector3.new(0.72, 0.16, 0.16), CFrame.new(x, y, 0) * A(0, R(90), 0), red, M.SmoothPlastic, CYL)
		end
	end
	mk(m, Vector3.new(2.02, 0.05, 0.74), CFrame.new(0, 0.28, 0), dark, M.SmoothPlastic)
	mk(m, Vector3.new(0.98, 0.84, 0.03), CFrame.new(0, -0.1, -0.37), Color3.fromRGB(238, 234, 228), M.SmoothPlastic)
	mk(m, Vector3.new(0.66, 0.2, 0.03), CFrame.new(0, -0.1, -0.39), red, M.SmoothPlastic)
	mk(m, Vector3.new(0.2, 0.66, 0.03), CFrame.new(0, -0.1, -0.39), red, M.SmoothPlastic)
	for _, x in ipairs({-0.72, 0.72}) do
		mk(m, Vector3.new(0.22, 0.16, 0.06), CFrame.new(x, 0.28, -0.38), Color3.fromRGB(190, 192, 196), M.Metal)
		mk(m, Vector3.new(0.1, 0.26, 0.1), CFrame.new(x * 0.5, 0.78, 0), Color3.fromRGB(30, 30, 32), M.SmoothPlastic)
	end
	mk(m, Vector3.new(0.86, 0.13, 0.13), CFrame.new(0, 0.92, 0), Color3.fromRGB(30, 30, 32), M.SmoothPlastic, CYL)
end
BUILD.adrenaline = function(m)
	local c = A(0, 0, R(-35))
	mk(m, Vector3.new(1.4, 0.3, 0.3), c, Color3.fromRGB(220, 225, 230), M.Glass, CYL, 0.5)
	mk(m, Vector3.new(1.1, 0.2, 0.2), c * CFrame.new(-0.05, 0, 0), Color3.fromRGB(255, 190, 40), M.Neon, CYL)
	mk(m, Vector3.new(0.5, 0.1, 0.1), c * CFrame.new(-0.95, 0, 0), STEEL, M.Metal, CYL)
	mk(m, Vector3.new(0.7, 0.03, 0.03), c * CFrame.new(-1.5, 0, 0), STEEL_L, M.Metal, CYL)
	mk(m, Vector3.new(0.08, 0.5, 0.5), c * CFrame.new(0.75, 0, 0), DARK, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.6, 0.1, 0.1), c * CFrame.new(1.05, 0, 0), DARK, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.06, 0.4, 0.4), c * CFrame.new(1.35, 0, 0), DARK, M.SmoothPlastic, CYL)
end
BUILD.jacket = function(m)
	local col = Color3.fromRGB(62, 70, 48)
	mk(m, Vector3.new(1.7, 2, 0.75), CFrame.new(), col, M.Fabric)
	for _, s in ipairs({-1, 1}) do
		mk(m, Vector3.new(0.55, 1.8, 0.6), CFrame.new(s * 1.1, -0.15, 0) * A(0, 0, R(s * 12)), col, M.Fabric)
		mk(m, Vector3.new(0.5, 0.2, 0.55), CFrame.new(s * 1.3, -1.05, 0) * A(0, 0, R(s * 12)), Color3.fromRGB(40, 44, 32), M.Fabric)
	end
	mk(m, Vector3.new(1.1, 0.3, 0.8), CFrame.new(0, 1.05, 0), Color3.fromRGB(48, 54, 38), M.Fabric)
	for i = 0, 3 do mk(m, Vector3.new(1.72, 0.05, 0.77), CFrame.new(0, 0.7 - i * 0.45, 0), Color3.fromRGB(44, 50, 34), M.Fabric) end
	mk(m, Vector3.new(0.06, 1.95, 0.77), CFrame.new(0, 0, 0), DARK, M.Metal)
end
BUILD.legguards = function(m)
	for _, s in ipairs({-1, 1}) do
		local c = CFrame.new(s * 0.55, 0, 0) * A(0, R(s * -10), 0)
		mk(m, Vector3.new(0.7, 1.9, 0.3), c, Color3.fromRGB(44, 46, 50), M.SmoothPlastic)
		mk(m, Vector3.new(0.55, 1.6, 0.1), c * CFrame.new(0, -0.05, -0.18), Color3.fromRGB(64, 66, 70), M.Metal)
		mk(m, Vector3.new(0.72, 0.6, 0.5), c * CFrame.new(0, 1.05, -0.05), Color3.fromRGB(58, 60, 64), M.SmoothPlastic, BALL)
		for _, y in ipairs({-0.5, 0.4}) do mk(m, Vector3.new(0.76, 0.14, 0.34), c * CFrame.new(0, y, 0.02), DARK, M.Fabric) end
	end
end
-- a gas mask: black rubber face, two round lenses in metal rims, a filter canister hanging under the chin, straps
BUILD.gasmask = function(m)
	local rubber = Color3.fromRGB(38, 39, 41)
	mk(m, Vector3.new(1.34, 1.45, 0.95), CFrame.new(0, 0.08, 0), rubber, M.Rubber, BALL)
	mk(m, Vector3.new(0.95, 0.85, 0.8), CFrame.new(0, -0.42, -0.16), rubber, M.Rubber, BALL)
	mk(m, Vector3.new(0.16, 0.34, 0.2), CFrame.new(0, 0.12, -0.44), Color3.fromRGB(30, 30, 32), M.Rubber)
	for _, s in ipairs({-1, 1}) do
		local eye = CFrame.new(s * 0.31, 0.24, -0.37) * A(0, R(s * 18), 0)
		mk(m, Vector3.new(0.16, 0.54, 0.54), eye * A(0, R(90), 0), Color3.fromRGB(110, 112, 116), M.Metal, CYL)
		mk(m, Vector3.new(0.17, 0.43, 0.43), eye * CFrame.new(0, 0, -0.01) * A(0, R(90), 0), Color3.fromRGB(96, 120, 116), M.Glass, CYL, 0.35)
		mk(m, Vector3.new(0.1, 0.3, 0.3), eye * CFrame.new(0, 0, 0.03) * A(0, R(90), 0), Color3.fromRGB(14, 16, 16), M.SmoothPlastic, CYL)
		-- head straps, running back from the temples and the cheeks
		mk(m, Vector3.new(0.06, 0.14, 0.62), CFrame.new(s * 0.56, 0.36, 0.34), Color3.fromRGB(56, 54, 50), M.Fabric)
		mk(m, Vector3.new(0.06, 0.12, 0.5), CFrame.new(s * 0.46, -0.34, 0.28), Color3.fromRGB(56, 54, 50), M.Fabric)
	end
	-- the filter: a short olive canister angled down under the chin, ribbed, with a dark perforated cap
	local filter = CFrame.new(0, -0.66, -0.46) * A(R(48), 0, 0)
	mk(m, Vector3.new(0.2, 0.38, 0.38), filter * CFrame.new(0, 0, 0.1) * A(0, R(90), 0), Color3.fromRGB(56, 58, 60), M.Metal, CYL)
	mk(m, Vector3.new(0.46, 0.56, 0.56), filter * CFrame.new(0, 0, -0.2) * A(0, R(90), 0), Color3.fromRGB(78, 88, 56), M.Metal, CYL)
	for _, z in ipairs({-0.08, -0.32}) do
		mk(m, Vector3.new(0.05, 0.6, 0.6), filter * CFrame.new(0, 0, z) * A(0, R(90), 0), Color3.fromRGB(58, 66, 42), M.Metal, CYL)
	end
	mk(m, Vector3.new(0.04, 0.46, 0.46), filter * CFrame.new(0, 0, -0.44) * A(0, R(90), 0), Color3.fromRGB(26, 26, 26), M.Metal, CYL)
end
BUILD.helmet = function(m)
	local col = Color3.fromRGB(34, 38, 50)
	mk(m, Vector3.new(1.6, 1.3, 1.7), CFrame.new(0, 0.2, 0), col, M.SmoothPlastic, BALL)
	mk(m, Vector3.new(0.18, 1.7, 1.8), CFrame.new(0, -0.25, 0) * A(0, 0, R(90)), col, M.SmoothPlastic, CYL)
	local visor = mk(m, Vector3.new(1.5, 0.7, 0.1), CFrame.new(0, -0.2, -0.86) * A(R(-10), 0, 0), Color3.fromRGB(160, 180, 200), M.Glass, nil, 0.45)
	visor.Reflectance = 0
	mk(m, Vector3.new(1.6, 0.12, 0.14), CFrame.new(0, 0.18, -0.82), DARK, M.Metal)
	for _, s in ipairs({-1, 1}) do mk(m, Vector3.new(0.1, 0.3, 0.3), CFrame.new(s * 0.8, -0.05, -0.55) * A(0, 0, R(90)), STEEL_L, M.Metal, CYL) end
end
BUILD.vest = function(m)
	local col = Color3.fromRGB(30, 32, 30)
	mk(m, Vector3.new(1.7, 2.0, 0.6), CFrame.new(), col, M.Fabric)
	mk(m, Vector3.new(1.35, 1.35, 0.12), CFrame.new(0, 0.15, -0.34), Color3.fromRGB(44, 46, 44), M.Fabric)
	for _, s in ipairs({-1, 1}) do mk(m, Vector3.new(0.4, 0.3, 0.64), CFrame.new(s * 0.6, 1.1, 0), col, M.Fabric) end
	for i = -1, 1 do mk(m, Vector3.new(0.38, 0.45, 0.2), CFrame.new(i * 0.45, -0.72, -0.4), OLIVE, M.Fabric) end
	mk(m, Vector3.new(1.0, 0.22, 0.02), CFrame.new(0, 0.55, -0.41), Color3.fromRGB(205, 200, 190), M.SmoothPlastic)
end

-- ===== guns, the baton, ammo and the trap =====
local GUNMETAL, BLUED = Color3.fromRGB(46, 48, 52), Color3.fromRGB(30, 32, 36)
local WALNUT, WALNUT_D = Color3.fromRGB(104, 62, 36), Color3.fromRGB(74, 42, 24)
local BRASS = Color3.fromRGB(196, 160, 72)

-- side-by-side double barrel: two blued barrels, a rib and a bead, walnut forend and stock, the hinge block
BUILD.doublebarrel = function(m)
	for _, z in ipairs({-0.125, 0.125}) do
		mk(m, Vector3.new(3.2, 0.24, 0.24), CFrame.new(1.72, 0.2, z), BLUED, M.Metal, CYL)
		mk(m, Vector3.new(0.03, 0.16, 0.16), CFrame.new(3.33, 0.2, z), Color3.fromRGB(8, 8, 8), M.SmoothPlastic, CYL)
		mk(m, Vector3.new(0.12, 0.27, 0.27), CFrame.new(3.26, 0.2, z), GUNMETAL, M.Metal, CYL)
	end
	mk(m, Vector3.new(3.1, 0.05, 0.1), CFrame.new(1.72, 0.33, 0), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.06, 0.06, 0.06), CFrame.new(3.22, 0.37, 0), BRASS, M.Metal, BALL)
	mk(m, Vector3.new(1.15, 0.22, 0.38), CFrame.new(0.95, 0.03, 0), WALNUT, M.Wood)
	mk(m, Vector3.new(1.15, 0.04, 0.4), CFrame.new(0.95, 0.14, 0), WALNUT_D, M.Wood)
	-- the action: hinge block, top lever, engraved side plates
	mk(m, Vector3.new(0.58, 0.44, 0.42), CFrame.new(0.02, 0.12, 0), Color3.fromRGB(150, 152, 156), M.Metal)
	for _, z in ipairs({-0.215, 0.215}) do
		mk(m, Vector3.new(0.44, 0.3, 0.02), CFrame.new(0.02, 0.1, z), Color3.fromRGB(120, 122, 126), M.DiamondPlate)
	end
	mk(m, Vector3.new(0.26, 0.05, 0.08), CFrame.new(-0.12, 0.36, 0.08) * A(0, R(20), 0), GUNMETAL, M.Metal)
	-- trigger and guard
	mk(m, Vector3.new(0.05, 0.2, 0.05), CFrame.new(-0.05, -0.12, 0) * A(0, 0, R(-10)), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.42, 0.05, 0.08), CFrame.new(-0.05, -0.25, 0), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.05, 0.16, 0.08), CFrame.new(0.15, -0.17, 0), GUNMETAL, M.Metal)
	-- wrist and stock, dropping a little towards the butt
	local stock = CFrame.new(-0.25, 0.02, 0) * A(0, 0, R(-7))
	mk(m, Vector3.new(0.7, 0.3, 0.3), stock * CFrame.new(-0.32, 0, 0), WALNUT, M.Wood)
	mk(m, Vector3.new(1.35, 0.5, 0.34), stock * CFrame.new(-1.3, -0.12, 0), WALNUT, M.Wood)
	mk(m, Vector3.new(1.1, 0.05, 0.345), stock * CFrame.new(-1.25, 0.12, 0), WALNUT_D, M.Wood)
	mk(m, Vector3.new(0.06, 0.58, 0.36), stock * CFrame.new(-2.0, -0.14, 0), Color3.fromRGB(26, 22, 20), M.Rubber)
end

-- WARDEN 870: a black pump gun. Receiver, barrel over the tube, ribbed pump, pistol grip, side-saddle shells
BUILD.warden870 = function(m)
	local black = Color3.fromRGB(24, 24, 26)
	mk(m, Vector3.new(0.95, 0.44, 0.3), CFrame.new(0, 0.12, 0), black, M.Metal)
	mk(m, Vector3.new(0.9, 0.06, 0.1), CFrame.new(0, 0.37, 0), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.34, 0.2, 0.02), CFrame.new(0.05, 0.14, 0.16), Color3.fromRGB(12, 12, 12), M.SmoothPlastic)
	mk(m, Vector3.new(2.7, 0.19, 0.19), CFrame.new(1.8, 0.22, 0), GUNMETAL, M.Metal, CYL)
	mk(m, Vector3.new(0.03, 0.13, 0.13), CFrame.new(3.16, 0.22, 0), Color3.fromRGB(8, 8, 8), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(2.1, 0.17, 0.17), CFrame.new(1.5, 0.0, 0), black, M.Metal, CYL)
	mk(m, Vector3.new(0.12, 0.22, 0.2), CFrame.new(2.55, 0.1, 0), black, M.Metal)
	-- the pump, ribbed
	mk(m, Vector3.new(0.85, 0.27, 0.33), CFrame.new(1.2, 0.0, 0), Color3.fromRGB(34, 34, 36), M.SmoothPlastic)
	for i = -3, 3 do mk(m, Vector3.new(0.04, 0.29, 0.35), CFrame.new(1.2 + i * 0.1, 0, 0), black, M.SmoothPlastic) end
	-- sights
	mk(m, Vector3.new(0.05, 0.1, 0.05), CFrame.new(3.05, 0.36, 0), Color3.fromRGB(230, 90, 30), M.Neon)
	mk(m, Vector3.new(0.1, 0.12, 0.16), CFrame.new(-0.35, 0.42, 0), black, M.Metal)
	-- four spare shells on the left of the receiver
	for i = 0, 3 do
		mk(m, Vector3.new(0.34, 0.1, 0.1), CFrame.new(-0.1 + i * 0.12, 0.12, -0.2) * A(0, 0, R(90)), Color3.fromRGB(170, 24, 24), M.SmoothPlastic, CYL)
		mk(m, Vector3.new(0.08, 0.105, 0.105), CFrame.new(-0.1 + i * 0.12, -0.02, -0.2) * A(0, 0, R(90)), BRASS, M.Metal, CYL)
	end
	-- trigger, guard, pistol grip, stock with a rubber pad
	mk(m, Vector3.new(0.05, 0.18, 0.05), CFrame.new(-0.2, -0.14, 0), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.4, 0.05, 0.08), CFrame.new(-0.2, -0.26, 0), black, M.Metal)
	mk(m, Vector3.new(0.26, 0.62, 0.26), CFrame.new(-0.52, -0.32, 0) * A(0, 0, R(18)), Color3.fromRGB(30, 30, 32), M.Rubber)
	mk(m, Vector3.new(1.35, 0.32, 0.24), CFrame.new(-1.15, 0.05, 0), black, M.SmoothPlastic)
	mk(m, Vector3.new(0.9, 0.18, 0.24), CFrame.new(-1.2, -0.2, 0) * A(0, 0, R(-10)), black, M.SmoothPlastic)
	mk(m, Vector3.new(0.12, 0.6, 0.3), CFrame.new(-1.86, -0.05, 0), Color3.fromRGB(40, 40, 42), M.Rubber)
end

-- shock baton: rubber handle, guard ring, black shaft, two prongs and a blue ring at the tip
BUILD.shockbaton = function(m)
	local black = Color3.fromRGB(22, 22, 24)
	mk(m, Vector3.new(1.0, 0.26, 0.26), CFrame.new(-0.75, 0, 0), Color3.fromRGB(34, 34, 36), M.Rubber, CYL)
	for i = 0, 4 do mk(m, Vector3.new(0.05, 0.28, 0.28), CFrame.new(-1.15 + i * 0.2, 0, 0), black, M.Rubber, CYL) end
	mk(m, Vector3.new(0.1, 0.36, 0.36), CFrame.new(-0.2, 0, 0), GUNMETAL, M.Metal, CYL)
	mk(m, Vector3.new(1.7, 0.2, 0.2), CFrame.new(0.72, 0, 0), black, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.12, 0.2, 0.08), CFrame.new(-0.55, 0.14, 0), Color3.fromRGB(200, 40, 30), M.SmoothPlastic)
	local ring = mk(m, Vector3.new(0.06, 0.24, 0.24), CFrame.new(1.52, 0, 0), Color3.fromRGB(110, 170, 255), M.Neon, CYL)
	ring.Name = "GS_ShockRing"
	for _, z in ipairs({-0.06, 0.06}) do mk(m, Vector3.new(0.14, 0.04, 0.04), CFrame.new(1.63, 0, z), Color3.fromRGB(190, 192, 196), M.Metal) end
	mk(m, Vector3.new(0.12, 0.28, 0.28), CFrame.new(-1.3, 0, 0), black, M.Metal, CYL)
end

-- a box of buckshot: red and cream cardboard with shells lying in front
BUILD.shells12 = function(m)
	mk(m, Vector3.new(1.2, 0.72, 0.8), CFrame.new(0, 0, 0.2), Color3.fromRGB(150, 30, 26), M.Cardboard)
	mk(m, Vector3.new(1.22, 0.22, 0.82), CFrame.new(0, 0.18, 0.2), Color3.fromRGB(226, 214, 186), M.Cardboard)
	mk(m, Vector3.new(0.6, 0.12, 0.02), CFrame.new(0, 0.18, -0.21), Color3.fromRGB(40, 36, 32), M.SmoothPlastic)
	for i = 0, 2 do
		local c = CFrame.new(-0.4 + i * 0.36, -0.28, -0.45) * A(0, R(20 + i * 30), 0)
		mk(m, Vector3.new(0.6, 0.16, 0.16), c, Color3.fromRGB(176, 26, 26), M.SmoothPlastic, CYL)
		mk(m, Vector3.new(0.14, 0.17, 0.17), c * CFrame.new(-0.3, 0, 0), BRASS, M.Metal, CYL)
	end
end
BUILD.flareshell = function(m)
	for _, z in ipairs({-0.25, 0.25}) do
		local c = CFrame.new(0, 0, z) * A(0, 0, R(90))
		mk(m, Vector3.new(0.9, 0.36, 0.36), c, Color3.fromRGB(232, 98, 22), M.SmoothPlastic, CYL)
		mk(m, Vector3.new(0.14, 0.4, 0.4), c * CFrame.new(-0.46, 0, 0), BRASS, M.Metal, CYL)
		mk(m, Vector3.new(0.04, 0.24, 0.24), c * CFrame.new(0.46, 0, 0), Color3.fromRGB(255, 70, 40), M.Neon, CYL)
	end
end

-- a bear trap, set: a base plate, two toothed jaws lying open, springs, a chain and a stake.
-- The jaws are sub-models (JawA / JawB) so a placed trap can snap them shut.
BUILD.beartrap = function(m)
	local steel = Color3.fromRGB(78, 70, 62)
	mk(m, Vector3.new(0.1, 0.9, 0.9), A(0, 0, R(90)), Color3.fromRGB(60, 54, 48), M.CorrodedMetal, CYL)
	mk(m, Vector3.new(0.12, 0.34, 0.34), CFrame.new(0, 0.04, 0) * A(0, 0, R(90)), Color3.fromRGB(140, 120, 90), M.Metal, CYL)
	for j, side in ipairs({-1, 1}) do
		local jaw = Instance.new("Model")
		jaw.Name = j == 1 and "JawA" or "JawB"
		jaw.Parent = m
		for i = 0, 6 do
			local a = math.pi * (i / 6)
			local x, z = math.cos(a) * 0.95, math.sin(a) * 0.95 * side
			mk(jaw, Vector3.new(0.3, 0.1, 0.1), CFrame.new(x, 0.02, z) * A(0, -a * side + math.pi / 2, 0), steel, M.CorrodedMetal)
			mk(jaw, Vector3.new(0.07, 0.22, 0.07), CFrame.new(x * 0.9, 0.12, z * 0.9) * A(0, 0, 0), Color3.fromRGB(170, 160, 146), M.Metal)
		end
	end
	for _, x in ipairs({-1.25, 1.25}) do
		mk(m, Vector3.new(0.7, 0.14, 0.2), CFrame.new(x, 0.02, 0), steel, M.CorrodedMetal)
		mk(m, Vector3.new(0.3, 0.2, 0.2), CFrame.new(x * 1.2, 0.02, 0) * A(0, 0, R(90)), Color3.fromRGB(60, 54, 48), M.Metal, CYL)
	end
	for i = 1, 4 do mk(m, Vector3.new(0.18, 0.06, 0.12), CFrame.new(0, 0, 0.9 + i * 0.16) * A(0, R(i % 2 * 90), 0), Color3.fromRGB(90, 84, 76), M.Metal) end
	mk(m, Vector3.new(0.12, 0.5, 0.12), CFrame.new(0, 0.1, 1.72), Color3.fromRGB(90, 84, 76), M.Metal)
end

-- armor without a shop model of its own is shown on an invisible body
local Wearables = nil
local function wearableDisplay(id)
	return function(m)
		if not Wearables then
			Wearables = require(script.Parent:WaitForChild("Wearables"))
		end
		Wearables.Display(id, m)
	end
end
for _, id in ipairs({"armguards", "scg_helmet", "scg_vest", "scg_arms", "scg_legs"}) do
	BUILD[id] = wearableDisplay(id)
end

-- where the hand holds each item: X points from the hand along the item, Y is its top
local function axeGrip()
	local c = A(0, 0, R(-22)) * CFrame.new(0, -1.25, 0)
	return c * CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.xAxis, -Vector3.zAxis)
end
ShopModels.Grip = {
	pipe = A(0, 0, R(25)) * CFrame.new(-1.45, 0, 0),
	knife = A(0, 0, R(18)) * CFrame.new(-0.78, -0.02, 0),
	nailbat = A(0, 0, R(28)) * CFrame.new(-1.75, 0, 0),
	axe = axeGrip(),
	flaregun = CFrame.new(-0.62, -0.3, 0),
	doublebarrel = CFrame.new(-0.42, -0.06, 0),
	warden870 = CFrame.new(-0.46, -0.24, 0),
	shockbaton = CFrame.new(-0.8, 0, 0),
}
-- items are modelled at shop-window size; in the hand some are shrunk
ShopModels.HeldScale = {
	pipe = 0.85, knife = 0.8, nailbat = 0.85, axe = 0.85, flaregun = 0.7, doublebarrel = 0.8, warden870 = 0.8,
	shockbaton = 0.8, bandage = 0.45, painkillers = 0.45, splint = 0.5, medkit = 0.55, adrenaline = 0.5, flare = 0.55,
	beartrap = 0.7, shells12 = 0.5, flareshell = 0.5,
}

function ShopModels.Build(id)
	local m = Instance.new("Model")
	m.Name = id
	local fn = BUILD[id]
	if fn then fn(m) end
	m.WorldPivot = CFrame.new()
	return m
end

function ShopModels.Has(id)
	return BUILD[id] ~= nil
end

return ShopModels
]=]},
	{name = "ShopServer", class = "Script", where = "ServerScriptService", source = [=[
-- The supply depot (workspace.GS_Shop): opened and closed from the admin panel.
--  * at start the ground under the hatch is dug out (terrain, and flat ground parts are cut around the hole),
--    so the model can be moved anywhere in Studio and still work
--  * opening / closing: State + T0 on the model (every client animates from them), the solid parts are moved here
--    a few times a second so the server's collisions follow, the final pose is set when it stops
--  * nobody is left in the pit: whoever is inside the hatch when the doors start to close is lifted out in front
--  * buying and selling: checked here (open, close enough), carried out by ServerStorage.GS_ItemService
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ShopRig = require(Modules:WaitForChild("ShopRig"))
local ShopData = require(Modules:WaitForChild("ShopData"))

local control = ServerStorage:FindFirstChild("GS_ShopControl")
if not control then
	control = Instance.new("BindableFunction")
	control.Name = "GS_ShopControl"
	control.Parent = ServerStorage
end
local remote = ReplicatedStorage:FindFirstChild("GS_ShopRemote")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GS_ShopRemote"
	remote.Parent = ReplicatedStorage
end

local function serverNow() return workspace:GetServerTimeNow() end

local shop = workspace:FindFirstChild("GS_Shop")
if not shop then
	control.OnInvoke = function() return false, "there is no GS_Shop in the world" end
	return
end

local HALF = ShopRig.HALF
local HOLE = HALF + 1 -- the hole plus the shaft walls

-- ===== dig the hole =====
local function splitAround(part, base)
	local cf, size = part.CFrame, part.Size
	if math.abs(cf.UpVector.Y) < 0.999 then return false end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, c in ipairs({Vector3.new(-HOLE, 0, -HOLE), Vector3.new(HOLE, 0, -HOLE), Vector3.new(-HOLE, 0, HOLE), Vector3.new(HOLE, 0, HOLE)}) do
		local p = cf:PointToObjectSpace(base * c)
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local hx, hz = size.X / 2, size.Z / 2
	minX, maxX = math.max(minX, -hx), math.min(maxX, hx)
	minZ, maxZ = math.max(minZ, -hz), math.min(maxZ, hz)
	if minX >= maxX or minZ >= maxZ then return false end
	local pieces = {
		{-hx, minX, -hz, hz}, {maxX, hx, -hz, hz},
		{minX, maxX, -hz, minZ}, {minX, maxX, maxZ, hz},
	}
	for _, r in ipairs(pieces) do
		local w, d = r[2] - r[1], r[4] - r[3]
		if w > 0.05 and d > 0.05 then
			local piece = part:Clone()
			piece.Size = Vector3.new(w, size.Y, d)
			piece.CFrame = cf * CFrame.new((r[1] + r[2]) / 2, 0, (r[3] + r[4]) / 2)
			-- keep tiled textures lined up with the rest of the ground
			for _, t in ipairs(piece:GetChildren()) do
				if t:IsA("Texture") then
					t.OffsetStudsU += r[1] + hx
					t.OffsetStudsV += r[3] + hz
				end
			end
			piece.Parent = part.Parent
		end
	end
	part:Destroy()
	return true
end

local function dig()
	local base = shop:GetPivot()
	pcall(function()
		workspace.Terrain:FillBlock(base * CFrame.new(0, -7.6, 0), Vector3.new(HOLE * 2 + 1.6, 16.4, HOLE * 2 + 1.6), Enum.Material.Air)
	end)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {shop, workspace.Terrain}
	local found = workspace:GetPartBoundsInBox(base * CFrame.new(0, -7.4, 0), Vector3.new(HOLE * 2 - 0.2, 14.6, HOLE * 2 - 0.2), params)
	local cut = 0
	for _, part in ipairs(found) do
		local ground = part:IsA("Part") and part.Shape == Enum.PartType.Block and part.Anchored
			and part.Size.X >= HOLE * 2 and part.Size.Z >= HOLE * 2
			and math.abs((part.Position.Y + part.Size.Y / 2) - base.Y) < 2.5
		if ground and splitAround(part, base) then cut += 1 end
	end
	return cut
end
dig()

-- ===== state =====
local rig = ShopRig.Collect(shop, 0)
local prompt
for _, d in ipairs(shop:GetDescendants()) do
	if d:IsA("ProximityPrompt") and d.Name == "ShopPrompt" then prompt = d break end
end
local busy = false

local function setState(state)
	local t0 = serverNow()
	shop:SetAttribute("T0", t0)
	shop:SetAttribute("State", state)
	workspace:SetAttribute("ShopT0", t0)
	workspace:SetAttribute("ShopState", state)
end
setState("closed")

local function nearby(radius)
	local base = shop:GetPivot()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local p = base:PointToObjectSpace(root.Position)
			if math.abs(p.X) < radius and math.abs(p.Z) < radius and p.Y < 18 and p.Y > -18 then
				table.insert(list, {player = player, character = character, root = root, local_ = p})
			end
		end
	end
	return list
end

-- moving floors and doors look like flying / noclip to the anticheat: people right next to it are let off
local function exemptNearby()
	for _, entry in ipairs(nearby(HOLE + 12)) do
		entry.character:SetAttribute("AC_TeleportAt", serverNow())
	end
end

-- whoever is down in the hatch is put back on the ground in front of it
local function clearPit()
	local base = shop:GetPivot()
	for _, entry in ipairs(nearby(HALF + 0.5)) do
		if entry.local_.Y < 4 then
			entry.character:SetAttribute("AC_TeleportAt", serverNow())
			local spot = base * CFrame.new(math.clamp(entry.local_.X, -5, 5), 3.5, -(HOLE + 4))
			entry.character:PivotTo(CFrame.lookAt(spot.Position, (base * CFrame.new(0, 3.5, 0)).Position))
			entry.root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function run(opening)
	busy = true
	local state = opening and "opening" or "closing"
	local tl = ShopRig.Timeline[state]
	if not opening then
		if prompt then prompt.Enabled = false end
		remote:FireAllClients("closing")
	end
	setState(state)
	local t0 = shop:GetAttribute("T0")
	local nextMove, nextExempt = 0, 0
	local cleared = false
	while shop.Parent do
		local elapsed = serverNow() - t0
		if elapsed >= tl.total then break end
		local now = os.clock()
		if now >= nextExempt then
			nextExempt = now + 0.5
			exemptNearby()
		end
		if not opening and not cleared and elapsed >= tl.doors[1] - 0.2 then
			cleared = true
			clearPit()
		end
		if now >= nextMove then
			nextMove = now + 1 / 12
			local d, l = ShopRig.Alphas(state, elapsed)
			ShopRig.Apply(rig, d, l, true)
		end
		RunService.Heartbeat:Wait()
	end
	local final = opening and 1 or 0
	ShopRig.Apply(rig, final, final, false)
	setState(opening and "open" or "closed")
	if opening and prompt then prompt.Enabled = true end
	busy = false
end

control.OnInvoke = function(open)
	if not shop.Parent then return false, "the shop is gone" end
	if busy then return false, "the depot is still moving" end
	local state = shop:GetAttribute("State")
	if open and state == "open" then return false, "the shop is already open" end
	if not open and state == "closed" then return false, "the shop is already closed" end
	task.spawn(run, open == true)
	return true, open and "shop opening" or "shop closing"
end

-- ===== the window =====
local ItemService = require(ServerStorage:WaitForChild("GS_ItemService"))
local lastBuy = {}
remote.OnServerEvent:Connect(function(player, kind, itemId, amount)
	if kind ~= "buy" and kind ~= "sell" then return end
	local now = os.clock()
	if now - (lastBuy[player] or 0) < 0.3 then return end
	lastBuy[player] = now
	if typeof(itemId) ~= "string" then return end
	if kind == "buy" and not ShopData.Get(itemId) then return end
	if shop:GetAttribute("State") ~= "open" then
		remote:FireClient(player, kind, itemId, false, "the depot is closed")
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local promptPart = prompt and prompt.Parent
	if not root or not promptPart or (root.Position - promptPart.Position).Magnitude > 20 then
		remote:FireClient(player, kind, itemId, false, "come closer to the counter")
		return
	end
	if kind == "buy" then
		local ok, message = ItemService.Buy(player, itemId)
		remote:FireClient(player, "buy", itemId, ok, message)
	else
		-- itemId is the bag entry's uid here
		local ok, paid = ItemService.Sell(player, itemId, tonumber(amount))
		remote:FireClient(player, "sell", itemId, ok, ok and ("sold for $" .. tostring(paid)) or paid)
	end
end)
Players.PlayerRemoving:Connect(function(player) lastBuy[player] = nil end)
]=]},
	{name = "ShopUI", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- The supply depot's window, opened at the counter (the prompt on GS_Shop). Same look as the menu's panels:
-- black card, thin frame with corner brackets, typewriter font. Three sections (ATTACK, CONSUMABLES, DEFENSE),
-- a grid of items with turning 3D models, and the picked item on the right with its stats, price and BUY.
-- Closes with X, Esc, E again, walking away, dying, or the depot going back under.
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ShopData = require(Modules:WaitForChild("ShopData"))
local SoundConfig = require(Modules:WaitForChild("SoundConfig"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("GS_ShopRemote", 30)
local shop = workspace:WaitForChild("GS_Shop", 60)
if not shop then return end

local FONT = Enum.Font.SpecialElite
local INK = Color3.fromRGB(245, 243, 240)
local MID = Color3.fromRGB(214, 210, 205)
local DIM = Color3.fromRGB(150, 146, 142)
local LINE = Color3.fromRGB(90, 88, 85)
local CELL = Color3.fromRGB(12, 12, 12)
local AMBER = Color3.fromRGB(232, 164, 52)
local RED = Color3.fromRGB(235, 40, 40)
local W, H = 820, 580

local function create(className, props, children)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	return obj
end
local function tween(obj, t, goal, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local soundFolder = create("Folder", {Name = "GS_ShopSounds", Parent = player:WaitForChild("PlayerGui")})
local function click(name, volume)
	pcall(function() SoundConfig.PlayOnce(name, soundFolder, {Volume = volume}) end)
end

local gui = create("ScreenGui", {
	Name = "GS_ShopUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui"),
})
local shade = create("TextButton", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
	AutoButtonColor = false, Text = "", Parent = gui,
})
local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = Color3.fromRGB(6, 6, 6), BackgroundTransparency = 0.02, BorderSizePixel = 0, Parent = gui,
}, {
	create("UIStroke", {Color = LINE, Thickness = 1}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 26, 25), Color3.fromRGB(0, 0, 0))}),
})
local panelScale = create("UIScale", {Parent = panel})
-- swallow clicks on the card itself so only the dark area around it closes the window
create("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = panel})

local function bracket(parent, anchor, pos)
	local holder = create("Frame", {AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 5, Parent = parent})
	create("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, anchor.Y), AnchorPoint = Vector2.new(0, anchor.Y),
		BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 5, Parent = holder})
	create("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(anchor.X, 0), AnchorPoint = Vector2.new(anchor.X, 0),
		BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 5, Parent = holder})
end
local function brackets(parent)
	bracket(parent, Vector2.new(0, 0), UDim2.fromOffset(6, 6))
	bracket(parent, Vector2.new(1, 0), UDim2.new(1, -6, 0, 6))
	bracket(parent, Vector2.new(0, 1), UDim2.new(0, 6, 1, -6))
	bracket(parent, Vector2.new(1, 1), UDim2.new(1, -6, 1, -6))
end
brackets(panel)

local function text(parent, props)
	local base = {BackgroundTransparency = 1, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, ZIndex = 3, Parent = parent}
	for k, v in pairs(props) do base[k] = v end
	return create("TextLabel", base)
end

-- header
text(panel, {Position = UDim2.fromOffset(26, 16), Size = UDim2.fromOffset(400, 30), Text = "SUPPLY DEPOT", TextSize = 28})
text(panel, {Position = UDim2.fromOffset(240, 26), Size = UDim2.fromOffset(240, 16),
	Text = "trader 07  -  no refunds", TextSize = 15, TextColor3 = DIM})
-- your money, top right: a gold coin and the amount (rolls and flashes when it changes)
local cashChip = create("Frame", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -66, 0, 14), Size = UDim2.fromOffset(176, 36),
	BackgroundColor3 = Color3.fromRGB(14, 12, 10), BorderSizePixel = 0, ZIndex = 3, Parent = panel,
})
local cashStroke = create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cashChip})
local cashCoin = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(24, 30),
	BackgroundTransparency = 1, Font = FONT, Text = "$", TextSize = 28, TextColor3 = AMBER, ZIndex = 4, Parent = cashChip,
})
local cashCoinScale = create("UIScale", {Parent = cashCoin})
local cashAmount = text(cashChip, {Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -48, 1, 0), Text = "0", TextSize = 22,
	TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4})
local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 14), Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Color3.fromRGB(14, 14, 14), BorderSizePixel = 0, AutoButtonColor = false, Font = FONT, Text = "X",
	TextSize = 20, TextColor3 = MID, ZIndex = 4, Parent = panel,
}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
create("Frame", {
	Position = UDim2.fromOffset(26, 56), Size = UDim2.new(1, -52, 0, 1), BackgroundColor3 = LINE, BorderSizePixel = 0, ZIndex = 3, Parent = panel,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1),
})})})

-- the item models live in ReplicatedStorage.Modules.ShopModels (so they can be built and checked on their own)
local ShopModels = require(Modules:WaitForChild("ShopModels"))
local buildItem = ShopModels.Build

-- a viewport with the item turning in it; returns the entry the spinner uses
local spinners = {}
local function itemView(parent, id, zIndex)
	local frame = create("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(125, 115, 110),
		LightColor = Color3.fromRGB(255, 236, 222), LightDirection = Vector3.new(-0.6, -1, -0.4), ZIndex = zIndex or 4, Parent = parent,
	})
	local world = create("WorldModel", {Parent = frame})
	local model = buildItem(id)
	model.Parent = world
	local cf, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot())
	local camera = create("Camera", {FieldOfView = 30, Parent = frame})
	frame.CurrentCamera = camera
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(15)) * 1.08
	camera.CFrame = CFrame.lookAt(Vector3.new(0, radius * 0.35, -dist), Vector3.zero)
	local entry = {frame = frame, model = model, base = model:GetPivot(), angle = math.random() * 6}
	table.insert(spinners, entry)
	return entry
end

-- ===== tabs =====
local tabButtons = {}
local tabTag = text(panel, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, 74), Size = UDim2.fromOffset(250, 16),
	Text = "", TextSize = 14, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right})
for i, section in ipairs(ShopData.Sections) do
	local b = create("TextButton", {
		Position = UDim2.fromOffset(26 + (i - 1) * 154, 68), Size = UDim2.fromOffset(148, 30), BackgroundColor3 = Color3.fromRGB(14, 14, 14),
		BorderSizePixel = 0, AutoButtonColor = false, Font = FONT, Text = section.title .. "  " .. #section.items, TextSize = 16,
		TextColor3 = MID, ZIndex = 3, Parent = panel,
	}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
	tabButtons[section.id] = b
end
do
	local b = create("TextButton", {
		Position = UDim2.fromOffset(26 + #ShopData.Sections * 154, 68), Size = UDim2.fromOffset(148, 30),
		BackgroundColor3 = Color3.fromRGB(14, 14, 14), BorderSizePixel = 0, AutoButtonColor = false, Font = FONT, Text = "SELL",
		TextSize = 16, TextColor3 = AMBER, ZIndex = 3, Parent = panel,
	}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
	tabButtons.sell = b
end

-- ===== grid (left) =====
local GRID_X, GRID_Y, GRID_W = 26, 110, 450
local grid = create("ScrollingFrame", {
	Position = UDim2.fromOffset(GRID_X, GRID_Y), Size = UDim2.fromOffset(GRID_W, H - GRID_Y - 46), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = LINE, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3, Parent = panel,
}, {
	create("UIGridLayout", {CellSize = UDim2.fromOffset(140, 170), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder}),
	create("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1)}),
})

-- ===== detail (right) =====
local DX = GRID_X + GRID_W + 16
local DW = W - DX - 26
local viewHolder = create("Frame", {
	Position = UDim2.fromOffset(DX, GRID_Y), Size = UDim2.fromOffset(DW, 190), BackgroundColor3 = Color3.fromRGB(12, 11, 11),
	BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3, Parent = panel,
}, {
	create("UIStroke", {Color = LINE, Thickness = 1}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 32, 31), Color3.fromRGB(6, 6, 6))}),
})
brackets(viewHolder)
local viewTag = text(viewHolder, {Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(240, 14), Text = "", TextSize = 13, TextColor3 = DIM, ZIndex = 6})
text(viewHolder, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -8), Size = UDim2.fromOffset(200, 14), Text = "drag to turn",
	TextSize = 12, TextColor3 = LINE, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6})
local detailName = text(panel, {Position = UDim2.fromOffset(DX, GRID_Y + 200), Size = UDim2.fromOffset(DW, 28), Text = "", TextSize = 25})
local detailTag = text(panel, {Position = UDim2.fromOffset(DX, GRID_Y + 228), Size = UDim2.fromOffset(DW, 16), Text = "", TextSize = 14, TextColor3 = DIM})
local detailDesc = text(panel, {Position = UDim2.fromOffset(DX, GRID_Y + 252), Size = UDim2.fromOffset(DW, 56), Text = "", TextSize = 14,
	TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = MID})
local statRows = {}
for i = 1, 3 do
	local y = GRID_Y + 314 + (i - 1) * 22
	local label = text(panel, {Position = UDim2.fromOffset(DX, y), Size = UDim2.fromOffset(110, 16), Text = "", TextSize = 13, TextColor3 = DIM})
	local cells = {}
	for c = 1, 10 do
		cells[c] = create("Frame", {
			Position = UDim2.fromOffset(DX + 112 + (c - 1) * 19, y + 4), Size = UDim2.fromOffset(15, 8), BackgroundColor3 = LINE,
			BorderSizePixel = 0, ZIndex = 3, Parent = panel,
		})
	end
	statRows[i] = {label = label, cells = cells}
end
local priceLabel = text(panel, {Position = UDim2.fromOffset(DX, GRID_Y + 384), Size = UDim2.fromOffset(150, 40), Text = "", TextSize = 32, TextColor3 = AMBER})
local buyButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(DX + DW, GRID_Y + 384), Size = UDim2.fromOffset(150, 40),
	BackgroundColor3 = Color3.fromRGB(110, 14, 14), BorderSizePixel = 0, AutoButtonColor = false, Font = FONT, Text = "BUY",
	TextSize = 22, TextColor3 = INK, ZIndex = 3, Parent = panel,
}, {create("UIStroke", {Color = Color3.fromRGB(190, 40, 40), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})

-- footer
create("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -38), Size = UDim2.new(1, -52, 0, 1), BackgroundColor3 = LINE,
	BorderSizePixel = 0, ZIndex = 3, Parent = panel,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1),
})})})
local statusLabel = text(panel, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -12), Size = UDim2.fromOffset(460, 18),
	Text = "", TextSize = 15, TextColor3 = DIM})
text(panel, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -26, 1, -12), Size = UDim2.fromOffset(280, 18),
	Text = UserInputService.TouchEnabled and "" or "[E] / [ESC] leave", TextSize = 15, TextColor3 = MID,
	TextXAlignment = Enum.TextXAlignment.Right})

-- ===== behaviour =====
local selectedSection, selectedItem = nil, nil
local isOpen = false
local cards = {}
local detailView = nil
local IDLE_TEXT = "the trader watches you from behind the counter"

local function setStatus(message, color)
	statusLabel.Text = message
	statusLabel.TextColor3 = color or DIM
end

local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local cashShown = 0
local cashValue = create("NumberValue", {Value = 0})
cashValue.Changed:Connect(function(v) cashAmount.Text = commas(v) end)
-- instant = just show it (opening the window); otherwise roll to it and flash
local function refreshCash(instant)
	local cash = player:GetAttribute("Cash")
	cash = typeof(cash) == "number" and math.floor(cash) or 0
	local delta = cash - cashShown
	cashShown = cash
	if instant or delta == 0 then
		cashValue.Value = cash
		cashAmount.Text = commas(cash)
		return
	end
	tween(cashValue, 0.6, {Value = cash})
	local color = delta > 0 and AMBER or RED
	cashStroke.Color = color
	cashAmount.TextColor3 = color
	task.delay(0.15, function()
		tween(cashStroke, 0.7, {Color = LINE})
		tween(cashAmount, 0.7, {TextColor3 = INK})
	end)
	cashCoinScale.Scale = delta > 0 and 1.35 or 0.75
	tween(cashCoinScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
	local pop = text(panel, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -74, 0, 50), Size = UDim2.fromOffset(160, 20),
		Text = (delta > 0 and "+" or "-") .. ShopData.Currency .. commas(math.abs(delta)), TextSize = 18, TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6})
	tween(pop, 1, {Position = UDim2.new(1, -74, 0, 64), TextTransparency = 1})
	task.delay(1.05, function() pop:Destroy() end)
end

local function removeSpinner(entry)
	for i, e in ipairs(spinners) do
		if e == entry then table.remove(spinners, i) break end
	end
end

local function showItem(item, section)
	selectedItem = item
	for id, card in pairs(cards) do
		card.stroke.Color = id == item.id and INK or LINE
		card.stroke.Thickness = id == item.id and 1.5 or 1
	end
	if detailView then
		removeSpinner(detailView)
		detailView.frame:Destroy()
	end
	detailView = itemView(viewHolder, item.id, 4)
	local index = 1
	for i, it in ipairs(section.items) do if it == item then index = i end end
	viewTag.Text = string.format("%s / %02d", section.title, index)
	detailName.Text = item.name
	detailTag.Text = section.title .. "  -  " .. section.tag
	detailDesc.Text = item.desc
	for i, row in ipairs(statRows) do
		row.label.Text = section.stats[i] or ""
		local filled = math.floor((item.stats[i] or 0) * 10 + 0.5)
		for c, cell in ipairs(row.cells) do
			cell.BackgroundColor3 = c <= filled and (i == 1 and AMBER or INK) or Color3.fromRGB(40, 39, 38)
		end
	end
	priceLabel.Text = ShopData.Currency .. " " .. item.price
	buyButton.Text = "BUY"
	setStatus(IDLE_TEXT)
end

local ItemData = require(Modules:WaitForChild("ItemData"))
local bag = {items = {}}
local syncRemote = ReplicatedStorage:WaitForChild("GS_InvSync", 30)
local showSell
if syncRemote then
	syncRemote.OnClientEvent:Connect(function(snap)
		if typeof(snap) ~= "table" then return end
		bag = snap
		if isOpen and selectedSection == "sell" then showSell() end
	end)
end
local selectedEntry = nil

local function sellPrice(entry)
	local item = ItemData.Get(entry.id)
	if not item or item.adminOnly then return nil end
	local each = item.sell
	if item.kind == "ammo" and item.buyAmount then each = item.sell / item.buyAmount end
	if item.kind == "armor" and entry.dur and item.durability then each = each * math.clamp(entry.dur / item.durability, 0.2, 1) end
	return math.max(1, math.floor(each * entry.n + 0.5))
end

local function showEntry(entry)
	selectedEntry = entry
	selectedItem = nil
	local item = ItemData.Get(entry.id)
	for id, card in pairs(cards) do
		card.stroke.Color = id == entry.uid and INK or LINE
		card.stroke.Thickness = id == entry.uid and 1.5 or 1
	end
	if detailView then
		removeSpinner(detailView)
		detailView.frame:Destroy()
	end
	detailView = itemView(viewHolder, entry.id, 4)
	viewTag.Text = "YOUR BAG"
	detailName.Text = item and item.name or entry.id
	detailTag.Text = (entry.n > 1 and ("x" .. entry.n .. "  -  ") or "") .. (entry.worn and "worn - it comes off first" or "the trader looks it over")
	local cond = ""
	if entry.dur and item and item.durability then
		cond = string.format("Condition: %d%%. ", math.floor(entry.dur / item.durability * 100 + 0.5))
	end
	if entry.ammo and entry.ammo > 0 then cond = cond .. string.format("%d loaded. ", entry.ammo) end
	detailDesc.Text = cond .. (item and item.desc or "")
	for _, row in ipairs(statRows) do
		row.label.Text = ""
		for _, cell in ipairs(row.cells) do cell.BackgroundColor3 = Color3.fromRGB(20, 19, 18) end
	end
	local price = sellPrice(entry)
	priceLabel.Text = price and ("+" .. ShopData.Currency .. " " .. price) or "-"
	buyButton.Text = price and "SELL" or "NO"
	setStatus(price and "the trader pays in cash, no questions" or "the trader won't touch that")
end

function showSell()
	selectedSection = "sell"
	for id, b in pairs(tabButtons) do
		local on = id == "sell"
		b.BackgroundColor3 = on and INK or Color3.fromRGB(14, 14, 14)
		b.TextColor3 = on and Color3.new(0, 0, 0) or (id == "sell" and AMBER or MID)
	end
	tabTag.Text = "what you carry, and what it's worth"
	for _, card in pairs(cards) do
		removeSpinner(card.view)
		card.button:Destroy()
	end
	table.clear(cards)
	local first, keep = nil, nil
	for i, entry in ipairs(bag.items or {}) do
		local item = ItemData.Get(entry.id)
		local price = sellPrice(entry)
		local b = create("TextButton", {
			BackgroundColor3 = CELL, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = i, ZIndex = 3, Parent = grid,
		})
		local stroke = create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b})
		local holder = create("Frame", {
			Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 104), BackgroundColor3 = Color3.fromRGB(20, 19, 18),
			BorderSizePixel = 0, ZIndex = 3, Parent = b,
		}, {create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 32, 31), Color3.fromRGB(8, 8, 8))})})
		local view = itemView(holder, entry.id, 4)
		text(b, {Position = UDim2.fromOffset(10, 112), Size = UDim2.new(1, -16, 0, 34),
			Text = (item and item.name or entry.id) .. (entry.n > 1 and ("  x" .. entry.n) or ""), TextSize = 15,
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4})
		text(b, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), Size = UDim2.fromOffset(120, 18),
			Text = price and ("+" .. ShopData.Currency .. " " .. price) or "no sale", TextSize = 16,
			TextColor3 = price and AMBER or DIM, ZIndex = 4})
		b.MouseEnter:Connect(function() tween(b, 0.12, {BackgroundColor3 = Color3.fromRGB(26, 24, 24)}) end)
		b.MouseLeave:Connect(function() tween(b, 0.15, {BackgroundColor3 = CELL}) end)
		b.Activated:Connect(function()
			click(SoundConfig.Random("TapeClick"), 0.35)
			showEntry(entry)
		end)
		cards[entry.uid] = {button = b, stroke = stroke, view = view}
		first = first or entry
		if selectedEntry and selectedEntry.uid == entry.uid then keep = entry end
	end
	if keep or first then
		showEntry(keep or first)
	else
		selectedEntry = nil
		if detailView then
			removeSpinner(detailView)
			detailView.frame:Destroy()
			detailView = nil
		end
		detailName.Text = "EMPTY BAG"
		detailTag.Text = ""
		detailDesc.Text = "Nothing to sell. Come back with something."
		priceLabel.Text = ""
		buyButton.Text = "-"
		setStatus("the trader shrugs")
	end
end

local function showSection(sectionId)
	if sectionId == "sell" then
		showSell()
		return
	end
	selectedEntry = nil
	local section
	for _, s in ipairs(ShopData.Sections) do if s.id == sectionId then section = s end end
	if not section then return end
	selectedSection = sectionId
	for id, b in pairs(tabButtons) do
		local on = id == sectionId
		b.BackgroundColor3 = on and INK or Color3.fromRGB(14, 14, 14)
		b.TextColor3 = on and Color3.new(0, 0, 0) or MID
	end
	tabTag.Text = section.tag
	for _, card in pairs(cards) do
		removeSpinner(card.view)
		card.button:Destroy()
	end
	table.clear(cards)
	for i, item in ipairs(section.items) do
		local b = create("TextButton", {
			BackgroundColor3 = CELL, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = i, ZIndex = 3, Parent = grid,
		})
		local stroke = create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b})
		local holder = create("Frame", {
			Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 104), BackgroundColor3 = Color3.fromRGB(20, 19, 18),
			BorderSizePixel = 0, ZIndex = 3, Parent = b,
		}, {create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 32, 31), Color3.fromRGB(8, 8, 8))})})
		local view = itemView(holder, item.id, 4)
		text(b, {Position = UDim2.fromOffset(10, 112), Size = UDim2.new(1, -16, 0, 34), Text = item.name, TextSize = 15,
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4})
		text(b, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), Size = UDim2.fromOffset(80, 18),
			Text = ShopData.Currency .. " " .. item.price, TextSize = 16, TextColor3 = AMBER, ZIndex = 4})
		b.MouseEnter:Connect(function()
			tween(b, 0.12, {BackgroundColor3 = Color3.fromRGB(26, 24, 24)})
		end)
		b.MouseLeave:Connect(function() tween(b, 0.15, {BackgroundColor3 = CELL}) end)
		b.Activated:Connect(function()
			if selectedItem == item then return end
			click(SoundConfig.Random("TapeClick"), 0.35)
			showItem(item, section)
		end)
		cards[item.id] = {button = b, stroke = stroke, view = view}
	end
	grid.CanvasPosition = Vector2.zero
	showItem(section.items[1], section)
end

for id, b in pairs(tabButtons) do
	b.Activated:Connect(function()
		if selectedSection == id then return end
		click("MenuClick", 0.5)
		showSection(id)
	end)
end

-- turning the big view by dragging
local turning, lastX = false, 0
viewHolder.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		turning, lastX = true, input.Position.X
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if turning and detailView and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		detailView.angle += (input.Position.X - lastX) * 0.012
		lastX = input.Position.X
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		turning = false
	end
end)

-- buying: the server answers (for now always "not yet")
buyButton.MouseEnter:Connect(function() tween(buyButton, 0.12, {BackgroundColor3 = Color3.fromRGB(150, 20, 20)}) end)
buyButton.MouseLeave:Connect(function() tween(buyButton, 0.15, {BackgroundColor3 = Color3.fromRGB(110, 14, 14)}) end)
local waiting = false
buyButton.Activated:Connect(function()
	if waiting or not remote then return end
	if selectedSection == "sell" then
		if not selectedEntry or not sellPrice(selectedEntry) then return end
		waiting = true
		buyButton.Text = "..."
		click("MenuClick", 0.5)
		remote:FireServer("sell", selectedEntry.uid)
		task.delay(3, function()
			if waiting then
				waiting = false
				buyButton.Text = "SELL"
			end
		end)
		return
	end
	if not selectedItem then return end
	waiting = true
	buyButton.Text = "..."
	click("MenuClick", 0.5)
	remote:FireServer("buy", selectedItem.id)
	task.delay(3, function()
		if waiting then
			waiting = false
			buyButton.Text = "BUY"
		end
	end)
end)

-- ===== open / close =====
local openedAt, closedAt = 0, 0
local promptPart
local function findPrompt()
	for _, d in ipairs(shop:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == "ShopPrompt" then return d end
	end
	return nil
end

local function fit()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local size = camera.ViewportSize
	panelScale.Scale = math.clamp(math.min((size.X - 16) / W, (size.Y - 16) / H), 0.35, 1)
end

local function setOpen(value)
	if value == isOpen then return end
	isOpen = value
	player:SetAttribute("UIOpen", value)
	if value then openedAt = os.clock() else closedAt = os.clock() end
	if value then
		fit()
		refreshCash(true)
		gui.Enabled = true
		shade.BackgroundTransparency = 1
		tween(shade, 0.25, {BackgroundTransparency = 0.45})
		panel.Position = UDim2.new(0.5, 0, 0.5, 18)
		tween(panel, 0.3, {Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Back)
		click(SoundConfig.Random("TapeClick"), 0.45)
		showSection(selectedSection or ShopData.Sections[1].id)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		click("MenuClick", 0.4)
		gui.Enabled = false
		for _, card in pairs(cards) do
			removeSpinner(card.view)
			card.button:Destroy()
		end
		table.clear(cards)
		if detailView then
			removeSpinner(detailView)
			detailView.frame:Destroy()
			detailView = nil
		end
		selectedItem = nil
	end
end

closeButton.Activated:Connect(function() setOpen(false) end)
shade.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input)
	if not isOpen or UserInputService:GetFocusedTextBox() then return end
	-- (the same E press that opened the window must not close it again)
	if input.KeyCode == Enum.KeyCode.Escape or (input.KeyCode == Enum.KeyCode.E and os.clock() - openedAt > 0.3) then
		setOpen(false)
	end
end)

task.spawn(function()
	local prompt = findPrompt()
	while not prompt do
		task.wait(1)
		prompt = findPrompt()
	end
	promptPart = prompt.Parent
	prompt.Triggered:Connect(function(who)
		if who ~= player then return end
		if not isOpen and os.clock() - closedAt > 0.3 then setOpen(true) end
	end)
end)

if remote then
	remote.OnClientEvent:Connect(function(kind, itemId, ok, message)
		if kind == "closing" then
			setOpen(false)
		elseif kind == "sell" then
			waiting = false
			if not isOpen then return end
			setStatus(ok and tostring(message) or tostring(message or "no deal"), ok and AMBER or RED)
			if not ok then pcall(function() SoundConfig.PlayOnce("FearHit", soundFolder, {Volume = 0.25, PlaybackSpeed = 1.6}) end) end
			refreshCash()
		elseif kind == "buy" then
			waiting = false
			buyButton.Text = "BUY"
			if not isOpen then return end
			local item = ShopData.Get(itemId)
			if ok then
				setStatus("bought: " .. (item and item.name or itemId), AMBER)
			else
				setStatus(tostring(message or "no deal"), RED)
				pcall(function() SoundConfig.PlayOnce("FearHit", soundFolder, {Volume = 0.25, PlaybackSpeed = 1.6}) end)
			end
			refreshCash()
		end
	end)
end
player:GetAttributeChangedSignal("Cash"):Connect(function() if isOpen then refreshCash() end end)

local camera = workspace.CurrentCamera
if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if isOpen then fit() end end) end

RunService.RenderStepped:Connect(function(dt)
	if not isOpen then return end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	for _, e in ipairs(spinners) do
		if e.model.Parent then
			if not (turning and e == detailView) then e.angle += dt * 0.6 end
			e.model:PivotTo(CFrame.Angles(0, e.angle, 0) * e.base)
		end
	end
	-- leave when the depot goes, when you walk off, or when you die
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local away = promptPart and root and (root.Position - promptPart.Position).Magnitude > 18
	if shop:GetAttribute("State") ~= "open" or not humanoid or humanoid.Health <= 0 or away then
		setOpen(false)
	end
end)
]=]},
	{name = "Spitter", class = "Script", where = "ServerScriptService", source = [=[
-- C-310 "The Spitter": a hunched green thing with acid sacs in its throat. It keeps its distance and spits.
--   * the spit flies in an arc (every client draws it from the same start, speed and gravity)
--   * a direct hit burns hard, and the fumes keep poisoning you for a few seconds
--   * a gas mask (or the SCG helmet) stops the poisoning and softens the burn: it's the breathing that kills
--   * where it lands a puddle of acid hisses for a while
-- Spawned from the admin panel like any other object (Monsters hands it over through GS_SpitterControl).
-- Health, limbs and death: MonsterHealth (id C-310).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local ID = "C-310"
local SPIT_SPEED = 85
local SPIT_GRAVITY = 40
local SPIT_COOLDOWN = {3, 4.5}
local SPIT_DAMAGE = 20
local POISON_DPS, POISON_TIME = 3, 6
local PUDDLE_TIME, PUDDLE_RADIUS, PUDDLE_DPS = 7, 3.2, 5
local KEEP_MIN, KEEP_MAX = 16, 34
local SIGHT = 110
local CLAW_DAMAGE = 11

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local control = ensure(ServerStorage, "BindableFunction", "GS_SpitterControl")
local fxRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_MonsterHit")
local folder = ensure(workspace, "Folder", "Monsters")

local rng = Random.new()
local function serverNow() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function itemService()
	local ok, svc = pcall(function() return require(ServerStorage:FindFirstChild("GS_ItemService")) end)
	return ok and svc or nil
end

-- ===== the body =====
local GREEN, DARK, SAC = Color3.fromRGB(88, 128, 52), Color3.fromRGB(50, 74, 30), Color3.fromRGB(190, 230, 60)

local function blob(model, part, cf, size, color, material, transparency)
	local b = Instance.new("Part")
	b.Name = "GS_Blob"
	b.Size = size
	b.Color = color
	b.Material = material or Enum.Material.SmoothPlastic
	b.Transparency = transparency or 0
	b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow, b.Massless = false, false, false, false, true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = b
	b.CFrame = part.CFrame * cf
	local w = Instance.new("WeldConstraint")
	w.Part0 = part
	w.Part1 = b
	w.Parent = b
	b.Parent = model
	return b
end

local function build(cframe)
	local desc = Instance.new("HumanoidDescription")
	for _, key in ipairs({"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"}) do
		desc[key] = GREEN
	end
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6) end)
	if not ok or not model then return nil end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Decal") then d:Destroy() end
	end
	model.Name = ID
	local head, torso = model:FindFirstChild("Head"), model:FindFirstChild("Torso")
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.12
		end
	end
	-- a hunched back of lumps and spines
	for i = 1, 6 do
		blob(model, torso, CFrame.new(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 0.9), 0.5), Vector3.new(0.7, 0.6, 0.6) * rng:NextNumber(0.8, 1.3), DARK)
		local spine = Instance.new("WedgePart")
		spine.Name = "GS_Spine"
		spine.Size = Vector3.new(0.12, 0.5, 0.35)
		spine.Color = Color3.fromRGB(180, 170, 120)
		spine.CanCollide, spine.CanQuery, spine.CanTouch, spine.Massless = false, false, false, true
		spine.CFrame = torso.CFrame * CFrame.new(0, 0.95 - i * 0.3, 0.62) * CFrame.Angles(math.rad(-30), 0, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1, w.Parent = torso, spine, spine
		spine.Parent = model
	end
	-- the acid sacs: swollen, glowing, under the jaw and on the neck
	for _, s in ipairs({-1, 1}) do
		local sac = blob(model, head, CFrame.new(s * 0.42, -0.42, -0.2), Vector3.new(0.55, 0.6, 0.55), SAC, Enum.Material.Neon, 0.15)
		sac.Name = "GS_Sac"
		blob(model, torso, CFrame.new(s * 0.45, 0.85, -0.45), Vector3.new(0.45, 0.45, 0.45), SAC, Enum.Material.Neon, 0.2).Name = "GS_Sac"
	end
	-- a wide jaw with teeth, four small black eyes
	blob(model, head, CFrame.new(0, -0.25, -0.52), Vector3.new(0.9, 0.35, 0.3), Color3.fromRGB(20, 26, 8))
	for i = -3, 3 do
		blob(model, head, CFrame.new(i * 0.1, -0.13, -0.63), Vector3.new(0.05, 0.12, 0.05), Color3.fromRGB(226, 220, 170))
	end
	for _, e in ipairs({{-0.22, 0.2}, {0.22, 0.2}, {-0.34, 0.05}, {0.34, 0.05}}) do
		blob(model, head, CFrame.new(e[1], e[2], -0.55), Vector3.new(0.14, 0.14, 0.1), Color3.fromRGB(8, 8, 6))
	end
	local glow = Instance.new("PointLight")
	glow.Color = SAC
	glow.Range = 7
	glow.Brightness = 0.6
	glow.Parent = head
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth, humanoid.Health = 1e6, 1e6
	humanoid.WalkSpeed = 12
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model:SetAttribute("MonsterId", ID)
	model:SetAttribute("DangerClass", "C")
	model:SetAttribute("GS_Twitch", true)
	model:PivotTo(cframe)
	model.Parent = folder
	pcall(function() model.HumanoidRootPart:SetNetworkOwner(nil) end)
	return model
end

-- ===== targets =====
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function alive(character)
	local h = character and character:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

local function targets()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		if alive(c) and not c:GetAttribute("Infected") then table.insert(list, c) end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	for _, npc in ipairs(npcs and npcs:GetChildren() or {}) do
		if npc:IsA("Model") and alive(npc) then table.insert(list, npc) end
	end
	return list
end

local function canSee(model, character)
	local head = model:FindFirstChild("Head")
	local th = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not head or not th then return false end
	local offset = th.Position - head.Position
	if offset.Magnitude > SIGHT then return false end
	sightParams.FilterDescendantsInstances = {folder, character}
	return workspace:Raycast(head.Position, offset, sightParams) == nil
end

-- ===== acid =====
local puddles = {}

local function poison(character, seconds)
	local h = character:FindFirstChildOfClass("Humanoid")
	if not h then return end
	local untilT = serverNow() + seconds
	if (character:GetAttribute("GS_Poison") or 0) > serverNow() then
		character:SetAttribute("GS_Poison", untilT)
		return
	end
	character:SetAttribute("GS_Poison", untilT)
	task.spawn(function()
		while character.Parent and h.Health > 0 and (character:GetAttribute("GS_Poison") or 0) > serverNow() do
			task.wait(1)
			if character:GetAttribute("GS_Filter") then break end -- put the mask on: the burning in your chest stops
			character:SetAttribute("LastDamageCause", "ACID")
			character:SetAttribute("LastDamageTime", serverNow())
			h:TakeDamage(POISON_DPS)
			if h.Health <= 0 then character:SetAttribute("DeathCause", "ACID") end
		end
		if character.Parent then character:SetAttribute("GS_Poison", nil) end
	end)
end

local function acidHit(victim, direct)
	local h = victim:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end
	local filtered = victim:GetAttribute("GS_Filter") == true
	local dmg = direct and SPIT_DAMAGE or PUDDLE_DPS
	if filtered then dmg *= direct and 0.55 or 0.5 end
	local svc = itemService()
	if svc and svc.Absorb then dmg = svc.Absorb(victim, direct and "Head" or "LeftLeg", dmg, "acid") end
	victim:SetAttribute("LastDamageCause", "ACID")
	victim:SetAttribute("LastDamageTime", serverNow())
	h:TakeDamage(dmg)
	if h.Health <= 0 then victim:SetAttribute("DeathCause", "ACID") return end
	if direct then
		if not filtered then poison(victim, POISON_TIME) end
		local plr = Players:GetPlayerFromCharacter(victim)
		if plr then fxRemote:FireClient(plr, "acidscreen", victim, filtered) end
	end
end

local function spit(model, target)
	local head = model:FindFirstChild("Head")
	local troot = target:FindFirstChild("HumanoidRootPart")
	if not head or not troot then return end
	local origin = head.Position + head.CFrame.LookVector * 0.8 - Vector3.new(0, 0.3, 0)
	-- aim where they will be, then lift the shot for the drop
	local aimAt = troot.Position + Vector3.new(0, 0.8, 0)
	local dist = (aimAt - origin).Magnitude
	local flight = dist / SPIT_SPEED
	aimAt += flat(troot.AssemblyLinearVelocity) * flight * 0.8
	aimAt += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)) * (dist / 30)
	local velocity = (aimAt - origin).Unit * SPIT_SPEED + Vector3.new(0, 0.5 * SPIT_GRAVITY * flight, 0)
	fxRemote:FireAllClients("spit", model, origin, velocity, SPIT_GRAVITY, serverNow())
	-- the server flies the same arc and decides what it hits
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {folder}
	local pos, vel = origin, velocity
	local elapsed = 0
	task.spawn(function()
		while elapsed < 3 do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			local newVel = vel - Vector3.new(0, SPIT_GRAVITY * dt, 0)
			local step = (vel + newVel) * 0.5 * dt
			local hit = workspace:Raycast(pos, step, params)
			if hit then
				local victim = hit.Instance:FindFirstAncestorOfClass("Model")
				while victim and not victim:FindFirstChildOfClass("Humanoid") do victim = victim:FindFirstAncestorOfClass("Model") end
				if victim and victim.Parent ~= folder and alive(victim) then acidHit(victim, true) end
				-- a puddle where it landed
				local ground = hit.Normal.Y > 0.5 and hit.Position or nil
				if not ground then
					local down = workspace:Raycast(hit.Position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
					ground = down and down.Position
				end
				if ground then
					table.insert(puddles, {pos = ground, untilT = os.clock() + PUDDLE_TIME, last = {}})
					fxRemote:FireAllClients("acidpuddle", ground, PUDDLE_TIME, PUDDLE_RADIUS)
				end
				fxRemote:FireAllClients("spitsplat", hit.Position, hit.Normal)
				return
			end
			pos += step
			vel = newVel
		end
	end)
end

-- puddles burn whoever stands in them
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for i = #puddles, 1, -1 do
			local p = puddles[i]
			if now > p.untilT then
				table.remove(puddles, i)
			else
				for _, c in ipairs(targets()) do
					local root = c.HumanoidRootPart
					local d = flat(root.Position - p.pos).Magnitude
					if d < PUDDLE_RADIUS and math.abs(root.Position.Y - p.pos.Y) < 4.5 and now - (p.last[c] or 0) >= 1 then
						p.last[c] = now
						acidHit(c, false)
					end
				end
			end
		end
	end
end)

-- ===== the brain =====
local function wander(model, humanoid, brain)
	if not brain.roamGoal or os.clock() > brain.roamUntil then
		local root = model.HumanoidRootPart
		local a = rng:NextNumber(0, math.pi * 2)
		brain.roamGoal = root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(12, 30)
		brain.roamUntil = os.clock() + rng:NextNumber(5, 9)
	end
	humanoid.WalkSpeed = 8
	humanoid:MoveTo(brain.roamGoal)
end

local function moveTo(model, humanoid, brain, goal, speed)
	humanoid.WalkSpeed = speed
	local root = model.HumanoidRootPart
	-- straight at it, and a path when it keeps bumping into things
	if brain.path and brain.pathIndex and os.clock() < brain.pathUntil then
		local wp = brain.path[brain.pathIndex]
		if wp then
			if flat(wp.Position - root.Position).Magnitude < 2.5 then brain.pathIndex += 1 end
			if wp.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
			humanoid:MoveTo(wp.Position)
			return
		end
	end
	humanoid:MoveTo(goal)
	local moved = brain.lastPos and (root.Position - brain.lastPos).Magnitude or 1
	brain.lastPos = root.Position
	brain.stuck = moved < 0.25 and (brain.stuck or 0) + 1 or 0
	if brain.stuck > 12 then
		brain.stuck = 0
		local path = PathfindingService:CreatePath({AgentRadius = 1.8, AgentHeight = 5, AgentCanJump = true})
		local ok = pcall(function() path:ComputeAsync(root.Position, goal) end)
		if ok and path.Status == Enum.PathStatus.Success then
			brain.path, brain.pathIndex, brain.pathUntil = path:GetWaypoints(), 2, os.clock() + 4
		else
			humanoid.Jump = true
		end
	end
end

local function run(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local brain = {nextSpit = os.clock() + 2, nextClaw = 0, lastHit = 0}
	while model.Parent and not model:GetAttribute("GS_Dead") do
		task.wait(0.1)
		local now = os.clock()
		if (model:GetAttribute("GS_StunUntil") or 0) > now then
			humanoid:Move(Vector3.zero)
			continue
		end
		-- pick the closest one it can see (or whoever just hurt it)
		local best, bestDist = nil, math.huge
		for _, c in ipairs(targets()) do
			local d = (c.HumanoidRootPart.Position - root.Position).Magnitude
			if d < bestDist and (canSee(model, c) or (brain.target == c and now - (brain.lastSeen or 0) < 5)) then best, bestDist = c, d end
		end
		if model:GetAttribute("GS_HitAt") and model:GetAttribute("GS_HitAt") ~= brain.lastHit then
			brain.lastHit = model:GetAttribute("GS_HitAt")
			brain.nextSpit = math.min(brain.nextSpit, now + 0.6) -- hurt it and it answers
		end
		if best then
			if best ~= brain.target or canSee(model, best) then brain.lastSeen = now end
			brain.target = best
			local troot = best.HumanoidRootPart
			local away = flat(root.Position - troot.Position)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
			if bestDist < 5 and now >= brain.nextClaw then
				-- too close: a claw
				brain.nextClaw = now + 1.2
				model:SetAttribute("GS_AttackServer", serverNow())
				task.delay(0.25, function()
					if alive(best) and (best.HumanoidRootPart.Position - root.Position).Magnitude < 6 then
						local svc = itemService()
						local dmg = CLAW_DAMAGE
						if svc and svc.Absorb then dmg = svc.Absorb(best, "Torso", dmg, "claw") end
						best:SetAttribute("LastDamageCause", "ACID")
						best:SetAttribute("LastDamageTime", serverNow())
						best:FindFirstChildOfClass("Humanoid"):TakeDamage(dmg)
					end
				end)
			elseif bestDist < KEEP_MIN then
				moveTo(model, humanoid, brain, root.Position + away * 10, 13)
			elseif bestDist > KEEP_MAX then
				moveTo(model, humanoid, brain, troot.Position + away * (KEEP_MIN + 6), 13)
			else
				humanoid:Move(Vector3.zero)
				-- face them
				local look = flat(troot.Position - root.Position)
				if look.Magnitude > 0.1 then root.CFrame = CFrame.lookAt(root.Position, root.Position + look) end
			end
			if now >= brain.nextSpit and bestDist < 80 and canSee(model, best) then
				brain.nextSpit = now + rng:NextNumber(SPIT_COOLDOWN[1], SPIT_COOLDOWN[2])
				model:SetAttribute("GS_SpitAt", serverNow())
				fxRemote:FireAllClients("spitwindup", model)
				task.delay(0.55, function()
					if model.Parent and not model:GetAttribute("GS_Dead") and alive(best) then spit(model, best) end
				end)
			end
		else
			brain.target = nil
			wander(model, humanoid, brain)
		end
	end
	humanoid:Move(Vector3.zero)
end

control.OnInvoke = function(action, cframe)
	if action == "Spawn" then
		if typeof(cframe) ~= "CFrame" then return false, "no position" end
		local model = build(cframe)
		if not model then return false, "could not build the body" end
		task.spawn(run, model)
		return true, "C-310 spawned · class C (HIGH)"
	elseif action == "Stun" then
		return true
	end
	return false, "unknown"
end

]=]},
	{name = "WeaponClient", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- Guns and melee in your hands.
--   LMB fire / swing, RMB aim (tighter spread, closer view), R reload.  Touch: USE, AIM, RELOAD buttons.
--   The crosshair is a ring: its size IS the spread - where the pellets can land. Aim and stand still: it closes.
--   Shots show at once (tracers, flash, shells, kick); the server replays the same seed and decides the damage.
-- Other people's shots, reloads and swings are drawn and heard here too.
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local weaponRemote = ReplicatedStorage:WaitForChild("GS_Weapon", 60)
local syncRemote = ReplicatedStorage:WaitForChild("GS_InvSync", 60)
if not weaponRemote or not syncRemote then return end
local clientAction = player:WaitForChild("GS_ClientAction", 30)

local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local FONT = Enum.Font.SpecialElite
local INK = Color3.fromRGB(236, 230, 222)
local DIM = Color3.fromRGB(130, 122, 116)
local BRIGHT = Color3.fromRGB(225, 40, 40)
local AMBER = Color3.fromRGB(232, 164, 52)

local function create(className, props, children)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	return obj
end
local function tween(obj, t, goal, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local fxFolder = workspace:FindFirstChild("GS_FX") or create("Folder", {Name = "GS_FX", Parent = workspace})

local function sound(name, parent, volume, speed, maxDist)
	local id = ItemData.Sound(name)
	if not id then return end
	local s = create("Sound", {
		SoundId = id, Volume = volume or 0.7, PlaybackSpeed = speed or 1, RollOffMaxDistance = maxDist or 250,
		RollOffMinDistance = 8, Parent = parent or workspace,
	})
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	Debris:AddItem(s, 8)
end

-- ===== what's in the hand =====
local bag = {items = {}}
local function held()
	if not bag.held then return nil end
	for _, e in ipairs(bag.items) do
		if e.uid == bag.held then return e, ItemData.Get(e.id) end
	end
	return nil
end
syncRemote.OnClientEvent:Connect(function(snap)
	if typeof(snap) == "table" then bag = snap end
end)

local function myCharacter()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return nil end
	return c, h
end

local function busy()
	return player:GetAttribute("GS_WheelOpen") or player:GetAttribute("GS_Minigame") or player:GetAttribute("InMenu")
		or (player:GetAttribute("UIOpen") and not player:GetAttribute("GS_WheelOpen"))
end

-- ===== the crosshair =====
local gui = create("ScreenGui", {
	Name = "GS_Crosshair", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 43, Enabled = false, Parent = playerGui,
})
local cross = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Parent = gui})
local ring = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40),
	BackgroundTransparency = 1, Parent = cross,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
local ringStroke = create("UIStroke", {Color = INK, Thickness = 1.5, Transparency = 0.15, Parent = ring})
local ringShadow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 4, 1, 4),
	BackgroundTransparency = 1, Parent = ring,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)}), create("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.6})})
local dot = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4),
	BackgroundColor3 = BRIGHT, BorderSizePixel = 0, Parent = cross,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)}), create("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.4})})
-- four short ticks on the ring
local ticks = {}
for i = 0, 3 do
	ticks[i] = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(i % 2 == 0 and 2 or 7, i % 2 == 0 and 7 or 2),
		BackgroundColor3 = INK, BorderSizePixel = 0, Parent = cross,
	})
end
-- hit marker: four diagonal strokes
local marks = {}
for i = 0, 3 do
	local a = math.rad(45 + i * 90)
	marks[i] = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 12, 0.5, math.sin(a) * 12),
		Size = UDim2.fromOffset(9, 2), Rotation = math.deg(a), BackgroundColor3 = INK, BackgroundTransparency = 1, BorderSizePixel = 0,
		Parent = cross,
	})
end
local hitText = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 12, 0.5, -18), Size = UDim2.fromOffset(120, 18), BackgroundTransparency = 1,
	Font = FONT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, TextTransparency = 1,
	TextStrokeTransparency = 0.5, Parent = cross,
})
-- ammo, bottom right
local ammoPanel = create("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -150), Size = UDim2.fromOffset(170, 56),
	BackgroundColor3 = Color3.fromRGB(8, 6, 6), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = gui,
}, {create("UIStroke", {Color = Color3.fromRGB(70, 8, 10), Thickness = 1})})
create("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Color3.fromRGB(150, 12, 16), BorderSizePixel = 0, Parent = ammoPanel})
local gunName = create("TextLabel", {
	Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -18, 0, 14), BackgroundTransparency = 1, Font = FONT, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM, Parent = ammoPanel,
})
local ammoText = create("TextLabel", {
	Position = UDim2.fromOffset(12, 18), Size = UDim2.new(1, -18, 0, 32), BackgroundTransparency = 1, Font = FONT, TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, RichText = true, Parent = ammoPanel,
})
local reloadBar = create("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, 0), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = AMBER,
	BorderSizePixel = 0, Parent = ammoPanel,
})

local function flashMarks(color, text)
	for _, m in pairs(marks) do
		m.BackgroundColor3 = color
		m.BackgroundTransparency = 0
		tween(m, 0.35, {BackgroundTransparency = 1})
	end
	if text then
		hitText.Text = text
		hitText.TextColor3 = color
		hitText.TextTransparency = 0
		hitText.Position = UDim2.new(1, 12, 0.5, -18)
		tween(hitText, 0.8, {TextTransparency = 1, Position = UDim2.new(1, 12, 0.5, -34)})
	end
end

-- ===== state =====
local aiming = false
local lastShot = 0
local lastSwing = 0
local reloadingUntil = 0
local reloadStarted = 0
local kick = 0 -- visual ring punch after a shot
local seedBase = math.random(1, 2 ^ 20)
local seedCount = 0
local baseFov = nil

local function currentSpread(item, character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local moving = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 3
	return (aiming and item.aimSpread or item.spread) * (moving and 1.3 or 1)
end

-- the point on screen the crosshair sits on
local function aimScreenPoint()
	local camera = workspace.CurrentCamera
	if TOUCH or aiming or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return camera.ViewportSize / 2
	end
	return UserInputService:GetMouseLocation()
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function refreshParams(character)
	local ignore = {character, fxFolder}
	for _, name in ipairs({"GS_Items", "GS_Traps", "SpiderWebs", "GS_Hallucinations", "PS_Blood", "GS_Tentacles"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(ignore, f) end
	end
	rayParams.FilterDescendantsInstances = ignore
end

local function muzzleOf(character, look)
	local heldModel = character:FindFirstChild("GS_Held")
	local head = character:FindFirstChild("Head")
	local best, bestD = head and head.Position or character:GetPivot().Position, -math.huge
	if heldModel then
		for _, p in ipairs(heldModel:GetDescendants()) do
			if p:IsA("BasePart") then
				local d = p.Position:Dot(look)
				if d > bestD then best, bestD = p.Position + look * (p.Size.X * 0.4), d end
			end
		end
	end
	return best
end

-- ===== effects =====
local function tracer(from, to, color)
	local length = (to - from).Magnitude
	if length < 0.5 then return end
	local p = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.Neon, Color = color or Color3.fromRGB(255, 220, 150), Transparency = 0.2,
		Size = Vector3.new(0.06, 0.06, length), CFrame = CFrame.lookAt((from + to) / 2, to), Parent = fxFolder,
	})
	tween(p, 0.09, {Transparency = 1, Size = Vector3.new(0.02, 0.02, length)})
	Debris:AddItem(p, 0.12)
end

local function puff(position, normal, color)
	local a = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position), Parent = fxFolder,
	})
	local e = create("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(color or Color3.fromRGB(120, 112, 100)),
		Size = NumberSequence.new(0.3, 1.1), Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(30, 30), Rate = 0, EmissionDirection = Enum.NormalId.Top, Parent = a,
	})
	if normal then a.CFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0) end
	e:Emit(4)
	Debris:AddItem(a, 1)
end

local function flash(position, look)
	local p = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 110), Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Transparency = 0.1,
		CFrame = CFrame.new(position), Parent = fxFolder,
	})
	create("PointLight", {Color = Color3.fromRGB(255, 190, 110), Range = 16, Brightness = 5, Parent = p})
	tween(p, 0.06, {Transparency = 1, Size = Vector3.new(1.6, 1.6, 1.6)})
	Debris:AddItem(p, 0.08)
	local smoke = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.lookAt(position, position + look), Parent = fxFolder,
	})
	local e = create("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(200, 196, 190)),
		Size = NumberSequence.new(0.4, 1.8), Transparency = NumberSequence.new(0.55, 1), Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(15, 15), Rate = 0, EmissionDirection = Enum.NormalId.Front, Parent = smoke,
	})
	e:Emit(6)
	Debris:AddItem(smoke, 1.2)
end

local function ejectShell(character, sideways)
	local held = character:FindFirstChild("GS_Held")
	local base = held and held:FindFirstChildWhichIsA("BasePart")
	if not base then return end
	local shell = create("Part", {
		CanCollide = true, CanQuery = false, CanTouch = false, Size = Vector3.new(0.14, 0.14, 0.34), Color = Color3.fromRGB(170, 24, 24),
		Material = Enum.Material.SmoothPlastic, CFrame = base.CFrame * CFrame.new(0, 0.2, 0), Parent = fxFolder,
	})
	create("Part", {
		CanCollide = false, CanQuery = false, Massless = true, Size = Vector3.new(0.15, 0.15, 0.08), Color = Color3.fromRGB(196, 160, 72),
		Material = Enum.Material.Metal, CFrame = shell.CFrame * CFrame.new(0, 0, 0.18), Parent = shell,
	}, {})
	local w = create("WeldConstraint", {Part0 = shell, Part1 = shell:FindFirstChildOfClass("Part"), Parent = shell})
	local right = base.CFrame.RightVector * (sideways or 1)
	shell.AssemblyLinearVelocity = right * 9 + Vector3.new(0, 10, 0)
	shell.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, 0)
	task.delay(0.45, function() if shell.Parent then sound("ShellDrop", shell, 0.4, 1) end end)
	Debris:AddItem(shell, 8)
	return w
end

local function shotSound(item, parent, isMine)
	if item.fire then
		sound("Flare", parent, 0.8, 0.9, 300)
		sound("Sizzle", parent, 0.4, 1.3, 120)
	else
		sound("Shotgun", parent, isMine and 1 or 0.9, item.id == "doublebarrel" and 0.78 or 0.9, 400)
	end
end

-- ===== firing =====
local function fire()
	local character = myCharacter()
	if not character or busy() then return end
	local e, item = held()
	if not e or item.kind ~= "gun" then return end
	local now = os.clock()
	if now - lastShot < 60 / item.rpm then return end
	local head = character:FindFirstChild("Head")
	if not head then return end
	if (e.ammo or 0) <= 0 then
		lastShot = now
		sound("Click", head, 0.6, 1.6, 40)
		if now > reloadingUntil then
			weaponRemote:FireServer("reload", e.uid)
			reloadStarted = now
			reloadingUntil = now + item.reload * (item.reloadPerShell and item.magazine or 1)
			character:SetAttribute("GS_ReloadAt", now)
		end
		return
	end
	lastShot = now
	e.ammo -= 1
	reloadingUntil = 0
	local camera = workspace.CurrentCamera
	refreshParams(character)
	local screen = aimScreenPoint()
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local target = workspace:Raycast(ray.Origin, ray.Direction * (item.range + 40), rayParams)
	local aimPoint = target and target.Position or (ray.Origin + ray.Direction * item.range)
	local origin = head.Position
	local look = CFrame.lookAt(origin, aimPoint)
	seedCount += 1
	local seed = seedBase + seedCount
	local spread = currentSpread(item, character)
	local muzzle = muzzleOf(character, look.LookVector)
	for _, dir in ipairs(ItemData.Pellets(item, look, seed, spread)) do
		local hit = workspace:Raycast(origin, dir * item.range, rayParams)
		local endPos = hit and hit.Position or (origin + dir * item.range)
		tracer(muzzle, endPos, item.fire and Color3.fromRGB(255, 90, 60) or nil)
		if hit then puff(hit.Position, hit.Normal) end
	end
	weaponRemote:FireServer("fire", e.uid, look, seed, aiming)
	flash(muzzle, look.LookVector)
	shotSound(item, head, true)
	kick = math.min(kick + item.recoil * 0.9, 30)
	character:SetAttribute("GS_RecoilAt", now)
	-- the view jumps a little
	camera.FieldOfView += item.recoil * 0.25
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.CameraOffset = Vector3.new(math.random(-10, 10) / 100, item.recoil * 0.025, 0)
		task.delay(0.08, function() if hum.Parent then hum.CameraOffset = Vector3.zero end end)
	end
	if item.pump then
		task.delay(0.32, function()
			sound("Rack", head, 0.6, 1.1, 60)
			character:SetAttribute("GS_PumpAt", os.clock())
			ejectShell(character)
		end)
	end
end

local function reload()
	local character = myCharacter()
	if not character or busy() then return end
	local e, item = held()
	if not e or item.kind ~= "gun" or (e.ammo or 0) >= item.magazine then return end
	local now = os.clock()
	if now < reloadingUntil then return end
	weaponRemote:FireServer("reload", e.uid)
	reloadStarted = now
	reloadingUntil = now + item.reload * (item.reloadPerShell and (item.magazine - (e.ammo or 0)) or 1)
	character:SetAttribute("GS_ReloadAt", now)
	character:SetAttribute("GS_ReloadDur", reloadingUntil - now)
end

local function swing()
	local character = myCharacter()
	if not character or busy() then return end
	local e, item = held()
	if not e or item.kind ~= "melee" then return end
	local now = os.clock()
	if now - lastSwing < item.cooldown then return end
	lastSwing = now
	character:SetAttribute("GS_AttackStart", now)
	local camera = workspace.CurrentCamera
	weaponRemote:FireServer("swing", e.uid, camera.CFrame.LookVector)
	local head = character:FindFirstChild("Head")
	sound("Swing", head, 0.5, item.id == "knife" and 1.4 or 1, 40)
	if item.stun then sound("ShockWhoosh", head, 0.35, 1.2, 50) end
end

local function setAim(value)
	local character = myCharacter()
	local _, item = held()
	if value and (not character or not item or item.kind ~= "gun" or busy()) then value = false end
	if value == aiming then return end
	aiming = value
	local camera = workspace.CurrentCamera
	if aiming then
		baseFov = baseFov or camera.FieldOfView
		tween(camera, 0.15, {FieldOfView = baseFov - 16})
		if not TOUCH then UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end
	else
		if baseFov then tween(camera, 0.15, {FieldOfView = baseFov}) end
		if not TOUCH and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and not player:GetAttribute("GS_ShiftLock") then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
	if character then character:SetAttribute("GS_Aim", aiming or nil) end
end

-- ===== input =====
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local _, item = held()
	if not item then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if item.kind == "gun" then fire() elseif item.kind == "melee" then swing() end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and item.kind == "gun" then
		setAim(true)
	elseif input.KeyCode == Enum.KeyCode.R and item.kind == "gun" then
		reload()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then setAim(false) end
end)
if clientAction then
	clientAction.Event:Connect(function(action)
		local _, item = held()
		if not item then return end
		if action == "use" then
			if item.kind == "gun" then fire() elseif item.kind == "melee" then swing() end
		elseif action == "aim" then
			setAim(not aiming)
		elseif action == "reload" then
			reload()
		end
	end)
end

-- ===== every frame =====
RunService.RenderStepped:Connect(function(dt)
	local character = myCharacter()
	local e, item = held()
	local gun = character and item and item.kind == "gun" and not busy()
	gui.Enabled = gun == true
	player:SetAttribute("GS_Crosshair", gun == true or nil)
	if not gun then
		if aiming then setAim(false) end
		return
	end
	local camera = workspace.CurrentCamera
	local point = aimScreenPoint()
	cross.Position = UDim2.fromOffset(point.X, point.Y)
	kick = math.max(0, kick - dt * 40)
	local spread = currentSpread(item, character)
	local fov = math.rad(camera.FieldOfView / 2)
	local radius = math.tan(math.rad(spread)) / math.tan(fov) * (camera.ViewportSize.Y / 2)
	radius = math.max(radius, 6) + kick
	ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
	for i, t in pairs(ticks) do
		local a = math.rad(i * 90 - 90)
		t.Position = UDim2.new(0.5, math.cos(a) * (radius + 5), 0.5, math.sin(a) * (radius + 5))
	end
	ringStroke.Color = aiming and Color3.fromRGB(255, 255, 255) or INK
	ringStroke.Transparency = aiming and 0 or 0.15
	-- aiming turns the body to where the camera looks
	if aiming then
		local root = character:FindFirstChild("HumanoidRootPart")
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if root and flat.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end
	-- ammo panel
	local spare = 0
	for _, other in ipairs(bag.items) do
		if other.id == item.ammo then spare += other.n end
	end
	gunName.Text = item.name
	local loaded = e.ammo or 0
	ammoText.Text = string.format('<font color="#%s">%d</font><font size="18" color="#8a827c"> / %d   |   %d</font>',
		loaded > 0 and "ECE6DE" or "E12828", loaded, item.magazine, spare)
	local now = os.clock()
	if now < reloadingUntil then
		reloadBar.Size = UDim2.new(math.clamp((now - reloadStarted) / math.max(reloadingUntil - reloadStarted, 0.01), 0, 1), -3, 0, 2)
	else
		reloadBar.Size = UDim2.new(0, 0, 0, 2)
	end
end)

-- ===== what the server says =====
weaponRemote.OnClientEvent:Connect(function(kind, a, b, c, d)
	local myChar = player.Character
	if kind == "hits" then
		local best = "hit"
		local total = 0
		for _, r in ipairs(a) do
			total += r[2] or 0
			if r[1] == "kill" then best = "kill" elseif r[1] == "head" and best ~= "kill" then best = "head"
			elseif r[1] == "immune" and best == "hit" and total == 0 then best = "immune" end
		end
		if best == "immune" then
			flashMarks(DIM, "NO EFFECT")
		else
			flashMarks(best == "kill" and BRIGHT or (best == "head" and AMBER or INK), best == "kill" and "KILL" or tostring(total))
		end
	elseif kind == "noammo" then
		local item = ItemData.Get(a)
		hitText.Text = "no " .. (item and item.name:lower() or "ammo")
		hitText.TextColor3 = BRIGHT
		hitText.TextTransparency = 0
		tween(hitText, 1.2, {TextTransparency = 1})
		reloadingUntil = 0
	elseif kind == "shot" then
		-- someone else's shot: their tracers, their flash, their bang
		local character, itemId, startPos, ends = a, b, c, d
		if character == myChar or typeof(character) ~= "Instance" then return end
		local item = ItemData.Get(itemId)
		if not item then return end
		local look = (#ends > 0 and (ends[1] - startPos).Unit) or Vector3.new(0, 0, -1)
		local muzzle = muzzleOf(character, look)
		for _, p in ipairs(ends) do tracer(muzzle, p, item.fire and Color3.fromRGB(255, 90, 60) or nil) end
		flash(muzzle, look)
		shotSound(item, character:FindFirstChild("Head") or character.PrimaryPart, false)
		if item.pump then task.delay(0.32, function() if character.Parent then sound("Rack", character:FindFirstChild("Head"), 0.5, 1.1, 60) ejectShell(character) end end) end
	elseif kind == "reload" then
		local character, itemId, mode = a, b, c
		if typeof(character) ~= "Instance" then return end
		local head = character:FindFirstChild("Head")
		if mode == "full" then
			-- break it open, the old shells fly out
			sound("Click", head, 0.7, 0.8, 50)
			task.delay(0.25, function() if character.Parent then ejectShell(character, -1) ejectShell(character, 1) end end)
		else
			sound("Click", head, 0.5, 1.2, 40)
		end
	elseif kind == "shellin" then
		local head = typeof(a) == "Instance" and a:FindFirstChild("Head")
		if head then sound("ShellIn", head, 0.6, 1.1, 40) end
	elseif kind == "reloaded" then
		local character, itemId = a, b
		local head = typeof(character) == "Instance" and character:FindFirstChild("Head")
		if head then
			local item = ItemData.Get(itemId)
			if item and item.pump then sound("Rack", head, 0.6, 1, 50) else
				sound("ShellIn", head, 0.6, 1, 40)
				task.delay(0.2, function() sound("Click", head, 0.7, 0.7, 50) end)
			end
		end
		if character == myChar then
			reloadingUntil = 0
			if myChar then myChar:SetAttribute("GS_ReloadAt", nil) end
		end
	elseif kind == "swing" then
		local character, itemId = a, b
		if character == myChar or typeof(character) ~= "Instance" then return end
		local item = ItemData.Get(itemId)
		sound("Swing", character:FindFirstChild("Head"), 0.5, item and item.id == "knife" and 1.4 or 1, 40)
	elseif kind == "impact" then
		local model, position, itemId = a, b, c
		local item = ItemData.Get(itemId)
		if typeof(position) ~= "Vector3" or not item then return end
		local anchor = create("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = CFrame.new(position), Parent = fxFolder,
		})
		Debris:AddItem(anchor, 4)
		if item.sound == "metal" then sound("MetalHit", anchor, 0.7, 1.1, 60) end
		sound("BloodHit", anchor, 0.7, 1, 60)
		if item.stun then
			sound("Shock", anchor, 0.8, 1, 60)
			local e = create("ParticleEmitter", {
				Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(140, 190, 255)),
				LightEmission = 1, Size = NumberSequence.new(0.35, 0), Lifetime = NumberRange.new(0.15, 0.35), Speed = NumberRange.new(8, 18),
				SpreadAngle = Vector2.new(180, 180), Rate = 0, Parent = anchor,
			})
			e:Emit(26)
			create("PointLight", {Color = Color3.fromRGB(140, 190, 255), Range = 10, Brightness = 4, Parent = anchor})
		end
	end
end)

player.CharacterAdded:Connect(function()
	aiming = false
	reloadingUntil = 0
	local camera = workspace.CurrentCamera
	if baseFov and camera then camera.FieldOfView = baseFov end
end)
]=]},
	{name = "Weapons", class = "Script", where = "ServerScriptService", source = [=[
-- Guns and melee, decided on the server. The client (WeaponClient) shows the shot at once; the server
-- replays it from the same seed (ItemData.Pellets), so the pellets that do damage are the ones you saw.
--   fire   (uid, origin CFrame, seed, aiming)   - ammo, fire rate, spread and range are checked here
--   reload (uid)                                - loads from the bag's ammo, shell by shell for pump guns
--   swing  (uid, look direction)                - melee: the closest thing in front, on the closest limb
-- Damage to creatures goes through ServerStorage.GS_MonsterHealth, to people through their armor first.
-- People only hurt people when PvP is on (admin panel) - the infected can always be hurt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Svc = require(ServerStorage:WaitForChild("GS_ItemService"))
local FallDamageController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FallDamageController"))
local ItemData = Svc.ItemData

local remote = ReplicatedStorage:FindFirstChild("GS_Weapon")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GS_Weapon"
	remote.Parent = ReplicatedStorage
end

local LIMB = {
	Head = "Head", Torso = "Torso", HumanoidRootPart = "Torso",
	["Left Arm"] = "LeftArm", ["Right Arm"] = "RightArm", ["Left Leg"] = "LeftLeg", ["Right Leg"] = "RightLeg",
}

local function serverNow() return workspace:GetServerTimeNow() end

local function monsterApi(...)
	local api = ServerStorage:FindFirstChild("GS_MonsterHealth")
	if not api then return 0, false end
	local ok, dealt, killed, severed, head = pcall(api.Invoke, api, ...)
	if not ok then return 0, false end
	return dealt or 0, killed, severed, head
end

local function monsterControl(...)
	local control = ServerStorage:FindFirstChild("GS_MonsterControl")
	if control then pcall(control.Invoke, control, ...) end
end

-- a loud noise every monster can hear (Monsters' hearing system)
local function noise(character, radius)
	monsterControl("Noise", character, radius, 1.5)
end

-- the model a hit part belongs to, and what kind of thing it is
local function classify(part)
	local monsters = workspace:FindFirstChild("Monsters")
	local npcs = workspace:FindFirstChild("NPCs")
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model.Parent == monsters then
			if model:GetAttribute("MonsterId") and not model:GetAttribute("GS_Dead") then return model, "monster" end
			return nil
		end
		if model.Parent == npcs then return model, "npc" end
		if Players:GetPlayerFromCharacter(model) then return model, "player" end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function canHurtPerson(attacker, victim)
	if victim == attacker then return false end
	if victim:GetAttribute("Infected") then return true end
	if attacker:GetAttribute("Infected") then return true end
	return Svc.PvP()
end

-- a person (player or npc) hit on one body part
local function hurtPerson(attackerPlayer, victim, partKey, damage, cause, opts)
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	local dealt, blocked = Svc.Absorb(victim, partKey, damage, opts and opts.type or "bullet")
	victim:SetAttribute("LastDamageCause", cause)
	victim:SetAttribute("LastDamageTime", serverNow())
	humanoid:TakeDamage(dealt)
	if humanoid.Health <= 0 then
		victim:SetAttribute("DeathCause", cause)
		return true
	end
	-- a heavy hit breaks something, unless the armor took it
	if not blocked and dealt >= (opts and opts.woundAt or 18) and partKey ~= "Torso" then
		local level = victim:GetAttribute("Injury_" .. partKey) or 0
		if level < 2 then FallDamageController.Injure(victim, partKey, level + 1) end
	end
	if opts and opts.bleed then FallDamageController.AddBleeding(victim, 0.35, 10) end
	if opts and opts.stun then
		FallDamageController.Ragdoll(victim, opts.stun * 0.7, 0.2)
		victim:SetAttribute("GS_Shocked", serverNow())
	end
	return false
end

-- ===== guns =====
local lastShot = {}
local reloading = {}

local function worldParams(shooter)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {shooter}
	for _, name in ipairs({"GS_Items", "GS_Traps", "SpiderWebs", "GS_Hallucinations", "PS_Blood", "GS_Tentacles", "GS_FX"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(ignore, f) end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function burn(model, attacker, seconds)
	if model:GetAttribute("GS_Burning") then return end
	model:SetAttribute("GS_Burning", serverNow() + seconds)
	task.spawn(function()
		for _ = 1, seconds do
			task.wait(1)
			if not model.Parent or model:GetAttribute("GS_Dead") then break end
			monsterApi("damage", model, "Torso", 7, "fire", attacker)
		end
		if model.Parent then model:SetAttribute("GS_Burning", nil) end
	end)
end

local function fire(player, uid, origin, seed, aiming)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not head or not root then return end
	if character:GetAttribute("Ragdolled") or character:GetAttribute("Infected") then return end
	if typeof(origin) ~= "CFrame" or typeof(seed) ~= "number" then return end
	local entry, item = Svc.Held(player)
	if not entry or entry.uid ~= uid or item.kind ~= "gun" then return end
	local now = os.clock()
	if now - (lastShot[player] or 0) < 60 / item.rpm * 0.85 then return end
	if (entry.ammo or 0) <= 0 then return end
	-- the shot must come from about where the head is
	if (origin.Position - head.Position).Magnitude > 14 then return end
	lastShot[player] = now
	reloading[player] = nil
	entry.ammo -= 1
	Svc.Sync(player)

	local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 3
	local spread = (aiming and item.aimSpread or item.spread) * (moving and 1.3 or 1)
	local startPos = origin.Position
	local look = CFrame.lookAt(startPos, startPos + origin.LookVector)
	local params = worldParams(character)
	local ends = {}
	local hits = {} -- model -> {damage, part}
	for _, dir in ipairs(ItemData.Pellets(item, look, seed, spread)) do
		local result = workspace:Raycast(startPos, dir * item.range, params)
		local hitPos = result and result.Position or (startPos + dir * item.range)
		table.insert(ends, hitPos)
		if result then
			local model, kind = classify(result.Instance)
			if model then
				local dist = (hitPos - startPos).Magnitude
				local falloff = math.clamp(1 - math.max(0, dist - 18) / item.range, 0.35, 1)
				local h = hits[model] or {kind = kind, damage = 0, parts = {}, point = hitPos}
				local partName = result.Instance.Name
				local dmg = item.damage * falloff * (partName == "Head" and (item.headMult or 1) or 1)
				h.damage += dmg
				h.parts[partName] = (h.parts[partName] or 0) + dmg
				hits[model] = h
			end
		end
	end
	remote:FireAllClients("shot", character, item.id, startPos, ends)
	noise(character, item.fire and 110 or 160)

	local report = {}
	for model, h in pairs(hits) do
		-- the body part that took the most pellets gets the whole volley
		local bestPart, bestDmg = "Torso", 0
		for name, d in pairs(h.parts) do
			if d > bestDmg then bestPart, bestDmg = name, d end
		end
		if h.kind == "monster" then
			local dealt, killed, _, headshot = monsterApi("damage", model, bestPart, h.damage, item.fire and "fire" or "bullet", player)
			if dealt > 0 then
				table.insert(report, {killed and "kill" or (headshot and "head" or "hit"), math.floor(dealt)})
				if item.knockback then
					local mroot = model:FindFirstChild("HumanoidRootPart")
					if mroot then
						local push = (mroot.Position - startPos)
						push = Vector3.new(push.X, 0, push.Z)
						if push.Magnitude > 0.1 then
							mroot.AssemblyLinearVelocity += push.Unit * item.knockback * math.clamp(h.damage / 60, 0.3, 1)
						end
					end
				end
				if item.fire then burn(model, player, 5) end
			else
				table.insert(report, {"immune", 0})
			end
		elseif canHurtPerson(character, model) then
			local killed = hurtPerson(player, model, LIMB[bestPart] or "Torso", h.damage, "SHOT", {woundAt = 22})
			table.insert(report, {killed and "kill" or "hit", math.floor(h.damage)})
		end
	end
	if #report > 0 then remote:FireClient(player, "hits", report) end
end

local function reload(player, uid)
	local entry, item = Svc.Held(player)
	if not entry or entry.uid ~= uid or item.kind ~= "gun" then return end
	if reloading[player] then return end
	if (entry.ammo or 0) >= item.magazine then return end
	if Svc.CountOf(player, item.ammo) <= 0 then
		remote:FireClient(player, "noammo", item.ammo)
		return
	end
	local token = {}
	reloading[player] = token
	local character = player.Character
	remote:FireAllClients("reload", character, item.id, item.reloadPerShell and "shell" or "full")
	task.spawn(function()
		while reloading[player] == token do
			task.wait(item.reload)
			local e, it = Svc.Held(player)
			if reloading[player] ~= token or not e or e.uid ~= uid or not it then break end
			local need = item.magazine - (e.ammo or 0)
			if need <= 0 then break end
			local take = item.reloadPerShell and 1 or need
			local got = Svc.TakeId(player, item.ammo, take)
			if got <= 0 then break end
			e.ammo = (e.ammo or 0) + got
			Svc.Sync(player)
			if item.reloadPerShell then
				remote:FireAllClients("shellin", character, item.id)
			else
				break
			end
			if (e.ammo or 0) >= item.magazine then break end
		end
		if reloading[player] == token then reloading[player] = nil end
		remote:FireAllClients("reloaded", character, item.id)
	end)
end

-- ===== melee =====
local lastSwing = {}
local swingParams = OverlapParams.new()
swingParams.FilterType = Enum.RaycastFilterType.Exclude

local function swing(player, uid, look)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or character:GetAttribute("Ragdolled") then return end
	local entry, item = Svc.Held(player)
	if not entry or entry.uid ~= uid or item.kind ~= "melee" then return end
	local now = os.clock()
	if now - (lastSwing[player] or 0) < item.cooldown * 0.85 then return end
	lastSwing[player] = now
	if typeof(look) ~= "Vector3" or look.Magnitude < 0.1 then look = root.CFrame.LookVector end
	look = look.Unit
	remote:FireAllClients("swing", character, item.id)
	noise(character, 35)
	task.wait(0.18) -- the swing lands a moment after it starts
	if not character.Parent or humanoid.Health <= 0 then return end
	local center = root.Position + Vector3.new(0, 0.8, 0) + look * (item.reach * 0.55)
	swingParams.FilterDescendantsInstances = {character}
	local best, bestKind, bestPart, bestScore = nil, nil, nil, math.huge
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, item.reach * 0.6, swingParams)) do
		local model, kind = classify(part)
		if model and model ~= character then
			local offset = part.Position - root.Position
			local flatOff = Vector3.new(offset.X, 0, offset.Z)
			local dot = flatOff.Magnitude > 0.1 and flatOff.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) or 1
			if dot > 0.2 and offset.Magnitude <= item.reach + 1 then
				local score = (part.Position - center).Magnitude
				if score < bestScore and (LIMB[part.Name] or kind == "monster") then
					best, bestKind, bestPart, bestScore = model, kind, part, score
				end
			end
		end
	end
	if not best then return end
	local report
	if bestKind == "monster" then
		local dealt, killed, _, headshot = monsterApi("damage", best, bestPart.Name, item.damage * (item.limbMult or 1),
			item.stun and "shock" or "melee", player)
		report = {killed and "kill" or (headshot and "head" or "hit"), math.floor(dealt)}
		if item.stun and dealt > 0 then monsterControl("Stun", best, item.stun) end
		monsterControl("Struck", best, character)
	elseif canHurtPerson(character, best) then
		local killed = hurtPerson(player, best, LIMB[bestPart.Name] or "Torso", item.damage, "BEATEN",
			{type = "melee", bleed = item.bleed, stun = item.stun, woundAt = 20})
		report = {killed and "kill" or "hit", item.damage}
	end
	remote:FireAllClients("impact", best, bestPart.Position, item.id)
	if report then remote:FireClient(player, "hits", {report}) end
end

-- ===== requests =====
remote.OnServerEvent:Connect(function(player, action, uid, a, b, c)
	if typeof(uid) ~= "string" then return end
	if action == "fire" then
		fire(player, uid, a, b, c == true)
	elseif action == "reload" then
		reload(player, uid)
	elseif action == "swing" then
		swing(player, uid, a)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastShot[player], reloading[player], lastSwing[player] = nil, nil, nil
end)
]=]},
	{name = "Wearables", class = "ModuleScript", where = "Modules", source = [=[
-- Armor as it looks on a body: every piece is built onto the R6 parts it covers and welded to them,
-- so it moves with the arms, legs and head like real gear.
--   Wearables.Attach(id, character) -> the Model it put on the character (name "GS_Wear_<id>")
--   Wearables.Display(id, model)    -> fills `model` with the same gear on an invisible body (shop / wheel icons)
-- Every GUI in here is named GS_* (the client anticheat ignores those on other people).
local Wearables = {}

local M = Enum.Material
local A, R = CFrame.Angles, math.rad
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball

-- the standard R6 body, relative to the torso (used for the display dummy)
local BODY = {
	Head = {size = Vector3.new(2, 1, 1), cf = CFrame.new(0, 1.5, 0)},
	Torso = {size = Vector3.new(2, 2, 1), cf = CFrame.new()},
	["Left Arm"] = {size = Vector3.new(1, 2, 1), cf = CFrame.new(-1.5, 0, 0)},
	["Right Arm"] = {size = Vector3.new(1, 2, 1), cf = CFrame.new(1.5, 0, 0)},
	["Left Leg"] = {size = Vector3.new(1, 2, 1), cf = CFrame.new(-0.5, -2, 0)},
	["Right Leg"] = {size = Vector3.new(1, 2, 1), cf = CFrame.new(0.5, -2, 0)},
}

local function piece(holder, bodyPart, localCF, size, color, material, shape, transparency)
	local p = Instance.new("Part")
	p.Name = "GS_Armor"
	p.Size = size
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	if transparency then p.Transparency = transparency end
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, true, true
	p.Anchored = false
	p.CFrame = bodyPart.CFrame * localCF
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = p
	weld.Parent = p
	p.Parent = holder
	return p
end

local function label(part, face, lines, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GS_Label"
	gui.Face = face
	gui.CanvasSize = Vector2.new(part.Size.X * 100, part.Size.Y * 100)
	gui.LightInfluence = 1
	gui.Parent = part
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = gui
	for _, line in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, line.h or 0.5, 0)
		t.Font = line.font or Enum.Font.GothamBlack
		t.Text = line.text
		t.TextScaled = true
		t.TextColor3 = color or Color3.fromRGB(232, 232, 228)
		t.Parent = gui
	end
	return gui
end

-- which side is "outside" for a limb
local function outward(name)
	return (name:find("Left") and -1) or 1
end

local BUILD = {}

-- ===== riot helmet: shell, tinted visor on hinges, neck guard, chin strap =====
BUILD.helmet = function(h, c)
	local head = c.Head
	local shell = Color3.fromRGB(34, 38, 50)
	piece(h, head, CFrame.new(0, 0.26, 0.03), Vector3.new(1.52, 1.28, 1.58), shell, M.SmoothPlastic, BALL)
	piece(h, head, CFrame.new(0, -0.02, 0.03) * A(0, 0, R(90)), Vector3.new(0.12, 1.58, 1.64), shell, M.SmoothPlastic, CYL)
	piece(h, head, CFrame.new(0, -0.3, 0.7), Vector3.new(1.3, 0.34, 0.12), shell, M.SmoothPlastic)
	local visor = piece(h, head, CFrame.new(0, 0.06, -0.8) * A(R(-12), 0, 0), Vector3.new(1.34, 0.72, 0.06),
		Color3.fromRGB(150, 175, 200), M.Glass, nil, 0.45)
	visor.Reflectance = 0.2
	piece(h, head, CFrame.new(0, 0.45, -0.76), Vector3.new(1.4, 0.1, 0.12), Color3.fromRGB(20, 20, 24), M.Metal)
	for _, s in ipairs({-1, 1}) do
		piece(h, head, CFrame.new(s * 0.72, 0.18, -0.55) * A(0, 0, R(90)), Vector3.new(0.1, 0.26, 0.26), Color3.fromRGB(150, 152, 158), M.Metal, CYL)
		piece(h, head, CFrame.new(s * 0.6, -0.35, -0.15) * A(R(20), 0, 0), Vector3.new(0.05, 0.55, 0.08), Color3.fromRGB(28, 28, 30), M.Fabric)
	end
	piece(h, head, CFrame.new(0, -0.62, -0.32), Vector3.new(1.05, 0.06, 0.08), Color3.fromRGB(28, 28, 30), M.Fabric)
end

-- ===== gas mask: rubber face piece, two lenses in rims, a canister under the chin, head straps =====
BUILD.gasmask = function(h, c)
	local head = c.Head
	local rubber = Color3.fromRGB(38, 39, 41)
	piece(h, head, CFrame.new(0, 0.02, -0.46), Vector3.new(1.12, 1.12, 0.5), rubber, M.Rubber, BALL)
	piece(h, head, CFrame.new(0, -0.32, -0.56), Vector3.new(0.72, 0.52, 0.42), rubber, M.Rubber, BALL)
	for _, s in ipairs({-1, 1}) do
		local eye = CFrame.new(s * 0.24, 0.13, -0.68) * A(0, R(s * 12), 0) * A(0, R(90), 0)
		piece(h, head, eye, Vector3.new(0.1, 0.36, 0.36), Color3.fromRGB(112, 114, 118), M.Metal, CYL)
		local lens = piece(h, head, eye * CFrame.new(-0.02, 0, 0), Vector3.new(0.1, 0.28, 0.28), Color3.fromRGB(90, 115, 110), M.Glass, CYL, 0.3)
		lens.Reflectance = 0.25
		piece(h, head, CFrame.new(s * 0.63, 0.12, 0.02), Vector3.new(0.05, 0.14, 1.05), Color3.fromRGB(56, 54, 50), M.Fabric)
		piece(h, head, CFrame.new(s * 0.55, -0.28, 0.05), Vector3.new(0.05, 0.1, 0.9), Color3.fromRGB(56, 54, 50), M.Fabric)
	end
	piece(h, head, CFrame.new(0, 0.62, 0.02), Vector3.new(0.9, 0.05, 0.14), Color3.fromRGB(56, 54, 50), M.Fabric)
	local filter = CFrame.new(0, -0.5, -0.82) * A(R(40), 0, 0)
	piece(h, head, filter * A(0, R(90), 0), Vector3.new(0.42, 0.42, 0.42), Color3.fromRGB(78, 88, 56), M.Metal, CYL)
	for _, z in ipairs({-0.08, 0.1}) do
		piece(h, head, filter * CFrame.new(0, 0, z) * A(0, R(90), 0), Vector3.new(0.05, 0.46, 0.46), Color3.fromRGB(58, 66, 42), M.Metal, CYL)
	end
	piece(h, head, filter * CFrame.new(0, 0, -0.22) * A(0, R(90), 0), Vector3.new(0.03, 0.34, 0.34), Color3.fromRGB(24, 24, 24), M.Metal, CYL)
end

-- ===== padded jacket: quilted body, collar, sleeves over the upper arms, zip =====
BUILD.jacket = function(h, c)
	local col, dark = Color3.fromRGB(62, 70, 48), Color3.fromRGB(44, 50, 34)
	piece(h, c.Torso, CFrame.new(0, 0, 0), Vector3.new(2.12, 2.04, 1.12), col, M.Fabric)
	for i = 0, 3 do piece(h, c.Torso, CFrame.new(0, 0.7 - i * 0.45, 0), Vector3.new(2.15, 0.05, 1.15), dark, M.Fabric) end
	piece(h, c.Torso, CFrame.new(0, 1.02, 0), Vector3.new(1.3, 0.28, 1.18), dark, M.Fabric)
	piece(h, c.Torso, CFrame.new(0, 0, -0.575), Vector3.new(0.07, 1.95, 0.04), Color3.fromRGB(28, 28, 30), M.Metal)
	for _, name in ipairs({"Left Arm", "Right Arm"}) do
		local arm = c[name]
		if arm then
			piece(h, arm, CFrame.new(0, 0.35, 0), Vector3.new(1.1, 1.35, 1.1), col, M.Fabric)
			piece(h, arm, CFrame.new(0, -0.32, 0), Vector3.new(1.12, 0.12, 1.12), dark, M.Fabric)
		end
	end
end

-- ===== kevlar vest: front and back panels, sides, shoulder straps, pouches, a name patch =====
BUILD.vest = function(h, c)
	local col, panel = Color3.fromRGB(30, 32, 30), Color3.fromRGB(44, 46, 44)
	local t = c.Torso
	piece(h, t, CFrame.new(0, 0.12, -0.6), Vector3.new(2.06, 1.62, 0.22), col, M.Fabric)
	piece(h, t, CFrame.new(0, 0.12, 0.6), Vector3.new(2.06, 1.62, 0.22), col, M.Fabric)
	for _, s in ipairs({-1, 1}) do
		piece(h, t, CFrame.new(s * 1.04, 0.05, 0), Vector3.new(0.14, 1.3, 1.24), col, M.Fabric)
		piece(h, t, CFrame.new(s * 0.62, 1.03, 0), Vector3.new(0.48, 0.12, 1.32), col, M.Fabric)
	end
	piece(h, t, CFrame.new(0, 0.3, -0.72), Vector3.new(1.4, 1.0, 0.04), panel, M.Fabric)
	for i = -1, 1 do
		piece(h, t, CFrame.new(i * 0.56, -0.48, -0.8), Vector3.new(0.44, 0.46, 0.22), Color3.fromRGB(72, 82, 52), M.Fabric)
		piece(h, t, CFrame.new(i * 0.56, -0.28, -0.9), Vector3.new(0.44, 0.08, 0.05), Color3.fromRGB(56, 62, 40), M.Fabric)
	end
	piece(h, t, CFrame.new(0, 0.62, -0.745), Vector3.new(0.95, 0.24, 0.02), Color3.fromRGB(205, 200, 190), M.SmoothPlastic)
end

-- ===== leg guards: knee cups, shin and thigh plates, straps =====
BUILD.legguards = function(h, c)
	for _, name in ipairs({"Left Leg", "Right Leg"}) do
		local leg = c[name]
		if leg then
			piece(h, leg, CFrame.new(0, -0.35, -0.53), Vector3.new(0.9, 1.05, 0.16), Color3.fromRGB(64, 66, 70), M.Metal)
			piece(h, leg, CFrame.new(0, 0.2, -0.52), Vector3.new(0.78, 0.62, 0.42), Color3.fromRGB(58, 60, 64), M.SmoothPlastic, BALL)
			piece(h, leg, CFrame.new(0, 0.66, -0.53), Vector3.new(0.88, 0.5, 0.12), Color3.fromRGB(64, 66, 70), M.Metal)
			for _, y in ipairs({-0.72, -0.1, 0.62}) do
				piece(h, leg, CFrame.new(0, y, 0), Vector3.new(1.06, 0.1, 1.06), Color3.fromRGB(28, 28, 30), M.Fabric)
			end
		end
	end
end

-- ===== arm guards: forearm and outer plates, elbow cups, straps (light plastic: breaks sooner) =====
BUILD.armguards = function(h, c)
	local plate, strap = Color3.fromRGB(88, 92, 80), Color3.fromRGB(150, 90, 30)
	for _, name in ipairs({"Left Arm", "Right Arm"}) do
		local arm = c[name]
		if arm then
			local s = outward(name)
			piece(h, arm, CFrame.new(0, -0.42, -0.53), Vector3.new(0.96, 0.95, 0.12), plate, M.SmoothPlastic)
			piece(h, arm, CFrame.new(s * 0.53, -0.42, 0), Vector3.new(0.12, 0.95, 0.96), plate, M.SmoothPlastic)
			piece(h, arm, CFrame.new(s * 0.1, 0.08, 0.46), Vector3.new(0.72, 0.56, 0.4), Color3.fromRGB(70, 74, 64), M.SmoothPlastic, BALL)
			for _, y in ipairs({-0.8, -0.1}) do
				piece(h, arm, CFrame.new(0, y, 0), Vector3.new(1.08, 0.1, 1.08), strap, M.Fabric)
			end
		end
	end
end

-- ===== SCG: black, heavy, stenciled =====
local SCG_BLACK = Color3.fromRGB(20, 20, 22)
local SCG_GREY = Color3.fromRGB(56, 58, 62)

BUILD.scg_helmet = function(h, c)
	local head = c.Head
	piece(h, head, CFrame.new(0, 0.22, 0.04), Vector3.new(1.58, 1.4, 1.64), SCG_BLACK, M.SmoothPlastic, BALL)
	piece(h, head, CFrame.new(0, -0.1, 0.4), Vector3.new(1.5, 0.9, 0.9), SCG_BLACK, M.SmoothPlastic)
	-- full face shield, dark and sealed
	local shield = piece(h, head, CFrame.new(0, 0.02, -0.8), Vector3.new(1.3, 1.0, 0.08), Color3.fromRGB(16, 22, 30), M.Glass, nil, 0.15)
	shield.Reflectance = 0.35
	piece(h, head, CFrame.new(0, 0.54, -0.76), Vector3.new(1.46, 0.12, 0.16), SCG_GREY, M.Metal)
	piece(h, head, CFrame.new(0, -0.55, -0.62), Vector3.new(1.2, 0.42, 0.34), SCG_BLACK, M.SmoothPlastic)
	for _, s in ipairs({-1, 1}) do
		-- twin filters at the jaw
		local f = CFrame.new(s * 0.46, -0.58, -0.74) * A(R(30), R(s * -25), 0)
		piece(h, head, f * A(0, R(90), 0), Vector3.new(0.34, 0.32, 0.32), SCG_GREY, M.Metal, CYL)
		piece(h, head, f * CFrame.new(0, 0, -0.18) * A(0, R(90), 0), Vector3.new(0.04, 0.26, 0.26), SCG_BLACK, M.Metal, CYL)
		-- side rails and the hinge discs
		piece(h, head, CFrame.new(s * 0.8, 0.2, -0.05), Vector3.new(0.06, 0.12, 0.9), SCG_GREY, M.Metal)
		piece(h, head, CFrame.new(s * 0.78, 0.0, -0.55) * A(0, 0, R(90)), Vector3.new(0.08, 0.3, 0.3), SCG_GREY, M.Metal, CYL)
	end
	local lamp = piece(h, head, CFrame.new(0.72, 0.36, -0.3), Vector3.new(0.08, 0.08, 0.08), Color3.fromRGB(255, 40, 40), M.Neon, BALL)
	lamp.Name = "GS_ArmorLamp"
	local back = piece(h, head, CFrame.new(0, 0.32, 0.83), Vector3.new(0.9, 0.34, 0.02), SCG_BLACK, M.SmoothPlastic)
	label(back, Enum.NormalId.Back, {{text = "SCG", h = 1}})
end

BUILD.scg_vest = function(h, c)
	local t = c.Torso
	local front = piece(h, t, CFrame.new(0, 0.1, -0.64), Vector3.new(2.16, 1.72, 0.34), SCG_BLACK, M.SmoothPlastic)
	piece(h, t, CFrame.new(0, 0.1, 0.64), Vector3.new(2.16, 1.72, 0.34), SCG_BLACK, M.SmoothPlastic)
	for _, s in ipairs({-1, 1}) do
		piece(h, t, CFrame.new(s * 1.09, -0.1, 0), Vector3.new(0.2, 1.1, 1.36), SCG_GREY, M.Fabric)
		piece(h, t, CFrame.new(s * 0.66, 1.08, 0), Vector3.new(0.62, 0.2, 1.46), SCG_BLACK, M.SmoothPlastic)
	end
	piece(h, t, CFrame.new(0, 1.16, 0), Vector3.new(1.5, 0.34, 1.3), SCG_BLACK, M.SmoothPlastic)
	piece(h, t, CFrame.new(0, -1.18, -0.6), Vector3.new(0.9, 0.55, 0.16), SCG_BLACK, M.SmoothPlastic)
	for i = 0, 3 do
		piece(h, t, CFrame.new(-0.75 + i * 0.5, -0.48, -0.9), Vector3.new(0.42, 0.52, 0.26), SCG_GREY, M.Fabric)
		piece(h, t, CFrame.new(-0.75 + i * 0.5, -0.24, -1.0), Vector3.new(0.42, 0.08, 0.06), SCG_BLACK, M.Fabric)
	end
	-- the chest plate reads SCG, the back spells it out
	local chest = piece(h, t, CFrame.new(0, 0.42, -0.82), Vector3.new(1.3, 0.56, 0.02), SCG_BLACK, M.SmoothPlastic)
	label(chest, Enum.NormalId.Front, {{text = "SCG", h = 0.7}, {text = "07 SECTOR CONTROL GUARD", h = 0.3, font = Enum.Font.GothamBold}})
	local backPlate = piece(h, t, CFrame.new(0, 0.32, 0.82), Vector3.new(1.7, 0.8, 0.02), SCG_BLACK, M.SmoothPlastic)
	label(backPlate, Enum.NormalId.Back, {{text = "SCG", h = 0.62}, {text = "07 SECTOR CONTROL GUARD", h = 0.38, font = Enum.Font.GothamBold}})
	front.Name = "GS_ArmorFront"
end

BUILD.scg_arms = function(h, c)
	for _, name in ipairs({"Left Arm", "Right Arm"}) do
		local arm = c[name]
		if arm then
			local s = outward(name)
			local pauldron = piece(h, arm, CFrame.new(s * 0.12, 0.82, 0), Vector3.new(1.3, 0.62, 1.28), SCG_BLACK, M.SmoothPlastic, BALL)
			local plate = piece(h, arm, CFrame.new(s * 0.55, 0.62, 0), Vector3.new(0.04, 0.34, 0.6), SCG_BLACK, M.SmoothPlastic)
			label(plate, s > 0 and Enum.NormalId.Right or Enum.NormalId.Left, {{text = "SCG", h = 1}})
			piece(h, arm, CFrame.new(0, 0.32, 0), Vector3.new(1.1, 0.62, 1.1), SCG_BLACK, M.SmoothPlastic)
			piece(h, arm, CFrame.new(0, -0.5, 0), Vector3.new(1.1, 0.82, 1.1), SCG_BLACK, M.SmoothPlastic)
			piece(h, arm, CFrame.new(0, -0.5, -0.57), Vector3.new(0.6, 0.6, 0.06), SCG_GREY, M.Metal)
			piece(h, arm, CFrame.new(s * 0.1, 0.02, 0.5), Vector3.new(0.7, 0.55, 0.42), SCG_GREY, M.SmoothPlastic, BALL)
			pauldron.Name = "GS_Pauldron"
		end
	end
end

BUILD.scg_legs = function(h, c)
	for _, name in ipairs({"Left Leg", "Right Leg"}) do
		local leg = c[name]
		if leg then
			piece(h, leg, CFrame.new(0, 0.52, 0), Vector3.new(1.1, 0.82, 1.1), SCG_BLACK, M.SmoothPlastic)
			piece(h, leg, CFrame.new(0, 0.02, -0.52), Vector3.new(0.86, 0.66, 0.5), SCG_GREY, M.SmoothPlastic, BALL)
			piece(h, leg, CFrame.new(0, -0.48, 0), Vector3.new(1.1, 0.72, 1.1), SCG_BLACK, M.SmoothPlastic)
			piece(h, leg, CFrame.new(0, -0.45, -0.58), Vector3.new(0.3, 0.6, 0.08), SCG_GREY, M.Metal)
			piece(h, leg, CFrame.new(0, -0.9, -0.1), Vector3.new(1.12, 0.3, 1.3), SCG_BLACK, M.Rubber)
		end
	end
end

local function bodyOf(character)
	local c = {}
	for name in pairs(BODY) do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then c[name] = p end
	end
	return c
end

function Wearables.Has(id)
	return BUILD[id] ~= nil
end

function Wearables.Attach(id, character)
	local build = BUILD[id]
	if not build then return nil end
	local c = bodyOf(character)
	if not c.Torso or not c.Head then return nil end
	local holder = Instance.new("Model")
	holder.Name = "GS_Wear_" .. id
	holder.Parent = character
	build(holder, c)
	return holder
end

-- the same gear on an invisible body, for viewports
function Wearables.Display(id, model)
	local build = BUILD[id]
	if not build then return model end
	local dummy = Instance.new("Model")
	local c = {}
	for name, spec in pairs(BODY) do
		local p = Instance.new("Part")
		p.Name = name
		p.Size = spec.size
		p.CFrame = spec.cf
		p.Anchored = true
		p.Transparency = 1
		p.Parent = dummy
		c[name] = p
	end
	build(model, c)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			for _, w in ipairs(part:GetChildren()) do
				if w:IsA("WeldConstraint") then w:Destroy() end
			end
		end
	end
	dummy:Destroy()
	return model
end

return Wearables
]=]},
}

-- only look where each script belongs: a free model somewhere else with the same name is left alone
local SEARCH = {
	ServerScriptService = {"ServerScriptService"},
	StarterPlayerScripts = {"StarterPlayer"},
	Modules = {"ReplicatedStorage"},
	ServerStorage = {"ServerStorage"},
}

local function findExisting(name, className, where)
	for _, serviceName in ipairs(SEARCH[where] or {}) do
		local service = game:GetService(serviceName)
		for _, d in ipairs(service:GetDescendants()) do
			if d.Name == name and d.ClassName == className then return d end
		end
	end
	return nil
end

local function defaultParent(where)
	if where == "ServerScriptService" then return game:GetService("ServerScriptService") end
	if where == "ServerStorage" then return game:GetService("ServerStorage") end
	if where == "StarterPlayerScripts" then
		return game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
			or game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	end
	local rs = game:GetService("ReplicatedStorage")
	local modules = rs:FindFirstChild("Modules")
	if not modules then
		modules = Instance.new("Folder")
		modules.Name = "Modules"
		modules.Parent = rs
	end
	return modules
end

local function install()
	local recording = ChangeHistoryService:TryBeginRecording("Install game scripts")
	local replaced, created = 0, 0
	for _, entry in ipairs(SCRIPTS) do
		local target = findExisting(entry.name, entry.class, entry.where)
		if target then
			replaced += 1
		else
			target = Instance.new(entry.class)
			target.Name = entry.name
			target.Parent = defaultParent(entry.where)
			created += 1
		end
		target.Source = entry.source
		print(string.format("[Installer] %s -> %s", entry.name, target:GetFullName()))
	end
	if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
	print(string.format("[Installer] done: %d replaced, %d created. Now: File -> Publish / Save.", replaced, created))
	warn("[Installer] Remember: Game Settings -> Security -> API Services + HTTP Requests ON.")
end

if plugin then
	local toolbar = plugin:CreateToolbar("Game scripts")
	local button = toolbar:CreateButton("Install scripts", "Install / update the game scripts", "rbxasset://textures/StudioToolbox/AssetPreview/more.png")
	button.ClickableWhenViewportHidden = true
	button.Click:Connect(function()
		install()
		button:SetActive(false)
	end)
else
	install()
end
