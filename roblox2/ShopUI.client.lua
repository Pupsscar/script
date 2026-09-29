-- The supply depot's window, opened at the counter (the prompt on GS_Shop). Same look as the menu's panels:
-- black card, thin frame with corner brackets, typewriter font. Three sections (ATTACK, CONSUMABLES, DEFENSE),
-- a grid of items with turning 3D models, and the picked item on the right with its stats, price and BUY.
-- Closes with X, Esc, E again, walking away, dying, or the depot going back under.
-- No long dashes in any text here: plain "-" only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ShopData = require(Modules:WaitForChild("ShopData"))
local SoundConfig = require(Modules:WaitForChild("SoundConfig"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("GS_ShopRemote", 30)
local shop = workspace:WaitForChild("GS_Shop", 60)
if not shop then return end

local FONT = Enum.Font.SpecialElite
local INK = Color3.fromRGB(245, 243, 240)
local MID = Color3.fromRGB(214, 210, 205)
local DIM = Color3.fromRGB(150, 146, 142)
local LINE = Color3.fromRGB(90, 88, 85)
local CELL = Color3.fromRGB(12, 12, 12)
local AMBER = Color3.fromRGB(232, 164, 52)
local RED = Color3.fromRGB(235, 40, 40)
local W, H = 820, 580

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
local soundFolder = create("Folder", {Name = "GS_ShopSounds", Parent = player:WaitForChild("PlayerGui")})
local function click(name, volume)
	pcall(function() SoundConfig.PlayOnce(name, soundFolder, {Volume = volume}) end)
end

local gui = create("ScreenGui", {
	Name = "GS_ShopUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui"),
})
local shade = create("TextButton", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
	AutoButtonColor = false, Text = "", Parent = gui,
})
local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = Color3.fromRGB(6, 6, 6), BackgroundTransparency = 0.02, BorderSizePixel = 0, Parent = gui,
}, {
	create("UIStroke", {Color = LINE, Thickness = 1}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 26, 25), Color3.fromRGB(0, 0, 0))}),
})
local panelScale = create("UIScale", {Parent = panel})
-- swallow clicks on the card itself so only the dark area around it closes the window
create("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = panel})

local function bracket(parent, anchor, pos)
	local holder = create("Frame", {AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 5, Parent = parent})
	create("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, anchor.Y), AnchorPoint = Vector2.new(0, anchor.Y),
		BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 5, Parent = holder})
	create("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(anchor.X, 0), AnchorPoint = Vector2.new(anchor.X, 0),
		BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 5, Parent = holder})
end
local function brackets(parent)
	bracket(parent, Vector2.new(0, 0), UDim2.fromOffset(6, 6))
	bracket(parent, Vector2.new(1, 0), UDim2.new(1, -6, 0, 6))
	bracket(parent, Vector2.new(0, 1), UDim2.new(0, 6, 1, -6))
	bracket(parent, Vector2.new(1, 1), UDim2.new(1, -6, 1, -6))
end
brackets(panel)

local function text(parent, props)
	local base = {BackgroundTransparency = 1, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK, ZIndex = 3, Parent = parent}
	for k, v in pairs(props) do base[k] = v end
	return create("TextLabel", base)
end

-- header
text(panel, {Position = UDim2.fromOffset(26, 16), Size = UDim2.fromOffset(400, 30), Text = "SUPPLY DEPOT", TextSize = 28})
text(panel, {Position = UDim2.fromOffset(240, 26), Size = UDim2.fromOffset(240, 16),
	Text = "trader 07  -  no refunds", TextSize = 15, TextColor3 = DIM})
-- your money, top right: a gold coin and the amount (rolls and flashes when it changes)
local cashChip = create("Frame", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -66, 0, 14), Size = UDim2.fromOffset(176, 36),
	BackgroundColor3 = Color3.fromRGB(14, 12, 10), BorderSizePixel = 0, ZIndex = 3, Parent = panel,
})
local cashStroke = create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cashChip})
local cashCoin = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(24, 30),
	BackgroundTransparency = 1, Font = FONT, Text = "$", TextSize = 28, TextColor3 = AMBER, ZIndex = 4, Parent = cashChip,
})
local cashCoinScale = create("UIScale", {Parent = cashCoin})
local cashAmount = text(cashChip, {Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -48, 1, 0), Text = "0", TextSize = 22,
	TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4})
local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 14), Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Color3.fromRGB(14, 14, 14), BorderSizePixel = 0, AutoButtonColor = false, Font = FONT, Text = "X",
	TextSize = 20, TextColor3 = MID, ZIndex = 4, Parent = panel,
}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
create("Frame", {
	Position = UDim2.fromOffset(26, 56), Size = UDim2.new(1, -52, 0, 1), BackgroundColor3 = LINE, BorderSizePixel = 0, ZIndex = 3, Parent = panel,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1),
})})})

-- the item models live in ReplicatedStorage.Modules.ShopModels (so they can be built and checked on their own)
local ShopModels = require(Modules:WaitForChild("ShopModels"))
local buildItem = ShopModels.Build

-- a viewport with the item turning in it; returns the entry the spinner uses
local spinners = {}
local function itemView(parent, id, zIndex)
	local frame = create("ViewportFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(125, 115, 110),
		LightColor = Color3.fromRGB(255, 236, 222), LightDirection = Vector3.new(-0.6, -1, -0.4), ZIndex = zIndex or 4, Parent = parent,
	})
	local world = create("WorldModel", {Parent = frame})
	local model = buildItem(id)
	model.Parent = world
	local cf, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot())
	local camera = create("Camera", {FieldOfView = 30, Parent = frame})
	frame.CurrentCamera = camera
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(15)) * 1.08
	camera.CFrame = CFrame.lookAt(Vector3.new(0, radius * 0.35, -dist), Vector3.zero)
	local entry = {frame = frame, model = model, base = model:GetPivot(), angle = math.random() * 6}
	table.insert(spinners, entry)
	return entry
end

-- ===== tabs =====
local tabButtons = {}
local tabTag = text(panel, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, 74), Size = UDim2.fromOffset(250, 16),
	Text = "", TextSize = 14, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right})
for i, section in ipairs(ShopData.Sections) do
	local b = create("TextButton", {
		Position = UDim2.fromOffset(26 + (i - 1) * 154, 68), Size = UDim2.fromOffset(148, 30), BackgroundColor3 = Color3.fromRGB(14, 14, 14),
		BorderSizePixel = 0, AutoButtonColor = false, Font = FONT, Text = section.title .. "  " .. #section.items, TextSize = 16,
		TextColor3 = MID, ZIndex = 3, Parent = panel,
	}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
	tabButtons[section.id] = b
end
do
	local b = create("TextButton", {
		Position = UDim2.fromOffset(26 + #ShopData.Sections * 154, 68), Size = UDim2.fromOffset(148, 30),
		BackgroundColor3 = Color3.fromRGB(14, 14, 14), BorderSizePixel = 0, AutoButtonColor = false, Font = FONT, Text = "SELL",
		TextSize = 16, TextColor3 = AMBER, ZIndex = 3, Parent = panel,
	}, {create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})
	tabButtons.sell = b
end

-- ===== grid (left) =====
local GRID_X, GRID_Y, GRID_W = 26, 110, 450
local grid = create("ScrollingFrame", {
	Position = UDim2.fromOffset(GRID_X, GRID_Y), Size = UDim2.fromOffset(GRID_W, H - GRID_Y - 46), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = LINE, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3, Parent = panel,
}, {
	create("UIGridLayout", {CellSize = UDim2.fromOffset(140, 170), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder}),
	create("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1)}),
})

-- ===== detail (right) =====
local DX = GRID_X + GRID_W + 16
local DW = W - DX - 26
local viewHolder = create("Frame", {
	Position = UDim2.fromOffset(DX, GRID_Y), Size = UDim2.fromOffset(DW, 190), BackgroundColor3 = Color3.fromRGB(12, 11, 11),
	BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3, Parent = panel,
}, {
	create("UIStroke", {Color = LINE, Thickness = 1}),
	create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 32, 31), Color3.fromRGB(6, 6, 6))}),
})
brackets(viewHolder)
local viewTag = text(viewHolder, {Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(240, 14), Text = "", TextSize = 13, TextColor3 = DIM, ZIndex = 6})
text(viewHolder, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -8), Size = UDim2.fromOffset(200, 14), Text = "drag to turn",
	TextSize = 12, TextColor3 = LINE, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6})
local detailName = text(panel, {Position = UDim2.fromOffset(DX, GRID_Y + 200), Size = UDim2.fromOffset(DW, 28), Text = "", TextSize = 25})
local detailTag = text(panel, {Position = UDim2.fromOffset(DX, GRID_Y + 228), Size = UDim2.fromOffset(DW, 16), Text = "", TextSize = 14, TextColor3 = DIM})
local detailDesc = text(panel, {Position = UDim2.fromOffset(DX, GRID_Y + 252), Size = UDim2.fromOffset(DW, 56), Text = "", TextSize = 14,
	TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = MID})
local statRows = {}
for i = 1, 3 do
	local y = GRID_Y + 314 + (i - 1) * 22
	local label = text(panel, {Position = UDim2.fromOffset(DX, y), Size = UDim2.fromOffset(110, 16), Text = "", TextSize = 13, TextColor3 = DIM})
	local cells = {}
	for c = 1, 10 do
		cells[c] = create("Frame", {
			Position = UDim2.fromOffset(DX + 112 + (c - 1) * 19, y + 4), Size = UDim2.fromOffset(15, 8), BackgroundColor3 = LINE,
			BorderSizePixel = 0, ZIndex = 3, Parent = panel,
		})
	end
	statRows[i] = {label = label, cells = cells}
end
local priceLabel = text(panel, {Position = UDim2.fromOffset(DX, GRID_Y + 384), Size = UDim2.fromOffset(150, 40), Text = "", TextSize = 32, TextColor3 = AMBER})
local buyButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(DX + DW, GRID_Y + 384), Size = UDim2.fromOffset(150, 40),
	BackgroundColor3 = Color3.fromRGB(110, 14, 14), BorderSizePixel = 0, AutoButtonColor = false, Font = FONT, Text = "BUY",
	TextSize = 22, TextColor3 = INK, ZIndex = 3, Parent = panel,
}, {create("UIStroke", {Color = Color3.fromRGB(190, 40, 40), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})})

-- footer
create("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -38), Size = UDim2.new(1, -52, 0, 1), BackgroundColor3 = LINE,
	BorderSizePixel = 0, ZIndex = 3, Parent = panel,
}, {create("UIGradient", {Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1),
})})})
local statusLabel = text(panel, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -12), Size = UDim2.fromOffset(460, 18),
	Text = "", TextSize = 15, TextColor3 = DIM})
text(panel, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -26, 1, -12), Size = UDim2.fromOffset(280, 18),
	Text = UserInputService.TouchEnabled and "" or "[E] / [ESC] leave", TextSize = 15, TextColor3 = MID,
	TextXAlignment = Enum.TextXAlignment.Right})

-- ===== behaviour =====
local selectedSection, selectedItem = nil, nil
local isOpen = false
local cards = {}
local detailView = nil
local IDLE_TEXT = "the trader watches you from behind the counter"

local function setStatus(message, color)
	statusLabel.Text = message
	statusLabel.TextColor3 = color or DIM
end

local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local cashShown = 0
local cashValue = create("NumberValue", {Value = 0})
cashValue.Changed:Connect(function(v) cashAmount.Text = commas(v) end)
-- instant = just show it (opening the window); otherwise roll to it and flash
local function refreshCash(instant)
	local cash = player:GetAttribute("Cash")
	cash = typeof(cash) == "number" and math.floor(cash) or 0
	local delta = cash - cashShown
	cashShown = cash
	if instant or delta == 0 then
		cashValue.Value = cash
		cashAmount.Text = commas(cash)
		return
	end
	tween(cashValue, 0.6, {Value = cash})
	local color = delta > 0 and AMBER or RED
	cashStroke.Color = color
	cashAmount.TextColor3 = color
	task.delay(0.15, function()
		tween(cashStroke, 0.7, {Color = LINE})
		tween(cashAmount, 0.7, {TextColor3 = INK})
	end)
	cashCoinScale.Scale = delta > 0 and 1.35 or 0.75
	tween(cashCoinScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
	local pop = text(panel, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -74, 0, 50), Size = UDim2.fromOffset(160, 20),
		Text = (delta > 0 and "+" or "-") .. ShopData.Currency .. commas(math.abs(delta)), TextSize = 18, TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6})
	tween(pop, 1, {Position = UDim2.new(1, -74, 0, 64), TextTransparency = 1})
	task.delay(1.05, function() pop:Destroy() end)
end

local function removeSpinner(entry)
	for i, e in ipairs(spinners) do
		if e == entry then table.remove(spinners, i) break end
	end
end

local function showItem(item, section)
	selectedItem = item
	for id, card in pairs(cards) do
		card.stroke.Color = id == item.id and INK or LINE
		card.stroke.Thickness = id == item.id and 1.5 or 1
	end
	if detailView then
		removeSpinner(detailView)
		detailView.frame:Destroy()
	end
	detailView = itemView(viewHolder, item.id, 4)
	local index = 1
	for i, it in ipairs(section.items) do if it == item then index = i end end
	viewTag.Text = string.format("%s / %02d", section.title, index)
	detailName.Text = item.name
	detailTag.Text = section.title .. "  -  " .. section.tag
	detailDesc.Text = item.desc
	for i, row in ipairs(statRows) do
		row.label.Text = section.stats[i] or ""
		local filled = math.floor((item.stats[i] or 0) * 10 + 0.5)
		for c, cell in ipairs(row.cells) do
			cell.BackgroundColor3 = c <= filled and (i == 1 and AMBER or INK) or Color3.fromRGB(40, 39, 38)
		end
	end
	priceLabel.Text = ShopData.Currency .. " " .. item.price
	buyButton.Text = "BUY"
	setStatus(IDLE_TEXT)
end

local ItemData = require(Modules:WaitForChild("ItemData"))
local bag = {items = {}}
local syncRemote = ReplicatedStorage:WaitForChild("GS_InvSync", 30)
local showSell
if syncRemote then
	syncRemote.OnClientEvent:Connect(function(snap)
		if typeof(snap) ~= "table" then return end
		bag = snap
		if isOpen and selectedSection == "sell" then showSell() end
	end)
end
local selectedEntry = nil

local function sellPrice(entry)
	local item = ItemData.Get(entry.id)
	if not item or item.adminOnly then return nil end
	local each = item.sell
	if item.kind == "ammo" and item.buyAmount then each = item.sell / item.buyAmount end
	if item.kind == "armor" and entry.dur and item.durability then each = each * math.clamp(entry.dur / item.durability, 0.2, 1) end
	return math.max(1, math.floor(each * entry.n + 0.5))
end

local function showEntry(entry)
	selectedEntry = entry
	selectedItem = nil
	local item = ItemData.Get(entry.id)
	for id, card in pairs(cards) do
		card.stroke.Color = id == entry.uid and INK or LINE
		card.stroke.Thickness = id == entry.uid and 1.5 or 1
	end
	if detailView then
		removeSpinner(detailView)
		detailView.frame:Destroy()
	end
	detailView = itemView(viewHolder, entry.id, 4)
	viewTag.Text = "YOUR BAG"
	detailName.Text = item and item.name or entry.id
	detailTag.Text = (entry.n > 1 and ("x" .. entry.n .. "  -  ") or "") .. (entry.worn and "worn - it comes off first" or "the trader looks it over")
	local cond = ""
	if entry.dur and item and item.durability then
		cond = string.format("Condition: %d%%. ", math.floor(entry.dur / item.durability * 100 + 0.5))
	end
	if entry.ammo and entry.ammo > 0 then cond = cond .. string.format("%d loaded. ", entry.ammo) end
	detailDesc.Text = cond .. (item and item.desc or "")
	for _, row in ipairs(statRows) do
		row.label.Text = ""
		for _, cell in ipairs(row.cells) do cell.BackgroundColor3 = Color3.fromRGB(20, 19, 18) end
	end
	local price = sellPrice(entry)
	priceLabel.Text = price and ("+" .. ShopData.Currency .. " " .. price) or "-"
	buyButton.Text = price and "SELL" or "NO"
	setStatus(price and "the trader pays in cash, no questions" or "the trader won't touch that")
end

function showSell()
	selectedSection = "sell"
	for id, b in pairs(tabButtons) do
		local on = id == "sell"
		b.BackgroundColor3 = on and INK or Color3.fromRGB(14, 14, 14)
		b.TextColor3 = on and Color3.new(0, 0, 0) or (id == "sell" and AMBER or MID)
	end
	tabTag.Text = "what you carry, and what it's worth"
	for _, card in pairs(cards) do
		removeSpinner(card.view)
		card.button:Destroy()
	end
	table.clear(cards)
	local first, keep = nil, nil
	for i, entry in ipairs(bag.items or {}) do
		local item = ItemData.Get(entry.id)
		local price = sellPrice(entry)
		local b = create("TextButton", {
			BackgroundColor3 = CELL, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = i, ZIndex = 3, Parent = grid,
		})
		local stroke = create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b})
		local holder = create("Frame", {
			Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 104), BackgroundColor3 = Color3.fromRGB(20, 19, 18),
			BorderSizePixel = 0, ZIndex = 3, Parent = b,
		}, {create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 32, 31), Color3.fromRGB(8, 8, 8))})})
		local view = itemView(holder, entry.id, 4)
		text(b, {Position = UDim2.fromOffset(10, 112), Size = UDim2.new(1, -16, 0, 34),
			Text = (item and item.name or entry.id) .. (entry.n > 1 and ("  x" .. entry.n) or ""), TextSize = 15,
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4})
		text(b, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), Size = UDim2.fromOffset(120, 18),
			Text = price and ("+" .. ShopData.Currency .. " " .. price) or "no sale", TextSize = 16,
			TextColor3 = price and AMBER or DIM, ZIndex = 4})
		b.MouseEnter:Connect(function() tween(b, 0.12, {BackgroundColor3 = Color3.fromRGB(26, 24, 24)}) end)
		b.MouseLeave:Connect(function() tween(b, 0.15, {BackgroundColor3 = CELL}) end)
		b.Activated:Connect(function()
			click(SoundConfig.Random("TapeClick"), 0.35)
			showEntry(entry)
		end)
		cards[entry.uid] = {button = b, stroke = stroke, view = view}
		first = first or entry
		if selectedEntry and selectedEntry.uid == entry.uid then keep = entry end
	end
	if keep or first then
		showEntry(keep or first)
	else
		selectedEntry = nil
		if detailView then
			removeSpinner(detailView)
			detailView.frame:Destroy()
			detailView = nil
		end
		detailName.Text = "EMPTY BAG"
		detailTag.Text = ""
		detailDesc.Text = "Nothing to sell. Come back with something."
		priceLabel.Text = ""
		buyButton.Text = "-"
		setStatus("the trader shrugs")
	end
end

local function showSection(sectionId)
	if sectionId == "sell" then
		showSell()
		return
	end
	selectedEntry = nil
	local section
	for _, s in ipairs(ShopData.Sections) do if s.id == sectionId then section = s end end
	if not section then return end
	selectedSection = sectionId
	for id, b in pairs(tabButtons) do
		local on = id == sectionId
		b.BackgroundColor3 = on and INK or Color3.fromRGB(14, 14, 14)
		b.TextColor3 = on and Color3.new(0, 0, 0) or MID
	end
	tabTag.Text = section.tag
	for _, card in pairs(cards) do
		removeSpinner(card.view)
		card.button:Destroy()
	end
	table.clear(cards)
	for i, item in ipairs(section.items) do
		local b = create("TextButton", {
			BackgroundColor3 = CELL, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = i, ZIndex = 3, Parent = grid,
		})
		local stroke = create("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b})
		local holder = create("Frame", {
			Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 104), BackgroundColor3 = Color3.fromRGB(20, 19, 18),
			BorderSizePixel = 0, ZIndex = 3, Parent = b,
		}, {create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 32, 31), Color3.fromRGB(8, 8, 8))})})
		local view = itemView(holder, item.id, 4)
		text(b, {Position = UDim2.fromOffset(10, 112), Size = UDim2.new(1, -16, 0, 34), Text = item.name, TextSize = 15,
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4})
		text(b, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), Size = UDim2.fromOffset(80, 18),
			Text = ShopData.Currency .. " " .. item.price, TextSize = 16, TextColor3 = AMBER, ZIndex = 4})
		b.MouseEnter:Connect(function()
			tween(b, 0.12, {BackgroundColor3 = Color3.fromRGB(26, 24, 24)})
		end)
		b.MouseLeave:Connect(function() tween(b, 0.15, {BackgroundColor3 = CELL}) end)
		b.Activated:Connect(function()
			if selectedItem == item then return end
			click(SoundConfig.Random("TapeClick"), 0.35)
			showItem(item, section)
		end)
		cards[item.id] = {button = b, stroke = stroke, view = view}
	end
	grid.CanvasPosition = Vector2.zero
	showItem(section.items[1], section)
end

for id, b in pairs(tabButtons) do
	b.Activated:Connect(function()
		if selectedSection == id then return end
		click("MenuClick", 0.5)
		showSection(id)
	end)
end

-- turning the big view by dragging
local turning, lastX = false, 0
viewHolder.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		turning, lastX = true, input.Position.X
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if turning and detailView and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		detailView.angle += (input.Position.X - lastX) * 0.012
		lastX = input.Position.X
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		turning = false
	end
end)

-- buying: the server answers (for now always "not yet")
buyButton.MouseEnter:Connect(function() tween(buyButton, 0.12, {BackgroundColor3 = Color3.fromRGB(150, 20, 20)}) end)
buyButton.MouseLeave:Connect(function() tween(buyButton, 0.15, {BackgroundColor3 = Color3.fromRGB(110, 14, 14)}) end)
local waiting = false
buyButton.Activated:Connect(function()
	if waiting or not remote then return end
	if selectedSection == "sell" then
		if not selectedEntry or not sellPrice(selectedEntry) then return end
		waiting = true
		buyButton.Text = "..."
		click("MenuClick", 0.5)
		remote:FireServer("sell", selectedEntry.uid)
		task.delay(3, function()
			if waiting then
				waiting = false
				buyButton.Text = "SELL"
			end
		end)
		return
	end
	if not selectedItem then return end
	waiting = true
	buyButton.Text = "..."
	click("MenuClick", 0.5)
	remote:FireServer("buy", selectedItem.id)
	task.delay(3, function()
		if waiting then
			waiting = false
			buyButton.Text = "BUY"
		end
	end)
end)

-- ===== open / close =====
local openedAt, closedAt = 0, 0
local promptPart
local function findPrompt()
	for _, d in ipairs(shop:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == "ShopPrompt" then return d end
	end
	return nil
end

local function fit()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local size = camera.ViewportSize
	panelScale.Scale = math.clamp(math.min((size.X - 16) / W, (size.Y - 16) / H), 0.35, 1)
end

local function setOpen(value)
	if value == isOpen then return end
	isOpen = value
	player:SetAttribute("UIOpen", value)
	if value then openedAt = os.clock() else closedAt = os.clock() end
	if value then
		fit()
		refreshCash(true)
		gui.Enabled = true
		shade.BackgroundTransparency = 1
		tween(shade, 0.25, {BackgroundTransparency = 0.45})
		panel.Position = UDim2.new(0.5, 0, 0.5, 18)
		tween(panel, 0.3, {Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Back)
		click(SoundConfig.Random("TapeClick"), 0.45)
		showSection(selectedSection or ShopData.Sections[1].id)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		click("MenuClick", 0.4)
		gui.Enabled = false
		for _, card in pairs(cards) do
			removeSpinner(card.view)
			card.button:Destroy()
		end
		table.clear(cards)
		if detailView then
			removeSpinner(detailView)
			detailView.frame:Destroy()
			detailView = nil
		end
		selectedItem = nil
	end
end

closeButton.Activated:Connect(function() setOpen(false) end)
shade.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input)
	if not isOpen or UserInputService:GetFocusedTextBox() then return end
	-- (the same E press that opened the window must not close it again)
	if input.KeyCode == Enum.KeyCode.Escape or (input.KeyCode == Enum.KeyCode.E and os.clock() - openedAt > 0.3) then
		setOpen(false)
	end
end)

task.spawn(function()
	local prompt = findPrompt()
	while not prompt do
		task.wait(1)
		prompt = findPrompt()
	end
	promptPart = prompt.Parent
	prompt.Triggered:Connect(function(who)
		if who ~= player then return end
		if not isOpen and os.clock() - closedAt > 0.3 then setOpen(true) end
	end)
end)

if remote then
	remote.OnClientEvent:Connect(function(kind, itemId, ok, message)
		if kind == "closing" then
			setOpen(false)
		elseif kind == "sell" then
			waiting = false
			if not isOpen then return end
			setStatus(ok and tostring(message) or tostring(message or "no deal"), ok and AMBER or RED)
			if not ok then pcall(function() SoundConfig.PlayOnce("FearHit", soundFolder, {Volume = 0.25, PlaybackSpeed = 1.6}) end) end
			refreshCash()
		elseif kind == "buy" then
			waiting = false
			buyButton.Text = "BUY"
			if not isOpen then return end
			local item = ShopData.Get(itemId)
			if ok then
				setStatus("bought: " .. (item and item.name or itemId), AMBER)
			else
				setStatus(tostring(message or "no deal"), RED)
				pcall(function() SoundConfig.PlayOnce("FearHit", soundFolder, {Volume = 0.25, PlaybackSpeed = 1.6}) end)
			end
			refreshCash()
		end
	end)
end
player:GetAttributeChangedSignal("Cash"):Connect(function() if isOpen then refreshCash() end end)

local camera = workspace.CurrentCamera
if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if isOpen then fit() end end) end

RunService.RenderStepped:Connect(function(dt)
	if not isOpen then return end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	for _, e in ipairs(spinners) do
		if e.model.Parent then
			if not (turning and e == detailView) then e.angle += dt * 0.6 end
			e.model:PivotTo(CFrame.Angles(0, e.angle, 0) * e.base)
		end
	end
	-- leave when the depot goes, when you walk off, or when you die
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local away = promptPart and root and (root.Position - promptPart.Position).Magnitude > 18
	if shop:GetAttribute("State") ~= "open" or not humanoid or humanoid.Health <= 0 or away then
		setOpen(false)
	end
end)
