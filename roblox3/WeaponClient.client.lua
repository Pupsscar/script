local kickRecoil
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
local VFX=require(Modules:WaitForChild("CustomVFX"))

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

local Audio=require(Modules:WaitForChild("CombatAudio"))
local function sound(name,parent,volume,speed,maxDist)
 return Audio.Play(name,parent or workspace,volume,speed,maxDist)
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
local dot=create("Frame",{
 Name="AimDot",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
 Size=UDim2.fromOffset(3,3),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Parent=cross
},{create("UICorner",{CornerRadius=UDim.new(1,0)}),create("UIStroke",{Color=Color3.new(0,0,0),Transparency=0.65,Thickness=1})})
local hitText = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 12, 0.5, -18), Size = UDim2.fromOffset(120, 18), BackgroundTransparency = 1,
	Font = FONT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, TextTransparency = 1,
	TextStrokeTransparency = 0.5, Parent = cross,
})
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

-- ===== the ammo, right next to the gun (only the one holding it sees it) =====
-- A little tag hangs beside the weapon: its name, one shell per chamber / tube slot (full ones in colour, empty
-- ones as outlines), the spare rounds in your bag, and "EMPTY" / "LOADING" when it matters. It lights up when you
-- shoot, load or aim, and dims when you just carry the gun around.
local AMMO_LOOK = {
	shells12 = {w = 11, h = 28, hull = Color3.fromRGB(176, 32, 28), hull2 = Color3.fromRGB(110, 16, 14)},
	flareshell = {w = 17, h = 30, hull = Color3.fromRGB(236, 116, 44), hull2 = Color3.fromRGB(160, 64, 22), band = true},
}
local hud = create("BillboardGui", {
	Name = "GS_AmmoHUD", Size = UDim2.fromOffset(200, 74), StudsOffset = Vector3.new(1.9, 0.4, 0), AlwaysOnTop = true,
	LightInfluence = 0, MaxDistance = 80, ResetOnSpawn = false, Enabled = false, Parent = playerGui,
})
local hudPaint = {} -- {object, property, base transparency}
local function painted(obj, prop, base)
	table.insert(hudPaint, {obj, prop, base})
	return obj
end
local leader = painted(create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0, 34), Size = UDim2.fromOffset(16, 1),
	BackgroundColor3 = INK, BorderSizePixel = 0, Parent = hud,
}), "BackgroundTransparency", 0.35)
painted(create("Frame", { -- the dot where the line meets the gun
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 34), Size = UDim2.fromOffset(4, 4),
	BackgroundColor3 = INK, BorderSizePixel = 0, Parent = hud,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})}), "BackgroundTransparency", 0.2)
local card = painted(create("Frame", {
	Position = UDim2.fromOffset(18, 4), Size = UDim2.new(1, -20, 1, -8), BackgroundColor3 = Color3.fromRGB(8, 7, 7),
	BorderSizePixel = 0, Parent = hud,
}, {
	create("UICorner", {CornerRadius = UDim.new(0, 4)}),
	create("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6)})}),
}), "BackgroundTransparency", 0.35)
local hudName = painted(create("TextLabel", {
	Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -60, 0, 13), BackgroundTransparency = 1, Font = FONT, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM, Text = "", Parent = card,
}), "TextTransparency", 0)
local hudSpare = painted(create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 3), Size = UDim2.fromOffset(60, 13), BackgroundTransparency = 1,
	Font = FONT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = INK, Text = "", Parent = card,
}), "TextTransparency", 0)
local slotRow = create("Frame", {Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 0, 32), BackgroundTransparency = 1, Parent = card},
	{create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Bottom})})
local hudStatus = create("TextLabel", {
	Position = UDim2.fromOffset(8, 51), Size = UDim2.new(1, -16, 0, 12), BackgroundTransparency = 1, Font = FONT, TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BRIGHT, Text = "", Parent = card,
})
local hudBar = create("Frame", {
	Position = UDim2.fromOffset(8, 63), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = AMBER, BorderSizePixel = 0, Parent = card,
})

local slots = {}
local slotKey = nil
local shownLoaded = nil
local hudActiveUntil = 0
local function bumpHud() hudActiveUntil = os.clock() + 3 end
local function buildSlots(item)
	for _, sl in ipairs(slots) do sl.frame:Destroy() end
	slots = {}
	local look = AMMO_LOOK[item.ammo] or AMMO_LOOK.shells12
	for i = 1, item.magazine do
		local frame = create("Frame", {Size = UDim2.fromOffset(look.w, look.h), BackgroundTransparency = 1, LayoutOrder = i, Parent = slotRow})
		local scale = create("UIScale", {Parent = frame})
		local hull = create("Frame", {
			Size = UDim2.new(1, 0, 1, -7), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = frame,
		}, {
			create("UICorner", {CornerRadius = UDim.new(0, 3)}),
			create("UIGradient", {Rotation = 0, Color = ColorSequence.new(look.hull, look.hull2)}),
		})
		local head = create("Frame", {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 7),
			BackgroundColor3 = Color3.fromRGB(206, 168, 80), BorderSizePixel = 0, Parent = frame,
		}, {create("UICorner", {CornerRadius = UDim.new(0, 2)})})
		local band = look.band and create("Frame", {
			Position = UDim2.new(0, 0, 0.3, 0), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.fromRGB(240, 236, 226),
			BorderSizePixel = 0, Parent = hull,
		}) or nil
		local outline = create("UIStroke", {Color = DIM, Thickness = 1, Transparency = 1, Parent = hull})
		table.insert(slots, {frame = frame, hull = hull, head = head, band = band, outline = outline, scale = scale, full = true})
	end
end
local function paintHud(alpha)
	for _, entry in ipairs(hudPaint) do
		local obj, prop, base = entry[1], entry[2], entry[3]
		obj[prop] = 1 - (1 - base) * alpha
	end
	for _, sl in ipairs(slots) do
		local fill = sl.full and alpha or 0
		sl.hull.BackgroundTransparency = 1 - fill
		sl.head.BackgroundTransparency = 1 - fill
		if sl.band then sl.band.BackgroundTransparency = 1 - fill end
		sl.outline.Transparency = sl.full and 1 or 1 - 0.8 * alpha
	end
end
-- a shell leaving the tag when one is fired
local function spendSlot(sl)
	local ghost = create("Frame", {
		Size = sl.frame.Size, Position = UDim2.fromOffset(sl.frame.AbsolutePosition.X - slotRow.AbsolutePosition.X + 8, 18),
		BackgroundColor3 = Color3.fromRGB(206, 168, 80), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = card,
	}, {create("UICorner", {CornerRadius = UDim.new(0, 3)})})
	tween(ghost, 0.35, {Position = ghost.Position + UDim2.fromOffset(6, -16), BackgroundTransparency = 1, Rotation = 35})
	Debris:AddItem(ghost, 0.4)
end
local hudAlpha = 0
local function updateHud(dt, character, e, item)
	local heldModel = character and character:FindFirstChild("GS_Held")
	local adornee = heldModel and (heldModel:FindFirstChild("Receiver") or heldModel.PrimaryPart or heldModel:FindFirstChildWhichIsA("BasePart"))
	if not e or not item or item.kind ~= "gun" or not adornee then
		hud.Enabled = false
		slotKey, shownLoaded = nil, nil
		return
	end
	hud.Adornee = adornee
	hud.Enabled = true
	local key = item.id
	if key ~= slotKey then
		slotKey = key
		buildSlots(item)
		shownLoaded = nil
		bumpHud()
	end
	local loaded = math.clamp(e.ammo or 0, 0, item.magazine)
	if shownLoaded and loaded ~= shownLoaded then
		bumpHud()
		if loaded < shownLoaded then
			for i = loaded + 1, shownLoaded do if slots[i] then spendSlot(slots[i]) end end
		else
			for i = shownLoaded + 1, loaded do
				local sl = slots[i]
				if sl then sl.scale.Scale = 1.35 tween(sl.scale, 0.3, {Scale = 1}, Enum.EasingStyle.Back) end
			end
		end
	end
	shownLoaded = loaded
	for i, sl in ipairs(slots) do sl.full = i <= loaded end
	local spare = 0
	for _, other in ipairs(bag.items) do
		if other.id == item.ammo then spare += other.n end
	end
	hudName.Text = item.name
	hudSpare.Text = "+" .. spare
	hudSpare.TextColor3 = spare > 0 and INK or BRIGHT
	local now = os.clock()
	if now < reloadingUntil then
		hudStatus.Text = "LOADING"
		hudStatus.TextColor3 = AMBER
		hudBar.Size = UDim2.new(math.clamp((now - reloadStarted) / math.max(reloadingUntil - reloadStarted, 0.01), 0, 1), -16, 0, 2)
		bumpHud()
	elseif loaded == 0 then
		hudStatus.Text = spare > 0 and (TOUCH and "EMPTY - TAP LOAD" or "EMPTY - PRESS R") or "EMPTY - NO SPARE ROUNDS"
		hudStatus.TextColor3 = BRIGHT
		hudBar.Size = UDim2.new(0, 0, 0, 2)
	else
		hudStatus.Text = ""
		hudBar.Size = UDim2.new(0, 0, 0, 2)
	end
	-- lit while something is happening, dim while it's just carried
	local target = (now < hudActiveUntil or aiming or loaded == 0) and 1 or 0.4
	hudAlpha += (target - hudAlpha) * math.min(1, dt * 8)
	paintHud(hudAlpha)
	hudStatus.TextTransparency = loaded == 0 and now >= reloadingUntil and (0.15 + 0.35 * (0.5 + 0.5 * math.sin(now * 6))) or 1 - hudAlpha
	hudBar.BackgroundTransparency = 1 - hudAlpha
	-- beside the gun on screen; tucked in closer when the gun is up at the eye
	hud.StudsOffset = aiming and Vector3.new(1.05, -0.25, 0) or Vector3.new(1.9, 0.4, 0)
end

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
 if heldModel then local a=heldModel:FindFirstChild("Muzzle",true) if a and a:IsA("Attachment") then return a.WorldPosition end end

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
local function tracer(from,to,color)
 local distance=(to-from).Magnitude
 if distance<0.5 then return end
 local direction=(to-from).Unit
 local length=math.min(2.4,distance)
 local p=create("Part",{Name="GS_ProjectileStreak",Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,
 CastShadow=false,Material=Enum.Material.Neon,Color=color or Color3.fromRGB(230,208,166),Transparency=0.6,
 Size=Vector3.new(0.022,0.022,length),CFrame=CFrame.lookAt(from+direction*length*.5,to),Parent=fxFolder})
 local duration=math.clamp(distance/1700,0.018,0.12)
 tween(p,duration,{CFrame=CFrame.lookAt(to-direction*length*.5,to),Transparency=1},Enum.EasingStyle.Linear)
 Debris:AddItem(p,duration+0.03)
end

local function flash(position,look,item)
 if item and item.fire then VFX.Muzzle(position,look) else VFX.MuzzleBlast(position,look,item and item.id=="doublebarrel" and 1.15 or 1) end
end

local function ejectShell(character, sideways)
	local held = character:FindFirstChild("GS_Held")
	local base = held and (held.PrimaryPart or held:FindFirstChildWhichIsA("BasePart"))
	if not base then return end
	local eject = held:FindFirstChild("EjectionPort",true)
	local shell = create("Part", {
 Shape = Enum.PartType.Cylinder,
		CanCollide = true, CanQuery = false, CanTouch = false, Size = Vector3.new(0.34, 0.14, 0.14), Color = Color3.fromRGB(170, 24, 24),
		Material = Enum.Material.SmoothPlastic, CFrame = eject and eject.WorldCFrame or base.CFrame * CFrame.new(0, 0.2, 0), Parent = fxFolder,
	})
	create("Part", {
		CanCollide = false, CanQuery = false, Massless = true, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.07, 0.15, 0.15), Color = Color3.fromRGB(196, 160, 72),
		Material = Enum.Material.Metal, CFrame = shell.CFrame * CFrame.new(-0.16, 0, 0), Parent = shell,
	}, {})
	local w = create("WeldConstraint", {Part0 = shell, Part1 = shell:FindFirstChildOfClass("Part"), Parent = shell})
	local right = base.CFrame.ZVector * (sideways or 1)
	shell.AssemblyLinearVelocity = right * 9 + Vector3.new(0, 10, 0)
	shell.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, 0)
	task.delay(0.45, function() if shell.Parent then sound("ShellDrop", shell, 0.4, 1) end end)
	Debris:AddItem(shell, 8)
	return w
end

local function shotSound(item, parent, isMine)
	if item.fire then return end -- (the flare's thump and hiss come with its flight: WeaponImpactFX)
	Audio.Shot("Shotgun", parent, isMine and 1 or 0.9, item.id == "doublebarrel" and 0.9 or 1, 400)
end

-- ===== firing =====
local function fire()
	local character = myCharacter()
	if not character or busy() or character:GetAttribute("Ragdolled") or character:GetAttribute("Infected") then return end
	local e, item = held()
	if not e or item.kind ~= "gun" then return end
 if reloadingUntil>os.clock() and not item.reloadPerShell then return end
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
			reloadingUntil = now + (item.reloadOpen or .35) + item.reload * (item.reloadPerShell and item.magazine or 1) + (item.reloadClose or .35)
			character:SetAttribute("GS_ReloadAt", workspace:GetServerTimeNow())
		end
		return
	end
	lastShot = now
	e.ammo -= 1
	reloadingUntil = 0
	local camera = workspace.CurrentCamera
	refreshParams(character)
	local screen = aimScreenPoint()
	local ray = (TOUCH or aiming or UserInputService.MouseBehavior==Enum.MouseBehavior.LockCenter) and camera:ViewportPointToRay(screen.X,screen.Y) or camera:ScreenPointToRay(screen.X,screen.Y)
	local target = workspace:Raycast(ray.Origin, ray.Direction * (item.range + 40), rayParams)
	local aimPoint = target and target.Position or (ray.Origin + ray.Direction * item.range)
	local origin = head.Position
	local look = CFrame.lookAt(origin, aimPoint)
	seedCount += 1
	local seed = seedBase + seedCount
	local spread = currentSpread(item, character)
	local muzzle = muzzleOf(character, look.LookVector)
	for _, dir in ipairs(item.fire and {} or ItemData.Pellets(item, look, seed, spread)) do
		local hit = workspace:Raycast(origin, dir * item.range, rayParams)
		local endPos = hit and hit.Position or (origin + dir * item.range)
		tracer(muzzle, endPos, item.fire and Color3.fromRGB(255, 90, 60) or nil)

	end
	weaponRemote:FireServer("fire", e.uid, look, seed, aiming)
	flash(muzzle, look.LookVector, item)
	shotSound(item, head, true)
	kick = math.min(kick + item.recoil * 0.9, 30)
	character:SetAttribute("GS_RecoilAt", workspace:GetServerTimeNow())
 character:SetAttribute("GS_ReloadAt",nil)
 character:SetAttribute("GS_ReloadPhase",nil)
	-- the gun climbs: the view is kicked up and settles back
	kickRecoil(item)
	if item.pump then
		-- the fore-end moves at once on this screen; WeaponMechanics racks it and throws the hull
		character:SetAttribute("GS_PumpAt", workspace:GetServerTimeNow() + (item.pumpDelay or 0.22))
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
	reloadingUntil = now + (item.reloadOpen or .35) + item.reload * (item.reloadPerShell and (item.magazine - (e.ammo or 0)) or 1) + (item.reloadClose or .35)
	character:SetAttribute("GS_ReloadAt", workspace:GetServerTimeNow())
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
	character:SetAttribute("GS_WeaponSwingAt", workspace:GetServerTimeNow())
 character:SetAttribute("GS_AttackDuration",item.cooldown)
	local camera = workspace.CurrentCamera
	refreshParams(character)
 local screen=aimScreenPoint()
 local ray=(TOUCH or aiming or UserInputService.MouseBehavior==Enum.MouseBehavior.LockCenter) and camera:ViewportPointToRay(screen.X,screen.Y) or camera:ScreenPointToRay(screen.X,screen.Y)
 local result=workspace:Raycast(ray.Origin,ray.Direction*100,rayParams)
 local head=character:FindFirstChild("Head")
 local aimPoint=result and result.Position or ray.Origin+ray.Direction*100
 local look=head and (aimPoint-head.Position).Unit or ray.Direction
 weaponRemote:FireServer("swing",e.uid,look)

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
	-- (the zoom itself is eased every frame below: no tweens fighting the camera scripts)
	if aiming then
		if not TOUCH then UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end
	else
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

-- ===== aiming down the sights + recoil =====
-- aimBlend eases 0 -> 1 when you aim. At full aim the eye sits right behind the gun (just right of the head, at the
-- stock), the view narrows, and the head / helmet are hidden from your own eyes. A shot kicks the view up hard and it
-- settles back. All of it is laid over the camera after the camera scripts ran and taken off before they run again.
local AIM_ZOOM = 0.7
local aimBlend = 0
local recoilUp, recoilSide, recoilVel = 0, 0, 0
local camMod
local hiddenHead = {}
local function showHead()
	for p in pairs(hiddenHead) do if p.Parent then p.LocalTransparencyModifier = 0 end end
	hiddenHead = {}
end
RunService:BindToRenderStep("GS_AimCamBefore", Enum.RenderPriority.Camera.Value - 2, function()
	if camMod then
		local c = camMod.cam
		if c.CFrame == camMod.outCFrame then c.CFrame = camMod.cframe end
		if math.abs(c.FieldOfView - camMod.outFov) < 0.001 then c.FieldOfView = camMod.fov end
	end
	camMod = nil
end)
function kickRecoil(item)
	local k = math.rad((item.recoil or 8) * 0.55)
	recoilVel += k * 22
	recoilSide += math.rad((math.random() - 0.5) * (item.recoil or 8) * 0.25)
end
RunService:BindToRenderStep("GS_AimCamAfter", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local target = aiming and 1 or 0
	aimBlend += (target - aimBlend) * (1 - math.exp(-(aiming and 10 or 9) * dt))
	if math.abs(target - aimBlend) < 0.002 then aimBlend = target end
	recoilUp += recoilVel * dt
	recoilVel -= recoilVel * math.min(1, 18 * dt)
	recoilUp -= recoilUp * math.min(1, 7 * dt)
	recoilSide -= recoilSide * math.min(1, 8 * dt)
	if math.abs(recoilUp) < 1e-4 and math.abs(recoilVel) < 1e-3 then recoilUp, recoilVel = 0, 0 end
	if math.abs(recoilSide) < 1e-4 then recoilSide = 0 end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not camera or (aimBlend <= 0 and recoilUp == 0 and recoilSide == 0) then
		if next(hiddenHead) then showHead() end
		return
	end
	local e = aimBlend * aimBlend * (3 - 2 * aimBlend)
	local base = camera.CFrame
	local rot = base.Rotation
	local pos = base.Position
	if head and e > 0 then
		local sight = head.Position + rot.RightVector * 0.3 + rot.UpVector * 0.05 - rot.LookVector * 0.1
		pos = pos:Lerp(sight, e)
	end
	local out = CFrame.new(pos) * rot * CFrame.Angles(recoilUp, recoilSide, 0)
	camMod = {cam = camera, cframe = base, fov = camera.FieldOfView}
	camMod.outCFrame = out
	camMod.outFov = camera.FieldOfView * (1 + (AIM_ZOOM - 1) * e)
	camera.CFrame = out
	camera.FieldOfView = camMod.outFov
	if e > 0.35 and character then
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				local wear = d:FindFirstAncestorWhichIsA("Model")
				local onHead = d == head or d:FindFirstAncestorWhichIsA("Accessory") ~= nil
					or (wear and wear ~= character and (wear.Name:find("helmet") or wear.Name:find("mask")))
				if onHead then
					d.LocalTransparencyModifier = 1
					hiddenHead[d] = true
				end
			end
		end
	elseif next(hiddenHead) then
		showHead()
	end
end)

-- ===== every frame =====
RunService.RenderStepped:Connect(function(dt)
	local character = myCharacter()
	local e, item = held()
	local gun=character and item and item.kind=="gun" and not busy()
 local weapon=character and item and (item.kind=="gun" or item.kind=="melee") and not busy()
 gui.Enabled=weapon==true
 updateHud(dt, character, e, item)
 player:SetAttribute("GS_Crosshair",weapon==true or nil)
 if not weapon then

		if aiming then setAim(false) end
		return
	end
	local camera = workspace.CurrentCamera
	local point = aimScreenPoint()
	cross.Position = UDim2.fromOffset(point.X, point.Y)
 if not gun then if aiming then setAim(false) end return end
	kick = math.max(0, kick - dt * 40)
	-- aiming turns the body to where the camera looks
	if aiming then
		local root = character:FindFirstChild("HumanoidRootPart")
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if root and flat.Magnitude > 0.1 then
			-- turn the body toward the aim smoothly instead of snapping it
			local want = math.atan2(-flat.X, -flat.Z)
			local rl = root.CFrame.LookVector
			local have = math.atan2(-rl.X, -rl.Z)
			local diff = (want - have + math.pi) % (2 * math.pi) - math.pi
			local step = diff * (1 - math.exp(-16 * dt))
			if math.abs(diff) > 0.001 then
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, have + step, 0)
			end
		end
	end
end)

-- ===== what the server says =====
weaponRemote.OnClientEvent:Connect(function(kind, a, b, c, d)
	local myChar = player.Character
	if kind == "hits" then
  return -- physical impact effects only
	elseif kind == "noammo" then
		local item = ItemData.Get(a)
		hitText.Text = "no " .. (item and item.name:lower() or "ammo")
		hitText.TextColor3 = BRIGHT
		hitText.TextTransparency = 0
		tween(hitText, 1.2, {TextTransparency = 1})
		reloadingUntil = 0
 if myChar then myChar:SetAttribute("GS_ReloadAt",nil) myChar:SetAttribute("GS_ReloadPhase",nil) end
	elseif kind == "shot" then
		-- someone else's shot: their tracers, their flash, their bang
		local character, itemId, startPos, ends = a, b, c, d
		if character == myChar or typeof(character) ~= "Instance" then return end
		local item = ItemData.Get(itemId)
		if not item then return end
		local look = (#ends > 0 and (ends[1] - startPos).Unit) or Vector3.new(0, 0, -1)
		local muzzle = muzzleOf(character, look)
		if not item.fire then for _, p in ipairs(ends) do tracer(muzzle,p) end end
		flash(muzzle, look, item)
		shotSound(item, character:FindFirstChild("Head") or character.PrimaryPart, false)

 elseif kind=="reloadphase" then
  local character,itemId,phase=a,b,c
  if typeof(character)~="Instance" then return end
  local item=ItemData.Get(itemId)
  local head=character:FindFirstChild("Head")
  if not item then return end
  character:SetAttribute("GS_ReloadPhase",phase)
  character:SetAttribute("GS_ReloadPhaseAt",workspace:GetServerTimeNow())
  character:SetAttribute("GS_ReloadPhaseDur",d)
  if character==myChar then reloadingUntil=os.clock()+d+0.2 bumpHud() end
 elseif kind=="shellin" then
  if a==myChar then bumpHud() end
 elseif kind=="reloaded" or kind=="reloadcancel" then
  if typeof(a)=="Instance" then a:SetAttribute("GS_ReloadAt",nil) a:SetAttribute("GS_ReloadPhase",nil) end
  if a==myChar then reloadingUntil=0 end
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
		if typeof(model)=="Instance" and game.Players:GetPlayerFromCharacter(model) then sound("BloodHit",anchor,0.4,1,60) end
		if item.stun then
			sound("Shock", anchor, 0.8, 1, 60)
 VFX.Sparks(position,Vector3.yAxis,Color3.fromRGB(153,191,255),9)

		end
	end
end)

player.CharacterAdded:Connect(function()
	aiming = false
	reloadingUntil = 0
	local camera = workspace.CurrentCamera
	if baseFov and camera then camera.FieldOfView = baseFov end
end)
