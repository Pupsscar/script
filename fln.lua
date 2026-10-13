--[[
    Aurora UI · Drawing API — optimized v1.7
    RightShift - toggle, I - No Recoil.
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
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
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

local function kill(o)
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

local function accentAt(p)
    p = p or 0
    if accentFrame ~= frameCounter then
        table.clear(accentCache)
        accentFrame = frameCounter
    end
    local k = math.floor(p * 10 + 0.5) / 10
    local c = accentCache[k]
    if c then return c end
    local t = (math.sin(clock * 1.6 + k * math.pi * 2) + 1) / 2
    c = cLerp(Theme.AccentA, Theme.AccentB, t)
    accentCache[k] = c
    return c
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
    color = color or Color3.new(1, 1, 1)
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

function RoundRect:destroy()
    kill(self.hr); kill(self.vr)
    for _, c in ipairs(self.c) do kill(c) end
end

local Gradient = {}
Gradient.__index = Gradient

function Gradient.new(n, z)
    local self = setmetatable({n = n, strips = {}, lastA = -1}, Gradient)
    for i = 1, n do
        self.strips[i] = new("Square", {Filled = true, Thickness = 1, ZIndex = z})
    end
    return self
end

function Gradient:set(x, y, w, h, alpha, colorFn, alphaFn)
    if not colorFn then return end
    alpha = tonumber(alpha) or 0
    if alpha <= 0 and self.lastA == 0 then return end
    self.lastA = alpha > 0 and alpha or 0

    local n = self.n
    for i, s in ipairs(self.strips) do
        local x0 = math.floor(x + (i - 1) / n * w + 0.5)
        local x1 = math.floor(x + i / n * w + 0.5)
        if x1 - x0 <= 0 or alpha <= 0 then
            show(s, 0)
        else
            local p = (i - 0.5) / n
            s.Position = Vector2.new(x0, y)
            s.Size = Vector2.new(x1 - x0, h)
            s.Color = colorFn(p)
            show(s, alpha, alphaFn and alphaFn(p) or 1)
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
V.sideFix = new("Square", {Filled = true, Thickness = 1, ZIndex = 3})
V.sideLine = new("Line", {Thickness = 1, ZIndex = 4})
V.blob1 = new("Circle", {Filled = true, NumSides = 32, ZIndex = 3})
V.blob2 = new("Circle", {Filled = true, NumSides = 32, ZIndex = 3})
V.topBar = Gradient.new(24, 9)
V.logoA = new("Circle", {Filled = true, NumSides = 16, ZIndex = 6})
V.logoB = new("Circle", {Filled = true, NumSides = 16, ZIndex = 6})
V.logoCore = new("Circle", {Filled = true, NumSides = 12, ZIndex = 7})
V.title = new("Text", {Text = "Aurora", Size = 19, Font = FONT, ZIndex = 6})
V.subtitle = new("Text", {Text = "v1.7  |  combat + esp", Size = 13, Font = FONT, ZIndex = 6})
V.sideDiv = Gradient.new(12, 5)
V.indicator = RoundRect.new(4)
V.indicatorBar = new("Square", {Filled = true, Thickness = 1, ZIndex = 6})
V.pageTitle = new("Text", {Text = "", Size = 21, Font = FONT, ZIndex = 6})
V.pageSub = new("Text", {Text = "", Size = 13, Font = FONT, ZIndex = 6})
V.headerLine = Gradient.new(16, 5)
V.hint = new("Text", {Text = "RightShift  -  hide", Size = 13, Font = FONT, ZIndex = 6})
V.dots = {
    {o = new("Circle", {Filled = true, NumSides = 14, ZIndex = 7}), color = Color3.fromRGB(255, 95, 110), hover = 0},
    {o = new("Circle", {Filled = true, NumSides = 14, ZIndex = 7}), color = Color3.fromRGB(255, 200, 80), hover = 0},
}

local Particles = {}
for i = 1, 18 do
    Particles[i] = {
        o = new("Circle", {Filled = true, NumSides = 8, ZIndex = 4}),
        x = math.random(), y = math.random(),
        s = 0.025 + math.random() * 0.06,
        r = 1 + math.random() * 1.6,
        ph = math.random() * math.pi * 2,
    }
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
    el.knob = new("Circle", {Filled = true, NumSides = 14, ZIndex = 8})
    el.knob.Color = Color3.new(1, 1, 1)

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
            fill = cLerp(fill, accentAt(0.3), self.hover * 0.18)
        end
        self.card:set(x, y, w, self.h, 8, fill, a)
        local b = bounds(self.label)
        self.label.Position = Vector2.new(x + 14 + self.hover * 2, y + (self.h - b.Y) / 2)
        self.label.Color = cLerp(Theme.SubText, Theme.Text, 0.55 + 0.45 * math.max(self.anim, self.hover))
        show(self.label, a)

        local tw, th = 42, 22
        local tx, ty = x + w - tw - 14, y + (self.h - th) / 2
        self.track:set(tx, ty, tw, th, th / 2, cLerp(Theme.Stroke, accentAt(0.3), self.anim), a)

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
    el.label = new("Text", {Text = o.Name, Size = 15, Font = FONT, ZIndex = 6})
    el.valueText = new("Text", {Text = "", Size = 14, Font = FONT, ZIndex = 6})
    el.track = RoundRect.new(6)
    el.cap = new("Circle", {Filled = true, NumSides = 12, ZIndex = 7})
    el.fill = Gradient.new(12, 7)
    el.knobGlow = new("Circle", {Filled = true, NumSides = 16, ZIndex = 8})
    el.knob = new("Circle", {Filled = true, NumSides = 16, ZIndex = 9})
    el.knob.Color = Color3.new(1, 1, 1)
    el.label.Color = Theme.Text
    -- одна функция на элемент вместо новой замыкалки каждый кадр
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
        self.valueText.Color = cLerp(Theme.SubText, accentAt(0.6), self.hover)
        show(self.valueText, a)

        local tx, ty, tw, th = x + 14, y + 39, w - 28, 6
        self.trackRect = {tx, ty - 10, tw, th + 20}
        self.track:set(tx, ty, tw, th, th / 2, Theme.Stroke, a)

        local fw = tw * self.anim
        self.cap.Position = Vector2.new(tx + th / 2, ty + th / 2)
        self.cap.Radius = th / 2
        self.cap.Color = accentAt(0)
        show(self.cap, a)
        self.fill:set(tx + th / 2, ty, math.max(0, fw - th / 2), th, a, self.fillFn)

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
        self.label.Color = cLerp(Theme.Text, accentAt(0.4), self.hover * 0.35)
        show(self.label, a)

        local cx, cy = x + w - 20 + self.hover * 4, y + self.h / 2
        local col = cLerp(Theme.SubText, accentAt(0.8), self.hover)
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
    el.label = new("Text", {Text = o.Name, Size = 15, Font = FONT, ZIndex = 6})
    el.label.Color = Theme.Text
    el.ring = new("Circle", {Filled = false, Thickness = 2, NumSides = 20, ZIndex = 8})
    el.ring.Color = Color3.new(1, 1, 1)
    for i, p in ipairs(presets) do
        local s = {
            outer = new("Circle", {Filled = true, NumSides = 18, ZIndex = 6}),
            inner = new("Circle", {Filled = true, NumSides = 14, ZIndex = 7}),
            a = p[1], b = p[2], hover = 0, pos = Vector2.new(),
        }
        s.outer.Color = s.a
        s.inner.Color = s.b
        el.sw[i] = s
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
    n.prog = Gradient.new(12, 22)
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
local OffsetsLoaded = false

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
        OffsetsLoaded = true
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

--==================== player cache ====================--
-- список игроков без LocalPlayer, обновляется раз в 0.5 сек вместо GetPlayers() каждый кадр

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
    -- кэшируем только когда id реально прочитан, иначе попробуем в следующий раз
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

-- слайдер больше не дёргает getgc на каждый шаг, применяем не чаще раза в 0.25 сек
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

--==================== inventory ====================--

local BoxCount = 8
local BoxSize = 64
local BoxSpacing = 5
local TopMargin = 55
local BoxRounding = 10
local ImageCache = {}
local ImageBaseUrl = "https://raw.githubusercontent.com/sigma4skin/matcha-fallen/main/armor_images/"
local SlotCache = {}
local ArmorViewerTarget
local ArmorLastUpdate = 0
local ARMOR_INTERVAL = 3
local slotsHidden = true

local SlotDrawings = {}
for i = 1, BoxCount do
    local Bg = new("Square", {Filled = true, Color = Theme.Panel, Corner = BoxRounding, ZIndex = 4})
    local Img = new("Image", {ZIndex = 5})
    SlotDrawings[i] = { Bg = Bg, Img = Img, LastIcon = nil, lastX = nil, lastY = nil }
end

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

local function HideAllSlots()
    if slotsHidden then return end
    slotsHidden = true
    for i = 1, BoxCount do
        local D = SlotDrawings[i]
        show(D.Bg, 0)
        show(D.Img, 0)
        D.LastIcon = nil
    end
end

-- возвращает Player (а не новую таблицу), чтобы сравнение цели работало
local TargetCache = {t = 0, p = nil}

local function FindClosestTarget()
    local now = tick()
    local cp = TargetCache.p
    if cp and (now - TargetCache.t) < 0.3 and getAliveHead(cp) then
        return cp
    end

    local MousePos = getMouse()
    local mx, my = MousePos.X, MousePos.Y
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

local function roleColor(Role)
    if Role == "Founder" then return Color3.fromRGB(255, 90, 90) end
    if Role == "Co-Founder" then return Color3.fromRGB(255, 150, 70) end
    if Role == "Lead Developer" then return Color3.fromRGB(90, 200, 255) end
    if Role == "Contribution" then return Color3.fromRGB(255, 215, 100) end
    return Color3.fromRGB(150, 130, 255)
end

--==================== ADMIN PANEL ====================--
-- постоянные объекты, без пересоздания/скрытия каждый кадр -> никакого мигания

local AP = {
    alpha = 0, h = 0, list = {}, scanT = -1, rows = {},
    hidden = true, empty = 0, count = -1,
    W = 250, HEADH = 44, ROWH = 38,
}
AP.shadow = RoundRect.new(97)
AP.border = RoundRect.new(98)
AP.bg = RoundRect.new(99)
AP.head = RoundRect.new(100)
AP.headFix = new("Square", {Filled = true, Thickness = 1, ZIndex = 100})
AP.line = Gradient.new(20, 101)
AP.liveGlow = new("Circle", {Filled = true, NumSides = 18, ZIndex = 101})
AP.live = new("Circle", {Filled = true, NumSides = 14, ZIndex = 102})
AP.title = new("Text", {Text = "ACTIVE ADMINS", Size = 14, Font = FONT, ZIndex = 102, Color = Theme.Text})
AP.pill = RoundRect.new(101)
AP.countText = new("Text", {Text = "0", Size = 13, Font = FONT, ZIndex = 102})
AP.emptyText = new("Text", {Text = "No admins online", Size = 13, Font = FONT, ZIndex = 102, Color = Theme.SubText})

local function getAdminRow(i)
    local r = AP.rows[i]
    if r then return r end
    r = {
        anim = 0, hidden = true,
        sep = new("Line", {Thickness = 1, ZIndex = 101, Color = Theme.Stroke}),
        glow = new("Circle", {Filled = true, NumSides = 16, ZIndex = 101}),
        dot = new("Circle", {Filled = true, NumSides = 12, ZIndex = 102}),
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
    AP.shadow:set(0, 0, 0, 0, 0, Theme.Bg, 0)
    AP.border:set(0, 0, 0, 0, 0, Theme.Bg, 0)
    AP.bg:set(0, 0, 0, 0, 0, Theme.Bg, 0)
    AP.head:set(0, 0, 0, 0, 0, Theme.Bg, 0)
    AP.pill:set(0, 0, 0, 0, 0, Theme.Bg, 0)
    AP.line:set(0, 0, 0, 0, 0, accentAt)
    show(AP.headFix, 0); show(AP.liveGlow, 0); show(AP.live, 0)
    show(AP.title, 0); show(AP.countText, 0); show(AP.emptyText, 0)
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

local SHADOW_COL = Color3.new(0, 0, 0)

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
    local x = math.floor(vs.X - w - 18 + (1 - e) * 40 + 0.5)
    local y = 18

    -- корпус: мягкая тень, светящаяся акцентная рамка, фон
    AP.shadow:set(x + 3, y + 5, w, h, 11, SHADOW_COL, a * 0.35)
    local glowPulse = Settings.pulse and (0.75 + 0.25 * math.sin(clock * 2)) or 1
    AP.border:set(x - 1, y - 1, w + 2, h + 2, 11, cLerp(Theme.Bg, accentAt(0.3), 0.55 * glowPulse), a)
    AP.bg:set(x, y, w, h, 10, Theme.Bg, a)
    AP.head:set(x, y, w, hh, 10, Theme.Panel, a)
    AP.headFix.Position = Vector2.new(x, y + hh - 10)
    AP.headFix.Size = Vector2.new(w, 10)
    AP.headFix.Color = Theme.Panel
    show(AP.headFix, a)
    AP.line:set(x, y + hh - 2, w, 2, a, accentAt, edgeFade)

    -- live-индикатор: красный если есть админы, зелёный если нет
    local pulse = (clock * 0.9) % 1
    local liveCol = n > 0 and Color3.fromRGB(255, 80, 95) or Color3.fromRGB(70, 225, 140)
    local lp = Vector2.new(x + 18, y + hh / 2 - 1)
    AP.live.Position = lp
    AP.live.Radius = 4
    AP.live.Color = liveCol
    show(AP.live, a)
    AP.liveGlow.Position = lp
    AP.liveGlow.Radius = 4 + pulse * 7
    AP.liveGlow.Color = liveCol
    show(AP.liveGlow, a, 0.45 * (1 - pulse))

    local tb = bounds(AP.title)
    AP.title.Position = Vector2.new(x + 30, y + (hh - tb.Y) / 2 - 1)
    show(AP.title, a)

    -- счётчик в пилюле
    if AP.count ~= n then
        AP.count = n
        AP.countText.Text = tostring(n)
    end
    local cb = bounds(AP.countText)
    local pw = math.max(24, cb.X + 14)
    local px, py = x + w - 14 - pw, y + hh / 2 - 11
    local acc = accentAt(0.6)
    AP.pill:set(px, py, pw, 20, 10, cLerp(Theme.Panel, acc, 0.28), a)
    AP.countText.Position = Vector2.new(px + (pw - cb.X) / 2, py + (20 - cb.Y) / 2)
    AP.countText.Color = cLerp(Theme.Text, acc, 0.5)
    show(AP.countText, a)

    -- пусто
    AP.empty = damp(AP.empty, n == 0 and 1 or 0, 12, dt)
    AP.emptyText.Position = Vector2.new(x + 16 + (1 - AP.empty) * 8, y + hh + 12)
    show(AP.emptyText, a * AP.empty)

    -- строки
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
                    if r.nameT ~= entry.name then
                        r.nameT = entry.name
                        r.name.Text = entry.name
                    end
                    if r.roleT ~= entry.role then
                        r.roleT = entry.role
                        r.role.Text = entry.role
                        r.col = roleColor(entry.role)
                        r.role.Color = r.col
                        r.dot.Color = r.col
                        r.glow.Color = r.col
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
                r.dot.Radius = 4
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

--==================== labels ====================--

local CheaterLabels = {}
local CheaterState = setmetatable({}, {__mode = "k"})
local CheaterScanT = 0
local cheatShown = 0

local AdminTags = {}
local adminShown = 0

local CHEAT_OFF = Vector3.new(0, 2.5, 0)
local ADMIN_OFF = Vector3.new(0, 3, 0)

local function GetCheaterLabel(i)
    local o = CheaterLabels[i]
    if not o then
        o = new("Text", {
            Text = "CHEATER", Color = Color3.fromRGB(255, 60, 60),
            Outline = true, Font = FONT, Size = 14, Center = true, ZIndex = 10,
        })
        CheaterLabels[i] = o
    end
    return o
end

local function GetAdminTag(i)
    local t = AdminTags[i]
    if not t then
        t = {
            bg = RoundRect.new(9),
            text = new("Text", {
                Text = "ADMIN", Color = Color3.fromRGB(90, 200, 255),
                Outline = true, Font = FONT, Size = 14, Center = true, ZIndex = 12,
            }),
        }
        AdminTags[i] = t
    end
    return t
end

local function IsCheater(Player)
    local Age = GetAge(Player)
    if Age and Age <= 60 then return true end
    local Char = Player.Character
    local Hrp = Char and Char:FindFirstChild("HumanoidRootPart")
    if not Hrp then return false end
    local ok, vel = pcall(function() return Hrp.Velocity end)
    if ok and vel and (vel.Y <= -1000 or vel.Y >= 1000) then return true end
    return false
end

local function renderLabels()
    local cheatOn, adminOn = Flags.CheatDetector, Flags.AdminLabels
    if not cheatOn and not adminOn and cheatShown == 0 and adminShown == 0 then
        return
    end
    local players = getPlayers()

    -- cheaters (пометка липкая, остальных перепроверяем раз в 3 сек)
    local idx = 0
    if cheatOn then
        local now = tick()
        if now - CheaterScanT >= 3 then
            CheaterScanT = now
            for _, P in ipairs(players) do
                if not CheaterState[P] then
                    CheaterState[P] = IsCheater(P)
                end
            end
        end
        for _, P in ipairs(players) do
            if CheaterState[P] then
                local Head = getAliveHead(P)
                if Head then
                    local Screen, OnScreen = WorldToScreen(Head.Position + CHEAT_OFF)
                    if OnScreen and Screen then
                        idx += 1
                        local L = GetCheaterLabel(idx)
                        L.Position = Vector2.new(tonumber(Screen.X) or 0, tonumber(Screen.Y) or 0)
                        show(L, 1)
                    end
                end
            end
        end
    elseif cheatShown > 0 then
        table.clear(CheaterState)
    end
    for i = idx + 1, cheatShown do show(CheaterLabels[i], 0) end
    cheatShown = idx

    -- admin labels
    local aidx = 0
    if adminOn then
        for _, P in ipairs(players) do
            local Role = GetRole(P)
            if Role then
                local Head = getAliveHead(P)
                if Head then
                    local Screen, OnScreen = WorldToScreen(Head.Position + ADMIN_OFF)
                    if OnScreen and Screen then
                        aidx += 1
                        local tag = GetAdminTag(aidx)
                        if tag.role ~= Role then
                            tag.role = Role
                            tag.text.Text = string.upper(Role)
                            tag.text.Color = roleColor(Role)
                        end
                        local sx, sy = tonumber(Screen.X) or 0, tonumber(Screen.Y) or 0
                        tag.text.Position = Vector2.new(sx, sy)
                        show(tag.text, 1)

                        local b = bounds(tag.text)
                        tag.bg:set(sx - b.X / 2 - 8, sy - b.Y / 2 - 3, b.X + 16, b.Y + 6, 4, Theme.Bg, 0.75)
                    end
                end
            end
        end
    end
    for i = aidx + 1, adminShown do
        local tag = AdminTags[i]
        show(tag.text, 0)
        tag.bg:set(0, 0, 0, 0, 0, Theme.Bg, 0)
    end
    adminShown = aidx
end

--==================== inventory render ====================--

local function renderInventory()
    if not Flags.Inventory then
        if ArmorViewerTarget then
            ArmorViewerTarget = nil
            table.clear(SlotCache)
        end
        HideAllSlots()
        return
    end

    local Target = FindClosestTarget()
    local Char = Target and Target.Character
    if not Char then
        ArmorViewerTarget = nil
        table.clear(SlotCache)
        HideAllSlots()
        return
    end

    local Now = tick()
    if ArmorViewerTarget ~= Target or Now - ArmorLastUpdate >= ARMOR_INTERVAL then
        ArmorLastUpdate = Now
        ArmorViewerTarget = Target
        RebuildSlotCache(Char)
    else
        UpdateSlotCacheImages()
    end

    slotsHidden = false
    local Viewport = Camera.ViewportSize
    local TotalWidth = BoxCount * BoxSize + (BoxCount - 1) * BoxSpacing
    local StartX = math.floor((Viewport.X - TotalWidth) / 2)
    local Y = TopMargin
    for I = 1, BoxCount do
        local Slot = SlotCache[I]
        local Draw = SlotDrawings[I]
        local X = StartX + (I - 1) * (BoxSize + BoxSpacing)
        local moved = Draw.lastX ~= X or Draw.lastY ~= Y
        if moved then
            Draw.lastX, Draw.lastY = X, Y
            Draw.Bg.Position = Vector2.new(X, Y)
            Draw.Bg.Size = Vector2.new(BoxSize, BoxSize)
            Draw.Img.Position = Vector2.new(X + 2, Y + 2)
            Draw.Img.Size = Vector2.new(BoxSize - 4, BoxSize - 4)
        end
        show(Draw.Bg, 0.65)
        if Slot and Slot.Icon then
            if Draw.LastIcon ~= Slot.Icon then
                Draw.Img.Data = Slot.Icon
                Draw.LastIcon = Slot.Icon
            end
            show(Draw.Img, 1)
        else
            show(Draw.Img, 0)
            Draw.LastIcon = nil
        end
    end
end

local function renderFeatures(dt)
    renderAdminPanel(dt)
    renderLabels()
    if frameCounter % 2 == 0 then renderInventory() end
end

--==================== RENDER ====================--

local dragging, dragOff = false, Vector2.new()

local function renderBody(dt)
    if Win.destroyed then return end
    clock += dt * Settings.speed
    local m = getMouse()

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
    V.sideFix.Color = Theme.Panel
    show(V.sideFix, a)
    V.sideLine.From = Vector2.new(ox + SIDEBAR, oy + 14)
    V.sideLine.To = Vector2.new(ox + SIDEBAR, oy + H - 14)
    V.sideLine.Color = Theme.Stroke
    show(V.sideLine, a, 0.7)
    V.topBar:set(ox + R, oy, W - R * 2, 2, a, accentAt)

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
            p.o.Radius = p.r
            p.o.Color = accentAt(p.x)
            local edge = math.clamp(math.min(p.y, 1 - p.y) * 6, 0, 1)
            show(p.o, a, (0.25 + 0.35 * math.sin(clock * 2 + p.ph)) * edge * particleAnim)
        end
    end

    local lcx, lcy = ox + 28, oy + 28
    local orbitX = math.cos(clock * 2) * 4
    local orbitY = math.sin(clock * 2) * 4
    V.logoA.Position = Vector2.new(lcx + orbitX, lcy + orbitY)
    V.logoA.Radius = 8
    V.logoA.Color = Theme.AccentA
    V.logoB.Position = Vector2.new(lcx - orbitX, lcy - orbitY)
    V.logoB.Radius = 8
    V.logoB.Color = Theme.AccentB
    V.logoCore.Position = Vector2.new(lcx, lcy)
    V.logoCore.Radius = 3
    V.logoCore.Color = Color3.new(1, 1, 1)
    show(V.logoA, a, 0.85); show(V.logoB, a, 0.85); show(V.logoCore, a)

    V.title.Position = Vector2.new(ox + 46, oy + 14)
    V.title.Color = Theme.Text
    show(V.title, a)
    V.subtitle.Position = Vector2.new(ox + 46, oy + 33)
    V.subtitle.Color = Theme.SubText
    show(V.subtitle, a)
    V.sideDiv:set(ox + 14, oy + HEADER + 4, SIDEBAR - 28, 1, a, accentAt, edgeFade)

    local tabY0 = oy + HEADER + 18
    Win.indicatorY = damp(Win.indicatorY, (Win.active - 1) * 38, 16, dt)
    V.indicator:set(ox + 10, tabY0 + Win.indicatorY, SIDEBAR - 20, 32, 8, Theme.Element, a)
    V.indicatorBar.Position = Vector2.new(ox + 10, tabY0 + Win.indicatorY + 8)
    V.indicatorBar.Size = Vector2.new(3, 16)
    V.indicatorBar.Color = accentAt(0.2)
    show(V.indicatorBar, a)

    local active = Win.tabs[Win.active]
    local tabCount = math.max(1, #Win.tabs)
    for i, tab in ipairs(Win.tabs) do
        local ty = tabY0 + (i - 1) * 38
        local isActive = i == Win.active
        tab.rect = {ox + 10, ty, SIDEBAR - 20, 32}
        tab.hover = damp(tab.hover, (not isActive and inRect(m, tab.rect)) and 1 or 0, 12, dt)
        tab.sel = damp(tab.sel, isActive and 1 or 0, 12, dt)
        tab.alpha = damp(tab.alpha, isActive and 1 or 0, 30, dt)
        local lb = bounds(tab.label)
        tab.label.Position = Vector2.new(ox + 34 + tab.sel * 4 + tab.hover * 2, ty + 16 - lb.Y / 2)
        tab.label.Color = cLerp(Theme.SubText, Theme.Text, math.max(tab.sel, tab.hover * 0.6))
        show(tab.label, a)
        tab.icon.Position = Vector2.new(ox + 25, ty + 16)
        tab.icon.Radius = 3 + tab.sel * 1.2
        tab.icon.Color = cLerp(Theme.SubText, accentAt(i / tabCount), tab.sel)
        show(tab.icon, a)
    end

    V.hint.Position = Vector2.new(ox + 16, oy + H - 26)
    V.hint.Color = Theme.SubText
    show(V.hint, a, 0.7)

    if active then
        if V.pageTitle.Text ~= active.name then V.pageTitle.Text = active.name end
        if V.pageSub.Text ~= active.desc then V.pageSub.Text = active.desc end
        local ta = a * active.alpha
        V.pageTitle.Position = Vector2.new(ox + SIDEBAR + 20 + (1 - active.alpha) * 12, oy + 10)
        V.pageTitle.Color = Theme.Text
        show(V.pageTitle, ta)
        V.pageSub.Position = Vector2.new(ox + SIDEBAR + 20 + (1 - active.alpha) * 18, oy + 33)
        V.pageSub.Color = Theme.SubText
        show(V.pageSub, ta)
    end
    V.headerLine:set(ox + SIDEBAR + 16, oy + HEADER, W - SIDEBAR - 32, 1, a, accentAt, edgeFade)

    for i, d in ipairs(V.dots) do
        local p = Vector2.new(ox + W - 22 - (i - 1) * 22, oy + 28)
        d.rect = {p.X - 9, p.Y - 9, 18, 18}
        d.hover = damp(d.hover, inRect(m, d.rect) and 1 or 0, 14, dt)
        d.o.Position = p
        d.o.Radius = 5 + d.hover * 1.5
        d.o.Color = d.color
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
                local hovered = isAct and Win.open and inRect(m, el.rect)
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
    local ok, err = pcall(renderBody, dt)
    if not ok then reportError("renderBody", err) end

    -- внутри каждой секции дешёвый ранний выход, когда она выключена
    local ok2, err2 = pcall(renderFeatures, dt)
    if not ok2 then reportError("renderFeatures", err2) end
end

table.insert(Connections, RunService.RenderStepped:Connect(render))

--==================== INPUT ====================--

local prevM1, prevRShift, prevI = false, false, false

local function handleClick()
    if not Win.open or Win.alpha < 0.3 then return end
    local m = getMouse()
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
        dragging = true
        dragOff = Vector2.new(m.X - Win.tx, m.Y - Win.ty)
    end
end

local function updateDrag()
    if dragging then
        local m = getMouse()
        Win.tx = m.X - dragOff.X
        Win.ty = m.Y - dragOff.Y
    end
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    if Win.destroyed then return end
    local ok, err = pcall(function()
        local active = isrbxactive()
        if active == nil then active = true end

        local m1 = active and ismouse1pressed()
        if m1 and not prevM1 then
            handleClick()
        end
        if (not m1) and prevM1 then
            dragging = false
            for _, tab in ipairs(Win.tabs) do
                for _, el in ipairs(tab.elements) do
                    el.dragging = false
                end
            end
        end
        prevM1 = m1

        local rshift = active and iskeypressed(0xA1)
        if rshift and not prevRShift then
            Win.open = not Win.open
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

task.delay(0.6, function()
    Win:Notify("Aurora UI", "RightShift - menu  |  I - recoil", 4)
end)

print("[Aurora] loaded")

return Win
