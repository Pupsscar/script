-- Guns and melee in your hands.
--   LMB fire / swing, RMB aim (tighter spread, closer view), R reload.  Touch: USE, AIM, RELOAD buttons.
--   The crosshair is a ring: its size IS the spread - where the pellets can land. Aim and stand still: it closes.
--   Shots show at once (tracers, flash, shells, kick); the server replays the same seed and decides the damage.
-- Other people's shots, reloads and swings are drawn and heard here too.
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local weaponRemote = ReplicatedStorage:WaitForChild("GS_Weapon", 60)
local syncRemote = ReplicatedStorage:WaitForChild("GS_InvSync", 60)
if not weaponRemote or not syncRemote then return end
local clientAction = player:WaitForChild("GS_ClientAction", 30)

local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local FONT = Enum.Font.SpecialElite
local INK = Color3.fromRGB(236, 230, 222)
local DIM = Color3.fromRGB(130, 122, 116)
local BRIGHT = Color3.fromRGB(225, 40, 40)
local AMBER = Color3.fromRGB(232, 164, 52)

local function create(className, props, children)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = obj end
	return obj
end
local function tween(obj, t, goal, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local fxFolder = workspace:FindFirstChild("GS_FX") or create("Folder", {Name = "GS_FX", Parent = workspace})

local function sound(name, parent, volume, speed, maxDist)
	local id = ItemData.Sound(name)
	if not id then return end
	local s = create("Sound", {
		SoundId = id, Volume = volume or 0.7, PlaybackSpeed = speed or 1, RollOffMaxDistance = maxDist or 250,
		RollOffMinDistance = 8, Parent = parent or workspace,
	})
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	Debris:AddItem(s, 8)
end

-- ===== what's in the hand =====
local bag = {items = {}}
local function held()
	if not bag.held then return nil end
	for _, e in ipairs(bag.items) do
		if e.uid == bag.held then return e, ItemData.Get(e.id) end
	end
	return nil
end
syncRemote.OnClientEvent:Connect(function(snap)
	if typeof(snap) == "table" then bag = snap end
end)

local function myCharacter()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return nil end
	return c, h
end

local function busy()
	return player:GetAttribute("GS_WheelOpen") or player:GetAttribute("GS_Minigame") or player:GetAttribute("InMenu")
		or (player:GetAttribute("UIOpen") and not player:GetAttribute("GS_WheelOpen"))
end

-- ===== the crosshair =====
local gui = create("ScreenGui", {
	Name = "GS_Crosshair", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 43, Enabled = false, Parent = playerGui,
})
local cross = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Parent = gui})
local ring = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40),
	BackgroundTransparency = 1, Parent = cross,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
local ringStroke = create("UIStroke", {Color = INK, Thickness = 1.5, Transparency = 0.15, Parent = ring})
local ringShadow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 4, 1, 4),
	BackgroundTransparency = 1, Parent = ring,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)}), create("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.6})})
local dot = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4),
	BackgroundColor3 = BRIGHT, BorderSizePixel = 0, Parent = cross,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)}), create("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.4})})
-- four short ticks on the ring
local ticks = {}
for i = 0, 3 do
	ticks[i] = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(i % 2 == 0 and 2 or 7, i % 2 == 0 and 7 or 2),
		BackgroundColor3 = INK, BorderSizePixel = 0, Parent = cross,
	})
end
-- hit marker: four diagonal strokes
local marks = {}
for i = 0, 3 do
	local a = math.rad(45 + i * 90)
	marks[i] = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 12, 0.5, math.sin(a) * 12),
		Size = UDim2.fromOffset(9, 2), Rotation = math.deg(a), BackgroundColor3 = INK, BackgroundTransparency = 1, BorderSizePixel = 0,
		Parent = cross,
	})
end
local hitText = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 12, 0.5, -18), Size = UDim2.fromOffset(120, 18), BackgroundTransparency = 1,
	Font = FONT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, TextTransparency = 1,
	TextStrokeTransparency = 0.5, Parent = cross,
})
-- ammo, bottom right
local ammoPanel = create("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -150), Size = UDim2.fromOffset(170, 56),
	BackgroundColor3 = Color3.fromRGB(8, 6, 6), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = gui,
}, {create("UIStroke", {Color = Color3.fromRGB(70, 8, 10), Thickness = 1})})
create("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Color3.fromRGB(150, 12, 16), BorderSizePixel = 0, Parent = ammoPanel})
local gunName = create("TextLabel", {
	Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -18, 0, 14), BackgroundTransparency = 1, Font = FONT, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM, Parent = ammoPanel,
})
local ammoText = create("TextLabel", {
	Position = UDim2.fromOffset(12, 18), Size = UDim2.new(1, -18, 0, 32), BackgroundTransparency = 1, Font = FONT, TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, RichText = true, Parent = ammoPanel,
})
local reloadBar = create("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, 0), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = AMBER,
	BorderSizePixel = 0, Parent = ammoPanel,
})

local function flashMarks(color, text)
	for _, m in pairs(marks) do
		m.BackgroundColor3 = color
		m.BackgroundTransparency = 0
		tween(m, 0.35, {BackgroundTransparency = 1})
	end
	if text then
		hitText.Text = text
		hitText.TextColor3 = color
		hitText.TextTransparency = 0
		hitText.Position = UDim2.new(1, 12, 0.5, -18)
		tween(hitText, 0.8, {TextTransparency = 1, Position = UDim2.new(1, 12, 0.5, -34)})
	end
end

-- ===== state =====
local aiming = false
local lastShot = 0
local lastSwing = 0
local reloadingUntil = 0
local reloadStarted = 0
local kick = 0 -- visual ring punch after a shot
local seedBase = math.random(1, 2 ^ 20)
local seedCount = 0
local baseFov = nil

local function currentSpread(item, character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local moving = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 3
	return (aiming and item.aimSpread or item.spread) * (moving and 1.3 or 1)
end

-- the point on screen the crosshair sits on
local function aimScreenPoint()
	local camera = workspace.CurrentCamera
	if TOUCH or aiming or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return camera.ViewportSize / 2
	end
	return UserInputService:GetMouseLocation()
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function refreshParams(character)
	local ignore = {character, fxFolder}
	for _, name in ipairs({"GS_Items", "GS_Traps", "SpiderWebs", "GS_Hallucinations", "PS_Blood", "GS_Tentacles"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(ignore, f) end
	end
	rayParams.FilterDescendantsInstances = ignore
end

local function muzzleOf(character, look)
	local heldModel = character:FindFirstChild("GS_Held")
	local head = character:FindFirstChild("Head")
	local best, bestD = head and head.Position or character:GetPivot().Position, -math.huge
	if heldModel then
		for _, p in ipairs(heldModel:GetDescendants()) do
			if p:IsA("BasePart") then
				local d = p.Position:Dot(look)
				if d > bestD then best, bestD = p.Position + look * (p.Size.X * 0.4), d end
			end
		end
	end
	return best
end

-- ===== effects =====
local function tracer(from, to, color)
	local length = (to - from).Magnitude
	if length < 0.5 then return end
	local p = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.Neon, Color = color or Color3.fromRGB(255, 220, 150), Transparency = 0.2,
		Size = Vector3.new(0.06, 0.06, length), CFrame = CFrame.lookAt((from + to) / 2, to), Parent = fxFolder,
	})
	tween(p, 0.09, {Transparency = 1, Size = Vector3.new(0.02, 0.02, length)})
	Debris:AddItem(p, 0.12)
end

local function puff(position, normal, color)
	local a = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position), Parent = fxFolder,
	})
	local e = create("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(color or Color3.fromRGB(120, 112, 100)),
		Size = NumberSequence.new(0.3, 1.1), Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(30, 30), Rate = 0, EmissionDirection = Enum.NormalId.Top, Parent = a,
	})
	if normal then a.CFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0) end
	e:Emit(4)
	Debris:AddItem(a, 1)
end

local function flash(position, look)
	local p = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 110), Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Transparency = 0.1,
		CFrame = CFrame.new(position), Parent = fxFolder,
	})
	create("PointLight", {Color = Color3.fromRGB(255, 190, 110), Range = 16, Brightness = 5, Parent = p})
	tween(p, 0.06, {Transparency = 1, Size = Vector3.new(1.6, 1.6, 1.6)})
	Debris:AddItem(p, 0.08)
	local smoke = create("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.lookAt(position, position + look), Parent = fxFolder,
	})
	local e = create("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(200, 196, 190)),
		Size = NumberSequence.new(0.4, 1.8), Transparency = NumberSequence.new(0.55, 1), Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(15, 15), Rate = 0, EmissionDirection = Enum.NormalId.Front, Parent = smoke,
	})
	e:Emit(6)
	Debris:AddItem(smoke, 1.2)
end

local function ejectShell(character, sideways)
	local held = character:FindFirstChild("GS_Held")
	local base = held and held:FindFirstChildWhichIsA("BasePart")
	if not base then return end
	local shell = create("Part", {
		CanCollide = true, CanQuery = false, CanTouch = false, Size = Vector3.new(0.14, 0.14, 0.34), Color = Color3.fromRGB(170, 24, 24),
		Material = Enum.Material.SmoothPlastic, CFrame = base.CFrame * CFrame.new(0, 0.2, 0), Parent = fxFolder,
	})
	create("Part", {
		CanCollide = false, CanQuery = false, Massless = true, Size = Vector3.new(0.15, 0.15, 0.08), Color = Color3.fromRGB(196, 160, 72),
		Material = Enum.Material.Metal, CFrame = shell.CFrame * CFrame.new(0, 0, 0.18), Parent = shell,
	}, {})
	local w = create("WeldConstraint", {Part0 = shell, Part1 = shell:FindFirstChildOfClass("Part"), Parent = shell})
	local right = base.CFrame.RightVector * (sideways or 1)
	shell.AssemblyLinearVelocity = right * 9 + Vector3.new(0, 10, 0)
	shell.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, 0)
	task.delay(0.45, function() if shell.Parent then sound("ShellDrop", shell, 0.4, 1) end end)
	Debris:AddItem(shell, 8)
	return w
end

local function shotSound(item, parent, isMine)
	if item.fire then
		sound("Flare", parent, 0.8, 0.9, 300)
		sound("Sizzle", parent, 0.4, 1.3, 120)
	else
		sound("Shotgun", parent, isMine and 1 or 0.9, item.id == "doublebarrel" and 0.78 or 0.9, 400)
	end
end

-- ===== firing =====
local function fire()
	local character = myCharacter()
	if not character or busy() then return end
	local e, item = held()
	if not e or item.kind ~= "gun" then return end
	local now = os.clock()
	if now - lastShot < 60 / item.rpm then return end
	local head = character:FindFirstChild("Head")
	if not head then return end
	if (e.ammo or 0) <= 0 then
		lastShot = now
		sound("Click", head, 0.6, 1.6, 40)
		if now > reloadingUntil then
			weaponRemote:FireServer("reload", e.uid)
			reloadStarted = now
			reloadingUntil = now + item.reload * (item.reloadPerShell and item.magazine or 1)
			character:SetAttribute("GS_ReloadAt", now)
		end
		return
	end
	lastShot = now
	e.ammo -= 1
	reloadingUntil = 0
	local camera = workspace.CurrentCamera
	refreshParams(character)
	local screen = aimScreenPoint()
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local target = workspace:Raycast(ray.Origin, ray.Direction * (item.range + 40), rayParams)
	local aimPoint = target and target.Position or (ray.Origin + ray.Direction * item.range)
	local origin = head.Position
	local look = CFrame.lookAt(origin, aimPoint)
	seedCount += 1
	local seed = seedBase + seedCount
	local spread = currentSpread(item, character)
	local muzzle = muzzleOf(character, look.LookVector)
	for _, dir in ipairs(ItemData.Pellets(item, look, seed, spread)) do
		local hit = workspace:Raycast(origin, dir * item.range, rayParams)
		local endPos = hit and hit.Position or (origin + dir * item.range)
		tracer(muzzle, endPos, item.fire and Color3.fromRGB(255, 90, 60) or nil)
		if hit then puff(hit.Position, hit.Normal) end
	end
	weaponRemote:FireServer("fire", e.uid, look, seed, aiming)
	flash(muzzle, look.LookVector)
	shotSound(item, head, true)
	kick = math.min(kick + item.recoil * 0.9, 30)
	character:SetAttribute("GS_RecoilAt", now)
	-- the view jumps a little
	camera.FieldOfView += item.recoil * 0.25
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.CameraOffset = Vector3.new(math.random(-10, 10) / 100, item.recoil * 0.025, 0)
		task.delay(0.08, function() if hum.Parent then hum.CameraOffset = Vector3.zero end end)
	end
	if item.pump then
		task.delay(0.32, function()
			sound("Rack", head, 0.6, 1.1, 60)
			character:SetAttribute("GS_PumpAt", os.clock())
			ejectShell(character)
		end)
	end
end

local function reload()
	local character = myCharacter()
	if not character or busy() then return end
	local e, item = held()
	if not e or item.kind ~= "gun" or (e.ammo or 0) >= item.magazine then return end
	local now = os.clock()
	if now < reloadingUntil then return end
	weaponRemote:FireServer("reload", e.uid)
	reloadStarted = now
	reloadingUntil = now + item.reload * (item.reloadPerShell and (item.magazine - (e.ammo or 0)) or 1)
	character:SetAttribute("GS_ReloadAt", now)
	character:SetAttribute("GS_ReloadDur", reloadingUntil - now)
end

local function swing()
	local character = myCharacter()
	if not character or busy() then return end
	local e, item = held()
	if not e or item.kind ~= "melee" then return end
	local now = os.clock()
	if now - lastSwing < item.cooldown then return end
	lastSwing = now
	character:SetAttribute("GS_AttackStart", now)
	local camera = workspace.CurrentCamera
	weaponRemote:FireServer("swing", e.uid, camera.CFrame.LookVector)
	local head = character:FindFirstChild("Head")
	sound("Swing", head, 0.5, item.id == "knife" and 1.4 or 1, 40)
	if item.stun then sound("ShockWhoosh", head, 0.35, 1.2, 50) end
end

local function setAim(value)
	local character = myCharacter()
	local _, item = held()
	if value and (not character or not item or item.kind ~= "gun" or busy()) then value = false end
	if value == aiming then return end
	aiming = value
	local camera = workspace.CurrentCamera
	if aiming then
		baseFov = baseFov or camera.FieldOfView
		tween(camera, 0.15, {FieldOfView = baseFov - 16})
		if not TOUCH then UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end
	else
		if baseFov then tween(camera, 0.15, {FieldOfView = baseFov}) end
		if not TOUCH and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and not player:GetAttribute("GS_ShiftLock") then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
	if character then character:SetAttribute("GS_Aim", aiming or nil) end
end

-- ===== input =====
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local _, item = held()
	if not item then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if item.kind == "gun" then fire() elseif item.kind == "melee" then swing() end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and item.kind == "gun" then
		setAim(true)
	elseif input.KeyCode == Enum.KeyCode.R and item.kind == "gun" then
		reload()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then setAim(false) end
end)
if clientAction then
	clientAction.Event:Connect(function(action)
		local _, item = held()
		if not item then return end
		if action == "use" then
			if item.kind == "gun" then fire() elseif item.kind == "melee" then swing() end
		elseif action == "aim" then
			setAim(not aiming)
		elseif action == "reload" then
			reload()
		end
	end)
end

-- ===== every frame =====
RunService.RenderStepped:Connect(function(dt)
	local character = myCharacter()
	local e, item = held()
	local gun = character and item and item.kind == "gun" and not busy()
	gui.Enabled = gun == true
	player:SetAttribute("GS_Crosshair", gun == true or nil)
	if not gun then
		if aiming then setAim(false) end
		return
	end
	local camera = workspace.CurrentCamera
	local point = aimScreenPoint()
	cross.Position = UDim2.fromOffset(point.X, point.Y)
	kick = math.max(0, kick - dt * 40)
	local spread = currentSpread(item, character)
	local fov = math.rad(camera.FieldOfView / 2)
	local radius = math.tan(math.rad(spread)) / math.tan(fov) * (camera.ViewportSize.Y / 2)
	radius = math.max(radius, 6) + kick
	ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
	for i, t in pairs(ticks) do
		local a = math.rad(i * 90 - 90)
		t.Position = UDim2.new(0.5, math.cos(a) * (radius + 5), 0.5, math.sin(a) * (radius + 5))
	end
	ringStroke.Color = aiming and Color3.fromRGB(255, 255, 255) or INK
	ringStroke.Transparency = aiming and 0 or 0.15
	-- aiming turns the body to where the camera looks
	if aiming then
		local root = character:FindFirstChild("HumanoidRootPart")
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if root and flat.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end
	-- ammo panel
	local spare = 0
	for _, other in ipairs(bag.items) do
		if other.id == item.ammo then spare += other.n end
	end
	gunName.Text = item.name
	local loaded = e.ammo or 0
	ammoText.Text = string.format('<font color="#%s">%d</font><font size="18" color="#8a827c"> / %d   |   %d</font>',
		loaded > 0 and "ECE6DE" or "E12828", loaded, item.magazine, spare)
	local now = os.clock()
	if now < reloadingUntil then
		reloadBar.Size = UDim2.new(math.clamp((now - reloadStarted) / math.max(reloadingUntil - reloadStarted, 0.01), 0, 1), -3, 0, 2)
	else
		reloadBar.Size = UDim2.new(0, 0, 0, 2)
	end
end)

-- ===== what the server says =====
weaponRemote.OnClientEvent:Connect(function(kind, a, b, c, d)
	local myChar = player.Character
	if kind == "hits" then
		local best = "hit"
		local total = 0
		for _, r in ipairs(a) do
			total += r[2] or 0
			if r[1] == "kill" then best = "kill" elseif r[1] == "head" and best ~= "kill" then best = "head"
			elseif r[1] == "immune" and best == "hit" and total == 0 then best = "immune" end
		end
		if best == "immune" then
			flashMarks(DIM, "NO EFFECT")
		else
			flashMarks(best == "kill" and BRIGHT or (best == "head" and AMBER or INK), best == "kill" and "KILL" or tostring(total))
		end
	elseif kind == "noammo" then
		local item = ItemData.Get(a)
		hitText.Text = "no " .. (item and item.name:lower() or "ammo")
		hitText.TextColor3 = BRIGHT
		hitText.TextTransparency = 0
		tween(hitText, 1.2, {TextTransparency = 1})
		reloadingUntil = 0
	elseif kind == "shot" then
		-- someone else's shot: their tracers, their flash, their bang
		local character, itemId, startPos, ends = a, b, c, d
		if character == myChar or typeof(character) ~= "Instance" then return end
		local item = ItemData.Get(itemId)
		if not item then return end
		local look = (#ends > 0 and (ends[1] - startPos).Unit) or Vector3.new(0, 0, -1)
		local muzzle = muzzleOf(character, look)
		for _, p in ipairs(ends) do tracer(muzzle, p, item.fire and Color3.fromRGB(255, 90, 60) or nil) end
		flash(muzzle, look)
		shotSound(item, character:FindFirstChild("Head") or character.PrimaryPart, false)
		if item.pump then task.delay(0.32, function() if character.Parent then sound("Rack", character:FindFirstChild("Head"), 0.5, 1.1, 60) ejectShell(character) end end) end
	elseif kind == "reload" then
		local character, itemId, mode = a, b, c
		if typeof(character) ~= "Instance" then return end
		local head = character:FindFirstChild("Head")
		if mode == "full" then
			-- break it open, the old shells fly out
			sound("Click", head, 0.7, 0.8, 50)
			task.delay(0.25, function() if character.Parent then ejectShell(character, -1) ejectShell(character, 1) end end)
		else
			sound("Click", head, 0.5, 1.2, 40)
		end
	elseif kind == "shellin" then
		local head = typeof(a) == "Instance" and a:FindFirstChild("Head")
		if head then sound("ShellIn", head, 0.6, 1.1, 40) end
	elseif kind == "reloaded" then
		local character, itemId = a, b
		local head = typeof(character) == "Instance" and character:FindFirstChild("Head")
		if head then
			local item = ItemData.Get(itemId)
			if item and item.pump then sound("Rack", head, 0.6, 1, 50) else
				sound("ShellIn", head, 0.6, 1, 40)
				task.delay(0.2, function() sound("Click", head, 0.7, 0.7, 50) end)
			end
		end
		if character == myChar then
			reloadingUntil = 0
			if myChar then myChar:SetAttribute("GS_ReloadAt", nil) end
		end
	elseif kind == "swing" then
		local character, itemId = a, b
		if character == myChar or typeof(character) ~= "Instance" then return end
		local item = ItemData.Get(itemId)
		sound("Swing", character:FindFirstChild("Head"), 0.5, item and item.id == "knife" and 1.4 or 1, 40)
	elseif kind == "impact" then
		local model, position, itemId = a, b, c
		local item = ItemData.Get(itemId)
		if typeof(position) ~= "Vector3" or not item then return end
		local anchor = create("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = CFrame.new(position), Parent = fxFolder,
		})
		Debris:AddItem(anchor, 4)
		if item.sound == "metal" then sound("MetalHit", anchor, 0.7, 1.1, 60) end
		sound("BloodHit", anchor, 0.7, 1, 60)
		if item.stun then
			sound("Shock", anchor, 0.8, 1, 60)
			local e = create("ParticleEmitter", {
				Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(140, 190, 255)),
				LightEmission = 1, Size = NumberSequence.new(0.35, 0), Lifetime = NumberRange.new(0.15, 0.35), Speed = NumberRange.new(8, 18),
				SpreadAngle = Vector2.new(180, 180), Rate = 0, Parent = anchor,
			})
			e:Emit(26)
			create("PointLight", {Color = Color3.fromRGB(140, 190, 255), Range = 10, Brightness = 4, Parent = anchor})
		end
	end
end)

player.CharacterAdded:Connect(function()
	aiming = false
	reloadingUntil = 0
	local camera = workspace.CurrentCamera
	if baseFov and camera then camera.FieldOfView = baseFov end
end)
