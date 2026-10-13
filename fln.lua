--[[
    Aurora UI · Drawing API — v2.0
    RightShift - toggle, I - No Recoil.
    При открытом меню: мышь свободна, панели тащатся за шапку,
    инвентарь меняет размер за уголок справа снизу.
]]

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local env = (getgenv and getgenv()) or _G
if env.AuroraUI then
    pcall(function() env.AuroraUI:Destroy() end)
end

local FONT = (Drawing.Fonts and Drawing.Fonts.Plex) or 2

local function cLerp(a, b, t)
    t = tonumber(t) or 0
    if t <= 0 then return a elseif t >= 1 then return b end
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

-- смешивание в "линейном" пространстве: середина градиента не грязнеет
local function cMix(a, b, t)
    t = tonumber(t) or 0
    if t <= 0 then return a elseif t >= 1 then return b end
    local ar, ag, ab = a.R * a.R, a.G * a.G, a.B * a.B
    return Color3.new(
        math.sqrt(ar + (b.R * b.R - ar) * t),
        math.sqrt(ag + (b.G * b.G - ag) * t),
        math.sqrt(ab + (b.B * b.B - ab) * t)
    )
end

local function vLerp(a, b, t)
    t = tonumber(t) or 0
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return Vector2.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end

local Theme = {
    Bg = Color3.fromRGB(13, 13, 20),
    Panel = Color3.fromRGB(18, 18, 28),
    Element = Color3.fromRGB(25, 25, 38),
    ElementHover = Color3.fromRGB(34, 34, 52),
    Stroke = Color3.fromRGB(46, 46, 70),
    Text = Color3.fromRGB(238, 238, 252),
    SubText = Color3.fromRGB(135, 135, 172),
    AccentA = Color3.fromRGB(140, 90, 255),
    AccentB = Color3.fromRGB(0, 205, 255),
}
local targetA, targetB = Theme.AccentA, Theme.AccentB
local SHADOW_COL = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local Presets = {
    {Color3.fromRGB(140, 90, 255), Color3.fromRGB(0, 205, 255)},
    {Color3.fromRGB(255, 70, 140), Color3.fromRGB(255, 175, 60)},
    {Color3.fromRGB(0, 230, 150), Color3.fromRGB(0, 140, 255)},
    {Color3.fromRGB(255, 55, 75), Color3.fromRGB(170, 40, 255)},
    {Color3.fromRGB(255, 215, 80), Color3.fromRGB(70, 255, 160)},
}

-- проверяем, умеет ли Drawing скруглять Square сам (Corner)
local NATIVE_CORNER = false
pcall(function()
    local s = Drawing.new("Square")
    s.Visible = false
    s.Corner = 4
    local v = s.Corner
    pcall(function() s:Remove() end)
    NATIVE_CORNER = tonumber(v) == 4
end)

local Settings = {
    glow = true,
    glowPower = 1,
    particles = true,
    pulse = true,
    speed = 1,
    unlockMouse = true,
    cursor = true,
    nativeRound = NATIVE_CORNER,
    hudOpacity = 0.72,  -- прозрачность фона HUD-панелей
    invScale = 1,       -- размер инвентаря
}

local Objects, Connections = {}, {}
local clock = 0
local frameCounter = 0

local function getMouse()
    local mx, my = 0, 0
    pcall(function()
        mx = tonumber(Mouse.X) or 0
        my = tonumber(Mouse.Y) or 0
    end)
    return Vector2.new(mx, my)
end

--==================== caches + helpers ====================--

local OutlineText = setmetatable({}, {__mode = "k"})
local VisCache = setmetatable({}, {__mode = "k"})
local TrCache = setmetatable({}, {__mode = "k"})
local BoundsCache = setmetatable({}, {__mode = "k"})
local TextCache = setmetatable({}, {__mode = "k"})
local SizeCache = setmetatable({}, {__mode = "k"})
local accentCache = {}
local accentFrame = -1
local ACC_Q = 48

local function new(class, props)
    local o = Drawing.new(class)
    o.Visible = false
    for k, v in pairs(props or {}) do o[k] = v end
    if class == "Text" and props then
        if props.Outline then OutlineText[o] = true end
        if props.Text then TextCache[o] = props.Text end
        if props.Size then SizeCache[o] = props.Size end
    end
    Objects[#Objects + 1] = o
    return o
end

local function tryNew(class, props)
    local ok, o = pcall(new, class, props)
    if ok then return o end
    return nil
end

local function kill(o)
    if not o then return end
    for i = #Objects, 1, -1 do
        if Objects[i] == o then
            table.remove(Objects, i)
            break
        end
    end
    pcall(function() o:Remove() end)
end

local function show(o, alpha, base)
    if not o then return end
    local t = (tonumber(base) or 1) * (tonumber(alpha) or 0)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end

    if OutlineText[o] then
        local want = t > 0.5
        if VisCache[o] ~= want then
            VisCache[o] = want
            o.Visible = want
        end
        if TrCache[o] ~= 1 then
            TrCache[o] = 1
            o.Transparency = 1
        end
        return
    end

    local vis = t > 0.01
    if VisCache[o] ~= vis then
        VisCache[o] = vis
        o.Visible = vis
    end
    if vis then
        local last = TrCache[o]
        if not last or math.abs(last - t) > 0.004 then
            TrCache[o] = t
            o.Transparency = t
        end
    end
end

-- Text/Size пишутся только при изменении, без чтения свойств из Drawing
local function setText(o, text)
    if TextCache[o] ~= text then
        TextCache[o] = text
        o.Text = text
    end
end

local function setSize(o, size)
    if SizeCache[o] ~= size then
        SizeCache[o] = size
        o.Size = size
        BoundsCache[o] = nil
    end
end

local function damp(a, b, speed, dt)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    local r = a + (b - a) * (1 - math.exp(-(tonumber(speed) or 12) * (tonumber(dt) or (1/60))))
    if math.abs(b - r) < 0.002 then return b end
    return r
end

local function accentAt(p)
    if accentFrame ~= frameCounter then
        table.clear(accentCache)
        accentFrame = frameCounter
    end
    local k = math.floor((p or 0) * ACC_Q + 0.5)
    local c = accentCache[k]
    if c then return c end
    local t = (math.sin(clock * 1.6 + k / ACC_Q * math.pi * 2) + 1) / 2
    t = t * t * (3 - 2 * t)
    c = cMix(Theme.AccentA, Theme.AccentB, t)
    accentCache[k] = c
    return c
end

local function pulseK(speed, ph, lo)
    if not Settings.pulse then return 1 end
    lo = lo or 0.75
    local v = lo + (1 - lo) * (0.5 + 0.5 * math.sin(clock * (speed or 2) + (ph or 0)))
    return math.floor(v * 24 + 0.5) / 24
end

local function bounds(t)
    if not t then return Vector2.new(0, 14) end
    local text = TextCache[t] or ""
    local c = BoundsCache[t]
    if c and c.text == text then return c.b end

    local ok, b = pcall(function() return t.TextBounds end)
    if ok and b and tonumber(b.X) and tonumber(b.Y) and b.X > 0 then
        b = Vector2.new(b.X, b.Y)
        BoundsCache[t] = {text = text, b = b}
        return b
    end
    local size = SizeCache[t] or 14
    return Vector2.new(#text * size * 0.5, size)
end

local function inRect(m, r)
    if not m or not r then return false end
    local x, y, w, h = r[1], r[2], r[3], r[4]
    if type(x) ~= "number" or type(y) ~= "number"
        or type(w) ~= "number" or type(h) ~= "number" then
        return false
    end
    local mx, my = tonumber(m.X) or 0, tonumber(m.Y) or 0
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function dist(a, b)
    if not a or not b then return 9999 end
    local dx = (tonumber(a.X) or 0) - (tonumber(b.X) or 0)
    local dy = (tonumber(a.Y) or 0) - (tonumber(b.Y) or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local reported = {}
local function reportError(where, err)
    local key = tostring(where) .. tostring(err)
    if reported[key] then return end
    reported[key] = true
    warn("[Aurora] " .. tostring(where) .. ": " .. tostring(err))
end

local function fireCallback(cb, ...)
    if not cb then return end
    local ok, err = pcall(cb, ...)
    if not ok then reportError("callback", err) end
end

--==================== primitives ====================--
-- RoundRect: если Drawing умеет Corner — 1 объект, честная прозрачность.
-- иначе 3 полосы без перекрытия + 4 круга (без тёмного "креста" на полупрозрачном фоне).

local RoundRect = {}
RoundRect.__index = RoundRect

-- outline=true: в нативном режиме рисуется контуром поверх, иначе заливкой снизу (zFill)
function RoundRect.new(z, outline, zFill)
    return setmetatable({z = z, outline = outline, zf = zFill or z}, RoundRect)
end

local function useNative()
    return NATIVE_CORNER and Settings.nativeRound
end

function RoundRect:_native()
    local s = self.sq
    if not s then
        s = new("Square", {Filled = not self.outline, Thickness = 1, ZIndex = self.z})
        self.sq = s
    end
    return s
end

function RoundRect:_parts()
    local p = self.p
    if not p then
        local z = self.zf
        p = {}
        for i = 1, 3 do
            p[i] = new("Square", {Filled = true, Thickness = 1, ZIndex = z})
        end
        for i = 4, 7 do
            p[i] = new("Circle", {Filled = true, NumSides = 12, Thickness = 1, ZIndex = z})
        end
        self.p = p
    end
    return p
end

local function hideList(p)
    if not p then return end
    for i = 1, #p do show(p[i], 0) end
end

local function setCorner(c, px, py, r, color, a)
    c.Position = Vector2.new(px, py)
    c.Radius = r
    c.Color = color
    show(c, a)
end

function RoundRect:set(x, y, w, h, r, color, alpha)
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    w = tonumber(w) or 0
    h = tonumber(h) or 0
    r = tonumber(r) or 0
    color = color or WHITE
    alpha = tonumber(alpha) or 0
    local native = useNative()

    local L = self.last
    if L then
        if L.native == native then
            if alpha <= 0 and L.a <= 0 then return end
            if L.x == x and L.y == y and L.w == w and L.h == h and L.r == r
                and L.a == alpha and L.cr == color.R and L.cg == color.G and L.cb == color.B then
                return
            end
        else
            -- режим переключили: прячем старый набор
            if native then hideList(self.p) else show(self.sq, 0) end
        end
    else
        L = {}
        self.last = L
    end
    L.native = native
    L.x, L.y, L.w, L.h, L.r, L.a = x, y, w, h, r, alpha
    L.cr, L.cg, L.cb = color.R, color.G, color.B

    if w <= 0 or h <= 0 or alpha <= 0 then
        if native then show(self.sq, 0) else hideList(self.p) end
        return
    end

    local minR = math.min(w, h) / 2
    if r > minR then r = minR end
    if r < 0 then r = 0 end

    if native then
        local s = self:_native()
        s.Position = Vector2.new(x, y)
        s.Size = Vector2.new(w, h)
        s.Color = color
        if self.lr ~= r then
            self.lr = r
            if not pcall(function() s.Corner = r end) then NATIVE_CORNER = false end
        end
        show(s, alpha)
        return
    end

    local p = self:_parts()
    local top, mid, bot = p[1], p[2], p[3]
    local iw, ih = w - r * 2, h - r * 2
    if r > 0 and iw > 0 then
        top.Position = Vector2.new(x + r, y)
        top.Size = Vector2.new(iw, r)
        top.Color = color
        show(top, alpha)
        bot.Position = Vector2.new(x + r, y + h - r)
        bot.Size = Vector2.new(iw, r)
        bot.Color = color
        show(bot, alpha)
    else
        show(top, 0); show(bot, 0)
    end
    if ih > 0 then
        mid.Position = Vector2.new(x, y + r)
        mid.Size = Vector2.new(w, ih)
        mid.Color = color
        show(mid, alpha)
    else
        show(mid, 0)
    end
    local ca = r > 0 and alpha or 0
    setCorner(p[4], x + r, y + r, r, color, ca)
    setCorner(p[5], x + w - r, y + r, r, color, ca)
    setCorner(p[6], x + r, y + h - r, r, color, ca)
    setCorner(p[7], x + w - r, y + h - r, r, color, ca)
end

function RoundRect:hide()
    self:set(0, 0, 0, 0, 0, WHITE, 0)
end

function RoundRect:destroy()
    kill(self.sq)
    if self.p then for _, o in ipairs(self.p) do kill(o) end end
end

local Gradient = {}
Gradient.__index = Gradient

function Gradient.new(n, z)
    local self = setmetatable({n = n, strips = {}, wd = {}, lastA = -1}, Gradient)
    for i = 1, n do
        self.strips[i] = new("Square", {Filled = true, Thickness = 1, ZIndex = z})
        self.wd[i] = 0
    end
    return self
end

function Gradient:set(x, y, w, h, alpha, colorFn, alphaFn)
    alpha = tonumber(alpha) or 0
    if alpha <= 0 or not colorFn then
        if self.lastA ~= 0 then
            self.lastA = 0
            for _, s in ipairs(self.strips) do show(s, 0) end
        end
        return
    end
    self.lastA = alpha

    local n = self.n
    local geo = self.gx ~= x or self.gy ~= y or self.gw ~= w or self.gh ~= h
    if geo then
        self.gx, self.gy, self.gw, self.gh = x, y, w, h
    end
    for i = 1, n do
        local s = self.strips[i]
        if geo then
            local x0 = math.floor(x + (i - 1) / n * w + 0.5)
            local x1 = math.floor(x + i / n * w + 0.5)
            local sw = x1 - x0
            self.wd[i] = sw
            if sw > 0 then
                s.Position = Vector2.new(x0, y)
                s.Size = Vector2.new(sw, h)
            end
        end
        if self.wd[i] > 0 then
            local p = (i - 0.5) / n
            s.Color = colorFn(p)
            show(s, alpha, alphaFn and alphaFn(p) or 1)
        else
            show(s, 0)
        end
    end
end

function Gradient:destroy()
    for _, s in ipairs(self.strips) do kill(s) end
end

local function edgeFade(p)
    local v = math.min(p, 1 - p) * 4
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return v
end

local function newGrip(z)
    local g = {}
    for i = 1, 6 do
        g[i] = new("Circle", {Filled = true, NumSides = 6, Radius = 1.3, ZIndex = z, Color = Theme.SubText})
    end
    return g
end

local function setGrip(g, x, y, a, col)
    if g.lx ~= x or g.ly ~= y then
        g.lx, g.ly = x, y
        for i = 1, 6 do
            local cx, cy = (i - 1) % 2, math.floor((i - 1) / 2)
            g[i].Position = Vector2.new(x + cx * 4, y + cy * 4)
        end
    end
    for i = 1, 6 do
        if col then g[i].Color = col end
        show(g[i], a)
    end
end

local function hideGrip(g)
    for i = 1, 6 do show(g[i], 0) end
end

--==================== shared frame state ====================--

local CurMouse = Vector2.new()
local CamPos = nil
local HoverAny = false
local MouseDown = false
local dragTarget, dragOff = nil, Vector2.new()

local function clampN(v, lo, hi)
    if hi < lo then return lo end
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function panelPos(P, defX, defY, w, h, dt)
    local vs = Camera.ViewportSize
    local tx = clampN(P.tx or defX, 4, vs.X - w - 4)
    local ty = clampN(P.ty or defY, 4, vs.Y - h - 4)
    if not P.cx then P.cx, P.cy = tx, ty end
    P.cx = damp(P.cx, tx, 28, dt)
    P.cy = damp(P.cy, ty, 28, dt)
    return math.floor(P.cx + 0.5), math.floor(P.cy + 0.5)
end

--==================== window ====================--

local W, H, HEADER, SIDEBAR, R = 620, 420, 56, 175, 10

local vs0 = Camera.ViewportSize
local Win = {
    x = vs0.X / 2 - W / 2,
    y = vs0.Y / 2 - H / 2,
    alpha = 0,
    intro = 0,
    open = true,
    tabs = {},
    active = 1,
    indicatorY = 0,
    keybind = Enum.KeyCode.RightShift,
    destroyed = false,
    sleeping = false,
}
Win.tx, Win.ty = Win.x, Win.y

local V = {}
V.glow = {}
for i = 1, 6 do
    V.glow[i] = new("Square", {Filled = false, Thickness = 2, ZIndex = 1})
end
V.glowAnim = 1
V.glowHidden = false
V.particlesHidden = false

V.bg = RoundRect.new(2)
V.side = RoundRect.new(3)
V.sideFix = new("Square", {Filled = true, Thickness = 1, ZIndex = 3, Color = Theme.Panel})
V.sideLine = new("Line", {Thickness = 1, ZIndex = 4, Color = Theme.Stroke})
V.blob1 = new("Circle", {Filled = true, NumSides = 32, ZIndex = 3})
V.blob2 = new("Circle", {Filled = true, NumSides = 32, ZIndex = 3})
V.topBar = Gradient.new(40, 9)
V.topGlow = Gradient.new(40, 8)
V.logoA = new("Circle", {Filled = true, NumSides = 16, ZIndex = 6, Radius = 8})
V.logoB = new("Circle", {Filled = true, NumSides = 16, ZIndex = 6, Radius = 8})
V.logoCore = new("Circle", {Filled = true, NumSides = 12, ZIndex = 7, Radius = 3, Color = WHITE})
V.title = new("Text", {Text = "Aurora", Size = 19, Font = FONT, ZIndex = 6, Color = Theme.Text})
V.subtitle = new("Text", {Text = "v2.0  |  combat + esp", Size = 13, Font = FONT, ZIndex = 6, Color = Theme.SubText})
V.sideDiv = Gradient.new(16, 5)
V.indicator = RoundRect.new(4)
V.indicatorBar = new("Square", {Filled = true, Thickness = 1, ZIndex = 6, Size = Vector2.new(3, 16)})
V.pageTitle = new("Text", {Text = "", Size = 21, Font = FONT, ZIndex = 6, Color = Theme.Text})
V.pageSub = new("Text", {Text = "", Size = 13, Font = FONT, ZIndex = 6, Color = Theme.SubText})
V.headerLine = Gradient.new(24, 5)
V.hint = new("Text", {Text = "RightShift  -  hide", Size = 13, Font = FONT, ZIndex = 6, Color = Theme.SubText})
V.dots = {
    {o = new("Circle", {Filled = true, NumSides = 14, ZIndex = 7}), color = Color3.fromRGB(255, 95, 110), hover = 0},
    {o = new("Circle", {Filled = true, NumSides = 14, ZIndex = 7}), color = Color3.fromRGB(255, 200, 80), hover = 0},
}
for _, d in ipairs(V.dots) do d.o.Color = d.color end

local Particles = {}
for i = 1, 18 do
    Particles[i] = {
        o = new("Circle", {Filled = true, NumSides = 8, ZIndex = 4}),
        x = math.random(), y = math.random(),
        s = 0.025 + math.random() * 0.06,
        r = 1 + math.random() * 1.6,
        ph = math.random() * math.pi * 2,
    }
    Particles[i].o.Radius = Particles[i].r
end
local particleAnim = 1

--==================== Tabs ====================--

local TabMT = {}
TabMT.__index = TabMT

function Win:Tab(name, desc)
    local tab = setmetatable({
        name = name, desc = desc or "", elements = {},
        alpha = 0, hover = 0, sel = 0, hidden = true,
    }, TabMT)
    tab.label = new("Text", {Text = name, Size = 15, Font = FONT, ZIndex = 6})
    tab.icon = new("Circle", {Filled = true, NumSides = 12, ZIndex = 6})
    table.insert(self.tabs, tab)
    return tab
end

function TabMT:Toggle(o)
    local el = {h = 44, state = o.Default or false, hover = 0, cb = o.Callback}
    el.anim = el.state and 1 or 0
    el.card = RoundRect.new(5)
    el.label = new("Text", {Text = o.Name, Size = 15, Font = FONT, ZIndex = 6})
    el.track = RoundRect.new(6)
    el.glow = new("Circle", {Filled = true, NumSides = 14, ZIndex = 7})
    el.knob = new("Circle", {Filled = true, NumSides = 14, ZIndex = 8, Color = WHITE})

    function el:Set(v)
        self.state = v and true or false
        fireCallback(self.cb, self.state)
    end

    function el:press()
        self:Set(not self.state)
    end

    function el:update(dt, x, y, w, a, hovered)
        self.anim = damp(self.anim, self.state and 1 or 0, 14, dt)
        self.hover = damp(self.hover, hovered and 1 or 0, 12, dt)
        local fill = cLerp(Theme.Element, Theme.ElementHover, self.hover)
        if self.hover > 0.01 then
            fill = cMix(fill, accentAt(0.3), self.hover * 0.18)
        end
        self.card:set(x, y, w, self.h, 8, fill, a)
        local b = bounds(self.label)
        self.label.Position = Vector2.new(x + 14 + self.hover * 2, y + (self.h - b.Y) / 2)
        self.label.Color = cLerp(Theme.SubText, Theme.Text, 0.55 + 0.45 * math.max(self.anim, self.hover))
        show(self.label, a)

        local tw, th = 42, 22
        local tx, ty = x + w - tw - 14, y + (self.h - th) / 2
        self.track:set(tx, ty, tw, th, th / 2, cMix(Theme.Stroke, accentAt(0.3), self.anim), a)

        local kp = Vector2.new(tx + th / 2 + (tw - th) * self.anim, ty + th / 2)
        self.knob.Position = kp
        self.knob.Radius = 7 + self.hover * 0.8
        show(self.knob, a)

        self.glow.Position = kp
        self.glow.Radius = 8 + 6 * self.anim
        self.glow.Color = accentAt(0.3)
        show(self.glow, a, 0.28 * self.anim)
    end

    table.insert(self.elements, el)
    return el
end

function TabMT:Slider(o)
    local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
    local dec = step < 1 and math.max(0, math.ceil(-math.log10(step) - 1e-9)) or 0
    local fmt = "%." .. dec .. "f"
    local el = {h = 58, value = math.clamp(o.Default or min, min, max), hover = 0, dragging = false, cb = o.Callback}
    el.anim = (el.value - min) / (max - min)
    el.card = RoundRect.new(5)
    el.label = new("Text", {Text = o.Name, Size = 15, Font = FONT, ZIndex = 6, Color = Theme.Text})
    el.valueText = new("Text", {Text = "", Size = 14, Font = FONT, ZIndex = 6})
    el.track = RoundRect.new(6)
    el.cap = new("Circle", {Filled = true, NumSides = 12, ZIndex = 7})
    el.fill = Gradient.new(16, 7)
    el.knobGlow = new("Circle", {Filled = true, NumSides = 16, ZIndex = 8})
    el.knob = new("Circle", {Filled = true, NumSides = 16, ZIndex = 9, Color = WHITE})
    el.fillFn = function(p) return accentAt(p * el.anim) end

    function el:Set(v)
        v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
        if v ~= self.value then
            self.value = v
            fireCallback(self.cb, v)
        end
    end

    -- обновить значение без вызова callback (синхронизация снаружи)
    function el:SetSilent(v)
        self.value = math.clamp(v, min, max)
    end

    function el:drag(m)
        local r = self.trackRect
        if not r then return end
        local mx = tonumber(m and m.X) or 0
        self:Set(min + (max - min) * math.clamp((mx - r[1]) / r[3], 0, 1))
    end

    function el:press(m)
        self.dragging = true
        self:drag(m)
    end

    function el:update(dt, x, y, w, a, hovered, m)
        if self.dragging then self:drag(m) end
        self.hover = damp(self.hover, (hovered or self.dragging) and 1 or 0, 12, dt)
        self.anim = damp(self.anim, (self.value - min) / (max - min), 18, dt)
        local fill = cLerp(Theme.Element, Theme.ElementHover, self.hover)
        self.card:set(x, y, w, self.h, 8, fill, a)
        self.label.Position = Vector2.new(x + 14, y + 10)
        show(self.label, a)

        setText(self.valueText, string.format(fmt, self.value) .. (o.Suffix or ""))
        local vb = bounds(self.valueText)
        self.valueText.Position = Vector2.new(x + w - 14 - vb.X, y + 11)
        self.valueText.Color = cMix(Theme.SubText, accentAt(0.6), self.hover)
        show(self.valueText, a)

        local tx, ty, tw, th = x + 14, y + 39, w - 28, 6
        self.trackRect = {tx, ty - 10, tw, th + 20}
        self.track:set(tx, ty, tw, th, th / 2, Theme.Stroke, a)

        local fw = tw * self.anim
        self.cap.Position = Vector2.new(tx + th / 2, ty + th / 2)
        self.cap.Radius = th / 2
        self.cap.Color = accentAt(0)
        show(self.cap, a)
        self.fill:set(tx + th / 2, ty, math.max(0, math.floor(fw - th / 2 + 0.5)), th, a, self.fillFn)

        local kp = Vector2.new(tx + fw, ty + th / 2)
        self.knob.Position = kp
        self.knob.Radius = 6 + self.hover * 1.5
        show(self.knob, a)

        self.knobGlow.Position = kp
        self.knobGlow.Radius = 9 + self.hover * 5
        self.knobGlow.Color = accentAt(self.anim)
        show(self.knobGlow, a, 0.3)
    end

    table.insert(self.elements, el)
    return el
end

function TabMT:Button(o)
    local el = {h = 42, hover = 0, ripple = 1, rx = 0, pressAnim = 0, cb = o.Callback}
    el.card = RoundRect.new(5)
    el.flash = new("Square", {Filled = true, Thickness = 1, ZIndex = 6})
    el.label = new("Text", {Text = o.Name, Size = 15, Font = FONT, ZIndex = 7})
    el.ch1 = new("Line", {Thickness = 2, ZIndex = 7})
    el.ch2 = new("Line", {Thickness = 2, ZIndex = 7})

    function el:press(m)
        self.ripple = 0
        self.rx = tonumber(m and m.X) or 0
        self.pressAnim = 1
        fireCallback(self.cb)
    end

    function el:update(dt, x, y, w, a, hovered)
        self.hover = damp(self.hover, hovered and 1 or 0, 12, dt)
        self.ripple = math.min(1, self.ripple + dt * 2.2)
        self.pressAnim = damp(self.pressAnim, 0, 10, dt)

        local ins = self.pressAnim * 2
        local fill = cLerp(Theme.Element, Theme.ElementHover, self.hover)
        self.card:set(x + ins, y + ins, w - ins * 2, self.h - ins * 2, 8, fill, a)

        if self.ripple < 0.99 then
            local e = 1 - (1 - self.ripple) ^ 3
            local x1 = math.max(x + 4, self.rx - e * w)
            local x2 = math.min(x + w - 4, self.rx + e * w)
            self.flash.Position = Vector2.new(x1, y + 3)
            self.flash.Size = Vector2.new(math.max(0, x2 - x1), self.h - 6)
            self.flash.Color = accentAt(math.clamp((self.rx - x) / w, 0, 1))
            show(self.flash, a, (1 - self.ripple) * 0.35)
        else
            show(self.flash, 0)
        end

        local b = bounds(self.label)
        self.label.Position = Vector2.new(x + 14 + self.hover * 3, y + (self.h - b.Y) / 2)
        self.label.Color = cMix(Theme.Text, accentAt(0.4), self.hover * 0.35)
        show(self.label, a)

        local cx, cy = x + w - 20 + self.hover * 4, y + self.h / 2
        local col = cMix(Theme.SubText, accentAt(0.8), self.hover)
        self.ch1.From = Vector2.new(cx - 3, cy - 5)
        self.ch1.To = Vector2.new(cx + 2, cy)
        self.ch2.From = Vector2.new(cx + 2, cy)
        self.ch2.To = Vector2.new(cx - 3, cy + 5)
        self.ch1.Color = col
        self.ch2.Color = col
        show(self.ch1, a); show(self.ch2, a)
    end

    table.insert(self.elements, el)
    return el
end

function TabMT:Swatches(o)
    local presets = o.Presets or Presets
    local el = {h = 50, sel = o.Default or 1, hover = 0, cb = o.Callback, sw = {}}
    el.card = RoundRect.new(5)
    el.label = new("Text", {Text = o.Name, Size = 15, Font = FONT, ZIndex = 6, Color = Theme.Text})
    el.ring = new("Circle", {Filled = false, Thickness = 2, NumSides = 20, ZIndex = 8, Color = WHITE})
    for i, p in ipairs(presets) do
        el.sw[i] = {
            outer = new("Circle", {Filled = true, NumSides = 18, ZIndex = 6, Color = p[1]}),
            inner = new("Circle", {Filled = true, NumSides = 14, ZIndex = 7, Color = p[2]}),
            a = p[1], b = p[2], hover = 0, pos = Vector2.new(),
        }
    end

    function el:press(m)
        for i, s in ipairs(self.sw) do
            if s.pos and dist(m, s.pos) <= 12 then
                self.sel = i
                targetA, targetB = s.a, s.b
                fireCallback(self.cb, i)
                return
            end
        end
    end

    function el:update(dt, x, y, w, a, hovered, m)
        self.hover = damp(self.hover, hovered and 1 or 0, 12, dt)
        local fill = cLerp(Theme.Element, Theme.ElementHover, self.hover)
        self.card:set(x, y, w, self.h, 8, fill, a)
        local b = bounds(self.label)
        self.label.Position = Vector2.new(x + 14, y + (self.h - b.Y) / 2)
        show(self.label, a)

        local n = #self.sw
        for i, s in ipairs(self.sw) do
            s.pos = Vector2.new(x + w - 24 - (n - i) * 30, y + self.h / 2)
            local on = hovered and dist(m, s.pos) <= 12
            s.hover = damp(s.hover, on and 1 or 0, 14, dt)
            local sx = math.cos(clock * 2 + i) * 2
            local sy = math.sin(clock * 2 + i) * 2
            s.outer.Position = s.pos
            s.outer.Radius = 9 + s.hover * 1.5
            show(s.outer, a)
            s.inner.Position = Vector2.new(s.pos.X + sx, s.pos.Y + sy)
            s.inner.Radius = 5 + s.hover
            show(s.inner, a)
        end

        local target = self.sw[self.sel].pos
        self.ringPos = self.ringPos and vLerp(self.ringPos, target, 1 - math.exp(-16 * dt)) or target
        self.ring.Position = self.ringPos
        self.ring.Radius = 13.5 + math.sin(clock * 4) * 0.6
        show(self.ring, a, 0.9)
    end

    table.insert(self.elements, el)
    return el
end

--==================== Notifications ====================--

local Notifs = {}

function Win:Notify(title, text, dur)
    local n = {t = 0, dur = dur or 4, show = 0}
    n.bg = RoundRect.new(20)
    n.bar = new("Square", {Filled = true, Thickness = 1, ZIndex = 21})
    n.dot = new("Circle", {Filled = true, NumSides = 12, ZIndex = 22})
    n.title = new("Text", {Text = title, Size = 15, Font = FONT, ZIndex = 22, Color = Theme.Text})
    n.text = new("Text", {Text = text, Size = 13, Font = FONT, ZIndex = 22, Color = Theme.SubText})
    n.prog = Gradient.new(16, 22)
    table.insert(Notifs, 1, n)
    return n
end

local function destroyNotif(n)
    n.bg:destroy(); n.prog:destroy()
    kill(n.bar); kill(n.dot); kill(n.title); kill(n.text)
end

local function updateNotifs(dt)
    if #Notifs == 0 then return end
    for i = #Notifs, 1, -1 do
        local n = Notifs[i]
        n.t += dt
        n.show = damp(n.show, n.t < n.dur and 1 or 0, 10, dt)
        if n.t >= n.dur and n.show < 0.02 then
            destroyNotif(n)
            table.remove(Notifs, i)
        end
    end
    if #Notifs == 0 then return end
    local vs = Camera.ViewportSize
    local nw, nh = 290, 66
    for i, n in ipairs(Notifs) do
        local ty = vs.Y - 24 - i * (nh + 10)
        n.y = n.y and damp(n.y, ty, 12, dt) or ty
        local e = n.show
        local x = vs.X - 24 - nw + (1 - e) * (nw + 40)
        local y = n.y
        n.bg:set(x, y, nw, nh, 9, Theme.Panel, e)
        n.bar.Position = Vector2.new(x, y + 12)
        n.bar.Size = Vector2.new(3, nh - 24)
        n.bar.Color = accentAt(0)
        show(n.bar, e)
        n.dot.Position = Vector2.new(x + 20, y + 20)
        n.dot.Radius = 4 + math.sin(clock * 5) * 0.8
        n.dot.Color = accentAt(0.5)
        show(n.dot, e)
        n.title.Position = Vector2.new(x + 32, y + 12)
        show(n.title, e)
        n.text.Position = Vector2.new(x + 16, y + 34)
        show(n.text, e)
        local left = math.clamp(1 - n.t / n.dur, 0, 1)
        n.prog:set(x + 12, y + nh - 7, (nw - 24) * left, 2, e, accentAt)
    end
end

--==================== GAME FUNCTIONS ====================--

local Flags = {
    RecoilEnabled = false,
    RecoilValue = -0.55,
    CheatDetector = false,
    ShowAdmins = false,
    AdminLabels = false,
    Inventory = false,
}

local Offsets = { Player = { AccountAge = 0, UserId = 0 }, BasePart = {} }

local function LoadOffsets()
    local ok, resp = pcall(function()
        return game:HttpGet("https://offsets.imtheo.lol/Offsets.json")
    end)
    if not ok or not resp then
        warn("[Aurora] Failed to grab offsets.")
        return
    end
    local ok2, decoded = pcall(function()
        return HttpService:JSONDecode(resp)
    end)
    if ok2 and decoded and decoded.Offsets then
        Offsets = decoded.Offsets
        if not Offsets.Player then Offsets.Player = { AccountAge = 0, UserId = 0 } end
    end
end
LoadOffsets()

local ModeratorIDs = {
    [51281722] = "Game Moderator", [7178750309] = "Game Moderator", [113179883] = "Game Moderator",
    [3122439095] = "Game Moderator", [991290934] = "Game Moderator", [3968854760] = "Game Moderator",
    [81993536] = "Game Moderator", [1004214871] = "Game Moderator", [3034930770] = "Game Moderator",
    [2364950171] = "Game Moderator", [1528346843] = "Game Moderator", [165053216] = "Game Moderator",
    [1127954045] = "Game Moderator", [3640120679] = "Game Moderator", [602009251] = "Game Moderator",
    [372791101] = "Game Moderator", [1378169111] = "Game Moderator", [3020799797] = "Game Moderator",
    [2567998467] = "Game Moderator", [4243907215] = "Game Moderator", [353983652] = "Game Moderator",
    [1406181681] = "Game Moderator", [2229169589] = "Game Moderator", [3004094651] = "Game Moderator",
    [839333692] = "Game Moderator", [979624578] = "Game Moderator", [1478885961] = "Game Moderator",
    [399754916] = "Game Moderator", [1193091081] = "Game Moderator", [4553863490] = "Game Moderator",
    [4225513035] = "Game Moderator", [41482597] = "Game Moderator", [2924549627] = "Game Moderator",
    [2732967856] = "Game Moderator", [1937516999] = "Game Moderator", [1374319325] = "Game Moderator",
    [1058831985] = "Game Moderator", [9621064456] = "Game Moderator", [584370127] = "Game Moderator",
    [813030262] = "Game Moderator", [3470393585] = "Game Moderator", [122915793] = "Game Moderator",
    [1534692727] = "Game Moderator", [7278178099] = "Game Moderator", [8593140875] = "Game Moderator",
    [2525997354] = "Game Moderator", [3126891654] = "Game Moderator", [1190967808] = "Game Moderator",
    [833946684] = "Game Moderator", [202751467] = "Game Moderator", [510349404] = "Game Moderator",
    [174212818] = "Contribution", [25548179] = "Lead Developer", [363101315] = "Lead Developer",
    [47983795] = "Co-Founder", [16681869] = "Founder",
}

local RoleRank = {
    ["Founder"] = 1, ["Co-Founder"] = 2, ["Lead Developer"] = 3,
    ["Contribution"] = 4, ["Game Moderator"] = 5,
}

local RoleColors = {
    ["Founder"] = Color3.fromRGB(255, 90, 90),
    ["Co-Founder"] = Color3.fromRGB(255, 150, 70),
    ["Lead Developer"] = Color3.fromRGB(90, 200, 255),
    ["Contribution"] = Color3.fromRGB(255, 215, 100),
}
local MOD_COL = Color3.fromRGB(150, 130, 255)
local CHEAT_COL = Color3.fromRGB(255, 70, 85)

local function roleColor(Role)
    return RoleColors[Role] or MOD_COL
end

--==================== player cache ====================--

local PlayerList = {}
local PlayerListT = -1

local function getPlayers()
    local now = tick()
    if now - PlayerListT >= 0.5 then
        PlayerListT = now
        table.clear(PlayerList)
        for _, P in ipairs(Players:GetPlayers()) do
            if P ~= LocalPlayer then
                PlayerList[#PlayerList + 1] = P
            end
        end
    end
    return PlayerList
end

local function getAliveHead(P)
    local Char = P and P.Character
    if not Char then return nil end
    local Hum = Char:FindFirstChild("Humanoid")
    if not Hum or Hum.Health <= 0 then return nil end
    return Char:FindFirstChild("Head")
end

--==================== memoized memory reads ====================--

-- ВАЖНО: исполнитель отдаёт новые объекты Player при каждом GetPlayers(),
-- поэтому все кэши держим по нику, а не по объекту (иначе всё "забывается"
-- каждые 0.5 сек и плашки мигают)

local function pkey(P)
    local ok, n = pcall(function() return P.Name end)
    return ok and n or nil
end

local UserIdCache = {}
local RoleCache = {}
local AgeCache = {}

local function GetUserId(P)
    local k = pkey(P)
    if not k then return nil end
    local id = UserIdCache[k]
    if id then return id end
    local ok, v = pcall(function()
        return memory_read("uintptr_t", P.Address + Offsets.Player.UserId)
    end)
    if ok and type(v) == "number" and v > 0 then
        UserIdCache[k] = v
        return v
    end
    return nil
end

local function GetRole(P)
    local k = pkey(P)
    if not k then return nil end
    local cached = RoleCache[k]
    if cached ~= nil then
        return cached or nil
    end
    local id = GetUserId(P)
    if not id then return nil end
    local role = ModeratorIDs[id] or false
    RoleCache[k] = role
    return role or nil
end

local function GetAge(P)
    local k = pkey(P)
    if not k then return nil end
    local c = AgeCache[k]
    local now = tick()
    if c and (now - c.t) < 60 then
        return c.v
    end
    local ok, v = pcall(function()
        return memory_read("int", P.Address + Offsets.Player.AccountAge)
    end)
    if ok and type(v) == "number" then
        if c then c.v, c.t = v, now else AgeCache[k] = {v = v, t = now} end
        return v
    end
    return nil
end

--==================== recoil ====================--

local function ApplyRecoil(Value)
    local ok, Cache = pcall(getgc, { "RecoilMult" })
    if not ok or not Cache then
        warn("[Aurora] getgc failed")
        return
    end
    local ok2, err = pcall(applygc, Cache, "RecoilMult", Value)
    if not ok2 then
        warn("[Aurora] applygc error: " .. tostring(err))
    end
end

local RecoilQueued, RecoilLastT = nil, 0

local function QueueRecoil(v)
    RecoilQueued = v
end

local function FlushRecoil()
    if RecoilQueued == nil then return end
    local now = tick()
    if now - RecoilLastT < 0.25 then return end
    RecoilLastT = now
    local v = RecoilQueued
    RecoilQueued = nil
    ApplyRecoil(v)
end

local RecoilToggle
local function SetRecoil(On)
    Flags.RecoilEnabled = On and true or false
    RecoilQueued = nil
    if On then ApplyRecoil(Flags.RecoilValue) else ApplyRecoil(1) end
    if RecoilToggle then RecoilToggle.state = Flags.RecoilEnabled end
end

--==================== inventory data ====================--

local BoxCount = 8
local ImageCache = {}
local ImageBaseUrl = "https://raw.githubusercontent.com/sigma4skin/matcha-fallen/main/armor_images/"
local SlotCache = {}
local ArmorViewerTarget
local ArmorLastUpdate = 0
local ARMOR_INTERVAL = 3

local function GetImage(ArmorId)
    if not ArmorId then return nil end
    local Cached = ImageCache[ArmorId]
    if Cached ~= nil then return Cached or nil end
    ImageCache[ArmorId] = false
    task.spawn(function()
        local Ok, Data = pcall(function() return game:HttpGet(ImageBaseUrl .. ArmorId .. ".png") end)
        ImageCache[ArmorId] = (Ok and Data) or false
    end)
    return nil
end

local function RebuildSlotCache(Char)
    table.clear(SlotCache)
    if not Char then return end
    local Seen = {}
    local Idx = 1
    for _, Child in Char:GetChildren() do
        if Idx > BoxCount then break end
        local ArmorId = Child.Name:match("^Armor_%d+")
        if ArmorId and not Seen[ArmorId] then
            Seen[ArmorId] = true
            SlotCache[Idx] = { ArmorId = ArmorId, Icon = GetImage(ArmorId) }
            Idx += 1
        end
    end
end

local function UpdateSlotCacheImages()
    for _, Slot in SlotCache do
        if Slot and not Slot.Icon then
            local Img = ImageCache[Slot.ArmorId]
            if Img then Slot.Icon = Img end
        end
    end
end

local TargetCache = {t = 0, p = nil}

local function FindClosestTarget()
    local now = tick()
    local cp = TargetCache.p
    if cp and (now - TargetCache.t) < 0.3 and getAliveHead(cp) then
        return cp
    end

    local mx, my = CurMouse.X, CurMouse.Y
    local Closest, Best = nil, math.huge
    for _, P in ipairs(getPlayers()) do
        local Head = getAliveHead(P)
        if Head then
            local Screen, OnScreen = WorldToScreen(Head.Position)
            if OnScreen and Screen then
                local dx = (tonumber(Screen.X) or 0) - mx
                local dy = (tonumber(Screen.Y) or 0) - my
                local d = dx * dx + dy * dy
                if d < Best then
                    Best = d
                    Closest = P
                end
            end
        end
    end

    TargetCache.p = Closest
    TargetCache.t = now
    return Closest
end

--==================== ADMIN PANEL ====================--

local AP = {
    alpha = 0, h = 0, list = {}, scanT = -1, rows = {},
    hidden = true, empty = 0, hover = 0,
    W = 250, HEADH = 44, ROWH = 38,
}
AP.shadow = RoundRect.new(95)
AP.border = RoundRect.new(98, true, 96)
AP.bg = RoundRect.new(97)
AP.line = Gradient.new(28, 101)
AP.liveGlow = new("Circle", {Filled = true, NumSides = 18, ZIndex = 101})
AP.live = new("Circle", {Filled = true, NumSides = 14, ZIndex = 102, Radius = 4})
AP.title = new("Text", {Text = "ACTIVE ADMINS", Size = 14, Font = FONT, ZIndex = 102, Color = Theme.Text})
AP.pill = RoundRect.new(101)
AP.countText = new("Text", {Text = "0", Size = 13, Font = FONT, ZIndex = 102})
AP.emptyText = new("Text", {Text = "No admins online", Size = 13, Font = FONT, ZIndex = 102, Color = Theme.SubText})
AP.grip = newGrip(102)

local function getAdminRow(i)
    local r = AP.rows[i]
    if r then return r end
    r = {
        anim = 0, hidden = true,
        sep = new("Line", {Thickness = 1, ZIndex = 101, Color = Theme.Stroke}),
        glow = new("Circle", {Filled = true, NumSides = 16, ZIndex = 101}),
        dot = new("Circle", {Filled = true, NumSides = 12, ZIndex = 102, Radius = 4}),
        role = new("Text", {Text = "", Size = 12, Font = FONT, ZIndex = 102}),
        name = new("Text", {Text = "", Size = 14, Font = FONT, ZIndex = 102, Color = Theme.Text}),
    }
    AP.rows[i] = r
    return r
end

local function hideAdminRow(r)
    if r.hidden then return end
    r.hidden = true
    show(r.sep, 0); show(r.glow, 0); show(r.dot, 0); show(r.role, 0); show(r.name, 0)
end

local function hideAdminPanel()
    AP.shadow:hide(); AP.border:hide(); AP.bg:hide(); AP.pill:hide()
    AP.line:set(0, 0, 0, 0, 0)
    show(AP.liveGlow, 0); show(AP.live, 0)
    show(AP.title, 0); show(AP.countText, 0); show(AP.emptyText, 0)
    hideGrip(AP.grip)
    for _, r in ipairs(AP.rows) do
        r.anim = 0
        hideAdminRow(r)
    end
end

local function adminSort(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.name < b.name
end

local function scanAdmins()
    local list = AP.list
    table.clear(list)
    for _, P in ipairs(getPlayers()) do
        local role = GetRole(P)
        if role then
            list[#list + 1] = {name = P.Name, role = role, rank = RoleRank[role] or 9}
        end
    end
    table.sort(list, adminSort)
end

local function renderAdminPanel(dt)
    local on = Flags.ShowAdmins
    AP.alpha = damp(AP.alpha, on and 1 or 0, 10, dt)
    if not on and AP.alpha <= 0 then
        if not AP.hidden then
            AP.hidden = true
            AP.h = 0
            hideAdminPanel()
        end
        return
    end
    AP.hidden = false

    local now = tick()
    if on and now - AP.scanT >= 0.5 then
        AP.scanT = now
        scanAdmins()
    end

    local list = AP.list
    local n = #list
    local w, hh, rh = AP.W, AP.HEADH, AP.ROWH
    local targetH = hh + math.max(n, 1) * rh + 8
    AP.h = AP.h > 0 and damp(AP.h, targetH, 14, dt) or targetH

    local a = AP.alpha
    local op = Settings.hudOpacity
    local e = 1 - (1 - a) ^ 3
    local h = math.floor(AP.h + 0.5)
    local vs = Camera.ViewportSize
    local bx, by = panelPos(AP, vs.X - w - 18, 18, w, h, dt)
    local x = math.floor(bx + (1 - e) * 40 + 0.5)
    local y = by

    AP.headRect = {x, y, w, hh}
    local canDrag = Win.open and Win.alpha > 0.3
    local hov = canDrag and (inRect(CurMouse, AP.headRect) or dragTarget == AP)
    if hov then HoverAny = true end
    AP.hover = damp(AP.hover, hov and 1 or 0, 12, dt)

    -- полупрозрачный корпус: фон * hudOpacity, текст остаётся чётким
    AP.shadow:set(x + 3, y + 5, w, h, 11, SHADOW_COL, a * 0.3 * op)
    local bk = (0.5 + 0.35 * AP.hover) * pulseK(2)
    AP.border:set(x - 1, y - 1, w + 2, h + 2, 11, cMix(Theme.Bg, accentAt(0.3), bk), a * math.min(1, op + 0.2))
    AP.bg:set(x, y, w, h, 10, Theme.Bg, a * op)
    AP.line:set(x + 6, y + hh - 2, w - 12, 2, a, accentAt, edgeFade)

    local pulse = (clock * 0.9) % 1
    local liveCol = n > 0 and Color3.fromRGB(255, 80, 95) or Color3.fromRGB(70, 225, 140)
    local lp = Vector2.new(x + 18, y + hh / 2 - 1)
    AP.live.Position = lp
    AP.live.Color = liveCol
    show(AP.live, a)
    AP.liveGlow.Position = lp
    AP.liveGlow.Radius = 4 + pulse * 7
    AP.liveGlow.Color = liveCol
    show(AP.liveGlow, a, 0.45 * (1 - pulse))

    local tb = bounds(AP.title)
    AP.title.Position = Vector2.new(x + 30, y + (hh - tb.Y) / 2 - 1)
    show(AP.title, a)

    setText(AP.countText, tostring(n))
    local cb = bounds(AP.countText)
    local pw = math.max(24, cb.X + 14)
    local px, py = x + w - 14 - pw, y + hh / 2 - 11
    local acc = accentAt(0.6)
    AP.pill:set(px, py, pw, 20, 10, cMix(Theme.Panel, acc, 0.3), a * math.min(1, op + 0.15))
    AP.countText.Position = Vector2.new(px + (pw - cb.X) / 2, py + (20 - cb.Y) / 2)
    AP.countText.Color = cMix(Theme.Text, acc, 0.5)
    show(AP.countText, a)

    setGrip(AP.grip, px - 16, y + hh / 2 - 5, a * Win.alpha * (0.45 + 0.55 * AP.hover),
        AP.hover > 0.01 and cMix(Theme.SubText, accentAt(0.5), AP.hover) or nil)

    AP.empty = damp(AP.empty, n == 0 and 1 or 0, 12, dt)
    AP.emptyText.Position = Vector2.new(x + 16 + (1 - AP.empty) * 8, y + hh + 12)
    show(AP.emptyText, a * AP.empty)

    local bottom = y + h - 4
    local rowsN = math.max(n, #AP.rows)
    for i = 1, rowsN do
        local entry = list[i]
        local r = entry and getAdminRow(i) or AP.rows[i]
        if r then
            r.anim = damp(r.anim, entry and 1 or 0, 12, dt)
            if r.anim <= 0 then
                hideAdminRow(r)
            else
                r.hidden = false
                if entry then
                    setText(r.name, entry.name)
                    if r.roleT ~= entry.role then
                        r.roleT = entry.role
                        setText(r.role, entry.role)
                        local col = roleColor(entry.role)
                        r.role.Color = col
                        r.dot.Color = col
                        r.glow.Color = col
                    end
                end

                local ry = y + hh + (i - 1) * rh + 4
                local clip = math.clamp((bottom - (ry + rh - 6)) / 8, 0, 1)
                local ra = a * r.anim * clip
                local slide = (1 - r.anim) * 14

                if i > 1 then
                    r.sep.From = Vector2.new(x + 14, ry - 2)
                    r.sep.To = Vector2.new(x + w - 14, ry - 2)
                    show(r.sep, ra, 0.5)
                else
                    show(r.sep, 0)
                end

                local dp = Vector2.new(x + 22 + slide, ry + 17)
                r.dot.Position = dp
                show(r.dot, ra)
                local gp = (clock * 0.8 + i * 0.27) % 1
                r.glow.Position = dp
                r.glow.Radius = 4 + gp * 6
                show(r.glow, ra, 0.35 * (1 - gp))

                r.role.Position = Vector2.new(x + 36 + slide, ry + 2)
                show(r.role, ra)
                r.name.Position = Vector2.new(x + 36 + slide, ry + 16)
                show(r.name, ra)
            end
        end
    end
end

--==================== INVENTORY PANEL ====================--

local IV = {alpha = 0, hidden = true, hover = 0, rhover = 0, slots = {}, hasTarget = 0, distT = 0}
IV.shadow = RoundRect.new(89)
IV.border = RoundRect.new(92, true, 90)
IV.bg = RoundRect.new(91)
IV.line = Gradient.new(40, 93)
IV.avGlow = new("Circle", {Filled = true, NumSides = 20, ZIndex = 94})
IV.avA = new("Circle", {Filled = true, NumSides = 16, ZIndex = 95})
IV.avB = new("Circle", {Filled = true, NumSides = 16, ZIndex = 95})
IV.avCore = new("Circle", {Filled = true, NumSides = 10, ZIndex = 96, Color = WHITE})
IV.name = new("Text", {Text = "No target", Size = 15, Font = FONT, ZIndex = 95, Color = Theme.Text})
IV.sub = new("Text", {Text = "", Size = 12, Font = FONT, ZIndex = 95, Color = Theme.SubText})
IV.pill = RoundRect.new(94)
IV.count = new("Text", {Text = "0/" .. BoxCount, Size = 13, Font = FONT, ZIndex = 95})
IV.grip = newGrip(95)
IV.rs1 = new("Line", {Thickness = 1.5, ZIndex = 96})
IV.rs2 = new("Line", {Thickness = 1.5, ZIndex = 96})

for i = 1, BoxCount do
    IV.slots[i] = {
        ring = RoundRect.new(95, true, 93),
        card = RoundRect.new(94),
        sheen = new("Line", {Thickness = 1, ZIndex = 96, Color = WHITE}),
        shimmer = new("Square", {Filled = true, Thickness = 1, ZIndex = 96}),
        img = new("Image", {ZIndex = 97}),
        idx = new("Text", {Text = tostring(i), Size = 12, Font = FONT, ZIndex = 96, Color = Theme.SubText}),
        fill = 0, pop = 0, iconA = 0, hover = 0, icon = nil,
    }
end

local function hideInventory()
    IV.shadow:hide(); IV.border:hide(); IV.bg:hide(); IV.pill:hide()
    IV.line:set(0, 0, 0, 0, 0)
    show(IV.avGlow, 0); show(IV.avA, 0); show(IV.avB, 0); show(IV.avCore, 0)
    show(IV.name, 0); show(IV.sub, 0); show(IV.count, 0)
    show(IV.rs1, 0); show(IV.rs2, 0)
    hideGrip(IV.grip)
    for _, s in ipairs(IV.slots) do
        s.ring:hide(); s.card:hide()
        show(s.sheen, 0); show(s.shimmer, 0); show(s.img, 0); show(s.idx, 0)
    end
end

-- размеры инвентаря от масштаба
local function invLayout(S)
    local slot = math.floor(56 * S + 0.5)
    local gap = math.max(3, math.floor(8 * S + 0.5))
    local pad = math.max(6, math.floor(12 * S + 0.5))
    local head = math.max(26, math.floor(40 * S + 0.5))
    local w = pad * 2 + BoxCount * slot + (BoxCount - 1) * gap
    local h = head + math.floor(10 * S + 0.5) + slot + pad
    return slot, gap, pad, head, w, h
end

local function renderInventory(dt)
    local on = Flags.Inventory
    local target = nil
    if on then
        target = FindClosestTarget()
        if target and not target.Character then target = nil end
    end

    if on and target then
        local now = tick()
        local tk = pkey(target)
        if ArmorViewerTarget ~= tk or now - ArmorLastUpdate >= ARMOR_INTERVAL then
            ArmorLastUpdate = now
            ArmorViewerTarget = tk
            RebuildSlotCache(target.Character)
        else
            UpdateSlotCacheImages()
        end
    elseif ArmorViewerTarget then
        ArmorViewerTarget = nil
        table.clear(SlotCache)
    end

    local want = on and (target ~= nil or Win.open)
    IV.alpha = damp(IV.alpha, want and 1 or 0, 10, dt)
    if not want and IV.alpha <= 0 then
        if not IV.hidden then
            IV.hidden = true
            hideInventory()
        end
        return
    end
    IV.hidden = false

    local S = Settings.invScale
    local SLOT, GAP, PAD, HEAD, IW, IH = invLayout(S)

    -- размеры текста/кружков меняем только при смене масштаба
    if IV.lastS ~= S then
        IV.lastS = S
        setSize(IV.name, math.max(10, math.floor(15 * S + 0.5)))
        setSize(IV.sub, math.max(9, math.floor(12 * S + 0.5)))
        setSize(IV.count, math.max(9, math.floor(13 * S + 0.5)))
        IV.avA.Radius = 6 * S
        IV.avB.Radius = 6 * S
        IV.avCore.Radius = 2.5 * S
        for _, s in ipairs(IV.slots) do
            setSize(s.idx, math.max(9, math.floor(12 * S + 0.5)))
            s.ix = nil
        end
    end

    local a = IV.alpha
    local op = Settings.hudOpacity
    local e = 1 - (1 - a) ^ 3
    local vs = Camera.ViewportSize
    local bx, by = panelPos(IV, (vs.X - IW) / 2, 18, IW, IH, dt)
    local x = bx
    local y = math.floor(by - (1 - e) * 20 + 0.5)

    IV.headRect = {x, y, IW, HEAD}
    IV.resizeRect = {x + IW - 18, y + IH - 18, 18, 18}
    IV.w, IV.h = IW, IH
    local canDrag = Win.open and Win.alpha > 0.3
    local hov = canDrag and (inRect(CurMouse, IV.headRect) or dragTarget == IV)
    local rhov = canDrag and (inRect(CurMouse, IV.resizeRect) or IV.resizing ~= nil)
    if hov or rhov then HoverAny = true end
    IV.hover = damp(IV.hover, hov and 1 or 0, 12, dt)
    IV.rhover = damp(IV.rhover, rhov and 1 or 0, 12, dt)
    IV.hasTarget = damp(IV.hasTarget, target and 1 or 0, 10, dt)

    local rad = math.max(6, math.floor(12 * S + 0.5))
    IV.shadow:set(x + 3, y + 5, IW, IH, rad + 1, SHADOW_COL, a * 0.3 * op)
    local bk = (0.45 + 0.35 * math.max(IV.hover, IV.rhover)) * pulseK(2, 1.3)
    IV.border:set(x - 1, y - 1, IW + 2, IH + 2, rad + 1, cMix(Theme.Bg, accentAt(0.5), bk), a * math.min(1, op + 0.2))
    IV.bg:set(x, y, IW, IH, rad, Theme.Bg, a * op)
    IV.line:set(x + 6, y + HEAD - 2, IW - 12, 2, a, accentAt, edgeFade)

    -- аватар
    local acx, acy = x + math.floor(22 * S), y + HEAD / 2 - 1
    local orb = 3 * S
    local ox, oy = math.cos(clock * 2) * orb, math.sin(clock * 2) * orb
    local ta = a * (0.35 + 0.65 * IV.hasTarget)
    IV.avA.Position = Vector2.new(acx + ox, acy + oy)
    IV.avA.Color = Theme.AccentA
    IV.avB.Position = Vector2.new(acx - ox, acy - oy)
    IV.avB.Color = Theme.AccentB
    IV.avCore.Position = Vector2.new(acx, acy)
    show(IV.avA, ta, 0.85); show(IV.avB, ta, 0.85); show(IV.avCore, ta)
    local gp = (clock * 0.7) % 1
    IV.avGlow.Position = Vector2.new(acx, acy)
    IV.avGlow.Radius = (9 + gp * 7) * S
    IV.avGlow.Color = accentAt(0.4)
    show(IV.avGlow, a * IV.hasTarget, 0.3 * (1 - gp))

    local filled = 0
    for i = 1, BoxCount do if SlotCache[i] then filled += 1 end end
    setText(IV.name, target and target.Name or "No target")
    local now = tick()
    if now - IV.distT > 0.25 then
        IV.distT = now
        local sub = "aim at a player"
        if target then
            local head = getAliveHead(target)
            local d = (head and CamPos) and math.floor((head.Position - CamPos).Magnitude) or 0
            sub = d .. "m  |  " .. filled .. (filled == 1 and " item" or " items")
        end
        setText(IV.sub, sub)
    end
    local nb, sb = bounds(IV.name), bounds(IV.sub)
    local tx = x + math.floor(40 * S)
    local ty0 = y + math.floor((HEAD - nb.Y - sb.Y) / 2) - 1
    IV.name.Position = Vector2.new(tx, ty0)
    IV.name.Color = cLerp(Theme.SubText, Theme.Text, IV.hasTarget)
    show(IV.name, a)
    IV.sub.Position = Vector2.new(tx, ty0 + nb.Y)
    show(IV.sub, a, 0.9)

    setText(IV.count, filled .. "/" .. BoxCount)
    local cb = bounds(IV.count)
    local ph = math.floor(20 * S + 0.5)
    local pw = math.max(math.floor(34 * S), cb.X + 16)
    local px, py = x + IW - PAD - pw, y + math.floor((HEAD - ph) / 2) - 1
    local acc = accentAt(0.7)
    IV.pill:set(px, py, pw, ph, ph / 2, cMix(Theme.Panel, acc, 0.3), a * math.min(1, op + 0.15))
    IV.count.Position = Vector2.new(px + (pw - cb.X) / 2, py + (ph - cb.Y) / 2)
    IV.count.Color = cMix(Theme.Text, acc, 0.5)
    show(IV.count, a)

    setGrip(IV.grip, px - 16, y + HEAD / 2 - 5, a * Win.alpha * (0.45 + 0.55 * IV.hover),
        IV.hover > 0.01 and cMix(Theme.SubText, accentAt(0.5), IV.hover) or nil)

    -- уголок для изменения размера
    local rx, ry = x + IW - 5, y + IH - 5
    local rcol = cMix(Theme.SubText, accentAt(0.8), IV.rhover)
    IV.rs1.From = Vector2.new(rx, ry - 9)
    IV.rs1.To = Vector2.new(rx - 9, ry)
    IV.rs2.From = Vector2.new(rx, ry - 4)
    IV.rs2.To = Vector2.new(rx - 4, ry)
    IV.rs1.Color = rcol
    IV.rs2.Color = rcol
    local ra = a * Win.alpha * (0.5 + 0.5 * IV.rhover)
    show(IV.rs1, ra); show(IV.rs2, ra)

    -- слоты
    local sy = y + HEAD + math.floor(10 * S + 0.5)
    local srad = math.max(4, math.floor(9 * S + 0.5))
    local inset = math.max(3, math.floor(5 * S + 0.5))
    for i = 1, BoxCount do
        local s = IV.slots[i]
        local data = SlotCache[i]
        local icon = data and data.Icon or nil
        local sx = x + PAD + (i - 1) * (SLOT + GAP)
        local p = i / BoxCount

        s.fill = damp(s.fill, data and 1 or 0, 12, dt)
        if icon ~= s.icon then
            s.icon = icon
            if icon then
                pcall(function() s.img.Data = icon end)
                s.pop = 1
                s.iconA = 0
            end
        end
        s.pop = damp(s.pop, 0, 9, dt)
        s.iconA = damp(s.iconA, icon and 1 or 0, 10, dt)
        local sh = canDrag and not IV.resizing and inRect(CurMouse, {sx, sy, SLOT, SLOT})
        s.hover = damp(s.hover, sh and 1 or 0, 14, dt)

        local lift = math.floor(s.hover * 2 + 0.5)
        local sry = sy - lift
        local acol = accentAt(p)
        s.ring:set(sx - 1, sry - 1, SLOT + 2, SLOT + 2, srad + 1,
            cMix(Theme.Stroke, acol, s.fill * (0.7 + 0.3 * s.hover)), a * math.min(1, op + 0.2))
        s.card:set(sx, sry, SLOT, SLOT, srad,
            cMix(Theme.Element, acol, 0.08 * s.fill + 0.06 * s.hover), a * op)

        s.sheen.From = Vector2.new(sx + srad, sry + 1)
        s.sheen.To = Vector2.new(sx + SLOT - srad, sry + 1)
        show(s.sheen, a, 0.06 + 0.06 * s.hover)

        if data and not icon then
            local t = (clock * 1.1 + i * 0.13) % 1
            local shw = math.max(6, math.floor(12 * S))
            s.shimmer.Position = Vector2.new(math.floor(sx + inset + t * (SLOT - inset * 2 - shw)), sry + inset)
            s.shimmer.Size = Vector2.new(shw, SLOT - inset * 2)
            s.shimmer.Color = acol
            show(s.shimmer, a, 0.22 * math.sin(t * math.pi))
        else
            show(s.shimmer, 0)
        end

        local ib = bounds(s.idx)
        s.idx.Position = Vector2.new(sx + (SLOT - ib.X) / 2, sry + (SLOT - ib.Y) / 2)
        show(s.idx, a, (1 - s.fill) * 0.45)

        if s.icon and s.iconA > 0.01 then
            local isz = math.floor((SLOT - inset * 2) * (1 - 0.15 * s.pop) + 0.5)
            local ix = sx + math.floor((SLOT - isz) / 2)
            local iy = sry + math.floor((SLOT - isz) / 2)
            if s.ix ~= ix or s.iy ~= iy or s.isz ~= isz then
                s.ix, s.iy, s.isz = ix, iy, isz
                s.img.Position = Vector2.new(ix, iy)
                s.img.Size = Vector2.new(isz, isz)
            end
            show(s.img, a * s.iconA)
        else
            show(s.img, 0)
        end
    end
end

--==================== NAMEPLATES (admin / cheater) ====================--
-- мигание было из-за того, что WorldToScreen/Humanoid иногда на кадр отдают "нет":
-- теперь плашка держится 0.3 сек после последнего успешного кадра и
-- позиция сглаживается, а ширина не прыгает от смены дистанции.

local Plates = {}
local platesActive = 0
local CheaterState = {}  -- [ник] = причина / false
local CheaterScanT = 0
local PLATE_OFF = Vector3.new(0, 2.6, 0)
local PLATE_MAX_DIST = 1500
local PLATE_GRACE = 0.3

local function IsCheater(Player)
    local Age = GetAge(Player)
    if Age and Age <= 60 then return "new account" end
    local Char = Player.Character
    local Hrp = Char and Char:FindFirstChild("HumanoidRootPart")
    if not Hrp then return false end
    local ok, vel = pcall(function() return Hrp.Velocity end)
    if ok and vel and (vel.Y <= -1000 or vel.Y >= 1000) then return "velocity" end
    return false
end

local function newPlate()
    return {
        a = 0, hidden = true, lastT = 0, ph = math.random() * 6.28, distT = 0,
        border = RoundRect.new(13, true, 11),
        bg = RoundRect.new(12),
        bar = new("Square", {Filled = true, Thickness = 1, ZIndex = 14}),
        title = new("Text", {Text = "", Size = 13, Font = FONT, ZIndex = 15}),
        name = new("Text", {Text = "", Size = 12, Font = FONT, ZIndex = 15, Color = Theme.Text}),
        dist = new("Text", {Text = "", Size = 11, Font = FONT, ZIndex = 15, Color = Theme.SubText}),
        tri = tryNew("Triangle", {Filled = true, Thickness = 1, ZIndex = 12}),
    }
end

local function hidePlate(pl)
    pl.border:hide(); pl.bg:hide()
    show(pl.bar, 0); show(pl.title, 0); show(pl.name, 0); show(pl.dist, 0); show(pl.tri, 0)
end

local function destroyPlate(pl)
    pl.border:destroy(); pl.bg:destroy()
    kill(pl.bar); kill(pl.title); kill(pl.name); kill(pl.dist); kill(pl.tri)
end

local function drawPlate(pl, dt)
    local a = pl.a
    local op = Settings.hudOpacity
    local col = pl.col or MOD_COL
    local tb, nb, db = bounds(pl.title), bounds(pl.name), bounds(pl.dist)
    local inner = math.max(tb.X + 12 + db.X, nb.X)
    local tw = math.ceil((inner + 24) / 8) * 8
    pl.w = pl.w and damp(pl.w, tw, 16, dt) or tw
    local w = math.floor(pl.w + 0.5)
    local h = 34
    local cx = math.floor(pl.sx + 0.5)
    local x = cx - math.floor(w / 2)
    local y = math.floor(pl.sy - h - 8 + 0.5)

    local bcol = cMix(Theme.Bg, col, 0.65 * pulseK(3, pl.ph, 0.7))
    pl.border:set(x - 1, y - 1, w + 2, h + 2, 7, bcol, a * math.min(1, op + 0.25))
    pl.bg:set(x, y, w, h, 6, Theme.Bg, a * math.min(1, op + 0.1))

    pl.bar.Position = Vector2.new(x + 5, y + 7)
    pl.bar.Size = Vector2.new(2, h - 14)
    pl.bar.Color = col
    show(pl.bar, a)

    pl.title.Position = Vector2.new(x + 13, y + 4)
    show(pl.title, a)
    pl.dist.Position = Vector2.new(x + w - 9 - db.X, y + 5)
    show(pl.dist, a, 0.85)
    pl.name.Position = Vector2.new(x + 13, y + 18)
    show(pl.name, a, 0.9)

    if pl.tri then
        pl.tri.PointA = Vector2.new(cx - 5, y + h)
        pl.tri.PointB = Vector2.new(cx + 5, y + h)
        pl.tri.PointC = Vector2.new(cx, y + h + 5)
        pl.tri.Color = bcol
        show(pl.tri, a * math.min(1, op + 0.25))
    end
end

local function renderPlates(dt)
    local cheatOn, adminOn = Flags.CheatDetector, Flags.AdminLabels
    if not cheatOn and not adminOn and platesActive == 0 then return end
    local players = getPlayers()
    local now = tick()

    if cheatOn then
        if now - CheaterScanT >= 3 then
            CheaterScanT = now
            for _, P in ipairs(players) do
                local k = pkey(P)
                if k and not CheaterState[k] then
                    CheaterState[k] = IsCheater(P)
                end
            end
        end
    elseif next(CheaterState) then
        table.clear(CheaterState)
    end

    for _, P in ipairs(players) do
        local role = adminOn and GetRole(P) or nil
        local key = pkey(P)
        local cheat = cheatOn and key and CheaterState[key] or nil
        if role or cheat then
            local head = getAliveHead(P)
            if head then
                local hp = head.Position
                local d = CamPos and (hp - CamPos).Magnitude or 0
                if d <= PLATE_MAX_DIST then
                    local s, onS = WorldToScreen(hp + PLATE_OFF)
                    local sx, sy = s and tonumber(s.X), s and tonumber(s.Y)
                    if onS and sx and sy and key then
                        local pl = Plates[key]
                        if not pl then
                            pl = newPlate()
                            Plates[key] = pl
                        end
                        pl.lastT = now
                        -- сглаживание: большие скачки (поворот камеры) - сразу, мелкая дрожь - плавно
                        if not pl.sx or math.abs(pl.sx - sx) + math.abs(pl.sy - sy) > 60 then
                            pl.sx, pl.sy = sx, sy
                        else
                            pl.sx = damp(pl.sx, sx, 40, dt)
                            pl.sy = damp(pl.sy, sy, 40, dt)
                        end

                        local title = role and string.upper(role) or "CHEATER"
                        if role and cheat then title = title .. "  /  CHEATER" end
                        if pl.titleT ~= title then
                            pl.titleT = title
                            setText(pl.title, title)
                            pl.col = role and roleColor(role) or CHEAT_COL
                            pl.title.Color = pl.col
                        end
                        setText(pl.name, cheat and (P.Name .. "  -  " .. cheat) or P.Name)
                        if now - pl.distT > 0.25 then
                            pl.distT = now
                            setText(pl.dist, math.floor(d) .. "m")
                        end
                    end
                end
            end
        end
    end

    platesActive = 0
    for key, pl in pairs(Plates) do
        local want = (now - pl.lastT) < PLATE_GRACE
            and ((adminOn and RoleCache[key]) or (cheatOn and CheaterState[key])) and true or false
        pl.a = damp(pl.a, want and 1 or 0, 12, dt)
        if not want and pl.a <= 0.01 then
            pl.a = 0
            if not pl.hidden then
                pl.hidden = true
                hidePlate(pl)
            end
            if now - pl.lastT > 15 then
                destroyPlate(pl)
                Plates[key] = nil
            end
        else
            pl.hidden = false
            platesActive += 1
            drawPlate(pl, dt)
        end
    end
end

--==================== CURSOR HALO ====================--

local Cur = {a = 0, hover = 0, press = 0, hidden = true}
Cur.glow = new("Circle", {Filled = true, NumSides = 24, ZIndex = 250})
Cur.ring = new("Circle", {Filled = false, Thickness = 1.5, NumSides = 28, ZIndex = 251})

local function renderCursor(dt)
    local want = Settings.cursor and Win.open and not Win.destroyed
    Cur.a = damp(Cur.a, want and 1 or 0, 14, dt)
    if Cur.a <= 0 then
        if not Cur.hidden then
            Cur.hidden = true
            show(Cur.glow, 0); show(Cur.ring, 0)
        end
        return
    end
    Cur.hidden = false
    local m = CurMouse
    if not Cur.x then Cur.x, Cur.y = m.X, m.Y end
    Cur.x = damp(Cur.x, m.X, 26, dt)
    Cur.y = damp(Cur.y, m.Y, 26, dt)
    Cur.hover = damp(Cur.hover, HoverAny and 1 or 0, 14, dt)
    Cur.press = damp(Cur.press, (MouseDown or dragTarget or IV.resizing) and 1 or 0, 20, dt)

    local p = Vector2.new(Cur.x, Cur.y)
    local r = 9 + 5 * Cur.hover - 3 * Cur.press
    Cur.ring.Position = p
    Cur.ring.Radius = r
    Cur.ring.Color = accentAt(0.5)
    show(Cur.ring, Cur.a, 0.9)
    Cur.glow.Position = p
    Cur.glow.Radius = r + 5
    Cur.glow.Color = accentAt(0.2)
    show(Cur.glow, Cur.a, 0.1 + 0.1 * Cur.hover)
end

--==================== RENDER ====================--

local function renderBody(dt)
    if Win.destroyed then return end
    local m = CurMouse

    Theme.AccentA = cLerp(Theme.AccentA, targetA, 1 - math.exp(-14 * dt))
    Theme.AccentB = cLerp(Theme.AccentB, targetB, 1 - math.exp(-14 * dt))

    Win.alpha = damp(Win.alpha, Win.open and 1 or 0, 12, dt)
    Win.intro = damp(Win.intro, Win.open and 1 or 0, 7, dt)
    Win.x = damp(Win.x, Win.tx, 28, dt)
    Win.y = damp(Win.y, Win.ty, 28, dt)

    if not Win.open and Win.alpha <= 0 then
        if Win.sleeping then
            updateNotifs(dt)
            return
        end
        Win.sleeping = true
    else
        Win.sleeping = false
    end

    local a = Win.alpha
    local ox = math.floor(Win.x + 0.5)
    local oy = math.floor(Win.y + (1 - Win.intro) * 30 + 0.5)

    V.glowAnim = damp(V.glowAnim, Settings.glow and 1 or 0, 8, dt)
    if V.glowAnim > 0 or not V.glowHidden then
        V.glowHidden = V.glowAnim <= 0
        local pulse = Settings.pulse and (0.6 + 0.4 * math.sin(clock * 2)) or 1
        local n = #V.glow
        for i, g in ipairs(V.glow) do
            local d = i * 3
            g.Position = Vector2.new(ox - d, oy - d)
            g.Size = Vector2.new(W + d * 2, H + d * 2)
            g.Color = accentAt(i / n)
            local k = 1 - (i - 1) / n
            show(g, a, 0.4 * k * k * pulse * V.glowAnim * Settings.glowPower)
        end
    end

    V.bg:set(ox, oy, W, H, R, Theme.Bg, a)
    V.side:set(ox, oy, SIDEBAR, H, R, Theme.Panel, a)
    V.sideFix.Position = Vector2.new(ox + SIDEBAR - R, oy)
    V.sideFix.Size = Vector2.new(R, H)
    show(V.sideFix, a)
    V.sideLine.From = Vector2.new(ox + SIDEBAR, oy + 14)
    V.sideLine.To = Vector2.new(ox + SIDEBAR, oy + H - 14)
    show(V.sideLine, a, 0.7)
    V.topBar:set(ox + R, oy, W - R * 2, 2, a, accentAt)
    V.topGlow:set(ox + R, oy + 2, W - R * 2, 3, a * 0.22, accentAt, edgeFade)

    V.blob1.Position = Vector2.new(ox + W - 100 + math.sin(clock * 0.7) * 20, oy + H - 90 + math.cos(clock * 0.5) * 12)
    V.blob1.Radius = 70
    V.blob1.Color = Theme.AccentA
    show(V.blob1, a, 0.07)
    V.blob2.Position = Vector2.new(ox + SIDEBAR + 110 + math.cos(clock * 0.6) * 25, oy + HEADER + 70 + math.sin(clock * 0.8) * 12)
    V.blob2.Radius = 55
    V.blob2.Color = Theme.AccentB
    show(V.blob2, a, 0.06)

    particleAnim = damp(particleAnim, Settings.particles and 1 or 0, 6, dt)
    if particleAnim > 0 or not V.particlesHidden then
        V.particlesHidden = particleAnim <= 0
        local pw, ph = W - SIDEBAR - 12, H - HEADER - 12
        for _, p in ipairs(Particles) do
            p.y -= p.s * dt * Settings.speed
            if p.y < 0 then p.y = 1; p.x = math.random() end
            p.o.Position = Vector2.new(
                ox + SIDEBAR + 6 + p.x * pw + math.sin(clock + p.ph) * 4,
                oy + HEADER + 6 + p.y * ph
            )
            p.o.Color = accentAt(p.x)
            local edge = math.clamp(math.min(p.y, 1 - p.y) * 6, 0, 1)
            show(p.o, a, (0.25 + 0.35 * math.sin(clock * 2 + p.ph)) * edge * particleAnim)
        end
    end

    local lcx, lcy = ox + 28, oy + 28
    local orbitX = math.cos(clock * 2) * 4
    local orbitY = math.sin(clock * 2) * 4
    V.logoA.Position = Vector2.new(lcx + orbitX, lcy + orbitY)
    V.logoA.Color = Theme.AccentA
    V.logoB.Position = Vector2.new(lcx - orbitX, lcy - orbitY)
    V.logoB.Color = Theme.AccentB
    V.logoCore.Position = Vector2.new(lcx, lcy)
    show(V.logoA, a, 0.85); show(V.logoB, a, 0.85); show(V.logoCore, a)

    V.title.Position = Vector2.new(ox + 46, oy + 14)
    show(V.title, a)
    V.subtitle.Position = Vector2.new(ox + 46, oy + 33)
    show(V.subtitle, a)
    V.sideDiv:set(ox + 14, oy + HEADER + 4, SIDEBAR - 28, 1, a, accentAt, edgeFade)

    local tabY0 = oy + HEADER + 18
    Win.indicatorY = damp(Win.indicatorY, (Win.active - 1) * 38, 16, dt)
    V.indicator:set(ox + 10, tabY0 + Win.indicatorY, SIDEBAR - 20, 32, 8, Theme.Element, a)
    V.indicatorBar.Position = Vector2.new(ox + 10, tabY0 + Win.indicatorY + 8)
    V.indicatorBar.Color = accentAt(0.2)
    show(V.indicatorBar, a)

    local active = Win.tabs[Win.active]
    local tabCount = math.max(1, #Win.tabs)
    for i, tab in ipairs(Win.tabs) do
        local ty = tabY0 + (i - 1) * 38
        local isActive = i == Win.active
        tab.rect = {ox + 10, ty, SIDEBAR - 20, 32}
        local th = inRect(m, tab.rect)
        if th and Win.open then HoverAny = true end
        tab.hover = damp(tab.hover, (not isActive and th) and 1 or 0, 12, dt)
        tab.sel = damp(tab.sel, isActive and 1 or 0, 12, dt)
        tab.alpha = damp(tab.alpha, isActive and 1 or 0, 30, dt)
        local lb = bounds(tab.label)
        tab.label.Position = Vector2.new(ox + 34 + tab.sel * 4 + tab.hover * 2, ty + 16 - lb.Y / 2)
        tab.label.Color = cLerp(Theme.SubText, Theme.Text, math.max(tab.sel, tab.hover * 0.6))
        show(tab.label, a)
        tab.icon.Position = Vector2.new(ox + 25, ty + 16)
        tab.icon.Radius = 3 + tab.sel * 1.2
        tab.icon.Color = cMix(Theme.SubText, accentAt(i / tabCount), tab.sel)
        show(tab.icon, a)
    end

    V.hint.Position = Vector2.new(ox + 16, oy + H - 26)
    show(V.hint, a, 0.7)

    if active then
        setText(V.pageTitle, active.name)
        setText(V.pageSub, active.desc)
        local ta = a * active.alpha
        V.pageTitle.Position = Vector2.new(ox + SIDEBAR + 20 + (1 - active.alpha) * 12, oy + 10)
        show(V.pageTitle, ta)
        V.pageSub.Position = Vector2.new(ox + SIDEBAR + 20 + (1 - active.alpha) * 18, oy + 33)
        show(V.pageSub, ta)
    end
    V.headerLine:set(ox + SIDEBAR + 16, oy + HEADER, W - SIDEBAR - 32, 1, a, accentAt, edgeFade)

    for i, d in ipairs(V.dots) do
        local p = Vector2.new(ox + W - 22 - (i - 1) * 22, oy + 28)
        d.rect = {p.X - 9, p.Y - 9, 18, 18}
        local dh = inRect(m, d.rect)
        if dh and Win.open then HoverAny = true end
        d.hover = damp(d.hover, dh and 1 or 0, 14, dt)
        d.o.Position = p
        d.o.Radius = 5 + d.hover * 1.5
        show(d.o, a, 0.7 + 0.3 * d.hover)
    end

    local cx0, cw = ox + SIDEBAR + 16, W - SIDEBAR - 32
    for _, tab in ipairs(Win.tabs) do
        local isAct = tab == active
        if isAct then tab.hidden = false end
        if not tab.hidden then
            local ta = a * tab.alpha
            local slide = (1 - tab.alpha) * 18 * (isAct and 1 or -1)
            local y = oy + HEADER + 14
            for _, el in ipairs(tab.elements) do
                local x = cx0 + slide
                el.rect = {x, y, cw, el.h}
                local hovered = isAct and Win.open and dragTarget == nil and not IV.resizing and inRect(m, el.rect)
                if hovered then HoverAny = true end
                local ok, err = pcall(el.update, el, dt, x, y, cw, ta, hovered, m)
                if not ok then reportError("element " .. tab.name, err) end
                y = y + el.h + 8
            end
            if not isAct and tab.alpha <= 0 then tab.hidden = true end
        end
    end

    updateNotifs(dt)
end

local function render(dt)
    frameCounter = frameCounter + 1
    clock += dt * Settings.speed
    CurMouse = getMouse()
    HoverAny = false
    CamPos = nil
    pcall(function() CamPos = Camera.CFrame.Position end)

    local ok, err = pcall(renderBody, dt)
    if not ok then reportError("renderBody", err) end

    local ok2, err2 = pcall(renderAdminPanel, dt)
    if not ok2 then reportError("adminPanel", err2) end
    local ok3, err3 = pcall(renderPlates, dt)
    if not ok3 then reportError("plates", err3) end
    local ok4, err4 = pcall(renderInventory, dt)
    if not ok4 then reportError("inventory", err4) end
    local ok5, err5 = pcall(renderCursor, dt)
    if not ok5 then reportError("cursor", err5) end
end

table.insert(Connections, RunService.RenderStepped:Connect(render))

--==================== FREE MOUSE ====================--

local MouseCtl = {active = false}

local function restoreMouse()
    if not MouseCtl.active then return end
    MouseCtl.active = false
    pcall(function()
        if MouseCtl.prevB then UIS.MouseBehavior = MouseCtl.prevB end
    end)
    pcall(function()
        if MouseCtl.prevI ~= nil then UIS.MouseIconEnabled = MouseCtl.prevI end
    end)
end

local function mouseStep()
    if Win.destroyed then return end
    if Win.open and Settings.unlockMouse then
        if not MouseCtl.active then
            MouseCtl.active = true
            pcall(function()
                MouseCtl.prevB = UIS.MouseBehavior
                MouseCtl.prevI = UIS.MouseIconEnabled
            end)
        end
        pcall(function()
            if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
                UIS.MouseBehavior = Enum.MouseBehavior.Default
            end
        end)
        pcall(function()
            if not UIS.MouseIconEnabled then UIS.MouseIconEnabled = true end
        end)
    else
        restoreMouse()
    end
end

local boundStep = pcall(function()
    RunService:BindToRenderStep("AuroraMouse", Enum.RenderPriority.Last.Value + 1, mouseStep)
end)
if not boundStep then
    table.insert(Connections, RunService.RenderStepped:Connect(mouseStep))
end

--==================== INPUT ====================--

local prevRShift, prevI = false, false
local InvSizeSlider

local function startDrag(P, m)
    if P ~= Win and not P.tx then
        P.tx, P.ty = P.cx, P.cy
    end
    dragTarget = P
    dragOff = Vector2.new(m.X - P.tx, m.Y - P.ty)
end

local DragPanels = {AP, IV}

local function handleClick()
    if not Win.open or Win.alpha < 0.3 then return end
    local m = getMouse()

    -- уголок размера инвентаря
    if not IV.hidden and IV.alpha > 0.3 and IV.resizeRect and inRect(m, IV.resizeRect) then
        if not IV.tx then IV.tx, IV.ty = IV.cx, IV.cy end
        IV.resizing = {mx = m.X, s = Settings.invScale, w = IV.w}
        return
    end

    for _, P in ipairs(DragPanels) do
        if not P.hidden and P.alpha > 0.3 and P.headRect and inRect(m, P.headRect) then
            startDrag(P, m)
            return
        end
    end

    for _, d in ipairs(V.dots) do
        if inRect(m, d.rect) then d.action() return end
    end
    for i, tab in ipairs(Win.tabs) do
        if inRect(m, tab.rect) then
            Win.active = i
            return
        end
    end
    local active = Win.tabs[Win.active]
    if active then
        for _, el in ipairs(active.elements) do
            if inRect(m, el.rect) then
                if el.press then el:press(m) end
                return
            end
        end
    end
    if inRect(m, {Win.x, Win.y, W, HEADER}) then
        startDrag(Win, m)
    end
end

local function updateDrag()
    local m
    if dragTarget then
        m = getMouse()
        dragTarget.tx = m.X - dragOff.X
        dragTarget.ty = m.Y - dragOff.Y
    end
    local rs = IV.resizing
    if rs then
        m = m or getMouse()
        local base = rs.w / rs.s
        local s = math.clamp(rs.s + (m.X - rs.mx) / base, 0.5, 1.6)
        s = math.floor(s * 100 + 0.5) / 100
        Settings.invScale = s
        if InvSizeSlider then InvSizeSlider:SetSilent(math.floor(s * 100 + 0.5)) end
    end
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    if Win.destroyed then return end
    local ok, err = pcall(function()
        local active = isrbxactive()
        if active == nil then active = true end

        local m1 = active and ismouse1pressed() or false
        if m1 and not MouseDown then
            handleClick()
        end
        if (not m1) and MouseDown then
            dragTarget = nil
            IV.resizing = nil
            for _, tab in ipairs(Win.tabs) do
                for _, el in ipairs(tab.elements) do
                    el.dragging = false
                end
            end
        end
        MouseDown = m1

        local rshift = active and iskeypressed(0xA1)
        if rshift and not prevRShift then
            Win.open = not Win.open
            if not Win.open then
                dragTarget = nil
                IV.resizing = nil
            end
        end
        prevRShift = rshift

        local ik = active and iskeypressed(0x49)
        if ik and not prevI then
            SetRecoil(not Flags.RecoilEnabled)
        end
        prevI = ik

        updateDrag()
        FlushRecoil()
    end)
    if not ok then reportError("input", err) end
end))

function Win:Destroy()
    if self.destroyed then return end
    self.destroyed = true
    restoreMouse()
    pcall(function() RunService:UnbindFromRenderStep("AuroraMouse") end)
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for i = #Objects, 1, -1 do pcall(function() Objects[i]:Remove() end) end
    table.clear(Objects)
    if env.AuroraUI == self then env.AuroraUI = nil end
end

function Win:Close()
    self.open = false
    task.delay(0.45, function() self:Destroy() end)
end

V.dots[1].action = function()
    pcall(ApplyRecoil, 1)
    Win:Close()
end
V.dots[2].action = function()
    Win.open = false
    Win:Notify("Menu collapsed", "Press RightShift to open", 3)
end

env.AuroraUI = Win

--==================== TABS ====================--

local main = Win:Tab("Features", "Main modules")

main:Toggle({
    Name = "Inventory Viewer",
    Default = false,
    Callback = function(v) Flags.Inventory = v end,
})

main:Toggle({
    Name = "Cheat Detector",
    Default = false,
    Callback = function(v) Flags.CheatDetector = v end,
})

main:Toggle({
    Name = "Admin List",
    Default = false,
    Callback = function(v)
        Flags.ShowAdmins = v
        if v then AP.scanT = -1 end
    end,
})

main:Toggle({
    Name = "Admin Labels",
    Default = false,
    Callback = function(v) Flags.AdminLabels = v end,
})

local recoil = Win:Tab("Recoil", "Recoil control")

recoil:Slider({
    Name = "Recoil Value",
    Min = -2,
    Max = 2,
    Step = 0.01,
    Default = -0.55,
    Callback = function(v)
        Flags.RecoilValue = v
        if Flags.RecoilEnabled then QueueRecoil(v) end
    end,
})

RecoilToggle = recoil:Toggle({
    Name = "No Recoil",
    Default = false,
    Callback = function(v)
        Flags.RecoilEnabled = v
        RecoilQueued = nil
        if v then ApplyRecoil(Flags.RecoilValue) else ApplyRecoil(1) end
    end,
})

recoil:Button({
    Name = "Apply Value",
    Callback = function()
        if Flags.RecoilEnabled then
            RecoilQueued = nil
            ApplyRecoil(Flags.RecoilValue)
            Win:Notify("Recoil", "Applied: " .. tostring(Flags.RecoilValue), 2)
        else
            Win:Notify("Recoil", "Enable No Recoil first", 2)
        end
    end,
})

recoil:Button({
    Name = "Toggle No Recoil (I)",
    Callback = function()
        SetRecoil(not Flags.RecoilEnabled)
    end,
})

local visuals = Win:Tab("Visuals", "Menu effects")

visuals:Swatches({
    Name = "Accent",
    Callback = function(i)
        local names = {"Aurora", "Sunset", "Ocean", "Crimson", "Lime"}
        Win:Notify("Theme", "Accent: " .. (names[i] or "?"), 2.5)
    end,
})

visuals:Toggle({
    Name = "Neon Glow",
    Default = true,
    Callback = function(v) Settings.glow = v end,
})

visuals:Toggle({
    Name = "Particles",
    Default = true,
    Callback = function(v) Settings.particles = v end,
})

visuals:Toggle({
    Name = "Pulse",
    Default = true,
    Callback = function(v) Settings.pulse = v end,
})

visuals:Slider({
    Name = "Animation Speed",
    Min = 0.2,
    Max = 3,
    Step = 0.1,
    Default = 1,
    Suffix = "x",
    Callback = function(v) Settings.speed = v end,
})

visuals:Slider({
    Name = "Glow Power",
    Min = 0,
    Max = 300,
    Step = 5,
    Default = 100,
    Suffix = "%",
    Callback = function(v) Settings.glowPower = v / 100 end,
})

local iface = Win:Tab("Interface", "Mouse and HUD panels")

iface:Toggle({
    Name = "Free Mouse In Menu",
    Default = true,
    Callback = function(v) Settings.unlockMouse = v end,
})

iface:Toggle({
    Name = "Cursor Halo",
    Default = true,
    Callback = function(v) Settings.cursor = v end,
})

iface:Toggle({
    Name = "Native Rounding",
    Default = Settings.nativeRound,
    Callback = function(v)
        Settings.nativeRound = v
        if v and not NATIVE_CORNER then
            Win:Notify("Rounding", "Executor has no Square.Corner", 2.5)
        end
    end,
})

InvSizeSlider = iface:Slider({
    Name = "Inventory Size",
    Min = 50,
    Max = 160,
    Step = 1,
    Default = 100,
    Suffix = "%",
    Callback = function(v) Settings.invScale = v / 100 end,
})

iface:Slider({
    Name = "HUD Opacity",
    Min = 20,
    Max = 100,
    Step = 1,
    Default = math.floor(Settings.hudOpacity * 100 + 0.5),
    Suffix = "%",
    Callback = function(v) Settings.hudOpacity = v / 100 end,
})

iface:Button({
    Name = "Reset Panels",
    Callback = function()
        AP.tx, AP.ty = nil, nil
        IV.tx, IV.ty = nil, nil
        Settings.invScale = 1
        InvSizeSlider:SetSilent(100)
        Win:Notify("Panels", "Position and size reset", 2)
    end,
})

task.delay(0.6, function()
    Win:Notify("Aurora UI", "RightShift - menu  |  I - recoil", 4)
end)

print("[Aurora] loaded" .. (NATIVE_CORNER and "  (native rounding)" or ""))

return Win
