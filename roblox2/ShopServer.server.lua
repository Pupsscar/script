-- The supply depot (workspace.GS_Shop): opened and closed from the admin panel.
--  * at start the ground under the hatch is dug out (terrain, and flat ground parts are cut around the hole),
--    so the model can be moved anywhere in Studio and still work
--  * opening / closing: State + T0 on the model (every client animates from them), the solid parts are moved here
--    a few times a second so the server's collisions follow, the final pose is set when it stops
--  * nobody is left in the pit: whoever is inside the hatch when the doors start to close is lifted out in front
--  * buying and selling: checked here (open, close enough), carried out by ServerStorage.GS_ItemService
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ShopRig = require(Modules:WaitForChild("ShopRig"))
local ShopData = require(Modules:WaitForChild("ShopData"))

local control = ServerStorage:FindFirstChild("GS_ShopControl")
if not control then
	control = Instance.new("BindableFunction")
	control.Name = "GS_ShopControl"
	control.Parent = ServerStorage
end
local remote = ReplicatedStorage:FindFirstChild("GS_ShopRemote")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GS_ShopRemote"
	remote.Parent = ReplicatedStorage
end

local function serverNow() return workspace:GetServerTimeNow() end

local shop = workspace:FindFirstChild("GS_Shop")
if not shop then
	control.OnInvoke = function() return false, "there is no GS_Shop in the world" end
	return
end

local HALF = ShopRig.HALF
local HOLE = HALF + 1 -- the hole plus the shaft walls

-- ===== dig the hole =====
local function splitAround(part, base)
	local cf, size = part.CFrame, part.Size
	if math.abs(cf.UpVector.Y) < 0.999 then return false end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, c in ipairs({Vector3.new(-HOLE, 0, -HOLE), Vector3.new(HOLE, 0, -HOLE), Vector3.new(-HOLE, 0, HOLE), Vector3.new(HOLE, 0, HOLE)}) do
		local p = cf:PointToObjectSpace(base * c)
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local hx, hz = size.X / 2, size.Z / 2
	minX, maxX = math.max(minX, -hx), math.min(maxX, hx)
	minZ, maxZ = math.max(minZ, -hz), math.min(maxZ, hz)
	if minX >= maxX or minZ >= maxZ then return false end
	local pieces = {
		{-hx, minX, -hz, hz}, {maxX, hx, -hz, hz},
		{minX, maxX, -hz, minZ}, {minX, maxX, maxZ, hz},
	}
	for _, r in ipairs(pieces) do
		local w, d = r[2] - r[1], r[4] - r[3]
		if w > 0.05 and d > 0.05 then
			local piece = part:Clone()
			piece.Size = Vector3.new(w, size.Y, d)
			piece.CFrame = cf * CFrame.new((r[1] + r[2]) / 2, 0, (r[3] + r[4]) / 2)
			-- keep tiled textures lined up with the rest of the ground
			for _, t in ipairs(piece:GetChildren()) do
				if t:IsA("Texture") then
					t.OffsetStudsU += r[1] + hx
					t.OffsetStudsV += r[3] + hz
				end
			end
			piece.Parent = part.Parent
		end
	end
	part:Destroy()
	return true
end

local function dig()
	local base = shop:GetPivot()
	pcall(function()
		workspace.Terrain:FillBlock(base * CFrame.new(0, -7.6, 0), Vector3.new(HOLE * 2 + 1.6, 16.4, HOLE * 2 + 1.6), Enum.Material.Air)
	end)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {shop, workspace.Terrain}
	local found = workspace:GetPartBoundsInBox(base * CFrame.new(0, -7.4, 0), Vector3.new(HOLE * 2 - 0.2, 14.6, HOLE * 2 - 0.2), params)
	local cut = 0
	for _, part in ipairs(found) do
		local ground = part:IsA("Part") and part.Shape == Enum.PartType.Block and part.Anchored
			and part.Size.X >= HOLE * 2 and part.Size.Z >= HOLE * 2
			and math.abs((part.Position.Y + part.Size.Y / 2) - base.Y) < 2.5
		if ground and splitAround(part, base) then cut += 1 end
	end
	return cut
end
dig()

-- ===== state =====
local rig = ShopRig.Collect(shop, 0)
local prompt
for _, d in ipairs(shop:GetDescendants()) do
	if d:IsA("ProximityPrompt") and d.Name == "ShopPrompt" then prompt = d break end
end
local busy = false

local function setState(state)
	local t0 = serverNow()
	shop:SetAttribute("T0", t0)
	shop:SetAttribute("State", state)
	workspace:SetAttribute("ShopT0", t0)
	workspace:SetAttribute("ShopState", state)
end
setState("closed")

local function nearby(radius)
	local base = shop:GetPivot()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local p = base:PointToObjectSpace(root.Position)
			if math.abs(p.X) < radius and math.abs(p.Z) < radius and p.Y < 18 and p.Y > -18 then
				table.insert(list, {player = player, character = character, root = root, local_ = p})
			end
		end
	end
	return list
end

-- moving floors and doors look like flying / noclip to the anticheat: people right next to it are let off
local function exemptNearby()
	for _, entry in ipairs(nearby(HOLE + 12)) do
		entry.character:SetAttribute("AC_TeleportAt", serverNow())
	end
end

-- whoever is down in the hatch is put back on the ground in front of it
local function clearPit()
	local base = shop:GetPivot()
	for _, entry in ipairs(nearby(HALF + 0.5)) do
		if entry.local_.Y < 4 then
			entry.character:SetAttribute("AC_TeleportAt", serverNow())
			local spot = base * CFrame.new(math.clamp(entry.local_.X, -5, 5), 3.5, -(HOLE + 4))
			entry.character:PivotTo(CFrame.lookAt(spot.Position, (base * CFrame.new(0, 3.5, 0)).Position))
			entry.root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function run(opening)
	busy = true
	local state = opening and "opening" or "closing"
	local tl = ShopRig.Timeline[state]
	if not opening then
		if prompt then prompt.Enabled = false end
		remote:FireAllClients("closing")
	end
	setState(state)
	local t0 = shop:GetAttribute("T0")
	local nextMove, nextExempt = 0, 0
	local cleared = false
	while shop.Parent do
		local elapsed = serverNow() - t0
		if elapsed >= tl.total then break end
		local now = os.clock()
		if now >= nextExempt then
			nextExempt = now + 0.5
			exemptNearby()
		end
		if not opening and not cleared and elapsed >= tl.doors[1] - 0.2 then
			cleared = true
			clearPit()
		end
		if now >= nextMove then
			nextMove = now + 1 / 12
			local d, l = ShopRig.Alphas(state, elapsed)
			ShopRig.Apply(rig, d, l, true)
		end
		RunService.Heartbeat:Wait()
	end
	local final = opening and 1 or 0
	ShopRig.Apply(rig, final, final, false)
	setState(opening and "open" or "closed")
	if opening and prompt then prompt.Enabled = true end
	busy = false
end

control.OnInvoke = function(open)
	if not shop.Parent then return false, "the shop is gone" end
	if busy then return false, "the depot is still moving" end
	local state = shop:GetAttribute("State")
	if open and state == "open" then return false, "the shop is already open" end
	if not open and state == "closed" then return false, "the shop is already closed" end
	task.spawn(run, open == true)
	return true, open and "shop opening" or "shop closing"
end

-- ===== the window =====
local ItemService = require(ServerStorage:WaitForChild("GS_ItemService"))
local lastBuy = {}
remote.OnServerEvent:Connect(function(player, kind, itemId, amount)
	if kind ~= "buy" and kind ~= "sell" then return end
	local now = os.clock()
	if now - (lastBuy[player] or 0) < 0.3 then return end
	lastBuy[player] = now
	if typeof(itemId) ~= "string" then return end
	if kind == "buy" and not ShopData.Get(itemId) then return end
	if shop:GetAttribute("State") ~= "open" then
		remote:FireClient(player, kind, itemId, false, "the depot is closed")
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local promptPart = prompt and prompt.Parent
	if not root or not promptPart or (root.Position - promptPart.Position).Magnitude > 20 then
		remote:FireClient(player, kind, itemId, false, "come closer to the counter")
		return
	end
	if kind == "buy" then
		local ok, message = ItemService.Buy(player, itemId)
		remote:FireClient(player, "buy", itemId, ok, message)
	else
		-- itemId is the bag entry's uid here
		local ok, paid = ItemService.Sell(player, itemId, tonumber(amount))
		remote:FireClient(player, "sell", itemId, ok, ok and ("sold for $" .. tostring(paid)) or paid)
	end
end)
Players.PlayerRemoving:Connect(function(player) lastBuy[player] = nil end)
