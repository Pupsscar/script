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
