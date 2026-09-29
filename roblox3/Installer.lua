-- ONE-CLICK INSTALLER: guns (ammo tag by the gun, reloads, flare gun, sounds), R6 gun poses, fog, lighting,
-- money display, touch buttons, acid effects, the Spitter's movement, anti-cheat checks.
-- Option A: Studio -> Plugins tab -> Plugins Folder -> put this file there -> restart Studio ->
--   Plugins tab -> "Install scripts" button.
-- Option B: paste the whole file into View -> Command Bar and press Enter (may lag for a few seconds).
-- A script with the same name and type in its own place is overwritten; a missing one is created:
--   Modules      -> ReplicatedStorage.Modules
--   ServerStorage -> ServerStorage (GS_ItemService)
--   ServerScriptService / StarterPlayerScripts as named.
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SCRIPTS = {
	{name = "Animation", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
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
]=]},
	{name = "AntiCheat", class = "Script", where = "ServerScriptService", source = [=[
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
	HoverTime = 3, -- a jump off a ledge, a long fall: up to 3 s in the air is fine
	SpinRate = 45, -- rad/s of turning the body keeps up for several samples (a spin bot)
	SizeTolerance = 0.12, -- a body part more than 12% off its spawn size (hitbox / size hacks)
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
		spin = 4, size = 6, honeypart = 6,
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
	bodymover = true, collision = true, camera = true, decoy = true, size = true, honeypart = true,
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
	-- a laggy connection delivers movement late and in bursts: give it room for its own ping
	local ping = 0
	pcall(function() ping = math.clamp(player:GetNetworkPing(), 0, 1) end)

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
		local allowed = (walk * CONFIG.SpeedAllowanceMult + CONFIG.SpeedAllowanceFlat) * span + walk * ping * 2
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

	-- spin bots: the body turning round and round far faster than a mouse flick, sample after sample
	do
		local look = root.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		if st.lastYaw and st.lastYawT and now > st.lastYawT then
			local d = math.abs((yaw - st.lastYaw + math.pi) % (2 * math.pi) - math.pi) / (now - st.lastYawT)
			st.spinTicks = d > CONFIG.SpinRate and (st.spinTicks or 0) + 1 or 0
			if st.spinTicks >= 6 then
				st.spinTicks = 0
				flag(player, "spin", string.format("turning %.0f rad/s", d))
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end
		st.lastYaw, st.lastYawT = yaw, now
	end

	-- spin-fling exploits
	if root.AssemblyAngularVelocity.Magnitude > CONFIG.FlingAngular then
		flag(player, "fling", string.format("spin %.0f", root.AssemblyAngularVelocity.Magnitude))
		root.AssemblyAngularVelocity = Vector3.zero
		violated = true
	end

	-- body part sizes (server side): changed by nothing in the game, so put back and noted
	if st.bodySizes then
		for part, size in pairs(st.bodySizes) do
			if part.Parent == character and (part.Size - size).Magnitude > size.Magnitude * CONFIG.SizeTolerance then
				part.Size = size
				flag(player, "size", part.Name)
			end
		end
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
	-- the body's own sizes as it spawned: hitbox / size hacks are put back and noted
	task.delay(2, function()
		if not character.Parent then return end
		local sizes = {}
		for _, name in ipairs({"HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then sizes[part] = part.Size end
		end
		st.bodySizes = sizes
	end)
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
local HONEYPOTS = {"AdminRemote", "GiveMoney", "DamagePlayer", "KillPlayer", "SetWalkSpeed", "TeleportRemote", "BanPlayer",
	"GiveCoins", "AdminMenu", "FreeGamepass", "AddCash", "GodMode"}
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

-- ===================== honeypot parts =====================
-- An invisible slab far above everything the map has: nobody gets up there without flying. Touching it is noted
-- (evidence for the admins) and the player is put back where they last stood.
task.spawn(function()
	task.wait(8)
	-- the map's highest point and its middle (only the built world: no players, creatures or effects)
	local skip = {}
	for _, name in ipairs({"Monsters", "NPCs", "GS_FX", "GS_Gibs", "PS_Blood", "GS_Weather", "SpiderWebs", "GS_Items", "GS_Traps"}) do
		local f = workspace:FindFirstChild(name)
		if f then skip[f] = true end
	end
	local top, minX, maxX, minZ, maxZ = -math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Anchored and d.Transparency < 1 then
			local ancestor = d.Parent
			local skipped = false
			while ancestor and ancestor ~= workspace do
				if skip[ancestor] or Players:GetPlayerFromCharacter(ancestor) then skipped = true break end
				ancestor = ancestor.Parent
			end
			if not skipped then
				local p = d.Position
				top = math.max(top, p.Y + d.Size.Y / 2)
				minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
				minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
			end
		end
	end
	if top == -math.huge or top > 5000 then return end
	local slab = Instance.new("Part")
	slab.Name = "AC_Sky"
	slab.Size = Vector3.new(math.clamp(maxX - minX + 600, 600, 2048), 4, math.clamp(maxZ - minZ + 600, 600, 2048))
	slab.Position = Vector3.new((minX + maxX) / 2, top + 140, (minZ + maxZ) / 2)
	slab.Anchored, slab.CanCollide, slab.CanQuery, slab.CastShadow = true, false, false, false
	slab.Transparency = 1
	slab.Parent = workspace
	slab.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local st = player and states[player]
		if not st or isAdmin(player) then return end
		flag(player, "honeypart", "above the map")
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then rubberband(st, root) end
	end)
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
]=]},
	{name = "CombatAudio", class = "ModuleScript", where = "Modules", source = [=[
-- Combat sounds through the AudioBus: every body gets a few separate channels, so sounds of the same kind replace
-- each other (no pile-ups) but different kinds never cut each other off:
--   Shot    the bang itself            ShotTail  its echo in the cave (a moment later, lower, softer)
--   Action  racks, clicks, shells in   Shell     spent shells hitting the floor (three at a time)
--   Weapon  swings and whooshes        Foley     cloth, plates, flesh...
-- Far away shots are muffled (high end cut), close ones are full.
local ItemData=require(script.Parent:WaitForChild("ItemData"))
local Bus=require(script.Parent:WaitForChild("AudioBus"))
local GameSettings=require(script.Parent:WaitForChild("GameSettings"))
local Audio={}
local last={}
local shellSlot=0
local duration={Shotgun=1.6,Flare=1.2,Rack=.6,Click=.3,ShellIn=.4,ShellDrop=.6,Swing=.45,Cloth=.7,Plate=.45,MetalHit=.6,BloodHit=.4,Flesh=.45,Bone=.55,Rattle=.9,Spray=.9,ShockWhoosh=.6,Shock=.8}
local CHANNEL={Shotgun="Shot",Flare="Shot",Rack="Action",Click="Action",ShellIn="Action",Swing="Weapon",ShockWhoosh="Weapon",Shock="Weapon"}
local PRIORITY={Shot=60,ShotTail=40,Action=50,Weapon=45}

local function make(name,id,parent,volume,speed,range,looped)
 local s=Instance.new("Sound") s.Name="GS_Audio_"..name s.SoundId=id s.Volume=math.clamp(volume or .5,0,1)
 s.PlaybackSpeed=speed or 1 s.RollOffMinDistance=7 s.RollOffMaxDistance=range or 100
 s.RollOffMode=Enum.RollOffMode.InverseTapered s.Looped=looped==true
 pcall(function() s.SoundGroup=GameSettings.GetGroup("SFX") end)
 s.Parent=parent
 return s
end

local function distanceTo(parent)
 local camera=workspace.CurrentCamera
 if not camera then return 0 end
 local p=parent:IsA("BasePart") and parent.Position or parent:IsA("Attachment") and parent.WorldPosition
 if not p then return 0 end
 return (p-camera.CFrame.Position).Magnitude
end

-- channel: optional override
function Audio.Play(name,parent,volume,speed,range,looped,channel)
 if not parent or not parent.Parent then return end
 local id=ItemData.Sound(name) if not id then return end
 local now=os.clock()
 if parent:IsA("BasePart") then
  local p=parent.Position local key=name..math.floor(p.X/8)..","..math.floor(p.Y/8)..","..math.floor(p.Z/8)
  if now-(last[key] or 0)<.06 then return end
  last[key]=now
 end
 local s=make(name,id,parent,volume,speed,range,looped)
 channel=channel or (looped and "Loop") or CHANNEL[name]
 if not channel and name=="ShellDrop" then shellSlot=(shellSlot+1)%3 channel="Shell"..shellSlot end
 channel=channel or "Foley"
 local playing=Bus.Play(s,parent,channel,PRIORITY[channel] or 30,.05,looped and math.huge or duration[name] or 1.2,looped)
 if math.random()<.02 then for key,t in pairs(last) do if now-t>10 then last[key]=nil end end end
 return playing
end

-- a gunshot: the bang (muffled with distance) and a late, low echo off the cave walls
function Audio.Shot(name,parent,volume,speed,range)
 local s=Audio.Play(name,parent,volume,speed,range,false,"Shot")
 if not s then return end
 local d=distanceTo(parent)
 if d>45 then
  local eq=Instance.new("EqualizerSoundEffect")
  eq.HighGain=-math.clamp((d-45)/6,0,26) eq.MidGain=-math.clamp((d-45)/14,0,10) eq.LowGain=2
  eq.Parent=s
 end
 local id=ItemData.Sound(name)
 task.delay(.09+math.min(d,200)/1500,function()
  if not parent.Parent or not id then return end
  local tail=make(name.."Tail",id,parent,(volume or .8)*.28,(speed or 1)*.62,(range or 300)*1.2,false)
  local eq=Instance.new("EqualizerSoundEffect") eq.HighGain=-22 eq.MidGain=-6 eq.LowGain=3 eq.Parent=tail
  Bus.Play(tail,parent,"ShotTail",PRIORITY.ShotTail,.05,1.8,false)
 end)
 return s
end

return Audio
]=]},
	{name = "CombatFX", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
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
]=]},
	{name = "Controls", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- The action HUD for everyone:
--  * keyboard: an ability panel (bottom-right) showing what each key does, with cooldowns. The infected also see
--    their stage, kills to the next stage and whether they are close to the Mother.
--  * touch: real on-screen buttons (HIT, CRAWL, GRAB for the infected) that never sit on the jump button.
--    Survivors also get BAG (the item wheel) and, with something in the hand, USE / FIRE, AIM, RELOAD and AWAY.
--  * an editor (the HUD button at the top): drag any button or panel, change its size and opacity, reset it.
--    The layout is saved on the server per device kind, so it comes back next time.
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local prefsRemote = ReplicatedStorage:WaitForChild("GS_Prefs", 30)

local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local DEVICE = TOUCH and "touch" or "desktop"

local STYLE = {
	Font = Enum.Font.SpecialElite,
	Ink = Color3.fromRGB(228, 220, 212),
	Dim = Color3.fromRGB(135, 124, 118),
	Faint = Color3.fromRGB(80, 72, 68),
	Panel = Color3.fromRGB(8, 6, 6),
	Blood = Color3.fromRGB(150, 12, 16),
	BloodBright = Color3.fromRGB(220, 34, 34),
	Ready = Color3.fromRGB(205, 40, 40),
}

local function create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do inst[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	return inst
end

-- the local event the gameplay scripts listen to (MonsterClient: strike / grab, Animation: crawl)
local clientAction = player:FindFirstChild("GS_ClientAction")
if not clientAction then
	clientAction = Instance.new("BindableEvent")
	clientAction.Name = "GS_ClientAction"
	clientAction.Parent = player
end

local gui = create("ScreenGui", {
	Name = "GS_Controls", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
})

-- ===== state helpers =====
local function character() return player.Character end
local function alive()
	local c = character()
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
local function infected()
	local c = character()
	return player:GetAttribute("Infected") == true and c ~= nil and c:GetAttribute("Infected") == true
end
local function stage()
	local c = character()
	return math.clamp((c and c:GetAttribute("InfectStage")) or 1, 1, 3)
end
local function inMenu()
	return player:GetAttribute("InMenu") == true or player:GetAttribute("UIOpen") == true
end
-- seconds left on the local swing (MonsterClient stamps GS_AttackStart with os.clock on every swing).
-- The infected claw every 0.7 s; a survivor's shove every 1.5 s.
local function strikeCooldown()
	local c = character()
	return (c and c:GetAttribute("Infected")) and 0.7 or 1.5
end
local function strikeLeft()
	local c = character()
	local t = c and c:GetAttribute("GS_AttackStart")
	return typeof(t) == "number" and math.max(0, strikeCooldown() - (os.clock() - t)) or 0
end
local function grabLeft()
	local c = character()
	return math.max(0, ((c and c:GetAttribute("GS_GrabReadyAt")) or 0) - workspace:GetServerTimeNow())
end

-- ===== movable elements: everything the editor can move =====
-- each: {id, name, frame, scalable, fadable, defaultPos (UDim2, top-left), getAlpha/setAlpha}
local movables = {}
local layout = {} -- id -> {x, y, s, a}

-- AbsolutePosition leaves out the top-bar inset while a Position inside a ScreenGui that ignores the inset
-- counts from the very top of the screen, so every conversion goes through the containers' own AbsolutePosition
local function relativeTo(container, point)
	local origin, size = container.AbsolutePosition, container.AbsoluteSize
	return (point.X - origin.X) / math.max(size.X, 1), (point.Y - origin.Y) / math.max(size.Y, 1)
end

local function applyEntry(m)
	local e = layout[m.id]
	local scale = m.frame:FindFirstChild("GS_LayoutScale")
	if not scale then
		scale = create("UIScale", {Name = "GS_LayoutScale", Parent = m.frame})
	end
	scale.Scale = e and e.s or 1
	if m.external then
		m.frame:SetAttribute("GS_LayoutPos", e and UDim2.fromScale(e.x, e.y) or nil)
	else
		m.frame.AnchorPoint = Vector2.new(0, 0)
		m.frame.Position = e and UDim2.fromScale(e.x, e.y) or m.defaultPos()
	end
	if m.setAlpha then m.setAlpha(e and e.a or 0) end
end

local function register(m)
	table.insert(movables, m)
	applyEntry(m)
end

-- ===== the keyboard ability panel =====
local abilityPanel = create("Frame", {
	Name = "Abilities", Size = UDim2.fromOffset(246, 10), BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.Y, Parent = gui, Visible = false,
})
create("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = abilityPanel})

-- infected header: stage, progress to the next stage, and the Mother
local header = create("Frame", {
	Name = "Header", Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = STYLE.Panel, BackgroundTransparency = 0.2,
	BorderSizePixel = 0, LayoutOrder = 0, Parent = abilityPanel,
}, {create("UIStroke", {Color = Color3.fromRGB(70, 8, 10), Thickness = 1})})
create("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = STYLE.Blood, BorderSizePixel = 0, Parent = header})
local stageText = create("TextLabel", {
	Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -18, 0, 18), BackgroundTransparency = 1, Font = STYLE.Font,
	TextSize = 15, TextColor3 = STYLE.BloodBright, TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})
local stageBarBack = create("Frame", {
	Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 3), BackgroundColor3 = Color3.fromRGB(40, 10, 10),
	BorderSizePixel = 0, Parent = header,
})
local stageBar = create("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = STYLE.BloodBright, BorderSizePixel = 0, Parent = stageBarBack})
local motherText = create("TextLabel", {
	Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -18, 0, 15), BackgroundTransparency = 1, Font = STYLE.Font,
	TextSize = 12, TextColor3 = STYLE.Dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})

local cards = {}
local function card(order, key, name, desc, id)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = STYLE.Panel, BackgroundTransparency = 0.25,
		BorderSizePixel = 0, LayoutOrder = order, Parent = abilityPanel,
	}, {create("UIStroke", {Color = Color3.fromRGB(45, 10, 10), Thickness = 1})})
	local keyBox = create("TextLabel", {
		Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromRGB(16, 4, 5),
		BorderSizePixel = 0, Font = STYLE.Font, Text = key, TextSize = #key > 1 and 11 or 18, TextColor3 = STYLE.Ink, Rotation = -3,
		ClipsDescendants = true, Parent = frame,
	})
	local keyStroke = create("UIStroke", {Color = STYLE.Blood, Thickness = 1.5, Parent = keyBox})
	-- cooldown: a dark curtain over the key that drains away
	local curtain = create("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 2, Parent = keyBox,
	})
	local title = create("TextLabel", {
		Position = UDim2.fromOffset(46, 5), Size = UDim2.new(1, -52, 0, 18), BackgroundTransparency = 1, Font = STYLE.Font,
		Text = name, TextSize = 15, TextColor3 = STYLE.Ink, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame,
	})
	local sub = create("TextLabel", {
		Position = UDim2.fromOffset(46, 23), Size = UDim2.new(1, -52, 0, 15), BackgroundTransparency = 1, Font = STYLE.Font,
		Text = desc, TextSize = 12, TextColor3 = STYLE.Dim, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame,
	})
	local status = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(60, 16),
		BackgroundTransparency = 1, Font = STYLE.Font, Text = "", TextSize = 12, TextColor3 = STYLE.Ready,
		TextXAlignment = Enum.TextXAlignment.Right, Parent = frame,
	})
	local c = {frame = frame, keyBox = keyBox, keyStroke = keyStroke, curtain = curtain, title = title, sub = sub, status = status}
	cards[id or key] = c
	return c
end
card(1, "F", "HIT", "shove whoever is in front")
card(2, "C", "LAY DOWN", "hold - lie down and crawl")
card(3, "E", "EAT", "hold next to remains")
card(4, "R", "GRAB", "tentacles drag a survivor in")
-- the bag and whatever is in the hand (InventoryUI / WeaponClient do the work)
card(5, "Q", "BAG", "hold - point at an item, let go", "bag")
card(6, "LMB", "USE", "", "use")
card(7, "RMB", "AIM", "hold - tighter spread, slow walk", "aim")
card(8, "R", "RELOAD", "shells from your bag", "reload")
card(9, "H", "PUT AWAY", "G - drop it for someone else", "away")
local USE_TEXT = {
	gun = {"FIRE", "white dot - aim point"},
	melee = {"SWING", "aim for the head, or a limb"},
	heal = {"TREAT", "hold to treat - release to pause"},
	light = {"LIGHT IT", "a flare burns for a minute"},
	trap = {"SET IT", "on the floor, at your feet"},
}

local function setCard(c, visible, ready, left, total, locked, lockText)
	c.frame.Visible = visible
	if not visible then return end
	local frac = (left > 0 and total > 0) and math.clamp(left / total, 0, 1) or 0
	c.curtain.Size = UDim2.fromScale(1, locked and 1 or frac)
	if locked then
		c.status.Text = lockText or "locked"
		c.status.TextColor3 = STYLE.Faint
		c.title.TextColor3 = STYLE.Faint
		c.keyStroke.Color = Color3.fromRGB(50, 14, 14)
	elseif left > 0 then
		c.status.Text = string.format("%.1fs", left)
		c.status.TextColor3 = STYLE.Dim
		c.title.TextColor3 = STYLE.Dim
		c.keyStroke.Color = Color3.fromRGB(70, 18, 18)
	else
		c.status.Text = ready and "ready" or ""
		c.status.TextColor3 = STYLE.Ready
		c.title.TextColor3 = STYLE.Ink
		c.keyStroke.Color = STYLE.Blood
	end
end

if not TOUCH then
	register({
		id = "abilities", name = "ABILITIES", frame = abilityPanel, scalable = true,
		defaultPos = function()
			local size = gui.AbsoluteSize
			return UDim2.fromOffset(size.X - 246 - 18, size.Y - abilityPanel.AbsoluteSize.Y - 18)
		end,
		setAlpha = function(a) abilityPanel:SetAttribute("GS_Alpha", a) end,
	})
end

-- ===== touch buttons =====
local buttons = {}
local function jumpRect()
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump.AbsoluteSize.X > 0 then
		return jump.AbsolutePosition, jump.AbsoluteSize
	end
	-- the standard spot when the jump button isn't built yet
	local size = gui.AbsoluteSize
	local s = math.min(size.X, size.Y) > 500 and 120 or 70
	return gui.AbsolutePosition + Vector2.new(size.X - s - (s == 120 and 95 or 25), size.Y - s - (s == 120 and 90 or 20)), Vector2.new(s, s)
end

local function overlaps(p1, s1, p2, s2, pad)
	pad = pad or 0
	return p1.X < p2.X + s2.X + pad and p2.X < p1.X + s1.X + pad and p1.Y < p2.Y + s2.Y + pad and p2.Y < p1.Y + s1.Y + pad
end

-- never on top of the jump button: slide left (then up) until clear
local function keepOffJump(frame)
	local jp, js = jumpRect()
	for _ = 1, 40 do
		local p, s = frame.AbsolutePosition, frame.AbsoluteSize
		if not overlaps(p, s, jp, js, 6) then return end
		local pos = frame.Position
		frame.Position = UDim2.new(pos.X.Scale, pos.X.Offset - 12, pos.Y.Scale, pos.Y.Offset)
		if frame.AbsolutePosition.X < 8 then
			frame.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset - 12)
		end
	end
end

-- calm look: a dark glassy disc, a thin light rim, clear small lettering. Red only when pressed or switched on.
local BTN_RIM = Color3.fromRGB(236, 230, 222)
local function touchButton(id, label, size, action, primary)
	local holder = create("Frame", {
		Name = "Btn_" .. id, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = gui, Visible = false,
	})
	local b = create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 13, 13), BackgroundTransparency = 0.45,
		AutoButtonColor = false, Text = "", Parent = holder,
	}, {
		create("UICorner", {CornerRadius = UDim.new(1, 0)}),
		create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0, 0.25)}),
	})
	local ring = create("UIStroke", {Color = BTN_RIM, Thickness = primary and 1.6 or 1.2, Transparency = primary and 0.45 or 0.6, Parent = b})
	-- cooldown: a dark disc growing over the button
	local shade = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, ZIndex = 2, Parent = b,
	}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
	local text = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = STYLE.Font, Text = label,
		TextSize = math.clamp(math.floor(size * (primary and 0.22 or 0.24)), 11, 18), TextColor3 = STYLE.Ink,
		TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.65, ZIndex = 3, Parent = b,
	})
	local inner = create("UIScale", {Scale = 1, Parent = b})
	local btn = {id = id, holder = holder, button = b, ring = ring, shade = shade, text = text, alpha = 0, size = size,
		primary = primary, pressed = false, on = false}
	local function restyle()
		local a = btn.alpha
		local lit = btn.pressed or btn.on
		ring.Color = lit and STYLE.BloodBright or BTN_RIM
		ring.Transparency = math.clamp((lit and 0.05 or (primary and 0.45 or 0.6)) + a, 0, 1)
		b.BackgroundTransparency = math.clamp((btn.pressed and 0.25 or 0.45) + a * 0.55, 0, 1)
		text.TextTransparency = a
		text.TextStrokeTransparency = math.clamp(0.65 + a, 0, 1)
	end
	btn.restyle = restyle
	function btn.setOn(value)
		if btn.on ~= value then btn.on = value restyle() end
	end
	b.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if btn.editing then return end
		TweenService:Create(inner, TweenInfo.new(0.07), {Scale = 0.9}):Play()
		btn.pressed = true
		restyle()
		clientAction:Fire(action)
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		TweenService:Create(inner, TweenInfo.new(0.12, Enum.EasingStyle.Back), {Scale = 1}):Play()
		btn.pressed = false
		restyle()
	end)
	buttons[id] = btn
	register({
		id = id, name = label, frame = holder, scalable = true,
		defaultPos = function() return btn.slot or UDim2.fromOffset(-500, -500) end,
		setAlpha = function(a)
			btn.alpha = a
			restyle()
		end,
	})
	return btn
end

-- Where the buttons go: a grid left of the jump button that fills from the jump button's bottom edge UP and to the
-- LEFT, in order of importance. However many are showing, none of them can end up below the screen, and only the
-- ones you need right now take a place (so there are no gaps). A button moved in the HUD editor keeps its spot.
local TOUCH_ORDER = {"use", "hit", "aim", "reload", "crawl", "grab", "away", "bag"}
local packKey = nil
local function packTouch(force)
	local visible = {}
	for _, id in ipairs(TOUCH_ORDER) do
		local btn = buttons[id]
		if btn and btn.holder.Visible and not layout[id] then table.insert(visible, btn) end
	end
	local screen = gui.AbsoluteSize
	local key = #visible .. ":" .. screen.X .. "x" .. screen.Y
	for _, btn in ipairs(visible) do key ..= btn.id end
	if key == packKey and not force then return end
	packKey = key
	local jp, js = jumpRect()
	jp -= gui.AbsolutePosition
	local big = math.min(screen.X, screen.Y) > 500
	local cell = big and 82 or 68
	local gap = 10
	local right = jp.X - gap -- right edge of the first column
	local bottom = jp.Y + js.Y -- bottom edge of the first row: level with the bottom of the jump button
	-- cells in the order they are handed out: across two columns, then up a row, then a third column
	local cells = {}
	for row = 0, 5 do
		for col = 0, 1 do table.insert(cells, {col, row}) end
	end
	for row = 0, 5 do table.insert(cells, {2, row}) end
	for i, btn in ipairs(visible) do
		local c = cells[i] or cells[#cells]
		local size = btn.size * (big and 1 or 0.86)
		local cx = right - cell * c[1] - cell / 2
		local cy = bottom - cell * c[2] - cell / 2
		local x = math.clamp(cx - size / 2, 6, screen.X - size - 6)
		local y = math.clamp(cy - size / 2, 6, screen.Y - size - 6)
		btn.slot = UDim2.fromOffset(x, y)
		btn.holder.Size = UDim2.fromOffset(size, size)
		btn.holder.Position = btn.slot
	end
end

if TOUCH then
	touchButton("use", "USE", 78, "use", true)
	touchButton("hit", "HIT", 70, "strike", true)
	touchButton("aim", "AIM", 60, "aim")
	touchButton("reload", "LOAD", 60, "reload")
	touchButton("crawl", "LAY", 58, "crawl")
	touchButton("grab", "GRAB", 62, "grab")
	touchButton("away", "AWAY", 54, "away")
	touchButton("bag", "BAG", 56, "inventory")
end

-- ===== the editor =====
local editButton = create("TextButton", {
	Name = "EditHUD", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.36, 0),
	Size = TOUCH and UDim2.fromOffset(64, 30) or UDim2.fromOffset(58, 26),
	BackgroundColor3 = STYLE.Panel, BackgroundTransparency = 0.25, AutoButtonColor = false, Font = STYLE.Font,
	Text = "HUD", TextSize = 14, TextColor3 = STYLE.Dim, Parent = gui,
}, {create("UIStroke", {Color = Color3.fromRGB(70, 12, 12), Thickness = 1})})

local editorGui = create("ScreenGui", {
	Name = "GS_HUDEditor", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false, Parent = playerGui,
})
create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Parent = editorGui})
create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(460, 50),
	BackgroundTransparency = 1, Font = STYLE.Font, TextSize = 16, TextColor3 = STYLE.Dim, TextWrapped = true,
	Text = "drag anything with a red frame - tap it to pick it, then change size and opacity below", Parent = editorGui,
})

local toolbar = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(560, 88),
	BackgroundColor3 = STYLE.Panel, BackgroundTransparency = 0.05, BorderSizePixel = 0, Parent = editorGui,
}, {create("UIStroke", {Color = STYLE.Blood, Thickness = 1.5})})
local selectedLabel = create("TextLabel", {
	Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 20), BackgroundTransparency = 1, Font = STYLE.Font,
	TextSize = 16, TextColor3 = STYLE.BloodBright, TextXAlignment = Enum.TextXAlignment.Left, Text = "nothing picked", Parent = toolbar,
})
local valueLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 6), Size = UDim2.fromOffset(240, 20),
	BackgroundTransparency = 1, Font = STYLE.Font, TextSize = 13, TextColor3 = STYLE.Dim,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = toolbar,
})
local function toolButton(text, x, w, y, callback, accent)
	local b = create("TextButton", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 30), BackgroundColor3 = Color3.fromRGB(18, 10, 10),
		AutoButtonColor = true, Font = STYLE.Font, Text = text, TextSize = 14,
		TextColor3 = accent and STYLE.BloodBright or STYLE.Ink, Parent = toolbar,
	}, {create("UIStroke", {Color = accent and STYLE.Blood or Color3.fromRGB(60, 16, 16), Thickness = 1})})
	b.Activated:Connect(callback)
	return b
end

local selected = nil
local handles = {}
local handleConnections = {}
local dirty = false

local function entryFor(m)
	local e = layout[m.id]
	if not e then
		local x, y = relativeTo(m.frame.Parent, m.frame.AbsolutePosition)
		e = {x = x, y = y, s = 1, a = 0}
		layout[m.id] = e
	end
	return e
end

local function refreshValues()
	if not selected then
		selectedLabel.Text = "nothing picked"
		valueLabel.Text = ""
		return
	end
	local e = layout[selected.id]
	selectedLabel.Text = selected.name
	valueLabel.Text = string.format("size %d%%   opacity %d%%", math.floor((e and e.s or 1) * 100 + 0.5),
		math.floor((1 - (e and e.a or 0)) * 100 + 0.5))
end

local function nudge(field, delta, lo, hi)
	if not selected then return end
	local e = entryFor(selected)
	e[field] = math.clamp(math.floor((e[field] + delta) * 100 + 0.5) / 100, lo, hi)
	applyEntry(selected)
	dirty = true
	refreshValues()
end

toolButton("SIZE -", 14, 76, 32, function() nudge("s", -0.1, 0.5, 2) end)
toolButton("SIZE +", 94, 76, 32, function() nudge("s", 0.1, 0.5, 2) end)
toolButton("OPACITY -", 180, 96, 32, function() nudge("a", 0.1, 0, 0.9) end)
toolButton("OPACITY +", 280, 96, 32, function() nudge("a", -0.1, 0, 0.9) end)
toolButton("RESET", 440, 106, 66, function()
	if not selected then return end
	layout[selected.id] = nil
	applyEntry(selected)
	dirty = true
	refreshValues()
end)

local function saveLayout()
	if not dirty or not prefsRemote then return end
	dirty = false
	task.spawn(function() pcall(function() prefsRemote:InvokeServer("setLayout", DEVICE, layout) end) end)
end

local function closeEditor()
	editorGui.Enabled = false
	for _, h in pairs(handles) do h:Destroy() end
	table.clear(handles)
	for _, conn in ipairs(handleConnections) do conn:Disconnect() end
	table.clear(handleConnections)
	for _, btn in pairs(buttons) do btn.editing = false end
	selected = nil
	saveLayout()
end

toolButton("RESET ALL", 14, 110, 66, function()
	table.clear(layout)
	for _, m in ipairs(movables) do applyEntry(m) end
	dirty = true
	selected = nil
	refreshValues()
end)
toolButton("DONE", 440, 106, 32, closeEditor, true)
toolbar.Size = UDim2.fromOffset(560, 100)

local function makeHandle(m)
	local h = create("TextButton", {
		BackgroundColor3 = STYLE.Blood, BackgroundTransparency = 0.8, AutoButtonColor = false, Text = "", ZIndex = 5,
		Parent = editorGui,
	}, {create("UIStroke", {Color = STYLE.BloodBright, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
	create("TextLabel", {
		Position = UDim2.new(0, 0, 0, -16), Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = STYLE.Font,
		Text = m.name, TextSize = 12, TextColor3 = STYLE.Ink, TextStrokeTransparency = 0.3, ZIndex = 6, Parent = h,
	})
	local dragging, startInput, startPos
	h.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		selected = m
		refreshValues()
		dragging = input
		startInput = Vector2.new(input.Position.X, input.Position.Y)
		startPos = m.frame.AbsolutePosition
	end)
	table.insert(handleConnections, UserInputService.InputChanged:Connect(function(input)
		if not dragging or not editorGui.Enabled then return end
		if input ~= dragging and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local now = Vector2.new(input.Position.X, input.Position.Y)
		local p = startPos + (now - startInput)
		-- kept on screen
		local screenPos, screen = gui.AbsolutePosition, gui.AbsoluteSize
		local s = m.frame.AbsoluteSize
		p = Vector2.new(math.clamp(p.X, screenPos.X, screenPos.X + screen.X - s.X), math.clamp(p.Y, screenPos.Y, screenPos.Y + screen.Y - s.Y))
		local e = entryFor(m)
		-- positions are kept as a fraction of the container, so they fit any screen size
		e.x, e.y = relativeTo(m.frame.Parent, p)
		applyEntry(m)
		dirty = true
	end))
	table.insert(handleConnections, UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
			if buttons[m.id] then
				keepOffJump(m.frame)
				-- store where it ended up after being pushed off the jump button
				local e = entryFor(m)
				e.x, e.y = relativeTo(m.frame.Parent, m.frame.AbsolutePosition)
			end
		end
	end))
	handles[m] = h
	return h
end

local function openEditor()
	if editorGui.Enabled then return end
	editorGui.Enabled = true
	for _, btn in pairs(buttons) do btn.editing = true end
	for _, m in ipairs(movables) do
		if m.frame.Parent then makeHandle(m) end
	end
	selected = nil
	refreshValues()
end
editButton.Activated:Connect(function()
	if editorGui.Enabled then closeEditor() else openEditor() end
end)

-- the vitals and body panels from the HealthBar script join the editor once they exist
task.spawn(function()
	local healthGui = playerGui:WaitForChild("HorrorHealthUI", 30)
	if not healthGui then return end
	for _, name in ipairs({"HealthPanel", "BodyStatus"}) do
		local frame = healthGui:WaitForChild(name, 10)
		if frame then
			register({id = name == "HealthPanel" and "vitals" or "body", name = frame:GetAttribute("GS_Movable") or name,
				frame = frame, scalable = true, external = true})
		end
	end
end)

-- the money panel (MoneyHUD script) too
task.spawn(function()
	local moneyGui = playerGui:WaitForChild("GS_MoneyHUD", 30)
	local frame = moneyGui and moneyGui:WaitForChild("Money", 10)
	if frame then
		register({id = "cash", name = "CASH", frame = frame, scalable = true, external = true})
	end
end)

-- load the saved layout for this kind of device
task.spawn(function()
	if not prefsRemote then return end
	local ok, data = pcall(function() return prefsRemote:InvokeServer("get") end)
	if ok and typeof(data) == "table" and typeof(data.layout) == "table" and typeof(data.layout[DEVICE]) == "table" then
		layout = data.layout[DEVICE]
		for _, m in ipairs(movables) do applyEntry(m) end
	end
end)

-- ===== every frame: what is shown, cooldowns, keep handles on their elements =====
local ROMAN = {"I", "II", "III"}
local NEXT = {3, 5}
RunService.RenderStepped:Connect(function()
	local playing = alive() and not inMenu()
	local inf = infected()
	local st = inf and stage() or 0
	local c = character()

	editButton.Visible = playing or editorGui.Enabled

	-- keyboard panel
	if not TOUCH then
		abilityPanel.Visible = playing
		if not layout.abilities then
			-- default: bottom-right corner, growing upward as cards appear
			local size = gui.AbsoluteSize
			abilityPanel.Position = UDim2.fromOffset(size.X - 246 - 18, size.Y - abilityPanel.AbsoluteSize.Y - 18)
		end
		header.Visible = inf
		if inf then
			local kills = player:GetAttribute("InfectKills") or 0
			local nextAt = NEXT[st]
			local prev = st == 1 and 0 or NEXT[st - 1]
			stageText.Text = nextAt and string.format("STAGE %s  -  %d / %d kills", ROMAN[st], kills, nextAt)
				or string.format("STAGE %s  -  %d kills", ROMAN[st], kills)
			stageBar.Size = UDim2.fromScale(nextAt and math.clamp((kills - prev) / (nextAt - prev), 0, 1) or 1, 1)
			local link = c and c:GetAttribute("GS_Boss")
			local dist = c and c:GetAttribute("GS_BossDist") or -1
			if link == "near" then
				motherText.Text = string.format("the Mother is %d m away", dist)
				motherText.TextColor3 = STYLE.Dim
			elseif link == "far" then
				motherText.Text = string.format("too far from the Mother (%d m) - weakened", dist)
				motherText.TextColor3 = STYLE.BloodBright
			else
				motherText.Text = "no Mother - weakened until one appears"
				motherText.TextColor3 = STYLE.BloodBright
			end
		end
		local strike = strikeLeft()
		setCard(cards.F, true, true, strike, strikeCooldown())
		cards.F.sub.Text = inf and "claw a survivor - long reach" or "shove whoever is in front"
		setCard(cards.C, not inf, false, 0, 1)
		setCard(cards.E, inf, false, 0, 1)
		local grab = grabLeft()
		setCard(cards.R, inf, true, grab, 7, st < 3, "stage III")
		local heldKind = player:GetAttribute("GS_HeldKind")
		local useText = USE_TEXT[heldKind or ""]
		setCard(cards.bag, not inf, false, 0, 1)
		setCard(cards.use, not inf and useText ~= nil, false, 0, 1)
		if useText then
			cards.use.title.Text = useText[1]
			cards.use.sub.Text = useText[2]
		end
		setCard(cards.aim, not inf and heldKind == "gun", false, 0, 1)
		setCard(cards.reload, not inf and heldKind == "gun", false, 0, 1)
		setCard(cards.away, not inf and heldKind ~= nil, false, 0, 1)
		-- fade (editor opacity)
		local a = abilityPanel:GetAttribute("GS_Alpha") or 0
		for _, cardData in pairs(cards) do
			cardData.frame.BackgroundTransparency = 0.25 + a * 0.75
			cardData.title.TextTransparency = a
			cardData.sub.TextTransparency = a
			cardData.status.TextTransparency = a
			cardData.keyBox.TextTransparency = a
			cardData.keyBox.BackgroundTransparency = a
		end
		header.BackgroundTransparency = 0.2 + a * 0.8
		stageText.TextTransparency = a
		motherText.TextTransparency = a
	end

	-- touch buttons
	local heldKind = player:GetAttribute("GS_HeldKind")
	for id, btn in pairs(buttons) do
		local wanted = true
		if id == "grab" then wanted = inf and st >= 3
		elseif id == "bag" then wanted = not inf
		elseif id == "use" then wanted = not inf and USE_TEXT[heldKind or ""] ~= nil
		elseif id == "aim" or id == "reload" then wanted = not inf and heldKind == "gun"
		elseif id == "away" then wanted = not inf and heldKind ~= nil end
		local show = (playing or editorGui.Enabled) and (wanted or editorGui.Enabled)
		btn.holder.Visible = show
		if id == "use" then
			local label = USE_TEXT[heldKind or ""]
			btn.text.Text = label and (label[1] == "LIGHT IT" and "LIGHT" or label[1] == "SET IT" and "SET" or label[1]) or "USE"
		elseif id == "aim" then
			btn.setOn(c and c:GetAttribute("GS_Aim") == true)
		end
		local left, total = 0, 1
		if id == "hit" then left, total = strikeLeft(), strikeCooldown()
		elseif id == "grab" then left, total = grabLeft(), 7 end
		local f = left > 0 and math.clamp(left / total, 0, 1) or 0
		btn.shade.Size = UDim2.fromScale(f, f)
		if id == "crawl" then
			btn.setOn(c ~= nil and (c:GetAttribute("GS_Crouch") or c:GetAttribute("GS_Prone")) == true)
		end
	end
	if TOUCH then packTouch(false) end

	-- editor handles follow their element
	if editorGui.Enabled then
		for m, h in pairs(handles) do
			local p, s = m.frame.AbsolutePosition - editorGui.AbsolutePosition, m.frame.AbsoluteSize
			h.Position = UDim2.fromOffset(p.X - 3, p.Y - 3)
			h.Size = UDim2.fromOffset(s.X + 6, s.Y + 6)
			h.Visible = m.frame.Visible or buttons[m.id] ~= nil or m.id == "abilities"
			h.BackgroundTransparency = selected == m and 0.6 or 0.85
		end
	end
end)

-- make sure buttons are off the jump button once it has been built (and after the screen turns)
if TOUCH then
	task.delay(2, function()
		-- the jump button exists by now: lay the buttons out around it again
		packTouch(true)
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		for _, m in ipairs(movables) do applyEntry(m) end
		packTouch(true)
	end)
end
]=]},
	{name = "CustomVFX", class = "ModuleScript", where = "Modules", source = [=[
-- Authored curved ribbons, ballistic sparks and vapor: no Fire, Smoke, stock particle textures or emitters.
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local templates=RS:WaitForChild("GS_AssetPreviews"):WaitForChild("Effects")
local settings=require(script.Parent:WaitForChild("GameSettings"))
local VFX={}
local folder=workspace:FindFirstChild("GS_FX") or Instance.new("Folder")
folder.Name="GS_FX" folder.Parent=workspace
local transient={}
local fires={}
local rng=Random.new()
local function anchor(position)
 local p=templates:WaitForChild("FXAnchor"):Clone() p.Position=position or Vector3.zero p.Parent=folder return p
end
local function ribbon(parent,name,a,b,width,color)
 local first=Instance.new("Attachment") first.Position=a first.Parent=parent
 local last=Instance.new("Attachment") last.Position=b last.Parent=parent
 local beam=templates:WaitForChild(name):Clone()
 beam.Attachment0=first beam.Attachment1=last beam.Width0=width beam.Color=ColorSequence.new(color)
 beam.Parent=parent
 return {beam=beam,a=first,b=last}
end
local function add(entry)
 while #transient>140 do local old=table.remove(transient,1) old.part:Destroy() end
 table.insert(transient,entry)
end
function VFX.Smoke(position,direction,scale,color)
 scale=scale or 1
 local count=settings.Get("LowGraphics") and 1 or 3
 for i=1,count do
  local p=anchor(position)
  local r=ribbon(p,"SmokeRibbon",Vector3.zero,Vector3.new(.05,.3,0)*scale,.12*scale,color or Color3.fromRGB(94,88,82))
  r.beam.Width1=.35*scale r.beam.CurveSize0=.15*scale r.beam.CurveSize1=-.22*scale
  add({part=p,r=r,kind="smoke",age=0,life=rng:NextNumber(.5,.95),velocity=(direction or Vector3.yAxis)*rng:NextNumber(.4,1.2)+Vector3.new(rng:NextNumber(-.3,.3),.6,rng:NextNumber(-.3,.3)),scale=scale,phase=rng:NextNumber(0,6)})
 end
end
function VFX.Sparks(position,normal,color,count)
 count=math.min(count or 7,settings.Get("LowGraphics") and 4 or 12)
 for _=1,count do
  local p=anchor(position)
  local dir=(normal or Vector3.yAxis)+Vector3.new(rng:NextNumber(-.9,.9),rng:NextNumber(-.4,.9),rng:NextNumber(-.9,.9))
  if dir.Magnitude<.01 then dir=Vector3.yAxis end
  local r=ribbon(p,"SparkRibbon",Vector3.zero,Vector3.zero,.016,color or Color3.fromRGB(241,168,79))
  add({part=p,r=r,kind="spark",velocity=dir.Unit*rng:NextNumber(5,14),age=0,life=rng:NextNumber(.12,.32),position=position})
 end
end
function VFX.Impact(position,normal,color,sparks)
 if sparks then VFX.Sparks(position,normal,color,7) end
 VFX.Smoke(position,normal,.6,color)
end
function VFX.Muzzle(position,look)
 local p=anchor(position)
 local cf=CFrame.lookAt(position,position+look)
 p.CFrame=cf
 for i=1,4 do
  local angle=i*math.pi*.5
  local tip=Vector3.new(math.cos(angle)*.055,math.sin(angle)*.055,-rng:NextNumber(.38,.8))
  local r=ribbon(p,"FlameRibbon",Vector3.zero,tip,.07,Color3.fromRGB(255,208,120))
  r.beam.Transparency=NumberSequence.new(.15,1)
 end
 local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,195,105) light.Range=10 light.Brightness=2.4 light.Parent=p
 add({part=p,kind="flash",age=0,life=.045})
 VFX.Smoke(position,look,.5)
end
-- a shotgun's muzzle blast: a star of flame out of the barrel, a hard flash of light, burning powder sparks
-- thrown forward and a thick puff of smoke that hangs for a moment
function VFX.MuzzleBlast(position,look,strength)
 strength=strength or 1
 local p=anchor(position)
 p.CFrame=CFrame.lookAt(position,position+look)
 local tongues=settings.Get("LowGraphics") and 4 or 7
 for i=1,tongues do
  local angle=i/tongues*math.pi*2+rng:NextNumber(-.2,.2)
  local spread=rng:NextNumber(.04,.12)*strength
  local tip=Vector3.new(math.cos(angle)*spread,math.sin(angle)*spread,-rng:NextNumber(.5,1.15)*strength)
  local r=ribbon(p,"FlameRibbon",Vector3.zero,tip,.11*strength,Color3.fromRGB(255,214,140))
  r.beam.Transparency=NumberSequence.new(.05,1)
  r.beam.LightEmission=1
 end
 -- the core: a short bright cone straight ahead
 local core=ribbon(p,"FlameRibbon",Vector3.zero,Vector3.new(0,0,-.55*strength),.2*strength,Color3.fromRGB(255,244,210))
 core.beam.Transparency=NumberSequence.new(0,1)
 local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,196,110) light.Range=16*strength light.Brightness=3.6 light.Shadows=true light.Parent=p
 add({part=p,kind="flash",age=0,life=.06})
 VFX.Sparks(position+look*.3,look,Color3.fromRGB(255,190,110),settings.Get("LowGraphics") and 3 or 7)
 VFX.Smoke(position+look*.4,look*.6+Vector3.yAxis*.3,.9*strength,Color3.fromRGB(150,146,140))
 VFX.Smoke(position,Vector3.yAxis,.6*strength,Color3.fromRGB(120,116,110))
end
function VFX.Ignite(target,scale,offset)
 if not target or not target.Parent then return end
 local p=anchor(target.Position)
 p.Name="GS_CustomFlame"
 local state={part=p,target=target,scale=scale or 1,offset=offset or Vector3.zero,ribbons={},age=0,nextSmoke=0}
 for i=1,(settings.Get("LowGraphics") and 4 or 8) do
  local r=ribbon(p,"FlameRibbon",Vector3.zero,Vector3.yAxis,.16*(scale or 1),Color3.fromRGB(255,132,45))
  r.beam.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,223,144)),ColorSequenceKeypoint.new(.35,Color3.fromRGB(244,119,35)),ColorSequenceKeypoint.new(1,Color3.fromRGB(140,37,14))})
  r.phase=i*2.39996 r.height=rng:NextNumber(.6,1.2) table.insert(state.ribbons,r)
 end
 local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,140,60) light.Range=math.clamp(12*state.scale,3,20) light.Brightness=1.3 light.Parent=p state.light=light
 fires[state]=true
 local handle={}
 function handle:Destroy() fires[state]=nil p:Destroy() end
 return handle
end
RunService.RenderStepped:Connect(function(dt)
 dt=math.min(dt,.1)
 for i=#transient,1,-1 do
  local e=transient[i] e.age+=dt
  if e.age>=e.life or not e.part.Parent then e.part:Destroy() table.remove(transient,i)
  elseif e.kind=="spark" then
   local old=e.position e.velocity+=Vector3.new(0,-workspace.Gravity*.45,0)*dt e.position+=e.velocity*dt
   e.part.Position=e.position
   e.r.a.Position=Vector3.zero e.r.b.Position=-e.velocity.Unit*math.min(.35,e.velocity.Magnitude*.018)
   e.r.beam.Transparency=NumberSequence.new(math.clamp(e.age/e.life,.15,1),1)
  elseif e.kind=="smoke" then
   local k=e.age/e.life e.part.Position+=e.velocity*dt
   e.r.a.Position=Vector3.new(math.sin(e.phase+e.age*3)*.07,0,0)*e.scale
   e.r.b.Position=Vector3.new(math.cos(e.phase+e.age*2)*.24,.3+k*.7,0)*e.scale
   e.r.beam.Width0=(.13+k*.35)*e.scale e.r.beam.Width1=(.35+k*.6)*e.scale
   e.r.beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,.82+k*.18),NumberSequenceKeypoint.new(1,1)})
  end
 end
 local now=os.clock()
 for state in pairs(fires) do
  if not state.target.Parent then state.part:Destroy() fires[state]=nil
  else
   state.part.CFrame=CFrame.new(state.target.CFrame:PointToWorldSpace(state.offset))
   local s=state.scale
   for i,r in ipairs(state.ribbons) do
    local t=now*4.8+r.phase local pulse=.75+.25*math.sin(t*1.7)
    local radiusX=math.min(state.target.Size.X*.5+.035,s*.6)
 local radiusZ=math.min(state.target.Size.Z*.5+.035,s*.6)
 local radial=Vector3.new(math.cos(r.phase)*radiusX,0,math.sin(r.phase)*radiusZ)

    r.a.Position=radial
    r.b.Position=radial+Vector3.new(math.sin(t)*.14,r.height*pulse,math.cos(t*.8)*.1)*s
    r.beam.Width0=(.23+.07*math.sin(t+.5))*s
    r.beam.CurveSize0=math.sin(t*.9)*.3*s r.beam.CurveSize1=math.cos(t)*.2*s
    r.beam.Transparency=NumberSequence.new(.22+.12*math.sin(t),1)
   end
   state.light.Brightness=.9+.45*math.noise(now*12,2)
   if now>state.nextSmoke and s>.4 then
    state.nextSmoke=now+.25
    VFX.Smoke(state.part.Position+Vector3.yAxis*s,Vector3.yAxis,s*.45,Color3.fromRGB(66,62,58))
   end
  end
 end
end)
local emitters={}
function VFX.Emitter(parent,kind,props)
 local e={Parent=parent,Rate=0,Enabled=true,kind=kind or "smoke",acc=0}
 for k,value in pairs(props or {}) do e[k]=value end
 function e:Emit(count)
  local p=self.Parent if not p or not p.Parent or self.Enabled==false then return end
  local position=p:IsA("Attachment") and p.WorldPosition or p.Position
  local color=self.Color and self.Color.Keypoints[1].Value or Color3.fromRGB(134,128,120)
  if self.kind=="spark" then VFX.Sparks(position,Vector3.yAxis,color,math.min(count,8))
  else
   local scale=self.Size and math.clamp(self.Size.Keypoints[#self.Size.Keypoints].Value*.4,.3,3) or 1
   if p:IsA("BasePart") and p.Size.X>5 then position+=Vector3.new(rng:NextNumber(-p.Size.X/2,p.Size.X/2),0,rng:NextNumber(-p.Size.Z/2,p.Size.Z/2)) end
   VFX.Smoke(position,Vector3.yAxis,scale,color)
  end
 end
 function e:Destroy() self.destroyed=true end
 table.insert(emitters,e)
 return e
end
RunService.Heartbeat:Connect(function(dt)
 for i=#emitters,1,-1 do
  local e=emitters[i]
  if e.destroyed or (e.Parent and not e.Parent.Parent) then table.remove(emitters,i)
  elseif e.Parent and e.Enabled~=false then
   e.acc+=dt*math.min(e.Rate or 0,4)
   if e.acc>=1 then e.acc=0 e:Emit(1) end
  end
 end
end)
return VFX

]=]},
	{name = "HorrorLighting", class = "Script", where = "ServerScriptService", source = [=[
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
]=]},
	{name = "MoneyHUD", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- Your money on screen (top right). A dark tag that fades out to the right, a round brass badge with the $ in it,
-- and the number next to it. When it changes the number rolls to the new value, the badge turns over like a
-- flipped coin, a soft glow pulses behind it and a "+$100" / "-$40" drifts away (gold for money in, red for out).
-- The HUD editor (Controls) can move and resize it like the other panels ("CASH").
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSettings = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameSettings"))

local player = Players.LocalPlayer
local FONT = Enum.Font.SpecialElite
local GOLD = Color3.fromRGB(226, 172, 74)
local GOLD_DARK = Color3.fromRGB(96, 64, 18)
local INK = Color3.fromRGB(238, 233, 226)
local RED = Color3.fromRGB(225, 52, 44)
local W, H = 196, 46

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

-- 1234567 -> "1,234,567"
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local gui = create("ScreenGui", {
	Name = "GS_MoneyHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 41,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui"),
})
local panel = create("Frame", {
	Name = "Money", Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false, Parent = gui,
})
panel:SetAttribute("GS_Movable", "CASH")

-- the tag: solid behind the badge, fading out towards the right edge
local tag = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, H / 2, 0.5, 0), Size = UDim2.new(1, -H / 2, 0, H - 12),
	BackgroundColor3 = Color3.fromRGB(8, 7, 7), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = panel,
}, {
	create("UICorner", {CornerRadius = UDim.new(0, 6)}),
	create("UIGradient", {Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.25), NumberSequenceKeypoint.new(1, 1),
	})}),
})
-- a hairline of brass along the bottom of the tag
local underline = create("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, H / 2, 0.5, (H - 12) / 2), Size = UDim2.new(1, -H / 2 - 10, 0, 1),
	BackgroundColor3 = GOLD, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = panel,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
})})})

-- glow behind the badge (pulses on a change)
local glow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(H / 2, H / 2), Size = UDim2.fromOffset(H, H),
	BackgroundColor3 = GOLD, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = panel,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})

-- the badge: a round brass coin with a raised rim and the $ struck into it
local badge = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(H / 2, H / 2), Size = UDim2.fromOffset(H - 8, H - 8),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = panel,
}, {
	create("UICorner", {CornerRadius = UDim.new(1, 0)}),
	create("UIGradient", {Rotation = 55, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(246, 208, 120)), ColorSequenceKeypoint.new(0.45, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_DARK),
	})}),
	create("UIStroke", {Color = Color3.fromRGB(58, 38, 10), Thickness = 1.5}),
})
local badgeScale = create("UIScale", {Parent = badge})
create("Frame", { -- the inner ring of the rim
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -7, 1, -7),
	BackgroundTransparency = 1, ZIndex = 3, Parent = badge,
}, {
	create("UICorner", {CornerRadius = UDim.new(1, 0)}),
	create("UIStroke", {Color = Color3.fromRGB(120, 82, 24), Thickness = 1, Transparency = 0.2}),
})
local dollar = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 1), Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1, Font = FONT, Text = "$", TextSize = 24, TextColor3 = Color3.fromRGB(64, 40, 8),
	TextStrokeColor3 = Color3.fromRGB(255, 230, 170), TextStrokeTransparency = 0.75, ZIndex = 4, Parent = badge,
})

local amount = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, H + 6, 0.5, 0), Size = UDim2.new(1, -H - 14, 0, 26),
	BackgroundTransparency = 1, Font = FONT, Text = "0", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = INK, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.6,
	TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = panel,
})

-- where it sits: top right under the top bar, unless the HUD editor moved it
local function defaultPosition()
	local inset = GuiService:GetGuiInset().Y
	return UDim2.new(1, -W - 14, 0, inset + 10)
end
local function place()
	local pos = panel:GetAttribute("GS_LayoutPos")
	panel.Position = typeof(pos) == "UDim2" and pos or defaultPosition()
end
panel:GetAttributeChangedSignal("GS_LayoutPos"):Connect(place)
place()

-- ===== the number and its animations =====
local shown = player:GetAttribute("Cash") or 0
local value = create("NumberValue", {Value = shown})
amount.Text = commas(shown)
value.Changed:Connect(function(v) amount.Text = commas(v) end)

local coinSound = create("Sound", {
	SoundId = "rbxassetid://9113849583", Volume = 0.3, PlaybackSpeed = 1.15, Parent = gui,
})
pcall(function() coinSound.SoundGroup = GameSettings.GetGroup("SFX") end)

local function popup(delta)
	local gain = delta > 0
	local label = create("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, H + 6, 0.5, 0), Size = UDim2.fromOffset(140, 22),
		BackgroundTransparency = 1, Font = FONT, Text = (gain and "+$" or "-$") .. commas(math.abs(delta)), TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = gain and GOLD or RED, TextStrokeTransparency = 0.5,
		TextTransparency = 1, ZIndex = 5, Parent = panel,
	})
	tween(label, 0.15, {TextTransparency = 0})
	tween(label, 1.1, {Position = UDim2.new(0, H + 6, 0.5, gain and 34 or 30)}, Enum.EasingStyle.Quart)
	task.delay(0.55, function() tween(label, 0.55, {TextTransparency = 1, TextStrokeTransparency = 1}) end)
	task.delay(1.15, function() label:Destroy() end)
end

local flipToken = 0
local function flip(gain)
	-- the coin turns over: squash to an edge, swap faces, open again
	flipToken += 1
	local my = flipToken
	local size = badge.Size
	tween(badge, 0.11, {Size = UDim2.fromOffset(2, size.Y.Offset)}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	task.delay(0.11, function()
		if my ~= flipToken then return end
		dollar.TextColor3 = gain and Color3.fromRGB(64, 40, 8) or Color3.fromRGB(90, 16, 12)
		tween(badge, 0.16, {Size = UDim2.fromOffset(H - 8, H - 8)}, Enum.EasingStyle.Back)
		task.delay(0.6, function() if my == flipToken then tween(dollar, 0.4, {TextColor3 = Color3.fromRGB(64, 40, 8)}) end end)
	end)
	badgeScale.Scale = gain and 1.18 or 0.9
	tween(badgeScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
	glow.BackgroundColor3 = gain and GOLD or RED
	glow.Size = UDim2.fromOffset(H - 6, H - 6)
	glow.BackgroundTransparency = 0.55
	tween(glow, 0.6, {Size = UDim2.fromOffset(H + 18, H + 18), BackgroundTransparency = 1})
end

local function changed()
	local new = player:GetAttribute("Cash") or 0
	local delta = new - shown
	shown = new
	if delta == 0 then return end
	local gain = delta > 0
	tween(value, math.clamp(0.35 + math.log10(math.abs(delta) + 1) * 0.2, 0.35, 1.2), {Value = new})
	if panel.Visible then
		popup(delta)
		flip(gain)
		amount.TextColor3 = gain and GOLD or RED
		underline.BackgroundTransparency = 0
		task.delay(0.2, function()
			tween(amount, 0.8, {TextColor3 = INK})
			tween(underline, 0.8, {BackgroundTransparency = 0.35})
		end)
		coinSound.PlaybackSpeed = gain and 1.15 or 0.8
		coinSound:Play()
	end
end
player:GetAttributeChangedSignal("Cash"):Connect(changed)

-- only in the game itself (not in the menu), and it slides in the first time it appears
RunService.RenderStepped:Connect(function()
	local want = player:GetAttribute("InMenu") ~= true and player:GetAttribute("Cash") ~= nil
	if want and not panel.Visible then
		panel.Visible = true
		place()
		local target = panel.Position
		panel.Position = target + UDim2.fromOffset(24, 0)
		tag.BackgroundTransparency = 1
		tween(panel, 0.45, {Position = target}, Enum.EasingStyle.Quart)
		tween(tag, 0.45, {BackgroundTransparency = 0.2})
	elseif not want and panel.Visible then
		panel.Visible = false
	end
end)
]=]},
	{name = "Spitter", class = "Script", where = "ServerScriptService", source = [=[
-- C-310 "The Spitter": a hunched green thing with acid sacs in its throat. It keeps its distance and spits.
--   * the spit flies in an arc (every client draws it from the same start, speed and gravity)
--   * a direct hit burns hard, and the fumes keep poisoning you for a few seconds
--   * a gas mask (or the SCG helmet) stops the poisoning and softens the burn: it's the breathing that kills
--   * where it lands a puddle of acid hisses for a while
-- Spawned from the admin panel like any other object (Monsters hands it over through GS_SpitterControl).
-- Health, limbs and death: MonsterHealth (id C-310).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local ID = "C-310"
local SPIT_SPEED = 85
local SPIT_GRAVITY = 40
local SPIT_COOLDOWN = {3, 4.5}
local SPIT_DAMAGE = 20
local POISON_DPS, POISON_TIME = 3, 6
local PUDDLE_TIME, PUDDLE_RADIUS, PUDDLE_DPS = 7, 3.2, 5
local KEEP_MIN, KEEP_MAX = 16, 34
local SIGHT = 110
local CLAW_DAMAGE = 11

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local control = ensure(ServerStorage, "BindableFunction", "GS_SpitterControl")
local fxRemote = ensure(ReplicatedStorage, "RemoteEvent", "GS_MonsterHit")
local folder = ensure(workspace, "Folder", "Monsters")

local rng = Random.new()
local function serverNow() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function itemService()
	local ok, svc = pcall(function() return require(ServerStorage:FindFirstChild("GS_ItemService")) end)
	return ok and svc or nil
end

-- ===== the body =====
local GREEN, DARK, SAC = Color3.fromRGB(88, 128, 52), Color3.fromRGB(50, 74, 30), Color3.fromRGB(190, 230, 60)

local function blob(model, part, cf, size, color, material, transparency)
	local b = Instance.new("Part")
	b.Name = "GS_Blob"
	b.Size = size
	b.Color = color
	b.Material = material or Enum.Material.SmoothPlastic
	b.Transparency = transparency or 0
	b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow, b.Massless = false, false, false, false, true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = b
	b.CFrame = part.CFrame * cf
	local w = Instance.new("WeldConstraint")
	w.Part0 = part
	w.Part1 = b
	w.Parent = b
	b.Parent = model
	return b
end

local function build(cframe)
	local desc = Instance.new("HumanoidDescription")
	for _, key in ipairs({"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"}) do
		desc[key] = GREEN
	end
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6) end)
	if not ok or not model then return nil end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Decal") then d:Destroy() end
	end
	model.Name = ID
	local head, torso = model:FindFirstChild("Head"), model:FindFirstChild("Torso")
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.12
		end
	end
	-- a hunched back of lumps and spines
	for i = 1, 6 do
		blob(model, torso, CFrame.new(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 0.9), 0.5), Vector3.new(0.7, 0.6, 0.6) * rng:NextNumber(0.8, 1.3), DARK)
		local spine = Instance.new("WedgePart")
		spine.Name = "GS_Spine"
		spine.Size = Vector3.new(0.12, 0.5, 0.35)
		spine.Color = Color3.fromRGB(180, 170, 120)
		spine.CanCollide, spine.CanQuery, spine.CanTouch, spine.Massless = false, false, false, true
		spine.CFrame = torso.CFrame * CFrame.new(0, 0.95 - i * 0.3, 0.62) * CFrame.Angles(math.rad(-30), 0, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1, w.Parent = torso, spine, spine
		spine.Parent = model
	end
	-- the acid sacs: swollen, glowing, under the jaw and on the neck
	for _, s in ipairs({-1, 1}) do
		local sac = blob(model, head, CFrame.new(s * 0.42, -0.42, -0.2), Vector3.new(0.55, 0.6, 0.55), SAC, Enum.Material.Neon, 0.15)
		sac.Name = "GS_Sac"
		blob(model, torso, CFrame.new(s * 0.45, 0.85, -0.45), Vector3.new(0.45, 0.45, 0.45), SAC, Enum.Material.Neon, 0.2).Name = "GS_Sac"
	end
	-- a wide jaw with teeth, four small black eyes
	blob(model, head, CFrame.new(0, -0.25, -0.52), Vector3.new(0.9, 0.35, 0.3), Color3.fromRGB(20, 26, 8))
	for i = -3, 3 do
		blob(model, head, CFrame.new(i * 0.1, -0.13, -0.63), Vector3.new(0.05, 0.12, 0.05), Color3.fromRGB(226, 220, 170))
	end
	for _, e in ipairs({{-0.22, 0.2}, {0.22, 0.2}, {-0.34, 0.05}, {0.34, 0.05}}) do
		blob(model, head, CFrame.new(e[1], e[2], -0.55), Vector3.new(0.14, 0.14, 0.1), Color3.fromRGB(8, 8, 6))
	end
	local glow = Instance.new("PointLight")
	glow.Color = SAC
	glow.Range = 7
	glow.Brightness = 0.6
	glow.Parent = head
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth, humanoid.Health = 1e6, 1e6
	humanoid.WalkSpeed = 12
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model:SetAttribute("MonsterId", ID)
	model:SetAttribute("DangerClass", "C")
	model:PivotTo(cframe)
	-- turning is done by physics (smooth for everyone) instead of snapping the body around
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		local att = Instance.new("Attachment")
		att.Name = "GS_FaceAttachment"
		att.Parent = root
		local align = Instance.new("AlignOrientation")
		align.Name = "GS_Face"
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = att
		align.MaxTorque = 1e6
		align.Responsiveness = 14
		align.Enabled = false
		align.Parent = root
	end
	model.Parent = folder
	pcall(function() model.HumanoidRootPart:SetNetworkOwner(nil) end)
	return model
end

-- ===== targets =====
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function alive(character)
	local h = character and character:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

local function targets()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		if alive(c) and not c:GetAttribute("Infected") then table.insert(list, c) end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	for _, npc in ipairs(npcs and npcs:GetChildren() or {}) do
		if npc:IsA("Model") and alive(npc) then table.insert(list, npc) end
	end
	return list
end

local function canSee(model, character)
	local head = model:FindFirstChild("Head")
	local th = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not head or not th then return false end
	local offset = th.Position - head.Position
	if offset.Magnitude > SIGHT then return false end
	sightParams.FilterDescendantsInstances = {folder, character}
	return workspace:Raycast(head.Position, offset, sightParams) == nil
end

-- ===== acid =====
local puddles = {}

local function poison(character, seconds)
	local h = character:FindFirstChildOfClass("Humanoid")
	if not h then return end
	local untilT = serverNow() + seconds
	if (character:GetAttribute("GS_Poison") or 0) > serverNow() then
		character:SetAttribute("GS_Poison", untilT)
		return
	end
	character:SetAttribute("GS_Poison", untilT)
	task.spawn(function()
		while character.Parent and h.Health > 0 and (character:GetAttribute("GS_Poison") or 0) > serverNow() do
			task.wait(1)
			if character:GetAttribute("GS_Filter") then break end -- put the mask on: the burning in your chest stops
			character:SetAttribute("LastDamageCause", "ACID")
			character:SetAttribute("LastDamageTime", serverNow())
			h:TakeDamage(POISON_DPS)
			if h.Health <= 0 then character:SetAttribute("DeathCause", "ACID") end
		end
		if character.Parent then character:SetAttribute("GS_Poison", nil) end
	end)
end

local function acidHit(victim, direct)
	local h = victim:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end
	local filtered = victim:GetAttribute("GS_Filter") == true
	local dmg = direct and SPIT_DAMAGE or PUDDLE_DPS
	if filtered then dmg *= direct and 0.55 or 0.5 end
	local svc = itemService()
	if svc and svc.Absorb then dmg = svc.Absorb(victim, direct and "Head" or "LeftLeg", dmg, "acid") end
	victim:SetAttribute("LastDamageCause", "ACID")
	victim:SetAttribute("LastDamageTime", serverNow())
	h:TakeDamage(dmg)
	if h.Health <= 0 then victim:SetAttribute("DeathCause", "ACID") return end
	if direct then
		if not filtered then poison(victim, POISON_TIME) end
		local plr = Players:GetPlayerFromCharacter(victim)
		if plr then fxRemote:FireClient(plr, "acidscreen", victim, filtered) end
	end
end

local function spit(model, target)
	local head = model:FindFirstChild("Head")
	local troot = target:FindFirstChild("HumanoidRootPart")
	if not head or not troot then return end
	local origin = head.Position + head.CFrame.LookVector * 0.8 - Vector3.new(0, 0.3, 0)
	-- aim where they will be, then lift the shot for the drop
	local aimAt = troot.Position + Vector3.new(0, 0.8, 0)
	local dist = (aimAt - origin).Magnitude
	local flight = dist / SPIT_SPEED
	aimAt += flat(troot.AssemblyLinearVelocity) * flight * 0.8
	aimAt += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)) * (dist / 30)
	local velocity = (aimAt - origin).Unit * SPIT_SPEED + Vector3.new(0, 0.5 * SPIT_GRAVITY * flight, 0)
	fxRemote:FireAllClients("spit", model, origin, velocity, SPIT_GRAVITY, serverNow())
	-- the server flies the same arc and decides what it hits
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {folder}
	local pos, vel = origin, velocity
	local elapsed = 0
	task.spawn(function()
		while elapsed < 3 do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			local newVel = vel - Vector3.new(0, SPIT_GRAVITY * dt, 0)
			local step = (vel + newVel) * 0.5 * dt
			local hit = workspace:Raycast(pos, step, params)
			if hit then
				local victim = hit.Instance:FindFirstAncestorOfClass("Model")
				while victim and not victim:FindFirstChildOfClass("Humanoid") do victim = victim:FindFirstAncestorOfClass("Model") end
				if victim and victim.Parent ~= folder and alive(victim) then acidHit(victim, true) end
				-- a puddle only where it hit the world: a spit that hits someone splashes over them, it doesn't
				-- leave a puddle hanging in the air where their head was
				if not victim then
					local ground = hit.Normal.Y > 0.5 and hit.Position or nil
					if not ground then
						local down = workspace:Raycast(hit.Position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
						ground = down and down.Position
					end
					if ground then
						table.insert(puddles, {pos = ground, untilT = os.clock() + PUDDLE_TIME, last = {}})
						fxRemote:FireAllClients("acidpuddle", ground, PUDDLE_TIME, PUDDLE_RADIUS)
					end
				end
				fxRemote:FireAllClients("spitsplat", hit.Position, hit.Normal, victim)
				return
			end
			pos += step
			vel = newVel
		end
	end)
end

-- puddles burn whoever stands in them
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for i = #puddles, 1, -1 do
			local p = puddles[i]
			if now > p.untilT then
				table.remove(puddles, i)
			else
				for _, c in ipairs(targets()) do
					local root = c.HumanoidRootPart
					local d = flat(root.Position - p.pos).Magnitude
					if d < PUDDLE_RADIUS and math.abs(root.Position.Y - p.pos.Y) < 4.5 and now - (p.last[c] or 0) >= 1 then
						p.last[c] = now
						acidHit(c, false)
					end
				end
			end
		end
	end
end)

-- ===== the brain =====
local function wander(model, humanoid, brain)
	if not brain.roamGoal or os.clock() > brain.roamUntil then
		local root = model.HumanoidRootPart
		local a = rng:NextNumber(0, math.pi * 2)
		brain.roamGoal = root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(12, 30)
		brain.roamUntil = os.clock() + rng:NextNumber(5, 9)
	end
	humanoid.WalkSpeed = 8
	humanoid:MoveTo(brain.roamGoal)
end

local function moveTo(model, humanoid, brain, goal, speed)
	humanoid.WalkSpeed = speed
	local root = model.HumanoidRootPart
	-- straight at it, and a path when it keeps bumping into things
	if brain.path and brain.pathIndex and os.clock() < brain.pathUntil then
		local wp = brain.path[brain.pathIndex]
		if wp then
			if flat(wp.Position - root.Position).Magnitude < 2.5 then brain.pathIndex += 1 end
			if wp.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
			humanoid:MoveTo(wp.Position)
			return
		end
	end
	humanoid:MoveTo(goal)
	local moved = brain.lastPos and (root.Position - brain.lastPos).Magnitude or 1
	brain.lastPos = root.Position
	brain.stuck = moved < 0.25 and (brain.stuck or 0) + 1 or 0
	if brain.stuck > 12 then
		brain.stuck = 0
		local path = PathfindingService:CreatePath({AgentRadius = 1.8, AgentHeight = 5, AgentCanJump = true})
		local ok = pcall(function() path:ComputeAsync(root.Position, goal) end)
		if ok and path.Status == Enum.PathStatus.Success then
			brain.path, brain.pathIndex, brain.pathUntil = path:GetWaypoints(), 2, os.clock() + 4
		else
			humanoid.Jump = true
		end
	end
end

local function run(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local brain = {nextSpit = os.clock() + 2, nextClaw = 0, lastHit = 0, mode = "hold"}
	local align = root and root:FindFirstChild("GS_Face")
	-- face a point smoothly (the body keeps looking at its prey even while it backs away)
	local function face(point)
		if not align then return end
		local look = flat(point - root.Position)
		if look.Magnitude < 0.1 then return end
		humanoid.AutoRotate = false
		align.CFrame = CFrame.lookAt(Vector3.zero, look)
		align.Enabled = true
	end
	local function freeTurn()
		humanoid.AutoRotate = true
		if align then align.Enabled = false end
	end
	while model.Parent and not model:GetAttribute("GS_Dead") do
		task.wait(0.1)
		local now = os.clock()
		if (model:GetAttribute("GS_StunUntil") or 0) > now then
			humanoid:Move(Vector3.zero)
			continue
		end
		-- pick the closest one it can see (or whoever just hurt it)
		local best, bestDist = nil, math.huge
		for _, c in ipairs(targets()) do
			local d = (c.HumanoidRootPart.Position - root.Position).Magnitude
			if d < bestDist and (canSee(model, c) or (brain.target == c and now - (brain.lastSeen or 0) < 5)) then best, bestDist = c, d end
		end
		if model:GetAttribute("GS_HitAt") and model:GetAttribute("GS_HitAt") ~= brain.lastHit then
			brain.lastHit = model:GetAttribute("GS_HitAt")
			brain.nextSpit = math.min(brain.nextSpit, now + 0.6) -- hurt it and it answers
		end
		if best then
			if best ~= brain.target or canSee(model, best) then brain.lastSeen = now end
			brain.target = best
			local troot = best.HumanoidRootPart
			local away = flat(root.Position - troot.Position)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
			if bestDist < 5 and now >= brain.nextClaw then
				-- too close: a claw
				brain.nextClaw = now + 1.2
				model:SetAttribute("GS_AttackServer", serverNow())
				task.delay(0.25, function()
					if alive(best) and (best.HumanoidRootPart.Position - root.Position).Magnitude < 6 then
						local svc = itemService()
						local dmg = CLAW_DAMAGE
						if svc and svc.Absorb then dmg = svc.Absorb(best, "Torso", dmg, "claw") end
						best:SetAttribute("LastDamageCause", "ACID")
						best:SetAttribute("LastDamageTime", serverNow())
						best:FindFirstChildOfClass("Humanoid"):TakeDamage(dmg)
					end
				end)
			else
				-- keep its distance, with some slack so it doesn't stop and start on the line every tick
				if brain.mode == "back" and bestDist > KEEP_MIN + 4 then brain.mode = "hold"
				elseif brain.mode == "close" and bestDist < KEEP_MAX - 5 then brain.mode = "hold"
				elseif brain.mode == "hold" and bestDist < KEEP_MIN then brain.mode = "back"
				elseif brain.mode == "hold" and bestDist > KEEP_MAX then brain.mode = "close" end
				if brain.mode == "back" then
					moveTo(model, humanoid, brain, root.Position + away * 10, 10)
				elseif brain.mode == "close" then
					moveTo(model, humanoid, brain, troot.Position + away * (KEEP_MIN + 6), 12)
				else
					humanoid:Move(Vector3.zero)
				end
			end
			face(troot.Position)
			if now >= brain.nextSpit and bestDist < 80 and canSee(model, best) then
				brain.nextSpit = now + rng:NextNumber(SPIT_COOLDOWN[1], SPIT_COOLDOWN[2])
				model:SetAttribute("GS_SpitAt", serverNow())
				fxRemote:FireAllClients("spitwindup", model)
				task.delay(0.55, function()
					if model.Parent and not model:GetAttribute("GS_Dead") and alive(best) then spit(model, best) end
				end)
			end
		else
			brain.target = nil
			freeTurn()
			wander(model, humanoid, brain)
		end
	end
	humanoid:Move(Vector3.zero)
end

control.OnInvoke = function(action, cframe)
	if action == "Spawn" then
		if typeof(cframe) ~= "CFrame" then return false, "no position" end
		local model = build(cframe)
		if not model then return false, "could not build the body" end
		task.spawn(run, model)
		return true, "C-310 spawned · class C (HIGH)"
	elseif action == "Stun" then
		return true
	end
	return false, "unknown"
end

]=]},
	{name = "WeaponClient", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
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
]=]},
	{name = "WeaponImpactFX", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- What guns do to the world, drawn on every client:
--   * pellet impacts: a puff of the surface's own dust, sparks and a ring off metal, a small scorched mark
--   * the flare: leaves the muzzle (not the head), a white-hot core in a red glow, a spark and smoke trail, a hiss.
--     It skips off walls, sticks burning in whatever it hits, or lies on the floor and burns like a road flare:
--     a flickering red light, a steady shower of sparks and a pink-grey plume, then it dies out.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Audio=require(RS:WaitForChild("Modules"):WaitForChild("CombatAudio"))
local VFX=require(RS.Modules:WaitForChild("CustomVFX"))
local GameSettings=require(RS.Modules:WaitForChild("GameSettings"))
local remote=RS:WaitForChild("GS_Weapon")
local folder=workspace:FindFirstChild("GS_FX") or Instance.new("Folder")
folder.Name="GS_FX" folder.Parent=workspace

local RED=Color3.fromRGB(255,62,48)
local HOT=Color3.fromRGB(255,228,210)
local SMOKE=Color3.fromRGB(176,128,126)
local rng=Random.new()
local function low() return GameSettings.Get("LowGraphics")==true end

local function anchor(pos)
 local p=Instance.new("Part") p.Name="GS_Impact" p.Size=Vector3.one*.08 p.Position=pos
 p.Transparency=1 p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.Parent=folder return p
end
local holes={}
local function dust(pos,normal,color,sparks) VFX.Impact(pos,normal,color,sparks) end

-- ===== the flare in flight =====
local flights={}
local function muzzleOf(character)
 local held=typeof(character)=="Instance" and character:FindFirstChild("GS_Held")
 local m=held and held:FindFirstChild("Muzzle",true)
 return m and m:IsA("Attachment") and m.WorldPosition or nil
end
local function makeFlare(position)
 local core=Instance.new("Part") core.Name="GS_FlareProjectile" core.Shape=Enum.PartType.Ball core.Size=Vector3.one*.34
 core.Material=Enum.Material.Neon core.Color=RED core.Anchored=true core.CanCollide=false core.CanQuery=false core.CanTouch=false
 core.CastShadow=false core.Position=position core.Parent=folder
 local heart=Instance.new("Part") heart.Name="GS_FlareHeart" heart.Shape=Enum.PartType.Ball heart.Size=Vector3.one*.17
 heart.Material=Enum.Material.Neon heart.Color=HOT heart.Anchored=true heart.CanCollide=false heart.CanQuery=false heart.CanTouch=false
 heart.CastShadow=false heart.Position=position heart.Parent=core
 local light=Instance.new("PointLight") light.Color=RED light.Range=30 light.Brightness=3.2 light.Shadows=not low() light.Parent=core
 local a0=Instance.new("Attachment") a0.Position=Vector3.new(0,.14,0) a0.Parent=core
 local a1=Instance.new("Attachment") a1.Position=Vector3.new(0,-.14,0) a1.Parent=core
 local trail=Instance.new("Trail") trail.Attachment0=a0 trail.Attachment1=a1 trail.Lifetime=.4 trail.LightEmission=1 trail.FaceCamera=true
 trail.Color=ColorSequence.new(Color3.fromRGB(255,120,90),Color3.fromRGB(120,20,16))
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=NumberSequence.new(1,.15) trail.Parent=core
 local hiss=Audio.Play("Sizzle",core,.35,1.45,70,true)
 return {core=core,heart=heart,light=light,hiss=hiss}
end
local function endFlight(f)
 if f.fx.hiss then f.fx.hiss:Destroy() end
 f.fx.core:Destroy()
end

-- ===== a flare stuck in something, burning =====
local function stuckFlare(part,position,normal)
 if typeof(part)~="Instance" or not part:IsA("BasePart") then return end
 local fx=makeFlare(position)
 local offset=part.CFrame:ToObjectSpace(CFrame.new(position))
 local t0=os.clock()
 local conn
 conn=RunService.RenderStepped:Connect(function()
  local age=os.clock()-t0
  if not part.Parent or age>5 then
   conn:Disconnect()
   if fx.hiss then fx.hiss:Destroy() end
   fx.core:Destroy()
   return
  end
  local cf=part.CFrame*offset
  fx.core.CFrame=cf fx.heart.CFrame=cf
  fx.light.Brightness=2.4+math.noise(age*14,1)*1.2
  if rng:NextNumber()<.3 then VFX.Sparks(cf.Position,Vector3.yAxis,Color3.fromRGB(255,170,120),2) end
  if rng:NextNumber()<.15 then VFX.Smoke(cf.Position,Vector3.yAxis,.5,SMOKE) end
 end)
end

remote.OnClientEvent:Connect(function(kind,a,b,c,d,e,f)
 if kind=="surface" then
  local pos,normal,material=a,b,c
  local metal=material==Enum.Material.Metal or material==Enum.Material.DiamondPlate or material==Enum.Material.CorrodedMetal
  local wood=material==Enum.Material.Wood or material==Enum.Material.WoodPlanks
  dust(pos,normal,metal and Color3.fromRGB(235,192,116) or wood and Color3.fromRGB(116,87,56) or Color3.fromRGB(141,137,126),metal)
  if metal then local p=anchor(pos) Audio.Play("MetalHit",p,.22,1.25,65) Debris:AddItem(p,1) end
  while #holes>=50 do local old=table.remove(holes,1) old:Destroy() end
  local p=anchor(pos+normal*.012) p.Name="GS_BulletMark" p.Transparency=.18 p.Color=Color3.fromRGB(23,22,20)
  p.Shape=Enum.PartType.Cylinder p.Size=Vector3.new(.012,.065,.065)
  p.CFrame=CFrame.lookAt(pos+normal*.012,pos+normal)*CFrame.Angles(0,math.pi/2,0)
  table.insert(holes,p) Debris:AddItem(p,18)
 elseif kind=="bodyimpact" then
  dust(b,c,Color3.fromRGB(100,10,9),false)
 elseif kind=="flareflight" then
  local id,origin,velocity,gravity,start,shooter=a,b,c,d,e,f
  if typeof(origin)~="Vector3" or typeof(velocity)~="Vector3" then return end
  -- drawn from the gun's muzzle, easing onto the real path over the first moment
  local muzzle=muzzleOf(shooter) or origin
  local fl={fx=makeFlare(muzzle),origin=origin,velocity=velocity,gravity=gravity or Vector3.zero,start=start,
   muzzle=muzzle,blendUntil=.12,lastSpark=0,lastSmoke=0,prev=muzzle}
  flights[id]=fl
  -- the thump and the whoosh of it leaving the barrel
  local head=typeof(shooter)=="Instance" and shooter:FindFirstChild("Head")
  if head then
   Audio.Shot("Shotgun",head,.42,1.75,220)
   Audio.Play("ShockWhoosh",head,.45,.6,120)
  end
 elseif kind=="flarebounce" then
  local fl=flights[a]
  if not fl then return end
  fl.origin,fl.velocity,fl.gravity,fl.start=b,c,d,e
  fl.blendUntil=0
  VFX.Sparks(b,(c.Magnitude>0 and c.Unit or Vector3.yAxis),Color3.fromRGB(255,170,120),8)
  local p=anchor(b) Audio.Play("MetalHit",p,.25,1.6,60) Debris:AddItem(p,1)
 elseif kind=="flarestop" then
  local fl=flights[a]
  flights[a]=nil
  if fl then endFlight(fl) end
  local pos,normal,part=b,c,d
  if typeof(pos)~="Vector3" then return end
  VFX.Sparks(pos,typeof(normal)=="Vector3" and normal or Vector3.yAxis,Color3.fromRGB(255,170,120),10)
  if typeof(part)=="Instance" then stuckFlare(part,pos,normal) end
 end
end)

RunService.RenderStepped:Connect(function()
 local now=workspace:GetServerTimeNow()
 for id,fl in pairs(flights) do
  local t=now-fl.start
  if t>7 or not fl.fx.core.Parent then endFlight(fl) flights[id]=nil
  else
   local pos=fl.origin+fl.velocity*math.max(t,0)+fl.gravity*(.5*t*t)
   if t<fl.blendUntil then pos=fl.muzzle:Lerp(pos,math.clamp(t/fl.blendUntil,0,1)) end
   local vel=pos-fl.prev
   fl.prev=pos
   local cf=vel.Magnitude>1e-3 and CFrame.lookAt(pos,pos+vel) or CFrame.new(pos)
   fl.fx.core.CFrame=cf fl.fx.heart.CFrame=cf
   fl.fx.light.Brightness=3+math.noise(now*20,3)*.8
   if now-fl.lastSpark>.05 then fl.lastSpark=now VFX.Sparks(pos,-vel.Unit,Color3.fromRGB(255,170,120),low() and 1 or 2) end
   if now-fl.lastSmoke>.06 then fl.lastSmoke=now VFX.Smoke(pos,Vector3.yAxis,.4,SMOKE) end
  end
 end
end)

-- ===== flares burning on the floor (the server's GS_FlareBurn parts) =====
local burning={}
local function watchBurn(part)
 if not part:IsA("BasePart") or part.Name~="GS_FlareBurn" or burning[part] then return end
 local light=part:FindFirstChildOfClass("PointLight")
 burning[part]={light=light,hiss=Audio.Play("Sizzle",part,.4,1.2,80,true),lastSpark=0,lastSmoke=0,base=light and light.Brightness or 3}
end
workspace.DescendantAdded:Connect(function(d) if d.Name=="GS_FlareBurn" then task.defer(watchBurn,d) end end)
for _,d in ipairs(workspace:GetDescendants()) do if d.Name=="GS_FlareBurn" then watchBurn(d) end end
RunService.Heartbeat:Connect(function()
 local now=os.clock()
 local camera=workspace.CurrentCamera
 for part,st in pairs(burning) do
  if not part.Parent then
   if st.hiss then st.hiss:Destroy() end
   burning[part]=nil
  else
   local left=(part:GetAttribute("GS_BurnUntil") or 0)-workspace:GetServerTimeNow()
   local strength=math.clamp(left/2.5,0,1) -- dies out over the last seconds
   if st.light then st.light.Brightness=st.base*(0.7+0.3*math.noise(now*11,part.Position.X))*strength end
   local near=camera and (camera.CFrame.Position-part.Position).Magnitude<150
   if near and strength>0 then
    if now-st.lastSpark>(low() and .2 or .08) then
     st.lastSpark=now
     VFX.Sparks(part.Position+Vector3.new(0,.15,0),Vector3.yAxis,Color3.fromRGB(255,176,128),2)
    end
    if now-st.lastSmoke>(low() and .35 or .16) then
     st.lastSmoke=now
     VFX.Smoke(part.Position+Vector3.new(0,.2,0),Vector3.yAxis,.9,SMOKE)
    end
   end
   if st.hiss then st.hiss.Volume=.4*strength end
  end
 end
end)
]=]},
	{name = "WeaponMechanics", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
-- The moving parts of every gun in someone's hands, and everything a reload looks and sounds like. Drawn on each
-- client for everyone, from the attributes the server puts on the character (GS_ReloadPhase / PhaseAt / PhaseDur /
-- ReloadCount, GS_PumpAt, GS_RecoilAt). Parts marked with a Motion attribute in the item model move:
--   Barrel  break-action barrels swing down on a hinge      Pump / Bolt  slide back and forward
-- Double barrel: break it open (overshoots, settles), the spent hulls kick out over the shoulder, the other hand
--   brings fresh shells up from the belt one by one and thumbs them into the chambers, then it's snapped shut.
-- Flare gun: the same with one fat flare cartridge.
-- Warden 870: rolled over to show the loading port, shells pushed into the tube one at a time, racked at the end;
--   after every shot the fore-end is pumped and the hull flies out of the ejection port.
-- After a shot the barrels smoke for a moment. Every sound goes through CombatAudio (no pile-ups).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Modules=RS:WaitForChild("Modules")
local ItemData=require(Modules:WaitForChild("ItemData"))
local Audio=require(Modules:WaitForChild("CombatAudio"))
local VFX=require(Modules:WaitForChild("CustomVFX"))
local GameSettings=require(Modules:WaitForChild("GameSettings"))

local folder=workspace:FindFirstChild("GS_FX") or Instance.new("Folder")
folder.Name="GS_FX" folder.Parent=workspace
local rng=Random.new()
local function low() return GameSettings.Get("LowGraphics")==true end
local function smooth(x) x=math.clamp(x,0,1) return x*x*(3-2*x) end
local function backOut(x) x=math.clamp(x,0,1) local c=1.9 return 1+(c+1)*(x-1)^3+c*(x-1)^2 end

-- per gun: how it opens and where the shells go (model space, before the held scale)
local RIG={
 doublebarrel={kind="break",hinge=Vector3.new(.15,-.08,0),angle=38,cartridge="shell",
  breech={Vector3.new(.12,.2,-.125),Vector3.new(.12,.2,.125)}},
 flaregun={kind="break",hinge=Vector3.new(.02,.08,0),angle=50,cartridge="flare",
  breech={Vector3.new(-.3,.28,0)}},
 warden870={kind="pump",pump=.34,bolt=.25,cartridge="shell"},
}
local CART={
 shell={len=.5,dia=.17,hull=Color3.fromRGB(158,26,24),spent=Color3.fromRGB(104,22,20),head=.11},
 flare={len=.52,dia=.27,hull=Color3.fromRGB(226,104,38),spent=Color3.fromRGB(150,70,30),head=.13,band=true},
}

-- a cartridge built from parts (X is its axis, the brass head at -X)
local function cartridge(kind,scale,spent)
 local c=CART[kind] or CART.shell
 local s=scale or 1
 local hull=Instance.new("Part") hull.Name="GS_Cartridge" hull.Shape=Enum.PartType.Cylinder
 hull.Size=Vector3.new(c.len,c.dia,c.dia)*s hull.Color=spent and c.spent or c.hull hull.Material=Enum.Material.SmoothPlastic
 hull.CanQuery=false hull.CanTouch=false hull.CastShadow=false
 local head=Instance.new("Part") head.Name="Head" head.Shape=Enum.PartType.Cylinder
 head.Size=Vector3.new(c.head,c.dia*1.08,c.dia*1.08)*s head.Color=Color3.fromRGB(196,160,72) head.Material=Enum.Material.Metal
 head.CanCollide=false head.CanQuery=false head.CanTouch=false head.Massless=true head.CastShadow=false
 head.CFrame=hull.CFrame*CFrame.new(-(c.len-c.head)/2*s,0,0) head.Parent=hull
 local w=Instance.new("WeldConstraint") w.Part0=hull w.Part1=head w.Parent=head
 if c.band then
  local band=Instance.new("Part") band.Name="Band" band.Shape=Enum.PartType.Cylinder
  band.Size=Vector3.new(.06,c.dia*1.02,c.dia*1.02)*s band.Color=Color3.fromRGB(236,232,222) band.Material=Enum.Material.SmoothPlastic
  band.CanCollide=false band.CanQuery=false band.CanTouch=false band.Massless=true band.CastShadow=false
  band.CFrame=hull.CFrame*CFrame.new(.12*s,0,0) band.Parent=hull
  local w2=Instance.new("WeldConstraint") w2.Part0=hull w2.Part1=band w2.Parent=band
 end
 return hull
end

-- a spent hull flying out: real physics on this client, a clink when it lands, gone after a while
local function spentHull(kind,cf,velocity,scale)
 local hull=cartridge(kind,scale,true)
 hull.CFrame=cf hull.Anchored=false hull.CanCollide=true hull.Parent=folder
 for _,d in ipairs(hull:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=false end end
 hull.AssemblyLinearVelocity=velocity
 hull.AssemblyAngularVelocity=Vector3.new(rng:NextNumber(-1,1),rng:NextNumber(-1,1),rng:NextNumber(-1,1))*18
 -- a wisp of smoke from the fired hull
 if not low() then VFX.Smoke(cf.Position,Vector3.yAxis,.35,Color3.fromRGB(120,114,108)) end
 task.delay(.45+rng:NextNumber(0,.15),function() if hull.Parent then Audio.Play("ShellDrop",hull,.35,rng:NextNumber(.9,1.15),45) end end)
 Debris:AddItem(hull,12)
end

-- ===== per character state =====
local states={}
local function stateFor(character,model)
 local st=states[character]
 if st and st.model==model then return st end
 if st and st.inHand then st.inHand:Destroy() end
 st={model=model,joints={},phaseKey=nil,events={},pumpDone=nil,recoilDone=nil,smokeUntil=0,lastSmoke=0}
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA("BasePart") and p:GetAttribute("Motion") then
   local w=p:FindFirstChild("GS_ItemWeld")
   if w and w:GetAttribute("ModelFrame") and w:GetAttribute("LocalFrame") then
    table.insert(st.joints,{w=w,motion=p:GetAttribute("Motion")})
   end
  end
 end
 st.anyWeld=model:FindFirstChild("GS_ItemWeld",true)
 states[character]=st
 return st
end

-- the held model's own frame in the world (all its welds share it)
local function modelFrame(st)
 local w=st.anyWeld
 if not w or not w.Parent or not w.Part0 then return nil end
 return w.Part0.CFrame*w:GetAttribute("ModelFrame")
end
local function barrelMotion(rig,scale,open)
 if not rig or rig.kind~="break" then return CFrame.new() end
 local h=rig.hinge*scale
 return CFrame.new(h)*CFrame.Angles(0,0,-math.rad(rig.angle)*open)*CFrame.new(-h)
end
local function breechCF(st,rig,scale,open,i)
 local mf=modelFrame(st)
 if not mf or not rig.breech then return nil end
 return mf*barrelMotion(rig,scale,open)*CFrame.new(rig.breech[i]*scale)
end
local function handCF(character)
 local arm=character:FindFirstChild("Left Arm")
 return arm and arm.CFrame*CFrame.new(0,-1.05,0) or nil
end
local function once(st,key,fn)
 if st.events[key] then return end
 st.events[key]=true
 fn()
end

RunService.RenderStepped:Connect(function()
 local now=workspace:GetServerTimeNow()
 for _,player in ipairs(Players:GetPlayers()) do
  local c=player.Character
  local model=c and c:FindFirstChild("GS_Held")
  local item=model and ItemData.Get(model:GetAttribute("ItemId"))
  if not item or item.kind~="gun" then
   local old=c and states[c]
   if old then if old.inHand then old.inHand:Destroy() end states[c]=nil end
   continue
  end
  local st=stateFor(c,model)
  local rig=RIG[item.id] or {kind="none"}
  local scale=model:GetScale()
  local head=c:FindFirstChild("Head")

  -- ===== the reload, phase by phase =====
  local phase=c:GetAttribute("GS_ReloadPhase")
  local phaseAt=c:GetAttribute("GS_ReloadPhaseAt") or now
  local dur=math.max(c:GetAttribute("GS_ReloadPhaseDur") or .5,.01)
  local pt=math.clamp((now-phaseAt)/dur,0,1)
  local key=phase and (phase..string.format("%.2f",phaseAt)) or nil
  if key~=st.phaseKey then
   st.phaseKey=key
   st.events={}
   if st.inHand then st.inHand:Destroy() st.inHand=nil end
  end
  local open=0
  local pump=0
  if rig.kind=="break" then
   if phase=="open" then
    open=backOut(pt/.7)
    once(st,"latch",function() Audio.Play("Click",head,.45,.85,40) end)
    if pt>.6 then
     -- the extractor kicks the hulls out, back over the shoulder
     once(st,"extract",function()
      local mf=modelFrame(st)
      local back=mf and -mf.XVector or Vector3.zero
      for i=1,#rig.breech do
       local cf=breechCF(st,rig,scale,1,i)
       if cf then
        spentHull(rig.cartridge,cf*CFrame.new(-.2*scale,0,0),back*rng:NextNumber(7,10)+Vector3.new(0,rng:NextNumber(7,10),0)+Vector3.new(rng:NextNumber(-1.5,1.5),0,rng:NextNumber(-1.5,1.5)))
       end
      end
      Audio.Play("Rack",head,.22,1.6,35)
     end)
    end
   elseif phase=="load" then
    open=1
   elseif phase=="close" then
    local k=pt/.35
    open=k<1 and 1-k*k or math.max(0,math.sin((k-1)*math.pi)*.04)
    once(st,"shut",function()
     task.delay(dur*.3,function() if head and head.Parent then Audio.Play("Click",head,.55,1.15,45) end end)
    end)
   end
  elseif rig.kind=="pump" then
   if phase=="close" then
    pump=math.sin(math.clamp(pt/.7,0,1)*math.pi)
    once(st,"rack",function() Audio.Play("Rack",head,.5,1,55) end)
   elseif phase=="open" then
    once(st,"gate",function() Audio.Play("Click",head,.35,1.2,35) end)
   end
  end

  -- ===== loading shells by hand =====
  if phase=="load" then
   local n=math.max(1,c:GetAttribute("GS_ReloadCount") or 1)
   local slot=math.min(math.floor(pt*n),n-1)
   local sub=math.clamp(pt*n-slot,0,1)
   local hand=handCF(c)
   local target
   if rig.kind=="break" then
    target=breechCF(st,rig,scale,1,math.min(slot+1,#rig.breech))
   else
    local port=model:FindFirstChild("LoadingPort",true)
    target=port and port.WorldCFrame*CFrame.Angles(0,math.pi/2,0)
   end
   if sub>=.3 and sub<.95 and hand and target then
    if not st.inHand then
     st.inHand=cartridge(rig.cartridge or "shell",scale,false)
     st.inHand.Anchored=true st.inHand.CanCollide=false
     for _,d in ipairs(st.inHand:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=true end end
     st.inHand.Parent=folder
     once(st,"grab"..slot,function() Audio.Play("Cloth",head,.18,1.5,20) end)
    end
    -- in the hand (pointing along the arm), then lined up with the chamber and pushed in
    local held=CFrame.fromMatrix(hand.Position,-hand.UpVector,hand.LookVector)
    local cf
    if sub<.72 then
     cf=held
    else
     local k=smooth((sub-.72)/.23)
     local mouth=target*CFrame.new(-.45*scale*(1-k),0,0)
     cf=held:Lerp(mouth,smooth((sub-.72)/.1))
     cf=cf:Lerp(mouth,k)
    end
    st.inHand:PivotTo(cf)
    if sub>.85 then once(st,"in"..slot,function() Audio.Play("ShellIn",head,.45,rng:NextNumber(.95,1.08),35) end) end
   elseif st.inHand then
    st.inHand:Destroy() st.inHand=nil
   end
  elseif st.inHand then
   st.inHand:Destroy() st.inHand=nil
  end

  -- ===== the pump after a shot =====
  local pumpAt=c:GetAttribute("GS_PumpAt")
  if rig.kind=="pump" and pumpAt then
   local t=(now-pumpAt)/(item.pumpDuration or .42)
   if t>=0 and t<=1 then
    pump=math.max(pump,math.sin(t*math.pi))
    -- (the shooter's own client and then the server both set it: one pump per shot)
    if not st.pumpDone or math.abs(st.pumpDone-pumpAt)>.4 then
     st.pumpDone=pumpAt
     Audio.Play("Rack",head,.5,1,60)
     task.delay((item.pumpDuration or .42)*.4,function()
      local port=model.Parent and model:FindFirstChild("EjectionPort",true)
      local mf=modelFrame(st)
      if port and mf then
       spentHull("shell",port.WorldCFrame*CFrame.Angles(0,-math.pi/2,0),mf.ZVector*rng:NextNumber(8,11)+Vector3.new(0,rng:NextNumber(8,11),0)-mf.XVector*2,scale)
      end
     end)
    end
   end
  end

  -- ===== smoke from the barrels after a shot =====
  local recoilAt=c:GetAttribute("GS_RecoilAt")
  if recoilAt and (not st.recoilDone or math.abs(st.recoilDone-recoilAt)>.2) and now-recoilAt<.5 then
   st.recoilDone=recoilAt
   st.smokeUntil=os.clock()+(item.fire and .8 or 1.8)
  end
  if os.clock()<st.smokeUntil and os.clock()-st.lastSmoke>(low() and .25 or .11) then
   st.lastSmoke=os.clock()
   local muzzle=model:FindFirstChild("Muzzle",true)
   if muzzle and muzzle:IsA("Attachment") then
    local left=(st.smokeUntil-os.clock())/1.8
    VFX.Smoke(muzzle.WorldPosition,Vector3.yAxis,.25+.25*left,Color3.fromRGB(130,126,120))
   end
  end

  -- ===== move the parts =====
  for _,j in ipairs(st.joints) do
   local w=j.w
   if w.Parent then
    local motion=CFrame.new()
    if j.motion=="Pump" then motion=CFrame.new(-(rig.pump or .34)*scale*pump,0,0)
    elseif j.motion=="Bolt" then motion=CFrame.new(-(rig.bolt or .25)*scale*pump,0,0)
    elseif j.motion=="Barrel" then motion=barrelMotion(rig,scale,open)
    end
    w.C0=w:GetAttribute("ModelFrame")*motion*w:GetAttribute("LocalFrame")
   end
  end
 end
 for character,st in pairs(states) do
  if not character.Parent or not st.model.Parent then
   if st.inHand then st.inHand:Destroy() end
   states[character]=nil
  end
 end
end)
]=]},
	{name = "Weapons", class = "Script", where = "ServerScriptService", source = [=[
-- Guns and melee, decided on the server. The client (WeaponClient) shows the shot at once; the server
-- replays it from the same seed (ItemData.Pellets), so the pellets that do damage are the ones you saw.
--   fire   (uid, origin CFrame, seed, aiming)   - ammo, fire rate, spread and range are checked here
--   reload (uid)                                - loads from the bag's ammo, shell by shell for pump guns
--   swing  (uid, look direction)                - melee: the closest thing in front, on the closest limb
-- Damage to creatures goes through ServerStorage.GS_MonsterHealth, to people through their armor first.
-- People only hurt people when PvP is on (admin panel) - the infected can always be hurt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Svc = require(ServerStorage:WaitForChild("GS_ItemService"))
local FallDamageController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FallDamageController"))
local ItemData = Svc.ItemData

local remote = ReplicatedStorage:FindFirstChild("GS_Weapon")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GS_Weapon"
	remote.Parent = ReplicatedStorage
end

local LIMB = {
	Head = "Head", Torso = "Torso", HumanoidRootPart = "Torso",
	["Left Arm"] = "LeftArm", ["Right Arm"] = "RightArm", ["Left Leg"] = "LeftLeg", ["Right Leg"] = "RightLeg",
}

local function serverNow() return workspace:GetServerTimeNow() end

local function monsterApi(...)
	local api = ServerStorage:FindFirstChild("GS_MonsterHealth")
	if not api then return 0, false end
	local ok, dealt, killed, severed, head = pcall(api.Invoke, api, ...)
	if not ok then return 0, false end
	return dealt or 0, killed, severed, head
end

local function monsterControl(...)
	local control = ServerStorage:FindFirstChild("GS_MonsterControl")
	if control then pcall(control.Invoke, control, ...) end
end

-- a loud noise every monster can hear (Monsters' hearing system)
local function noise(character, radius)
	monsterControl("Noise", character, radius, 1.5)
end

-- the model a hit part belongs to, and what kind of thing it is
local function classify(part)
	local monsters = workspace:FindFirstChild("Monsters")
	local npcs = workspace:FindFirstChild("NPCs")
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model.Parent == monsters then
			if model:GetAttribute("MonsterId") and not model:GetAttribute("GS_Dead") then return model, "monster" end
			return nil
		end
		if model.Parent == npcs then return model, "npc" end
		if Players:GetPlayerFromCharacter(model) then return model, "player" end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function canHurtPerson(attacker, victim)
	if victim == attacker then return false end
	if victim:GetAttribute("Infected") then return true end
	if attacker:GetAttribute("Infected") then return true end
	return Svc.PvP()
end

-- a person (player or npc) hit on one body part
local function hurtPerson(attackerPlayer, victim, partKey, damage, cause, opts)
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	local dealt, blocked = Svc.Absorb(victim, partKey, damage, opts and opts.type or "bullet")
	victim:SetAttribute("LastDamageCause", cause)
	victim:SetAttribute("LastDamageTime", serverNow())
	humanoid:TakeDamage(dealt)
	if humanoid.Health <= 0 then
		victim:SetAttribute("DeathCause", cause)
		return true
	end
	-- a heavy hit breaks something, unless the armor took it
	if not blocked and dealt >= (opts and opts.woundAt or 18) and partKey ~= "Torso" then
		local level = victim:GetAttribute("Injury_" .. partKey) or 0
		if level < 2 then FallDamageController.Injure(victim, partKey, level + 1) end
	end
	if opts and opts.bleed and dealt > 0 then FallDamageController.AddBleeding(victim, 0.35, 10) end
	if opts and opts.stun and dealt > 0 then
		FallDamageController.Ragdoll(victim, opts.stun * 0.7, 0.2)
		victim:SetAttribute("GS_Shocked", serverNow())
	end
	return false
end

-- ===== guns =====
local lastShot = {}
local reloading = {}

local worldParams
function worldParams(shooter)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {shooter}
	for _, name in ipairs({"GS_Items", "GS_Traps", "SpiderWebs", "GS_Hallucinations", "PS_Blood", "GS_Tentacles", "GS_FX"}) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(ignore, f) end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function burn(model, attacker, seconds)
 local untilTime=serverNow()+seconds
 if (model:GetAttribute("GS_Burning") or 0)>serverNow() then
  model:SetAttribute("GS_Burning",math.max(model:GetAttribute("GS_Burning"),untilTime))
  return
 end
 model:SetAttribute("GS_Burning",untilTime)
 task.spawn(function()
  while model.Parent and not model:GetAttribute("GS_Dead") and serverNow()<(model:GetAttribute("GS_Burning") or 0) do
   task.wait(0.5)
   if not model.Parent or model:GetAttribute("GS_Dead") then break end
   monsterApi("damage",model,"Torso",4,"fire",attacker)
  end
  if model.Parent then model:SetAttribute("GS_Burning",nil) end
 end)
end

-- a flare shell burning where it landed: light, smoke, and anything standing in it catches fire
local function setAlight(character, attacker, seconds)
	if (character:GetAttribute("GS_OnFire") or 0)>serverNow() then
 character:SetAttribute("GS_OnFire",math.max(character:GetAttribute("GS_OnFire"),serverNow()+seconds))
 return end

	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not torso or not humanoid then return end
	character:SetAttribute("GS_OnFire", serverNow() + seconds)
	task.spawn(function()
		while serverNow() < (character:GetAttribute("GS_OnFire") or 0) do
			task.wait(0.5)
			if not character.Parent or humanoid.Health <= 0 then break end
			character:SetAttribute("LastDamageCause", "BURNED")
			character:SetAttribute("LastDamageTime", serverNow())
			humanoid:TakeDamage(2.5)
		end
		if character.Parent then character:SetAttribute("GS_OnFire", nil) end
	end)
end
local FLARE_BURN = 14
local function flareLanded(position, normal, attacker)
	local p = Instance.new("Part")
	p.Name = "GS_FlareBurn"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size = Vector3.new(0.25, 0.25, 0.8)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 70, 50)
	p.CFrame = CFrame.lookAt(position + normal * 0.15, position + normal * 0.15 + Vector3.new(normal.Z, 0, -normal.X) + Vector3.new(0.01, 0, 0))
	p.Parent = workspace:FindFirstChild("GS_FX") or workspace
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 70, 50), 24, 3, true
	light.Parent = p
 p:SetAttribute("GS_BurnUntil",serverNow()+FLARE_BURN)
	task.spawn(function()
		local t0 = os.clock()
		while p.Parent and os.clock() - t0 < FLARE_BURN do
			for _, plr in ipairs(Players:GetPlayers()) do
				local c = plr.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if r and (r.Position - position).Magnitude < 3.2 and (c:GetAttribute("Infected") or Svc.PvP() or plr.Character == attacker.Character) then
					setAlight(c, attacker, 4)
				end
			end
			local monsters = workspace:FindFirstChild("Monsters")
			for _, m in ipairs(monsters and monsters:GetChildren() or {}) do
				local r = m:FindFirstChild("HumanoidRootPart")
				if r and (r.Position - position).Magnitude < 4 then burn(m, attacker, 5) end
			end
			task.wait(0.4)
		end
		if p.Parent then p:Destroy() end
	end)
end

local function validCharacter(player)
 local c=player.Character
 local h=c and c:FindFirstChildOfClass("Humanoid")
 if not h or h.Health<=0 or c:GetAttribute("Ragdolled") or c:GetAttribute("Infected") or c:GetAttribute("GS_UseStart") then return end
 return c,h
end
local function cancelReload(player)
 local token=reloading[player]
 if not token then return end
 reloading[player]=nil
 if token.character.Parent then
  token.character:SetAttribute("GS_ReloadAt",nil)
  token.character:SetAttribute("GS_ReloadPhase",nil)
 end
 remote:FireAllClients("reloadcancel",token.character,token.id)
end
local function resolveHit(player, character, item, result, damage, direction)
 local model,kind=classify(result.Instance)
 if not model then
  remote:FireAllClients("surface",result.Position,result.Normal,result.Material,item.id)
  return
 end
 local partName=result.Instance:GetAttribute("BodyPart") or result.Instance.Name
 if kind=="monster" then
  local dealt=monsterApi("damage",model,partName,damage,item.fire and "fire" or "bullet",player,result.Position,direction)
  if item.fire then burn(model,player,7) end
 elseif canHurtPerson(character,model) then
  local killed=hurtPerson(player,model,LIMB[partName] or "Torso",damage,item.fire and "BURNED" or "SHOT",{woundAt=22,type=item.fire and "fire" or "bullet"})
  remote:FireAllClients("bodyimpact",model,result.Position,result.Normal)
  if item.fire and not killed then setAlight(model,player,6) end
 end
end
-- the flare: a burning ball on a slow, dropping arc. It skips off walls and floors it hits at a shallow angle
-- (twice at most), sticks in anything alive it hits (and sets it on fire), and otherwise lies where it lands and
-- burns red for a while, lighting the place up.
local function launchFlare(player,character,item,origin,direction)
 local params=worldParams(character)
 local position=origin
 local velocity=direction*(item.projectileSpeed or 150)
 local gravity=Vector3.new(0,-workspace.Gravity*0.16,0)
 local start=serverNow()
 local id=tostring(player.UserId)..":"..string.format("%.3f",start)
 remote:FireAllClients("flareflight",id,position,velocity,gravity,start,character)
 task.spawn(function()
  local elapsed,travelled,bounces=0,0,0
  while elapsed<6 and travelled<item.range do
   local dt=math.min(game:GetService("RunService").Heartbeat:Wait(),0.05)
   elapsed+=dt
   local step=velocity*dt+gravity*(0.5*dt*dt)
   local hit=workspace:Spherecast(position,0.15,step,params)
   if hit then
    local model=classify(hit.Instance)
    if model then
     resolveHit(player,character,item,hit,item.damage,velocity.Unit)
     remote:FireAllClients("flarestop",id,hit.Position,hit.Normal,hit.Instance)
     return
    end
    local speed=velocity.Magnitude
    local into=velocity:Dot(hit.Normal)
    if bounces<2 and speed>30 and math.abs(into)/speed<0.5 then
     -- a glancing hit: it skips off, slower
     bounces+=1
     velocity=(velocity-2*into*hit.Normal)*0.45
     position=hit.Position+hit.Normal*0.2
     start=serverNow()
     remote:FireAllClients("flarebounce",id,position,velocity,gravity,start)
    else
     flareLanded(hit.Position,hit.Normal,player)
     remote:FireAllClients("flarestop",id,hit.Position,hit.Normal)
     return
    end
   else
    position+=step
    velocity+=gravity*dt
    travelled+=step.Magnitude
   end
  end
  -- out of range: it falls to the floor below and burns there
  local down=workspace:Raycast(position,Vector3.new(0,-60,0),params)
  if down then flareLanded(down.Position,down.Normal,player) end
  remote:FireAllClients("flarestop",id,down and down.Position or position,down and down.Normal or nil)
 end)
end
local function fire(player,uid,origin,seed,aiming)
 local character=validCharacter(player)
 if not character then return end
 local head=character:FindFirstChild("Head")
 local root=character:FindFirstChild("HumanoidRootPart")
 if not head or not root or typeof(origin)~="CFrame" or typeof(seed)~="number" or seed~=seed or math.abs(seed)>2^31 then return end
 local entry,item=Svc.Held(player)
 if not entry or entry.uid~=uid or item.kind~="gun" then return end
 if reloading[player] and reloading[player].uid~=uid then cancelReload(player) end
 if reloading[player] and not item.reloadPerShell then return end
 local now=os.clock()
 if now-(lastShot[player] or 0)<60/item.rpm-0.015 or (entry.ammo or 0)<=0 then return end
 if (origin.Position-head.Position).Magnitude>3 or origin.LookVector.Magnitude<0.9 or origin.LookVector.X~=origin.LookVector.X then return end
 lastShot[player]=now
 cancelReload(player)
 entry.ammo-=1
 Svc.Sync(player)
 character:SetAttribute("GS_RecoilAt",serverNow())
 if item.pump then character:SetAttribute("GS_PumpAt",serverNow()+(item.pumpDelay or 0.22)) end
 local moving=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude>3
 local spread=(aiming and item.aimSpread or item.spread)*(moving and 1.3 or 1)
 local startPos=origin.Position
 local look=CFrame.lookAt(startPos,startPos+origin.LookVector)
 local params=worldParams(character)
 local ends={}
 if item.fire then
  launchFlare(player,character,item,startPos,look.LookVector)
  table.insert(ends,startPos+look.LookVector*item.range)
 else
  -- Aggregate only pellets on the SAME physical part; never move limb damage to another limb.
  local groups={}
  for _,dir in ipairs(ItemData.Pellets(item,look,seed,spread)) do
   local result=workspace:Raycast(startPos,dir*item.range,params)
   local pos=result and result.Position or startPos+dir*item.range
   table.insert(ends,pos)
   if result then
    local dist=(pos-startPos).Magnitude
    local falloff=math.clamp(1-math.max(0,dist-18)/item.range,0.35,1)
    local damage=item.damage*falloff*(result.Instance.Name=="Head" and (item.headMult or 1) or 1)
    local group=groups[result.Instance]
    if group then group.damage+=damage else groups[result.Instance]={result=result,damage=damage,direction=dir} end
   end
  end
  for _,group in pairs(groups) do resolveHit(player,character,item,group.result,group.damage,group.direction) end
 end
 remote:FireAllClients("shot",character,item.id,startPos,ends)
 noise(character,item.fire and 110 or 160)
end
local function reload(player,uid)
 local character=validCharacter(player)
 local entry,item=Svc.Held(player)
 if reloading[player] and reloading[player].uid~=uid then cancelReload(player) end
 if not character or not entry or entry.uid~=uid or item.kind~="gun" or reloading[player] then return end
 local need=item.magazine-(entry.ammo or 0)
 local reserve=Svc.CountOf(player,item.ammo)
 if need<=0 then return end
 if reserve<=0 then remote:FireClient(player,"noammo",item.ammo) return end
 local count=math.min(need,reserve)
 local open=item.reloadOpen or 0.35
 local close=item.reloadClose or 0.35
 local duration=open+item.reload*(item.reloadPerShell and count or 1)+close
 local token={character=character,id=item.id,uid=uid}
 reloading[player]=token
 character:SetAttribute("GS_ReloadAt",serverNow())
 character:SetAttribute("GS_ReloadDur",duration)
 character:SetAttribute("GS_ReloadCycle",item.reload)
 character:SetAttribute("GS_ReloadOpen",open)
 local function valid()
  local e=Svc.Held(player)
  return reloading[player]==token and validCharacter(player)==character and e and e.uid==uid
 end
 local function phase(name,dur,n)
  character:SetAttribute("GS_ReloadCount",n or 1)
  character:SetAttribute("GS_ReloadPhase",name)
  character:SetAttribute("GS_ReloadPhaseAt",serverNow())
  character:SetAttribute("GS_ReloadPhaseDur",dur)
  remote:FireAllClients("reloadphase",character,item.id,name,dur,n or 1)
 end
 task.spawn(function()
  phase("open",open)
  task.wait(open)
  if not valid() then if reloading[player]==token then cancelReload(player) end return end
  local cycles=item.reloadPerShell and count or 1
  for _=1,cycles do
   phase("load",item.reload,item.reloadPerShell and 1 or count)
   task.wait(item.reload)
   if not valid() then if reloading[player]==token then cancelReload(player) end return end
   local e=Svc.Held(player)
   local got=Svc.TakeId(player,item.ammo,item.reloadPerShell and 1 or count)
   if got<=0 then break end
   e.ammo=math.min(item.magazine,(e.ammo or 0)+got)
   Svc.Sync(player)
   remote:FireAllClients("shellin",character,item.id)
  end
  phase("close",close)
  task.wait(close)
  if not valid() then if reloading[player]==token then cancelReload(player) end return end
  reloading[player]=nil
  character:SetAttribute("GS_ReloadAt",nil)
  character:SetAttribute("GS_ReloadPhase",nil)
  remote:FireAllClients("reloaded",character,item.id)
 end)
end
local lastSwing={}
local function swing(player,uid,look)
 local character,humanoid=validCharacter(player)
 if not character or typeof(look)~="Vector3" or look.Magnitude<0.9 or look.X~=look.X then return end
 local entry,item=Svc.Held(player)
 if not entry or entry.uid~=uid or item.kind~="melee" then return end
 local now=os.clock()
 if now-(lastSwing[player] or 0)<item.cooldown-0.015 then return end
 lastSwing[player]=now
 look=look.Unit
 character:SetAttribute("GS_WeaponSwingAt",serverNow())
 character:SetAttribute("GS_AttackDuration",item.cooldown)
 remote:FireAllClients("swing",character,item.id)
 noise(character,25)
 task.wait(item.windup or item.cooldown*0.38)
 local e=Svc.Held(player)
 if validCharacter(player)~=character or not e or e.uid~=uid then return end
 local head=character:FindFirstChild("Head")
 if not head then return end
 local params=worldParams(character)
 local hit=workspace:Raycast(head.Position,look*item.reach,params)
 if not hit then hit=workspace:Spherecast(head.Position,item.hitRadius or 0.12,look*item.reach,params) end
 if not hit then return end
 local model,kind=classify(hit.Instance)
 if not model then remote:FireAllClients("surface",hit.Position,hit.Normal,hit.Material,item.id) return end
 if kind=="monster" then
  local dealt=monsterApi("damage",model,hit.Instance.Name,item.damage*(item.limbMult or 1),item.stun and "shock" or "melee",player,hit.Position,look)
  if item.stun and dealt>0 then monsterControl("Stun",model,item.stun) end
  monsterControl("Struck",model,character)
 elseif canHurtPerson(character,model) then
  hurtPerson(player,model,LIMB[hit.Instance.Name] or "Torso",item.damage,"BEATEN",{type="melee",bleed=item.bleed,stun=item.stun,woundAt=20})
 end
 remote:FireAllClients("impact",model,hit.Position,item.id)
end

-- ===== requests =====
remote.OnServerEvent:Connect(function(player, action, uid, a, b, c)
	if typeof(uid) ~= "string" then return end
	if action == "fire" then
		fire(player, uid, a, b, c == true)
	elseif action == "reload" then
		reload(player, uid)
	elseif action == "swing" then
		swing(player, uid, a)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastShot[player], reloading[player], lastSwing[player] = nil, nil, nil
end)
]=]},
	{name = "Weather", class = "LocalScript", where = "StarterPlayerScripts", source = [=[
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
]=]},
}

-- only look where each script belongs: a free model somewhere else with the same name is left alone
local SEARCH = {
	ServerScriptService = {"ServerScriptService"},
	StarterPlayerScripts = {"StarterPlayer"},
	Modules = {"ReplicatedStorage"},
	ServerStorage = {"ServerStorage"},
}

local function findExisting(name, className, where)
	for _, serviceName in ipairs(SEARCH[where] or {}) do
		local service = game:GetService(serviceName)
		for _, d in ipairs(service:GetDescendants()) do
			if d.Name == name and d.ClassName == className then return d end
		end
	end
	return nil
end

local function defaultParent(where)
	if where == "ServerScriptService" then return game:GetService("ServerScriptService") end
	if where == "ServerStorage" then return game:GetService("ServerStorage") end
	if where == "StarterPlayerScripts" then
		return game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
			or game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	end
	local rs = game:GetService("ReplicatedStorage")
	local modules = rs:FindFirstChild("Modules")
	if not modules then
		modules = Instance.new("Folder")
		modules.Name = "Modules"
		modules.Parent = rs
	end
	return modules
end

-- light everywhere: Future lighting (shadows and reflections from every lamp), full environment lighting,
-- the newer materials. A running game can't switch these, so the installer does it in Studio.
local function setupLighting()
	local Lighting = game:GetService("Lighting")
	for key, value in pairs({
		Technology = Enum.Technology.Future, GlobalShadows = true, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1,
		ShadowSoftness = 0.35,
	}) do
		local ok = pcall(function() Lighting[key] = value end)
		print(string.format("[Installer] Lighting.%s %s", key, ok and "set" or "could not be set"))
	end
	pcall(function() Lighting.LightingStyle = Enum.LightingStyle.Realistic end)
	pcall(function() Lighting.PrioritizeLightingQuality = true end)
	pcall(function() game:GetService("MaterialService").Use2022Materials = true end)
end

-- the old text of every script it replaces goes into ServerStorage first (like the backups already there)
local function backupFolder()
	local folder = Instance.new("Folder")
	folder.Name = "GS_Backup_Installer_" .. os.date("!%Y%m%d_%H%M%S")
	folder.Parent = game:GetService("ServerStorage")
	return folder
end

local function install()
	local recording = ChangeHistoryService:TryBeginRecording("Install game scripts")
	local replaced, created = 0, 0
	local backup = backupFolder()
	setupLighting()
	for _, entry in ipairs(SCRIPTS) do
		local target = findExisting(entry.name, entry.class, entry.where)
		if target then
			local copy = Instance.new("StringValue")
			copy.Name = target:GetFullName()
			pcall(function() copy.Value = target.Source end)
			copy.Parent = backup
			replaced += 1
		else
			target = Instance.new(entry.class)
			target.Name = entry.name
			target.Parent = defaultParent(entry.where)
			created += 1
		end
		target.Source = entry.source
		print(string.format("[Installer] %s -> %s", entry.name, target:GetFullName()))
	end
	if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
	print(string.format("[Installer] done: %d replaced, %d created. Now: File -> Publish / Save.", replaced, created))
	warn("[Installer] Remember: Game Settings -> Security -> API Services + HTTP Requests ON.")
end

if plugin then
	local toolbar = plugin:CreateToolbar("Game scripts")
	local button = toolbar:CreateButton("Install scripts", "Install / update the game scripts", "rbxasset://textures/StudioToolbox/AssetPreview/more.png")
	button.ClickableWhenViewportHidden = true
	button.Click:Connect(function()
		install()
		button:SetActive(false)
	end)
else
	install()
end
