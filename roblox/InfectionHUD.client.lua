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
