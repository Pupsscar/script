local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))
local Skeletons = require(Modules:WaitForChild("Skeletons"))
local boneHolders = setmetatable({}, {__mode = "k"}) -- corpse -> the skeleton its eaten pieces leave behind
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
local TEXTURES = MonsterData.Textures or {
	Meat = "93176580262165",          -- flesh_meat.png
	Veins = "110379790827308",         -- veins_overlay.png
	ListenerSkin = "127788127447980",  -- listener_skin.png
}
local SKIN_BARE = Color3.fromRGB(226, 224, 218)
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
local scent = {}
local lastScentPos = {}
local SCENT_LIFETIME = 90
local SENSE_RADIUS = 170
local senseRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_InfectedSense")
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
		-- footprints every survivor leaves (only infected eyes ever see them)
		while scent[1] and now - scent[1].t > SCENT_LIFETIME do table.remove(scent, 1) end
		for _, character in ipairs(livingTargets()) do
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local last = lastScentPos[character]
				if not last or (root.Position - last).Magnitude >= 2.5 then
					lastScentPos[character] = root.Position
					local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), groundParams)
					if hit then
						table.insert(scent, {pos = hit.Position, t = now})
						if #scent > 3000 then table.remove(scent, 1) end
					end
				end
			end
		end
		for character in pairs(lastScentPos) do
			if not character.Parent then lastScentPos[character] = nil end
		end
	end
end)

-- stage 2+ infected: every second, send them the tracks and blood around them
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, plr in ipairs(Players:GetPlayers()) do
			local character = plr.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and character:GetAttribute("Infected") and (character:GetAttribute("InfectStage") or 1) >= 3 then
				local blood, prints = {}, {}
				for i = #trail, 1, -1 do
					local p = trail[i]
					if now - p.t > 240 or #blood >= 250 then break end
					if (p.pos - root.Position).Magnitude < SENSE_RADIUS then table.insert(blood, {p.pos, now - p.t}) end
				end
				for i = #scent, 1, -1 do
					local p = scent[i]
					if #prints >= 300 then break end
					if (p.pos - root.Position).Magnitude < SENSE_RADIUS then table.insert(prints, {p.pos, now - p.t}) end
				end
				senseRemote:FireClient(plr, blood, prints)
			end
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

local function storedMonster(id)
 local source=ServerStorage:WaitForChild("GS_Assets"):WaitForChild("Monsters"):FindFirstChild(id)
 return source and source:Clone() or nil
end
local function buildBareModel() return storedMonster("B-414") end

local function weldBlob(parent, part, localCF, size, color, reflect, texture)
	local blob = Instance.new("Part")
	blob.Name = "GS_Blob"
	blob.Color = color
	blob.Material = Enum.Material.SmoothPlastic
	blob.Reflectance = reflect or 0.1
	blob.CanCollide, blob.CanQuery, blob.CanTouch, blob.CastShadow, blob.Massless = false, false, false, false, true
	if texture then
		-- textures only render on real part shapes, not on SpecialMesh spheres
		blob.Shape = Enum.PartType.Ball
		local d = math.max(size.X, size.Y, size.Z)
		blob.Size = Vector3.new(d, d, d)
		paintPart(blob, texture, math.max(1, d * 1.6))
	else
		blob.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = blob
	end
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
function paintPart(part, id, studs, transparency)
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

-- A SpecialMesh head can't show tiled textures, so monster heads become real balls:
-- then the skin texture covers the whole head, not just the face.
local function roundHead(model, diameter)
	local head = model:FindFirstChild("Head")
	if not head then return end
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("SpecialMesh") or d:IsA("Decal") or d:IsA("FaceControls") then d:Destroy() end
	end
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(diameter, diameter, diameter)
end

-- A-013: a walking heap of raw meat. Veins everywhere, white eyes in black pits, tentacles (drawn by clients).
local function buildFleshModel() return storedMonster("A-013") end

local function buildListenerModel() return storedMonster("C-207") end

local function spiderBlob(model, root, name, size, localCF, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Reflectance = 0.06
	part.CanCollide, part.CanQuery, part.CanTouch, part.Massless = false, false, false, true
	if shape then
		part.Shape = shape
	else
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.CFrame = root.CFrame * localCF
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- mother = A-116: the same body plan at car size, rust-red, with an egg sac under the abdomen
local MOTHER_SCALE = 1.35
local function buildSpiderModel(mother) return storedMonster(mother and "A-116" or "E-116") end

local function buildModel(id, cframe)
	local data = MonsterData.Get(id)
	if not data then return nil, "unknown object" end
 local templates=ServerStorage:WaitForChild("GS_Assets"):WaitForChild("Monsters")
 local template=templates:FindFirstChild(id)
 if not template or not template:IsA("Model") then return nil,"editable monster template missing: "..tostring(id) end
 local model=template:Clone()
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
		-- its own skin: pale grey, nothing on it, and the wrong face (3D sockets, pinprick eyes, the long grin).
		-- The B-414 template is a plain dummy, so the look is put on here every time it spawns.
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
 local part="Torso"
 local attackerRoot=brain.model and brain.model:FindFirstChild("HumanoidRootPart")
 local victimRoot=character:FindFirstChild("HumanoidRootPart")
 local origin=attackerRoot and attackerRoot.Position+Vector3.new(0,.6,0) or victimRoot and victimRoot.Position or character:GetPivot().Position
 local names={Head="Head",Torso="Torso",LeftArm="Left Arm",RightArm="Right Arm",LeftLeg="Left Leg",RightLeg="Right Leg"}
 local closest=math.huge
 for _,choice in ipairs(choices) do
  local body=character:FindFirstChild(names[choice[1]] or choice[1])
  if body then
   local p=body.CFrame:PointToObjectSpace(origin)
   local half=body.Size*.5
   local q=Vector3.new(math.clamp(p.X,-half.X,half.X),math.clamp(p.Y,-half.Y,half.Y),math.clamp(p.Z,-half.Z,half.Z))
   local distance=(body.CFrame:PointToWorldSpace(q)-origin).Magnitude
   if distance<closest then closest=distance part=choice[1] end
  end
 end
	local level = (character:GetAttribute("Injury_" .. part) or 0) + 1
	if level == 2 and part ~= "Head" and (character:GetAttribute("InfectStage") or 0) >= 2 then
		-- fully grown infected: bones don't break, but a limb hit hard enough twice still comes off
		local key = "GS_Wounds_" .. part
		local wounds = (character:GetAttribute(key) or 0) + 1
		character:SetAttribute(key, wounds < 2 and wounds or 0)
		level = wounds >= 2 and 3 or 1
	end
	local raw = (brain.data.damageBase or 4) + level * (brain.data.damagePerLevel or 3)
	local dealt, blocked = raw, false
	do -- worn armor (ServerStorage.GS_ItemService) takes a share and may stop the wound
		local okSvc, svc = pcall(function() return require(game:GetService("ServerStorage"):FindFirstChild("GS_ItemService")) end)
		if okSvc and svc and svc.Absorb then dealt, blocked = svc.Absorb(character, part, raw, "claw") end
	end
	humanoid:TakeDamage(dealt)
	if humanoid.Health > 0 and not blocked then
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
local ENRAGE_HITS = 3
local ENRAGE_TIME = 90
local function onStruck(brain, striker)
	if brain.data.kind == "skinwalker" and skinwalkerStruck then
		skinwalkerStruck(brain, striker)
		return
	end
	local now = os.clock()
	local strikerRoot = striker:FindFirstChild("HumanoidRootPart")
	local away = strikerRoot and flat(brain.root.Position - strikerRoot.Position) or Vector3.zero
	away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
	brain.hitsTaken = (brain.hitsTaken or 0) + 1

	if brain.data.kind ~= "stalker" then
		-- the flesh and the listener don't run: a short flinch, then they turn on whoever hit them
		fx(brain, "Hurt")
		brain.staggerUntil = now + 0.45
		brain.root.AssemblyLinearVelocity += away * 10
		if aliveCharacter(striker) and not isInfected(striker) then
			if brain.state == "eat" then abortEat(brain) end
			setTarget(brain, striker)
			brain.lastSeen, brain.lastHeard = now, now
			if strikerRoot then brain.noisePos = strikerRoot.Position end
			setState(brain, brain.data.kind == "flesh" and "chase" or "hunt")
		end
		return
	end

	-- D-130: hit it while it is only watching you, or hit it three times, and it stops being afraid
	local provoked = brain.state ~= "attack" and brain.state ~= "retreat"
	if brain.enraged or provoked or brain.hitsTaken >= ENRAGE_HITS then
		brain.enraged = true
		brain.enragedUntil = now + ENRAGE_TIME
		brain.model:SetAttribute("Enraged", true)
		if brain.state == "eat" then abortEat(brain) end
		if aliveCharacter(striker) then setTarget(brain, striker) end
		brain.lastSeen = now
		brain.staggerUntil = now + 0.2
		fx(brain, "Shriek")
		setState(brain, "attack")
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
local hatchBrood
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
				-- every piece eaten leaves its bones where it lay
				boneHolders[food] = Skeletons.FromPart(eaten, boneHolders[food])
			end
			if foodPiece(food) then
				brain.stateSince = now
			else
				finish()
			end
		else
			if eaten and eaten.Parent then Skeletons.FromPart(eaten) end
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

	if now < (brain.staggerUntil or 0) then
		stop(brain)
		return true
	end
	-- the rage fades after a while without being hit
	if brain.enraged and now > (brain.enragedUntil or 0) and brain.state ~= "attack" then
		brain.enraged = false
		brain.hitsTaken = 0
		model:SetAttribute("Enraged", nil)
	end
	-- enraged: no watching, no backing off, no retreating — straight at you
	if brain.enraged and brain.target and aliveCharacter(brain.target)
		and (brain.state == "watch" or brain.state == "stalk" or brain.state == "avoid" or brain.state == "retreat") then
		setState(brain, "attack")
	end

	if brain.state ~= "eat" and brain.state ~= "retreat" and not (brain.enraged and brain.state == "attack") then
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
			if brain.enraged then
				fx(brain, "Shriek")
				setState(brain, "attack")
			else
				setState(brain, "watch")
			end
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
			if brain.unreachableSince and now - brain.unreachableSince > 6 and not brain.enraged then
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

-- the skinwalker prefers someone on their own; failing that, whoever has the fewest people around them
local function pickLonely(brain)
	local best, bestGroup, bestDist = nil, math.huge, math.huge
	for _, character in ipairs(livingTargets()) do
		if canSee(brain, character) then
			local pos = character.HumanoidRootPart.Position
			local group = playersNear(pos, 35, character)
			local d = (pos - brain.root.Position).Magnitude
			if group < bestGroup or (group == bestGroup and d < bestDist) then
				best, bestGroup, bestDist = character, group, d
			end
		end
	end
	return best
end

-- someone staring at it while it feeds: looking its way and nothing in between
local function watcherOf(brain)
	local best, bestDist = nil, 60
	for _, character in ipairs(livingTargets()) do
		local head = character:FindFirstChild("Head")
		if head then
			local offset = brain.head.Position - head.Position
			local d = offset.Magnitude
			if d < bestDist and d > 0.1 and head.CFrame.LookVector:Dot(offset.Unit) > 0.82 and canSee(brain, character) then
				best, bestDist = character, d
			end
		end
	end
	return best
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
		local victim = brain.target
		if victim == brain.lastHitVictim and brain.lastHitLook and now - (brain.lastHitTime or 0) < 8 then
			-- its own kill: the body is stripped to the bone where it fell, and it walks off wearing them
			local look = brain.lastHitLook
			victim:SetAttribute("GS_NoCorpse", true)
			task.delay(1.1, function()
				if victim.Parent and not victim:GetAttribute("GS_Skeletonized") then Skeletons.FromModel(victim, true) end
			end)
			brain.lastHitVictim, brain.lastHitLook = nil, nil
			setTarget(brain, nil)
			stop(brain)
			fx(brain, "Eat")
			if disguise(brain, look) then
				brain.killedLook, brain.killPos, brain.killTime = nil, nil, nil
				brain.trailFloor = -math.huge
				setState(brain, "roam")
				return true
			end
			brain.killedLook = look
		end
		-- the body turns into a corpse a few seconds after death: stay for the meal
		local deadRoot = brain.target:FindFirstChild("HumanoidRootPart") or brain.target:FindFirstChild("Torso")
		brain.killPos = deadRoot and deadRoot.Position or root.Position
		brain.killTime = now
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
		elseif brain.killPos and now - (brain.killTime or 0) < 9 then
			-- waiting over the body until it can be eaten (still hunting anyone who comes close)
			local near = pickLonely(brain)
			if near and (near.HumanoidRootPart.Position - root.Position).Magnitude < 25 then
				setTarget(brain, near)
				setState(brain, "hunt")
				fx(brain, "Shriek")
			else
				if (brain.killPos - root.Position).Magnitude > 4 then goTo(brain, brain.killPos, WALK_SPEED + 2) else stop(brain) end
				return true
			end
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
		local found = pickLonely(brain)
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
			-- eye contact at point blank: no more pretending, it throws itself at you
			local eyeContact = false
			local theirHead = brain.target:FindFirstChild("Head")
			if theirHead and distance < 5.5 then
				local toFace = brain.head.Position - theirHead.Position
				eyeContact = toFace.Magnitude > 0.1 and theirHead.CFrame.LookVector:Dot(toFace.Unit) > 0.86
			end
			local shouldReveal = eyeContact or brain.stareTime > 2.6
				or (alone and distance < 10 and mimicFor > 15 and rng:NextNumber() < 0.05)
				or (mimicFor > 120 and distance < 14)
			if shouldReveal then
				brain.lungeOnReveal = eyeContact
				brain.revealUntil = now + (eyeContact and 0.35 or 1.3)
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
			if brain.lungeOnReveal and targetRoot then
				-- the lunge: straight at their face, and the first swing comes at once
				local dir = flat(targetRoot.Position - root.Position)
				if dir.Magnitude > 0.1 then root.AssemblyLinearVelocity = dir.Unit * 42 + Vector3.new(0, 14, 0) end
				brain.nextSwing = 0
			end
			brain.lungeOnReveal = nil
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
		-- it eats the whole body, but not with an audience: anyone watching the meal is next
		local watcher = watcherOf(brain)
		if watcher then
			abortEat(brain)
			brain.killPos, brain.killTime = nil, nil
			setTarget(brain, watcher)
			fx(brain, "Shriek")
			setState(brain, "hunt")
			return true
		end
		eatStep(brain, now, function()
			brain.killPos, brain.killTime = nil, nil
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
	if brain.data.kind == "spidermother" then
		hatchBrood(brain)
		return
	end
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

-- the body under the meat disappears completely, so no package mesh, layered clothing or odd body shape
-- can poke out of it (works for R6 and R15 bodies alike)
local function hideUnderShell(part)
	if part.Transparency < 1 then
		part:SetAttribute("GS_ShellHidT", part.Transparency)
		part.Transparency = 1
	end
	for _, d in ipairs(part:GetChildren()) do
		if (d:IsA("Decal") and not d:IsA("Texture")) or d:IsA("SurfaceAppearance") or d:IsA("FaceControls") then d:Destroy() end
	end
end

local function fleshShellPart(part)
	if not part or not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then return end
	local isHead = part.Name == "Head"
	local old = part:FindFirstChild("GS_FleshShell")
	if old then old:Destroy() end
	hideUnderShell(part)
	local holder = Instance.new("Folder")
	holder.Name = "GS_FleshShell"
	holder.Parent = part
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	-- a little bigger than the part it hides; thin R15 pieces get a minimum thickness
	local size = part.Size
	shell.Size = Vector3.new(math.max(size.X * 1.08, 0.5), math.max(size.Y * 1.04, 0.5), math.max(size.Z * 1.08, 0.5))
	shell.Color = FLESH_COLORS[rng:NextInteger(1, 3)]
	shell.Material = Enum.Material.SmoothPlastic
	shell.Reflectance = 0.14
	shell.CanCollide, shell.CanQuery, shell.CanTouch, shell.CastShadow, shell.Massless = false, false, false, false, true
	if isHead then
		-- a ball, not a head mesh: only real shapes show the meat texture all the way round
		shell.Shape = Enum.PartType.Ball
		local d = math.max(1.5, size.Y * 1.25)
		shell.Size = Vector3.new(d, d, d)
	end
	paintPart(shell, TEXTURES.Meat, isHead and 1.2 or 2.5)
	paintPart(shell, TEXTURES.Veins, isHead and 1.5 or 3, 0.1)
	shell.CFrame = part.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = shell
	weld.Parent = shell
	shell.Parent = holder
	local big = part.Name == "Torso" or part.Name == "UpperTorso"
	for _ = 1, big and 5 or 3 do
		local half = part.Size / 2
		if isHead then half = Vector3.new(0.45, 0.45, 0.45) end
		local offset = Vector3.new(rng:NextNumber(-half.X, half.X), rng:NextNumber(-half.Y, half.Y), rng:NextNumber(-half.Z, half.Z))
		local r = rng:NextNumber(0.3, 0.7)
		weldBlob(holder, part, CFrame.new(offset), Vector3.new(r, r, r), FLESH_COLORS[rng:NextInteger(1, #FLESH_COLORS)], 0.2, TEXTURES.Meat)
	end
end

local function fleshShell(character, key)
	fleshShellPart(character:FindFirstChild(PART_NAME[key]))
end

local function coverBody(character)
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then fleshShellPart(part) end
	end
end

-- ===== infected progression: kills make the meat stronger =====
-- stage 1 (just turned): long reach, eats remains, infects whoever it kills, sees in the dark
-- stage 2 (3 kills): 225 hp, bones never break, a lost limb grows back every 15 seconds
-- stage 3 (5 kills): tentacles (R), A-013's eyes and teeth, sees through fog, sees survivors' tracks and blood
-- They move like A-013 does (a little slower than a survivor), whatever the stage.
local INFECT_SPEED = {15, 15, 15}
local INFECT_REACH = {9, 10, 11.5}
local STAGE_KILLS = {3, 5}
local function infectStage(character)
	return character and character:GetAttribute("InfectStage") or 1
end

-- stage 3: the same white pinprick eyes in black pits and the torn toothy maw as A-013, on the meat head
local function addInfectedFace(character)
	local head = character:FindFirstChild("Head")
	if not head or head:FindFirstChild("GS_FleshFace") then return end
	local holder = Instance.new("Folder")
	holder.Name = "GS_FleshFace"
	holder.Parent = head
	-- the meat shell on the head is a 1.5 ball: its front surface sits about 0.7 in front of the centre
	local z = -0.66
	addEye(holder, head, CFrame.new(-0.24, 0.16, z), 0.28)
	addEye(holder, head, CFrame.new(0.26, 0.12, z), 0.32)
	addEye(holder, head, CFrame.new(0.05, 0.4, z + 0.08), 0.17)
	weldBlob(holder, head, CFrame.new(0, -0.22, z + 0.02), Vector3.new(0.36, 0.64, 0.3), Color3.fromRGB(16, 0, 2), 0.35)
	for i = 1, 7 do
		local y = -0.5 + i * 0.075
		for _, side in ipairs({-1, 1}) do
			weldBlob(holder, head, CFrame.new(side * 0.13, y, z - 0.1) * CFrame.Angles(0, 0, side * math.rad(80)),
				Vector3.new(0.05, 0.14, 0.05), Color3.fromRGB(226, 214, 186), 0.05)
		end
	end
	-- and eyes where eyes should not be
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if torso then
		for _ = 1, 3 do
			addEye(holder, torso, CFrame.new(rng:NextNumber(-0.7, 0.7), rng:NextNumber(-0.6, 0.7), -torso.Size.Z / 2 - 0.08),
				rng:NextNumber(0.14, 0.22))
		end
	end
end

local function removeInfectedFace(character)
	local head = character:FindFirstChild("Head")
	local face = head and head:FindFirstChild("GS_FleshFace")
	if face then face:Destroy() end
end

local function applyInfectStage(plr, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local kills = plr:GetAttribute("InfectKills") or 0
	local stage = kills >= STAGE_KILLS[2] and 3 or (kills >= STAGE_KILLS[1] and 2 or 1)
	local old = character:GetAttribute("InfectStage") or 0
	character:SetAttribute("InfectStage", stage)
	humanoid.WalkSpeed = INFECT_SPEED[stage]
	character:SetAttribute("SpeedCap", math.ceil(INFECT_SPEED[stage] * 1.45))
	-- every infected sees in the dark; from stage 2 the fog thins out too (client: InfectedSenses)
	character:SetAttribute("InfectVision", true)
	if stage >= 3 then
		if not character:FindFirstChild("GS_GrabTarget") then
			local grab = Instance.new("ObjectValue")
			grab.Name = "GS_GrabTarget"
			grab.Parent = character
		end
		addInfectedFace(character)
	else
		local grab = character:FindFirstChild("GS_GrabTarget")
		if grab then grab:Destroy() end
		removeInfectedFace(character)
	end
	if stage >= 2 and old < 2 then
		humanoid.MaxHealth = 225
		humanoid.Health = math.min(225, humanoid.Health + 75)
	elseif stage < 2 and old >= 2 then
		humanoid.MaxHealth = 150
		humanoid.Health = math.min(humanoid.Health, 150)
	end
	if stage > old and old > 0 then
		fxRemote:FireAllClients(character, "Shriek")
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
	-- the infected are meat from head to toe: hair, hats, layered clothing and body-package meshes go,
	-- the body underneath turns invisible and every part (R6 or R15) gets a flesh shell
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") or item:IsA("CharacterMesh") or item:IsA("ShirtGraphic") then item:Destroy() end
	end
	coverBody(character)
	-- anything the avatar loader adds later is covered too
	character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") or child:IsA("CharacterMesh") then
			task.defer(function() if child.Parent then child:Destroy() end end)
		elseif child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and not child:FindFirstChild("GS_FleshShell") then
			task.defer(fleshShellPart, child)
		end
	end)
	-- (no INFECTED label over the head: you have to recognise them by the meat)
	plr:SetAttribute("InfectPending", nil)
	plr:SetAttribute("InfectSpawn", nil)
	-- (an admin can hand out a stage: it arrives as InfectStartKills)
	plr:SetAttribute("InfectKills", plr:GetAttribute("InfectStartKills") or 0)
	plr:SetAttribute("InfectStartKills", nil)
	applyInfectStage(plr, character)

	-- stage 2+ bones don't break: a fracture is only ever a wound
	for key in pairs(PART_NAME) do
		if key ~= "Head" then
			character:GetAttributeChangedSignal("Injury_" .. key):Connect(function()
				if (character:GetAttribute("InfectStage") or 1) >= 2 and character:GetAttribute("Injury_" .. key) == 2 then
					character:SetAttribute("Injury_" .. key, 1)
				end
			end)
		end
	end

	-- the flesh mends itself: every injury closes 30s after it happened, torn limbs grow back as meat,
	-- and the body regains 2 hp every 10 seconds. Stage 3 regrows a lost limb every 15s, one at a time.
	task.spawn(function()
		local since = {}
		local ticks = 0
		local lastRegrow = -math.huge
		while plr.Character == character and character.Parent and humanoid.Health > 0 do
			task.wait(1)
			ticks += 1
			local stage = character:GetAttribute("InfectStage") or 1
			-- (cut off from the Mother the flesh does not mend at all)
			if ticks % 10 == 0 and character:GetAttribute("GS_Boss") == "near" then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (stage >= 2 and 4 or 2))
			end
			local anyInjury = false
			local regrew = false
			for key in pairs(PART_NAME) do
				local level = character:GetAttribute("Injury_" .. key) or 0
				if level <= 0 then
					since[key] = nil
				else
					anyInjury = true
					since[key] = since[key] or os.clock()
					local limb = key ~= "Head" and key ~= "Torso"
					if stage >= 2 and level >= 3 and limb then
						if not regrew and os.clock() - since[key] >= 15 and os.clock() - lastRegrow >= 15 then
							regrew = true
							lastRegrow = os.clock()
							since[key] = nil
							local ok = FallDamageController.RestorePart(character, key)
							if ok then
								fleshShell(character, key)
								-- clients play the limb growing back out of the stump
								character:SetAttribute("GS_Regrow_" .. key, serverNow())
							end
						end
					elseif os.clock() - since[key] >= 30 then
						since[key] = nil
						if level >= 3 and limb then
							local ok = FallDamageController.RestorePart(character, key)
							if ok then
								fleshShell(character, key)
								character:SetAttribute("GS_Regrow_" .. key, serverNow())
							end
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
			plr:SetAttribute("InfectKills", nil)
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
		plr:SetAttribute("InfectKills", nil)
		pendingInfection[plr] = nil
	end
end

-- someone the infected killed (or whose body they ate) comes back as one of them
local INFECTED_REVIVE_DELAY = 7
local function infectVictim(victim, position)
	local plr = Players:GetPlayerFromCharacter(victim)
	if not plr or plr:GetAttribute("InfectPending") then return end
	plr:SetAttribute("InfectPending", true)
	local lost = {}
	for key in pairs(PART_NAME) do
		if (victim:GetAttribute("Injury_" .. key) or 0) >= 3 then lost[key] = true end
	end
	local token = {}
	pendingInfection[plr] = token
	task.delay(INFECTED_REVIVE_DELAY, function()
		if pendingInfection[plr] == token then reviveInfected(plr, lost, position) end
	end)
end

local function countInfectedKill(killer)
	local plr = Players:GetPlayerFromCharacter(killer)
	if not plr or not isInfected(killer) then return end
	plr:SetAttribute("InfectKills", (plr:GetAttribute("InfectKills") or 0) + 1)
	applyInfectStage(plr, killer)
end

-- ===== the Mother: the infected are bound to A-013 =====
-- Stay within BOSS_RADIUS of the nearest A-013 and nothing happens. Stray further, or have no Mother alive at
-- all, and the flesh weakens: slower, half-strength hits, no mending, and it withers down to 30% health.
-- Clients mark the Mother for the infected (GS_BossRef) and show the state (GS_Boss = near / far / none).
local BOSS_RADIUS = 90
local BOSS_WITHER = 1 -- hp per second while cut off
local BOSS_WITHER_FLOOR = 0.3
local BOSS_SLOW = 0.75
task.spawn(function()
	while true do
		task.wait(1)
		local mothers = {}
		for model, brain in pairs(monsters) do
			if brain.data.kind == "flesh" and model.Parent then table.insert(mothers, brain) end
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			local character = plr.Character
			if character and isInfected(character) and aliveCharacter(character) then
				local root = character.HumanoidRootPart
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local nearest, dist = nil, math.huge
				for _, mother in ipairs(mothers) do
					local d = (mother.root.Position - root.Position).Magnitude
					if d < dist then nearest, dist = mother, d end
				end
				local state = not nearest and "none" or (dist <= BOSS_RADIUS and "near" or "far")
				character:SetAttribute("GS_Boss", state)
				character:SetAttribute("GS_BossDist", nearest and math.floor(dist) or -1)
				local ref = character:FindFirstChild("GS_BossRef")
				if not ref then
					ref = Instance.new("ObjectValue")
					ref.Name = "GS_BossRef"
					ref.Parent = character
				end
				ref.Value = nearest and nearest.model or nil
				local weak = state ~= "near"
				local speed = INFECT_SPEED[infectStage(character)] * (weak and BOSS_SLOW or 1)
				-- (0 means ragdolled / paralysed: leave that alone)
				if humanoid.WalkSpeed > 0 and math.abs(humanoid.WalkSpeed - speed) > 0.01 then humanoid.WalkSpeed = speed end
				if weak and humanoid.Health > humanoid.MaxHealth * BOSS_WITHER_FLOOR then
					humanoid.Health = math.max(humanoid.MaxHealth * BOSS_WITHER_FLOOR, humanoid.Health - BOSS_WITHER)
				end
			end
		end
	end
end)

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
	local infected = isInfected(striker)
	local stage = infected and infectStage(striker) or 0
	local fake = {
		model = striker,
		data = {kind = "player", deathCause = infected and "INFECTED" or "BEATEN", damagePerLevel = 3,
			-- far from the Mother an infected hits at half strength
			damageBase = (infected and striker:GetAttribute("GS_Boss") ~= "near") and 2 or 4 + stage},
	}
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	local wasAlive = humanoid and humanoid.Health > 0
	local root = victim:FindFirstChild("HumanoidRootPart") or victim:FindFirstChild("Torso")
	local position = root and root.Position
	hitVictim(fake, victim)
	if infected and wasAlive then
		task.delay(0.1, function()
			if humanoid.Health > 0 then return end
			countInfectedKill(striker)
			if Players:GetPlayerFromCharacter(victim) and not isInfected(victim) and position then
				infectVictim(victim, position)
			end
		end)
	end
end

-- a survivor's punch doesn't wound anyone: it shoves them back a few steps
local SHOVE_SPEED = 44
local function shoveCharacter(striker, victim)
	local root = victim:FindFirstChild("HumanoidRootPart")
	local from = striker:FindFirstChild("HumanoidRootPart")
	if not root or not from then return end
	local dir = flat(root.Position - from.Position)
	if dir.Magnitude < 0.1 then dir = flat(from.CFrame.LookVector) end
	if dir.Magnitude < 0.1 then return end
	local push = dir.Unit * SHOVE_SPEED + Vector3.new(0, 16, 0)
	victim:SetAttribute("AC_TeleportAt", serverNow()) -- the anticheat lets the sudden slide through
	fxRemote:FireAllClients(victim, "Shoved")
	makeNoise(victim, 30, 1)
	local plr = Players:GetPlayerFromCharacter(victim)
	if plr then
		fxRemote:FireClient(plr, victim, "Shove", push) -- players move their own bodies
	else
		root.AssemblyLinearVelocity = push
	end
end

-- ===== the infected eat remains: walk up to a body or a torn-off limb and hold E =====
-- Every piece of meat lying around carries a ProximityPrompt (custom style, drawn by the EatPrompt client
-- script, shown only to the infected). One completed hold = one piece eaten.
do -- eating and the infected grab (in a block: the script is close to Luau's 200-local limit)
	local EAT_HOLD = 1.1
	local EAT_REACH = 11
	local eatPrompts = {}

	local function consumePiece(character, food, piece)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local isCorpse = isCorpseModel(food)
		if isCorpse then
			local list = food:GetAttribute("EatenParts")
			food:SetAttribute("EatenParts", (list and list ~= "" and (list .. ",") or "") .. piece.Name)
		end
		local where = piece.Position
		-- what is eaten leaves its bones behind
		if isCorpse then
			boneHolders[food] = Skeletons.FromPart(piece, boneHolders[food])
		else
			Skeletons.FromPart(piece)
		end
		fxRemote:FireAllClients(character, "Bite")
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (isCorpse and 25 or 15))
		if (character:GetAttribute("Bleeding") or 0) > 0 then FallDamageController.StopBleeding(character) end
		if not foodPiece(food) or not isCorpse then
			-- a player's body picked clean: they get up as one of us
			if isCorpse then
				local userId = food:GetAttribute("CorpseUserId")
				local plr = userId and Players:GetPlayerByUserId(userId)
				if plr and not aliveCharacter(plr.Character) and not plr:GetAttribute("InfectPending") then
					plr:SetAttribute("InfectPending", true)
					local root = character:FindFirstChild("HumanoidRootPart")
					reviveInfected(plr, splitList(food:GetAttribute("LostParts")), root and root.Position + root.CFrame.LookVector * 3 or where)
				end
			end
			if food.Parent then food:Destroy() end
		end
	end

	local function canEat(plr, food)
		local character = plr.Character
		if not aliveCharacter(character) or not isInfected(character) or character:GetAttribute("Ragdolled") then return nil end
		-- a creature already chewing on it keeps it
		if not food.Parent or food:GetAttribute("GS_BeingEaten") then return nil end
		local piece = foodPiece(food)
		local root = character:FindFirstChild("HumanoidRootPart")
		if not piece or not root or (piece.Position - root.Position).Magnitude > EAT_REACH then return nil end
		return character, piece
	end

	local function placeEatPrompt(food)
		local piece = foodPiece(food)
		local prompt = eatPrompts[food]
		if not piece then
			if prompt then prompt:Destroy() end
			eatPrompts[food] = nil
			return
		end
		-- (a prompt goes down with the piece it sat on; the next piece gets a fresh one)
		if not prompt or not prompt.Parent then
			if prompt then pcall(function() prompt:Destroy() end) end
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "GS_EatPrompt"
			prompt.ActionText = "Eat"
			local owner = food:GetAttribute("CorpseUserId") and Players:GetPlayerByUserId(food:GetAttribute("CorpseUserId"))
			prompt.ObjectText = isCorpseModel(food) and (owner and (owner.DisplayName .. "'s body") or "A body") or "Torn-off meat"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
			prompt.HoldDuration = EAT_HOLD
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt:SetAttribute("GS_Eat", true)
			prompt.PromptButtonHoldBegan:Connect(function(plr)
				local character = canEat(plr, food)
				if not character then return end
				-- crouch over it and tear at it while the key is held
				character:SetAttribute("GS_EatServer", serverNow() + EAT_HOLD + 0.3)
				fxRemote:FireAllClients(character, "Chew")
			end)
			prompt.PromptButtonHoldEnded:Connect(function(plr)
				local character = plr.Character
				if character and (character:GetAttribute("GS_EatServer") or 0) > serverNow() + 0.35 then
					character:SetAttribute("GS_EatServer", nil)
				end
			end)
			prompt.Triggered:Connect(function(plr)
				local character, piece = canEat(plr, food)
				if not character then return end
				character:SetAttribute("GS_EatServer", serverNow() + 0.3)
				consumePiece(character, food, piece)
				if food.Parent then placeEatPrompt(food) end
			end)
			eatPrompts[food] = prompt
		end
		-- a body keeps its prompt on the torso (the middle of it) until the torso itself is all that is left
		local torso = food:FindFirstChild("Torso")
		local anchor = (torso and torso:IsA("BasePart")) and torso or piece
		if prompt.Parent ~= anchor then prompt.Parent = anchor end
	end

	local function anyInfectedAlive()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character and isInfected(plr.Character) and aliveCharacter(plr.Character) then return true end
		end
		return false
	end

	-- prompts exist only while someone infected is walking around
	task.spawn(function()
		while true do
			task.wait(0.5)
			local wanted = anyInfectedAlive()
			local seen = {}
			if wanted then
				for _, folderName in ipairs({"SeveredLimbs", "Corpses"}) do
					local foodFolder = workspace:FindFirstChild(folderName)
					for _, model in ipairs(foodFolder and foodFolder:GetChildren() or {}) do
						if model:IsA("Model") then
							seen[model] = true
							placeEatPrompt(model)
						end
					end
				end
			end
			for food, prompt in pairs(eatPrompts) do
				if not seen[food] or not food.Parent then
					prompt:Destroy()
					eatPrompts[food] = nil
				end
			end
		end
	end)

	-- stage 2+: the tentacles lash out at a survivor further away and drag them in
	local PLAYER_GRAB_REACH = 22
	local playerGrabReady = {}
	local function infectedGrab(character, victim)
		local now = os.clock()
		if now < (playerGrabReady[character] or 0) then return false end
		local root = character:FindFirstChild("HumanoidRootPart")
		local vr = victim:FindFirstChild("HumanoidRootPart")
		local value = character:FindFirstChild("GS_GrabTarget")
		if not root or not vr or not value then return false end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {character, victim, folder}
		if workspace:Raycast(root.Position, vr.Position - root.Position, params) then return false end
		playerGrabReady[character] = now + 7
		character:SetAttribute("GS_GrabReadyAt", serverNow() + 7)
		character:SetAttribute("GS_GrabPoint", nil)
		value.Value = victim
		character:SetAttribute("GS_GrabHit", false)
		character:SetAttribute("GS_GrabAt", serverNow())
		fxRemote:FireAllClients(character, "Shriek")
		task.delay(0.35, function()
			if not aliveCharacter(victim) or not aliveCharacter(character) then return end
			if (vr.Position - root.Position).Magnitude > PLAYER_GRAB_REACH + 2 then return end
			character:SetAttribute("GS_GrabHit", true)
			fxRemote:FireAllClients(character, "Hit")
			makeNoise(victim, 60, 1.5)
			victim:SetAttribute("AC_TeleportAt", serverNow())
			FallDamageController.Ragdoll(victim, 2, 0.5)
			local torso = victim:FindFirstChild("Torso") or vr
			local started = os.clock()
			while os.clock() - started < 1 and aliveCharacter(victim) and aliveCharacter(character) do
				local offset = root.Position + root.CFrame.LookVector * 3 - torso.Position
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
			if value.Parent and value.Value == victim then value.Value = nil end
		end)
		return true
	end
	Players.PlayerRemoving:Connect(function(plr)
		if plr.Character then playerGrabReady[plr.Character] = nil end
	end)

	-- R (stage 2+): throw the tentacles at whoever is in front and in reach; a miss still lashes out
	local grabRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_InfectedGrab")
	local GRAB_CONE = 0.35
	grabRemote.OnServerEvent:Connect(function(player)
		local character = player.Character
		if not aliveCharacter(character) or not isInfected(character) or infectStage(character) < 3 then return end
		if character:GetAttribute("Ragdolled") or (character:GetAttribute("GS_EatServer") or 0) > serverNow() then return end
		local now = os.clock()
		if now < (playerGrabReady[character] or 0) then return end
		local root = character.HumanoidRootPart
		local look = flat(root.CFrame.LookVector).Unit
		local best, bestScore = nil, -math.huge
		for _, plr in ipairs(Players:GetPlayers()) do
			local other = plr.Character
			if other ~= character and aliveCharacter(other) and not isInfected(other) and not other:GetAttribute("Ragdolled") then
				local offset = other.HumanoidRootPart.Position - root.Position
				local d = offset.Magnitude
				local dir = flat(offset)
				if d <= PLAYER_GRAB_REACH and dir.Magnitude > 0.1 then
					local dot = look:Dot(dir.Unit)
					-- closest to the centre of the aim wins, nearer breaks ties
					local score = dot * 2 - d / PLAYER_GRAB_REACH
					if dot >= GRAB_CONE and score > bestScore then best, bestScore = other, score end
				end
			end
		end
		if best and infectedGrab(character, best) then return end
		-- missed: the tentacles whip out at the air in front and come back
		playerGrabReady[character] = now + 1.5
		character:SetAttribute("GS_GrabReadyAt", serverNow() + 1.5)
		local value = character:FindFirstChild("GS_GrabTarget")
		if value then value.Value = nil end
		character:SetAttribute("GS_GrabPoint", root.Position + look * (PLAYER_GRAB_REACH * 0.8) + Vector3.new(0, 1, 0))
		character:SetAttribute("GS_GrabHit", false)
		character:SetAttribute("GS_GrabAt", serverNow())
		fxRemote:FireAllClients(character, "Shriek")
	end)
end

-- ===== E-116 "The Weaver": webs, point-blank bites, low climbing =====
local webs = {}
local breakWeb, spinWeb
do -- (in a block: the script is close to Luau's 200-local limit)
	local webFolder = ensure(workspace, "Folder", "SpiderWebs")
	local WEB_MAX = 30
	local WEB_LIFE = 360
	local WEB_HOLD = 5 -- ragdolled and stuck this long
	local WEB_SLOW = 3 -- then the threads still cling: slowed for this long
	local WEB_COLOR = Color3.fromRGB(222, 222, 216)

	local function webThread(parent, a, b, width)
		local length = (b - a).Magnitude
		if length < 0.05 then return end
		local part = Instance.new("Part")
		part.Name = "Thread"
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.SmoothPlastic
		part.Color = WEB_COLOR
		part.Transparency = 0.3
		part.Reflectance = 0.15
		part.Size = Vector3.new(length, width, width)
		part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		part.Parent = parent
	end

	-- a round web in the plane of cf (its X and Y axes), w wide and h tall. tight = the rim touches the edges
	-- (a web strung across a passage); otherwise the rim is a little ragged
	local function buildWeb(cf, w, h, tight)
		local model = Instance.new("Model")
		model.Name = "Web"
		local spokes = 12
		local rim = {}
		for i = 1, spokes do
			local a = (i / spokes) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
			local reach = tight and 1 or rng:NextNumber(0.88, 1)
			rim[i] = Vector3.new(math.cos(a) * w / 2 * reach, math.sin(a) * h / 2 * reach, 0)
			webThread(model, cf.Position, cf:PointToWorldSpace(rim[i]), 0.07)
		end
		for _, f in ipairs({0.18, 0.36, 0.54, 0.72, 0.88, 1}) do
			for i = 1, spokes do
				local j = i % spokes + 1
				webThread(model, cf:PointToWorldSpace(rim[i] * f), cf:PointToWorldSpace(rim[j] * f), f == 1 and 0.07 or 0.05)
			end
		end
		local trigger = Instance.new("Part")
		trigger.Name = "Trigger"
		trigger.Anchored, trigger.CanCollide, trigger.CanQuery, trigger.CanTouch = true, false, false, false
		trigger.Transparency = 1
		trigger.Size = Vector3.new(w, h, 1.6)
		trigger.CFrame = cf
		trigger.Parent = model
		model.PrimaryPart = trigger
		model.Parent = webFolder
		local entry = {model = model, trigger = trigger, expires = os.clock() + WEB_LIFE}
		table.insert(webs, entry)
		while #webs > WEB_MAX do
			local old = table.remove(webs, 1)
			if old.model.Parent then old.model:Destroy() end
		end
		return entry
	end

	function breakWeb(entry)
		local index = table.find(webs, entry)
		if index then table.remove(webs, index) end
		if entry.model.Parent then entry.model:Destroy() end
	end

	-- the floor under a whole round web: flat, solid and with nothing sticking up through it. Returns the floor point.
	local function flatFloor(centre, radius, params)
		local mid = workspace:Raycast(centre + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), params)
		if not mid or mid.Normal.Y < 0.92 then return nil end
		local y = mid.Position.Y
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			for _, f in ipairs({0.55, 1}) do
				local p = Vector3.new(mid.Position.X + math.cos(a) * radius * f, y, mid.Position.Z + math.sin(a) * radius * f)
				local hit = workspace:Raycast(p + Vector3.new(0, 2.5, 0), Vector3.new(0, -3.3, 0), params)
				if not hit or math.abs(hit.Position.Y - y) > 0.25 then return nil end
			end
		end
		return mid.Position
	end

	-- spin across a passage if there is one, otherwise flat on a patch of open floor
	function spinWeb(brain)
		local root = brain.root
		local params = getMoveParams()
		local ground = groundAt(root.Position, 12)
		if not ground then return end
		local look = flat(root.CFrame.LookVector)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
		local side = Vector3.new(-look.Z, 0, look.X)
		local mid = ground + Vector3.new(0, 2.6, 0)
		local left = workspace:Raycast(mid, -side * 13, params)
		local right = workspace:Raycast(mid, side * 13, params)
		if left and right and math.abs(left.Normal.Y) < 0.3 and math.abs(right.Normal.Y) < 0.3 then
			local width = (right.Position - left.Position).Magnitude
			if width >= 4 and width <= 24 then
				local across = flat(right.Position - left.Position).Unit
				local centre = (left.Position + right.Position) / 2
				local floor = workspace:Raycast(Vector3.new(centre.X, mid.Y, centre.Z), Vector3.new(0, -6, 0), params)
				if floor and floor.Normal.Y > 0.9 then
					local ceiling = workspace:Raycast(Vector3.new(centre.X, mid.Y, centre.Z), Vector3.new(0, 11, 0), params)
					local height = math.clamp(ceiling and (ceiling.Position.Y - floor.Position.Y - 0.3) or 10, 5, 11)
					-- the plane runs wall to wall, standing straight up, with its lowest threads just off the floor
					local c = Vector3.new(centre.X, floor.Position.Y + 0.25 + height / 2, centre.Z)
					buildWeb(CFrame.fromMatrix(c, across, Vector3.yAxis), width, height, true)
					return
				end
			end
		end
		-- on the floor: try a few spots around the spider for one where the whole web lies flat
		for _, size in ipairs({rng:NextNumber(9, 12), 7}) do
			for attempt = 1, 7 do
				local offset = attempt == 1 and -look * 3
					or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * rng:NextNumber(2, 9)
				local spot = flatFloor(ground + offset, size / 2, params)
				if spot then
					-- spin it about the vertical first, then lay it down: the plane stays perfectly level
					buildWeb(CFrame.new(spot + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
						* CFrame.Angles(math.rad(-90), 0, 0), size, size)
					return
				end
			end
		end
		brain.nextWeb = os.clock() + 4 -- nowhere good here: look again soon
	end

	-- anything alive that walks into a web sticks for a moment, and every spider nearby feels it
	local webOverlap = OverlapParams.new()
	webOverlap.FilterType = Enum.RaycastFilterType.Include
	task.spawn(function()
		while true do
			task.wait(0.15)
			if #webs > 0 then
				local bodies = {}
				for _, plr in ipairs(Players:GetPlayers()) do
					if aliveCharacter(plr.Character) then table.insert(bodies, plr.Character) end
				end
				webOverlap.FilterDescendantsInstances = bodies
				local now = os.clock()
				for i = #webs, 1, -1 do
					local entry = webs[i]
					if not entry.model.Parent or now > entry.expires then
						table.remove(webs, i)
						if entry.model.Parent then entry.model:Destroy() end
					elseif not entry.tearing and #bodies > 0 then
						for _, part in ipairs(workspace:GetPartBoundsInBox(entry.trigger.CFrame, entry.trigger.Size, webOverlap)) do
							local character = part:FindFirstAncestorOfClass("Model")
							if character and aliveCharacter(character) then
								entry.tearing = true
								character:SetAttribute("GS_Webbed", serverNow() + WEB_HOLD + WEB_SLOW)
								-- caught: down in the threads until the web tears
								character:SetAttribute("AC_TeleportAt", serverNow())
								-- no ragdoll, no concussion: stuck down in the threads, getting up slowly (Animation)
								character:SetAttribute("GS_WebStunDur", WEB_HOLD)
								character:SetAttribute("GS_WebStun", serverNow() + WEB_HOLD)
								makeNoise(character, 40, 1)
								for _, brain in pairs(monsters) do
									if (brain.data.kind == "spider" or brain.data.kind == "spidermother") and (brain.root.Position - entry.trigger.Position).Magnitude < 140 then
										brain.webAlert = {victim = character, at = now}
									end
								end
								-- the web holds them, then tears
								task.delay(WEB_HOLD, function() breakWeb(entry) end)
								break
							end
						end
					end
				end
			end
		end
	end)
end

-- climbing: straight up a wall of up to 10 studs, never up a wall you can't see
local BROOD_MAX = 8 -- A-116 stops hatching once this many E-116 are about
local thinkSpider
do
	local SPIDER_CLIMB_MAX = 10
	local function tryClimb(brain, towards)
		local now = os.clock()
		if brain.climbing or now < (brain.nextClimbCheck or 0) then return false end
		brain.nextClimbCheck = now + 0.25
		local root = brain.root
		local dir = flat(towards - root.Position)
		if dir.Magnitude < 1.5 then return false end
		dir = dir.Unit
		local params = getMoveParams()
		local hit = workspace:Raycast(root.Position - Vector3.new(0, 0.6, 0), dir * 3.4, params)
		if not hit or math.abs(hit.Normal.Y) > 0.35 then return false end
		local wall = hit.Instance
		if not wall:IsA("BasePart") or wall.Transparency >= 0.5 then return false end -- no grip on what isn't there
		local hip = brain.humanoid.HipHeight + root.Size.Y / 2
		local groundY = root.Position.Y - hip
		local topHit = workspace:Raycast(hit.Position - hit.Normal * 1.6 + Vector3.new(0, SPIDER_CLIMB_MAX + 0.6, 0),
			Vector3.new(0, -(SPIDER_CLIMB_MAX + 1.2), 0), params)
		if not topHit or topHit.Normal.Y < 0.6 then return false end
		local height = topHit.Position.Y - groundY
		if height < 2.2 or height > SPIDER_CLIMB_MAX then return false end
		-- room to stand up there?
		if workspace:Raycast(topHit.Position + Vector3.new(0, 0.3, 0), Vector3.new(0, 3, 0), params) then return false end

		brain.climbing = true
		stop(brain)
		if brain.align then brain.align.Enabled = false end
		local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
		root.Anchored = true
		fx(brain, "Skitter")
		task.spawn(function()
			local function glide(from, to, duration)
				local t0 = os.clock()
				while true do
					local a = math.clamp((os.clock() - t0) / duration, 0, 1)
					if not root.Parent then return false end
					root.CFrame = from:Lerp(to, a * a * (3 - 2 * a))
					if a >= 1 then return true end
					RunService.Heartbeat:Wait()
				end
			end
			-- belly to the wall, head up
			local base = hit.Position + normal * (root.Size.Y / 2 + 0.9)
			base = Vector3.new(base.X, groundY + 1.6, base.Z)
			local onWall = CFrame.lookAt(base, base + Vector3.yAxis, normal)
			local okay = glide(root.CFrame, onWall, 0.3)
			local topPos = Vector3.new(base.X, topHit.Position.Y + 0.4, base.Z)
			okay = okay and glide(onWall, CFrame.lookAt(topPos, topPos + Vector3.yAxis, normal), math.max(0.4, (topPos.Y - base.Y) / 7))
			local stand = topHit.Position - normal * 1.2 + Vector3.new(0, hip + 0.1, 0)
			okay = okay and glide(root.CFrame, CFrame.lookAt(stand, stand - normal), 0.35)
			if root.Parent then
				root.Anchored = false
				root.AssemblyLinearVelocity = Vector3.zero
				pcall(function() root:SetNetworkOwner(nil) end)
			end
			brain.waypoints = nil
			brain.climbing = false
		end)
		return true
	end

	local SPIDER_SENSE = 16 -- it notices you this close even when it can't see you
	local SPIDER_SIGHT = 45
	-- (BROOD_MAX lives above: hatchBrood needs it)

	-- the nearest whole body lying around (A-116 only eats corpses, not loose limbs)
	local function nearestCorpse(brain, maxDist)
		local best, bestDist = nil, maxDist
		local corpses = workspace:FindFirstChild("Corpses")
		for _, model in ipairs(corpses and corpses:GetChildren() or {}) do
			if model:IsA("Model") and not model:GetAttribute("GS_BeingEaten") then
				local part = foodPiece(model)
				if part then
					local d = (part.Position - brain.root.Position).Magnitude
					if d < bestDist then best, bestDist = model, d end
				end
			end
		end
		return best
	end

	function thinkSpider(brain)
		local now = os.clock()
		local model = brain.model
		if not model.Parent then return false end
		if brain.climbing then return true end
		local root = brain.root
		local mother = brain.data.kind == "spidermother"
		local sense = mother and 22 or SPIDER_SENSE
		local sight = mother and 60 or SPIDER_SIGHT
		if brain.target and (not aliveCharacter(brain.target) or isInfected(brain.target)) then
			if mother and not aliveCharacter(brain.target) then
				-- her kill: the body becomes a corpse a few seconds later, and she stays for it
				local deadRoot = brain.target:FindFirstChild("HumanoidRootPart") or brain.target:FindFirstChild("Torso")
				if deadRoot and (deadRoot.Position - root.Position).Magnitude < 20 then
					brain.killPos, brain.killTime = deadRoot.Position, now
				end
			end
			setTarget(brain, nil)
			if brain.state == "hunt" then setState(brain, "roam") end
		end
		if now < (brain.staggerUntil or 0) then
			stop(brain)
			return true
		end

		-- A-116 feeding: nothing distracts her except someone walking right up to her
		if mother and brain.state == "eat" then
			for _, character in ipairs(livingTargets()) do
				if (character.HumanoidRootPart.Position - root.Position).Magnitude < 12 then
					abortEat(brain)
					setTarget(brain, character)
					setState(brain, "hunt")
					fx(brain, "Hiss")
					return true
				end
			end
			eatStep(brain, now, function()
				brain.killPos, brain.killTime = nil, nil
				return "roam"
			end)
			return true
		end

		-- something is struggling in one of the webs
		local alert = brain.webAlert
		if alert and now - alert.at < 12 and aliveCharacter(alert.victim) and not isInfected(alert.victim) then
			brain.webAlert = nil
			setTarget(brain, alert.victim)
			setState(brain, "hunt")
			fx(brain, "Skitter")
		end
		if not brain.target then
			local best, bestDist = nil, math.huge
			for _, character in ipairs(livingTargets()) do
				local d = (character.HumanoidRootPart.Position - root.Position).Magnitude
				if d < bestDist and (d < sense or (d < sight and canSee(brain, character))) then
					best, bestDist = character, d
				end
			end
			if best then
				setTarget(brain, best)
				setState(brain, "hunt")
				fx(brain, "Hiss")
			end
		end

		-- A-116 with nobody to chase: go and eat
		if mother and not brain.target then
			local food = nearestCorpse(brain, 55)
			if food then
				brain.food = food
				setState(brain, "eat")
				return true
			elseif brain.killPos and now - (brain.killTime or 0) < 9 then
				if (brain.killPos - root.Position).Magnitude > 5 then goTo(brain, brain.killPos, WALK_SPEED) else stop(brain) end
				return true
			end
		end

		local targetRoot = brain.target and brain.target:FindFirstChild("HumanoidRootPart")
		if brain.state == "hunt" then
			local distance = targetRoot and (targetRoot.Position - root.Position).Magnitude or math.huge
			if targetRoot and (distance < sense or canSee(brain, brain.target)) then brain.lastSeen = now end
			if not targetRoot or distance > (mother and 90 or 70) or now - (brain.lastSeen or 0) > 9 then
				setTarget(brain, nil)
				setState(brain, "roam")
			else
				local speed = HUMAN_SPEED * (brain.data.speedMultiplier or 0.8)
				if not tryClimb(brain, targetRoot.Position) then
					-- it only bites at point blank: attackStep swings only inside attackRange
					attackStep(brain, now, targetRoot, speed, "hunt", brain.data.swingCooldown or 1.2, 0.16)
				end
			end
		else
			if brain.state ~= "roam" then setState(brain, "roam") end
			if now >= (brain.nextWeb or 0) then
				brain.nextWeb = now + (mother and rng:NextNumber(35, 60) or rng:NextNumber(18, 32))
				stop(brain)
				fx(brain, "Skitter")
				spinWeb(brain)
			elseif not brain.roamGoal or now > brain.roamUntil then
				brain.roamGoal = groundSpot(root.Position, 12, 40)
				brain.roamUntil = now + rng:NextNumber(6, 12)
			else
				if not tryClimb(brain, brain.roamGoal) then
					if goTo(brain, brain.roamGoal, WALK_SPEED * 0.75) then brain.roamUntil = now end
				end
			end
		end

		if now >= (brain.nextSound or 0) then
			brain.nextSound = now + rng:NextNumber(4, 9)
			fx(brain, brain.state == "hunt" and "Hiss" or "Skitter")
		end
		return true
	end
end

local THINK = {skinwalker = thinkSkinwalker, flesh = thinkFlesh, listener = thinkListener, spider = thinkSpider,
	spidermother = thinkSpider}

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
			local ok, alive
			if (brain.stunUntil or 0) > os.clock() then
				ok, alive = true, true
				pcall(stop, brain)
			else
				ok, alive = pcall(THINK[brain.data.kind] or think, brain)
			end
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

-- A-116 finished a body: the egg sac splits and a new E-116 crawls out next to her
function hatchBrood(brain)
	local count = 0
	for _, other in pairs(monsters) do
		if other.data.kind == "spider" then count += 1 end
	end
	if count >= BROOD_MAX then return end
	local root = brain.root
	local back = root.CFrame * CFrame.new(rng:NextNumber(-2, 2), 0, 5)
	local ground = groundAt(back.Position, 12)
	local spot = (ground or back.Position) + Vector3.new(0, 2, 0)
	local model = buildModel("E-116", CFrame.lookAt(spot, spot + flat(root.CFrame.LookVector)))
	if not model then return end
	local baby = startBrain(model, "E-116")
	fx(brain, "Hiss")
	fx(baby, "Skitter")
	-- a newborn scurries off before it starts hunting
	baby.nextWeb = os.clock() + rng:NextNumber(8, 15)
end


local lastStrike = {}
strikeRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local character = player.Character
	if not aliveCharacter(character) or character:GetAttribute("Ragdolled") then return end
	-- the infected claw fast; a survivor's shove needs a breath between swings
	if now - (lastStrike[player] or 0) < (isInfected(character) and 0.65 or 1.4) then return end
	lastStrike[player] = now
	local left = character:GetAttribute("Injury_LeftArm") or 0
	local right = character:GetAttribute("Injury_RightArm") or 0
	if left >= 2 and right >= 2 then return end
	local root = character.HumanoidRootPart
	makeNoise(character, 45, 1)
	-- a swing tears any web right in front of you
	do
		local reachPoint = root.Position + flat(root.CFrame.LookVector) * 2
		for i = #webs, 1, -1 do
			local entry = webs[i]
			if entry.model.Parent and not entry.tearing then
				local p = entry.trigger.CFrame:PointToObjectSpace(reachPoint)
				local size = entry.trigger.Size
				if math.abs(p.X) < size.X / 2 + 1.5 and math.abs(p.Y) < size.Y / 2 + 1.5 and math.abs(p.Z) < 3.2 then
					breakWeb(entry)
				end
			end
		end
	end
	local infected = isInfected(character)
	if infected and (character:GetAttribute("GS_EatServer") or 0) > serverNow() then return end
	-- the infected reach further and swing wider
	local stage = infected and infectStage(character) or 0
	local reach = infected and INFECT_REACH[stage] or 6
	local arc = infected and -0.15 or 0.2
	local function inFront(position, range, minDot)
		local offset = position - root.Position
		return offset.Magnitude < range and flat(offset).Magnitude > 0.1 and flat(root.CFrame.LookVector):Dot(flat(offset).Unit) > (minDot or 0.2)
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
			if d < bestDist and inFront(other.HumanoidRootPart.Position, reach, arc) then best, bestDist = other, d end
		end
	end
	if infected then
		local npcFolder = workspace:FindFirstChild("NPCs")
		for _, npc in ipairs(npcFolder and npcFolder:GetChildren() or {}) do
			if npc:IsA("Model") and aliveCharacter(npc) then
				local d = (npc.HumanoidRootPart.Position - root.Position).Magnitude
				if d < bestDist and inFront(npc.HumanoidRootPart.Position, reach, arc) then best, bestDist = npc, d end
			end
		end
		-- (eating is on E and the tentacle grab on R: F only ever hits)
	end
	if best then task.delay(0.2, function()
			if not aliveCharacter(best) or not aliveCharacter(character) then return end
			if infected then strikeCharacter(character, best) else shoveCharacter(character, best) end
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
		if MonsterData.Get(id).kind == "spitter" then
			local spitter = game:GetService("ServerStorage"):FindFirstChild("GS_SpitterControl")
			if not spitter then return false, "the Spitter script is not running" end
			return spitter:Invoke("Spawn", cframe)
		end
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
	elseif action == "SetInfection" then
		-- admin panel: 0 cures, 1-3 infects (or re-stages) the player right where they stand
		local plr, stage = ...
		if typeof(plr) ~= "Instance" or not plr:IsA("Player") then return false, "player not found" end
		stage = math.clamp(math.floor(tonumber(stage) or 0), 0, 3)
		local character = plr.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local where = root and root.CFrame
		if stage == 0 then
			if not plr:GetAttribute("Infected") then return false, plr.DisplayName .. " is not infected" end
			pendingInfection[plr] = nil
			for _, key in ipairs({"Infected", "FleshParts", "InfectKills", "InfectPending", "InfectSpawn", "InfectStartKills"}) do
				plr:SetAttribute(key, nil)
			end
			plr:LoadCharacter()
			if where and plr.Character then
				plr.Character:SetAttribute("AC_TeleportAt", serverNow())
				plr.Character:PivotTo(where)
			end
			return true, plr.DisplayName .. " cured"
		end
		local kills = ({0, STAGE_KILLS[1], STAGE_KILLS[2]})[stage]
		if aliveCharacter(character) and isInfected(character) then
			plr:SetAttribute("InfectKills", kills)
			applyInfectStage(plr, character)
			return true, string.format("%s is now infected, stage %d", plr.DisplayName, stage)
		end
		pendingInfection[plr] = nil
		plr:SetAttribute("Infected", true)
		plr:SetAttribute("InfectPending", true)
		plr:SetAttribute("FleshParts", "")
		plr:SetAttribute("InfectStartKills", kills)
		local spawnPart = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		local fallback = spawnPart and spawnPart.Position or Vector3.new(0, 5, 0)
		plr:SetAttribute("InfectSpawn", where and where.Position - Vector3.new(0, 3, 0) or fallback)
		plr:LoadCharacter()
		return true, string.format("%s turned, stage %d", plr.DisplayName, stage)
	elseif action == "Strike" then
		-- server-only testing hook: hit a monster by model name on behalf of a character
		local name, character = ...
		for model, brain in pairs(monsters) do
			if model.Name == name and typeof(character) == "Instance" then
				onStruck(brain, character)
				return true, brain.state, brain.enraged == true, brain.hitsTaken
			end
		end
		return false, "not found"
	elseif action == "Struck" then
		-- a weapon hit (Weapons / MonsterHealth): the creature reacts like it was struck
		local model, character = ...
		local brain = monsters[model]
		if brain and typeof(character) == "Instance" and character:IsA("Model") then onStruck(brain, character) end
		return true
	elseif action == "Kill" then
		-- MonsterHealth took the last of its health: the brain stops
		local model = ...
		local brain = monsters[model]
		if brain then
			monsters[model] = nil
			pcall(stop, brain)
		end
		return true
	elseif action == "Stun" then
		local model, seconds = ...
		local brain = monsters[model]
		local untilT = os.clock() + (tonumber(seconds) or 1)
		if brain then brain.stunUntil = math.max(brain.stunUntil or 0, untilT) end
		-- creatures with a brain of their own (the Spitter) read it from the model
		if typeof(model) == "Instance" then model:SetAttribute("GS_StunUntil", untilT) end
		return true
	elseif action == "Noise" then
		-- gunshots and the like, for every creature's ears
		local character, radius, duration = ...
		if typeof(character) == "Instance" then makeNoise(character, tonumber(radius) or 40, tonumber(duration) or 1) end
		return true
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

-- ===== the journal: still copies of every object for the menu's 3D view (ReplicatedStorage.GS_Journal) =====
-- A-013 also gets the three stages of what it turns people into.
task.spawn(function()
	local journal = ReplicatedStorage:FindFirstChild("GS_Journal")
	if journal then journal:Destroy() end
	journal = Instance.new("Folder")
	journal.Name = "GS_Journal"

	local function limb(model, a, b, width, color)
		local length = (b - a).Magnitude
		if length < 0.05 then return end
		local part = Instance.new("Part")
		part.Name = "GS_PreviewLeg"
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.Slate
		part.Color = color
		part.Size = Vector3.new(length, width, width)
		part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		part.Parent = model
		local joint = Instance.new("Part")
		joint.Name = "GS_PreviewJoint"
		joint.Shape = Enum.PartType.Ball
		joint.Material = Enum.Material.Slate
		joint.Color = color:Lerp(Color3.new(1, 1, 1), 0.08)
		joint.Size = Vector3.one * width * 1.4
		joint.CFrame = CFrame.new(b)
		joint.Parent = model
	end

	-- the legs are normally drawn by each client; the preview gets a fixed standing pose
	local function staticLegs(model)
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local scale = model:GetAttribute("SpiderScale") or 1
		local hipHeight = model:GetAttribute("SpiderHip") or 1
		local color = model:FindFirstChild("Torso") and model.Torso.Color or Color3.fromRGB(30, 23, 21)
		for i = 1, 8 do
			local hip = root:FindFirstChild("Leg" .. i)
			if hip then
				local side = hip.Position.X < 0 and -1 or 1
				local from = hip.WorldPosition
				local foot = root.CFrame:PointToWorldSpace(Vector3.new(side * 3.1 * scale, -(hipHeight + root.Size.Y / 2), hip.Position.Z * 1.7))
				local knee = (from + foot) / 2 + root.CFrame.UpVector * 1.5 * scale + root.CFrame.RightVector * side * 0.5 * scale
				limb(model, from, knee, 0.22 * scale, color)
				limb(model, knee, foot, 0.15 * scale, color)
			end
		end
	end

	local function freeze(model)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			end
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
		model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	end

	local function body(id)
		local data = MonsterData.Get(id)
		if not data then return nil end
		local model
		if data.kind == "skinwalker" then
			model = buildBareModel()
			if model then applyBareLook(model) end
		elseif data.kind == "flesh" then
			model = buildFleshModel()
		elseif data.kind == "listener" then
			model = buildListenerModel()
		elseif data.kind == "spider" or data.kind == "spidermother" then
			model = buildSpiderModel(data.kind == "spidermother")
			staticLegs(model)
		else
			local template = getTemplate()
			model = template and template:Clone()
			local head = model and model:FindFirstChild("Head")
			for _, part in ipairs(head and head:GetChildren() or {}) do
				if part:IsA("BasePart") and part.Name == "Eye" then part.Color = Color3.fromRGB(205, 215, 225) end
			end
		end
		return model
	end

	for _, id in ipairs(MonsterData.Order) do
		local ok, model = pcall(body, id)
		if ok and model then
			freeze(model)
			model.Name = id
			model.Parent = journal
		else
			warn("[Journal] no preview for " .. id .. ": " .. tostring(model))
		end
	end

	-- A-013's victims: I - just turned (the eaten limbs came back as meat), II - the meat has taken the whole body,
	-- III - the eyes, the teeth and the tentacles
	local SKIN = Color3.fromRGB(196, 150, 120)
	for stage = 1, 3 do
		local ok, model = pcall(function()
			local m = coloredModel(SKIN)
			if not m then return nil end
			local bodyColors = m:FindFirstChildOfClass("BodyColors")
			for _, name in ipairs({"Torso", "Left Leg", "Right Leg"}) do
				local part = m:FindFirstChild(name)
				if part then part.Color = name == "Torso" and Color3.fromRGB(58, 60, 64) or Color3.fromRGB(38, 42, 56) end
			end
			if bodyColors then
				bodyColors.TorsoColor3 = Color3.fromRGB(58, 60, 64)
				bodyColors.LeftLegColor3 = Color3.fromRGB(38, 42, 56)
				bodyColors.RightLegColor3 = Color3.fromRGB(38, 42, 56)
			end
			if stage == 1 then
				fleshShellPart(m:FindFirstChild("Left Arm"))
				fleshShellPart(m:FindFirstChild("Right Leg"))
			else
				coverBody(m)
			end
			if stage == 3 then
				-- the eyes and the teeth; the tentacles are drawn (and move) in the journal itself
				addInfectedFace(m)
			end
			return m
		end)
		if ok and model then
			freeze(model)
			model.Name = "A-013_Stage" .. stage
			model.Parent = journal
		else
			warn("[Journal] stage " .. stage .. ": " .. tostring(model))
		end
	end
	journal.Parent = ReplicatedStorage
end)
