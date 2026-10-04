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
