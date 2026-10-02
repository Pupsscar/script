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
-- a fixed-height box with the cards stacked from its BOTTOM edge: more cards grow the stack upward, wherever the
-- panel was moved to, and it never runs off the bottom of the screen
local PANEL_W, PANEL_H = 230, 420
local abilityPanel = create("Frame", {
	Name = "Abilities", Size = UDim2.fromOffset(PANEL_W, PANEL_H), BackgroundTransparency = 1, Parent = gui, Visible = false,
})
create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = abilityPanel})

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
local KEY_RIM = Color3.fromRGB(200, 192, 184)
local function card(order, key, name, desc, id)
	-- calm and compact: a dark strip, a small key chip with a light rim, the action and a short hint
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = STYLE.Panel, BackgroundTransparency = 0.5,
		BorderSizePixel = 0, LayoutOrder = order, Parent = abilityPanel,
	}, {
		create("UICorner", {CornerRadius = UDim.new(0, 4)}),
		create("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.7)})}),
	})
	local keyBox = create("TextLabel", {
		Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(#key > 1 and 34 or 22, 22), BackgroundColor3 = Color3.fromRGB(20, 18, 18),
		BorderSizePixel = 0, Font = STYLE.Font, Text = key, TextSize = #key > 1 and 10 or 13, TextColor3 = STYLE.Ink,
		ClipsDescendants = true, Parent = frame,
	}, {create("UICorner", {CornerRadius = UDim.new(0, 3)})})
	local keyStroke = create("UIStroke", {Color = KEY_RIM, Thickness = 1, Transparency = 0.45, Parent = keyBox})
	-- cooldown: a dark curtain over the key that drains away
	local curtain = create("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 2, Parent = keyBox,
	})
	local left = #key > 1 and 46 or 34
	local title = create("TextLabel", {
		Position = UDim2.fromOffset(left, 2), Size = UDim2.new(1, -left - 56, 0, 15), BackgroundTransparency = 1, Font = STYLE.Font,
		Text = name, TextSize = 13, TextColor3 = STYLE.Ink, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame,
	})
	local sub = create("TextLabel", {
		Position = UDim2.fromOffset(left, 16), Size = UDim2.new(1, -left - 6, 0, 12), BackgroundTransparency = 1, Font = STYLE.Font,
		Text = desc, TextSize = 10, TextColor3 = STYLE.Dim, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame,
	})
	local status = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 3), Size = UDim2.fromOffset(52, 13),
		BackgroundTransparency = 1, Font = STYLE.Font, Text = "", TextSize = 11, TextColor3 = STYLE.Ready,
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
		c.keyStroke.Color = STYLE.Faint
	elseif left > 0 then
		c.status.Text = string.format("%.1fs", left)
		c.status.TextColor3 = STYLE.Dim
		c.title.TextColor3 = STYLE.Dim
		c.keyStroke.Color = STYLE.Dim
	else
		c.status.Text = ready and "ready" or ""
		c.status.TextColor3 = STYLE.Ready
		c.title.TextColor3 = STYLE.Ink
		c.keyStroke.Color = KEY_RIM
	end
end

if not TOUCH then
	register({
		id = "abilities", name = "ABILITIES", frame = abilityPanel, scalable = true,
		defaultPos = function()
			local size = gui.AbsoluteSize
			return UDim2.fromOffset(size.X - PANEL_W - 18, size.Y - PANEL_H - 18)
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
			abilityPanel.Position = UDim2.fromOffset(size.X - PANEL_W - 18, size.Y - PANEL_H - 18)
		elseif not editorGui.Enabled then
			-- a spot saved for the old, shorter panel: keep the bottom of the stack on the screen
			local size = gui.AbsoluteSize
			local p = abilityPanel.AbsolutePosition - gui.AbsolutePosition
			if p.Y + PANEL_H > size.Y - 6 then
				abilityPanel.Position = UDim2.fromOffset(p.X, size.Y - PANEL_H - 6)
			end
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
			cardData.frame.BackgroundTransparency = 0.5 + a * 0.5
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
