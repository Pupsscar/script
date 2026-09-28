local Players = game:GetService("Players")

local CONFIG = {
	Amount = 1,
	Interval = 10,
	NoDamageTime = 10,
}

local lastDamage = {}

local function setupCharacter(character)

	local default = character:WaitForChild("Health", 5)
	if default and default:IsA("Script") then
		default:Destroy()
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local lastHealth = humanoid.Health
	lastDamage[character] = os.clock()
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth - 1e-3 then
			lastDamage[character] = os.clock()
		end
		lastHealth = health
	end)
	character.Destroying:Connect(function()
		lastDamage[character] = nil
	end)

	task.spawn(function()
		while character.Parent and humanoid.Parent do
			task.wait(CONFIG.Interval)
			if not character.Parent or humanoid.Health <= 0 then break end
			-- the infected heal on their own schedule (Monsters script)
			if character:GetAttribute("Infected") then continue end
			local since = os.clock() - (lastDamage[character] or 0)
			if since >= CONFIG.NoDamageTime and humanoid.Health < humanoid.MaxHealth then
				lastHealth = math.min(humanoid.MaxHealth, humanoid.Health + CONFIG.Amount)
				humanoid.Health = lastHealth
			end
		end
	end)
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then task.spawn(setupCharacter, player.Character) end
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
