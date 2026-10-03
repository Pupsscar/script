--!nocheck
--[[
	MARROW ANIMATOR  - keyframe animation for Roblox Studio

	Animate anything that is built from Motor6D joints (R6, R15, creatures, weapons, props with joints), plus
	properties of any object (lights, parts, models, GUI, sounds, effects) and the camera, on one timeline.

	  * projects live inside the place (ServerStorage > MarrowAnimations): Studio's own Undo / Redo works on
	    everything, Team Create sees the same animations, nothing is lost when Studio closes
	  * POSE mode: click a body part in the viewport, turn it with the rotate rings or slide it with the move
	    arrows (local / world space, angle and distance snapping); Auto-key writes the key for you
	  * timeline: zoom (Ctrl + wheel), pan (Shift + wheel or middle mouse), box select, drag keys in time,
	    Ctrl + drag duplicates, double-click adds a key, right-click for everything else
	  * 12 easing styles x 3 directions per key with a live curve preview - exported exactly as you see them
	  * onion skin (ghosts of the previous and next key poses) and a motion path for the selected part
	  * copy / paste keys and whole poses, mirror a pose left <-> right, paste mirrored, reset joints
	  * events (KeyframeMarkers for AnimationTrack:GetMarkerReachedSignal)
	  * property and camera tracks; a cutscene ModuleScript plays joints, properties, camera and events in game
	    without uploading anything
	  * import from a KeyframeSequence or an animation ID, export to a KeyframeSequence (RBX_ANIMSAVES, so the
	    built-in Animation Editor can open it too) and publish it straight to Roblox
	  * numeric pose input, frame-exact playback with loop and speed, insert / remove time, close the loop,
	    reverse and stretch keys, change FPS without losing timing, simplify baked animations, a pose library

	Install: put this file into your Plugins folder (Studio > Plugins tab > Plugins Folder) and restart Studio,
	or put it in a Script and right-click > Save as Local Plugin / Publish as Plugin.
]]

if not plugin then
	warn("[Marrow Animator] This is a plugin. Put the file in your Plugins folder (Plugins tab > Plugins Folder) or publish it as a plugin.")
	return
end

local VERSION = "1.1.0"
-- toolbar icon: upload MarrowAnimatorIcon.png (Creator Dashboard > Development Items > Decals / Images) and put its
-- image ID here, for example "rbxassetid://1234567890". Empty = the button shows only its name.
local ICON = ""

local Svc = {
	Selection = game:GetService("Selection"),
	History = game:GetService("ChangeHistoryService"),
	Run = game:GetService("RunService"),
	Tween = game:GetService("TweenService"),
	UIS = game:GetService("UserInputService"),
	ServerStorage = game:GetService("ServerStorage"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	CoreGui = game:GetService("CoreGui"),
	KSP = game:GetService("KeyframeSequenceProvider"),
}

-- the look: near-black panels, bone-white text and keys, marrow red for what is selected or playing
local T = {
	bg = Color3.fromRGB(20, 20, 23),
	panel = Color3.fromRGB(28, 28, 32),
	panel2 = Color3.fromRGB(39, 39, 45),
	panel3 = Color3.fromRGB(52, 52, 60),
	row = Color3.fromRGB(31, 31, 36),
	rowAlt = Color3.fromRGB(26, 26, 30),
	rowSel = Color3.fromRGB(62, 38, 38),
	line = Color3.fromRGB(58, 58, 66),
	text = Color3.fromRGB(228, 226, 222),
	dim = Color3.fromRGB(150, 148, 156),
	faint = Color3.fromRGB(92, 92, 102),
	bone = Color3.fromRGB(238, 226, 202),
	accent = Color3.fromRGB(222, 82, 74),
	accentDim = Color3.fromRGB(118, 44, 42),
	amber = Color3.fromRGB(242, 168, 76),
	green = Color3.fromRGB(112, 204, 132),
	blue = Color3.fromRGB(104, 156, 255),
	violet = Color3.fromRGB(178, 132, 255),
	font = Enum.Font.Gotham,
	bold = Enum.Font.GothamBold,
	mono = Enum.Font.Code,
}

-- sizes of the window's parts (pixels)
local L = {BAR = 30, STATUS = 22, LEFT = 230, RIGHT = 272, RULER = 26, ROW = 22}

-- every part of the plugin lives in one of these tables (keeps the number of top-level locals low)
local U, Ease, Hist, Store, Rig, Anim, View, Gizmo, S, UI, Draw, Act, IO = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}

-- ===================================================================================================
-- utilities
-- ===================================================================================================
function U.new(class, props, children)
	local o = Instance.new(class)
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then parent = v else o[k] = v end
		end
	end
	if children then
		for _, c in ipairs(children) do c.Parent = o end
	end
	if parent then o.Parent = parent end
	return o
end

function U.corner(r) return U.new("UICorner", {CornerRadius = UDim.new(0, r or 4)}) end
function U.stroke(color, thickness, transparency)
	return U.new("UIStroke", {Color = color or T.line, Thickness = thickness or 1, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
function U.round(x) return math.floor(x + 0.5) end
function U.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

-- 1.50 -> "1.5", 2.00 -> "2", 10 -> "10"
function U.fmt(n, digits)
	local s = string.format("%." .. (digits or 2) .. "f", n)
	if s:find("%.") then
		s = s:gsub("0+$", "")
		s = s:gsub("%.$", "")
	end
	if s == "-0" then s = "0" end
	return s
end

-- the angle (radians) of a rotation
function U.angleOf(cf)
	local _, angle = cf:ToAxisAngle()
	return math.abs(angle)
end

-- blend two CFrames; t may go below 0 or above 1 (overshooting easings like Back and Elastic)
function U.blend(a, b, t)
	if t == 0 then return a elseif t == 1 then return b end
	local rel = a.Rotation:Inverse() * b.Rotation
	local axis, angle = rel:ToAxisAngle()
	if angle > math.pi then angle -= 2 * math.pi end
	local rot
	if angle ~= angle or math.abs(angle) < 1e-7 or axis.Magnitude < 0.5 then
		rot = a.Rotation
	else
		rot = a.Rotation * CFrame.fromAxisAngle(axis, angle * t)
	end
	return CFrame.new(a.Position + (b.Position - a.Position) * t) * rot
end

-- mirror a CFrame across its parent's YZ plane (left <-> right)
function U.mirror(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- "Left Arm" <-> "Right Arm", "LeftUpperLeg" <-> "RightUpperLeg"
function U.partnerName(name)
	if name:find("Left") then return (name:gsub("Left", "Right")) end
	if name:find("Right") then return (name:gsub("Right", "Left")) end
	if name:find("left") then return (name:gsub("left", "right")) end
	if name:find("right") then return (name:gsub("right", "left")) end
	return nil
end

function U.pathOf(inst)
	local parts = {}
	local cur = inst
	while cur and cur ~= game do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return parts
end

-- the kinds of value a property track can animate
local KINDS = {number = true, boolean = true, Vector3 = true, Vector2 = true, Color3 = true, CFrame = true, UDim2 = true, UDim = true}
function U.valueKind(v)
	local t = typeof(v)
	return KINDS[t] and t or nil
end

function U.lerpValue(a, b, t, kind)
	if typeof(a) ~= typeof(b) then return t < 1 and a or b end
	if kind == "number" then return a + (b - a) * t
	elseif kind == "Vector3" or kind == "Vector2" then return a + (b - a) * t
	elseif kind == "Color3" then return a:Lerp(b, U.clamp(t, 0, 1))
	elseif kind == "CFrame" then return U.blend(a, b, t)
	elseif kind == "UDim2" then
		return UDim2.new(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t,
			a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)
	elseif kind == "UDim" then
		return UDim.new(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t)
	end
	return t < 1 and a or b
end

function U.num(x)
	if x ~= x or x == math.huge or x == -math.huge then return "0" end
	local s = string.format("%.7g", x)
	return s
end

-- a value as Luau source (for the cutscene export)
function U.literal(v)
	local t = typeof(v)
	if t == "number" then return U.num(v)
	elseif t == "boolean" then return tostring(v)
	elseif t == "string" then return string.format("%q", v)
	elseif t == "Vector3" then return ("Vector3.new(%s, %s, %s)"):format(U.num(v.X), U.num(v.Y), U.num(v.Z))
	elseif t == "Vector2" then return ("Vector2.new(%s, %s)"):format(U.num(v.X), U.num(v.Y))
	elseif t == "Color3" then return ("Color3.new(%s, %s, %s)"):format(U.num(v.R), U.num(v.G), U.num(v.B))
	elseif t == "UDim2" then
		return ("UDim2.new(%s, %s, %s, %s)"):format(U.num(v.X.Scale), U.num(v.X.Offset), U.num(v.Y.Scale), U.num(v.Y.Offset))
	elseif t == "UDim" then return ("UDim.new(%s, %s)"):format(U.num(v.Scale), U.num(v.Offset))
	elseif t == "CFrame" then
		local c = {v:GetComponents()}
		for i, x in ipairs(c) do c[i] = U.num(x) end
		return "CFrame.new(" .. table.concat(c, ", ") .. ")"
	end
	return "nil"
end

-- a short readable text for a value (inspector)
function U.valueText(v)
	local t = typeof(v)
	if t == "number" then return U.fmt(v, 3)
	elseif t == "boolean" then return v and "true" or "false"
	elseif t == "Vector3" then return U.fmt(v.X) .. ", " .. U.fmt(v.Y) .. ", " .. U.fmt(v.Z)
	elseif t == "Vector2" then return U.fmt(v.X) .. ", " .. U.fmt(v.Y)
	elseif t == "Color3" then return ("%d, %d, %d"):format(U.round(v.R * 255), U.round(v.G * 255), U.round(v.B * 255))
	elseif t == "CFrame" then
		local p = v.Position
		local rx, ry, rz = v:ToEulerAnglesXYZ()
		return ("pos %s, %s, %s  rot %s, %s, %s"):format(U.fmt(p.X, 1), U.fmt(p.Y, 1), U.fmt(p.Z, 1),
			U.fmt(math.deg(rx), 0), U.fmt(math.deg(ry), 0), U.fmt(math.deg(rz), 0))
	elseif t == "UDim2" then return ("{%s, %s}, {%s, %s}"):format(U.fmt(v.X.Scale), U.fmt(v.X.Offset, 0), U.fmt(v.Y.Scale), U.fmt(v.Y.Offset, 0))
	elseif t == "UDim" then return ("%s, %s"):format(U.fmt(v.Scale), U.fmt(v.Offset, 0))
	end
	return tostring(v)
end

-- parse what someone typed into a value of the same kind
function U.parseValue(text, kind)
	local nums = {}
	local clean = tostring(text):gsub("[{}%(%)%[%]]", " ")
	for token in clean:gmatch("[^,%s;]+") do
		local n = tonumber(token)
		if n then table.insert(nums, n) end
	end
	if kind == "boolean" then
		local l = tostring(text):lower():gsub("%s", "")
		return l == "true" or l == "1" or l == "yes" or l == "on"
	elseif kind == "number" or kind == "emit" then return nums[1]
	elseif kind == "play" then return true
	elseif kind == "Vector3" and #nums >= 3 then return Vector3.new(nums[1], nums[2], nums[3])
	elseif kind == "Vector2" and #nums >= 2 then return Vector2.new(nums[1], nums[2])
	elseif kind == "Color3" and #nums >= 3 then return Color3.fromRGB(nums[1], nums[2], nums[3])
	elseif kind == "UDim2" and #nums >= 4 then return UDim2.new(nums[1], nums[2], nums[3], nums[4])
	elseif kind == "UDim" and #nums >= 2 then return UDim.new(nums[1], nums[2])
	elseif kind == "CFrame" and #nums >= 3 then
		-- "x, y, z" or "x, y, z, rx, ry, rz" (degrees), the way the inspector shows it
		return CFrame.new(nums[1], nums[2], nums[3])
			* CFrame.fromEulerAnglesXYZ(math.rad(nums[4] or 0), math.rad(nums[5] or 0), math.rad(nums[6] or 0))
	end
	return nil
end

local MOD_CODES = {
	Shift = {"LeftShift", "RightShift"},
	Ctrl = {"LeftControl", "RightControl", "LeftMeta", "RightMeta", "LeftSuper", "RightSuper"},
	Alt = {"LeftAlt", "RightAlt"},
}
function U.isDown(input, key)
	local ok, down = pcall(function() return input:IsModifierKeyDown(key) end)
	if ok and down then return true end
	if key == Enum.ModifierKey.Ctrl then
		local okMeta, meta = pcall(function() return input:IsModifierKeyDown(Enum.ModifierKey.Meta) end)
		if okMeta and meta then return true end
	end
	for _, name in ipairs(MOD_CODES[key.Name] or {}) do
		local okKey, pressed = pcall(function() return Svc.UIS:IsKeyDown(Enum.KeyCode[name]) end)
		if okKey and pressed then return true end
	end
	return false
end

-- ===================================================================================================
-- easing
-- ===================================================================================================
Ease.STYLES = {"Linear", "Constant", "Sine", "Quad", "Cubic", "Quart", "Quint", "Exponential", "Circular", "Back", "Bounce", "Elastic"}
Ease.DIRS = {"In", "Out", "InOut"}
Ease.enumStyle = {}
for _, name in ipairs(Ease.STYLES) do
	if name ~= "Constant" then
		local ok, e = pcall(function() return Enum.EasingStyle[name] end)
		if ok and e then Ease.enumStyle[name] = e end
	end
end
Ease.enumDir = {In = Enum.EasingDirection.In, Out = Enum.EasingDirection.Out, InOut = Enum.EasingDirection.InOut}
Ease.PRESETS = {
	{"Linear", "Linear", "InOut"}, {"Hold", "Constant", "InOut"}, {"Smooth", "Cubic", "InOut"}, {"Soft", "Sine", "InOut"},
	{"Ease out", "Quad", "Out"}, {"Ease in", "Quad", "In"}, {"Snap", "Quint", "Out"}, {"Overshoot", "Back", "Out"},
	{"Bounce", "Bounce", "Out"}, {"Elastic", "Elastic", "Out"},
}

-- 0..1 -> eased 0..1 (Back and Elastic go a little past the ends)
function Ease.value(t, style, dir)
	if style == "Constant" then return 0 end
	if style == "Linear" or not style then return t end
	local es = Ease.enumStyle[style]
	if not es then return t end
	return Svc.Tween:GetValue(t, es, Ease.enumDir[dir] or Enum.EasingDirection.InOut)
end

function Ease.color(style)
	if style == "Linear" then return T.dim
	elseif style == "Constant" then return T.accent
	elseif style == "Back" or style == "Bounce" or style == "Elastic" then return T.violet
	end
	return T.bone
end

-- ===================================================================================================
-- history: every change to the animation data is one Studio undo step
-- ===================================================================================================
function Hist.run(name, fn, keepView)
	local id
	pcall(function() id = Svc.History:TryBeginRecording(name, name) end)
	if not id then pcall(function() Svc.History:SetWaypoint("Before " .. name) end) end
	local ok, err = pcall(fn)
	if id then
		pcall(function()
			Svc.History:FinishRecording(id, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
		end)
	elseif ok then
		pcall(function() Svc.History:SetWaypoint(name) end)
	end
	if not ok then
		warn("[Marrow Animator] " .. tostring(err))
		Act.status("Error: " .. tostring(err), true)
	end
	Act.reload(keepView)
	return ok
end

-- ===================================================================================================
-- storage: the animation data as instances in ServerStorage > MarrowAnimations
--   <Animation> (Folder: Fps, Length, Loop, Priority, DefaultStyle, DefaultDir)
--     Rig (ObjectValue)
--     Joints / <joint name> (Folder) / K (CFrameValue = pose, attributes F frame, S style, D direction)
--     Markers / M (Configuration: F, Name, Value)
--     Props / P (Folder: Property, Kind, IsCamera; Target ObjectValue) / K (Configuration: F, S, D, V value)
-- ===================================================================================================
function Store.root(create)
	local r = Svc.ServerStorage:FindFirstChild("MarrowAnimations")
	if not r and create then r = U.new("Folder", {Name = "MarrowAnimations", Parent = Svc.ServerStorage}) end
	return r
end

function Store.list()
	local out = {}
	local r = Store.root(false)
	if r then
		for _, f in ipairs(r:GetChildren()) do
			if f:IsA("Folder") and f:GetAttribute("MarrowVersion") then table.insert(out, f) end
		end
	end
	table.sort(out, function(a, b) return a.Name:lower() < b.Name:lower() end)
	return out
end

function Store.child(folder, name, class)
	local f = folder:FindFirstChild(name)
	if not f then f = U.new(class or "Folder", {Name = name, Parent = folder}) end
	return f
end

function Store.uniqueName(base)
	local used = {}
	for _, f in ipairs(Store.list()) do used[f.Name] = true end
	if not used[base] then return base end
	local i = 2
	while used[base .. " " .. i] do i += 1 end
	return base .. " " .. i
end

function Store.create(name, rig)
	local f = U.new("Folder", {Name = name})
	f:SetAttribute("MarrowVersion", 1)
	f:SetAttribute("Fps", 60)
	f:SetAttribute("Length", 120)
	f:SetAttribute("Loop", false)
	f:SetAttribute("Priority", "Action")
	f:SetAttribute("DefaultStyle", "Cubic")
	f:SetAttribute("DefaultDir", "InOut")
	U.new("ObjectValue", {Name = "Rig", Value = rig, Parent = f})
	Store.child(f, "Joints")
	Store.child(f, "Markers")
	Store.child(f, "Props")
	f.Parent = Store.root(true)
	return f
end

local function byFrame(a, b)
	if a.frame == b.frame then return tostring(a.inst) < tostring(b.inst) end
	return a.frame < b.frame
end

function Store.load(folder)
	local p = {folder = folder, name = folder.Name}
	p.fps = math.max(1, folder:GetAttribute("Fps") or 60)
	p.length = math.max(1, folder:GetAttribute("Length") or 120)
	p.loop = folder:GetAttribute("Loop") == true
	p.priority = folder:GetAttribute("Priority") or "Action"
	p.defStyle = folder:GetAttribute("DefaultStyle") or "Cubic"
	p.defDir = folder:GetAttribute("DefaultDir") or "InOut"
	local rigValue = folder:FindFirstChild("Rig")
	p.rig = (rigValue and rigValue:IsA("ObjectValue")) and rigValue.Value or nil
	p.tracks = {}
	local joints = folder:FindFirstChild("Joints")
	if joints then
		for _, tf in ipairs(joints:GetChildren()) do
			if tf:IsA("Folder") then
				local tr = {name = tf.Name, folder = tf, keys = {}}
				for _, k in ipairs(tf:GetChildren()) do
					if k:IsA("CFrameValue") then
						table.insert(tr.keys, {inst = k, kind = "joint", track = tr, frame = k:GetAttribute("F") or 0, cf = k.Value,
							style = k:GetAttribute("S") or "Linear", dir = k:GetAttribute("D") or "InOut"})
					end
				end
				table.sort(tr.keys, byFrame)
				p.tracks[tf.Name] = tr
			end
		end
	end
	p.markers = {}
	local markers = folder:FindFirstChild("Markers")
	if markers then
		for _, m in ipairs(markers:GetChildren()) do
			if m:IsA("Configuration") then
				table.insert(p.markers, {inst = m, kind = "marker", frame = m:GetAttribute("F") or 0,
					name = m:GetAttribute("Name") or "Event", value = m:GetAttribute("Value") or ""})
			end
		end
		table.sort(p.markers, byFrame)
	end
	p.props = {}
	local props = folder:FindFirstChild("Props")
	if props then
		for _, pf in ipairs(props:GetChildren()) do
			if pf:IsA("Folder") then
				local targetValue = pf:FindFirstChild("Target")
				local target = targetValue and targetValue:IsA("ObjectValue") and targetValue.Value or nil
				if pf:GetAttribute("IsCamera") then target = workspace.CurrentCamera end
				local pt = {folder = pf, target = target, property = pf:GetAttribute("Property") or "", kind = pf:GetAttribute("Kind") or "number",
					isCamera = pf:GetAttribute("IsCamera") == true, isItem = pf:GetAttribute("IsItem") == true, keys = {}}
				pt.isAction = pt.kind == "emit" or pt.kind == "play"
				for _, k in ipairs(pf:GetChildren()) do
					if k:IsA("Configuration") then
						table.insert(pt.keys, {inst = k, kind = "prop", track = pt, frame = k:GetAttribute("F") or 0, value = k:GetAttribute("V"),
							style = k:GetAttribute("S") or "Linear", dir = k:GetAttribute("D") or "InOut"})
					end
				end
				table.sort(pt.keys, byFrame)
				table.insert(p.props, pt)
			end
		end
		table.sort(p.props, function(a, b) return a.folder.Name < b.folder.Name end)
	end
	return p
end

-- ===== writes (always inside Hist.run) =====
function Store.setAttr(name, value)
	if S.proj and S.proj.folder.Parent then S.proj.folder:SetAttribute(name, value) end
end

function Store.trackFolder(name)
	local joints = Store.child(S.proj.folder, "Joints")
	return Store.child(joints, name)
end

-- a joint key at a frame: updated if one is there, made if not
function Store.setJointKey(name, frame, cf, style, dir)
	local tf = Store.trackFolder(name)
	for _, k in ipairs(tf:GetChildren()) do
		if k:IsA("CFrameValue") and k:GetAttribute("F") == frame then
			k.Value = cf
			if style then k:SetAttribute("S", style) end
			if dir then k:SetAttribute("D", dir) end
			return k
		end
	end
	local k = U.new("CFrameValue", {Name = "K", Value = cf})
	k:SetAttribute("F", frame)
	k:SetAttribute("S", style or S.proj.defStyle)
	k:SetAttribute("D", dir or S.proj.defDir)
	k.Parent = tf
	return k
end

function Store.setPropKey(pt, frame, value, style, dir)
	for _, k in ipairs(pt.folder:GetChildren()) do
		if k:IsA("Configuration") and k:GetAttribute("F") == frame then
			k:SetAttribute("V", value)
			if style then k:SetAttribute("S", style) end
			if dir then k:SetAttribute("D", dir) end
			return k
		end
	end
	local k = U.new("Configuration", {Name = "K"})
	k:SetAttribute("F", frame)
	k:SetAttribute("V", value)
	k:SetAttribute("S", style or S.proj.defStyle)
	k:SetAttribute("D", dir or S.proj.defDir)
	k.Parent = pt.folder
	return k
end

function Store.addMarker(frame, name, value)
	local markers = Store.child(S.proj.folder, "Markers")
	local m = U.new("Configuration", {Name = "M"})
	m:SetAttribute("F", frame)
	m:SetAttribute("Name", name or "Event")
	m:SetAttribute("Value", value or "")
	m.Parent = markers
	return m
end

-- after keys were moved: one key per frame per track (the moved one wins)
function Store.resolveCollisions(folder, winners)
	local seen = {}
	local list = {}
	for _, k in ipairs(folder:GetChildren()) do
		if k:GetAttribute("F") ~= nil then table.insert(list, k) end
	end
	table.sort(list, function(a, b) return (winners[a] and 0 or 1) < (winners[b] and 0 or 1) end)
	for _, k in ipairs(list) do
		local f = k:GetAttribute("F")
		if seen[f] then k:Destroy() else seen[f] = true end
	end
end

-- ===================================================================================================
-- the rig: its Motor6D tree, rest pose and how a pose is shown
-- ===================================================================================================
function Rig.collect(model)
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 and d.Part0 ~= d.Part1
			and d.Part0:IsDescendantOf(model) and d.Part1:IsDescendantOf(model) then
			table.insert(motors, d)
		end
	end
	local byPart1, childrenOf = {}, {}
	for _, m in ipairs(motors) do
		if not byPart1[m.Part1] then
			byPart1[m.Part1] = m
			childrenOf[m.Part0] = childrenOf[m.Part0] or {}
			table.insert(childrenOf[m.Part0], m)
		end
	end
	local roots = {}
	for part0 in pairs(childrenOf) do
		if not byPart1[part0] then table.insert(roots, part0) end
	end
	table.sort(roots, function(a, b) return a.Name < b.Name end)
	local joints, visited = {}, {}
	local function visit(part, depth, parentJoint)
		local kids = childrenOf[part]
		if not kids then return end
		table.sort(kids, function(a, b) return a.Part1.Name < b.Part1.Name end)
		for _, m in ipairs(kids) do
			if not visited[m] then
				visited[m] = true
				local j = {motor = m, name = m.Part1.Name, part0 = m.Part0, part1 = m.Part1, depth = depth, parent = parentJoint, children = {}}
				table.insert(joints, j)
				if parentJoint then table.insert(parentJoint.children, j) end
				visit(m.Part1, depth + 1, j)
			end
		end
	end
	for _, r in ipairs(roots) do visit(r, 0, nil) end
	return joints, roots
end

function Rig.isRig(model)
	if not model or not model:IsA("Model") then return false end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then return true end
	end
	return false
end

-- the model a selected thing belongs to (the outermost model with joints)
function Rig.fromSelection()
	for _, obj in ipairs(Svc.Selection:Get()) do
		local found = nil
		local cur = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model")
		while cur do
			if Rig.isRig(cur) then found = cur end
			cur = cur:FindFirstAncestorOfClass("Model")
		end
		if found then return found end
	end
	return nil
end

-- Motor6D.Transform is shown in edit mode in current Studio; older builds only move a part when C0 changes
function Rig.detectMode()
	local j
	for _, cand in ipairs(S.joints) do
		if not cand.part1.Anchored then j = cand break end
	end
	if not j then return "C0" end
	local ok, moved = pcall(function()
		local before = j.part1.CFrame
		j.motor.Transform = CFrame.Angles(0.35, 0, 0)
		local after = j.part1.CFrame
		j.motor.Transform = CFrame.identity
		return (before.Position - after.Position).Magnitude > 1e-4 or U.angleOf(before:ToObjectSpace(after)) > 1e-4
	end)
	if ok and moved then return "Transform" end
	return "C0"
end

function Rig.bind(model)
	Rig.unbind()
	if not model or not model.Parent then return false, "the rig is gone" end
	local joints, roots = Rig.collect(model)
	if #joints == 0 then return false, model.Name .. " has no Motor6D joints" end
	S.rig, S.joints, S.roots = model, joints, roots
	S.jointByName, S.jointByPart1, S.rootSet, S.treeParts = {}, {}, {}, {}
	for _, r in ipairs(roots) do
		S.rootSet[r] = true
		S.treeParts[r] = true
	end
	local dup = {}
	for _, j in ipairs(joints) do
		if S.jointByName[j.name] then table.insert(dup, j.name) else S.jointByName[j.name] = j end
		S.jointByPart1[j.part1] = j
		S.treeParts[j.part1] = true
		-- a C0 kept on the joint means a session ended while posed: that one is the real rest pose
		local saved = j.motor:GetAttribute("MarrowRestC0")
		if typeof(saved) == "CFrame" then
			j.rest = saved
			pcall(function()
				j.motor.C0 = saved
				j.motor:SetAttribute("MarrowRestC0", nil)
			end)
		else
			j.rest = j.motor.C0
		end
		pcall(function() j.motor.Transform = CFrame.identity end)
	end
	S.applyMode = Rig.detectMode()
	if S.applyMode == "C0" then
		for _, j in ipairs(joints) do pcall(function() j.motor:SetAttribute("MarrowRestC0", j.rest) end) end
	end
	-- parts held to the body by welds (accessories, armour): they ride on the part they are welded to
	S.carrierOf = {}
	for _, link in ipairs(Rig.attachments()) do S.carrierOf[link.part] = link.carrier end
	local anchored = 0
	for _, j in ipairs(joints) do
		if j.part1.Anchored then anchored += 1 end
	end
	local note = {}
	if #dup > 0 then table.insert(note, "joints sharing a name: " .. table.concat(dup, ", ")) end
	if anchored > 0 then table.insert(note, anchored .. " anchored part(s) can't move: use Attach again to fix") end
	return true, (#note > 0) and table.concat(note, "; ") or nil
end

function Rig.unbind()
	if S.rig then
		for _, j in ipairs(S.joints) do
			if j.motor.Parent then
				pcall(function()
					if S.applyMode == "C0" then
						j.motor.C0 = j.rest
						j.motor:SetAttribute("MarrowRestC0", nil)
					else
						j.motor.Transform = CFrame.identity
					end
				end)
			end
		end
	end
	S.rig, S.joints, S.roots = nil, {}, {}
	S.jointByName, S.jointByPart1, S.rootSet, S.treeParts, S.carrierOf = {}, {}, {}, {}, {}
	View.clearGhosts()
	View.clearPath()
end

-- show one joint's pose (T = the offset from its rest pose)
function Rig.setT(j, cf)
	if S.applyMode == "C0" then
		local c0 = j.rest * cf
		if j.motor.C0 ~= c0 then j.motor.C0 = c0 end
	elseif j.motor.Transform ~= cf then
		j.motor.Transform = cf
	end
end

-- parts welded onto the jointed body (accessory handles, armour, held items), each with the part carrying it
function Rig.attachments()
	local out, attached = {}, {}
	for p in pairs(S.treeParts) do attached[p] = true end
	local links, isRigJoint = {}, {}
	for _, j in ipairs(S.joints) do isRigJoint[j.motor] = true end
	for _, d in ipairs(S.rig:GetDescendants()) do
		if d:IsA("JointInstance") and not isRigJoint[d] then
			if d.Part0 and d.Part1 then table.insert(links, {d.Part0, d.Part1}) end
		elseif d:IsA("WeldConstraint") and d.Part0 and d.Part1 then
			table.insert(links, {d.Part0, d.Part1})
		end
	end
	local changed = true
	while changed do
		changed = false
		for _, l in ipairs(links) do
			local a, b = l[1], l[2]
			if attached[a] and not attached[b] and b:IsDescendantOf(S.rig) then
				attached[b] = true
				table.insert(out, {part = b, carrier = a})
				changed = true
			elseif attached[b] and not attached[a] and a:IsDescendantOf(S.rig) then
				attached[a] = true
				table.insert(out, {part = a, carrier = b})
				changed = true
			end
		end
	end
	return out
end

-- the joint that moves a clicked part
function Rig.jointForPart(part, depth)
	depth = depth or 0
	if not part or depth > 12 then return nil end
	if S.jointByPart1[part] then return S.jointByPart1[part] end
	if S.rootSet[part] then
		for _, j in ipairs(S.joints) do
			if j.part0 == part then return j end
		end
	end
	return Rig.jointForPart(S.carrierOf[part], depth + 1)
end

-- ===================================================================================================
-- evaluating the animation
-- ===================================================================================================
local function findSegment(keys, frame)
	local n = #keys
	if frame <= keys[1].frame then return 1, nil end
	if frame >= keys[n].frame then return n, nil end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if keys[mid].frame <= frame then lo = mid else hi = mid end
	end
	return lo, hi
end

function Anim.sample(keys, frame)
	if #keys == 0 then return CFrame.identity end
	local i, j = findSegment(keys, frame)
	if not j then return keys[i].cf end
	local a, b = keys[i], keys[j]
	if a.style == "Constant" then return a.cf end
	return U.blend(a.cf, b.cf, Ease.value((frame - a.frame) / (b.frame - a.frame), a.style, a.dir))
end

function Anim.sampleValue(keys, frame, kind)
	if #keys == 0 then return nil end
	local i, j = findSegment(keys, frame)
	if not j then return keys[i].value end
	local a, b = keys[i], keys[j]
	if a.style == "Constant" or kind == "boolean" then return a.value end
	return U.lerpValue(a.value, b.value, Ease.value((frame - a.frame) / (b.frame - a.frame), a.style, a.dir), kind)
end

-- a joint's pose at a frame (an unkeyed pose you are still working on wins)
function Anim.jointT(name, frame)
	local p = S.pending[name]
	if p then return p end
	local tr = S.proj and S.proj.tracks[name]
	if not tr or #tr.keys == 0 then return CFrame.identity end
	return Anim.sample(tr.keys, frame)
end

function Anim.getProp(inst, prop)
	if prop == "Pivot" then return inst:GetPivot() end
	return inst[prop]
end

function Anim.setProp(inst, prop, value)
	if value == nil then return end
	local orig = S.propOriginal[inst]
	if not orig then
		orig = {}
		S.propOriginal[inst] = orig
	end
	if orig[prop] == nil then
		local ok, cur = pcall(Anim.getProp, inst, prop)
		if ok then orig[prop] = cur end
	end
	pcall(function()
		if prop == "Pivot" then inst:PivotTo(value) else inst[prop] = value end
	end)
end

-- put back what preview changed (the camera only, or everything)
function Anim.restoreProps(cameraOnly)
	for inst, props in pairs(S.propOriginal) do
		local isCam = inst:IsA("Camera")
		if not cameraOnly or isCam then
			if inst.Parent then
				for prop, v in pairs(props) do
					pcall(function()
						if prop == "Pivot" then inst:PivotTo(v) else inst[prop] = v end
					end)
				end
			end
			S.propOriginal[inst] = nil
		end
	end
end

function Anim.applyProps(frame)
	if not S.proj then return end
	for _, pt in ipairs(S.proj.props) do
		local inst = pt.isCamera and workspace.CurrentCamera or pt.target
		if inst and inst.Parent and pt.property ~= "" and #pt.keys > 0 and not pt.isAction and (not pt.isCamera or S.camPreview) then
			Anim.setProp(inst, pt.property, Anim.sampleValue(pt.keys, frame, pt.kind))
		end
	end
end

-- one-shot tracks (particle bursts, sounds) fire when the playhead passes their keys: frames in (from, to]
function Anim.fireActions(from, to)
	if not S.proj then return end
	for _, pt in ipairs(S.proj.props) do
		local inst = pt.target
		if pt.isAction and inst and inst.Parent then
			for _, k in ipairs(pt.keys) do
				if k.frame > from and k.frame <= to then
					pcall(function()
						if pt.kind == "emit" then
							inst:Emit(math.max(1, math.floor(tonumber(k.value) or 20)))
						else
							local ok = pcall(function() game:GetService("SoundService"):PlayLocalSound(inst) end)
							if not ok then inst:Play() end
						end
					end)
				end
			end
		end
	end
end

function Anim.apply(frame)
	if S.rig then
		for _, j in ipairs(S.joints) do
			if j.motor.Parent then Rig.setT(j, Anim.jointT(j.name, frame)) end
		end
	end
	Anim.applyProps(frame)
end

-- a joint's keyed pose at a frame, leaving out the unkeyed pose being worked on (ghosts and the path)
function Anim.jointTAt(name, frame, ignorePending)
	if not ignorePending then return Anim.jointT(name, frame) end
	local tr = S.proj and S.proj.tracks[name]
	if not tr or #tr.keys == 0 then return CFrame.identity end
	return Anim.sample(tr.keys, frame)
end

-- ===================================================================================================
-- in the viewport: onion skin ghosts and the motion path
-- ===================================================================================================
function View.folderNow()
	local cam = workspace.CurrentCamera
	if not View.folder or not View.folder.Parent then
		View.folder = U.new("Folder", {Name = "MarrowView", Archivable = false})
	end
	if cam and View.folder.Parent ~= cam then View.folder.Parent = cam end
	return View.folder
end

-- world CFrames of every jointed part at a frame (forward kinematics from the root parts)
function View.worldPose(frame, ignorePending)
	local cf = {}
	for _, r in ipairs(S.roots) do cf[r] = r.CFrame end
	for _, j in ipairs(S.joints) do
		local p0 = cf[j.part0]
		if p0 then cf[j.part1] = p0 * j.rest * Anim.jointTAt(j.name, frame, ignorePending) * j.motor.C1:Inverse() end
	end
	return cf
end

local function ghostFrom(src, color)
	local g
	if src.Archivable then
		local ok, copy = pcall(function() return src:Clone() end)
		if ok then g = copy end
	end
	if not g then g = U.new("Part", {Size = src.Size}) end
	for _, c in ipairs(g:GetChildren()) do
		if c:IsA("SpecialMesh") then
			c.TextureId = ""
		elseif not c:IsA("DataModelMesh") then
			c:Destroy()
		end
	end
	if g:IsA("MeshPart") then pcall(function() g.TextureID = "" end) end
	g.Name = "MarrowGhost"
	g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
	g.Locked = true
	g.Archivable = false
	g.Material = Enum.Material.SmoothPlastic
	g.Color = color
	g.Reflectance = 0
	g.Transparency = 1
	return g
end

View.ghosts = nil
View.offsets = {}
function View.clearGhosts()
	if View.ghosts then
		for _, set in ipairs(View.ghosts) do
			for _, e in ipairs(set) do e.ghost:Destroy() end
		end
	end
	View.ghosts = nil
	View.ghostKey = nil
end

function View.buildGhosts()
	View.clearGhosts()
	if not S.rig then return end
	View.offsets = {}
	for extra, carrier in pairs(S.carrierOf) do
		if extra:IsA("BasePart") and carrier:IsA("BasePart") then
			View.offsets[extra] = carrier.CFrame:ToObjectSpace(extra.CFrame)
		end
	end
	View.ghosts = {}
	local colors = {T.blue, T.amber}
	for i = 1, 2 do
		local set = {}
		for part in pairs(S.treeParts) do
			if part:IsA("BasePart") and part.Transparency < 0.99 then table.insert(set, {ghost = ghostFrom(part, colors[i]), part = part}) end
		end
		for extra in pairs(View.offsets) do
			if extra.Transparency < 0.99 then table.insert(set, {ghost = ghostFrom(extra, colors[i]), part = extra}) end
		end
		local folder = View.folderNow()
		for _, e in ipairs(set) do e.ghost.Parent = folder end
		View.ghosts[i] = set
	end
end

-- ghosts of the nearest keyed poses before (blue) and after (amber) the playhead
function View.updateGhosts(force)
	if not S.onion or not S.rig or not S.proj then
		if View.ghosts then View.clearGhosts() end
		return
	end
	local prevF, nextF = Act.neighborFrames(U.round(S.frame))
	local key = tostring(prevF) .. ":" .. tostring(nextF) .. ":" .. tostring(S.dataVersion)
	if not force and key == View.ghostKey and View.ghosts then return end
	View.ghostKey = key
	if not View.ghosts then View.buildGhosts() end
	if not View.ghosts then return end
	for i, set in ipairs(View.ghosts) do
		local frame = (i == 1) and prevF or nextF
		if frame then
			local pose = View.worldPose(frame, true)
			local placed = {}
			local function place(part, depth)
				if placed[part] ~= nil then return placed[part] or nil end
				local cf = pose[part]
				if not cf and depth < 12 then
					local carrier, off = S.carrierOf[part], View.offsets[part]
					if carrier and off then
						local base = place(carrier, depth + 1)
						cf = base and base * off
					end
				end
				placed[part] = cf or false
				return cf
			end
			for _, e in ipairs(set) do
				local cf = place(e.part, 0)
				if cf then
					e.ghost.CFrame = cf
					e.ghost.Transparency = 0.74
				else
					e.ghost.Transparency = 1
				end
			end
		else
			for _, e in ipairs(set) do e.ghost.Transparency = 1 end
		end
	end
end

-- the path the selected part travels: a dot per frame step, bigger bone-white dots on its keys
View.dots = {}
function View.clearPath()
	for _, d in ipairs(View.dots) do d:Destroy() end
	View.dots = {}
	View.pathKey = nil
end

function View.updatePath(force)
	local j = S.path and S.rig and S.proj and S.selJoint and S.jointByName[S.selJoint]
	if not j then
		if #View.dots > 0 then View.clearPath() end
		return
	end
	local key = S.selJoint .. ":" .. tostring(S.dataVersion)
	if not force and key == View.pathKey then return end
	View.pathKey = key
	local chain = {}
	local cur = j
	while cur do
		table.insert(chain, 1, cur)
		cur = cur.parent
	end
	local root = chain[1].part0
	local length = S.proj.length
	local frames, keyed = {}, {}
	local step = math.max(1, math.ceil(length / 150))
	for f = 0, length, step do table.insert(frames, f) end
	local tr = S.proj.tracks[j.name]
	if tr then
		for _, k in ipairs(tr.keys) do
			keyed[k.frame] = true
			table.insert(frames, k.frame)
		end
	end
	table.sort(frames)
	local folder = View.folderNow()
	local n, last = 0, nil
	for _, f in ipairs(frames) do
		if f ~= last and f >= 0 and f <= length then
			last = f
			local cf = root.CFrame
			for _, cj in ipairs(chain) do
				cf = cf * cj.rest * Anim.jointTAt(cj.name, f, true) * cj.motor.C1:Inverse()
			end
			n += 1
			local d = View.dots[n]
			if not d then
				d = U.new("Part", {Name = "MarrowPathDot", Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false,
					CanQuery = false, CanTouch = false, CastShadow = false, Locked = true, Archivable = false, Material = Enum.Material.Neon})
				View.dots[n] = d
			end
			local isKey = keyed[f]
			local size = isKey and 0.22 or 0.1
			d.Size = Vector3.new(size, size, size)
			d.Color = isKey and T.bone or T.blue:Lerp(T.accent, f / math.max(length, 1))
			d.Transparency = isKey and 0 or 0.3
			d.CFrame = CFrame.new(cf.Position)
			d.Parent = folder
		end
	end
	for i = #View.dots, n + 1, -1 do
		View.dots[i]:Destroy()
		View.dots[i] = nil
	end
end

function View.refresh(force)
	View.updateGhosts(force)
	View.updatePath(force)
end

-- ===================================================================================================
-- gizmo: rotate rings / move arrows on the selected joint (POSE mode)
-- ===================================================================================================
function Gizmo.init()
	Gizmo.folder = U.new("Folder", {Name = "MarrowAnimatorGizmos", Archivable = false, Parent = Svc.CoreGui})
	Gizmo.proxy = U.new("Part", {Name = "MarrowGizmo", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		CastShadow = false, Locked = true, Archivable = false, Transparency = 1, Size = Vector3.one})
	Gizmo.arc = U.new("ArcHandles", {Name = "MarrowRotate", Adornee = Gizmo.proxy, Visible = false,
		Axes = Axes.new(Enum.Axis.X, Enum.Axis.Y, Enum.Axis.Z), Parent = Gizmo.folder})
	Gizmo.move = U.new("Handles", {Name = "MarrowMove", Adornee = Gizmo.proxy, Visible = false, Style = Enum.HandlesStyle.Movement,
		Color3 = T.amber, Parent = Gizmo.folder})
	Gizmo.selBox = U.new("SelectionBox", {Name = "MarrowSelected", LineThickness = 0.03, Color3 = T.bone, SurfaceTransparency = 1,
		Visible = false, Parent = Gizmo.folder})
	Gizmo.hoverBox = U.new("SelectionBox", {Name = "MarrowHover", LineThickness = 0.015, Color3 = T.accent, SurfaceColor3 = T.accent,
		SurfaceTransparency = 0.88, Visible = false, Parent = Gizmo.folder})
	Gizmo.hovered = false
	Gizmo.drag = nil

	Gizmo.arc.MouseEnter:Connect(function() Gizmo.hovered = true end)
	Gizmo.arc.MouseLeave:Connect(function() Gizmo.hovered = false end)
	Gizmo.move.MouseEnter:Connect(function() Gizmo.hovered = true end)
	Gizmo.move.MouseLeave:Connect(function() Gizmo.hovered = false end)
	Gizmo.arc.MouseButton1Down:Connect(function() Gizmo.begin() end)
	Gizmo.move.MouseButton1Down:Connect(function() Gizmo.begin() end)
	Gizmo.arc.MouseDrag:Connect(function(axis, angle) Gizmo.rotate(axis, angle) end)
	Gizmo.move.MouseDrag:Connect(function(face, distance) Gizmo.translate(face, distance) end)
	Gizmo.arc.MouseButton1Up:Connect(function() Gizmo.finish() end)
	Gizmo.move.MouseButton1Up:Connect(function() Gizmo.finish() end)
end

function Gizmo.hide()
	if not Gizmo.arc then return end
	Gizmo.arc.Visible = false
	Gizmo.move.Visible = false
	Gizmo.selBox.Visible = false
	Gizmo.hoverBox.Visible = false
	Gizmo.proxy.Parent = nil
end

-- the item track being posed (a part or model animated by its pivot), if one is selected in POSE
function Gizmo.itemTrack()
	if not S.poseMode or not S.selPropFolder then return nil end
	local pt = Draw.selectedProp()
	if pt and pt.isItem and pt.target and pt.target.Parent then return pt end
	return nil
end

function Gizmo.place()
	if not Gizmo.arc then return end
	if Gizmo.drag then return end
	local frame, size, adornee
	local j = S.poseMode and S.rig and S.selJoint and S.jointByName[S.selJoint]
	if j and j.part1.Parent and j.part0.Parent then
		frame = j.part0.CFrame * j.rest * Anim.jointT(j.name, S.frame)
		size = U.clamp(j.part1.Size.Magnitude * 0.55, 0.8, 8)
		adornee = j.part1
	else
		local pt = Gizmo.itemTrack()
		if pt then
			local ok, pivot = pcall(Anim.getProp, pt.target, "Pivot")
			if ok and typeof(pivot) == "CFrame" then
				frame = pivot
				local okSize, ext = pcall(function()
					return pt.target:IsA("Model") and pt.target:GetExtentsSize() or pt.target.Size
				end)
				size = U.clamp((okSize and ext.Magnitude or 2) * 0.5, 0.8, 12)
				adornee = pt.target
			end
		end
	end
	if not frame then
		Gizmo.hide()
		return
	end
	Gizmo.proxy.CFrame = (S.space == "world") and CFrame.new(frame.Position) or frame
	Gizmo.proxy.Size = Vector3.new(size, size, size)
	Gizmo.proxy.Parent = View.folderNow()
	Gizmo.arc.Visible = S.tool == "rotate"
	Gizmo.move.Visible = S.tool == "move"
	Gizmo.selBox.Adornee = adornee
	Gizmo.selBox.Visible = true
end

function Gizmo.snapAngle(a)
	if not S.snapOn or S.snapRot <= 0 then return a end
	local step = math.rad(S.snapRot)
	return math.floor(a / step + 0.5) * step
end

function Gizmo.snapDist(d)
	if not S.snapOn or S.snapMove <= 0 then return d end
	return math.floor(d / S.snapMove + 0.5) * S.snapMove
end

function Gizmo.begin()
	if not S.proj then return end
	local j = S.selJoint and S.jointByName[S.selJoint]
	local item = not j and Gizmo.itemTrack()
	if item then
		if S.playing then Act.stop() end
		local ok, pivot = pcall(Anim.getProp, item.target, "Pivot")
		if ok then Gizmo.drag = {item = item, T0 = pivot, T = pivot, frame0 = pivot} end
		return
	end
	if not j then return end
	if S.playing then Act.stop() end
	local T0 = Anim.jointT(j.name, S.frame)
	local base = j.part0.CFrame * j.rest
	Gizmo.drag = {joint = j, T0 = T0, T = T0, base = base, frame0 = base * T0}
end

function Gizmo.rotate(axis, angle)
	local d = Gizmo.drag
	if not d then return end
	local a = Gizmo.snapAngle(angle)
	local v = Vector3.FromAxis(axis)
	if d.item then
		local f0 = d.frame0
		local p = (S.space == "world") and (CFrame.new(f0.Position) * CFrame.fromAxisAngle(v, a) * f0.Rotation) or (f0 * CFrame.fromAxisAngle(v, a))
		d.T = p
		Anim.setProp(d.item.target, "Pivot", p)
		Act.status(("Rotating %s around %s: %s deg"):format(d.item.target.Name, axis.Name, U.fmt(math.deg(a), 1)))
		return
	end
	local newT
	if S.space == "world" then
		local f0 = d.frame0
		newT = d.base:Inverse() * (CFrame.new(f0.Position) * CFrame.fromAxisAngle(v, a) * f0.Rotation)
	else
		newT = d.T0 * CFrame.fromAxisAngle(v, a)
	end
	d.T = newT
	S.pending[d.joint.name] = newT
	Rig.setT(d.joint, newT)
	Act.status(("Rotating %s around %s: %s deg"):format(d.joint.name, axis.Name, U.fmt(math.deg(a), 1)))
end

function Gizmo.translate(face, distance)
	local d = Gizmo.drag
	if not d then return end
	local s = Gizmo.snapDist(distance)
	local dir = Vector3.FromNormalId(face)
	local worldDir = (S.space == "world") and dir or d.frame0:VectorToWorldSpace(dir)
	if d.item then
		local p = d.frame0 + worldDir * s
		d.T = p
		Anim.setProp(d.item.target, "Pivot", p)
		Act.status(("Moving %s: %s studs"):format(d.item.target.Name, U.fmt(s, 3)))
		return
	end
	local newT = d.base:Inverse() * (d.frame0 + worldDir * s)
	d.T = newT
	S.pending[d.joint.name] = newT
	Rig.setT(d.joint, newT)
	Act.status(("Moving %s: %s studs"):format(d.joint.name, U.fmt(s, 3)))
end

function Gizmo.finish()
	local d = Gizmo.drag
	Gizmo.drag = nil
	if not d then return end
	if d.item then
		if d.T == d.T0 then
			Gizmo.place()
		else
			Act.commitItem(d.item, d.T)
		end
		return
	end
	if d.T == d.T0 then
		S.pending[d.joint.name] = nil
		Gizmo.place()
		return
	end
	Act.commitJoint(d.joint.name, d.T)
end

-- the item track a clicked part belongs to
function Gizmo.itemAt(part)
	if not part or not S.proj then return nil end
	for _, pt in ipairs(S.proj.props) do
		if pt.isItem and pt.target and (part == pt.target or part:IsDescendantOf(pt.target)) then return pt end
	end
	return nil
end

-- the visible part under the mouse (looks through invisible parts such as HumanoidRootPart, ghosts and dots)
function Gizmo.pick()
	local mouse = Gizmo.mouse
	if not mouse then return nil end
	local ok, ray = pcall(function() return mouse.UnitRay end)
	if not ok or not ray then return mouse.Target end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = {View.folderNow()}
	for _ = 1, 10 do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
		if not hit then return nil end
		local part = hit.Instance
		if part:IsA("BasePart") and part.Transparency >= 0.99 then
			table.insert(skip, part)
		else
			return part
		end
	end
	return nil
end

-- clicks in the viewport while POSE is on: pick the joint under the mouse
function Gizmo.mouseDown()
	if not S.poseMode or Gizmo.hovered or Gizmo.drag then return end
	local target = Gizmo.pick()
	if target and S.rig and target:IsDescendantOf(S.rig) then
		local j = Rig.jointForPart(target)
		if j then
			Act.selectJoint(j.name)
			return
		end
	end
	local item = Gizmo.itemAt(target)
	if item then
		Act.selectProp(item.folder)
		return
	end
	Act.selectJoint(nil)
	Act.selectProp(nil)
end

function Gizmo.mouseMove()
	if not S.poseMode or Gizmo.drag then
		if Gizmo.hoverBox then Gizmo.hoverBox.Visible = false end
		return
	end
	local target = Gizmo.pick()
	if target and S.rig and target:IsDescendantOf(S.rig) then
		local j = Rig.jointForPart(target)
		if j and j.name ~= S.selJoint then
			Gizmo.hoverBox.Adornee = j.part1
			Gizmo.hoverBox.Visible = true
			return
		end
	end
	local item = Gizmo.itemAt(target)
	if item and item.folder ~= S.selPropFolder then
		Gizmo.hoverBox.Adornee = item.target
		Gizmo.hoverBox.Visible = true
		return
	end
	Gizmo.hoverBox.Visible = false
end

-- ===================================================================================================
-- the window
-- ===================================================================================================
UI.active = setmetatable({}, {__mode = "k"})
UI.listRows, UI.keyRows, UI.diamonds, UI.flags, UI.ticks = {}, {}, {}, {}, {}

function UI.safe(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Marrow Animator] " .. tostring(err))
			Act.status("Error: " .. tostring(err), true)
		end
	end
end

function UI.button(parent, text, x, y, w, h, onClick, tip)
	local b = U.new("TextButton", {Name = "Button", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = T.panel2, BorderSizePixel = 0, AutoButtonColor = false, Font = T.font, TextSize = 12,
		TextColor3 = T.text, Text = text, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent}, {U.corner(4)})
	b.MouseEnter:Connect(function()
		if not UI.active[b] then b.BackgroundColor3 = T.panel3 end
		if tip then Act.hint(tip) end
	end)
	b.MouseLeave:Connect(function()
		if not UI.active[b] then b.BackgroundColor3 = T.panel2 end
	end)
	if onClick then
		b.MouseButton1Click:Connect(UI.safe(function() onClick(b) end))
	end
	return b
end

function UI.setActive(b, on, color)
	UI.active[b] = on and true or nil
	b.BackgroundColor3 = on and (color or T.accentDim) or T.panel2
	b.TextColor3 = on and T.bone or T.text
end

function UI.label(parent, text, x, y, w, h, color, font, size, align)
	return U.new("TextLabel", {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1,
		Font = font or T.font, TextSize = size or 12, TextColor3 = color or T.text, Text = text,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent})
end

-- hotkeys stay quiet while someone types in one of the plugin's boxes
function UI.trackFocus(b)
	b.Focused:Connect(function() UI.typing = b end)
	b.FocusLost:Connect(function() if UI.typing == b then UI.typing = nil end end)
	return b
end

function UI.box(parent, text, x, y, w, h, onCommit, placeholder)
	local b = U.new("TextBox", {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = T.bg,
		BorderSizePixel = 0, ClearTextOnFocus = false, Font = T.mono, TextSize = 12, TextColor3 = T.text, Text = text,
		PlaceholderText = placeholder or "", PlaceholderColor3 = T.faint, TextXAlignment = Enum.TextXAlignment.Center,
		Parent = parent}, {U.corner(4), U.stroke(T.line)})
	UI.trackFocus(b)
	if onCommit then
		b.FocusLost:Connect(UI.safe(function(enter) onCommit(b.Text, enter, b) end))
	end
	return b
end

-- a toolbar row that scrolls sideways when the window is narrow
function UI.makeBar(y)
	local bar = U.new("ScrollingFrame", {Name = "Bar", Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, L.BAR),
		BackgroundColor3 = T.panel, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.faint, CanvasSize = UDim2.fromOffset(0, L.BAR), ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = UI.root})
	local api = {x = 6, bar = bar}
	local function grow() bar.CanvasSize = UDim2.fromOffset(api.x + 6, L.BAR) end
	function api.add(text, w, fn, tip)
		local b = UI.button(bar, text, api.x, 4, w, L.BAR - 9, fn, tip)
		api.x += w + 4
		grow()
		return b
	end
	function api.label(text, w, color)
		local l = UI.label(bar, text, api.x, 4, w, L.BAR - 9, color)
		api.x += w + 4
		grow()
		return l
	end
	function api.box(text, w, fn, tip)
		local b = UI.box(bar, text, api.x, 4, w, L.BAR - 9, fn)
		if tip then b.MouseEnter:Connect(function() Act.hint(tip) end) end
		api.x += w + 4
		grow()
		return b
	end
	function api.gap()
		U.new("Frame", {Position = UDim2.fromOffset(api.x + 2, 8), Size = UDim2.fromOffset(1, L.BAR - 16), BackgroundColor3 = T.line,
			BorderSizePixel = 0, Parent = bar})
		api.x += 9
		grow()
	end
	return api
end

function UI.hitButton(parent, z)
	return U.new("TextButton", {Name = "Hit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, ZIndex = z or 20, Parent = parent})
end

function UI.build(widget)
	UI.root = U.new("Frame", {Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.bg, BorderSizePixel = 0, Parent = widget})

	-- ===== the menu bar, like a program of its own =====
	local b1 = UI.makeBar(0)
	b1.bar.BackgroundColor3 = T.bg
	UI.menuButtons = {}
	for _, m in ipairs({
		{"File", function(b) Act.fileMenu(b) end, "New, open, import, export, publish"},
		{"Edit", function(b) Act.editMenu(b) end, "Undo, copy / paste, mirror, keys and time tools"},
		{"View", function(b) Act.viewMenu(b) end, "Onion skin, motion path, camera, snapping, speed"},
		{"Add", function(b) Act.addMenu(b) end, "Add a rig, an item, a property, the camera or an event"},
		{"Effects", function(b) Act.effectsMenu(b) end, "Fire, smoke, sparks, blood, explosion, light flash, sound"},
		{"Help", function() Act.help() end, "Controls and hotkeys"},
	}) do
		local b = b1.add(m[1], m[1] == "Effects" and 62 or 48, m[2], m[3])
		b.BackgroundTransparency = 1
		b.Font = T.bold
		table.insert(UI.menuButtons, b)
	end
	b1.gap()
	UI.projBtn = b1.add("Animation: none", 230, Act.projectMenu, "Pick, create, rename, duplicate or delete an animation")
	UI.rigLabel = b1.label("Rig: none", 180, T.dim)
	b1.gap()
	UI.publishBtn = b1.add("Publish", 78, function() IO.publish() end, "Save the animation and upload it to Roblox in one click")
	UI.setActive(UI.publishBtn, true, T.accent)
	UI.publishBtn.Font = T.bold
	UI.bar1 = b1

	-- ===== playback and posing =====
	local b2 = UI.makeBar(L.BAR)
	b2.add("|<", 28, Act.toStart, "First frame (Home)")
	b2.add("<<", 30, Act.prevKey, "Previous key ( [ )")
	b2.add("<", 26, function() Act.step(-1) end, "Previous frame ( , )")
	UI.playBtn = b2.add("PLAY", 54, Act.togglePlay, "Play / stop (Space)")
	b2.add(">", 26, function() Act.step(1) end, "Next frame ( . )")
	b2.add(">>", 30, Act.nextKey, "Next key ( ] )")
	b2.add(">|", 28, Act.toEnd, "Last frame (End)")
	UI.loopBtn = b2.add("Loop", 46, Act.toggleLoopPlay, "Loop the preview")
	UI.frameBox = b2.box("0", 52, Act.frameBoxCommit, "The current frame: type one to jump there")
	UI.timeLabel = b2.label("/ 120   0.00 s", 116, T.dim)
	UI.speedBtn = b2.add("1x", 40, Act.speedMenu, "Preview speed")
	b2.gap()
	UI.poseBtn = b2.add("POSE", 54, Act.togglePoseMode, "Pose mode: click body parts or items in the viewport, turn and move them (P)")
	UI.rotBtn = b2.add("Rotate", 58, function() Act.setTool("rotate") end, "Rotate rings (R)")
	UI.moveBtn = b2.add("Move", 50, function() Act.setTool("move") end, "Move arrows (G)")
	UI.spaceBtn = b2.add("Local", 54, Act.toggleSpace, "Local or world axes (L)")
	UI.snapBtn = b2.add("Snap", 112, Act.snapMenu, "Angle and distance snapping (N switches it on / off)")
	b2.gap()
	UI.keyBtn = b2.add("+ Key", 56, function() Act.keySelected() end, "Key the selected joint or track at the playhead (K)")
	UI.autoBtn = b2.add("Auto-key", 70, Act.toggleAutoKey, "Write a key at the playhead whenever you pose something")
	UI.bar2 = b2

	-- ===== body =====
	UI.body = U.new("Frame", {Name = "Body", Position = UDim2.fromOffset(0, L.BAR * 2), Size = UDim2.new(1, 0, 1, -L.BAR * 2 - L.STATUS),
		BackgroundTransparency = 1, Parent = UI.root})

	-- tracks (left)
	UI.left = U.new("Frame", {Name = "Tracks", Size = UDim2.new(0, L.LEFT, 1, 0), BackgroundColor3 = T.panel, BorderSizePixel = 0,
		Parent = UI.body})
	U.new("Frame", {Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = T.line, BorderSizePixel = 0,
		ZIndex = 5, Parent = UI.left})
	UI.search = U.new("TextBox", {Position = UDim2.fromOffset(6, 3), Size = UDim2.new(1, -12, 0, L.RULER - 6), BackgroundColor3 = T.bg,
		BorderSizePixel = 0, ClearTextOnFocus = false, Font = T.font, TextSize = 12, TextColor3 = T.text, Text = "",
		PlaceholderText = "search joints...", PlaceholderColor3 = T.faint, TextXAlignment = Enum.TextXAlignment.Left,
		Parent = UI.left}, {U.corner(4), U.new("UIPadding", {PaddingLeft = UDim.new(0, 6)})})
	UI.trackFocus(UI.search)
	UI.list = U.new("Frame", {Name = "List", Position = UDim2.fromOffset(0, L.RULER), Size = UDim2.new(1, -1, 1, -L.RULER),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = UI.left})
	UI.listHit = UI.hitButton(UI.list)

	-- timeline (middle)
	UI.center = U.new("Frame", {Name = "Timeline", Position = UDim2.fromOffset(L.LEFT, 0), Size = UDim2.new(1, -L.LEFT - L.RIGHT, 1, 0),
		BackgroundColor3 = T.bg, BorderSizePixel = 0, ClipsDescendants = true, Parent = UI.body})
	UI.ruler = U.new("Frame", {Name = "Ruler", Size = UDim2.new(1, 0, 0, L.RULER), BackgroundColor3 = T.panel2, BorderSizePixel = 0,
		ClipsDescendants = true, Parent = UI.center})
	UI.rulerHit = UI.hitButton(UI.ruler)
	UI.keys = U.new("Frame", {Name = "Keys", Position = UDim2.fromOffset(0, L.RULER), Size = UDim2.new(1, 0, 1, -L.RULER),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = UI.center})
	UI.keysHit = UI.hitButton(UI.keys)
	UI.endShade = U.new("Frame", {Name = "PastTheEnd", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5,
		BorderSizePixel = 0, ZIndex = 6, Parent = UI.keys})
	UI.startShade = U.new("Frame", {Name = "BeforeTheStart", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5,
		BorderSizePixel = 0, ZIndex = 6, Parent = UI.keys})
	UI.playheadKeys = U.new("Frame", {Name = "Playhead", Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0,
		ZIndex = 9, Parent = UI.keys})
	UI.playheadRuler = U.new("Frame", {Name = "Playhead", Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0,
		ZIndex = 9, Parent = UI.ruler})
	UI.playheadTag = U.new("TextLabel", {Name = "Tag", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(40, 15),
		BackgroundColor3 = T.accent, BorderSizePixel = 0, Font = T.bold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), Text = "0",
		ZIndex = 10, Parent = UI.ruler}, {U.corner(3)})
	UI.boxSel = U.new("Frame", {Name = "BoxSelect", BackgroundColor3 = T.bone, BackgroundTransparency = 0.88, BorderSizePixel = 0,
		Visible = false, ZIndex = 12, Parent = UI.keys}, {U.stroke(T.bone, 1, 0.3)})
	UI.emptyNote = U.new("TextLabel", {Name = "Empty", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -40, 0, 90), BackgroundTransparency = 1, Font = T.font, TextSize = 14, TextColor3 = T.dim, TextWrapped = true,
		ZIndex = 15, Text = "", Parent = UI.keys})

	-- inspector (right)
	UI.right = U.new("Frame", {Name = "Inspector", Position = UDim2.new(1, -L.RIGHT, 0, 0), Size = UDim2.new(0, L.RIGHT, 1, 0),
		BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = UI.body})
	U.new("Frame", {Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = T.line, BorderSizePixel = 0, ZIndex = 5, Parent = UI.right})
	UI.inspector = U.new("ScrollingFrame", {Name = "Scroll", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, ScrollBarImageColor3 = T.faint, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = UI.right}, {
		U.new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
		U.new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10)}),
	})
	UI.buildInspector()

	-- status line
	UI.statusBar = U.new("Frame", {Name = "Status", Position = UDim2.new(0, 0, 1, -L.STATUS), Size = UDim2.new(1, 0, 0, L.STATUS),
		BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = UI.root})
	UI.status = U.new("TextLabel", {Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -330, 1, 0), BackgroundTransparency = 1, Font = T.font,
		TextSize = 12, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Marrow Animator " .. VERSION, Parent = UI.statusBar})
	UI.info = U.new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(320, L.STATUS),
		BackgroundTransparency = 1, Font = T.font, TextSize = 12, TextColor3 = T.faint, TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = UI.statusBar})

	-- overlays: drag catcher, menus, dialogs
	UI.catcher = U.new("TextButton", {Name = "DragCatcher", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, Visible = false, ZIndex = 100, Parent = UI.root})
	UI.menuCatcher = U.new("TextButton", {Name = "MenuCatcher", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, Visible = false, ZIndex = 200, Parent = UI.root})
	UI.menu = U.new("Frame", {Name = "Menu", Size = UDim2.fromOffset(200, 10), BackgroundColor3 = T.panel2, BorderSizePixel = 0,
		Visible = false, ZIndex = 210, Parent = UI.root}, {U.corner(5), U.stroke(T.line)})
	UI.dialogLayer = U.new("TextButton", {Name = "Dialog", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 300, Parent = UI.root})
	UI.menuCatcher.MouseButton1Down:Connect(function() UI.closeMenu() end)
	UI.menuCatcher.MouseButton2Down:Connect(function() UI.closeMenu() end)
end

-- ===== menus =====
function UI.closeMenu()
	UI.menu.Visible = false
	UI.menuCatcher.Visible = false
	for _, c in ipairs(UI.menu:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

-- items: {text = , fn = , disabled = , checked = , sep = true}
function UI.openMenu(items, x, y, width)
	UI.closeMenu()
	width = width or 210
	local yy = 4
	for _, item in ipairs(items) do
		if item.sep then
			U.new("Frame", {Position = UDim2.fromOffset(6, yy + 3), Size = UDim2.new(1, -12, 0, 1), BackgroundColor3 = T.line,
				BorderSizePixel = 0, ZIndex = 211, Parent = UI.menu})
			yy += 7
		elseif item.title then
			UI.label(UI.menu, item.title, 10, yy, width - 20, 18, T.faint, T.bold, 11).ZIndex = 211
			yy += 18
		else
			local b = U.new("TextButton", {Position = UDim2.fromOffset(4, yy), Size = UDim2.new(1, -8, 0, 22), BackgroundColor3 = T.panel2,
				BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Font = T.font, TextSize = 12,
				TextColor3 = item.disabled and T.faint or T.text, Text = (item.checked and "> " or "   ") .. item.text,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 211, Parent = UI.menu}, {U.corner(3),
				U.new("UIPadding", {PaddingLeft = UDim.new(0, 6)})})
			b.MouseEnter:Connect(function() b.BackgroundTransparency = 0 b.BackgroundColor3 = T.panel3 end)
			b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
			if not item.disabled then
				b.MouseButton1Click:Connect(UI.safe(function()
					UI.closeMenu()
					if item.fn then item.fn() end
				end))
			end
			yy += 22
		end
	end
	local size = UI.root.AbsoluteSize
	local h = yy + 4
	UI.menu.Size = UDim2.fromOffset(width, h)
	UI.menu.Position = UDim2.fromOffset(U.clamp(x, 2, math.max(2, size.X - width - 2)), U.clamp(y, 2, math.max(2, size.Y - h - 2)))
	UI.menu.Visible = true
	UI.menuCatcher.Visible = true
end

function UI.mouse()
	return UI.widget:GetRelativeMousePosition()
end

-- a menu under a button
function UI.menuAt(button, items, width)
	local p = button.AbsolutePosition - UI.root.AbsolutePosition
	UI.openMenu(items, p.X, p.Y + button.AbsoluteSize.Y + 2, width)
end

-- ===== dialogs =====
-- fields: { {label = , default = } }; onOk(values) where values[i] is the text in field i
function UI.dialog(title, message, fields, onOk, okText)
	local layer = UI.dialogLayer
	for _, c in ipairs(layer:GetChildren()) do c:Destroy() end
	fields = fields or {}
	local w = 360
	local msgH = message and 44 or 0
	local h = 46 + msgH + #fields * 30 + 44
	local panel = U.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = T.panel, BorderSizePixel = 0, ZIndex = 301, Parent = layer}, {U.corner(6), U.stroke(T.line)})
	UI.label(panel, title, 14, 10, w - 28, 22, T.bone, T.bold, 14).ZIndex = 302
	local y = 40
	if message then
		local m = UI.label(panel, message, 14, y, w - 28, msgH - 4, T.dim, T.font, 12)
		m.TextWrapped = true
		m.TextYAlignment = Enum.TextYAlignment.Top
		m.ZIndex = 302
		y += msgH
	end
	local boxes = {}
	local function submit()
		local values = {}
		for i, b in ipairs(boxes) do values[i] = b.Text end
		layer.Visible = false
		for _, c in ipairs(layer:GetChildren()) do c:Destroy() end
		if onOk then UI.safe(onOk)(values) end
	end
	for i, f in ipairs(fields) do
		UI.label(panel, f.label, 14, y + 4, 110, 20, T.dim).ZIndex = 302
		local b = UI.box(panel, tostring(f.default or ""), 126, y, w - 140, 24)
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.ZIndex = 302
		U.new("UIPadding", {PaddingLeft = UDim.new(0, 6), Parent = b})
		b.FocusLost:Connect(function(enter) if enter and i == #fields then submit() end end)
		boxes[i] = b
		y += 30
	end
	local ok = UI.button(panel, okText or "OK", w - 190, h - 36, 84, 26, function() submit() end)
	ok.ZIndex = 302
	UI.setActive(ok, true)
	local cancel = UI.button(panel, "Cancel", w - 98, h - 36, 84, 26, function()
		layer.Visible = false
		for _, c in ipairs(layer:GetChildren()) do c:Destroy() end
	end)
	cancel.ZIndex = 302
	layer.Visible = true
	if boxes[1] then task.defer(function() pcall(function() boxes[1]:CaptureFocus() end) end) end
end

function UI.confirm(title, message, onYes, yesText)
	UI.dialog(title, message, nil, function() onYes() end, yesText or "Yes")
end

-- ===================================================================================================
-- the inspector (right side)
-- ===================================================================================================
local function section(name, height, order)
	local f = U.new("Frame", {Name = name, Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = T.panel2, BackgroundTransparency = 0.35,
		BorderSizePixel = 0, LayoutOrder = order, Parent = UI.inspector}, {U.corner(5)})
	local title = UI.label(f, name, 10, 4, 230, 18, T.bone, T.bold, 12)
	return f, title
end

function UI.buildInspector()
	local ins = {}
	UI.ins = ins
	local bw = 78 -- button width in a three-across row

	-- the selected joint
	ins.joint, ins.jointTitle = section("JOINT", 182, 1)
	UI.label(ins.joint, "Rotate", 10, 28, 50, 20, T.dim)
	UI.label(ins.joint, "Move", 10, 54, 50, 20, T.dim)
	ins.rot, ins.pos = {}, {}
	for i = 1, 3 do
		ins.rot[i] = UI.box(ins.joint, "0", 58 + (i - 1) * 64, 26, 60, 22, function(text, _, box) Act.numericPose("rot", i, text, box) end)
		ins.pos[i] = UI.box(ins.joint, "0", 58 + (i - 1) * 64, 52, 60, 22, function(text, _, box) Act.numericPose("pos", i, text, box) end)
	end
	UI.button(ins.joint, "Key (K)", 10, 82, bw, 22, function() Act.keySelected() end, "Key the selected joint at the playhead")
	UI.button(ins.joint, "Reset", 10 + bw + 4, 82, bw, 22, function() Act.resetJoint() end, "Back to the rest pose (keyed)")
	UI.button(ins.joint, "Its keys", 10 + (bw + 4) * 2, 82, bw, 22, function() Act.selectRowKeys() end, "Select every key of this joint")
	UI.button(ins.joint, "Copy pose", 10, 108, 118, 22, function() Act.copyPose() end, "Copy the whole pose at the playhead")
	UI.button(ins.joint, "Paste pose", 132, 108, 118, 22, function() Act.pastePose(false) end, "Paste the copied pose at the playhead")
	UI.button(ins.joint, "Mirror pose", 10, 134, 118, 22, function() Act.mirrorPose() end, "Swap left and right at the playhead")
	UI.button(ins.joint, "Paste mirrored", 132, 134, 118, 22, function() Act.pastePose(true) end, "Paste the copied pose, left and right swapped")
	ins.jointNote = UI.label(ins.joint, "", 10, 160, 240, 18, T.faint, T.font, 11)

	-- selected keys
	ins.keys, ins.keysTitle = section("KEYS", 276, 2)
	UI.label(ins.keys, "Easing", 10, 28, 60, 20, T.dim)
	ins.styleBtn = UI.button(ins.keys, "Cubic", 72, 26, 100, 22, function(b) Act.styleMenu(b) end, "How the motion leaves this key")
	ins.dirBtn = UI.button(ins.keys, "InOut", 176, 26, 74, 22, function(b) Act.dirMenu(b) end, "Ease in, out or both")
	ins.curve = U.new("Frame", {Position = UDim2.fromOffset(10, 54), Size = UDim2.fromOffset(240, 84), BackgroundColor3 = T.bg,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = ins.keys}, {U.corner(4)})
	for _, gy in ipairs({0.15, 0.85}) do
		U.new("Frame", {Position = UDim2.new(0, 0, gy, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.line, BorderSizePixel = 0,
			Parent = ins.curve})
	end
	ins.curveSegs = {}
	for i = 1, 48 do
		ins.curveSegs[i] = U.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 2), BackgroundColor3 = T.bone,
			BorderSizePixel = 0, ZIndex = 2, Parent = ins.curve})
	end
	for i, preset in ipairs(Ease.PRESETS) do
		local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
		UI.button(ins.keys, preset[1], 10 + col * 48, 144 + row * 24, 46, 21, function() Act.setEasing(preset[2], preset[3]) end,
			preset[2] .. " " .. preset[3]).TextSize = 10
	end
	UI.button(ins.keys, "Delete", 10, 196, bw, 22, function() Act.deleteSelected() end, "Delete the selected keys (Delete)")
	UI.button(ins.keys, "Copy", 10 + bw + 4, 196, bw, 22, function() Act.copyKeys() end, "Copy the selected keys (Ctrl+C)")
	UI.button(ins.keys, "Paste", 10 + (bw + 4) * 2, 196, bw, 22, function() Act.pasteKeys(U.round(S.frame)) end, "Paste at the playhead (Ctrl+V)")
	UI.button(ins.keys, "Reverse", 10, 222, bw, 22, function() Act.reverseKeys() end, "Play the selected keys backwards")
	UI.button(ins.keys, "Stretch...", 10 + bw + 4, 222, bw, 22, function() Act.stretchDialog() end, "Make the selected stretch of keys longer or shorter")
	UI.button(ins.keys, "Shift...", 10 + (bw + 4) * 2, 222, bw, 22, function() Act.shiftDialog() end, "Move the selected keys by a number of frames")
	ins.keysNote = UI.label(ins.keys, "", 10, 250, 240, 18, T.faint, T.font, 11)

	-- a selected event
	ins.event, ins.eventTitle = section("EVENT", 128, 3)
	UI.label(ins.event, "Name", 10, 28, 60, 20, T.dim)
	UI.label(ins.event, "Value", 10, 54, 60, 20, T.dim)
	UI.label(ins.event, "Frame", 10, 80, 60, 20, T.dim)
	ins.eventName = UI.box(ins.event, "", 72, 26, 178, 22, function(text) Act.editMarker("Name", text) end)
	ins.eventValue = UI.box(ins.event, "", 72, 52, 178, 22, function(text) Act.editMarker("Value", text) end)
	ins.eventFrame = UI.box(ins.event, "", 72, 78, 80, 22, function(text) Act.editMarker("F", text) end)
	UI.button(ins.event, "Delete event", 156, 78, 94, 22, function() Act.deleteSelected() end)
	UI.label(ins.event, "AnimationTrack:GetMarkerReachedSignal(name)", 10, 104, 240, 18, T.faint, T.font, 10)

	-- a selected property track
	ins.prop, ins.propTitle = section("PROPERTY", 128, 4)
	ins.propTarget = UI.label(ins.prop, "", 10, 26, 240, 18, T.dim)
	UI.label(ins.prop, "Value", 10, 50, 50, 20, T.dim)
	ins.propValue = UI.box(ins.prop, "", 58, 48, 192, 22, function(text) Act.typePropValue(text) end)
	ins.propValue.TextXAlignment = Enum.TextXAlignment.Left
	UI.button(ins.prop, "Key current value (K)", 10, 76, 150, 22, function() Act.keySelected() end, "Key what the object shows right now")
	UI.button(ins.prop, "Remove", 164, 76, 86, 22, function() Act.removePropTrack() end, "Remove this property track")
	ins.propNote = UI.label(ins.prop, "", 10, 102, 240, 18, T.faint, T.font, 11)

	-- the animation itself
	ins.project, ins.projectTitle = section("ANIMATION", 214, 5)
	UI.label(ins.project, "Name", 10, 28, 60, 20, T.dim)
	ins.projName = UI.box(ins.project, "", 72, 26, 178, 22, function(text) Act.renameProject(text) end)
	ins.projName.TextXAlignment = Enum.TextXAlignment.Left
	UI.label(ins.project, "FPS", 10, 54, 60, 20, T.dim)
	ins.projFps = UI.box(ins.project, "60", 72, 52, 56, 22, function(text) Act.setFps(text) end)
	UI.label(ins.project, "Length", 134, 54, 50, 20, T.dim)
	ins.projLength = UI.box(ins.project, "120", 186, 52, 64, 22, function(text) Act.setLength(text) end)
	ins.projSeconds = UI.label(ins.project, "", 10, 78, 240, 18, T.faint, T.font, 11)
	ins.loopBtn = UI.button(ins.project, "Looped", 10, 100, 118, 22, function() Act.toggleProjectLoop() end, "The exported animation loops")
	ins.prioBtn = UI.button(ins.project, "Action", 132, 100, 118, 22, function(b) Act.priorityMenu(b) end, "Animation priority")
	UI.label(ins.project, "New keys", 10, 130, 70, 20, T.dim)
	ins.defStyleBtn = UI.button(ins.project, "Cubic", 80, 128, 96, 22, function(b) Act.defaultStyleMenu(b) end, "Easing for new keys")
	ins.defDirBtn = UI.button(ins.project, "InOut", 180, 128, 70, 22, function(b) Act.defaultDirMenu(b) end)
	UI.button(ins.project, "+ Property", 10, 158, 78, 22, function() Act.addPropertyMenu() end, "Animate a property of the object selected in the Explorer")
	UI.button(ins.project, "+ Camera", 92, 158, 78, 22, function() Act.addCameraTracks() end, "Animate the camera (position and field of view)")
	UI.button(ins.project, "+ Event", 174, 158, 76, 22, function() Act.addMarker(U.round(S.frame)) end, "An event at the playhead")
	ins.projNote = UI.label(ins.project, "", 10, 186, 240, 18, T.faint, T.font, 11)
end

-- ===================================================================================================
-- drawing
-- ===================================================================================================
function Draw.width() return math.max(UI.keys.AbsoluteSize.X, 10) end
function Draw.ppf() return Draw.width() / math.max(S.view.finish - S.view.start, 1) end
function Draw.frameToX(f) return (f - S.view.start) * Draw.ppf() end
function Draw.xToFrame(x) return S.view.start + x / Draw.ppf() end
function Draw.mouseIn(gui)
	return UI.mouse() - (gui.AbsolutePosition - UI.root.AbsolutePosition)
end

function Draw.propLabel(pt)
	local target = pt.isCamera and "Camera" or (pt.target and pt.target.Name or "(missing)")
	if pt.isItem then return target .. "   (item)" end
	return target .. "." .. pt.property
end

-- the rows of the timeline, top to bottom
function Draw.buildRows()
	local rows = {}
	table.insert(rows, {kind = "summary", label = "All keys"})
	table.insert(rows, {kind = "events", label = "Events"})
	local search = S.search:lower()
	if S.rig then
		for _, j in ipairs(S.joints) do
			local show
			if search ~= "" then
				show = j.name:lower():find(search, 1, true) ~= nil
			else
				show = true
				local p = j.parent
				while p do
					if S.collapsed[p.name] then show = false break end
					p = p.parent
				end
			end
			if show then table.insert(rows, {kind = "joint", joint = j, name = j.name, depth = search ~= "" and 0 or j.depth}) end
		end
	end
	if S.proj then
		-- keys for joints the rig doesn't have (rig missing, renamed parts)
		local orphans = {}
		for name, tr in pairs(S.proj.tracks) do
			if #tr.keys > 0 and not S.jointByName[name] then table.insert(orphans, name) end
		end
		table.sort(orphans)
		for _, name in ipairs(orphans) do
			if search == "" or name:lower():find(search, 1, true) then
				table.insert(rows, {kind = "joint", name = name, depth = 0, orphan = true})
			end
		end
		for _, pt in ipairs(S.proj.props) do
			table.insert(rows, {kind = "prop", prop = pt, label = Draw.propLabel(pt)})
		end
	end
	S.rows = rows
	local maxScroll = math.max(0, #rows * L.ROW - UI.keys.AbsoluteSize.Y + L.ROW)
	S.scrollY = U.clamp(S.scrollY, 0, maxScroll)
end

function Draw.rowKeys(row)
	if not S.proj then return {} end
	if row.kind == "joint" then
		local tr = S.proj.tracks[row.name]
		return tr and tr.keys or {}
	elseif row.kind == "prop" then
		return row.prop.keys
	elseif row.kind == "events" then
		return S.proj.markers
	end
	return {}
end

-- all keys of every track, grouped by frame (the "All keys" row)
function Draw.summary()
	local groups, order = {}, {}
	if not S.proj then return groups, order end
	local function add(k)
		local g = groups[k.frame]
		if not g then
			g = {}
			groups[k.frame] = g
			table.insert(order, k.frame)
		end
		table.insert(g, k)
	end
	for _, tr in pairs(S.proj.tracks) do
		for _, k in ipairs(tr.keys) do add(k) end
	end
	for _, pt in ipairs(S.proj.props) do
		for _, k in ipairs(pt.keys) do add(k) end
	end
	table.sort(order)
	return groups, order
end

function Draw.rowSelected(row)
	if row.kind == "joint" then return S.selJoint == row.name end
	if row.kind == "prop" then return S.selPropFolder == row.prop.folder end
	return false
end

function Draw.list()
	local h = UI.list.AbsoluteSize.Y
	local used = 0
	for i, row in ipairs(S.rows) do
		local y = (i - 1) * L.ROW - S.scrollY
		if y > -L.ROW and y < h then
			used += 1
			local r = UI.listRows[used]
			if not r then
				local f = U.new("Frame", {Size = UDim2.new(1, 0, 0, L.ROW), BackgroundColor3 = T.row, BorderSizePixel = 0, Parent = UI.list})
				r = {
					frame = f,
					arrow = U.new("TextLabel", {Size = UDim2.fromOffset(14, L.ROW), BackgroundTransparency = 1, Font = T.bold, TextSize = 11,
						TextColor3 = T.dim, Text = "", Parent = f}),
					name = U.new("TextLabel", {Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Font = T.font, TextSize = 12,
						TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f}),
					key = U.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -13, 0.5, 0), Size = UDim2.fromOffset(8, 8),
						Rotation = 45, BackgroundColor3 = T.faint, BorderSizePixel = 0, Parent = f}),
				}
				UI.listRows[used] = r
			end
			r.frame.Visible = true
			r.frame.Position = UDim2.fromOffset(0, y)
			local selected = Draw.rowSelected(row)
			r.frame.BackgroundColor3 = selected and T.rowSel or ((i % 2 == 0) and T.row or T.rowAlt)
			local indent = 8 + (row.depth or 0) * 12
			r.arrow.Position = UDim2.fromOffset(indent - 4, 0)
			r.name.Position = UDim2.fromOffset(indent + 10, 0)
			r.key.Visible = row.kind == "joint" or row.kind == "prop"
			if row.kind == "joint" then
				local hasKids = row.joint and #row.joint.children > 0
				r.arrow.Text = hasKids and (S.collapsed[row.name] and "+" or "-") or ""
				r.name.Text = row.name .. (row.orphan and "  (not in rig)" or "")
				r.name.Font = T.font
				local pending = S.pending[row.name] ~= nil
				r.name.TextColor3 = pending and T.amber or (row.orphan and T.faint or T.text)
				local onKey = Act.keyAt(Draw.rowKeys(row), U.round(S.frame)) ~= nil
				r.key.BackgroundColor3 = pending and T.amber or (onKey and T.bone or T.faint)
			elseif row.kind == "prop" then
				r.arrow.Text = ""
				r.name.Text = row.label
				r.name.Font = T.font
				r.name.TextColor3 = row.prop.isCamera and T.blue or (row.prop.isItem and T.amber or (row.prop.isAction and T.violet or T.green))
				local onKey = Act.keyAt(row.prop.keys, U.round(S.frame)) ~= nil
				r.key.BackgroundColor3 = onKey and T.bone or T.faint
			else
				r.arrow.Text = ""
				r.name.Text = row.label
				r.name.Font = T.bold
				r.name.TextColor3 = T.dim
			end
		end
	end
	for i = used + 1, #UI.listRows do UI.listRows[i].frame.Visible = false end
end

function Draw.keyRows()
	local h = UI.keys.AbsoluteSize.Y
	local used = 0
	for i, row in ipairs(S.rows) do
		local y = (i - 1) * L.ROW - S.scrollY
		if y > -L.ROW and y < h then
			used += 1
			local f = UI.keyRows[used]
			if not f then
				f = U.new("Frame", {Size = UDim2.new(1, 0, 0, L.ROW), BorderSizePixel = 0, ZIndex = 1, Parent = UI.keys})
				UI.keyRows[used] = f
			end
			f.Visible = true
			f.Position = UDim2.fromOffset(0, y)
			f.BackgroundColor3 = Draw.rowSelected(row) and T.rowSel or ((i % 2 == 0) and T.row or T.rowAlt)
			f.BackgroundTransparency = (row.kind == "summary" or row.kind == "events") and 0.2 or 0.45
		end
	end
	for i = used + 1, #UI.keyRows do UI.keyRows[i].Visible = false end
end

local function diamondAt(index)
	local d = UI.diamonds[index]
	if not d then
		local f = U.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 5, Parent = UI.keys})
		d = {frame = f, stroke = U.stroke(T.accent, 2, 0)}
		d.stroke.Parent = f
		UI.diamonds[index] = d
	end
	return d
end

local function flagAt(index)
	local fl = UI.flags[index]
	if not fl then
		local line = U.new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(2, L.ROW - 4), BorderSizePixel = 0,
			ZIndex = 5, Parent = UI.keys})
		local label = U.new("TextLabel", {Size = UDim2.fromOffset(90, L.ROW - 6), BackgroundTransparency = 1, Font = T.font, TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = UI.keys})
		fl = {line = line, label = label}
		UI.flags[index] = fl
	end
	return fl
end

function Draw.keys()
	local w = Draw.width()
	local h = UI.keys.AbsoluteSize.Y
	local used, flagsUsed = 0, 0
	if S.proj then
		local groups, order = Draw.summary()
		for i, row in ipairs(S.rows) do
			local cy = (i - 1) * L.ROW - S.scrollY + L.ROW / 2
			if cy > -L.ROW and cy < h + L.ROW then
				if row.kind == "summary" then
					local lastX = -100
					for _, frame in ipairs(order) do
						local x = Draw.frameToX(frame)
						if x >= -8 and x <= w + 8 and x - lastX >= 3 then
							lastX = x
							local all = true
							for _, k in ipairs(groups[frame]) do
								if not S.sel[k.inst] then all = false break end
							end
							used += 1
							local d = diamondAt(used)
							d.frame.Visible = true
							d.frame.Position = UDim2.fromOffset(x, cy)
							d.frame.Size = UDim2.fromOffset(8, 8)
							d.frame.Rotation = 45
							d.frame.BackgroundColor3 = all and T.accent or T.dim
							d.stroke.Enabled = false
						end
					end
				elseif row.kind == "events" then
					for _, m in ipairs(S.proj.markers) do
						local x = Draw.frameToX(m.frame)
						if x >= -4 and x <= w + 4 then
							flagsUsed += 1
							local fl = flagAt(flagsUsed)
							local selected = S.sel[m.inst]
							fl.line.Visible = true
							fl.line.Position = UDim2.fromOffset(x, cy - L.ROW / 2 + 2)
							fl.line.BackgroundColor3 = selected and T.accent or T.amber
							fl.label.Visible = true
							fl.label.Position = UDim2.fromOffset(x + 4, cy - L.ROW / 2 + 3)
							fl.label.Text = m.name
							fl.label.TextColor3 = selected and T.accent or T.amber
						end
					end
				else
					local lastX = -100
					for _, k in ipairs(Draw.rowKeys(row)) do
						local x = Draw.frameToX(k.frame)
						local selected = S.sel[k.inst]
						if x >= -8 and x <= w + 8 and (x - lastX >= 3 or selected) then
							lastX = x
							used += 1
							local d = diamondAt(used)
							d.frame.Visible = true
							d.frame.Position = UDim2.fromOffset(x, cy)
							local square = k.style == "Constant"
							d.frame.Size = square and UDim2.fromOffset(8, 8) or UDim2.fromOffset(9, 9)
							d.frame.Rotation = square and 0 or 45
							d.frame.BackgroundColor3 = selected and T.accent or Ease.color(k.style)
							d.stroke.Enabled = selected and true or false
							d.stroke.Color = Color3.new(1, 1, 1)
							d.stroke.Thickness = 1.5
						end
					end
				end
			end
		end
	end
	for i = used + 1, #UI.diamonds do UI.diamonds[i].frame.Visible = false end
	for i = flagsUsed + 1, #UI.flags do
		UI.flags[i].line.Visible = false
		UI.flags[i].label.Visible = false
	end
	-- shade outside 0..length
	if S.proj then
		local x0 = Draw.frameToX(0)
		local x1 = Draw.frameToX(S.proj.length)
		UI.startShade.Visible = x0 > 0
		UI.startShade.Position = UDim2.fromOffset(0, 0)
		UI.startShade.Size = UDim2.new(0, math.max(0, x0), 1, 0)
		UI.endShade.Visible = x1 < w
		UI.endShade.Position = UDim2.fromOffset(math.max(0, x1), 0)
		UI.endShade.Size = UDim2.new(0, math.max(0, w - x1), 1, 0)
	else
		UI.startShade.Visible = false
		UI.endShade.Visible = false
	end
end

-- frame numbers along the top; the step widens as you zoom out
local TICK_STEPS = {1, 2, 5, 10, 15, 20, 30, 60, 120, 300, 600, 1200, 3000}
function Draw.ruler()
	local w = Draw.width()
	local ppf = Draw.ppf()
	local step = TICK_STEPS[#TICK_STEPS]
	for _, s in ipairs(TICK_STEPS) do
		if s * ppf >= 46 then step = s break end
	end
	local minor = step >= 10 and step / 5 or (step >= 2 and 1 or nil)
	local used = 0
	local function tick(x, major, text)
		used += 1
		local t = UI.ticks[used]
		if not t then
			t = {
				line = U.new("Frame", {BorderSizePixel = 0, ZIndex = 2, Parent = UI.ruler}),
				label = U.new("TextLabel", {Size = UDim2.fromOffset(60, 12), BackgroundTransparency = 1, Font = T.mono, TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.dim, ZIndex = 2, Parent = UI.ruler}),
			}
			UI.ticks[used] = t
		end
		t.line.Visible = true
		t.line.Position = UDim2.fromOffset(x, major and 13 or 19)
		t.line.Size = UDim2.fromOffset(1, major and 13 or 7)
		t.line.BackgroundColor3 = major and T.dim or T.faint
		t.label.Visible = major
		if major then
			t.label.Position = UDim2.fromOffset(x + 3, 1)
			t.label.Text = text
		end
	end
	local first = math.floor(S.view.start / step) * step
	local f = first
	local guard = 0
	while f <= S.view.finish and guard < 400 do
		guard += 1
		local x = Draw.frameToX(f)
		if x >= -2 and x <= w + 2 then tick(x, true, tostring(f)) end
		if minor and minor * ppf >= 6 then
			for m = f + minor, f + step - minor, minor do
				local mx = Draw.frameToX(m)
				if mx >= 0 and mx <= w then tick(mx, false) end
			end
		end
		f += step
	end
	for i = used + 1, #UI.ticks do
		UI.ticks[i].line.Visible = false
		UI.ticks[i].label.Visible = false
	end
end

function Draw.playhead()
	local x = Draw.frameToX(S.frame)
	local visible = S.proj ~= nil
	UI.playheadKeys.Visible = visible
	UI.playheadRuler.Visible = visible
	UI.playheadTag.Visible = visible
	UI.playheadKeys.Position = UDim2.fromOffset(x - 1, 0)
	UI.playheadRuler.Position = UDim2.fromOffset(x - 1, 0)
	UI.playheadTag.Position = UDim2.fromOffset(x, 1)
	local f = U.round(S.frame)
	UI.playheadTag.Text = tostring(f)
	if S.proj then
		if not UI.frameBox:IsFocused() then UI.frameBox.Text = tostring(f) end
		UI.timeLabel.Text = ("/ %d   %s s"):format(S.proj.length, string.format("%.2f", S.frame / S.proj.fps))
	end
end

-- the easing curve of the selected keys
function Draw.curve(style, dir)
	local segs = UI.ins.curveSegs
	local w, h = 240, 84
	local n = #segs
	local prev
	for i = 0, n do
		local t = i / n
		local v
		if style == "Constant" then v = (t < 1) and 0 or 1 else v = Ease.value(t, style, dir) end
		local p = Vector2.new(t * w, h - (0.15 + v * 0.7) * h)
		if prev then
			local seg = segs[i]
			local d = p - prev
			seg.Position = UDim2.fromOffset((p.X + prev.X) / 2, (p.Y + prev.Y) / 2)
			seg.Size = UDim2.fromOffset(math.max(d.Magnitude, 1) + 1, 2)
			seg.Rotation = math.deg(math.atan2(d.Y, d.X))
			seg.Visible = true
		end
		prev = p
	end
end

function Draw.selectedKeys()
	local list = {}
	if not S.proj then return list end
	for _, tr in pairs(S.proj.tracks) do
		for _, k in ipairs(tr.keys) do
			if S.sel[k.inst] then table.insert(list, k) end
		end
	end
	for _, pt in ipairs(S.proj.props) do
		for _, k in ipairs(pt.keys) do
			if S.sel[k.inst] then table.insert(list, k) end
		end
	end
	return list
end

function Draw.selectedMarkers()
	local list = {}
	if not S.proj then return list end
	for _, m in ipairs(S.proj.markers) do
		if S.sel[m.inst] then table.insert(list, m) end
	end
	return list
end

function Draw.selectedProp()
	if not S.proj or not S.selPropFolder then return nil end
	for _, pt in ipairs(S.proj.props) do
		if pt.folder == S.selPropFolder then return pt end
	end
	return nil
end

local function setBox(box, text)
	if not box:IsFocused() then box.Text = text end
end

function Draw.inspector()
	local ins = UI.ins
	local proj = S.proj
	local frame = U.round(S.frame)
	-- joint
	local j = S.selJoint and S.jointByName[S.selJoint]
	ins.joint.Visible = proj ~= nil and S.selJoint ~= nil
	if ins.joint.Visible then
		ins.jointTitle.Text = "JOINT   " .. S.selJoint
		local cf = Anim.jointT(S.selJoint, S.frame)
		local rx, ry, rz = cf:ToEulerAnglesXYZ()
		local r = {math.deg(rx), math.deg(ry), math.deg(rz)}
		local p = {cf.Position.X, cf.Position.Y, cf.Position.Z}
		for i = 1, 3 do
			setBox(ins.rot[i], U.fmt(r[i], 1))
			setBox(ins.pos[i], U.fmt(p[i], 3))
		end
		local tr = proj.tracks[S.selJoint]
		local onKey = tr and Act.keyAt(tr.keys, frame)
		if S.pending[S.selJoint] then
			ins.jointNote.Text = "posed, not keyed yet - press K"
			ins.jointNote.TextColor3 = T.amber
		elseif onKey then
			ins.jointNote.Text = "key at frame " .. frame .. "  (" .. onKey.style .. " " .. onKey.dir .. ")"
			ins.jointNote.TextColor3 = T.faint
		else
			ins.jointNote.Text = (tr and #tr.keys or 0) .. " keys on this joint" .. (j and "" or "  (not in the rig)")
			ins.jointNote.TextColor3 = T.faint
		end
	end
	-- keys
	local keys = Draw.selectedKeys()
	ins.keys.Visible = #keys > 0
	if #keys > 0 then
		ins.keysTitle.Text = "KEYS   " .. #keys .. " selected"
		local style, dir = keys[1].style, keys[1].dir
		local mixedS, mixedD = false, false
		local minF, maxF = math.huge, -math.huge
		for _, k in ipairs(keys) do
			if k.style ~= style then mixedS = true end
			if k.dir ~= dir then mixedD = true end
			minF = math.min(minF, k.frame)
			maxF = math.max(maxF, k.frame)
		end
		ins.styleBtn.Text = mixedS and "(mixed)" or style
		ins.dirBtn.Text = mixedD and "(mixed)" or dir
		Draw.curve(style, dir)
		ins.keysNote.Text = minF == maxF and ("frame " .. minF) or ("frames " .. minF .. " - " .. maxF)
	end
	-- event
	local markers = Draw.selectedMarkers()
	ins.event.Visible = #markers == 1
	if #markers == 1 then
		local m = markers[1]
		ins.eventTitle.Text = "EVENT   " .. m.name
		setBox(ins.eventName, m.name)
		setBox(ins.eventValue, m.value)
		setBox(ins.eventFrame, tostring(m.frame))
	end
	-- property
	local pt = Draw.selectedProp()
	ins.prop.Visible = pt ~= nil
	if pt then
		ins.propTitle.Text = pt.isItem and ("ITEM   " .. (pt.target and pt.target.Name or "?"))
			or ((pt.isAction and "EFFECT   " or "PROPERTY   ") .. pt.property)
		ins.propTarget.Text = pt.isCamera and "the camera" or (pt.target and pt.target:GetFullName() or "(the object is gone)")
		local value = Anim.sampleValue(pt.keys, S.frame, pt.kind)
		if pt.isAction then
			local k = Act.keyAt(pt.keys, frame)
			value = k and k.value or nil
		elseif value == nil then
			local target = pt.isCamera and workspace.CurrentCamera or pt.target
			local ok, cur = pcall(function() return Anim.getProp(target, pt.property) end)
			value = ok and cur or nil
		end
		setBox(ins.propValue, value ~= nil and U.valueText(value) or "")
		ins.propNote.Text = pt.kind .. " - " .. #pt.keys .. " keys" .. (pt.isCamera and not S.camPreview and "  (Camera preview off)" or "")
	end
	-- animation
	ins.project.Visible = proj ~= nil
	if proj then
		ins.projectTitle.Text = "ANIMATION"
		setBox(ins.projName, proj.name)
		setBox(ins.projFps, tostring(proj.fps))
		setBox(ins.projLength, tostring(proj.length))
		ins.projSeconds.Text = ("%d frames = %s s at %d FPS"):format(proj.length, U.fmt(proj.length / proj.fps, 2), proj.fps)
		ins.loopBtn.Text = proj.loop and "Looped" or "Plays once"
		UI.setActive(ins.loopBtn, proj.loop)
		ins.prioBtn.Text = "Priority: " .. proj.priority
		ins.defStyleBtn.Text = proj.defStyle
		ins.defDirBtn.Text = proj.defDir
		local count = 0
		for _, tr in pairs(proj.tracks) do count += #tr.keys end
		for _, p in ipairs(proj.props) do count += #p.keys end
		ins.projNote.Text = count .. " keys, " .. #proj.markers .. " events, " .. #proj.props .. " property tracks"
	end
end

function Draw.toolbar()
	UI.projBtn.Text = "Animation: " .. (S.proj and S.proj.name or "none") .. "  v"
	UI.rigLabel.Text = "Rig: " .. (S.rig and S.rig.Name or (S.proj and S.proj.rig and (S.proj.rig.Name .. " (released)") or "none"))
	UI.rigLabel.TextColor3 = S.rig and T.text or T.dim
	UI.playBtn.Text = S.playing and "STOP" or "PLAY"
	UI.setActive(UI.playBtn, S.playing)
	UI.setActive(UI.loopBtn, S.loopPlay)
	UI.speedBtn.Text = U.fmt(S.speed, 2) .. "x"
	UI.setActive(UI.poseBtn, S.poseMode)
	UI.setActive(UI.rotBtn, S.tool == "rotate", T.panel3)
	UI.setActive(UI.moveBtn, S.tool == "move", T.panel3)
	UI.spaceBtn.Text = S.space == "world" and "World" or "Local"
	UI.snapBtn.Text = S.snapOn and ("Snap " .. U.fmt(S.snapRot, 1) .. "° " .. U.fmt(S.snapMove, 3)) or "Snap off"
	UI.setActive(UI.snapBtn, S.snapOn, T.panel3)
	UI.setActive(UI.autoBtn, S.autoKey)
	local info = {}
	if S.rig then table.insert(info, #S.joints .. " joints") table.insert(info, "preview: " .. S.applyMode) end
	if S.proj then table.insert(info, S.proj.fps .. " FPS") end
	UI.info.Text = table.concat(info, "  -  ")
end

function Draw.empty()
	local text = ""
	if not S.proj then
		text = "Select a character (or any part / model) in the viewport,\nthen  Add > Rig  or  Add > Item.   File > Open  for saved animations."
	elseif not S.rig and #S.proj.props == 0 then
		text = "Nothing on the timeline yet.\nSelect a character or a part, then  Add > Rig  or  Add > Item."
	end
	UI.emptyNote.Text = text
	UI.emptyNote.Visible = text ~= ""
end

function Draw.all()
	if not UI.root then return end
	Draw.buildRows()
	Draw.list()
	Draw.keyRows()
	Draw.keys()
	Draw.ruler()
	Draw.playhead()
	Draw.inspector()
	Draw.toolbar()
	Draw.empty()
end

-- ===================================================================================================
-- actions
-- ===================================================================================================
function Act.status(text, isError)
	if not UI.status then return end
	UI.status.Text = text
	UI.status.TextColor3 = isError and T.accent or T.dim
	S.statusAt = os.clock()
end

function Act.hint(text)
	if not UI.status then return end
	if os.clock() - (S.statusAt or 0) > 2.5 then
		UI.status.Text = text
		UI.status.TextColor3 = T.faint
	end
end

function Act.saveSetting(key, value)
	pcall(function() plugin:SetSetting("Marrow_" .. key, value) end)
end

function Act.keyAt(keys, frame)
	for _, k in ipairs(keys) do
		if k.frame == frame then return k end
	end
	return nil
end

function Act.allKeyFrames(includeProps)
	local cacheKey = tostring(S.dataVersion) .. (includeProps and "p" or "j")
	if Act.frameCache and Act.frameCache.key == cacheKey and not S.drag then return Act.frameCache.list end
	local set = {}
	if S.proj then
		for _, tr in pairs(S.proj.tracks) do
			for _, k in ipairs(tr.keys) do set[k.frame] = true end
		end
		if includeProps then
			for _, pt in ipairs(S.proj.props) do
				for _, k in ipairs(pt.keys) do set[k.frame] = true end
			end
		end
	end
	local list = {}
	for f in pairs(set) do table.insert(list, f) end
	table.sort(list)
	Act.frameCache = {key = cacheKey, list = list}
	return list
end

function Act.neighborFrames(f)
	local prev, nextF
	for _, kf in ipairs(Act.allKeyFrames(false)) do
		if kf < f then prev = kf elseif kf > f and not nextF then nextF = kf end
	end
	return prev, nextF
end

-- read everything back from the instances, show it on the rig, redraw
function Act.reload(keepView)
	S.dataVersion = (S.dataVersion or 0) + 1
	if S.proj then
		if S.proj.folder and S.proj.folder.Parent then
			S.proj = Store.load(S.proj.folder)
		else
			S.proj = nil
		end
	end
	local wantRig = S.proj and not S.released and S.proj.rig or nil
	if wantRig and not wantRig.Parent then wantRig = nil end
	if UI.widget and not UI.widget.Enabled then wantRig = nil end
	if wantRig ~= S.rig then
		if wantRig then
			local ok, note = Rig.bind(wantRig)
			if not ok then Act.status(note, true) elseif note then Act.status(note) end
		else
			Rig.unbind()
		end
	elseif S.rig and not S.rig.Parent then
		Rig.unbind()
	end
	for inst in pairs(S.sel) do
		if not inst.Parent then S.sel[inst] = nil end
	end
	if S.selPropFolder and not S.selPropFolder.Parent then S.selPropFolder = nil end
	if S.selJoint and S.rig and not S.jointByName[S.selJoint] and not (S.proj and S.proj.tracks[S.selJoint]) then S.selJoint = nil end
	if S.proj then S.frame = U.clamp(S.frame, 0, S.proj.length) end
	if not keepView and S.proj and S.view.finish - S.view.start < 4 then Act.fitView() end
	Anim.apply(S.frame)
	Draw.all()
	View.refresh(true)
	Gizmo.place()
end

function Act.fitView()
	local length = S.proj and S.proj.length or 120
	local pad = math.max(2, length * 0.04)
	S.view.start = -pad
	S.view.finish = length + pad
end

-- ===== animations =====
function Act.openProject(folder)
	Act.stop()
	Anim.restoreProps()
	Rig.unbind()
	S.proj, S.sel, S.pending, S.selJoint, S.selPropFolder = nil, {}, {}, nil, nil
	S.released = false
	S.frame = 0
	S.scrollY = 0
	if folder and folder.Parent then
		S.proj = Store.load(folder)
		Act.saveSetting("lastProject", folder.Name)
		Act.fitView()
	end
	Act.reload()
	if S.proj then
		Act.status("Opened " .. S.proj.name .. (S.rig and "" or "   -   select its rig and press Attach selected"))
	end
end

function Act.newProject()
	local rig = Rig.fromSelection() or (S.proj and S.proj.rig) or nil
	local default = Store.uniqueName(rig and (rig.Name .. " anim") or "Animation")
	UI.dialog("New animation",
		rig and ("Rig: " .. rig:GetFullName()) or "No rig selected. You can attach one later: select it and press Attach selected.",
		{{label = "Name", default = default}, {label = "FPS", default = "60"}, {label = "Length (frames)", default = "120"}},
		function(v)
			local name = Store.uniqueName((v[1] ~= "" and v[1]) or default)
			local fps = U.clamp(math.floor(tonumber(v[2]) or 60), 1, 240)
			local length = U.clamp(math.floor(tonumber(v[3]) or 120), 1, 36000)
			local folder
			Hist.run("Marrow: new animation", function()
				folder = Store.create(name, rig)
				folder:SetAttribute("Fps", fps)
				folder:SetAttribute("Length", length)
			end)
			if folder then Act.openProject(folder) end
		end, "Create")
end

function Act.projectMenu(b)
	local items = {}
	local list = Store.list()
	if #list == 0 then table.insert(items, {title = "No animations in this place yet"}) end
	for _, f in ipairs(list) do
		table.insert(items, {text = f.Name, checked = S.proj ~= nil and S.proj.folder == f, fn = function() Act.openProject(f) end})
	end
	table.insert(items, {sep = true})
	table.insert(items, {text = "New animation...", fn = Act.newProject})
	table.insert(items, {text = "Duplicate", disabled = not S.proj, fn = Act.duplicateProject})
	table.insert(items, {text = "Rename...", disabled = not S.proj, fn = Act.renameDialog})
	table.insert(items, {text = "Delete...", disabled = not S.proj, fn = Act.deleteProject})
	table.insert(items, {text = "Close", disabled = not S.proj, fn = function() Act.openProject(nil) end})
	UI.menuAt(b or UI.projBtn, items, 260)
end

function Act.duplicateProject()
	if not S.proj then return end
	local source = S.proj.folder
	local copy
	Hist.run("Marrow: duplicate animation", function()
		copy = source:Clone()
		copy.Name = Store.uniqueName(source.Name .. " copy")
		copy.Parent = source.Parent
	end)
	if copy then Act.openProject(copy) end
end

function Act.renameProject(text)
	if not S.proj then return end
	text = tostring(text):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" or text == S.proj.name then
		Draw.inspector()
		return
	end
	local folder = S.proj.folder
	local name = Store.uniqueName(text)
	Hist.run("Marrow: rename animation", function() folder.Name = name end)
	Act.saveSetting("lastProject", name)
end

function Act.renameDialog()
	if not S.proj then return end
	UI.dialog("Rename animation", nil, {{label = "Name", default = S.proj.name}}, function(v) Act.renameProject(v[1]) end, "Rename")
end

function Act.deleteProject()
	if not S.proj then return end
	local folder = S.proj.folder
	UI.confirm("Delete " .. folder.Name .. "?", "It can be brought back with Undo (Ctrl+Z).", function()
		Act.openProject(nil)
		Hist.run("Marrow: delete animation", function() folder.Parent = nil end)
	end, "Delete")
end

-- ===== the rig =====
function Act.attachSelected()
	local rig = Rig.fromSelection()
	if not rig then
		Act.status("Select a model with Motor6D joints first (click it in the viewport or the Explorer)", true)
		return
	end
	if not S.proj then
		local folder
		Hist.run("Marrow: new animation", function() folder = Store.create(Store.uniqueName(rig.Name .. " anim"), rig) end)
		if folder then Act.openProject(folder) end
		return
	end
	Act.stop()
	S.released = false
	S.pending = {}
	Rig.unbind()
	local fixed = 0
	Hist.run("Marrow: attach rig", function()
		local rv = S.proj.folder:FindFirstChild("Rig")
		if not rv or not rv:IsA("ObjectValue") then
			if rv then rv.Parent = nil end
			rv = U.new("ObjectValue", {Name = "Rig", Parent = S.proj.folder})
		end
		rv.Value = rig
		-- jointed parts can't be anchored or the joints can't move them (the root part stays as it is)
		local joints, roots = Rig.collect(rig)
		local rootSet = {}
		for _, r in ipairs(roots) do rootSet[r] = true end
		for _, j in ipairs(joints) do
			if j.part1.Anchored and not rootSet[j.part1] then
				j.part1.Anchored = false
				fixed += 1
			end
		end
	end)
	Act.status("Attached " .. rig.Name .. (fixed > 0 and ("  -  unanchored " .. fixed .. " parts so the joints can move them") or ""))
end

function Act.releaseRig()
	Act.stop()
	S.pending = {}
	S.released = true
	Act.setPoseMode(false)
	Rig.unbind()
	Act.reload()
	Act.status("Released: the rig is back in its rest pose. Press Attach selected to keep animating it.")
end

-- ===== playback =====
function Act.play()
	if not S.proj then return end
	if S.frame >= S.proj.length then S.frame = 0 end
	S.pending = {}
	S.playing = true
	Anim.fireActions(S.frame - 0.5, S.frame)
	Gizmo.hide()
	Draw.toolbar()
end

function Act.stop()
	if not S.playing then return end
	S.playing = false
	S.frame = U.round(S.frame)
	Anim.apply(S.frame)
	Draw.all()
	View.refresh()
	Gizmo.place()
end

function Act.togglePlay()
	if S.playing then Act.stop() else Act.play() end
end

function Act.setFrame(f)
	if not S.proj then return end
	f = U.clamp(U.round(f), 0, S.proj.length)
	if next(S.pending) then
		S.pending = {}
		Act.status("Unkeyed pose changes were dropped (press K to key a pose, or turn Auto-key on)")
	end
	S.frame = f
	Anim.apply(f)
	Draw.playhead()
	Draw.list()
	Draw.inspector()
	View.refresh()
	Gizmo.place()
end

function Act.step(d)
	if S.playing then Act.stop() end
	local before = U.round(S.frame)
	Act.setFrame(before + d)
	if d > 0 then Anim.fireActions(before, U.round(S.frame)) end
end

function Act.toStart()
	if S.playing then Act.stop() end
	Act.setFrame(0)
end

function Act.toEnd()
	if S.playing then Act.stop() end
	if S.proj then Act.setFrame(S.proj.length) end
end

function Act.prevKey()
	if S.playing then Act.stop() end
	local f, best = U.round(S.frame), nil
	for _, kf in ipairs(Act.allKeyFrames(true)) do
		if kf < f then best = kf end
	end
	if best then Act.setFrame(best) end
end

function Act.nextKey()
	if S.playing then Act.stop() end
	local f = U.round(S.frame)
	for _, kf in ipairs(Act.allKeyFrames(true)) do
		if kf > f then
			Act.setFrame(kf)
			return
		end
	end
end

function Act.frameBoxCommit(text)
	local n = tonumber(text)
	if n and U.round(n) == U.round(S.frame) then
		Draw.playhead()
		return
	end
	if n then
		if S.playing then Act.stop() end
		Act.setFrame(n)
	else
		Draw.playhead()
	end
end

function Act.toggleLoopPlay()
	S.loopPlay = not S.loopPlay
	Act.saveSetting("loopPlay", S.loopPlay)
	Draw.toolbar()
end

function Act.speedMenu(b)
	local items = {}
	for _, s in ipairs({0.1, 0.25, 0.5, 0.75, 1, 1.5, 2}) do
		table.insert(items, {text = U.fmt(s, 2) .. "x", checked = S.speed == s, fn = function()
			S.speed = s
			Draw.toolbar()
		end})
	end
	UI.menuAt(b, items, 110)
end

-- ===== selection =====
function Act.selectJoint(name)
	S.selJoint = name
	if name then S.selPropFolder = nil end
	Draw.list()
	Draw.keyRows()
	Draw.inspector()
	View.refresh()
	Gizmo.place()
end

function Act.selectProp(folder)
	S.selPropFolder = folder
	if folder then S.selJoint = nil end
	Draw.list()
	Draw.keyRows()
	Draw.inspector()
	View.refresh()
	Gizmo.place()
end

function Act.selectAll()
	if not S.proj then return end
	S.sel = {}
	for _, tr in pairs(S.proj.tracks) do
		for _, k in ipairs(tr.keys) do S.sel[k.inst] = true end
	end
	for _, pt in ipairs(S.proj.props) do
		for _, k in ipairs(pt.keys) do S.sel[k.inst] = true end
	end
	Draw.all()
end

function Act.selectColumn(frame)
	if not S.proj then return end
	S.sel = {}
	for _, tr in pairs(S.proj.tracks) do
		for _, k in ipairs(tr.keys) do
			if k.frame == frame then S.sel[k.inst] = true end
		end
	end
	for _, pt in ipairs(S.proj.props) do
		for _, k in ipairs(pt.keys) do
			if k.frame == frame then S.sel[k.inst] = true end
		end
	end
	Draw.all()
end

function Act.selectRowKeys()
	if not S.proj then return end
	S.sel = {}
	if S.selJoint and S.proj.tracks[S.selJoint] then
		for _, k in ipairs(S.proj.tracks[S.selJoint].keys) do S.sel[k.inst] = true end
	end
	local pt = Draw.selectedProp()
	if pt then
		for _, k in ipairs(pt.keys) do S.sel[k.inst] = true end
	end
	Draw.all()
end

-- ===== keys =====
function Act.keyJoint(name, frame)
	if not S.proj then return end
	frame = frame or U.round(S.frame)
	local cf = Anim.jointT(name, S.frame)
	S.pending[name] = nil
	Hist.run("Marrow: key " .. name, function() Store.setJointKey(name, frame, cf) end, true)
end

function Act.keyProp(pt)
	local target = pt.isCamera and workspace.CurrentCamera or pt.target
	if not target then
		Act.status("The object of this track is gone", true)
		return
	end
	if pt.isAction then
		-- a burst / sound key: the count (or "play") of the nearest key, or a default
		local last = pt.keys[#pt.keys]
		local value = last and last.value or (pt.kind == "emit" and 20 or true)
		local f = U.round(S.frame)
		Hist.run("Marrow: key " .. pt.property, function() Store.setPropKey(pt, f, value, "Constant", "InOut") end, true)
		return
	end
	local ok, value = pcall(Anim.getProp, target, pt.property)
	if not ok or U.valueKind(value) == nil then
		Act.status("Can't read " .. pt.property .. " from " .. target.Name, true)
		return
	end
	local frame = U.round(S.frame)
	Hist.run("Marrow: key " .. pt.property, function() Store.setPropKey(pt, frame, value) end, true)
end

function Act.keySelected()
	if not S.proj then return end
	local pt = Draw.selectedProp()
	if pt then
		Act.keyProp(pt)
	elseif S.selJoint then
		Act.keyJoint(S.selJoint)
	else
		Act.status("Select a joint (click it in POSE mode or in the list) or a property track first", true)
	end
end

function Act.keyAll()
	if not S.proj or not S.rig then
		Act.status("Attach the rig first", true)
		return
	end
	local frame = U.round(S.frame)
	local values = {}
	for _, j in ipairs(S.joints) do values[j.name] = Anim.jointT(j.name, S.frame) end
	S.pending = {}
	Hist.run("Marrow: key all joints", function()
		for name, cf in pairs(values) do Store.setJointKey(name, frame, cf) end
	end, true)
end

-- a joint was posed (gizmo or numbers): key it, or keep it as an unkeyed pose when Auto-key is off
function Act.commitJoint(name, cf)
	if not S.proj then return end
	local frame = U.round(S.frame)
	local tr = S.proj.tracks[name]
	local exists = tr and Act.keyAt(tr.keys, frame)
	if S.autoKey or exists then
		S.pending[name] = nil
		Hist.run("Marrow: pose " .. name, function() Store.setJointKey(name, frame, cf) end, true)
	else
		S.pending[name] = cf
		Anim.apply(S.frame)
		Draw.list()
		Draw.inspector()
		View.refresh(true)
		Gizmo.place()
		Act.status("Posed " .. name .. " but not keyed: press K (or turn Auto-key on)")
	end
end

function Act.addKeyAt(row, frame)
	if not S.proj then return end
	if row.kind == "joint" then
		local cf = Anim.jointTAt(row.name, frame, true)
		Hist.run("Marrow: add key", function() Store.setJointKey(row.name, frame, cf) end, true)
	elseif row.kind == "prop" then
		local pt = row.prop
		local value = Anim.sampleValue(pt.keys, frame, pt.kind)
		if value == nil then
			local target = pt.isCamera and workspace.CurrentCamera or pt.target
			local ok, cur = pcall(Anim.getProp, target, pt.property)
			value = ok and cur or nil
		end
		if value == nil then return end
		Hist.run("Marrow: add key", function() Store.setPropKey(pt, frame, value) end, true)
	end
end

function Act.resetJoint()
	if not S.selJoint then return end
	Act.commitJoint(S.selJoint, CFrame.identity)
end

function Act.deleteSelected()
	local list = {}
	for inst in pairs(S.sel) do
		if inst.Parent then table.insert(list, inst) end
	end
	if #list == 0 then
		Act.status("Nothing selected")
		return
	end
	S.sel = {}
	Hist.run("Marrow: delete " .. #list .. " keys", function()
		for _, inst in ipairs(list) do inst.Parent = nil end
	end, true)
end

function Act.copyKeys()
	local keys = Draw.selectedKeys()
	if #keys == 0 then
		Act.copyPose()
		return
	end
	local base = math.huge
	for _, k in ipairs(keys) do base = math.min(base, k.frame) end
	local clip = {}
	for _, k in ipairs(keys) do
		table.insert(clip, {kind = k.kind, name = (k.kind == "joint") and k.track.name or nil, folder = (k.kind == "prop") and k.track.folder or nil,
			offset = k.frame - base, cf = k.cf, value = k.value, style = k.style, dir = k.dir})
	end
	S.clipboard = clip
	Act.status("Copied " .. #clip .. " keys  -  Ctrl+V pastes them at the playhead")
end

function Act.pasteKeys(frame)
	local clip = S.clipboard
	if not clip or not S.proj then
		Act.status("Nothing copied yet")
		return
	end
	frame = frame or U.round(S.frame)
	local made = {}
	Hist.run("Marrow: paste keys", function()
		for _, c in ipairs(clip) do
			if c.kind == "joint" then
				table.insert(made, Store.setJointKey(c.name, frame + c.offset, c.cf, c.style, c.dir))
			elseif c.kind == "prop" and c.folder and c.folder.Parent then
				table.insert(made, Store.setPropKey({folder = c.folder}, frame + c.offset, c.value, c.style, c.dir))
			end
		end
	end, true)
	S.sel = {}
	for _, inst in ipairs(made) do S.sel[inst] = true end
	Draw.all()
end

-- ===== poses =====
function Act.copyPose()
	if not S.rig then
		Act.status("Attach the rig first", true)
		return
	end
	local clip = {}
	for _, j in ipairs(S.joints) do clip[j.name] = j.rest * Anim.jointT(j.name, S.frame) * j.motor.C1:Inverse() end
	S.poseClipboard = clip
	Act.status("Copied the pose at frame " .. U.round(S.frame))
end

function Act.pastePose(mirrored)
	local clip = S.poseClipboard
	if not clip or not S.rig then
		Act.status("Copy a pose first (Copy pose, or Ctrl+C with no keys selected)", true)
		return
	end
	local frame = U.round(S.frame)
	local values = {}
	for name, a in pairs(clip) do
		local target, A = name, a
		if mirrored then
			target = U.partnerName(name) or name
			if not S.jointByName[target] then target = name end
			A = U.mirror(a)
		end
		local j = S.jointByName[target]
		if j then values[target] = j.rest:Inverse() * A * j.motor.C1 end
	end
	S.pending = {}
	Hist.run(mirrored and "Marrow: paste mirrored pose" or "Marrow: paste pose", function()
		for name, cf in pairs(values) do Store.setJointKey(name, frame, cf) end
	end, true)
end

function Act.mirrorPose()
	if not S.rig or not S.proj then return end
	local frame = U.round(S.frame)
	local values = {}
	for _, j in ipairs(S.joints) do
		local a = j.rest * Anim.jointT(j.name, S.frame) * j.motor.C1:Inverse()
		local target = U.partnerName(j.name)
		if not target or not S.jointByName[target] then target = j.name end
		local tj = S.jointByName[target]
		values[target] = tj.rest:Inverse() * U.mirror(a) * tj.motor.C1
	end
	local changed = {}
	for name, cf in pairs(values) do
		local tr = S.proj.tracks[name]
		local cur = Anim.jointT(name, S.frame)
		if (tr and #tr.keys > 0) or (cur.Position - cf.Position).Magnitude > 1e-4 or U.angleOf(cur:ToObjectSpace(cf)) > 1e-4 then
			changed[name] = cf
		end
	end
	S.pending = {}
	Hist.run("Marrow: mirror pose", function()
		for name, cf in pairs(changed) do Store.setJointKey(name, frame, cf) end
	end, true)
end

function Act.numericPose(which, axis, text)
	if not S.selJoint or not S.proj then return end
	local n = tonumber(text)
	if not n then
		Draw.inspector()
		return
	end
	local cf = Anim.jointT(S.selJoint, S.frame)
	local rx, ry, rz = cf:ToEulerAnglesXYZ()
	local r = {math.deg(rx), math.deg(ry), math.deg(rz)}
	local p = {cf.Position.X, cf.Position.Y, cf.Position.Z}
	local old = (which == "rot") and r[axis] or p[axis]
	if math.abs(old - n) < 1e-4 then return end
	if which == "rot" then r[axis] = n else p[axis] = n end
	local newCf = CFrame.new(p[1], p[2], p[3]) * CFrame.fromEulerAnglesXYZ(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
	Act.commitJoint(S.selJoint, newCf)
end

-- ===== easing =====
function Act.setEasing(style, dir)
	local keys = Draw.selectedKeys()
	if #keys == 0 then
		Act.status("Select keys first (click them on the timeline)")
		return
	end
	Hist.run("Marrow: easing " .. tostring(style or dir), function()
		for _, k in ipairs(keys) do
			if style then k.inst:SetAttribute("S", style) end
			if dir then k.inst:SetAttribute("D", dir) end
		end
	end, true)
end

function Act.styleMenu(b)
	local items = {}
	for _, s in ipairs(Ease.STYLES) do table.insert(items, {text = s, fn = function() Act.setEasing(s, nil) end}) end
	UI.menuAt(b, items, 140)
end

function Act.dirMenu(b)
	local items = {}
	for _, d in ipairs(Ease.DIRS) do table.insert(items, {text = d, fn = function() Act.setEasing(nil, d) end}) end
	UI.menuAt(b, items, 110)
end

-- ===== moving keys in time =====
function Act.selectionRange()
	local minF, maxF = math.huge, -math.huge
	for inst in pairs(S.sel) do
		local f = inst.Parent and inst:GetAttribute("F")
		if f then
			minF = math.min(minF, f)
			maxF = math.max(maxF, f)
		end
	end
	if minF == math.huge then return nil end
	return minF, maxF
end

function Act.transformKeys(name, fn)
	local items = {}
	for inst in pairs(S.sel) do
		if inst.Parent then table.insert(items, inst) end
	end
	if #items == 0 then
		Act.status("Select keys first")
		return
	end
	Hist.run(name, function()
		local folders, winners = {}, {}
		for _, inst in ipairs(items) do
			local f = inst:GetAttribute("F") or 0
			inst:SetAttribute("F", math.max(0, U.round(fn(f))))
			winners[inst] = true
			folders[inst.Parent] = true
		end
		for folder in pairs(folders) do
			if folder.Name ~= "Markers" then Store.resolveCollisions(folder, winners) end
		end
	end, true)
end

function Act.reverseKeys()
	local minF, maxF = Act.selectionRange()
	if not minF then return end
	Act.transformKeys("Marrow: reverse keys", function(f) return minF + maxF - f end)
end

function Act.stretchDialog()
	local minF = Act.selectionRange()
	if not minF then
		Act.status("Select keys first")
		return
	end
	UI.dialog("Stretch keys", "Measured from the first selected key. 2 = twice as long, 0.5 = twice as fast.",
		{{label = "Factor", default = "2"}}, function(v)
			local factor = tonumber(v[1])
			if not factor or factor <= 0 then return end
			Act.transformKeys("Marrow: stretch keys", function(f) return minF + (f - minF) * factor end)
		end, "Stretch")
end

function Act.shiftDialog()
	if not Act.selectionRange() then
		Act.status("Select keys first")
		return
	end
	UI.dialog("Shift keys", "Moves the selected keys by this many frames (negative = earlier).",
		{{label = "Frames", default = "10"}}, function(v)
			local n = tonumber(v[1])
			if not n then return end
			Act.transformKeys("Marrow: shift keys", function(f) return f + n end)
		end, "Shift")
end

-- ===== timeline mouse =====
function Act.hitKeys(row, x)
	if row.kind == "summary" then
		local groups, order = Draw.summary()
		local best, bestD = nil, 7
		for _, f in ipairs(order) do
			local d = math.abs(Draw.frameToX(f) - x)
			if d < bestD then best, bestD = f, d end
		end
		return best and groups[best] or nil
	end
	local best, bestD = nil, 7
	for _, k in ipairs(Draw.rowKeys(row)) do
		local d = math.abs(Draw.frameToX(k.frame) - x)
		if d < bestD then best, bestD = k, d end
	end
	return best and {best} or nil
end

function Act.rowAt(gui)
	local m = Draw.mouseIn(gui)
	return S.rows[math.floor((m.Y + S.scrollY) / L.ROW) + 1], m
end

function Act.keysPress(input)
	if not S.proj then return end
	if S.playing then Act.stop() end
	local row, m = Act.rowAt(UI.keys)
	local shift = U.isDown(input, Enum.ModifierKey.Shift)
	local copy = U.isDown(input, Enum.ModifierKey.Ctrl) or U.isDown(input, Enum.ModifierKey.Alt)
	local now = os.clock()
	local dbl = now - S.lastClick.t < 0.32 and (m - S.lastClick.p).Magnitude < 6
	S.lastClick = {t = now, p = m}
	if row then
		if row.kind == "joint" then
			S.selJoint = row.name
			S.selPropFolder = nil
		elseif row.kind == "prop" then
			S.selPropFolder = row.prop.folder
			S.selJoint = nil
		end
	end
	local hits = row and Act.hitKeys(row, m.X) or nil
	if hits then
		local allSel = true
		for _, k in ipairs(hits) do
			if not S.sel[k.inst] then allSel = false break end
		end
		if shift then
			for _, k in ipairs(hits) do S.sel[k.inst] = (not allSel) or nil end
		elseif not allSel or dbl then
			S.sel = {}
			for _, k in ipairs(hits) do S.sel[k.inst] = true end
		end
		if dbl then Act.setFrame(hits[1].frame) end
		Draw.all()
		View.refresh()
		Gizmo.place()
		if not shift then Act.beginKeyDrag(m, copy) end
		return
	end
	if dbl and row then
		local frame = math.max(0, U.round(Draw.xToFrame(m.X)))
		if row.kind == "joint" or row.kind == "prop" then
			Act.addKeyAt(row, frame)
			return
		elseif row.kind == "events" then
			Act.addMarker(frame)
			return
		end
	end
	if not shift then S.sel = {} end
	Draw.all()
	View.refresh()
	Gizmo.place()
	Act.beginBox(m, shift)
end

function Act.beginKeyDrag(m, duplicate)
	local entries = {}
	local function collect(list)
		for _, k in ipairs(list) do
			if S.sel[k.inst] then table.insert(entries, {entry = k, orig = k.frame}) end
		end
	end
	for _, tr in pairs(S.proj.tracks) do collect(tr.keys) end
	for _, pt in ipairs(S.proj.props) do collect(pt.keys) end
	collect(S.proj.markers)
	if #entries == 0 then return end
	S.drag = {kind = "keys", startX = m.X, startFrame = Draw.xToFrame(m.X), entries = entries, delta = 0, duplicate = duplicate, moved = false}
	UI.catcher.Visible = true
end

function Act.dragKeys(m)
	local d = S.drag
	if not d.moved and math.abs(m.X - d.startX) < 4 then return end
	d.moved = true
	local delta = U.round(Draw.xToFrame(m.X) - d.startFrame)
	local minOrig = math.huge
	for _, e in ipairs(d.entries) do minOrig = math.min(minOrig, e.orig) end
	delta = math.max(delta, -minOrig)
	if delta == d.delta then return end
	d.delta = delta
	for _, e in ipairs(d.entries) do e.entry.frame = e.orig + delta end
	for _, tr in pairs(S.proj.tracks) do table.sort(tr.keys, byFrame) end
	for _, pt in ipairs(S.proj.props) do table.sort(pt.keys, byFrame) end
	Draw.keys()
	Act.status(("%s %d keys  %s%d frames"):format(d.duplicate and "Copying" or "Moving", #d.entries, delta >= 0 and "+" or "", delta))
end

function Act.endKeyDrag(d)
	if not d.moved or d.delta == 0 then
		Draw.keys()
		return
	end
	local delta = d.delta
	Hist.run(d.duplicate and "Marrow: copy keys" or "Marrow: move keys", function()
		local winners, folders = {}, {}
		for _, e in ipairs(d.entries) do
			local inst = e.entry.inst
			if inst.Parent then
				local target = inst
				if d.duplicate then
					target = inst:Clone()
					target.Parent = inst.Parent
					S.sel[inst] = nil
					S.sel[target] = true
				end
				target:SetAttribute("F", e.orig + delta)
				winners[target] = true
				folders[target.Parent] = true
			end
		end
		for folder in pairs(folders) do
			if folder.Name ~= "Markers" then Store.resolveCollisions(folder, winners) end
		end
	end, true)
end

function Act.beginBox(m, additive)
	S.drag = {kind = "box", start = m, base = additive and table.clone(S.sel) or {}}
	UI.catcher.Visible = true
end

function Act.dragBox(m)
	local d = S.drag
	local x0, x1 = math.min(d.start.X, m.X), math.max(d.start.X, m.X)
	local y0, y1 = math.min(d.start.Y, m.Y), math.max(d.start.Y, m.Y)
	if x1 - x0 < 3 and y1 - y0 < 3 then return end
	UI.boxSel.Visible = true
	UI.boxSel.Position = UDim2.fromOffset(x0, y0)
	UI.boxSel.Size = UDim2.fromOffset(x1 - x0, y1 - y0)
	local f0, f1 = Draw.xToFrame(x0), Draw.xToFrame(x1)
	local r0 = math.floor((y0 + S.scrollY) / L.ROW) + 1
	local r1 = math.floor((y1 + S.scrollY) / L.ROW) + 1
	local sel = table.clone(d.base)
	for i = r0, r1 do
		local row = S.rows[i]
		if row then
			if row.kind == "summary" then
				local groups, order = Draw.summary()
				for _, f in ipairs(order) do
					if f >= f0 and f <= f1 then
						for _, k in ipairs(groups[f]) do sel[k.inst] = true end
					end
				end
			else
				for _, k in ipairs(Draw.rowKeys(row)) do
					if k.frame >= f0 and k.frame <= f1 then sel[k.inst] = true end
				end
			end
		end
	end
	S.sel = sel
	Draw.keys()
end

function Act.keysContext()
	if not S.proj then return end
	local row, m = Act.rowAt(UI.keys)
	local frame = math.max(0, U.round(Draw.xToFrame(m.X)))
	local hits = row and Act.hitKeys(row, m.X)
	if hits then
		local any = false
		for _, k in ipairs(hits) do
			if S.sel[k.inst] then any = true end
		end
		if not any then
			S.sel = {}
			for _, k in ipairs(hits) do S.sel[k.inst] = true end
			Draw.all()
		end
	end
	local count = 0
	for _ in pairs(S.sel) do count += 1 end
	local items = {}
	if count > 0 then
		table.insert(items, {title = count .. " selected"})
		for i = 1, 5 do
			local p = Ease.PRESETS[i == 5 and 8 or i]
			table.insert(items, {text = "Easing: " .. p[1], fn = function() Act.setEasing(p[2], p[3]) end})
		end
		table.insert(items, {text = "Copy  (Ctrl+C)", fn = Act.copyKeys})
		table.insert(items, {text = "Delete  (Del)", fn = Act.deleteSelected})
		table.insert(items, {text = "Reverse", fn = Act.reverseKeys})
		table.insert(items, {sep = true})
	end
	table.insert(items, {text = "Paste here (frame " .. frame .. ")", disabled = not S.clipboard, fn = function() Act.pasteKeys(frame) end})
	if row and (row.kind == "joint" or row.kind == "prop") then
		table.insert(items, {text = "Add key here", fn = function() Act.addKeyAt(row, frame) end})
	end
	table.insert(items, {text = "Select all at frame " .. frame, fn = function() Act.selectColumn(frame) end})
	table.insert(items, {text = "Add event here", fn = function() Act.addMarker(frame) end})
	table.insert(items, {text = "Playhead here", fn = function() Act.setFrame(frame) end})
	local p = UI.mouse()
	UI.openMenu(items, p.X, p.Y, 220)
end

function Act.listPress(input)
	local t = input.UserInputType
	local row, m = Act.rowAt(UI.list)
	if not row then return end
	if t == Enum.UserInputType.MouseButton2 then
		Act.rowMenu(row)
		return
	end
	local w = UI.list.AbsoluteSize.X
	if row.kind == "joint" then
		local indent = 8 + (row.depth or 0) * 12
		if row.joint and #row.joint.children > 0 and m.X >= indent - 6 and m.X <= indent + 9 then
			S.collapsed[row.name] = (not S.collapsed[row.name]) or nil
			Draw.all()
			return
		end
		Act.selectJoint(row.name)
		if m.X >= w - 24 then Act.keyJoint(row.name) end
	elseif row.kind == "prop" then
		Act.selectProp(row.prop.folder)
		if m.X >= w - 24 then Act.keyProp(row.prop) end
	elseif row.kind == "summary" then
		Act.selectAll()
	elseif row.kind == "events" then
		Act.addMarker(U.round(S.frame))
	end
end

function Act.rowMenu(row)
	local items = {}
	if row.kind == "joint" then
		Act.selectJoint(row.name)
		table.insert(items, {title = row.name})
		table.insert(items, {text = "Key now  (K)", fn = function() Act.keyJoint(row.name) end})
		table.insert(items, {text = "Reset to rest pose", fn = Act.resetJoint})
		table.insert(items, {text = "Select its keys", fn = Act.selectRowKeys})
		table.insert(items, {text = "Delete its keys", fn = function()
			Act.selectRowKeys()
			Act.deleteSelected()
		end})
		table.insert(items, {sep = true})
		table.insert(items, {text = "Collapse all", fn = function()
			for _, j in ipairs(S.joints) do
				if #j.children > 0 then S.collapsed[j.name] = true end
			end
			Draw.all()
		end})
		table.insert(items, {text = "Expand all", fn = function()
			S.collapsed = {}
			Draw.all()
		end})
	elseif row.kind == "prop" then
		Act.selectProp(row.prop.folder)
		table.insert(items, {title = row.label})
		table.insert(items, {text = "Key current value  (K)", fn = function() Act.keyProp(row.prop) end})
		table.insert(items, {text = "Select its keys", fn = Act.selectRowKeys})
		table.insert(items, {text = "Remove track", fn = Act.removePropTrack})
	elseif row.kind == "events" then
		table.insert(items, {text = "Add event at the playhead", fn = function() Act.addMarker(U.round(S.frame)) end})
	else
		table.insert(items, {text = "Select every key  (Ctrl+A)", fn = Act.selectAll})
		table.insert(items, {text = "Key all joints  (Shift+K)", fn = Act.keyAll})
	end
	local p = UI.mouse()
	UI.openMenu(items, p.X, p.Y, 210)
end

function Act.rulerPress(input)
	if not S.proj then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if S.playing then Act.stop() end
		S.drag = {kind = "scrub"}
		UI.catcher.Visible = true
		Act.setFrame(Draw.xToFrame(Draw.mouseIn(UI.ruler).X))
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		local frame = math.max(0, U.round(Draw.xToFrame(Draw.mouseIn(UI.ruler).X)))
		local p = UI.mouse()
		UI.openMenu({
			{text = "Fit the whole animation", fn = function() Act.fitView() Draw.all() end},
			{text = "Make it end at frame " .. frame, disabled = frame < 1, fn = function() Act.setLength(tostring(frame)) end},
			{text = "Add event at frame " .. frame, fn = function() Act.addMarker(frame) end},
		}, p.X, p.Y, 220)
	end
end

function Act.wheel(input, area)
	if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
	local dz = input.Position.Z
	if dz == 0 then return end
	local ctrl = U.isDown(input, Enum.ModifierKey.Ctrl)
	local shift = U.isDown(input, Enum.ModifierKey.Shift)
	if area == "ruler" or (area == "keys" and ctrl) then
		local m = Draw.mouseIn(UI.keys)
		local f = Draw.xToFrame(m.X)
		local span = U.clamp((S.view.finish - S.view.start) * (dz > 0 and 0.8 or 1.25), 8, 40000)
		S.view.start = f - (m.X / Draw.width()) * span
		S.view.finish = S.view.start + span
		Draw.keys()
		Draw.ruler()
		Draw.playhead()
	elseif area == "keys" and shift then
		local d = -dz * (S.view.finish - S.view.start) * 0.12
		S.view.start += d
		S.view.finish += d
		Draw.keys()
		Draw.ruler()
		Draw.playhead()
	else
		S.scrollY -= dz * L.ROW * 3
		Draw.all()
	end
end

function Act.beginPan()
	S.drag = {kind = "pan", lastX = UI.mouse().X}
	UI.catcher.Visible = true
end

function Act.dragStep()
	local d = S.drag
	if not d then return end
	if d.kind == "keys" then
		Act.dragKeys(Draw.mouseIn(UI.keys))
	elseif d.kind == "box" then
		Act.dragBox(Draw.mouseIn(UI.keys))
	elseif d.kind == "scrub" then
		local f = U.clamp(U.round(Draw.xToFrame(Draw.mouseIn(UI.ruler).X)), 0, S.proj and S.proj.length or 0)
		if f ~= U.round(S.frame) then Act.setFrame(f) end
	elseif d.kind == "pan" then
		local x = UI.mouse().X
		local df = (x - d.lastX) / Draw.ppf()
		d.lastX = x
		if df ~= 0 then
			S.view.start -= df
			S.view.finish -= df
			Draw.keys()
			Draw.ruler()
			Draw.playhead()
		end
	end
end

function Act.endDrag()
	local d = S.drag
	S.drag = nil
	UI.catcher.Visible = false
	if not d then return end
	if d.kind == "keys" then
		Act.endKeyDrag(d)
	elseif d.kind == "box" then
		UI.boxSel.Visible = false
		Draw.all()
	end
end

-- ===== events =====
function Act.addMarker(frame)
	if not S.proj then return end
	local made
	Hist.run("Marrow: add event", function() made = Store.addMarker(math.max(0, frame), "Event", "") end, true)
	if made then
		S.sel = {[made] = true}
		Draw.all()
	end
end

function Act.editMarker(field, text)
	local list = Draw.selectedMarkers()
	if #list ~= 1 then return end
	local m = list[1]
	local value = text
	if field == "F" then
		value = tonumber(text)
		if not value then
			Draw.inspector()
			return
		end
		value = math.max(0, U.round(value))
	end
	if m.inst:GetAttribute(field) == value then return end
	Hist.run("Marrow: edit event", function() m.inst:SetAttribute(field, value) end, true)
end

-- ===== property and camera tracks =====
Act.PROPS = {
	{"BasePart", {"CFrame", "Transparency", "Color", "Size", "Reflectance"}},
	{"Model", {"Pivot"}},
	{"Light", {"Brightness", "Range", "Color", "Enabled"}},
	{"SpotLight", {"Angle"}},
	{"SurfaceLight", {"Angle"}},
	{"Camera", {"CFrame", "FieldOfView"}},
	{"GuiObject", {"Position", "Size", "Rotation", "BackgroundTransparency", "BackgroundColor3", "Visible"}},
	{"TextLabel", {"TextTransparency", "TextColor3", "TextStrokeTransparency"}},
	{"TextButton", {"TextTransparency", "TextColor3"}},
	{"ImageLabel", {"ImageTransparency", "ImageColor3"}},
	{"ImageButton", {"ImageTransparency", "ImageColor3"}},
	{"Sound", {"Volume", "PlaybackSpeed"}},
	{"ParticleEmitter", {"Rate", "Enabled", "TimeScale"}},
	{"Beam", {"Width0", "Width1", "Enabled"}},
	{"Trail", {"Enabled"}},
	{"Decal", {"Transparency", "Color3"}},
	{"Highlight", {"FillTransparency", "OutlineTransparency", "FillColor", "OutlineColor", "Enabled"}},
	{"Atmosphere", {"Density", "Haze", "Glare", "Color", "Decay"}},
	{"BloomEffect", {"Intensity", "Size", "Threshold"}},
	{"BlurEffect", {"Size"}},
	{"ColorCorrectionEffect", {"Brightness", "Contrast", "Saturation", "TintColor"}},
	{"DepthOfFieldEffect", {"FarIntensity", "NearIntensity", "FocusDistance", "InFocusRadius"}},
	{"SunRaysEffect", {"Intensity", "Spread"}},
	{"Lighting", {"ClockTime", "Brightness", "ExposureCompensation", "FogEnd", "FogStart", "Ambient", "OutdoorAmbient"}},
	{"ValueBase", {"Value"}},
	{"Attachment", {"CFrame"}},
	{"Motor6D", {"C0", "C1"}},
	{"Weld", {"C0", "C1"}},
}

function Act.addPropertyMenu()
	if not S.proj then
		Act.status("Open an animation first", true)
		return
	end
	local target = Svc.Selection:Get()[1]
	if not target then
		Act.status("Select the object in the Explorer first, then press + Property", true)
		return
	end
	local items = {{title = target.Name .. "  (" .. target.ClassName .. ")"}}
	local seen = {}
	for _, entry in ipairs(Act.PROPS) do
		if target:IsA(entry[1]) then
			for _, prop in ipairs(entry[2]) do
				if not seen[prop] then
					seen[prop] = true
					local ok, value = pcall(Anim.getProp, target, prop)
					local kind = ok and U.valueKind(value)
					if kind then
						table.insert(items, {text = prop .. "   (" .. kind .. ")", fn = function() Act.addPropTrack(target, prop, false) end})
					end
				end
			end
		end
	end
	if target:IsA("ParticleEmitter") then
		table.insert(items, {text = "Emit   (a burst of particles)", fn = function() Act.addActionTrack(target, "emit") end})
	elseif target:IsA("Sound") then
		table.insert(items, {text = "Play   (the sound starts)", fn = function() Act.addActionTrack(target, "play") end})
	end
	table.insert(items, {sep = true})
	table.insert(items, {text = "Another property...", fn = function()
		UI.dialog("Property track", "Type the property name exactly as the Properties window shows it.",
			{{label = "Property", default = ""}}, function(v) Act.addPropTrack(target, v[1], false) end, "Add")
	end})
	local p = UI.mouse()
	UI.openMenu(items, p.X - 120, p.Y, 240)
end

function Act.addPropTrack(target, prop, isCamera)
	if not S.proj or not target then return end
	prop = tostring(prop or ""):gsub("%s", "")
	local ok, value = pcall(Anim.getProp, target, prop)
	if not ok then
		Act.status(("%s has no property called %s"):format(target.Name, prop), true)
		return
	end
	local kind = U.valueKind(value)
	if not kind then
		Act.status(prop .. " can't be animated (" .. typeof(value) .. ")", true)
		return
	end
	for _, pt in ipairs(S.proj.props) do
		if pt.property == prop and ((isCamera and pt.isCamera) or (not isCamera and pt.target == target)) then
			Act.selectProp(pt.folder)
			Act.status("That track is already there")
			return
		end
	end
	local frame = U.round(S.frame)
	local folder
	Hist.run("Marrow: add property track", function()
		local props = Store.child(S.proj.folder, "Props")
		folder = U.new("Folder", {Name = string.format("P%03d", #props:GetChildren() + 1)})
		folder:SetAttribute("Property", prop)
		folder:SetAttribute("Kind", kind)
		if isCamera then folder:SetAttribute("IsCamera", true) end
		U.new("ObjectValue", {Name = "Target", Value = (not isCamera) and target or nil, Parent = folder})
		local k = U.new("Configuration", {Name = "K"})
		k:SetAttribute("F", frame)
		k:SetAttribute("V", value)
		k:SetAttribute("S", S.proj.defStyle)
		k:SetAttribute("D", S.proj.defDir)
		k.Parent = folder
		folder.Parent = props
	end, true)
	if folder then Act.selectProp(folder) end
	Act.status("Added " .. prop .. " with a key at frame " .. frame .. ".  Change the value, move the playhead, press K.")
end

function Act.addCameraTracks()
	if not S.proj then
		Act.status("Open an animation first", true)
		return
	end
	local cam = workspace.CurrentCamera
	Act.addPropTrack(cam, "CFrame", true)
	Act.addPropTrack(cam, "FieldOfView", true)
	Act.status("Camera tracks added. Fly the view where you want it, select a camera row and press K. Camera button = look through it.")
end

function Act.removePropTrack()
	local pt = Draw.selectedProp()
	if not pt then return end
	local target = pt.isCamera and workspace.CurrentCamera or pt.target
	local orig = target and S.propOriginal[target]
	if orig and orig[pt.property] ~= nil then
		pcall(function()
			if pt.property == "Pivot" then target:PivotTo(orig[pt.property]) else target[pt.property] = orig[pt.property] end
		end)
		orig[pt.property] = nil
	end
	S.selPropFolder = nil
	local folder = pt.folder
	Hist.run("Marrow: remove property track", function() folder.Parent = nil end, true)
end

function Act.typePropValue(text)
	local pt = Draw.selectedProp()
	if not pt then return end
	local value = U.parseValue(text, pt.kind)
	if value == nil then
		Draw.inspector()
		return
	end
	local current = Anim.sampleValue(pt.keys, S.frame, pt.kind)
	if current ~= nil and U.valueText(current) == U.valueText(value) then return end
	local frame = U.round(S.frame)
	Hist.run("Marrow: key " .. pt.property, function() Store.setPropKey(pt, frame, value) end, true)
end

-- ===== the animation's settings =====
function Act.setFps(text)
	local fps = math.floor(tonumber(text) or 0)
	if not S.proj or fps < 1 or fps > 240 or fps == S.proj.fps then
		Draw.inspector()
		return
	end
	local ratio = fps / S.proj.fps
	local folder = S.proj.folder
	local length = S.proj.length
	Hist.run("Marrow: FPS " .. fps, function()
		for _, d in ipairs(folder:GetDescendants()) do
			local f = d:GetAttribute("F")
			if f then d:SetAttribute("F", U.round(f * ratio)) end
		end
		folder:SetAttribute("Length", math.max(1, U.round(length * ratio)))
		folder:SetAttribute("Fps", fps)
		local joints = folder:FindFirstChild("Joints")
		for _, tf in ipairs(joints and joints:GetChildren() or {}) do Store.resolveCollisions(tf, {}) end
		local props = folder:FindFirstChild("Props")
		for _, pf in ipairs(props and props:GetChildren() or {}) do Store.resolveCollisions(pf, {}) end
	end)
	S.frame = U.round(S.frame * ratio)
	Act.fitView()
	Act.reload()
end

-- "90" = 90 frames, "2s" = two seconds
function Act.setLength(text)
	if not S.proj then return end
	local s = tostring(text):lower()
	local n = tonumber(s:match("[%d%.]+") or "")
	if not n then
		Draw.inspector()
		return
	end
	if s:find("s") then n = n * S.proj.fps end
	n = U.clamp(U.round(n), 1, 36000)
	if n == S.proj.length then return end
	Hist.run("Marrow: length " .. n, function() Store.setAttr("Length", n) end)
	Act.fitView()
	Draw.all()
end

function Act.toggleProjectLoop()
	if not S.proj then return end
	local v = not S.proj.loop
	Hist.run("Marrow: loop", function() Store.setAttr("Loop", v) end, true)
end

function Act.priorityMenu(b)
	local items = {}
	for _, p in ipairs({"Core", "Idle", "Movement", "Action", "Action2", "Action3", "Action4"}) do
		table.insert(items, {text = p, checked = S.proj and S.proj.priority == p, fn = function()
			Hist.run("Marrow: priority " .. p, function() Store.setAttr("Priority", p) end, true)
		end})
	end
	UI.menuAt(b, items, 130)
end

function Act.defaultStyleMenu(b)
	local items = {}
	for _, s in ipairs(Ease.STYLES) do
		table.insert(items, {text = s, checked = S.proj and S.proj.defStyle == s, fn = function()
			Hist.run("Marrow: default easing", function() Store.setAttr("DefaultStyle", s) end, true)
		end})
	end
	UI.menuAt(b, items, 140)
end

function Act.defaultDirMenu(b)
	local items = {}
	for _, d in ipairs(Ease.DIRS) do
		table.insert(items, {text = d, checked = S.proj and S.proj.defDir == d, fn = function()
			Hist.run("Marrow: default easing", function() Store.setAttr("DefaultDir", d) end, true)
		end})
	end
	UI.menuAt(b, items, 110)
end

-- ===== tools =====
function Act.toolsMenu(b)
	local has = S.proj ~= nil
	UI.menuAt(b, {
		{text = "Key all joints  (Shift+K)", disabled = not S.rig, fn = Act.keyAll},
		{text = "Select every key  (Ctrl+A)", disabled = not has, fn = Act.selectAll},
		{text = "Close the loop (frame 0 pose at the end)", disabled = not has, fn = Act.closeLoop},
		{text = "Simplify keys (remove keys that change nothing)", disabled = not has, fn = Act.simplifyKeys},
		{sep = true},
		{text = "Save the pose to the library...", disabled = not S.rig, fn = Act.savePoseDialog},
		{text = "Apply a pose from the library...", disabled = not S.rig, fn = function() Act.poseLibraryMenu(b) end},
		{sep = true},
		{text = "Insert frames at the playhead...", disabled = not has, fn = function() Act.timeDialog(true) end},
		{text = "Remove frames at the playhead...", disabled = not has, fn = function() Act.timeDialog(false) end},
		{text = "Fit the timeline", disabled = not has, fn = function() Act.fitView() Draw.all() end},
		{sep = true},
		{text = "Delete every key...", disabled = not has, fn = Act.clearAll},
		{text = "Release the rig (rest pose)", disabled = not S.rig, fn = Act.releaseRig},
	}, 330)
end

function Act.closeLoop()
	if not S.proj then return end
	local length = S.proj.length
	local joints, props = {}, {}
	for name, tr in pairs(S.proj.tracks) do
		if #tr.keys > 0 then joints[name] = Anim.sample(tr.keys, 0) end
	end
	for _, pt in ipairs(S.proj.props) do
		if #pt.keys > 0 then table.insert(props, {pt = pt, value = Anim.sampleValue(pt.keys, 0, pt.kind)}) end
	end
	Hist.run("Marrow: close the loop", function()
		for name, cf in pairs(joints) do Store.setJointKey(name, length, cf) end
		for _, e in ipairs(props) do Store.setPropKey(e.pt, length, e.value) end
		Store.setAttr("Loop", true)
	end, true)
	Act.status("The last frame now matches the first, and the animation loops")
end

function Act.timeDialog(insert)
	if not S.proj then return end
	local at = U.round(S.frame)
	UI.dialog(insert and "Insert frames" or "Remove frames",
		insert and ("Keys from frame " .. at .. " on move later; the animation gets longer.")
			or ("Keys from frame " .. at .. " on in this many frames are deleted; later keys move back."),
		{{label = "Frames", default = "10"}}, function(v)
			local n = math.floor(tonumber(v[1]) or 0)
			if n <= 0 then return end
			local folder = S.proj.folder
			local length = S.proj.length
			Hist.run(insert and "Marrow: insert frames" or "Marrow: remove frames", function()
				for _, d in ipairs(folder:GetDescendants()) do
					local f = d:GetAttribute("F")
					if f then
						if insert then
							if f >= at then d:SetAttribute("F", f + n) end
						elseif f >= at and f < at + n then
							d.Parent = nil
						elseif f >= at + n then
							d:SetAttribute("F", f - n)
						end
					end
				end
				folder:SetAttribute("Length", math.max(1, insert and (length + n) or (length - n)))
			end)
			Act.fitView()
			Draw.all()
		end, insert and "Insert" or "Remove")
end

function Act.clearAll()
	if not S.proj then return end
	local folder = S.proj.folder
	UI.confirm("Delete every key?", "Joints, properties and events of " .. folder.Name .. ". Undo brings them back.", function()
		S.sel = {}
		Hist.run("Marrow: delete every key", function()
			for _, d in ipairs(folder:GetDescendants()) do
				if d:GetAttribute("F") ~= nil then d.Parent = nil end
			end
		end)
	end, "Delete all")
end

-- ===== modes and toggles =====
function Act.setPoseMode(on)
	if on then
		if not S.rig and not Act.hasItems() then
			Act.status("Add a rig (Add > Rig) or an item (Add > Item) first", true)
			return
		end
		if S.playing then Act.stop() end
		S.poseMode = true
		pcall(function() plugin:Activate(true) end)
		Gizmo.mouse = Gizmo.mouse or plugin:GetMouse()
		pcall(function() Gizmo.mouse.TargetFilter = View.folderNow() end)
		pcall(function() Svc.Selection:Set({}) end)
		Act.status("POSE: click a body part, drag the rings to turn it or the arrows to move it.  R / G / L / K / Space")
	else
		local was = S.poseMode
		S.poseMode = false
		if was then pcall(function() plugin:Deactivate() end) end
		if Gizmo.hoverBox then Gizmo.hoverBox.Visible = false end
	end
	Draw.toolbar()
	Gizmo.place()
end

function Act.togglePoseMode()
	Act.setPoseMode(not S.poseMode)
end

function Act.setTool(tool)
	S.tool = tool
	Act.saveSetting("tool", tool)
	if not S.poseMode and (S.rig or Act.hasItems()) then Act.setPoseMode(true) end
	Draw.toolbar()
	Gizmo.place()
end

function Act.toggleSpace()
	S.space = (S.space == "world") and "local" or "world"
	Act.saveSetting("space", S.space)
	Draw.toolbar()
	Gizmo.place()
end

function Act.snapMenu(b)
	local items = {{text = S.snapOn and "Snapping on  (N)" or "Snapping off  (N)", checked = S.snapOn, fn = Act.toggleSnap}, {title = "Rotation step"}}
	for _, v in ipairs({1, 5, 10, 15, 22.5, 30, 45, 90}) do
		table.insert(items, {text = U.fmt(v, 1) .. " degrees", checked = S.snapRot == v, fn = function()
			S.snapRot = v
			S.snapOn = true
			Act.saveSetting("snapRot", v)
			Act.saveSetting("snapOn", true)
			Draw.toolbar()
		end})
	end
	table.insert(items, {title = "Move step"})
	for _, v in ipairs({0.01, 0.05, 0.1, 0.25, 0.5, 1}) do
		table.insert(items, {text = U.fmt(v, 2) .. " studs", checked = S.snapMove == v, fn = function()
			S.snapMove = v
			S.snapOn = true
			Act.saveSetting("snapMove", v)
			Act.saveSetting("snapOn", true)
			Draw.toolbar()
		end})
	end
	UI.menuAt(b, items, 170)
end

function Act.toggleSnap()
	S.snapOn = not S.snapOn
	Act.saveSetting("snapOn", S.snapOn)
	Draw.toolbar()
end

function Act.toggleAutoKey()
	S.autoKey = not S.autoKey
	Act.saveSetting("autoKey", S.autoKey)
	Draw.toolbar()
end

function Act.toggleOnion()
	S.onion = not S.onion
	Act.saveSetting("onion", S.onion)
	Draw.toolbar()
	View.refresh(true)
end

function Act.togglePath()
	S.path = not S.path
	Act.saveSetting("path", S.path)
	Draw.toolbar()
	View.refresh(true)
end

function Act.toggleCamera()
	S.camPreview = not S.camPreview
	if S.camPreview then
		Anim.applyProps(S.frame)
		Act.status("Looking through the animated camera. Switch it off to fly the view freely again.")
	else
		Anim.restoreProps(true)
	end
	Draw.toolbar()
	Draw.inspector()
end

function Act.help()
	local layer = UI.dialogLayer
	for _, c in ipairs(layer:GetChildren()) do c:Destroy() end
	local panel = U.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -60, 1, -40),
		BackgroundColor3 = T.panel, BorderSizePixel = 0, ZIndex = 301, Parent = layer}, {U.corner(6), U.stroke(T.line)})
	UI.label(panel, "MARROW ANIMATOR " .. VERSION, 14, 10, 400, 22, T.bone, T.bold, 15)
	local scroll = U.new("ScrollingFrame", {Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 1, -84), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel})
	U.new("TextLabel", {Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = T.font,
		TextSize = 13, TextColor3 = T.text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Text = table.concat({
			"START:  select a character (anything with Motor6D) and Add > Rig, or any part / model and Add > Item.",
			"POSE:  press POSE (P), click a body part or an item in the viewport, drag the rings to turn it (R) or the arrows to move it (G).",
			"EFFECTS:  select a part (or click it in POSE), Effects > Fire / Smoke / Sparks / Blood / Explosion / Light flash / Sound.",
			"    They are keyed at the playhead: drag their keys to retime them. Add > Hold item in hand welds a tool to a hand.",
			"PUBLISH:  the red Publish button exports the animation and opens the Roblox upload window.",
			"    L switches local / world axes, N switches snapping. With Auto-key on every change is keyed at the playhead.",
			"",
			"KEYS:  work in this window (click the timeline first) and in the 3D view while POSE is on.",
			"    Space  play / stop          K  key the selected joint or property          Shift+K  key every joint",
			"    ,  .  previous / next frame          [  ]  previous / next key          Home / End  first / last frame",
			"    Delete  delete the selected keys          Ctrl+C / Ctrl+V  copy / paste keys (or the whole pose)",
			"    Ctrl+A  select every key   M  mirror the pose   O  onion skin   T  motion path   F  fit the timeline",
			"    Esc  clear the key selection / leave POSE.   Ctrl+C / Ctrl+V / Ctrl+A only work inside this window.",
			"    Your own keys: Customize Shortcuts in the File menu (or File > Advanced), search 'Marrow'.",
			"",
			"TIMELINE:  click a key to select it, Shift+click to add, drag an empty area to box select.",
			"    Drag keys to move them in time, Ctrl+drag (or Alt+drag) copies them. Double-click a row to add a key,",
			"    double-click a key to jump to it. Right-click anywhere for more. The All keys row moves whole poses.",
			"    Ctrl+wheel (or wheel over the frame numbers) zooms, Shift+wheel or the middle mouse button pans.",
			"",
			"EASING:  every key has an easing style and direction for the motion that leaves it. Pick them in the",
			"    inspector, or use the presets. Hold = the pose snaps to the next key. Exports bake the curves, so the",
			"    game plays them exactly as the preview.",
			"",
			"PROPERTIES & CAMERA:  select any object in the Explorer and press + Property (lights, parts, models,",
			"    GUI, sounds, effects, Lighting...). + Camera adds the view position and field of view. Change the value,",
			"    move the playhead, press K. Export > Cutscene ModuleScript gives you a script that plays them in game:",
			"        require(path.to.module).Play()",
			"",
			"EVENTS:  double-click the Events row. They become KeyframeMarkers: track:GetMarkerReachedSignal(name).",
			"",
			"EXPORT:  Export > KeyframeSequence saves to ServerStorage > RBX_ANIMSAVES > <rig>. Publish uploads it.",
			"    Import takes a selected KeyframeSequence, a saved one, or any animation ID you can access.",
			"    Export > Cutscene ModuleScript also plays the joints (Motor6D.Transform), no upload needed.",
			"",
			"TOOLS:  Simplify keys cleans up baked / imported animations. The pose library keeps poses between",
			"    animations (ServerStorage > MarrowAnimations > _PoseLibrary).",
			"",
			"Everything is stored in ServerStorage > MarrowAnimations and works with Undo / Redo (Ctrl+Z / Ctrl+Y).",
		}, "\n"), Parent = scroll})
	UI.button(panel, "Close", 0, 0, 90, 26, function()
		layer.Visible = false
		for _, c in ipairs(layer:GetChildren()) do c:Destroy() end
	end).Position = UDim2.new(1, -104, 1, -38)
	layer.Visible = true
end

-- ===================================================================================================
-- import / export
-- ===================================================================================================
function Act.importMenu(b)
	local items = {
		{text = "Selected KeyframeSequence / Animation", fn = IO.importSelected},
		{text = "Animation ID...", fn = IO.importIdDialog},
	}
	local saves = Svc.ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	local found = {}
	if saves then
		for _, d in ipairs(saves:GetDescendants()) do
			if d:IsA("KeyframeSequence") then
				table.insert(found, d)
				if #found >= 14 then break end
			end
		end
	end
	if #found > 0 then
		table.insert(items, {sep = true})
		table.insert(items, {title = "SAVED IN RBX_ANIMSAVES"})
		for _, ks in ipairs(found) do
			local owner = ks.Parent and ks.Parent ~= saves and ("   (" .. ks.Parent.Name .. ")") or ""
			table.insert(items, {text = ks.Name .. owner, fn = function() IO.importSequence(ks) end})
		end
	end
	if b then
		UI.menuAt(b, items, 300)
	else
		local p = UI.mouse()
		UI.openMenu(items, p.X, p.Y, 300)
	end
end

function Act.exportMenu(b)
	local has = S.proj ~= nil
	local items = {
		{text = "KeyframeSequence  (ServerStorage > RBX_ANIMSAVES)", disabled = not has, fn = IO.exportKeyframeSequence},
		{text = "Publish to Roblox...", disabled = not has, fn = IO.publish},
		{sep = true},
		{text = "Cutscene ModuleScript  (joints, properties, camera, events)", disabled = not has, fn = IO.exportCutscene},
	}
	if b then
		UI.menuAt(b, items, 380)
	else
		local p = UI.mouse()
		UI.openMenu(items, p.X, p.Y, 380)
	end
end

-- the key a frame belongs to: keys[i].frame <= f < keys[i + 1].frame (nil before the first and from the last key on)
local function segmentStart(keys, f)
	local n = #keys
	if n < 2 or f < keys[1].frame or f >= keys[n].frame then return nil end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if keys[mid].frame <= f then lo = mid else hi = mid end
	end
	return keys[lo]
end

-- KeyframeSequence with the curves baked: Linear stretches stay as they are, eased stretches get a keyframe on
-- every frame, Hold stretches use the engine's Constant easing. Plays exactly like the preview.
function IO.buildSequence()
	local proj = S.proj
	local length = proj.length
	local needed, animated, skipped = {}, 0, 0
	local used = {}
	for _, j in ipairs(S.joints) do
		local tr = proj.tracks[j.name]
		if tr and #tr.keys > 0 then
			animated += 1
			used[j.name] = true
			local cur = j
			while cur and not needed[cur] do
				needed[cur] = true
				cur = cur.parent
			end
		end
	end
	for name, tr in pairs(proj.tracks) do
		if #tr.keys > 0 and not used[name] then skipped += 1 end
	end
	if animated == 0 then return nil, "Nothing to export yet: key some joints first" end

	local frameSet = {[0] = true, [length] = true}
	for name in pairs(used) do
		local keys = proj.tracks[name].keys
		for i, k in ipairs(keys) do
			if k.frame >= 0 and k.frame <= length then frameSet[k.frame] = true end
			local nk = keys[i + 1]
			if nk and k.style ~= "Linear" and k.style ~= "Constant" then
				for f = math.max(k.frame + 1, 0), math.min(nk.frame - 1, length) do frameSet[f] = true end
			end
		end
	end
	local markers = {}
	for _, m in ipairs(proj.markers) do
		if m.frame >= 0 and m.frame <= length then
			frameSet[m.frame] = true
			table.insert(markers, m)
		end
	end
	local frames = {}
	for f in pairs(frameSet) do table.insert(frames, f) end
	table.sort(frames)

	local rootNeeded = {}
	for j in pairs(needed) do
		if S.rootSet[j.part0] then rootNeeded[j.part0] = true end
	end

	local ks = Instance.new("KeyframeSequence")
	ks.Name = proj.name
	ks.Loop = proj.loop
	pcall(function() ks.Priority = Enum.AnimationPriority[proj.priority] end)
	for _, f in ipairs(frames) do
		local kf = Instance.new("Keyframe")
		kf.Name = "Keyframe"
		kf.Time = f / proj.fps
		local poseOf = {}
		for _, r in ipairs(S.roots) do
			if rootNeeded[r] then
				local p = Instance.new("Pose")
				p.Name = r.Name
				p.CFrame = CFrame.identity
				p.Weight = 0
				p.Parent = kf
				poseOf[r] = p
			end
		end
		for _, j in ipairs(S.joints) do
			local parentPose = needed[j] and poseOf[j.part0]
			if parentPose then
				local p = Instance.new("Pose")
				p.Name = j.name
				local tr = used[j.name] and proj.tracks[j.name]
				if tr then
					p.CFrame = Anim.sample(tr.keys, f)
					p.Weight = 1
					local seg = segmentStart(tr.keys, f)
					p.EasingStyle = (seg and seg.style == "Constant") and Enum.PoseEasingStyle.Constant or Enum.PoseEasingStyle.Linear
				else
					p.CFrame = CFrame.identity
					p.Weight = 0
					p.EasingStyle = Enum.PoseEasingStyle.Linear
				end
				p.EasingDirection = Enum.PoseEasingDirection.In
				p.Parent = parentPose
				poseOf[j.part1] = p
			end
		end
		for _, m in ipairs(markers) do
			if m.frame == f then
				local km = Instance.new("KeyframeMarker")
				km.Name = m.name
				km.Value = tostring(m.value)
				local ok = pcall(function() kf:AddMarker(km) end)
				if not ok then km.Parent = kf end
			end
		end
		kf.Parent = ks
	end
	return ks, nil, #frames, skipped
end

function IO.exportKeyframeSequence()
	if not S.proj then return nil end
	if not S.rig then
		Act.status("Attach the rig first (select it, press Attach selected): the export needs its joint tree", true)
		return nil
	end
	local ks, err, count, skipped = IO.buildSequence()
	if not ks then
		Act.status(err, true)
		return nil
	end
	local rig = S.rig
	local ok = Hist.run("Marrow: export " .. ks.Name, function()
		local saves = Svc.ServerStorage:FindFirstChild("RBX_ANIMSAVES")
		if not saves then saves = U.new("Model", {Name = "RBX_ANIMSAVES", Parent = Svc.ServerStorage}) end
		local holder
		for _, c in ipairs(saves:GetChildren()) do
			if c:IsA("ObjectValue") and c.Value == rig then holder = c break end
		end
		if not holder then holder = U.new("ObjectValue", {Name = rig.Name, Value = rig, Parent = saves}) end
		local old = holder:FindFirstChild(ks.Name)
		if old and old:IsA("KeyframeSequence") then old.Parent = nil end
		ks.Parent = holder
	end, true)
	if not ok then return nil end
	pcall(function() Svc.Selection:Set({ks}) end)
	local notes = {}
	if skipped and skipped > 0 then table.insert(notes, skipped .. " tracks skipped (joints the rig doesn't have)") end
	if next(S.pending) then table.insert(notes, "unkeyed pose changes are not in it") end
	Act.status(("Exported %s: %d keyframes, %s s  ->  ServerStorage.RBX_ANIMSAVES.%s%s"):format(ks.Name, count,
		U.fmt(S.proj.length / S.proj.fps, 2), rig.Name, #notes > 0 and ("   (" .. table.concat(notes, "; ") .. ")") or ""))
	return ks
end

function IO.publish()
	local ks = IO.exportKeyframeSequence()
	if not ks then return end
	pcall(function() Svc.Selection:Set({ks}) end)
	local ok = pcall(function() plugin:SaveSelectedToRoblox() end)
	if ok then
		Act.status("Upload window opened for " .. ks.Name .. ". After upload, copy the ID into an Animation object.")
	else
		Act.status("Exported " .. ks.Name .. ". To upload it: right-click it in the Explorer > Save to Roblox", true)
	end
end

-- ===== import =====
local IMPORT_STYLE = {Linear = "Linear", Constant = "Constant", CubicV2 = "Cubic", Cubic = "Cubic", Elastic = "Elastic", Bounce = "Bounce"}
-- the old Cubic / Elastic / Bounce pose easings run the other way round (their "In" is the usual "Out")
local IMPORT_FLIP = {Cubic = true, Elastic = true, Bounce = true}

function IO.importSequence(ks, label)
	if not ks or not ks:IsA("KeyframeSequence") then
		Act.status("That is not a KeyframeSequence", true)
		return
	end
	local rig = S.rig or (S.proj and S.proj.rig) or Rig.fromSelection()
	-- sequences saved in RBX_ANIMSAVES sit under an ObjectValue that points at their rig
	local holder = ks.Parent
	if not rig and holder and holder:IsA("ObjectValue") and typeof(holder.Value) == "Instance" and Rig.isRig(holder.Value) then
		rig = holder.Value
	end
	local fps = (S.proj and S.proj.fps) or 60
	local skip = {}
	if rig then
		local _, roots = Rig.collect(rig)
		for _, r in ipairs(roots) do skip[r.Name] = true end
	end
	local tracks, markers, maxFrame, poses = {}, {}, 1, 0
	local function walk(parent, frame, top)
		for _, p in ipairs(parent:GetChildren()) do
			if p:IsA("Pose") then
				if not top and p.Weight > 0 and not skip[p.Name] then
					local sName, dName = p.EasingStyle.Name, p.EasingDirection.Name
					if IMPORT_FLIP[sName] then
						if dName == "In" then dName = "Out" elseif dName == "Out" then dName = "In" end
					end
					tracks[p.Name] = tracks[p.Name] or {}
					tracks[p.Name][frame] = {cf = p.CFrame, style = IMPORT_STYLE[sName] or "Linear", dir = dName}
					poses += 1
				end
				walk(p, frame, false)
			end
		end
	end
	for _, kf in ipairs(ks:GetChildren()) do
		if kf:IsA("Keyframe") then
			local frame = math.max(0, U.round(kf.Time * fps))
			maxFrame = math.max(maxFrame, frame)
			walk(kf, frame, true)
			local ok, list = pcall(function() return kf:GetMarkers() end)
			if ok then
				for _, m in ipairs(list) do table.insert(markers, {frame = frame, name = m.Name, value = m.Value}) end
			end
		end
	end
	if poses == 0 then
		Act.status("That KeyframeSequence has no poses to import", true)
		return
	end
	local name = Store.uniqueName(label or ks.Name)
	local folder
	Hist.run("Marrow: import " .. name, function()
		folder = Store.create(name, rig)
		folder:SetAttribute("Fps", fps)
		folder:SetAttribute("Length", maxFrame)
		folder:SetAttribute("Loop", ks.Loop)
		folder:SetAttribute("Priority", ks.Priority.Name)
		local joints = Store.child(folder, "Joints")
		for jointName, frames in pairs(tracks) do
			local tf = Store.child(joints, jointName)
			for frame, k in pairs(frames) do
				local v = U.new("CFrameValue", {Name = "K", Value = k.cf})
				v:SetAttribute("F", frame)
				v:SetAttribute("S", k.style)
				v:SetAttribute("D", k.dir)
				v.Parent = tf
			end
		end
		local mf = Store.child(folder, "Markers")
		for _, m in ipairs(markers) do
			local c = U.new("Configuration", {Name = "M"})
			c:SetAttribute("F", m.frame)
			c:SetAttribute("Name", m.name)
			c:SetAttribute("Value", m.value)
			c.Parent = mf
		end
	end)
	if folder then
		Act.openProject(folder)
		Act.status(("Imported %s: %d poses, %d events. Tools > Simplify keys cleans up baked animations."):format(name, poses, #markers))
	end
end

function IO.importSelected()
	for _, obj in ipairs(Svc.Selection:Get()) do
		if obj:IsA("KeyframeSequence") then
			IO.importSequence(obj)
			return
		elseif obj:IsA("Animation") and obj.AnimationId ~= "" then
			IO.importId(obj.AnimationId, obj.Name)
			return
		end
	end
	Act.status("Select a KeyframeSequence (or an Animation object) in the Explorer first", true)
end

function IO.importIdDialog()
	UI.dialog("Import an animation ID", "Works for animations you (or your group) own. Paste the number or the whole link.",
		{{label = "Animation ID", default = ""}}, function(v) IO.importId(v[1]) end, "Import")
end

function IO.importId(text, label)
	local id = tostring(text or ""):match("%d%d%d+")
	if not id then
		Act.status("That doesn't look like an animation ID", true)
		return
	end
	Act.status("Loading animation " .. id .. "...")
	task.spawn(function()
		local ok, ks = pcall(function() return Svc.KSP:GetKeyframeSequenceAsync("rbxassetid://" .. id) end)
		if not ok or typeof(ks) ~= "Instance" then
			Act.status("Couldn't load " .. id .. ": " .. tostring(ks), true)
			return
		end
		UI.safe(function() IO.importSequence(ks, label or ("Animation " .. id)) end)()
	end)
end

-- ===== cutscene ModuleScript =====
IO.RUNTIME = [==[
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Cutscene = {Data = DATA, Name = DATA.name, Length = DATA.length / DATA.fps}

local STYLES = {}
for _, s in ipairs({"Sine", "Quad", "Cubic", "Quart", "Quint", "Exponential", "Circular", "Back", "Bounce", "Elastic"}) do
	STYLES[s] = Enum.EasingStyle[s]
end
local DIRS = {In = Enum.EasingDirection.In, Out = Enum.EasingDirection.Out, InOut = Enum.EasingDirection.InOut}
local ACTIONS = {emit = true, play = true}

local function ease(t, style, dir)
	if style == "Constant" then return 0 end
	local es = STYLES[style]
	if not es then return t end
	return TweenService:GetValue(t, es, DIRS[dir] or Enum.EasingDirection.InOut)
end

local function blend(a, b, t)
	if t == 0 then return a elseif t == 1 then return b end
	local axis, angle = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
	if angle > math.pi then angle -= 2 * math.pi end
	local rot = a.Rotation
	if angle == angle and math.abs(angle) > 1e-7 and axis.Magnitude > 0.5 then
		rot = a.Rotation * CFrame.fromAxisAngle(axis, angle * t)
	end
	return CFrame.new(a.Position + (b.Position - a.Position) * t) * rot
end

local function lerp(a, b, t, kind)
	if typeof(a) ~= typeof(b) then return t < 1 and a or b end
	if kind == "number" or kind == "Vector3" or kind == "Vector2" then return a + (b - a) * t end
	if kind == "Color3" then return a:Lerp(b, math.clamp(t, 0, 1)) end
	if kind == "CFrame" then return blend(a, b, t) end
	if kind == "UDim2" then
		return UDim2.new(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t,
			a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)
	end
	if kind == "UDim" then return UDim.new(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t) end
	return t < 1 and a or b
end

-- keys: {{frame, value, style, direction}, ...} in frame order
local function sample(keys, frame, kind)
	local n = #keys
	if n == 0 then return nil end
	if frame <= keys[1][1] then return keys[1][2] end
	if frame >= keys[n][1] then return keys[n][2] end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if keys[mid][1] <= frame then lo = mid else hi = mid end
	end
	local a, b = keys[lo], keys[hi]
	if a[3] == "Constant" or kind == "boolean" then return a[2] end
	return lerp(a[2], b[2], ease((frame - a[1]) / (b[1] - a[1]), a[3], a[4]), kind)
end

-- objects are found by their path; things from StarterGui are looked up in the player's PlayerGui
local function find(path)
	if not path then return nil end
	local cur = game
	for i, name in ipairs(path) do
		local nextObj
		if i == 1 then
			if name == "StarterGui" and RunService:IsClient() and Players.LocalPlayer then
				nextObj = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
			else
				nextObj = game:FindFirstChild(name)
				if not nextObj then
					local ok, service = pcall(function() return game:GetService(name) end)
					if ok then nextObj = service end
				end
			end
		elseif i == 2 and path[1] == "StarterGui" then
			nextObj = cur:FindFirstChild(name) or cur:WaitForChild(name, 5)
		else
			nextObj = cur:FindFirstChild(name)
		end
		cur = nextObj
		if not cur then return nil end
	end
	return cur
end

--[[ options (all optional):
	Speed = 1            playback speed
	Loop = false         loop it (default: the animation's own Loop setting)
	Camera = true        false = leave the camera alone
	KeepCamera = false   true = leave the camera Scriptable when it ends
	Rig = model          play the joint tracks on this model instead of the one it was made with
	ResetJoints = false  true = put the joints back in their rest pose when it ends
  returns a handle: handle.MarkerReached (name, value), handle.Finished (completed), handle:Stop(), handle:Wait(), handle.Playing ]]
function Cutscene.Play(options)
	options = options or {}
	local data = Cutscene.Data
	local speed = options.Speed or 1
	local loop = options.Loop
	if loop == nil then loop = data.loop end
	local markerEvent, finishedEvent = Instance.new("BindableEvent"), Instance.new("BindableEvent")
	local handle = {MarkerReached = markerEvent.Event, Finished = finishedEvent.Event, Playing = true}

	local props, hasCamera = {}, false
	for _, tr in ipairs(data.tracks) do
		local inst
		if tr.camera then
			if options.Camera ~= false then inst = workspace.CurrentCamera end
		else
			inst = find(tr.path)
			if not inst then warn("[Cutscene " .. data.name .. "] can't find " .. table.concat(tr.path, ".")) end
		end
		if inst then
			table.insert(props, {inst = inst, track = tr})
			if tr.camera then hasCamera = true end
		end
	end
	local motors = {}
	local rig = options.Rig or (data.rig and find(data.rig))
	if rig and data.joints then
		for _, d in ipairs(rig:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part1 and data.joints[d.Part1.Name] then
				table.insert(motors, {motor = d, keys = data.joints[d.Part1.Name]})
			end
		end
	end
	local camera = workspace.CurrentCamera
	local oldCameraType
	if hasCamera and camera then
		oldCameraType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local frame = 0
	local function applyProps(f)
		for _, p in ipairs(props) do
			local v = not ACTIONS[p.track.kind] and sample(p.track.keys, f, p.track.kind) or nil
			if v ~= nil then
				pcall(function()
					if p.track.property == "Pivot" then p.inst:PivotTo(v) else p.inst[p.track.property] = v end
				end)
			end
		end
	end
	local function applyJoints(f)
		for _, m in ipairs(motors) do
			if m.motor.Parent then m.motor.Transform = sample(m.keys, f, "CFrame") end
		end
	end
	local function fireMarkers(from, to)
		for _, m in ipairs(data.markers) do
			if m[1] > from and m[1] <= to then markerEvent:Fire(m[2], m[3]) end
		end
		-- particle bursts and sounds
		for _, p in ipairs(props) do
			local kind = p.track.kind
			if ACTIONS[kind] then
				for _, k in ipairs(p.track.keys) do
					if k[1] > from and k[1] <= to then
						pcall(function()
							if kind == "emit" then p.inst:Emit(math.max(1, math.floor(tonumber(k[2]) or 20))) else p.inst:Play() end
						end)
					end
				end
			end
		end
	end

	local connections = {}
	local function finish(completed)
		if not handle.Playing then return end
		handle.Playing = false
		for _, c in ipairs(connections) do c:Disconnect() end
		if options.ResetJoints then
			for _, m in ipairs(motors) do m.motor.Transform = CFrame.identity end
		end
		if hasCamera and camera and not options.KeepCamera then camera.CameraType = oldCameraType or Enum.CameraType.Custom end
		finishedEvent:Fire(completed)
		task.delay(1, function()
			markerEvent:Destroy()
			finishedEvent:Destroy()
		end)
	end
	function handle:Stop() finish(false) end
	function handle:Wait()
		if handle.Playing then handle.Finished:Wait() end
	end

	applyProps(0)
	applyJoints(0)
	local clock = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat
	table.insert(connections, clock:Connect(function(dt)
		local before = frame
		frame += dt * data.fps * speed
		if frame >= data.length then
			fireMarkers(before, data.length)
			if loop then
				frame = frame % data.length
				fireMarkers(-1, frame)
			else
				frame = data.length
				applyProps(frame)
				applyJoints(frame)
				finish(true)
				return
			end
		else
			fireMarkers(before, frame)
		end
		applyProps(frame)
	end))
	if #motors > 0 then
		-- after the Animator has had its turn, so the cutscene wins
		table.insert(connections, RunService.Stepped:Connect(function() applyJoints(frame) end))
	end
	task.defer(fireMarkers, -1, 0)
	return handle
end

return Cutscene
]==]

function IO.exportCutscene()
	local proj = S.proj
	if not proj then return end
	local out = {}
	local function w(line) table.insert(out, line) end
	local function pathLiteral(inst)
		local parts = {}
		for _, name in ipairs(U.pathOf(inst)) do table.insert(parts, U.literal(name)) end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	local function keyLine(frame, value, style, dir)
		return ("\t\t\t{%s, %s, %s, %s},"):format(U.num(frame), U.literal(value), U.literal(style), U.literal(dir))
	end

	-- joints (played on the rig through Motor6D.Transform)
	local jointNames = {}
	for name, tr in pairs(proj.tracks) do
		if #tr.keys > 0 then table.insert(jointNames, name) end
	end
	table.sort(jointNames)
	local rig = proj.rig
	local rigOk = rig ~= nil and rig:IsDescendantOf(game)
	-- property and camera tracks
	local tracks, missing = {}, 0
	for _, pt in ipairs(proj.props) do
		if #pt.keys > 0 and pt.property ~= "" then
			if pt.isCamera or (pt.target and pt.target:IsDescendantOf(game)) then
				table.insert(tracks, pt)
			else
				missing += 1
			end
		end
	end
	if #tracks == 0 and #jointNames == 0 then
		Act.status("Nothing to export: key some joints, or add property / camera tracks", true)
		return
	end

	w("-- " .. proj.name .. "  -  made with Marrow Animator " .. VERSION)
	w("-- From a LocalScript (camera, GUI) or a Script:")
	w("--     local cutscene = require(game.ReplicatedStorage.MarrowCutscenes[" .. U.literal(proj.name) .. "])")
	w("--     local handle = cutscene.Play({Speed = 1})")
	w("--     handle.MarkerReached:Connect(function(name, value) print(name, value) end)")
	w("--     handle:Wait()      -- or handle:Stop()")
	w("-- Joint tracks drive Motor6D.Transform of the rig directly: no animation upload needed.")
	w("")
	w("local DATA = {")
	w("\tname = " .. U.literal(proj.name) .. ",")
	w(("\tfps = %s, length = %s, loop = %s,"):format(U.num(proj.fps), U.num(proj.length), tostring(proj.loop)))
	if #jointNames > 0 and rigOk then
		w("\trig = " .. pathLiteral(rig) .. ",")
	elseif #jointNames > 0 then
		w("\trig = nil, -- pass Play({Rig = model})")
	end
	w("\tjoints = {")
	for _, name in ipairs(jointNames) do
		w("\t\t[" .. U.literal(name) .. "] = {")
		for _, k in ipairs(proj.tracks[name].keys) do w(keyLine(k.frame, k.cf, k.style, k.dir)) end
		w("\t\t},")
	end
	w("\t},")
	w("\ttracks = {")
	for _, pt in ipairs(tracks) do
		local where = pt.isCamera and "camera = true" or ("path = " .. pathLiteral(pt.target))
		w(("\t\t{property = %s, kind = %s, %s, keys = {"):format(U.literal(pt.property), U.literal(pt.kind), where))
		for _, k in ipairs(pt.keys) do
			if k.value ~= nil then w(keyLine(k.frame, k.value, k.style, k.dir)) end
		end
		w("\t\t}},")
	end
	w("\t},")
	w("\tmarkers = {")
	for _, m in ipairs(proj.markers) do
		w(("\t\t{%s, %s, %s},"):format(U.num(m.frame), U.literal(tostring(m.name)), U.literal(tostring(m.value))))
	end
	w("\t},")
	w("}")
	w("")
	w(IO.RUNTIME)
	local source = table.concat(out, "\n")

	local module
	Hist.run("Marrow: export cutscene", function()
		local holder = Svc.ReplicatedStorage:FindFirstChild("MarrowCutscenes")
		if not holder then holder = U.new("Folder", {Name = "MarrowCutscenes", Parent = Svc.ReplicatedStorage}) end
		local old = holder:FindFirstChild(proj.name)
		if old and old:IsA("ModuleScript") then old.Parent = nil end
		module = U.new("ModuleScript", {Name = proj.name})
		module.Source = source
		module.Parent = holder
	end, true)
	if not module then return end
	pcall(function() Svc.Selection:Set({module}) end)
	local notes = {}
	if missing > 0 then table.insert(notes, missing .. " tracks skipped (their object is gone)") end
	if #jointNames > 0 and not rigOk then table.insert(notes, "no rig: pass Play({Rig = model})") end
	Act.status("Exported ReplicatedStorage.MarrowCutscenes." .. proj.name .. "  -  require(it).Play()"
		.. (#notes > 0 and ("   (" .. table.concat(notes, "; ") .. ")") or ""))
end

-- ===================================================================================================
-- tools: simplify keys, the pose library
-- ===================================================================================================
local function closeCF(a, b)
	return (a.Position - b.Position).Magnitude < 1e-4 and U.angleOf(a:ToObjectSpace(b)) < 1e-4
end

-- drop keys that change nothing: the curve through them is the same without them
function Act.simplifyKeys()
	if not S.proj then return end
	local remove = {}
	local count = 0
	for _, tr in pairs(S.proj.tracks) do
		local keys = tr.keys
		local n = #keys
		if n > 2 then
			local last = 1
			for i = 2, n - 1 do
				local a, b = keys[last], keys[i + 1]
				local same = closeCF(a.cf, b.cf)
				local fits = true
				for m = last + 1, i do
					local km = keys[m]
					if same then
						fits = closeCF(km.cf, a.cf)
					else
						fits = a.style == "Linear" and km.style == "Linear"
							and closeCF(U.blend(a.cf, b.cf, (km.frame - a.frame) / (b.frame - a.frame)), km.cf)
					end
					if not fits then break end
				end
				if fits then
					remove[keys[i].inst] = true
					count += 1
				else
					last = i
				end
			end
		end
	end
	if count == 0 then
		Act.status("Nothing to simplify: every key changes the motion")
		return
	end
	S.sel = {}
	Hist.run("Marrow: simplify keys", function()
		for inst in pairs(remove) do inst.Parent = nil end
	end, true)
	Act.status("Removed " .. count .. " keys that changed nothing")
end

function Act.poseLibrary(create)
	local root = Store.root(create)
	if not root then return nil end
	local lib = root:FindFirstChild("_PoseLibrary")
	if not lib and create then lib = U.new("Folder", {Name = "_PoseLibrary", Parent = root}) end
	return lib
end

function Act.savePoseDialog()
	if not S.rig then
		Act.status("Attach the rig first", true)
		return
	end
	UI.dialog("Save the pose", "The pose at the playhead goes to the library. It can be applied to any rig with the same joint names.",
		{{label = "Name", default = "Pose " .. U.round(S.frame)}}, function(v)
			local name = (v[1] or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if name == "" then return end
			local values = {}
			for _, j in ipairs(S.joints) do values[j.name] = Anim.jointT(j.name, S.frame) end
			Hist.run("Marrow: save pose " .. name, function()
				local lib = Act.poseLibrary(true)
				local old = lib:FindFirstChild(name)
				if old then old.Parent = nil end
				local f = U.new("Folder", {Name = name})
				for jointName, cf in pairs(values) do U.new("CFrameValue", {Name = jointName, Value = cf, Parent = f}) end
				f.Parent = lib
			end, true)
			Act.status("Saved the pose " .. name .. " (Tools > Apply a pose from the library)")
		end, "Save")
end

function Act.applyLibraryPose(folder)
	if not S.rig or not S.proj or not folder.Parent then return end
	local frame = U.round(S.frame)
	local values, count = {}, 0
	for _, v in ipairs(folder:GetChildren()) do
		if v:IsA("CFrameValue") and S.jointByName[v.Name] then
			values[v.Name] = v.Value
			count += 1
		end
	end
	if count == 0 then
		Act.status("None of the joints in " .. folder.Name .. " are in this rig", true)
		return
	end
	S.pending = {}
	Hist.run("Marrow: apply pose " .. folder.Name, function()
		for name, cf in pairs(values) do Store.setJointKey(name, frame, cf) end
	end, true)
	Act.status("Applied " .. folder.Name .. " to " .. count .. " joints at frame " .. frame)
end

function Act.poseLibraryMenu(b)
	local lib = Act.poseLibrary(false)
	local items = {}
	local list = lib and lib:GetChildren() or {}
	table.sort(list, function(x, y) return x.Name:lower() < y.Name:lower() end)
	if #list == 0 then table.insert(items, {title = "The library is empty: Tools > Save the pose"}) end
	for _, f in ipairs(list) do
		if f:IsA("Folder") then table.insert(items, {text = f.Name, fn = function() Act.applyLibraryPose(f) end}) end
	end
	if #list > 0 then
		table.insert(items, {sep = true})
		table.insert(items, {text = "Delete a pose...", fn = function()
			local del = {{title = "DELETE"}}
			for _, f in ipairs(list) do
				table.insert(del, {text = f.Name, fn = function()
					Hist.run("Marrow: delete pose", function() f.Parent = nil end, true)
				end})
			end
			local p = UI.mouse()
			UI.openMenu(del, p.X, p.Y, 220)
		end})
	end
	if b then
		UI.menuAt(b, items, 240)
	else
		local p = UI.mouse()
		UI.openMenu(items, p.X, p.Y, 240)
	end
end

-- ===================================================================================================
-- items: any part or model, animated by its pivot and posed with the same rings and arrows
-- ===================================================================================================
function Act.hasItems()
	if not S.proj then return false end
	for _, pt in ipairs(S.proj.props) do
		if pt.isItem then return true end
	end
	return false
end

-- a property track folder (call inside Hist.run)
function Store.newPropTrack(target, prop, kind, attrs)
	local props = Store.child(S.proj.folder, "Props")
	local i = #props:GetChildren() + 1
	while props:FindFirstChild(string.format("P%03d", i)) do i += 1 end
	local folder = U.new("Folder", {Name = string.format("P%03d", i)})
	folder:SetAttribute("Property", prop)
	folder:SetAttribute("Kind", kind)
	for k, v in pairs(attrs or {}) do folder:SetAttribute(k, v) end
	U.new("ObjectValue", {Name = "Target", Value = target, Parent = folder})
	folder.Parent = props
	return folder
end

-- no animation open yet: make one so a single click is enough
function Act.ensureProject(baseName)
	if S.proj then return true end
	local folder
	Hist.run("Marrow: new animation", function() folder = Store.create(Store.uniqueName(baseName .. " anim"), nil) end)
	if folder then Act.openProject(folder) end
	return S.proj ~= nil
end

function Act.addItemTrack(target)
	target = target or Svc.Selection:Get()[1]
	if not target or not (target:IsA("BasePart") or target:IsA("Model")) then
		Act.status("Select a part or a model (a sword, a door, a car...) first, then Add > Item", true)
		return
	end
	if S.rig and (target == S.rig or target:IsDescendantOf(S.rig)) then
		Act.status("That is part of the rig: pose it in POSE mode, or use Add > Hold item in hand", true)
		return
	end
	if not Act.ensureProject(target.Name) then return end
	for _, pt in ipairs(S.proj.props) do
		if pt.isItem and pt.target == target then
			Act.selectProp(pt.folder)
			Act.status(target.Name .. " is already on the timeline")
			return
		end
	end
	local ok, pivot = pcall(Anim.getProp, target, "Pivot")
	if not ok or typeof(pivot) ~= "CFrame" then
		Act.status("Can't move " .. target.Name, true)
		return
	end
	local frame = U.round(S.frame)
	local folder
	Hist.run("Marrow: add item " .. target.Name, function()
		-- an animated item must not fall: anchor its parts
		for _, p in ipairs(target:IsA("BasePart") and {target} or target:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
		folder = Store.newPropTrack(target, "Pivot", "CFrame", {IsItem = true})
		Store.setPropKey({folder = folder}, frame, pivot)
	end, true)
	if folder then
		Act.selectProp(folder)
		if not S.poseMode then Act.setPoseMode(true) end
		Act.selectProp(folder)
		Act.status("Added " .. target.Name .. ". Move the playhead, then turn / move it with the rings and arrows.")
	end
end

-- an item was moved with the gizmo
function Act.commitItem(pt, cf)
	local frame = U.round(S.frame)
	if S.autoKey or Act.keyAt(pt.keys, frame) then
		Hist.run("Marrow: move " .. (pt.target and pt.target.Name or "item"), function() Store.setPropKey(pt, frame, cf) end, true)
	else
		Gizmo.place()
		Act.status("Moved " .. pt.target.Name .. " but not keyed: press K (or turn Auto-key on)")
	end
end

-- weld an item to a body part with a Motor6D: it becomes a joint of the rig (tools, weapons) and goes into
-- the KeyframeSequence with the body
function Act.weldItem()
	if not S.proj or not S.rig then
		Act.status("Add the rig first (Add > Rig)", true)
		return
	end
	local rig = S.rig
	local body, item
	for _, o in ipairs(Svc.Selection:Get()) do
		if o:IsA("BasePart") and o:IsDescendantOf(rig) then
			body = body or o
		elseif (o:IsA("BasePart") or o:IsA("Model")) and o ~= rig and not o:IsDescendantOf(rig) then
			item = item or o
		end
	end
	if not body and S.selJoint and S.jointByName[S.selJoint] then body = S.jointByName[S.selJoint].part1 end
	if not item then
		local pt = Draw.selectedProp()
		if pt and pt.isItem then item = pt.target end
	end
	if not body or not item then
		Act.status("Select the body part (for example Right Arm) and the item: Ctrl+click both in the Explorer", true)
		return
	end
	local handle = item:IsA("BasePart") and item or item.PrimaryPart or item:FindFirstChild("Handle", true)
		or item:FindFirstChildWhichIsA("BasePart", true)
	if not handle then
		Act.status(item.Name .. " has no parts", true)
		return
	end
	Act.stop()
	Act.setPoseMode(false)
	S.pending = {}
	S.propOriginal[item] = nil
	Rig.unbind()
	local itemName, bodyName = item.Name, body.Name
	Hist.run("Marrow: hold " .. itemName, function()
		for _, pt in ipairs(S.proj.props) do
			if pt.isItem and pt.target == item then pt.folder.Parent = nil end
		end
		for _, p in ipairs(item:IsA("BasePart") and {item} or item:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.Massless = true
				p.CanCollide = false
				if p ~= handle then U.new("WeldConstraint", {Name = "MarrowWeld", Part0 = handle, Part1 = p, Parent = p}) end
			end
		end
		item.Parent = rig
		U.new("Motor6D", {Name = handle.Name, Part0 = body, Part1 = handle, C0 = body.CFrame:ToObjectSpace(handle.CFrame), Parent = body})
	end)
	Act.selectJoint(handle.Name)
	Act.status(("%s now hangs on %s as the joint %s: pose it like a body part. In the game your tool needs the same Motor6D.")
		:format(itemName, bodyName, handle.Name))
end

-- ===================================================================================================
-- effects: particles, light flashes and sounds, keyed on the timeline
-- ===================================================================================================
local function seq(a, b) return NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b)}) end
local function cseq(a, b) return ColorSequence.new(a, b) end
local TEX = {
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	spark = "rbxasset://textures/particles/sparkles_main.dds",
}

Act.EMITTERS = {
	Fire = function() return {Texture = TEX.fire, Color = cseq(Color3.fromRGB(255, 196, 96), Color3.fromRGB(255, 70, 24)),
		LightEmission = 1, Size = seq(1.4, 0.2), Transparency = seq(0.15, 1), Lifetime = NumberRange.new(0.35, 0.8),
		Speed = NumberRange.new(3, 6), Rate = 70, SpreadAngle = Vector2.new(12, 12), Acceleration = Vector3.new(0, 5, 0),
		RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360)} end,
	Smoke = function() return {Texture = TEX.smoke, Color = cseq(Color3.fromRGB(90, 88, 86), Color3.fromRGB(40, 40, 42)),
		Size = seq(1.2, 4.5), Transparency = seq(0.35, 1), Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(1.5, 3),
		Rate = 22, SpreadAngle = Vector2.new(20, 20), Acceleration = Vector3.new(0, 1.5, 0), RotSpeed = NumberRange.new(-30, 30),
		Rotation = NumberRange.new(0, 360)} end,
	Sparks = function() return {Texture = TEX.spark, Color = cseq(Color3.fromRGB(255, 236, 160), Color3.fromRGB(255, 120, 30)),
		LightEmission = 1, Size = seq(0.3, 0), Transparency = seq(0, 0.4), Lifetime = NumberRange.new(0.25, 0.6),
		Speed = NumberRange.new(14, 24), Rate = 0, SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -35, 0)} end,
	Magic = function() return {Texture = TEX.spark, Color = cseq(Color3.fromRGB(170, 120, 255), Color3.fromRGB(90, 220, 255)),
		LightEmission = 1, Size = seq(0.55, 0), Transparency = seq(0, 1), Lifetime = NumberRange.new(0.9, 1.6),
		Speed = NumberRange.new(1, 3), Rate = 35, SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 1, 0)} end,
	Blood = function() return {Texture = TEX.spark, Color = cseq(Color3.fromRGB(120, 6, 10), Color3.fromRGB(60, 0, 4)),
		LightEmission = 0, Size = seq(0.35, 0.12), Transparency = seq(0, 0.2), Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(8, 15), Rate = 0, SpreadAngle = Vector2.new(45, 45), Acceleration = Vector3.new(0, -45, 0)} end,
	Explosion = function() return {Texture = TEX.fire, Color = cseq(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 60, 10)),
		LightEmission = 1, Size = seq(2.5, 0.5), Transparency = seq(0, 1), Lifetime = NumberRange.new(0.3, 0.7),
		Speed = NumberRange.new(14, 26), Rate = 0, SpreadAngle = Vector2.new(180, 180), Drag = 4,
		RotSpeed = NumberRange.new(-180, 180), Rotation = NumberRange.new(0, 360)} end,
}

function Act.makeEmitter(parent, name, cfg)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in pairs(cfg) do pcall(function() e[k] = v end) end
	e.Enabled = false
	e.Parent = parent
	return e
end

-- where an effect goes: the part selected in Studio, else the selected joint's part or item
function Act.effectTarget()
	local sel = Svc.Selection:Get()[1]
	if sel and (sel:IsA("BasePart") or sel:IsA("Attachment")) then return sel end
	if sel and sel:IsA("Model") then return sel.PrimaryPart or sel:FindFirstChildWhichIsA("BasePart", true) end
	local j = S.selJoint and S.jointByName[S.selJoint]
	if j then return j.part1 end
	local pt = Draw.selectedProp()
	if pt and pt.isItem and pt.target then
		return pt.target:IsA("BasePart") and pt.target or pt.target.PrimaryPart or pt.target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function holderFor(target, name)
	if target:IsA("Attachment") then return target end
	return U.new("Attachment", {Name = "MarrowFX_" .. name, Parent = target})
end

-- a held effect: on at the playhead for a while
local function loopEffect(name, seconds)
	return function(target, frame)
		local e = Act.makeEmitter(holderFor(target, name), name, Act.EMITTERS[name]())
		local f = Store.newPropTrack(e, "Enabled", "boolean")
		if frame > 0 then Store.setPropKey({folder = f}, 0, false, "Constant", "InOut") end
		Store.setPropKey({folder = f}, frame, true, "Constant", "InOut")
		Store.setPropKey({folder = f}, frame + U.round(seconds * S.proj.fps), false, "Constant", "InOut")
		return f
	end
end

-- a burst: the particles fly out once when the playhead passes the key
local function burstEffect(name, count)
	return function(target, frame)
		local e = Act.makeEmitter(holderFor(target, name), name, Act.EMITTERS[name]())
		local f = Store.newPropTrack(e, "Emit", "emit")
		Store.setPropKey({folder = f}, frame, count, "Constant", "InOut")
		return f
	end
end

local function lightFlash(target, frame, peak, color)
	local light = U.new("PointLight", {Name = "MarrowFlash", Brightness = 0, Range = 16, Color = color or Color3.fromRGB(255, 190, 110),
		Shadows = true, Parent = holderFor(target, "Flash")})
	local f = Store.newPropTrack(light, "Brightness", "number")
	if frame > 0 then Store.setPropKey({folder = f}, math.max(0, frame - 1), 0, "Linear", "InOut") end
	Store.setPropKey({folder = f}, frame, 0, "Quad", "Out")
	Store.setPropKey({folder = f}, frame + 2, peak, "Quad", "Out")
	Store.setPropKey({folder = f}, frame + U.round(0.35 * S.proj.fps), 0, "Linear", "InOut")
	return f
end

Act.EFFECTS = {
	{"Fire", "Fire (2 s)", loopEffect("Fire", 2)},
	{"Smoke", "Smoke (3 s)", loopEffect("Smoke", 3)},
	{"Magic", "Magic dust (2 s)", loopEffect("Magic", 2)},
	{"Sparks", "Sparks (burst)", burstEffect("Sparks", 40)},
	{"Blood", "Blood splash (burst)", burstEffect("Blood", 30)},
	{"Explosion", "Explosion (burst + smoke + flash)", function(target, frame)
		local first = burstEffect("Explosion", 60)(target, frame)
		burstEffect("Smoke", 25)(target, frame)
		lightFlash(target, frame, 10)
		return first
	end},
	{"Flash", "Light flash", function(target, frame) return lightFlash(target, frame, 8) end},
}

-- a key past the end makes the animation longer (call inside Hist.run)
function Act.fitLengthToKeys()
	local last = S.proj.length
	for _, d in ipairs(S.proj.folder:GetDescendants()) do
		local f = d:GetAttribute("F")
		if f and f > last then last = f end
	end
	if last > S.proj.length then Store.setAttr("Length", last) end
end

function Act.addEffect(entry)
	local target = Act.effectTarget()
	if not target then
		Act.status("Select a part first (in the Explorer, or click a body part / item in POSE), then pick an effect", true)
		return
	end
	if not Act.ensureProject(target.Name) then return end
	local frame = U.round(S.frame)
	local made
	Hist.run("Marrow: effect " .. entry[1], function()
		made = entry[3](target, frame)
		Act.fitLengthToKeys()
	end, true)
	if made then
		Act.selectProp(made)
		Act.status(entry[2] .. " on " .. target.Name .. " at frame " .. frame .. ". Drag its keys to retime it; Space plays it.")
	end
end

function Act.addSoundDialog()
	local target = Act.effectTarget()
	if not target then
		Act.status("Select a part first, then Effects > Sound", true)
		return
	end
	UI.dialog("Sound", "Paste the sound ID (from the Toolbox or Creator Store). It plays when the playhead reaches the key.",
		{{label = "Sound ID", default = ""}, {label = "Volume", default = "0.8"}}, function(v)
			local id = tostring(v[1] or ""):match("%d%d%d+")
			if not id then
				Act.status("That doesn't look like a sound ID", true)
				return
			end
			if not Act.ensureProject(target.Name) then return end
			local frame = U.round(S.frame)
			local made
			Hist.run("Marrow: sound", function()
				local parent = target
				local sound = U.new("Sound", {Name = "MarrowSound", SoundId = "rbxassetid://" .. id,
					Volume = U.clamp(tonumber(v[2]) or 0.8, 0, 10), Parent = parent})
				made = Store.newPropTrack(sound, "Play", "play")
				Store.setPropKey({folder = made}, frame, true, "Constant", "InOut")
			end, true)
			if made then Act.selectProp(made) end
		end, "Add")
end

-- the target of an action track created from the property menu
function Act.addActionTrack(target, kind)
	if not Act.ensureProject(target.Name) then return end
	for _, pt in ipairs(S.proj.props) do
		if pt.target == target and pt.kind == kind then
			Act.selectProp(pt.folder)
			return
		end
	end
	local frame = U.round(S.frame)
	local made
	Hist.run("Marrow: add " .. kind, function()
		made = Store.newPropTrack(target, kind == "emit" and "Emit" or "Play", kind)
		Store.setPropKey({folder = made}, frame, kind == "emit" and 20 or true, "Constant", "InOut")
	end, true)
	if made then Act.selectProp(made) end
end

-- ===================================================================================================
-- the menu bar
-- ===================================================================================================
function Act.fileMenu(b)
	local has = S.proj ~= nil
	UI.menuAt(b, {
		{text = "New animation...", fn = Act.newProject},
		{text = "Open...", fn = function() Act.projectMenu(b) end},
		{text = "Duplicate", disabled = not has, fn = Act.duplicateProject},
		{text = "Rename...", disabled = not has, fn = Act.renameDialog},
		{text = "Delete...", disabled = not has, fn = Act.deleteProject},
		{sep = true},
		{text = "Import...", fn = function() Act.importMenu(b) end},
		{text = "Export KeyframeSequence", disabled = not has, fn = IO.exportKeyframeSequence},
		{text = "Export cutscene (plays in game, no upload)", disabled = not has, fn = IO.exportCutscene},
		{sep = true},
		{text = "Publish to Roblox", disabled = not has, fn = IO.publish},
		{sep = true},
		{text = "Close animation", disabled = not has, fn = function() Act.openProject(nil) end},
	}, 300)
end

function Act.editMenu(b)
	local has = S.proj ~= nil
	local rig = S.rig ~= nil
	UI.menuAt(b, {
		{text = "Undo  (Ctrl+Z)", fn = function() pcall(function() Svc.History:Undo() end) end},
		{text = "Redo  (Ctrl+Y)", fn = function() pcall(function() Svc.History:Redo() end) end},
		{sep = true},
		{text = "Key selected  (K)", disabled = not has, fn = Act.keySelected},
		{text = "Key every joint  (Shift+K)", disabled = not rig, fn = Act.keyAll},
		{text = "Copy keys  (Ctrl+C)", disabled = not has, fn = Act.copyKeys},
		{text = "Paste keys  (Ctrl+V)", disabled = not has, fn = function() Act.pasteKeys(U.round(S.frame)) end},
		{text = "Delete keys  (Delete)", disabled = not has, fn = Act.deleteSelected},
		{text = "Select every key  (Ctrl+A)", disabled = not has, fn = Act.selectAll},
		{sep = true},
		{text = "Copy pose", disabled = not rig, fn = Act.copyPose},
		{text = "Paste pose", disabled = not rig, fn = function() Act.pastePose(false) end},
		{text = "Paste pose mirrored", disabled = not rig, fn = function() Act.pastePose(true) end},
		{text = "Mirror pose  (M)", disabled = not rig, fn = Act.mirrorPose},
		{text = "Reset joint to rest", disabled = not rig, fn = Act.resetJoint},
		{text = "Save pose to the library...", disabled = not rig, fn = Act.savePoseDialog},
		{text = "Apply pose from the library...", disabled = not rig, fn = function() Act.poseLibraryMenu(b) end},
		{sep = true},
		{text = "Reverse keys", disabled = not has, fn = Act.reverseKeys},
		{text = "Stretch keys...", disabled = not has, fn = Act.stretchDialog},
		{text = "Shift keys...", disabled = not has, fn = Act.shiftDialog},
		{text = "Insert frames at the playhead...", disabled = not has, fn = function() Act.timeDialog(true) end},
		{text = "Remove frames at the playhead...", disabled = not has, fn = function() Act.timeDialog(false) end},
		{text = "Close the loop", disabled = not has, fn = Act.closeLoop},
		{text = "Simplify keys", disabled = not has, fn = Act.simplifyKeys},
		{text = "Delete every key...", disabled = not has, fn = Act.clearAll},
	}, 290)
end

function Act.viewMenu(b)
	UI.menuAt(b, {
		{text = "Onion skin  (O)", checked = S.onion, fn = Act.toggleOnion},
		{text = "Motion path  (T)", checked = S.path, fn = Act.togglePath},
		{text = "Look through the camera track", checked = S.camPreview, fn = Act.toggleCamera},
		{text = "World axes  (L)", checked = S.space == "world", fn = Act.toggleSpace},
		{text = "Snapping...", fn = function() Act.snapMenu(b) end},
		{text = "Loop the preview", checked = S.loopPlay, fn = Act.toggleLoopPlay},
		{text = "Preview speed...", fn = function() Act.speedMenu(b) end},
		{sep = true},
		{text = "Fit the timeline  (F)", disabled = not S.proj, fn = function() Act.fitView() Draw.all() end},
		{text = "Release the rig (rest pose)", disabled = not S.rig, fn = Act.releaseRig},
	}, 270)
end

function Act.addMenu(b)
	local has = S.proj ~= nil
	UI.menuAt(b, {
		{title = "SELECT IT IN THE VIEWPORT OR EXPLORER FIRST"},
		{text = "Rig  (a character or anything with Motor6D)", fn = Act.attachSelected},
		{text = "Item  (any part or model: sword, door, car...)", fn = function() Act.addItemTrack() end},
		{text = "Hold item in hand  (body part + item)", disabled = not S.rig, fn = Act.weldItem},
		{text = "Property of the selected object...", disabled = not has, fn = Act.addPropertyMenu},
		{sep = true},
		{text = "Camera", disabled = not has, fn = Act.addCameraTracks},
		{text = "Event at the playhead", disabled = not has, fn = function() Act.addMarker(U.round(S.frame)) end},
	}, 340)
end

function Act.effectsMenu(b)
	local items = {{title = "ON THE SELECTED PART, AT THE PLAYHEAD"}}
	for _, entry in ipairs(Act.EFFECTS) do
		table.insert(items, {text = entry[2], fn = function() Act.addEffect(entry) end})
	end
	table.insert(items, {text = "Sound...", fn = Act.addSoundDialog})
	UI.menuAt(b, items, 300)
end

-- ===================================================================================================
-- start
-- ===================================================================================================
-- play tests load plugins too: the animator only runs while editing
local editing = true
pcall(function() editing = Svc.Run:IsEdit() end)
if not editing then return end

function Act.loadSetting(key, default)
	local ok, v = pcall(function() return plugin:GetSetting("Marrow_" .. key) end)
	if ok and v ~= nil and typeof(v) == typeof(default) then return v end
	return default
end

S.proj, S.rig, S.joints, S.roots = nil, nil, {}, {}
S.jointByName, S.jointByPart1, S.rootSet, S.treeParts, S.carrierOf = {}, {}, {}, {}, {}
S.applyMode = "Transform"
S.frame, S.playing, S.speed = 0, false, 1
S.sel, S.pending = {}, {}
S.view = {start = -2, finish = 122}
S.scrollY, S.collapsed, S.search, S.rows = 0, {}, "", {}
S.poseMode, S.drag = false, nil
S.lastClick = {t = 0, p = Vector2.zero}
S.released = false
S.propOriginal = {}
S.dataVersion = 0
S.tool = Act.loadSetting("tool", "rotate")
S.space = Act.loadSetting("space", "local")
S.snapOn = Act.loadSetting("snapOn", true)
S.snapRot = Act.loadSetting("snapRot", 15)
S.snapMove = Act.loadSetting("snapMove", 0.25)
S.autoKey = Act.loadSetting("autoKey", true)
S.onion = Act.loadSetting("onion", false)
S.path = Act.loadSetting("path", false)
S.loopPlay = Act.loadSetting("loopPlay", true)
S.camPreview = false
if S.tool ~= "rotate" and S.tool ~= "move" then S.tool = "rotate" end
if S.space ~= "local" and S.space ~= "world" then S.space = "local" end

-- ===== the window =====
UI.toolbar = plugin:CreateToolbar("Marrow Animator")
UI.openButton = UI.toolbar:CreateButton("MarrowAnimatorOpen",
	"Marrow Animator: keyframe animation for rigs, properties and the camera", ICON, "Marrow Animator")
UI.openButton.ClickableWhenViewportHidden = true
-- its own floating window, like a separate program (it can still be docked by dragging its title)
UI.widget = plugin:CreateDockWidgetPluginGui("MarrowAnimatorMain",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 1200, 560, 820, 320))
UI.widget.Title = "Marrow Animator"
UI.widget.Name = "MarrowAnimator"
UI.widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
UI.build(UI.widget)
Gizmo.init()
UI.conns = {}
local function keep(c) table.insert(UI.conns, c) return c end

-- ===== keys =====
local K = Enum.KeyCode
-- fromViewport: the key came through the 3D view, where only POSE mode listens (and never to Ctrl+ keys,
-- which Studio uses there for its own copy / paste)
function Act.hotkey(input, fromViewport)
	if input.UserInputType ~= Enum.UserInputType.Keyboard or not UI.widget.Enabled then return end
	if UI.typing and UI.typing.Parent then
		local ok, focused = pcall(function() return UI.typing:IsFocused() end)
		if not ok or focused then return end
	end
	local k = input.KeyCode
	local ctrl = U.isDown(input, Enum.ModifierKey.Ctrl)
	local shift = U.isDown(input, Enum.ModifierKey.Shift)
	if fromViewport then
		if not S.poseMode or ctrl or k == K.F then return end
		-- in the 3D view Delete also removes what Studio has selected: only act when that is nothing
		if (k == K.Delete or k == K.Backspace) and #Svc.Selection:Get() > 0 then return end
	end
	-- the same key press can arrive through the 3D view and the window
	local now = os.clock()
	if S.lastKey == k and now - (S.lastKeyAt or 0) < 0.08 then return end
	S.lastKey, S.lastKeyAt = k, now
	if UI.dialogLayer.Visible then
		if k == K.Escape then
			UI.dialogLayer.Visible = false
			for _, c in ipairs(UI.dialogLayer:GetChildren()) do c:Destroy() end
		end
		return
	end
	if UI.menu.Visible then
		if k == K.Escape then UI.closeMenu() end
		return
	end
	if ctrl then
		if k == K.C then Act.copyKeys()
		elseif k == K.V then Act.pasteKeys(U.round(S.frame))
		elseif k == K.A then Act.selectAll()
		end
		return
	end
	if k == K.Space then Act.togglePlay()
	elseif k == K.K then
		if shift then Act.keyAll() else Act.keySelected() end
	elseif k == K.Comma then Act.step(-1)
	elseif k == K.Period then Act.step(1)
	elseif k == K.LeftBracket then Act.prevKey()
	elseif k == K.RightBracket then Act.nextKey()
	elseif k == K.Home then Act.toStart()
	elseif k == K.End then Act.toEnd()
	elseif k == K.Delete or k == K.Backspace then
		Act.deleteSelected()
	elseif k == K.R then Act.setTool("rotate")
	elseif k == K.G then Act.setTool("move")
	elseif k == K.L then Act.toggleSpace()
	elseif k == K.N then Act.toggleSnap()
	elseif k == K.O then Act.toggleOnion()
	elseif k == K.T then Act.togglePath()
	elseif k == K.M then Act.mirrorPose()
	elseif k == K.P then Act.togglePoseMode()
	elseif k == K.F then
		Act.fitView()
		Draw.all()
	elseif k == K.Escape then
		if next(S.sel) then
			S.sel = {}
			Draw.all()
		elseif S.poseMode then
			Act.setPoseMode(false)
		end
	end
end

keep(Svc.UIS.InputBegan:Connect(UI.safe(function(input, processed)
	if not processed then Act.hotkey(input, true) end
end)))
UI.root.InputBegan:Connect(UI.safe(function(input) Act.hotkey(input, false) end))

-- shortcuts anyone can bind in Studio's Customize Shortcuts window (File menu; search "Marrow")
local ACTIONS = {
	{"MarrowPlay", "Marrow: Play / Stop", Act.togglePlay},
	{"MarrowKey", "Marrow: Key the selected joint or property", Act.keySelected},
	{"MarrowKeyAll", "Marrow: Key every joint", Act.keyAll},
	{"MarrowPrevFrame", "Marrow: Previous frame", function() Act.step(-1) end},
	{"MarrowNextFrame", "Marrow: Next frame", function() Act.step(1) end},
	{"MarrowPrevKey", "Marrow: Previous key", Act.prevKey},
	{"MarrowNextKey", "Marrow: Next key", Act.nextKey},
	{"MarrowPose", "Marrow: POSE mode on / off", Act.togglePoseMode},
	{"MarrowRotate", "Marrow: Rotate tool", function() Act.setTool("rotate") end},
	{"MarrowMove", "Marrow: Move tool", function() Act.setTool("move") end},
	{"MarrowSpace", "Marrow: Local / world axes", Act.toggleSpace},
	{"MarrowMirror", "Marrow: Mirror the pose", Act.mirrorPose},
	{"MarrowCopy", "Marrow: Copy keys (or the pose)", Act.copyKeys},
	{"MarrowPaste", "Marrow: Paste keys at the playhead", function() Act.pasteKeys(U.round(S.frame)) end},
	{"MarrowDelete", "Marrow: Delete the selected keys", Act.deleteSelected},
}
for _, a in ipairs(ACTIONS) do
	local ok, action = pcall(function() return plugin:CreatePluginAction(a[1], a[2], a[2], "", true) end)
	if ok and action then
		action.Triggered:Connect(UI.safe(function()
			if UI.widget.Enabled then a[3]() end
		end))
	end
end

-- ===== the timeline's mouse =====
UI.search:GetPropertyChangedSignal("Text"):Connect(UI.safe(function()
	S.search = UI.search.Text
	S.scrollY = 0
	Draw.all()
end))

local MB1, MB2, MB3 = Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3
local function isButton(input)
	local t = input.UserInputType
	return t == MB1 or t == MB2 or t == MB3
end

UI.keysHit.InputBegan:Connect(UI.safe(function(input)
	local t = input.UserInputType
	if t == MB1 then Act.keysPress(input)
	elseif t == MB2 then Act.keysContext()
	elseif t == MB3 then Act.beginPan()
	elseif t == Enum.UserInputType.Keyboard then Act.hotkey(input, false)
	end
end))
UI.keysHit.InputChanged:Connect(UI.safe(function(input) Act.wheel(input, "keys") end))

UI.listHit.InputBegan:Connect(UI.safe(function(input)
	local t = input.UserInputType
	if t == MB1 or t == MB2 then Act.listPress(input)
	elseif t == Enum.UserInputType.Keyboard then Act.hotkey(input, false)
	end
end))
UI.listHit.InputChanged:Connect(UI.safe(function(input) Act.wheel(input, "list") end))

UI.rulerHit.InputBegan:Connect(UI.safe(function(input)
	local t = input.UserInputType
	if t == MB1 or t == MB2 then Act.rulerPress(input)
	elseif t == MB3 then Act.beginPan()
	elseif t == Enum.UserInputType.Keyboard then Act.hotkey(input, false)
	end
end))
UI.rulerHit.InputChanged:Connect(UI.safe(function(input) Act.wheel(input, "ruler") end))

-- a drag ends when the button comes up; if that happened outside the window, the next click ends it
UI.catcherShownAt = 0
UI.catcher:GetPropertyChangedSignal("Visible"):Connect(function()
	if UI.catcher.Visible then UI.catcherShownAt = os.clock() end
end)
UI.catcher.InputEnded:Connect(UI.safe(function(input)
	if isButton(input) and S.drag then Act.endDrag() end
end))
UI.catcher.InputBegan:Connect(UI.safe(function(input)
	if isButton(input) and S.drag and os.clock() - UI.catcherShownAt > 0.15 then Act.endDrag() end
end))
for _, hit in ipairs({UI.keysHit, UI.rulerHit}) do
	hit.InputEnded:Connect(UI.safe(function(input)
		if isButton(input) and S.drag then Act.endDrag() end
	end))
end
UI.widget.WindowFocusReleased:Connect(UI.safe(function()
	if S.drag then Act.endDrag() end
end))

UI.keys:GetPropertyChangedSignal("AbsoluteSize"):Connect(UI.safe(function() Draw.all() end))
UI.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(UI.safe(function() UI.closeMenu() end))

-- ===== the 3D view =====
Gizmo.mouse = plugin:GetMouse()
Gizmo.mouse.Button1Down:Connect(UI.safe(Gizmo.mouseDown))
Gizmo.mouse.Move:Connect(UI.safe(Gizmo.mouseMove))
Gizmo.mouse.Button1Up:Connect(UI.safe(function()
	if Gizmo.drag then Gizmo.finish() end
end))
plugin.Deactivation:Connect(UI.safe(function()
	if S.poseMode then Act.setPoseMode(false) end
end))

-- Studio's Undo / Redo changed the data: show what is there now
keep(Svc.History.OnUndo:Connect(UI.safe(function()
	if UI.widget.Enabled and S.proj then Act.reload(true) end
end)))
keep(Svc.History.OnRedo:Connect(UI.safe(function()
	if UI.widget.Enabled and S.proj then Act.reload(true) end
end)))

-- picking a body part in the Explorer or viewport (outside POSE) selects its joint
keep(Svc.Selection.SelectionChanged:Connect(UI.safe(function()
	if S.poseMode or not S.rig or not UI.widget.Enabled then return end
	local obj = Svc.Selection:Get()[1]
	if obj and obj:IsA("BasePart") and obj:IsDescendantOf(S.rig) then
		local j = Rig.jointForPart(obj)
		if j and j.name ~= S.selJoint then Act.selectJoint(j.name) end
	end
end)))

-- ===== playback =====
function Act.tick(dt)
	local length = S.proj.length
	local before = S.frame
	local f = S.frame + dt * S.proj.fps * S.speed
	if f >= length then
		Anim.fireActions(before, length)
		if S.loopPlay and length > 0 then
			f = f % length
			Anim.fireActions(-1, f)
		else
			S.frame = length
			Anim.apply(length)
			Act.stop()
			return
		end
	else
		Anim.fireActions(before, f)
	end
	S.frame = f
	Anim.apply(f)
	Draw.playhead()
	View.updateGhosts()
end

keep(Svc.Run.Heartbeat:Connect(function(dt)
	if not UI.widget.Enabled then return end
	if S.drag then
		local ok, err = pcall(Act.dragStep)
		if not ok then
			S.drag = nil
			UI.catcher.Visible = false
			UI.boxSel.Visible = false
			Act.status("Error: " .. tostring(err), true)
		end
	end
	if S.playing then
		if not S.proj then
			S.playing = false
			return
		end
		local ok, err = pcall(Act.tick, math.min(dt, 0.1))
		if not ok then
			S.playing = false
			Draw.toolbar()
			warn("[Marrow Animator] " .. tostring(err))
			Act.status("Error: " .. tostring(err), true)
		end
	end
end))

-- ===== opening and closing =====
function Act.onOpen()
	UI.openButton:SetActive(true)
	if not S.proj then
		local last = Act.loadSetting("lastProject", "")
		local root = Store.root(false)
		local folder = last ~= "" and root and root:FindFirstChild(last) or nil
		if folder and folder:IsA("Folder") and folder:GetAttribute("MarrowVersion") then
			Act.openProject(folder)
		else
			Act.reload()
			Act.status("Marrow Animator " .. VERSION .. "  -  select a rig and press + New.  Help explains everything.")
		end
	else
		Act.reload(true)
	end
	task.defer(UI.safe(function() Draw.all() end))
end

function Act.onClose()
	UI.openButton:SetActive(false)
	if S.drag then Act.endDrag() end
	UI.closeMenu()
	S.playing = false
	Act.setPoseMode(false)
	S.camPreview = false
	S.pending = {}
	Anim.restoreProps()
	Rig.unbind()
	Gizmo.hide()
	View.clearGhosts()
	View.clearPath()
end

UI.openButton.Click:Connect(function()
	UI.widget.Enabled = not UI.widget.Enabled
end)
UI.widget:GetPropertyChangedSignal("Enabled"):Connect(UI.safe(function()
	if UI.widget.Enabled then Act.onOpen() else Act.onClose() end
end))
if UI.widget.Enabled then task.defer(UI.safe(Act.onOpen)) end

-- the plugin is turned off, updated or Studio closes: leave the rig and the scene as they were
plugin.Unloading:Connect(function()
	pcall(Act.onClose)
	for _, c in ipairs(UI.conns) do pcall(function() c:Disconnect() end) end
	pcall(function() Gizmo.folder:Destroy() end)
	pcall(function()
		if View.folder then View.folder:Destroy() end
	end)
end)
