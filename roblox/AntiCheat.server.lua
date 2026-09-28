-- Server anti-cheat: movement checks, account screening, bans, incident replays, punishment.
-- Everything a player sees from here is in English.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FallDamageController = require(Modules:WaitForChild("FallDamageController"))

local CONFIG = {
	Admins = {[1666069865] = true},

	-- account screening (admins are never screened)
	ScreenAccounts = true,
	MinAccountAgeDays = 3,
	MinFriends = 5,
	MinBadges = 20,
	-- Roblox blocks HttpService calls to roblox.com, so badges go through a public proxy.
	-- Needs "Allow HTTP Requests" on. If the request fails the badge check is skipped, never a kick.
	BadgeApi = "https://badges.roproxy.com/v1/users/%d/badges?limit=25&sortOrder=Desc",
	ScreenWhitelist = {},
	SuspiciousMessage = "Suspicious account",

	-- movement
	SampleInterval = 0.1,
	SpeedAllowanceMult = 1.45,
	SpeedAllowanceFlat = 6,
	TeleportDistance = 40,
	HoverTime = 1.25,
	MaxRise = 11,
	FlingAngular = 200,
	DesyncDistance = 25,
	RemoteSpamPerSecond = 90,
	HeartbeatTimeout = 45,
	FirstHeartbeatTimeout = 120,

	-- scoring: every flag adds points, points decay over time
	ScoreDecayPerSecond = 0.25,
	IncidentScore = 8,
	PunishScore = 25,
	Points = {
		speed = 2, teleport = 5, fly = 4, noclip = 4, desync = 3, fling = 8, humanoid = 30, remotespam = 10,
		hook = 6, esp = 5, lighting = 1, gravity = 5, walkspeed = 5, jumppower = 5, injected = 8,
	},

	-- punishment
	PunishKillDelay = 20,
	AutoBanSeconds = 30 * 86400,
	AutoBanAllDevices = true,

	-- replays
	RecordSeconds = 90,
	ReplayBefore = 30,
	ReplayAfter = 8,
	ReplayRadius = 150,
	ReplayMaxEntities = 12,
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

local reportRemote = ensure(ReplicatedStorage, "RemoteEvent", "ACReport")
local alertRemote = ensure(ReplicatedStorage, "RemoteEvent", "ACAlert")
local adminRemote = ensure(ReplicatedStorage, "RemoteFunction", "ACAdmin")
local worldInfo = ensure(ReplicatedStorage, "Configuration", "AC_World")
local strikeRemote = ReplicatedStorage:WaitForChild("PlayerStrike", 30)

local banStore, incidentStore
pcall(function() banStore = DataStoreService:GetDataStore("AC_Bans_v1") end)
pcall(function() incidentStore = DataStoreService:GetDataStore("AC_Incidents_v1") end)

local function serverNow() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end

local function isAdmin(player)
	return CONFIG.Admins[player.UserId] == true or player:GetAttribute("IsAdmin") == true
end

local function forAdmins(fn)
	for _, plr in ipairs(Players:GetPlayers()) do
		if isAdmin(plr) then fn(plr) end
	end
end

-- ===================== bans =====================

local function formatDuration(seconds)
	if seconds < 0 then return "permanent" end
	if seconds >= 86400 then return string.format("%dd", math.floor(seconds / 86400)) end
	if seconds >= 3600 then return string.format("%dh", math.floor(seconds / 3600)) end
	return string.format("%dm", math.max(1, math.floor(seconds / 60)))
end

local function parseDuration(text)
	if typeof(text) == "number" then return text end
	if typeof(text) ~= "string" then return nil end
	text = text:lower():gsub("%s", "")
	if text == "" or text == "perm" or text == "permanent" or text == "-1" then return -1 end
	local total = 0
	for amount, unit in text:gmatch("(%d+)(%a*)") do
		local n = tonumber(amount)
		local mult = ({s = 1, m = 60, h = 3600, d = 86400, w = 604800, y = 31536000, [""] = 86400})[unit]
		if not mult then return nil end
		total += n * mult
	end
	return total > 0 and total or nil
end

local function banMessage(entry)
	local expires = entry.expires == -1 and "never" or os.date("!%Y-%m-%d %H:%M UTC", entry.expires)
	return string.format("You are banned.\nReason: %s\nExpires: %s", entry.reason or "no reason", expires)
end

local function banActive(entry)
	return entry and entry.active and (entry.expires == -1 or os.time() < entry.expires)
end

local function updateIndex(entry)
	if not banStore then return end
	pcall(function()
		banStore:UpdateAsync("index", function(list)
			list = list or {}
			for i = #list, 1, -1 do
				if list[i].userId == entry.userId then table.remove(list, i) end
			end
			table.insert(list, 1, entry)
			while #list > 300 do table.remove(list) end
			return list
		end)
	end)
end

local function ban(userId, name, reason, seconds, allDevices, by, source, incidentId)
	local entry = {
		userId = userId, name = name or tostring(userId), reason = reason, by = by, source = source,
		at = os.time(), expires = seconds < 0 and -1 or os.time() + seconds, duration = seconds,
		allDevices = allDevices, incident = incidentId, active = true,
	}
	if banStore then pcall(function() banStore:SetAsync("u_" .. userId, entry) end) end
	updateIndex(entry)
	-- Roblox's own ban API adds alt-account (device) detection when allDevices is on
	pcall(function()
		Players:BanAsync({
			UserIds = {userId}, ApplyToUniverse = true, Duration = seconds < 0 and -1 or seconds,
			DisplayReason = string.sub(reason, 1, 380), PrivateReason = string.sub(source .. " / " .. tostring(by) .. ": " .. reason, 1, 900),
			ExcludeAltAccounts = not allDevices,
		})
	end)
	local online = Players:GetPlayerByUserId(userId)
	if online then online:Kick(banMessage(entry)) end
	forAdmins(function(admin)
		alertRemote:FireClient(admin, "ban", string.format("%s banned (%s) — %s", entry.name, formatDuration(seconds), reason))
	end)
	return entry
end

local function unban(userId, by)
	local entry
	if banStore then
		pcall(function() entry = banStore:GetAsync("u_" .. userId) end)
	end
	entry = entry or {userId = userId, name = tostring(userId), reason = "?", at = os.time(), expires = -1}
	entry.active = false
	entry.unbannedBy = by
	entry.unbannedAt = os.time()
	if banStore then pcall(function() banStore:SetAsync("u_" .. userId, entry) end) end
	updateIndex(entry)
	pcall(function() Players:UnbanAsync({UserIds = {userId}, ApplyToUniverse = true}) end)
	return entry
end

-- ===================== account screening =====================

local function screenAccount(player)
	if not CONFIG.ScreenAccounts or isAdmin(player) or CONFIG.ScreenWhitelist[player.UserId] then return end
	if player.AccountAge < CONFIG.MinAccountAgeDays then
		player:Kick(CONFIG.SuspiciousMessage)
		return
	end
	local okFriends, count = pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		local n = #pages:GetCurrentPage()
		while n < CONFIG.MinFriends and not pages.IsFinished do
			pages:AdvanceToNextPageAsync()
			n += #pages:GetCurrentPage()
		end
		return n
	end)
	if okFriends and count < CONFIG.MinFriends then
		player:Kick(CONFIG.SuspiciousMessage)
		return
	end
	local okBadges, badges = pcall(function()
		local body = HttpService:GetAsync(string.format(CONFIG.BadgeApi, player.UserId))
		local data = HttpService:JSONDecode(body)
		if typeof(data) ~= "table" or typeof(data.data) ~= "table" then error("bad reply") end
		if #data.data >= CONFIG.MinBadges or data.nextPageCursor then return math.huge end
		return #data.data
	end)
	if okBadges and badges < CONFIG.MinBadges and player.Parent then
		player:Kick(CONFIG.SuspiciousMessage)
	end
end

-- ===================== recording (replays) =====================

local frames = {}
local events = {}
local entityInfo = {}
local monsterIds = 0

local function entityIdFor(model)
	local plr = Players:GetPlayerFromCharacter(model)
	if plr then
		entityInfo["P" .. plr.UserId] = {name = plr.DisplayName .. " (@" .. plr.Name .. ")", kind = "player", userId = plr.UserId}
		return "P" .. plr.UserId
	end
	local id = model:GetAttribute("AC_Id")
	if not id then
		monsterIds += 1
		local isNpc = model.Parent and model.Parent.Name == "NPCs"
		id = (isNpc and "N" or "M") .. monsterIds
		model:SetAttribute("AC_Id", id)
		entityInfo[id] = {name = isNpc and (model:GetAttribute("DisplayName") or model.Name) or model.Name, kind = isNpc and "npc" or "monster"}
	end
	return id
end

local function logEvent(model, kind, text)
	if not model then return end
	table.insert(events, {t = serverNow(), id = entityIdFor(model), kind = kind, text = text})
	local cutoff = serverNow() - CONFIG.RecordSeconds
	while events[1] and events[1].t < cutoff do table.remove(events, 1) end
end

local function stateCode(model, humanoid)
	if not humanoid or humanoid.Health <= 0 then return 3 end
	if model:GetAttribute("Ragdolled") then return 2 end
	if humanoid.FloorMaterial == Enum.Material.Air then return 1 end
	return 0
end

local function recordFrame()
	local entities = {}
	local function add(model)
		local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
		if not root or not root:IsA("BasePart") then return end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local look = root.CFrame.LookVector
		local hp = humanoid and humanoid.MaxHealth > 0 and math.floor(humanoid.Health / humanoid.MaxHealth * 100) or 0
		local p = root.Position
		entities[entityIdFor(model)] = {r1(p.X), r1(p.Y), r1(p.Z), r1(math.atan2(-look.X, -look.Z)), stateCode(model, humanoid), hp}
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then add(plr.Character) end
	end
	for _, folderName in ipairs({"Monsters", "NPCs"}) do
		local f = workspace:FindFirstChild(folderName)
		if f then
			for _, model in ipairs(f:GetChildren()) do
				if model:IsA("Model") then add(model) end
			end
		end
	end
	table.insert(frames, {t = serverNow(), e = entities})
	local cutoff = serverNow() - CONFIG.RecordSeconds
	while frames[1] and frames[1].t < cutoff do table.remove(frames, 1) end
end

local incidentCache = {}
local incidentIndexCache = {}

local function buildReplay(suspectId, fromT, toT)
	local relevant = {[suspectId] = true}
	local count = 1
	for _, frame in ipairs(frames) do
		if frame.t >= fromT and frame.t <= toT then
			local s = frame.e[suspectId]
			if s then
				for id, e in pairs(frame.e) do
					if not relevant[id] and count < CONFIG.ReplayMaxEntities then
						local d = Vector3.new(e[1] - s[1], e[2] - s[2], e[3] - s[3]).Magnitude
						if d < CONFIG.ReplayRadius then
							relevant[id] = true
							count += 1
						end
					end
				end
			end
		end
	end
	local order, index = {}, {}
	for id in pairs(relevant) do
		local info = entityInfo[id] or {name = id, kind = "?"}
		table.insert(order, {id = id, name = info.name, kind = info.kind, suspect = id == suspectId})
		index[id] = #order
	end
	local outFrames = {}
	for _, frame in ipairs(frames) do
		if frame.t >= fromT and frame.t <= toT then
			local row = {math.floor((frame.t - fromT) * 100 + 0.5) / 100}
			for id, e in pairs(frame.e) do
				local i = index[id]
				if i then table.insert(row, {i, e[1], e[2], e[3], e[4], e[5], e[6]}) end
			end
			table.insert(outFrames, row)
		end
	end
	local outEvents = {}
	for _, ev in ipairs(events) do
		if ev.t >= fromT and ev.t <= toT and index[ev.id] then
			table.insert(outEvents, {math.floor((ev.t - fromT) * 100 + 0.5) / 100, index[ev.id], ev.kind, ev.text})
		end
	end
	return {entities = order, frames = outFrames, events = outEvents, length = toT - fromT}
end

local function saveIncident(meta, replay)
	incidentCache[meta.id] = {meta = meta, replay = replay}
	table.insert(incidentIndexCache, 1, meta)
	while #incidentIndexCache > 150 do table.remove(incidentIndexCache) end
	if not incidentStore then return end
	pcall(function() incidentStore:SetAsync("i_" .. meta.id, {meta = meta, replay = replay}) end)
	pcall(function()
		incidentStore:UpdateAsync("index", function(list)
			list = list or {}
			table.insert(list, 1, meta)
			while #list > 150 do table.remove(list) end
			return list
		end)
	end)
end

-- ===================== per-player state =====================

local states = {}

local function newState(player)
	return {
		player = player, score = 0, window = {}, flagLast = {}, flagCounts = {},
		lastIncidentAt = -math.huge, joinedAt = os.clock(), key = HttpService:GenerateGUID(false),
		lastBeat = nil, seq = 0, desyncStrikes = 0, remoteCount = 0, remoteWindowStart = os.clock(),
	}
end

local createIncident
local punish

local function flag(player, kind, detail)
	local st = states[player]
	if not st or st.punishing then return end
	local now = os.clock()
	if now - (st.flagLast[kind] or -math.huge) < 0.45 then return end
	st.flagLast[kind] = now
	st.flagCounts[kind] = (st.flagCounts[kind] or 0) + 1
	st.score += CONFIG.Points[kind] or 3
	local text = kind .. (detail and (": " .. detail) or "")
	logEvent(player.Character, "flag", text)
	st.lastReason = text
	if st.score >= CONFIG.PunishScore then
		punish(player, text)
	elseif st.score >= CONFIG.IncidentScore and now - st.lastIncidentAt > 60 then
		st.lastIncidentAt = now
		createIncident(player, text, "recorded")
	end
end

function createIncident(player, reason, action)
	local st = states[player]
	local counts = {}
	for kind, n in pairs(st and st.flagCounts or {}) do table.insert(counts, kind .. " x" .. n) end
	local meta = {
		id = string.sub(HttpService:GenerateGUID(false), 1, 8), userId = player.UserId,
		name = player.DisplayName .. " (@" .. player.Name .. ")", reason = reason, flags = table.concat(counts, ", "),
		score = st and math.floor(st.score) or 0, at = os.time(), server = game.JobId, action = action,
	}
	local flagT = serverNow()
	local suspectId = "P" .. player.UserId
	entityInfo[suspectId] = {name = meta.name, kind = "player", userId = player.UserId}
	forAdmins(function(admin)
		alertRemote:FireClient(admin, "incident", string.format("[AC] %s — %s (%s)", meta.name, reason, action))
	end)
	task.delay(CONFIG.ReplayAfter, function()
		local replay = buildReplay(suspectId, flagT - CONFIG.ReplayBefore, flagT + CONFIG.ReplayAfter)
		saveIncident(meta, replay)
		forAdmins(function(admin) alertRemote:FireClient(admin, "incidents") end)
	end)
	return meta
end

-- confident: paralyse, lobotomise, kill, then ban. Leaving or resetting just bans sooner.
function punish(player, reason)
	local st = states[player]
	if not st or st.punishing then return end
	st.punishing = true
	player:SetAttribute("AC_Punished", true)
	local meta = createIncident(player, reason, "punished")
	local function doBan()
		if st.banned then return end
		st.banned = true
		ban(player.UserId, player.Name, "Exploiting (" .. reason .. ")", CONFIG.AutoBanSeconds, CONFIG.AutoBanAllDevices,
			"AntiCheat", "anticheat", meta.id)
	end
	st.doBan = doBan
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		doBan()
		return
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	character:SetAttribute("Injury_Torso", 2)
	character:SetAttribute("Lobotomized", true)
	humanoid.Died:Connect(function()
		task.wait(3)
		doBan()
	end)
	task.delay(CONFIG.PunishKillDelay, function()
		if humanoid.Parent and humanoid.Health > 0 then
			if not FallDamageController.ExplodeHead(character) then humanoid.Health = 0 end
		end
		task.wait(5)
		doBan()
	end)
end

-- ===================== movement checks =====================

local function worldParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local ignore = {character}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(ignore, plr.Character) end
	end
	for _, name in ipairs({"Monsters", "NPCs", "Corpses", "SeveredLimbs", "GS_Hallucinations"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(ignore, f) end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function groundParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = false
	params.FilterDescendantsInstances = {character}
	return params
end

local function rubberband(st, root)
	if not st.lastGood then return end
	root.CFrame = st.lastGood
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	st.graceUntil = os.clock() + 0.35
	st.window = {}
	st.air = nil
	st.lastPos = st.lastGood.Position
	logEvent(st.player.Character, "rubberband", "pulled back")
end

local function exempt(character, humanoid)
	if character:GetAttribute("Ragdolled") or character:GetAttribute("Paralyzed") then return true end
	if humanoid.Sit or humanoid.SeatPart or humanoid.PlatformStand then return true end
	local tp = character:GetAttribute("AC_TeleportAt")
	if tp and serverNow() - tp < 3 then return true end
	return false
end

local function checkPlayer(player, st, now)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or st.punishing then
		st.lastPos, st.window, st.air, st.lastGood = nil, {}, nil, nil
		return
	end
	local pos = root.Position
	if now < (st.graceUntil or 0) or exempt(character, humanoid) then
		st.lastPos, st.window, st.air = pos, {}, nil
		st.lastGood = root.CFrame
		return
	end
	local lastPos = st.lastPos or pos
	st.lastPos = pos
	local delta = pos - lastPos
	local violated = false

	-- teleport
	if flat(delta).Magnitude > CONFIG.TeleportDistance or delta.Y > 25 then
		flag(player, "teleport", string.format("%.0f studs in one tick", delta.Magnitude))
		rubberband(st, root)
		return
	end

	-- noclip: passing through, or standing inside, solid geometry
	if delta.Magnitude > 0.3 then
		local params = worldParams(character)
		local forward = workspace:Raycast(lastPos, delta, params)
		if forward and forward.Instance.Anchored then
			local back = workspace:Raycast(pos, -delta, params)
			local inside = false
			if not back then
				local overlap = OverlapParams.new()
				overlap.FilterType = Enum.RaycastFilterType.Include
				overlap.FilterDescendantsInstances = {forward.Instance}
				overlap.RespectCanCollide = true
				inside = #workspace:GetPartBoundsInRadius(pos, 0.4, overlap) > 0
			end
			if back or inside then
				flag(player, "noclip", forward.Instance:GetFullName())
				rubberband(st, root)
				return
			end
		end
	end

	-- speed over a one second window
	table.insert(st.window, {t = now, p = pos})
	while st.window[1] and now - st.window[1].t > 1.05 do table.remove(st.window, 1) end
	local oldest = st.window[1]
	local span = now - oldest.t
	if span > 0.9 then
		local dist = flat(pos - oldest.p).Magnitude
		local base = math.max(humanoid.WalkSpeed, 16)
		local allowed = (base * CONFIG.SpeedAllowanceMult + CONFIG.SpeedAllowanceFlat) * span
		if dist > allowed then
			flag(player, "speed", string.format("%.0f studs/s", dist / span))
			violated = true
		end
	end

	-- fly / hover / rising without ground
	local state = humanoid:GetState()
	local climbing = state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming
	if not climbing then
		for _, part in ipairs(workspace:GetPartBoundsInRadius(pos, 3)) do
			if part:IsA("TrussPart") then climbing = true break end
		end
	end
	-- a box cast, not a single ray: standing on an edge or someone's head still counts as ground
	local ground = workspace:Blockcast(root.CFrame, Vector3.new(2.4, 1, 1.6), Vector3.new(0, -(2.5 + humanoid.HipHeight + 4), 0), groundParams(character)) ~= nil
	if ground or climbing then
		st.air = nil
	else
		if not st.air then
			st.air = {start = now, startY = pos.Y, history = {}}
		end
		local air = st.air
		table.insert(air.history, {t = now, y = pos.Y})
		while air.history[1] and now - air.history[1].t > CONFIG.HoverTime do table.remove(air.history, 1) end
		local first = air.history[1]
		if now - air.start > CONFIG.HoverTime and first and now - first.t > CONFIG.HoverTime * 0.9 and pos.Y >= first.y - 1 then
			flag(player, "fly", string.format("airborne %.1fs without falling", now - air.start))
			violated = true
		elseif pos.Y - air.startY > CONFIG.MaxRise then
			flag(player, "fly", string.format("rose %.0f studs in the air", pos.Y - air.startY))
			violated = true
		end
	end

	-- spin-fling exploits
	if root.AssemblyAngularVelocity.Magnitude > CONFIG.FlingAngular then
		flag(player, "fling", string.format("spin %.0f", root.AssemblyAngularVelocity.Magnitude))
		root.AssemblyAngularVelocity = Vector3.zero
		violated = true
	end

	if violated then
		rubberband(st, root)
	elseif ground then
		st.lastGood = root.CFrame
	end
end

local function watchCharacter(player, character)
	local st = states[player]
	if not st then return end
	st.lastPos, st.window, st.air, st.lastGood = nil, {}, nil, nil
	st.graceUntil = os.clock() + 3
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if lastHealth - health >= 5 then
			logEvent(character, "damage", string.format("-%d hp (%s)", math.floor(lastHealth - health), tostring(character:GetAttribute("LastDamageCause") or "?")))
		end
		lastHealth = health
	end)
	humanoid.Died:Connect(function()
		logEvent(character, "death", tostring(character:GetAttribute("DeathCause") or "died"))
	end)
	character.ChildRemoved:Connect(function(child)
		-- deleting the humanoid client-side is the classic god-mode trick
		if child == humanoid and character.Parent and player.Character == character and lastHealth > 0 then
			flag(player, "humanoid", "Humanoid removed")
		end
	end)
end

local function onPlayerAdded(player)
	-- bans first
	local entry
	if banStore then pcall(function() entry = banStore:GetAsync("u_" .. player.UserId) end) end
	if banActive(entry) then
		player:Kick(banMessage(entry))
		return
	end
	states[player] = newState(player)
	task.spawn(screenAccount, player)
	player.CharacterAdded:Connect(function(character) watchCharacter(player, character) end)
	if player.Character then task.spawn(watchCharacter, player, player.Character) end
	reportRemote:FireClient(player, "key", states[player].key)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end

Players.PlayerRemoving:Connect(function(player)
	local st = states[player]
	if st and st.punishing and st.doBan then
		-- left before the punishment finished
		st.doBan()
	end
	states[player] = nil
end)

-- ===================== client reports & heartbeat =====================

local CLIENT_FLAGS = {hook = true, esp = true, lighting = true, gravity = true, walkspeed = true, jumppower = true, injected = true}

reportRemote.OnServerEvent:Connect(function(player, kind, a, b, c)
	local st = states[player]
	if not st then return end
	if kind == "hello" then
		reportRemote:FireClient(player, "key", st.key)
	elseif kind == "hb" then
		if a ~= st.key or typeof(b) ~= "number" or b <= st.seq then return end
		st.seq = b
		st.lastBeat = os.clock()
		-- desync: where the client says it is vs where the server has it
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if typeof(c) == "Vector3" and root and humanoid and humanoid.Health > 0 and not exempt(character, humanoid)
			and os.clock() > (st.graceUntil or 0) then
			if (c - root.Position).Magnitude > CONFIG.DesyncDistance then
				st.desyncStrikes += 1
				if st.desyncStrikes >= 3 then
					st.desyncStrikes = 0
					flag(player, "desync", string.format("client %.0f studs from server", (c - root.Position).Magnitude))
					rubberband(st, root)
					pcall(function() root:SetNetworkOwner(nil) end)
					task.delay(2, function()
						if root.Parent and player.Parent and not st.punishing then
							pcall(function() root:SetNetworkOwner(player) end)
						end
					end)
				end
			else
				st.desyncStrikes = 0
			end
		end
	elseif kind == "flag" then
		if typeof(a) ~= "string" or not CLIENT_FLAGS[a] then return end
		flag(player, a, typeof(b) == "string" and string.sub(b, 1, 120) or nil)
	end
end)

-- remote flooding across every RemoteEvent in the game
local function watchRemote(remote)
	if not remote:IsA("RemoteEvent") or remote == reportRemote then return end
	remote.OnServerEvent:Connect(function(player)
		local st = states[player]
		if not st then return end
		local now = os.clock()
		if now - st.remoteWindowStart >= 1 then
			st.remoteWindowStart = now
			st.remoteCount = 0
		end
		st.remoteCount += 1
		if st.remoteCount == CONFIG.RemoteSpamPerSecond then
			flag(player, "remotespam", remote.Name)
		end
	end)
end
for _, d in ipairs(ReplicatedStorage:GetDescendants()) do watchRemote(d) end
ReplicatedStorage.DescendantAdded:Connect(watchRemote)

if strikeRemote then
	strikeRemote.OnServerEvent:Connect(function(player)
		logEvent(player.Character, "strike", "swing")
	end)
end

-- ===================== world snapshot for the client lighting check =====================

local function snapshotWorld()
	worldInfo:SetAttribute("ClockTime", Lighting.ClockTime)
	worldInfo:SetAttribute("Brightness", Lighting.Brightness)
	worldInfo:SetAttribute("Ambient", Lighting.Ambient)
	worldInfo:SetAttribute("OutdoorAmbient", Lighting.OutdoorAmbient)
	worldInfo:SetAttribute("GlobalShadows", Lighting.GlobalShadows)
	worldInfo:SetAttribute("FogEnd", Lighting.FogEnd)
	worldInfo:SetAttribute("FogStart", Lighting.FogStart)
	worldInfo:SetAttribute("ExposureCompensation", Lighting.ExposureCompensation)
	worldInfo:SetAttribute("Gravity", workspace.Gravity)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	worldInfo:SetAttribute("AtmosphereDensity", atmosphere and atmosphere.Density or -1)
	worldInfo:SetAttribute("AtmosphereHaze", atmosphere and atmosphere.Haze or -1)
	local names = {}
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then table.insert(names, child.Name) end
	end
	worldInfo:SetAttribute("Effects", table.concat(names, ","))
end

-- ===================== main loop =====================

local accumulator = 0
local worldTimer = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	worldTimer += dt
	if worldTimer >= 0.5 then
		worldTimer = 0
		snapshotWorld()
	end
	if accumulator < CONFIG.SampleInterval then return end
	accumulator = 0
	local now = os.clock()
	recordFrame()
	for player, st in pairs(states) do
		st.score = math.max(0, st.score - CONFIG.ScoreDecayPerSecond * CONFIG.SampleInterval)
		local ok, err = pcall(checkPlayer, player, st, now)
		if not ok then warn("[AntiCheat] " .. tostring(err)) end
		-- the client anti-cheat must keep beating
		if not isAdmin(player) then
			if st.lastBeat and now - st.lastBeat > CONFIG.HeartbeatTimeout then
				player:Kick("Anti-cheat stopped responding (AC-01)")
			elseif not st.lastBeat and now - st.joinedAt > CONFIG.FirstHeartbeatTimeout then
				player:Kick("Anti-cheat did not start (AC-02)")
			end
		end
	end
end)

-- ===================== admin =====================

local function readBanIndex()
	local list
	if banStore then pcall(function() list = banStore:GetAsync("index") end) end
	return list or {}
end

local function readIncidentIndex()
	local list
	if incidentStore then pcall(function() list = incidentStore:GetAsync("index") end) end
	list = list or {}
	local seen = {}
	for _, meta in ipairs(list) do seen[meta.id] = true end
	for _, meta in ipairs(incidentIndexCache) do
		if not seen[meta.id] then table.insert(list, 1, meta) end
	end
	return list
end

local ADMIN = {}

-- a player in this server by user id, username or display name
local function findOnline(target)
	local id = tonumber(target)
	if id then return Players:GetPlayerByUserId(id) end
	if typeof(target) ~= "string" or target == "" then return nil end
	local lower = target:lower()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Name:lower() == lower or plr.DisplayName:lower() == lower then return plr end
	end
	return nil
end

function ADMIN.ListBans()
	return true, readBanIndex()
end

function ADMIN.Ban(admin, target, reason, durationText, allDevices)
	local seconds = parseDuration(durationText)
	if not seconds then return false, "bad duration (use 30m, 12h, 7d, 2w or perm)" end
	if typeof(reason) ~= "string" or reason:gsub("%s", "") == "" then reason = "No reason given" end
	local userId, name = tonumber(target), nil
	if not userId then
		if typeof(target) ~= "string" or target == "" then return false, "no target" end
		local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(target) end)
		if not ok or not id then return false, "user not found" end
		userId, name = id, target
	end
	if CONFIG.Admins[userId] then return false, "can't ban an admin" end
	if not name then
		local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		name = ok and n or tostring(userId)
	end
	local entry = ban(userId, name, reason, seconds, allDevices == true, admin.Name, "admin")
	return true, string.format("%s banned for %s", entry.name, formatDuration(seconds))
end

function ADMIN.Unban(admin, userId)
	userId = tonumber(userId)
	if not userId then return false, "bad user id" end
	local entry = unban(userId, admin.Name)
	return true, (entry.name or tostring(userId)) .. " unbanned"
end

function ADMIN.Kick(admin, userId, reason)
	local plr = findOnline(userId)
	if not plr then return false, "player is not in this server" end
	plr:Kick(typeof(reason) == "string" and reason ~= "" and reason or "Kicked by an admin")
	return true, plr.Name .. " kicked"
end

function ADMIN.ListIncidents()
	return true, readIncidentIndex()
end

function ADMIN.GetIncident(admin, id)
	if typeof(id) ~= "string" then return false, "bad id" end
	local cached = incidentCache[id]
	if cached then return true, cached end
	local data
	if incidentStore then pcall(function() data = incidentStore:GetAsync("i_" .. id) end) end
	if not data then return false, "incident not found" end
	return true, data
end

function ADMIN.DeleteIncident(admin, id)
	if typeof(id) ~= "string" then return false, "bad id" end
	incidentCache[id] = nil
	for i = #incidentIndexCache, 1, -1 do
		if incidentIndexCache[i].id == id then table.remove(incidentIndexCache, i) end
	end
	if incidentStore then
		pcall(function() incidentStore:RemoveAsync("i_" .. id) end)
		pcall(function()
			incidentStore:UpdateAsync("index", function(list)
				list = list or {}
				for i = #list, 1, -1 do
					if list[i].id == id then table.remove(list, i) end
				end
				return list
			end)
		end)
	end
	return true, "incident deleted"
end

function ADMIN.Record(admin, userId)
	local plr = findOnline(userId)
	if not plr or not states[plr] then return false, "player is not in this server" end
	createIncident(plr, "manual recording by " .. admin.Name, "recorded")
	return true, "recording saved in " .. CONFIG.ReplayAfter .. "s"
end

function ADMIN.Punish(admin, userId)
	local plr = findOnline(userId)
	if not plr or not states[plr] then return false, "player is not in this server" end
	if isAdmin(plr) then return false, "can't punish an admin" end
	punish(plr, "manual by " .. admin.Name)
	return true, plr.Name .. " is being punished"
end

local lastAdminCall = {}
adminRemote.OnServerInvoke = function(player, action, ...)
	if not isAdmin(player) then return false, "not an admin" end
	local now = os.clock()
	if now - (lastAdminCall[player] or 0) < 0.2 then return false, "slow down" end
	lastAdminCall[player] = now
	local handler = typeof(action) == "string" and ADMIN[action]
	if not handler then return false, "unknown action" end
	local ok, result, payload = pcall(handler, player, ...)
	if not ok then return false, "error: " .. tostring(result) end
	return result, payload
end
Players.PlayerRemoving:Connect(function(player) lastAdminCall[player] = nil end)
