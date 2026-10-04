-- ONE-CLICK INSTALLER for all game scripts.
-- Option A (recommended): Studio → Plugins tab → Plugins Folder → put this file there → restart Studio →
--   Plugins tab → "Install scripts" button.
-- Option B: paste the whole file into View → Command Bar and press Enter (may lag for a few seconds).
-- Existing scripts with the same name and type are overwritten in place; missing ones are created.
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
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 470),
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

local WORLD = {Night = true, Weather = true, NpcCreate = true}
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
}
for i, entry in ipairs(actions) do
	local col = (i - 1) % 2
	local rowIndex = math.floor((i - 1) / 2)
	button(entry[1], ACT_X + col * 123, 74 + rowIndex * 36, 117, 30, panel, entry[2])
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
local onTabSelected = {}

local tabButtons = {}
local function selectTab(name)
	mainPage.Visible = name == "PLAYERS"
	entitiesPage.Visible = name == "ENTITIES"
	bansPage.Visible = name == "BANS"
	acPage.Visible = name == "ANTICHEAT"
	if onTabSelected[name] then task.spawn(onTabSelected[name]) end
	for tabName, b in pairs(tabButtons) do
		local active = tabName == name
		b.TextColor3 = active and INK or DIM
		b:FindFirstChild("Underline").Visible = active
	end
end
for i, tabName in ipairs({"PLAYERS", "ENTITIES", "BANS", "ANTICHEAT"}) do
	local b = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20 - (4 - i) * 98, 0, 14), Size = UDim2.fromOffset(94, 24),
		BackgroundTransparency = 1, AutoButtonColor = false, Font = CONFIG.Font, Text = tabName, TextSize = 14,
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
local objectList = create("Frame", {
	Position = UDim2.fromOffset(20, 74), Size = UDim2.fromOffset(200, 330), BackgroundColor3 = Color3.fromRGB(10, 10, 10),
	BorderSizePixel = 0, Parent = entitiesPage,
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
		Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = CELL, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		LayoutOrder = i, Parent = objectList,
	}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -60, 0, 24), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = data.id, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, Parent = card,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 29), Size = UDim2.new(1, -60, 0, 16), BackgroundTransparency = 1, Font = CONFIG.Font,
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

local function listRow(list, order, top, bottom, onClick)
	local row = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = CELL, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		LayoutOrder = order, Parent = list,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -12, 0, 18), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = top, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(8, 21), Size = UDim2.new(1, -12, 0, 14), BackgroundTransparency = 1, Font = CONFIG.Font,
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

-- ----- BANS -----
sectionTitle("BANS", 20, 54, bansPage)
local banList = listBox(20, 74, 380, 300, bansPage)
local selectedBan = nil

local function refreshBans()
	local ok, list = call("ListBans")
	if not ok then setStatus(false, list or "could not load bans") return end
	clearList(banList)
	selectedBan = nil
	for i, entry in ipairs(list) do
		local active = entry.active and (entry.expires == -1 or os.time() < entry.expires)
		local expires = not entry.active and ("unbanned by " .. tostring(entry.unbannedBy or "?"))
			or (entry.expires == -1 and "permanent" or ((active and "until " or "expired ") .. when(entry.expires)))
		local top = string.format("%s%s  ·  %d", active and "" or "(inactive) ", tostring(entry.name), entry.userId)
		local bottom = string.format("%s — by %s — %s%s", tostring(entry.reason), tostring(entry.by or entry.source or "?"),
			expires, entry.allDevices and " — ALL DEVICES" or "")
		listRow(banList, i, top, bottom, function()
			selectedBan = entry
			setStatus(true, string.format("%s: %s (banned %s)", tostring(entry.name), tostring(entry.reason), when(entry.at)))
		end)
	end
	setStatus(true, string.format("%d ban record(s)", #list))
end
onTabSelected.BANS = refreshBans

button("REFRESH", 300, 50, 100, 22, bansPage, refreshBans)
button("UNBAN SELECTED", 20, 382, 185, 30, bansPage, function()
	if not selectedBan then setStatus(false, "select a ban first") return end
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
			Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 0,
			AutoButtonColor = true, Font = CONFIG.Font, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = INK, ZIndex = 21, LayoutOrder = i, TextTruncate = Enum.TextTruncate.AtEnd,
			Text = string.format("  %s  @%s  ·  %s", tostring(user.displayName or user.name), tostring(user.name), tostring(user.source)),
			Parent = suggestBox,
		})
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
create("TextLabel", {
	Position = UDim2.fromOffset(FORM_X, 318), Size = UDim2.fromOffset(260, 60), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "ALL DEVICES also bans alt accounts Roblox links to the same device. AC PUNISH paralyses, lobotomises, kills, then bans.",
	TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = DIM, Parent = bansPage,
})

-- ----- ANTICHEAT (incidents + replays) -----
sectionTitle("INCIDENTS", 20, 54, acPage)
local incidentList = listBox(20, 74, 400, 338, acPage)
local selectedIncident = nil
local detailText = create("TextLabel", {
	Position = UDim2.fromOffset(440, 74), Size = UDim2.fromOffset(240, 200), BackgroundTransparency = 1, Font = CONFIG.Font,
	Text = "select an incident", TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(200, 198, 194), Parent = acPage,
})

local function refreshIncidents()
	local ok, list = call("ListIncidents")
	if not ok then setStatus(false, list or "could not load incidents") return end
	clearList(incidentList)
	selectedIncident = nil
	detailText.Text = "select an incident"
	for i, meta in ipairs(list) do
		listRow(incidentList, i, string.format("%s — %s", tostring(meta.name), tostring(meta.reason)),
			string.format("%s%s · %s · score %s · %s", meta.verdict and ("[" .. string.upper(meta.verdict) .. "] ") or "",
				when(meta.at), tostring(meta.action), tostring(meta.score), tostring(meta.flags)),
			function()
				selectedIncident = meta
				detailText.Text = string.format("%s\n\nuser id: %d\nwhen: %s\naction: %s\nscore: %s\n\nreason: %s\n\nflags: %s\n\nserver: %s",
					tostring(meta.name), meta.userId, when(meta.at), tostring(meta.action), tostring(meta.score),
					tostring(meta.reason), tostring(meta.flags), string.sub(tostring(meta.server), 1, 8))
			end)
	end
	setStatus(true, string.format("%d incident(s)", #list))
end
onTabSelected.ANTICHEAT = refreshIncidents
button("REFRESH", 320, 50, 100, 22, acPage, refreshIncidents)

local playReplay
button("PLAY REPLAY", 440, 290, 240, 30, acPage, function()
	if not selectedIncident then setStatus(false, "select an incident first") return end
	local ok, data = call("GetIncident", selectedIncident.id)
	if not ok then setStatus(false, data or "replay not found") return end
	playReplay(data)
end)
button("BAN THIS PLAYER", 440, 326, 240, 30, acPage, function()
	if not selectedIncident then setStatus(false, "select an incident first") return end
	targetBox.Text = tostring(selectedIncident.userId)
	reasonBox.Text = "Exploiting (" .. tostring(selectedIncident.reason) .. ")"
	selectTab("BANS")
end)
button("DELETE", 440, 362, 240, 30, acPage, function()
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
	panelScale.Scale = math.clamp(math.min((size.X - 16) / 700, (size.Y - 16) / 470), 0.4, 1)
	barScale.Scale = math.clamp((size.X - 16) / 760, 0.4, 1)
end
rescale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(rescale)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

if UserInputService.TouchEnabled then
	local ContextActionService = game:GetService("ContextActionService")
	ContextActionService:BindAction("GS_AdminPanel", function(_, state)
		if state == Enum.UserInputState.Begin then setOpen(not open) end
		return Enum.ContextActionResult.Sink
	end, true)
	ContextActionService:SetTitle("GS_AdminPanel", "ADMIN")
	ContextActionService:SetPosition("GS_AdminPanel", UDim2.new(1, -165, 0, 10))
end
]=]},
	{name = "Animation", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
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
end, true, table.unpack(crouchKeys))
ContextActionService:SetTitle("GS_Crawl", "CRAWL")
ContextActionService:SetPosition("GS_Crawl", UDim2.new(1, -240, 1, -95))

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

		local getUp = (os.clock() - getUpStart) / getUpDuration
		local gettingUp = getUp >= 0 and getUp < 1
		local proneTarget = (crawling and not climbing) and 1 or 0
		if gettingUp and not crawlForced then
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
		local wantJump = proneAmount < 0.5 and not gettingUp
		if not puppet and wantJump ~= jumpEnabled then
			jumpEnabled = wantJump
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, wantJump)
		end

		local crouchWanted = puppet and (
			(character:GetAttribute("GS_EatUntil") or 0) > os.clock()
			or (character:GetAttribute("GS_EatServer") or 0) > workspace:GetServerTimeNow())
		local crouchTarget = (crouchWanted and grounded and not climbing and proneAmount < 0.5) and 1 or 0
		if gettingUp and not crawlForced then
			local getUpCrouch = getUp < 0.45 and 1 or math.clamp(1 - (getUp - 0.45) / 0.55, 0, 1)
			crouchAmount = math.max(approach(crouchAmount, crouchTarget, dt, 9), getUpCrouch)
		else
			crouchAmount = approach(crouchAmount, crouchTarget, dt, 9)
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
			local want = baseWalkSpeed * surfaceState.speed * lerp(1, CROUCH_SPEED_MUL, crouchAmount) * injurySpeed
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
		elseif not puppet and proneAmount > 0.5 then

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

		if inFirstPerson then
			neckYaw, neckPitch = 0, 0
		else
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

		if (puppet or character:GetAttribute("GS_AttackStart")) and not climbing then
			local now = os.clock()
			local attackStart = character:GetAttribute("GS_AttackStart")
			local eatUntil = puppet and character:GetAttribute("GS_EatUntil") or nil

			local attackServer = character:GetAttribute("GS_AttackServer")
			if attackServer then
				local local0 = now - (workspace:GetServerTimeNow() - attackServer)
				if not attackStart or local0 > attackStart then attackStart = local0 end
			end
			local eatServer = puppet and character:GetAttribute("GS_EatServer")
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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
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
	SpeedAllowanceMult = 1.45,
	SpeedAllowanceFlat = 6,
	TeleportDistance = 40,
	HoverTime = 1.25,
	MaxRise = 11,
	FlingAngular = 200,
	DesyncDistance = 25,
	RemoteSpamPerSecond = 90,
	HeartbeatTimeout = 45,
	FirstHeartbeatTimeout = 120,

	-- scoring: every flag adds points, points decay over time
	ScoreDecayPerSecond = 0.25,
	IncidentScore = 8,
	PunishScore = 25,
	Points = {
		speed = 2, teleport = 5, fly = 4, noclip = 4, desync = 3, fling = 8, humanoid = 30, remotespam = 10,
		hook = 6, esp = 5, lighting = 1, gravity = 5, walkspeed = 5, jumppower = 5, injected = 8,
	},

	-- punishment
	PunishKillDelay = 20,
	AutoBanSeconds = 30 * 86400,
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

local banStore, incidentStore
pcall(function() banStore = DataStoreService:GetDataStore("AC_Bans_v1") end)
pcall(function() incidentStore = DataStoreService:GetDataStore("AC_Incidents_v1") end)

local function serverNow() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end

local function isAdmin(player)
	return CONFIG.Admins[player.UserId] == true or player:GetAttribute("IsAdmin") == true
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

local function ban(userId, name, reason, seconds, allDevices, by, source, incidentId)
	local entry = {
		userId = userId, name = name or tostring(userId), reason = reason, by = by, source = source,
		at = os.time(), expires = seconds < 0 and -1 or os.time() + seconds, duration = seconds,
		allDevices = allDevices, incident = incidentId, active = true,
	}
	if banStore then pcall(function() banStore:SetAsync("u_" .. userId, entry) end) end
	updateIndex(entry)
	-- Roblox's own ban API adds alt-account (device) detection when allDevices is on
	pcall(function()
		Players:BanAsync({
			UserIds = {userId}, ApplyToUniverse = true, Duration = seconds < 0 and -1 or seconds,
			DisplayReason = string.sub(reason, 1, 380), PrivateReason = string.sub(source .. " / " .. tostring(by) .. ": " .. reason, 1, 900),
			ExcludeAltAccounts = not allDevices,
		})
	end)
	local online = Players:GetPlayerByUserId(userId)
	if online then online:Kick(banMessage(entry)) end
	forAdmins(function(admin)
		alertRemote:FireClient(admin, "ban", string.format("%s banned (%s) — %s", entry.name, formatDuration(seconds), reason))
	end)
	return entry
end

local function unban(userId, by)
	local entry
	if banStore then
		pcall(function() entry = banStore:GetAsync("u_" .. userId) end)
	end
	entry = entry or {userId = userId, name = tostring(userId), reason = "?", at = os.time(), expires = -1}
	entry.active = false
	entry.unbannedBy = by
	entry.unbannedAt = os.time()
	if banStore then pcall(function() banStore:SetAsync("u_" .. userId, entry) end) end
	updateIndex(entry)
	pcall(function() Players:UnbanAsync({UserIds = {userId}, ApplyToUniverse = true}) end)
	return entry
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
				if model:IsA("Model") then add(model) end
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

local function flag(player, kind, detail)
	local st = states[player]
	if not st or st.punishing then return end
	local now = os.clock()
	if now - (st.flagLast[kind] or -math.huge) < 0.45 then return end
	st.flagLast[kind] = now
	st.flagCounts[kind] = (st.flagCounts[kind] or 0) + 1
	st.score += (CONFIG.Points[kind] or 3) * (st.trusted and 0.5 or 1)
	local text = kind .. (detail and (": " .. detail) or "")
	logEvent(player.Character, "flag", text)
	st.lastReason = text
	if st.score >= CONFIG.PunishScore then
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
	if not st or st.punishing then return end
	st.punishing = true
	local token = {}
	st.punishToken = token
	player:SetAttribute("AC_Punished", true)
	local meta = createIncident(player, reason, "punished")
	local function doBan()
		if st.banned or st.punishToken ~= token then return end
		st.banned = true
		ban(player.UserId, player.Name, "Exploiting (" .. reason .. ")", CONFIG.AutoBanSeconds, CONFIG.AutoBanAllDevices,
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
	return params
end

local function groundParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = false
	params.FilterDescendantsInstances = {character}
	return params
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
	local tp = character:GetAttribute("AC_TeleportAt")
	if tp and serverNow() - tp < 3 then return true end
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

	-- teleport
	if flat(delta).Magnitude > CONFIG.TeleportDistance or delta.Y > 25 then
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
				local overlap = OverlapParams.new()
				overlap.FilterType = Enum.RaycastFilterType.Include
				overlap.FilterDescendantsInstances = {forward.Instance}
				overlap.RespectCanCollide = true
				inside = #workspace:GetPartBoundsInRadius(pos, 0.4, overlap) > 0
			end
			if back or inside then
				flag(player, "noclip", forward.Instance:GetFullName())
				rubberband(st, root)
				return
			end
		end
	end

	-- speed over a one second window
	table.insert(st.window, {t = now, p = pos})
	while st.window[1] and now - st.window[1].t > 1.05 do table.remove(st.window, 1) end
	local oldest = st.window[1]
	local span = now - oldest.t
	if span > 0.9 then
		local dist = flat(pos - oldest.p).Magnitude
		local base = math.max(humanoid.WalkSpeed, 16)
		local allowed = (base * CONFIG.SpeedAllowanceMult + CONFIG.SpeedAllowanceFlat) * span
		if dist > allowed then
			flag(player, "speed", string.format("%.0f studs/s", dist / span))
			violated = true
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
		if child == humanoid and character.Parent and player.Character == character and lastHealth > 0 then
			flag(player, "humanoid", "Humanoid removed")
		end
	end)
end

local function onPlayerAdded(player)
	-- bans first
	local entry
	if banStore then pcall(function() entry = banStore:GetAsync("u_" .. player.UserId) end) end
	if banActive(entry) then
		player:Kick(banMessage(entry))
		return
	end
	states[player] = newState(player)
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
	states[player] = nil
end)

-- ===================== client reports & heartbeat =====================

local CLIENT_FLAGS = {hook = true, esp = true, lighting = true, gravity = true, walkspeed = true, jumppower = true, injected = true}

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
			if (c - root.Position).Magnitude > CONFIG.DesyncDistance then
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
		local ok, err = pcall(checkPlayer, player, st, now)
		if not ok then warn("[AntiCheat] " .. tostring(err)) end
		-- the client anti-cheat must keep beating
		if not isAdmin(player) then
			if st.lastBeat and now - st.lastBeat > CONFIG.HeartbeatTimeout then
				player:Kick("Anti-cheat stopped responding (AC-01)")
			elseif not st.lastBeat and now - st.joinedAt > CONFIG.FirstHeartbeatTimeout then
				player:Kick("Anti-cheat did not start (AC-02)")
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

function ADMIN.Unban(admin, userId)
	userId = tonumber(userId)
	if not userId then return false, "bad user id" end
	local entry = unban(userId, admin.Name)
	return true, (entry.name or tostring(userId)) .. " unbanned"
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
	if not isAdmin(player) then return false, "not an admin" end
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
	{name = "AntiCheatClient", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- Client half of the anti-cheat: heartbeat, lighting/gravity guard, ESP and injector signs.
-- Nothing here bans on its own; it reports to the server, which scores and decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local LogService = game:GetService("LogService")

local player = Players.LocalPlayer
local report = ReplicatedStorage:WaitForChild("ACReport", 60)
local world = ReplicatedStorage:WaitForChild("AC_World", 60)
if not report then return end

local key = nil
local seq = 0
report.OnClientEvent:Connect(function(kind, value)
	if kind == "key" then key = value end
end)
report:FireServer("hello")

local lastFlag = {}
local function flag(kind, detail)
	local now = os.clock()
	if now - (lastFlag[kind] or -math.huge) < 2 then return end
	lastFlag[kind] = now
	report:FireServer("flag", kind, detail)
end

-- ===== heartbeat =====
task.spawn(function()
	while true do
		task.wait(2)
		if not key then
			report:FireServer("hello")
		else
			seq += 1
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			report:FireServer("hb", key, seq, root and root.Position or nil)
		end
	end
end)

-- ===== core functions must still be native =====
local NATIVE = {
	print = print, warn = warn, error = error, pcall = pcall, tostring = tostring, typeof = typeof,
	require = require, setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget,
	["Instance.new"] = Instance.new, ["task.spawn"] = task.spawn, ["debug.info"] = debug.info,
	["game.GetService"] = game.GetService, ["game.FindFirstChild"] = game.FindFirstChild,
	["workspace.Raycast"] = workspace.Raycast, ["Instance.Destroy"] = game.Destroy,
}
local function checkHooks()
	for name, fn in pairs(NATIVE) do
		local ok, source = pcall(debug.info, fn, "s")
		if ok and source ~= "[C]" then
			flag("hook", name)
			return
		end
	end
	-- a hooked __namecall usually changes this error message or adds frames to it
	local ok, err = pcall(function() return game:AC_NotARealMethod() end)
	if ok or not string.find(tostring(err), "AC_NotARealMethod", 1, true) then flag("hook", "__namecall") end
end

-- ===== executor / script-hub traces in the client log =====
local SIGNS = {
	"synapse", "krnl", "fluxus", "script-ware", "scriptware", "electron", "celery", "solara", "wave executor",
	"xeno", "hydrogen", "codex", "arceus", "delta executor", "infinite yield", "dark dex", "dex explorer",
	"simplespy", "remotespy", "remote spy", "hydroxide", "owl hub", "vape", "unnamed esp", "aimbot",
	"getgenv", "hookmetamethod", "hookfunction",
}
local function scanMessage(message)
	local lower = string.lower(tostring(message))
	for _, sign in ipairs(SIGNS) do
		if string.find(lower, sign, 1, true) then
			flag("injected", sign)
			return
		end
	end
end
LogService.MessageOut:Connect(scanMessage)
pcall(function()
	for _, entry in ipairs(LogService:GetLogHistory()) do scanMessage(entry.message) end
end)

-- ===== ESP: highlights / boxes / labels stuck on other players =====
local OURS = {"^GS_", "^Horror", "^AC_"}
local function ours(inst)
	for _, pattern in ipairs(OURS) do
		if string.find(inst.Name, pattern) then return true end
	end
	return false
end
local function isEspClass(inst)
	return inst:IsA("Highlight") or inst:IsA("HandleAdornment") or inst:IsA("SelectionBox")
		or inst:IsA("SelectionSphere") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui")
end
local function otherCharacter(inst)
	if not inst then return nil end
	local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
	while model do
		local plr = Players:GetPlayerFromCharacter(model)
		if plr then return plr ~= player and model or nil end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end
local function checkEsp(inst)
	if not isEspClass(inst) or ours(inst) then return end
	task.defer(function()
		if not inst.Parent then return end
		local adornee = nil
		pcall(function() adornee = inst.Adornee end)
		if otherCharacter(inst) or otherCharacter(adornee) then
			flag("esp", inst.ClassName .. " " .. inst.Name)
			pcall(function() inst:Destroy() end)
		end
	end)
end
workspace.DescendantAdded:Connect(checkEsp)
player:WaitForChild("PlayerGui").DescendantAdded:Connect(checkEsp)

-- ===== lighting and gravity must match the server =====
local function colorOff(a, b)
	return math.abs(a.R - b.R) > 0.12 or math.abs(a.G - b.G) > 0.12 or math.abs(a.B - b.B) > 0.12
end
local EFFECT_OK = {"^Fall", "^LowHealth", "^GS_", "^Horror"}
local mismatch = 0
local function checkWorld()
	if not world or world:GetAttribute("ClockTime") == nil then return end
	local bad = {}
	local clock = math.abs(Lighting.ClockTime - world:GetAttribute("ClockTime")) % 24
	if math.min(clock, 24 - clock) > 0.75 then table.insert(bad, "ClockTime") end
	if math.abs(Lighting.Brightness - world:GetAttribute("Brightness")) > 0.5 then table.insert(bad, "Brightness") end
	if colorOff(Lighting.Ambient, world:GetAttribute("Ambient")) then table.insert(bad, "Ambient") end
	if colorOff(Lighting.OutdoorAmbient, world:GetAttribute("OutdoorAmbient")) then table.insert(bad, "OutdoorAmbient") end
	if Lighting.GlobalShadows ~= world:GetAttribute("GlobalShadows") then table.insert(bad, "GlobalShadows") end
	local fog = world:GetAttribute("FogEnd")
	if math.abs(Lighting.FogEnd - fog) > math.max(50, fog * 0.2) then table.insert(bad, "FogEnd") end
	if math.abs(Lighting.ExposureCompensation - world:GetAttribute("ExposureCompensation")) > 0.3 then table.insert(bad, "Exposure") end
	local density = world:GetAttribute("AtmosphereDensity")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if density and density >= 0 and (not atmosphere or math.abs(atmosphere.Density - density) > 0.08) then
		table.insert(bad, "Atmosphere")
	end
	if math.abs(workspace.Gravity - world:GetAttribute("Gravity")) > 1 then
		workspace.Gravity = world:GetAttribute("Gravity")
		flag("gravity", string.format("%.0f", workspace.Gravity))
	end
	-- post effects the server never made (except our own local ones)
	local serverEffects = {}
	for name in string.gmatch(world:GetAttribute("Effects") or "", "[^,]+") do serverEffects[name] = true end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") and not serverEffects[child.Name] then
			local allowed = false
			for _, pattern in ipairs(EFFECT_OK) do
				if string.find(child.Name, pattern) then allowed = true break end
			end
			if not allowed then
				table.insert(bad, "effect " .. child.Name)
				child:Destroy()
			end
		end
	end

	if #bad == 0 then
		mismatch = 0
		return
	end
	mismatch += 1
	if mismatch < 3 then return end
	mismatch = 0
	-- put the server's values back
	Lighting.ClockTime = world:GetAttribute("ClockTime")
	Lighting.Brightness = world:GetAttribute("Brightness")
	Lighting.Ambient = world:GetAttribute("Ambient")
	Lighting.OutdoorAmbient = world:GetAttribute("OutdoorAmbient")
	Lighting.GlobalShadows = world:GetAttribute("GlobalShadows")
	Lighting.FogEnd = world:GetAttribute("FogEnd")
	Lighting.FogStart = world:GetAttribute("FogStart")
	Lighting.ExposureCompensation = world:GetAttribute("ExposureCompensation")
	if density and density >= 0 then
		if not atmosphere then
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Name = "HorrorAtmosphere"
			atmosphere.Parent = Lighting
		end
		atmosphere.Density = density
		atmosphere.Haze = world:GetAttribute("AtmosphereHaze")
	end
	flag("lighting", table.concat(bad, ", "))
end

-- ===== humanoid values the game never uses =====
local function checkHumanoid()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if humanoid.WalkSpeed > 26 then
		flag("walkspeed", string.format("%.0f", humanoid.WalkSpeed))
		humanoid.WalkSpeed = 16
	end
	if humanoid.UseJumpPower and humanoid.JumpPower > 60 then
		flag("jumppower", string.format("%.0f", humanoid.JumpPower))
		humanoid.JumpPower = 50
	elseif not humanoid.UseJumpPower and humanoid.JumpHeight > 12 then
		flag("jumppower", string.format("height %.0f", humanoid.JumpHeight))
		humanoid.JumpHeight = 7.2
	end
end

task.spawn(function()
	local tick = 0
	while true do
		task.wait(1)
		tick += 1
		pcall(checkWorld)
		pcall(checkHumanoid)
		if tick % 5 == 0 then pcall(checkHooks) end
	end
end)
]=]},
	{name = "BloodFX", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundConfig"))
local player = Players.LocalPlayer

local SETTINGS = {
	Enabled = true,
	BloodColor = Color3.fromRGB(92, 4, 4),
	BloodDark = Color3.fromRGB(55, 2, 2),
	MaxDroplets = 260,
	MaxSplats = 220,
	SplatLifetime = 60,
	DropletsPerDamage = 1.1,
	MinDamage = 2,
	FallBloodMinHeight = 22,
	PoolDamage = 10,
	ScreenBlood = true,
	GibDroplets = 140,
}

if not SETTINGS.Enabled then return end

local rng = Random.new()
local folder = Instance.new("Folder")
folder.Name = "PS_Blood"
folder.Parent = workspace

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

local function refreshFilter()
	local list = {folder}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(list, plr.Character) end
	end
	local npcFolder = workspace:FindFirstChild("NPCs")
	if npcFolder then table.insert(list, npcFolder) end
	local corpses = workspace:FindFirstChild("Corpses")
	if corpses then table.insert(list, corpses) end
	params.FilterDescendantsInstances = list
end
refreshFilter()

local function newPart(size, color)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local splats = {}

local function addSplat(position, normal, diameter, grow)
	if #splats >= SETTINGS.MaxSplats then
		local old = table.remove(splats, 1)
		if old.Parent then old:Destroy() end
	end

	local up = normal.Unit
	local tangent = up:Cross(Vector3.new(0, 1, 0))
	if tangent.Magnitude < 0.1 then tangent = up:Cross(Vector3.new(1, 0, 0)) end
	tangent = tangent.Unit
	local cf = CFrame.fromMatrix(position + up * 0.03, up, tangent) * CFrame.Angles(rng:NextNumber(0, math.pi * 2), 0, 0)
	local shade = SETTINGS.BloodColor:Lerp(SETTINGS.BloodDark, rng:NextNumber(0, 0.6))
	local splat = newPart(Vector3.new(0.04, 0.2, 0.2), shade)
	splat.Shape = Enum.PartType.Cylinder
	splat.Reflectance = 0.05
	splat.CFrame = cf
	splat.Parent = folder
	table.insert(splats, splat)
	TweenService:Create(splat, TweenInfo.new(grow or 0.25, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.04, diameter, diameter * rng:NextNumber(0.75, 1.1)),
	}):Play()
	task.delay(SETTINGS.SplatLifetime, function()
		if splat.Parent then
			local t = TweenService:Create(splat, TweenInfo.new(4), {Transparency = 1})
			t:Play()
			t.Completed:Wait()
			splat:Destroy()
		end
	end)
	return splat
end

local function addPool(position, size, time)
	local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -8, 0), params)
	if not hit then return end
	for i = 1, 5 do
		local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size * 0.25
		task.delay((i - 1) * 0.15, function()
			addSplat(hit.Position + offset, hit.Normal, size * rng:NextNumber(0.5, 0.9), time)
		end)
	end
end

local droplets = {}

local function spawnDroplets(origin, count, speed, spread, bias)
	for _ = 1, count do
		if #droplets >= SETTINGS.MaxDroplets then break end
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1))
		if bias then dir += bias end
		if dir.Magnitude < 1e-3 then dir = Vector3.new(0, 1, 0) end
		dir = dir.Unit
		local size = rng:NextNumber(0.12, 0.3)
		local drop = newPart(Vector3.new(size, size, size), SETTINGS.BloodColor)
		drop.Shape = Enum.PartType.Ball
		drop.Position = origin
		drop.Parent = folder
		table.insert(droplets, {
			part = drop,
			position = origin,
			velocity = dir * speed * rng:NextNumber(0.4, 1) + Vector3.new(0, rng:NextNumber(0, spread), 0),
			life = 0,
			size = size,
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
			addSplat(hit.Position, hit.Normal, d.size * rng:NextNumber(3, 6), 0.15)
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

-- blood spurts are real droplets only; the old smoke-textured puff clouds are gone
local function makeSpurt(part, duration, rate, offset)
	local attachment = Instance.new("Attachment")
	attachment.Position = offset or Vector3.zero
	attachment.Parent = part
	local perTick = math.clamp(math.floor(rate / 20), 1, 3)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and part.Parent do
			spawnDroplets(attachment.WorldPosition, perTick, 9, 3, part.CFrame.UpVector * 0.5)
			task.wait(0.12)
			elapsed += 0.12
		end
		attachment:Destroy()
	end)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BloodScreen"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 25
screenGui.Parent = player:WaitForChild("PlayerGui")

local function screenSplat(amount)
	if not SETTINGS.ScreenBlood then return end
	local count = math.clamp(math.floor(amount / 6) + 1, 1, 8)
	for _ = 1, count do

		local x = rng:NextNumber() < 0.5 and rng:NextNumber(0, 0.28) or rng:NextNumber(0.72, 1)
		local y = rng:NextNumber(0, 1)
		if rng:NextNumber() < 0.3 then x, y = rng:NextNumber(0, 1), rng:NextNumber() < 0.5 and rng:NextNumber(0, 0.2) or rng:NextNumber(0.8, 1) end
		local size = rng:NextInteger(60, 180) * math.clamp(amount / 20, 0.6, 2)
		local blob = Instance.new("Frame")
		blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.fromScale(x, y)
		blob.Size = UDim2.fromOffset(size, size * rng:NextNumber(0.7, 1.3))
		blob.Rotation = rng:NextNumber(0, 360)
		blob.BackgroundColor3 = SETTINGS.BloodColor:Lerp(SETTINGS.BloodDark, rng:NextNumber())
		blob.BackgroundTransparency = 0.15
		blob.BorderSizePixel = 0
		blob.Parent = screenGui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = blob
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = rng:NextNumber(0, 360)
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.25), NumberSequenceKeypoint.new(1, 0.8),
		})
		gradient.Parent = blob
		task.delay(rng:NextNumber(2.5, 4), function()
			TweenService:Create(blob, TweenInfo.new(2.5), {BackgroundTransparency = 1}):Play()
			task.wait(2.6)
			blob:Destroy()
		end)
	end
end

local function setupCharacter(plr, character)
	refreshFilter()
	local humanoid = character:WaitForChild("Humanoid", 10)
	local torso = character:WaitForChild("Torso", 10)
	if not humanoid or not torso then return end
	local isLocal = plr == player
	local lastHealth = humanoid.Health

	humanoid.HealthChanged:Connect(function(health)
		local damage = lastHealth - health
		lastHealth = health
		if damage < SETTINGS.MinDamage or character:GetAttribute("Gibbed") then return end
		if character:GetAttribute("LastDamageCause") == "FALL"
			and (character:GetAttribute("LastFallHeight") or 0) < SETTINGS.FallBloodMinHeight
			and workspace:GetServerTimeNow() - (character:GetAttribute("LastDamageTime") or 0) < 1 then
			return
		end
		local count = math.clamp(math.floor(damage * 2.5), 6, 80)
		spawnDroplets(torso.Position, count, 10 + damage * 0.3, 6)
		task.delay(0.35, function()
			if torso.Parent then addPool(torso.Position, math.clamp(damage / 9, 1.2, 3), 1.5) end
		end)
		if damage >= SETTINGS.PoolDamage then
			task.delay(0.6, function()
				if torso.Parent then addPool(torso.Position, math.clamp(damage / 8, 1.5, 5), 2.5) end
			end)
		end
		if isLocal then screenSplat(damage) end
	end)

	task.spawn(function()
		while character.Parent and torso.Parent and humanoid.Health > 0 do
			local bleeding = character:GetAttribute("Bleeding") or 0
			if bleeding > 0.02 then
				spawnDroplets(torso.Position - Vector3.new(0, 0.6, 0), math.clamp(math.floor(bleeding * 4) + 1, 1, 6), 3, 1, Vector3.new(0, -1.5, 0))
				task.wait(math.clamp(1.1 - bleeding * 0.6, 0.25, 1.1))
			else
				task.wait(0.5)
			end
		end
	end)

	humanoid.Died:Connect(function()
		task.delay(1.2, function()
			if torso.Parent and not character:GetAttribute("Gibbed") then
				addPool(torso.Position, 5, 6)
			end
		end)
	end)

	local function onGibbed()
		if not character:GetAttribute("Gibbed") then return end
		task.wait(0.05)
		local position = torso.Position
		spawnDroplets(position, SETTINGS.GibDroplets, 28, 14)
		SoundConfig.PlayOnce("Gore1", torso)
		SoundConfig.PlayOnce("Gore2", torso)
		addPool(position, 8, 3)
		makeSpurt(torso, 5, 60)
		if isLocal then screenSplat(80) end

		task.delay(0.25, function()
			local list = character:GetAttribute("GibbedParts") or ""
			for name in string.gmatch(list, "[^,]+") do
				local part = character:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					makeSpurt(part, 3.5, 35)
					spawnDroplets(part.Position, 20, 16, 6)
				end
			end
		end)
	end
	character:GetAttributeChangedSignal("Gibbed"):Connect(onGibbed)

	local function onHeadExploded()
		if not character:GetAttribute("HeadExploded") then return end
		local position = character:GetAttribute("HeadExplodePosition")
		if typeof(position) ~= "Vector3" then
			position = torso.CFrame:PointToWorldSpace(Vector3.new(0, 1.5, 0))
		end
		spawnDroplets(position, 120, 30, 16, Vector3.new(0, 6, 0))
		SoundConfig.PlayOnce("Gore1", torso, {PlaybackSpeed = 0.9})
		SoundConfig.PlayOnce("Gore2", torso, {PlaybackSpeed = 1.05})
		SoundConfig.PlayOnce(SoundConfig.Random("BoneCrack"), torso, {PlaybackSpeed = 0.7})
		makeSpurt(torso, 7, 70, Vector3.new(0, 1, 0))
		task.delay(0.5, function()
			if torso.Parent then addPool(torso.Position, 5, 4) end
		end)
		if isLocal then screenSplat(100) end
	end
	character:GetAttributeChangedSignal("HeadExploded"):Connect(onHeadExploded)

	character:GetAttributeChangedSignal("LimbExploded"):Connect(function()
		local position = character:GetAttribute("LimbExplodePosition")
		if typeof(position) ~= "Vector3" then return end
		spawnDroplets(position, 90, 26, 14, Vector3.new(0, 4, 0))
		SoundConfig.PlayOnce("Gore1", torso, {PlaybackSpeed = rng:NextNumber(0.85, 1)})
		SoundConfig.PlayOnce(SoundConfig.Random("BoneCrack"), torso, {PlaybackSpeed = 0.75})
		task.delay(0.4, function() addPool(position, 3.5, 3) end)
		if isLocal then screenSplat(70) end
	end)

	local STUMPS = {
		Head = {offset = Vector3.new(0, 1, 0), part = "Head", limbEnd = Vector3.new(0, -0.5, 0)},
		RightArm = {offset = Vector3.new(1, 0.6, 0), part = "Right Arm", limbEnd = Vector3.new(0, 1, 0)},
		LeftArm = {offset = Vector3.new(-1, 0.6, 0), part = "Left Arm", limbEnd = Vector3.new(0, 1, 0)},
		RightLeg = {offset = Vector3.new(0.5, -1, 0), part = "Right Leg", limbEnd = Vector3.new(0, 1, 0)},
		LeftLeg = {offset = Vector3.new(-0.5, -1, 0), part = "Left Leg", limbEnd = Vector3.new(0, 1, 0)},
	}
	local bled = {}
	for key, info in pairs(STUMPS) do
		local attribute = "Injury_" .. key
		character:GetAttributeChangedSignal(attribute):Connect(function()
			if (character:GetAttribute(attribute) or 0) < 3 then bled[key] = nil return end
			if bled[key] or not torso.Parent then return end
			bled[key] = true
			local stump = torso.CFrame:PointToWorldSpace(info.offset)
			spawnDroplets(stump, 50, 20, 9)
			makeSpurt(torso, 6, 60, info.offset)
			task.delay(6, function()
				if torso.Parent then makeSpurt(torso, 25, 14, info.offset) end
			end)
			task.delay(0.4, function()
				if torso.Parent then addPool(torso.Position, 4, 4) end
			end)
			if isLocal then screenSplat(50) end

			task.delay(0.3, function()
				local folder = workspace:FindFirstChild("SeveredLimbs")
				if not folder then return end
				for _, limb in ipairs(folder:GetDescendants()) do
					if limb.Name == info.part and limb:GetAttribute("SeveredFrom") == character.Name and limb:IsA("BasePart") then
						makeSpurt(limb, 12, 25, info.limbEnd)
						task.delay(1.5, function()
							if limb.Parent then addPool(limb.Position, 2.5, 3) end
						end)
					end
				end
			end)
		end)
	end
end

local function watch(plr)
	if plr.Character then task.spawn(setupCharacter, plr, plr.Character) end
	plr.CharacterAdded:Connect(function(character) setupCharacter(plr, character) end)
end
for _, plr in ipairs(Players:GetPlayers()) do watch(plr) end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(refreshFilter)

task.spawn(function()
	local npcFolder = workspace:WaitForChild("NPCs", 60)
	if not npcFolder then return end
	local function onNpc(model)
		if not model:IsA("Model") then return end
		local fake = {Name = "npc", DisplayName = model:GetAttribute("DisplayName") or model.Name, UserId = model:GetAttribute("NpcId") or 0, IsNpc = true}
		task.spawn(setupCharacter, fake, model)
	end
	for _, model in ipairs(npcFolder:GetChildren()) do onNpc(model) end
	npcFolder.ChildAdded:Connect(onNpc)
end)
]=]},
	{name = "CharacterVisualSyncServer", class = "Script", where = "ServerScriptService", source = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LimbPose = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LimbPose"))

local event = ReplicatedStorage:FindFirstChild("CharacterVisualSync")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "CharacterVisualSync"
	event.Parent = ReplicatedStorage
end
assert(event:IsA("RemoteEvent"), "CharacterVisualSync must be a RemoteEvent")

local lastSent = {}
local MIN_INTERVAL = 1 / 30

event.OnServerEvent:Connect(function(player, packet)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Ragdolled") then return end
	local now = os.clock()
	if now - (lastSent[player] or -math.huge) < MIN_INTERVAL then return end

	local values = LimbPose.Unpack(packet)
	if not values then return end
	lastSent[player] = now
	local clean = LimbPose.Pack(values)
	-- the server keeps crouch / prone as attributes so monsters can hear how you move
	local crouch = (values[#values - 2] or 0) > 0.5
	local prone = (values[#values - 1] or 0) > 0.5
	if character:GetAttribute("GS_Crouch") ~= crouch then character:SetAttribute("GS_Crouch", crouch) end
	if character:GetAttribute("GS_Prone") ~= prone then character:SetAttribute("GS_Prone", prone) end

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then event:FireClient(other, player, clean) end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastSent[player] = nil
end)
]=]},
	{name = "Chat", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundConfig"))
local typingRemote = ReplicatedStorage:WaitForChild("ChatTyping", 15)
local player = Players.LocalPlayer

local CONFIG = {
	Font = Enum.Font.SpecialElite,
	HearDistance = 50,
	MaxLength = 150,
	Width = 440,
	Ink = Color3.fromRGB(225, 222, 218),
	Dim = Color3.fromRGB(95, 93, 90),
	Line = Color3.fromRGB(60, 58, 56),
	Key = Enum.KeyCode.Slash,
}

local isNewChat = TextChatService.ChatVersion == Enum.ChatVersion.TextChatService

local function configureChat()
	if not isNewChat then
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) end)
		return
	end
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local bar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	local bubbles = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	if window then pcall(function() window.Enabled = false end) end
	if bar then pcall(function() bar.Enabled = false end) end
	if bubbles then
		local props = {
			Enabled = true,
			MaxDistance = CONFIG.HearDistance,
			MinimizeDistance = CONFIG.HearDistance * 0.7,
			BackgroundColor3 = Color3.fromRGB(8, 8, 8),
			BackgroundTransparency = 0.15,
			TextColor3 = CONFIG.Ink,
			TextSize = 17,
			FontFace = Font.fromEnum(CONFIG.Font),
			BubbleDuration = 12,
			BubblesSpacing = 4,
			VerticalStudsOffset = 0.6,
			TailVisible = false,
		}
		for key, value in pairs(props) do
			pcall(function() bubbles[key] = value end)
		end
	end
end
configureChat()
task.delay(3, configureChat)

local gui = Instance.new("ScreenGui")
gui.Name = "HorrorChat"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("CanvasGroup")
bar.AnchorPoint = Vector2.new(0, 0)
bar.Position = UDim2.new(0, 16, 0, 64)
bar.Size = UDim2.fromOffset(CONFIG.Width, 38)
bar.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
bar.BackgroundTransparency = 0.1
bar.BorderSizePixel = 0
bar.GroupTransparency = 1
bar.Parent = gui
local barStroke = Instance.new("UIStroke")
barStroke.Color = CONFIG.Line
barStroke.Thickness = 1
barStroke.Parent = bar
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new(Color3.fromRGB(28, 27, 26), Color3.fromRGB(0, 0, 0))
gradient.Parent = bar

local prompt = Instance.new("TextLabel")
prompt.Position = UDim2.fromOffset(12, 0)
prompt.Size = UDim2.new(0, 16, 1, 0)
prompt.BackgroundTransparency = 1
prompt.Font = CONFIG.Font
prompt.Text = "›"
prompt.TextSize = 22
prompt.TextColor3 = Color3.fromRGB(170, 20, 20)
prompt.Parent = bar

local box = Instance.new("TextBox")
box.Position = UDim2.fromOffset(32, 0)
box.Size = UDim2.new(1, -90, 1, 0)
box.BackgroundTransparency = 1
box.Font = CONFIG.Font
box.PlaceholderText = "whisper something..."
box.PlaceholderColor3 = CONFIG.Dim
box.Text = ""
box.TextSize = 18
box.TextColor3 = CONFIG.Ink
box.TextXAlignment = Enum.TextXAlignment.Left
box.ClearTextOnFocus = false
box.TextTruncate = Enum.TextTruncate.AtEnd
box.Parent = bar

local counter = Instance.new("TextLabel")
counter.AnchorPoint = Vector2.new(1, 0)
counter.Position = UDim2.new(1, -12, 0, 0)
counter.Size = UDim2.new(0, 50, 1, 0)
counter.BackgroundTransparency = 1
counter.Font = CONFIG.Font
counter.Text = ""
counter.TextSize = 13
counter.TextColor3 = CONFIG.Dim
counter.TextXAlignment = Enum.TextXAlignment.Right
counter.Parent = bar

-- the hint is a button: click or tap it to talk (the "/" key still works too)
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local hint = Instance.new("TextButton")
hint.AutoButtonColor = false
hint.AnchorPoint = Vector2.new(0, 0)
hint.Position = UDim2.new(0, 18, 0, 70)
hint.Size = touch and UDim2.fromOffset(150, 34) or UDim2.fromOffset(200, 18)
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.BackgroundTransparency = touch and 0.4 or 1
hint.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
hint.BorderSizePixel = 0
hint.Font = CONFIG.Font
hint.Text = touch and "  tap to talk" or "/ talk  (or click)"
hint.TextSize = touch and 18 or 13
hint.TextColor3 = CONFIG.Dim
hint.TextTransparency = 0.4
hint.Parent = gui

local function tween(object, time, props)
	TweenService:Create(object, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local typing = false
local function setTyping(value)
	if typing == value then return end
	typing = value
	if typingRemote then typingRemote:FireServer(value) end
end

local function canChat()
	return player:GetAttribute("CanChat") ~= false
end

local function showBar()
	tween(bar, 0.15, {GroupTransparency = 0, Position = UDim2.new(0, 16, 0, 64)})
	tween(hint, 0.15, {TextTransparency = 1, BackgroundTransparency = 1})
end

local function openBar()
	if player:GetAttribute("InMenu") or not canChat() then return end
	showBar()
	box:CaptureFocus()
	task.delay(0.03, function()
		if box.Text == "/" then box.Text = "" end
	end)
end

local function closeBar()
	tween(bar, 0.3, {GroupTransparency = 1, Position = UDim2.new(0, 8, 0, 64)})
	tween(hint, 0.3, {TextTransparency = 0.4, BackgroundTransparency = touch and 0.4 or 1})
	setTyping(false)
end

local function send(text)
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text == 0 then return end
	text = text:sub(1, CONFIG.MaxLength)
	if isNewChat then
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			task.spawn(function() pcall(function() general:SendAsync(text) end) end)
		end
	end
end

box:GetPropertyChangedSignal("Text"):Connect(function()
	if #box.Text > CONFIG.MaxLength then
		box.Text = box.Text:sub(1, CONFIG.MaxLength)
	end
	counter.Text = #box.Text > 0 and string.format("%d/%d", #box.Text, CONFIG.MaxLength) or ""
	setTyping(box:IsFocused() and #box.Text > 0)
end)

-- clicking straight into the (hidden) box used to focus it without showing anything
box.Focused:Connect(function()
	if player:GetAttribute("InMenu") or not canChat() then
		box:ReleaseFocus()
		return
	end
	showBar()
end)
hint.Activated:Connect(openBar)

box.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		send(box.Text)
	end
	box.Text = ""
	closeBar()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == CONFIG.Key and not UserInputService:GetFocusedTextBox() then
		task.defer(openBar)
	end
end)

RunService.RenderStepped:Connect(function()
	local allowed = canChat() and not player:GetAttribute("InMenu")
	hint.Visible = allowed
	bar.Visible = allowed
end)

local rng = Random.new()
local typingBillboards = {}

local function makeTypingIndicator(character)
	local head = character:WaitForChild("Head", 10)
	if not head then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GS_Typing"
	billboard.Size = UDim2.fromOffset(46, 22)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = CONFIG.HearDistance
	billboard.AlwaysOnTop = false
	billboard.Enabled = false
	billboard.Adornee = head
	billboard.Parent = gui
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back
	local dots = {}
	for i = 1, 3 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(0.5, (i - 2) * 11, 0.5, 0)
		dot.Size = UDim2.fromOffset(5, 5)
		dot.BackgroundColor3 = CONFIG.Ink
		dot.BorderSizePixel = 0
		dot.Parent = back
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = dot
		dots[i] = dot
	end
	typingBillboards[character] = {billboard = billboard, dots = dots}
	character.Destroying:Connect(function()
		billboard:Destroy()
		typingBillboards[character] = nil
	end)
	character.AncestryChanged:Connect(function()
		if not character.Parent then
			billboard:Destroy()
			typingBillboards[character] = nil
		end
	end)
end

local function watch(plr)
	if plr == player then return end
	if plr.Character then task.spawn(makeTypingIndicator, plr.Character) end
	plr.CharacterAdded:Connect(function(character) makeTypingIndicator(character) end)
end
for _, plr in ipairs(Players:GetPlayers()) do watch(plr) end
Players.PlayerAdded:Connect(watch)

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for character, data in pairs(typingBillboards) do
		local on = character:GetAttribute("Typing") == true
		data.billboard.Enabled = on
		if on then
			for i, dot in ipairs(data.dots) do
				local wave = math.max(0, math.sin(t * 6 - i * 0.9))
				dot.Position = UDim2.new(0.5, (i - 2) * 11, 0.5, -wave * 3)
				dot.BackgroundTransparency = 0.5 - wave * 0.5
			end
		end
	end
end)

local function mumble(character, text)
	local head = character:FindFirstChild("Head")
	if not head then return end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - head.Position).Magnitude > CONFIG.HearDistance + 10 then return end
	local words = select(2, text:gsub("%S+", "")) or 1
	local count = math.clamp(math.ceil(words / 3), 1, 5)
	local pitch = 0.9 + ((character:GetAttribute("VoicePitch") or rng:NextNumber()) - 0.5) * 0.25
	task.spawn(function()
		for _ = 1, count do
			if not head.Parent then break end
			local sound = SoundConfig.PlayOnce(SoundConfig.Random("Mumble"), head, {
				PlaybackSpeed = pitch * rng:NextNumber(0.94, 1.08),
				RollOffMaxDistance = CONFIG.HearDistance,
				RollOffMinDistance = 6,
			})
			task.wait(math.min(sound.TimeLength > 0 and sound.TimeLength * 0.75 or 0.8, 1.4) + rng:NextNumber(0.05, 0.2))
		end
	end)
end

if isNewChat then
	TextChatService.MessageReceived:Connect(function(message)
		local source = message.TextSource
		if not source then return end
		local plr = Players:GetPlayerByUserId(source.UserId)
		local character = plr and plr.Character
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		local text = message.Text or ""
		if plr == player then
			local duration = math.clamp(#text * 0.06, 1.2, 4.5)
			character:SetAttribute("TalkUntil", os.clock() + duration)
		end
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
		INFECTED = {
			"Someone you knew tore you apart. Their eyes were gone.",
			"The infected don't stop to talk.",
		},
		BEATEN = {
			"Beaten to death by another survivor.",
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
	{name = "FallDamageController", class = "ModuleScript", where = "Modules", source = [=[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RagdollController = require(script.Parent:WaitForChild("RagdollController"))
local FallDamageController = {}
local setups = {}

local SETTINGS = {

	LightHeight = 8,
	LightMinSpeed = 45,
	LightDamageMin = 4,
	LightDamageMax = 12,
	LightDurationMin = 0.8,
	LightDurationMax = 1.4,

	HeavyHeight = 18,
	HeavyDamageMin = 12,
	MaxHeight = 70,
	MaxDamage = 100,
	HeavyDurationMin = 2.0,
	HeavyDurationMax = 3.2,

	RecoveryGrace = 0.5,

	GibHeight = 55,
	GibSpeed = 150,
	GibDeathVisibleTime = 12,

	BruiseHealTime = 40,
	HeadDamageTime = 25,
	SeverChance = 0.3,
	LobotomyChance = 0.25,
	SpineChance = 0.12,
	BleedDecay = 0.02,
	SeverBleed = 1.1,
	SeverBleedFloor = 0.3,
	FractureBleed = 0.3,
	FractureBleedTime = 35,
	FallBleedPerDamage = 0.03,
	FallBleedMinHeight = 22,
	FallBleedTime = 20,
	SeveredLimbLifetime = 600,
	CorpseLifetime = 900,
	MaxCorpses = 12,
	PainThreshold = 0.4,
	HeadExplodeChance = 0.5,
	FallHeadExplodeHeight = 45,
	FallHeadExplodeChance = 0.25,
	DeathVisibleTime = 4,
	DeathFadeTime = 1,
}

local SOFT_SURFACES = {
	[Enum.Material.Snow] = 0.55,
	[Enum.Material.Sand] = 0.7,
	[Enum.Material.Mud] = 0.7,
	[Enum.Material.Fabric] = 0.6,
	[Enum.Material.LeafyGrass] = 0.85,
	[Enum.Material.Grass] = 0.9,
	[Enum.Material.Ground] = 0.9,
	[Enum.Material.Water] = 0,
}

do
	local ok, carpet = pcall(function() return Enum.Material.Carpet end)
	if ok and carpet then SOFT_SURFACES[carpet] = 0.75 end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function spawnGoreChunks(position, skin, count, speed)
	local folder = workspace:FindFirstChild("SeveredLimbs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SeveredLimbs"
		folder.Parent = workspace
	end
	local palette = {
		{skin, 0.45}, {Color3.fromRGB(92, 4, 4), 0.3}, {Color3.fromRGB(150, 60, 62), 0.1}, {Color3.fromRGB(222, 214, 196), 0.15},
	}
	for i = 1, count do
		local roll = math.random()
		local color = skin
		for _, entry in ipairs(palette) do
			roll -= entry[2]
			if roll <= 0 then color = entry[1] break end
		end
		local chunk = Instance.new("Part")
		chunk.Name = "GoreChunk"
		chunk.Size = Vector3.new(0.15 + math.random() * 0.35, 0.1 + math.random() * 0.25, 0.15 + math.random() * 0.3)
		chunk.Color = color
		chunk.Material = color == skin and Enum.Material.SmoothPlastic or Enum.Material.Glass
		chunk.CFrame = CFrame.new(position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.6)
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		chunk.CanCollide = true
		chunk.CanTouch = false
		chunk.CastShadow = false
		chunk.Parent = folder
		pcall(function() chunk:SetNetworkOwner(nil) end)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.9 + 0.2, math.random() - 0.5).Unit
		chunk.AssemblyLinearVelocity = dir * (speed * (0.6 + math.random() * 0.8))
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 40
		task.delay(120 + i, function() if chunk.Parent then chunk:Destroy() end end)
	end
end

function FallDamageController.Setup(character)
	assert(RunService:IsServer(), "FallDamageController.Setup must run on the server")
	if setups[character] then return end
	local record = {connections = {}, alive = true}
	setups[character] = record
	local function cleanup()
		if not record.alive then return end
		record.alive = false
		for _, connection in ipairs(record.connections) do connection:Disconnect() end
		setups[character] = nil
		RagdollController.Cleanup(character)
	end
	table.insert(record.connections, character.Destroying:Connect(cleanup))
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not record.alive or not humanoid or not root or not character.Parent
		or humanoid.RigType ~= Enum.HumanoidRigType.R6 then cleanup() return end
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	if not humanoid:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	character:SetAttribute("Ragdolled", false)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}
	params.RespectCanCollide = true
	local tracking = false
	local startY = root.Position.Y
	local lastGroundY = startY
	local maxSpeed = 0
	local graceUntil = 0
	local deathHandled = false
	local recoverToken = 0

	local function onDeath()
		if deathHandled or not record.alive then return end
		deathHandled = true
		tracking = false

		local lastTime = character:GetAttribute("LastDamageTime")
		local recent = lastTime and workspace:GetServerTimeNow() - lastTime < 3
		if not character:GetAttribute("DeathCause") then
			character:SetAttribute("DeathCause", recent and character:GetAttribute("LastDamageCause") or "UNKNOWN")
		end
		RagdollController.Enable(character)

		local gibbed = character:GetAttribute("Gibbed") == true
		if gibbed then
			local pool = {"Right Arm", "Left Arm", "Right Leg", "Left Leg", "Head"}
			local chosen = {}
			for _, name in ipairs(pool) do
				local chance = name == "Head" and 0.45 or 0.7
				if math.random() < chance then table.insert(chosen, name) end
			end
			if #chosen == 0 then table.insert(chosen, pool[math.random(1, 4)]) end
			character:SetAttribute("GibbedParts", table.concat(chosen, ","))
			RagdollController.Dismember(character, chosen, 50)
		end
		task.delay(SETTINGS.DeathVisibleTime, function()
			if not record.alive or not character.Parent then return end
			FallDamageController.MakeCorpse(character)
		end)
	end
	table.insert(record.connections, humanoid.Died:Connect(onDeath))
	if humanoid.Health <= 0 then onDeath() end

	local applyInjuries
	local closedFractureUntil = 0
	local function ragdollFor(duration, severity)
		character:SetAttribute("RagdollDuration", duration)
		character:SetAttribute("RagdollSeverity", severity)
		RagdollController.Enable(character)
		recoverToken += 1
		local token = recoverToken
		task.delay(duration, function()
			if token ~= recoverToken then return end
			if not record.alive or not character.Parent or humanoid.Health <= 0 then return end
			if character:GetAttribute("Paralyzed") then return end
			graceUntil = os.clock() + SETTINGS.RecoveryGrace
			tracking, maxSpeed, lastGroundY = false, 0, root.Position.Y
			RagdollController.Disable(character)
		end)
	end

	local history = {}
	local HISTORY_TIME = 8
	local lastProcessed = 0
	local pendingServerLanding = nil
	local lastReportAt = -math.huge

	local function peakSince(seconds)
		local now = os.clock()
		local peak = root.Position.Y
		for _, sample in ipairs(history) do
			if now - sample[1] <= seconds and sample[2] > peak then
				peak = sample[2]
			end
		end
		return peak
	end

	local INJURY_PARTS = {"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}
	local LIMB_INFO = {
		Head = {part = "Head", motor = "Neck"},
		RightArm = {part = "Right Arm", motor = "Right Shoulder"},
		LeftArm = {part = "Left Arm", motor = "Left Shoulder"},
		RightLeg = {part = "Right Leg", motor = "Right Hip"},
		LeftLeg = {part = "Left Leg", motor = "Left Hip"},
	}
	for _, part in ipairs(INJURY_PARTS) do
		character:SetAttribute("Injury_" .. part, 0)
	end

	local function sever(partKey)
		local info = LIMB_INFO[partKey]
		local torso = character:FindFirstChild("Torso")
		if not info or not torso then return end
		local limb = character:FindFirstChild(info.part)
		local motor = torso:FindFirstChild(info.motor)
		if motor then motor:Destroy() end

		if limb then
			for _, object in ipairs(torso:GetChildren()) do
				if object:IsA("BallSocketConstraint") and object.Attachment1 and object.Attachment1.Parent == limb then
					object:Destroy()
				end
			end
		end
		if limb and limb:IsA("BasePart") then
			local severedFolder = workspace:FindFirstChild("SeveredLimbs")
			if not severedFolder then
				severedFolder = Instance.new("Folder")
				severedFolder.Name = "SeveredLimbs"
				severedFolder.Parent = workspace
			end
			local model = Instance.new("Model")
			model.Name = "Severed_" .. info.part
			local fake = Instance.new("Humanoid")
			fake.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			fake.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			fake.NameDisplayDistance = 0
			fake.HealthDisplayDistance = 0
			fake.RequiresNeck = false
			fake.BreakJointsOnDeath = false
			fake.EvaluateStateMachine = false
			fake.PlatformStand = true
			fake.Parent = model
			for _, item in ipairs(character:GetChildren()) do
				if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("BodyColors") then
					item:Clone().Parent = model
				elseif item:IsA("CharacterMesh") then
					item:Clone().Parent = model
				elseif item:IsA("Accessory") then
					local handle = item:FindFirstChild("Handle")
					local weld = handle and handle:FindFirstChildWhichIsA("JointInstance")
					if weld and (weld.Part0 == limb or weld.Part1 == limb) then
						item.Parent = model
					end
				end
			end
			limb.Parent = model
			model.PrimaryPart = limb
			model.Parent = severedFolder
			limb.CanCollide = true
			limb.CanQuery = true
			pcall(function() limb:SetNetworkOwner(nil) end)
			local away = (limb.Position - torso.Position)
			away = away.Magnitude > 1e-3 and away.Unit or Vector3.new(0, 1, 0)
			limb.AssemblyLinearVelocity = (away + Vector3.new(0, 0.8, 0)).Unit * 28
			limb.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 25
			limb:SetAttribute("SeveredFrom", character.Name)
			task.delay(SETTINGS.SeveredLimbLifetime, function()
				if model.Parent then model:Destroy() end
			end)
		end
		character:SetAttribute("LastSevered", partKey)
		character:SetAttribute("LastSeveredTime", workspace:GetServerTimeNow())
	end

	local function injure(part, level)
		local key = "Injury_" .. part
		local current = character:GetAttribute(key) or 0
		if level <= current then return end
		if level >= 3 and not LIMB_INFO[part] then
			level = 2
		end
		character:SetAttribute(key, level)
		if level == 1 then
			local healTime = part == "Head" and SETTINGS.HeadDamageTime or SETTINGS.BruiseHealTime
			task.delay(healTime, function()
				if record.alive and character.Parent and character:GetAttribute(key) == 1 then
					character:SetAttribute(key, 0)
				end
			end)
		end
	end
	record.injure = injure

	local function explodeHead()
		local head = character:FindFirstChild("Head")
		if not head or not head:IsA("BasePart") or character:GetAttribute("HeadExploded") then return end
		local position = head.Position
		local skin = head.Color
		character:SetAttribute("DeathCause", "HEAD_EXPLODED")
		character:SetAttribute("LastDamageCause", "HEAD_EXPLODED")
		character:SetAttribute("LastDamageTime", workspace:GetServerTimeNow())
		character:SetAttribute("HeadExplodePosition", position)
		character:SetAttribute("HeadExploded", true)
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Accessory") then
				local handle = item:FindFirstChild("Handle")
				local weld = handle and handle:FindFirstChildWhichIsA("JointInstance")
				if weld and (weld.Part0 == head or weld.Part1 == head) then item:Destroy() end
			end
		end
		for _, d in ipairs(head:GetChildren()) do
			if d:IsA("Decal") or d:IsA("SpecialMesh") or d:IsA("Sound") then d:Destroy() end
		end
		head.Transparency = 1
		head.CanCollide = false
		head.CanQuery = false
		local severedFolder = workspace:FindFirstChild("SeveredLimbs")
		if not severedFolder then
			severedFolder = Instance.new("Folder")
			severedFolder.Name = "SeveredLimbs"
			severedFolder.Parent = workspace
		end
		local palette = {
			{skin, 0.45}, {Color3.fromRGB(92, 4, 4), 0.25}, {Color3.fromRGB(150, 60, 62), 0.15}, {Color3.fromRGB(222, 214, 196), 0.15},
		}
		local function pickColor()
			local roll = math.random()
			for _, entry in ipairs(palette) do
				roll -= entry[2]
				if roll <= 0 then return entry[1] end
			end
			return skin
		end
		for i = 1, 16 do
			local chunk = Instance.new("Part")
			chunk.Name = "HeadChunk"
			local s1 = 0.15 + math.random() * 0.35
			chunk.Size = Vector3.new(s1, 0.1 + math.random() * 0.25, 0.15 + math.random() * 0.3)
			chunk.Color = pickColor()
			chunk.Material = (chunk.Color == skin) and Enum.Material.SmoothPlastic or Enum.Material.Glass
			chunk.Reflectance = 0
			chunk.CFrame = CFrame.new(position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.6)
				* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			chunk.CanCollide = true
			chunk.CanTouch = false
			chunk.CastShadow = false
			chunk.Parent = severedFolder
			pcall(function() chunk:SetNetworkOwner(nil) end)
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.9 + 0.2, math.random() - 0.5).Unit
			chunk.AssemblyLinearVelocity = dir * (25 + math.random() * 30)
			chunk.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 40
			task.delay(45 + i, function() if chunk.Parent then chunk:Destroy() end end)
		end
		humanoid.Health = 0
		onDeath()
	end
	record.explodeHead = explodeHead

	local passOutUntil = 0
	local lastHealthSeen = humanoid.Health
	table.insert(record.connections, humanoid.HealthChanged:Connect(function(health)
		local damage = lastHealthSeen - health
		lastHealthSeen = health
		if damage < 3 or health <= 0 or not record.alive then return end
		local frac = health / math.max(humanoid.MaxHealth, 1)
		if frac > SETTINGS.PainThreshold then return end
		if character:GetAttribute("Paralyzed") then return end
		local now = os.clock()
		if now < passOutUntil then return end
		local chance = (0.15 + 0.55 * (SETTINGS.PainThreshold - frac) / SETTINGS.PainThreshold) * math.clamp(damage / 12, 0.3, 1.2)
		if math.random() < chance then
			local duration = 3.5 + math.random() * 4 + (1 - frac) * 2
			passOutUntil = now + duration + 12
			task.defer(function()
				if not record.alive or humanoid.Health <= 0 then return end
				character:SetAttribute("PassedOut", workspace:GetServerTimeNow())
				ragdollFor(duration, 1)
			end)
		end
	end))
	record.ragdollFor = ragdollFor

	local severed = {}
	local paralyzed = false

	local bleeds = {}
	local bloodLost = 0
	local bleedAttrTimer = 0
	local function addBleed(rate, duration, floor)
		local entry = {rate = rate, left = duration or math.huge, floor = floor or 0, decay = SETTINGS.BleedDecay}
		table.insert(bleeds, entry)
		return entry
	end
	record.addBleed = addBleed
	record.stopBleeding = function()
		table.clear(bleeds)
		character:SetAttribute("Bleeding", 0)
	end
	character:SetAttribute("Bleeding", 0)
	character:SetAttribute("BloodLost", 0)

	table.insert(record.connections, RunService.Heartbeat:Connect(function(dt)
		if not record.alive or humanoid.Health <= 0 then return end
		local total = 0
		for i = #bleeds, 1, -1 do
			local b = bleeds[i]
			b.left -= dt
			b.rate = math.max(b.floor, b.rate - b.decay * dt)
			if b.left <= 0 or b.rate <= 0.001 then
				table.remove(bleeds, i)
			else
				total += b.rate
			end
		end
		if total > 0 then
			local damage = total * dt
			bloodLost += damage
			if humanoid.Health - damage <= 0 then
				character:SetAttribute("DeathCause", "BLEEDING")
				character:SetAttribute("LastDamageCause", "BLEEDING")
				character:SetAttribute("LastDamageTime", workspace:GetServerTimeNow())
			end
			humanoid:TakeDamage(damage)
			if humanoid.Health <= 0 then onDeath() end
		end
		bleedAttrTimer += dt
		if bleedAttrTimer > 0.25 then
			bleedAttrTimer = 0
			character:SetAttribute("Bleeding", math.floor(total * 100 + 0.5) / 100)
			character:SetAttribute("BloodLost", math.floor(bloodLost + 0.5))
		end
	end))

	local loose = {}
	local DOWN_AXIS = CFrame.Angles(0, 0, -math.pi / 2)
	local function loosen(partKey)
		local info = LIMB_INFO[partKey]
		local torso = character:FindFirstChild("Torso")
		if not info or not torso or partKey == "Head" then return end
		local limb = character:FindFirstChild(info.part)
		local motor = torso:FindFirstChild(info.motor)
		if not limb or not motor or not motor:IsA("Motor6D") then return end
		local entry = loose[partKey]
		if not entry then
			entry = {limb = limb, motor = motor, objects = {}}
			local p1 = partKey:find("Leg") and Vector3.new(0, limb.Size.Y * 0.5 - 0.15, 0) or Vector3.new(0, limb.Size.Y * 0.25, 0)
			local p0 = (motor.C0 * motor.C1:Inverse() * CFrame.new(p1)).Position
			local a0 = Instance.new("Attachment")
			a0.Name = "GS_LooseAttachment0"
			a0.CFrame = CFrame.new(p0) * DOWN_AXIS
			a0.Parent = torso
			local a1 = Instance.new("Attachment")
			a1.Name = "GS_LooseAttachment1"
			a1.CFrame = CFrame.new(p1) * DOWN_AXIS
			a1.Parent = limb
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "GS_LooseJoint"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = partKey:find("Leg") and 50 or 75
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -25
			socket.TwistUpperAngle = 25
			socket.MaxFrictionTorque = 1.5
			socket.Parent = torso
			table.insert(entry.objects, a0)
			table.insert(entry.objects, a1)
			table.insert(entry.objects, socket)
			local collider = Instance.new("Part")
			collider.Name = "GS_LooseCollider"

			collider.Size = limb.Size * Vector3.new(0.8, 0.72, 0.8)
			collider.CFrame = limb.CFrame * CFrame.new(0, limb.Size.Y * 0.12, 0)
			collider.Transparency = 1
			collider.CanCollide = true
			collider.CanQuery = false
			collider.CanTouch = false
			collider.CastShadow = false
			collider.Massless = true
			collider.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0, 0, 100, 1)
			collider.Parent = limb
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = limb
			weld.Part1 = collider
			weld.Parent = collider
			table.insert(entry.objects, collider)
			for _, other in ipairs(character:GetDescendants()) do
				if other:IsA("BasePart") and other ~= limb and other ~= collider then
					local nc = Instance.new("NoCollisionConstraint")
					nc.Name = "GS_LooseNoCollide"
					nc.Part0 = collider
					nc.Part1 = other
					nc.Parent = collider
				end
			end
			entry.props = limb.CustomPhysicalProperties
			loose[partKey] = entry
		end
		motor.Enabled = false
		local ragdolledNow = character:GetAttribute("Ragdolled") == true
		for _, object in ipairs(entry.objects) do
			if object:IsA("Constraint") then object.Enabled = not ragdolledNow end
			-- no collision right after the break (the limb spawns inside the floor and would launch
			-- the body); the collider comes back a second later once the limb has settled
			if object:IsA("BasePart") then object.CanCollide = false end
		end
		if not ragdolledNow then limb.CanCollide = false end
		entry.collideToken = (entry.collideToken or 0) + 1
		local collideToken = entry.collideToken
		task.delay(1, function()
			if loose[partKey] ~= entry or entry.collideToken ~= collideToken then return end
			if character:GetAttribute("Ragdolled") or humanoid.Health <= 0 then return end
			for _, object in ipairs(entry.objects) do
				if object:IsA("BasePart") and object.Parent then object.CanCollide = true end
			end
		end)
		limb.Massless = true
		limb.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.15, 0, 1, 1)
	end
	local function tighten(partKey)
		local entry = loose[partKey]
		if not entry then return end
		loose[partKey] = nil
		for _, object in ipairs(entry.objects) do object:Destroy() end
		if entry.motor.Parent then entry.motor.Enabled = true end
		if entry.limb.Parent then
			entry.limb.CanCollide = false
			entry.limb.Massless = false
			entry.limb.CustomPhysicalProperties = entry.props
		end
	end
	table.insert(record.connections, character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		local ragdolledNow = character:GetAttribute("Ragdolled") or humanoid.Health <= 0
		for _, entry in pairs(loose) do
			for _, object in ipairs(entry.objects) do
				if object:IsA("BasePart") then object.CanCollide = false end

				if object:IsA("Constraint") then object.Enabled = not ragdolledNow end
			end
		end
		if ragdolledNow then return end
		task.defer(function()
			for partKey in pairs(loose) do
				if (character:GetAttribute("Injury_" .. partKey) or 0) == 2 then loosen(partKey) end
			end
		end)
	end))

	local explodeNext = {}
	local severBleeds = {}
	local limbTemplates = {}
	do
		local torso0 = character:FindFirstChild("Torso")
		for key, info in pairs(LIMB_INFO) do
			if key ~= "Head" and torso0 then
				local limb = character:FindFirstChild(info.part)
				local motor = torso0:FindFirstChild(info.motor)
				if limb and motor then
					limb.Archivable = true
					local okClone, copy = pcall(function() return limb:Clone() end)
					if okClone and copy then
						for _, d in ipairs(copy:GetChildren()) do
							if not (d:IsA("DataModelMesh") or d:IsA("Decal") or d:IsA("Attachment")) then d:Destroy() end
						end
						limbTemplates[key] = {part = copy, c0 = motor.C0, c1 = motor.C1}
					end
				end
			end
		end
	end

	local function explodeLimb(partKey)
		local info = LIMB_INFO[partKey]
		local torso = character:FindFirstChild("Torso")
		if not info or not torso then return end
		local limb = character:FindFirstChild(info.part)
		if not limb then return end
		if loose[partKey] then tighten(partKey) end
		local position, skin = limb.Position, limb.Color
		for _, object in ipairs(torso:GetDescendants()) do
			if object:IsA("BallSocketConstraint") and object.Attachment1 and object.Attachment1.Parent == limb then
				object:Destroy()
			end
		end
		local motor = torso:FindFirstChild(info.motor)
		if motor then motor:Destroy() end
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Accessory") then
				local handle = item:FindFirstChild("Handle")
				local weld = handle and handle:FindFirstChildWhichIsA("JointInstance")
				if weld and (weld.Part0 == limb or weld.Part1 == limb) then item:Destroy() end
			end
		end
		limb:Destroy()
		spawnGoreChunks(position, skin, 12, 32)
		character:SetAttribute("LimbExplodePosition", position)
		character:SetAttribute("LimbExploded", partKey .. "|" .. tostring(os.clock()))
		character:SetAttribute("LastSevered", partKey)
		character:SetAttribute("LastSeveredTime", workspace:GetServerTimeNow())
	end

	local function restoreLimb(partKey)
		if not record.alive or humanoid.Health <= 0 then return false, "dead" end
		if partKey == "Torso" or partKey == "Head" then
			character:SetAttribute("Injury_" .. partKey, 0)
			return true
		end
		local info = LIMB_INFO[partKey]
		local torso = character:FindFirstChild("Torso")
		if not info or not torso then return false, "no torso" end
		local limb = character:FindFirstChild(info.part)
		local motor = torso:FindFirstChild(info.motor)
		if limb and motor then
			character:SetAttribute("Injury_" .. partKey, 0)
			return true
		end
		local template = limbTemplates[partKey]
		if not template then return false, "no template" end
		if limb then limb:Destroy() end
		if motor then motor:Destroy() end
		local newLimb = template.part:Clone()
		newLimb.CFrame = torso.CFrame * template.c0 * template.c1:Inverse()
		newLimb.Parent = character
		local newMotor = Instance.new("Motor6D")
		newMotor.Name = info.motor
		newMotor.Part0 = torso
		newMotor.Part1 = newLimb
		newMotor.C0 = template.c0
		newMotor.C1 = template.c1
		newMotor.Parent = torso
		local bleedEntry = severBleeds[partKey]
		if bleedEntry then
			local index = table.find(bleeds, bleedEntry)
			if index then table.remove(bleeds, index) end
			severBleeds[partKey] = nil
		end
		severed[partKey] = nil
		character:SetAttribute("Injury_" .. partKey, 0)
		character:SetAttribute("RigVersion", (character:GetAttribute("RigVersion") or 0) + 1)
		return true
	end
	record.restoreLimb = restoreLimb
	record.explodePart = function(partKey)
		if humanoid.Health <= 0 then return false, "dead" end
		if partKey == "Torso" then
			local torso = character:FindFirstChild("Torso")
			if torso then spawnGoreChunks(torso.Position, torso.Color, 18, 40) end
			character:SetAttribute("Gibbed", true)
			character:SetAttribute("DeathCause", "GIBBED")
			character:SetAttribute("LastDamageCause", "GIBBED")
			character:SetAttribute("LastDamageTime", workspace:GetServerTimeNow())
			humanoid.Health = 0
			onDeath()
			return true
		end
		if not LIMB_INFO[partKey] then return false, "bad part" end
		if (character:GetAttribute("Injury_" .. partKey) or 0) >= 3 then return false, "already gone" end
		explodeNext[partKey] = true
		character:SetAttribute("Injury_" .. partKey, 3)
		return true
	end

	local function onInjuryChanged(part)
		local level = character:GetAttribute("Injury_" .. part) or 0
		if not record.alive then return end
		if part ~= "Head" and part ~= "Torso" and LIMB_INFO[part] then
			if level == 2 and humanoid.Health > 0 then
				loosen(part)
			elseif loose[part] then
				tighten(part)
			end
		end
		if level >= 3 and LIMB_INFO[part] and not severed[part] then
			severed[part] = true
			if part == "Head" and (explodeNext[part] or math.random() < SETTINGS.HeadExplodeChance) then
				explodeNext[part] = nil
				explodeHead()
			elseif part == "Head" then

				character:SetAttribute("DeathCause", "DECAPITATED")
				character:SetAttribute("LastDamageCause", "DECAPITATED")
				character:SetAttribute("LastDamageTime", workspace:GetServerTimeNow())
				sever(part)
				humanoid.Health = 0
				onDeath()
			elseif explodeNext[part] then
				explodeNext[part] = nil
				explodeLimb(part)
				severBleeds[part] = addBleed(SETTINGS.SeverBleed * 1.2, math.huge, SETTINGS.SeverBleedFloor)
			else
				sever(part)
				severBleeds[part] = addBleed(SETTINGS.SeverBleed, math.huge, SETTINGS.SeverBleedFloor)
			end
		elseif level == 2 and humanoid.Health > 0 and part ~= "Torso" and os.clock() > closedFractureUntil then
			addBleed(SETTINGS.FractureBleed, SETTINGS.FractureBleedTime)
		elseif part == "Torso" and level < 2 and paralyzed and humanoid.Health > 0 then

			paralyzed = false
			character:SetAttribute("Paralyzed", false)
			graceUntil = os.clock() + SETTINGS.RecoveryGrace
			RagdollController.Disable(character)
		elseif part == "Torso" and level >= 2 and not paralyzed and humanoid.Health > 0 then

			paralyzed = true
			character:SetAttribute("Paralyzed", true)
			character:SetAttribute("RagdollDuration", 4)
			character:SetAttribute("RagdollSeverity", 0.9)
			RagdollController.Enable(character)
		end
	end
	for _, part in ipairs(INJURY_PARTS) do
		table.insert(record.connections, character:GetAttributeChangedSignal("Injury_" .. part):Connect(function()
			onInjuryChanged(part)
		end))
	end

	applyInjuries = function(fallHeight, softness)
		if fallHeight < SETTINGS.FallBleedMinHeight then
			closedFractureUntil = os.clock() + 1
		end
		local chanceScale = softness
		local legs = {"RightLeg", "LeftLeg"}
		local arms = {"RightArm", "LeftArm"}
		local firstLeg = legs[math.random(1, 2)]
		local otherLeg = firstLeg == "RightLeg" and "LeftLeg" or "RightLeg"
		if fallHeight < SETTINGS.HeavyHeight then
			if math.random() < 0.45 * chanceScale then injure(firstLeg, 1) end
		elseif fallHeight < 35 then
			injure(firstLeg, math.random() < 0.8 * chanceScale and 2 or 1)
			if math.random() < 0.5 then injure(otherLeg, 1) end
			if math.random() < 0.3 then injure(arms[math.random(1, 2)], 1) end
			injure("Torso", 1)
			if math.random() < 0.35 then injure("Head", 1) end
		else

			injure(firstLeg, math.random() < SETTINGS.SeverChance * chanceScale and 3 or 2)
			injure(otherLeg, math.random() < 0.55 * chanceScale and 2 or 1)
			local arm = arms[math.random(1, 2)]
			local armRoll = math.random()
			injure(arm, armRoll < SETTINGS.SeverChance * 0.6 * chanceScale and 3 or (armRoll < 0.5 and 2 or 1))
			injure("Torso", math.random() < SETTINGS.SpineChance * chanceScale and 2 or 1)
			local headRoll = math.random()
			if headRoll < SETTINGS.LobotomyChance * chanceScale then
				injure("Head", 2)
			elseif headRoll < 0.7 then
				injure("Head", 1)
			end
		end
	end

	local function processLanding(fallHeight, speed, material)
		if not record.alive or humanoid.Health <= 0 or character:GetAttribute("Ragdolled") then return end
		local now = os.clock()
		if now - lastProcessed < 0.75 then return end
		if fallHeight < SETTINGS.LightHeight or speed < SETTINGS.LightMinSpeed then return end
		lastProcessed = now
		pendingServerLanding = nil

		local softness = SOFT_SURFACES[material] or 1
		if softness <= 0 then return end

		local damage, duration, severity
		if fallHeight < SETTINGS.HeavyHeight then
			local t = math.clamp((fallHeight - SETTINGS.LightHeight) / (SETTINGS.HeavyHeight - SETTINGS.LightHeight), 0, 1)
			damage = lerp(SETTINGS.LightDamageMin, SETTINGS.LightDamageMax, t)
			duration = lerp(SETTINGS.LightDurationMin, SETTINGS.LightDurationMax, t)
			severity = lerp(0.15, 0.4, t)
		else
			local t = math.clamp((fallHeight - SETTINGS.HeavyHeight) / (SETTINGS.MaxHeight - SETTINGS.HeavyHeight), 0, 1)
			damage = lerp(SETTINGS.HeavyDamageMin, SETTINGS.MaxDamage, t ^ 1.4)
			duration = lerp(SETTINGS.HeavyDurationMin, SETTINGS.HeavyDurationMax, t)
			severity = lerp(0.5, 1, t)
		end
		damage *= softness
		duration *= lerp(0.7, 1, softness)

		if (fallHeight >= SETTINGS.GibHeight or speed >= SETTINGS.GibSpeed) and softness >= 0.7
			and humanoid.Health - damage <= 0 then
			character:SetAttribute("Gibbed", true)
		end

		if fallHeight >= SETTINGS.FallHeadExplodeHeight and humanoid.Health - damage <= 0
			and not character:GetAttribute("Gibbed") and math.random() < SETTINGS.FallHeadExplodeChance then
			character:SetAttribute("LastFallHeight", math.floor(fallHeight + 0.5))
			explodeHead()
			return
		end
		applyInjuries(fallHeight, softness)

		character:SetAttribute("LastDamageCause", "FALL")
		character:SetAttribute("LastDamageTime", workspace:GetServerTimeNow())
		character:SetAttribute("LastFallHeight", math.floor(fallHeight + 0.5))
		humanoid:TakeDamage(damage)
		if humanoid.Health <= 0 then onDeath() return end
		if fallHeight >= SETTINGS.FallBleedMinHeight then
			addBleed(math.clamp(damage * SETTINGS.FallBleedPerDamage, 0.08, 0.8), SETTINGS.FallBleedTime)
		end
		ragdollFor(duration, severity)
	end

	local function groundMaterial()
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -7, 0), params)
		return hit and hit.Material or Enum.Material.Plastic
	end

	record.handleReport = function(height, speed)
		if typeof(height) ~= "number" or typeof(speed) ~= "number" then return end
		if height ~= height or speed ~= speed then return end
		if graceUntil > os.clock() then return end
		lastReportAt = os.clock()
		pendingServerLanding = nil

		local observedDrop = peakSince(HISTORY_TIME) - root.Position.Y
		height = math.clamp(height, 0, math.max(0, observedDrop) + 6)
		local maxPossibleSpeed = math.sqrt(2 * workspace.Gravity * (height + 6)) + 25
		speed = math.clamp(speed, 0, maxPossibleSpeed)
		processLanding(height, speed, groundMaterial())
	end

	table.insert(record.connections, RunService.Heartbeat:Connect(function()
		if not character.Parent or not root.Parent then cleanup() return end
		if humanoid.Health <= 0 then onDeath() return end
		local now = os.clock()
		table.insert(history, {now, root.Position.Y})
		while history[1] and now - history[1][1] > HISTORY_TIME do
			table.remove(history, 1)
		end

		if pendingServerLanding and now >= pendingServerLanding.at then
			local landing = pendingServerLanding
			pendingServerLanding = nil
			processLanding(landing.height, landing.speed, landing.material)
		end

		local state = humanoid:GetState()
		if character:GetAttribute("Ragdolled") or humanoid.PlatformStand or humanoid.Sit
			or state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.Climbing
			or now < graceUntil then
			tracking, maxSpeed, lastGroundY = false, 0, root.Position.Y
			return
		end
		local velocity = root.AssemblyLinearVelocity
		local leg = character:FindFirstChild("Left Leg")
		local standingHeight = root.Size.Y * 0.5 + humanoid.HipHeight + (leg and leg.Size.Y or 2)
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -standingHeight - 0.6, 0), params)
		local grounded = hit ~= nil and velocity.Y <= 4
		if not grounded then
			if not tracking then
				tracking = true
				startY = lastGroundY
				maxSpeed = 0
			end
			maxSpeed = math.max(maxSpeed, -velocity.Y)
			return
		end
		lastGroundY = root.Position.Y
		if not tracking then return end
		local fallHeight = startY - root.Position.Y

		local speed = math.max(maxSpeed, -velocity.Y, math.sqrt(2 * workspace.Gravity * math.max(fallHeight, 0)) * 0.9)
		tracking, maxSpeed = false, 0
		if now - lastReportAt < 1 then return end
		pendingServerLanding = {at = now + 0.4, height = fallHeight, speed = speed, material = hit.Material}
	end))
end

function FallDamageController.Injure(character, part, level)
	local record = setups[character]
	if record and record.alive and record.injure then
		record.injure(part, level)
	end
end

function FallDamageController.AddBleeding(character, rate, duration)
	local record = setups[character]
	if record and record.alive and record.addBleed then
		record.addBleed(rate or 0.5, duration or 20)
	end
end

function FallDamageController.StopBleeding(character)
	local record = setups[character]
	if record and record.alive and record.stopBleeding then
		record.stopBleeding()
	end
end

function FallDamageController.Ragdoll(character, duration, severity)
	local record = setups[character]
	if record and record.alive and record.ragdollFor then
		record.ragdollFor(duration or 3, severity or 0.4)
	end
end

local corpseList = {}

function FallDamageController.MakeCorpse(character)
	if not character or not character.Parent then return nil end
	local folder = workspace:FindFirstChild("Corpses")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Corpses"
		folder.Parent = workspace
	end
	character.Archivable = true
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Attachment")
			or d:IsA("Clothing") or d:IsA("Accessory") or d:IsA("Decal") or d:IsA("DataModelMesh")
			or d:IsA("BodyColors") or d:IsA("CharacterMesh") or d:IsA("ShirtGraphic") then
			d.Archivable = true
		end
	end
	local ok, corpse = pcall(function() return character:Clone() end)
	if not ok or not corpse then
		character:Destroy()
		return nil
	end
	corpse.Name = "Corpse_" .. character.Name
	for _, d in ipairs(corpse:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("BillboardGui")
			or d:IsA("ParticleEmitter") or d:IsA("Tool") or d:IsA("Animator") then
			d:Destroy()
		end
	end
	for attribute in pairs(corpse:GetAttributes()) do
		corpse:SetAttribute(attribute, nil)
	end
	corpse:SetAttribute("Corpse", true)
	local owner = Players:GetPlayerFromCharacter(character)
	if owner then corpse:SetAttribute("CorpseUserId", owner.UserId) end
	local lost = {}
	for _, key in ipairs({"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}) do
		if (character:GetAttribute("Injury_" .. key) or 0) >= 3 then table.insert(lost, key) end
	end
	corpse:SetAttribute("LostParts", table.concat(lost, ","))
	corpse:SetAttribute("DeathCause", character:GetAttribute("DeathCause"))
	local humanoid = corpse:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.PlatformStand = true
		pcall(function() humanoid.EvaluateStateMachine = false end)
	end
	local root = corpse:FindFirstChild("HumanoidRootPart")
	if root then root:Destroy() end
	corpse.Parent = folder
	for _, d in ipairs(corpse:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			pcall(function() d:SetNetworkOwner(nil) end)
		end
	end
	character:Destroy()
	table.insert(corpseList, corpse)
	while #corpseList > SETTINGS.MaxCorpses do
		local old = table.remove(corpseList, 1)
		if old and old.Parent then old:Destroy() end
	end
	task.delay(SETTINGS.CorpseLifetime, function()
		if not corpse.Parent then return end
		for _, d in ipairs(corpse:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				TweenService:Create(d, TweenInfo.new(4), {Transparency = 1}):Play()
			end
		end
		task.wait(4.2)
		if corpse.Parent then corpse:Destroy() end
		local index = table.find(corpseList, corpse)
		if index then table.remove(corpseList, index) end
	end)
	return corpse
end

function FallDamageController.ExplodePart(character, part)
	local record = setups[character]
	if record and record.alive and record.explodePart then
		return record.explodePart(part)
	end
	return false, "no character"
end

function FallDamageController.RestorePart(character, part)
	local record = setups[character]
	if record and record.alive and record.restoreLimb then
		return record.restoreLimb(part)
	end
	return false, "no character"
end

function FallDamageController.ExplodeHead(character)
	local record = setups[character]
	if record and record.alive and record.explodeHead then
		record.explodeHead()
		return true
	end
	return false
end

function FallDamageController.Report(character, height, speed)
	local record = setups[character]
	if record and record.alive and record.handleReport then
		record.handleReport(height, speed)
	end
end

return FallDamageController
]=]},
	{name = "InfectionHUD", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "InfectionHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Color3.fromRGB(90, 0, 4)
vignette.BorderSizePixel = 0
vignette.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.7, 1),
	NumberSequenceKeypoint.new(1, 0.35),
})
gradient.Parent = vignette

local function label(y, size, color)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.fromOffset(700, size + 6)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.SpecialElite
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.5
	l.Parent = gui
	return l
end
local master = label(28, 26, Color3.fromRGB(200, 20, 20))
master.Text = "THE FLESH IS YOUR MASTER"
local order = label(60, 18, Color3.fromRGB(225, 215, 210))
order.Text = "KILL THE SURVIVORS"
local count = label(84, 14, Color3.fromRGB(150, 140, 136))

local function survivorsLeft()
	local n = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		local character = plr.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not character:GetAttribute("Infected") then n += 1 end
	end
	return n
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local on = player:GetAttribute("Infected") == true and humanoid ~= nil and humanoid.Health > 0
	gui.Enabled = on
	if not on then return end
	local t = os.clock()
	vignette.BackgroundTransparency = 0.55 + 0.15 * math.sin(t * 2.2)
	master.Position = UDim2.new(0.5, math.random(-1, 1), 0, 28 + math.random(-1, 1))
	count.Text = string.format("survivors left: %d", survivorsLeft())
end)
]=]},
	{name = "MonsterClient", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SoundConfig = require(Modules:WaitForChild("SoundConfig"))

local player = Players.LocalPlayer
local fxRemote = ReplicatedStorage:WaitForChild("MonsterFX", 60)
local strikeRemote = ReplicatedStorage:WaitForChild("PlayerStrike", 60)
local rng = Random.new()

local AMBIENT = {"BranchSnap", "Knock", "WoodCreak", "BranchSnap"}

local function play(name, parent, props)
	local ok, sound = pcall(SoundConfig.PlayOnce, name, parent, props)
	return ok and sound or nil
end

local HANDLERS = {

	Growl = function(head)
		play(SoundConfig.Random("Breath"), head, {
			PlaybackSpeed = rng:NextNumber(0.38, 0.5), Volume = 1.1, RollOffMaxDistance = 55, RollOffMinDistance = 4,
		})
	end,

	Ambient = function(head)
		play(SoundConfig.Random(AMBIENT[rng:NextInteger(1, #AMBIENT)]), head, {
			PlaybackSpeed = rng:NextNumber(0.9, 1.05), Volume = 0.9, RollOffMaxDistance = 110, RollOffMinDistance = 8,
		})
	end,

	Mimic = function(head)
		local r = rng:NextNumber()
		local name = r < 0.45 and SoundConfig.Random("PainScream") or (r < 0.75 and "DistantScream" or SoundConfig.Random("AgonyScream"))
		local sound = play(name, head, {
			PlaybackSpeed = rng:NextNumber(0.9, 0.97), Volume = 0.85, RollOffMaxDistance = 170, RollOffMinDistance = 12,
		})
		if sound and rng:NextNumber() < 0.5 then

			task.delay(rng:NextNumber(0.8, 1.6), function()
				if sound.Parent then sound:Stop() sound:Destroy() end
			end)
		end
	end,

	Shriek = function(head)
		play("DeathScream3", head, {PlaybackSpeed = rng:NextNumber(1.05, 1.2), Volume = 1, RollOffMaxDistance = 140, RollOffMinDistance = 10})
		play("FearHit", head, {Volume = 0.6, RollOffMaxDistance = 60})
	end,

	Hurt = function(head)
		play("DeathScream3", head, {PlaybackSpeed = rng:NextNumber(1.45, 1.7), Volume = 0.9, RollOffMaxDistance = 120})
		play(SoundConfig.Random("BloodHit"), head, {Volume = 0.8})
	end,

	Hit = function(head)
		play(SoundConfig.Random("BloodHit"), head, {Volume = 1, RollOffMaxDistance = 70})
	end,

	Mumble = function(head)
		local model = head.Parent
		local pitch = 0.9 + (((model and model:GetAttribute("VoicePitch")) or rng:NextNumber()) - 0.5) * 0.25
		for _ = 1, rng:NextInteger(1, 3) do
			if not head.Parent then break end
			local sound = play(SoundConfig.Random("Mumble"), head, {
				PlaybackSpeed = pitch * rng:NextNumber(0.94, 1.08), RollOffMaxDistance = 45, RollOffMinDistance = 6,
			})
			task.wait(sound and math.min(sound.TimeLength > 0 and sound.TimeLength * 0.75 or 0.8, 1.4) or 0.8)
		end
	end,

	Reveal = function(head)
		play("DeathScream3", head, {PlaybackSpeed = rng:NextNumber(0.62, 0.72), Volume = 1, RollOffMaxDistance = 120, RollOffMinDistance = 10})
		play(SoundConfig.Random("BoneCrack"), head, {Volume = 1, RollOffMaxDistance = 60})
		task.delay(0.25, function() if head.Parent then play(SoundConfig.Random("BoneCrack"), head, {Volume = 0.9}) end end)
		local character = player.Character
		local myHead = character and character:FindFirstChild("Head")
		if myHead and (myHead.Position - head.Position).Magnitude < 40 then
			play("FearHit", SoundService, {Volume = 0.8})
		end
	end,

	Eat = function(head)
		for i = 0, 6 do
			task.delay(i * 0.45 + rng:NextNumber(0, 0.15), function()
				if not head.Parent then return end
				if i % 2 == 0 then
					play(SoundConfig.Random("Gore"), head, {Volume = 0.8, PlaybackSpeed = rng:NextNumber(0.6, 0.8), RollOffMaxDistance = 60})
				else
					play(SoundConfig.Random("BoneCrack"), head, {Volume = 0.7, PlaybackSpeed = rng:NextNumber(0.8, 1), RollOffMaxDistance = 60})
				end
			end)
		end
	end,
}

local trailParts = {}
local function showTrail(points)
	for _, p in ipairs(trailParts) do p:Destroy() end
	table.clear(trailParts)
	local holder = Instance.new("Folder")
	holder.Name = "GS_TrailDebug"
	holder.Parent = workspace
	table.insert(trailParts, holder)
	for _, entry in ipairs(points or {}) do
		local pos, age = entry[1], entry[2]
		local dot = Instance.new("Part")
		dot.Anchored, dot.CanCollide, dot.CanQuery, dot.CanTouch, dot.CastShadow = true, false, false, false, false
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.new(0.5, 0.5, 0.5)
		dot.Material = Enum.Material.Neon
		dot.Color = Color3.fromRGB(255, 40, 40):Lerp(Color3.fromRGB(80, 0, 120), math.clamp(age / 360, 0, 1))
		dot.Position = pos + Vector3.new(0, 0.2, 0)
		dot.Parent = holder
	end
	task.delay(15, function()
		if holder.Parent then holder:Destroy() end
	end)
end

if fxRemote then
	fxRemote.OnClientEvent:Connect(function(model, kind, extra)
		if kind == "Trail" then
			showTrail(extra)
			return
		end
		if typeof(model) ~= "Instance" or not model.Parent then return end
		local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
		local handler = HANDLERS[kind]
		if head and handler then task.spawn(handler, head) end
	end)
end

local ContextActionService = game:GetService("ContextActionService")
local lastStrike = 0
local function strike()
	if UserInputService:GetFocusedTextBox() or player:GetAttribute("UIOpen") then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Ragdolled") then return end
	local left = character:GetAttribute("Injury_LeftArm") or 0
	local right = character:GetAttribute("Injury_RightArm") or 0
	if left >= 2 and right >= 2 then return end
	local now = os.clock()
	if now - lastStrike < 0.7 then return end
	lastStrike = now
	character:SetAttribute("GS_AttackStart", now)
	play("Grunt", character:FindFirstChild("Head") or SoundService, {Volume = 0.6, PlaybackSpeed = rng:NextNumber(1, 1.2)})
	if strikeRemote then strikeRemote:FireServer() end
end
-- F on keyboard, X on gamepad, an on-screen HIT button on phones and tablets
ContextActionService:BindAction("GS_Strike", function(_, state)
	if state == Enum.UserInputState.Begin then strike() end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("GS_Strike", "HIT")
ContextActionService:SetPosition("GS_Strike", UDim2.new(1, -170, 1, -150))

local RunService = game:GetService("RunService")
local disguises = {}

local function makeDisguiseTag(model)
	if disguises[model] then return end
	local head = model:WaitForChild("Head", 10)
	if not head then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GS_DisguiseTag"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(220, 48)
	billboard.StudsOffset = Vector3.new(0, 2.1, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 12
	billboard.ResetOnSpawn = false
	billboard.Parent = player:WaitForChild("PlayerGui")
	local display = Instance.new("TextLabel")
	display.Size = UDim2.new(1, 0, 0, 26)
	display.BackgroundTransparency = 1
	display.Font = Enum.Font.SpecialElite
	display.TextSize = 20
	display.TextColor3 = Color3.fromRGB(215, 210, 205)
	display.TextStrokeColor3 = Color3.new(0, 0, 0)
	display.Parent = billboard
	local user = Instance.new("TextLabel")
	user.Position = UDim2.fromOffset(0, 24)
	user.Size = UDim2.new(1, 0, 0, 18)
	user.BackgroundTransparency = 1
	user.Font = Enum.Font.SpecialElite
	user.TextSize = 13
	user.TextColor3 = Color3.fromRGB(120, 110, 105)
	user.TextStrokeColor3 = Color3.new(0, 0, 0)
	user.Parent = billboard

	local typing = Instance.new("BillboardGui")
	typing.Name = "GS_DisguiseTyping"
	typing.Adornee = head
	typing.Size = UDim2.fromOffset(46, 22)
	typing.StudsOffset = Vector3.new(0, 2.4, 0)
	typing.MaxDistance = 60
	typing.Enabled = false
	typing.ResetOnSpawn = false
	typing.Parent = billboard.Parent
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = typing
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back
	local dots = {}
	for i = 1, 3 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(0.5, (i - 2) * 11, 0.5, 0)
		dot.Size = UDim2.fromOffset(5, 5)
		dot.BackgroundColor3 = Color3.fromRGB(225, 222, 218)
		dot.BorderSizePixel = 0
		dot.Parent = back
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = dot
		dots[i] = dot
	end
	disguises[model] = {billboard = billboard, display = display, user = user, head = head, typing = typing, dots = dots}
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			billboard:Destroy()
			typing:Destroy()
			disguises[model] = nil
		end
	end)
end

task.spawn(function()
	local folder = workspace:WaitForChild("Monsters", 120)
	if not folder then return end
	local function onModel(model)
		if model:IsA("Model") and model:GetAttribute("DisguiseName") ~= nil then
			task.spawn(makeDisguiseTag, model)
		end
	end
	for _, model in ipairs(folder:GetChildren()) do onModel(model) end
	folder.ChildAdded:Connect(function(model)
		task.wait(0.2)
		onModel(model)
	end)
end)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local character = player.Character
	local myHead = character and character:FindFirstChild("Head")
	local from = myHead and myHead.Position or camera.CFrame.Position
	local t = os.clock()
	for model, tag in pairs(disguises) do
		local disguised = model:GetAttribute("Revealed") ~= true
		tag.display.Text = model:GetAttribute("DisguiseName") or ""
		tag.user.Text = model:GetAttribute("DisguiseUser") or ""
		local distance = (tag.head.Position - from).Magnitude
		local alpha = disguised and (1 - math.clamp((distance - 6) / 5, 0, 1)) or 0
		tag.billboard.Enabled = alpha > 0.01
		tag.display.TextTransparency = 1 - alpha
		tag.display.TextStrokeTransparency = 1 - alpha * 0.65
		tag.user.TextTransparency = 1 - alpha * 0.9
		tag.user.TextStrokeTransparency = 1 - alpha * 0.5
		local typingOn = disguised and model:GetAttribute("Typing") == true
		tag.typing.Enabled = typingOn
		if typingOn then
			for i, dot in ipairs(tag.dots) do
				local wave = math.max(0, math.sin(t * 6 - i * 0.9))
				dot.Position = UDim2.new(0.5, (i - 2) * 11, 0.5, -wave * 3)
				dot.BackgroundTransparency = 0.5 - wave * 0.5
			end
		end
	end
end)

-- ===== A-013 tentacles (drawn locally so they move smoothly) =====
local TENTACLE_ROOTS = {
	{offset = Vector3.new(-0.7, 0.7, 0.45), out = Vector3.new(-0.7, 0.45, 1)},
	{offset = Vector3.new(0.7, 0.7, 0.45), out = Vector3.new(0.7, 0.45, 1)},
	{offset = Vector3.new(-0.8, -0.5, 0.4), out = Vector3.new(-1, -0.1, 0.8)},
	{offset = Vector3.new(0.8, -0.5, 0.4), out = Vector3.new(1, -0.1, 0.8)},
	{offset = Vector3.new(0, 0.2, 0.5), out = Vector3.new(0, 0.8, 1)},
}
local SEGMENTS = 10
local TENTACLE_LENGTH = 6
local tentacled = {}
local tentacleFolder = Instance.new("Folder")
tentacleFolder.Name = "GS_Tentacles"
tentacleFolder.Parent = workspace

local function fleshPart(shape, color)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Shape = shape
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0.15
	part.Color = color
	part.Parent = tentacleFolder
	return part
end

local function addTentacles(model)
	if tentacled[model] then return end
	local list = {}
	for i, spec in ipairs(TENTACLE_ROOTS) do
		local tentacle = {spec = spec, seed = rng:NextNumber(0, 100), bones = {}, joints = {}}
		for s = 1, SEGMENTS do
			local shade = Color3.fromRGB(140, 30, 36):Lerp(Color3.fromRGB(60, 6, 18), s / SEGMENTS)
			tentacle.bones[s] = fleshPart(Enum.PartType.Cylinder, shade)
			tentacle.joints[s] = fleshPart(Enum.PartType.Ball, shade)
		end
		list[i] = tentacle
	end
	tentacled[model] = list
	model.AncestryChanged:Connect(function()
		if model:IsDescendantOf(workspace) then return end
		for _, tentacle in ipairs(tentacled[model] or {}) do
			for s = 1, SEGMENTS do
				tentacle.bones[s]:Destroy()
				tentacle.joints[s]:Destroy()
			end
		end
		tentacled[model] = nil
	end)
end

local function bezier(a, b, c, t)
	local u = 1 - t
	return a * u * u + b * 2 * u * t + c * t * t
end

local function drawTentacle(tentacle, base, control, tip)
	local prev = base
	for s = 1, SEGMENTS do
		local point = bezier(base, control, tip, s / SEGMENTS)
		local width = 0.55 - 0.42 * (s / SEGMENTS)
		local length = (point - prev).Magnitude
		local bone, joint = tentacle.bones[s], tentacle.joints[s]
		if length > 0.01 then
			bone.Size = Vector3.new(length, width, width)
			bone.CFrame = CFrame.lookAt((prev + point) / 2, point) * CFrame.Angles(0, math.pi / 2, 0)
		end
		joint.Size = Vector3.new(width, width, width)
		joint.CFrame = CFrame.new(point)
		prev = point
	end
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local serverTime = workspace:GetServerTimeNow()
	for model, list in pairs(tentacled) do
		local torso = model:FindFirstChild("Torso")
		if torso then
			local grabValue = model:FindFirstChild("GS_GrabTarget")
			local victim = grabValue and grabValue.Value
			local victimPart = victim and victim.Parent and (victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart"))
			local since = serverTime - (model:GetAttribute("GS_GrabAt") or -math.huge)
			local hit = model:GetAttribute("GS_GrabHit") == true
			for i, tentacle in ipairs(list) do
				local spec = tentacle.spec
				local base = torso.CFrame:PointToWorldSpace(spec.offset)
				local out = torso.CFrame:VectorToWorldSpace(spec.out.Unit)
				local n = tentacle.seed
				local sway = Vector3.new(math.noise(t * 0.7, n), math.noise(n, t * 0.6), math.noise(t * 0.8, n, 3)) * 2.2
				local tip = base + out * TENTACLE_LENGTH + sway + Vector3.new(0, math.sin(t * 1.3 + n) * 0.8, 0)
				-- the two upper tentacles do the grabbing
				if i <= 2 and victimPart and since >= 0 and since < 1.6 then
					local reach
					if since < 0.35 then
						reach = since / 0.35
					elseif hit then
						reach = 1
					else
						reach = math.clamp(1 - (since - 0.35) / 0.35, 0, 1)
					end
					local grip = victimPart.Position + Vector3.new(i == 1 and -0.4 or 0.4, 0.3, 0)
					tip = tip:Lerp(grip, reach)
				end
				local control = base + out * TENTACLE_LENGTH * 0.45 + Vector3.new(0, 1.2, 0) + sway * 0.4
				drawTentacle(tentacle, base, control, tip)
			end
		end
	end
end)

task.spawn(function()
	local folder = workspace:WaitForChild("Monsters", 120)
	if not folder then return end
	local function onModel(model)
		if model:IsA("Model") and model:WaitForChild("GS_GrabTarget", 5) then addTentacles(model) end
	end
	for _, model in ipairs(folder:GetChildren()) do task.spawn(onModel, model) end
	folder.ChildAdded:Connect(function(model) task.spawn(onModel, model) end)
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
}
MonsterData.Order = {"D-130", "B-414", "A-013", "C-207"}

function MonsterData.Get(id)
	return MonsterData.Objects[id]
end

function MonsterData.DangerOf(id)
	local object = MonsterData.Objects[id]
	return object and MonsterData.Danger[object.class] or nil
end

return MonsterData
]=]},
	{name = "Monsters", class = "Script", where = "ServerScriptService", source = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))
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
local TEXTURES = {
	Meat = "",          -- flesh_meat.png
	Veins = "",         -- veins_overlay.png
	ListenerSkin = "",  -- listener_skin.png
}
local SKIN_BARE = Color3.fromRGB(192, 190, 186)
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

local function weldBlob(parent, part, localCF, size, color, reflect)
	local blob = Instance.new("Part")
	blob.Name = "GS_Blob"
	blob.Size = size
	blob.Color = color
	blob.Material = Enum.Material.SmoothPlastic
	blob.Reflectance = reflect or 0.1
	blob.CanCollide, blob.CanQuery, blob.CanTouch, blob.CastShadow, blob.Massless = false, false, false, false, true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = blob
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
local function paintPart(part, id, studs, transparency)
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

-- A-013: a walking heap of raw meat. Veins everywhere, white eyes in black pits, tentacles (drawn by clients).
local function buildFleshModel()
	local model = coloredModel(FLESH_COLORS[1])
	if not model then return nil end
	local holder = Instance.new("Folder")
	holder.Name = "GS_Body"
	holder.Parent = model
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = FLESH_COLORS[rng:NextInteger(1, 3)]
			part.Material = Enum.Material.SmoothPlastic
			part.Reflectance = 0.14
			paintPart(part, TEXTURES.Meat, 2.5)
			paintPart(part, TEXTURES.Veins, 3, 0.1)
			addVeins(holder, part, part.Name == "Torso" and 5 or 3, Color3.fromRGB(58, 6, 32), 0.1)
			local count = part.Name == "Torso" and 8 or (part.Name == "Head" and 4 or 3)
			for _ = 1, count do
				local half = part.Size / 2
				local offset = Vector3.new(rng:NextNumber(-half.X, half.X), rng:NextNumber(-half.Y, half.Y), rng:NextNumber(-half.Z, half.Z))
				local r = rng:NextNumber(0.45, part.Name == "Torso" and 1.2 or 0.8)
				weldBlob(holder, part, CFrame.new(offset), Vector3.new(r, r * rng:NextNumber(0.7, 1.2), r),
					FLESH_COLORS[rng:NextInteger(1, #FLESH_COLORS)], rng:NextNumber(0.1, 0.3))
			end
		end
	end
	local head = model:FindFirstChild("Head")
	if head then
		for _, d in ipairs(head:GetChildren()) do
			if d:IsA("Decal") then d:Destroy() end
		end
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
	local holder = Instance.new("Folder")
	holder.Name = "GS_Body"
	holder.Parent = model
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.SmoothPlastic
			part.Color = skin
			paintPart(part, TEXTURES.ListenerSkin, 3)
			addVeins(holder, part, part.Name == "Torso" and 6 or 4, Color3.fromRGB(62, 42, 96), 0.08)
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
	humanoid:TakeDamage((brain.data.damageBase or 4) + level * (brain.data.damagePerLevel or 3))
	if humanoid.Health > 0 then
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
local function onStruck(brain, striker)
	if brain.data.kind == "skinwalker" and skinwalkerStruck then
		skinwalkerStruck(brain, striker)
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
				eaten:Destroy()
			end
			if foodPiece(food) then
				brain.stateSince = now
			else
				finish()
			end
		else
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

	if brain.state ~= "eat" and brain.state ~= "retreat" then
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
			setState(brain, "watch")
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
			if brain.unreachableSince and now - brain.unreachableSince > 6 then
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
		if brain.target == brain.lastHitVictim and brain.lastHitLook and now - (brain.lastHitTime or 0) < 8 then
			brain.killedLook = brain.lastHitLook
		end
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
		local found = pickTarget(brain)
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
			local shouldReveal = brain.stareTime > 2.6
				or (alone and distance < 10 and mimicFor > 15 and rng:NextNumber() < 0.05)
				or (mimicFor > 120 and distance < 14)
			if shouldReveal then
				brain.revealUntil = now + 1.3
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
		eatStep(brain, now, function()
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

local function fleshShell(character, key)
	local part = character:FindFirstChild(PART_NAME[key])
	if not part or not part:IsA("BasePart") then return end
	local old = part:FindFirstChild("GS_FleshShell")
	if old then old:Destroy() end
	local holder = Instance.new("Folder")
	holder.Name = "GS_FleshShell"
	holder.Parent = part
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Size = part.Size * 1.05
	shell.Color = FLESH_COLORS[rng:NextInteger(1, 3)]
	shell.Material = Enum.Material.SmoothPlastic
	shell.Reflectance = 0.14
	shell.CanCollide, shell.CanQuery, shell.CanTouch, shell.CastShadow, shell.Massless = false, false, false, false, true
	if key == "Head" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = Vector3.new(1.3, 1.3, 1.3)
		mesh.Parent = shell
	end
	shell.CFrame = part.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = shell
	weld.Parent = shell
	shell.Parent = holder
	for _ = 1, key == "Torso" and 5 or 3 do
		local half = part.Size / 2
		local offset = Vector3.new(rng:NextNumber(-half.X, half.X), rng:NextNumber(-half.Y, half.Y), rng:NextNumber(-half.Z, half.Z))
		local r = rng:NextNumber(0.3, 0.7)
		weldBlob(holder, part, CFrame.new(offset), Vector3.new(r, r, r), FLESH_COLORS[rng:NextInteger(1, #FLESH_COLORS)], 0.2)
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
	for key in pairs(splitList(plr:GetAttribute("FleshParts"))) do
		if PART_NAME[key] then fleshShell(character, key) end
	end
	local head = character:FindFirstChild("Head")
	if head then
		local tag = Instance.new("BillboardGui")
		tag.Name = "GS_InfectedTag"
		tag.Size = UDim2.fromOffset(160, 22)
		tag.StudsOffset = Vector3.new(0, 3.3, 0)
		tag.MaxDistance = 60
		tag.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.SpecialElite
		label.Text = "INFECTED"
		label.TextSize = 16
		label.TextColor3 = Color3.fromRGB(190, 20, 20)
		label.TextStrokeTransparency = 0.4
		label.Parent = tag
		tag.Parent = head
	end
	plr:SetAttribute("InfectPending", nil)
	plr:SetAttribute("InfectSpawn", nil)
	-- the flesh mends itself: every injury closes 30s after it happened, torn limbs grow back as meat,
	-- and the body regains 2 hp every 10 seconds
	task.spawn(function()
		local since = {}
		local ticks = 0
		while plr.Character == character and character.Parent and humanoid.Health > 0 do
			task.wait(1)
			ticks += 1
			if ticks % 10 == 0 then humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 2) end
			local anyInjury = false
			for key in pairs(PART_NAME) do
				local level = character:GetAttribute("Injury_" .. key) or 0
				if level <= 0 then
					since[key] = nil
				else
					anyInjury = true
					since[key] = since[key] or os.clock()
					if os.clock() - since[key] >= 30 then
						since[key] = nil
						if level >= 3 and key ~= "Head" and key ~= "Torso" then
							local ok = FallDamageController.RestorePart(character, key)
							if ok then fleshShell(character, key) end
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
		pendingInfection[plr] = nil
	end
end
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
	local fake = {
		model = striker,
		data = {kind = "player", deathCause = isInfected(striker) and "INFECTED" or "BEATEN", damageBase = 4, damagePerLevel = 3},
	}
	hitVictim(fake, victim)
end

local THINK = {skinwalker = thinkSkinwalker, flesh = thinkFlesh, listener = thinkListener}

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
			local ok, alive = pcall(THINK[brain.data.kind] or think, brain)
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

local lastStrike = {}
strikeRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastStrike[player] or 0) < 0.65 then return end
	lastStrike[player] = now
	local character = player.Character
	if not aliveCharacter(character) or character:GetAttribute("Ragdolled") then return end
	local left = character:GetAttribute("Injury_LeftArm") or 0
	local right = character:GetAttribute("Injury_RightArm") or 0
	if left >= 2 and right >= 2 then return end
	local root = character.HumanoidRootPart
	makeNoise(character, 45, 1)
	local infected = isInfected(character)
	local function inFront(position, reach)
		local offset = position - root.Position
		return offset.Magnitude < reach and flat(offset).Magnitude > 0.1 and flat(root.CFrame.LookVector):Dot(flat(offset).Unit) > 0.2
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
			if d < bestDist and inFront(other.HumanoidRootPart.Position, 6) then best, bestDist = other, d end
		end
	end
	if infected then
		local npcFolder = workspace:FindFirstChild("NPCs")
		for _, npc in ipairs(npcFolder and npcFolder:GetChildren() or {}) do
			if npc:IsA("Model") and aliveCharacter(npc) then
				local d = (npc.HumanoidRootPart.Position - root.Position).Magnitude
				if d < bestDist and inFront(npc.HumanoidRootPart.Position, 6) then best, bestDist = npc, d end
			end
		end
	end
	if best then task.delay(0.2, function()
		if aliveCharacter(best) and aliveCharacter(character) then strikeCharacter(character, best) end
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
]=]},
	{name = "PlayerList", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
local Players = game:GetService("Players")
local function isNpc(x)
	return type(x) == "table" and x.IsNpc == true
end

local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CONFIG = {
	Key = Enum.KeyCode.Tab,
	Title = "S O M E T H I N G   I S   C O M I N G",
	Subtitle = "those who are still here",
	Font = Enum.Font.SpecialElite,
	RowHeight = 46,
	Width = 460,
	MaxPlayers = Players.MaxPlayers,
}

task.spawn(function()
	for _ = 1, 30 do
		local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
		if ok then break end
		task.wait(0.5)
	end
end)

local function create(className, props, children)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do obj[key] = value end
	for _, child in ipairs(children or {}) do child.Parent = obj end
	return obj
end

local INK = Color3.fromRGB(232, 230, 226)
local MID = Color3.fromRGB(150, 148, 144)
local DIM = Color3.fromRGB(85, 84, 82)
local LINE = Color3.fromRGB(60, 60, 58)

local gui = create("ScreenGui", {
	Name = "HorrorPlayerList", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = create("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(CONFIG.Width, 120),
	BackgroundColor3 = Color3.fromRGB(6, 6, 6), BackgroundTransparency = 0.04, BorderSizePixel = 0,
	GroupTransparency = 1, Visible = false, Parent = gui,
}, {
	create("UIStroke", {Color = LINE, Thickness = 1}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 26, 25), Color3.fromRGB(0, 0, 0))}),
})

local function bracket(anchor, pos)
	local holder = create("Frame", {
		AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = panel,
	})
	create("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, anchor.Y), AnchorPoint = Vector2.new(0, anchor.Y),
		BackgroundColor3 = INK, BorderSizePixel = 0, Parent = holder})
	create("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(anchor.X, 0), AnchorPoint = Vector2.new(anchor.X, 0),
		BackgroundColor3 = INK, BorderSizePixel = 0, Parent = holder})
end
bracket(Vector2.new(0, 0), UDim2.fromOffset(6, 6))
bracket(Vector2.new(1, 0), UDim2.new(1, -6, 0, 6))
bracket(Vector2.new(0, 1), UDim2.new(0, 6, 1, -6))
bracket(Vector2.new(1, 1), UDim2.new(1, -6, 1, -6))

create("TextLabel", {
	Position = UDim2.fromOffset(22, 14), Size = UDim2.new(1, -44, 0, 26), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = CONFIG.Title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = INK, Parent = panel,
})
local countLine = create("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -38), Size = UDim2.new(1, -44, 0, 1),
	BackgroundColor3 = LINE, BorderSizePixel = 0, Parent = panel,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1),
})})})
local countLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -44, 0, 20),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = MID, Parent = panel,
})
create("TextLabel", {
	Position = UDim2.fromOffset(22, 42), Size = UDim2.new(1, -44, 0, 16), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = CONFIG.Subtitle, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = DIM, Parent = panel,
})
create("Frame", {
	Position = UDim2.fromOffset(22, 64), Size = UDim2.new(1, -44, 0, 1), BackgroundColor3 = LINE,
	BorderSizePixel = 0, Parent = panel,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1),
})})})

local list = create("Frame", {
	Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 1, -124), BackgroundTransparency = 1, Parent = panel,
}, {create("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder})})

local rows = {}

local function characterOf(plr)
	if isNpc(plr) then
		local folder = workspace:FindFirstChild("NPCs")
		return folder and folder:FindFirstChild("NPC_" .. tostring(-plr.UserId))
	end
	return plr.Character
end

local function statusOf(plr)
	local character = characterOf(plr)
	if isNpc(plr) and not character then return "DEAD", Color3.fromRGB(255, 255, 255) end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character then return "IN MENU", DIM end
	if not humanoid or humanoid.Health <= 0 then return "DEAD", Color3.fromRGB(255, 255, 255) end
	if character:GetAttribute("Paralyzed") then return "PARALYZED", INK end
	for _, part in ipairs({"RightLeg", "LeftLeg", "RightArm", "LeftArm"}) do
		if (character:GetAttribute("Injury_" .. part) or 0) >= 3 then return "MUTILATED", INK end
	end
	for _, part in ipairs({"Head", "RightLeg", "LeftLeg", "RightArm", "LeftArm", "Torso"}) do
		if (character:GetAttribute("Injury_" .. part) or 0) >= 2 then return "INJURED", MID end
	end
	return "ALIVE", MID
end

local function addRow(plr)
	if rows[plr] then return end
	local isMe = plr == player
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, CONFIG.RowHeight), BackgroundColor3 = isMe and Color3.fromRGB(30, 30, 29) or Color3.fromRGB(14, 14, 14),
		BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = list,
	})
	if isMe then
		create("Frame", {Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = INK, BorderSizePixel = 0, Parent = row})
	end
	local avatar = create("ImageLabel", {
		Position = UDim2.fromOffset(10, 5), Size = UDim2.fromOffset(CONFIG.RowHeight - 10, CONFIG.RowHeight - 10),
		BackgroundColor3 = Color3.fromRGB(24, 24, 24), BorderSizePixel = 0, ImageColor3 = Color3.fromRGB(175, 175, 175),
		Parent = row,
	}, {create("UIStroke", {Color = LINE, Thickness = 1})})
	if isNpc(plr) then
		create("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = CONFIG.Font, Text = "NPC", TextSize = 12,
			TextColor3 = MID, Parent = avatar,
		})
	else
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
			end)
			if ok then avatar.Image = image end
		end)
	end
	local display = create("TextLabel", {
		Position = UDim2.fromOffset(CONFIG.RowHeight + 8, 4), Size = UDim2.new(1, -180, 0, 22), BackgroundTransparency = 1,
		Font = CONFIG.Font, Text = plr.DisplayName, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = isMe and Color3.new(1, 1, 1) or INK, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	create("TextLabel", {
		Position = UDim2.fromOffset(CONFIG.RowHeight + 8, 25), Size = UDim2.new(1, -180, 0, 16), BackgroundTransparency = 1,
		Font = CONFIG.Font, Text = isNpc(plr) and "npc" or ("@" .. plr.Name), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DIM, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	local statusLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(120, 20),
		BackgroundTransparency = 1, Font = CONFIG.Font, Text = "", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	rows[plr] = {frame = row, status = statusLabel, display = display}
end

local function removeRow(plr)
	local row = rows[plr]
	if row then
		row.frame:Destroy()
		rows[plr] = nil
	end
end

for _, plr in ipairs(Players:GetPlayers()) do addRow(plr) end
Players.PlayerAdded:Connect(addRow)
Players.PlayerRemoving:Connect(removeRow)

local npcEntries = {}
local npcRegistry = game:GetService("ReplicatedStorage"):WaitForChild("NPCs", 20)
if npcRegistry then
	local function addNpc(config)
		if not config:IsA("Configuration") or npcEntries[config] then return end
		local entry = {IsNpc = true, UserId = config:GetAttribute("Id"), DisplayName = config:GetAttribute("DisplayName") or "NPC", Name = "npc"}
		npcEntries[config] = entry
		addRow(entry)
	end
	for _, config in ipairs(npcRegistry:GetChildren()) do addNpc(config) end
	npcRegistry.ChildAdded:Connect(addNpc)
	npcRegistry.ChildRemoved:Connect(function(config)
		local entry = npcEntries[config]
		if entry then
			npcEntries[config] = nil
			removeRow(entry)
		end
	end)
end

local function refresh()
	local ordered = Players:GetPlayers()
	local playerCount = #ordered
	for _, entry in pairs(npcEntries) do table.insert(ordered, entry) end
	table.sort(ordered, function(a, b)
		if a == player then return true end
		if b == player then return false end
		if (isNpc(a) == true) ~= (isNpc(b) == true) then return not isNpc(a) end
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	for index, plr in ipairs(ordered) do
		local row = rows[plr]
		if row then
			row.frame.LayoutOrder = index
			local text, color = statusOf(plr)
			row.status.Text = text
			row.status.TextColor3 = color
		end
	end
	local npcCount = #ordered - playerCount
	countLabel.Text = string.format("PLAYERS  %d / %d", playerCount, CONFIG.MaxPlayers) .. (npcCount > 0 and string.format("   ·   NPC  %d", npcCount) or "")
	panel.Size = UDim2.fromOffset(CONFIG.Width, 126 + #ordered * (CONFIG.RowHeight + 4))
end

local open = false
local function setOpen(value)
	if value == open then return end
	open = value
	if open then
		refresh()
		panel.Visible = true
		panel.Position = UDim2.new(0.5, 0, 0, 60)
		TweenService:Create(panel, TweenInfo.new(0.18), {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 70)}):Play()
	else
		local tween = TweenService:Create(panel, TweenInfo.new(0.15), {GroupTransparency = 1})
		tween:Play()
		tween.Completed:Once(function() if not open then panel.Visible = false end end)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == CONFIG.Key and not UserInputService:GetFocusedTextBox() then
		setOpen(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == CONFIG.Key then
		setOpen(false)
	end
end)
-- touch screens have no Tab: a LIST button toggles it
if UserInputService.TouchEnabled then
	local ContextActionService = game:GetService("ContextActionService")
	ContextActionService:BindAction("GS_PlayerList", function(_, state)
		if state == Enum.UserInputState.Begin then setOpen(not open) end
		return Enum.ContextActionResult.Sink
	end, true)
	ContextActionService:SetTitle("GS_PlayerList", "LIST")
	ContextActionService:SetPosition("GS_PlayerList", UDim2.new(1, -95, 0, 10))
end

local timer = 0
RunService.Heartbeat:Connect(function(dt)
	if not open then return end
	timer += dt
	if timer > 0.5 then
		timer = 0
		refresh()
	end
end)
]=]},
	{name = "Regeneration", class = "Script", where = "ServerScriptService", source = [=[
local Players = game:GetService("Players")

local CONFIG = {
	Amount = 1,
	Interval = 10,
	NoDamageTime = 10,
}

local lastDamage = {}

local function setupCharacter(character)

	local default = character:WaitForChild("Health", 5)
	if default and default:IsA("Script") then
		default:Destroy()
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local lastHealth = humanoid.Health
	lastDamage[character] = os.clock()
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth - 1e-3 then
			lastDamage[character] = os.clock()
		end
		lastHealth = health
	end)
	character.Destroying:Connect(function()
		lastDamage[character] = nil
	end)

	task.spawn(function()
		while character.Parent and humanoid.Parent do
			task.wait(CONFIG.Interval)
			if not character.Parent or humanoid.Health <= 0 then break end
			-- the infected heal on their own schedule (Monsters script)
			if character:GetAttribute("Infected") then continue end
			local since = os.clock() - (lastDamage[character] or 0)
			if since >= CONFIG.NoDamageTime and humanoid.Health < humanoid.MaxHealth then
				lastHealth = math.min(humanoid.MaxHealth, humanoid.Health + CONFIG.Amount)
				humanoid.Health = lastHealth
			end
		end
	end)
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then task.spawn(setupCharacter, player.Character) end
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
]=]},
	{name = "SpawnService", class = "Script", where = "ServerScriptService", source = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false
pcall(function() game:GetService("StarterPlayer").EnableMouseLockOption = false end)

local spawnRequest = ReplicatedStorage:FindFirstChild("SpawnRequest")
if not spawnRequest then
	spawnRequest = Instance.new("RemoteEvent")
	spawnRequest.Name = "SpawnRequest"
	spawnRequest.Parent = ReplicatedStorage
end

local lastSpawn = {}

local CAMERA_NAMES = {"cam", "Cam", "CAM", "MenuCamera"}
local function findCameraPart()
	for _, name in ipairs(CAMERA_NAMES) do
		local found = workspace:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then return found end
	end
	return nil
end
local cameraPart = findCameraPart()
if cameraPart then
	ReplicatedStorage:SetAttribute("MenuCameraCFrame", cameraPart.CFrame)
	cameraPart:GetPropertyChangedSignal("CFrame"):Connect(function()
		ReplicatedStorage:SetAttribute("MenuCameraCFrame", cameraPart.CFrame)
	end)
end

local function focusMenu(player)
	if cameraPart then
		pcall(function() player.ReplicationFocus = cameraPart end)
	end
end

local function noMouseLock(player)
	pcall(function() player.DevEnableMouseLock = false end)
end
for _, player in ipairs(Players:GetPlayers()) do noMouseLock(player) end

Players.PlayerAdded:Connect(function(player)
	noMouseLock(player)
	focusMenu(player)
	player.CharacterAdded:Connect(function()
		pcall(function() player.ReplicationFocus = nil end)
	end)
	player.CharacterRemoving:Connect(function()
		focusMenu(player)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do focusMenu(player) end

spawnRequest.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastSpawn[player] or 0) < 1.5 then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid and humanoid.Health > 0 then return end
	-- infected players don't get to choose: the flesh brings them back
	if player:GetAttribute("InfectPending") or player:GetAttribute("AC_Punished") then return end
	lastSpawn[player] = now
	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(function(player)
	lastSpawn[player] = nil
end)
]=]},
	{name = "VoiceNoise", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- Measures how loud this player is talking in voice chat and tells the server, so monsters hear it.
-- Needs the new audio API: VoiceChatService → UseAudioApi = Enabled (and voice chat enabled for the game).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("GS_Noise", 60)
if not remote then return end

local analyzer = nil
local input = nil

local function hook(child)
	if not child:IsA("AudioDeviceInput") then return end
	input = child
	if analyzer then analyzer:Destroy() end
	local ok = pcall(function()
		analyzer = Instance.new("AudioAnalyzer")
		analyzer.Name = "GS_VoiceMeter"
		analyzer.Parent = child
		local wire = Instance.new("Wire")
		wire.SourceInstance = child
		wire.TargetInstance = analyzer
		wire.Parent = analyzer
	end)
	if not ok then analyzer = nil end
end

for _, child in ipairs(player:GetChildren()) do hook(child) end
player.ChildAdded:Connect(hook)

while true do
	task.wait(0.15)
	if analyzer and input and input.Parent then
		local ok, rms = pcall(function() return analyzer.RmsLevel end)
		local muted = false
		pcall(function() muted = input.Muted end)
		if ok and not muted and rms and rms > 0.015 then
			remote:FireServer("voice", math.clamp(rms * 6, 0, 1))
		end
	end
end
]=]},
}

local SEARCH = {"ServerScriptService", "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui", "Workspace", "ServerStorage"}

local function findExisting(name, className)
	for _, serviceName in ipairs(SEARCH) do
		local service = game:GetService(serviceName)
		for _, d in ipairs(service:GetDescendants()) do
			if d.Name == name and d.ClassName == className then return d end
		end
	end
	return nil
end

local function defaultParent(where)
	if where == "ServerScriptService" then return game:GetService("ServerScriptService") end
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
		local target = findExisting(entry.name, entry.class)
		if target then
			replaced += 1
		else
			target = Instance.new(entry.class)
			target.Name = entry.name
			target.Parent = defaultParent(entry.where)
			created += 1
		end
		target.Source = entry.source
		print(string.format("[Installer] %s → %s", entry.name, target:GetFullName()))
	end
	if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
	print(string.format("[Installer] done: %d replaced, %d created. Now: File → Publish / Save.", replaced, created))
	warn("[Installer] Remember: Game Settings → Security → API Services + HTTP Requests ON; VoiceChatService.UseAudioApi = Enabled.")
end

if plugin then
	local toolbar = plugin:CreateToolbar("Game scripts")
	local button = toolbar:CreateButton("Install scripts", "Install / update all game scripts", "rbxasset://textures/StudioToolbox/AssetPreview/more.png")
	button.ClickableWhenViewportHidden = true
	button.Click:Connect(function()
		install()
		button:SetActive(false)
	end)
else
	install()
end
