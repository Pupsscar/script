-- Measures how loud this player is talking in voice chat and tells the server, so monsters hear it.
-- Needs the new audio API: VoiceChatService → UseAudioApi = Enabled (and voice chat enabled for the game).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("GS_Noise", 60)
if not remote then return end

local analyzer = nil
local input = nil

local function hook(child)
	if not child:IsA("AudioDeviceInput") then return end
	input = child
	if analyzer then analyzer:Destroy() end
	local ok = pcall(function()
		analyzer = Instance.new("AudioAnalyzer")
		analyzer.Name = "GS_VoiceMeter"
		analyzer.Parent = child
		local wire = Instance.new("Wire")
		wire.SourceInstance = child
		wire.TargetInstance = analyzer
		wire.Parent = analyzer
	end)
	if not ok then analyzer = nil end
end

for _, child in ipairs(player:GetChildren()) do hook(child) end
player.ChildAdded:Connect(hook)

while true do
	task.wait(0.15)
	if analyzer and input and input.Parent then
		local ok, rms = pcall(function() return analyzer.RmsLevel end)
		local muted = false
		pcall(function() muted = input.Muted end)
		if ok and not muted and rms and rms > 0.015 then
			remote:FireServer("voice", math.clamp(rms * 6, 0, 1))
		end
	end
end
