local Lighting = game:GetService("Lighting")

local PRESET = "Overcast"
local DISABLE_OTHER_EFFECTS = true

local PRESETS = {

	Overcast = {
		ClockTime = 14.5,
		Brightness = 1.6,
		Ambient = Color3.fromRGB(95, 97, 100),
		OutdoorAmbient = Color3.fromRGB(135, 138, 142),
		ColorShift_Top = Color3.fromRGB(0, 0, 0),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		-- full environment lighting and reflections: every material picks up the sky and the lamps (Future)
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
		ExposureCompensation = -0.15,
		ShadowSoftness = 0.35,
		GeographicLatitude = 45,
		Atmosphere = {
			Density = 0.38, Offset = 0.25, Haze = 2.6, Glare = 0,
			Color = Color3.fromRGB(168, 170, 172), Decay = Color3.fromRGB(118, 120, 124),
		},
		Bloom = {Intensity = 0.55, Size = 30, Threshold = 1.35},
		Color = {Brightness = 0.01, Contrast = 0.16, Saturation = -0.5, TintColor = Color3.fromRGB(228, 231, 235)},
		DepthOfField = {FarIntensity = 0.32, FocusDistance = 25, InFocusRadius = 25, NearIntensity = 0},
		SunRays = {Intensity = 0, Spread = 0},
		Sky = {StarCount = 0, CelestialBodiesShown = false},
		Clouds = {Cover = 0.92, Density = 0.75, Color = Color3.fromRGB(150, 152, 155)},
	},

	Facility = {
		ClockTime = 0.3,
		Brightness = 0.6,
		Ambient = Color3.fromRGB(10, 11, 13),
		OutdoorAmbient = Color3.fromRGB(22, 24, 28),
		ColorShift_Top = Color3.fromRGB(0, 0, 0),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		EnvironmentDiffuseScale = 0.2,
		EnvironmentSpecularScale = 0.5,
		ExposureCompensation = -0.2,
		ShadowSoftness = 0.15,
		GeographicLatitude = 20,
		Atmosphere = {
			Density = 0.45, Offset = 0.12, Haze = 2.4, Glare = 0,
			Color = Color3.fromRGB(38, 42, 44), Decay = Color3.fromRGB(12, 14, 14),
		},
		Bloom = {Intensity = 0.7, Size = 28, Threshold = 1.4},
		Color = {Brightness = -0.02, Contrast = 0.2, Saturation = -0.4, TintColor = Color3.fromRGB(215, 228, 222)},
		DepthOfField = {FarIntensity = 0.18, FocusDistance = 35, InFocusRadius = 45, NearIntensity = 0},
		SunRays = {Intensity = 0, Spread = 0},
		Sky = {StarCount = 400, CelestialBodiesShown = false},
	},

	Forest = {
		ClockTime = 23.5,
		Brightness = 0.9,
		Ambient = Color3.fromRGB(8, 10, 16),
		OutdoorAmbient = Color3.fromRGB(28, 32, 48),
		ColorShift_Top = Color3.fromRGB(40, 50, 80),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		EnvironmentDiffuseScale = 0.35,
		EnvironmentSpecularScale = 0.4,
		ExposureCompensation = -0.1,
		ShadowSoftness = 0.3,
		GeographicLatitude = 35,
		Atmosphere = {
			Density = 0.38, Offset = 0.2, Haze = 1.8, Glare = 0.2,
			Color = Color3.fromRGB(30, 36, 52), Decay = Color3.fromRGB(10, 12, 20),
		},
		Bloom = {Intensity = 0.6, Size = 30, Threshold = 1.6},
		Color = {Brightness = 0, Contrast = 0.15, Saturation = -0.3, TintColor = Color3.fromRGB(205, 215, 240)},
		DepthOfField = {FarIntensity = 0.22, FocusDistance = 40, InFocusRadius = 50, NearIntensity = 0},
		SunRays = {Intensity = 0.02, Spread = 0.4},
		Sky = {StarCount = 2500, CelestialBodiesShown = true, MoonAngularSize = 14},
	},

	Blackout = {
		ClockTime = 0,
		Brightness = 0,
		Ambient = Color3.fromRGB(3, 3, 4),
		OutdoorAmbient = Color3.fromRGB(6, 6, 8),
		ColorShift_Top = Color3.fromRGB(0, 0, 0),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		EnvironmentDiffuseScale = 0.05,
		EnvironmentSpecularScale = 0.3,
		ExposureCompensation = 0,
		ShadowSoftness = 0.1,
		GeographicLatitude = 0,
		Atmosphere = {
			Density = 0.55, Offset = 0, Haze = 3, Glare = 0,
			Color = Color3.fromRGB(10, 10, 12), Decay = Color3.fromRGB(4, 4, 5),
		},
		Bloom = {Intensity = 0.9, Size = 24, Threshold = 1.2},
		Color = {Brightness = 0, Contrast = 0.25, Saturation = -0.5, TintColor = Color3.fromRGB(230, 220, 215)},
		DepthOfField = {FarIntensity = 0.1, FocusDistance = 25, InFocusRadius = 35, NearIntensity = 0},
		SunRays = {Intensity = 0, Spread = 0},
		Sky = {StarCount = 0, CelestialBodiesShown = false},
	},
}

local preset = PRESETS[PRESET] or PRESETS.Facility

-- (a running game can't switch this; the installer sets Future in Studio. Tried here too for older places)
pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)
pcall(function() game:GetService("MaterialService").Use2022Materials = true end)

for _, key in ipairs({
	"ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation", "ShadowSoftness",
	"GeographicLatitude",
}) do
	pcall(function() Lighting[key] = preset[key] end)
end
Lighting.GlobalShadows = true
Lighting.FogEnd = 100000

local OURS = {
	HorrorAtmosphere = true, HorrorBloom = true, HorrorColor = true,
	HorrorDOF = true, HorrorSunRays = true, HorrorSky = true,
}
if DISABLE_OTHER_EFFECTS then
	for _, child in ipairs(Lighting:GetChildren()) do
		if not OURS[child.Name] then
			if child:IsA("Atmosphere") or child:IsA("Sky") then
				child:Destroy()
			elseif child:IsA("PostEffect") and not child.Name:match("^Fall") and not child.Name:match("^LowHealth") then
				child.Enabled = false
			end
		end
	end
end

local function ensure(className, name, props)
	local object = Lighting:FindFirstChild(name)
	if not object then
		object = Instance.new(className)
		object.Name = name
	end
	for key, value in pairs(props) do
		pcall(function() object[key] = value end)
	end
	object.Parent = Lighting
	return object
end

ensure("Atmosphere", "HorrorAtmosphere", preset.Atmosphere)
ensure("BloomEffect", "HorrorBloom", preset.Bloom)
ensure("ColorCorrectionEffect", "HorrorColor", preset.Color)
ensure("DepthOfFieldEffect", "HorrorDOF", preset.DepthOfField)
ensure("SunRaysEffect", "HorrorSunRays", preset.SunRays)
ensure("Sky", "HorrorSky", preset.Sky)

local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	if preset.Clouds then
		if not clouds then
			clouds = Instance.new("Clouds")
			clouds.Parent = terrain
		end
		for key, value in pairs(preset.Clouds) do
			pcall(function() clouds[key] = value end)
		end
		clouds.Enabled = true
	elseif clouds then
		clouds.Enabled = false
	end
end

local TweenService = game:GetService("TweenService")

local NIGHT = {
	ClockTime = 23.4,
	Brightness = 0.35,
	Ambient = Color3.fromRGB(26, 28, 38),
	OutdoorAmbient = Color3.fromRGB(46, 52, 72),
	EnvironmentDiffuseScale = 0.55,
	EnvironmentSpecularScale = 0.85,
	ExposureCompensation = 0,
	Atmosphere = {
		Density = 0.46, Offset = 0.1, Haze = 2.2, Glare = 0,
		Color = Color3.fromRGB(38, 42, 58), Decay = Color3.fromRGB(14, 16, 26),
	},
	Bloom = {Intensity = 0.6, Size = 30, Threshold = 1.5},
	Color = {Brightness = 0, Contrast = 0.18, Saturation = -0.45, TintColor = Color3.fromRGB(198, 210, 238)},
	DepthOfField = {FarIntensity = 0.36, FocusDistance = 25, InFocusRadius = 25, NearIntensity = 0},
	Sky = {StarCount = 1800, CelestialBodiesShown = true, MoonAngularSize = 16},
	Clouds = {Cover = 0.7, Density = 0.55, Color = Color3.fromRGB(40, 44, 56)},
}
local DAY = preset

local LIGHTING_KEYS = {
	"ClockTime", "Brightness", "Ambient", "OutdoorAmbient",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation",
}
local EFFECTS = {
	HorrorAtmosphere = "Atmosphere", HorrorBloom = "Bloom", HorrorColor = "Color", HorrorDOF = "DepthOfField",
}

local function tweenTo(target, time)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local props = {}
	for _, key in ipairs(LIGHTING_KEYS) do
		if target[key] ~= nil then props[key] = target[key] end
	end
	TweenService:Create(Lighting, info, props):Play()
	for objectName, key in pairs(EFFECTS) do
		local object = Lighting:FindFirstChild(objectName)
		if object and target[key] then
			local numeric = {}
			for prop, value in pairs(target[key]) do
				if typeof(value) == "number" or typeof(value) == "Color3" then numeric[prop] = value end
			end
			pcall(function() TweenService:Create(object, info, numeric):Play() end)
		end
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
	if clouds and target.Clouds then
		pcall(function() TweenService:Create(clouds, info, target.Clouds):Play() end)
	end
	task.delay(time * 0.5, function()
		local sky = Lighting:FindFirstChild("HorrorSky")
		if sky and target.Sky then
			for key, value in pairs(target.Sky) do pcall(function() sky[key] = value end) end
		end
	end)
end

local WEATHER_MODS = {
	Clear = {},
	Rain = {
		brightness = 0.78, ambient = 0.85, atmosphere = {Density = 0.07, Haze = 0.5}, atmoColor = 0.82,
		color = {Saturation = -0.08, Contrast = 0.03}, dof = 0.05,
		clouds = {Cover = 1, Density = 0.95}, cloudColor = 0.7, wind = Vector3.new(6, 0, 3),
	},
	Storm = {
		brightness = 0.55, ambient = 0.7, atmosphere = {Density = 0.11, Haze = 0.8}, atmoColor = 0.62,
		color = {Saturation = -0.14, Contrast = 0.07}, dof = 0.08,
		clouds = {Cover = 1, Density = 1}, cloudColor = 0.45, wind = Vector3.new(24, 0, 10),
	},
	Wind = {
		brightness = 0.95, ambient = 0.95, atmosphere = {Density = 0.02, Haze = 0.3}, atmoColor = 0.95,
		color = {Contrast = 0.02}, dof = 0,
		clouds = {Cover = 0.85, Density = 0.7}, cloudColor = 0.9, wind = Vector3.new(38, 0, 16),
	},
	Fog = {
		brightness = 0.9, ambient = 1, atmosphere = {Density = 0.24, Haze = 1.2, Offset = -0.1}, atmoColor = 1.06,
		color = {Saturation = -0.06, Contrast = -0.04}, dof = 0.2,
		clouds = {Cover = 0.95, Density = 0.8}, cloudColor = 1, wind = Vector3.new(1, 0, 0.5),
	},
}

local function scaleColor(c, k)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function copy(t)
	local r = {}
	for k, v in pairs(t) do r[k] = typeof(v) == "table" and copy(v) or v end
	return r
end

local function compose(base, weatherName)
	local mod = WEATHER_MODS[weatherName] or WEATHER_MODS.Clear
	local t = copy(base)
	if mod.brightness then t.Brightness = (t.Brightness or 1) * mod.brightness end
	if mod.ambient then
		t.Ambient = scaleColor(t.Ambient, mod.ambient)
		t.OutdoorAmbient = scaleColor(t.OutdoorAmbient, mod.ambient)
	end
	if t.Atmosphere then
		for k, v in pairs(mod.atmosphere or {}) do
			t.Atmosphere[k] = math.clamp((t.Atmosphere[k] or 0) + v, 0, k == "Haze" and 10 or 1)
		end
		if mod.atmoColor then
			t.Atmosphere.Color = scaleColor(t.Atmosphere.Color, mod.atmoColor)
			t.Atmosphere.Decay = scaleColor(t.Atmosphere.Decay, mod.atmoColor)
		end
	end
	if t.Color then
		for k, v in pairs(mod.color or {}) do t.Color[k] = (t.Color[k] or 0) + v end
	end
	if t.DepthOfField and mod.dof then
		t.DepthOfField.FarIntensity = math.clamp(t.DepthOfField.FarIntensity + mod.dof, 0, 1)
	end
	if t.Clouds then
		for k, v in pairs(mod.clouds or {}) do t.Clouds[k] = v end
		if mod.cloudColor then t.Clouds.Color = scaleColor(t.Clouds.Color, mod.cloudColor) end
	end
	t.Wind = mod.wind or Vector3.new(2, 0, 1)
	return t
end

local function currentTarget()
	return compose(workspace:GetAttribute("Night") and NIGHT or DAY, workspace:GetAttribute("Weather") or "Clear")
end

local function apply(time)
	local target = currentTarget()
	tweenTo(target, time)
	pcall(function()
		TweenService:Create(workspace, TweenInfo.new(time, Enum.EasingStyle.Sine), {GlobalWind = target.Wind}):Play()
	end)
end

workspace:GetAttributeChangedSignal("Night"):Connect(function() apply(8) end)
workspace:GetAttributeChangedSignal("Weather"):Connect(function() apply(20) end)
if workspace:GetAttribute("Night") == nil then
	workspace:SetAttribute("Night", false)
end

local WEATHER_CYCLE = {
	Enabled = true,
	MinTime = 240,
	MaxTime = 540,
	LockTime = 600,
	Weights = {Clear = 3, Rain = 3, Storm = 1.5, Wind = 2, Fog = 2},
}

local function pickWeather(exclude)
	local total = 0
	for name, w in pairs(WEATHER_CYCLE.Weights) do
		if name ~= exclude then total += w end
	end
	local roll = math.random() * total
	for name, w in pairs(WEATHER_CYCLE.Weights) do
		if name ~= exclude then
			roll -= w
			if roll <= 0 then return name end
		end
	end
	return "Clear"
end

if workspace:GetAttribute("Weather") == nil then
	workspace:SetAttribute("Weather", "Clear")
end
apply(0.1)

if WEATHER_CYCLE.Enabled then
	task.spawn(function()
		while true do
			task.wait(math.random(WEATHER_CYCLE.MinTime, WEATHER_CYCLE.MaxTime))
			local lock = workspace:GetAttribute("WeatherLock")
			if not (lock and os.clock() - lock < WEATHER_CYCLE.LockTime) then
				workspace:SetAttribute("Weather", pickWeather(workspace:GetAttribute("Weather")))
			end
		end
	end)
end

local PUDDLES = {
	Enabled = true,
	Max = 45,
	SpawnRadius = 70,
	MinGap = 7,
	WetRate = 1 / 80,
	DryRate = 1 / 240,
	Tick = 3,
}

if PUDDLES.Enabled then
	local Players = game:GetService("Players")
	local folder = workspace:FindFirstChild("Puddles") or Instance.new("Folder")
	folder.Name = "Puddles"
	folder.Parent = workspace
	local wetness = 0
	local puddles = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false

	local function refreshFilter()
		local list = {folder}
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then table.insert(list, player.Character) end
		end
		for _, name in ipairs({"Corpses", "SeveredLimbs", "GS_Weather", "NPCs"}) do
			local f = workspace:FindFirstChild(name)
			if f then table.insert(list, f) end
		end
		params.FilterDescendantsInstances = list
	end

	local function tooClose(position)
		for _, p in ipairs(puddles) do
			if (p.position - position).Magnitude < PUDDLES.MinGap then return true end
		end
		return false
	end

	local function makePuddle(position, normal)
		local model = Instance.new("Model")
		model.Name = "Puddle"
		local parts = {}
		local main = math.random() * 4 + 4
		local blobs = math.random(2, 4)
		for i = 1, blobs do
			local d = i == 1 and main or main * (0.45 + math.random() * 0.4)
			local offset = i == 1 and Vector3.zero or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit * main * (0.25 + math.random() * 0.25)
			local part = Instance.new("Part")
			part.Name = "Water"
			part.Shape = Enum.PartType.Cylinder
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.Glass
			part.Color = Color3.fromRGB(128, 136, 145)
			part.Transparency = 0.62
			part.Reflectance = 0.14
			part.Size = Vector3.new(0.05 + i * 0.004, 0.05, 0.05)
			part.CFrame = CFrame.new(position + offset + normal * (0.03 + i * 0.004)) * CFrame.Angles(0, 0, math.pi / 2)
			part:SetAttribute("Diameter", d)
			part.Parent = model
			table.insert(parts, part)
		end
		model.Parent = folder
		table.insert(puddles, {model = model, parts = parts, position = position, scale = 0, max = 0.7 + math.random() * 0.3})
	end

	local function trySpawn(origin)
		local angle = math.random() * math.pi * 2
		local dist = 8 + math.random() * (PUDDLES.SpawnRadius - 8)
		local x = origin.X + math.cos(angle) * dist
		local z = origin.Z + math.sin(angle) * dist
		local top = Vector3.new(x, origin.Y + 120, z)
		local hit = workspace:Raycast(top, Vector3.new(0, -260, 0), params)
		if not hit or hit.Normal.Y < 0.93 or hit.Material == Enum.Material.Water then return end
		local instance = hit.Instance
		if not instance:IsA("Terrain") and not (instance:IsA("BasePart") and instance.Anchored) then return end
		if tooClose(hit.Position) then return end
		makePuddle(hit.Position, hit.Normal)
	end

	task.spawn(function()
		while true do
			task.wait(PUDDLES.Tick)
			local weather = workspace:GetAttribute("Weather")
			local raining = weather == "Rain" or weather == "Storm"
			if raining then
				wetness = math.min(1, wetness + PUDDLES.WetRate * PUDDLES.Tick * (weather == "Storm" and 1.6 or 1))
			else
				wetness = math.max(0, wetness - PUDDLES.DryRate * PUDDLES.Tick)
			end
			workspace:SetAttribute("Wetness", math.floor(wetness * 100) / 100)
			refreshFilter()
			local roots = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then table.insert(roots, root.Position) end
			end
			if raining and wetness > 0.15 then
				for _, origin in ipairs(roots) do
					for _ = 1, 2 do
						if #puddles < PUDDLES.Max then trySpawn(origin) end
					end
				end
			end
			for i = #puddles, 1, -1 do
				local p = puddles[i]
				local near = false
				for _, origin in ipairs(roots) do
					if (origin - p.position).Magnitude < 220 then near = true break end
				end
				local target = raining and math.min(p.scale + 0.12, wetness * p.max) or wetness * p.max
				if not near then target = 0 end
				p.scale = target
				if not near or (target < 0.12 and not raining) then
					p.model:Destroy()
					table.remove(puddles, i)
				else
					for _, part in ipairs(p.parts) do
						local d = part:GetAttribute("Diameter") * math.max(target, 0.05)
						TweenService:Create(part, TweenInfo.new(PUDDLES.Tick, Enum.EasingStyle.Linear), {
							Size = Vector3.new(part.Size.X, d, d),
						}):Play()
					end
				end
			end
		end
	end)
end
