-- Your money on screen (top right). A dark tag that fades out to the right, a round brass badge with the $ in it,
-- and the number next to it. When it changes the number rolls to the new value, the badge turns over like a
-- flipped coin, a soft glow pulses behind it and a "+$100" / "-$40" drifts away (gold for money in, red for out).
-- The HUD editor (Controls) can move and resize it like the other panels ("CASH").
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSettings = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSettings"))

local player = Players.LocalPlayer
local FONT = Enum.Font.SpecialElite
local GOLD = Color3.fromRGB(226, 172, 74)
local GOLD_DARK = Color3.fromRGB(96, 64, 18)
local INK = Color3.fromRGB(238, 233, 226)
local RED = Color3.fromRGB(225, 52, 44)
local W, H = 196, 46

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
	Name = "Money", Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false, Parent = gui,
})
panel:SetAttribute("GS_Movable", "CASH")

-- the tag: solid behind the badge, fading out towards the right edge
local tag = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, H / 2, 0.5, 0), Size = UDim2.new(1, -H / 2, 0, H - 12),
	BackgroundColor3 = Color3.fromRGB(8, 7, 7), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = panel,
}, {
	create("UICorner", {CornerRadius = UDim.new(0, 6)}),
	create("UIGradient", {Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.25), NumberSequenceKeypoint.new(1, 1),
	})}),
})
-- a hairline of brass along the bottom of the tag
local underline = create("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, H / 2, 0.5, (H - 12) / 2), Size = UDim2.new(1, -H / 2 - 10, 0, 1),
	BackgroundColor3 = GOLD, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = panel,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
})})})

-- glow behind the badge (pulses on a change)
local glow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(H / 2, H / 2), Size = UDim2.fromOffset(H, H),
	BackgroundColor3 = GOLD, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = panel,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})

-- the badge: a round brass coin with a raised rim and the $ struck into it
local badge = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(H / 2, H / 2), Size = UDim2.fromOffset(H - 8, H - 8),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = panel,
}, {
	create("UICorner", {CornerRadius = UDim.new(1, 0)}),
	create("UIGradient", {Rotation = 55, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(246, 208, 120)), ColorSequenceKeypoint.new(0.45, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_DARK),
	})}),
	create("UIStroke", {Color = Color3.fromRGB(58, 38, 10), Thickness = 1.5}),
})
local badgeScale = create("UIScale", {Parent = badge})
create("Frame", { -- the inner ring of the rim
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -7, 1, -7),
	BackgroundTransparency = 1, ZIndex = 3, Parent = badge,
}, {
	create("UICorner", {CornerRadius = UDim.new(1, 0)}),
	create("UIStroke", {Color = Color3.fromRGB(120, 82, 24), Thickness = 1, Transparency = 0.2}),
})
local dollar = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 1), Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1, Font = FONT, Text = "$", TextSize = 24, TextColor3 = Color3.fromRGB(64, 40, 8),
	TextStrokeColor3 = Color3.fromRGB(255, 230, 170), TextStrokeTransparency = 0.75, ZIndex = 4, Parent = badge,
})

local amount = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, H + 6, 0.5, 0), Size = UDim2.new(1, -H - 14, 0, 26),
	BackgroundTransparency = 1, Font = FONT, Text = "0", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = INK, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.6,
	TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = panel,
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
	SoundId = "rbxassetid://9113849583", Volume = 0.3, PlaybackSpeed = 1.15, Parent = gui,
})
pcall(function() coinSound.SoundGroup = GameSettings.GetGroup("SFX") end)

local function popup(delta)
	local gain = delta > 0
	local label = create("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, H + 6, 0.5, 0), Size = UDim2.fromOffset(140, 22),
		BackgroundTransparency = 1, Font = FONT, Text = (gain and "+$" or "-$") .. commas(math.abs(delta)), TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = gain and GOLD or RED, TextStrokeTransparency = 0.5,
		TextTransparency = 1, ZIndex = 5, Parent = panel,
	})
	tween(label, 0.15, {TextTransparency = 0})
	tween(label, 1.1, {Position = UDim2.new(0, H + 6, 0.5, gain and 34 or 30)}, Enum.EasingStyle.Quart)
	task.delay(0.55, function() tween(label, 0.55, {TextTransparency = 1, TextStrokeTransparency = 1}) end)
	task.delay(1.15, function() label:Destroy() end)
end

local flipToken = 0
local function flip(gain)
	-- the coin turns over: squash to an edge, swap faces, open again
	flipToken += 1
	local my = flipToken
	local size = badge.Size
	tween(badge, 0.11, {Size = UDim2.fromOffset(2, size.Y.Offset)}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	task.delay(0.11, function()
		if my ~= flipToken then return end
		dollar.TextColor3 = gain and Color3.fromRGB(64, 40, 8) or Color3.fromRGB(90, 16, 12)
		tween(badge, 0.16, {Size = UDim2.fromOffset(H - 8, H - 8)}, Enum.EasingStyle.Back)
		task.delay(0.6, function() if my == flipToken then tween(dollar, 0.4, {TextColor3 = Color3.fromRGB(64, 40, 8)}) end end)
	end)
	badgeScale.Scale = gain and 1.18 or 0.9
	tween(badgeScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
	glow.BackgroundColor3 = gain and GOLD or RED
	glow.Size = UDim2.fromOffset(H - 6, H - 6)
	glow.BackgroundTransparency = 0.55
	tween(glow, 0.6, {Size = UDim2.fromOffset(H + 18, H + 18), BackgroundTransparency = 1})
end

local function changed()
	local new = player:GetAttribute("Cash") or 0
	local delta = new - shown
	shown = new
	if delta == 0 then return end
	local gain = delta > 0
	tween(value, math.clamp(0.35 + math.log10(math.abs(delta) + 1) * 0.2, 0.35, 1.2), {Value = new})
	if panel.Visible then
		popup(delta)
		flip(gain)
		amount.TextColor3 = gain and GOLD or RED
		underline.BackgroundTransparency = 0
		task.delay(0.2, function()
			tween(amount, 0.8, {TextColor3 = INK})
			tween(underline, 0.8, {BackgroundTransparency = 0.35})
		end)
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
		panel.Position = target + UDim2.fromOffset(24, 0)
		tag.BackgroundTransparency = 1
		tween(panel, 0.45, {Position = target}, Enum.EasingStyle.Quart)
		tween(tag, 0.45, {BackgroundTransparency = 0.2})
	elseif not want and panel.Visible then
		panel.Visible = false
	end
end)
