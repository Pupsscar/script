local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false
pcall(function() game:GetService("StarterPlayer").EnableMouseLockOption = false end)

local spawnRequest = ReplicatedStorage:FindFirstChild("SpawnRequest")
if not spawnRequest then
	spawnRequest = Instance.new("RemoteEvent")
	spawnRequest.Name = "SpawnRequest"
	spawnRequest.Parent = ReplicatedStorage
end

local lastSpawn = {}

local CAMERA_NAMES = {"cam", "Cam", "CAM", "MenuCamera"}
local function findCameraPart()
	for _, name in ipairs(CAMERA_NAMES) do
		local found = workspace:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then return found end
	end
	return nil
end
local cameraPart = findCameraPart()
if cameraPart then
	ReplicatedStorage:SetAttribute("MenuCameraCFrame", cameraPart.CFrame)
	cameraPart:GetPropertyChangedSignal("CFrame"):Connect(function()
		ReplicatedStorage:SetAttribute("MenuCameraCFrame", cameraPart.CFrame)
	end)
end

local function focusMenu(player)
	if cameraPart then
		pcall(function() player.ReplicationFocus = cameraPart end)
	end
end

local function noMouseLock(player)
	pcall(function() player.DevEnableMouseLock = false end)
end
for _, player in ipairs(Players:GetPlayers()) do noMouseLock(player) end

Players.PlayerAdded:Connect(function(player)
	noMouseLock(player)
	focusMenu(player)
	player.CharacterAdded:Connect(function()
		pcall(function() player.ReplicationFocus = nil end)
	end)
	player.CharacterRemoving:Connect(function()
		focusMenu(player)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do focusMenu(player) end

spawnRequest.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastSpawn[player] or 0) < 1.5 then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid and humanoid.Health > 0 then return end
	-- infected players don't get to choose: the flesh brings them back
	if player:GetAttribute("InfectPending") or player:GetAttribute("AC_Punished") then return end
	lastSpawn[player] = now
	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(function(player)
	lastSpawn[player] = nil
end)
