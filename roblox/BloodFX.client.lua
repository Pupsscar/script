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
