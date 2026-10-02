local GS_AimBlend = {} -- per character: how far the gun is raised (0 low ready .. 1 at the eye)
-- (GS: holding items and guns, carrying weight, bear traps and webs are handled here too:
--   GS_HoldPose / GS_Aim / GS_ReloadAt / GS_RecoilAt / GS_UseStart pose the arms, GS_CarrySpeed slows you by the weight
--   you carry, GS_Trapped holds you in place, GS_WebStun puts you down in the threads and you get up slowly as it runs out)
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
end, false, table.unpack(crouchKeys))
-- phones: the HUD's own CRAWL button (Controls script) toggles it through this event
task.spawn(function()
	local action = player:WaitForChild("GS_ClientAction", 30)
	if not action then return end
	action.Event:Connect(function(kind)
		if kind == "crawl" then crouchHeld = not crouchHeld end
	end)
end)

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
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(3, 3)
	dot.BackgroundColor3 = Color3.new(1,1,1)
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
	local center = Instance.new("Frame")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(3, 3)
	center.BackgroundColor3 = Color3.new(1,1,1)
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
	player:SetAttribute("GS_ShiftLock", enabled or nil)
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
	-- a gun in the hand: its own spread circle takes over from the cursor and the dot
	if player:GetAttribute("GS_Crosshair") and not uiOpen then
		cursor.Visible = false
		reticle.Visible = false
	elseif not ShiftLockEnabled and not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		cursor.Visible = true
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

		-- caught in a web: flat in the threads, then up on the knees, then standing, as the timer runs out
		-- (no ragdoll and no concussion any more)
		local serverTime = workspace:GetServerTimeNow()
		local webLeft = (character:GetAttribute("GS_WebStun") or 0) - serverTime
		local webStunned = webLeft > 0 and not climbing and humanoid.Health > 0
		local webP = 1
		if webStunned then
			webP = math.clamp(1 - webLeft / math.max(character:GetAttribute("GS_WebStunDur") or 5, 0.5), 0, 1)
		end
		local trapUntil = character:GetAttribute("GS_Trapped")
		local trapped = typeof(trapUntil) == "number" and trapUntil > serverTime

		local getUp = (os.clock() - getUpStart) / getUpDuration
		local gettingUp = getUp >= 0 and getUp < 1
		local proneTarget = (crawling and not climbing) and 1 or 0
		if webStunned then
			local webProne = webP < 0.35 and 1 or math.clamp(1 - (webP - 0.35) / 0.35, 0, 1)
			proneAmount = approach(proneAmount, math.max(webProne, crawlForced and 1 or 0), dt, webP < 0.35 and 6 or 3)
		elseif gettingUp and not crawlForced then
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
		local wantJump = proneAmount < 0.5 and not gettingUp and not webStunned and not trapped
		if not puppet and wantJump ~= jumpEnabled then
			jumpEnabled = wantJump
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, wantJump)
		end

		-- monsters feeding, and infected players holding E over remains, hunch down over the meat
		local crouchWanted = (puppet and (character:GetAttribute("GS_EatUntil") or 0) > os.clock())
			or (character:GetAttribute("GS_EatServer") or 0) > workspace:GetServerTimeNow()
		local crouchTarget = (crouchWanted and grounded and not climbing and proneAmount < 0.5) and 1 or 0
		if gettingUp and not crawlForced then
			local getUpCrouch = getUp < 0.45 and 1 or math.clamp(1 - (getUp - 0.45) / 0.55, 0, 1)
			crouchAmount = math.max(approach(crouchAmount, crouchTarget, dt, 9), getUpCrouch)
		else
			crouchAmount = approach(crouchAmount, crouchTarget, dt, 9)
		end
		if webStunned and webP >= 0.35 and not crawlForced then
			-- on the knees for a moment, then straightening up
			crouchAmount = math.max(crouchAmount, webP < 0.6 and 1 or math.clamp(1 - (webP - 0.6) / 0.4, 0, 1))
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
			-- threads from a web still clinging after you get up: slowed until they fall off
			local webbed = (character:GetAttribute("GS_Webbed") or 0) > serverTime
			-- the heavier the load (armor, guns), the slower; a trap or a web holds you in place; aiming is a slow walk
			local carry = math.clamp(tonumber(character:GetAttribute("GS_CarrySpeed")) or 1, 0.4, 1.3)
			local held = (trapped or webStunned) and 0 or 1
			local aimWalk = character:GetAttribute("GS_Aim") and 0.6 or 1
			local want = baseWalkSpeed * surfaceState.speed * lerp(1, CROUCH_SPEED_MUL, crouchAmount) * injurySpeed * (webbed and 0.4 or 1)
				* carry * held * aimWalk
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
		elseif not puppet and proneAmount > 0.5 and not webStunned then

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

		-- the head follows where you look in first person too (everyone else sees it turn and nod)
		do
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
			if webStunned then
				for i, name in ipairs(ARMS) do
					local joint = limbs[name]
					if injury[name] < 3 then
						local target = targets[name]
						target.weight = 1
						joint.skipClip = true
						if webP < 0.35 then
							-- tangled: the arms jerk against the threads
							target.pitchAbs = math.rad(135) + math.noise(t * 3, i * 2.3) * math.rad(40)
							target.roll = math.rad(22) + math.noise(t * 2.5, i * 5.1) * math.rad(22)
						else
							-- pushing up off the floor
							target.pitchAbs = lerp(math.rad(120), math.rad(10), math.clamp((webP - 0.35) / 0.5, 0, 1))
							target.roll = math.rad(12)
						end
					end
				end
				if webP < 0.35 then
					for i, name in ipairs(LEGS) do
						local joint = limbs[name]
						local target = targets[name]
						joint.skipClip = true
						target.weight = proneAmount
						target.pitchAbs = math.rad(4) + math.noise(t * 3.4, i * 7.7) * math.rad(16)
						target.roll = math.rad(8)
					end
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

		if (puppet or character:GetAttribute("GS_AttackStart") or character:GetAttribute("GS_EatServer")) and not climbing then
			local now = os.clock()
			local attackStart = character:GetAttribute("GS_AttackStart")
			local eatUntil = puppet and character:GetAttribute("GS_EatUntil") or nil

			local attackServer = character:GetAttribute("GS_AttackServer")
			if attackServer then
				local local0 = now - (workspace:GetServerTimeNow() - attackServer)
				if not attackStart or local0 > attackStart then attackStart = local0 end
			end
			local eatServer = character:GetAttribute("GS_EatServer")
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

		-- what's in the hand: guns up to the eye when aiming, low ready otherwise; melee at the side; kits in front
		local holdPose = character:GetAttribute("GS_HoldPose")
		if holdPose and not climbing and not webStunned and proneAmount < 0.3 then
			local clock = serverTime
			local aimPitch = math.clamp(math.asin(math.clamp(camLook.Y, -1, 1)), math.rad(-60), math.rad(70))
			local aimingNow = character:GetAttribute("GS_Aim") == true
			-- the gun comes up to the eye and goes back down over a moment instead of snapping
			local ab = GS_AimBlend[character] or {v = 0, t = clock}
			GS_AimBlend[character] = ab
			local adt = math.clamp(clock - ab.t, 0, 0.1)
			ab.t = clock
			ab.v += ((aimingNow and 1 or 0) - ab.v) * (1 - math.exp(-(aimingNow and 12 or 9) * adt))
			local aimK = ab.v * ab.v * (3 - 2 * ab.v)
			local reloadAt = character:GetAttribute("GS_ReloadAt")
			local reloading = reloadAt and clock - reloadAt < (character:GetAttribute("GS_ReloadDur") or 2.4)
			local recoilAt = character:GetAttribute("GS_RecoilAt")
			local recoil = recoilAt and math.clamp(1 - (clock - recoilAt) / 0.18, 0, 1) or 0
			local pumpAt = character:GetAttribute("GS_PumpAt")
			local pumpT=pumpAt and (clock-pumpAt)/0.42 or 2
 local pump=pumpT>=0 and pumpT<1 and math.sin(pumpT*math.pi) or 0
			local attackAt = character:GetAttribute("GS_WeaponSwingAt")
			local swingP = attackAt and (clock - attackAt) / (character:GetAttribute("GS_AttackDuration") or 0.8) or 2
			local useAt = character:GetAttribute("GS_UseStart")
			local using = useAt and serverTime - useAt < 12
			local drawAt = character:GetAttribute("GS_DrawAt")
			local draw = drawAt and math.clamp((serverTime - drawAt) / 0.3, 0, 1) or 1
			local r, l = targets.rightArm, targets.leftArm
			local rightOk = limbs.rightArm and injury.rightArm < 3
			local leftOk = limbs.leftArm and injury.leftArm < 3
			local function pose(target, joint, pitch, roll, weight)
				if not target or not joint then return end
				target.weight = (weight or 1) * draw
				target.pitchAdd = 0
				target.pitchAbs = pitch
				target.roll = roll
				joint.skipClip = true
			end
			if holdPose == "long" or holdPose == "pistol" then
				-- R6 is rigid: straight arms, no elbows. Both arms come forward and angle in to meet at the gun: the
				-- gun hand turned at the shoulder to line up with the grip, the other hand under the fore-end. The torso
				-- leans into it (5-10 degrees). A slow breath lifts the arms and the chest a little, in place.
				local long = holdPose == "long"
				local rad = math.rad
				local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
				local breathe = math.sin(clock * 2 * math.pi / 3.4)
				local sway = math.sin(clock * 2 * math.pi / 5.3 + 1.3)
				local phase = reloading and character:GetAttribute("GS_ReloadPhase") or nil
				local pt = phase and math.clamp((clock - (character:GetAttribute("GS_ReloadPhaseAt") or clock))
					/ math.max(character:GetAttribute("GS_ReloadPhaseDur") or 0.5, 0.01), 0, 1) or 0
				local isPump = character:GetAttribute("GS_Hold") == "warden870"
				local rp, rr, lp, lr, lean
				if phase then
					-- loading: the gun comes down and across the chest, the other hand works
					rp, rr = rad(long and 50 or 54), rad(isPump and -34 or (long and -26 or -22))
					lean = rad(9)
					if phase == "open" then
						local k = smooth(pt / 0.6)
						rp = lerp(rad(74), rp, k)
						-- break guns: the hand pushes the barrels down; the pump gun is rolled to show its port
						lp = lerp(rad(76), rad(isPump and 50 or 60), k)
						lr = lerp(rad(-50), rad(isPump and -40 or -54), k)
						if not isPump and pt > 0.55 then lp -= math.sin((pt - 0.55) / 0.45 * math.pi) * rad(8) end
					elseif phase == "load" then
						-- per shell: hand down to the belt, up to the breech with it, thumb it in
						local n = math.max(1, character:GetAttribute("GS_ReloadCount") or 1)
						local sub = math.min(pt * n, n - 1e-3) % 1
						if sub < 0.35 then
							local k = smooth(sub / 0.35)
							lp, lr = lerp(rad(54), rad(6), k), lerp(rad(-46), rad(-6), k)
						elseif sub < 0.75 then
							local k = smooth((sub - 0.35) / 0.4)
							lp, lr = lerp(rad(6), rad(isPump and 46 or 54), k), lerp(rad(-6), rad(isPump and -36 or -46), k)
						else
							local k = math.sin((sub - 0.75) / 0.25 * math.pi)
							lp, lr = rad(isPump and 46 or 54) + k * rad(7), rad(isPump and -36 or -46)
						end
					else -- close
						local k = smooth(pt / 0.45)
						if isPump then
							-- rack it: pull the fore-end back and slam it home
							local rack = math.sin(math.clamp(pt / 0.7, 0, 1) * math.pi)
							rp = lerp(rp, rad(72), k)
							rr = lerp(rr, rad(-15), k)
							lp, lr = lerp(rad(46), rad(74), k) - rack * rad(12), lerp(rad(-36), rad(-50), k)
						else
							-- flick the gun up: the barrels swing shut
							local flick = math.sin(math.clamp(pt / 0.35, 0, 1) * math.pi)
							rp = lerp(rp, rad(long and 74 or 72), k) + flick * rad(12)
							rr = lerp(rr, rad(-14), k)
							lp, lr = lerp(rad(54), rad(long and 76 or 70), k), lerp(rad(-46), rad(long and -50 or -42), k)
						end
					end
				else
					-- ready: aimK (0 low ready .. 1 at the eye) lifts both arms together
					local k = aimK
					local base = lerp(rad(long and 74 or 70) + aimPitch * 0.55, rad(90) + aimPitch, k)
					local breath = breathe * rad(1.5) * (1 - 0.6 * k)
					rp = base + recoil * rad(long and 16 or 22) + breath
					rr = lerp(rad(-14), rad(-17), k) + sway * rad(1)
					lp = base + rad(long and 2 or -2) + recoil * rad(10) - pump * rad(10) + breath * 0.9
					lr = long and lerp(rad(-50), rad(-56), k) or lerp(rad(-40), rad(-46), k)
					lean = rad(long and 8 or 6) + breathe * rad(0.8) - recoil * rad(6)
				end
				if rightOk then pose(r, limbs.rightArm, rp, rr) end
				if leftOk then pose(l, limbs.leftArm, lp, lr) end
				targetLeanForward += lean
			elseif holdPose == "melee" or holdPose == "knife" then
				if swingP < 1 and rightOk then
					if holdPose == "knife" then
						-- a quick stab forward
						local s = math.sin(math.clamp(swingP, 0, 1) * math.pi)
						pose(r, limbs.rightArm, math.rad(40) + s * math.rad(60) + aimPitch * 0.5, math.rad(-10) - s * math.rad(10))
						if l and limbs.leftArm then
							-- (one hand is enough: the other one stays down instead of the two-handed overhead swing)
							l.weight, l.pitchAbs, l.pitchAdd, l.roll = 0, 0, 0, 0
							limbs.leftArm.skipClip = false
						end
						targetLeanForward += s * 0.12
					else
						-- wind up over the shoulder, then chop down across
						local up = swingP < 0.27
						local k = up and swingP / 0.27 or math.clamp((swingP - 0.27) / 0.24, 0, 1)
 k=k*k*(3-2*k)
						local pitch = up and lerp(math.rad(25), math.rad(160), k) or lerp(math.rad(160), math.rad(30), k)
						local roll = up and lerp(math.rad(5), math.rad(28), k) or lerp(math.rad(28), math.rad(-28), k)
						pose(r, limbs.rightArm, pitch + aimPitch * 0.75, roll)
						if leftOk and holdPose == "melee" then pose(l, limbs.leftArm, pitch - math.rad(10), math.rad(-30)) end
						targetLeanForward += up and -0.08 or 0.22 * k
					end
				elseif rightOk and not (attackAt and clock - attackAt < 0.6) then
					pose(r, limbs.rightArm, holdPose == "knife" and math.rad(32) or math.rad(22), math.rad(4), isMoving and 0.8 or 1)
				end
			elseif holdPose == "item" then
				if using then
					-- both hands busy in front of the chest (wrapping, stitching, setting a splint)
					local jitter = math.sin(clock * 8) * math.rad(8)
					if rightOk then pose(r, limbs.rightArm, math.rad(58) + jitter, math.rad(-28)) end
					if leftOk then pose(l, limbs.leftArm, math.rad(52) - jitter, math.rad(-30)) end
					targetLeanForward += 0.12
				elseif character:GetAttribute("GS_FlareLit") and rightOk then
					-- a lit flare held up high to see by
					pose(r, limbs.rightArm, math.rad(110) + aimPitch * 0.3, math.rad(10))
				elseif rightOk then
					pose(r, limbs.rightArm, math.rad(34), math.rad(-6), isMoving and 0.8 or 1)
				end
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
