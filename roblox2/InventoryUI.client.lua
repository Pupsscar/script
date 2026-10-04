-- The bag, as a wheel. Same look as the rest of the game: black cards, thin frames, typewriter type, blood red.
--   Q (hold)     open the wheel; point at an item and let go to take it (or wear it / take it off)
--   Q (tap)      open it and click: LMB take in hand / wear / take off, RMB drop it on the ground for someone else
--   centre       put away what's in your hand
--   H            put away, G drop what's in your hand
--   touch        the BAG button opens it; tap an item, then the buttons in the middle
-- Holding a medical item, LMB (or USE) starts a short mini-game: hit the green arc when the needle crosses it.
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemData = require(Modules:WaitForChild("ItemData"))
local ShopModels = require(Modules:WaitForChild("ShopModels"))
local SoundConfig = require(Modules:WaitForChild("SoundConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local invRemote = ReplicatedStorage:WaitForChild("GS_Inventory", 60)
local syncRemote = ReplicatedStorage:WaitForChild("GS_InvSync", 60)
local itemFx = ReplicatedStorage:WaitForChild("GS_ItemFX", 60)
if not invRemote or not syncRemote then return end

local clientAction = player:WaitForChild("GS_ClientAction", 30)

local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local FONT = Enum.Font.SpecialElite
local INK = Color3.fromRGB(236, 230, 222)
local MID = Color3.fromRGB(190, 184, 178)
local DIM = Color3.fromRGB(120, 112, 106)
local LINE = Color3.fromRGB(70, 60, 56)
local PANEL = Color3.fromRGB(8, 6, 6)
local BLOOD = Color3.fromRGB(150, 12, 16)
local BRIGHT = Color3.fromRGB(225, 40, 40)
local AMBER = Color3.fromRGB(232, 164, 52)
local GREEN = Color3.fromRGB(110, 200, 90)

local SLOTS = ItemData.MaxSlots
local RADIUS = 200
local CARD = 78

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
local function sfx(name, volume, speed)
	pcall(function() SoundConfig.PlayOnce(name, SoundService, {Volume = volume or 0.4, PlaybackSpeed = speed or 1}) end)
end
local function itemSound(name, volume, speed)
	local id = ItemData.Sound(name)
	if not id then return end
	local s = create("Sound", {SoundId = id, Volume = volume or 0.5, PlaybackSpeed = speed or 1, Parent = SoundService})
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	task.delay(6, function() if s.Parent then s:Destroy() end end)
end

-- ===== state from the server =====
local bag = {items = {}, weight = 0, speed = 1, max = SLOTS}
local function entryByUid(uid)
	for _, e in ipairs(bag.items) do
		if e.uid == uid then return e end
	end
	return nil
end
local function heldEntry()
	return bag.held and entryByUid(bag.held) or nil
end

local function ask(action, ...)
	local args = table.pack(...)
	local ok, a, b = pcall(function() return invRemote:InvokeServer(action, table.unpack(args, 1, args.n)) end)
	if not ok then return false end
	return a, b
end

-- ===== the wheel =====
local gui = create("ScreenGui", {
	Name = "GS_ItemWheel", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 45, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
})
local shade = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = gui})
local wheel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(RADIUS * 2 + CARD + 20, RADIUS * 2 + CARD + 20),
	BackgroundTransparency = 1, Parent = gui,
})
local wheelScale = create("UIScale", {Parent = wheel})
-- a faint ring the cards sit on
create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(RADIUS * 2, RADIUS * 2),
	BackgroundTransparency = 1, Parent = wheel,
}, {
	create("UICorner", {CornerRadius = UDim.new(1, 0)}),
	create("UIStroke", {Color = LINE, Thickness = 1, Transparency = 0.3}),
})

-- the centre: the pointed-at item, or the load you carry
local center = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(250, 250),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, Parent = wheel,
}, {
	create("UICorner", {CornerRadius = UDim.new(1, 0)}),
	create("UIStroke", {Color = BLOOD, Thickness = 1.5}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 6, 6), Color3.fromRGB(0, 0, 0))}),
})
local function label(parent, props)
	local base = {BackgroundTransparency = 1, Font = FONT, TextColor3 = INK, TextSize = 14, Parent = parent}
	for k, v in pairs(props) do base[k] = v end
	return create("TextLabel", base)
end
local cName = label(center, {Position = UDim2.fromOffset(20, 40), Size = UDim2.fromOffset(210, 26), TextSize = 20, TextWrapped = true})
local cKind = label(center, {Position = UDim2.fromOffset(20, 68), Size = UDim2.fromOffset(210, 16), TextSize = 12, TextColor3 = DIM})
local cInfo = label(center, {Position = UDim2.fromOffset(30, 88), Size = UDim2.fromOffset(190, 64), TextSize = 12, TextColor3 = MID,
	TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
local durBack = create("Frame", {
	Position = UDim2.fromOffset(45, 156), Size = UDim2.fromOffset(160, 6), BackgroundColor3 = Color3.fromRGB(40, 12, 12),
	BorderSizePixel = 0, Parent = center,
})
local durFill = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0, Parent = durBack})
local durText = label(center, {Position = UDim2.fromOffset(45, 164), Size = UDim2.fromOffset(160, 14), TextSize = 11, TextColor3 = DIM})
local cHint = label(center, {Position = UDim2.fromOffset(20, 184), Size = UDim2.fromOffset(210, 30), TextSize = 12, TextColor3 = BRIGHT,
	TextWrapped = true})
local cLoad = label(center, {Position = UDim2.fromOffset(20, 214), Size = UDim2.fromOffset(210, 16), TextSize = 11, TextColor3 = DIM})

-- touch: action buttons in the middle once an item is tapped
local touchBar = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 186), Size = UDim2.fromOffset(220, 30),
	BackgroundTransparency = 1, Visible = false, Parent = center,
}, {create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6)})})
local function touchButton(text, width)
	return create("TextButton", {
		Size = UDim2.fromOffset(width, 30), BackgroundColor3 = Color3.fromRGB(18, 8, 8), AutoButtonColor = true, Font = FONT,
		Text = text, TextSize = 14, TextColor3 = INK, Parent = touchBar,
	}, {create("UIStroke", {Color = BLOOD, Thickness = 1})})
end
local primaryBtn = touchButton("TAKE", 110)
local dropBtn = touchButton("DROP", 90)

-- the twelve cards
local cards = {}
for i = 1, SLOTS do
	local angle = math.rad(-90 + (i - 1) * (360 / SLOTS))
	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(CARD, CARD), BackgroundColor3 = Color3.fromRGB(12, 11, 11),
		BackgroundTransparency = 0.05, BorderSizePixel = 0,
		Position = UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS), Parent = wheel,
	}, {create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 30, 30), Color3.fromRGB(6, 6, 6))})})
	local stroke = create("UIStroke", {Color = LINE, Thickness = 1, Parent = holder})
	local scale = create("UIScale", {Parent = holder})
	local view = create("ViewportFrame", {
		Size = UDim2.new(1, -8, 1, -22), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(125, 115, 110), LightColor = Color3.fromRGB(255, 236, 222), LightDirection = Vector3.new(-0.6, -1, -0.4),
		Parent = holder,
	})
	local cam = create("Camera", {FieldOfView = 30, Parent = view})
	view.CurrentCamera = cam
	local nameText = label(holder, {Position = UDim2.new(0, 3, 1, -18), Size = UDim2.new(1, -6, 0, 16), TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = MID})
	local count = label(holder, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(40, 14),
		TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right})
	local tag = label(holder, {Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(50, 14), TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = AMBER})
	local dur = create("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -18), Size = UDim2.new(1, -8, 0, 3),
		BackgroundColor3 = GREEN, BorderSizePixel = 0, Visible = false, Parent = holder,
	})
	cards[i] = {holder = holder, stroke = stroke, scale = scale, view = view, cam = cam, name = nameText, count = count, tag = tag,
		dur = dur, angle = angle, id = nil}
end

local function durColor(frac)
	if frac > 0.6 then return GREEN end
	if frac > 0.3 then return AMBER end
	return BRIGHT
end

local function setView(card, id)
	if card.id == id then return end
	card.id = id
	for _, c in ipairs(card.view:GetChildren()) do
		if c:IsA("Model") then c:Destroy() end
	end
	if not id then return end
	local model = ShopModels.Build(id)
	model.Parent = card.view
	local cf, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot())
	local radius = size.Magnitude / 2
	card.cam.CFrame = CFrame.lookAt(Vector3.new(radius * 0.5, radius * 0.45, -radius / math.tan(math.rad(15)) * 1.05), Vector3.zero)
end

local hovered = nil -- card index
local picked = nil -- touch: the tapped card

local function actionFor(e)
	local item = e and ItemData.Get(e.id)
	if not item then return nil end
	if item.kind == "armor" then return e.worn and "TAKE OFF" or "WEAR" end
	if item.kind == "ammo" then return nil end
	if bag.held == e.uid then return "PUT AWAY" end
	return "TAKE"
end

local function describe(e)
	local item = e and ItemData.Get(e.id)
	durBack.Visible, durText.Visible = false, false
	touchBar.Visible = false
	if not item then
		local h = heldEntry()
		local hi = h and ItemData.Get(h.id)
		cName.Text = hi and ("IN HAND: " .. hi.name) or "YOUR BAG"
		cKind.Text = string.format("%d / %d slots", #bag.items, bag.max or SLOTS)
		cInfo.Text = hi and "point at the middle and click to put it away" or "point at something"
		cHint.Text = TOUCH and "" or (hi and "[LMB] PUT AWAY" or "")
		return
	end
	cName.Text = item.name
	local kinds = {melee = "MELEE", gun = "FIREARM", heal = "MEDICAL", light = "LIGHT", armor = "ARMOR", ammo = "AMMUNITION", trap = "TRAP"}
	local kindText = kinds[item.kind] or ""
	if item.kind == "armor" then
		local slots = {}
		for _, s in ipairs(item.slots or {}) do table.insert(slots, ItemData.SlotNames[s] or s) end
		kindText = kindText .. "  -  " .. table.concat(slots, " + ") .. (e.worn and "  -  WORN" or "")
	end
	cKind.Text = kindText .. string.format("  -  %.1f kg", item.weight * (item.stack > 1 and e.n or 1))
	local info = item.desc or ""
	if item.kind == "gun" then
		info = string.format("%d / %d loaded, %d spare. ", e.ammo or 0, item.magazine, 0) .. info
		local spare = 0
		for _, other in ipairs(bag.items) do
			if other.id == item.ammo then spare += other.n end
		end
		info = string.format("%d / %d loaded  -  %d spare\n", e.ammo or 0, item.magazine, spare) .. (item.desc or "")
	elseif item.kind == "melee" then
		info = string.format("%d damage%s\n", item.damage, item.stun and " + shock" or (item.bleed and " + bleeding" or "")) .. info
	elseif e.n > 1 then
		info = "x" .. e.n .. "\n" .. info
	end
	cInfo.Text = info
	if item.kind == "armor" and e.dur and item.durability then
		local frac = math.clamp(e.dur / item.durability, 0, 1)
		durBack.Visible, durText.Visible = true, true
		durFill.Size = UDim2.fromScale(frac, 1)
		durFill.BackgroundColor3 = durColor(frac)
		durText.Text = string.format("DURABILITY %d%%%s", math.floor(frac * 100 + 0.5), item.fragile and "  -  fragile" or "")
	end
	local action = actionFor(e)
	if TOUCH then
		cHint.Text = ""
		touchBar.Visible = picked ~= nil
		primaryBtn.Visible = action ~= nil
		primaryBtn.Text = action or ""
	else
		cHint.Text = (action and ("[LMB] " .. action .. "   ") or "") .. "[RMB] DROP"
	end
end

local function refreshCards()
	for i, card in ipairs(cards) do
		local e = bag.items[i]
		setView(card, e and e.id or nil)
		local item = e and ItemData.Get(e.id)
		card.name.Text = item and item.name or ""
		card.count.Text = (e and e.n > 1) and ("x" .. e.n) or ""
		if item and item.kind == "gun" then card.count.Text = string.format("%d/%d", e.ammo or 0, item.magazine) end
		card.tag.Text = e and (e.worn and "WORN" or (bag.held == e.uid and "HAND" or "")) or ""
		card.tag.TextColor3 = e and e.worn and BRIGHT or AMBER
		card.holder.BackgroundTransparency = e and 0.05 or 0.55
		card.dur.Visible = item ~= nil and item.kind == "armor" and e.dur ~= nil
		if card.dur.Visible then
			local frac = math.clamp(e.dur / item.durability, 0, 1)
			card.dur.Size = UDim2.new(frac, -8 * frac, 0, 3)
			card.dur.BackgroundColor3 = durColor(frac)
		end
	end
	cLoad.Text = string.format("LOAD %.1f kg  -  speed %d%%", bag.weight or 0, math.floor((bag.speed or 1) * 100 + 0.5))
	cLoad.TextColor3 = (bag.speed or 1) < 0.85 and BRIGHT or DIM
end

local function setHovered(i)
	if hovered == i then return end
	if hovered and cards[hovered] then
		tween(cards[hovered].scale, 0.12, {Scale = 1})
		cards[hovered].stroke.Color = LINE
		cards[hovered].stroke.Thickness = 1
	end
	hovered = i
	if i and cards[i] then
		tween(cards[i].scale, 0.12, {Scale = 1.14}, Enum.EasingStyle.Back)
		cards[i].stroke.Color = INK
		cards[i].stroke.Thickness = 1.5
		if bag.items[i] then sfx(SoundConfig.Random("TapeClick"), 0.18, 1.3) end
	end
	describe(i and bag.items[i] or nil)
end

-- ===== open / close =====
local isOpen = false
local openedAt = 0
local heldQ = false
local function fit()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local size = camera.ViewportSize
	wheelScale.Scale = math.clamp(math.min(size.X, size.Y) / (RADIUS * 2 + CARD + 60), 0.45, 1)
end

local function canOpen()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0 and not player:GetAttribute("InMenu") and not c:GetAttribute("Infected")
		and not (player:GetAttribute("UIOpen") and not isOpen)
end

local function setOpen(value)
	if value == isOpen then return end
	if value and not canOpen() then return end
	isOpen = value
	player:SetAttribute("UIOpen", value)
	player:SetAttribute("GS_WheelOpen", value)
	if value then
		openedAt = os.clock()
		fit()
		refreshCards()
		picked = nil
		setHovered(nil)
		gui.Enabled = true
		shade.BackgroundTransparency = 1
		tween(shade, 0.2, {BackgroundTransparency = 0.45})
		wheelScale.Scale *= 0.9
		local target = wheelScale.Scale / 0.9
		tween(wheelScale, 0.22, {Scale = target}, Enum.EasingStyle.Back)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		sfx(SoundConfig.Random("TapeClick"), 0.35)
		itemSound("Cloth", 0.25, 1.3)
	else
		gui.Enabled = false
		setHovered(nil)
		picked = nil
	end
end

-- ===== actions =====
local toastLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -140), Size = UDim2.fromOffset(500, 24),
	BackgroundTransparency = 1, Font = FONT, TextSize = 18, TextColor3 = INK, TextStrokeTransparency = 0.4, TextTransparency = 1,
	Parent = create("ScreenGui", {Name = "GS_ItemToast", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 44, Parent = playerGui}),
})
local toastToken = 0
local function toast(text, color)
	toastToken += 1
	local my = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or INK
	toastLabel.TextTransparency = 0
	task.delay(1.8, function()
		if my == toastToken then tween(toastLabel, 0.5, {TextTransparency = 1}) end
	end)
end

local function primary(e)
	local item = e and ItemData.Get(e.id)
	if not item then
		if bag.held then
			ask("holster")
			sfx("MenuClick", 0.35)
		end
		return
	end
	if item.kind == "armor" then
		local ok, why = ask(e.worn and "unwear" or "wear", e.uid)
		if ok then
			itemSound(item.set == "scg" and "Plate" or "Cloth", 0.5)
			toast((e.worn and "took off " or "put on ") .. item.name, AMBER)
		elseif why then toast(tostring(why), BRIGHT) end
	elseif item.kind == "ammo" then
		toast("load it: take the gun and press R", DIM)
	elseif bag.held == e.uid then
		ask("holster")
	else
		local ok, why = ask("equip", e.uid)
		if not ok and why then toast(tostring(why), BRIGHT) end
	end
end

local function drop(e)
	if not e then return end
	local item = ItemData.Get(e.id)
	local ok = ask("drop", e.uid)
	if ok then
		toast("dropped " .. (item and item.name or "it") .. " - anyone can pick it up", DIM)
		sfx(SoundConfig.Random("TapeClick"), 0.3, 0.8)
	end
end

primaryBtn.Activated:Connect(function()
	local e = picked and bag.items[picked]
	primary(e)
	setOpen(false)
end)
dropBtn.Activated:Connect(function()
	local e = picked and bag.items[picked]
	drop(e)
	setOpen(false)
end)

-- which card the pointer is over (or the centre)
local function pointerIndex(pos)
	local abs = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
	local offset = pos - abs
	local r = offset.Magnitude / math.max(wheelScale.Scale, 0.1)
	if r < 125 then return 0 end
	if r > RADIUS + CARD then return nil end
	local angle = math.deg(math.atan2(offset.Y, offset.X)) + 90
	angle = (angle + 360 / SLOTS / 2) % 360
	return math.floor(angle / (360 / SLOTS)) + 1
end

UserInputService.InputBegan:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Q and not processed then
		if isOpen then
			setOpen(false)
		else
			heldQ = true
			setOpen(true)
		end
		return
	end
	if not isOpen then
		if processed then return end
		if input.KeyCode == Enum.KeyCode.H and bag.held then
			ask("holster")
		elseif input.KeyCode == Enum.KeyCode.G and bag.held then
			drop(heldEntry())
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		setOpen(false)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not TOUCH then
		local i = pointerIndex(UserInputService:GetMouseLocation())
		if i == 0 then
			primary(nil)
			setOpen(false)
		elseif i and bag.items[i] then
			primary(bag.items[i])
			setOpen(false)
		elseif not i then
			setOpen(false)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not TOUCH then
		local i = pointerIndex(UserInputService:GetMouseLocation())
		if i and i > 0 and bag.items[i] then
			drop(bag.items[i])
			setOpen(false)
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		local i = pointerIndex(Vector2.new(input.Position.X, input.Position.Y))
		if i == 0 then
			if not picked then
				primary(nil)
				setOpen(false)
			end
		elseif i and bag.items[i] then
			picked = i
			setHovered(nil)
			setHovered(i)
		elseif not i then
			setOpen(false)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.Q or not heldQ then return end
	heldQ = false
	-- a hold: letting go picks what the pointer is on. A quick tap leaves the wheel open for clicking.
	if isOpen and os.clock() - openedAt > 0.3 then
		local i = pointerIndex(UserInputService:GetMouseLocation())
		if i == 0 then
			primary(nil)
		elseif i and bag.items[i] then
			primary(bag.items[i])
		end
		setOpen(false)
	end
end)

if clientAction then
	clientAction.Event:Connect(function(action)
		if action == "inventory" then
			setOpen(not isOpen)
		elseif action == "away" and bag.held then
			ask("holster")
		end
	end)
end

RunService.RenderStepped:Connect(function()
	if not isOpen then return end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	if not canOpen() and isOpen then
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 then setOpen(false) return end
	end
	if not TOUCH then
		local i = pointerIndex(UserInputService:GetMouseLocation())
		setHovered((i and i > 0 and bag.items[i]) and i or nil)
	end
	-- the hovered item turns slowly
	local card = hovered and cards[hovered]
	if card then
		local model = card.view:FindFirstChildOfClass("Model")
		if model then model:PivotTo(CFrame.Angles(0, os.clock() * 0.8, 0) * CFrame.new(model:GetPivot().Position)) end
	end
end)

-- ===== the heal mini-game =====
local mg = create("ScreenGui", {
	Name = "GS_HealGame", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 46, Enabled = false, Parent = playerGui,
})
local mgCard = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(250, 270),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.08, Parent = mg,
}, {
	create("UIStroke", {Color = BLOOD, Thickness = 1.5}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 6, 6), Color3.fromRGB(0, 0, 0))}),
})
local mgScale = create("UIScale", {Parent = mgCard})
local mgTitle = label(mgCard, {Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 22), TextSize = 18})
local mgSub = label(mgCard, {Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = DIM})
local DIAL = 150
local dial = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(DIAL, DIAL),
	BackgroundTransparency = 1, Parent = mgCard,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)}), create("UIStroke", {Color = LINE, Thickness = 2})})
-- the green arc: a row of small dots around the dial
local zoneDots = {}
for i = 1, 14 do
	zoneDots[i] = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = GREEN, BorderSizePixel = 0, Parent = dial,
	}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
end
local needle = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, DIAL / 2 - 4),
	BackgroundColor3 = BRIGHT, BorderSizePixel = 0, Parent = dial,
})
create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
	BackgroundColor3 = INK, BorderSizePixel = 0, Parent = dial,
}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
local mgDots = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 214), Size = UDim2.fromOffset(200, 12), BackgroundTransparency = 1,
	Parent = mgCard,
}, {create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8)})})
local mgHint = label(mgCard, {Position = UDim2.fromOffset(10, 236), Size = UDim2.new(1, -20, 0, 20), TextSize = 12, TextColor3 = BRIGHT,
	Text = TOUCH and "TAP when the needle is in the green" or "[LMB] / [SPACE] when the needle is in the green"})

local GAMES = {
	wrap = {title = "WRAP THE WOUND", sub = "keep the bandage tight", hits = 3, zone = 60, speed = 260},
	set = {title = "SET THE BONE", sub = "straighten it, then tie it", hits = 2, zone = 44, speed = 200},
	stitch = {title = "CLEAN AND STITCH", sub = "steady hands", hits = 4, zone = 50, speed = 300},
	none = {title = "", sub = "", hits = 0},
}

local game_ = nil
local function hitDots(n, needed)
	for _, c in ipairs(mgDots:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for i = 1, needed do
		create("Frame", {
			Size = UDim2.fromOffset(12, 12), BackgroundColor3 = i <= n and GREEN or Color3.fromRGB(40, 36, 34), BorderSizePixel = 0,
			Parent = mgDots,
		}, {create("UICorner", {CornerRadius = UDim.new(1, 0)})})
	end
end

local function placeZone()
	local g = game_
	g.zoneAt = math.random(0, 359)
	for i, dot in ipairs(zoneDots) do
		local a = math.rad(g.zoneAt - g.def.zone / 2 + (i - 1) * g.def.zone / (#zoneDots - 1) - 90)
		dot.Position = UDim2.new(0.5, math.cos(a) * (DIAL / 2 - 10), 0.5, math.sin(a) * (DIAL / 2 - 10))
	end
end

local function endGame(cancelled)
	local g = game_
	if not g then return end
	game_ = nil
	mg.Enabled = false
	player:SetAttribute("GS_Minigame", nil)
	if cancelled then
		ask("usecancel")
		return
	end
	local quality = g.def.hits > 0 and math.clamp(g.hits / g.def.hits - g.misses * 0.12, 0, 1) or 1
	-- a real hand can't do it faster than the item takes
	local waitMore = g.useTime * 0.7 - (os.clock() - g.started)
	if waitMore > 0 then task.wait(waitMore) end
	local ok = ask("usefinish", g.uid, quality)
	local item = ItemData.Get(g.id)
	if ok then
		toast((item and item.name or "done") .. (quality >= 0.8 and " - done right" or (quality >= 0.4 and " - it'll hold" or " - sloppy")),
			quality >= 0.4 and GREEN or AMBER)
	end
end

local function startGame(e)
	local item = ItemData.Get(e.id)
	local ok, useTime = ask("usebegin", e.uid)
	if not ok then return end
	local def = GAMES[item.game or "none"] or GAMES.none
	game_ = {uid = e.uid, id = e.id, def = def, hits = 0, misses = 0, angle = 0, started = os.clock(), useTime = useTime or item.useTime}
	player:SetAttribute("GS_Minigame", true)
	if item.sound == "spray" then itemSound("Spray", 0.4) elseif item.sound == "pills" then itemSound("Rattle", 0.4, 1.6)
	else itemSound("Cloth", 0.45) end
	if def.hits == 0 then
		-- pills and the shot: just a moment
		mg.Enabled = true
		mgTitle.Text = item.name
		mgSub.Text = "..."
		dial.Visible = false
		mgDots.Visible = false
		mgHint.Text = ""
		task.delay(game_.useTime, function() endGame(false) end)
		return
	end
	dial.Visible = true
	mgDots.Visible = true
	mgHint.Text = TOUCH and "TAP when the needle is in the green" or "[LMB] / [SPACE] when the needle is in the green"
	mgTitle.Text = def.title
	mgSub.Text = def.sub
	hitDots(0, def.hits)
	placeZone()
	mg.Enabled = true
	mgScale.Scale = 0.85
	tween(mgScale, 0.2, {Scale = 1}, Enum.EasingStyle.Back)
end

local function press()
	local g = game_
	if not g or g.def.hits == 0 then return end
	local diff = math.abs(((g.angle - g.zoneAt) + 180) % 360 - 180)
	if diff <= g.def.zone / 2 then
		g.hits += 1
		itemSound(g.id == "medkit" and "Spray" or "Cloth", 0.35, 1 + g.hits * 0.08)
		hitDots(g.hits, g.def.hits)
		if g.hits >= g.def.hits then
			endGame(false)
			return
		end
		placeZone()
	else
		g.misses += 1
		sfx("FearHit", 0.15, 1.8)
		mgCard.Position = UDim2.new(0.5, 6, 0.62, 0)
		tween(mgCard, 0.15, {Position = UDim2.new(0.5, 0, 0.62, 0)})
	end
end

RunService.RenderStepped:Connect(function(dt)
	local g = game_
	if not g or g.def.hits == 0 then return end
	g.angle = (g.angle + g.def.speed * dt) % 360
	needle.Rotation = g.angle
	-- too long: the game ends by itself (worse result)
	if os.clock() - g.started > g.useTime * 3 then endGame(false) end
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 or c:GetAttribute("Ragdolled") then endGame(true) end
end)

-- ===== using what's in the hand (LMB / USE button) =====
local function useHeld()
	if isOpen or game_ then
		if game_ then press() end
		return
	end
	local e = heldEntry()
	local item = e and ItemData.Get(e.id)
	if not item then return end
	if item.kind == "heal" then
		startGame(e)
	elseif item.kind == "light" then
		if ask("usebegin", e.uid) then itemSound("Sizzle", 0.5, 1.2) toast("the flare hisses into light", AMBER) end
	elseif item.kind == "trap" then
		if ask("usebegin", e.uid) then itemSound("TrapSet", 0.6) toast("trap set - keep your feet out of it", AMBER) end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space and game_ then
		if input.KeyCode == Enum.KeyCode.Space and not game_ then return end
		local e = heldEntry()
		local item = e and ItemData.Get(e.id)
		if game_ or (item and (item.kind == "heal" or item.kind == "light" or item.kind == "trap")) then useHeld() end
	elseif input.UserInputType == Enum.UserInputType.Touch and game_ then
		press()
	elseif input.KeyCode == Enum.KeyCode.Escape and game_ then
		endGame(true)
	end
end)
if clientAction then
	clientAction.Event:Connect(function(action)
		if action == "use" then
			local e = heldEntry()
			local item = e and ItemData.Get(e.id)
			if game_ or (item and (item.kind == "heal" or item.kind == "light" or item.kind == "trap")) then useHeld() end
		end
	end)
end

-- ===== the server's word =====
syncRemote.OnClientEvent:Connect(function(snap)
	if typeof(snap) ~= "table" then return end
	bag = snap
	local e = heldEntry()
	local item = e and ItemData.Get(e.id)
	player:SetAttribute("GS_HeldKind", item and item.kind or nil)
	player:SetAttribute("GS_HeldId", item and item.id or nil)
	if isOpen then
		refreshCards()
		describe(hovered and bag.items[hovered] or (picked and bag.items[picked]) or nil)
	end
	if game_ and not entryByUid(game_.uid) then
		game_ = nil
		mg.Enabled = false
	end
end)
if itemFx then
	itemFx.OnClientEvent:Connect(function(kind, a)
		if kind == "toast" then toast(tostring(a), BRIGHT) end
	end)
end
task.spawn(function() ask("get") end)

player.CharacterAdded:Connect(function()
	setOpen(false)
	if game_ then
		game_ = nil
		mg.Enabled = false
	end
end)
