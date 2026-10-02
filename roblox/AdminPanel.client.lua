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
