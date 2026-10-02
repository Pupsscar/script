-- The bag: what the item wheel (InventoryUI) asks the server to do, checked here and carried out by
-- ServerStorage.GS_ItemService. Admins give items through ServerStorage.GS_ItemAdmin (the admin panel).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Svc = require(ServerStorage:WaitForChild("GS_ItemService"))
local ItemData = Svc.ItemData

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local remote = ensure(ReplicatedStorage, "RemoteFunction", "GS_Inventory")
local adminApi = ensure(ServerStorage, "BindableFunction", "GS_ItemAdmin")

local function alive(player)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and not c:GetAttribute("Ragdolled")
end

local ACTIONS = {}

ACTIONS.get = function(player)
	return true, nil
end

ACTIONS.equip = function(player, uid)
	if not alive(player) then return false, "not now" end
	local e = Svc.Find(player, uid)
	if not e then return false, "you don't have that" end
	local item = ItemData.Get(e.id)
	if item.kind == "armor" then return Svc.Wear(player, uid) end
	if item.kind == "ammo" then return false, "ammo goes into a gun" end
	return Svc.Equip(player, uid)
end

ACTIONS.holster = function(player)
	Svc.Unequip(player, false)
	return true
end

ACTIONS.wear = function(player, uid)
	if not alive(player) then return false, "not now" end
	return Svc.Wear(player, uid)
end

ACTIONS.unwear = function(player, uid)
	return Svc.Unwear(player, uid)
end

ACTIONS.drop = function(player, uid, amount)
	if not player.Character then return false end
	return Svc.Drop(player, uid, amount)
end

ACTIONS.usebegin = function(player, uid)
	if not alive(player) then return false, "not now" end
	local e = Svc.Find(player, uid)
	if not e then return false end
	local item = ItemData.Get(e.id)
	if item.kind == "trap" then return Svc.PlaceTrap(player, uid) end
	if item.kind == "light" then
		if Svc.State(player).held ~= uid then Svc.Equip(player, uid) end
		return Svc.LightFlare(player, uid)
	end
	return Svc.UseBegin(player, uid)
end

ACTIONS.usefinish = function(player, uid, quality)
	return Svc.UseFinish(player, uid, quality)
end

ACTIONS.usecancel = function(player)
	Svc.UseCancel(player)
	return true
end

-- selling happens at the shop counter (ShopServer checks the distance and calls Svc.Sell itself);
-- the wheel only lists what could be sold
ACTIONS.sellprices = function(player)
	local list = {}
	for _, e in ipairs(Svc.State(player).items) do
		local item = ItemData.Get(e.id)
		if item and not item.adminOnly then
			local each = item.sell
			if item.kind == "ammo" and item.buyAmount then each = item.sell / item.buyAmount end
			list[e.uid] = math.max(1, math.floor(each * e.n + 0.5))
		end
	end
	return true, list
end

local last = {}
remote.OnServerInvoke = function(player, action, ...)
	local now = os.clock()
	if now - (last[player] or 0) < 0.08 then return false, "slow down" end
	last[player] = now
	local handler = typeof(action) == "string" and ACTIONS[action]
	if not handler then return false, "unknown" end
	local ok, a, b = pcall(handler, player, ...)
	if not ok then
		warn("[Inventory] " .. tostring(a))
		return false, "error"
	end
	Svc.Sync(player)
	return a, b
end
Players.PlayerRemoving:Connect(function(player) last[player] = nil end)

-- ===== admin: give items, the SCG set, PvP =====
adminApi.OnInvoke = function(action, target, id, amount)
	if action == "give" then
		if typeof(target) ~= "Instance" or not target:IsA("Player") then return false, "player not found" end
		if id == "scg_set" then
			for _, piece in ipairs(ItemData.SCG_SET) do Svc.Give(target, piece, 1) end
			Svc.Give(target, "shells12", 24)
			return true, target.DisplayName .. " got the SCG set"
		end
		local item = ItemData.Get(id)
		if not item then return false, "unknown item" end
		local ok, message = Svc.Give(target, id, math.clamp(math.floor(tonumber(amount) or 1), 1, 200))
		return ok, ok and string.format("%s got %s x%d", target.DisplayName, item.name, math.floor(tonumber(amount) or 1)) or message
	elseif action == "clear" then
		if typeof(target) ~= "Instance" or not target:IsA("Player") then return false, "player not found" end
		local st = Svc.State(target)
		Svc.Unequip(target, true)
		table.clear(st.items)
		Svc.RefreshBody(target)
		Svc.Sync(target)
		return true, target.DisplayName .. "'s bag emptied"
	elseif action == "pvp" then
		workspace:SetAttribute("GS_PvP", target == true)
		return true, target == true and "PvP on: players can hurt each other" or "PvP off"
	end
	return false, "unknown"
end
workspace:SetAttribute("GS_PvP", workspace:GetAttribute("GS_PvP") == true)
