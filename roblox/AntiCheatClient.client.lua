-- Client half of the anti-cheat: heartbeat, lighting/gravity guard, ESP and injector signs.
-- Nothing here bans on its own; it reports to the server, which scores and decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local LogService = game:GetService("LogService")

local player = Players.LocalPlayer
local report = ReplicatedStorage:WaitForChild("ACReport", 60)
local world = ReplicatedStorage:WaitForChild("AC_World", 60)
if not report then return end

local key = nil
local seq = 0
report.OnClientEvent:Connect(function(kind, value)
	if kind == "key" then key = value end
end)
report:FireServer("hello")

local lastFlag = {}
local function flag(kind, detail)
	local now = os.clock()
	if now - (lastFlag[kind] or -math.huge) < 2 then return end
	lastFlag[kind] = now
	report:FireServer("flag", kind, detail)
end

-- ===== heartbeat =====
task.spawn(function()
	while true do
		task.wait(2)
		if not key then
			report:FireServer("hello")
		else
			seq += 1
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			report:FireServer("hb", key, seq, root and root.Position or nil)
		end
	end
end)

-- ===== core functions must still be native =====
local NATIVE = {
	print = print, warn = warn, error = error, pcall = pcall, tostring = tostring, typeof = typeof,
	require = require, setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget,
	["Instance.new"] = Instance.new, ["task.spawn"] = task.spawn, ["debug.info"] = debug.info,
	["game.GetService"] = game.GetService, ["game.FindFirstChild"] = game.FindFirstChild,
	["workspace.Raycast"] = workspace.Raycast, ["Instance.Destroy"] = game.Destroy,
}
local function checkHooks()
	for name, fn in pairs(NATIVE) do
		local ok, source = pcall(debug.info, fn, "s")
		if ok and source ~= "[C]" then
			flag("hook", name)
			return
		end
	end
	-- a hooked __namecall usually changes this error message or adds frames to it
	local ok, err = pcall(function() return game:AC_NotARealMethod() end)
	if ok or not string.find(tostring(err), "AC_NotARealMethod", 1, true) then flag("hook", "__namecall") end
end

-- ===== executor / script-hub traces in the client log =====
local SIGNS = {
	"synapse", "krnl", "fluxus", "script-ware", "scriptware", "electron", "celery", "solara", "wave executor",
	"xeno", "hydrogen", "codex", "arceus", "delta executor", "infinite yield", "dark dex", "dex explorer",
	"simplespy", "remotespy", "remote spy", "hydroxide", "owl hub", "vape", "unnamed esp", "aimbot",
	"getgenv", "hookmetamethod", "hookfunction",
}
local function scanMessage(message)
	local lower = string.lower(tostring(message))
	for _, sign in ipairs(SIGNS) do
		if string.find(lower, sign, 1, true) then
			flag("injected", sign)
			return
		end
	end
end
LogService.MessageOut:Connect(scanMessage)
pcall(function()
	for _, entry in ipairs(LogService:GetLogHistory()) do scanMessage(entry.message) end
end)

-- ===== ESP: highlights / boxes / labels stuck on other players =====
local OURS = {"^GS_", "^Horror", "^AC_"}
local function ours(inst)
	for _, pattern in ipairs(OURS) do
		if string.find(inst.Name, pattern) then return true end
	end
	return false
end
local function isEspClass(inst)
	return inst:IsA("Highlight") or inst:IsA("HandleAdornment") or inst:IsA("SelectionBox")
		or inst:IsA("SelectionSphere") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui")
end
local function otherCharacter(inst)
	if not inst then return nil end
	local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
	while model do
		local plr = Players:GetPlayerFromCharacter(model)
		if plr then return plr ~= player and model or nil end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end
local function checkEsp(inst)
	if not isEspClass(inst) or ours(inst) then return end
	task.defer(function()
		if not inst.Parent then return end
		local adornee = nil
		pcall(function() adornee = inst.Adornee end)
		if otherCharacter(inst) or otherCharacter(adornee) then
			flag("esp", inst.ClassName .. " " .. inst.Name)
			pcall(function() inst:Destroy() end)
		end
	end)
end
workspace.DescendantAdded:Connect(checkEsp)
player:WaitForChild("PlayerGui").DescendantAdded:Connect(checkEsp)

-- ===== lighting and gravity must match the server =====
local function colorOff(a, b)
	return math.abs(a.R - b.R) > 0.12 or math.abs(a.G - b.G) > 0.12 or math.abs(a.B - b.B) > 0.12
end
local EFFECT_OK = {"^Fall", "^LowHealth", "^GS_", "^Horror"}
local mismatch = 0
local function checkWorld()
	if not world or world:GetAttribute("ClockTime") == nil then return end
	local bad = {}
	local clock = math.abs(Lighting.ClockTime - world:GetAttribute("ClockTime")) % 24
	if math.min(clock, 24 - clock) > 0.75 then table.insert(bad, "ClockTime") end
	if math.abs(Lighting.Brightness - world:GetAttribute("Brightness")) > 0.5 then table.insert(bad, "Brightness") end
	if colorOff(Lighting.Ambient, world:GetAttribute("Ambient")) then table.insert(bad, "Ambient") end
	if colorOff(Lighting.OutdoorAmbient, world:GetAttribute("OutdoorAmbient")) then table.insert(bad, "OutdoorAmbient") end
	if Lighting.GlobalShadows ~= world:GetAttribute("GlobalShadows") then table.insert(bad, "GlobalShadows") end
	local fog = world:GetAttribute("FogEnd")
	if math.abs(Lighting.FogEnd - fog) > math.max(50, fog * 0.2) then table.insert(bad, "FogEnd") end
	if math.abs(Lighting.ExposureCompensation - world:GetAttribute("ExposureCompensation")) > 0.3 then table.insert(bad, "Exposure") end
	local density = world:GetAttribute("AtmosphereDensity")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if density and density >= 0 and (not atmosphere or math.abs(atmosphere.Density - density) > 0.08) then
		table.insert(bad, "Atmosphere")
	end
	if math.abs(workspace.Gravity - world:GetAttribute("Gravity")) > 1 then
		workspace.Gravity = world:GetAttribute("Gravity")
		flag("gravity", string.format("%.0f", workspace.Gravity))
	end
	-- post effects the server never made (except our own local ones)
	local serverEffects = {}
	for name in string.gmatch(world:GetAttribute("Effects") or "", "[^,]+") do serverEffects[name] = true end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") and not serverEffects[child.Name] then
			local allowed = false
			for _, pattern in ipairs(EFFECT_OK) do
				if string.find(child.Name, pattern) then allowed = true break end
			end
			if not allowed then
				table.insert(bad, "effect " .. child.Name)
				child:Destroy()
			end
		end
	end

	if #bad == 0 then
		mismatch = 0
		return
	end
	mismatch += 1
	if mismatch < 3 then return end
	mismatch = 0
	-- put the server's values back
	Lighting.ClockTime = world:GetAttribute("ClockTime")
	Lighting.Brightness = world:GetAttribute("Brightness")
	Lighting.Ambient = world:GetAttribute("Ambient")
	Lighting.OutdoorAmbient = world:GetAttribute("OutdoorAmbient")
	Lighting.GlobalShadows = world:GetAttribute("GlobalShadows")
	Lighting.FogEnd = world:GetAttribute("FogEnd")
	Lighting.FogStart = world:GetAttribute("FogStart")
	Lighting.ExposureCompensation = world:GetAttribute("ExposureCompensation")
	if density and density >= 0 then
		if not atmosphere then
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Name = "HorrorAtmosphere"
			atmosphere.Parent = Lighting
		end
		atmosphere.Density = density
		atmosphere.Haze = world:GetAttribute("AtmosphereHaze")
	end
	flag("lighting", table.concat(bad, ", "))
end

-- ===== humanoid values the game never uses =====
local function checkHumanoid()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if humanoid.WalkSpeed > 26 then
		flag("walkspeed", string.format("%.0f", humanoid.WalkSpeed))
		humanoid.WalkSpeed = 16
	end
	if humanoid.UseJumpPower and humanoid.JumpPower > 60 then
		flag("jumppower", string.format("%.0f", humanoid.JumpPower))
		humanoid.JumpPower = 50
	elseif not humanoid.UseJumpPower and humanoid.JumpHeight > 12 then
		flag("jumppower", string.format("height %.0f", humanoid.JumpHeight))
		humanoid.JumpHeight = 7.2
	end
end

task.spawn(function()
	local tick = 0
	while true do
		task.wait(1)
		tick += 1
		pcall(checkWorld)
		pcall(checkHumanoid)
		if tick % 5 == 0 then pcall(checkHooks) end
	end
end)
