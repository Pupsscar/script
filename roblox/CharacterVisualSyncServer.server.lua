local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LimbPose = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LimbPose"))

local event = ReplicatedStorage:FindFirstChild("CharacterVisualSync")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "CharacterVisualSync"
	event.Parent = ReplicatedStorage
end
assert(event:IsA("RemoteEvent"), "CharacterVisualSync must be a RemoteEvent")

local lastSent = {}
local MIN_INTERVAL = 1 / 30

event.OnServerEvent:Connect(function(player, packet)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Ragdolled") then return end
	local now = os.clock()
	if now - (lastSent[player] or -math.huge) < MIN_INTERVAL then return end

	local values = LimbPose.Unpack(packet)
	if not values then return end
	lastSent[player] = now
	local clean = LimbPose.Pack(values)
	-- the server keeps crouch / prone as attributes so monsters can hear how you move
	local crouch = (values[#values - 2] or 0) > 0.5
	local prone = (values[#values - 1] or 0) > 0.5
	if character:GetAttribute("GS_Crouch") ~= crouch then character:SetAttribute("GS_Crouch", crouch) end
	if character:GetAttribute("GS_Prone") ~= prone then character:SetAttribute("GS_Prone", prone) end

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then event:FireClient(other, player, clean) end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastSent[player] = nil
end)
