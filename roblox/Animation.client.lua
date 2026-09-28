local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
end)

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ScreenEffects = require(Modules:WaitForChild("ScreenEffects"))
local LimbPose = require(Modules:WaitForChild("LimbPose"))

local event = ReplicatedStorage:WaitForChild("CharacterVisualSync")
local fallReport = ReplicatedStorage:WaitForChild("FallReport")
local remoteData = {}
local SEND_INTERVAL = 1 / 20
local sendTimer = 0

local FALL_RAGDOLL_SPEED = 65
local FALL_DAMAGE_MAX_SPEED = 160
local RAGDOLL_DURATION = 2.5
local LANDING_MIN_SPEED = 55

local ANIMATIONS = {
	idle = {
		id = "rbxassetid://91036027758402",
		priority = Enum.AnimationPriority.Idle,
		looped = true,
		speed = 1,
	},
	walk = {
		id = "rbxassetid://99045916736745",
		priority = Enum.AnimationPriority.Movement,
		looped = true,
		speed = 0.8,
	},
	jump = {
		id = "rbxassetid://74104429078784",
		priority = Enum.AnimationPriority.Action,
		looped = false,
		speed = 1,
	},

	climb = {
		id = "rbxassetid://180436334",
		priority = Enum.AnimationPriority.Movement,
		looped = true,
		speed = 1,
	},
}

local ANIM_FADE = 0.15
local MOVE_SPEED_THRESHOLD = 0.5
local BACKWARD_DOT_THRESHOLD = -0.3

local BODY_TURN_SMOOTH = 4
local HEAD_MAX_YAW = math.rad(80)
local HEAD_MAX_PITCH = math.rad(75)
local HEAD_SMOOTH = 4

local LIMB_SMOOTH = 10
local LEAN_SMOOTH = 6

local LEG_MAX_LIFT = math.rad(70)
local VOID_EXTRA = 0.35
local HERON_PITCH = math.rad(-30)
local HERON_ROLL = math.rad(-10)
local HERON_WEIGHT = 0.9
local SLOPE_ALIGN = 0.55
local SLOPE_MAX = math.rad(25)

local BALANCE_ROLL = math.rad(75)
local BALANCE_PITCH = math.rad(30)
local GUARD_DISTANCE = 2.0
local GUARD_IDLE_DISTANCE = 1.1
local GUARD_ROLL = math.rad(-42)
local GUARD_MIN_PITCH = math.rad(30)
local GUARD_MAX_PITCH = math.rad(105)
local SIDE_REACH = 1.9
local SIDE_PITCH = math.rad(12)
local LEDGE_REACH = 2.4
local LEDGE_MIN = -1.0
local LEDGE_MAX = 1.9
local LEDGE_HAND_SPREAD = 0.75
local FALL_SPREAD_SPEED = 22
local FALL_ARMS_ROLL = math.rad(78)
local FALL_ARMS_PITCH = math.rad(18)
local FLAIL_SPEED = 80

local STRAFE_ENABLED = false
local BODY_STRAFE_YAW = math.rad(45)
local LIMB_LIFT_SCALE = 0.8

local LEG_SPEED = {
	OneDamaged = 0.85,
	BothDamaged = 0.75,
	OneBroken = 0.6,
	BrokenAndDamaged = 0.5,
}
local LEG_JUMP = {
	OneDamaged = 0.85,
	BothDamaged = 0.7,
	OneBroken = 0.45,
	BrokenAndDamaged = 0.35,
}

local CRAWL_SPEED_MUL = 0.2
local PRONE_CAMERA_DROP = 2.2
local CRAWL_STRIDE = 1.6
local CRAWL_TURN_RATE = math.rad(110)

local GETUP_TIME = 1.1
local SPAWN_GETUP_TIME = 3.2

local STRAFE_ENTER = 0.5
local STRAFE_EXIT = 0.3
local STRAFE_ROLL = math.rad(24)
local STRAFE_SWING = math.rad(26)
local STRAFE_LIFT = math.rad(18)
local STRAFE_CROSS_FORWARD = 0.9
local STRAFE_STRIDE = 6.5
local STRAFE_MIN_HZ = 0.9
local STRAFE_MAX_HZ = 2.1
local STRAFE_LEAN = 0.05
local STRAFE_ARM_ROLL = math.rad(9)
local STRAFE_ARM_ROLL_SWING = math.rad(12)
local STRAFE_ARM_PITCH_SWING = math.rad(18)

local CROUCH_KEYS = {
	[Enum.KeyCode.LeftControl] = true,
	[Enum.KeyCode.RightControl] = true,
	[Enum.KeyCode.C] = true,
}
local CROUCH_TOGGLE = false
local CROUCH_SPEED_MUL = 0.45
local CROUCH_CAMERA_DROP = 1.3
local CROUCH_STRIDE = 3.2

local CLIMB_ANIM_SCALE = 5
local CLIMB_ARM_BASE = math.rad(148)
local CLIMB_ARM_SWING = math.rad(22)
local CLIMB_LEG_BASE = math.rad(8)
local CLIMB_LEG_LIFT = math.rad(40)
local CLIMB_STRIDE = 1.6
local CLIMB_TURN_SPEED = 14
local CLIMB_RELEASE_GRACE = 0.35

local ICE_SLIDE_ENABLED = true
local SURFACE_DEFAULT = {speed = 1, anim = 1, slide = 0, balance = 0, lift = 0, lean = 0, wobble = 0}
local SURFACES = {}
local function surface(materials, profile)
	for key, value in pairs(SURFACE_DEFAULT) do
		if profile[key] == nil then profile[key] = value end
	end
	for _, material in ipairs(materials) do
		SURFACES[material] = profile
	end
end
surface({Enum.Material.Ice, Enum.Material.Glacier},
	{speed = 1.05, anim = 0.9, slide = 0.85, balance = math.rad(20), wobble = 0.6})
surface({Enum.Material.Sand}, {speed = 0.82, anim = 0.85, lift = math.rad(9), lean = 0.05})
surface({Enum.Material.Snow}, {speed = 0.8, anim = 0.82, lift = math.rad(12), lean = 0.06})
surface({Enum.Material.Mud}, {speed = 0.7, anim = 0.72, lift = math.rad(14), lean = 0.08, wobble = 0.2})
surface({Enum.Material.Ground}, {speed = 0.93, anim = 0.93, lift = math.rad(4)})
surface({Enum.Material.Grass, Enum.Material.LeafyGrass}, {speed = 0.97, anim = 0.97, lift = math.rad(3)})
surface({Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.Pebble,
	Enum.Material.CrackedLava, Enum.Material.Cobblestone, Enum.Material.Limestone,
	Enum.Material.Sandstone, Enum.Material.Salt},
	{speed = 0.95, anim = 0.95, wobble = 0.3})
surface({Enum.Material.Metal, Enum.Material.DiamondPlate, Enum.Material.CorrodedMetal},
	{speed = 1, anim = 1.05})
do
	local soft = {Enum.Material.Fabric}
	local ok, carpet = pcall(function() return Enum.Material.Carpet end)
	if ok and carpet then table.insert(soft, carpet) end
	surface(soft, {speed = 0.96, anim = 0.95})
end

local SHIFT_LOCK_KEY = Enum.KeyCode.LeftShift
local SHOULDER_OFFSET = Vector3.new(1.75, 0.25, 0)
local CAMERA_OFFSET_SMOOTH = 8
local CURSOR_SIZE = 16
local SHIFT_LOCK_SENSITIVITY = 0.45
local SHIFT_LOCK_PITCH_LIMIT = math.rad(55)

local ShiftLockEnabled = false
local currentHumanoid = nil
local crouchHeld = false

local function approach(current, target, dt, speed)
	return current + (target - current) * math.min(dt * speed, 1)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Ctrl / C on keyboard, B on gamepad, a CRAWL toggle button on touch screens
local ContextActionService = game:GetService("ContextActionService")
local crouchKeys = {Enum.KeyCode.ButtonB}
for key in pairs(CROUCH_KEYS) do table.insert(crouchKeys, key) end
ContextActionService:BindAction("GS_Crawl", function(_, state, input)
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	local touch = input.UserInputType == Enum.UserInputType.Touch
	if state == Enum.UserInputState.Begin then
		if CROUCH_TOGGLE or touch then
			crouchHeld = not crouchHeld
		else
			crouchHeld = true
		end
	elseif state == Enum.UserInputState.End and not CROUCH_TOGGLE and not touch then
		crouchHeld = false
	end
	return Enum.ContextActionResult.Sink
end, true, table.unpack(crouchKeys))
ContextActionService:SetTitle("GS_Crawl", "CRAWL")
ContextActionService:SetPosition("GS_Crawl", UDim2.new(1, -240, 1, -95))

local function CreateUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShiftLockUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 2147483647
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local reticle = Instance.new("Frame")
	reticle.Name = "Reticle"
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Position = UDim2.new(0.5, 0, 0.5, 0)
	reticle.Size = UDim2.fromOffset(22, 22)
	reticle.BackgroundTransparency = 1
	reticle.ZIndex = 2147483647
	reticle.Visible = false
	reticle.Parent = screenGui
	for _, spec in ipairs({
		{UDim2.fromScale(0.5, 0), UDim2.fromOffset(2, 6), Vector2.new(0.5, 0)},
		{UDim2.fromScale(0.5, 1), UDim2.fromOffset(2, 6), Vector2.new(0.5, 1)},
		{UDim2.fromScale(0, 0.5), UDim2.fromOffset(6, 2), Vector2.new(0, 0.5)},
		{UDim2.fromScale(1, 0.5), UDim2.fromOffset(6, 2), Vector2.new(1, 0.5)},
	}) do
		local line = Instance.new("Frame")
		line.Position = spec[1]
		line.Size = spec[2]
		line.AnchorPoint = spec[3]
		line.BackgroundColor3 = Color3.fromRGB(225, 220, 215)
		line.BackgroundTransparency = 0.25
		line.BorderSizePixel = 0
		line.ZIndex = 2147483647
		line.Parent = reticle
	end
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(3, 3)
	dot.BackgroundColor3 = Color3.fromRGB(200, 20, 20)
	dot.BorderSizePixel = 0
	dot.ZIndex = 2147483647
	dot.Parent = reticle

	local cursor = Instance.new("Frame")
	cursor.Name = "Cursor"
	cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	cursor.Size = UDim2.fromOffset(CURSOR_SIZE, CURSOR_SIZE)
	cursor.BackgroundTransparency = 1
	cursor.ZIndex = 2147483647
	cursor.Parent = screenGui
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = cursor
	local ring = Instance.new("UIStroke")
	ring.Thickness = 1.5
	ring.Color = Color3.fromRGB(230, 225, 220)
	ring.Transparency = 0.15
	ring.Parent = cursor
	local center = Instance.new("Frame")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(4, 4)
	center.BackgroundColor3 = Color3.fromRGB(190, 15, 15)
	center.BorderSizePixel = 0
	center.ZIndex = 2147483647
	center.Parent = cursor
	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = UDim.new(1, 0)
	centerCorner.Parent = center

	return reticle, cursor
end

local reticle, cursor = CreateUI()

UserInputService.MouseIconEnabled = false

local function UpdateShiftLockState()
	UserInputService.MouseDeltaSensitivity = ShiftLockEnabled and SHIFT_LOCK_SENSITIVITY or 1
	if ShiftLockEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		reticle.Visible = true
		cursor.Visible = false
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		reticle.Visible = false
		cursor.Visible = true
	end
end

local function DesiredAutoRotate(character)
	return not ShiftLockEnabled
		and not character:GetAttribute("FirstPersonCameraActive")
		and not character:GetAttribute("Ragdolled")
		and not character:GetAttribute("Climbing")
end

local function SetShiftLock(enabled)
	ShiftLockEnabled = enabled
	if currentHumanoid and currentHumanoid.Parent then
		local character = currentHumanoid.Parent
		if not character:GetAttribute("Ragdolled")
			and not character:GetAttribute("FirstPersonCameraActive")
			and not character:GetAttribute("Climbing") then
			currentHumanoid.AutoRotate = not enabled
		end
	end
	UpdateShiftLockState()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == SHIFT_LOCK_KEY then
		SetShiftLock(not ShiftLockEnabled)
	end
end)

local uiWasOpen = false
RunService.RenderStepped:Connect(function()
	if UserInputService.MouseIconEnabled then UserInputService.MouseIconEnabled = false end
	local uiOpen = player:GetAttribute("UIOpen") == true
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		-- phones and tablets: no fake mouse cursor
		cursor.Visible = false
	elseif not ShiftLockEnabled or uiOpen then
		local pos = UserInputService:GetMouseLocation()
		cursor.Position = UDim2.new(0, pos.X, 0, pos.Y)
	end
	if ShiftLockEnabled then
		cursor.Visible = uiOpen
		reticle.Visible = not uiOpen
		if uiWasOpen and not uiOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end
	uiWasOpen = uiOpen
end)

UpdateShiftLockState()

RunService:BindToRenderStep("PlayerSystem_ShiftLockClamp", Enum.RenderPriority.Camera.Value + 2, function()
	if not ShiftLockEnabled or not currentHumanoid or not currentHumanoid.Parent then return end
	if currentHumanoid.Parent:GetAttribute("FirstPersonCameraActive") then return end
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Custom then return end
	local look = cam.CFrame.LookVector
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	if math.abs(pitch) <= SHIFT_LOCK_PITCH_LIMIT then return end
	local focus = cam.Focus.Position
	local distance = (cam.CFrame.Position - focus).Magnitude
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then return end
	flat = flat.Unit
	local clamped = math.clamp(pitch, -SHIFT_LOCK_PITCH_LIMIT, SHIFT_LOCK_PITCH_LIMIT)
	local newLook = flat * math.cos(clamped) + Vector3.new(0, math.sin(clamped), 0)
	local position = focus - newLook * distance
	cam.CFrame = CFrame.lookAt(position, position + newLook)
end)

local function LoadTrack(animator, config)
	if not config or config.id == "" then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = config.id
	local track = animator:LoadAnimation(anim)
	track.Priority = config.priority
	track.Looped = config.looped
	return track
end

local function NewParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

local REMOTE_CLIP_DISTANCE = 80
local MODE_INDEX = 21
local CROUCH_INDEX = 22

local function SetupRemoteCharacter(plr, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end
	local rig = LimbPose.CreateRig(character)
	if not rig then return end
	character:GetAttributeChangedSignal("RigVersion"):Connect(function()
		task.wait(0.1)
		LimbPose.RefreshRig(rig)
	end)
	local params = NewParams(character)

	local entry = {target = nil, current = table.create(LimbPose.FIELD_COUNT, 0), wasPosed = false}
	remoteData[plr] = entry

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not character.Parent then
			connection:Disconnect()
			if remoteData[plr] == entry then remoteData[plr] = nil end
			return
		end
		if character:GetAttribute("Ragdolled") or humanoid.Health <= 0 then
			if entry.wasPosed then
				entry.wasPosed = false
				LimbPose.Reset(rig)
				entry.current = table.create(LimbPose.FIELD_COUNT, 0)
			end
			return
		end
		local target = entry.target
		if not target then return end
		entry.wasPosed = true

		local cur = entry.current
		local alpha = math.min(dt * LIMB_SMOOTH, 1)
		for i = 1, LimbPose.FIELD_COUNT do
			cur[i] += (target[i] - cur[i]) * alpha
		end
		cur[MODE_INDEX] = target[MODE_INDEX]

		LimbPose.ApplyNeck(rig, cur[1], cur[2])
		LimbPose.ApplyLean(rig, cur[3], cur[4], cur[CROUCH_INDEX], cur[23], cur[24])
		LimbPose.Assign(rig, cur)

		local near = camera and (camera.CFrame.Position - rig.torso.Position).Magnitude < REMOTE_CLIP_DISTANCE
		LimbPose.Apply(rig, {
			antiClip = near and cur[MODE_INDEX] == 0,
			params = params,
		})
	end)
end

event.OnClientEvent:Connect(function(plr, packet)
	local entry = remoteData[plr]
	if entry then
		local values = LimbPose.Unpack(packet)
		if values then
			entry.target = values
		end
	end
end)

local function SetupCharacter(character, opts)
	opts = opts or {}
	local puppet = opts.puppet == true
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end

	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end

	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	local torso = character:WaitForChild("Torso", 10)
	local headPart = character:WaitForChild("Head", 10)
	if not rootPart or not torso or not headPart then return end

	local defaultAnimate = character:FindFirstChild("Animate")
	if defaultAnimate then
		defaultAnimate.Disabled = true
	end

	local animator = humanoid:WaitForChild("Animator", 10)
	if not animator then
		if not puppet then return end
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local rig = LimbPose.CreateRig(character)
	if not rig then return end
	local limbs = rig.limbs
	character:GetAttributeChangedSignal("RigVersion"):Connect(function()
		task.wait(0.1)
		LimbPose.RefreshRig(rig)
	end)
	local ARMS = {"rightArm", "leftArm"}
	local LEGS = {"rightLeg", "leftLeg"}

	local moveTracks = {}
	for name, config in pairs(ANIMATIONS) do

		for _ = 1, 4 do
			local ok, track = pcall(LoadTrack, animator, config)
			if ok and track then
				moveTracks[name] = track
				break
			end
			task.wait(0.5)
		end
	end

	if moveTracks.idle then
		moveTracks.idle:Play(0, 1, ANIMATIONS.idle.speed)
	end

	local currentState = "idle"

	local function SetMoveState(newState)
		if newState == currentState then
			return
		end
		local oldTrack = moveTracks[currentState]
		local newTrack = moveTracks[newState]
		local newConfig = ANIMATIONS[newState]
		if oldTrack then
			oldTrack:Stop(ANIM_FADE)
		end
		if newTrack then
			newTrack:Play(ANIM_FADE, 1, newConfig and newConfig.speed or 1)
		end
		currentState = newState
	end

	if not puppet then
		currentHumanoid = humanoid
		if DesiredAutoRotate(character) then humanoid.AutoRotate = true end
		humanoid.CameraOffset = Vector3.zero
	end
	local isRagdolled = false
	local flightEffectActive = false
	local params = NewParams(character)

	local baseWalkSpeed = humanoid.WalkSpeed
	local baseJumpPower = humanoid.JumpPower
	local baseJumpHeight = humanoid.JumpHeight
	local lastJumpScale = 1
	local writtenWalkSpeed = nil
	local walkSpeedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if writtenWalkSpeed == nil or math.abs(humanoid.WalkSpeed - writtenWalkSpeed) > 1e-3 then
			baseWalkSpeed = humanoid.WalkSpeed
			writtenWalkSpeed = nil
		end
	end)

	local function stopFlightEffect()
		if flightEffectActive then
			flightEffectActive = false
			ScreenEffects.ResetFlightEffect()
		end
	end

	local neckYaw, neckPitch = 0, 0
	local leanForward, leanRight = 0, 0
	local bodyYaw = 0
	local strafeAmount, strafePhase = 0, 0
	local strafing, strafeSide = false, 1
	local crouchAmount, crouchPhase = 0, 0
	local proneAmount, crawlPhase = 0, 0
	local wriggleActive = false
	local torsoSlick, torsoProps = false, nil
	local crawlSteering = false
	local getUpStart = opts.noGetUp and -math.huge or os.clock()
	local getUpDuration = SPAWN_GETUP_TIME
	local spawnGetUp = true
	local jumpEnabled = true
	local climbPhase = 0
	local climbing = false
	local climbYaw = nil
	local climbReleasedAt = -math.huge
	local surfaceState = table.clone(SURFACE_DEFAULT)
	local airMinVelocity = 0
	local wasAirborne = false
	local slideVelocity = nil
	local lastWrittenSlide = nil
	local grounded = true
	local balanceWobble = 0

	local function resetPose()
		LimbPose.Reset(rig)
		neckYaw, neckPitch, leanForward, leanRight = 0, 0, 0, 0
		bodyYaw = 0
		strafeAmount, strafing, crouchAmount = 0, false, 0
	end

	local function syncRagdoll()
		local enabled = character:GetAttribute("Ragdolled") == true
		if enabled == isRagdolled then return end
		isRagdolled = enabled
		if enabled then
			stopFlightEffect()
			for _, track in pairs(moveTracks) do track:Stop(0.1) end
			currentState = ""
			resetPose()
			slideVelocity = nil
			wasAirborne, airMinVelocity = false, 0
			if puppet then return end
			humanoid.AutoRotate = false
			humanoid.PlatformStand = true
			if humanoid.Health > 0 then
				local duration = character:GetAttribute("RagdollDuration") or RAGDOLL_DURATION
				ScreenEffects.Knockout(duration, character:GetAttribute("RagdollSeverity") or 0.6)

				player:SetAttribute("AdrenalineUntil", workspace:GetServerTimeNow() + duration + 8)
			end
		else
			getUpStart = os.clock()
			getUpDuration = GETUP_TIME
			spawnGetUp = false
			if puppet then return end
			humanoid.PlatformStand = false
			if humanoid.Health > 0 then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
			if DesiredAutoRotate(character) then
				humanoid.AutoRotate = true
			end
		end
	end
	local ragdollConnection = character:GetAttributeChangedSignal("Ragdolled"):Connect(syncRagdoll)
	syncRagdoll()

	local function FindLadderYaw()
		local look = rootPart.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then return nil end
		local hit = workspace:Raycast(rootPart.Position, flat.Unit * 3, params)
		if hit and math.abs(hit.Normal.Y) < 0.5 then
			return math.atan2(hit.Normal.X, hit.Normal.Z)
		end
		return nil
	end

	local function setClimbing(value)
		if value == climbing then return end
		climbing = value
		if puppet then
			climbYaw = value and (FindLadderYaw() or select(2, rootPart.CFrame:ToOrientation())) or nil
			return
		end
		character:SetAttribute("Climbing", value)
		if value then
			humanoid.AutoRotate = false
			climbYaw = FindLadderYaw() or select(2, rootPart.CFrame:ToOrientation())
		else
			climbYaw = nil
			climbReleasedAt = os.clock()
			if not isRagdolled and DesiredAutoRotate(character) then
				humanoid.AutoRotate = true
			end
		end
	end

	local slideConnection = RunService.Heartbeat:Connect(function(dt)
		if puppet or not ICE_SLIDE_ENABLED or isRagdolled or climbing or not grounded or surfaceState.slide < 0.05 then
			slideVelocity, lastWrittenSlide = nil, nil
			return
		end
		local v = rootPart.AssemblyLinearVelocity
		local horizontal = Vector3.new(v.X, 0, v.Z)
		if not slideVelocity then
			slideVelocity = horizontal
		end
		if lastWrittenSlide and (horizontal - lastWrittenSlide).Magnitude > 10 then
			slideVelocity = horizontal
		end
		local desired = humanoid.MoveDirection * humanoid.WalkSpeed
		local accel = lerp(40, 2.2, surfaceState.slide)
		slideVelocity = slideVelocity:Lerp(desired, 1 - math.exp(-accel * dt))
		rootPart.AssemblyLinearVelocity = Vector3.new(slideVelocity.X, v.Y, slideVelocity.Z)
		lastWrittenSlide = slideVelocity
	end)

	local fallTracking = false
	local fallStartY = rootPart.Position.Y
	local fallLastGroundY = rootPart.Position.Y
	local fallMaxSpeed = 0
	local fallConnection = RunService.Heartbeat:Connect(function()
		if puppet then return end
		local state = humanoid:GetState()
		local y = rootPart.Position.Y
		if isRagdolled or humanoid.Health <= 0 or humanoid.Sit
			or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then
			fallTracking, fallMaxSpeed, fallLastGroundY = false, 0, y
			return
		end
		local vy = rootPart.AssemblyLinearVelocity.Y
		local inAir = humanoid.FloorMaterial == Enum.Material.Air
			or state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
		if inAir then
			if not fallTracking then
				fallTracking = true
				fallStartY = fallLastGroundY
				fallMaxSpeed = 0
			end
			fallMaxSpeed = math.max(fallMaxSpeed, -vy)
			return
		end
		fallLastGroundY = y
		if fallTracking then
			fallTracking = false
			local height = fallStartY - y
			if height >= 4 then
				fallReport:FireServer(height, fallMaxSpeed)
			end
			fallMaxSpeed = 0
		end
	end)

	local LIMB_KEYS = {"LeftArm", "RightArm", "LeftLeg", "RightLeg"}
	local lastGroundedAt = os.clock()
	local jumpStartedAt = -math.huge
	local function limbTrouble()
		for _, key in ipairs(LIMB_KEYS) do
			if (character:GetAttribute("Injury_" .. key) or 0) >= 2 then return true end
		end
		return false
	end
	local function groundBelow()
		local leg = character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
		local reach = rootPart.Size.Y * 0.5 + humanoid.HipHeight + (leg and leg.Size.Y or 2) + 1.2
		return workspace:Raycast(rootPart.Position, Vector3.new(0, -reach, 0), params) ~= nil
	end
	local jumpGuardConnection = humanoid.StateChanged:Connect(function(_, new)
		if puppet then return end
		if new == Enum.HumanoidStateType.Jumping then

			if os.clock() - lastGroundedAt > 0.2 and not groundBelow() then
				local v = rootPart.AssemblyLinearVelocity
				rootPart.AssemblyLinearVelocity = Vector3.new(v.X, math.min(v.Y, 0), v.Z)
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			else
				jumpStartedAt = os.clock()
				if limbTrouble() then

					local v = rootPart.AssemblyLinearVelocity
					local jumpV = math.sqrt(2 * workspace.Gravity * math.max(humanoid.JumpHeight, 0))
					rootPart.AssemblyLinearVelocity = Vector3.new(v.X, jumpV, v.Z)
					humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
				end
			end
		end
	end)
	local stabilizeConnection = RunService.Heartbeat:Connect(function()
		if puppet or isRagdolled or humanoid.Health <= 0 then return end
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed
			or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then
			lastGroundedAt = os.clock()
		end
		if state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then return end
		if not limbTrouble() then return end
		local v = rootPart.AssemblyLinearVelocity
		local jumpV = math.sqrt(2 * workspace.Gravity * math.max(humanoid.JumpHeight, 1))
		local maxUp = jumpV * 1.05 + 1
		if os.clock() - jumpStartedAt > 0.45 then

			maxUp = 14
		end
		local vy = v.Y
		if vy > maxUp then vy = maxUp end
		if state == Enum.HumanoidStateType.Jumping and os.clock() - jumpStartedAt > 0.04 then

			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		local flat = Vector3.new(v.X, 0, v.Z)
		local maxFlat = math.max(humanoid.WalkSpeed, 4) + 7
		if proneAmount > 0.5 then

			maxFlat = humanoid.WalkSpeed * 1.25 + 0.75
		end
		if flat.Magnitude > maxFlat then flat = flat.Unit * maxFlat end
		if vy ~= v.Y or flat.X ~= v.X or flat.Z ~= v.Z then
			rootPart.AssemblyLinearVelocity = Vector3.new(flat.X, vy, flat.Z)
		end
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
			local w = rootPart.AssemblyAngularVelocity
			if w.Magnitude > 12 then rootPart.AssemblyAngularVelocity = w.Unit * 12 end
		end
	end)

	local function aimArm(joint, worldPoint)
		local v = torso.CFrame:PointToObjectSpace(worldPoint) - joint.base.Position
		if v.Magnitude < 1e-3 then return 0, 0 end
		local dir = v.Unit
		local roll = math.asin(math.clamp(dir.X, -1, 1))
		local pitch = math.atan2(-dir.Z, -dir.Y)
		return pitch, roll * joint.side
	end

	local function FindLedge(flatFacing)
		local shoulder = torso.CFrame:PointToWorldSpace(Vector3.new(0, 0.5, 0))
		local wall = workspace:Raycast(shoulder, flatFacing * LEDGE_REACH, params)
		if not wall or wall.Normal:Dot(flatFacing) > -0.5 then
			return nil, wall
		end
		local top = shoulder.Y + LEDGE_MAX + 0.3
		local origin = Vector3.new(wall.Position.X, top, wall.Position.Z) + flatFacing * 0.4
		local down = workspace:Raycast(origin, Vector3.new(0, -(LEDGE_MAX - LEDGE_MIN + 0.6), 0), params)
		if down and down.Normal.Y > 0.7 then
			local relative = down.Position.Y - shoulder.Y
			if relative >= LEDGE_MIN and relative <= LEDGE_MAX and relative < (LEDGE_MAX + 0.25) then
				return {point = down.Position, distance = wall.Distance}, wall
			end
		end
		return nil, wall
	end

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not character.Parent or humanoid.Health <= 0 then
			fallConnection:Disconnect()
			jumpGuardConnection:Disconnect()
			stabilizeConnection:Disconnect()
			stopFlightEffect()
			connection:Disconnect()
			ragdollConnection:Disconnect()
			walkSpeedConnection:Disconnect()
			slideConnection:Disconnect()
			for _, track in pairs(moveTracks) do track:Stop(0) end
			if character.Parent and not puppet then character:SetAttribute("Climbing", false) end
			if currentHumanoid == humanoid then
				currentHumanoid = nil
			end
			return
		end

		if not camera then return end
		if puppet and (camera.CFrame.Position - rootPart.Position).Magnitude > (opts.maxDistance or 160) then return end
		if isRagdolled then
			stopFlightEffect()
			setClimbing(false)
			return
		end

		local velocity = rootPart.AssemblyLinearVelocity
		local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		local horizontalSpeed = horizontalVelocity.Magnitude
		local isMoving = horizontalSpeed > MOVE_SPEED_THRESHOLD

		local humanoidState = humanoid:GetState()
		local isAirborne = humanoidState == Enum.HumanoidStateType.Jumping
			or humanoidState == Enum.HumanoidStateType.Freefall
		setClimbing(humanoidState == Enum.HumanoidStateType.Climbing)
		grounded = not isAirborne and not climbing and humanoid.FloorMaterial ~= Enum.Material.Air

		local injury = {
			rightArm = character:GetAttribute("Injury_RightArm") or 0,
			leftArm = character:GetAttribute("Injury_LeftArm") or 0,
			rightLeg = character:GetAttribute("Injury_RightLeg") or 0,
			leftLeg = character:GetAttribute("Injury_LeftLeg") or 0,
		}
		local legGone = injury.rightLeg >= 3 or injury.leftLeg >= 3
		local crawlForced = legGone or (injury.rightLeg >= 2 and injury.leftLeg >= 2)

		local proneVoluntary = not puppet and crouchHeld and not crawlForced and not climbing
		local crawling = crawlForced or proneVoluntary

		local getUp = (os.clock() - getUpStart) / getUpDuration
		local gettingUp = getUp >= 0 and getUp < 1
		local proneTarget = (crawling and not climbing) and 1 or 0
		if gettingUp and not crawlForced then
			proneAmount = math.clamp(1 - getUp / 0.4, 0, 1)
		else
			proneAmount = approach(proneAmount, proneTarget, dt, 4)
		end

		local slick = not puppet and proneAmount > 0.5
		if slick ~= torsoSlick then
			torsoSlick = slick
			if slick then
				torsoProps = torso.CustomPhysicalProperties
				torso.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 100, 100)
			else
				torso.CustomPhysicalProperties = torsoProps
			end
		end
		local wantJump = proneAmount < 0.5 and not gettingUp
		if not puppet and wantJump ~= jumpEnabled then
			jumpEnabled = wantJump
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, wantJump)
		end

		local crouchWanted = puppet and (
			(character:GetAttribute("GS_EatUntil") or 0) > os.clock()
			or (character:GetAttribute("GS_EatServer") or 0) > workspace:GetServerTimeNow())
		local crouchTarget = (crouchWanted and grounded and not climbing and proneAmount < 0.5) and 1 or 0
		if gettingUp and not crawlForced then
			local getUpCrouch = getUp < 0.45 and 1 or math.clamp(1 - (getUp - 0.45) / 0.55, 0, 1)
			crouchAmount = math.max(approach(crouchAmount, crouchTarget, dt, 9), getUpCrouch)
		else
			crouchAmount = approach(crouchAmount, crouchTarget, dt, 9)
		end

		local inFirstPerson = not puppet and character:GetAttribute("FirstPersonCameraActive") == true
		if not puppet then
			local targetOffset = ShiftLockEnabled and not inFirstPerson and SHOULDER_OFFSET or Vector3.zero
			if not inFirstPerson then
				targetOffset += Vector3.new(0, -CROUCH_CAMERA_DROP * crouchAmount * (1 - proneAmount) - PRONE_CAMERA_DROP * proneAmount, 0)
			end
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetOffset, math.min(dt * CAMERA_OFFSET_SMOOTH, 1))
		end

		local profile = SURFACES[humanoid.FloorMaterial] or SURFACE_DEFAULT
		if not grounded then profile = surfaceState end
		for key, value in pairs(profile) do
			surfaceState[key] = approach(surfaceState[key], value, dt, 5)
		end

		local legState = nil
		do
			local hi = math.max(injury.rightLeg, injury.leftLeg)
			local lo = math.min(injury.rightLeg, injury.leftLeg)
			if hi == 2 then
				legState = lo == 1 and "BrokenAndDamaged" or "OneBroken"
			elseif hi == 1 then
				legState = lo == 1 and "BothDamaged" or "OneDamaged"
			end
		end
		local injurySpeed = crawling and CRAWL_SPEED_MUL or (legState and LEG_SPEED[legState] or 1)
		if crawling then

			local pullers = (injury.rightArm < 2 and 1 or 0) + (injury.leftArm < 2 and 1 or 0)
			local pushers = (injury.rightLeg < 2 and 0.5 or 0) + (injury.leftLeg < 2 and 0.5 or 0)
			local power = pullers + pushers
			if power <= 0 then
				wriggleActive = true
				local surge = math.max(0, math.sin(os.clock() * 5.5))
				injurySpeed *= 0.12 + 0.28 * surge * surge
			else
				wriggleActive = false
				injurySpeed *= power >= 2 and 1 or (power >= 1 and 0.6 or 0.4)
			end

			local move = humanoid.MoveDirection
			local look = rootPart.CFrame.LookVector
			local flatMove, facing = Vector3.new(move.X, 0, move.Z), Vector3.new(look.X, 0, look.Z)
			if flatMove.Magnitude > 0.1 and facing.Magnitude > 1e-3 then
				local d = flatMove.Unit:Dot(facing.Unit)
				injurySpeed *= d > 0.3 and 1 or (d > -0.6 and 0.7 or 0.55)
			end
		else
			wriggleActive = false
		end
		local jumpScale = legState and LEG_JUMP[legState] or 1
		jumpScale *= math.clamp(character:GetAttribute("DebuffSpeed") or 1, 0.6, 1)
		if not puppet and math.abs(jumpScale - lastJumpScale) > 0.001 then
			lastJumpScale = jumpScale
			humanoid.JumpPower = baseJumpPower * math.sqrt(jumpScale)
			humanoid.JumpHeight = baseJumpHeight * jumpScale
		end
		if gettingUp then injurySpeed = math.min(injurySpeed, (spawnGetUp and getUp < 0.75) and 0 or 0.25) end
		injurySpeed *= character:GetAttribute("DebuffSpeed") or 1

		if grounded and not puppet then
			local want = baseWalkSpeed * surfaceState.speed * lerp(1, CROUCH_SPEED_MUL, crouchAmount) * injurySpeed
			if math.abs(humanoid.WalkSpeed - want) > 0.01 then
				writtenWalkSpeed = want
				humanoid.WalkSpeed = want
			end
		end

		if isAirborne then
			wasAirborne = true
			airMinVelocity = math.min(airMinVelocity, velocity.Y)
		elseif wasAirborne then
			wasAirborne = false
			local impact = -airMinVelocity
			airMinVelocity = 0
			if impact >= LANDING_MIN_SPEED and not puppet then
				ScreenEffects.Landing(math.clamp((impact - 40) / 110, 0.05, 1))
			end
		end

		local facing = rootPart.CFrame.LookVector
		local flatFacing = Vector3.new(facing.X, 0, facing.Z)
		flatFacing = flatFacing.Magnitude > 1e-3 and flatFacing.Unit or Vector3.new(0, 0, -1)
		local rightVector = rootPart.CFrame.RightVector
		local moveDir = isMoving and horizontalVelocity.Unit or Vector3.zero
		local forwardDot = moveDir:Dot(flatFacing)
		local sideDot = moveDir:Dot(rightVector)

		local sideAbs = math.abs(sideDot)
		if STRAFE_ENABLED and isMoving and grounded and not climbing and crouchAmount < 0.5 then
			if strafing then
				strafing = sideAbs > STRAFE_EXIT
			else
				strafing = sideAbs > STRAFE_ENTER
			end
		else
			strafing = false
		end
		strafeAmount = approach(strafeAmount, strafing and 1 or 0, dt, 10)
		if strafing and sideAbs > 0.2 then
			strafeSide = sideDot >= 0 and 1 or -1
		end

		local climbTrack = moveTracks.climb
		local climbTrackOK = climbTrack ~= nil and climbTrack.Length > 0
		if climbing then
			SetMoveState("climb")
			if climbTrack then
				local speed = math.clamp(velocity.Y / CLIMB_ANIM_SCALE, -2.5, 2.5)
				climbTrack:AdjustSpeed(math.abs(speed) < 0.05 and 0 or speed)
			end
		elseif isAirborne and moveTracks.jump then
			SetMoveState("jump")
		elseif proneAmount > 0.3 then
			SetMoveState("crawl")
		elseif crouchAmount > 0.5 then
			SetMoveState("crouch")
		elseif isMoving and strafing then
			SetMoveState("strafe")
		elseif isMoving then
			SetMoveState("walk")
			if moveTracks.walk then
				local baseSpeed = ANIMATIONS.walk.speed * surfaceState.anim
				local speed = (forwardDot < BACKWARD_DOT_THRESHOLD) and -baseSpeed or baseSpeed
				moveTracks.walk:AdjustSpeed(speed)
			end
		else
			SetMoveState("idle")
		end

		local fallSpeed = math.max(0, -velocity.Y)
		local falling = humanoidState == Enum.HumanoidStateType.Freefall
		if falling and fallSpeed >= FALL_RAGDOLL_SPEED and not puppet then
			flightEffectActive = true
			ScreenEffects.FlightEffect(fallSpeed, FALL_RAGDOLL_SPEED, FALL_DAMAGE_MAX_SPEED, inFirstPerson)
		else
			stopFlightEffect()
		end

		local camLook = camera.CFrame.LookVector
		if puppet then
			local target = opts.lookTarget and opts.lookTarget(character)
			if target then
				local d = target - headPart.Position
				camLook = d.Magnitude > 0.01 and d.Unit or rootPart.CFrame.LookVector
			else
				camLook = rootPart.CFrame.LookVector
			end
		end
		local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
		local currentYaw = select(2, rootPart.CFrame:ToOrientation())
		local targetBodyYaw = currentYaw
		if flatLook.Magnitude > 0.001 then
			flatLook = flatLook.Unit
			targetBodyYaw = math.atan2(-flatLook.X, -flatLook.Z)
		end
		local yawDiff = math.atan2(math.sin(targetBodyYaw - currentYaw), math.cos(targetBodyYaw - currentYaw))

		if crawlSteering and (puppet or proneAmount <= 0.5 or climbing) then
			crawlSteering = false
			if not puppet and not climbing and DesiredAutoRotate(character) then humanoid.AutoRotate = true end
		end
		if climbing and puppet then
			climbYaw = FindLadderYaw() or climbYaw
		elseif climbing then

			humanoid.AutoRotate = false
			local ladderYaw = FindLadderYaw()
			if ladderYaw then climbYaw = ladderYaw end
			if climbYaw then
				local diff = math.atan2(math.sin(climbYaw - currentYaw), math.cos(climbYaw - currentYaw))
				if math.abs(diff) > 1e-3 then
					local newYaw = currentYaw + diff * math.min(dt * CLIMB_TURN_SPEED, 1)
					rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, newYaw, 0)
				end
			end
		elseif not puppet and proneAmount > 0.5 then

			crawlSteering = true
			humanoid.AutoRotate = false
			local desiredYaw = nil
			if ShiftLockEnabled or inFirstPerson then
				desiredYaw = targetBodyYaw
			else
				local move = humanoid.MoveDirection
				local flatMove = Vector3.new(move.X, 0, move.Z)
				if flatMove.Magnitude > 0.1 then
					flatMove = flatMove.Unit
					local look = rootPart.CFrame.LookVector
					local facing = Vector3.new(look.X, 0, look.Z)
					facing = facing.Magnitude > 1e-3 and facing.Unit or flatMove

					local camFlat = Vector3.new(camLook.X, 0, camLook.Z)
					local backward = facing:Dot(flatMove) < -0.6 and camFlat.Magnitude > 1e-3 and facing:Dot(camFlat.Unit) > 0.3
					if not backward then
						desiredYaw = math.atan2(-flatMove.X, -flatMove.Z)
					end
				end
			end
			if desiredYaw then
				local diff = math.atan2(math.sin(desiredYaw - currentYaw), math.cos(desiredYaw - currentYaw))
				local step = math.clamp(diff, -CRAWL_TURN_RATE * dt, CRAWL_TURN_RATE * dt)
				if math.abs(step) > 1e-4 then
					rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, currentYaw + step, 0)
				end
			end
		elseif not puppet and ShiftLockEnabled and not inFirstPerson and os.clock() - climbReleasedAt > CLIMB_RELEASE_GRACE then
			local newYaw = currentYaw + yawDiff * math.min(dt * BODY_TURN_SMOOTH, 1)
			rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, newYaw, 0)
		end

		if inFirstPerson then
			neckYaw, neckPitch = 0, 0
		else
			local targetNeckYaw = math.clamp(yawDiff, -HEAD_MAX_YAW, HEAD_MAX_YAW)
			local targetNeckPitch = -math.asin(math.clamp(camLook.Y, -1, 1))
			targetNeckPitch = math.clamp(targetNeckPitch, -HEAD_MAX_PITCH, HEAD_MAX_PITCH)
			neckYaw = approach(neckYaw, targetNeckYaw, dt, HEAD_SMOOTH)
			neckPitch = approach(neckPitch, targetNeckPitch, dt, HEAD_SMOOTH)
		end

		local headPitch = neckPitch - proneAmount * 1.25
		do
			local targetYaw = 0
			if not puppet and not humanoid.AutoRotate and grounded and not climbing and proneAmount < 0.3 and horizontalSpeed > 2
				and not character:GetAttribute("Ragdolled") then
				local rel = rootPart.CFrame:VectorToObjectSpace(horizontalVelocity)
				local a = math.atan2(-rel.X, -rel.Z)
				if math.abs(a) > math.pi / 2 then
					a -= math.sign(a) * math.pi
				end
				targetYaw = math.clamp(a, -BODY_STRAFE_YAW, BODY_STRAFE_YAW) * math.clamp((horizontalSpeed - 2) / 4, 0, 1)
			end
			bodyYaw = approach(bodyYaw, targetYaw, dt, 7)
		end
		LimbPose.ApplyNeck(rig, (neckYaw - bodyYaw) * (1 - proneAmount * 0.5), headPitch)

		local targets = {}
		for name, joint in pairs(limbs) do
			targets[name] = {pitchAdd = 0, roll = 0, weight = 0, pitchAbs = 0}
			joint.skipClip = false
		end
		local targetLeanForward, targetLeanRight = 0, 0
		local t = os.clock()
		local hasTool = character:FindFirstChildOfClass("Tool") ~= nil
		local mode = 0

		local function armFree(name)
			return not (hasTool and name == "rightArm")
		end

		if climbing then
			mode = 1
			for _, joint in pairs(limbs) do joint.skipClip = true end
			if not climbTrackOK then

				climbPhase += dt * (velocity.Y / CLIMB_STRIDE) * math.pi
				local s = math.sin(climbPhase)
				for name, target in pairs(targets) do
					local joint = limbs[name]
					target.weight = 1
					if joint.isLeg then
						local lift = joint.side > 0 and math.max(0, -s) or math.max(0, s)
						target.pitchAbs = CLIMB_LEG_BASE + CLIMB_LEG_LIFT * lift
						target.roll = math.rad(4)
					else
						target.pitchAbs = CLIMB_ARM_BASE + CLIMB_ARM_SWING * s * joint.side
						target.roll = math.rad(8)
					end
				end
				targetLeanForward = 0.1
			end

		elseif not grounded then

			local downSpeed = -velocity.Y
			local spread = math.clamp((downSpeed - FALL_SPREAD_SPEED) / 30, 0, 1)
			local flail = math.clamp((downSpeed - FLAIL_SPEED) / 25, 0, 1)
			if spread > 0 then
				mode = 1
				for name, joint in pairs(limbs) do
					local target = targets[name]
					joint.skipClip = true
					local s = joint.side
					if joint.isLeg then
						local calmPitch = math.rad(10) + math.rad(8) * math.sin(t * 2 + s)
						local kickPitch = math.rad(38) * math.sin(t * 9 + (s > 0 and 0 or math.pi))
						target.weight = spread * 0.9
						target.pitchAbs = lerp(calmPitch, kickPitch, flail)
						target.roll = math.rad(8) + math.rad(10) * flail * (0.5 + 0.5 * math.sin(t * 7 + s))
					elseif armFree(name) then
						local calmPitch = FALL_ARMS_PITCH + math.noise(t * 3, s * 4.1) * math.rad(12)
						local calmRoll = FALL_ARMS_ROLL + math.noise(t * 3.3, s * 2.7) * math.rad(10)

						local flailPitch = math.rad(85) + math.rad(95) * math.sin(t * 11 + (s > 0 and 0 or 1.9))
						local flailRoll = math.rad(55) + math.rad(35) * math.sin(t * 8.5 + s * 1.3)
						target.weight = spread
						target.pitchAbs = lerp(calmPitch, flailPitch, flail)
						target.roll = lerp(calmRoll, flailRoll, flail)
					end
				end
				targetLeanForward = -0.12 * flail
				targetLeanRight = math.sin(t * 5) * 0.08 * flail
			end

		else
			local idleFactor = 1 - math.clamp(horizontalSpeed / 3, 0, 1)
			local balanceSide = nil
			local balanceAmount = 0

			if proneAmount > 0.01 then
				mode = 1
				local moving = math.clamp(horizontalSpeed / 1.5, 0, 1)
				crawlPhase += dt * 2 * math.pi * math.clamp(horizontalSpeed / CRAWL_STRIDE, 0, 1.4)
				local s = math.sin(crawlPhase)
				for name, joint in pairs(limbs) do
					local target = targets[name]
					joint.skipClip = true
					if joint.isLeg and proneVoluntary and injury[name] < 2 then

						target.weight = proneAmount
						target.pitchAbs = math.rad(4) + math.rad(12) * s * joint.side * moving
						target.roll = math.rad(8) + math.rad(4) * math.max(0, s * joint.side) * moving
					elseif joint.isLeg then

						local drag = math.sin(crawlPhase * 0.5 + joint.side * 1.6)
						target.weight = proneAmount
						target.pitchAbs = math.rad(2) + math.rad(2) * drag * moving
						target.roll = math.rad(6) + math.rad(2.5) * drag * moving
					elseif armFree(name) then

						target.weight = proneAmount
						target.pitchAbs = math.rad(158) + math.rad(24) * s * joint.side * moving
						target.roll = math.rad(20) - math.rad(6) * s * joint.side * moving
					end
				end
				targetLeanRight += 0.05 * s * moving * proneAmount
				if wriggleActive then

					targetLeanRight += 0.22 * math.sin(os.clock() * 5.5) * moving * proneAmount
				end
			end
			if gettingUp and not crawlForced then

				for _, name in ipairs(ARMS) do
					local joint = limbs[name]
					if armFree(name) then
						local target = targets[name]
						target.weight = 1
						target.pitchAbs = lerp(math.rad(120), math.rad(10), math.clamp(getUp / 0.8, 0, 1))
						target.roll = math.rad(12)
						joint.skipClip = true
					end
				end
			end

			if crouchAmount > 0.01 and proneAmount < 0.3 then
				mode = crouchAmount > 0.5 and 1 or mode
				local moving = math.clamp(horizontalSpeed / 3, 0, 1)
				crouchPhase += dt * 2 * math.pi * math.clamp(horizontalSpeed / CROUCH_STRIDE, 0, 1.8)
				local s = math.sin(crouchPhase)

				local swap = math.tanh(2.6 * s) / math.tanh(2.6)
				local c = math.cos(crouchPhase)
				for name, joint in pairs(limbs) do
					local target = targets[name]
					if joint.isLeg then

						local kneel = joint.side > 0 and math.rad(66) or math.rad(-58)

						local walk = math.rad(64) * swap * joint.side
						local lift = math.max(0, c * joint.side)
						target.weight = crouchAmount
						target.pitchAbs = lerp(kneel, walk, moving)
						target.roll = math.rad(5) + math.rad(7) * lift * moving
						joint.skipClip = true
					elseif armFree(name) then

						target.weight = crouchAmount * 0.85
						target.pitchAbs = math.rad(32) - math.rad(22) * swap * joint.side * moving
						target.roll = math.rad(5)
					end
				end
				targetLeanForward += (0.3 + 0.04 * math.abs(s) * moving) * crouchAmount
				targetLeanRight += 0.03 * swap * moving * crouchAmount
			end

			if idleFactor > 0.01 and crouchAmount < 0.5 and proneAmount < 0.3 then
				local info = {}
				local voidCount = 0
				for _, name in ipairs(LEGS) do
					local joint = limbs[name]
					local g, hit = LimbPose.GroundDistance(rig, joint, params, 1.5)
					local void = g > joint.length + VOID_EXTRA
					if void then voidCount += 1 end
					info[name] = {g = g, hit = hit, void = void}
				end
				for _, name in ipairs(LEGS) do
					local joint = limbs[name]
					local data = info[name]
					local target = targets[name]
					local L = joint.length
					if data.void and voidCount == 1 then

						target.weight = math.max(target.weight, HERON_WEIGHT * idleFactor)
						target.pitchAbs = HERON_PITCH
						target.roll = HERON_ROLL
						balanceSide = -joint.side
						balanceAmount = idleFactor
						targetLeanRight += -joint.side * 0.05 * idleFactor
					elseif data.void then

						target.pitchAdd += math.rad(10) * idleFactor
						target.roll += math.rad(6) * idleFactor
					elseif data.hit then

						local lift = 0
						if data.g < L - 0.06 then
							lift = math.min(math.acos(math.clamp(data.g / L, 0, 1)), LEG_MAX_LIFT)
						end
						local n = torso.CFrame:VectorToObjectSpace(data.hit.Normal)
						local alignPitch = math.clamp(math.atan2(n.Z, n.Y), -SLOPE_MAX, SLOPE_MAX)
						local alignRoll = math.clamp(math.asin(math.clamp(-n.X, -1, 1)), -SLOPE_MAX, SLOPE_MAX) * joint.side
						target.pitchAdd += (lift + alignPitch * SLOPE_ALIGN) * idleFactor
						target.roll += alignRoll * SLOPE_ALIGN * idleFactor
					end
				end
			end

			if isMoving and strafeAmount < 0.5 and crouchAmount < 0.5 then
				for _, name in ipairs(LEGS) do
					local joint = limbs[name]
					local animPitch = LimbPose.AnimPitch(joint)
					targets[name].pitchAdd += surfaceState.lift * math.clamp(animPitch / 0.45, 0, 1)
					if surfaceState.wobble > 0.01 then
						targets[name].roll += math.noise(t * 3, joint.side * 7.3) * math.rad(6) * surfaceState.wobble
					end
				end
				targetLeanForward += surfaceState.lean
				if surfaceState.wobble > 0.01 then
					targetLeanRight += math.noise(t * 1.7, 3.1) * 0.06 * surfaceState.wobble
				end
				local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -4.5, 0), params)
				if hit then
					local uphill = -hit.Normal:Dot(moveDir)
					targetLeanForward += math.clamp(uphill * 0.5, -0.1, 0.18)
				end
			end

			if strafeAmount > 0.01 then
				local hz = math.clamp(horizontalSpeed / STRAFE_STRIDE, STRAFE_MIN_HZ, STRAFE_MAX_HZ)
				strafePhase = (strafePhase + dt * 2 * math.pi * hz) % (2 * math.pi)
				local s = math.sin(strafePhase)
				local c = math.cos(strafePhase)
				local lateral = math.clamp(sideAbs, 0, 1)
				local forward = math.clamp(forwardDot, -1, 1)
				local amount = strafeAmount
				for _, name in ipairs(LEGS) do
					local joint = limbs[name]
					local target = targets[name]

					local roll = STRAFE_ROLL * lateral * s

					local lift = math.max(0, strafeSide * joint.side * c)

					local cross = math.max(0, -roll) * STRAFE_CROSS_FORWARD
					local swing = forward * STRAFE_SWING * s * joint.side
					target.weight = math.max(target.weight, amount)
					target.pitchAbs = swing + STRAFE_LIFT * lift * lateral + cross
					target.pitchAdd = 0
					target.roll = roll
				end
				for _, name in ipairs(ARMS) do
					local joint = limbs[name]
					if armFree(name) then
						local target = targets[name]

						target.weight = math.max(target.weight, amount)
						target.pitchAbs = STRAFE_ARM_PITCH_SWING * s * joint.side * (0.6 + 0.4 * lateral)
							- forward * STRAFE_SWING * 0.5 * s * joint.side
						target.roll = STRAFE_ARM_ROLL - STRAFE_ARM_ROLL_SWING * s * lateral
					end
				end
				targetLeanRight += (strafeSide * STRAFE_LEAN + 0.03 * math.sin(strafePhase * 2)) * lateral * amount
				targetLeanForward += forward * 0.04 * amount
			end

			local moveInput = humanoid.MoveDirection
			local towardWall = moveInput.Magnitude > 0.1 and moveInput.Unit:Dot(flatFacing) > 0.3
			local ledge, frontWall = FindLedge(flatFacing)
			local frontFacing = frontWall and frontWall.Normal:Dot(flatFacing) < -0.5
			local wallDistance = frontFacing and frontWall.Distance or math.huge
			local awayFromLedge = moveInput.Magnitude > 0.1 and moveInput.Unit:Dot(flatFacing) < -0.3

			for _, name in ipairs(ARMS) do
				local joint = limbs[name]
				if armFree(name) and crouchAmount < 0.5 and proneAmount < 0.3 and not gettingUp then
					local target = targets[name]
					local handled = false

					if ledge and not awayFromLedge and ledge.distance < LEDGE_REACH then
						local grip = ledge.point + rightVector * joint.side * LEDGE_HAND_SPREAD + Vector3.new(0, 0.12, 0)
						local pitch, roll = aimArm(joint, grip)
						target.weight = 1
						target.pitchAbs = pitch
						target.roll = roll
						joint.skipClip = true
						handled = true

					elseif frontFacing and wallDistance < GUARD_DISTANCE
						and (towardWall or wallDistance < GUARD_IDLE_DISTANCE) then
						local reach = joint.length * math.cos(math.abs(GUARD_ROLL))
						local room = wallDistance - LimbPose.HALF_DEPTH - 0.05
						local pitch = room >= reach and GUARD_MAX_PITCH
							or math.max(GUARD_MIN_PITCH, math.asin(math.clamp(room / reach, 0, 1)))
						target.weight = 1
						target.pitchAbs = pitch
						target.roll = GUARD_ROLL
						joint.skipClip = true
						handled = true
						if name == "rightArm" then targetLeanForward -= 0.03 end
					end

					if not handled then
						local dS = LimbPose.Probe(rig, joint, Vector3.new(joint.side, 0, 0), {0.3, joint.length * 0.6}, 2.3, params)
						if dS < SIDE_REACH then
							if dS > 0.55 then
								target.weight = isMoving and 0.8 or 1
								target.pitchAbs = SIDE_PITCH
								target.roll = math.asin(math.clamp((dS - 0.5) / joint.length, 0, 1))
								joint.skipClip = true
							else
								target.weight = 0.8
								target.pitchAbs = math.rad(4)
								target.roll = math.rad(-8)
							end
						end
					end

					if balanceSide == joint.side and balanceAmount > 0 then
						balanceWobble = math.noise(t * 4, 9.1)
						target.weight = math.max(target.weight, balanceAmount)
						target.pitchAbs = BALANCE_PITCH + math.rad(10) * balanceWobble
						target.roll = BALANCE_ROLL + math.rad(12) * balanceWobble
						joint.skipClip = true
					end

					if surfaceState.balance > 0.01 and not handled then
						local wobble = 1 + math.noise(t * 2.3, joint.side) * 0.4
						target.roll += surfaceState.balance * wobble * (isMoving and 1 or 0.5)
					end
				end
			end
		end

		local talkUntil = character:GetAttribute("TalkUntil")
		if talkUntil and os.clock() < talkUntil and not climbing and proneAmount < 0.3 then
			local fade = math.clamp((talkUntil - os.clock()) / 0.4, 0, 1)
			for i, name in ipairs(ARMS) do
				if injury[name] < 2 and not (hasTool and name == "rightArm") then
					local joint = limbs[name]
					local target = targets[name]
					local phase = t * (i == 1 and 5.1 or 4.3) + i * 1.7
					local active = i == 1 and 1 or (0.55 + 0.45 * math.sin(t * 0.9))
					target.weight = math.max(target.weight, 0.6 * fade * active)
					target.pitchAbs = math.rad(28) + math.rad(20) * math.sin(phase) + math.rad(8) * math.sin(phase * 2.3)
					target.roll = math.rad(6) + math.rad(7) * math.sin(phase * 0.7)
					joint.skipClip = false
				end
			end
		end

		if not climbing then
			local limpPhase = t * math.clamp(horizontalSpeed / 2.2, 2, 7)
			for _, name in ipairs(LEGS) do
				local joint = limbs[name]
				if injury[name] == 2 and proneAmount < 0.3 then
					local target = targets[name]
					joint.skipClip = true
					if not grounded then
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(8)
						target.roll = math.rad(3)
					elseif isMoving then
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(-8) + math.rad(3) * math.sin(limpPhase * 0.5)
						target.roll = math.rad(4)
						targetLeanRight += -joint.side * (0.07 + 0.04 * math.abs(math.sin(limpPhase)))
						targetLeanForward += 0.06
					else

						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(12)
						target.roll = math.rad(4)
						targetLeanRight += -joint.side * 0.07
					end
				end
			end
			for _, name in ipairs(ARMS) do
				local joint = limbs[name]
				if injury[name] == 2 and proneAmount < 0.3 then

					local target = targets[name]
					joint.skipClip = false
					target.weight = 1
					target.pitchAbs = math.rad(3) + math.rad(5) * math.sin(t * 2.3 + joint.side) * math.clamp(horizontalSpeed / 8, 0.2, 1)
					target.roll = math.rad(-3)
					target.pitchAdd = 0
				end
			end
		end

		if not climbing and proneAmount < 0.3 and not gettingUp then
			for name, target in pairs(targets) do
				if injury[name] ~= 2 then
					target.pitchAbs *= LIMB_LIFT_SCALE
					target.pitchAdd *= LIMB_LIFT_SCALE
				end
			end
		end

		if (puppet or character:GetAttribute("GS_AttackStart")) and not climbing then
			local now = os.clock()
			local attackStart = character:GetAttribute("GS_AttackStart")
			local eatUntil = puppet and character:GetAttribute("GS_EatUntil") or nil

			local attackServer = character:GetAttribute("GS_AttackServer")
			if attackServer then
				local local0 = now - (workspace:GetServerTimeNow() - attackServer)
				if not attackStart or local0 > attackStart then attackStart = local0 end
			end
			local eatServer = puppet and character:GetAttribute("GS_EatServer")
			if eatServer then
				local local1 = now + (eatServer - workspace:GetServerTimeNow())
				if not eatUntil or local1 > eatUntil then eatUntil = local1 end
			end
			if attackStart and now - attackStart < 0.6 then
				local p = (now - attackStart) / 0.6
				local pitch
				if p < 0.4 then
					pitch = lerp(math.rad(20), math.rad(165), p / 0.4)
				else
					pitch = lerp(math.rad(165), math.rad(10), math.clamp((p - 0.4) / 0.35, 0, 1))
				end
				for i, name in ipairs(ARMS) do
					if injury[name] < 3 then
						local target = targets[name]
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = pitch - (i == 2 and math.rad(18) or 0)
						target.roll = math.rad(-12)
						limbs[name].skipClip = true
					end
				end
				targetLeanForward += p < 0.4 and -0.12 or 0.3
			elseif eatUntil and now < eatUntil then
				for i, name in ipairs(ARMS) do
					if injury[name] < 3 then
						local target = targets[name]
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(75) + math.rad(22) * math.sin(now * 13 + i * 1.9)
						target.roll = math.rad(-28)
						limbs[name].skipClip = true
					end
				end
				targetLeanForward += 0.35
			elseif puppet and character:GetAttribute("GS_Twitch") then

				for i, name in ipairs(ARMS) do
					if injury[name] < 3 then
						local target = targets[name]
						local jerk = math.noise(now * 7, i * 3.1) * math.rad(35)
						target.weight = 1
						target.pitchAdd = 0
						target.pitchAbs = math.rad(95) + jerk
						target.roll = math.rad(-8) + math.noise(now * 5, i) * math.rad(20)
						limbs[name].skipClip = true
					end
				end
				targetLeanForward += 0.28 + math.noise(now * 3, 7.7) * 0.1
				targetLeanRight += math.noise(now * 9, 1.3) * 0.12
			end
		end

		local alpha = math.min(dt * LIMB_SMOOTH, 1)
		for name, joint in pairs(limbs) do
			local target = targets[name]
			if joint.weight < 0.05 then
				joint.pitchAbs = target.pitchAbs
			else
				joint.pitchAbs += (target.pitchAbs - joint.pitchAbs) * alpha
			end
			joint.pitchAdd += (target.pitchAdd - joint.pitchAdd) * alpha
			joint.roll += (target.roll - joint.roll) * alpha
			joint.weight += (target.weight - joint.weight) * alpha
		end
		if not climbing and proneAmount < 0.3 then
			for _, name in ipairs(LEGS) do
				if injury[name] == 2 then
					local joint = limbs[name]
					joint.weight = 1
					joint.pitchAdd = 0
					joint.pitchAbs = math.clamp(joint.pitchAbs, math.rad(-12), math.rad(14))
				end
			end
			for _, name in ipairs(ARMS) do
				if injury[name] == 2 then
					local joint = limbs[name]
					joint.weight = 1
					joint.pitchAdd = 0
				end
			end
		end
		leanForward = approach(leanForward, math.clamp(targetLeanForward, -0.35, 0.35), dt, LEAN_SMOOTH)
		leanRight = approach(leanRight, math.clamp(targetLeanRight, -0.35, 0.35), dt, LEAN_SMOOTH)

		LimbPose.ApplyLean(rig, leanForward, leanRight, crouchAmount, proneAmount, bodyYaw)
		LimbPose.Apply(rig, {antiClip = true, params = params})

		sendTimer += dt
		if not puppet and sendTimer >= SEND_INTERVAL then
			sendTimer = 0
			local values = LimbPose.Collect(rig, (neckYaw - bodyYaw) * (1 - proneAmount * 0.5), headPitch, leanForward, leanRight, mode, crouchAmount, proneAmount, bodyYaw)
			event:FireServer(LimbPose.Pack(values))
		end
	end)
end

if player.Character then
	task.spawn(SetupCharacter, player.Character)
end
player.CharacterAdded:Connect(SetupCharacter)

local function WatchPlayer(plr)
	if plr == player then return end
	if plr.Character then
		task.spawn(SetupRemoteCharacter, plr, plr.Character)
	end
	plr.CharacterAdded:Connect(function(char)
		SetupRemoteCharacter(plr, char)
	end)
end

for _, plr in ipairs(Players:GetPlayers()) do
	WatchPlayer(plr)
end
Players.PlayerAdded:Connect(WatchPlayer)
Players.PlayerRemoving:Connect(function(plr)
	remoteData[plr] = nil
end)

local function nearestPlayerHead(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local best, bestDist = nil, 45
	for _, plr in ipairs(Players:GetPlayers()) do
		local head = plr.Character and plr.Character:FindFirstChild("Head")
		if head then
			local d = (head.Position - root.Position).Magnitude
			if d < bestDist then best, bestDist = head.Position, d end
		end
	end
	return best
end

local function localPlayerHead(character)
	local look = character:GetAttribute("GS_LookAt")
	if typeof(look) == "Vector3" then return look end
	local head = player.Character and player.Character:FindFirstChild("Head")
	return head and head.Position or nil
end

local function watchFolder(folderName, lookTarget)
	task.spawn(function()
		local folder = workspace:WaitForChild(folderName, 120)
		if not folder then return end
		local function add(model)
			if model:IsA("Model") then
				task.spawn(SetupCharacter, model, {puppet = true, lookTarget = lookTarget})
			end
		end
		for _, model in ipairs(folder:GetChildren()) do add(model) end
		folder.ChildAdded:Connect(add)
	end)
end

watchFolder("NPCs", nearestPlayerHead)

local function monsterLook(character)
	local look = character:GetAttribute("GS_LookAt")
	if typeof(look) == "Vector3" then return look end
	local value = character:FindFirstChild("GS_Target")
	local target = value and value.Value
	local head = target and target.Parent and (target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart"))
	if head then return head.Position end
	return nearestPlayerHead(character)
end
watchFolder("Monsters", monsterLook)
task.spawn(function()
	local folder = workspace:WaitForChild("GS_Hallucinations", 120)
	if not folder then return end
	local function add(model)
		if model:IsA("Model") then
			task.spawn(SetupCharacter, model, {puppet = true, noGetUp = true, lookTarget = localPlayerHead})
		end
	end
	for _, model in ipairs(folder:GetChildren()) do add(model) end
	folder.ChildAdded:Connect(add)
end)
