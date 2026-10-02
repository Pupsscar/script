-- Armor as it looks on a body: every piece is built onto the R6 parts it covers and welded to them,
-- so it moves with the arms, legs and head like real gear.
--   Wearables.Attach(id, character) -> the Model it put on the character (name "GS_Wear_<id>")
--   Wearables.Display(id, model)    -> fills `model` with the same gear on an invisible body (shop / wheel icons)
-- Every GUI in here is named GS_* (the client anticheat ignores those on other people).
local Wearables = {}

local M = Enum.Material
local A, R = CFrame.Angles, math.rad
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball

-- the standard R6 body, relative to the torso (used for the display dummy)
local BODY = {
	Head = {size = Vector3.new(2, 1, 1), cf = CFrame.new(0, 1.5, 0)},
	Torso = {size = Vector3.new(2, 2, 1), cf = CFrame.new()},
	["Left Arm"] = {size = Vector3.new(1, 2, 1), cf = CFrame.new(-1.5, 0, 0)},
	["Right Arm"] = {size = Vector3.new(1, 2, 1), cf = CFrame.new(1.5, 0, 0)},
	["Left Leg"] = {size = Vector3.new(1, 2, 1), cf = CFrame.new(-0.5, -2, 0)},
	["Right Leg"] = {size = Vector3.new(1, 2, 1), cf = CFrame.new(0.5, -2, 0)},
}

local function piece(holder, bodyPart, localCF, size, color, material, shape, transparency)
	local p = Instance.new("Part")
	p.Name = "GS_Armor"
	p.Size = size
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	if transparency then p.Transparency = transparency end
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, true, true
	p.Anchored = false
	p.CFrame = bodyPart.CFrame * localCF
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = p
	weld.Parent = p
	p.Parent = holder
	return p
end

local function label(part, face, lines, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GS_Label"
	gui.Face = face
	gui.CanvasSize = Vector2.new(part.Size.X * 100, part.Size.Y * 100)
	gui.LightInfluence = 1
	gui.Parent = part
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = gui
	for _, line in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, line.h or 0.5, 0)
		t.Font = line.font or Enum.Font.GothamBlack
		t.Text = line.text
		t.TextScaled = true
		t.TextColor3 = color or Color3.fromRGB(232, 232, 228)
		t.Parent = gui
	end
	return gui
end

-- which side is "outside" for a limb
local function outward(name)
	return (name:find("Left") and -1) or 1
end

local BUILD = {}

-- ===== riot helmet: shell, tinted visor on hinges, neck guard, chin strap =====
BUILD.helmet = function(h, c)
	local head = c.Head
	local shell = Color3.fromRGB(34, 38, 50)
	piece(h, head, CFrame.new(0, 0.26, 0.03), Vector3.new(1.52, 1.28, 1.58), shell, M.SmoothPlastic, BALL)
	piece(h, head, CFrame.new(0, -0.02, 0.03) * A(0, 0, R(90)), Vector3.new(0.12, 1.58, 1.64), shell, M.SmoothPlastic, CYL)
	piece(h, head, CFrame.new(0, -0.3, 0.7), Vector3.new(1.3, 0.34, 0.12), shell, M.SmoothPlastic)
	local visor = piece(h, head, CFrame.new(0, 0.06, -0.8) * A(R(-12), 0, 0), Vector3.new(1.34, 0.72, 0.06),
		Color3.fromRGB(150, 175, 200), M.Glass, nil, 0.45)
	visor.Reflectance = 0.2
	piece(h, head, CFrame.new(0, 0.45, -0.76), Vector3.new(1.4, 0.1, 0.12), Color3.fromRGB(20, 20, 24), M.Metal)
	for _, s in ipairs({-1, 1}) do
		piece(h, head, CFrame.new(s * 0.72, 0.18, -0.55) * A(0, 0, R(90)), Vector3.new(0.1, 0.26, 0.26), Color3.fromRGB(150, 152, 158), M.Metal, CYL)
		piece(h, head, CFrame.new(s * 0.6, -0.35, -0.15) * A(R(20), 0, 0), Vector3.new(0.05, 0.55, 0.08), Color3.fromRGB(28, 28, 30), M.Fabric)
	end
	piece(h, head, CFrame.new(0, -0.62, -0.32), Vector3.new(1.05, 0.06, 0.08), Color3.fromRGB(28, 28, 30), M.Fabric)
end

-- ===== gas mask: rubber face piece, two lenses in rims, a canister under the chin, head straps =====
BUILD.gasmask = function(h, c)
	local head = c.Head
	local rubber = Color3.fromRGB(38, 39, 41)
	piece(h, head, CFrame.new(0, 0.02, -0.46), Vector3.new(1.12, 1.12, 0.5), rubber, M.Rubber, BALL)
	piece(h, head, CFrame.new(0, -0.32, -0.56), Vector3.new(0.72, 0.52, 0.42), rubber, M.Rubber, BALL)
	for _, s in ipairs({-1, 1}) do
		local eye = CFrame.new(s * 0.24, 0.13, -0.68) * A(0, R(s * 12), 0) * A(0, R(90), 0)
		piece(h, head, eye, Vector3.new(0.1, 0.36, 0.36), Color3.fromRGB(112, 114, 118), M.Metal, CYL)
		local lens = piece(h, head, eye * CFrame.new(-0.02, 0, 0), Vector3.new(0.1, 0.28, 0.28), Color3.fromRGB(90, 115, 110), M.Glass, CYL, 0.3)
		lens.Reflectance = 0.25
		piece(h, head, CFrame.new(s * 0.63, 0.12, 0.02), Vector3.new(0.05, 0.14, 1.05), Color3.fromRGB(56, 54, 50), M.Fabric)
		piece(h, head, CFrame.new(s * 0.55, -0.28, 0.05), Vector3.new(0.05, 0.1, 0.9), Color3.fromRGB(56, 54, 50), M.Fabric)
	end
	piece(h, head, CFrame.new(0, 0.62, 0.02), Vector3.new(0.9, 0.05, 0.14), Color3.fromRGB(56, 54, 50), M.Fabric)
	local filter = CFrame.new(0, -0.5, -0.82) * A(R(40), 0, 0)
	piece(h, head, filter * A(0, R(90), 0), Vector3.new(0.42, 0.42, 0.42), Color3.fromRGB(78, 88, 56), M.Metal, CYL)
	for _, z in ipairs({-0.08, 0.1}) do
		piece(h, head, filter * CFrame.new(0, 0, z) * A(0, R(90), 0), Vector3.new(0.05, 0.46, 0.46), Color3.fromRGB(58, 66, 42), M.Metal, CYL)
	end
	piece(h, head, filter * CFrame.new(0, 0, -0.22) * A(0, R(90), 0), Vector3.new(0.03, 0.34, 0.34), Color3.fromRGB(24, 24, 24), M.Metal, CYL)
end

-- ===== padded jacket: quilted body, collar, sleeves over the upper arms, zip =====
BUILD.jacket = function(h, c)
	local col, dark = Color3.fromRGB(62, 70, 48), Color3.fromRGB(44, 50, 34)
	piece(h, c.Torso, CFrame.new(0, 0, 0), Vector3.new(2.12, 2.04, 1.12), col, M.Fabric)
	for i = 0, 3 do piece(h, c.Torso, CFrame.new(0, 0.7 - i * 0.45, 0), Vector3.new(2.15, 0.05, 1.15), dark, M.Fabric) end
	piece(h, c.Torso, CFrame.new(0, 1.02, 0), Vector3.new(1.3, 0.28, 1.18), dark, M.Fabric)
	piece(h, c.Torso, CFrame.new(0, 0, -0.575), Vector3.new(0.07, 1.95, 0.04), Color3.fromRGB(28, 28, 30), M.Metal)
	for _, name in ipairs({"Left Arm", "Right Arm"}) do
		local arm = c[name]
		if arm then
			piece(h, arm, CFrame.new(0, 0.35, 0), Vector3.new(1.1, 1.35, 1.1), col, M.Fabric)
			piece(h, arm, CFrame.new(0, -0.32, 0), Vector3.new(1.12, 0.12, 1.12), dark, M.Fabric)
		end
	end
end

-- ===== kevlar vest: front and back panels, sides, shoulder straps, pouches, a name patch =====
BUILD.vest = function(h, c)
	local col, panel = Color3.fromRGB(30, 32, 30), Color3.fromRGB(44, 46, 44)
	local t = c.Torso
	piece(h, t, CFrame.new(0, 0.12, -0.6), Vector3.new(2.06, 1.62, 0.22), col, M.Fabric)
	piece(h, t, CFrame.new(0, 0.12, 0.6), Vector3.new(2.06, 1.62, 0.22), col, M.Fabric)
	for _, s in ipairs({-1, 1}) do
		piece(h, t, CFrame.new(s * 1.04, 0.05, 0), Vector3.new(0.14, 1.3, 1.24), col, M.Fabric)
		piece(h, t, CFrame.new(s * 0.62, 1.03, 0), Vector3.new(0.48, 0.12, 1.32), col, M.Fabric)
	end
	piece(h, t, CFrame.new(0, 0.3, -0.72), Vector3.new(1.4, 1.0, 0.04), panel, M.Fabric)
	for i = -1, 1 do
		piece(h, t, CFrame.new(i * 0.56, -0.48, -0.8), Vector3.new(0.44, 0.46, 0.22), Color3.fromRGB(72, 82, 52), M.Fabric)
		piece(h, t, CFrame.new(i * 0.56, -0.28, -0.9), Vector3.new(0.44, 0.08, 0.05), Color3.fromRGB(56, 62, 40), M.Fabric)
	end
	piece(h, t, CFrame.new(0, 0.62, -0.745), Vector3.new(0.95, 0.24, 0.02), Color3.fromRGB(205, 200, 190), M.SmoothPlastic)
end

-- ===== leg guards: knee cups, shin and thigh plates, straps =====
BUILD.legguards = function(h, c)
	for _, name in ipairs({"Left Leg", "Right Leg"}) do
		local leg = c[name]
		if leg then
			piece(h, leg, CFrame.new(0, -0.35, -0.53), Vector3.new(0.9, 1.05, 0.16), Color3.fromRGB(64, 66, 70), M.Metal)
			piece(h, leg, CFrame.new(0, 0.2, -0.52), Vector3.new(0.78, 0.62, 0.42), Color3.fromRGB(58, 60, 64), M.SmoothPlastic, BALL)
			piece(h, leg, CFrame.new(0, 0.66, -0.53), Vector3.new(0.88, 0.5, 0.12), Color3.fromRGB(64, 66, 70), M.Metal)
			for _, y in ipairs({-0.72, -0.1, 0.62}) do
				piece(h, leg, CFrame.new(0, y, 0), Vector3.new(1.06, 0.1, 1.06), Color3.fromRGB(28, 28, 30), M.Fabric)
			end
		end
	end
end

-- ===== arm guards: forearm and outer plates, elbow cups, straps (light plastic: breaks sooner) =====
BUILD.armguards = function(h, c)
	local plate, strap = Color3.fromRGB(88, 92, 80), Color3.fromRGB(150, 90, 30)
	for _, name in ipairs({"Left Arm", "Right Arm"}) do
		local arm = c[name]
		if arm then
			local s = outward(name)
			piece(h, arm, CFrame.new(0, -0.42, -0.53), Vector3.new(0.96, 0.95, 0.12), plate, M.SmoothPlastic)
			piece(h, arm, CFrame.new(s * 0.53, -0.42, 0), Vector3.new(0.12, 0.95, 0.96), plate, M.SmoothPlastic)
			piece(h, arm, CFrame.new(s * 0.1, 0.08, 0.46), Vector3.new(0.72, 0.56, 0.4), Color3.fromRGB(70, 74, 64), M.SmoothPlastic, BALL)
			for _, y in ipairs({-0.8, -0.1}) do
				piece(h, arm, CFrame.new(0, y, 0), Vector3.new(1.08, 0.1, 1.08), strap, M.Fabric)
			end
		end
	end
end

-- ===== SCG: black, heavy, stenciled =====
local SCG_BLACK = Color3.fromRGB(20, 20, 22)
local SCG_GREY = Color3.fromRGB(56, 58, 62)

BUILD.scg_helmet = function(h, c)
	local head = c.Head
	piece(h, head, CFrame.new(0, 0.22, 0.04), Vector3.new(1.58, 1.4, 1.64), SCG_BLACK, M.SmoothPlastic, BALL)
	piece(h, head, CFrame.new(0, -0.1, 0.4), Vector3.new(1.5, 0.9, 0.9), SCG_BLACK, M.SmoothPlastic)
	-- full face shield, dark and sealed
	local shield = piece(h, head, CFrame.new(0, 0.02, -0.8), Vector3.new(1.3, 1.0, 0.08), Color3.fromRGB(16, 22, 30), M.Glass, nil, 0.15)
	shield.Reflectance = 0.35
	piece(h, head, CFrame.new(0, 0.54, -0.76), Vector3.new(1.46, 0.12, 0.16), SCG_GREY, M.Metal)
	piece(h, head, CFrame.new(0, -0.55, -0.62), Vector3.new(1.2, 0.42, 0.34), SCG_BLACK, M.SmoothPlastic)
	for _, s in ipairs({-1, 1}) do
		-- twin filters at the jaw
		local f = CFrame.new(s * 0.46, -0.58, -0.74) * A(R(30), R(s * -25), 0)
		piece(h, head, f * A(0, R(90), 0), Vector3.new(0.34, 0.32, 0.32), SCG_GREY, M.Metal, CYL)
		piece(h, head, f * CFrame.new(0, 0, -0.18) * A(0, R(90), 0), Vector3.new(0.04, 0.26, 0.26), SCG_BLACK, M.Metal, CYL)
		-- side rails and the hinge discs
		piece(h, head, CFrame.new(s * 0.8, 0.2, -0.05), Vector3.new(0.06, 0.12, 0.9), SCG_GREY, M.Metal)
		piece(h, head, CFrame.new(s * 0.78, 0.0, -0.55) * A(0, 0, R(90)), Vector3.new(0.08, 0.3, 0.3), SCG_GREY, M.Metal, CYL)
	end
	local lamp = piece(h, head, CFrame.new(0.72, 0.36, -0.3), Vector3.new(0.08, 0.08, 0.08), Color3.fromRGB(255, 40, 40), M.Neon, BALL)
	lamp.Name = "GS_ArmorLamp"
	local back = piece(h, head, CFrame.new(0, 0.32, 0.83), Vector3.new(0.9, 0.34, 0.02), SCG_BLACK, M.SmoothPlastic)
	label(back, Enum.NormalId.Back, {{text = "SCG", h = 1}})
end

BUILD.scg_vest = function(h, c)
	local t = c.Torso
	local front = piece(h, t, CFrame.new(0, 0.1, -0.64), Vector3.new(2.16, 1.72, 0.34), SCG_BLACK, M.SmoothPlastic)
	piece(h, t, CFrame.new(0, 0.1, 0.64), Vector3.new(2.16, 1.72, 0.34), SCG_BLACK, M.SmoothPlastic)
	for _, s in ipairs({-1, 1}) do
		piece(h, t, CFrame.new(s * 1.09, -0.1, 0), Vector3.new(0.2, 1.1, 1.36), SCG_GREY, M.Fabric)
		piece(h, t, CFrame.new(s * 0.66, 1.08, 0), Vector3.new(0.62, 0.2, 1.46), SCG_BLACK, M.SmoothPlastic)
	end
	piece(h, t, CFrame.new(0, 1.16, 0), Vector3.new(1.5, 0.34, 1.3), SCG_BLACK, M.SmoothPlastic)
	piece(h, t, CFrame.new(0, -1.18, -0.6), Vector3.new(0.9, 0.55, 0.16), SCG_BLACK, M.SmoothPlastic)
	for i = 0, 3 do
		piece(h, t, CFrame.new(-0.75 + i * 0.5, -0.48, -0.9), Vector3.new(0.42, 0.52, 0.26), SCG_GREY, M.Fabric)
		piece(h, t, CFrame.new(-0.75 + i * 0.5, -0.24, -1.0), Vector3.new(0.42, 0.08, 0.06), SCG_BLACK, M.Fabric)
	end
	-- the chest plate reads SCG, the back spells it out
	local chest = piece(h, t, CFrame.new(0, 0.42, -0.82), Vector3.new(1.3, 0.56, 0.02), SCG_BLACK, M.SmoothPlastic)
	label(chest, Enum.NormalId.Front, {{text = "SCG", h = 0.7}, {text = "07 SECTOR CONTROL GUARD", h = 0.3, font = Enum.Font.GothamBold}})
	local backPlate = piece(h, t, CFrame.new(0, 0.32, 0.82), Vector3.new(1.7, 0.8, 0.02), SCG_BLACK, M.SmoothPlastic)
	label(backPlate, Enum.NormalId.Back, {{text = "SCG", h = 0.62}, {text = "07 SECTOR CONTROL GUARD", h = 0.38, font = Enum.Font.GothamBold}})
	front.Name = "GS_ArmorFront"
end

BUILD.scg_arms = function(h, c)
	for _, name in ipairs({"Left Arm", "Right Arm"}) do
		local arm = c[name]
		if arm then
			local s = outward(name)
			local pauldron = piece(h, arm, CFrame.new(s * 0.12, 0.82, 0), Vector3.new(1.3, 0.62, 1.28), SCG_BLACK, M.SmoothPlastic, BALL)
			local plate = piece(h, arm, CFrame.new(s * 0.55, 0.62, 0), Vector3.new(0.04, 0.34, 0.6), SCG_BLACK, M.SmoothPlastic)
			label(plate, s > 0 and Enum.NormalId.Right or Enum.NormalId.Left, {{text = "SCG", h = 1}})
			piece(h, arm, CFrame.new(0, 0.32, 0), Vector3.new(1.1, 0.62, 1.1), SCG_BLACK, M.SmoothPlastic)
			piece(h, arm, CFrame.new(0, -0.5, 0), Vector3.new(1.1, 0.82, 1.1), SCG_BLACK, M.SmoothPlastic)
			piece(h, arm, CFrame.new(0, -0.5, -0.57), Vector3.new(0.6, 0.6, 0.06), SCG_GREY, M.Metal)
			piece(h, arm, CFrame.new(s * 0.1, 0.02, 0.5), Vector3.new(0.7, 0.55, 0.42), SCG_GREY, M.SmoothPlastic, BALL)
			pauldron.Name = "GS_Pauldron"
		end
	end
end

BUILD.scg_legs = function(h, c)
	for _, name in ipairs({"Left Leg", "Right Leg"}) do
		local leg = c[name]
		if leg then
			piece(h, leg, CFrame.new(0, 0.52, 0), Vector3.new(1.1, 0.82, 1.1), SCG_BLACK, M.SmoothPlastic)
			piece(h, leg, CFrame.new(0, 0.02, -0.52), Vector3.new(0.86, 0.66, 0.5), SCG_GREY, M.SmoothPlastic, BALL)
			piece(h, leg, CFrame.new(0, -0.48, 0), Vector3.new(1.1, 0.72, 1.1), SCG_BLACK, M.SmoothPlastic)
			piece(h, leg, CFrame.new(0, -0.45, -0.58), Vector3.new(0.3, 0.6, 0.08), SCG_GREY, M.Metal)
			piece(h, leg, CFrame.new(0, -0.9, -0.1), Vector3.new(1.12, 0.3, 1.3), SCG_BLACK, M.Rubber)
		end
	end
end

local function bodyOf(character)
	local c = {}
	for name in pairs(BODY) do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then c[name] = p end
	end
	return c
end

function Wearables.Has(id)
	return BUILD[id] ~= nil
end

function Wearables.Attach(id, character)
	local build = BUILD[id]
	if not build then return nil end
	local c = bodyOf(character)
	if not c.Torso or not c.Head then return nil end
	local holder = Instance.new("Model")
	holder.Name = "GS_Wear_" .. id
	holder.Parent = character
	build(holder, c)
	return holder
end

-- the same gear on an invisible body, for viewports
function Wearables.Display(id, model)
	local build = BUILD[id]
	if not build then return model end
	local dummy = Instance.new("Model")
	local c = {}
	for name, spec in pairs(BODY) do
		local p = Instance.new("Part")
		p.Name = name
		p.Size = spec.size
		p.CFrame = spec.cf
		p.Anchored = true
		p.Transparency = 1
		p.Parent = dummy
		c[name] = p
	end
	build(model, c)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			for _, w in ipairs(part:GetChildren()) do
				if w:IsA("WeldConstraint") then w:Destroy() end
			end
		end
	end
	dummy:Destroy()
	return model
end

return Wearables
