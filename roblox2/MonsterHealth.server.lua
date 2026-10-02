-- Creatures can finally be hurt and killed. Every creature in workspace.Monsters (with a MonsterId) gets a
-- health pool and, for the ones with arms and legs, a pool per limb:
--   hit a limb hard enough and it comes off (the head: that's the end of it); A-013's limbs grow back.
-- ServerStorage.GS_MonsterHealth:Invoke("damage", model, partName, amount, kind, attacker)
--   -> dealt, killed, severedPart, headshot
-- kinds: bullet, fire, melee, shock, trap, acid. D-130 shrugs off bullets and flares: only melee works.
-- Blood: black for everything except the spiders (green) and the spitter (acid yellow-green).
-- The clients draw the blood, the goo and the spider bursts (CombatFX).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RagdollController = require(Modules:WaitForChild("RagdollController"))

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local api = ensure(ServerStorage, "BindableFunction", "GS_MonsterHealth")
local fxRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_MonsterHit")
local gibFolder = ensure(workspace, "Folder", "GS_Gibs")

-- health per creature; limbs = hp of each limb that can come off. Bounty = cash for the kill.
local STATS = {
	["D-130"] = {hp = 200, blood = "black", immune = {bullet = true, fire = true}, bounty = 60,
		limbs = {Head = 90, ["Left Arm"] = 70, ["Right Arm"] = 70, ["Left Leg"] = 80, ["Right Leg"] = 80}},
	["B-414"] = {hp = 300, blood = "black", bounty = 80,
		limbs = {Head = 100, ["Left Arm"] = 100, ["Right Arm"] = 100, ["Left Leg"] = 100, ["Right Leg"] = 100}},
	["A-013"] = {hp = 500, blood = "black", bounty = 150, regrow = 5,
		limbs = {Head = 250, ["Left Arm"] = 120, ["Right Arm"] = 120, ["Left Leg"] = 140, ["Right Leg"] = 140}},
	["C-207"] = {hp = 400, blood = "black", bounty = 100,
		limbs = {Head = 200, ["Left Arm"] = 250, ["Right Arm"] = 250, ["Left Leg"] = 250, ["Right Leg"] = 250}},
	["E-116"] = {hp = 75, blood = "green", bounty = 15, spider = true},
	["A-116"] = {hp = 450, blood = "green", bounty = 120, spider = true, mother = true},
	["C-310"] = {hp = 180, blood = "acid", bounty = 50,
		limbs = {Head = 80, ["Left Arm"] = 60, ["Right Arm"] = 60, ["Left Leg"] = 70, ["Right Leg"] = 70}},
}
local DEFAULT = {hp = 250, blood = "black", bounty = 40}

local MOTORS = {["Left Arm"] = "Left Shoulder", ["Right Arm"] = "Right Shoulder", ["Left Leg"] = "Left Hip",
	["Right Leg"] = "Right Hip", Head = "Neck"}

local pools = {}

local function serverNow() return workspace:GetServerTimeNow() end

local function poolOf(model)
	local pool = pools[model]
	if pool then return pool end
	local id = model:GetAttribute("MonsterId")
	if not id then return nil end
	local stats = STATS[id] or DEFAULT
	pool = {stats = stats, hp = stats.hp, limbs = {}, templates = {}, damageBy = {}}
	for name, hp in pairs(stats.limbs or {}) do
		pool.limbs[name] = hp
		-- A-013 grows its limbs back: remember what they looked like
		if stats.regrow and name ~= "Head" then
			local part = model:FindFirstChild(name)
			local torso = model:FindFirstChild("Torso")
			local motor = torso and torso:FindFirstChild(MOTORS[name])
			if part and motor and motor:IsA("Motor6D") then
				local ok, copy = pcall(function()
					part.Archivable = true
					for _, d in ipairs(part:GetDescendants()) do d.Archivable = true end
					return part:Clone()
				end)
				if ok and copy then pool.templates[name] = {part = copy, c0 = motor.C0, c1 = motor.C1} end
			end
		end
	end
	pools[model] = pool
	model:SetAttribute("GS_HP", pool.hp)
	model:SetAttribute("GS_MaxHP", stats.hp)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then pools[model] = nil end
	end)
	return pool
end

local function control(...)
	local c = ServerStorage:FindFirstChild("GS_MonsterControl")
	if c then pcall(c.Invoke, c, ...) end
end

-- ===== losing a limb =====
local function sever(model, pool, name)
	local part = model:FindFirstChild(name)
	local torso = model:FindFirstChild("Torso")
	if not part or not torso then return end
	local motor = torso:FindFirstChild(MOTORS[name])
	if motor then motor:Destroy() end
	for _, w in ipairs(part:GetChildren()) do
		if w:IsA("JointInstance") or w:IsA("WeldConstraint") then w:Destroy() end
	end
	local holder = Instance.new("Model")
	holder.Name = "GS_Limb_" .. name
	-- everything welded onto the limb (veins, lumps, armor bits) comes off with it
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WeldConstraint") and (d.Part0 == part or d.Part1 == part) then
			local other = d.Part0 == part and d.Part1 or d.Part0
			if other and other ~= torso and other.Parent and other:IsDescendantOf(model) and other.Name ~= "HumanoidRootPart" then
				other.Parent = holder
			end
		end
	end
	part.Parent = holder
	part.CanCollide = true
	holder.Parent = gibFolder
	pcall(function() part:SetNetworkOwner(nil) end)
	part.AssemblyLinearVelocity = (part.Position - torso.Position).Unit * 18 + Vector3.new(0, 14, 0)
	part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
	Debris:AddItem(holder, 40)
	pool.limbs[name] = nil
	fxRemote:FireAllClients("sever", model, part.Position, pool.stats.blood, name)
	-- A-013: the stump bubbles and the limb grows back
	local template = pool.templates[name]
	if pool.stats.regrow and template then
		task.delay(pool.stats.regrow, function()
			if not model.Parent or model:GetAttribute("GS_Dead") or model:FindFirstChild(name) then return end
			local torsoNow = model:FindFirstChild("Torso")
			if not torsoNow then return end
			local newPart = template.part:Clone()
			newPart.CFrame = torsoNow.CFrame * template.c0 * template.c1:Inverse()
			newPart.Parent = model
			local newMotor = Instance.new("Motor6D")
			newMotor.Name = MOTORS[name]
			newMotor.Part0 = torsoNow
			newMotor.Part1 = newPart
			newMotor.C0 = template.c0
			newMotor.C1 = template.c1
			newMotor.Parent = torsoNow
			pool.limbs[name] = (pool.stats.limbs or {})[name] or 100
			model:SetAttribute("RigVersion", (model:GetAttribute("RigVersion") or 0) + 1)
			fxRemote:FireAllClients("regrow", model, newPart.Position, name)
		end)
	end
end

-- ===== dying =====
local function payBounty(model, pool)
	local best, bestDamage = nil, 0
	for player, dmg in pairs(pool.damageBy) do
		if player.Parent and dmg > bestDamage then best, bestDamage = player, dmg end
	end
	if not best then return end
	local economy = ServerStorage:FindFirstChild("GS_Economy")
	if economy then pcall(economy.Invoke, economy, "add", best, pool.stats.bounty or 0) end
end

local function kill(model, pool, attacker)
	if model:GetAttribute("GS_Dead") then return end
	model:SetAttribute("GS_Dead", true)
	model:SetAttribute("GS_HP", 0)
	control("Kill", model)
	payBounty(model, pool)
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then pcall(function() humanoid:Move(Vector3.zero) humanoid.WalkSpeed = 0 end) end
	if pool.stats.spider then
		-- the spider bursts: green goo everywhere, the legs are left lying about, the body flies apart
		local legs = {}
		if root then
			for _, a in ipairs(root:GetChildren()) do
				if a:IsA("Attachment") and a.Name:match("^Leg%d") then table.insert(legs, a.WorldPosition) end
			end
		end
		fxRemote:FireAllClients("spiderdeath", model, root and root.Position or model:GetPivot().Position, legs,
			model:GetAttribute("SpiderScale") or 1, pool.stats.mother == true)
		local center = root and root.Position or model:GetPivot().Position
		local pieces = Instance.new("Model")
		pieces.Name = "GS_SpiderRemains"
		pieces.Parent = gibFolder
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and p ~= root then
				for _, w in ipairs(p:GetChildren()) do
					if w:IsA("WeldConstraint") or w:IsA("JointInstance") then w:Destroy() end
				end
				p.Anchored = false
				p.CanCollide = p.Size.Magnitude > 0.6
				p.Massless = false
				p.Parent = pieces
				local dir = p.Position - center
				dir = dir.Magnitude > 0.05 and dir.Unit or Vector3.new(0, 1, 0)
				p.AssemblyLinearVelocity = dir * math.random(20, 42) + Vector3.new(0, math.random(12, 28), 0)
				p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 30
			end
		end
		Debris:AddItem(pieces, 25)
		model:Destroy()
		return
	end
	-- everything else falls down where it stood and lies there for a while
	fxRemote:FireAllClients("death", model, root and root.Position or model:GetPivot().Position, pool.stats.blood)
	local okRagdoll = pcall(function() RagdollController.Enable(model) end)
	if not okRagdoll then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") then d:Destroy() end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("AlignOrientation") then d.Enabled = false end
	end
	task.delay(30, function()
		if model.Parent then model:Destroy() end
	end)
end

-- ===== taking damage =====
local function damage(model, partName, amount, kind, attacker)
	if typeof(model) ~= "Instance" or not model.Parent or model:GetAttribute("GS_Dead") then return 0, false end
	local pool = poolOf(model)
	if not pool then return 0, false end
	amount = math.max(0, tonumber(amount) or 0)
	if pool.stats.immune and pool.stats.immune[kind] then
		local where = model:FindFirstChild(partName or "") or model:FindFirstChild("HumanoidRootPart")
		fxRemote:FireAllClients("immune", model, where and where.Position or model:GetPivot().Position)
		return 0, false
	end
	local attackerPlayer = typeof(attacker) == "Instance" and (attacker:IsA("Player") and attacker or Players:GetPlayerFromCharacter(attacker))
	if attackerPlayer then pool.damageBy[attackerPlayer] = (pool.damageBy[attackerPlayer] or 0) + amount end
	local part = model:FindFirstChild(partName or "")
	if not part or not part:IsA("BasePart") then part = model:FindFirstChild("HumanoidRootPart") end
	local name = part and part.Name or "Torso"
	if name == "HumanoidRootPart" then name = "Torso" end
	local headshot = name == "Head"
	pool.hp -= amount
	model:SetAttribute("GS_HP", math.max(0, math.floor(pool.hp)))
	model:SetAttribute("GS_HitAt", serverNow())
	fxRemote:FireAllClients("hit", model, part and part.Position or model:GetPivot().Position, pool.stats.blood, amount, name)
	local severed = nil
	if pool.limbs[name] then
		pool.limbs[name] -= amount
		if pool.limbs[name] <= 0 then
			if name == "Head" then
				sever(model, pool, name)
				kill(model, pool, attacker)
				return amount, true, name, true
			end
			sever(model, pool, name)
			severed = name
		end
	end
	if pool.hp <= 0 then
		kill(model, pool, attacker)
		return amount, true, severed, headshot
	end
	-- let the creature know who is hurting it
	if attackerPlayer and attackerPlayer.Character then control("Struck", model, attackerPlayer.Character) end
	return amount, false, severed, headshot
end

api.OnInvoke = function(action, ...)
	if action == "damage" then
		return damage(...)
	elseif action == "hp" then
		local model = ...
		local pool = poolOf(model)
		return pool and pool.hp or 0, pool and pool.stats.hp or 0
	end
	return false
end

-- give every creature its pool as soon as it appears (so the clients can show the bar right away)
task.spawn(function()
	local folder = workspace:WaitForChild("Monsters", 120)
	if not folder then return end
	local function onModel(model)
		if not model:IsA("Model") then return end
		task.wait(0.5)
		if model.Parent and model:GetAttribute("MonsterId") then poolOf(model) end
	end
	for _, m in ipairs(folder:GetChildren()) do task.spawn(onModel, m) end
	folder.ChildAdded:Connect(onModel)
end)
