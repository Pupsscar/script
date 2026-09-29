-- C-310 "The Spitter": a hunched green thing with acid sacs in its throat. It keeps its distance and spits.
--   * the spit flies in an arc (every client draws it from the same start, speed and gravity)
--   * a direct hit burns hard, and the fumes keep poisoning you for a few seconds
--   * a gas mask (or the SCG helmet) stops the poisoning and softens the burn: it's the breathing that kills
--   * where it lands a puddle of acid hisses for a while
-- Spawned from the admin panel like any other object (Monsters hands it over through GS_SpitterControl).
-- Health, limbs and death: MonsterHealth (id C-310).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local ID = "C-310"
local SPIT_SPEED = 85
local SPIT_GRAVITY = 40
local SPIT_COOLDOWN = {3, 4.5}
local SPIT_DAMAGE = 20
local POISON_DPS, POISON_TIME = 3, 6
local PUDDLE_TIME, PUDDLE_RADIUS, PUDDLE_DPS = 7, 3.2, 5
local KEEP_MIN, KEEP_MAX = 16, 34
local SIGHT = 110
local CLAW_DAMAGE = 11

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local control = ensure(ServerStorage, "BindableFunction", "GS_SpitterControl")
local fxRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_MonsterHit")
local folder = ensure(workspace, "Folder", "Monsters")

local rng = Random.new()
local function serverNow() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function itemService()
	local ok, svc = pcall(function() return require(ServerStorage:FindFirstChild("GS_ItemService")) end)
	return ok and svc or nil
end

-- ===== the body =====
local GREEN, DARK, SAC = Color3.fromRGB(88, 128, 52), Color3.fromRGB(50, 74, 30), Color3.fromRGB(190, 230, 60)

local function blob(model, part, cf, size, color, material, transparency)
	local b = Instance.new("Part")
	b.Name = "GS_Blob"
	b.Size = size
	b.Color = color
	b.Material = material or Enum.Material.SmoothPlastic
	b.Transparency = transparency or 0
	b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow, b.Massless = false, false, false, false, true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = b
	b.CFrame = part.CFrame * cf
	local w = Instance.new("WeldConstraint")
	w.Part0 = part
	w.Part1 = b
	w.Parent = b
	b.Parent = model
	return b
end

local function build(cframe)
	local desc = Instance.new("HumanoidDescription")
	for _, key in ipairs({"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"}) do
		desc[key] = GREEN
	end
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6) end)
	if not ok or not model then return nil end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Decal") then d:Destroy() end
	end
	model.Name = ID
	local head, torso = model:FindFirstChild("Head"), model:FindFirstChild("Torso")
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.12
		end
	end
	-- a hunched back of lumps and spines
	for i = 1, 6 do
		blob(model, torso, CFrame.new(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 0.9), 0.5), Vector3.new(0.7, 0.6, 0.6) * rng:NextNumber(0.8, 1.3), DARK)
		local spine = Instance.new("WedgePart")
		spine.Name = "GS_Spine"
		spine.Size = Vector3.new(0.12, 0.5, 0.35)
		spine.Color = Color3.fromRGB(180, 170, 120)
		spine.CanCollide, spine.CanQuery, spine.CanTouch, spine.Massless = false, false, false, true
		spine.CFrame = torso.CFrame * CFrame.new(0, 0.95 - i * 0.3, 0.62) * CFrame.Angles(math.rad(-30), 0, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1, w.Parent = torso, spine, spine
		spine.Parent = model
	end
	-- the acid sacs: swollen, glowing, under the jaw and on the neck
	for _, s in ipairs({-1, 1}) do
		local sac = blob(model, head, CFrame.new(s * 0.42, -0.42, -0.2), Vector3.new(0.55, 0.6, 0.55), SAC, Enum.Material.Neon, 0.15)
		sac.Name = "GS_Sac"
		blob(model, torso, CFrame.new(s * 0.45, 0.85, -0.45), Vector3.new(0.45, 0.45, 0.45), SAC, Enum.Material.Neon, 0.2).Name = "GS_Sac"
	end
	-- a wide jaw with teeth, four small black eyes
	blob(model, head, CFrame.new(0, -0.25, -0.52), Vector3.new(0.9, 0.35, 0.3), Color3.fromRGB(20, 26, 8))
	for i = -3, 3 do
		blob(model, head, CFrame.new(i * 0.1, -0.13, -0.63), Vector3.new(0.05, 0.12, 0.05), Color3.fromRGB(226, 220, 170))
	end
	for _, e in ipairs({{-0.22, 0.2}, {0.22, 0.2}, {-0.34, 0.05}, {0.34, 0.05}}) do
		blob(model, head, CFrame.new(e[1], e[2], -0.55), Vector3.new(0.14, 0.14, 0.1), Color3.fromRGB(8, 8, 6))
	end
	local glow = Instance.new("PointLight")
	glow.Color = SAC
	glow.Range = 7
	glow.Brightness = 0.6
	glow.Parent = head
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth, humanoid.Health = 1e6, 1e6
	humanoid.WalkSpeed = 12
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model:SetAttribute("MonsterId", ID)
	model:SetAttribute("DangerClass", "C")
	model:PivotTo(cframe)
	-- turning is done by physics (smooth for everyone) instead of snapping the body around
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		local att = Instance.new("Attachment")
		att.Name = "GS_FaceAttachment"
		att.Parent = root
		local align = Instance.new("AlignOrientation")
		align.Name = "GS_Face"
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = att
		align.MaxTorque = 1e6
		align.Responsiveness = 14
		align.Enabled = false
		align.Parent = root
	end
	model.Parent = folder
	pcall(function() model.HumanoidRootPart:SetNetworkOwner(nil) end)
	return model
end

-- ===== targets =====
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function alive(character)
	local h = character and character:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

local function targets()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		if alive(c) and not c:GetAttribute("Infected") then table.insert(list, c) end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	for _, npc in ipairs(npcs and npcs:GetChildren() or {}) do
		if npc:IsA("Model") and alive(npc) then table.insert(list, npc) end
	end
	return list
end

local function canSee(model, character)
	local head = model:FindFirstChild("Head")
	local th = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not head or not th then return false end
	local offset = th.Position - head.Position
	if offset.Magnitude > SIGHT then return false end
	sightParams.FilterDescendantsInstances = {folder, character}
	return workspace:Raycast(head.Position, offset, sightParams) == nil
end

-- ===== acid =====
local puddles = {}

local function poison(character, seconds)
	local h = character:FindFirstChildOfClass("Humanoid")
	if not h then return end
	local untilT = serverNow() + seconds
	if (character:GetAttribute("GS_Poison") or 0) > serverNow() then
		character:SetAttribute("GS_Poison", untilT)
		return
	end
	character:SetAttribute("GS_Poison", untilT)
	task.spawn(function()
		while character.Parent and h.Health > 0 and (character:GetAttribute("GS_Poison") or 0) > serverNow() do
			task.wait(1)
			if character:GetAttribute("GS_Filter") then break end -- put the mask on: the burning in your chest stops
			character:SetAttribute("LastDamageCause", "ACID")
			character:SetAttribute("LastDamageTime", serverNow())
			h:TakeDamage(POISON_DPS)
			if h.Health <= 0 then character:SetAttribute("DeathCause", "ACID") end
		end
		if character.Parent then character:SetAttribute("GS_Poison", nil) end
	end)
end

local function acidHit(victim, direct)
	local h = victim:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end
	local filtered = victim:GetAttribute("GS_Filter") == true
	local dmg = direct and SPIT_DAMAGE or PUDDLE_DPS
	if filtered then dmg *= direct and 0.55 or 0.5 end
	local svc = itemService()
	if svc and svc.Absorb then dmg = svc.Absorb(victim, direct and "Head" or "LeftLeg", dmg, "acid") end
	victim:SetAttribute("LastDamageCause", "ACID")
	victim:SetAttribute("LastDamageTime", serverNow())
	h:TakeDamage(dmg)
	if h.Health <= 0 then victim:SetAttribute("DeathCause", "ACID") return end
	if direct then
		if not filtered then poison(victim, POISON_TIME) end
		local plr = Players:GetPlayerFromCharacter(victim)
		if plr then fxRemote:FireClient(plr, "acidscreen", victim, filtered) end
	end
end

local function spit(model, target)
	local head = model:FindFirstChild("Head")
	local troot = target:FindFirstChild("HumanoidRootPart")
	if not head or not troot then return end
	local origin = head.Position + head.CFrame.LookVector * 0.8 - Vector3.new(0, 0.3, 0)
	-- aim where they will be, then lift the shot for the drop
	local aimAt = troot.Position + Vector3.new(0, 0.8, 0)
	local dist = (aimAt - origin).Magnitude
	local flight = dist / SPIT_SPEED
	aimAt += flat(troot.AssemblyLinearVelocity) * flight * 0.8
	aimAt += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)) * (dist / 30)
	local velocity = (aimAt - origin).Unit * SPIT_SPEED + Vector3.new(0, 0.5 * SPIT_GRAVITY * flight, 0)
	fxRemote:FireAllClients("spit", model, origin, velocity, SPIT_GRAVITY, serverNow())
	-- the server flies the same arc and decides what it hits
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {folder}
	local pos, vel = origin, velocity
	local elapsed = 0
	task.spawn(function()
		while elapsed < 3 do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			local newVel = vel - Vector3.new(0, SPIT_GRAVITY * dt, 0)
			local step = (vel + newVel) * 0.5 * dt
			local hit = workspace:Raycast(pos, step, params)
			if hit then
				local victim = hit.Instance:FindFirstAncestorOfClass("Model")
				while victim and not victim:FindFirstChildOfClass("Humanoid") do victim = victim:FindFirstAncestorOfClass("Model") end
				if victim and victim.Parent ~= folder and alive(victim) then acidHit(victim, true) end
				-- a puddle only where it hit the world: a spit that hits someone splashes over them, it doesn't
				-- leave a puddle hanging in the air where their head was
				if not victim then
					local ground = hit.Normal.Y > 0.5 and hit.Position or nil
					if not ground then
						local down = workspace:Raycast(hit.Position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
						ground = down and down.Position
					end
					if ground then
						table.insert(puddles, {pos = ground, untilT = os.clock() + PUDDLE_TIME, last = {}})
						fxRemote:FireAllClients("acidpuddle", ground, PUDDLE_TIME, PUDDLE_RADIUS)
					end
				end
				fxRemote:FireAllClients("spitsplat", hit.Position, hit.Normal, victim)
				return
			end
			pos += step
			vel = newVel
		end
	end)
end

-- puddles burn whoever stands in them
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for i = #puddles, 1, -1 do
			local p = puddles[i]
			if now > p.untilT then
				table.remove(puddles, i)
			else
				for _, c in ipairs(targets()) do
					local root = c.HumanoidRootPart
					local d = flat(root.Position - p.pos).Magnitude
					if d < PUDDLE_RADIUS and math.abs(root.Position.Y - p.pos.Y) < 4.5 and now - (p.last[c] or 0) >= 1 then
						p.last[c] = now
						acidHit(c, false)
					end
				end
			end
		end
	end
end)

-- ===== the brain =====
local function wander(model, humanoid, brain)
	if not brain.roamGoal or os.clock() > brain.roamUntil then
		local root = model.HumanoidRootPart
		local a = rng:NextNumber(0, math.pi * 2)
		brain.roamGoal = root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(12, 30)
		brain.roamUntil = os.clock() + rng:NextNumber(5, 9)
	end
	humanoid.WalkSpeed = 8
	humanoid:MoveTo(brain.roamGoal)
end

local function moveTo(model, humanoid, brain, goal, speed)
	humanoid.WalkSpeed = speed
	local root = model.HumanoidRootPart
	-- straight at it, and a path when it keeps bumping into things
	if brain.path and brain.pathIndex and os.clock() < brain.pathUntil then
		local wp = brain.path[brain.pathIndex]
		if wp then
			if flat(wp.Position - root.Position).Magnitude < 2.5 then brain.pathIndex += 1 end
			if wp.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
			humanoid:MoveTo(wp.Position)
			return
		end
	end
	humanoid:MoveTo(goal)
	local moved = brain.lastPos and (root.Position - brain.lastPos).Magnitude or 1
	brain.lastPos = root.Position
	brain.stuck = moved < 0.25 and (brain.stuck or 0) + 1 or 0
	if brain.stuck > 12 then
		brain.stuck = 0
		local path = PathfindingService:CreatePath({AgentRadius = 1.8, AgentHeight = 5, AgentCanJump = true})
		local ok = pcall(function() path:ComputeAsync(root.Position, goal) end)
		if ok and path.Status == Enum.PathStatus.Success then
			brain.path, brain.pathIndex, brain.pathUntil = path:GetWaypoints(), 2, os.clock() + 4
		else
			humanoid.Jump = true
		end
	end
end

local function run(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local brain = {nextSpit = os.clock() + 2, nextClaw = 0, lastHit = 0, mode = "hold"}
	local align = root and root:FindFirstChild("GS_Face")
	-- face a point smoothly (the body keeps looking at its prey even while it backs away)
	local function face(point)
		if not align then return end
		local look = flat(point - root.Position)
		if look.Magnitude < 0.1 then return end
		humanoid.AutoRotate = false
		align.CFrame = CFrame.lookAt(Vector3.zero, look)
		align.Enabled = true
	end
	local function freeTurn()
		humanoid.AutoRotate = true
		if align then align.Enabled = false end
	end
	while model.Parent and not model:GetAttribute("GS_Dead") do
		task.wait(0.1)
		local now = os.clock()
		if (model:GetAttribute("GS_StunUntil") or 0) > now then
			humanoid:Move(Vector3.zero)
			continue
		end
		-- pick the closest one it can see (or whoever just hurt it)
		local best, bestDist = nil, math.huge
		for _, c in ipairs(targets()) do
			local d = (c.HumanoidRootPart.Position - root.Position).Magnitude
			if d < bestDist and (canSee(model, c) or (brain.target == c and now - (brain.lastSeen or 0) < 5)) then best, bestDist = c, d end
		end
		if model:GetAttribute("GS_HitAt") and model:GetAttribute("GS_HitAt") ~= brain.lastHit then
			brain.lastHit = model:GetAttribute("GS_HitAt")
			brain.nextSpit = math.min(brain.nextSpit, now + 0.6) -- hurt it and it answers
		end
		if best then
			if best ~= brain.target or canSee(model, best) then brain.lastSeen = now end
			brain.target = best
			local troot = best.HumanoidRootPart
			local away = flat(root.Position - troot.Position)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
			if bestDist < 5 and now >= brain.nextClaw then
				-- too close: a claw
				brain.nextClaw = now + 1.2
				model:SetAttribute("GS_AttackServer", serverNow())
				task.delay(0.25, function()
					if alive(best) and (best.HumanoidRootPart.Position - root.Position).Magnitude < 6 then
						local svc = itemService()
						local dmg = CLAW_DAMAGE
						if svc and svc.Absorb then dmg = svc.Absorb(best, "Torso", dmg, "claw") end
						best:SetAttribute("LastDamageCause", "ACID")
						best:SetAttribute("LastDamageTime", serverNow())
						best:FindFirstChildOfClass("Humanoid"):TakeDamage(dmg)
					end
				end)
			else
				-- keep its distance, with some slack so it doesn't stop and start on the line every tick
				if brain.mode == "back" and bestDist > KEEP_MIN + 4 then brain.mode = "hold"
				elseif brain.mode == "close" and bestDist < KEEP_MAX - 5 then brain.mode = "hold"
				elseif brain.mode == "hold" and bestDist < KEEP_MIN then brain.mode = "back"
				elseif brain.mode == "hold" and bestDist > KEEP_MAX then brain.mode = "close" end
				if brain.mode == "back" then
					moveTo(model, humanoid, brain, root.Position + away * 10, 10)
				elseif brain.mode == "close" then
					moveTo(model, humanoid, brain, troot.Position + away * (KEEP_MIN + 6), 12)
				else
					humanoid:Move(Vector3.zero)
				end
			end
			face(troot.Position)
			if now >= brain.nextSpit and bestDist < 80 and canSee(model, best) then
				brain.nextSpit = now + rng:NextNumber(SPIT_COOLDOWN[1], SPIT_COOLDOWN[2])
				model:SetAttribute("GS_SpitAt", serverNow())
				fxRemote:FireAllClients("spitwindup", model)
				task.delay(0.55, function()
					if model.Parent and not model:GetAttribute("GS_Dead") and alive(best) then spit(model, best) end
				end)
			end
		else
			brain.target = nil
			freeTurn()
			wander(model, humanoid, brain)
		end
	end
	humanoid:Move(Vector3.zero)
end

control.OnInvoke = function(action, cframe)
	if action == "Spawn" then
		if typeof(cframe) ~= "CFrame" then return false, "no position" end
		local model = build(cframe)
		if not model then return false, "could not build the body" end
		task.spawn(run, model)
		return true, "C-310 spawned · class C (HIGH)"
	elseif action == "Stun" then
		return true
	end
	return false, "unknown"
end

