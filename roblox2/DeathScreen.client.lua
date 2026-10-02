local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SoundConfig = require(Modules:WaitForChild("SoundConfig"))
local spawnRequest = ReplicatedStorage:WaitForChild("SpawnRequest")
local player = Players.LocalPlayer

local CONFIG = {
	Font = Enum.Font.SpecialElite,
	Ink = Color3.fromRGB(225, 222, 218),
	Mid = Color3.fromRGB(150, 146, 142),
	Dim = Color3.fromRGB(80, 78, 76),
	Red = Color3.fromRGB(175, 12, 12),
	Causes = {
		FALL = {
			"You fell %d studs. The spine gave way first.",
			"A %d stud drop. Nobody heard the landing.",
			"You hit the ground after %d studs. Bones snapped like dry wood.",
		},
		GIBBED = {
			"You fell %d studs. There was not much left to identify.",
			"A %d stud drop tore your body apart.",
		},
		DECAPITATED = {
			"Your head was found several meters away.",
			"Decapitated. It was quick, at least.",
		},
		HAUNTED = {
			"They took you apart piece by piece. Then they ate what was left.",
			"Nobody else saw them. That didn't stop them.",
			"They were hungry. You were there.",
		},
		D130 = {
			"Object D-130 watched you for a long time before it came closer.",
			"It followed your blood. It always does.",
			"You heard someone screaming nearby. It wasn't someone.",
		},
		SKINWALKER = {
			"It looked just like someone you trusted. Right up until it didn't.",
			"It was typing something. It never finished the message.",
			"Tomorrow it will be wearing your face.",
		},
		HEAD_EXPLODED = {
			"Your head burst open. There was nothing left to bury above the neck.",
			"Something inside your skull gave way. All at once.",
			"They found pieces of you on the walls.",
		},
		BLEEDING = {
			"You bled out. Nobody came to stop it.",
			"Your blood soaked into the ground. Then everything went quiet.",
		},
		FLESH = {
			"It ate you. You are still in there.",
			"The flesh does not let go of what it eats.",
		},
		LISTENER = {
			"It heard you breathing.",
			"You ran. It was the loudest thing in the cave.",
		},
		SPIDER = {
			"You walked into the web. It felt you struggling.",
			"Eight red eyes were the last thing you saw.",
			"It was waiting in the dark corner the whole time.",
		},
		SPIDERMOTHER = {
			"She was bigger than the door. She ate you slowly.",
			"Something small crawled out of her afterwards. It has your smell.",
			"The brood is fed.",
		},
		INFECTED = {
			"Someone you knew tore you apart. Their eyes were gone.",
			"The infected don't stop to talk.",
		},
		BEATEN = {
			"Beaten to death by another survivor.",
		},
		SHOT = {
			"Buckshot. You never saw who pulled the trigger.",
			"Somebody down here decided you were a threat.",
			"Shot. The echo went on longer than you did.",
		},
		ACID = {
			"C-310 spat. The acid ate through everything, then through you.",
			"You breathed it in. Your lungs gave up before your legs did.",
			"A gas mask would have bought you a minute. Maybe two.",
		},
		TRAP = {
			"The jaws closed on your leg. Something heard the snap.",
			"Someone set that trap for a monster. It caught you instead.",
		},
		UNKNOWN = {
			"Something found you first.",
			"Cause of death: unknown.",
		},
	},
	Epitaphs = {
		"the cave remembers you",
		"you were not the first",
		"something is still coming",
		"nobody came looking",
	},
}

local rng = Random.new()

local function create(className, props, children)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do obj[key] = value end
	for _, child in ipairs(children or {}) do child.Parent = obj end
	return obj
end

local function tween(object, time, props, style)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local gui = create("ScreenGui", {
	Name = "DeathScreen", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900,
	Enabled = false, Parent = player:WaitForChild("PlayerGui"),
})

local black = create("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 1, Parent = gui,
})
local redFlash = create("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 0, 0), BackgroundTransparency = 1,
	BorderSizePixel = 0, ZIndex = 20, Parent = gui,
})

local card = create("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(620, 470),
	BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 5, Parent = black,
})

-- shrink the record card on phones
do
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local function rescale()
		local camera = workspace.CurrentCamera
		if camera then scale.Scale = math.clamp(math.min((camera.ViewportSize.X - 16) / 620, (camera.ViewportSize.Y - 16) / 520), 0.45, 1) end
	end
	rescale()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end
end

local header = create("TextLabel", {
	Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "— RECORD OF DEATH —", TextSize = 14, TextColor3 = CONFIG.Dim, ZIndex = 6, Parent = card,
})
local titleShadow = create("TextLabel", {
	Position = UDim2.fromOffset(3, 30), Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "YOU DIED", TextSize = 72, TextColor3 = CONFIG.Red, TextTransparency = 0.35, ZIndex = 6, Parent = card,
})
local title = create("TextLabel", {
	Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "YOU DIED", TextSize = 72, TextColor3 = CONFIG.Ink, ZIndex = 7, Parent = card,
})
local nameLabel = create("TextLabel", {
	Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "", TextSize = 16, TextColor3 = CONFIG.Mid, ZIndex = 6, Parent = card,
})
create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.fromOffset(460, 1),
	BackgroundColor3 = CONFIG.Dim, BorderSizePixel = 0, ZIndex = 6, Parent = card,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
})})})
local causeLabel = create("TextLabel", {
	Position = UDim2.fromOffset(20, 154), Size = UDim2.new(1, -40, 0, 48), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "", TextSize = 20, TextWrapped = true, TextColor3 = CONFIG.Ink, ZIndex = 6, Parent = card,
})

local statsFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 214), Size = UDim2.fromOffset(440, 150),
	BackgroundTransparency = 1, ZIndex = 6, Parent = card,
}, {create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})})

local function statRow(order)
	local row = create("Frame", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = order, Parent = statsFrame})
	local key = create("TextLabel", {
		Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, Font = CONFIG.Font, Text = "", TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = CONFIG.Dim, ZIndex = 6, Parent = row,
	})
	local value = create("TextLabel", {
		Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, Font = CONFIG.Font,
		Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = CONFIG.Ink,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6, Parent = row,
	})
	create("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.fromRGB(30, 30, 29), BorderSizePixel = 0, ZIndex = 6, Parent = row,
	})
	return row, key, value
end
local statRows = {}
for i = 1, 6 do
	local row, key, value = statRow(i)
	statRows[i] = {row = row, key = key, value = value}
end

local epitaph = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(600, 20),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = "", TextSize = 14, TextColor3 = Color3.fromRGB(90, 20, 20),
	TextTransparency = 1, ZIndex = 6, Parent = black,
})

local question = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 378), Size = UDim2.fromOffset(600, 24),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = "try again?", TextSize = 20, TextColor3 = CONFIG.Mid,
	ZIndex = 6, Parent = card,
})

local buttonRow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 412), Size = UDim2.fromOffset(520, 44),
	BackgroundTransparency = 1, ZIndex = 6, Parent = card,
}, {create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 60),
})})

local busy = false
local buttonsEnabled = false

local function hideDeathInfo()
	card.Visible = false
	epitaph.Visible = false
	question.Visible = false
	buttonRow.Visible = false
end
local function showDeathInfo()
	card.Visible = true
	epitaph.Visible = true
	question.Visible = true
end

local function makeButton(text, callback)
	local button = create("TextButton", {
		Size = UDim2.fromOffset(200, 40), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 7,
		Parent = buttonRow,
	})
	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(0, 1),
		BackgroundColor3 = CONFIG.Red, BorderSizePixel = 0, ZIndex = 7, Parent = button,
	})
	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = CONFIG.Font, Text = text, TextSize = 24,
		TextColor3 = CONFIG.Mid, ZIndex = 8, Parent = button,
	})
	button.MouseEnter:Connect(function()
		if not buttonsEnabled then return end
		SoundConfig.PlayOnce("MenuHover", SoundService)
		label.Text = "> " .. text .. " <"
		tween(label, 0.15, {TextColor3 = Color3.fromRGB(235, 30, 30)})
		tween(bar, 0.2, {Size = UDim2.fromOffset(180, 1)})
	end)
	button.MouseLeave:Connect(function()
		label.Text = text
		tween(label, 0.2, {TextColor3 = CONFIG.Mid})
		tween(bar, 0.2, {Size = UDim2.fromOffset(0, 1)})
	end)
	button.Activated:Connect(function()
		if player:GetAttribute("InfectPending") then
			-- the flesh has you: nothing on this screen works any more
			SoundConfig.PlayOnce("FearHit", SoundService, {Volume = 0.5, PlaybackSpeed = rng:NextNumber(0.6, 0.8)})
			label.Text = "NO"
			label.TextColor3 = CONFIG.Red
			task.delay(0.35, function() label.Text = text label.TextColor3 = CONFIG.Mid end)
			return
		end
		if busy or not buttonsEnabled then return end
		busy = true
		SoundConfig.PlayOnce("MenuClick", SoundService)
		callback()
	end)
end

local life = {start = os.clock(), distance = 0, falls = 0, highestFall = 0}
local showing = false
local token = 0

local function formatTime(seconds)
	seconds = math.floor(seconds)
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local function typeText(label, text, speed, my, silent)
	label.Text = ""
	for i = 1, #text do
		if my ~= token then return end
		label.Text = string.sub(text, 1, i)
		local ch = string.sub(text, i, i)
		if ch ~= " " then
			task.wait(speed)
		end
	end
end

local function injuriesText(character)
	if not character then return "unknown" end
	if character:GetAttribute("Gibbed") then return "body torn apart" end
	local names = {Head = "skull", Torso = "spine", RightArm = "right arm", LeftArm = "left arm", RightLeg = "right leg", LeftLeg = "left leg"}
	local list = {}
	for _, key in ipairs({"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}) do
		local level = character:GetAttribute("Injury_" .. key) or 0
		if level >= 3 then
			table.insert(list, names[key] .. " torn off")
		elseif level == 2 then
			table.insert(list, "broken " .. names[key])
		end
	end
	return #list > 0 and table.concat(list, ", ") or "none recorded"
end

local function resolveCause(character)
	if not character then return "UNKNOWN" end
	if character:GetAttribute("Gibbed") then return "GIBBED" end
	local cause = character:GetAttribute("DeathCause")
	if cause and CONFIG.Causes[cause] then return cause end
	local last = character:GetAttribute("LastDamageCause")
	if last and CONFIG.Causes[last] then return last end
	return "UNKNOWN"
end

local function showDeath(character)
	if showing then return end
	showing = true
	token += 1
	local my = token
	busy = true
	buttonsEnabled = false
	local aliveFor = os.clock() - life.start

	gui.Enabled = true
	showDeathInfo()
	black.BackgroundTransparency = 1
	card.GroupTransparency = 1
	epitaph.TextTransparency = 1
	question.TextTransparency = 1
	buttonRow.Visible = false

	redFlash.BackgroundTransparency = 0.15
	SoundConfig.PlayOnce("Impact", SoundService, {PlaybackSpeed = 0.7, Volume = 0.9})
	SoundConfig.PlayOnce("FearHit", SoundService, {Volume = 0.7})
	task.delay(0.9, function()
		if my == token then SoundConfig.PlayOnce("DeathBoom", SoundService, {PlaybackSpeed = 0.85}) end
	end)
	tween(black, 0.9, {BackgroundTransparency = 0}, Enum.EasingStyle.Sine)
	tween(redFlash, 1.3, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine)
	task.wait(1.2)
	if my ~= token then return end

	title.TextTransparency = 0
	nameLabel.Text = string.format("%s  ·  @%s", player.DisplayName, player.Name)
	causeLabel.Text = ""
	for _, r in ipairs(statRows) do r.key.Text = "" r.value.Text = "" end
	tween(card, 0.8, {GroupTransparency = 0})
	task.spawn(function()
		while showing and my == token do
			title.Position = UDim2.fromOffset(rng:NextInteger(-1, 1), 28 + rng:NextInteger(-1, 1))
			titleShadow.Position = UDim2.fromOffset(3 + rng:NextInteger(-2, 2), 30)
			title.TextTransparency = rng:NextNumber() < 0.03 and 0.5 or 0
			task.wait(0.05)
		end
	end)
	task.wait(0.8)
	if my ~= token then return end

	local ok, cause, height = pcall(function()
		local key = resolveCause(character)
		local h = character and (character:GetAttribute("LastFallHeight") or 0) or 0
		return key, h
	end)
	if not ok then cause, height = "UNKNOWN", 0 end
	local variants = CONFIG.Causes[cause] or CONFIG.Causes.UNKNOWN
	local text = variants[rng:NextInteger(1, #variants)]
	if string.find(text, "%%d") then text = string.format(text, height) end
	typeText(causeLabel, text, 0.028, my)
	task.wait(0.3)
	if my ~= token then return end

	local okStats, rows = pcall(function()
		local bloodLost = character and (character:GetAttribute("BloodLost") or 0) or 0
		local highest = math.max(life.highestFall, (cause == "FALL" or cause == "GIBBED") and height or 0)
		return {
			{"time survived", formatTime(aliveFor)},
			{"distance walked", string.format("%d studs", math.floor(life.distance))},
			{"falls survived", tostring(life.falls)},
			{"highest fall", string.format("%d studs", math.floor(highest))},
			{"blood lost", string.format("%d%%", math.clamp(math.floor(bloodLost), 0, 100))},
			{"injuries", injuriesText(character)},
		}
	end)
	if not okStats then
		rows = {{"time survived", formatTime(aliveFor)}}
	end
	for i, r in ipairs(statRows) do
		local data = rows[i]
		r.row.Visible = data ~= nil
		if data then
			r.key.Text = data[1]
			SoundConfig.PlayOnce(SoundConfig.Random("TapeClick"), SoundService, {Volume = 0.3, PlaybackSpeed = rng:NextNumber(1, 1.2)})
			typeText(r.value, data[2], 0.015, my, true)
			if my ~= token then return end
		end
	end

	local infected = player:GetAttribute("InfectPending") == true
	epitaph.Text = infected and "KILL THE SURVIVORS" or CONFIG.Epitaphs[rng:NextInteger(1, #CONFIG.Epitaphs)]
	question.Text = infected and "THE FLESH IS YOUR MASTER" or "try again?"
	question.TextColor3 = infected and CONFIG.Red or CONFIG.Mid
	tween(epitaph, 2, {TextTransparency = 0.2})
	task.wait(0.4)
	if my ~= token then return end
	tween(question, 0.8, {TextTransparency = 0})
	buttonRow.Visible = true
	buttonsEnabled = true
	busy = false
end

local rewind = create("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 6, 8), BackgroundTransparency = 1,
	BorderSizePixel = 0, ZIndex = 30, Visible = false, Parent = gui,
})
local rewindLines = {}
for i = 1, 18 do
	rewindLines[i] = create("Frame", {
		Size = UDim2.new(1, 0, 0, rng:NextInteger(2, 7)), BackgroundColor3 = Color3.fromRGB(210, 210, 215),
		BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 31, Parent = rewind,
	})
end
local rewindGrain = {}
for i = 1, 90 do
	rewindGrain[i] = create("Frame", {
		Size = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 31, Parent = rewind,
	})
end
local rewindLabel = create("TextLabel", {
	Position = UDim2.fromOffset(48, 40), Size = UDim2.fromOffset(300, 34), BackgroundTransparency = 1,
	Font = CONFIG.Font, Text = "◄◄ REWIND", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(230, 230, 225), ZIndex = 32, Parent = rewind,
})
local rewindCounter = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -48, 0, 44), Size = UDim2.fromOffset(240, 28),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = "", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(230, 230, 225), ZIndex = 32, Parent = rewind,
})
local rewinding = false
local rewindSound = nil

local function startRewind(aliveFor)
	rewinding = true
	rewind.Visible = true
	rewind.BackgroundTransparency = 0
	rewindLabel.Text = "◄◄ REWIND"
	rewindSound = SoundConfig.Make("TapeRewind", SoundService, {Looped = true})
	rewindSound:Play()
	local counter = aliveFor
	task.spawn(function()
		while rewinding do
			counter = math.max(0, counter - rng:NextNumber(3, 9))
			local sec = math.floor(counter)
			rewindCounter.Text = string.format("%02d:%02d:%02d", sec // 3600, (sec // 60) % 60, sec % 60)
			for _, line in ipairs(rewindLines) do
				line.Position = UDim2.fromScale(0, rng:NextNumber())
				line.BackgroundTransparency = rng:NextNumber(0.55, 0.9)
			end
			for _, dot in ipairs(rewindGrain) do
				dot.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
				dot.BackgroundTransparency = rng:NextNumber(0.3, 0.9)
			end
			rewindLabel.TextTransparency = (os.clock() % 0.6) < 0.3 and 0 or 0.4
			task.wait(0.04)
		end
	end)
end

local function stopRewind()
	if not rewinding then return end
	rewinding = false
	if rewindSound then
		local s = rewindSound
		rewindSound = nil
		tween(s, 0.3, {Volume = 0})
		task.delay(0.35, function() s:Destroy() end)
	end
	SoundConfig.PlayOnce(SoundConfig.Random("TapeClick"), SoundService, {Volume = 0.6})
	rewindLabel.Text = "PLAY ►"
	rewindLabel.TextTransparency = 0
	rewindCounter.Text = "00:00:00"
	for _, line in ipairs(rewindLines) do line.BackgroundTransparency = 1 end
	task.delay(0.3, function()
		if rewinding then return end
		rewind.Visible = false
		rewind.BackgroundTransparency = 0
		rewindCounter.TextTransparency = 0
	end)
end

makeButton("TRY AGAIN", function()
	buttonsEnabled = false
	SoundConfig.PlayOnce(SoundConfig.Random("TapeClick"), SoundService, {Volume = 0.6})
	startRewind(os.clock() - life.start)
	hideDeathInfo()
	card.GroupTransparency = 1
	epitaph.TextTransparency = 1
	question.TextTransparency = 1
	buttonRow.Visible = false
	task.delay(0.4, function()
		spawnRequest:FireServer()
	end)
	task.delay(10, function()
		if showing then
			stopRewind()
			busy = false
			buttonsEnabled = true
			showDeathInfo()
			buttonRow.Visible = true
			tween(card, 0.4, {GroupTransparency = 0})
		end
	end)
end)

makeButton("MAIN MENU", function()
	SoundConfig.PlayOnce(SoundConfig.Random("TapeClick"), SoundService, {Volume = 0.6})
	showing = false
	token += 1
	hideDeathInfo()
	gui.Enabled = false
	busy = false
	player:SetAttribute("OpenMenu", os.clock())
end)

local function onCharacter(character)
	life = {start = os.clock(), distance = 0, falls = 0, highestFall = 0}
	if showing then
		showing = false
		token += 1
		local my = token
		buttonsEnabled = false
		hideDeathInfo()
		black.BackgroundTransparency = 0
		card.GroupTransparency = 1
		epitaph.TextTransparency = 1
		question.TextTransparency = 1
		stopRewind()
		task.delay(0.35, function()
			if my ~= token then return end
			TweenService:Create(black, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 1}):Play()
		end)
		task.delay(2, function()
			if my ~= token then return end
			if not showing then gui.Enabled = false end
			busy = false
		end)
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then return end

	local lastPosition = root.Position
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not root.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			return
		end
		local delta = root.Position - lastPosition
		lastPosition = root.Position
		local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if horizontal < 5 and humanoid.FloorMaterial ~= Enum.Material.Air then
			life.distance += horizontal
		end
	end)

	character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		if character:GetAttribute("Ragdolled") and humanoid.Health > 0 then
			life.falls += 1
		end
	end)
	character:GetAttributeChangedSignal("LastFallHeight"):Connect(function()
		life.highestFall = math.max(life.highestFall, character:GetAttribute("LastFallHeight") or 0)
	end)

	humanoid.Died:Connect(function()
		task.spawn(showDeath, character)
	end)
end

if player.Character then task.spawn(onCharacter, player.Character) end
player.CharacterAdded:Connect(onCharacter)

local resetRemote = ReplicatedStorage:WaitForChild("ResetRequest", 20)
if resetRemote then
	local StarterGui = game:GetService("StarterGui")
	local resetEvent = Instance.new("BindableEvent")
	resetEvent.Event:Connect(function()
		resetRemote:FireServer()
	end)
	task.spawn(function()
		for _ = 1, 30 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", resetEvent)
			end)
			if ok then break end
			task.wait(1)
		end
	end)
end
