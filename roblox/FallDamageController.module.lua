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
