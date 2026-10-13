--[[
    Aurora UI · Drawing API — v1.8
    RightShift - toggle, I - No Recoil.
    При открытом меню: мышь свободна, панели админов/инвентаря тащатся за шапку.
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

local Settings = {
    glow = true,
    glowPower = 1,
    particles = true,
    pulse = true,
    speed = 1,
    unlockMouse = true,
    cursor = true,
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
local accentCache = {}
local accentFrame = -1
local ACC_Q = 48

local function new(class, props)
    local o = Drawing.new(class)
    o.Visible = false
    for k, v in pairs(props or {}) do o[k] = v end
    if class == "Text" and props and props.Outline then
        OutlineText[o] = true
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

local function damp(a, b, speed, dt)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    local r = a + (b - a) * (1 - math.exp(-(tonumber(speed) or 12) * (tonumber(dt) or (1/60))))
    if math.abs(b - r) < 0.002 then return b end
    return r
end

-- 48 ступеней вместо 10 + smoothstep + gamma-смешивание -> без полос
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

-- пульс квантуется, чтобы рамки не перерисовывались каждый кадр
local function pulseK(speed, ph, lo)
    if not Settings.pulse then return 1 end
    lo = lo or 0.75
    local v = lo + (1 - lo) * (0.5 + 0.5 * math.sin(clock * (speed or 2) + (ph or 0)))
    return math.floor(v * 24 + 0.5) / 24
end

local function bounds(t)
    if not t then return Vector2.new(0, 14) end
    local text = tostring(t.Text or "")
    local c = BoundsCache[t]
    if c and c.text == text then return c.b end

    local ok, b = pcall(function() return t.TextBounds end)
    if ok and b and tonumber(b.X) and tonumber(b.Y) and b.X > 0 then
        b = Vector2.new(b.X, b.Y)
        BoundsCache[t] = {text = text, b = b}
        return b
    end
    local size = tonumber(t.Size) or 14
    return Vector2.new(#text * size * 0.5, size)
end

local function setText(o, key, text)
    -- пишем Text только при изменении
    if o[key] ~= text then
        o[key] = text
        return true
    end
    return false
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

local RoundRect = {}
RoundRect.__index = RoundRect

function RoundRect.new(z)
    local self = setmetatable({}, RoundRect)
    self.hr = new("Square", {Filled = true, Thickness = 1, ZIndex = z})
    self.vr = new("Square", {Filled = true, Thickness = 1, ZIndex = z})
    self.c = {}
    for i = 1, 4 do
        self.c[i] = new("Circle", {Filled = true, NumSides = 12, Thickness = 1, ZIndex = z})
    end
    return self
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

    local L = self.last
    if L then
        if alpha <= 0 and L.a <= 0 then return end
        if L.x == x and L.y == y and L.w == w and L.h == h and L.r == r
            and L.a == alpha and L.cr == color.R and L.cg == color.G and L.cb == color.B then
            return
        end
    else
        L = {}
        self.last = L
    end
    L.x, L.y, L.w, L.h, L.r, L.a = x, y, w, h, r, alpha
    L.cr, L.cg, L.cb = color.R, color.G, color.B

    local c = self.c
    if w <= 0 or h <= 0 or alpha <= 0 then
        show(self.hr, 0); show(self.vr, 0)
        show(c[1], 0); show(c[2], 0); show(c[3], 0); show(c[4], 0)
        return
    end

    local minR = w / 2
    if h / 2 < minR then minR = h / 2 end
    if r > minR then r = minR end
    if r < 0 then r = 0 end

    self.hr.Position = Vector2.new(x, y + r)
    self.hr.Size = Vector2.new(w, h - r * 2)
    self.vr.Position = Vector2.new(x + r, y)
    self.vr.Size = Vector2.new(w - r * 2, h)
    self.hr.Color = color
    self.vr.Color = color
    show(self.hr, alpha)
    show(self.vr, alpha)

    local ca = r > 0 and alpha or 0
    local x1, y1, x2, y2 = x + r, y + r, x + w - r, y + h - r
    setCorner(c[1], x1, y1, r, color, ca)
    setCorner(c[2], x2, y1, r, color, ca)
    setCorner(c[3], x1, y2, r, color, ca)
    setCorner(c[4], x2, y2, r, color, ca)
end

function RoundRect:hide()
    self:set(0, 0, 0, 0, 0, WHITE, 0)
end

function RoundRect:destroy()
    kill(self.hr); kill(self.vr)
    for _, c in ipairs(self.c) do kill(c) end
end

-- градиент: геометрия пересчитывается только когда сдвинулся/изменил размер
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

-- "ручка" для перетаскивания: 2x3 точки
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

-- позиция перетаскиваемой панели: default пока не трогали, дальше tx/ty
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
V.subtitle = new("Text", {Text = "v1.8  |  combat + esp", Size = 13, Font = FONT, ZIndex = 6, Color = Theme.SubText})
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

        if self.shownValue ~= self.value then
            self.shownValue = self.value
            self.valueText.Text = string.format(fmt, self.value) .. (o.Suffix or "")
        end
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

local UserIdCache = setmetatable({}, {__mode = "k"})
local RoleCache = setmetatable({}, {__mode = "k"})
local AgeCache = setmetatable({}, {__mode = "k"})

local function GetUserId(P)
    local id = UserIdCache[P]
    if id then return id end
    local ok, v = pcall(function()
        return memory_read("uintptr_t", P.Address + Offsets.Player.UserId)
    end)
    if ok and type(v) == "number" and v > 0 then
        UserIdCache[P] = v
        return v
    end
    return nil
end

local function GetRole(P)
    local cached = RoleCache[P]
    if cached ~= nil then
        return cached or nil
    end
    local id = GetUserId(P)
    if not id then return nil end
    local role = ModeratorIDs[id] or false
    RoleCache[P] = role
    return role or nil
end

local function GetAge(P)
    local c = AgeCache[P]
    local now = tick()
    if c and (now - c.t) < 60 then
        return c.v
    end
    local ok, v = pcall(function()
        return memory_read("int", P.Address + Offsets.Player.AccountAge)
    end)
    if ok and type(v) == "number" then
        if c then c.v, c.t = v, now else AgeCache[P] = {v = v, t = now} end
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
AP.shadow = RoundRect.new(97)
AP.border = RoundRect.new(98)
AP.bg = RoundRect.new(99)
AP.head = RoundRect.new(100)
AP.headFix = new("Square", {Filled = true, Thickness = 1, ZIndex = 100})
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
    AP.shadow:hide(); AP.border:hide(); AP.bg:hide(); AP.head:hide(); AP.pill:hide()
    AP.line:set(0, 0, 0, 0, 0)
    show(AP.headFix, 0); show(AP.liveGlow, 0); show(AP.live, 0)
    show(AP.title, 0); show(AP.countText, 0); show(AP.emptyText, 0)
    for i = 1, 6 do show(AP.grip[i], 0) end
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

    AP.shadow:set(x + 3, y + 5, w, h, 11, SHADOW_COL, a * 0.35)
    local bk = (0.5 + 0.3 * AP.hover) * pulseK(2)
    AP.border:set(x - 1, y - 1, w + 2, h + 2, 11, cMix(Theme.Bg, accentAt(0.3), bk), a)
    AP.bg:set(x, y, w, h, 10, Theme.Bg, a)
    local hcol = AP.hover > 0.01 and cMix(Theme.Panel, accentAt(0.3), 0.08 * AP.hover) or Theme.Panel
    AP.head:set(x, y, w, hh, 10, hcol, a)
    AP.headFix.Position = Vector2.new(x, y + hh - 10)
    AP.headFix.Size = Vector2.new(w, 10)
    AP.headFix.Color = hcol
    show(AP.headFix, a)
    AP.line:set(x, y + hh - 2, w, 2, a, accentAt, edgeFade)

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

    setText(AP.countText, "Text", tostring(n))
    local cb = bounds(AP.countText)
    local pw = math.max(24, cb.X + 14)
    local px, py = x + w - 14 - pw, y + hh / 2 - 11
    local acc = accentAt(0.6)
    AP.pill:set(px, py, pw, 20, 10, cMix(Theme.Panel, acc, 0.28), a)
    AP.countText.Position = Vector2.new(px + (pw - cb.X) / 2, py + (20 - cb.Y) / 2)
    AP.countText.Color = cMix(Theme.Text, acc, 0.5)
    show(AP.countText, a)

    -- ручка видна только когда меню открыто
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
                    setText(r.name, "Text", entry.name)
                    if r.roleT ~= entry.role then
                        r.roleT = entry.role
                        r.role.Text = entry.role
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
                    show(r.sep, ra, 0.6)
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

local SLOT, SLOT_GAP, IV_PAD, IV_HEAD = 56, 8, 12, 40
local IV_W = IV_PAD * 2 + BoxCount * SLOT + (BoxCount - 1) * SLOT_GAP
local IV_H = IV_HEAD + 10 + SLOT + IV_PAD

local IV = {alpha = 0, hidden = true, hover = 0, slots = {}, hasTarget = 0, distT = 0}
IV.shadow = RoundRect.new(90)
IV.border = RoundRect.new(91)
IV.bg = RoundRect.new(92)
IV.head = RoundRect.new(93)
IV.headFix = new("Square", {Filled = true, Thickness = 1, ZIndex = 93})
IV.line = Gradient.new(40, 94)
IV.avGlow = new("Circle", {Filled = true, NumSides = 20, ZIndex = 94})
IV.avA = new("Circle", {Filled = true, NumSides = 16, ZIndex = 95, Radius = 6})
IV.avB = new("Circle", {Filled = true, NumSides = 16, ZIndex = 95, Radius = 6})
IV.avCore = new("Circle", {Filled = true, NumSides = 10, ZIndex = 96, Radius = 2.5, Color = WHITE})
IV.name = new("Text", {Text = "No target", Size = 15, Font = FONT, ZIndex = 95, Color = Theme.Text})
IV.sub = new("Text", {Text = "", Size = 12, Font = FONT, ZIndex = 95, Color = Theme.SubText})
IV.pill = RoundRect.new(94)
IV.count = new("Text", {Text = "0/" .. BoxCount, Size = 13, Font = FONT, ZIndex = 95})
IV.grip = newGrip(95)

for i = 1, BoxCount do
    IV.slots[i] = {
        ring = RoundRect.new(94),
        card = RoundRect.new(95),
        sheen = new("Line", {Thickness = 1, ZIndex = 96, Color = WHITE}),
        shimmer = new("Square", {Filled = true, Thickness = 1, ZIndex = 96}),
        img = new("Image", {ZIndex = 97}),
        idx = new("Text", {Text = tostring(i), Size = 12, Font = FONT, ZIndex = 96, Color = Theme.SubText}),
        fill = 0, pop = 0, iconA = 0, hover = 0, icon = nil,
    }
end

local function hideInventory()
    IV.shadow:hide(); IV.border:hide(); IV.bg:hide(); IV.head:hide(); IV.pill:hide()
    IV.line:set(0, 0, 0, 0, 0)
    show(IV.headFix, 0); show(IV.avGlow, 0); show(IV.avA, 0); show(IV.avB, 0); show(IV.avCore, 0)
    show(IV.name, 0); show(IV.sub, 0); show(IV.count, 0)
    for i = 1, 6 do show(IV.grip[i], 0) end
    for _, s in ipairs(IV.slots) do
        s.ring:hide(); s.card:hide()
        show(s.sheen, 0); show(s.shimmer, 0); show(s.img, 0); show(s.idx, 0)
    end
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
        if ArmorViewerTarget ~= target or now - ArmorLastUpdate >= ARMOR_INTERVAL then
            ArmorLastUpdate = now
            ArmorViewerTarget = target
            RebuildSlotCache(target.Character)
        else
            UpdateSlotCacheImages()
        end
    elseif ArmorViewerTarget then
        ArmorViewerTarget = nil
        table.clear(SlotCache)
    end

    -- без цели панель видна только при открытом меню (чтобы её можно было двигать)
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

    local a = IV.alpha
    local e = 1 - (1 - a) ^ 3
    local vs = Camera.ViewportSize
    local bx, by = panelPos(IV, (vs.X - IV_W) / 2, 18, IV_W, IV_H, dt)
    local x = bx
    local y = math.floor(by - (1 - e) * 20 + 0.5)

    IV.headRect = {x, y, IV_W, IV_HEAD}
    local canDrag = Win.open and Win.alpha > 0.3
    local hov = canDrag and (inRect(CurMouse, IV.headRect) or dragTarget == IV)
    if hov then HoverAny = true end
    IV.hover = damp(IV.hover, hov and 1 or 0, 12, dt)
    IV.hasTarget = damp(IV.hasTarget, target and 1 or 0, 10, dt)

    -- корпус
    IV.shadow:set(x + 3, y + 5, IV_W, IV_H, 13, SHADOW_COL, a * 0.35)
    local bk = (0.45 + 0.3 * IV.hover) * pulseK(2, 1.3)
    IV.border:set(x - 1, y - 1, IV_W + 2, IV_H + 2, 13, cMix(Theme.Bg, accentAt(0.5), bk), a)
    IV.bg:set(x, y, IV_W, IV_H, 12, Theme.Bg, a)
    local hcol = IV.hover > 0.01 and cMix(Theme.Panel, accentAt(0.2), 0.08 * IV.hover) or Theme.Panel
    IV.head:set(x, y, IV_W, IV_HEAD, 12, hcol, a)
    IV.headFix.Position = Vector2.new(x, y + IV_HEAD - 12)
    IV.headFix.Size = Vector2.new(IV_W, 12)
    IV.headFix.Color = hcol
    show(IV.headFix, a)
    IV.line:set(x, y + IV_HEAD - 2, IV_W, 2, a, accentAt, edgeFade)

    -- "аватар" в стиле логотипа
    local acx, acy = x + 22, y + IV_HEAD / 2 - 1
    local ox, oy = math.cos(clock * 2) * 3, math.sin(clock * 2) * 3
    local ta = a * (0.35 + 0.65 * IV.hasTarget)
    IV.avA.Position = Vector2.new(acx + ox, acy + oy)
    IV.avA.Color = Theme.AccentA
    IV.avB.Position = Vector2.new(acx - ox, acy - oy)
    IV.avB.Color = Theme.AccentB
    IV.avCore.Position = Vector2.new(acx, acy)
    show(IV.avA, ta, 0.85); show(IV.avB, ta, 0.85); show(IV.avCore, ta)
    local gp = (clock * 0.7) % 1
    IV.avGlow.Position = Vector2.new(acx, acy)
    IV.avGlow.Radius = 9 + gp * 7
    IV.avGlow.Color = accentAt(0.4)
    show(IV.avGlow, a * IV.hasTarget, 0.3 * (1 - gp))

    -- текст
    local filled = 0
    for i = 1, BoxCount do if SlotCache[i] then filled += 1 end end
    setText(IV.name, "Text", target and target.Name or "No target")
    local now = tick()
    if now - IV.distT > 0.25 then
        IV.distT = now
        local sub = "aim at a player"
        if target then
            local head = getAliveHead(target)
            local d = (head and CamPos) and math.floor((head.Position - CamPos).Magnitude) or 0
            sub = d .. "m  |  " .. filled .. (filled == 1 and " item" or " items")
        end
        setText(IV.sub, "Text", sub)
    end
    IV.name.Position = Vector2.new(x + 40, y + 5)
    IV.name.Color = cLerp(Theme.SubText, Theme.Text, IV.hasTarget)
    show(IV.name, a)
    IV.sub.Position = Vector2.new(x + 40, y + 21)
    show(IV.sub, a, 0.9)

    setText(IV.count, "Text", filled .. "/" .. BoxCount)
    local cb = bounds(IV.count)
    local pw = math.max(34, cb.X + 16)
    local px, py = x + IV_W - 14 - pw, y + IV_HEAD / 2 - 11
    local acc = accentAt(0.7)
    IV.pill:set(px, py, pw, 20, 10, cMix(Theme.Panel, acc, 0.28), a)
    IV.count.Position = Vector2.new(px + (pw - cb.X) / 2, py + (20 - cb.Y) / 2)
    IV.count.Color = cMix(Theme.Text, acc, 0.5)
    show(IV.count, a)

    setGrip(IV.grip, px - 16, y + IV_HEAD / 2 - 5, a * Win.alpha * (0.45 + 0.55 * IV.hover),
        IV.hover > 0.01 and cMix(Theme.SubText, accentAt(0.5), IV.hover) or nil)

    -- слоты
    local sy = y + IV_HEAD + 10
    for i = 1, BoxCount do
        local s = IV.slots[i]
        local data = SlotCache[i]
        local icon = data and data.Icon or nil
        local sx = x + IV_PAD + (i - 1) * (SLOT + SLOT_GAP)
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
        local sh = canDrag and inRect(CurMouse, {sx, sy, SLOT, SLOT})
        s.hover = damp(s.hover, sh and 1 or 0, 14, dt)

        local lift = math.floor(s.hover * 2 + 0.5)
        local ry = sy - lift
        local acol = accentAt(p)
        s.ring:set(sx - 1, ry - 1, SLOT + 2, SLOT + 2, 10,
            cMix(Theme.Stroke, acol, s.fill * (0.7 + 0.3 * s.hover)), a)
        s.card:set(sx, ry, SLOT, SLOT, 9,
            cMix(Theme.Element, acol, 0.08 * s.fill + 0.06 * s.hover), a)

        s.sheen.From = Vector2.new(sx + 9, ry + 1)
        s.sheen.To = Vector2.new(sx + SLOT - 9, ry + 1)
        show(s.sheen, a, 0.07 + 0.06 * s.hover)

        if data and not icon then
            -- загрузка: бегущий блик
            local t = (clock * 1.1 + i * 0.13) % 1
            s.shimmer.Position = Vector2.new(math.floor(sx + 4 + t * (SLOT - 20)), ry + 5)
            s.shimmer.Size = Vector2.new(12, SLOT - 10)
            s.shimmer.Color = acol
            show(s.shimmer, a, 0.22 * math.sin(t * math.pi))
        else
            show(s.shimmer, 0)
        end

        local ib = bounds(s.idx)
        s.idx.Position = Vector2.new(sx + (SLOT - ib.X) / 2, ry + (SLOT - ib.Y) / 2)
        show(s.idx, a, (1 - s.fill) * 0.45)

        if s.icon and s.iconA > 0.01 then
            local isz = math.floor((SLOT - 10) * (1 - 0.15 * s.pop) + 0.5)
            local ix = sx + math.floor((SLOT - isz) / 2)
            local iy = ry + math.floor((SLOT - isz) / 2)
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

local Plates = {}
local platesActive = 0
local CheaterState = setmetatable({}, {__mode = "k"})
local CheaterScanT = 0
local PLATE_OFF = Vector3.new(0, 2.6, 0)
local PLATE_MAX_DIST = 1500

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
        a = 0, hidden = true, seen = -1, lastT = tick(), ph = math.random() * 6.28, distT = 0,
        border = RoundRect.new(11),
        bg = RoundRect.new(12),
        bar = new("Square", {Filled = true, Thickness = 1, ZIndex = 13}),
        title = new("Text", {Text = "", Size = 13, Font = FONT, ZIndex = 14}),
        name = new("Text", {Text = "", Size = 12, Font = FONT, ZIndex = 14, Color = Theme.Text}),
        dist = new("Text", {Text = "", Size = 11, Font = FONT, ZIndex = 14, Color = Theme.SubText}),
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

local function drawPlate(pl)
    local a = pl.a
    local col = pl.col or MOD_COL
    local tb, nb, db = bounds(pl.title), bounds(pl.name), bounds(pl.dist)
    local inner = math.max(tb.X + 12 + db.X, nb.X)
    local w = math.floor(inner + 24 + 0.5)
    local h = 34
    local cx = math.floor(pl.sx + 0.5)
    local x = cx - math.floor(w / 2)
    local y = math.floor(pl.sy - h - 8 + 0.5)

    local bcol = cMix(Theme.Bg, col, 0.6 * pulseK(3, pl.ph, 0.7))
    pl.border:set(x - 1, y - 1, w + 2, h + 2, 7, bcol, a)
    pl.bg:set(x, y, w, h, 6, Theme.Bg, a)

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
        show(pl.tri, a)
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
                if not CheaterState[P] then
                    CheaterState[P] = IsCheater(P)
                end
            end
        end
    elseif next(CheaterState) then
        table.clear(CheaterState)
    end

    for _, P in ipairs(players) do
        local role = adminOn and GetRole(P) or nil
        local cheat = cheatOn and CheaterState[P] or nil
        if role or cheat then
            local head = getAliveHead(P)
            if head then
                local hp = head.Position
                local d = CamPos and (hp - CamPos).Magnitude or 0
                if d <= PLATE_MAX_DIST then
                    local s, onS = WorldToScreen(hp + PLATE_OFF)
                    if onS and s then
                        local pl = Plates[P]
                        if not pl then
                            pl = newPlate()
                            Plates[P] = pl
                        end
                        pl.seen = frameCounter
                        pl.lastT = now
                        pl.sx, pl.sy = tonumber(s.X) or 0, tonumber(s.Y) or 0

                        local title = role and string.upper(role) or "CHEATER"
                        if role and cheat then title = title .. "  /  CHEATER" end
                        if pl.titleT ~= title then
                            pl.titleT = title
                            pl.title.Text = title
                            pl.col = role and roleColor(role) or CHEAT_COL
                            pl.title.Color = pl.col
                        end
                        local nm = cheat and (P.Name .. "  -  " .. cheat) or P.Name
                        setText(pl.name, "Text", nm)
                        if now - pl.distT > 0.25 then
                            pl.distT = now
                            setText(pl.dist, "Text", math.floor(d) .. "m")
                        end
                    end
                end
            end
        end
    end

    platesActive = 0
    for P, pl in pairs(Plates) do
        local want = pl.seen == frameCounter
        pl.a = damp(pl.a, want and 1 or 0, 14, dt)
        if not want and pl.a <= 0.01 then
            pl.a = 0
            if not pl.hidden then
                pl.hidden = true
                hidePlate(pl)
            end
            if now - pl.lastT > 15 then
                destroyPlate(pl)
                Plates[P] = nil
            end
        else
            pl.hidden = false
            platesActive += 1
            drawPlate(pl)
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
    Cur.press = damp(Cur.press, (MouseDown or dragTarget) and 1 or 0, 20, dt)

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
        setText(V.pageTitle, "Text", active.name)
        setText(V.pageSub, "Text", active.desc)
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
                local hovered = isAct and Win.open and dragTarget == nil and inRect(m, el.rect)
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
-- игра обычно держит мышь в центре (LockCenter) и прячет курсор каждый кадр,
-- поэтому перебиваем это после камеры, пока меню открыто

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

    -- панели лежат поверх окна, проверяем их первыми
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
    if dragTarget then
        local m = getMouse()
        dragTarget.tx = m.X - dragOff.X
        dragTarget.ty = m.Y - dragOff.Y
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
            if not Win.open then dragTarget = nil end
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

local iface = Win:Tab("Interface", "Mouse and panels")

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

iface:Button({
    Name = "Reset Panel Positions",
    Callback = function()
        AP.tx, AP.ty = nil, nil
        IV.tx, IV.ty = nil, nil
        Win:Notify("Panels", "Positions reset", 2)
    end,
})

task.delay(0.6, function()
    Win:Notify("Aurora UI", "RightShift - menu  |  I - recoil", 4)
end)

print("[Aurora] loaded")

return Win
