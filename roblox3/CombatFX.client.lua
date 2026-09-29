-- Combat effects, drawn on every client:
--   * creature blood by kind: black (almost everything), green goo (the spiders), acid (C-310)
--   * limbs coming off, stumps bubbling while they grow back (A-013), bodies dropping into a pool
--   * spiders bursting: a green splash where they died, the legs left twitching on the floor for a while
--   * C-310: the gurgle before it spits, the arc of the spit, acid puddles, and the splash on your own screen
--   * items: armor breaking into bits, putting things on and taking them off, traps, heals (sounds for everyone)
--   * a thin health bar over a creature for a moment after it's hit
--   * your own state: caught in a web (getting up, with a timer), leg in a trap, acid fumes, shocked
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local VFX=require(Modules:WaitForChild("CustomVFX"))
local GameSettings = require(Modules:WaitForChild("GameSettings"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.SpecialElite
local INK = Color3.fromRGB(236, 230, 222)
local DIM = Color3.fromRGB(120, 112, 106)
local LINE = Color3.fromRGB(70, 60, 56)
local PANEL = Color3.fromRGB(8, 6, 6)
local BRIGHT = Color3.fromRGB(225, 40, 40)
local AMBER = Color3.fromRGB(232, 164, 52)
local ACID_UI = Color3.fromRGB(170, 214, 60)

-- blood by kind: {main, dark, reflectance, glow}
local PALETTES = {
	black = {Color3.fromRGB(18, 14, 16), Color3.fromRGB(3, 2, 3), 0.14},
	green = {Color3.fromRGB(108, 172, 38), Color3.fromRGB(46, 90, 16), 0.2},
	acid = {Color3.fromRGB(190, 230, 56), Color3.fromRGB(118, 158, 26), 0.25, true},
	red = {Color3.fromRGB(92, 4, 4), Color3.fromRGB(55, 2, 2), 0.05},
}
local function paletteOf(kind) return PALETTES[kind or "black"] or PALETTES.black end

local CHITIN = Color3.fromRGB(30, 23, 21)
local JOINT = Color3.fromRGB(58, 42, 36)

local rng = Random.new()
local function now() return workspace:GetServerTimeNow() end
local function low() return GameSettings.Get("LowGraphics") == true end

local function create(className, props, children)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	return obj
end
local function tween(obj, t, goal, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local fxFolder = workspace:FindFirstChild("GS_FX") or create("Folder", {Name = "GS_FX", Parent = workspace})
local gooFolder = create("Folder", {Name = "GS_Goo", Parent = fxFolder})

-- ===== sounds (Roblox's public library, see ItemData.Sounds) =====
local Audio=require(Modules:WaitForChild("CombatAudio"))
local function sound(name,parent,volume,speed,maxDist)
 return Audio.Play(name,parent,volume,speed,maxDist,name=="Sizzle")
end
local function anchorAt(position, life)
	local p = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Parent = fxFolder,
	})
	Debris:AddItem(p, life or 6)
	return p
end
local function soundAt(name, position, volume, speed, maxDist)
	if typeof(position) ~= "Vector3" then return end
	sound(name, anchorAt(position), volume, speed, maxDist)
end

-- ===== droplets and stains =====
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
params.RespectCanCollide = true
local function refreshFilter()
	local list = {fxFolder}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(list, plr.Character) end
	end
	for _, name in ipairs({"Monsters", "NPCs", "GS_Gibs", "PS_Blood", "GS_Items", "GS_Traps", "SpiderWebs", "GS_SpiderLegs", "GS_Tentacles"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(list, f) end
	end
	params.FilterDescendantsInstances = list
end
refreshFilter()
task.spawn(function()
	while true do
		task.wait(2)
		refreshFilter()
	end
end)

local function newPart(size, color, reflect)
	return create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.SmoothPlastic, Color = color, Size = size, Reflectance = reflect or 0,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
	})
end

local splats = {}
local function maxSplats() return low() and 60 or 180 end
local function addSplat(position, normal, diameter, grow, pal, life)
	while #splats >= maxSplats() do
		local old = table.remove(splats, 1)
		if old.Parent then old:Destroy() end
	end
	local up = normal.Unit
	local tangent = up:Cross(Vector3.new(0, 1, 0))
	if tangent.Magnitude < 0.1 then tangent = up:Cross(Vector3.new(1, 0, 0)) end
	tangent = tangent.Unit
	local cf = CFrame.fromMatrix(position + up * 0.035, up, tangent) * CFrame.Angles(rng:NextNumber(0, math.pi * 2), 0, 0)
	local splat = newPart(Vector3.new(0.04, 0.2, 0.2), pal[1]:Lerp(pal[2], rng:NextNumber(0, 0.6)), pal[3])
	splat.Shape = Enum.PartType.Cylinder
	splat.CFrame = cf
	splat.Parent = gooFolder
	table.insert(splats, splat)
	tween(splat, grow or 0.25, {Size = Vector3.new(0.04, diameter, diameter * rng:NextNumber(0.75, 1.1))})
	task.delay(life or 50, function()
		if splat.Parent then
			tween(splat, 4, {Transparency = 1}).Completed:Wait()
			splat:Destroy()
		end
	end)
	return splat
end

local function addPool(position, size, time, pal, life)
	local hit = workspace:Raycast(position + Vector3.new(0, 1.5, 0), Vector3.new(0, -9, 0), params)
	if not hit then return end
	for i = 1, 5 do
		local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size * 0.25
		task.delay((i - 1) * 0.15, function()
			addSplat(hit.Position + offset, hit.Normal, size * rng:NextNumber(0.5, 0.9), time, pal, life)
		end)
	end
end

local droplets = {}
local function maxDroplets() return low() and 70 or 240 end
local function spawnDroplets(origin, count, speed, spread, bias, pal)
	if typeof(origin) ~= "Vector3" then return end
	if low() then count = math.ceil(count * 0.4) end
	for _ = 1, count do
		if #droplets >= maxDroplets() then break end
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1))
		if bias then dir += bias end
		if dir.Magnitude < 1e-3 then dir = Vector3.new(0, 1, 0) end
		dir = dir.Unit
		local size = rng:NextNumber(0.12, 0.3)
		local drop = newPart(Vector3.new(size, size, size), pal[1], pal[3])
		drop.Shape = Enum.PartType.Ball
		if pal[4] then drop.Material = Enum.Material.Neon drop.Transparency = 0.25 end
		drop.Position = origin
		drop.Parent = fxFolder
		table.insert(droplets, {
			part = drop, position = origin, life = 0, size = size, pal = pal,
			velocity = dir * speed * rng:NextNumber(0.4, 1) + Vector3.new(0, rng:NextNumber(0, spread), 0),
		})
	end
end

RunService.Heartbeat:Connect(function(dt)
	for i = #droplets, 1, -1 do
		local d = droplets[i]
		d.life += dt
		local newVelocity = d.velocity + Vector3.new(0, -workspace.Gravity * 0.8, 0) * dt
		local step = (d.velocity + newVelocity) * 0.5 * dt
		local hit = workspace:Raycast(d.position, step, params)
		if hit then
			addSplat(hit.Position, hit.Normal, d.size * rng:NextNumber(3, 6), 0.15, d.pal)
			d.part:Destroy()
			table.remove(droplets, i)
		elseif d.life > 4 then
			d.part:Destroy()
			table.remove(droplets, i)
		else
			d.velocity = newVelocity
			d.position += step
			d.part.CFrame = CFrame.lookAt(d.position, d.position + newVelocity)
			local stretch = math.clamp(newVelocity.Magnitude / 40, 1, 2.5)
			d.part.Size = Vector3.new(d.size, d.size, d.size * stretch)
			local shape = Enum.PartType.Ball
			if d.part.Shape ~= shape then d.part.Shape = shape end
		end
	end
end)

-- a stream of drops out of a wound for a while
local function spurt(part, localOffset, duration, perTick, pal, bias)
	if not part or not part.Parent then return end
	task.spawn(function()
		local t = 0
		while t < duration and part.Parent do
			local cf = part.CFrame
			spawnDroplets(cf:PointToWorldSpace(localOffset), perTick, 8, 3, bias or cf.UpVector * 0.5, pal)
			task.wait(0.12)
			t += 0.12
		end
	end)
end

-- swelling bubbles that pop (stumps growing back, acid puddles)
local function bubble(position, size, pal, life)
	local b = newPart(Vector3.one * 0.05, pal[1]:Lerp(pal[2], rng:NextNumber()), 0.3)
	b.Shape = Enum.PartType.Ball
	if pal[4] then b.Material = Enum.Material.Neon b.Transparency = 0.3 end
	b.Position = position
	b.Parent = fxFolder
	tween(b, life or 0.6, {Size = Vector3.one * size, Position = position + Vector3.new(0, size * 0.4, 0)}, Enum.EasingStyle.Sine)
	task.delay(life or 0.6, function()
		if not b.Parent then return end
		b:Destroy()
		if rng:NextNumber() < 0.5 then spawnDroplets(position + Vector3.new(0, size * 0.4, 0), 2, 3, 2, nil, pal) end
	end)
end

-- ===== the screen =====
local screen = create("ScreenGui", {Name = "GS_CombatScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 27, Parent = playerGui})
local tint = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = ACID_UI, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = screen})
-- green creeping in from the edges (fumes): two soft bands, faded together
-- (hidden outright when there are no fumes: a CanvasGroup at GroupTransparency 1 still shows on some machines)
local vignette = create("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = screen})
for _, rotation in ipairs({0, 90}) do
	create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 130, 18), BorderSizePixel = 0, Parent = vignette}, {
		create("UIGradient", {
			Rotation = rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.22, 1), NumberSequenceKeypoint.new(0.78, 1), NumberSequenceKeypoint.new(1, 0.1),
			}),
		}),
	})
end
local flashFrame = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(210, 230, 255), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = screen})

-- goo on the lens: blobs that slide down slowly and fade (acid, spider goo)
local function screenGoo(count, pal, sizeScale, life)
	for _ = 1, count do
		local x = rng:NextNumber(0.08, 0.92)
		local y = rng:NextNumber(0.05, 0.75)
		local size = rng:NextInteger(70, 200) * (sizeScale or 1)
		local color = pal[1]:Lerp(pal[2], rng:NextNumber(0, 0.5))
		local blob = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(size, size * rng:NextNumber(0.7, 1.25)),
			Rotation = rng:NextNumber(0, 360), BackgroundColor3 = color, BackgroundTransparency = 0.12, BorderSizePixel = 0, Parent = screen,
		}, {
			create("UICorner", {CornerRadius = UDim.new(1, 0)}),
			create("UIGradient", {
				Rotation = rng:NextNumber(0, 360),
				Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.2), NumberSequenceKeypoint.new(1, 0.85)}),
			}),
		})
		-- a glossy highlight so it reads as wet
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.35, 0.32), Size = UDim2.fromScale(0.22, 0.14),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = blob,
		}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
		-- runs: a couple of drips hanging off the bottom
		for _ = 1, rng:NextInteger(1, 3) do
			local drip = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(rng:NextNumber(0.3, 0.7), 0.75), Size = UDim2.new(0, rng:NextInteger(8, 16), 0, 0),
				BackgroundColor3 = color, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = blob,
			}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
			tween(drip, rng:NextNumber(2.5, 5), {Size = UDim2.new(0, drip.Size.X.Offset, 0, rng:NextInteger(40, 140))}, Enum.EasingStyle.Sine)
		end
		local lifeNow = (life or 6) * rng:NextNumber(0.8, 1.2)
		tween(blob, lifeNow, {Position = UDim2.fromScale(x, y + rng:NextNumber(0.04, 0.14))}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		task.delay(lifeNow * 0.6, function()
			for _, d in ipairs(blob:GetDescendants()) do
				if d:IsA("Frame") then tween(d, lifeNow * 0.4, {BackgroundTransparency = 1}) end
			end
			tween(blob, lifeNow * 0.4, {BackgroundTransparency = 1})
		end)
		Debris:AddItem(blob, lifeNow + 0.2)
	end
end

-- the status card: web, trap, fumes (middle, a little below the crosshair)
local card = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(280, 58),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false, Parent = screen,
}, {create("UIStroke", {Color = LINE, Thickness = 1})})
local cardTitle = create("TextLabel", {
	Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18), BackgroundTransparency = 1, Font = FONT, TextSize = 16,
	TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = card,
})
local cardTime = create("TextLabel", {
	Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18), BackgroundTransparency = 1, Font = FONT, TextSize = 16,
	TextColor3 = AMBER, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = card,
})
local cardHint = create("TextLabel", {
	Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -24, 0, 14), BackgroundTransparency = 1, Font = FONT, TextSize = 12,
	TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = card,
})
local barBack = create("Frame", {
	Position = UDim2.new(0, 12, 1, -12), Size = UDim2.new(1, -24, 0, 4), BackgroundColor3 = Color3.fromRGB(30, 24, 22), BorderSizePixel = 0, Parent = card,
})
local barFill = create("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = AMBER, BorderSizePixel = 0, Parent = barBack})

local notice = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, -30), Size = UDim2.fromOffset(460, 22),
	BackgroundTransparency = 1, Font = FONT, TextSize = 18, TextColor3 = BRIGHT, TextStrokeTransparency = 0.4, TextTransparency = 1, Text = "", Parent = screen,
})
local noticeToken = 0
local function say(text, color)
	noticeToken += 1
	local my = noticeToken
	notice.Text = text
	notice.TextColor3 = color or BRIGHT
	notice.TextTransparency = 0
	task.delay(2.2, function()
		if my == noticeToken then tween(notice, 0.6, {TextTransparency = 1}) end
	end)
end

local function flash(color, strength, t)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - (strength or 0.5)
	tween(flashFrame, t or 0.35, {BackgroundTransparency = 1})
end

-- ===== creature health bars (a moment after each hit) =====
local bars = {}
-- (switched off: no health bars over creatures, you only see what the hit does to them)
local SHOW_BARS = false
local function showBar(model) end
local function dropBar(model)
	local entry = bars[model]
	if entry then
		entry.gui:Destroy()
		bars[model] = nil
	end
end

-- ===== spider remains =====
local function segment(a, b, width, color)
	local length = math.max((b - a).Magnitude, 0.05)
	local p = create("Part", {
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate, Color = color, Size = Vector3.new(length, width, width),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		CanCollide = true, CanQuery = false, CanTouch = false, CastShadow = true,
	})
	return p
end
local function ball(position, size, color, material)
	return create("Part", {
		Shape = Enum.PartType.Ball, Material = material or Enum.Material.Slate, Color = color, Size = Vector3.one * size,
		CFrame = CFrame.new(position), CanCollide = false, CanQuery = false, CanTouch = false, Massless = true,
	})
end

-- a torn-off leg: flies out, lands, twitches for a bit, lies there, then fades
local function deadLeg(hip, center, scale, stay)
	local out = hip - center
	out = Vector3.new(out.X, 0, out.Z)
	out = out.Magnitude > 0.05 and out.Unit or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
	local up = Vector3.yAxis
	local upperLen, lowerLen = 2.1 * scale, 2.6 * scale
	local knee = hip + out * upperLen * 0.7 + up * upperLen * 0.6
	local foot = knee + out * lowerLen * 0.5 - up * lowerLen * 0.85
	local model = create("Model", {Name = "GS_SpiderLeg"})
	local upper = segment(hip, knee, 0.22 * scale, CHITIN)
	local lower = segment(knee, foot, 0.15 * scale, CHITIN)
	upper.Parent, lower.Parent = model, model
	local kneeBall = ball(knee, 0.3 * scale, JOINT)
	local tip = ball(foot, 0.16 * scale, JOINT)
	local torn = ball(hip, 0.26 * scale, PALETTES.green[1], Enum.Material.SmoothPlastic) -- the wet torn end
	for _, p in ipairs({kneeBall, tip, torn}) do p.Parent = model end
	for _, p in ipairs({lower, kneeBall, tip, torn}) do
		create("WeldConstraint", {Part0 = upper, Part1 = p, Parent = p})
	end
	model.PrimaryPart = upper
	model.Parent = gooFolder
	upper.AssemblyLinearVelocity = out * rng:NextNumber(12, 26) * math.sqrt(scale) + up * rng:NextNumber(14, 26)
	upper.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 14
	task.spawn(function()
		-- a dribble of goo while it flies
		for _ = 1, 6 do
			task.wait(0.12)
			if not torn.Parent then return end
			spawnDroplets(torn.Position, 1, 3, 1, nil, PALETTES.green)
		end
		task.wait(0.9)
		if not upper.Parent then return end
		-- settled: pin it down (no tripping over it), then the last twitches
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false end
		end
		local base = model:GetPivot()
		local pivotAt = torn.Position
		local t0 = os.clock()
		local twitchFor = rng:NextNumber(3, 7)
		while os.clock() - t0 < twitchFor and model.Parent do
			local fade = 1 - (os.clock() - t0) / twitchFor
			local jerk = rng:NextNumber() < 0.35 and rng:NextNumber(-1, 1) * math.rad(14) * fade or 0
			if jerk ~= 0 then
				local around = CFrame.new(pivotAt) * CFrame.Angles(0, 0, jerk) * CFrame.Angles(jerk * 0.5, 0, 0) * CFrame.new(-pivotAt)
				model:PivotTo(around * base)
				task.wait(0.06)
				model:PivotTo(base)
			end
			task.wait(rng:NextNumber(0.15, 0.6))
		end
		task.wait(stay)
		if not model.Parent then return end
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then tween(p, 2, {Transparency = 1}) end
		end
		task.wait(2.1)
		model:Destroy()
	end)
end

local function spiderBurst(position, legs, scale, mother)
	scale = tonumber(scale) or 1
	local pal = PALETTES.green
	local anchor = anchorAt(position, 8)
	sound("Splat", anchor, mother and 1 or 0.8, mother and 0.7 or 1, 160)
	sound("Explosion", anchor, mother and 0.55 or 0.25, mother and 1.1 or 1.7, mother and 220 or 120)
	sound("Flesh", anchor, 0.7, 0.8, 120)
	-- the pop: a wet green ball swelling and gone
	local pop = ball(position, 0.5 * scale, pal[1], Enum.Material.SmoothPlastic)
	pop.Anchored = true
	pop.Transparency = 0.2
	pop.Parent = fxFolder
	tween(pop, 0.18, {Size = Vector3.one * (mother and 9 or 4) * scale, Transparency = 1})
	Debris:AddItem(pop, 0.3)
	spawnDroplets(position, mother and 150 or 70, (mother and 30 or 22) * math.sqrt(scale), 14, Vector3.new(0, 0.6, 0), pal)
	-- the goo where it burst
	task.delay(0.25, function()
		addPool(position, (mother and 8 or 3.6) * scale, 1.4, pal, 70)
		local hit = workspace:Raycast(position + Vector3.new(0, 1.5, 0), Vector3.new(0, -9, 0), params)
		if hit then
			for _ = 1, mother and 12 or 6 do
				local r = rng:NextNumber(1, (mother and 7 or 3.5) * scale)
				local a = rng:NextNumber(0, math.pi * 2)
				local spot = hit.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				local down = workspace:Raycast(spot + Vector3.new(0, 2, 0), Vector3.new(0, -5, 0), params)
				if down then addSplat(down.Position, down.Normal, rng:NextNumber(0.6, 1.8) * scale, 0.4, pal, 70) end
			end
			-- it keeps bubbling a little
			task.spawn(function()
				for _ = 1, mother and 18 or 8 do
					task.wait(rng:NextNumber(0.2, 0.5))
					local o = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 1.5 * scale
					bubble(hit.Position + o, rng:NextNumber(0.2, 0.45) * scale, pal, 0.7)
				end
			end)
		end
	end)
	if typeof(legs) == "table" then
		for _, hip in ipairs(legs) do
			if typeof(hip) == "Vector3" then deadLeg(hip, position, scale, mother and 26 or 16) end
		end
	end
	-- too close: some of it lands on you
	local head = player.Character and player.Character:FindFirstChild("Head")
	if head and (head.Position - position).Magnitude < (mother and 14 or 7) * scale then
		screenGoo(mother and 6 or 3, pal, 0.9, 5)
	end
end

-- ===== C-310's spit =====
local spitParams = RaycastParams.new()
spitParams.FilterType = Enum.RaycastFilterType.Exclude
spitParams.IgnoreWater = true
local function spitFlight(origin, velocity, gravity, t0)
	if typeof(origin) ~= "Vector3" or typeof(velocity) ~= "Vector3" then return end
	gravity = tonumber(gravity) or 40
	local pal = PALETTES.acid
	local g = Vector3.new(0, -gravity, 0)
	-- catch up with the server: it left a moment ago
	local late = math.clamp(now() - (tonumber(t0) or now()), 0, 0.3)
	local pos = origin + velocity * late + 0.5 * g * late * late
	local vel = velocity + g * late
	local function glob(size, transparency)
		return create("Part", {
			Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = pal[1], Transparency = transparency,
			Size = Vector3.one * size, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			CFrame = CFrame.new(pos), Parent = fxFolder,
		})
	end
	-- a wet glob with two smaller strings of spit trailing behind it on the same arc
	local head = glob(0.55, 0.05)
	local tails = {glob(0.36, 0.25), glob(0.22, 0.45)}
	local a0 = create("Attachment", {Position = Vector3.new(0, 0.2, 0), Parent = head})
	local a1 = create("Attachment", {Position = Vector3.new(0, -0.2, 0), Parent = head})
	create("Trail", {
		Attachment0 = a0, Attachment1 = a1, Lifetime = 0.18, LightEmission = 0.3, FaceCamera = true, MinLength = 0.05,
		Color = ColorSequence.new(pal[1], pal[2]), Transparency = NumberSequence.new(0.35, 1),
		WidthScale = NumberSequence.new(1, 0.1), Parent = head,
	})
	create("PointLight", {Color = pal[1], Range = 8, Brightness = 1, Parent = head})
	-- (unlike the stains, the spit stops on people: the server's arc does too)
	spitParams.FilterDescendantsInstances = {fxFolder, workspace:FindFirstChild("Monsters")}
	local history = {}
	local elapsed = 0
	local nextDrip = 0
	local conn
	-- drawn every rendered frame (not physics steps): no stutter on fast screens
	conn = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		elapsed += dt
		local newVel = vel + g * dt
		local step = (vel + newVel) * 0.5 * dt
		local hit = workspace:Raycast(pos, step, spitParams)
		if hit or elapsed > 3 then
			conn:Disconnect()
			head:Destroy()
			for _, t in ipairs(tails) do t:Destroy() end
			return
		end
		pos += step
		vel = newVel
		table.insert(history, 1, pos)
		if #history > 8 then table.remove(history) end
		-- stretched a little along the flight, like a thrown liquid
		local stretch = math.clamp(vel.Magnitude / 60, 1, 1.6)
		head.Size = Vector3.new(0.5, 0.5, 0.5 * stretch)
		head.CFrame = CFrame.lookAt(pos, pos + vel)
		for i, t in ipairs(tails) do
			local p = history[math.min(#history, i * 3)] or pos
			t.CFrame = CFrame.new(p)
		end
		if elapsed > nextDrip then
			nextDrip = elapsed + 0.06
			spawnDroplets(pos, 1, 1, 0.3, Vector3.new(0, -1, 0), pal)
		end
	end)
end

-- acid on your own face: the eyes blur and sting, spots of it land on the view and run down in streaks.
-- With a mask on it lands on the glass instead: a few runs down the visor and your eyes stay clear.
local acidBlur = create("BlurEffect", {Name = "GS_AcidBlur", Size = 0, Enabled = false, Parent = game:GetService("Lighting")})
local acidTint = create("ColorCorrectionEffect", {Name = "GS_AcidTint", Enabled = false, Parent = game:GetService("Lighting")})
local acidToken = 0
local function acidStreak(x, y, width, length, life, pal)
	local color = pal[1]:Lerp(pal[2], rng:NextNumber(0, 0.4))
	local streak = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(width, 0),
		BackgroundColor3 = color, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = screen,
	}, {
		create("UICorner", {CornerRadius = UDim.new(1, 0)}),
		create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 0),
		})}),
	})
	-- the bead at the bottom of the run
	local bead = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(width * 1.7, width * 1.9),
		BackgroundColor3 = color, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = streak,
	}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.35, 0.3), Size = UDim2.fromScale(0.3, 0.25),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = bead,
	}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
	-- runs down in a slowing crawl, then fades
	tween(streak, life * 0.75, {Size = UDim2.fromOffset(width, length)}, Enum.EasingStyle.Quart)
	task.delay(life * 0.55, function()
		tween(streak, life * 0.45, {BackgroundTransparency = 1})
		tween(bead, life * 0.45, {BackgroundTransparency = 1})
		for _, d in ipairs(bead:GetChildren()) do if d:IsA("Frame") then tween(d, life * 0.3, {BackgroundTransparency = 1}) end end
	end)
	Debris:AddItem(streak, life + 0.1)
end
local function acidSpot(x, y, size, life, pal)
	-- a splash spot: a few overlapping round drops, glossy, not one big flat disc
	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1, Parent = screen,
	})
	for i = 1, rng:NextInteger(3, 5) do
		local d = size * rng:NextNumber(0.3, 0.6)
		local drop = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rng:NextNumber(0.25, 0.75), rng:NextNumber(0.25, 0.75)),
			Size = UDim2.fromOffset(d, d * rng:NextNumber(0.8, 1.2)), BackgroundColor3 = pal[1]:Lerp(pal[2], rng:NextNumber(0, 0.5)),
			BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = holder,
		}, {
			create("UICorner", {CornerRadius = UDim.new(1, 0)}),
			create("UIGradient", {Rotation = rng:NextNumber(0, 360), Transparency = NumberSequence.new(0.1, 0.7)}),
		})
		if i == 1 then
			create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.35, 0.3), Size = UDim2.fromScale(0.25, 0.18),
				BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = drop,
			}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
		end
	end
	task.delay(life * 0.5, function()
		for _, d in ipairs(holder:GetDescendants()) do
			if d:IsA("Frame") then tween(d, life * 0.5, {BackgroundTransparency = 1}) end
		end
	end)
	Debris:AddItem(holder, life + 0.1)
	-- each spot leaves a run or two
	for _ = 1, rng:NextInteger(1, 2) do
		task.delay(rng:NextNumber(0.1, 0.5), function()
			acidStreak(x + rng:NextNumber(-0.015, 0.015), y, rng:NextNumber(5, 9), rng:NextNumber(60, 170), life, pal)
		end)
	end
end
local function acidFace(filtered)
	local pal = PALETTES.acid
	acidToken += 1
	local my = acidToken
	if filtered then
		for _ = 1, 3 do acidSpot(rng:NextNumber(0.3, 0.7), rng:NextNumber(0.2, 0.55), rng:NextNumber(40, 70), 3.5, pal) end
		flash(ACID_UI, 0.12, 0.3)
		return
	end
	-- where it hit: mostly the middle of the view
	for _ = 1, rng:NextInteger(4, 6) do
		acidSpot(rng:NextNumber(0.28, 0.72), rng:NextNumber(0.2, 0.6), rng:NextNumber(60, 130), rng:NextNumber(5, 7), pal)
	end
	flash(ACID_UI, 0.35, 0.6)
	acidBlur.Enabled = true
	acidBlur.Size = 16
	acidTint.Enabled = true
	acidTint.TintColor = Color3.fromRGB(214, 255, 176)
	acidTint.Saturation = -0.25
	acidTint.Contrast = 0.12
	tween(acidBlur, 3.5, {Size = 0}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	tween(acidTint, 5, {TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	task.delay(5.1, function()
		if my ~= acidToken then return end
		acidBlur.Enabled = false
		acidTint.Enabled = false
	end)
end

-- a puddle of acid: hisses, bubbles, glows faintly, then dries up
local function acidPuddle(position, life, radius)
	if typeof(position) ~= "Vector3" then return end
	life = tonumber(life) or 7
	radius = tonumber(radius) or 3
	local pal = PALETTES.acid
	local puddle = newPart(Vector3.new(0.05, 0.3, 0.3), pal[1], 0.2)
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Material = Enum.Material.Neon
	puddle.Transparency = 0.45
	puddle.CFrame = CFrame.new(position + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90))
	puddle.Parent = fxFolder
	local rim = newPart(Vector3.new(0.04, 0.3, 0.3), pal[2], 0.1)
	rim.Shape = Enum.PartType.Cylinder
	rim.CFrame = CFrame.new(position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
	rim.Parent = fxFolder
	tween(puddle, 0.5, {Size = Vector3.new(0.05, radius * 1.8, radius * 1.7)})
	tween(rim, 0.6, {Size = Vector3.new(0.04, radius * 2.1, radius * 2)})
	local light = create("PointLight", {Color = pal[1], Range = radius * 2.5, Brightness = 0.6, Parent = puddle})
	local hiss = create("Sound", {
		SoundId = ItemData.Sound("Sizzle") or "", Volume = 0.45, Looped = true, RollOffMaxDistance = 60, RollOffMinDistance = 5,
		PlaybackSpeed = rng:NextNumber(0.9, 1.1), Parent = puddle,
	})
	hiss:Play()
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < life and puddle.Parent do
			local r = rng:NextNumber(0, radius * 0.8)
			local a = rng:NextNumber(0, math.pi * 2)
			bubble(position + Vector3.new(math.cos(a) * r, 0.05, math.sin(a) * r), rng:NextNumber(0.15, 0.4), pal, 0.5)
			task.wait(low() and 0.45 or 0.18)
		end
		if not puddle.Parent then return end
		tween(hiss, 1.2, {Volume = 0})
		tween(light, 1.5, {Brightness = 0})
		tween(puddle, 1.5, {Transparency = 1, Size = Vector3.new(0.05, radius * 1.2, radius * 1.1)})
		tween(rim, 1.8, {Transparency = 1})
		task.wait(1.9)
		puddle:Destroy()
		rim:Destroy()
	end)
end

-- ===== creature events =====
local hitRemote = ReplicatedStorage:WaitForChild("GS_MonsterHit", 60)
if hitRemote then
	hitRemote.OnClientEvent:Connect(function(kind, a, b, c, d, e)
		if kind == "hit" then
			local model, position, blood, amount = a, b, c, tonumber(d) or 10
			if typeof(position) ~= "Vector3" then return end
			local pal = paletteOf(blood)
			spawnDroplets(position, math.clamp(math.floor(amount * 0.7), 4, 28), 8 + math.min(amount, 60) * 0.18, 5, nil, pal)
			sound("BloodHit",typeof(model)=="Instance" and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")),0.38,rng:NextNumber(.95,1.05),70)
			if amount >= 25 then
				task.delay(0.3, function() addPool(position, math.clamp(amount / 22, 1, 2.6), 1, pal) end)
			end
			showBar(model)
		elseif kind == "sever" then
			local model, position, blood, limbName = a, b, c, d
			if typeof(position) ~= "Vector3" then return end
			local pal = paletteOf(blood)
			spawnDroplets(position, 55, 20, 9, nil, pal)
			soundAt("Bone", position, 0.8, rng:NextNumber(0.8, 0.95), 120)
			soundAt("Flesh", position, 0.8, 0.9, 120)
			task.delay(0.4, function() addPool(position, 3, 2, pal) end)
			-- the stump pumps for a while
			local torso = typeof(model) == "Instance" and model:FindFirstChild("Torso")
			if torso then
				local offset = torso.CFrame:PointToObjectSpace(position)
				offset = Vector3.new(math.clamp(offset.X, -1.2, 1.2), math.clamp(offset.Y, -1.2, 1.2), 0)
				spurt(torso, offset, limbName == "Head" and 6 or 4, 2, pal)
			end
			-- and so does the piece that came off
			task.delay(0.15, function()
				local gibs = workspace:FindFirstChild("GS_Gibs")
				local best, bestD = nil, 12
				for _, holder in ipairs(gibs and gibs:GetChildren() or {}) do
					if holder.Name == "GS_Limb_" .. tostring(limbName) then
						local part = holder:FindFirstChild(tostring(limbName))
						if part and (part.Position - position).Magnitude < bestD then best, bestD = part, (part.Position - position).Magnitude end
					end
				end
				if best then spurt(best, Vector3.new(0, best.Size.Y * 0.45, 0), 3, 1, pal) end
			end)
		elseif kind == "regrow" then
			local position = b
			if typeof(position) ~= "Vector3" then return end
			local pal = PALETTES.black
			soundAt("Flesh", position, 0.8, 0.6, 90)
			task.delay(0.35, function() soundAt("Bone", position, 0.5, 0.7, 70) end)
			for i = 1, 10 do
				task.delay(i * 0.07, function()
					local o = Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6))
					bubble(position + o, rng:NextNumber(0.3, 0.6), pal, 0.45)
				end)
			end
			spawnDroplets(position, 16, 7, 4, nil, pal)
		elseif kind == "immune" then
			local position = b
			if typeof(position) ~= "Vector3" then return end
			soundAt("MetalHit", position, 0.35, rng:NextNumber(1.3, 1.6), 80)
			-- the round just flattens on it: a puff of grit
			for _ = 1, 6 do
				local bit = newPart(Vector3.one * 0.12, Color3.fromRGB(70, 66, 62), 0)
				bit.Position = position
				bit.Parent = fxFolder
				local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)).Unit
				tween(bit, 0.35, {Position = position + dir * rng:NextNumber(0.8, 1.8), Transparency = 1})
				Debris:AddItem(bit, 0.4)
			end
		elseif kind == "death" then
			local model, position, blood = a, b, c
			if typeof(position) ~= "Vector3" then return end
			local pal = paletteOf(blood)
			soundAt("Flesh", position, 0.9, 0.75, 140)
			spawnDroplets(position, 40, 12, 7, nil, pal)
			task.delay(1.2, function() addPool(position, 5.5, 5, pal, 70) end)
			dropBar(model)
		elseif kind == "spiderdeath" then
			local model, position, legs, scale, mother = a, b, c, d, e
			if typeof(position) ~= "Vector3" then return end
			dropBar(model)
			spiderBurst(position, legs, scale, mother == true)
		elseif kind == "spitwindup" then
			local model = a
			local head = typeof(model) == "Instance" and model:FindFirstChild("Head")
			if not head then return end
			sound("Flesh", head, 0.8, 0.5, 90)
			local glow = create("PointLight", {Color = PALETTES.acid[1], Range = 6, Brightness = 0, Parent = head})
			tween(glow, 0.5, {Brightness = 2.2})
			Debris:AddItem(glow, 0.7)
			for i = 1, 4 do
				task.delay(i * 0.1, function()
					if head.Parent then spawnDroplets(head.Position - Vector3.new(0, 0.4, 0), 1, 1.5, 0.5, Vector3.new(0, -1, 0), PALETTES.acid) end
				end)
			end
		elseif kind == "spit" then
			local model, origin, velocity, gravity, t0 = a, b, c, d, e
			local head = typeof(model) == "Instance" and model:FindFirstChild("Head")
			if head then
				sound("Spray", head, 0.5, 1.4, 100)
				sound("Flesh", head, 0.6, 1.3, 100)
			end
			spitFlight(origin, velocity, gravity, t0)
		elseif kind == "spitsplat" then
			local position, normal, victim = a, b, c
			if typeof(position) ~= "Vector3" then return end
			normal = typeof(normal) == "Vector3" and normal or Vector3.yAxis
			local pal = PALETTES.acid
			soundAt("Splat", position, 0.7, 1.1, 110)
			soundAt("Sizzle", position, 0.6, 1.2, 70)
			if typeof(victim) == "Instance" then
				-- it splashed over someone: spray off them, drips down their body, a sour haze. No stain in mid-air.
				spawnDroplets(position + normal * 0.3, 18, 9, 4, normal * 0.6, pal)
				local torso = victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart")
				if torso then
					local offset = torso.CFrame:PointToObjectSpace(position)
					offset = Vector3.new(math.clamp(offset.X, -0.9, 0.9), math.clamp(offset.Y, -0.5, 1.4), -0.55)
					spurt(torso, offset, 1.4, 1, pal, Vector3.new(0, -1.2, 0))
				end
				for i = 1, 3 do
					task.delay(i * 0.18, function() VFX.Smoke(position, Vector3.yAxis, 0.5, Color3.fromRGB(170, 200, 90)) end)
				end
			else
				spawnDroplets(position + normal * 0.2, 26, 12, 5, normal * 0.8, pal)
				addSplat(position, normal, rng:NextNumber(1.6, 2.4), 0.2, pal, 20)
			end
		elseif kind == "acidpuddle" then
			acidPuddle(a, b, c)
		elseif kind == "acidscreen" then
			-- a direct hit, on my own face
			local filtered = b == true
			acidFace(filtered)
			say(filtered and "the mask took it" or "IT BURNS", ACID_UI)
			local head = player.Character and player.Character:FindFirstChild("Head")
			if head then
				sound("Sizzle", head, 0.8, 1, 30)
				sound("Splat", head, 0.7, 1.2, 30)
			end
		end
	end)
end

-- ===== item events (sounds and bits for everyone; the owner's own texts are in InventoryUI) =====
local SLOT_PART = {head = "Head", face = "Head", torso = "Torso", torso_under = "Torso", arms = "Right Arm", legs = "Right Leg"}
local function wornPart(character, id)
	local item = ItemData.Get(id)
	local slot = item and item.slots and item.slots[1] or (item and item.slot)
	return character:FindFirstChild(SLOT_PART[slot or "torso"] or "Torso") or character:FindFirstChild("Torso")
end
local function heavy(id)
	local item = ItemData.Get(id)
	return item and ((item.weight or 0) >= 3 or tostring(id):find("helmet") ~= nil or tostring(id):find("vest") ~= nil)
end

local itemFx = ReplicatedStorage:WaitForChild("GS_ItemFX", 60)
if itemFx then
	itemFx.OnClientEvent:Connect(function(kind, character, id, extra)
		if kind == "toast" or typeof(character) ~= "Instance" then return end
		local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
		local item = ItemData.Get(id)
		local mine = character == player.Character
		if kind == "draw" then
			if item and item.kind == "gun" then
				sound("Click", head, 0.5, 0.9, 40)
				if item.pump then task.delay(0.2, function() sound("Rack", head, 0.45, 1.1, 50) end) end
			elseif item and item.kind == "melee" then
				sound("Swing", head, 0.2, 0.7, 30)
			else
				sound("Cloth", head, 0.35, 1.2, 30)
			end
		elseif kind == "stow" or kind == "pickup" or kind == "drop" then
			sound("Cloth", head, 0.35, kind == "drop" and 0.9 or 1.1, 35)
		elseif kind == "wear" or kind == "unwear" then
			sound("Cloth", head, 0.5, kind == "wear" and 1 or 1.15, 35)
			if heavy(id) then task.delay(0.15, function() sound("Plate", head, 0.35, 1.3, 40) end) end
		elseif kind == "armorbreak" then
			local part = wornPart(character, id)
			if not part then return end
			sound("MetalHit", part, 0.9, 0.7, 90)
			sound("Bone", part, 0.4, 1.4, 60)
			-- chips of the broken piece
			local color = Color3.fromRGB(40, 40, 42)
			for _ = 1, low() and 4 or 9 do
				local chip = create("Part", {
					Size = Vector3.new(rng:NextNumber(0.1, 0.35), rng:NextNumber(0.05, 0.12), rng:NextNumber(0.1, 0.3)),
					Color = color:Lerp(Color3.fromRGB(90, 86, 80), rng:NextNumber()), Material = Enum.Material.Metal,
					CFrame = part.CFrame * CFrame.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)),
					CanCollide = true, CanQuery = false, CanTouch = false, Parent = fxFolder,
				})
				chip.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1), rng:NextNumber(-1, 1)) * rng:NextNumber(10, 20)
				chip.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 20
				task.delay(4, function() if chip.Parent then tween(chip, 1, {Transparency = 1}) end end)
				Debris:AddItem(chip, 5.2)
			end
			if mine then
				say(((item and item.name) or "ARMOR") .. " BROKE", BRIGHT)
				flash(Color3.new(1, 1, 1), 0.2, 0.25)
			end
		elseif kind == "armorhit" then
 sound("Plate",head,0.3,0.9,45)
		elseif kind == "usebegin" then
 if mine then return end
			if item and item.id == "painkillers" then
				sound("Rattle", head, 0.5, 1, 30)
			elseif item and item.id == "adrenaline" then
				sound("Click", head, 0.4, 1.4, 25)
			elseif item and item.kind == "heal" then
				sound("Cloth", head, 0.5, 0.8, 30)
			end
		elseif kind == "used" then
			if item and item.id == "adrenaline" then
				sound("Spray", head, 0.3, 1.8, 25)
			elseif item and item.kind == "heal" then
				sound("Cloth", head, 0.45, 1.3, 30)
			end
		elseif kind == "trapset" then
			local model = character -- (the trap model)
			local pivot = model:IsA("Model") and model:GetPivot().Position or nil
			if pivot then soundAt("TrapSet", pivot, 0.7, 1, 50) end
		elseif kind == "trapopen" then
			local pivot = character:IsA("Model") and character:GetPivot().Position or nil
			if pivot then soundAt("TrapSet", pivot, 0.6, 1.2, 50) end
		elseif kind == "trapsnap" then
			local pivot = character:IsA("Model") and character:GetPivot().Position or nil
			if pivot then
				soundAt("TrapSnap", pivot, 1, 1, 140)
				soundAt("Bone", pivot, 0.7, 0.9, 90)
			end
			local victim = id
			if typeof(victim) == "Instance" and victim == player.Character then
				flash(Color3.fromRGB(160, 10, 10), 0.35, 0.5)
			end
		end
	end)
end

-- ===== my own state: web, trap, fumes, shock =====
local lastShock = nil
local cardWas = nil
RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		card.Visible = false
		vignette.GroupTransparency = 1
		vignette.Visible = false
		return
	end
	local t = now()
	local shown = nil
	-- caught in a web: down in the threads, getting up slowly (no concussion, just the timer)
	local webUntil = character:GetAttribute("GS_WebStun") or 0
	local trapUntil = character:GetAttribute("GS_Trapped") or 0
	if webUntil > t then
		local dur = math.max(character:GetAttribute("GS_WebStunDur") or 5, 0.5)
		local left = webUntil - t
		local p = math.clamp(1 - left / dur, 0, 1)
		shown = "web"
		cardTitle.Text = p < 0.35 and "CAUGHT IN THE WEB" or "GETTING UP"
		cardTime.Text = string.format("%.1f", left)
		cardHint.Text = p < 0.35 and "the threads hold you down" or "pulling free of the threads"
		barFill.BackgroundColor3 = INK
		barFill.Size = UDim2.fromScale(p, 1)
	elseif typeof(trapUntil) == "number" and trapUntil > t then
		local left = trapUntil - t
		shown = "trap"
		cardTitle.Text = "LEG IN A TRAP"
		cardTime.Text = string.format("%.1f", left)
		cardHint.Text = "the jaws let go soon - someone can pry it open"
		barFill.BackgroundColor3 = BRIGHT
		barFill.Size = UDim2.fromScale(math.clamp(1 - left / 4, 0, 1), 1)
	elseif (character:GetAttribute("GS_Poison") or 0) > t then
		local left = character:GetAttribute("GS_Poison") - t
		shown = "acid"
		cardTitle.Text = "ACID FUMES"
		cardTime.Text = string.format("%.1f", left)
		cardHint.Text = character:GetAttribute("GS_Filter") and "the filter is clearing it" or "a gas mask would stop this"
		barFill.BackgroundColor3 = ACID_UI
		barFill.Size = UDim2.fromScale(math.clamp(left / 6, 0, 1), 1)
	end
	if shown ~= cardWas then
		cardWas = shown
		if shown then
			card.Visible = true
			card.BackgroundTransparency = 1
			tween(card, 0.2, {BackgroundTransparency = 0.15})
		else
			card.Visible = false
		end
	end
	-- the fumes: the edges of the screen go green and throb
	if shown == "acid" then
		vignette.Visible = true
		vignette.GroupTransparency = 0.45 + 0.25 * math.sin(os.clock() * 4)
	elseif vignette.Visible then
		vignette.GroupTransparency = math.min(1, vignette.GroupTransparency + 0.02)
		if vignette.GroupTransparency >= 0.99 then vignette.Visible = false end
	end
	-- a shock baton hit: a white flash and a buzz
	local shock = character:GetAttribute("GS_Shocked")
	if shock and shock ~= lastShock then
		lastShock = shock
		if t - shock < 1 then
			flash(Color3.fromRGB(200, 225, 255), 0.7, 0.6)
			local torso = character:FindFirstChild("Torso")
			if torso then sound("Shock", torso, 0.7, 1, 40) end
		end
	end
end)

-- everyone's sparks when someone gets shocked
local function watchShock(character)
	character:GetAttributeChangedSignal("GS_Shocked"):Connect(function()
		local torso = character:FindFirstChild("Torso")
		if not torso then return end
		local att = create("Attachment", {Parent = torso})
 VFX.Sparks(torso.Position,Vector3.yAxis,Color3.fromRGB(150,190,255),low() and 5 or 10)
		local light = create("PointLight", {Color = Color3.fromRGB(170, 210, 255), Range = 10, Brightness = 3, Parent = att})
		tween(light, 0.5, {Brightness = 0})
		Debris:AddItem(att, 1)
	end)
end
local function onPlayer(plr)
	if plr.Character then watchShock(plr.Character) end
	plr.CharacterAdded:Connect(watchShock)
end
for _, plr in ipairs(Players:GetPlayers()) do onPlayer(plr) end
Players.PlayerAdded:Connect(onPlayer)
