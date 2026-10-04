local Players = game:GetService("Players")
local function isNpc(x)
	return type(x) == "table" and x.IsNpc == true
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))

local ADMINS = {
	[1666069865] = "Owner",
}

local function isAdmin(player)
	return ADMINS[player.UserId] ~= nil
end

local remote = ReplicatedStorage:FindFirstChild("AdminAction")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "AdminAction"
	remote.Parent = ReplicatedStorage
end

local PARTS = {Head = true, Torso = true, RightArm = true, LeftArm = true, RightLeg = true, LeftLeg = true}

local function reply(player, ok, message)
	remote:FireClient(player, ok and "ok" or "error", message)
end

local npcRegistry = ReplicatedStorage:FindFirstChild("NPCs")
if not npcRegistry then
	npcRegistry = Instance.new("Folder")
	npcRegistry.Name = "NPCs"
	npcRegistry.Parent = ReplicatedStorage
end
local npcFolder = workspace:FindFirstChild("NPCs")
if not npcFolder then
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "NPCs"
	npcFolder.Parent = workspace
end

local NPC_NAMES = {
	"Jacob", "Ethan", "Mason", "Walter", "Arthur", "Victor", "Ivan", "Dmitri", "Oleg", "Henry",
	"Anna", "Maria", "Sofia", "Emma", "Olga", "Clara", "Martha", "Nikolai", "Leon", "Harold",
}
local NPC_ANIMS = {
	idle = {"rbxassetid://180435571", true, Enum.AnimationPriority.Idle},
	walk = {"rbxassetid://180426354", true, Enum.AnimationPriority.Movement},
	jump = {"rbxassetid://125750702", false, Enum.AnimationPriority.Movement},
	fall = {"rbxassetid://180436148", true, Enum.AnimationPriority.Movement},
	climb = {"rbxassetid://180436334", true, Enum.AnimationPriority.Movement},
}
local NPC_WALK_SPEED = 16
local LEG_SPEED = {OneDamaged = 0.85, BothDamaged = 0.75, OneBroken = 0.6, BrokenAndDamaged = 0.5}
local npcs = {}
local nextNpcId = -1

local function buildNpc(entry)
	entry.tracks = nil
	entry.current = nil
	entry.goal = nil
	entry.downUntil = nil
	local desc = Instance.new("HumanoidDescription")
	local grey = Color3.fromRGB(163, 162, 165)
	desc.HeadColor, desc.TorsoColor = grey, grey
	desc.LeftArmColor, desc.RightArmColor = grey, grey
	desc.LeftLegColor, desc.RightLegColor = grey, grey
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then return nil, "could not build rig" end
	model.Name = "NPC_" .. tostring(-entry.id)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") then d:Destroy() end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then model:Destroy() return nil, "bad rig" end
	humanoid.DisplayName = entry.name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model:SetAttribute("NpcId", entry.id)
	model:SetAttribute("DisplayName", entry.name)
	model:PivotTo(entry.cframe)
	model.Parent = npcFolder
	pcall(function() root:SetNetworkOwner(nil) end)
	entry.model = model
	entry.config:SetAttribute("Alive", true)
	task.spawn(FallDamageController.Setup, model)
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	entry.tracks = true
	entry.home = root.Position
	entry.nextThink = os.clock() + 3.5 + math.random() * 3
	entry.stuckTime = 0
	entry.nextWince = os.clock() + 5
	humanoid.Died:Connect(function()
		if entry.model == model then
			entry.config:SetAttribute("Alive", false)
			local r = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
			if r then entry.cframe = CFrame.new(r.Position + Vector3.new(0, 3, 0)) end
		end
	end)
	return model
end

local function createNpc(name, cframe)
	local id = nextNpcId
	nextNpcId -= 1
	if typeof(name) ~= "string" or name:gsub("%s", "") == "" then
		name = NPC_NAMES[math.random(1, #NPC_NAMES)]
	end
	name = name:sub(1, 24)
	local config = Instance.new("Configuration")
	config.Name = tostring(-id)
	config:SetAttribute("Id", id)
	config:SetAttribute("DisplayName", name)
	config:SetAttribute("Alive", false)
	config.Parent = npcRegistry
	local entry = {id = id, name = name, cframe = cframe, config = config}
	npcs[id] = entry
	local model, err = buildNpc(entry)
	if not model then
		config:Destroy()
		npcs[id] = nil
		return nil, err
	end
	return entry
end

local function deleteNpc(entry)
	if entry.model and entry.model.Parent then entry.model:Destroy() end
	entry.config:Destroy()
	npcs[entry.id] = nil
end

local function getTarget(targetUserId)
	if typeof(targetUserId) ~= "number" then return nil end
	if targetUserId < 0 then
		local entry = npcs[targetUserId]
		if not entry then return nil end
		local character = entry.model and entry.model.Parent and entry.model or nil
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local target = {DisplayName = entry.name, UserId = entry.id, IsNpc = true, Entry = entry}
		return target, character, humanoid
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then return nil end
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return target, character, humanoid
end

local ACTIONS = {}

ACTIONS.SetInjury = function(admin, target, character, humanoid, part, level)
	if not character or not humanoid or humanoid.Health <= 0 then return false, "target has no living character" end
	if not PARTS[part] or typeof(level) ~= "number" then return false, "bad part" end
	level = math.clamp(math.floor(level), 0, 3)
	if part == "Torso" and level == 3 then level = 2 end
	local current = character:GetAttribute("Injury_" .. part) or 0
	if current >= 3 and level < 3 then return false, "can't reattach a severed part — respawn the player" end
	character:SetAttribute("Injury_" .. part, level)
	local names = {[0] = "healed", "damaged", "broken", "severed"}
	return true, string.format("%s: %s %s", target.DisplayName, part, names[level])
end

ACTIONS.HealAll = function(admin, target, character, humanoid)
	if not character or not humanoid or humanoid.Health <= 0 then return false, "target has no living character" end
	for part in pairs(PARTS) do
		if (character:GetAttribute("Injury_" .. part) or 0) < 3 then
			character:SetAttribute("Injury_" .. part, 0)
		end
	end
	humanoid.Health = humanoid.MaxHealth
	FallDamageController.StopBleeding(character)
	return true, target.DisplayName .. " healed"
end

ACTIONS.Damage = function(admin, target, character, humanoid, amount)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	amount = typeof(amount) == "number" and math.clamp(amount, 1, 1000) or 25
	humanoid:TakeDamage(amount)
	return true, string.format("%s took %d damage", target.DisplayName, amount)
end

ACTIONS.Bleed = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	FallDamageController.AddBleeding(character, 1, 30)
	return true, target.DisplayName .. " is bleeding"
end

ACTIONS.Kill = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is already dead" end
	humanoid.Health = 0
	return true, target.DisplayName .. " killed"
end

ACTIONS.Gib = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is already dead" end
	character:SetAttribute("Gibbed", true)
	character:SetAttribute("LastDamageCause", "FALL")
	character:SetAttribute("LastDamageTime", workspace:GetServerTimeNow())
	humanoid.Health = 0
	return true, target.DisplayName .. " torn apart"
end

ACTIONS.ExplodePart = function(admin, target, character, humanoid, part)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	if not PARTS[part] then return false, "bad part" end
	local ok, err = FallDamageController.ExplodePart(character, part)
	if not ok then return false, err or "failed" end
	return true, string.format("%s: %s exploded", target.DisplayName, part)
end

ACTIONS.RestorePart = function(admin, target, character, humanoid, part)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	if not PARTS[part] then return false, "bad part" end
	local ok, err = FallDamageController.RestorePart(character, part)
	if not ok then return false, err or "failed" end
	return true, string.format("%s: %s restored", target.DisplayName, part)
end

ACTIONS.Lobotomy = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	local value = not character:GetAttribute("Lobotomized")
	character:SetAttribute("Lobotomized", value)
	return true, target.DisplayName .. (value and " lobotomized" or ": lobotomy removed")
end

ACTIONS.NpcAI = function(admin, target)
	if not isNpc(target) then return false, "not an npc" end
	local entry = target.Entry
	entry.aiOff = not entry.aiOff
	entry.config:SetAttribute("AI", not entry.aiOff)
	if entry.aiOff and entry.model and entry.model.Parent then
		local humanoid = entry.model:FindFirstChildOfClass("Humanoid")
		local root = entry.model:FindFirstChild("HumanoidRootPart")
		if humanoid and root then humanoid:MoveTo(root.Position) end
		entry.goal = nil
	end
	return true, entry.name .. (entry.aiOff and ": AI off" or ": AI on")
end

ACTIONS.HeadPop = function(admin, target, character, humanoid)
	if not humanoid or humanoid.Health <= 0 then return false, "target is already dead" end
	if not FallDamageController.ExplodeHead(character) then return false, "no head" end
	return true, target.DisplayName .. "'s head exploded"
end

ACTIONS.Weather = function(admin, _, _, _, kind)
	local allowed = {Clear = true, Rain = true, Storm = true, Wind = true, Fog = true}
	if not allowed[kind] then return false, "bad weather" end
	workspace:SetAttribute("WeatherLock", os.clock())
	workspace:SetAttribute("Weather", kind)
	return true, "weather: " .. kind
end

ACTIONS.Ragdoll = function(admin, target, character, humanoid, duration)
	if not humanoid or humanoid.Health <= 0 then return false, "target is dead" end
	duration = typeof(duration) == "number" and math.clamp(duration, 0.5, 60) or 3
	FallDamageController.Ragdoll(character, duration, 0.4)
	return true, string.format("%s ragdolled for %ds", target.DisplayName, duration)
end

ACTIONS.Respawn = function(admin, target)
	if isNpc(target) then
		local entry = target.Entry
		if entry.model and entry.model.Parent then entry.model:Destroy() end
		local model, err = buildNpc(entry)
		if not model then return false, err end
		return true, entry.name .. " respawned"
	end
	target:LoadCharacter()
	return true, target.DisplayName .. " respawned"
end

ACTIONS.NpcCreate = function(admin, _, _, _, name)
	local character = admin.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local cframe = root and (root.CFrame * CFrame.new(0, 0, -6)) or CFrame.new(0, 10, 0)
	cframe = CFrame.new(cframe.Position) * CFrame.Angles(0, math.atan2(-(root and root.CFrame.LookVector.X or 0), -(root and root.CFrame.LookVector.Z or 1)) + math.pi, 0)
	local entry, err = createNpc(name, cframe)
	if not entry then return false, err end
	return true, "npc created: " .. entry.name
end

ACTIONS.NpcDelete = function(admin, target)
	if not isNpc(target) then return false, "not an npc" end
	deleteNpc(target.Entry)
	return true, target.DisplayName .. " deleted"
end

ACTIONS.Night = function(admin, _, _, _, enabled)
	workspace:SetAttribute("Night", enabled == true)
	return true, enabled and "night started" or "night ended"
end

local ServerStorage = game:GetService("ServerStorage")
local function monsterControl(...)
	local control = ServerStorage:FindFirstChild("GS_MonsterControl") or ServerStorage:WaitForChild("GS_MonsterControl", 5)
	if not control then return false, "monster system is not running" end
	return control:Invoke(...)
end

ACTIONS.MonsterSpawn = function(admin, _, _, _, id, whereUserId)
	if typeof(id) ~= "string" then return false, "no object selected" end
	local anchorCharacter = admin.Character
	if typeof(whereUserId) == "number" and whereUserId ~= 0 then
		local _, character = getTarget(whereUserId)
		anchorCharacter = character or anchorCharacter
	end
	local root = anchorCharacter and anchorCharacter:FindFirstChild("HumanoidRootPart")
	if not root then return false, "no position (spawn your character first)" end
	return monsterControl("Spawn", id, root.Position)
end

ACTIONS.MonsterClear = function()
	return monsterControl("Clear")
end

ACTIONS.TrailView = function(admin)
	local ok, points = monsterControl("Trail")
	if not ok then return false, points end
	local fx = ReplicatedStorage:FindFirstChild("MonsterFX")
	if fx then fx:FireClient(admin, nil, "Trail", points) end
	return true, string.format("blood trail: %d points (shown for 15s)", #points)
end

-- infection: 1-3 = that stage (turns them on the spot if they're human), 0 = cure
ACTIONS.Infect = function(admin, target, character, humanoid, stage)
	if isNpc(target) then return false, "npcs can't be infected" end
	return monsterControl("SetInfection", target, stage)
end

-- the supply depot: open = true raises it, false sends it back under (ShopServer does the work)
ACTIONS.Shop = function(admin, _, _, _, open)
	local control = game:GetService("ServerStorage"):FindFirstChild("GS_ShopControl")
	if not control then return false, "no shop in this place" end
	return control:Invoke(open == true)
end

-- money (Economy script): a positive amount gives, a negative one takes
ACTIONS.Cash = function(admin, target, character, humanoid, amount)
	if isNpc(target) then return false, "npcs have no money" end
	local economy = game:GetService("ServerStorage"):FindFirstChild("GS_Economy")
	if not economy then return false, "no economy" end
	if typeof(amount) ~= "number" or amount ~= amount or amount == 0 or math.abs(amount) > 1000000 then return false, "bad amount" end
	amount = math.floor(amount)
	local ok, cash = economy:Invoke("add", target, amount)
	if not ok then return false, tostring(cash) end
	return true, string.format("%s  %s$%d  -  now $%d", target.DisplayName, amount >= 0 and "+" or "-", math.abs(amount), cash)
end

-- items (Inventory script): give any item or the whole SCG set, empty a bag
local function itemAdmin(...)
	local api = game:GetService("ServerStorage"):FindFirstChild("GS_ItemAdmin")
	if not api then return false, "the Inventory script is not running" end
	return api:Invoke(...)
end
ACTIONS.GiveItem = function(admin, target, character, humanoid, itemId, amount)
	if isNpc(target) then return false, "npcs don't carry things" end
	if typeof(itemId) ~= "string" then return false, "no item" end
	return itemAdmin("give", target, itemId, amount)
end
ACTIONS.ClearBag = function(admin, target)
	if isNpc(target) then return false, "npcs don't carry things" end
	return itemAdmin("clear", target)
end
ACTIONS.Pvp = function(admin, _, _, _, enabled)
	return itemAdmin("pvp", enabled == true)
end

local WORLD_ACTIONS = {Night = true, Weather = true, NpcCreate = true, MonsterSpawn = true, MonsterClear = true, TrailView = true, Shop = true, Pvp = true}
local lastUse = {}

remote.OnServerEvent:Connect(function(player, action, targetUserId, a, b)
	if not isAdmin(player) then return end
	local now = os.clock()
	if now - (lastUse[player] or 0) < 0.15 then return end
	lastUse[player] = now
	local handler = typeof(action) == "string" and ACTIONS[action]
	if not handler then return reply(player, false, "unknown action") end
	local target, character, humanoid
	if not WORLD_ACTIONS[action] then
		target, character, humanoid = getTarget(targetUserId)
		if not target then return reply(player, false, "player not found") end
	end
	local ok, result, message = pcall(handler, player, target, character, humanoid, a, b)
	if not ok then
		reply(player, false, "error: " .. tostring(result))
	else
		reply(player, result, message)
	end
end)

local function onPlayer(player)
	if isAdmin(player) then
		player:SetAttribute("IsAdmin", true)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
Players.PlayerRemoving:Connect(function(player) lastUse[player] = nil end)

local resetRemote = ReplicatedStorage:FindFirstChild("ResetRequest")
if not resetRemote then
	resetRemote = Instance.new("RemoteEvent")
	resetRemote.Name = "ResetRequest"
	resetRemote.Parent = ReplicatedStorage
end
local lastReset = {}
resetRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastReset[player] or 0) < 2 then return end
	lastReset[player] = now
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if not FallDamageController.ExplodeHead(character) then
		humanoid.Health = 0
	end
end)
Players.PlayerRemoving:Connect(function(player) lastReset[player] = nil end)

local RunService = game:GetService("RunService")
local npcParams = RaycastParams.new()
npcParams.FilterType = Enum.RaycastFilterType.Exclude

local function playTrack() end
local function stopTracks() end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, entry in pairs(npcs) do
		local model = entry.model
		local humanoid = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
		local root = model and model.Parent and model:FindFirstChild("HumanoidRootPart")
		if humanoid and root and entry.tracks and humanoid.Health > 0 then
			if model:GetAttribute("Ragdolled") then
				stopTracks(entry)
				humanoid:Move(Vector3.zero)
			else
				local r = model:GetAttribute("Injury_RightLeg") or 0
				local l = model:GetAttribute("Injury_LeftLeg") or 0
				local hi, lo = math.max(r, l), math.min(r, l)
				local mult = 1
				local cantWalk = hi >= 3 or (r >= 2 and l >= 2)
				if hi == 2 then mult = lo == 1 and LEG_SPEED.BrokenAndDamaged or LEG_SPEED.OneBroken
				elseif hi == 1 then mult = lo == 1 and LEG_SPEED.BothDamaged or LEG_SPEED.OneDamaged end
				local bleeding = model:GetAttribute("Bleeding") or 0
				mult *= math.clamp(1 - bleeding * 0.2, 0.6, 1)
				if entry.flinchUntil and now < entry.flinchUntil then mult *= 0.15 end
				humanoid.WalkSpeed = cantWalk and NPC_WALK_SPEED * 0.2 or NPC_WALK_SPEED * mult
				humanoid.JumpPower = cantWalk and 0 or 50 * math.sqrt(mult)
				local moving = root.AssemblyLinearVelocity.Magnitude > 2
				if hi >= 1 and hi < 3 and moving and now > entry.nextWince then
					entry.nextWince = now + (hi == 2 and (4 + math.random() * 5) or (10 + math.random() * 8))
					entry.flinchUntil = now + (hi == 2 and 0.9 or 0.4)
					model:SetAttribute("Wince", (hi == 2 and 1 or 0.4) + math.random() * 0.01)
				end
				if entry.aiOff then
					entry.goal = nil
				else
					if now >= entry.nextThink then
						entry.nextThink = now + 3 + math.random() * 7
						if math.random() < 0.35 then
							entry.goal = nil
							humanoid:Move(Vector3.zero)
						else
							local angle = math.random() * math.pi * 2
							local dist = 6 + math.random() * 22
							local target = entry.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
							npcParams.FilterDescendantsInstances = {model}
							local hit = workspace:Raycast(target + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), npcParams)
							if hit then
								entry.goal = hit.Position
								humanoid:MoveTo(hit.Position)
							end
						end
					end
					if entry.goal and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(entry.goal.X, 0, entry.goal.Z)).Magnitude < 2 then
						entry.goal = nil
					end
				end
				local velocity = root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if entry.goal and humanoid.WalkSpeed > 0 then
					if speed < 0.6 then
						entry.stuckTime += dt
						if entry.stuckTime > 0.8 then
							humanoid.Jump = true
							entry.stuckTime = 0
						end
					else
						entry.stuckTime = 0
					end
				end
				local state = humanoid:GetState()
				if state == Enum.HumanoidStateType.Jumping then
					playTrack(entry, "jump")
				elseif state == Enum.HumanoidStateType.Freefall then
					playTrack(entry, "fall")
				elseif state == Enum.HumanoidStateType.Climbing then
					playTrack(entry, "climb", math.clamp(math.abs(velocity.Y) / 8, 0.1, 2))
				elseif speed > 0.8 then
					playTrack(entry, "walk", math.clamp(speed / 14.5, 0.3, 1.6))
				else
					playTrack(entry, "idle")
				end
			end
		end
	end
end)

task.spawn(function()
	local desc = Instance.new("HumanoidDescription")
	local black = Color3.fromRGB(8, 8, 10)
	desc.HeadColor, desc.TorsoColor = black, black
	desc.LeftArmColor, desc.RightArmColor = black, black
	desc.LeftLegColor, desc.RightLegColor = black, black
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("shadow template failed: " .. tostring(model))
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Decal") or d:IsA("Clothing") or d:IsA("Accessory") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Color = black
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = humanoid end
	end
	local head = model:FindFirstChild("Head")
	if head then
		for _, x in ipairs({-0.22, 0.22}) do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Size = Vector3.new(0.14, 0.06, 0.05)
			eye.Material = Enum.Material.Neon
			eye.Color = Color3.fromRGB(235, 225, 215)
			eye.CanCollide, eye.CanQuery, eye.CanTouch, eye.CastShadow, eye.Massless = false, false, false, false, true
			eye.CFrame = head.CFrame * CFrame.new(x, 0.12, -head.Size.Z / 2 - 0.01)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = eye
			weld.Parent = eye
			eye.Parent = head
		end
	end
	model.Name = "GS_ShadowTemplate"
	model.Parent = ReplicatedStorage
end)

local hauntRemote = ReplicatedStorage:FindFirstChild("HauntEvent")
if not hauntRemote then
	hauntRemote = Instance.new("RemoteEvent")
	hauntRemote.Name = "HauntEvent"
	hauntRemote.Parent = ReplicatedStorage
end
local lastHaunt = {}
local HAUNT_LIMBS = {RightArm = true, LeftArm = true, RightLeg = true, LeftLeg = true, Head = true}
hauntRemote.OnServerEvent:Connect(function(player, kind, arg)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not character:GetAttribute("Lobotomized") then return end
	local now = os.clock()
	if now - (lastHaunt[player] or 0) < 0.6 then return end
	lastHaunt[player] = now
	if kind == "Hit" then
		if typeof(arg) ~= "string" or not HAUNT_LIMBS[arg] then return end
		local level = character:GetAttribute("Injury_" .. arg) or 0
		if level >= 3 then return end
		character:SetAttribute("LastDamageCause", "HAUNTED")
		character:SetAttribute("LastDamageTime", workspace:GetServerTimeNow())
		humanoid:TakeDamage(4 + (level + 1) * 3)
		if humanoid.Health <= 0 then
			character:SetAttribute("DeathCause", "HAUNTED")
			return
		end
		if level + 1 >= 3 and arg == "Head" then
			character:SetAttribute("DeathCause", "HAUNTED")
		end
		FallDamageController.Injure(character, arg, level + 1)
	elseif kind == "Eat" then
		if typeof(arg) ~= "Instance" then return end
		local folder = workspace:FindFirstChild("SeveredLimbs")
		if not folder or not arg:IsDescendantOf(folder) then return end
		local model = arg:IsA("Model") and arg or arg:FindFirstAncestorOfClass("Model")
		if not model or model.Parent ~= folder then return end
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("BasePart") and d:GetAttribute("SeveredFrom") == character.Name then
				model:Destroy()
				return
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(player) lastHaunt[player] = nil end)
