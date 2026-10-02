-- Everything a player carries, holds and wears, kept on the server. Other server scripts require this
-- module (ShopServer buys and sells, Weapons fires, Monsters asks the armor how much a bite really hurts).
-- The client only asks (the GS_Inventory remote) and is told the result (GS_InvSync).
--
-- An entry: {uid, id, n = count, dur = durability (armor), ammo = rounds loaded (guns), worn = true}
-- Kept across servers for 5 minutes after leaving, like the cash (MemoryStore).
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local ShopModels = require(Modules:WaitForChild("ShopModels"))
local Wearables = require(Modules:WaitForChild("Wearables"))
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))

local Svc = {}
Svc.ItemData = ItemData

local KEEP_SECONDS = 5 * 60
local DROP_LIFETIME = 600
local TRAP_ARM_TIME = 1.5
local TRAP_OWNER_GRACE = 3

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local syncRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_InvSync")
local fxRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_ItemFX")
local dropFolder = ensure(workspace, "Folder", "GS_Items")
local trapFolder = ensure(workspace, "Folder", "GS_Traps")
Svc.SyncRemote, Svc.FxRemote = syncRemote, fxRemote

local store
pcall(function() store = MemoryStoreService:GetSortedMap("GS_Inventory") end)

local states = {}
local function serverNow() return workspace:GetServerTimeNow() end
local function newUid() return string.sub(HttpService:GenerateGUID(false), 1, 8) end

local function economy(kind, player, amount)
	local api = ServerStorage:FindFirstChild("GS_Economy")
	if not api then return false, "no economy" end
	return api:Invoke(kind, player, amount)
end

function Svc.PvP()
	return workspace:GetAttribute("GS_PvP") == true
end

-- ===================== state =====================
local function stateOf(player)
	local st = states[player]
	if not st then
		st = {items = {}, held = nil, loaded = false}
		states[player] = st
	end
	return st
end
Svc.State = stateOf

local function find(st, uid)
	for i, e in ipairs(st.items) do
		if e.uid == uid then return e, i end
	end
	return nil
end
Svc.Find = function(player, uid) return find(stateOf(player), uid) end

local function weightOf(st)
	local w = 0
	for _, e in ipairs(st.items) do
		local item = ItemData.Get(e.id)
		if item then w += item.weight * (item.stack > 1 and e.n or 1) end
	end
	return w
end

-- heavier = slower. A light kit costs nothing, full SCG plate costs about a quarter of your speed.
local function speedFor(weight)
	return math.clamp(1 - math.max(0, weight - 10) * 0.012, 0.55, 1)
end

local function snapshot(st)
	local list = {}
	for _, e in ipairs(st.items) do
		table.insert(list, {uid = e.uid, id = e.id, n = e.n, dur = e.dur, ammo = e.ammo, worn = e.worn})
	end
	local w = weightOf(st)
	return {items = list, held = st.held, weight = math.floor(w * 10 + 0.5) / 10, speed = speedFor(w), max = ItemData.MaxSlots}
end

local saveQueued = {}
local function save(player)
	local st = states[player]
	if not store or not st or not st.loaded then return end
	local data = {}
	for _, e in ipairs(st.items) do
		table.insert(data, {id = e.id, n = e.n, dur = e.dur, ammo = e.ammo, worn = e.worn})
	end
	pcall(function()
		if #data > 0 then
			store:SetAsync("u" .. player.UserId, HttpService:JSONEncode(data), KEEP_SECONDS)
		else
			store:RemoveAsync("u" .. player.UserId)
		end
	end)
end

local refreshBody
local function sync(player)
	local st = states[player]
	if not st or not player.Parent then return end
	local snap = snapshot(st)
	syncRemote:FireClient(player, snap)
	local character = player.Character
	if character then
		local boost = (character:GetAttribute("GS_BoostUntil") or 0) > serverNow() and 1.2 or 1
		character:SetAttribute("GS_CarrySpeed", snap.speed * boost)
		character:SetAttribute("GS_Weight", snap.weight)
	end
	if not saveQueued[player] then
		saveQueued[player] = true
		task.delay(5, function()
			saveQueued[player] = nil
			save(player)
		end)
	end
end
Svc.Sync = sync

local function load(player)
	local st = stateOf(player)
	if store then
		local ok, raw = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if ok and typeof(raw) == "string" then
			local okJson, data = pcall(function() return HttpService:JSONDecode(raw) end)
			if okJson and typeof(data) == "table" then
				for _, e in ipairs(data) do
					if ItemData.Get(e.id) and #st.items < ItemData.MaxSlots then
						table.insert(st.items, {uid = newUid(), id = e.id, n = math.max(1, math.floor(tonumber(e.n) or 1)),
							dur = tonumber(e.dur), ammo = tonumber(e.ammo), worn = e.worn == true})
					end
				end
			end
		end
	end
	st.loaded = true
	if player.Character then refreshBody(player) end
	sync(player)
end

-- ===================== giving and taking =====================
function Svc.Give(player, id, amount)
	local item = ItemData.Get(id)
	if not item then return false, "unknown item" end
	local st = stateOf(player)
	amount = math.max(1, math.floor(amount or 1))
	local left = amount
	-- top up stacks first
	if item.stack > 1 then
		for _, e in ipairs(st.items) do
			if e.id == id and e.n < item.stack then
				local add = math.min(item.stack - e.n, left)
				e.n += add
				left -= add
				if left <= 0 then break end
			end
		end
	end
	while left > 0 and #st.items < ItemData.MaxSlots do
		local n = math.min(item.stack, left)
		table.insert(st.items, {
			uid = newUid(), id = id, n = n,
			dur = item.kind == "armor" and item.durability or nil,
			ammo = item.kind == "gun" and 0 or nil,
		})
		left -= n
	end
	sync(player)
	if left == amount then return false, "your bag is full" end
	return true, left > 0 and "bag full - some was left behind" or nil, left
end

function Svc.CountOf(player, id)
	local total = 0
	for _, e in ipairs(stateOf(player).items) do
		if e.id == id and not e.worn then total += e.n end
	end
	return total
end

-- take `amount` of an item id from any stacks (ammo)
function Svc.TakeId(player, id, amount)
	local st = stateOf(player)
	local left = amount
	for i = #st.items, 1, -1 do
		local e = st.items[i]
		if e.id == id and not e.worn and left > 0 then
			local take = math.min(e.n, left)
			e.n -= take
			left -= take
			if e.n <= 0 then table.remove(st.items, i) end
		end
	end
	sync(player)
	return amount - left
end

local unequip
local function removeEntry(player, uid, amount)
	local st = stateOf(player)
	local e, i = find(st, uid)
	if not e then return nil end
	amount = math.clamp(math.floor(amount or e.n), 1, e.n)
	if st.held == uid and amount >= e.n then unequip(player, true) end
	if e.worn and amount >= e.n then Svc.Unwear(player, uid, true) end
	local taken = {id = e.id, n = amount, dur = e.dur, ammo = e.ammo}
	e.n -= amount
	if e.n <= 0 then table.remove(st.items, i) end
	sync(player)
	return taken
end
Svc.Remove = removeEntry

-- ===================== the body: held item, worn armor =====================
local HAND = CFrame.new(0, -1, 0) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0))
local BACK = CFrame.new(0, 0.1, 0.62) * CFrame.Angles(0, math.rad(180), math.rad(-55))

local function weldModel(model, part, cf, scale)
	if scale and scale ~= 1 then pcall(function() model:ScaleTo(scale) end) end
	model:PivotTo(cf)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
			local w = Instance.new("WeldConstraint")
			w.Part0 = part
			w.Part1 = p
			w.Parent = p
		end
	end
end

local function clearHeldModel(character)
	for _, name in ipairs({"GS_Held", "GS_Holstered"}) do
		local old = character:FindFirstChild(name)
		if old then old:Destroy() end
	end
end

local function buildHeld(character, id)
	local arm = character:FindFirstChild("Right Arm")
	if not arm then return nil end
	local model = ShopModels.Build(id)
	model.Name = "GS_Held"
	local scale = ShopModels.HeldScale[id] or 0.6
	local grip = ShopModels.Grip[id] or CFrame.new()
	grip = grip - grip.Position + grip.Position * scale
	model.Parent = character
	weldModel(model, arm, arm.CFrame * HAND * grip:Inverse(), scale)
	model:SetAttribute("ItemId", id)
	return model
end

-- long guns ride on the back while put away
local function buildHolstered(character, id)
	local item = ItemData.Get(id)
	local torso = character:FindFirstChild("Torso")
	if not item or item.pose ~= "long" or not torso then return end
	local model = ShopModels.Build(id)
	model.Name = "GS_Holstered"
	model.Parent = character
	weldModel(model, torso, torso.CFrame * BACK, ShopModels.HeldScale[id] or 0.8)
end

local function setHoldAttributes(character, item)
	character:SetAttribute("GS_Hold", item and item.id or nil)
	character:SetAttribute("GS_HoldPose", item and (item.pose or "item") or nil)
end

function unequip(player, instant)
	local st = stateOf(player)
	local character = player.Character
	local uid = st.held
	st.held = nil
	if character then
		local e = uid and find(st, uid)
		setHoldAttributes(character, nil)
		character:SetAttribute("GS_StowAt", serverNow())
		local function finish()
			if st.held ~= nil then return end
			clearHeldModel(character)
			local holster
			for _, other in ipairs(st.items) do
				local item = ItemData.Get(other.id)
				if item and item.pose == "long" then holster = other.id break end
			end
			if holster then buildHolstered(character, holster) end
		end
		if instant then finish() else task.delay(0.35, finish) end
		if e and ItemData.Get(e.id) then
			fxRemote:FireAllClients("stow", character, e.id)
		end
	end
	sync(player)
end
Svc.Unequip = unequip

function Svc.Equip(player, uid)
	local st = stateOf(player)
	local e = find(st, uid)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not e or not humanoid or humanoid.Health <= 0 then return false, "can't" end
	if character:GetAttribute("Infected") then return false, "your hands are not yours any more" end
	local item = ItemData.Get(e.id)
	if not item or item.kind == "armor" or item.kind == "ammo" then return false, "that can't be held" end
	if st.held == uid then return true end
	st.held = uid
	clearHeldModel(character)
	buildHeld(character, e.id)
	setHoldAttributes(character, item)
	character:SetAttribute("GS_DrawAt", serverNow())
	fxRemote:FireAllClients("draw", character, e.id)
	sync(player)
	return true
end

function Svc.Held(player)
	local st = stateOf(player)
	if not st.held then return nil end
	local e = find(st, st.held)
	if not e then
		st.held = nil
		return nil
	end
	return e, ItemData.Get(e.id)
end

-- hats and hair hide under a helmet
local function hideHeadgear(character, hide)
	for _, acc in ipairs(character:GetChildren()) do
		if acc:IsA("Accessory") then
			local ok, t = pcall(function() return acc.AccessoryType end)
			local onHead = ok and (t == Enum.AccessoryType.Hat or t == Enum.AccessoryType.Hair or t == Enum.AccessoryType.Face)
			local handle = acc:FindFirstChild("Handle")
			if onHead and handle then
				if hide then
					if handle:GetAttribute("GS_Transparency") == nil then handle:SetAttribute("GS_Transparency", handle.Transparency) end
					handle.Transparency = 1
				else
					local was = handle:GetAttribute("GS_Transparency")
					if was ~= nil then handle.Transparency = was handle:SetAttribute("GS_Transparency", nil) end
				end
			end
		end
	end
end

-- rebuilds everything on the body from the state (after a respawn, a load, or wearing / removing)
function refreshBody(player)
	local character = player.Character
	local st = states[player]
	if not character or not st then return end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model") and child.Name:sub(1, 8) == "GS_Wear_" then child:Destroy() end
	end
	local headCovered = false
	local filter = false
	for _, e in ipairs(st.items) do
		if e.worn then
			local item = ItemData.Get(e.id)
			Wearables.Attach(e.id, character)
			if item and table.find(item.slots or {}, "head") then headCovered = true end
			if item and item.filter then filter = true end
		end
	end
	hideHeadgear(character, headCovered)
	character:SetAttribute("GS_Filter", filter)
	-- the held item
	clearHeldModel(character)
	local e = st.held and find(st, st.held)
	if e and not character:GetAttribute("Infected") then
		buildHeld(character, e.id)
		setHoldAttributes(character, ItemData.Get(e.id))
	else
		st.held = nil
		setHoldAttributes(character, nil)
		for _, other in ipairs(st.items) do
			local item = ItemData.Get(other.id)
			if item and item.pose == "long" then buildHolstered(character, other.id) break end
		end
	end
end
Svc.RefreshBody = refreshBody

function Svc.Wear(player, uid)
	local st = stateOf(player)
	local e = find(st, uid)
	local character = player.Character
	if not e or not character then return false, "can't" end
	local item = ItemData.Get(e.id)
	if not item or item.kind ~= "armor" then return false, "that isn't worn" end
	if e.worn then return true end
	-- one piece per slot: whatever sits there now comes off first
	for _, other in ipairs(st.items) do
		if other.worn and other ~= e then
			local o = ItemData.Get(other.id)
			for _, slot in ipairs(item.slots) do
				if o and table.find(o.slots, slot) then other.worn = false end
			end
		end
	end
	if st.held == uid then unequip(player, true) end
	e.worn = true
	refreshBody(player)
	fxRemote:FireAllClients("wear", character, e.id)
	sync(player)
	return true
end

function Svc.Unwear(player, uid, silent)
	local st = stateOf(player)
	local e = find(st, uid)
	if not e or not e.worn then return false end
	e.worn = false
	refreshBody(player)
	if not silent and player.Character then fxRemote:FireAllClients("unwear", player.Character, e.id) end
	sync(player)
	return true
end

-- ===================== armor against damage =====================
-- damage to one body part: worn armor takes a share of it (and wears down). Returns the damage that
-- gets through and whether the armor stopped the wound itself (no broken bone this time).
function Svc.Absorb(character, partKey, damage, damageType)
	local player = Players:GetPlayerFromCharacter(character)
	local st = player and states[player]
	if not st then return damage, false end
	local slots = ItemData.PartSlots[partKey]
	if not slots then return damage, false end
	local best, bestProt = nil, 0
	for _, e in ipairs(st.items) do
		if e.worn then
			local item = ItemData.Get(e.id)
			local prot = item and item.covers and item.covers[partKey]
			if prot and prot > bestProt then best, bestProt = e, prot end
		end
	end
	if not best then return damage, false end
	local item = ItemData.Get(best.id)
	if damageType == "acid" then bestProt *= 0.5 end
	local absorbed = damage * bestProt
	best.dur = (best.dur or item.durability) - absorbed * (item.fragile and 2.2 or 1.2)
	local blocked = math.random() < bestProt
	if best.dur <= 0 then
		-- it breaks and falls off
		local _, i = find(st, best.uid)
		if i then table.remove(st.items, i) end
		refreshBody(player)
		fxRemote:FireAllClients("armorbreak", character, best.id)
	end
	sync(player)
	return damage - absorbed, blocked
end

function Svc.HasFilter(character)
	return character:GetAttribute("GS_Filter") == true
end

-- ===================== buying and selling =====================
function Svc.Buy(player, id)
	local item = ItemData.Get(id)
	if not item or item.adminOnly or (item.price or 0) <= 0 then return false, "not for sale" end
	local cash = economy("get", player) or 0
	if cash < item.price then return false, "not enough money" end
	local amount = item.buyAmount or 1
	-- room check before taking money
	local st = stateOf(player)
	local room = (ItemData.MaxSlots - #st.items) * item.stack
	if item.stack > 1 then
		for _, e in ipairs(st.items) do
			if e.id == id then room += item.stack - e.n end
		end
	end
	if room < amount then return false, "your bag is full" end
	local ok = economy("add", player, -item.price)
	if not ok then return false, "the trader refused" end
	Svc.Give(player, id, amount)
	return true
end

function Svc.Sell(player, uid, amount)
	local st = stateOf(player)
	local e = find(st, uid)
	if not e then return false, "you don't have that" end
	local item = ItemData.Get(e.id)
	if not item or item.adminOnly then return false, "the trader won't touch that" end
	amount = math.clamp(math.floor(amount or e.n), 1, e.n)
	local each = item.sell
	if item.kind == "ammo" and item.buyAmount then each = item.sell / item.buyAmount end
	if item.kind == "armor" and e.dur and item.durability then each = each * math.clamp(e.dur / item.durability, 0.2, 1) end
	local pay = math.max(1, math.floor(each * amount + 0.5))
	removeEntry(player, uid, amount)
	economy("add", player, pay)
	return true, pay
end

-- ===================== dropping for someone else =====================
local function prompt(parent, action, object, hold)
	local p = Instance.new("ProximityPrompt")
	p.Name = "GS_ItemPrompt"
	p.Style = Enum.ProximityPromptStyle.Custom
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0.3
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = parent
	return p
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(position, ignore)
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), groundParams)
	return hit and hit.Position or nil
end

local function bodiesAndFolders()
	local list = {dropFolder, trapFolder}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(list, plr.Character) end
	end
	for _, name in ipairs({"Monsters", "NPCs", "Corpses", "SeveredLimbs"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(list, f) end
	end
	return list
end

function Svc.SpawnDrop(entry, position, droppedBy)
	local item = ItemData.Get(entry.id)
	if not item then return nil end
	local model = ShopModels.Build(entry.id)
	model.Name = "GS_Drop_" .. entry.id
	pcall(function() model:ScaleTo(ShopModels.HeldScale[entry.id] or 0.6) end)
	local ground = groundBelow(position, bodiesAndFolders()) or position
	local _, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(ground + Vector3.new(0, size.Y / 2 + 0.05, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	local base
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = true
			base = base or p
		end
	end
	if not base then model:Destroy() return nil end
	model:SetAttribute("Entry", HttpService:JSONEncode({id = entry.id, n = entry.n, dur = entry.dur, ammo = entry.ammo}))
	model:SetAttribute("DroppedBy", droppedBy)
	local label = item.name .. ((entry.n or 1) > 1 and ("  x" .. entry.n) or "")
	local p = prompt(base, "Pick up", label, 0.35)
	model.Parent = dropFolder
	p.Triggered:Connect(function(who)
		if not model.Parent then return end
		local data = HttpService:JSONDecode(model:GetAttribute("Entry"))
		local ok, _, left = Svc.Give(who, data.id, data.n)
		if not ok then
			fxRemote:FireClient(who, "toast", "your bag is full")
			return
		end
		-- keep the durability / loaded rounds of what was picked up
		local st = stateOf(who)
		for i = #st.items, 1, -1 do
			local e = st.items[i]
			if e.id == data.id then
				if data.dur then e.dur = data.dur end
				if data.ammo then e.ammo = data.ammo end
				break
			end
		end
		sync(who)
		fxRemote:FireAllClients("pickup", who.Character, data.id)
		if left and left > 0 then
			data.n = left
			model:SetAttribute("Entry", HttpService:JSONEncode(data))
		else
			model:Destroy()
		end
	end)
	task.delay(DROP_LIFETIME, function() if model.Parent then model:Destroy() end end)
	return model
end

function Svc.Drop(player, uid, amount)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local taken = removeEntry(player, uid, amount)
	if not taken then return false end
	Svc.SpawnDrop(taken, root.Position + root.CFrame.LookVector * 2.5, player.Name)
	fxRemote:FireAllClients("drop", character, taken.id)
	return true
end

-- ===================== using things =====================
function Svc.UseBegin(player, uid)
	local st = stateOf(player)
	local e = find(st, uid)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not e or not humanoid or humanoid.Health <= 0 then return false end
	local item = ItemData.Get(e.id)
	if not item or item.kind ~= "heal" then return false end
	st.using = {uid = uid, t0 = os.clock()}
	character:SetAttribute("GS_UseStart", serverNow())
	character:SetAttribute("GS_UseItem", e.id)
	fxRemote:FireAllClients("usebegin", character, e.id)
	return true, item.useTime
end

function Svc.UseCancel(player)
	local st = stateOf(player)
	st.using = nil
	if player.Character then
		player.Character:SetAttribute("GS_UseStart", nil)
		player.Character:SetAttribute("GS_UseItem", nil)
	end
end

function Svc.UseFinish(player, uid, quality)
	local st = stateOf(player)
	local using = st.using
	st.using = nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character then
		character:SetAttribute("GS_UseStart", nil)
		character:SetAttribute("GS_UseItem", nil)
	end
	if not using or using.uid ~= uid or not humanoid or humanoid.Health <= 0 then return false end
	local e = find(st, uid)
	local item = e and ItemData.Get(e.id)
	if not item then return false end
	-- a finished mini-game can't be quicker than a real hand
	if os.clock() - using.t0 < item.useTime * 0.6 then return false, "too fast" end
	quality = math.clamp(tonumber(quality) or 0.5, 0, 1)
	local strength = 0.55 + 0.45 * quality
	if item.hp then humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + item.hp * strength) end
	if item.stopBleed and quality > 0.2 then FallDamageController.StopBleeding(character) end
	if item.fixLegs then
		for _, key in ipairs({"LeftLeg", "RightLeg"}) do
			local level = character:GetAttribute("Injury_" .. key) or 0
			if level > 0 and level < 3 then character:SetAttribute("Injury_" .. key, quality > 0.5 and 0 or 1) end
		end
	end
	if item.fixOne then
		local worst, worstLevel = nil, 0
		for _, key in ipairs({"LeftArm", "RightArm", "LeftLeg", "RightLeg", "Torso", "Head"}) do
			local level = character:GetAttribute("Injury_" .. key) or 0
			if level > worstLevel and level < 3 then worst, worstLevel = key, level end
		end
		if worst then character:SetAttribute("Injury_" .. worst, math.max(0, worstLevel - (quality > 0.6 and 2 or 1))) end
	end
	if item.painkill then
		-- a slow steady heal while the pills work
		task.spawn(function()
			for _ = 1, 12 do
				task.wait(1)
				if humanoid.Health <= 0 then break end
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 1)
			end
		end)
	end
	if item.boost then
		character:SetAttribute("GS_BoostUntil", serverNow() + item.boost)
		task.delay(item.boost + 0.1, function() if player.Parent then sync(player) end end)
	end
	removeEntry(player, uid, 1)
	fxRemote:FireAllClients("used", character, item.id, quality)
	return true
end

-- the road flare: light it in the hand, it burns for a minute and is gone
function Svc.LightFlare(player, uid)
	local st = stateOf(player)
	local e = find(st, uid)
	local character = player.Character
	if not e or e.id ~= "flare" or st.held ~= uid or not character then return false end
	if e.lit then return false end
	e.lit = true
	local held = character:FindFirstChild("GS_Held")
	local tip = held and held:FindFirstChildWhichIsA("BasePart")
	if tip then
		local light = Instance.new("PointLight")
		light.Name = "GS_FlareLight"
		light.Color = Color3.fromRGB(255, 70, 50)
		light.Range = 26
		light.Brightness = 2.4
		light.Shadows = true
		light.Parent = tip
		local fire = Instance.new("ParticleEmitter")
		fire.Name = "GS_FlareFire"
		fire.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 90, 60), Color3.fromRGB(255, 200, 120))
		fire.LightEmission = 1
		fire.Size = NumberSequence.new(0.25, 0)
		fire.Lifetime = NumberRange.new(0.3, 0.6)
		fire.Rate = 60
		fire.Speed = NumberRange.new(2, 5)
		fire.SpreadAngle = Vector2.new(25, 25)
		fire.Parent = tip
	end
	character:SetAttribute("GS_FlareLit", serverNow())
	task.delay(ItemData.Get("flare").burn, function()
		if find(st, uid) then removeEntry(player, uid, 1) end
		if character.Parent then character:SetAttribute("GS_FlareLit", nil) end
	end)
	return true
end

-- ===================== bear traps =====================
local traps = {}

local function setJaws(model, closed)
	for _, name in ipairs({"JawA", "JawB"}) do
		local jaw = model:FindFirstChild(name)
		if jaw then
			local side = name == "JawA" and -1 or 1
			local pivot = model:GetAttribute("BaseCF")
			if typeof(pivot) == "CFrame" then
				-- open: flat on the ground; shut: raised up to meet in the middle
				local angle = closed and math.rad(82) * -side or 0
				local base = jaw:GetAttribute("OpenCF")
				if typeof(base) ~= "CFrame" then
					base = jaw:GetPivot()
					jaw:SetAttribute("OpenCF", base)
				end
				local hinge = pivot * CFrame.Angles(angle, 0, 0)
				jaw:PivotTo(hinge * (pivot:Inverse() * base))
			end
		end
	end
end

local releaseTrap
local function buildTrap(position, owner)
	local model = ShopModels.Build("beartrap")
	model.Name = "GS_BearTrap"
	pcall(function() model:ScaleTo(0.9) end)
	local ground = groundBelow(position, bodiesAndFolders()) or position
	local cf = CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	model:PivotTo(cf)
	model:SetAttribute("BaseCF", cf)
	local base
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			base = base or p
		end
	end
	for _, name in ipairs({"JawA", "JawB"}) do
		local jaw = model:FindFirstChild(name)
		if jaw then jaw:SetAttribute("OpenCF", jaw:GetPivot()) end
	end
	model.Parent = trapFolder
	local entry = {model = model, base = base, center = ground, owner = owner, armedAt = os.clock() + TRAP_ARM_TIME, placedAt = os.clock()}
	entry.prompt = prompt(base, "Pick up", "BEAR TRAP", 0.8)
	entry.prompt.Triggered:Connect(function(who)
		if entry.victim then
			releaseTrap(entry)
			return
		end
		if not model.Parent then return end
		local ok = Svc.Give(who, "beartrap", 1)
		if ok then
			model:Destroy()
			entry.dead = true
		end
	end)
	table.insert(traps, entry)
	fxRemote:FireAllClients("trapset", model)
	return entry
end

function releaseTrap(entry)
	if entry.weld then entry.weld:Destroy() entry.weld = nil end
	local victim = entry.victim
	entry.victim = nil
	if victim and victim.Parent then
		victim:SetAttribute("GS_Trapped", nil)
		victim:SetAttribute("AC_TeleportAt", serverNow())
	end
	if entry.prompt then
		entry.prompt.ActionText = "Pick up"
		entry.prompt.HoldDuration = 0.8
	end
	setJaws(entry.model, false)
	entry.armedAt = math.huge -- sprung: it has to be picked up and set again
	fxRemote:FireAllClients("trapopen", entry.model)
end

function Svc.PlaceTrap(player, uid)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local e = find(stateOf(player), uid)
	if not root or not e or e.id ~= "beartrap" then return false end
	removeEntry(player, uid, 1)
	buildTrap(root.Position + root.CFrame.LookVector * 3, player)
	return true
end

local function snap(entry, victim, isMonster)
	entry.armedAt = math.huge
	setJaws(entry.model, true)
	fxRemote:FireAllClients("trapsnap", entry.model, victim)
	local item = ItemData.Get("beartrap")
	if isMonster then
		local health = ServerStorage:FindFirstChild("GS_MonsterHealth")
		if health then
			pcall(function() health:Invoke("damage", victim, "LeftLeg", item.monsterDamage, "trap", entry.owner) end)
		end
		local control = ServerStorage:FindFirstChild("GS_MonsterControl")
		if control then pcall(function() control:Invoke("Stun", victim, item.stun) end) end
		task.delay(item.stun, function() if entry.model.Parent then setJaws(entry.model, false) end end)
		return
	end
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end
	victim:SetAttribute("LastDamageCause", "TRAP")
	victim:SetAttribute("LastDamageTime", serverNow())
	local dmg = Svc.Absorb(victim, "LeftLeg", item.damage, "trap")
	humanoid:TakeDamage(dmg)
	local leg = math.random() < 0.5 and "LeftLeg" or "RightLeg"
	local level = victim:GetAttribute("Injury_" .. leg) or 0
	if level < 2 and humanoid.Health > 0 then FallDamageController.Injure(victim, leg, 2) end
	-- held in place until the jaws are pried open or the timer runs out
	entry.victim = victim
	victim:SetAttribute("GS_Trapped", serverNow() + item.hold)
	victim:SetAttribute("AC_TeleportAt", serverNow())
	local w = Instance.new("WeldConstraint")
	w.Part0 = entry.base
	w.Part1 = root
	w.Parent = entry.base
	entry.weld = w
	entry.prompt.ActionText = "Pry open"
	entry.prompt.HoldDuration = 1.5
	task.delay(item.hold, function() if entry.victim == victim then releaseTrap(entry) end end)
end

local function trapTargets(entry, now)
	local list = {}
	local pvp = Svc.PvP()
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if c and h and h.Health > 0 and not c:GetAttribute("GS_Trapped") then
			local mine = plr == entry.owner
			local allowed = c:GetAttribute("Infected") or pvp or mine
			if allowed and not (mine and now - entry.placedAt < TRAP_OWNER_GRACE) then
				table.insert(list, {c, false})
			end
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	for _, npc in ipairs(npcs and npcs:GetChildren() or {}) do
		if npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart") then table.insert(list, {npc, false}) end
	end
	local monsters = workspace:FindFirstChild("Monsters")
	for _, m in ipairs(monsters and monsters:GetChildren() or {}) do
		if m:IsA("Model") and m:GetAttribute("MonsterId") and not m:GetAttribute("GS_Dead") then table.insert(list, {m, true}) end
	end
	return list
end

task.spawn(function()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for i = #traps, 1, -1 do
			local entry = traps[i]
			if entry.dead or not entry.model.Parent then
				table.remove(traps, i)
			elseif now >= entry.armedAt then
				for _, t in ipairs(trapTargets(entry, now)) do
					local root = t[1]:FindFirstChild("HumanoidRootPart")
					if root then
						local d = Vector3.new(root.Position.X - entry.center.X, 0, root.Position.Z - entry.center.Z).Magnitude
						local dy = root.Position.Y - entry.center.Y
						if d < 1.9 and dy > -1 and dy < 5 then
							snap(entry, t[1], t[2])
							break
						end
					end
				end
			end
		end
	end
end)

-- ===================== players coming and going =====================
local function onCharacter(player, character)
	character:WaitForChild("Humanoid", 10)
	task.wait(0.2)
	if states[player] then
		refreshBody(player)
		sync(player)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			local st = states[player]
			if st then
				st.held = nil
				st.using = nil
			end
		end)
	end
	-- the infected drop what's in their hands
	character:GetAttributeChangedSignal("Infected"):Connect(function()
		if character:GetAttribute("Infected") and states[player] and states[player].held then unequip(player, true) end
	end)
end

local function onPlayer(player)
	stateOf(player)
	player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
	task.spawn(load, player)
end

-- this module is required by several scripts: hook the players only once
if not _G.GS_ItemServiceStarted then
	_G.GS_ItemServiceStarted = true
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, player) end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		states[player] = nil
		saveQueued[player] = nil
	end)
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do task.spawn(save, player) end
		task.wait(2)
	end)
	-- the adrenaline boost wears off on its own; keep everyone's speed attribute honest
	task.spawn(function()
		while true do
			task.wait(2)
			for player, st in pairs(states) do
				local c = player.Character
				if c and (c:GetAttribute("GS_BoostUntil") or 0) > 0 and (c:GetAttribute("GS_BoostUntil") or 0) < serverNow() then
					c:SetAttribute("GS_BoostUntil", nil)
					sync(player)
				end
			end
		end
	end)
end

return Svc
