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
	if opts and opts.bleed and dealt > 0 then FallDamageController.AddBleeding(victim, 0.35, 10) end
	if opts and opts.stun and dealt > 0 then
		FallDamageController.Ragdoll(victim, opts.stun * 0.7, 0.2)
		victim:SetAttribute("GS_Shocked", serverNow())
	end
	return false
end

-- ===== guns =====
local lastShot = {}
local reloading = {}

local worldParams
function worldParams(shooter)
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
 local untilTime=serverNow()+seconds
 if (model:GetAttribute("GS_Burning") or 0)>serverNow() then
  model:SetAttribute("GS_Burning",math.max(model:GetAttribute("GS_Burning"),untilTime))
  return
 end
 model:SetAttribute("GS_Burning",untilTime)
 task.spawn(function()
  while model.Parent and not model:GetAttribute("GS_Dead") and serverNow()<(model:GetAttribute("GS_Burning") or 0) do
   task.wait(0.5)
   if not model.Parent or model:GetAttribute("GS_Dead") then break end
   monsterApi("damage",model,"Torso",4,"fire",attacker)
  end
  if model.Parent then model:SetAttribute("GS_Burning",nil) end
 end)
end

-- a flare shell burning where it landed: light, smoke, and anything standing in it catches fire
local function setAlight(character, attacker, seconds)
	if (character:GetAttribute("GS_OnFire") or 0)>serverNow() then
 character:SetAttribute("GS_OnFire",math.max(character:GetAttribute("GS_OnFire"),serverNow()+seconds))
 return end

	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not torso or not humanoid then return end
	character:SetAttribute("GS_OnFire", serverNow() + seconds)
	task.spawn(function()
		while serverNow() < (character:GetAttribute("GS_OnFire") or 0) do
			task.wait(0.5)
			if not character.Parent or humanoid.Health <= 0 then break end
			character:SetAttribute("LastDamageCause", "BURNED")
			character:SetAttribute("LastDamageTime", serverNow())
			humanoid:TakeDamage(2.5)
		end
		if character.Parent then character:SetAttribute("GS_OnFire", nil) end
	end)
end
local FLARE_BURN = 14
local function flareLanded(position, normal, attacker)
	local p = Instance.new("Part")
	p.Name = "GS_FlareBurn"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size = Vector3.new(0.25, 0.25, 0.8)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 70, 50)
	p.CFrame = CFrame.lookAt(position + normal * 0.15, position + normal * 0.15 + Vector3.new(normal.Z, 0, -normal.X) + Vector3.new(0.01, 0, 0))
	p.Parent = workspace:FindFirstChild("GS_FX") or workspace
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 70, 50), 24, 3, true
	light.Parent = p
 p:SetAttribute("GS_BurnUntil",serverNow()+FLARE_BURN)
	task.spawn(function()
		local t0 = os.clock()
		while p.Parent and os.clock() - t0 < FLARE_BURN do
			for _, plr in ipairs(Players:GetPlayers()) do
				local c = plr.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if r and (r.Position - position).Magnitude < 3.2 and (c:GetAttribute("Infected") or Svc.PvP() or plr.Character == attacker.Character) then
					setAlight(c, attacker, 4)
				end
			end
			local monsters = workspace:FindFirstChild("Monsters")
			for _, m in ipairs(monsters and monsters:GetChildren() or {}) do
				local r = m:FindFirstChild("HumanoidRootPart")
				if r and (r.Position - position).Magnitude < 4 then burn(m, attacker, 5) end
			end
			task.wait(0.4)
		end
		if p.Parent then p:Destroy() end
	end)
end

local function validCharacter(player)
 local c=player.Character
 local h=c and c:FindFirstChildOfClass("Humanoid")
 if not h or h.Health<=0 or c:GetAttribute("Ragdolled") or c:GetAttribute("Infected") or c:GetAttribute("GS_UseStart") then return end
 return c,h
end
local function cancelReload(player)
 local token=reloading[player]
 if not token then return end
 reloading[player]=nil
 if token.character.Parent then
  token.character:SetAttribute("GS_ReloadAt",nil)
  token.character:SetAttribute("GS_ReloadPhase",nil)
 end
 remote:FireAllClients("reloadcancel",token.character,token.id)
end
local function resolveHit(player, character, item, result, damage, direction)
 local model,kind=classify(result.Instance)
 if not model then
  remote:FireAllClients("surface",result.Position,result.Normal,result.Material,item.id)
  return
 end
 local partName=result.Instance:GetAttribute("BodyPart") or result.Instance.Name
 if kind=="monster" then
  local dealt=monsterApi("damage",model,partName,damage,item.fire and "fire" or "bullet",player,result.Position,direction)
  if item.fire then burn(model,player,7) end
 elseif canHurtPerson(character,model) then
  local killed=hurtPerson(player,model,LIMB[partName] or "Torso",damage,item.fire and "BURNED" or "SHOT",{woundAt=22,type=item.fire and "fire" or "bullet"})
  remote:FireAllClients("bodyimpact",model,result.Position,result.Normal)
  if item.fire and not killed then setAlight(model,player,6) end
 end
end
-- the flare: a burning ball on a slow, dropping arc. It skips off walls and floors it hits at a shallow angle
-- (twice at most), sticks in anything alive it hits (and sets it on fire), and otherwise lies where it lands and
-- burns red for a while, lighting the place up.
local function launchFlare(player,character,item,origin,direction)
 local params=worldParams(character)
 local position=origin
 local velocity=direction*(item.projectileSpeed or 150)
 local gravity=Vector3.new(0,-workspace.Gravity*0.16,0)
 local start=serverNow()
 local id=tostring(player.UserId)..":"..string.format("%.3f",start)
 remote:FireAllClients("flareflight",id,position,velocity,gravity,start,character)
 task.spawn(function()
  local elapsed,travelled,bounces=0,0,0
  while elapsed<6 and travelled<item.range do
   local dt=math.min(game:GetService("RunService").Heartbeat:Wait(),0.05)
   elapsed+=dt
   local step=velocity*dt+gravity*(0.5*dt*dt)
   local hit=workspace:Spherecast(position,0.15,step,params)
   if hit then
    local model=classify(hit.Instance)
    if model then
     resolveHit(player,character,item,hit,item.damage,velocity.Unit)
     remote:FireAllClients("flarestop",id,hit.Position,hit.Normal,hit.Instance)
     return
    end
    local speed=velocity.Magnitude
    local into=velocity:Dot(hit.Normal)
    if bounces<2 and speed>30 and math.abs(into)/speed<0.5 then
     -- a glancing hit: it skips off, slower
     bounces+=1
     velocity=(velocity-2*into*hit.Normal)*0.45
     position=hit.Position+hit.Normal*0.2
     start=serverNow()
     remote:FireAllClients("flarebounce",id,position,velocity,gravity,start)
    else
     flareLanded(hit.Position,hit.Normal,player)
     remote:FireAllClients("flarestop",id,hit.Position,hit.Normal)
     return
    end
   else
    position+=step
    velocity+=gravity*dt
    travelled+=step.Magnitude
   end
  end
  -- out of range: it falls to the floor below and burns there
  local down=workspace:Raycast(position,Vector3.new(0,-60,0),params)
  if down then flareLanded(down.Position,down.Normal,player) end
  remote:FireAllClients("flarestop",id,down and down.Position or position,down and down.Normal or nil)
 end)
end
local function fire(player,uid,origin,seed,aiming)
 local character=validCharacter(player)
 if not character then return end
 local head=character:FindFirstChild("Head")
 local root=character:FindFirstChild("HumanoidRootPart")
 if not head or not root or typeof(origin)~="CFrame" or typeof(seed)~="number" or seed~=seed or math.abs(seed)>2^31 then return end
 local entry,item=Svc.Held(player)
 if not entry or entry.uid~=uid or item.kind~="gun" then return end
 if reloading[player] and reloading[player].uid~=uid then cancelReload(player) end
 if reloading[player] and not item.reloadPerShell then return end
 local now=os.clock()
 if now-(lastShot[player] or 0)<60/item.rpm-0.015 or (entry.ammo or 0)<=0 then return end
 if (origin.Position-head.Position).Magnitude>3 or origin.LookVector.Magnitude<0.9 or origin.LookVector.X~=origin.LookVector.X then return end
 lastShot[player]=now
 cancelReload(player)
 entry.ammo-=1
 Svc.Sync(player)
 character:SetAttribute("GS_RecoilAt",serverNow())
 if item.pump then character:SetAttribute("GS_PumpAt",serverNow()+(item.pumpDelay or 0.22)) end
 local moving=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude>3
 local spread=(aiming and item.aimSpread or item.spread)*(moving and 1.3 or 1)
 local startPos=origin.Position
 local look=CFrame.lookAt(startPos,startPos+origin.LookVector)
 local params=worldParams(character)
 local ends={}
 if item.fire then
  launchFlare(player,character,item,startPos,look.LookVector)
  table.insert(ends,startPos+look.LookVector*item.range)
 else
  -- Aggregate only pellets on the SAME physical part; never move limb damage to another limb.
  local groups={}
  for _,dir in ipairs(ItemData.Pellets(item,look,seed,spread)) do
   local result=workspace:Raycast(startPos,dir*item.range,params)
   local pos=result and result.Position or startPos+dir*item.range
   table.insert(ends,pos)
   if result then
    local dist=(pos-startPos).Magnitude
    local falloff=math.clamp(1-math.max(0,dist-18)/item.range,0.35,1)
    local damage=item.damage*falloff*(result.Instance.Name=="Head" and (item.headMult or 1) or 1)
    local group=groups[result.Instance]
    if group then group.damage+=damage else groups[result.Instance]={result=result,damage=damage,direction=dir} end
   end
  end
  for _,group in pairs(groups) do resolveHit(player,character,item,group.result,group.damage,group.direction) end
 end
 remote:FireAllClients("shot",character,item.id,startPos,ends)
 noise(character,item.fire and 110 or 160)
end
local function reload(player,uid)
 local character=validCharacter(player)
 local entry,item=Svc.Held(player)
 if reloading[player] and reloading[player].uid~=uid then cancelReload(player) end
 if not character or not entry or entry.uid~=uid or item.kind~="gun" or reloading[player] then return end
 local need=item.magazine-(entry.ammo or 0)
 local reserve=Svc.CountOf(player,item.ammo)
 if need<=0 then return end
 if reserve<=0 then remote:FireClient(player,"noammo",item.ammo) return end
 local count=math.min(need,reserve)
 local open=item.reloadOpen or 0.35
 local close=item.reloadClose or 0.35
 local duration=open+item.reload*(item.reloadPerShell and count or 1)+close
 local token={character=character,id=item.id,uid=uid}
 reloading[player]=token
 character:SetAttribute("GS_ReloadAt",serverNow())
 character:SetAttribute("GS_ReloadDur",duration)
 character:SetAttribute("GS_ReloadCycle",item.reload)
 character:SetAttribute("GS_ReloadOpen",open)
 local function valid()
  local e=Svc.Held(player)
  return reloading[player]==token and validCharacter(player)==character and e and e.uid==uid
 end
 local function phase(name,dur,n)
  character:SetAttribute("GS_ReloadCount",n or 1)
  character:SetAttribute("GS_ReloadPhase",name)
  character:SetAttribute("GS_ReloadPhaseAt",serverNow())
  character:SetAttribute("GS_ReloadPhaseDur",dur)
  remote:FireAllClients("reloadphase",character,item.id,name,dur,n or 1)
 end
 task.spawn(function()
  phase("open",open)
  task.wait(open)
  if not valid() then if reloading[player]==token then cancelReload(player) end return end
  local cycles=item.reloadPerShell and count or 1
  for _=1,cycles do
   phase("load",item.reload,item.reloadPerShell and 1 or count)
   task.wait(item.reload)
   if not valid() then if reloading[player]==token then cancelReload(player) end return end
   local e=Svc.Held(player)
   local got=Svc.TakeId(player,item.ammo,item.reloadPerShell and 1 or count)
   if got<=0 then break end
   e.ammo=math.min(item.magazine,(e.ammo or 0)+got)
   Svc.Sync(player)
   remote:FireAllClients("shellin",character,item.id)
  end
  phase("close",close)
  task.wait(close)
  if not valid() then if reloading[player]==token then cancelReload(player) end return end
  reloading[player]=nil
  character:SetAttribute("GS_ReloadAt",nil)
  character:SetAttribute("GS_ReloadPhase",nil)
  remote:FireAllClients("reloaded",character,item.id)
 end)
end
local lastSwing={}
local function swing(player,uid,look)
 local character,humanoid=validCharacter(player)
 if not character or typeof(look)~="Vector3" or look.Magnitude<0.9 or look.X~=look.X then return end
 local entry,item=Svc.Held(player)
 if not entry or entry.uid~=uid or item.kind~="melee" then return end
 local now=os.clock()
 if now-(lastSwing[player] or 0)<item.cooldown-0.015 then return end
 lastSwing[player]=now
 look=look.Unit
 character:SetAttribute("GS_WeaponSwingAt",serverNow())
 character:SetAttribute("GS_AttackDuration",item.cooldown)
 remote:FireAllClients("swing",character,item.id)
 noise(character,25)
 task.wait(item.windup or item.cooldown*0.38)
 local e=Svc.Held(player)
 if validCharacter(player)~=character or not e or e.uid~=uid then return end
 local head=character:FindFirstChild("Head")
 if not head then return end
 local params=worldParams(character)
 local hit=workspace:Raycast(head.Position,look*item.reach,params)
 if not hit then hit=workspace:Spherecast(head.Position,item.hitRadius or 0.12,look*item.reach,params) end
 if not hit then return end
 local model,kind=classify(hit.Instance)
 if not model then remote:FireAllClients("surface",hit.Position,hit.Normal,hit.Material,item.id) return end
 if kind=="monster" then
  local dealt=monsterApi("damage",model,hit.Instance.Name,item.damage*(item.limbMult or 1),item.stun and "shock" or "melee",player,hit.Position,look)
  if item.stun and dealt>0 then monsterControl("Stun",model,item.stun) end
  monsterControl("Struck",model,character)
 elseif canHurtPerson(character,model) then
  hurtPerson(player,model,LIMB[hit.Instance.Name] or "Torso",item.damage,"BEATEN",{type="melee",bleed=item.bleed,stun=item.stun,woundAt=20})
 end
 remote:FireAllClients("impact",model,hit.Position,item.id)
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
