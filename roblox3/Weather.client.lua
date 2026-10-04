local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundConfig"))
local GameSettings = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSettings"))
-- low graphics (settings): about a third of the rain, dust and mist, no puddle ripples, fewer ray checks
local function lowGraphics() return GameSettings.Get("LowGraphics") == true end
local player = Players.LocalPlayer

local CONFIG = {
	Grid = 7,
	Cell = 14,
	EmitterHeight = 42,
	RainSpeed = 95,
	RainRate = 48,
	SplashRate = 26,
	UpdatePeriod = 0.12,
	StraightTexture = "rbxassetid://1822883048",
	SplashTexture = "rbxassetid://1822856633",
	DustTexture = "rbxasset://textures/particles/smoke_main.dds",
	LightningMin = 7,
	LightningMax = 22,
	GustMin = 5,
	GustMax = 12,
	FadeSpeed = 0.08,
}

local PROFILES = {
	Clear = {rain = 0, storm = 0, wind = 0.08, fog = 0},
	Rain = {rain = 0.75, storm = 0, wind = 0.15, fog = 0.1},
	Storm = {rain = 1, storm = 1, wind = 0.55, fog = 0.15},
	Wind = {rain = 0, storm = 0, wind = 1, fog = 0},
	Fog = {rain = 0, storm = 0, wind = 0.05, fog = 1},
}

local rng = Random.new()
local level = {rain = 0, storm = 0, wind = 0, fog = 0}

local folder = Instance.new("Folder")
folder.Name = "GS_Weather"
folder.Parent = workspace

local soundFolder = Instance.new("Folder")
soundFolder.Name = "GS_WeatherSounds"
soundFolder.Parent = SoundService

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false

local function refreshFilter()
	local list = {folder}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(list, plr.Character) end
	end
	for _, name in ipairs({"PS_Blood", "SeveredLimbs", "NPCs", "Corpses", "Puddles"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(list, f) end
	end
	params.FilterDescendantsInstances = list
end

local function invisiblePart(name, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = folder
	return part
end

local cells = {}
for i = 1, CONFIG.Grid * CONFIG.Grid do
	local top = invisiblePart("RainCell", Vector3.new(CONFIG.Cell, 0.2, CONFIG.Cell))
	local streak = Instance.new("ParticleEmitter")
	streak.Name = "Streak"
	streak.Texture = CONFIG.StraightTexture
	streak.Orientation = Enum.ParticleOrientation.VelocityParallel
	streak.EmissionDirection = Enum.NormalId.Bottom
	streak.Size = NumberSequence.new(5.5)
	streak.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0.62),
		NumberSequenceKeypoint.new(0.9, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	streak.LightEmission = 0.05
	streak.LightInfluence = 0.9
	streak.Color = ColorSequence.new(Color3.fromRGB(205, 212, 222))
	streak.Speed = NumberRange.new(CONFIG.RainSpeed * 0.92, CONFIG.RainSpeed * 1.08)
	streak.Lifetime = NumberRange.new(0.4)
	streak.Rate = 0
	streak.Parent = top

	local bottom = invisiblePart("SplashCell", Vector3.new(CONFIG.Cell, 0.1, CONFIG.Cell))
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splash"
	splash.Texture = CONFIG.SplashTexture
	splash.Orientation = Enum.ParticleOrientation.FacingCamera
	splash.EmissionDirection = Enum.NormalId.Top
	splash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	splash.Transparency = NumberSequence.new(0.55)
	splash.LightEmission = 0.05
	splash.LightInfluence = 0.9
	splash.Rotation = NumberRange.new(0, 360)
	splash.Lifetime = NumberRange.new(0.1, 0.16)
	splash.Speed = NumberRange.new(0)
	splash.Rate = 0
	splash.Parent = bottom

	cells[i] = {top = top, streak = streak, bottom = bottom, splash = splash}
end

local dustPart = invisiblePart("Dust", Vector3.new(90, 30, 90))
local dust = Instance.new("ParticleEmitter")
dust.Texture = CONFIG.DustTexture
dust.Shape = Enum.ParticleEmitterShape.Box
dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
dust.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.4)})
dust.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(1, 1),
})
dust.Color = ColorSequence.new(Color3.fromRGB(150, 145, 135))
dust.Lifetime = NumberRange.new(2, 4)
dust.Speed = NumberRange.new(0.5, 2)
dust.Rotation = NumberRange.new(0, 360)
dust.RotSpeed = NumberRange.new(-90, 90)
dust.LightInfluence = 1
dust.Rate = 0
dust.Parent = dustPart

local debris = Instance.new("ParticleEmitter")
debris.Shape = Enum.ParticleEmitterShape.Box
debris.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
debris.Size = NumberSequence.new(0.12)
debris.Squash = NumberSequence.new(0.6)
debris.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1),
})
debris.Color = ColorSequence.new(Color3.fromRGB(70, 62, 48), Color3.fromRGB(110, 100, 78))
debris.Lifetime = NumberRange.new(2, 3.5)
debris.Speed = NumberRange.new(0, 1)
debris.Rotation = NumberRange.new(0, 360)
debris.RotSpeed = NumberRange.new(-300, 300)
debris.LightInfluence = 1
debris.Rate = 0
debris.Parent = dustPart

local mistPart = invisiblePart("Mist", Vector3.new(110, 6, 110))
local mist = Instance.new("ParticleEmitter")
mist.Texture = CONFIG.DustTexture
mist.Shape = Enum.ParticleEmitterShape.Box
mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
mist.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 18)})
mist.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.9), NumberSequenceKeypoint.new(1, 1),
})
mist.Color = ColorSequence.new(Color3.fromRGB(190, 192, 195))
mist.Lifetime = NumberRange.new(8, 12)
mist.Speed = NumberRange.new(0.2, 0.8)
mist.Rotation = NumberRange.new(0, 360)
mist.RotSpeed = NumberRange.new(-8, 8)
mist.LightInfluence = 1
mist.Rate = 0
mist.Parent = mistPart

local flash = Instance.new("ColorCorrectionEffect")
flash.Name = "GS_Lightning"
flash.Parent = Lighting

local function loop(name)
	local sound = SoundConfig.Make(name, soundFolder, {Looped = true, Volume = 0})
	sound:Play()
	return {sound = sound, base = SoundConfig.Sounds[name].volume}
end
local rainOut = loop("RainLoop")
local rainIn = loop("RainLoop")
rainIn.sound.PlaybackSpeed = 0.92
rainIn.sound.TimePosition = 3
do
	local eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain = -30
	eq.MidGain = -12
	eq.LowGain = 3
	eq.Parent = rainIn.sound
end
local windLoop = loop("WindLoop")

local gui = Instance.new("ScreenGui")
gui.Name = "WeatherUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")

local function screenDrop()
	local size = rng:NextInteger(6, 22)
	local drop = Instance.new("Frame")
	drop.AnchorPoint = Vector2.new(0.5, 0.5)
	drop.Position = UDim2.fromScale(rng:NextNumber(0.02, 0.98), rng:NextNumber(0.02, 0.9))
	drop.Size = UDim2.fromOffset(size, size * rng:NextNumber(1, 1.3))
	drop.BackgroundColor3 = Color3.fromRGB(215, 222, 230)
	drop.BackgroundTransparency = 0.86
	drop.BorderSizePixel = 0
	drop.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = drop
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(240, 244, 250)
	stroke.Transparency = 0.7
	stroke.Thickness = 1
	stroke.Parent = drop
	local life = rng:NextNumber(1.2, 3)
	local slide = rng:NextNumber() < 0.35 and rng:NextNumber(0.05, 0.2) or 0.01
	local info = TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(drop, info, {
		BackgroundTransparency = 1,
		Position = drop.Position + UDim2.fromScale(0, slide),
		Size = UDim2.fromOffset(size * 0.7, size * (1 + slide * 6)),
	}):Play()
	TweenService:Create(stroke, info, {Transparency = 1}):Play()
	task.delay(life, function() drop:Destroy() end)
end

local function strike()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local origin = camera.CFrame.Position
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(120, 650)
	local base = origin + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	local topY = origin.Y + rng:NextNumber(260, 380)
	local hit = workspace:Raycast(Vector3.new(base.X, topY, base.Z), Vector3.new(0, -topY + origin.Y - 300, 0), params)
	local bottomY = hit and hit.Position.Y or origin.Y - 20
	local points = {Vector3.new(base.X, topY, base.Z)}
	local segments = 14
	for i = 1, segments do
		local t = i / segments
		local jitter = (1 - t * 0.4) * 22
		local p = Vector3.new(base.X + rng:NextNumber(-jitter, jitter), topY + (bottomY - topY) * t, base.Z + rng:NextNumber(-jitter, jitter))
		if i == segments then p = Vector3.new(base.X, bottomY, base.Z) end
		table.insert(points, p)
	end
	local parts = {}
	local function segment(a, b, width)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(215, 225, 255)
		p.Size = Vector3.new(width, width, (b - a).Magnitude)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p.Parent = folder
		table.insert(parts, p)
	end
	for i = 1, #points - 1 do
		segment(points[i], points[i + 1], rng:NextNumber(1.2, 2.4))
		if rng:NextNumber() < 0.3 and i < #points - 2 then
			local branchEnd = points[i] + Vector3.new(rng:NextNumber(-40, 40), -rng:NextNumber(20, 60), rng:NextNumber(-40, 40))
			segment(points[i], branchEnd, 0.8)
		end
	end
	local close = distance < 280
	local strength = close and 0.55 or 0.3
	task.spawn(function()
		for _ = 1, rng:NextInteger(2, 4) do
			flash.Brightness = strength
			flash.Contrast = strength * 0.4
			for _, p in ipairs(parts) do p.Transparency = 0 end
			task.wait(rng:NextNumber(0.04, 0.08))
			flash.Brightness = strength * 0.2
			for _, p in ipairs(parts) do p.Transparency = 0.7 end
			task.wait(rng:NextNumber(0.04, 0.1))
		end
		for _, p in ipairs(parts) do p:Destroy() end
		TweenService:Create(flash, TweenInfo.new(0.6), {Brightness = 0, Contrast = 0}):Play()
	end)
	task.delay(math.clamp(distance / 320, 0.15, 2.4), function()
		local name = close and SoundConfig.Random("ThunderClose") or SoundConfig.Random("ThunderFar")
		SoundConfig.PlayOnce(name, soundFolder, {
			Volume = (close and 1 or 0.75) * math.clamp(1.2 - distance / 900, 0.35, 1),
			PlaybackSpeed = rng:NextNumber(0.85, 1.02),
		})
	end)
end

local function applyWeatherTarget()
	return PROFILES[workspace:GetAttribute("Weather") or "Clear"] or PROFILES.Clear
end

local ripples = {}
local function updateRipples(rainAmount)
	local puddleFolder = workspace:FindFirstChild("Puddles")
	local seen = {}
	if puddleFolder then
		for _, model in ipairs(puddleFolder:GetChildren()) do
			local main = model:FindFirstChild("Water")
			if main and main:IsA("BasePart") then
				seen[model] = true
				local entry = ripples[model]
				if not entry then
					local box = invisiblePart("Ripples", Vector3.new(1, 0.05, 1))
					local emitter = Instance.new("ParticleEmitter")
					emitter.Texture = CONFIG.SplashTexture
					emitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
					emitter.EmissionDirection = Enum.NormalId.Top
					emitter.Speed = NumberRange.new(0.01)
					emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1.1)})
					emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1)})
					emitter.Color = ColorSequence.new(Color3.fromRGB(200, 208, 216))
					emitter.Lifetime = NumberRange.new(0.45, 0.7)
					emitter.LightInfluence = 1
					emitter.Rate = 0
					emitter.Parent = box
					entry = {box = box, emitter = emitter}
					ripples[model] = entry
				end
				local d = main.Size.Y * 0.7
				entry.box.Size = Vector3.new(math.max(d, 0.2), 0.05, math.max(d, 0.2))
				entry.box.CFrame = CFrame.new(main.Position + Vector3.new(0, 0.06, 0))
				entry.emitter.Rate = rainAmount > 0.05 and (d * d * 0.35 * rainAmount) or 0
			end
		end
	end
	for model, entry in pairs(ripples) do
		if not seen[model] then
			entry.box:Destroy()
			ripples[model] = nil
		end
	end
end
local nextRipple = 0

local covered = 0
local nextUpdate = 0
local nextLightning = os.clock() + rng:NextNumber(CONFIG.LightningMin, CONFIG.LightningMax)
local nextGust = os.clock() + rng:NextNumber(CONFIG.GustMin, CONFIG.GustMax)
local gustUntil, gustStrength = 0, 0
local dropAccum = 0

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local now = os.clock()
	local target = applyWeatherTarget()
	for key, value in pairs(target) do
		local current = level[key]
		local step = CONFIG.FadeSpeed * dt
		if math.abs(value - current) <= step then
			level[key] = value
		else
			level[key] = current + math.sign(value - current) * step
		end
	end

	local camPos = camera.CFrame.Position
	local wind = workspace.GlobalWind
	local gust = now < gustUntil and gustStrength or 0
	local windVec = wind * (1 + gust)
	local rainAmount = math.max(level.rain, level.storm)

	if now >= nextUpdate then
		local low = lowGraphics()
		nextUpdate = now + (low and CONFIG.UpdatePeriod * 2 or CONFIG.UpdatePeriod)
		refreshFilter()
		local g = CONFIG.Grid
		local half = (g - 1) / 2
		local baseX = math.floor(camPos.X / CONFIG.Cell) * CONFIG.Cell
		local baseZ = math.floor(camPos.Z / CONFIG.Cell) * CONFIG.Cell
		local topY = camPos.Y + CONFIG.EmitterHeight
		local rate = CONFIG.RainRate * rainAmount * (1 + level.storm * 0.5) * (low and 0.35 or 1)
		local accel = Vector3.new(windVec.X, 0, windVec.Z) * 0.9
		local coveredHits = 0
		local index = 0
		for ix = 0, g - 1 do
			for iz = 0, g - 1 do
				index += 1
				local cell = cells[index]
				local x = baseX + (ix - half) * CONFIG.Cell
				local z = baseZ + (iz - half) * CONFIG.Cell
				cell.top.CFrame = CFrame.new(x, topY, z)
				if rainAmount < 0.01 then
					cell.streak.Rate = 0
					cell.splash.Rate = 0
				else
					local hit = workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -CONFIG.EmitterHeight - 160, 0), params)
					local groundY = hit and hit.Position.Y or (camPos.Y - 120)
					local fall = math.max(topY - groundY, 1)
					cell.streak.Lifetime = NumberRange.new(math.clamp(fall / CONFIG.RainSpeed, 0.05, 2.2))
					cell.streak.Acceleration = accel
					local dist = math.abs(ix - half) + math.abs(iz - half)
					local falloff = dist > half * 1.5 and 0.5 or 1
					cell.streak.Rate = rate * falloff
					if hit then
						cell.bottom.CFrame = CFrame.new(x, groundY + 0.05, z)
						local onWater = hit.Material == Enum.Material.Water
						cell.splash.Rate = CONFIG.SplashRate * rainAmount * falloff * (onWater and 1.4 or 1) * (low and 0.3 or 1)
						cell.splash.Size = onWater and NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 2), NumberSequenceKeypoint.new(1, 0),
						}) or NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 1.4), NumberSequenceKeypoint.new(1, 0),
						})
						if dist <= 1.5 and hit.Position.Y > camPos.Y + 1 then coveredHits += 1 end
					else
						cell.splash.Rate = 0
					end
				end
			end
		end
		local upHit = workspace:Raycast(camPos, Vector3.new(0, 80, 0), params)
		local coverTarget = upHit and 1 or math.clamp(coveredHits / 9, 0, 1) * 0.6
		covered += (coverTarget - covered) * 0.35
	end

	if now >= nextRipple then
		nextRipple = now + 0.5
		updateRipples(lowGraphics() and 0 or rainAmount)
	end

	local outside = 1 - covered
	local function setLoop(l, v)
		local s = l.sound
		s.Volume = s.Volume + (l.base * v - s.Volume) * math.min(dt * 2, 1)
	end
	setLoop(rainOut, rainAmount * outside * (1 + level.storm * 0.3))
	setLoop(rainIn, rainAmount * covered * 1.1)
	local windAmount = math.max(level.wind, level.storm * 0.6)
	setLoop(windLoop, windAmount * (0.35 + 0.65 * outside) * (1 + gust * 0.6))

	local windUnit = Vector3.new(windVec.X, 0, windVec.Z)
	dustPart.CFrame = CFrame.new(camPos + Vector3.new(0, 4, 0))
	local fx = lowGraphics() and 0.35 or 1
	dust.Rate = level.wind * 70 * outside * fx
	debris.Rate = level.wind * 45 * outside * fx
	dust.Acceleration = windUnit * 0.6
	debris.Acceleration = windUnit * 0.5 + Vector3.new(0, -2, 0)

	mistPart.CFrame = CFrame.new(camPos.X, camPos.Y - 2, camPos.Z)
	mist.Rate = level.fog * 18 * fx
	mist.Acceleration = windUnit * 0.05

	if level.storm > 0.6 and now >= nextLightning then
		nextLightning = now + rng:NextNumber(CONFIG.LightningMin, CONFIG.LightningMax)
		strike()
	elseif level.storm <= 0.6 and now >= nextLightning then
		nextLightning = now + rng:NextNumber(CONFIG.LightningMin, CONFIG.LightningMax)
	end

	if windAmount > 0.4 and now >= nextGust then
		nextGust = now + rng:NextNumber(CONFIG.GustMin, CONFIG.GustMax)
		gustStrength = rng:NextNumber(0.4, 1) * windAmount
		gustUntil = now + rng:NextNumber(1.5, 3.5)
		SoundConfig.PlayOnce(SoundConfig.Random("WindGust"), soundFolder, {
			Volume = 0.25 + 0.35 * gustStrength * outside,
			PlaybackSpeed = rng:NextNumber(0.85, 1.1),
		})
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and gust > 0.2 and outside > 0.5 and not character:GetAttribute("Ragdolled") and not player:GetAttribute("InMenu") then
		root.AssemblyLinearVelocity += Vector3.new(windVec.X, 0, windVec.Z) * 0.012 * gust * outside
	end

	if rainAmount > 0.25 and outside > 0.6 and camera.CFrame.LookVector.Y > -0.35 then
		dropAccum += dt * rainAmount * (4 + 6 * math.max(camera.CFrame.LookVector.Y + 0.35, 0))
		while dropAccum >= 1 do
			dropAccum -= 1
			screenDrop()
		end
	else
		dropAccum = 0
	end
end)
