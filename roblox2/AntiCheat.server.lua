-- Server anti-cheat: movement checks, account screening, bans, incident replays, punishment.
-- Everything a player sees from here is in English.
-- Fewer false kicks and bans (this version):
--   * only proof a normal client can never produce bans on its own: a honeypot remote, an admin remote
--   * what the client reports about itself (hooks, log traces, ESP, movers, lighting, camera, collision) and the
--     decoys are evidence for the admins (an incident with a replay), never a kick or a ban by themselves
--   * movement oddities rubberband the player; only a long run of them kicks, and a kick never turns into a ban
--   * lag is not cheating: catching up after a freeze, fast falls, knockback, traps and webs are allowed for
--   * the heartbeat only kicks a client that keeps moving while its anti-cheat is silent (a phone put in the
--     background, or a slow load, is left alone)
--   * automatic bans last AutoBanSeconds; the admin makes it permanent (or clears it) on the replay
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
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
	UserSearchApi = "https://users.roproxy.com/v1/users/search?keyword=%s&limit=10",
	ScreenWhitelist = {},
	SuspiciousMessage = "Suspicious account",

	-- movement
	SampleInterval = 0.1,
	SpeedAllowanceMult = 1.6,
	SpeedAllowanceFlat = 8,
	SpeedStrikes = 4, -- samples in a row over the limit before it counts (a burst of knockback never does)
	TeleportDistance = 40,
	HoverTime = 2,
	MaxRise = 14,
	FlingAngular = 200,
	DesyncDistance = 25,
	RemoteSpamPerSecond = 120,
	HeartbeatTimeout = 60,
	FirstHeartbeatTimeout = 180,
	SilentMoveDistance = 150, -- a silent client must also move this far before it is kicked

	-- scoring: every flag adds points, points decay over time
	ScoreDecayPerSecond = 0.35,
	IncidentScore = 8,
	PunishScore = 25, -- hard proof (honeypot / admin remote): paralyse, kill, ban
	KickScore = 45, -- movement only: a kick, never a ban
	Points = {
		speed = 2, teleport = 5, fly = 4, noclip = 4, desync = 3, fling = 8, humanoid = 30, remotespam = 10,
		hook = 6, esp = 5, lighting = 1, gravity = 5, walkspeed = 5, jumppower = 5, injected = 8,
		honeypot = 30, remoteabuse = 12, launch = 5, inside = 3, bodymover = 8, collision = 5, camera = 3, decoy = 6,
	},

	-- punishment
	PunishKillDelay = 20,
	AutoBanSeconds = 7 * 86400, -- the admin makes it permanent (or clears it) with the verdict on the replay
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

local banStore, incidentStore, dossierStore
pcall(function() banStore = DataStoreService:GetDataStore("AC_Bans_v1") end)
pcall(function() incidentStore = DataStoreService:GetDataStore("AC_Incidents_v1") end)
pcall(function() dossierStore = DataStoreService:GetDataStore("AC_Dossier_v1") end)
local BAN_TOPIC = "AC_Bans_v1"

-- DataStore calls fail now and then; bans and dossiers must not be lost to a hiccup
local function retry(fn, attempts)
	for i = 1, attempts or 3 do
		local ok, result = pcall(fn)
		if ok then return true, result end
		if i < (attempts or 3) then task.wait(0.6 * i) end
	end
	return false, nil
end

local function serverNow() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end

-- admins (and the place owner) are never checked, flagged, punished or banned by the anti-cheat
local function isAdminId(userId)
	userId = tonumber(userId)
	if not userId then return false end
	if CONFIG.Admins[userId] then return true end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == userId
end

local function isAdmin(player)
	return isAdminId(player.UserId) or player:GetAttribute("IsAdmin") == true
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

local recordDossier
local function ban(userId, name, reason, seconds, allDevices, by, source, incidentId)
	local online = Players:GetPlayerByUserId(userId)
	if isAdminId(userId) or (online and isAdmin(online)) then
		warn("[AntiCheat] refused to ban admin " .. tostring(name or userId))
		return nil
	end
	local entry = {
		userId = userId, name = name or tostring(userId), reason = reason, by = by, source = source,
		at = os.time(), expires = seconds < 0 and -1 or os.time() + seconds, duration = seconds,
		allDevices = allDevices, incident = incidentId, active = true,
	}
	local saved = banStore and retry(function() banStore:SetAsync("u_" .. userId, entry) end, 4)
	updateIndex(entry)
	-- Roblox's own ban API: works in live servers (not in Studio) and adds alt-account detection
	entry.robloxBan = pcall(function()
		Players:BanAsync({
			UserIds = {userId}, ApplyToUniverse = true, Duration = seconds < 0 and -1 or seconds,
			DisplayReason = string.sub(reason, 1, 380), PrivateReason = string.sub(source .. " / " .. tostring(by) .. ": " .. reason, 1, 900),
			ExcludeAltAccounts = not allDevices,
		})
	end)
	-- every other server kicks them right now too
	pcall(function() MessagingService:PublishAsync(BAN_TOPIC, {op = "ban", userId = userId, message = banMessage(entry)}) end)
	if recordDossier then task.spawn(recordDossier, userId, name, nil, {ban = {at = entry.at, reason = reason, by = by, expires = entry.expires}}) end
	if not saved then warn("[AntiCheat] ban for " .. tostring(userId) .. " could not be saved to the DataStore") end
	if online then online:Kick(banMessage(entry)) end
	forAdmins(function(admin)
		alertRemote:FireClient(admin, "ban", string.format("%s banned (%s) — %s", entry.name, formatDuration(seconds), reason))
	end)
	return entry
end

local function robloxUnban(userId)
	-- Studio silently skips UnbanAsync ("will succeed on production game servers"), so there it never counts
	if RunService:IsStudio() then return false end
	return (pcall(function() Players:UnbanAsync({UserIds = {userId}, ApplyToUniverse = true}) end))
end

local function unban(userId, by)
	local entry
	if banStore then
		retry(function() entry = banStore:GetAsync("u_" .. userId) end)
	end
	entry = entry or {userId = userId, name = tostring(userId), reason = "?", at = os.time(), expires = -1}
	entry.active = false
	entry.unbannedBy = by
	entry.unbannedAt = os.time()
	-- Roblox's own ban can only be lifted from a live server; if that fails here, live servers finish the job
	entry.robloxUnbanPending = not robloxUnban(userId) or nil
	local saved = banStore and retry(function() banStore:SetAsync("u_" .. userId, entry) end, 4)
	updateIndex(entry)
	pcall(function() MessagingService:PublishAsync(BAN_TOPIC, {op = "unban", userId = userId}) end)
	if recordDossier then task.spawn(recordDossier, userId, entry.name, nil, {unban = {at = entry.unbannedAt, by = by}}) end
	return entry, saved
end

-- read a ban record, retrying; nil + false when the DataStore could not be reached
local function readBan(userId)
	if not banStore then return nil, false end
	local ok, entry = retry(function() return banStore:GetAsync("u_" .. userId) end, 3)
	return entry, ok
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
				-- (decoys have no MonsterId and never show up in replays)
				if model:IsA("Model") and (folderName ~= "Monsters" or model:GetAttribute("MonsterId")) then add(model) end
			end
		end
	end
	table.insert(frames, {t = serverNow(), e = entities})
	local cutoff = serverNow() - CONFIG.RecordSeconds
	while frames[1] and frames[1].t < cutoff do table.remove(frames, 1) end
end

local rememberPlayer
local incidentCache = {}

-- ===================== seen players (for name suggestions) =====================
local seenStore
pcall(function() seenStore = DataStoreService:GetDataStore("AC_Seen_v1") end)
local seenCache, seenCacheAt = nil, -math.huge

function rememberPlayer(player)
	if not seenStore then return end
	local entry = {userId = player.UserId, name = player.Name, displayName = player.DisplayName, last = os.time()}
	pcall(function()
		seenStore:UpdateAsync("index", function(list)
			list = list or {}
			for i = #list, 1, -1 do
				if list[i].userId == entry.userId then table.remove(list, i) end
			end
			table.insert(list, 1, entry)
			while #list > 1500 do table.remove(list) end
			return list
		end)
	end)
	seenCacheAt = -math.huge
end

local function seenPlayers()
	if seenCache and os.clock() - seenCacheAt < 60 then return seenCache end
	local list
	if seenStore then pcall(function() list = seenStore:GetAsync("index") end) end
	seenCache, seenCacheAt = list or seenCache or {}, os.clock()
	return seenCache
end
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

-- Hard proof: things only an exploit ever does (a remote nothing in the game fires, an admin remote from a
-- non-admin). That alone may ban.
local HARD_FLAGS = {honeypot = true, remoteabuse = true}
-- Evidence only: the client reports these about itself (a slow phone, an odd GPU driver, other software in the
-- log can all trip them) and the decoys can be walked into by chance. They go to the admins as incidents with
-- a replay and never kick or ban by themselves.
local EVIDENCE_ONLY = {
	hook = true, esp = true, lighting = true, gravity = true, walkspeed = true, jumppower = true, injected = true,
	bodymover = true, collision = true, camera = true, decoy = true,
}

local function flag(player, kind, detail)
	local st = states[player]
	if not st or st.punishing then return end
	if isAdmin(player) then return end -- admins are never flagged
	local now = os.clock()
	if now - (st.flagLast[kind] or -math.huge) < 0.45 then return end
	st.flagLast[kind] = now
	st.flagCounts[kind] = (st.flagCounts[kind] or 0) + 1
	local points = (CONFIG.Points[kind] or 3) * (st.trusted and 0.5 or 1)
	st.dossierFlags = st.dossierFlags or {}
	st.dossierFlags[kind] = (st.dossierFlags[kind] or 0) + 1
	local text = kind .. (detail and (": " .. detail) or "")
	logEvent(player.Character, "flag", text)
	st.lastReason = text
	if EVIDENCE_ONLY[kind] then
		st.evidence = (st.evidence or 0) + points
		if st.evidence >= CONFIG.IncidentScore and now - st.lastIncidentAt > 90 then
			st.lastIncidentAt = now
			st.evidence = 0
			createIncident(player, text, "recorded")
		end
		return
	end
	if HARD_FLAGS[kind] then st.hardFlag = kind end
	st.score += points
	st.maxScore = math.max(st.maxScore or 0, st.score)
	if st.hardFlag and st.score >= CONFIG.PunishScore then
		punish(player, text)
	elseif st.score >= CONFIG.KickScore then
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
	if recordDossier then
		task.spawn(recordDossier, player.UserId, player.Name, player.DisplayName,
			{incident = {id = meta.id, reason = reason, action = action, at = meta.at, server = string.sub(game.JobId, 1, 8), score = meta.score}})
	end
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
	if not st or st.punishing or isAdmin(player) then return end
	-- movement-only evidence: pull them out of the server, never a ban (the kicks are counted in the dossier,
	-- the admins see the replays and can ban by hand)
	if not st.hardFlag then
		st.punishing = true
		local meta = createIncident(player, reason, "kicked")
		if recordDossier then
			task.spawn(recordDossier, player.UserId, player.Name, player.DisplayName, {kick = {at = os.time(), reason = reason, id = meta.id}})
		end
		task.delay(1, function()
			if player.Parent then
				player:Kick("Disconnected by the anti-cheat: " .. reason .. "\nIf this was a mistake, just rejoin.")
			end
		end)
		return
	end
	st.punishing = true
	local token = {}
	st.punishToken = token
	player:SetAttribute("AC_Punished", true)
	local meta = createIncident(player, reason, "punished")
	local function doBan()
		if st.banned or st.punishToken ~= token then return end
		st.banned = true
		local why = reason
		ban(player.UserId, player.Name, "Exploiting (" .. why .. ")", CONFIG.AutoBanSeconds, CONFIG.AutoBanAllDevices,
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
		if st.punishToken ~= token then return end
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
	-- walls the player's collision group passes through are not walls for this player
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then pcall(function() params.CollisionGroup = root.CollisionGroup end) end
	return params
end

local function groundParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = false
	params.FilterDescendantsInstances = {character}
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then pcall(function() params.CollisionGroup = root.CollisionGroup end) end
	return params
end

-- is a point truly inside a solid block (checked against the part's real, rotated shape)?
local function pointInsideSolid(point, character, margin)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = worldParams(character).FilterDescendantsInstances
	overlap.RespectCanCollide = true
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then pcall(function() overlap.CollisionGroup = root.CollisionGroup end) end
	for _, part in ipairs(workspace:GetPartBoundsInRadius(point, 0.1, overlap)) do
		-- only plain blocks: wedges, meshes and unions have shapes a bounding box can't describe
		if part.Anchored and part.CanCollide and part.ClassName == "Part" and part.Shape == Enum.PartType.Block then
			local size = part.Size
			if math.min(size.X, size.Y, size.Z) > margin * 2 + 0.4 then
				local p = part.CFrame:PointToObjectSpace(point)
				if math.abs(p.X) < size.X / 2 - margin and math.abs(p.Y) < size.Y / 2 - margin and math.abs(p.Z) < size.Z / 2 - margin then
					return part
				end
			end
		end
	end
	return nil
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
	local now = serverNow()
	local tp = character:GetAttribute("AC_TeleportAt")
	if tp and now - tp < 3 then return true end
	-- held in place by the game: a bear trap, a web, a baton shock
	local trapped = character:GetAttribute("GS_Trapped")
	if typeof(trapped) == "number" and trapped > now - 1 then return true end
	if (character:GetAttribute("GS_WebStun") or 0) > now - 1 then return true end
	local shocked = character:GetAttribute("GS_Shocked")
	if shocked and now - shocked < 3 then return true end
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
	local walk = math.max(humanoid.WalkSpeed, 16) * math.max(1, tonumber(character:GetAttribute("GS_CarrySpeed")) or 1)

	-- lag: a client that froze (no new positions) catches up in one jump. That is only as far as it could have
	-- walked in the time it was frozen, and the speed window starts over afterwards.
	local frozenFor = now - (st.lastMovedAt or now)
	if delta.Magnitude > 0.05 then
		st.lastMovedAt = now
		if frozenFor > 0.5 then st.window = {} end
	end
	local catchUp = walk * CONFIG.SpeedAllowanceMult * (frozenFor + CONFIG.SampleInterval) + CONFIG.SpeedAllowanceFlat

	-- teleport
	if flat(delta).Magnitude > math.max(CONFIG.TeleportDistance, catchUp) or delta.Y > 25 then
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
				inside = pointInsideSolid(pos, character, 0.3) == forward.Instance
			end
			if back or inside then
				flag(player, "noclip", forward.Instance:GetFullName())
				rubberband(st, root)
				return
			end
		end
	end

	-- standing inside a wall for several ticks in a row (noclip that never "passes" a surface)
	-- (the body's centre, not its edges: lying down, crawling under things or brushing a wall never count)
	do
		local head = character:FindFirstChild("Head")
		local wall = pointInsideSolid(root.Position, character, 0.35)
		if wall and head then
			-- the head must be buried too, and in the same wall
			wall = pointInsideSolid(head.Position, character, 0.2) == wall and wall or nil
		end
		st.insideTicks = wall and (st.insideTicks or 0) + 1 or 0
		if st.insideTicks >= 10 then
			st.insideTicks = 0
			flag(player, "inside", "inside " .. wall:GetFullName())
			rubberband(st, root)
			return
		end
	end

	-- shooting straight up far faster than any jump can
	do
		local jumpV = humanoid.UseJumpPower and humanoid.JumpPower or math.sqrt(2 * workspace.Gravity * math.max(humanoid.JumpHeight, 0))
		local vy = root.AssemblyLinearVelocity.Y
		if vy > jumpV * 1.6 + 25 then
			st.launchTicks = (st.launchTicks or 0) + 1
			if st.launchTicks >= 3 then
				st.launchTicks = 0
				flag(player, "launch", string.format("rising at %.0f studs/s", vy))
				violated = true
			end
		else
			st.launchTicks = 0
		end
	end

	-- speed over a one second window
	table.insert(st.window, {t = now, p = pos})
	while st.window[1] and now - st.window[1].t > 1.05 do table.remove(st.window, 1) end
	local oldest = st.window[1]
	local span = now - oldest.t
	if span > 0.9 then
		local dist = flat(pos - oldest.p).Magnitude
		local allowed = (walk * CONFIG.SpeedAllowanceMult + CONFIG.SpeedAllowanceFlat) * span
		if dist > allowed then
			st.speedStrikes = (st.speedStrikes or 0) + 1
			if st.speedStrikes >= CONFIG.SpeedStrikes then
				st.speedStrikes = 0
				flag(player, "speed", string.format("%.0f studs/s", dist / span))
				violated = true
			end
		else
			st.speedStrikes = 0
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
		-- (a body the game itself is swapping out is gone or replaced a moment later: that one doesn't count)
		if child == humanoid and character.Parent and player.Character == character and lastHealth > 0 then
			task.delay(1.5, function()
				if character.Parent and player.Character == character and not character:FindFirstChildOfClass("Humanoid") then
					flag(player, "humanoid", "Humanoid removed")
				end
			end)
		end
	end)
end

local function onPlayerAdded(player)
	-- bans first (retried; if the DataStore is down the periodic sweep checks again)
	local entry, reached = readBan(player.UserId)
	if banActive(entry) then
		if isAdmin(player) then
			-- an admin can never stay banned: clear whatever banned them
			task.spawn(unban, player.UserId, "auto (admin)")
		else
			player:Kick(banMessage(entry))
			return
		end
	end
	if not reached then player:SetAttribute("AC_BanUnchecked", true) end
	states[player] = newState(player)
	-- how many times the anti-cheat already kicked them (from every server) decides kick vs ban
	task.spawn(function()
		if not dossierStore or isAdmin(player) then return end
		local d
		retry(function() d = dossierStore:GetAsync("d_" .. player.UserId) end)
		local st = states[player]
		if st and d then st.priorKicks = d.kicks or 0 end
	end)
	task.spawn(rememberPlayer, player)
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
	if st and st.dossierFlags and next(st.dossierFlags) and recordDossier then
		local userId, name, displayName = player.UserId, player.Name, player.DisplayName
		task.spawn(recordDossier, userId, name, displayName, nil)
	end
	states[player] = nil
end)

-- ===================== client reports & heartbeat =====================

local CLIENT_FLAGS = {
	hook = true, esp = true, lighting = true, gravity = true, walkspeed = true, jumppower = true, injected = true,
	bodymover = true, collision = true, camera = true,
}

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
			local allowedGap = CONFIG.DesyncDistance + root.AssemblyLinearVelocity.Magnitude * 0.6
			if (c - root.Position).Magnitude > allowedGap then
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

-- ===================== honeypots & remote abuse =====================
-- Remotes the game never uses, named like the ones exploit scripts go looking for.
-- Only a remote spy / exploit script ever fires them.
local HONEYPOTS = {"AdminRemote", "GiveMoney", "DamagePlayer", "KillPlayer", "SetWalkSpeed", "TeleportRemote", "BanPlayer"}
local honeypotFolder = ensure(ReplicatedStorage, "Folder", "Remotes")
for _, name in ipairs(HONEYPOTS) do
	local remote = ensure(honeypotFolder, "RemoteEvent", name)
	remote.OnServerEvent:Connect(function(player)
		if not isAdmin(player) then flag(player, "honeypot", name) end
	end)
	local fn = ensure(honeypotFolder, "RemoteFunction", name .. "Function")
	fn.OnServerInvoke = function(player)
		if not isAdmin(player) then flag(player, "honeypot", fn.Name) end
		return nil
	end
end
-- the admin remotes: a normal player's client never shows the admin UI, so it never fires them
task.spawn(function()
	local adminAction = ReplicatedStorage:WaitForChild("AdminAction", 30)
	if adminAction then
		adminAction.OnServerEvent:Connect(function(player)
			if not isAdmin(player) then flag(player, "remoteabuse", "AdminAction") end
		end)
	end
end)

-- ===================== anti-ESP decoys =====================
-- Roblox can't hide an instance from one client and not another, and ESP drawn through the executor's
-- own UI can't be seen by any script (DevForum consensus). What we can do is poison what ESP shows:
-- invisible fake creatures, named exactly like the real ones, wander the map inside the Monsters folder.
-- A normal player never sees them; an ESP user sees creatures everywhere and can't tell which are real.
-- Anyone who walks right up to a decoy again and again is following something only ESP shows.
local DECOY_COUNT = 5
local decoys = {}
local okData, MonsterDataModule = pcall(require, Modules:WaitForChild("MonsterData", 10))
local DECOY_NAMES = okData and MonsterDataModule and MonsterDataModule.Order or {"D-130", "B-414", "A-013", "C-207"}

local function decoyGround(center, radius)
	for _ = 1, 8 do
		local angle = math.random() * math.pi * 2
		local r = math.random() * radius
		local origin = center + Vector3.new(math.cos(angle) * r, 200, math.sin(angle) * r)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = {}
		for _, name in ipairs({"Monsters", "NPCs", "Corpses", "SeveredLimbs"}) do
			local f = workspace:FindFirstChild(name)
			if f then table.insert(ignore, f) end
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then table.insert(ignore, plr.Character) end
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
		if hit then return hit.Position + Vector3.new(0, 3, 0) end
	end
	return nil
end

local function buildDecoy(name)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then return nil end
	model.Name = name
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Decal") or d:IsA("Accessory") or d:IsA("Clothing") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Transparency = 1
			d.Anchored = true
			d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
	end
	return model
end

task.spawn(function()
	local monstersFolder = workspace:WaitForChild("Monsters", 120)
	if not monstersFolder then return end
	local center = Vector3.zero
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
	if spawn then center = spawn.Position end
	while true do
		for i = 1, DECOY_COUNT do
			local d = decoys[i]
			if not d or not d.model.Parent then
				local model = buildDecoy(DECOY_NAMES[(i - 1) % #DECOY_NAMES + 1])
				local spot = model and decoyGround(center, 350)
				if model and spot then
					model:PivotTo(CFrame.new(spot))
					model.Parent = monstersFolder
					decoys[i] = {model = model, goal = spot, near = {}}
				elseif model then
					model:Destroy()
				end
			end
			d = decoys[i]
			if d and d.model.Parent then
				-- wander like a creature would
				local pos = d.model:GetPivot().Position
				if (d.goal - pos).Magnitude < 3 or math.random() < 0.02 then
					d.goal = decoyGround(pos, 60) or d.goal
				end
				local step = d.goal - pos
				local move = step.Magnitude > 0 and step.Unit * math.min(step.Magnitude, 5) or Vector3.zero
				local nextPos = pos + move
				local flatMove = Vector3.new(move.X, 0, move.Z)
				d.model:PivotTo(flatMove.Magnitude > 0.01 and CFrame.lookAt(nextPos, nextPos + flatMove) or CFrame.new(nextPos))
				-- who keeps ending up right next to something nobody can see?
				for _, plr in ipairs(Players:GetPlayers()) do
					local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if root and not isAdmin(plr) and (root.Position - nextPos).Magnitude < 6 then
						local last = d.near[plr]
						if not last or os.clock() - last > 20 then
							d.near[plr] = os.clock()
							local st = states[plr]
							if st then
								st.decoyTouches = (st.decoyTouches or 0) + 1
								if st.decoyTouches >= 4 then
									st.decoyTouches = 0
									flag(plr, "decoy", "kept walking up to invisible decoys")
								end
							end
						end
					end
				end
			end
		end
		task.wait(0.5)
	end
end)

-- ===================== bans across servers =====================
-- live servers lift any Roblox-level ban that ever landed on an admin
if not RunService:IsStudio() then
	task.spawn(function()
		local ids = {}
		for id in pairs(CONFIG.Admins) do table.insert(ids, id) end
		if game.CreatorType == Enum.CreatorType.User then table.insert(ids, game.CreatorId) end
		for _, id in ipairs(ids) do robloxUnban(id) end
	end)
end
pcall(function()
	MessagingService:SubscribeAsync(BAN_TOPIC, function(message)
		local data = message.Data
		if typeof(data) ~= "table" or data.op ~= "ban" then return end
		local plr = Players:GetPlayerByUserId(tonumber(data.userId) or 0)
		if plr then plr:Kick(typeof(data.message) == "string" and data.message or "You are banned.") end
	end)
end)

-- every minute: re-check everyone online (catches bans made while a message got lost or the DataStore
-- was down when they joined) and finish Roblox-level unbans that could not run in Studio
task.spawn(function()
	while true do
		task.wait(60)
		for _, plr in ipairs(Players:GetPlayers()) do
			if not isAdmin(plr) then
				local entry, reached = readBan(plr.UserId)
				if banActive(entry) then
					plr:Kick(banMessage(entry))
				elseif reached then
					plr:SetAttribute("AC_BanUnchecked", nil)
				end
			end
		end
		if banStore and not RunService:IsStudio() then
			local list
			pcall(function() list = banStore:GetAsync("index") end)
			for _, entry in ipairs(list or {}) do
				if entry.robloxUnbanPending and robloxUnban(entry.userId) then
					entry.robloxUnbanPending = nil
					pcall(function() banStore:SetAsync("u_" .. entry.userId, entry) end)
					updateIndex(entry)
				end
			end
		end
	end
end)

-- ===================== dossiers: everything the anti-cheat ever noticed about a player, from every server =====================
local DOSSIER_INCIDENTS = 40

function recordDossier(userId, name, displayName, extra)
	if not dossierStore or not userId or isAdminId(userId) then return end
	local plr = Players:GetPlayerByUserId(userId)
	local st = plr and states[plr]
	local flags = st and st.dossierFlags or nil
	local maxScore = st and st.maxScore or 0
	if st then st.dossierFlags, st.maxScore = nil, 0 end
	local hasFlags = flags and next(flags) ~= nil
	if not hasFlags and not extra then return end
	local summary
	retry(function()
		dossierStore:UpdateAsync("d_" .. userId, function(d)
			d = d or {userId = userId, flags = {}, incidents = {}, bans = {}, servers = {}, totalFlags = 0, firstAt = os.time()}
			d.name = name or d.name
			d.displayName = displayName or d.displayName or d.name
			d.lastAt = os.time()
			for kind, n in pairs(flags or {}) do
				d.flags[kind] = (d.flags[kind] or 0) + n
				d.totalFlags += n
			end
			d.maxScore = math.max(d.maxScore or 0, math.floor(maxScore))
			local server = string.sub(game.JobId ~= "" and game.JobId or "studio", 1, 8)
			if hasFlags and not table.find(d.servers, server) then
				table.insert(d.servers, 1, server)
				while #d.servers > 20 do table.remove(d.servers) end
			end
			if extra and extra.incident then
				table.insert(d.incidents, 1, extra.incident)
				while #d.incidents > DOSSIER_INCIDENTS do table.remove(d.incidents) end
			end
			if extra and extra.ban then
				table.insert(d.bans, 1, extra.ban)
				d.banned = true
			end
			if extra and extra.unban then
				table.insert(d.bans, 1, {at = extra.unban.at, reason = "unbanned", by = extra.unban.by, unban = true})
				d.banned = false
			end
			if extra and extra.kick then
				d.kicks = (d.kicks or 0) + 1
				table.insert(d.bans, 1, {at = extra.kick.at, reason = "kicked: " .. tostring(extra.kick.reason), by = "AntiCheat", kick = true})
			end
			if extra and extra.verdict then
				d.verdicts = d.verdicts or {}
				table.insert(d.verdicts, 1, extra.verdict)
				while #d.verdicts > 20 do table.remove(d.verdicts) end
			end
			while #d.bans > 20 do table.remove(d.bans) end
			local top, topN = nil, 0
			for kind, n in pairs(d.flags) do if n > topN then top, topN = kind, n end end
			summary = {
				userId = userId, name = d.name, displayName = d.displayName, lastAt = d.lastAt, totalFlags = d.totalFlags,
				incidents = #d.incidents, banned = d.banned, topFlag = top, servers = #d.servers, kicks = d.kicks or 0,
			}
			return d
		end)
	end, 3)
	if not summary then return end
	retry(function()
		dossierStore:UpdateAsync("index", function(list)
			list = list or {}
			for i = #list, 1, -1 do
				if list[i].userId == userId then table.remove(list, i) end
			end
			table.insert(list, 1, summary)
			while #list > 500 do table.remove(list) end
			return list
		end)
	end, 3)
end

-- flags pile up in memory and are written every 30 seconds (and when the player leaves)
task.spawn(function()
	while true do
		task.wait(30)
		for plr, st in pairs(states) do
			if st.dossierFlags and next(st.dossierFlags) then
				task.spawn(recordDossier, plr.UserId, plr.Name, plr.DisplayName, nil)
			end
		end
	end
end)

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
		st.evidence = math.max(0, (st.evidence or 0) - CONFIG.ScoreDecayPerSecond * 0.5 * CONFIG.SampleInterval)
		local ok, err = pcall(checkPlayer, player, st, now)
		if not ok then warn("[AntiCheat] " .. tostring(err)) end
		-- the client anti-cheat must keep beating. A phone in the background or a slow load stops everything,
		-- the body too: only a client that keeps moving while its anti-cheat is silent has switched it off.
		if not isAdmin(player) then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local silent = (st.lastBeat and now - st.lastBeat > CONFIG.HeartbeatTimeout)
				or (not st.lastBeat and now - st.joinedAt > CONFIG.FirstHeartbeatTimeout)
			if silent and root then
				if st.silentFrom then
					st.silentMoved = (st.silentMoved or 0) + flat(root.Position - st.silentFrom).Magnitude
				end
				st.silentFrom = root.Position
				if (st.silentMoved or 0) > CONFIG.SilentMoveDistance then
					player:Kick(st.lastBeat and "Anti-cheat stopped responding (AC-01)" or "Anti-cheat did not start (AC-02)")
				end
			else
				st.silentFrom, st.silentMoved = nil, 0
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

function ADMIN.Unban(admin, target)
	local userId = tonumber(target)
	if not userId and typeof(target) == "string" and target ~= "" then
		local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(target) end)
		if ok then userId = id end
	end
	if not userId then return false, "user not found" end
	local entry, saved = unban(userId, admin.Name)
	if not saved then return false, "could not reach the ban DataStore — try again" end
	local note = entry.robloxUnbanPending
		and (RunService:IsStudio()
			and " in the game's list. Roblox's own ban can't be lifted from Studio: Creator Hub > your game > Moderation > Bans > Unban, or it is lifted by the next live server"
			or " (Roblox-level unban queued)")
		or ""
	return true, (entry.name or tostring(userId)) .. " unbanned" .. note
end

function ADMIN.ListDossiers()
	local list
	if dossierStore then retry(function() list = dossierStore:GetAsync("index") end) end
	return true, list or {}
end

function ADMIN.GetDossier(admin, target)
	local userId = tonumber(target)
	if not userId then return false, "bad user id" end
	for plr, st in pairs(states) do
		if plr.UserId == userId and st.dossierFlags and next(st.dossierFlags) then
			recordDossier(userId, plr.Name, plr.DisplayName, nil)
		end
	end
	local d
	if dossierStore then retry(function() d = dossierStore:GetAsync("d_" .. userId) end) end
	local entry = readBan(userId)
	local online = Players:GetPlayerByUserId(userId)
	local live = online and states[online]
	return true, {
		dossier = d, ban = entry, banActive = banActive(entry) == true,
		online = online ~= nil, liveScore = live and math.floor(live.score) or nil,
	}
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

-- name suggestions while typing: online players, everyone seen before, ban records, then Roblox itself
function ADMIN.SearchUsers(admin, query)
	if typeof(query) ~= "string" then return false, "bad query" end
	query = query:gsub("^%s+", ""):gsub("%s+$", "")
	if query == "" then return true, {} end
	local lower = query:lower()
	local results, seen = {}, {}
	local function consider(userId, name, displayName, source)
		if not userId or seen[userId] then return end
		local n, d = tostring(name or ""):lower(), tostring(displayName or ""):lower()
		local score
		if n == lower or tostring(userId) == query then score = 5
		elseif n:sub(1, #lower) == lower then score = 4
		elseif d:sub(1, #lower) == lower then score = 3
		elseif n:find(lower, 1, true) or d:find(lower, 1, true) then score = 2
		elseif tostring(userId):sub(1, #query) == query then score = 1 end
		if not score then return end
		if source == "online" then score += 0.5 end
		seen[userId] = true
		table.insert(results, {userId = userId, name = name, displayName = displayName, source = source, score = score})
	end
	for _, plr in ipairs(Players:GetPlayers()) do consider(plr.UserId, plr.Name, plr.DisplayName, "online") end
	for _, entry in ipairs(seenPlayers()) do consider(entry.userId, entry.name, entry.displayName, "seen") end
	for _, entry in ipairs(readBanIndex()) do consider(entry.userId, entry.name, entry.name, "banned") end
	if #results < 8 and #query >= 3 then
		pcall(function()
			local url = string.format(CONFIG.UserSearchApi, HttpService:UrlEncode(query))
			local data = HttpService:JSONDecode(HttpService:GetAsync(url))
			for _, user in ipairs(data.data or {}) do consider(user.id, user.name, user.displayName, "roblox") end
		end)
		if not seen[query] then
			local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(query) end)
			if ok and id then consider(id, query, query, "roblox") end
		end
	end
	table.sort(results, function(a, b) return a.score > b.score end)
	while #results > 8 do table.remove(results) end
	return true, results
end

local function updateIncidentMeta(id, fields)
	local function apply(meta)
		if meta and meta.id == id then
			for k, v in pairs(fields) do meta[k] = v end
		end
	end
	local cached = incidentCache[id]
	if cached then apply(cached.meta) end
	for _, meta in ipairs(incidentIndexCache) do apply(meta) end
	if not incidentStore then return end
	pcall(function()
		incidentStore:UpdateAsync("i_" .. id, function(data)
			if data then apply(data.meta) end
			return data
		end)
	end)
	pcall(function()
		incidentStore:UpdateAsync("index", function(list)
			for _, meta in ipairs(list or {}) do apply(meta) end
			return list
		end)
	end)
end

local function findIncidentMeta(id)
	local cached = incidentCache[id]
	if cached then return cached.meta end
	for _, meta in ipairs(readIncidentIndex()) do
		if meta.id == id then return meta end
	end
	return nil
end

-- the admin watched the replay and decided
function ADMIN.Verdict(admin, id, verdict)
	if typeof(id) ~= "string" then return false, "bad id" end
	local meta = findIncidentMeta(id)
	if not meta then return false, "incident not found" end
	if recordDossier then
		task.spawn(recordDossier, meta.userId, nil, nil, {verdict = {id = id, verdict = verdict, by = admin.Name, at = os.time()}})
	end
	if verdict == "cheat" then
		ban(meta.userId, meta.name, "Cheating (confirmed on replay)", -1, true, admin.Name, "admin", id)
		updateIncidentMeta(id, {verdict = "cheat", verdictBy = admin.Name})
		return true, meta.name .. ": permanent ban on all devices"
	elseif verdict == "legit" then
		local plr = Players:GetPlayerByUserId(meta.userId)
		local st = plr and states[plr]
		if st then
			-- stop a punishment that is still running and undo it
			st.punishToken = nil
			st.punishing = false
			st.banned = false
			st.doBan = nil
			st.score = 0
			st.flagCounts = {}
			st.trusted = true
			plr:SetAttribute("AC_Punished", nil)
			local character = plr.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				character:SetAttribute("Lobotomized", false)
				character:SetAttribute("Injury_Torso", 0)
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
			end
		end
		local entry
		if banStore then pcall(function() entry = banStore:GetAsync("u_" .. meta.userId) end) end
		if banActive(entry) and entry.source == "anticheat" then unban(meta.userId, admin.Name) end
		updateIncidentMeta(id, {verdict = "legit", verdictBy = admin.Name})
		return true, meta.name .. " cleared as legit" .. (st and " and released" or "")
	end
	return false, "bad verdict"
end

local lastAdminCall = {}
adminRemote.OnServerInvoke = function(player, action, ...)
	if not isAdmin(player) then
		flag(player, "remoteabuse", "ACAdmin")
		return false, "not an admin"
	end
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
