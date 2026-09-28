local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))
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
local SKIN_BARE = Color3.fromRGB(192, 190, 186)
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

local function livingTargets()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if aliveCharacter(plr.Character) then table.insert(list, plr.Character) end
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

local function buildBareModel()
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(bareDescription(), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then return nil end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") then d:Destroy() end
	end
	return model
end

local function buildModel(id, cframe)
	local data = MonsterData.Get(id)
	if not data then return nil, "unknown object" end
	local model
	if data.kind == "skinwalker" then
		model = buildBareModel()
		if not model then return nil, "could not build the body" end
	else
		local template = getTemplate()
		if not template then return nil, "shadow template missing" end
		model = template:Clone()
	end
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
		applyBareLook(model)
	else

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
		if humanoid.Health <= 0 then character:SetAttribute("DeathCause", cause) end
		return
	end
	local roll = rng:NextNumber(0, total)
	local part = choices[#choices][1]
	for _, c in ipairs(choices) do
		roll -= c[2]
		if roll <= 0 then part = c[1] break end
	end
	local level = (character:GetAttribute("Injury_" .. part) or 0) + 1
	humanoid:TakeDamage((brain.data.damageBase or 4) + level * (brain.data.damagePerLevel or 3))
	if humanoid.Health <= 0 then
		character:SetAttribute("DeathCause", cause)
		return
	end
	FallDamageController.Injure(character, part, level)
	if level >= 3 then
		brain.eatPriorityUntil = os.clock() + 20
	end
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

local function abortEat(brain)
	if brain.food and brain.food.Parent then brain.food:SetAttribute("GS_BeingEaten", nil) end
	if brain.eatingPiece and brain.eatingPiece.Parent then
		pcall(function() brain.eatingPiece.Anchored = false end)
	end
	brain.food, brain.eatingPiece, brain.eatingUntil = nil, nil, nil
	brain.model:SetAttribute("GS_EatServer", nil)
end

local skinwalkerStruck
local function onStruck(brain, striker)
	if brain.data.kind == "skinwalker" and skinwalkerStruck then
		skinwalkerStruck(brain, striker)
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

local function eatStep(brain, now, nextState)
	local model, root = brain.model, brain.root
	local food = brain.food
	local piece = foodPiece(food)
	local isCorpse = food and isCorpseModel(food)
	local function finish()
		brain.eatingUntil = nil
		brain.eatPriorityUntil = 0
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
				eaten:Destroy()
			end
			if foodPiece(food) then
				brain.stateSince = now
			else
				finish()
			end
		else
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

	if brain.state ~= "eat" and brain.state ~= "retreat" then
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
			setState(brain, "watch")
		else
			local point = freshestTrailPoint(brain, 140)
			if point then
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
			if brain.unreachableSince and now - brain.unreachableSince > 6 then
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
		if brain.target == brain.lastHitVictim and brain.lastHitLook and now - (brain.lastHitTime or 0) < 8 then
			brain.killedLook = brain.lastHitLook
		end
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
		local found = pickTarget(brain)
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
			local point = freshestTrailPoint(brain, 140)
			if point then
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
			local shouldReveal = brain.stareTime > 2.6
				or (alone and distance < 10 and mimicFor > 15 and rng:NextNumber() < 0.05)
				or (mimicFor > 120 and distance < 14)
			if shouldReveal then
				brain.revealUntil = now + 1.3
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
		eatStep(brain, now, function()
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
			local ok, alive = pcall(brain.data.kind == "skinwalker" and thinkSkinwalker or think, brain)
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

local lastStrike = {}
strikeRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastStrike[player] or 0) < 0.65 then return end
	lastStrike[player] = now
	local character = player.Character
	if not aliveCharacter(character) or character:GetAttribute("Ragdolled") then return end
	local left = character:GetAttribute("Injury_LeftArm") or 0
	local right = character:GetAttribute("Injury_RightArm") or 0
	if left >= 2 and right >= 2 then return end
	local root = character.HumanoidRootPart
	for _, brain in pairs(monsters) do
		local offset = brain.root.Position - root.Position
		if offset.Magnitude < 7 and flat(root.CFrame.LookVector):Dot(flat(offset).Unit) > 0.2 then
			onStruck(brain, character)
		end
	end
end)
Players.PlayerRemoving:Connect(function(player) lastStrike[player] = nil end)

control.OnInvoke = function(action, ...)
	if action == "Spawn" then
		local id, near = ...
		if not MonsterData.Get(id) then return false, "unknown object" end
		if typeof(near) ~= "Vector3" then return false, "no position" end
		local spot = groundSpot(near, 30, 45)
		local look = flat(near - spot)
		local cframe = look.Magnitude > 0.1 and CFrame.lookAt(spot, spot + look) or CFrame.new(spot)
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
