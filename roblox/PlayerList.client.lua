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
