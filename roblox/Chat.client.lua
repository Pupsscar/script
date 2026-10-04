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
