-- Guns and melee, decided on the server. The client (WeaponClient) shows the shot at once; the server
-- replays it from the same seed (ItemData.Pellets), so the pellets that do damage are the ones you saw.
--   fire   (uid, origin CFrame, seed, aiming)   - ammo, fire rate, spread and range are checked here
--   reload (uid)                                - loads from the bag's ammo, shell by shell for pump guns
--   swing  (uid, look direction)                - melee: the closest thing in front, on the closest limb
-- Damage to creatures goes through ServerStorage.GS_MonsterHealth, to people through their armor first.
-- People only hurt people when PvP is on (admin panel) - the infected can always be hurt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Svc = require(ServerStorage:WaitForChild("GS_ItemService"))
local FallDamageController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FallDamageController"))
local ItemData = Svc.ItemData

local remote = ReplicatedStorage:FindFirstChild("GS_Weapon")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GS_Weapon"
	remote.Parent = ReplicatedStorage
end

local LIMB = {
	Head = "Head", Torso = "Torso", HumanoidRootPart = "Torso",
	["Left Arm"] = "LeftArm", ["Right Arm"] = "RightArm", ["Left Leg"] = "LeftLeg", ["Right Leg"] = "RightLeg",
}

local function serverNow() return workspace:GetServerTimeNow() end

local function monsterApi(...)
	local api = ServerStorage:FindFirstChild("GS_MonsterHealth")
	if not api then return 0, false end
	local ok, dealt, killed, severed, head = pcall(api.Invoke, api, ...)
	if not ok then return 0, false end
	return dealt or 0, killed, severed, head
end

local function monsterControl(...)
	local control = ServerStorage:FindFirstChild("GS_MonsterControl")
	if control then pcall(control.Invoke, control, ...) end
end

-- a loud noise every monster can hear (Monsters' hearing system)
local function noise(character, radius)
	monsterControl("Noise", character, radius, 1.5)
end

-- the model a hit part belongs to, and what kind of thing it is
local function classify(part)
	local monsters = workspace:FindFirstChild("Monsters")
	local npcs = workspace:FindFirstChild("NPCs")
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model.Parent == monsters then
			if model:GetAttribute("MonsterId") and not model:GetAttribute("GS_Dead") then return model, "monster" end
			return nil
		end
		if model.Parent == npcs then return model, "npc" end
		if Players:GetPlayerFromCharacter(model) then return model, "player" end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function canHurtPerson(attacker, victim)
	if victim == attacker then return false end
	if victim:GetAttribute("Infected") then return true end
	if attacker:GetAttribute("Infected") then return true end
	return Svc.PvP()
end

-- a person (player or npc) hit on one body part
local function hurtPerson(attackerPlayer, victim, partKey, damage, cause, opts)
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	local dealt, blocked = Svc.Absorb(victim, partKey, damage, opts and opts.type or "bullet")
	victim:SetAttribute("LastDamageCause", cause)
	victim:SetAttribute("LastDamageTime", serverNow())
	humanoid:TakeDamage(dealt)
	if humanoid.Health <= 0 then
		victim:SetAttribute("DeathCause", cause)
		return true
	end
	-- a heavy hit breaks something, unless the armor took it
	if not blocked and dealt >= (opts and opts.woundAt or 18) and partKey ~= "Torso" then
		local level = victim:GetAttribute("Injury_" .. partKey) or 0
		if level < 2 then FallDamageController.Injure(victim, partKey, level + 1) end
	end
	if opts and opts.bleed then FallDamageController.AddBleeding(victim, 0.35, 10) end
	if opts and opts.stun then
		FallDamageController.Ragdoll(victim, opts.stun * 0.7, 0.2)
		victim:SetAttribute("GS_Shocked", serverNow())
	end
	return false
end

-- ===== guns =====
local lastShot = {}
local reloading = {}

local function worldParams(shooter)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {shooter}
	for _, name in ipairs({"GS_Items", "GS_Traps", "SpiderWebs", "GS_Hallucinations", "PS_Blood", "GS_Tentacles", "GS_FX"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(ignore, f) end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function burn(model, attacker, seconds)
	if model:GetAttribute("GS_Burning") then return end
	model:SetAttribute("GS_Burning", serverNow() + seconds)
	task.spawn(function()
		for _ = 1, seconds do
			task.wait(1)
			if not model.Parent or model:GetAttribute("GS_Dead") then break end
			monsterApi("damage", model, "Torso", 7, "fire", attacker)
		end
		if model.Parent then model:SetAttribute("GS_Burning", nil) end
	end)
end

local function fire(player, uid, origin, seed, aiming)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not head or not root then return end
	if character:GetAttribute("Ragdolled") or character:GetAttribute("Infected") then return end
	if typeof(origin) ~= "CFrame" or typeof(seed) ~= "number" then return end
	local entry, item = Svc.Held(player)
	if not entry or entry.uid ~= uid or item.kind ~= "gun" then return end
	local now = os.clock()
	if now - (lastShot[player] or 0) < 60 / item.rpm * 0.85 then return end
	if (entry.ammo or 0) <= 0 then return end
	-- the shot must come from about where the head is
	if (origin.Position - head.Position).Magnitude > 14 then return end
	lastShot[player] = now
	reloading[player] = nil
	entry.ammo -= 1
	Svc.Sync(player)

	local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 3
	local spread = (aiming and item.aimSpread or item.spread) * (moving and 1.3 or 1)
	local startPos = origin.Position
	local look = CFrame.lookAt(startPos, startPos + origin.LookVector)
	local params = worldParams(character)
	local ends = {}
	local hits = {} -- model -> {damage, part}
	for _, dir in ipairs(ItemData.Pellets(item, look, seed, spread)) do
		local result = workspace:Raycast(startPos, dir * item.range, params)
		local hitPos = result and result.Position or (startPos + dir * item.range)
		table.insert(ends, hitPos)
		if result then
			local model, kind = classify(result.Instance)
			if model then
				local dist = (hitPos - startPos).Magnitude
				local falloff = math.clamp(1 - math.max(0, dist - 18) / item.range, 0.35, 1)
				local h = hits[model] or {kind = kind, damage = 0, parts = {}, point = hitPos}
				local partName = result.Instance.Name
				local dmg = item.damage * falloff * (partName == "Head" and (item.headMult or 1) or 1)
				h.damage += dmg
				h.parts[partName] = (h.parts[partName] or 0) + dmg
				hits[model] = h
			end
		end
	end
	remote:FireAllClients("shot", character, item.id, startPos, ends)
	noise(character, item.fire and 110 or 160)

	local report = {}
	for model, h in pairs(hits) do
		-- the body part that took the most pellets gets the whole volley
		local bestPart, bestDmg = "Torso", 0
		for name, d in pairs(h.parts) do
			if d > bestDmg then bestPart, bestDmg = name, d end
		end
		if h.kind == "monster" then
			local dealt, killed, _, headshot = monsterApi("damage", model, bestPart, h.damage, item.fire and "fire" or "bullet", player)
			if dealt > 0 then
				table.insert(report, {killed and "kill" or (headshot and "head" or "hit"), math.floor(dealt)})
				if item.knockback then
					local mroot = model:FindFirstChild("HumanoidRootPart")
					if mroot then
						local push = (mroot.Position - startPos)
						push = Vector3.new(push.X, 0, push.Z)
						if push.Magnitude > 0.1 then
							mroot.AssemblyLinearVelocity += push.Unit * item.knockback * math.clamp(h.damage / 60, 0.3, 1)
						end
					end
				end
				if item.fire then burn(model, player, 5) end
			else
				table.insert(report, {"immune", 0})
			end
		elseif canHurtPerson(character, model) then
			local killed = hurtPerson(player, model, LIMB[bestPart] or "Torso", h.damage, "SHOT", {woundAt = 22})
			table.insert(report, {killed and "kill" or "hit", math.floor(h.damage)})
		end
	end
	if #report > 0 then remote:FireClient(player, "hits", report) end
end

local function reload(player, uid)
	local entry, item = Svc.Held(player)
	if not entry or entry.uid ~= uid or item.kind ~= "gun" then return end
	if reloading[player] then return end
	if (entry.ammo or 0) >= item.magazine then return end
	if Svc.CountOf(player, item.ammo) <= 0 then
		remote:FireClient(player, "noammo", item.ammo)
		return
	end
	local token = {}
	reloading[player] = token
	local character = player.Character
	remote:FireAllClients("reload", character, item.id, item.reloadPerShell and "shell" or "full")
	task.spawn(function()
		while reloading[player] == token do
			task.wait(item.reload)
			local e, it = Svc.Held(player)
			if reloading[player] ~= token or not e or e.uid ~= uid or not it then break end
			local need = item.magazine - (e.ammo or 0)
			if need <= 0 then break end
			local take = item.reloadPerShell and 1 or need
			local got = Svc.TakeId(player, item.ammo, take)
			if got <= 0 then break end
			e.ammo = (e.ammo or 0) + got
			Svc.Sync(player)
			if item.reloadPerShell then
				remote:FireAllClients("shellin", character, item.id)
			else
				break
			end
			if (e.ammo or 0) >= item.magazine then break end
		end
		if reloading[player] == token then reloading[player] = nil end
		remote:FireAllClients("reloaded", character, item.id)
	end)
end

-- ===== melee =====
local lastSwing = {}
local swingParams = OverlapParams.new()
swingParams.FilterType = Enum.RaycastFilterType.Exclude

local function swing(player, uid, look)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or character:GetAttribute("Ragdolled") then return end
	local entry, item = Svc.Held(player)
	if not entry or entry.uid ~= uid or item.kind ~= "melee" then return end
	local now = os.clock()
	if now - (lastSwing[player] or 0) < item.cooldown * 0.85 then return end
	lastSwing[player] = now
	if typeof(look) ~= "Vector3" or look.Magnitude < 0.1 then look = root.CFrame.LookVector end
	look = look.Unit
	remote:FireAllClients("swing", character, item.id)
	noise(character, 35)
	task.wait(0.18) -- the swing lands a moment after it starts
	if not character.Parent or humanoid.Health <= 0 then return end
	local center = root.Position + Vector3.new(0, 0.8, 0) + look * (item.reach * 0.55)
	swingParams.FilterDescendantsInstances = {character}
	local best, bestKind, bestPart, bestScore = nil, nil, nil, math.huge
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, item.reach * 0.6, swingParams)) do
		local model, kind = classify(part)
		if model and model ~= character then
			local offset = part.Position - root.Position
			local flatOff = Vector3.new(offset.X, 0, offset.Z)
			local dot = flatOff.Magnitude > 0.1 and flatOff.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) or 1
			if dot > 0.2 and offset.Magnitude <= item.reach + 1 then
				local score = (part.Position - center).Magnitude
				if score < bestScore and (LIMB[part.Name] or kind == "monster") then
					best, bestKind, bestPart, bestScore = model, kind, part, score
				end
			end
		end
	end
	if not best then return end
	local report
	if bestKind == "monster" then
		local dealt, killed, _, headshot = monsterApi("damage", best, bestPart.Name, item.damage * (item.limbMult or 1),
			item.stun and "shock" or "melee", player)
		report = {killed and "kill" or (headshot and "head" or "hit"), math.floor(dealt)}
		if item.stun and dealt > 0 then monsterControl("Stun", best, item.stun) end
		monsterControl("Struck", best, character)
	elseif canHurtPerson(character, best) then
		local killed = hurtPerson(player, best, LIMB[bestPart.Name] or "Torso", item.damage, "BEATEN",
			{type = "melee", bleed = item.bleed, stun = item.stun, woundAt = 20})
		report = {killed and "kill" or "hit", item.damage}
	end
	remote:FireAllClients("impact", best, bestPart.Position, item.id)
	if report then remote:FireClient(player, "hits", {report}) end
end

-- ===== requests =====
remote.OnServerEvent:Connect(function(player, action, uid, a, b, c)
	if typeof(uid) ~= "string" then return end
	if action == "fire" then
		fire(player, uid, a, b, c == true)
	elseif action == "reload" then
		reload(player, uid)
	elseif action == "swing" then
		swing(player, uid, a)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastShot[player], reloading[player], lastSwing[player] = nil, nil, nil
end)
