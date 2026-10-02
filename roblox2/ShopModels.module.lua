-- The supply depot's items as little part models (shown turning in the shop window).
-- Every model is built around the origin; the long ones lie along X, the front of anything with a face looks at -Z.
local ShopModels = {}
local INK = Color3.fromRGB(245, 243, 240)
local M = Enum.Material
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local function mk(model, size, cf, color, material, shape, transparency)
	local p = Instance.new(shape == "wedge" and "WedgePart" or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape and shape ~= "wedge" then p.Shape = shape end
	if transparency then p.Transparency = transparency end
	p.Parent = model
	return p
end
local A = CFrame.Angles
local R = math.rad
local STEEL, STEEL_L, DARK = Color3.fromRGB(70, 72, 75), Color3.fromRGB(165, 168, 172), Color3.fromRGB(28, 28, 30)
local WOOD, RUST, OLIVE = Color3.fromRGB(110, 78, 50), Color3.fromRGB(112, 70, 44), Color3.fromRGB(72, 82, 52)

local BUILD = {}
BUILD.pipe = function(m)
	local c = A(0, 0, R(25))
	mk(m, Vector3.new(4, 0.36, 0.36), c, RUST, M.CorrodedMetal, CYL)
	for _, x in ipairs({-1.85, 1.85}) do mk(m, Vector3.new(0.4, 0.48, 0.48), c * CFrame.new(x, 0, 0), Color3.fromRGB(80, 60, 44), M.Metal, CYL) end
	mk(m, Vector3.new(0.5, 0.4, 0.4), c * CFrame.new(0.4, 0, 0), Color3.fromRGB(80, 60, 44), M.Metal, CYL)
end
-- a chef's knife: straight edge, the spine sweeping down to the point, riveted wooden handle
BUILD.knife = function(m)
	local c = A(0, 0, R(18))
	local blade = Color3.fromRGB(176, 180, 186)
	mk(m, Vector3.new(1.7, 0.44, 0.06), c * CFrame.new(0.85, 0, 0), blade, M.Metal)
	mk(m, Vector3.new(0.06, 0.44, 0.75), c * CFrame.new(2.075, 0, 0) * A(0, R(-90), 0), blade, M.Metal, "wedge")
	-- the ground edge, a lighter strip along the bottom
	mk(m, Vector3.new(1.7, 0.07, 0.064), c * CFrame.new(0.85, -0.19, 0), Color3.fromRGB(222, 225, 230), M.Metal)
	mk(m, Vector3.new(0.064, 0.07, 0.74), c * CFrame.new(2.07, -0.19, 0) * A(0, R(-90), 0), Color3.fromRGB(222, 225, 230), M.Metal)
	mk(m, Vector3.new(0.14, 0.5, 0.13), c * CFrame.new(-0.07, 0.01, 0), Color3.fromRGB(60, 62, 66), M.Metal)
	mk(m, Vector3.new(1.15, 0.36, 0.17), c * CFrame.new(-0.72, -0.02, 0), Color3.fromRGB(62, 40, 26), M.Wood)
	mk(m, Vector3.new(0.2, 0.36, 0.17), c * CFrame.new(-1.33, -0.02, 0), Color3.fromRGB(62, 40, 26), M.Wood, BALL)
	for _, x in ipairs({-0.35, -0.72, -1.09}) do
		mk(m, Vector3.new(0.19, 0.08, 0.08), c * CFrame.new(x, -0.02, 0) * A(0, R(90), 0), Color3.fromRGB(200, 202, 206), M.Metal, CYL)
	end
end
BUILD.nailbat = function(m)
	local c = A(0, 0, R(28))
	mk(m, Vector3.new(1.3, 0.26, 0.26), c * CFrame.new(-1.6, 0, 0), Color3.fromRGB(60, 40, 28), M.Fabric, CYL)
	mk(m, Vector3.new(1.3, 0.36, 0.36), c * CFrame.new(-0.4, 0, 0), WOOD, M.Wood, CYL)
	mk(m, Vector3.new(1.6, 0.5, 0.5), c * CFrame.new(1.0, 0, 0), WOOD, M.Wood, CYL)
	mk(m, Vector3.new(0.12, 0.36, 0.36), c * CFrame.new(-2.3, 0, 0), Color3.fromRGB(60, 40, 28), M.Wood, CYL)
	for i = 0, 9 do
		local a = i * 2.4
		mk(m, Vector3.new(0.45, 0.05, 0.05), c * CFrame.new(0.4 + (i % 5) * 0.28, 0, 0) * A(a, 0, 0) * CFrame.new(0, 0.3, 0) * A(0, 0, R(90)),
			STEEL_L, M.Metal, CYL)
	end
end
-- a fire axe: red head, a clean silver edge, a short pick at the back, wooden haft with a rubber grip
BUILD.axe = function(m)
	local c = A(0, 0, R(-22))
	local red = Color3.fromRGB(176, 26, 20)
	local wood = Color3.fromRGB(150, 108, 66)
	local steel = Color3.fromRGB(205, 208, 212)
	mk(m, Vector3.new(0.22, 3.3, 0.18), c * CFrame.new(0, -0.1, 0), wood, M.Wood)
	mk(m, Vector3.new(0.27, 0.95, 0.23), c * CFrame.new(0, -1.35, 0), Color3.fromRGB(26, 26, 28), M.Rubber)
	mk(m, Vector3.new(0.3, 0.12, 0.26), c * CFrame.new(0, -1.78, 0), Color3.fromRGB(26, 26, 28), M.Rubber)
	mk(m, Vector3.new(0.26, 0.14, 0.2), c * CFrame.new(0, 1.72, 0), wood, M.Wood)
	-- head: the eye round the haft, one clean red cheek out to a silver ground edge
	mk(m, Vector3.new(0.44, 0.62, 0.3), c * CFrame.new(0, 1.42, 0), red, M.Metal)
	mk(m, Vector3.new(0.66, 0.7, 0.18), c * CFrame.new(0.52, 1.42, 0), red, M.Metal)
	mk(m, Vector3.new(0.12, 0.78, 0.1), c * CFrame.new(0.91, 1.42, 0), steel, M.Metal)
	mk(m, Vector3.new(0.5, 0.04, 0.19), c * CFrame.new(0.5, 1.42, 0), Color3.fromRGB(120, 16, 12), M.Metal)
	-- the pick: a short even point out of the back of the eye (two wedges, one turned over)
	local back, backDown = A(0, R(90), 0), A(R(180), 0, 0) * A(0, R(90), 0)
	mk(m, Vector3.new(0.16, 0.16, 0.5), c * CFrame.new(-0.47, 1.5, 0) * back, red, M.Metal, "wedge")
	mk(m, Vector3.new(0.16, 0.16, 0.5), c * CFrame.new(-0.47, 1.34, 0) * backDown, red, M.Metal, "wedge")
end
-- a flare pistol: fat orange barrel with a dark bore, hinged breech, hammer, ribbed grip and a trigger guard
BUILD.flaregun = function(m)
	local orange = Color3.fromRGB(232, 98, 22)
	local deep = Color3.fromRGB(190, 70, 14)
	local black = Color3.fromRGB(24, 24, 26)
	mk(m, Vector3.new(1.55, 0.62, 0.62), CFrame.new(0.55, 0.28, 0), orange, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.14, 0.7, 0.7), CFrame.new(1.28, 0.28, 0), deep, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.05, 0.44, 0.44), CFrame.new(1.36, 0.28, 0), black, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.16, 0.7, 0.7), CFrame.new(-0.16, 0.28, 0), deep, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(1.2, 0.06, 0.1), CFrame.new(0.55, 0.61, 0), deep, M.SmoothPlastic)
	mk(m, Vector3.new(0.06, 0.1, 0.06), CFrame.new(1.2, 0.66, 0), black, M.SmoothPlastic)
	-- breech block, hinge pin and the hammer on top at the back
	mk(m, Vector3.new(0.6, 0.7, 0.48), CFrame.new(-0.5, 0.22, 0), orange, M.SmoothPlastic)
	mk(m, Vector3.new(0.52, 0.14, 0.14), CFrame.new(-0.24, -0.06, 0) * A(0, R(90), 0), black, M.Metal, CYL)
	mk(m, Vector3.new(0.12, 0.26, 0.14), CFrame.new(-0.74, 0.62, 0) * A(0, 0, R(25)), black, M.Metal)
	mk(m, Vector3.new(0.14, 0.08, 0.18), CFrame.new(-0.8, 0.74, 0) * A(0, 0, R(25)), black, M.Metal)
	-- grip under the back of the breech, leaning back, with dark ribbed panels
	local grip = CFrame.new(-0.72, -0.5, 0) * A(0, 0, R(14))
	mk(m, Vector3.new(0.5, 1.15, 0.44), grip, orange, M.SmoothPlastic)
	for _, z in ipairs({-0.23, 0.23}) do
		mk(m, Vector3.new(0.36, 0.85, 0.03), grip * CFrame.new(0, -0.05, z), black, M.SmoothPlastic)
		for i = -2, 2 do
			mk(m, Vector3.new(0.3, 0.04, 0.04), grip * CFrame.new(0, i * 0.15, z * 1.08), Color3.fromRGB(46, 46, 48), M.SmoothPlastic)
		end
	end
	mk(m, Vector3.new(0.54, 0.1, 0.46), grip * CFrame.new(0, -0.6, 0), deep, M.SmoothPlastic)
	mk(m, Vector3.new(0.06, 0.16, 0.16), grip * CFrame.new(0, -0.7, 0) * A(0, R(90), 0), black, M.Metal, CYL)
	-- trigger and its guard
	mk(m, Vector3.new(0.07, 0.26, 0.07), CFrame.new(-0.3, -0.24, 0) * A(0, 0, R(-12)), black, M.Metal)
	mk(m, Vector3.new(0.46, 0.06, 0.09), CFrame.new(-0.28, -0.42, 0), deep, M.SmoothPlastic)
	mk(m, Vector3.new(0.06, 0.32, 0.09), CFrame.new(-0.05, -0.27, 0), deep, M.SmoothPlastic)
end
BUILD.bandage = function(m)
	mk(m, Vector3.new(0.7, 1.1, 1.1), A(0, R(30), 0), Color3.fromRGB(226, 220, 206), M.Fabric, CYL)
	mk(m, Vector3.new(0.72, 0.4, 0.4), A(0, R(30), 0), Color3.fromRGB(160, 150, 130), M.Fabric, CYL)
	mk(m, Vector3.new(0.6, 0.04, 1.4), A(0, R(30), 0) * CFrame.new(0, -0.53, -0.6) * A(R(-12), 0, 0), Color3.fromRGB(226, 220, 206), M.Fabric)
	mk(m, Vector3.new(0.2, 0.05, 0.4), A(0, R(30), 0) * CFrame.new(0, -0.55, -1.2), Color3.fromRGB(150, 30, 26), M.Fabric)
end
BUILD.painkillers = function(m)
	local b = mk(m, Vector3.new(1.2, 0.7, 0.7), A(0, 0, R(90)), Color3.fromRGB(210, 110, 30), M.Glass, CYL, 0.25)
	b.Reflectance = 0
	mk(m, Vector3.new(0.3, 0.78, 0.78), A(0, 0, R(90)) * CFrame.new(0.72, 0, 0), Color3.fromRGB(235, 232, 225), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.5, 0.72, 0.72), A(0, 0, R(90)) * CFrame.new(-0.05, 0, 0), Color3.fromRGB(240, 236, 228), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.22, 0.04, 0.3), CFrame.new(0, -0.05, -0.37), Color3.fromRGB(170, 24, 24), M.SmoothPlastic)
	for i = 0, 3 do mk(m, Vector3.new(0.16, 0.08, 0.16), CFrame.new(0.3 + i * 0.15, -0.56, -0.5 + i * 0.1), INK, M.SmoothPlastic, BALL) end
end
BUILD.splint = function(m)
	local c = A(0, 0, R(18))
	for _, z in ipairs({-0.3, 0.3}) do mk(m, Vector3.new(3, 0.12, 0.3), c * CFrame.new(0, 0, z), Color3.fromRGB(150, 118, 78), M.Wood) end
	for _, x in ipairs({-1, 0, 1}) do mk(m, Vector3.new(0.3, 0.25, 0.86), c * CFrame.new(x, 0, 0), Color3.fromRGB(205, 200, 185), M.Fabric) end
	mk(m, Vector3.new(0.08, 0.25, 0.25), c * CFrame.new(1.3, 0.1, 0.7) * A(0, R(40), 0), Color3.fromRGB(205, 200, 185), M.Fabric)
end
BUILD.flare = function(m)
	local c = A(0, 0, R(60))
	mk(m, Vector3.new(2, 0.34, 0.34), c, Color3.fromRGB(190, 30, 24), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.35, 0.38, 0.38), c * CFrame.new(1.1, 0, 0), DARK, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.5, 0.35, 0.35), c * CFrame.new(-0.4, 0, 0), Color3.fromRGB(235, 225, 200), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.12, 0.3, 0.3), c * CFrame.new(-1.05, 0, 0), Color3.fromRGB(255, 110, 60), M.Neon, CYL)
end
-- a first aid case: red box with rounded edges, a white panel with a red cross, latches and a carry handle
BUILD.medkit = function(m)
	local red = Color3.fromRGB(178, 28, 28)
	local dark = Color3.fromRGB(110, 16, 16)
	mk(m, Vector3.new(1.84, 1.3, 0.72), CFrame.new(), red, M.SmoothPlastic)
	mk(m, Vector3.new(2.0, 1.14, 0.72), CFrame.new(), red, M.SmoothPlastic)
	for _, x in ipairs({-0.92, 0.92}) do
		for _, y in ipairs({-0.57, 0.57}) do
			mk(m, Vector3.new(0.72, 0.16, 0.16), CFrame.new(x, y, 0) * A(0, R(90), 0), red, M.SmoothPlastic, CYL)
		end
	end
	mk(m, Vector3.new(2.02, 0.05, 0.74), CFrame.new(0, 0.28, 0), dark, M.SmoothPlastic)
	mk(m, Vector3.new(0.98, 0.84, 0.03), CFrame.new(0, -0.1, -0.37), Color3.fromRGB(238, 234, 228), M.SmoothPlastic)
	mk(m, Vector3.new(0.66, 0.2, 0.03), CFrame.new(0, -0.1, -0.39), red, M.SmoothPlastic)
	mk(m, Vector3.new(0.2, 0.66, 0.03), CFrame.new(0, -0.1, -0.39), red, M.SmoothPlastic)
	for _, x in ipairs({-0.72, 0.72}) do
		mk(m, Vector3.new(0.22, 0.16, 0.06), CFrame.new(x, 0.28, -0.38), Color3.fromRGB(190, 192, 196), M.Metal)
		mk(m, Vector3.new(0.1, 0.26, 0.1), CFrame.new(x * 0.5, 0.78, 0), Color3.fromRGB(30, 30, 32), M.SmoothPlastic)
	end
	mk(m, Vector3.new(0.86, 0.13, 0.13), CFrame.new(0, 0.92, 0), Color3.fromRGB(30, 30, 32), M.SmoothPlastic, CYL)
end
BUILD.adrenaline = function(m)
	local c = A(0, 0, R(-35))
	mk(m, Vector3.new(1.4, 0.3, 0.3), c, Color3.fromRGB(220, 225, 230), M.Glass, CYL, 0.5)
	mk(m, Vector3.new(1.1, 0.2, 0.2), c * CFrame.new(-0.05, 0, 0), Color3.fromRGB(255, 190, 40), M.Neon, CYL)
	mk(m, Vector3.new(0.5, 0.1, 0.1), c * CFrame.new(-0.95, 0, 0), STEEL, M.Metal, CYL)
	mk(m, Vector3.new(0.7, 0.03, 0.03), c * CFrame.new(-1.5, 0, 0), STEEL_L, M.Metal, CYL)
	mk(m, Vector3.new(0.08, 0.5, 0.5), c * CFrame.new(0.75, 0, 0), DARK, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.6, 0.1, 0.1), c * CFrame.new(1.05, 0, 0), DARK, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.06, 0.4, 0.4), c * CFrame.new(1.35, 0, 0), DARK, M.SmoothPlastic, CYL)
end
BUILD.jacket = function(m)
	local col = Color3.fromRGB(62, 70, 48)
	mk(m, Vector3.new(1.7, 2, 0.75), CFrame.new(), col, M.Fabric)
	for _, s in ipairs({-1, 1}) do
		mk(m, Vector3.new(0.55, 1.8, 0.6), CFrame.new(s * 1.1, -0.15, 0) * A(0, 0, R(s * 12)), col, M.Fabric)
		mk(m, Vector3.new(0.5, 0.2, 0.55), CFrame.new(s * 1.3, -1.05, 0) * A(0, 0, R(s * 12)), Color3.fromRGB(40, 44, 32), M.Fabric)
	end
	mk(m, Vector3.new(1.1, 0.3, 0.8), CFrame.new(0, 1.05, 0), Color3.fromRGB(48, 54, 38), M.Fabric)
	for i = 0, 3 do mk(m, Vector3.new(1.72, 0.05, 0.77), CFrame.new(0, 0.7 - i * 0.45, 0), Color3.fromRGB(44, 50, 34), M.Fabric) end
	mk(m, Vector3.new(0.06, 1.95, 0.77), CFrame.new(0, 0, 0), DARK, M.Metal)
end
BUILD.legguards = function(m)
	for _, s in ipairs({-1, 1}) do
		local c = CFrame.new(s * 0.55, 0, 0) * A(0, R(s * -10), 0)
		mk(m, Vector3.new(0.7, 1.9, 0.3), c, Color3.fromRGB(44, 46, 50), M.SmoothPlastic)
		mk(m, Vector3.new(0.55, 1.6, 0.1), c * CFrame.new(0, -0.05, -0.18), Color3.fromRGB(64, 66, 70), M.Metal)
		mk(m, Vector3.new(0.72, 0.6, 0.5), c * CFrame.new(0, 1.05, -0.05), Color3.fromRGB(58, 60, 64), M.SmoothPlastic, BALL)
		for _, y in ipairs({-0.5, 0.4}) do mk(m, Vector3.new(0.76, 0.14, 0.34), c * CFrame.new(0, y, 0.02), DARK, M.Fabric) end
	end
end
-- a gas mask: black rubber face, two round lenses in metal rims, a filter canister hanging under the chin, straps
BUILD.gasmask = function(m)
	local rubber = Color3.fromRGB(38, 39, 41)
	mk(m, Vector3.new(1.34, 1.45, 0.95), CFrame.new(0, 0.08, 0), rubber, M.Rubber, BALL)
	mk(m, Vector3.new(0.95, 0.85, 0.8), CFrame.new(0, -0.42, -0.16), rubber, M.Rubber, BALL)
	mk(m, Vector3.new(0.16, 0.34, 0.2), CFrame.new(0, 0.12, -0.44), Color3.fromRGB(30, 30, 32), M.Rubber)
	for _, s in ipairs({-1, 1}) do
		local eye = CFrame.new(s * 0.31, 0.24, -0.37) * A(0, R(s * 18), 0)
		mk(m, Vector3.new(0.16, 0.54, 0.54), eye * A(0, R(90), 0), Color3.fromRGB(110, 112, 116), M.Metal, CYL)
		mk(m, Vector3.new(0.17, 0.43, 0.43), eye * CFrame.new(0, 0, -0.01) * A(0, R(90), 0), Color3.fromRGB(96, 120, 116), M.Glass, CYL, 0.35)
		mk(m, Vector3.new(0.1, 0.3, 0.3), eye * CFrame.new(0, 0, 0.03) * A(0, R(90), 0), Color3.fromRGB(14, 16, 16), M.SmoothPlastic, CYL)
		-- head straps, running back from the temples and the cheeks
		mk(m, Vector3.new(0.06, 0.14, 0.62), CFrame.new(s * 0.56, 0.36, 0.34), Color3.fromRGB(56, 54, 50), M.Fabric)
		mk(m, Vector3.new(0.06, 0.12, 0.5), CFrame.new(s * 0.46, -0.34, 0.28), Color3.fromRGB(56, 54, 50), M.Fabric)
	end
	-- the filter: a short olive canister angled down under the chin, ribbed, with a dark perforated cap
	local filter = CFrame.new(0, -0.66, -0.46) * A(R(48), 0, 0)
	mk(m, Vector3.new(0.2, 0.38, 0.38), filter * CFrame.new(0, 0, 0.1) * A(0, R(90), 0), Color3.fromRGB(56, 58, 60), M.Metal, CYL)
	mk(m, Vector3.new(0.46, 0.56, 0.56), filter * CFrame.new(0, 0, -0.2) * A(0, R(90), 0), Color3.fromRGB(78, 88, 56), M.Metal, CYL)
	for _, z in ipairs({-0.08, -0.32}) do
		mk(m, Vector3.new(0.05, 0.6, 0.6), filter * CFrame.new(0, 0, z) * A(0, R(90), 0), Color3.fromRGB(58, 66, 42), M.Metal, CYL)
	end
	mk(m, Vector3.new(0.04, 0.46, 0.46), filter * CFrame.new(0, 0, -0.44) * A(0, R(90), 0), Color3.fromRGB(26, 26, 26), M.Metal, CYL)
end
BUILD.helmet = function(m)
	local col = Color3.fromRGB(34, 38, 50)
	mk(m, Vector3.new(1.6, 1.3, 1.7), CFrame.new(0, 0.2, 0), col, M.SmoothPlastic, BALL)
	mk(m, Vector3.new(0.18, 1.7, 1.8), CFrame.new(0, -0.25, 0) * A(0, 0, R(90)), col, M.SmoothPlastic, CYL)
	local visor = mk(m, Vector3.new(1.5, 0.7, 0.1), CFrame.new(0, -0.2, -0.86) * A(R(-10), 0, 0), Color3.fromRGB(160, 180, 200), M.Glass, nil, 0.45)
	visor.Reflectance = 0
	mk(m, Vector3.new(1.6, 0.12, 0.14), CFrame.new(0, 0.18, -0.82), DARK, M.Metal)
	for _, s in ipairs({-1, 1}) do mk(m, Vector3.new(0.1, 0.3, 0.3), CFrame.new(s * 0.8, -0.05, -0.55) * A(0, 0, R(90)), STEEL_L, M.Metal, CYL) end
end
BUILD.vest = function(m)
	local col = Color3.fromRGB(30, 32, 30)
	mk(m, Vector3.new(1.7, 2.0, 0.6), CFrame.new(), col, M.Fabric)
	mk(m, Vector3.new(1.35, 1.35, 0.12), CFrame.new(0, 0.15, -0.34), Color3.fromRGB(44, 46, 44), M.Fabric)
	for _, s in ipairs({-1, 1}) do mk(m, Vector3.new(0.4, 0.3, 0.64), CFrame.new(s * 0.6, 1.1, 0), col, M.Fabric) end
	for i = -1, 1 do mk(m, Vector3.new(0.38, 0.45, 0.2), CFrame.new(i * 0.45, -0.72, -0.4), OLIVE, M.Fabric) end
	mk(m, Vector3.new(1.0, 0.22, 0.02), CFrame.new(0, 0.55, -0.41), Color3.fromRGB(205, 200, 190), M.SmoothPlastic)
end

-- ===== guns, the baton, ammo and the trap =====
local GUNMETAL, BLUED = Color3.fromRGB(46, 48, 52), Color3.fromRGB(30, 32, 36)
local WALNUT, WALNUT_D = Color3.fromRGB(104, 62, 36), Color3.fromRGB(74, 42, 24)
local BRASS = Color3.fromRGB(196, 160, 72)

-- side-by-side double barrel: two blued barrels, a rib and a bead, walnut forend and stock, the hinge block
BUILD.doublebarrel = function(m)
	for _, z in ipairs({-0.125, 0.125}) do
		mk(m, Vector3.new(3.2, 0.24, 0.24), CFrame.new(1.72, 0.2, z), BLUED, M.Metal, CYL)
		mk(m, Vector3.new(0.03, 0.16, 0.16), CFrame.new(3.33, 0.2, z), Color3.fromRGB(8, 8, 8), M.SmoothPlastic, CYL)
		mk(m, Vector3.new(0.12, 0.27, 0.27), CFrame.new(3.26, 0.2, z), GUNMETAL, M.Metal, CYL)
	end
	mk(m, Vector3.new(3.1, 0.05, 0.1), CFrame.new(1.72, 0.33, 0), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.06, 0.06, 0.06), CFrame.new(3.22, 0.37, 0), BRASS, M.Metal, BALL)
	mk(m, Vector3.new(1.15, 0.22, 0.38), CFrame.new(0.95, 0.03, 0), WALNUT, M.Wood)
	mk(m, Vector3.new(1.15, 0.04, 0.4), CFrame.new(0.95, 0.14, 0), WALNUT_D, M.Wood)
	-- the action: hinge block, top lever, engraved side plates
	mk(m, Vector3.new(0.58, 0.44, 0.42), CFrame.new(0.02, 0.12, 0), Color3.fromRGB(150, 152, 156), M.Metal)
	for _, z in ipairs({-0.215, 0.215}) do
		mk(m, Vector3.new(0.44, 0.3, 0.02), CFrame.new(0.02, 0.1, z), Color3.fromRGB(120, 122, 126), M.DiamondPlate)
	end
	mk(m, Vector3.new(0.26, 0.05, 0.08), CFrame.new(-0.12, 0.36, 0.08) * A(0, R(20), 0), GUNMETAL, M.Metal)
	-- trigger and guard
	mk(m, Vector3.new(0.05, 0.2, 0.05), CFrame.new(-0.05, -0.12, 0) * A(0, 0, R(-10)), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.42, 0.05, 0.08), CFrame.new(-0.05, -0.25, 0), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.05, 0.16, 0.08), CFrame.new(0.15, -0.17, 0), GUNMETAL, M.Metal)
	-- wrist and stock, dropping a little towards the butt
	local stock = CFrame.new(-0.25, 0.02, 0) * A(0, 0, R(-7))
	mk(m, Vector3.new(0.7, 0.3, 0.3), stock * CFrame.new(-0.32, 0, 0), WALNUT, M.Wood)
	mk(m, Vector3.new(1.35, 0.5, 0.34), stock * CFrame.new(-1.3, -0.12, 0), WALNUT, M.Wood)
	mk(m, Vector3.new(1.1, 0.05, 0.345), stock * CFrame.new(-1.25, 0.12, 0), WALNUT_D, M.Wood)
	mk(m, Vector3.new(0.06, 0.58, 0.36), stock * CFrame.new(-2.0, -0.14, 0), Color3.fromRGB(26, 22, 20), M.Rubber)
end

-- WARDEN 870: a black pump gun. Receiver, barrel over the tube, ribbed pump, pistol grip, side-saddle shells
BUILD.warden870 = function(m)
	local black = Color3.fromRGB(24, 24, 26)
	mk(m, Vector3.new(0.95, 0.44, 0.3), CFrame.new(0, 0.12, 0), black, M.Metal)
	mk(m, Vector3.new(0.9, 0.06, 0.1), CFrame.new(0, 0.37, 0), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.34, 0.2, 0.02), CFrame.new(0.05, 0.14, 0.16), Color3.fromRGB(12, 12, 12), M.SmoothPlastic)
	mk(m, Vector3.new(2.7, 0.19, 0.19), CFrame.new(1.8, 0.22, 0), GUNMETAL, M.Metal, CYL)
	mk(m, Vector3.new(0.03, 0.13, 0.13), CFrame.new(3.16, 0.22, 0), Color3.fromRGB(8, 8, 8), M.SmoothPlastic, CYL)
	mk(m, Vector3.new(2.1, 0.17, 0.17), CFrame.new(1.5, 0.0, 0), black, M.Metal, CYL)
	mk(m, Vector3.new(0.12, 0.22, 0.2), CFrame.new(2.55, 0.1, 0), black, M.Metal)
	-- the pump, ribbed
	mk(m, Vector3.new(0.85, 0.27, 0.33), CFrame.new(1.2, 0.0, 0), Color3.fromRGB(34, 34, 36), M.SmoothPlastic)
	for i = -3, 3 do mk(m, Vector3.new(0.04, 0.29, 0.35), CFrame.new(1.2 + i * 0.1, 0, 0), black, M.SmoothPlastic) end
	-- sights
	mk(m, Vector3.new(0.05, 0.1, 0.05), CFrame.new(3.05, 0.36, 0), Color3.fromRGB(230, 90, 30), M.Neon)
	mk(m, Vector3.new(0.1, 0.12, 0.16), CFrame.new(-0.35, 0.42, 0), black, M.Metal)
	-- four spare shells on the left of the receiver
	for i = 0, 3 do
		mk(m, Vector3.new(0.34, 0.1, 0.1), CFrame.new(-0.1 + i * 0.12, 0.12, -0.2) * A(0, 0, R(90)), Color3.fromRGB(170, 24, 24), M.SmoothPlastic, CYL)
		mk(m, Vector3.new(0.08, 0.105, 0.105), CFrame.new(-0.1 + i * 0.12, -0.02, -0.2) * A(0, 0, R(90)), BRASS, M.Metal, CYL)
	end
	-- trigger, guard, pistol grip, stock with a rubber pad
	mk(m, Vector3.new(0.05, 0.18, 0.05), CFrame.new(-0.2, -0.14, 0), GUNMETAL, M.Metal)
	mk(m, Vector3.new(0.4, 0.05, 0.08), CFrame.new(-0.2, -0.26, 0), black, M.Metal)
	mk(m, Vector3.new(0.26, 0.62, 0.26), CFrame.new(-0.52, -0.32, 0) * A(0, 0, R(18)), Color3.fromRGB(30, 30, 32), M.Rubber)
	mk(m, Vector3.new(1.35, 0.32, 0.24), CFrame.new(-1.15, 0.05, 0), black, M.SmoothPlastic)
	mk(m, Vector3.new(0.9, 0.18, 0.24), CFrame.new(-1.2, -0.2, 0) * A(0, 0, R(-10)), black, M.SmoothPlastic)
	mk(m, Vector3.new(0.12, 0.6, 0.3), CFrame.new(-1.86, -0.05, 0), Color3.fromRGB(40, 40, 42), M.Rubber)
end

-- shock baton: rubber handle, guard ring, black shaft, two prongs and a blue ring at the tip
BUILD.shockbaton = function(m)
	local black = Color3.fromRGB(22, 22, 24)
	mk(m, Vector3.new(1.0, 0.26, 0.26), CFrame.new(-0.75, 0, 0), Color3.fromRGB(34, 34, 36), M.Rubber, CYL)
	for i = 0, 4 do mk(m, Vector3.new(0.05, 0.28, 0.28), CFrame.new(-1.15 + i * 0.2, 0, 0), black, M.Rubber, CYL) end
	mk(m, Vector3.new(0.1, 0.36, 0.36), CFrame.new(-0.2, 0, 0), GUNMETAL, M.Metal, CYL)
	mk(m, Vector3.new(1.7, 0.2, 0.2), CFrame.new(0.72, 0, 0), black, M.SmoothPlastic, CYL)
	mk(m, Vector3.new(0.12, 0.2, 0.08), CFrame.new(-0.55, 0.14, 0), Color3.fromRGB(200, 40, 30), M.SmoothPlastic)
	local ring = mk(m, Vector3.new(0.06, 0.24, 0.24), CFrame.new(1.52, 0, 0), Color3.fromRGB(110, 170, 255), M.Neon, CYL)
	ring.Name = "GS_ShockRing"
	for _, z in ipairs({-0.06, 0.06}) do mk(m, Vector3.new(0.14, 0.04, 0.04), CFrame.new(1.63, 0, z), Color3.fromRGB(190, 192, 196), M.Metal) end
	mk(m, Vector3.new(0.12, 0.28, 0.28), CFrame.new(-1.3, 0, 0), black, M.Metal, CYL)
end

-- a box of buckshot: red and cream cardboard with shells lying in front
BUILD.shells12 = function(m)
	mk(m, Vector3.new(1.2, 0.72, 0.8), CFrame.new(0, 0, 0.2), Color3.fromRGB(150, 30, 26), M.Cardboard)
	mk(m, Vector3.new(1.22, 0.22, 0.82), CFrame.new(0, 0.18, 0.2), Color3.fromRGB(226, 214, 186), M.Cardboard)
	mk(m, Vector3.new(0.6, 0.12, 0.02), CFrame.new(0, 0.18, -0.21), Color3.fromRGB(40, 36, 32), M.SmoothPlastic)
	for i = 0, 2 do
		local c = CFrame.new(-0.4 + i * 0.36, -0.28, -0.45) * A(0, R(20 + i * 30), 0)
		mk(m, Vector3.new(0.6, 0.16, 0.16), c, Color3.fromRGB(176, 26, 26), M.SmoothPlastic, CYL)
		mk(m, Vector3.new(0.14, 0.17, 0.17), c * CFrame.new(-0.3, 0, 0), BRASS, M.Metal, CYL)
	end
end
BUILD.flareshell = function(m)
	for _, z in ipairs({-0.25, 0.25}) do
		local c = CFrame.new(0, 0, z) * A(0, 0, R(90))
		mk(m, Vector3.new(0.9, 0.36, 0.36), c, Color3.fromRGB(232, 98, 22), M.SmoothPlastic, CYL)
		mk(m, Vector3.new(0.14, 0.4, 0.4), c * CFrame.new(-0.46, 0, 0), BRASS, M.Metal, CYL)
		mk(m, Vector3.new(0.04, 0.24, 0.24), c * CFrame.new(0.46, 0, 0), Color3.fromRGB(255, 70, 40), M.Neon, CYL)
	end
end

-- a bear trap, set: a base plate, two toothed jaws lying open, springs, a chain and a stake.
-- The jaws are sub-models (JawA / JawB) so a placed trap can snap them shut.
BUILD.beartrap = function(m)
	local steel = Color3.fromRGB(78, 70, 62)
	mk(m, Vector3.new(0.1, 0.9, 0.9), A(0, 0, R(90)), Color3.fromRGB(60, 54, 48), M.CorrodedMetal, CYL)
	mk(m, Vector3.new(0.12, 0.34, 0.34), CFrame.new(0, 0.04, 0) * A(0, 0, R(90)), Color3.fromRGB(140, 120, 90), M.Metal, CYL)
	for j, side in ipairs({-1, 1}) do
		local jaw = Instance.new("Model")
		jaw.Name = j == 1 and "JawA" or "JawB"
		jaw.Parent = m
		for i = 0, 6 do
			local a = math.pi * (i / 6)
			local x, z = math.cos(a) * 0.95, math.sin(a) * 0.95 * side
			mk(jaw, Vector3.new(0.3, 0.1, 0.1), CFrame.new(x, 0.02, z) * A(0, -a * side + math.pi / 2, 0), steel, M.CorrodedMetal)
			mk(jaw, Vector3.new(0.07, 0.22, 0.07), CFrame.new(x * 0.9, 0.12, z * 0.9) * A(0, 0, 0), Color3.fromRGB(170, 160, 146), M.Metal)
		end
	end
	for _, x in ipairs({-1.25, 1.25}) do
		mk(m, Vector3.new(0.7, 0.14, 0.2), CFrame.new(x, 0.02, 0), steel, M.CorrodedMetal)
		mk(m, Vector3.new(0.3, 0.2, 0.2), CFrame.new(x * 1.2, 0.02, 0) * A(0, 0, R(90)), Color3.fromRGB(60, 54, 48), M.Metal, CYL)
	end
	for i = 1, 4 do mk(m, Vector3.new(0.18, 0.06, 0.12), CFrame.new(0, 0, 0.9 + i * 0.16) * A(0, R(i % 2 * 90), 0), Color3.fromRGB(90, 84, 76), M.Metal) end
	mk(m, Vector3.new(0.12, 0.5, 0.12), CFrame.new(0, 0.1, 1.72), Color3.fromRGB(90, 84, 76), M.Metal)
end

-- armor without a shop model of its own is shown on an invisible body
local Wearables = nil
local function wearableDisplay(id)
	return function(m)
		if not Wearables then
			Wearables = require(script.Parent:WaitForChild("Wearables"))
		end
		Wearables.Display(id, m)
	end
end
for _, id in ipairs({"armguards", "scg_helmet", "scg_vest", "scg_arms", "scg_legs"}) do
	BUILD[id] = wearableDisplay(id)
end

-- where the hand holds each item: X points from the hand along the item, Y is its top
local function axeGrip()
	local c = A(0, 0, R(-22)) * CFrame.new(0, -1.25, 0)
	return c * CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.xAxis, -Vector3.zAxis)
end
ShopModels.Grip = {
	pipe = A(0, 0, R(25)) * CFrame.new(-1.45, 0, 0),
	knife = A(0, 0, R(18)) * CFrame.new(-0.78, -0.02, 0),
	nailbat = A(0, 0, R(28)) * CFrame.new(-1.75, 0, 0),
	axe = axeGrip(),
	flaregun = CFrame.new(-0.62, -0.3, 0),
	doublebarrel = CFrame.new(-0.42, -0.06, 0),
	warden870 = CFrame.new(-0.46, -0.24, 0),
	shockbaton = CFrame.new(-0.8, 0, 0),
}
-- items are modelled at shop-window size; in the hand some are shrunk
ShopModels.HeldScale = {
	pipe = 0.85, knife = 0.8, nailbat = 0.85, axe = 0.85, flaregun = 0.7, doublebarrel = 0.8, warden870 = 0.8,
	shockbaton = 0.8, bandage = 0.45, painkillers = 0.45, splint = 0.5, medkit = 0.55, adrenaline = 0.5, flare = 0.55,
	beartrap = 0.7, shells12 = 0.5, flareshell = 0.5,
}

function ShopModels.Build(id)
	local m = Instance.new("Model")
	m.Name = id
	local fn = BUILD[id]
	if fn then fn(m) end
	m.WorldPivot = CFrame.new()
	return m
end

function ShopModels.Has(id)
	return BUILD[id] ~= nil
end

return ShopModels
