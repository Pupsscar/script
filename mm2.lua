--[[
    Aurora Drones · Drawing API — v1.0
    T - запустить дрон (в полёте T ещё раз = самоподрыв), RightCtrl - меню.
    FPV: мышь - направление, W/S - газ, Shift - буст, A/D - рысканье, Space/Ctrl - вверх/вниз.
    Shahed: мышь - курс (медленный разворот), W/S - скорость.
    Влетел в игрока: роль murder (есть нож) - удар ножом, иначе флинг.
    Нас телепортирует к цели на мгновение и возвращает на место. Один удар за вылет.
    Matcha/внешние исполнители (нет Instance.new): дрон рисуется через Drawing как 3D-модель,
    летим своим персонажем от первого лица, звуков нет. Обычные исполнители: полный режим.
]]

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local env = (getgenv and getgenv()) or _G
if env.AuroraDrones then
    pcall(function() env.AuroraDrones:Destroy() end)
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

local new, tryNew, kill, show, setText, setSize, damp, accentAt, pulseK, bounds, inRect, dist, reportError, fireCallback
do
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

function new(class, props)
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

function tryNew(class, props)
    local ok, o = pcall(new, class, props)
    if ok then return o end
    return nil
end

function kill(o)
    if not o then return end
    for i = #Objects, 1, -1 do
        if Objects[i] == o then
            table.remove(Objects, i)
            break
        end
    end
    pcall(function() o:Remove() end)
end

function show(o, alpha, base)
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
function setText(o, text)
    if TextCache[o] ~= text then
        TextCache[o] = text
        o.Text = text
    end
end

function setSize(o, size)
    if SizeCache[o] ~= size then
        SizeCache[o] = size
        o.Size = size
        BoundsCache[o] = nil
    end
end

function damp(a, b, speed, dt)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    local r = a + (b - a) * (1 - math.exp(-(tonumber(speed) or 12) * (tonumber(dt) or (1/60))))
    if math.abs(b - r) < 0.002 then return b end
    return r
end

function accentAt(p)
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

function pulseK(speed, ph, lo)
    if not Settings.pulse then return 1 end
    lo = lo or 0.75
    local v = lo + (1 - lo) * (0.5 + 0.5 * math.sin(clock * (speed or 2) + (ph or 0)))
    return math.floor(v * 24 + 0.5) / 24
end

function bounds(t)
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

function inRect(m, r)
    if not m or not r then return false end
    local x, y, w, h = r[1], r[2], r[3], r[4]
    if type(x) ~= "number" or type(y) ~= "number"
        or type(w) ~= "number" or type(h) ~= "number" then
        return false
    end
    local mx, my = tonumber(m.X) or 0, tonumber(m.Y) or 0
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function dist(a, b)
    if not a or not b then return 9999 end
    local dx = (tonumber(a.X) or 0) - (tonumber(b.X) or 0)
    local dy = (tonumber(a.Y) or 0) - (tonumber(b.Y) or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local reported = {}
function reportError(where, err)
    local key = tostring(where) .. tostring(err)
    if reported[key] then return end
    reported[key] = true
    warn("[Aurora] " .. tostring(where) .. ": " .. tostring(err))
end

function fireCallback(cb, ...)
    if not cb then return end
    local ok, err = pcall(cb, ...)
    if not ok then reportError("callback", err) end
end
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

--==================== shared frame state ====================--

local CurMouse = Vector2.new()
local HoverAny = false
local MouseDown = false
local dragTarget, dragOff = nil, Vector2.new()

--==================== window ====================--

local W, H, HEADER, SIDEBAR, R = 620, 490, 56, 175, 10

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
V.subtitle = new("Text", {Text = "drones  |  v1.0", Size = 13, Font = FONT, ZIndex = 6, Color = Theme.SubText})
V.sideDiv = Gradient.new(16, 5)
V.indicator = RoundRect.new(4)
V.indicatorBar = new("Square", {Filled = true, Thickness = 1, ZIndex = 6, Size = Vector2.new(3, 16)})
V.pageTitle = new("Text", {Text = "", Size = 21, Font = FONT, ZIndex = 6, Color = Theme.Text})
V.pageSub = new("Text", {Text = "", Size = 13, Font = FONT, ZIndex = 6, Color = Theme.SubText})
V.headerLine = Gradient.new(24, 5)
V.hint = new("Text", {Text = "RightCtrl  -  hide", Size = 13, Font = FONT, ZIndex = 6, Color = Theme.SubText})
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


local IV = {} -- общие части интерфейса ждут эту таблицу (ресайз панелей тут не нужен)

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


--==================== DRONES ====================--

local function svc(name)
    local ok, s = pcall(function() return game:GetService(name) end)
    return ok and s or nil
end

local Lighting = svc("Lighting")
local CAS = svc("ContextActionService")
local Debris = svc("Debris")
local TweenService = svc("TweenService")
local SoundService = svc("SoundService")

-- что умеет исполнитель. Matcha (внешний) не создаёт Instance -> режим "body":
-- дрон рисуется через Drawing, а летим мы сами своим персонажем от первого лица
local HAS_INSTANCE = type(Instance) ~= "nil" and pcall(function()
    local f = Instance.new("Folder")
    f:Destroy()
end)
local FULL = HAS_INSTANCE and type(CFrame) ~= "nil" and type(RaycastParams) ~= "nil" and TweenService ~= nil

local VK, KC, keyDown, mouse1Down, robloxFocused, typingInChat, UPV, vdot, vcross, vunit, dirOf, yawPitchOf, basis, project, CamS, updateCam, pxPerStud
do
--==================== input (опрос, работает и во внешних исполнителях) ====================--

VK = {
    T = 0x54, W = 0x57, A = 0x41, S = 0x53, D = 0x44, ONE = 0x31,
    SPACE = 0x20, LSHIFT = 0xA0, LCTRL = 0xA2, RCTRL = 0xA3,
}
KC = Enum.KeyCode

function keyDown(vk, kc)
    if type(iskeypressed) == "function" then
        local ok, v = pcall(iskeypressed, vk)
        if ok then return v and true or false end
    end
    local ok, v = pcall(function() return UIS:IsKeyDown(kc) end)
    return ok and v or false
end

function mouse1Down()
    if type(ismouse1pressed) == "function" then
        local ok, v = pcall(ismouse1pressed)
        if ok then return v and true or false end
    end
    local ok, v = pcall(function() return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end)
    return ok and v or false
end

function robloxFocused()
    if type(isrbxactive) == "function" then
        local ok, v = pcall(isrbxactive)
        if ok and v ~= nil then return v end
    end
    return true
end

function typingInChat()
    local ok, box = pcall(function() return UIS:GetFocusedTextBox() end)
    return ok and box ~= nil
end

--==================== vector / camera helpers ====================--

UPV = Vector3.new(0, 1, 0)

function vdot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function vcross(a, b)
    return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function vunit(a)
    local m = a.Magnitude
    if m < 1e-6 then return Vector3.new(0, 0, -1) end
    return a * (1 / m)
end

-- направление по рысканью/тангажу (Roblox: yaw 0 = смотрим в -Z)
function dirOf(yaw, pitch)
    local cp = math.cos(pitch)
    return Vector3.new(-math.sin(yaw) * cp, math.sin(pitch), -math.cos(yaw) * cp)
end

function yawPitchOf(v)
    local m = v.Magnitude
    if m < 1e-6 then return 0, 0 end
    return math.atan2(-v.X, -v.Z), math.asin(math.clamp(v.Y / m, -1, 1))
end

-- базис дрона: R вправо, U вверх, F вперёд (+ крен)
function basis(yaw, pitch, roll)
    local F = dirOf(yaw, pitch)
    local R = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
    local U = vcross(R, F)
    if roll and roll ~= 0 then
        local c, s = math.cos(roll), math.sin(roll)
        R, U = R * c + U * s, U * c - R * s
    end
    return R, U, F
end

local W2S = WorldToScreen

function project(p)
    if type(W2S) == "function" then
        local ok, s, on = pcall(W2S, p)
        if ok and s then return s.X, s.Y, on and true or false end
        return 0, 0, false
    end
    local ok, v, on = pcall(function() return Camera:WorldToViewportPoint(p) end)
    if ok and v then return v.X, v.Y, (on and v.Z > 0) and true or false end
    return 0, 0, false
end

-- камера: если CFrame не читается (внешний исполнитель), направление взгляда
-- подбираем численно через WorldToScreen так, чтобы точка попала в центр экрана
CamS = {pos = nil, look = Vector3.new(0, 0, -1), right = Vector3.new(1, 0, 0), up = UPV, fov = 70, yaw = 0, pitch = 0}
local CAM_CF_OK = nil

local function solveAim(origin)
    local vs = Camera.ViewportSize
    local cx, cy = vs.X / 2, vs.Y / 2
    local yaw, pitch = CamS.yaw, CamS.pitch
    local RANGE, h = 120, 0.004
    for _ = 1, 3 do
        local x0, y0, on = project(origin + dirOf(yaw, pitch) * RANGE)
        if not on then
            -- точка за кадром: разворачиваемся по направлению персонажа
            local _, hrp = nil, LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local ok, lv = pcall(function() return hrp.CFrame.LookVector end)
            if ok and lv then yaw, pitch = yawPitchOf(lv) else yaw = yaw + math.pi end
            break
        end
        local ex, ey = x0 - cx, y0 - cy
        if ex * ex + ey * ey < 1 then break end
        local xa, ya = project(origin + dirOf(yaw + h, pitch) * RANGE)
        local xb, yb = project(origin + dirOf(yaw, pitch + h) * RANGE)
        local j11, j12 = (xa - x0) / h, (xb - x0) / h
        local j21, j22 = (ya - y0) / h, (yb - y0) / h
        local det = j11 * j22 - j12 * j21
        if math.abs(det) < 1e-6 then break end
        local dy = (-ex * j22 + ey * j12) / det
        local dp = (-ey * j11 + ex * j21) / det
        yaw += math.clamp(dy, -0.5, 0.5)
        pitch = math.clamp(pitch + math.clamp(dp, -0.5, 0.5), -1.5, 1.5)
    end
    CamS.yaw, CamS.pitch = yaw, pitch
end

function updateCam()
    local ok, p, l = false, nil, nil
    if CAM_CF_OK ~= false then
        ok, p, l = pcall(function()
            local cf = Camera.CFrame
            return cf.Position, cf.LookVector
        end)
        if CAM_CF_OK == nil then CAM_CF_OK = (ok and p ~= nil and l ~= nil) end
    end
    if ok and p and l then
        CamS.pos, CamS.look = p, l
        CamS.yaw, CamS.pitch = yawPitchOf(l)
    else
        local ch = LocalPlayer.Character
        local head = ch and (ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart"))
        if head then
            local origin = head.Position
            solveAim(origin)
            CamS.pos = origin
            CamS.look = dirOf(CamS.yaw, CamS.pitch)
        end
    end
    local R, U = basis(CamS.yaw, CamS.pitch, 0)
    CamS.right, CamS.up = R, U
    local okf, f = pcall(function() return Camera.FieldOfView end)
    CamS.fov = (okf and tonumber(f)) or 70
end

-- пикселей на студ на заданной глубине
function pxPerStud(depth)
    local vs = Camera.ViewportSize
    return (vs.Y / 2) / math.tan(math.rad(CamS.fov) / 2) / math.max(depth, 0.1)
end
end

local MONO = (Drawing.Fonts and Drawing.Fonts.Monospace) or 3
local STUD_M = 0.28 -- 1 stud ~ 0.28 м
local TAKEOFF = 0.75

local DroneCfg = {
    kind = "FPV",        -- "FPV" | "SHAHED"
    enabled = true,
    useKnife = true,     -- если у нас нож (роль murder) - удар ножом
    flingPower = 1,
    hitRadius = 1,
    battery = 40,        -- секунд полёта для FPV (шахед x2.2)
    sensitivity = 1,
    fovFPV = 110,
    volume = 0.8,
    fx = {color = true, noise = true, scan = true, osd = true, shake = true},
}

local Specs = {
    FPV = {
        name = "FPV KAMIKAZE", desc = "fast  |  agile  |  short battery",
        cruise = 60, min = 8, max = 135, boost = 1.35, accel = 2.6, inertia = 5,
        turn = 2.4, hit = 4.5, fov = 110, batMul = 1, stats = {0.92, 0.95, 0.4},
    },
    SHAHED = {
        name = "SHAHED-136", desc = "loitering  |  heavy  |  long range",
        cruise = 80, min = 55, max = 120, boost = 1.2, accel = 1.1, inertia = 2.2,
        turn = 1.1, hit = 7, fov = 72, batMul = 2.2, stats = {0.72, 0.35, 1.0},
    },
}

local SND, SoundFolder, makeSound, playOnce, addFx, makeMotor
do
--==================== sounds ====================--
-- встроенные звуки клиента Roblox: есть у всех и не бывают приватными.
-- свой звук: поставь "rbxassetid://ID" первым в список, встроенный останется запасным
-- (если свой не загрузится за 3 сек - переключится на следующий)

SND = {
    fpvMotor = {"rbxasset://sounds/Rocket whoosh 01.wav"},
    shahedMotor = {"rbxasset://sounds/Rocket whoosh 01.wav"},
    launch = {"rbxasset://sounds/swoosh.wav"},
    boom = {"rbxasset://sounds/collide.wav", "rbxasset://sounds/Rocket shot.wav"},
    beep = {"rbxasset://sounds/electronicpingshort.wav"},
}

SoundFolder = nil
if FULL then
    SoundFolder = Instance.new("Folder")
    SoundFolder.Name = "AuroraDroneSFX"
    SoundFolder.Parent = SoundService
end

function makeSound(list, props, parent)
    local s = Instance.new("Sound")
    for k, v in pairs(props or {}) do s[k] = v end
    s.SoundId = list[1]
    s.Parent = parent or SoundFolder
    if #list > 1 then
        task.spawn(function()
            for i = 2, #list do
                local t0 = tick()
                while tick() - t0 < 3 and s.Parent and s.TimeLength <= 0 do task.wait(0.2) end
                if not s.Parent or s.TimeLength > 0 then return end
                s.SoundId = list[i]
            end
        end)
    end
    return s
end

function playOnce(list, vol, speed, parent)
    if not FULL then return nil end
    local s = makeSound(list, {Volume = vol * DroneCfg.volume, PlaybackSpeed = speed or 1}, parent)
    s:Play()
    Debris:AddItem(s, 8)
    return s
end

function addFx(class, parent, props)
    local ok, fx = pcall(function()
        local e = Instance.new(class)
        for k, v in pairs(props) do e[k] = v end
        e.Parent = parent
        return e
    end)
    return ok and fx or nil
end

-- мотор: один луп + эффекты. FPV - высокий злой жужж, шахед - "мопед"
function makeMotor(kind)
    local s = makeSound(kind == "FPV" and SND.fpvMotor or SND.shahedMotor, {Looped = true, Volume = 0})
    local dist = addFx("DistortionSoundEffect", s, {Level = kind == "FPV" and 0.55 or 0.8})
    if kind == "FPV" then
        addFx("EqualizerSoundEffect", s, {HighGain = 6, MidGain = 3, LowGain = -10})
        addFx("ChorusSoundEffect", s, {Depth = 0.45, Rate = 9, Mix = 0.5})
    else
        addFx("TremoloSoundEffect", s, {Depth = 0.9, Frequency = 18, Duty = 0.55})
        addFx("EqualizerSoundEffect", s, {LowGain = 7, MidGain = 2, HighGain = -6})
    end
    s:Play()
    return s, dist
end
end

--==================== models ====================--

local FX = nil
if FULL then
    FX = Instance.new("Folder")
    FX.Name = "AuroraDroneFX"
    FX.Parent = workspace
end

local V3, RAD = Vector3.new, math.rad
local CFn = FULL and CFrame.new or nil
local ANG = FULL and CFrame.Angles or nil
local VERT = FULL and ANG(0, 0, RAD(90)) or nil    -- цилиндр стоя
local ALONGZ = FULL and ANG(0, RAD(90), 0) or nil  -- цилиндр вдоль Z
local MAT = Enum.Material

local DC = {
    CARBON = Color3.fromRGB(30, 30, 33),
    DARK = Color3.fromRGB(16, 16, 18),
    ORANGE = Color3.fromRGB(255, 112, 28),
    RED = Color3.fromRGB(205, 40, 40),
    OLIVE = Color3.fromRGB(96, 74, 44),
    OLIVE_D = Color3.fromRGB(70, 54, 32),
    TAPE = Color3.fromRGB(225, 230, 235),
    SILVER = Color3.fromRGB(165, 168, 172),
    SH_GREY = Color3.fromRGB(198, 200, 196),
    SH_DARK = Color3.fromRGB(58, 60, 63),
}

local moveModel, buildFPV, buildShahed, spawnExplosion
do
local function mk(class, size, color, mat, props)
    local p = Instance.new(class)
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Size = size
    p.Color = color
    p.Material = mat or MAT.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    if props then for k, v in pairs(props) do p[k] = v end end
    return p
end

local function cyl(size, color, mat, props)
    local p = mk("Part", size, color, mat, props)
    p.Shape = Enum.PartType.Cylinder
    return p
end

local function ball(d, color, mat)
    local p = mk("Part", V3(d, d, d), color, mat)
    p.Shape = Enum.PartType.Ball
    return p
end

local function newModel()
    local m = {folder = Instance.new("Model"), parts = {}, offs = {}, spin = {}, cfs = {}}
    m.folder.Name = "AuroraDrone"
    return m
end

local function add(m, part, off, spin)
    part.Parent = m.folder
    local i = #m.parts + 1
    m.parts[i] = part
    m.offs[i] = off
    if spin then
        spin.i = i
        m.spin[#m.spin + 1] = spin
    end
    return part
end

-- двигаем всю модель одним BulkMoveTo
function moveModel(m, cf, phase)
    if not m then return end
    local cfs = m.cfs
    local offs = m.offs
    for i = 1, #offs do cfs[i] = cf * offs[i] end
    for _, s in ipairs(m.spin) do
        local a = phase * s.speed
        cfs[s.i] = cf * offs[s.i] * (s.axis == "Z" and ANG(0, 0, a) or ANG(0, a, 0))
    end
    local ok = pcall(function()
        workspace:BulkMoveTo(m.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
    end)
    if not ok then
        for i, p in ipairs(m.parts) do p.CFrame = cfs[i] end
    end
end


-- FPV-камикадзе как на фото: рама X, 4 мотора, камера, АКБ, антенна, БЧ снизу на скотче
function buildFPV()
    local m = newModel()
    add(m, mk("Part", V3(0.8, 0.1, 1.2), DC.CARBON, MAT.Metal), CFn(0, 0, 0))
    add(m, mk("Part", V3(0.7, 0.06, 1.0), DC.CARBON, MAT.Metal), CFn(0, 0.24, 0))
    for _, s in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
        add(m, cyl(V3(0.22, 0.05, 0.05), DC.SILVER, MAT.Metal), CFn(s[1] * 0.3, 0.12, s[2] * 0.45) * VERT)
    end
    local dirs = {{1, -1, 1}, {-1, -1, -1}, {1, 1, -1}, {-1, 1, 1}}
    for _, d in ipairs(dirs) do
        local sx, sz, rot = d[1], d[2], d[3]
        local ang = math.atan2(sx, sz)
        add(m, mk("Part", V3(0.14, 0.07, 1.5), DC.CARBON, MAT.Metal), CFn(sx * 0.55, 0, sz * 0.55) * ANG(0, ang, 0))
        add(m, cyl(V3(0.3, 0.28, 0.28), DC.DARK, MAT.Metal), CFn(sx * 1.05, 0.12, sz * 1.05) * VERT)
        add(m, cyl(V3(0.06, 0.3, 0.3), Color3.fromRGB(120, 122, 128), MAT.Metal), CFn(sx * 1.05, 0.28, sz * 1.05) * VERT)
        add(m, cyl(V3(0.02, 1.25, 1.25), Color3.fromRGB(45, 45, 50), MAT.SmoothPlastic, {Transparency = 0.78}),
            CFn(sx * 1.05, 0.32, sz * 1.05) * VERT)
        add(m, mk("Part", V3(1.15, 0.025, 0.11), Color3.fromRGB(22, 22, 24)),
            CFn(sx * 1.05, 0.32, sz * 1.05), {axis = "Y", speed = rot})
    end
    -- камера
    add(m, mk("Part", V3(0.36, 0.32, 0.3), DC.DARK, MAT.Metal), CFn(0, 0.24, -0.6))
    add(m, mk("Part", V3(0.04, 0.3, 0.28), DC.ORANGE), CFn(0.2, 0.24, -0.6))
    add(m, mk("Part", V3(0.04, 0.3, 0.28), DC.ORANGE), CFn(-0.2, 0.24, -0.6))
    add(m, cyl(V3(0.08, 0.22, 0.22), Color3.fromRGB(10, 10, 14), MAT.Glass, {Reflectance = 0.35}), CFn(0, 0.25, -0.78) * ALONGZ)
    -- АКБ + провода + скотч
    add(m, mk("Part", V3(0.42, 0.3, 0.75), DC.DARK), CFn(0, 0.42, 0.05))
    add(m, mk("Part", V3(0.44, 0.32, 0.07), DC.ORANGE), CFn(0, 0.42, -0.15))
    add(m, mk("Part", V3(0.46, 0.34, 0.5), DC.TAPE, MAT.SmoothPlastic, {Transparency = 0.62}), CFn(0, 0.42, 0.08))
    add(m, mk("Part", V3(0.05, 0.05, 0.45), DC.RED), CFn(0.12, 0.6, -0.02) * ANG(RAD(-12), 0, 0))
    add(m, mk("Part", V3(0.05, 0.05, 0.45), DC.DARK), CFn(0.04, 0.61, -0.02) * ANG(RAD(-12), 0, 0))
    -- антенна
    add(m, cyl(V3(0.9, 0.045, 0.045), DC.DARK), CFn(0.14, 0.78, 0.5) * ANG(RAD(18), 0, 0) * VERT)
    add(m, mk("Part", V3(0.1, 0.14, 0.1), DC.DARK), CFn(0.14, 1.2, 0.64))
    -- БЧ (выстрел РПГ) вдоль Z под рамой, нос вперёд
    add(m, cyl(V3(1.0, 0.6, 0.6), DC.OLIVE, MAT.Metal), CFn(0, -0.42, 0.1) * ALONGZ)
    add(m, cyl(V3(0.3, 0.52, 0.52), DC.OLIVE, MAT.Metal), CFn(0, -0.42, -0.52) * ALONGZ)
    add(m, cyl(V3(0.3, 0.42, 0.42), DC.OLIVE, MAT.Metal), CFn(0, -0.42, -0.8) * ALONGZ)
    add(m, cyl(V3(0.3, 0.32, 0.32), DC.OLIVE, MAT.Metal), CFn(0, -0.42, -1.07) * ALONGZ)
    add(m, cyl(V3(0.25, 0.22, 0.22), DC.OLIVE, MAT.Metal), CFn(0, -0.42, -1.32) * ALONGZ)
    add(m, cyl(V3(0.22, 0.13, 0.13), DC.SILVER, MAT.Metal), CFn(0, -0.42, -1.54) * ALONGZ)
    add(m, cyl(V3(0.35, 0.5, 0.5), DC.OLIVE_D, MAT.Metal), CFn(0, -0.42, 0.75) * ALONGZ)
    add(m, cyl(V3(0.4, 0.42, 0.42), DC.DARK, MAT.Metal), CFn(0, -0.42, 1.1) * ALONGZ)
    add(m, cyl(V3(0.22, 0.64, 0.64), DC.TAPE, MAT.SmoothPlastic, {Transparency = 0.55}), CFn(0, -0.42, -0.05) * ALONGZ)
    add(m, cyl(V3(0.22, 0.64, 0.64), DC.TAPE, MAT.SmoothPlastic, {Transparency = 0.55}), CFn(0, -0.42, 0.35) * ALONGZ)
    add(m, mk("Part", V3(0.5, 0.55, 0.12), DC.TAPE, MAT.SmoothPlastic, {Transparency = 0.6}), CFn(0, -0.15, 0.2))
    return m
end

-- Shahed-136: дельта-крыло, законцовки, толкающий винт
function buildShahed()
    local m = newModel()
    add(m, cyl(V3(6.2, 0.95, 0.95), DC.SH_GREY, MAT.SmoothPlastic), CFn(0, 0, 0.2) * ALONGZ)
    add(m, cyl(V3(0.5, 0.85, 0.85), DC.SH_GREY), CFn(0, 0, -3.15) * ALONGZ)
    add(m, cyl(V3(0.45, 0.7, 0.7), DC.SH_GREY), CFn(0, 0, -3.6) * ALONGZ)
    add(m, cyl(V3(0.4, 0.52, 0.52), DC.SH_GREY), CFn(0, 0, -4.0) * ALONGZ)
    add(m, ball(0.5, DC.SH_GREY), CFn(0, 0, -4.22))
    -- крылья (WedgePart, повёрнутый на бок = треугольник)
    add(m, mk("WedgePart", V3(0.14, 4.2, 5.2), DC.SH_GREY), CFn(2.55, 0.05, 1.0) * ANG(0, 0, RAD(-90)))
    add(m, mk("WedgePart", V3(0.14, 4.2, 5.2), DC.SH_GREY), CFn(-2.55, 0.05, 1.0) * ANG(0, 0, RAD(90)))
    -- законцовки
    add(m, mk("WedgePart", V3(0.14, 1.4, 1.3), DC.SH_DARK), CFn(4.62, 0, 3.0))
    add(m, mk("WedgePart", V3(0.14, 1.4, 1.3), DC.SH_DARK), CFn(-4.62, 0, 3.0))
    -- мотор и винт
    add(m, cyl(V3(0.7, 0.78, 0.78), DC.DARK, MAT.Metal), CFn(0, 0, 3.55) * ALONGZ)
    add(m, cyl(V3(0.25, 0.32, 0.32), DC.DARK, MAT.Metal), CFn(0, 0, 4.0) * ALONGZ)
    add(m, cyl(V3(0.02, 2.3, 2.3), Color3.fromRGB(40, 40, 44), MAT.SmoothPlastic, {Transparency = 0.82}), CFn(0, 0, 4.05) * ALONGZ)
    add(m, mk("Part", V3(0.2, 2.3, 0.06), DC.DARK), CFn(0, 0, 4.05), {axis = "Z", speed = 1})
    -- надпись на правом крыле
    local plate = mk("Part", V3(2.6, 0.02, 0.55), DC.SH_GREY, MAT.SmoothPlastic, {Transparency = 1})
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Top
    sg.CanvasSize = Vector2.new(520, 110)
    sg.Parent = plate
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.fromScale(1, 1)
    tl.BackgroundTransparency = 1
    tl.Text = "SHAHED-136"
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.TextColor3 = Color3.fromRGB(20, 20, 22)
    tl.Parent = sg
    add(m, plate, CFn(2.0, 0.14, 2.3) * ANG(0, RAD(-90), 0))
    return m
end

--==================== explosion ====================--

local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local function tween(o, t, props, style)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function emitter(parent, props, n)
    local e = Instance.new("ParticleEmitter")
    e.Enabled = false
    for k, v in pairs(props) do e[k] = v end
    e.Parent = parent
    e:Emit(n)
end

function spawnExplosion(pos, kind)
    local sc = kind == "SHAHED" and 1.7 or 1
    pcall(function()
        local e = Instance.new("Explosion")
        e.Position = pos
        e.BlastRadius = 6 * sc
        e.BlastPressure = 0
        e.DestroyJointRadiusPercent = 0
        e.ExplosionType = Enum.ExplosionType.NoCraters
        e.Parent = FX
    end)

    local holder = mk("Part", V3(1, 1, 1), Color3.new(), nil, {Transparency = 1, CFrame = CFn(pos)})
    holder.Parent = FX

    local core = ball(1, Color3.new(1, 1, 1), MAT.Neon)
    core.CFrame = CFn(pos)
    core.Parent = FX
    tween(core, 0.18, {Size = V3(9, 9, 9) * sc, Transparency = 1})

    local fb = ball(1, Color3.fromRGB(255, 195, 95), MAT.Neon)
    fb.CFrame = CFn(pos)
    fb.Parent = FX
    tween(fb, 0.55, {Size = V3(16, 16, 16) * sc, Transparency = 1, Color = Color3.fromRGB(255, 70, 20)})

    local ring = cyl(V3(0.3, 2, 2), Color3.fromRGB(255, 230, 200), MAT.Neon, {Transparency = 0.25, CFrame = CFn(pos) * VERT})
    ring.Parent = FX
    tween(ring, 0.6, {Size = V3(0.3, 42, 42) * sc, Transparency = 1})

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 150, 60)
    light.Brightness = 9
    light.Range = 40 * sc
    light.Parent = holder
    tween(light, 0.9, {Brightness = 0})

    pcall(emitter, holder, {
        Texture = SMOKE_TEX, Color = ColorSequence.new(Color3.fromRGB(70, 66, 62), Color3.fromRGB(25, 24, 24)),
        Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 3 * sc), NumberSequenceKeypoint.new(1, 13 * sc)}),
        Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1)}),
        Lifetime = NumberRange.new(1.6, 3.2), Speed = NumberRange.new(5, 14), SpreadAngle = Vector2.new(180, 180),
        Drag = 2.5, Acceleration = V3(0, 4, 0), RotSpeed = NumberRange.new(-40, 40), Rotation = NumberRange.new(0, 360),
    }, math.floor(26 * sc))
    pcall(emitter, holder, {
        Texture = FIRE_TEX, Color = ColorSequence.new(Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 60, 10)),
        LightEmission = 1,
        Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4 * sc), NumberSequenceKeypoint.new(1, 0)}),
        Lifetime = NumberRange.new(0.35, 0.8), Speed = NumberRange.new(8, 22), SpreadAngle = Vector2.new(180, 180), Drag = 4,
    }, math.floor(20 * sc))
    pcall(emitter, holder, {
        Texture = SPARK_TEX, Color = ColorSequence.new(Color3.fromRGB(255, 220, 150)), LightEmission = 1,
        Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)}),
        Lifetime = NumberRange.new(0.5, 1.2), Speed = NumberRange.new(30, 70), SpreadAngle = Vector2.new(180, 180),
        Acceleration = V3(0, -60, 0),
    }, 36)

    -- обломки
    for _ = 1, math.floor(8 * sc) do
        local p = mk("Part", V3(0.25, 0.15, 0.35) * (0.6 + math.random()), DC.DARK, MAT.Metal)
        p.CFrame = CFn(pos)
        p.Parent = FX
        local dir = V3(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
        tween(p, 0.9, {
            CFrame = CFn(pos + dir * (10 + math.random() * 12) * sc) * ANG(math.random() * 6, math.random() * 6, 0),
            Transparency = 1,
        }, Enum.EasingStyle.Quad)
        Debris:AddItem(p, 1.2)
    end

    local s3d = makeSound(SND.boom, {
        Volume = 2 * DroneCfg.volume, RollOffMinDistance = 15, RollOffMaxDistance = 700, PlaybackSpeed = kind == "SHAHED" and 0.7 or 0.9,
    }, holder)
    s3d:Play()
    playOnce(SND.boom, 0.9, 0.55) -- низкий бас поверх

    Debris:AddItem(holder, 5)
    Debris:AddItem(core, 1)
    Debris:AddItem(fb, 1)
    Debris:AddItem(ring, 1)
end
end

--==================== character helpers ====================--

local function myChar()
    local c = LocalPlayer.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChild("Humanoid")
    return c, hrp, hum
end

local function findKnife()
    local c = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    for _, cont in ipairs({c, bp}) do
        if cont then
            for _, t in ipairs(cont:GetChildren()) do
                local okc, isTool = pcall(function() return t:IsA("Tool") end)
                if not okc then isTool = t.ClassName == "Tool" end
                if isTool and string.find(string.lower(t.Name), "knife") then
                    return t
                end
            end
        end
    end
    return nil
end

local KnifeState = {t = 0, has = false}
local function hasKnife()
    local now = tick()
    if now - KnifeState.t > 0.5 then
        KnifeState.t = now
        KnifeState.has = findKnife() ~= nil
    end
    return KnifeState.has
end

local function segDist(a, b, p)
    local ab = b - a
    local l2 = vdot(ab, ab)
    local t = 0
    if l2 > 1e-6 then t = math.clamp(vdot(p - a, ab) / l2, 0, 1) end
    return (a + ab * t - p).Magnitude
end

--==================== strike ====================--
-- один раз за полёт: телепорт к цели -> нож (murder) или флинг -> назад на место

local function performStrike(target)
    local char, hrp, hum = myChar()
    local tch = target.Character
    local thrp = tch and tch:FindFirstChild("HumanoidRootPart")
    local thum = tch and tch:FindFirstChild("Humanoid")
    if not (hrp and hum and hum.Health > 0 and thrp and thum and thum.Health > 0) then
        return "miss"
    end

    local home = hrp.CFrame
    local knife = DroneCfg.useKnife and findKnife() or nil
    local result = "miss"

    if knife then
        local wasEquipped = knife.Parent == char
        if not wasEquipped then
            pcall(function() hum:EquipTool(knife) end)
            task.wait(0.05)
        end
        local handle = knife:FindFirstChild("Handle")
        local t0 = tick()
        while tick() - t0 < 0.7 and thum.Health > 0 and thrp.Parent do
            local behind = (thrp.CFrame * CFn(0, 0, 1.8)).Position
            hrp.CFrame = CFrame.lookAt(behind, thrp.Position)
            hrp.AssemblyLinearVelocity = Vector3.zero
            pcall(function() knife:Activate() end)
            if handle and firetouchinterest then
                pcall(firetouchinterest, handle, thrp, 0)
                pcall(firetouchinterest, handle, thrp, 1)
            end
            RunService.Heartbeat:Wait()
        end
        result = thum.Health <= 0 and "knife" or "miss"
        if not wasEquipped then pcall(function() hum:UnequipTools() end) end
    else
        local power = 9000 * DroneCfg.flingPower
        local t0 = tick()
        while tick() - t0 < 0.5 and thrp.Parent do
            RunService.Heartbeat:Wait()
            hrp.CFrame = thrp.CFrame * CFn((math.random() - 0.5) * 1.2, 0, (math.random() - 0.5) * 1.2)
            hrp.AssemblyLinearVelocity = V3(power, power * 1.5, power)
            hrp.AssemblyAngularVelocity = V3(0, power, 0)
            RunService.RenderStepped:Wait()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        result = "fling"
    end

    for _ = 1, 5 do
        hrp.CFrame = home
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    return result
end

--==================== flight ====================--

local Fly = {active = false, phase = "idle", cooldown = 0, flash = 0, lossT = 0}

local rayParams = nil
if FULL then
    rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true
end

local function refreshRayFilter()
    if rayParams then rayParams.FilterDescendantsInstances = {FX, LocalPlayer.Character} end
end

local meshFPV, meshShahed, renderMesh, hideMesh, startBoom, renderBoom
do
--==================== drawing-mesh дрона (режим body / Matcha) ====================--
-- модель описана гранями в локальных координатах (X вправо, Y вверх, -Z вперёд),
-- каждый кадр проецируется через WorldToScreen, сортируется по глубине и освещается

local MESH_MODE = "line"
do
    local q = tryNew("Quad", {Filled = true, Thickness = 1})
    if q then
        MESH_MODE = "quad"
        kill(q)
    else
        local t = tryNew("Triangle", {Filled = true, Thickness = 1})
        if t then
            MESH_MODE = "tri"
            kill(t)
        end
    end
end

local BOX_Q = {{1, 2, 3, 4}, {6, 5, 8, 7}, {5, 1, 4, 8}, {2, 6, 7, 3}, {4, 3, 7, 8}, {5, 6, 2, 1}}

local function face(list, pts, col, alpha, spin)
    list[#list + 1] = {p = pts, col = col, a = alpha or 1, spin = spin}
end

local function rotY(x, z, a)
    local c, s = math.cos(a), math.sin(a)
    return x * c + z * s, -x * s + z * c
end

local function rbox(list, cx, cy, cz, sx, sy, sz, yaw, col, alpha, spin)
    local hx, hy, hz = sx / 2, sy / 2, sz / 2
    local cs = {{-hx, -hy, -hz}, {hx, -hy, -hz}, {hx, hy, -hz}, {-hx, hy, -hz},
        {-hx, -hy, hz}, {hx, -hy, hz}, {hx, hy, hz}, {-hx, hy, hz}}
    local v = {}
    for i, c in ipairs(cs) do
        local x, z = c[1], c[3]
        if yaw ~= 0 then x, z = rotY(x, z, yaw) end
        v[i] = {cx + x, cy + c[2], cz + z}
    end
    for _, q in ipairs(BOX_Q) do
        face(list, {v[q[1]], v[q[2]], v[q[3]], v[q[4]]}, col, alpha, spin)
    end
end

-- призма/усечённый конус вдоль Z
local function zprism(list, cx, cy, z0, z1, r0, r1, n, col, alpha)
    local ring0, ring1 = {}, {}
    for i = 1, n do
        local a = (i - 0.5) / n * math.pi * 2
        ring0[i] = {cx + math.cos(a) * r0, cy + math.sin(a) * r0, z0}
        ring1[i] = {cx + math.cos(a) * r1, cy + math.sin(a) * r1, z1}
    end
    for i = 1, n do
        local j = i % n + 1
        face(list, {ring0[i], ring0[j], ring1[j], ring1[i]}, col, alpha)
    end
    for side = 1, 2 do
        local ring, r = side == 1 and ring0 or ring1, side == 1 and r0 or r1
        if r > 0.02 then
            for i = 2, n - 2, 2 do
                face(list, {ring[1], ring[i], ring[i + 1], ring[math.min(i + 2, n)]}, col, alpha)
            end
        end
    end
end

local BLADE_COL = Color3.fromRGB(28, 28, 32)

function meshFPV()
    local L = {}
    rbox(L, 0, 0, 0, 0.8, 0.1, 1.2, 0, DC.CARBON)
    rbox(L, 0, 0.24, 0, 0.7, 0.06, 1.0, 0, DC.CARBON)
    for _, d in ipairs({{1, -1, 1}, {-1, -1, -1}, {1, 1, -1}, {-1, 1, 1}}) do
        local sx, sz, rot = d[1], d[2], d[3]
        rbox(L, sx * 0.55, 0, sz * 0.55, 0.14, 0.07, 1.5, math.atan2(sx, sz), DC.CARBON)
        rbox(L, sx * 1.05, 0.12, sz * 1.05, 0.28, 0.28, 0.28, 0.785, DC.DARK)
        rbox(L, sx * 1.05, 0.32, sz * 1.05, 1.15, 0.025, 0.11, 0, BLADE_COL, 1,
            {axis = "Y", c1 = sx * 1.05, c2 = sz * 1.05, speed = rot})
    end
    rbox(L, 0, 0.24, -0.6, 0.36, 0.32, 0.3, 0, DC.DARK)
    rbox(L, 0.2, 0.24, -0.6, 0.04, 0.3, 0.28, 0, DC.ORANGE)
    rbox(L, -0.2, 0.24, -0.6, 0.04, 0.3, 0.28, 0, DC.ORANGE)
    rbox(L, 0, 0.42, 0.05, 0.42, 0.3, 0.75, 0, DC.DARK)
    rbox(L, 0, 0.42, -0.15, 0.44, 0.32, 0.07, 0, DC.ORANGE)
    rbox(L, 0.14, 0.78, 0.5, 0.05, 0.9, 0.05, 0, DC.DARK)
    -- БЧ
    zprism(L, 0, -0.42, -0.4, 0.6, 0.3, 0.3, 6, DC.OLIVE)
    zprism(L, 0, -0.42, -1.45, -0.4, 0.07, 0.3, 6, DC.OLIVE)
    zprism(L, 0, -0.42, -1.62, -1.45, 0.06, 0.07, 6, DC.SILVER)
    zprism(L, 0, -0.42, 0.6, 1.3, 0.24, 0.24, 6, DC.DARK)
    zprism(L, 0, -0.42, -0.08, 0.12, 0.32, 0.32, 6, DC.TAPE, 0.55)
    return L
end

function meshShahed()
    local L = {}
    zprism(L, 0, 0, -2.9, 3.3, 0.47, 0.47, 6, DC.SH_GREY)
    zprism(L, 0, 0, -4.35, -2.9, 0.12, 0.47, 6, DC.SH_GREY)
    face(L, {{0.45, 0.05, -1.6}, {0.45, 0.05, 3.6}, {4.65, 0.05, 3.6}, {4.65, 0.05, 3.6}}, DC.SH_GREY)
    face(L, {{-0.45, 0.05, -1.6}, {-0.45, 0.05, 3.6}, {-4.65, 0.05, 3.6}, {-4.65, 0.05, 3.6}}, DC.SH_GREY)
    for _, sx in ipairs({4.62, -4.62}) do
        face(L, {{sx, -0.6, 2.6}, {sx, -0.6, 3.65}, {sx, 0.7, 3.65}, {sx, 0.7, 3.15}}, DC.SH_DARK)
    end
    zprism(L, 0, 0, 3.2, 3.9, 0.39, 0.39, 6, DC.DARK)
    face(L, {{-0.1, -1.15, 4.05}, {0.1, -1.15, 4.05}, {0.1, 1.15, 4.05}, {-0.1, 1.15, 4.05}}, DC.DARK, 1,
        {axis = "Z", c1 = 0, c2 = 0, speed = 1})
    return L
end

local MESH_Z = 100
local MeshPool = {}
local MeshShown = 0
local MeshItems, MeshOrder = {}, {}
local LIGHT = vunit(Vector3.new(0.35, 1, 0.25))

local function meshObj(i)
    local o = MeshPool[i]
    if o then return o end
    if MESH_MODE == "quad" then
        o = {q = new("Quad", {Filled = true, Thickness = 1, ZIndex = MESH_Z})}
    elseif MESH_MODE == "tri" then
        o = {
            t1 = new("Triangle", {Filled = true, Thickness = 1, ZIndex = MESH_Z}),
            t2 = new("Triangle", {Filled = true, Thickness = 1, ZIndex = MESH_Z}),
        }
    else
        o = {l = {}}
        for k = 1, 4 do o.l[k] = new("Line", {Thickness = 1, ZIndex = MESH_Z}) end
    end
    MeshPool[i] = o
    return o
end

local function hideMeshObj(o)
    if o.q then show(o.q, 0) end
    if o.t1 then show(o.t1, 0); show(o.t2, 0) end
    if o.l then for _, l in ipairs(o.l) do show(l, 0) end end
end

function hideMesh()
    for i = 1, MeshShown do hideMeshObj(MeshPool[i]) end
    MeshShown = 0
end

local function meshSort(a, b) return a.d > b.d end

function renderMesh(faces, O, R, U, F, scale, alpha, phase, near)
    local camPos, camF = CamS.pos, CamS.look
    if not camPos or alpha <= 0 then
        hideMesh()
        return
    end
    near = near or 0.3
    local n = 0
    local sx, sy, wp = {}, {}, {}
    for _, f in ipairs(faces) do
        local ok, depthSum, anyOn = true, 0, false
        local sp = f.spin
        local c, s = 1, 0
        if sp then
            local ang = phase * sp.speed
            c, s = math.cos(ang), math.sin(ang)
        end
        for k = 1, 4 do
            local lp = f.p[k]
            local x, y, z = lp[1], lp[2], lp[3]
            if sp then
                if sp.axis == "Y" then
                    local dx, dz = x - sp.c1, z - sp.c2
                    x, z = sp.c1 + dx * c + dz * s, sp.c2 - dx * s + dz * c
                else
                    local dx, dy = x - sp.c1, y - sp.c2
                    x, y = sp.c1 + dx * c - dy * s, sp.c2 + dx * s + dy * c
                end
            end
            local w = O + R * (x * scale) + U * (y * scale) - F * (z * scale)
            local d = vdot(w - camPos, camF)
            if d < near then
                ok = false
                break
            end
            local px, py, on = project(w)
            if on then anyOn = true end
            sx[k], sy[k], wp[k] = px, py, w
            depthSum += d
        end
        if ok and anyOn then
            n += 1
            local it = MeshItems[n]
            if not it then
                it = {}
                MeshItems[n] = it
            end
            it.f = f
            it.d = depthSum / 4
            it.x1, it.y1, it.x2, it.y2 = sx[1], sy[1], sx[2], sy[2]
            it.x3, it.y3, it.x4, it.y4 = sx[3], sy[3], sx[4], sy[4]
            local nrm = vcross(wp[2] - wp[1], wp[3] - wp[1])
            if nrm.Magnitude < 1e-6 then nrm = vcross(wp[3] - wp[1], wp[4] - wp[1]) end
            local lit = 0.42 + 0.58 * math.abs(vdot(vunit(nrm), LIGHT))
            local col = f.col
            it.col = Color3.new(math.min(1, col.R * lit * 1.1), math.min(1, col.G * lit * 1.1), math.min(1, col.B * lit * 1.1))
        end
    end

    table.clear(MeshOrder)
    for i = 1, n do MeshOrder[i] = MeshItems[i] end
    table.sort(MeshOrder, meshSort)

    for i, it in ipairs(MeshOrder) do
        local o = meshObj(i)
        local z = MESH_Z + i
        local a = alpha * it.f.a
        if o.q then
            o.q.PointA = Vector2.new(it.x1, it.y1)
            o.q.PointB = Vector2.new(it.x2, it.y2)
            o.q.PointC = Vector2.new(it.x3, it.y3)
            o.q.PointD = Vector2.new(it.x4, it.y4)
            o.q.Color = it.col
            if o.z ~= z then o.z = z; o.q.ZIndex = z end
            show(o.q, a)
        elseif o.t1 then
            o.t1.PointA = Vector2.new(it.x1, it.y1)
            o.t1.PointB = Vector2.new(it.x2, it.y2)
            o.t1.PointC = Vector2.new(it.x3, it.y3)
            o.t2.PointA = Vector2.new(it.x1, it.y1)
            o.t2.PointB = Vector2.new(it.x3, it.y3)
            o.t2.PointC = Vector2.new(it.x4, it.y4)
            o.t1.Color = it.col
            o.t2.Color = it.col
            if o.z ~= z then
                o.z = z
                o.t1.ZIndex = z
                o.t2.ZIndex = z
            end
            show(o.t1, a)
            show(o.t2, a)
        else
            local xs = {it.x1, it.x2, it.x3, it.x4}
            local ys = {it.y1, it.y2, it.y3, it.y4}
            for k = 1, 4 do
                local l = o.l[k]
                local j = k % 4 + 1
                l.From = Vector2.new(xs[k], ys[k])
                l.To = Vector2.new(xs[j], ys[j])
                l.Color = it.col
                show(l, a)
            end
        end
    end
    for i = #MeshOrder + 1, MeshShown do hideMeshObj(MeshPool[i]) end
    MeshShown = #MeshOrder
end

--==================== взрыв на Drawing ====================--

local BOOMZ = 265
local Boom = {t = 99, hidden = true, k = 1, sparks = {}, smoke = {}, fire = {}}
Boom.core = new("Circle", {Filled = true, NumSides = 32, ZIndex = BOOMZ + 3, Color = WHITE})
Boom.fire[1] = new("Circle", {Filled = true, NumSides = 32, ZIndex = BOOMZ, Color = Color3.fromRGB(205, 55, 20)})
Boom.fire[2] = new("Circle", {Filled = true, NumSides = 32, ZIndex = BOOMZ + 1, Color = Color3.fromRGB(255, 130, 40)})
Boom.fire[3] = new("Circle", {Filled = true, NumSides = 32, ZIndex = BOOMZ + 2, Color = Color3.fromRGB(255, 225, 150)})
Boom.ring = new("Circle", {Filled = false, Thickness = 3, NumSides = 48, ZIndex = BOOMZ + 4, Color = Color3.fromRGB(255, 232, 205)})
for i = 1, 26 do
    Boom.sparks[i] = {o = new("Line", {Thickness = 2, ZIndex = BOOMZ + 5, Color = Color3.fromRGB(255, 205, 120)})}
end
for i = 1, 12 do
    Boom.smoke[i] = {o = new("Circle", {Filled = true, NumSides = 24, ZIndex = BOOMZ - 1})}
end

local function hideBoom()
    show(Boom.core, 0); show(Boom.ring, 0)
    for _, f in ipairs(Boom.fire) do show(f, 0) end
    for _, s in ipairs(Boom.sparks) do show(s.o, 0) end
    for _, s in ipairs(Boom.smoke) do show(s.o, 0) end
end

local function randDir()
    local v = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
    return vunit(v)
end

function startBoom(pos, big)
    Boom.t = 0
    Boom.pos = pos
    Boom.k = big and 1.7 or 1
    for _, s in ipairs(Boom.sparks) do
        s.dir = randDir()
        s.speed = 25 + math.random() * 35
    end
    for _, s in ipairs(Boom.smoke) do
        s.off = randDir() * (1 + math.random() * 2)
        s.g = 0.2 + math.random() * 0.1
    end
end

function renderBoom(dt)
    if Boom.t > 3.2 or not Boom.pos then
        if not Boom.hidden then
            Boom.hidden = true
            hideBoom()
        end
        return
    end
    Boom.hidden = false
    Boom.t += dt
    local t, k, pos = Boom.t, Boom.k, Boom.pos
    if not CamS.pos then return end
    local depth = vdot(pos - CamS.pos, CamS.look)
    if depth < 0.5 then
        hideBoom()
        return
    end
    local x, y = project(pos)
    local pps = pxPerStud(depth)
    local c = Vector2.new(x, y)
    local function rad(st) return math.min(2500, st * k * pps) end

    local e = 1 - (1 - math.min(t / 0.5, 1)) ^ 3
    local fa = math.clamp(1 - t / 0.75, 0, 1)
    local sizes = {2 + 8 * e, 1.5 + 6 * e, 1 + 4 * e}
    for i, f in ipairs(Boom.fire) do
        f.Position = c
        f.Radius = rad(sizes[i])
        show(f, fa, i == 3 and 1 or 0.88)
    end
    Boom.core.Position = c
    Boom.core.Radius = rad(3)
    show(Boom.core, math.clamp(1 - t / 0.2, 0, 1))
    Boom.ring.Position = c
    Boom.ring.Radius = rad(1 + 22 * t)
    show(Boom.ring, t < 0.8 and (1 - t / 0.8) * 0.8 or 0)

    local sa = math.clamp(1 - t / 1.1, 0, 1)
    local drop = Vector3.new(0, -5 * t * t, 0)
    for _, s in ipairs(Boom.sparks) do
        if sa > 0 then
            local d = s.speed * (1 - math.exp(-3 * t)) / 3 * k
            local p1 = pos + s.dir * d + drop
            local p2 = pos + s.dir * math.max(0, d - 1.6 * k) + drop
            local x1, y1 = project(p1)
            local x2, y2 = project(p2)
            s.o.From = Vector2.new(x1, y1)
            s.o.To = Vector2.new(x2, y2)
            show(s.o, sa)
        else
            show(s.o, 0)
        end
    end

    local smA = 0.55 * math.min(1, t / 0.3) * math.clamp(1 - (t - 0.3) / 2.9, 0, 1)
    for _, s in ipairs(Boom.smoke) do
        local p = pos + s.off * (k * (1 + t * 0.8)) + UPV * (t * 2.5)
        local sxp, syp = project(p)
        s.o.Position = Vector2.new(sxp, syp)
        s.o.Radius = rad(1.5 + t * 2.2)
        s.o.Color = Color3.new(s.g, s.g * 0.97, s.g * 0.95)
        show(s.o, smA)
    end
end
end

local ZERO3, setPos, setVel, setRotVel, forceFirstPerson, setPlatform, bodyReturn, bodyStrike, bodyRay
do
--==================== body flight helpers ====================--

ZERO3 = Vector3.new(0, 0, 0)

function setPos(part, v)
    if not pcall(function() part.Position = v end) then
        pcall(function() part.CFrame = CFrame.new(v) end)
    end
end

function setVel(part, v)
    pcall(function() part.Velocity = v end)
    pcall(function() part.AssemblyLinearVelocity = v end)
end

function setRotVel(part, v)
    pcall(function() part.RotVelocity = v end)
    pcall(function() part.AssemblyAngularVelocity = v end)
end

local function clickOnce()
    if type(mouse1click) == "function" then
        pcall(mouse1click)
    elseif type(mouse1press) == "function" and type(mouse1release) == "function" then
        pcall(mouse1press)
        task.wait(0.02)
        pcall(mouse1release)
    end
end

local function pressKey(vk)
    if type(keypress) == "function" and type(keyrelease) == "function" then
        pcall(keypress, vk)
        task.wait(0.03)
        pcall(keyrelease, vk)
        return true
    end
    return false
end

local CamSave = nil
function forceFirstPerson(on)
    if on then
        CamSave = {}
        pcall(function() CamSave.mode = LocalPlayer.CameraMode end)
        pcall(function() CamSave.min = LocalPlayer.CameraMinZoomDistance end)
        pcall(function() CamSave.max = LocalPlayer.CameraMaxZoomDistance end)
        pcall(function() LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson end)
        pcall(function() LocalPlayer.CameraMinZoomDistance = 0.5 end)
        pcall(function() LocalPlayer.CameraMaxZoomDistance = 0.5 end)
    elseif CamSave then
        local s = CamSave
        CamSave = nil
        pcall(function() if s.max then LocalPlayer.CameraMaxZoomDistance = s.max end end)
        pcall(function() if s.min then LocalPlayer.CameraMinZoomDistance = s.min end end)
        pcall(function() if s.mode then LocalPlayer.CameraMode = s.mode end end)
    end
end

function setPlatform(on)
    local _, _, hum = myChar()
    if hum then pcall(function() hum.PlatformStand = on end) end
end

function bodyReturn(home)
    local _, hrp = myChar()
    if not (hrp and home) then return end
    for _ = 1, 6 do
        setPos(hrp, home)
        setVel(hrp, ZERO3)
        setRotVel(hrp, ZERO3)
        task.wait()
    end
end

-- мы уже у цели (летели своим телом): нож или флинг, потом домой
function bodyStrike(target)
    local char, hrp, hum = myChar()
    local home = Fly.home
    local result = "none"
    if target and hrp and hum then
        local tch = target.Character
        local thrp = tch and tch:FindFirstChild("HumanoidRootPart")
        local thum = tch and tch:FindFirstChild("Humanoid")
        if thrp and thum and thum.Health > 0 then
            local approach = (Fly.vel and Fly.vel.Magnitude > 0.1) and vunit(Fly.vel) or CamS.look
            approach = vunit(Vector3.new(approach.X, 0, approach.Z))
            local knife = DroneCfg.useKnife and findKnife() or nil
            if knife then
                local pressed = false
                if knife.Parent ~= char then
                    pcall(function() hum:EquipTool(knife) end)
                    task.wait(0.03)
                    if knife.Parent ~= char then pressed = pressKey(VK.ONE) end
                    task.wait(0.06)
                end
                local handle = knife:FindFirstChild("Handle")
                local t0 = tick()
                while tick() - t0 < 0.8 and thum.Health > 0 do
                    setPos(hrp, thrp.Position - approach * 1.3)
                    setVel(hrp, ZERO3)
                    pcall(function() knife:Activate() end)
                    clickOnce()
                    if handle and type(firetouchinterest) == "function" then
                        pcall(firetouchinterest, handle, thrp, 0)
                        pcall(firetouchinterest, handle, thrp, 1)
                    end
                    task.wait()
                end
                result = thum.Health <= 0 and "knife" or "miss"
                if pressed and knife.Parent == char then pressKey(VK.ONE) end
            else
                local power = 9000 * DroneCfg.flingPower
                local t0 = tick()
                while tick() - t0 < 0.55 do
                    setPos(hrp, thrp.Position + Vector3.new((math.random() - 0.5) * 1.2, 0, (math.random() - 0.5) * 1.2))
                    setVel(hrp, Vector3.new(power, power * 1.5, power))
                    setRotVel(hrp, Vector3.new(0, power, 0))
                    task.wait()
                    setVel(hrp, ZERO3)
                    setRotVel(hrp, ZERO3)
                end
                result = "fling"
            end
        end
    end
    bodyReturn(home)
    return result
end

local RAY_OK = true
function bodyRay(origin, dir, char)
    if not RAY_OK then return nil end
    local ok, r = pcall(function() return workspace:Raycast(origin, dir) end)
    if not ok then
        RAY_OK = false
        return nil
    end
    if r and r.Instance then
        local inst = r.Instance
        for _ = 1, 6 do
            if not inst then break end
            if inst == char then return nil end
            inst = inst.Parent
        end
        return r
    end
    return nil
end
end

local fullEnd, impact, fullLaunch
do
local function bodyCF()
    if Fly.kind == "FPV" then
        local tilt = -(Fly.speed / Fly.spec.max) * 0.45
        return CFn(Fly.pos) * CFrame.fromEulerAnglesYXZ(Fly.pitch + tilt, Fly.yaw, Fly.roll * 1.3)
    end
    return CFn(Fly.pos) * CFrame.fromEulerAnglesYXZ(Fly.pitch, Fly.yaw, Fly.roll)
end

local function camCF(shake)
    local rollK = Fly.kind == "FPV" and 1 or 0.6
    local base = CFn(Fly.pos) * CFrame.fromEulerAnglesYXZ(Fly.pitch, Fly.yaw, Fly.roll * rollK)
    local off = Fly.kind == "FPV" and CFn(0, 0.25, -0.85) or CFn(0, 0.12, -4.75)
    return base * off * (shake or CFrame.identity)
end

function fullEnd()
    pcall(function() RunService:UnbindFromRenderStep("AuroraDroneCam") end)
    pcall(function() CAS:UnbindAction("AuroraDroneSink") end)
    if Fly.model then Fly.model.folder:Destroy() end
    if Fly.motor then Fly.motor:Destroy() end
    if Fly.cc then Fly.cc:Destroy() end
    if Fly.blur then Fly.blur:Destroy() end
    Fly.model, Fly.motor, Fly.motorDist, Fly.cc, Fly.blur = nil, nil, nil, nil, nil

    local _, _, hum = myChar()
    pcall(function()
        Camera.CameraType = Enum.CameraType.Custom
        if hum then Camera.CameraSubject = hum end
        Camera.FieldOfView = Fly.fovFrom or 70
    end)
    pcall(function()
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
    end)
    Fly.active = false
    Fly.phase = "idle"
    Fly.cooldown = tick() + 1.5
end

function impact(target, hitPos)
    if Fly.phase == "impact" then return end
    Fly.phase = "impact"
    Fly.lossT = 0.95
    Fly.flash = 1
    Fly.strikeMsg = target and ("TARGET  " .. string.upper(target.Name)) or "NO TARGET"
    local mode = Fly.mode
    if mode ~= "full" then
        startBoom(hitPos, Fly.kind == "SHAHED")
        Fly.striking = true
        task.spawn(function()
            local ok, res = pcall(bodyStrike, target)
            Fly.striking = false
            if not ok then reportError("strike", res) return end
            if target then
                local msg = res == "knife" and "Eliminated: " or (res == "fling" and "Flung: " or "Missed: ")
                Win:Notify("Strike", msg .. target.Name, 3)
            end
        end)
        return
    end
    Fly.camFrozen = Camera.CFrame
    if Fly.model then
        Fly.model.folder:Destroy()
        Fly.model = nil
    end
    -- обрыв связи: мотор превращается в шипение и затихает
    local motor, md = Fly.motor, Fly.motorDist
    if motor then
        motor.PlaybackSpeed = 3.2
        motor.Volume = 0.35 * DroneCfg.volume
        if md then md.Level = 1 end
        task.delay(0.5, function() pcall(function() motor:Stop() end) end)
    end
    spawnExplosion(hitPos, Fly.kind)

    if target then
        Fly.striking = true
        task.spawn(function()
            local ok, res = pcall(performStrike, target)
            Fly.striking = false
            if not ok then reportError("strike", res) return end
            if res == "knife" then
                Win:Notify("Strike", "Eliminated: " .. target.Name, 3)
            elseif res == "fling" then
                Win:Notify("Strike", "Flung: " .. target.Name, 3)
            else
                Win:Notify("Strike", "Missed: " .. target.Name, 3)
            end
        end)
    end
end

local function flightStep(dt)
    if not Fly.active then return end
    dt = math.min(dt, 1 / 20)
    pcall(function()
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
        UIS.MouseIconEnabled = false
    end)
    Camera.CameraType = Enum.CameraType.Scriptable
    local spec = Fly.spec
    local fpv = Fly.kind == "FPV"
    Fly.t += dt

    local _, _, hum = myChar()
    if Fly.phase ~= "impact" and (not hum or hum.Health <= 0) then
        impact(nil, Fly.pos)
    end

    if Fly.phase == "takeoff" then
        local k = math.clamp(Fly.t / TAKEOFF, 0, 1)
        local e = k * k * (3 - 2 * k)
        local fwd = CFrame.fromEulerAnglesYXZ(0, Fly.yaw, 0).LookVector
        Fly.pos = Fly.spawn + V3(0, 3 * e, 0) + (fpv and Vector3.zero or fwd * (e * e * 8))
        Fly.prop += dt * (12 + 40 * e)
        moveModel(Fly.model, bodyCF(), Fly.prop)
        Camera.CFrame = Fly.camFrom:Lerp(camCF(), e)
        Camera.FieldOfView = Fly.fovFrom + (Fly.fov - Fly.fovFrom) * e
        if Fly.motor then
            Fly.motor.Volume = 0.5 * DroneCfg.volume * e
            Fly.motor.PlaybackSpeed = fpv and (0.8 + 1.2 * e) or (0.4 + 0.2 * e)
        end
        if k >= 1 then
            Fly.phase = "flight"
            Fly.speed = fpv and 12 or spec.cruise * 0.8
            Fly.vel = fwd * Fly.speed
        end
        return
    end

    if Fly.phase == "impact" then
        Fly.lossT -= dt
        local amp = math.max(0, Fly.lossT) * 0.03
        local n = clock * 40
        Camera.CFrame = Fly.camFrozen * ANG(math.noise(n, 0.2) * amp, math.noise(0.4, n) * amp, math.noise(n, n) * amp)
        if Fly.lossT <= 0 and not Fly.striking then fullEnd() end
        return
    end

    -- управление
    local md = UIS:GetMouseDelta()
    local sens = DroneCfg.sensitivity
    local kW = keyDown(VK.W, KC.W)
    local kS = keyDown(VK.S, KC.S)
    local kA = keyDown(VK.A, KC.A)
    local kD = keyDown(VK.D, KC.D)
    local boost = keyDown(VK.LSHIFT, KC.LeftShift)
    local yawIn = (kA and 1 or 0) - (kD and 1 or 0)
    local prevYaw = Fly.yaw

    if fpv then
        Fly.yaw -= md.X * 0.0032 * sens
        Fly.pitch = math.clamp(Fly.pitch - md.Y * 0.0032 * sens, -1.45, 1.45)
        Fly.yaw += yawIn * spec.turn * dt * 0.8
    else
        local maxStep = spec.turn * dt
        Fly.yaw += math.clamp(-md.X * 0.0024 * sens + yawIn * spec.turn * dt * 0.7, -maxStep, maxStep)
        Fly.pitch = math.clamp(Fly.pitch + math.clamp(-md.Y * 0.0024 * sens, -maxStep * 0.8, maxStep * 0.8), -0.95, 0.6)
    end
    local yawRate = (Fly.yaw - prevYaw) / math.max(dt, 1e-3)
    local rollT = fpv and math.clamp(yawRate * 0.12, -0.85, 0.85) or math.clamp(yawRate * 0.75, -0.9, 0.9)
    Fly.roll = damp(Fly.roll, rollT, 7, dt)

    Fly.bat -= dt
    local target
    if Fly.bat <= 0 then
        target = 0
    elseif kW then
        target = spec.max * (boost and spec.boost or 1)
    elseif kS then
        target = spec.min
    else
        target = spec.cruise
    end
    Fly.speed = damp(Fly.speed, target, spec.accel, dt)

    local look = CFrame.fromEulerAnglesYXZ(Fly.pitch, Fly.yaw, 0).LookVector
    local desired = look * Fly.speed
    local lift = 0
    if fpv then
        lift = (keyDown(VK.SPACE, KC.Space) and 1 or 0) - (keyDown(VK.LCTRL, KC.LeftControl) and 1 or 0)
        desired += V3(0, lift * 30, 0)
    end
    Fly.vel = Fly.vel:Lerp(desired, 1 - math.exp(-spec.inertia * dt))
    if Fly.bat <= 0 then
        -- батарея/топливо кончились: падаем
        Fly.vel += V3(0, -45 * dt, 0)
        Fly.pitch = damp(Fly.pitch, -1.2, 0.8, dt)
    end
    local newPos = Fly.pos + Fly.vel * dt

    -- попадание в игрока
    local hitPlr, hitPos = nil, nil
    local hitR = spec.hit * DroneCfg.hitRadius
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local ch = p.Character
            local thrp = ch and ch:FindFirstChild("HumanoidRootPart")
            local th = ch and ch:FindFirstChild("Humanoid")
            if thrp and th and th.Health > 0 and segDist(Fly.pos, newPos, thrp.Position) < hitR then
                hitPlr, hitPos = p, thrp.Position
                break
            end
        end
    end
    -- стены/земля
    if not hitPos then
        local dir = newPos - Fly.pos
        if dir.Magnitude > 1e-3 then
            local r = workspace:Raycast(Fly.pos, dir + dir.Unit * 0.7, rayParams)
            if r then
                local mdl = r.Instance:FindFirstAncestorOfClass("Model")
                local p = mdl and Players:GetPlayerFromCharacter(mdl)
                if p == LocalPlayer then p = nil end
                hitPlr, hitPos = p, r.Position
            end
        end
    end
    if hitPos then
        Fly.pos = hitPos
        impact(hitPlr, hitPos)
        return
    end
    if newPos.Y < workspace.FallenPartsDestroyHeight + 5 then
        impact(nil, newPos)
        return
    end
    Fly.pos = newPos

    local sr = math.clamp(Fly.speed / spec.max, 0, 1.4)
    Fly.prop += dt * (fpv and (25 + Fly.speed * 0.5) or 60)
    moveModel(Fly.model, bodyCF(), Fly.prop)

    if Fly.motor then
        local vol = DroneCfg.volume
        if Fly.bat <= 0 then
            Fly.motor.Volume = damp(Fly.motor.Volume, 0, 3, dt)
        elseif fpv then
            Fly.motor.PlaybackSpeed = 1.5 + sr * 1.6 + math.abs(lift) * 0.2
            Fly.motor.Volume = (0.35 + 0.35 * sr) * vol
        else
            Fly.motor.PlaybackSpeed = 0.55 + sr * 0.25
            Fly.motor.Volume = 0.6 * vol
        end
    end

    local amp = 0
    if DroneCfg.fx.shake then
        amp = fpv and (0.0025 + 0.006 * sr) or 0.0015
    end
    local n = clock * 25
    local sh = ANG(math.noise(n, 0.3) * amp, math.noise(0.7, n) * amp, math.noise(n, n * 0.5) * amp * 0.6)
    Camera.CFrame = camCF(sh)
    Camera.FieldOfView = damp(Camera.FieldOfView, Fly.fov + (fpv and sr * 8 or 0), 6, dt)
end

local function sinkInput()
    return Enum.ContextActionResult.Sink
end

function fullLaunch()
    if Fly.active or Win.destroyed then return end
    if tick() < Fly.cooldown then
        Win:Notify("Drone", "Recharging...", 1.5)
        return
    end
    local _, hrp, hum = myChar()
    if not (hrp and hum and hum.Health > 0) then return end

    Win.open = false
    dragTarget = nil
    refreshRayFilter()

    local kind = DroneCfg.kind
    local spec = Specs[kind]
    local look = Camera.CFrame.LookVector
    local flat = V3(look.X, 0, look.Z)
    flat = flat.Magnitude > 0.01 and flat.Unit or V3(0, 0, -1)
    local spawn = hrp.Position + flat * 5 + V3(0, 2, 0)
    local r = workspace:Raycast(hrp.Position, spawn - hrp.Position, rayParams)
    if r then spawn = r.Position - (spawn - hrp.Position).Unit * 1.2 end

    local model = kind == "FPV" and buildFPV() or buildShahed()
    model.folder.Parent = FX

    Fly.active = true
    Fly.mode = "full"
    Fly.phase = "takeoff"
    Fly.kind = kind
    Fly.spec = spec
    Fly.model = model
    Fly.t = 0
    Fly.prop = 0
    Fly.spawn = spawn
    Fly.pos = spawn
    Fly.home = hrp.Position
    Fly.vel = Vector3.zero
    Fly.speed = 0
    Fly.yaw = math.atan2(-flat.X, -flat.Z)
    Fly.pitch = 0
    Fly.roll = 0
    Fly.batMax = DroneCfg.battery * spec.batMul
    Fly.bat = Fly.batMax
    Fly.flash = 0
    Fly.lossT = 0
    Fly.striking = false
    Fly.lock = nil
    Fly.camFrom = Camera.CFrame
    Fly.fovFrom = Camera.FieldOfView
    Fly.fov = kind == "FPV" and DroneCfg.fovFPV or spec.fov

    moveModel(model, bodyCF(), 0)

    if DroneCfg.fx.color then
        Fly.cc = addFx("ColorCorrectionEffect", Lighting, kind == "FPV"
            and {Name = "AuroraDroneCC", Saturation = -0.25, Contrast = 0.18, Brightness = 0.02, TintColor = Color3.fromRGB(255, 248, 238)}
            or {Name = "AuroraDroneCC", Saturation = -1, Contrast = 0.35, Brightness = 0.05, TintColor = Color3.fromRGB(215, 255, 222)})
        Fly.blur = addFx("BlurEffect", Lighting, {Name = "AuroraDroneBlur", Size = kind == "FPV" and 2 or 1})
    end

    Fly.motor, Fly.motorDist = makeMotor(kind)
    playOnce(SND.launch, 0.8, kind == "FPV" and 1.3 or 0.8)
    playOnce(SND.beep, 0.5, 1)

    pcall(function()
        CAS:BindActionAtPriority("AuroraDroneSink", sinkInput, false, 3000,
            Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight,
            Enum.PlayerActions.CharacterJump,
            Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
            Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl,
            Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2)
    end)
    local ok = pcall(function()
        RunService:BindToRenderStep("AuroraDroneCam", Enum.RenderPriority.Camera.Value + 1, flightStep)
    end)
    if not ok then
        local conn
        conn = RunService.RenderStepped:Connect(function(dt)
            if not Fly.active then conn:Disconnect() return end
            flightStep(dt)
        end)
    end
end
end


local bodyEnd, bodyStep, launchDrone
do
--==================== body flight (Matcha) ====================--

local SOUND_WARNED = false

function bodyEnd()
    hideMesh()
    forceFirstPerson(false)
    setPlatform(false)
    Fly.active = false
    Fly.phase = "idle"
    Fly.cooldown = tick() + 1.5
end

local function bodyLaunch()
    local _, hrp = myChar()
    pcall(updateCam)
    local flat = Vector3.new(CamS.look.X, 0, CamS.look.Z)
    flat = flat.Magnitude > 0.01 and vunit(flat) or Vector3.new(0, 0, -1)
    local kind = DroneCfg.kind
    local spec = Specs[kind]

    Fly.active = true
    Fly.mode = "body"
    Fly.phase = "deploy"
    Fly.kind = kind
    Fly.spec = spec
    Fly.mesh = kind == "FPV" and meshFPV() or meshShahed()
    Fly.t = 0
    Fly.prop = 0
    Fly.home = hrp.Position
    Fly.spawn = hrp.Position + flat * 6 + Vector3.new(0, 2.5, 0)
    Fly.pos = Fly.spawn
    Fly.vel = ZERO3
    Fly.speed = 0
    Fly.yaw = yawPitchOf(flat)
    Fly.pitch = 0
    Fly.roll = 0
    Fly.batMax = DroneCfg.battery * spec.batMul
    Fly.bat = Fly.batMax
    Fly.flash = 0
    Fly.lossT = 0
    Fly.striking = false
    Fly.lock = nil

    if not FULL and not SOUND_WARNED then
        SOUND_WARNED = true
        Win:Notify("Matcha mode", "Executor can't create sounds or parts - drawing only", 4)
    end
end

function bodyStep(dt)
    if not Fly.active or Fly.mode ~= "body" then return end
    dt = math.min(dt, 1 / 20)
    local char, hrp, hum = myChar()
    local spec = Fly.spec
    local fpv = Fly.kind == "FPV"
    Fly.t += dt

    if Fly.phase ~= "impact" and (not hrp or not hum or hum.Health <= 0) then
        impact(nil, Fly.pos)
        return
    end

    -- дрон собирается рядом с нами, потом "заходим" в него
    if Fly.phase == "deploy" then
        local k = math.clamp(Fly.t / 0.8, 0, 1)
        local e = k * k * (3 - 2 * k)
        Fly.prop += dt * (10 + 40 * e)
        local R, U, F = basis(Fly.yaw, 0, 0)
        local O = Fly.spawn + Vector3.new(0, (1 - e) * -1.5, 0)
        renderMesh(Fly.mesh, O, R, U, F, (fpv and 1.6 or 0.8) * (0.3 + 0.7 * e), e, Fly.prop)
        if k >= 1 then
            Fly.home = hrp.Position
            Fly.pos = Fly.spawn
            setPlatform(true)
            forceFirstPerson(true)
            setPos(hrp, Fly.pos)
            setVel(hrp, ZERO3)
            Fly.phase = "flight"
            Fly.flash = 0.5
            Fly.speed = fpv and 15 or spec.cruise * 0.8
            Fly.vel = F * Fly.speed
        end
        return
    end

    if Fly.phase == "impact" then
        Fly.lossT -= dt
        hideMesh()
        if Fly.lossT <= 0 and not Fly.striking then bodyEnd() end
        return
    end

    -- курс = куда смотрит камера (мышь двигает камеру от первого лица)
    local prevYaw = Fly.yaw
    if fpv then
        Fly.yaw = CamS.yaw
        Fly.pitch = math.clamp(CamS.pitch, -1.45, 1.45)
    else
        local maxStep = spec.turn * dt
        local dy = (CamS.yaw - Fly.yaw + math.pi) % (2 * math.pi) - math.pi
        Fly.yaw += math.clamp(dy, -maxStep, maxStep)
        local tp = math.clamp(CamS.pitch, -0.95, 0.6)
        Fly.pitch += math.clamp(tp - Fly.pitch, -maxStep * 0.8, maxStep * 0.8)
    end
    local dyaw = (Fly.yaw - prevYaw + math.pi) % (2 * math.pi) - math.pi
    local yawRate = dyaw / math.max(dt, 1e-3)
    local rollT = fpv and math.clamp(yawRate * 0.12, -0.85, 0.85) or math.clamp(yawRate * 0.75, -0.9, 0.9)
    Fly.roll = damp(Fly.roll, rollT, 7, dt)

    local kW = keyDown(VK.W, KC.W)
    local kS = keyDown(VK.S, KC.S)
    local strafe = (keyDown(VK.D, KC.D) and 1 or 0) - (keyDown(VK.A, KC.A) and 1 or 0)
    local boost = keyDown(VK.LSHIFT, KC.LeftShift)
    local lift = (keyDown(VK.SPACE, KC.Space) and 1 or 0) - (keyDown(VK.LCTRL, KC.LeftControl) and 1 or 0)

    Fly.bat -= dt
    local target
    if Fly.bat <= 0 then
        target = 0
    elseif kW then
        target = spec.max * (boost and spec.boost or 1)
    elseif kS then
        target = spec.min
    else
        target = spec.cruise
    end
    Fly.speed = damp(Fly.speed, target, spec.accel, dt)

    local R, U, F = basis(Fly.yaw, Fly.pitch, 0)
    local desired = F * Fly.speed
    if fpv then
        desired += UPV * (lift * 30) + R * (strafe * 25)
    end
    local kk = 1 - math.exp(-spec.inertia * dt)
    Fly.vel = Fly.vel + (desired - Fly.vel) * kk
    if Fly.bat <= 0 then
        Fly.vel += Vector3.new(0, -45 * dt, 0)
    end
    local newPos = Fly.pos + Fly.vel * dt

    -- попадание в игрока
    local hitR = spec.hit * DroneCfg.hitRadius
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local ch = p.Character
            local thrp = ch and ch:FindFirstChild("HumanoidRootPart")
            local th = ch and ch:FindFirstChild("Humanoid")
            if thrp and th and th.Health > 0 and segDist(Fly.pos, newPos, thrp.Position) < hitR then
                Fly.pos = thrp.Position
                impact(p, thrp.Position)
                return
            end
        end
    end

    -- стены (если исполнитель умеет Raycast)
    local step = newPos - Fly.pos
    if step.Magnitude > 1e-3 then
        local dirU = vunit(step)
        local r = bodyRay(Fly.pos + dirU * 1.6, step + dirU * 0.6, char)
        if r then
            local hitPlr = nil
            for _, p in ipairs(Players:GetPlayers()) do
                local ch = p.Character
                if p ~= LocalPlayer and ch then
                    local inst = r.Instance
                    for _ = 1, 5 do
                        if not inst then break end
                        if inst == ch then hitPlr = p break end
                        inst = inst.Parent
                    end
                end
                if hitPlr then break end
            end
            impact(hitPlr, r.Position)
            return
        end
    end
    if newPos.Y < -480 then
        impact(nil, newPos)
        return
    end

    setPos(hrp, newPos)
    setVel(hrp, ZERO3)
    setRotVel(hrp, ZERO3)
    Fly.pos = newPos
    Fly.prop += dt * (fpv and (25 + Fly.speed * 0.5) or 60)

    -- модель: от первого лица видно БЧ и винты, со стороны - весь дрон вокруг нас
    local pov = CamS.pos and (CamS.pos - newPos).Magnitude < 2.6
    if pov then
        if fpv then
            local cR, cU, cF = basis(CamS.yaw, CamS.pitch, 0)
            local O = CamS.pos - cU * 0.25 - cF * 0.85
            renderMesh(Fly.mesh, O, cR, cU, cF, 1, 1, Fly.prop, 0.12)
        else
            hideMesh()
        end
    else
        local dR, dU, dF = basis(Fly.yaw, Fly.pitch + (fpv and -(Fly.speed / spec.max) * 0.45 or 0), Fly.roll * (fpv and 1.3 or 1))
        renderMesh(Fly.mesh, newPos, dR, dU, dF, fpv and 2.2 or 1, 1, Fly.prop)
    end
end

function launchDrone()
    if Fly.active or not DroneCfg.enabled or Win.destroyed then return end
    if tick() < Fly.cooldown then
        Win:Notify("Drone", "Recharging...", 1.5)
        return
    end
    local _, hrp, hum = myChar()
    if not (hrp and hum and hum.Health > 0) then return end
    Win.open = false
    dragTarget = nil
    if FULL then
        fullLaunch()
    else
        bodyLaunch()
    end
end
end

local setLine, renderOSD, OSD_RED
do
--==================== OSD (вид с камеры дрона) ====================--

local OSDZ = 280
local OSD_WHITE = Color3.fromRGB(236, 240, 246)
local OSD_GREEN = Color3.fromRGB(125, 255, 160)
OSD_RED = Color3.fromRGB(255, 70, 80)
local BLACK = Color3.new(0, 0, 0)

local OSD = {a = 0, hidden = true, all = {}, scan = {}, noise = {}, vig = {}, tg = {}}

local function oreg(o)
    OSD.all[#OSD.all + 1] = o
    return o
end

local function otext(size, center)
    return oreg(new("Text", {Text = "", Size = size, Font = MONO, ZIndex = OSDZ + 10, Outline = true, Center = center or false}))
end

local function oline(th, z)
    return oreg(new("Line", {Thickness = th or 1, ZIndex = z or (OSDZ + 8)}))
end

for i = 1, 10 do
    OSD.vig[i] = oreg(new("Square", {Filled = false, Thickness = 12, ZIndex = OSDZ, Color = BLACK}))
end
for i = 1, 110 do
    OSD.noise[i] = oline(1, OSDZ + 2)
end
OSD.black = oreg(new("Square", {Filled = true, ZIndex = OSDZ + 3, Color = BLACK}))
OSD.flash = oreg(new("Square", {Filled = true, ZIndex = OSDZ + 20, Color = WHITE}))
OSD.lost = otext(34, true)
OSD.lostSub = otext(14, true)
OSD.cross = {oline(2), oline(2), oline(2), oline(2)}
OSD.dot = oreg(new("Circle", {Filled = true, NumSides = 10, Radius = 2, ZIndex = OSDZ + 8}))
OSD.pip = oreg(new("Circle", {Filled = false, Thickness = 1.5, NumSides = 36, Radius = 22, ZIndex = OSDZ + 8}))
OSD.hz = {oline(2), oline(2)}
OSD.frame = {}
for i = 1, 8 do OSD.frame[i] = oline(2) end
OSD.top = Gradient.new(48, OSDZ + 9)
OSD.mode = otext(14, true)
OSD.role = otext(13, true)
OSD.bat = otext(14)
OSD.batBox = oreg(new("Square", {Filled = false, Thickness = 1, ZIndex = OSDZ + 8}))
OSD.batFill = oreg(new("Square", {Filled = true, ZIndex = OSDZ + 8}))
OSD.rec = otext(14)
OSD.recDot = oreg(new("Circle", {Filled = true, NumSides = 12, Radius = 5, ZIndex = OSDZ + 8, Color = OSD_RED}))
OSD.spd = otext(14)
OSD.alt = otext(14)
OSD.dst = otext(14)
OSD.lq = otext(14)
OSD.thr = otext(14, true)
OSD.grid = otext(12)
OSD.hdgTicks = {}
for i = 1, 13 do OSD.hdgTicks[i] = oline(1.5) end
OSD.hdgLbl = {}
for i = 1, 5 do OSD.hdgLbl[i] = otext(12, true) end
OSD.hdgTxt = otext(13, true)
OSD.hdgCaret = oline(2)
for i = 1, 4 do
    local t = {l = {}, name = otext(12, true), info = otext(11, true)}
    for j = 1, 8 do t.l[j] = oline(2) end
    OSD.tg[i] = t
end

local function hideOSD()
    for _, o in ipairs(OSD.all) do show(o, 0) end
    OSD.top:set(0, 0, 0, 0, 0)
end

function setLine(l, x1, y1, x2, y2, col, a)
    l.From = Vector2.new(x1, y1)
    l.To = Vector2.new(x2, y2)
    l.Color = col
    show(l, a)
end

local function corners(lines, x0, y0, w, h, len, col, a)
    local x1, y1 = x0 + w, y0 + h
    setLine(lines[1], x0, y0, x0 + len, y0, col, a)
    setLine(lines[2], x0, y0, x0, y0 + len, col, a)
    setLine(lines[3], x1, y0, x1 - len, y0, col, a)
    setLine(lines[4], x1, y0, x1, y0 + len, col, a)
    setLine(lines[5], x0, y1, x0 + len, y1, col, a)
    setLine(lines[6], x0, y1, x0, y1 - len, col, a)
    setLine(lines[7], x1, y1, x1 - len, y1, col, a)
    setLine(lines[8], x1, y1, x1, y1 - len, col, a)
end

local altCache = {t = 0, v = 0}

function renderOSD(dt)
    local want = Fly.active
    OSD.a = damp(OSD.a, want and 1 or 0, 14, dt)
    if not want and OSD.a <= 0 then
        if not OSD.hidden then
            OSD.hidden = true
            hideOSD()
        end
        return
    end
    OSD.hidden = false
    local a = OSD.a
    local vs = Camera.ViewportSize
    local sw, sh = vs.X, vs.Y
    local cx, cy = sw / 2, sh / 2
    local fpv = Fly.kind == "FPV"
    local col = fpv and OSD_WHITE or OSD_GREEN
    local fx = DroneCfg.fx
    local inImpact = Fly.phase == "impact"
    local oa = (fx.osd and not inImpact) and a or 0

    -- виньетка
    local va = fx.color and a or 0
    if OSD.vsX ~= sw or OSD.vsY ~= sh then
        OSD.vsX, OSD.vsY = sw, sh
        for i, v in ipairs(OSD.vig) do
            local ins = (i - 1) * 12
            v.Position = Vector2.new(ins - 6, ins - 6)
            v.Size = Vector2.new(sw - ins * 2 + 12, sh - ins * 2 + 12)
        end
        -- сканлайны под текущий экран
        local need = math.floor(sh / 4)
        for i = #OSD.scan + 1, need do
            OSD.scan[i] = oline(1, OSDZ + 1)
            OSD.scan[i].Color = BLACK
        end
        for i, l in ipairs(OSD.scan) do
            l.From = Vector2.new(0, i * 4)
            l.To = Vector2.new(sw, i * 4)
            if i > need then show(l, 0) end
        end
        OSD.scanN = need
    end
    for i, v in ipairs(OSD.vig) do
        local k = 1 - (i - 1) / #OSD.vig
        show(v, va, 0.5 * k * k)
    end
    local scA = fx.scan and a * (fpv and 0.14 or 0.1) or 0
    for i = 1, OSD.scanN or 0 do show(OSD.scan[i], scA) end

    -- статика
    local takeK = Fly.phase == "takeoff" and (1 - math.clamp(Fly.t / TAKEOFF, 0, 1)) or 0
    local distK = (Fly.home and Fly.pos) and math.clamp(((Fly.pos - Fly.home).Magnitude - 300) / 900, 0, 1) or 0
    local batK = Fly.batMax and math.clamp(Fly.bat / Fly.batMax, 0, 1) or 1
    local inten = (fpv and 0.16 or 0.07) + distK * 0.5 + (batK < 0.15 and 0.25 or 0) + takeK * 0.6
    if not fx.noise then inten = 0 end
    if inImpact then inten = 1 end
    for _, l in ipairs(OSD.noise) do
        if math.random() < inten * 0.9 then
            local y = math.random(0, sh)
            local x = math.random(-60, sw)
            local len = math.random(20, 60 + math.floor(400 * inten))
            local g = 0.5 + math.random() * 0.5
            l.From = Vector2.new(x, y)
            l.To = Vector2.new(x + len, y)
            l.Thickness = math.random(1, 3)
            l.Color = Color3.new(g, g, g)
            show(l, a, 0.05 + math.random() * 0.35 * inten)
        else
            show(l, 0)
        end
    end

    -- потеря сигнала
    OSD.black.Position = Vector2.new(0, 0)
    OSD.black.Size = Vector2.new(sw, sh)
    show(OSD.black, a, inImpact and 0.88 or 0)
    Fly.flash = damp(Fly.flash or 0, 0, 6, dt)
    OSD.flash.Position = Vector2.new(0, 0)
    OSD.flash.Size = Vector2.new(sw, sh)
    show(OSD.flash, a, Fly.flash * 0.85)
    if inImpact and frameCounter % 8 < 6 then
        setText(OSD.lost, "NO SIGNAL")
        OSD.lost.Position = Vector2.new(cx, cy - 26)
        OSD.lost.Color = WHITE
        show(OSD.lost, a)
        setText(OSD.lostSub, "LINK LOST  |  " .. (Fly.strikeMsg or ""))
        OSD.lostSub.Position = Vector2.new(cx, cy + 16)
        OSD.lostSub.Color = Theme.SubText
        show(OSD.lostSub, a)
    else
        show(OSD.lost, 0)
        show(OSD.lostSub, 0)
    end

    if oa <= 0 then
        -- OSD выключен или идёт обрыв: прячем приборы
        for _, o in ipairs(OSD.cross) do show(o, 0) end
        for _, o in ipairs(OSD.hz) do show(o, 0) end
        for _, o in ipairs(OSD.frame) do show(o, 0) end
        for _, o in ipairs(OSD.hdgTicks) do show(o, 0) end
        for _, o in ipairs(OSD.hdgLbl) do show(o, 0) end
        for _, t in ipairs(OSD.tg) do
            for _, l in ipairs(t.l) do show(l, 0) end
            show(t.name, 0); show(t.info, 0)
        end
        for _, o in ipairs({OSD.dot, OSD.pip, OSD.mode, OSD.role, OSD.bat, OSD.batBox, OSD.batFill,
            OSD.rec, OSD.recDot, OSD.spd, OSD.alt, OSD.dst, OSD.lq, OSD.thr, OSD.grid, OSD.hdgTxt, OSD.hdgCaret}) do
            show(o, 0)
        end
        OSD.top:set(0, 0, 0, 0, 0)
        return
    end

    -- рамка кадра + акцентная полоса
    local m = 36
    corners(OSD.frame, m, m, sw - m * 2, sh - m * 2, 36, col, oa * 0.75)
    OSD.top:set(0, 0, sw, 2, oa * 0.9, accentAt)

    local spec = Fly.spec
    local knife = DroneCfg.useKnife and hasKnife()
    local lq = math.floor(100 - distK * 70 - takeK * 40 + 0.5)
    setText(OSD.mode, spec.name .. "   |   LINK " .. lq .. "%")
    OSD.mode.Position = Vector2.new(cx, 14)
    OSD.mode.Color = col
    show(OSD.mode, oa)
    setText(OSD.role, knife and "MURDER  -  KNIFE STRIKE" or "FLING STRIKE")
    OSD.role.Position = Vector2.new(cx, 34)
    OSD.role.Color = knife and OSD_RED or cMix(col, accentAt(0.5), 0.5)
    show(OSD.role, oa)

    -- батарея / топливо
    if fpv then
        setText(OSD.bat, string.format("BAT %.1fV", 13.2 + 3.6 * batK))
    else
        setText(OSD.bat, string.format("FUEL %d%%", math.floor(batK * 100 + 0.5)))
    end
    OSD.bat.Position = Vector2.new(m + 14, m + 12)
    OSD.bat.Color = batK < 0.2 and OSD_RED or col
    show(OSD.bat, (batK < 0.2 and frameCounter % 30 < 15) and 0 or oa)
    OSD.batBox.Position = Vector2.new(m + 14, m + 32)
    OSD.batBox.Size = Vector2.new(70, 9)
    OSD.batBox.Color = col
    show(OSD.batBox, oa, 0.8)
    OSD.batFill.Position = Vector2.new(m + 16, m + 34)
    OSD.batFill.Size = Vector2.new(math.max(0, 66 * batK), 5)
    OSD.batFill.Color = batK > 0.5 and Color3.fromRGB(110, 235, 130) or (batK > 0.2 and Color3.fromRGB(255, 210, 80) or OSD_RED)
    show(OSD.batFill, oa)

    -- REC
    local secs = math.floor(Fly.t or 0)
    setText(OSD.rec, string.format("REC %02d:%02d", math.floor(secs / 60), secs % 60))
    OSD.rec.Position = Vector2.new(sw - m - 112, m + 12)
    OSD.rec.Color = col
    show(OSD.rec, oa)
    OSD.recDot.Position = Vector2.new(sw - m - 124, m + 20)
    show(OSD.recDot, oa, (frameCounter // 20) % 2 == 0 and 1 or 0.15)

    -- прицел
    if fpv then
        local g, l = 6, 10
        setLine(OSD.cross[1], cx - g - l, cy, cx - g, cy, col, oa)
        setLine(OSD.cross[2], cx + g, cy, cx + g + l, cy, col, oa)
        setLine(OSD.cross[3], cx, cy - g - l, cx, cy - g, col, oa)
        setLine(OSD.cross[4], cx, cy + g, cx, cy + g + l, col, oa)
        show(OSD.pip, 0)
    else
        OSD.pip.Position = Vector2.new(cx, cy)
        OSD.pip.Color = col
        show(OSD.pip, oa)
        setLine(OSD.cross[1], cx - 34, cy, cx - 22, cy, col, oa)
        setLine(OSD.cross[2], cx + 22, cy, cx + 34, cy, col, oa)
        setLine(OSD.cross[3], cx, cy - 34, cx, cy - 22, col, oa)
        setLine(OSD.cross[4], cx, cy + 22, cx, cy + 34, col, oa)
    end
    OSD.dot.Position = Vector2.new(cx, cy)
    OSD.dot.Color = col
    show(OSD.dot, oa)

    -- авиагоризонт
    local camPos = CamS.pos
    local hy = Fly.yaw or 0
    local flatLook = dirOf(hy, 0)
    local right = Vector3.new(math.cos(hy), 0, -math.sin(hy))
    local x0, y0, on0 = false, false, false
    local xr, yr = 0, 0
    if camPos then
        x0, y0, on0 = project(camPos + flatLook * 1000)
        xr, yr = project(camPos + flatLook * 1000 + right * 300)
    end
    if on0 then
        local d = Vector2.new(xr - x0, yr - y0)
        d = d.Magnitude > 0.001 and d * (1 / d.Magnitude) or Vector2.new(1, 0)
        local mid = Vector2.new(x0, y0)
        local l1, l2 = mid - d * 170, mid - d * 55
        local r1, r2 = mid + d * 55, mid + d * 170
        setLine(OSD.hz[1], l1.X, l1.Y, l2.X, l2.Y, col, oa * 0.85)
        setLine(OSD.hz[2], r1.X, r1.Y, r2.X, r2.Y, col, oa * 0.85)
    else
        show(OSD.hz[1], 0); show(OSD.hz[2], 0)
    end

    -- телеметрия
    if frameCounter - altCache.t > 5 then
        altCache.t = frameCounter
        if rayParams then
            local r = workspace:Raycast(Fly.pos, V3(0, -600, 0), rayParams)
            altCache.v = r and (Fly.pos.Y - r.Position.Y) or 600
        else
            altCache.v = Fly.home and math.max(0, Fly.pos.Y - Fly.home.Y + 3) or 0
        end
    end
    local spd = (Fly.vel and Fly.vel.Magnitude or 0) * STUD_M * 3.6
    setText(OSD.spd, string.format("SPD %3d km/h", math.floor(spd + 0.5)))
    setText(OSD.alt, string.format("ALT %3d m", math.floor(altCache.v * STUD_M + 0.5)))
    local homeD = (Fly.home and Fly.pos) and (Fly.pos - Fly.home).Magnitude * STUD_M or 0
    setText(OSD.dst, string.format("DST %4d m", math.floor(homeD + 0.5)))
    setText(OSD.lq, string.format("LQ  %3d%%", lq))
    OSD.spd.Position = Vector2.new(m + 14, sh - m - 48)
    OSD.alt.Position = Vector2.new(m + 14, sh - m - 28)
    OSD.dst.Position = Vector2.new(sw - m - 112, sh - m - 48)
    OSD.lq.Position = Vector2.new(sw - m - 112, sh - m - 28)
    for _, o in ipairs({OSD.spd, OSD.alt, OSD.dst, OSD.lq}) do
        o.Color = col
        show(o, oa)
    end
    local thr = spec.max > 0 and math.floor(math.clamp((Fly.speed or 0) / spec.max, 0, 1.4) * 100 + 0.5) or 0
    setText(OSD.thr, (fpv and "THR " or "PWR ") .. thr .. "%")
    OSD.thr.Position = Vector2.new(cx, sh - m - 30)
    OSD.thr.Color = col
    show(OSD.thr, oa)

    -- шахед: курс + координаты
    if not fpv then
        local hdg = (-math.deg(Fly.yaw or 0)) % 360
        local base = math.floor(hdg / 10) * 10
        local li = 0
        for i, t in ipairs(OSD.hdgTicks) do
            local deg = base + (i - 7) * 10
            local x = cx + (deg - hdg) * 4
            local big = deg % 30 == 0
            local fade = math.clamp(1 - math.abs(x - cx) / 260, 0, 1)
            setLine(t, x, 92, x, 92 - (big and 10 or 5), col, oa * fade)
            if big and li < #OSD.hdgLbl then
                li += 1
                local lbl = OSD.hdgLbl[li]
                local dd = deg % 360
                local name = dd == 0 and "N" or dd == 90 and "E" or dd == 180 and "S" or dd == 270 and "W" or tostring(dd)
                setText(lbl, name)
                lbl.Position = Vector2.new(x, 64)
                lbl.Color = col
                show(lbl, fade > 0.3 and oa * fade or 0)
            end
        end
        for i = li + 1, #OSD.hdgLbl do show(OSD.hdgLbl[i], 0) end
        setLine(OSD.hdgCaret, cx, 96, cx, 104, col, oa)
        setText(OSD.hdgTxt, string.format("%03d", math.floor(hdg + 0.5) % 360))
        OSD.hdgTxt.Position = Vector2.new(cx, 106)
        OSD.hdgTxt.Color = col
        show(OSD.hdgTxt, oa)
        setText(OSD.grid, string.format("GRID %05d %05d", math.floor(Fly.pos.X) % 100000, math.floor(Fly.pos.Z) % 100000))
        OSD.grid.Position = Vector2.new(m + 14, m + 50)
        OSD.grid.Color = col
        show(OSD.grid, oa, 0.8)
    else
        for _, o in ipairs(OSD.hdgTicks) do show(o, 0) end
        for _, o in ipairs(OSD.hdgLbl) do show(o, 0) end
        show(OSD.hdgCaret, 0); show(OSD.hdgTxt, 0); show(OSD.grid, 0)
    end

    -- цели
    local cands = {}
    if Fly.pos then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ch = p.Character
                local thrp = ch and ch:FindFirstChild("HumanoidRootPart")
                local th = ch and ch:FindFirstChild("Humanoid")
                if thrp and th and th.Health > 0 then
                    local vx, vy, on = project(thrp.Position)
                    if on then
                        local _, ty = project(thrp.Position + V3(0, 3, 0))
                        local _, by = project(thrp.Position - V3(0, 3.2, 0))
                        local h = math.max(14, math.abs(by - ty))
                        cands[#cands + 1] = {
                            p = p, x = vx, y = (ty + by) / 2, w = h * 0.62, h = h,
                            d = (thrp.Position - Fly.pos).Magnitude,
                            sd = (vx - cx) ^ 2 + (vy - cy) ^ 2,
                        }
                    end
                end
            end
        end
        table.sort(cands, function(x, y) return x.sd < y.sd end)
    end
    local lockR = sh * 0.2
    local lock = cands[1] and cands[1].sd < lockR * lockR and cands[1].d < 160 and cands[1].p or nil
    if lock and lock ~= Fly.lock then playOnce(SND.beep, 0.35, 1.6) end
    Fly.lock = lock
    for i, t in ipairs(OSD.tg) do
        local c = cands[i]
        if c then
            local locked = c.p == lock
            local tc = locked and OSD_RED or col
            local ta = locked and oa * (0.7 + 0.3 * math.sin(clock * 12)) or oa * 0.6
            local x0, y0 = c.x - c.w / 2, c.y - c.h / 2
            corners(t.l, x0, y0, c.w, c.h, math.min(c.w, c.h) * 0.28, tc, ta)
            setText(t.name, c.p.Name)
            t.name.Position = Vector2.new(c.x, y0 + c.h + 4)
            t.name.Color = tc
            show(t.name, ta)
            setText(t.info, string.format(locked and (knife and "LOCK | KNIFE  %dm" or "LOCK  %dm") or "%dm", math.floor(c.d * STUD_M + 0.5)))
            t.info.Position = Vector2.new(c.x, y0 - 16)
            t.info.Color = tc
            show(t.info, ta)
        else
            for _, l in ipairs(t.l) do show(l, 0) end
            show(t.name, 0); show(t.info, 0)
        end
    end
end
end

local renderChip
do
--==================== HUD chip (готовность) ====================--

local Chip = {a = 0, hidden = true}
Chip.shadow = RoundRect.new(58)
Chip.border = RoundRect.new(61, true, 59)
Chip.bg = RoundRect.new(60)
Chip.key = RoundRect.new(62)
Chip.keyT = new("Text", {Text = "T", Size = 14, Font = FONT, ZIndex = 63, Color = Theme.Text})
Chip.title = new("Text", {Text = "", Size = 14, Font = FONT, ZIndex = 63, Color = Theme.Text})
Chip.sub = new("Text", {Text = "", Size = 11, Font = FONT, ZIndex = 63, Color = Theme.SubText})
Chip.dot = new("Circle", {Filled = true, NumSides = 12, Radius = 3.5, ZIndex = 63})
Chip.prog = Gradient.new(24, 63)

local function hideChip()
    Chip.shadow:hide(); Chip.border:hide(); Chip.bg:hide(); Chip.key:hide()
    show(Chip.keyT, 0); show(Chip.title, 0); show(Chip.sub, 0); show(Chip.dot, 0)
    Chip.prog:set(0, 0, 0, 0, 0)
end

function renderChip(dt)
    local want = DroneCfg.enabled and not Fly.active and not Win.destroyed
    Chip.a = damp(Chip.a, want and 1 or 0, 10, dt)
    if not want and Chip.a <= 0 then
        if not Chip.hidden then
            Chip.hidden = true
            hideChip()
        end
        return
    end
    Chip.hidden = false
    local a = Chip.a
    local op = Settings.hudOpacity
    local now = tick()
    local cd = math.max(0, Fly.cooldown - now)
    local knife = DroneCfg.useKnife and hasKnife()

    setText(Chip.title, Specs[DroneCfg.kind].name)
    if cd > 0 then
        setText(Chip.sub, string.format("RECHARGING  %.1fs", cd))
    else
        setText(Chip.sub, knife and "READY  |  MURDER - KNIFE" or "READY  |  FLING")
    end
    local tb, sb = bounds(Chip.title), bounds(Chip.sub)
    local w = math.floor(math.max(tb.X, sb.X) + 64)
    local h = 42
    local vs = Camera.ViewportSize
    local x = math.floor((vs.X - w) / 2)
    local y = math.floor(vs.Y - 96 + (1 - a) * 20)

    Chip.shadow:set(x + 2, y + 4, w, h, 11, SHADOW_COL, a * 0.3 * op)
    Chip.border:set(x - 1, y - 1, w + 2, h + 2, 11, cMix(Theme.Bg, accentAt(0.4), 0.55 * pulseK(2)), a * math.min(1, op + 0.2))
    Chip.bg:set(x, y, w, h, 10, Theme.Bg, a * op)
    Chip.key:set(x + 10, y + 10, 22, 22, 6, cMix(Theme.Element, accentAt(0.5), 0.35), a)
    local kb = bounds(Chip.keyT)
    Chip.keyT.Position = Vector2.new(x + 21 - kb.X / 2, y + 21 - kb.Y / 2)
    show(Chip.keyT, a)
    Chip.title.Position = Vector2.new(x + 42, y + 6)
    show(Chip.title, a)
    Chip.sub.Position = Vector2.new(x + 42, y + 23)
    Chip.sub.Color = knife and OSD_RED or Theme.SubText
    show(Chip.sub, a)
    Chip.dot.Position = Vector2.new(x + w - 12, y + 12)
    Chip.dot.Color = cd > 0 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(80, 230, 140)
    show(Chip.dot, a, 0.6 + 0.4 * math.sin(clock * 4))
    local k = cd > 0 and (1 - cd / 1.5) or 1
    Chip.prog:set(x + 10, y + h - 3, (w - 20) * k, 2, a, accentAt)
end
end

do
--==================== drone picker element ====================--

local OLIVE_UI = Color3.fromRGB(150, 118, 68)

local function buildArt(kind)
    local art = {kind = kind}
    if kind == "FPV" then
        art.arm1 = new("Line", {Thickness = 4, ZIndex = 7})
        art.arm2 = new("Line", {Thickness = 4, ZIndex = 7})
        art.body = new("Square", {Filled = true, ZIndex = 8})
        art.war = new("Line", {Thickness = 7, ZIndex = 9})
        art.tip = new("Circle", {Filled = true, NumSides = 10, ZIndex = 10})
        art.rot, art.blade, art.hub = {}, {}, {}
        for i = 1, 4 do
            art.rot[i] = new("Circle", {Filled = false, Thickness = 1.5, NumSides = 22, ZIndex = 7})
            art.blade[i] = new("Line", {Thickness = 2, ZIndex = 8})
            art.hub[i] = new("Circle", {Filled = true, NumSides = 10, ZIndex = 9})
        end
    else
        art.wl = tryNew("Triangle", {Filled = true, Thickness = 1, ZIndex = 7})
        art.wr = tryNew("Triangle", {Filled = true, Thickness = 1, ZIndex = 7})
        art.el = new("Line", {Thickness = 2, ZIndex = 8})
        art.er = new("Line", {Thickness = 2, ZIndex = 8})
        art.te = new("Line", {Thickness = 2, ZIndex = 8})
        art.fus = new("Line", {Thickness = 8, ZIndex = 9})
        art.nose = new("Circle", {Filled = true, NumSides = 12, ZIndex = 9})
        art.fl = new("Line", {Thickness = 4, ZIndex = 9})
        art.fr = new("Line", {Thickness = 4, ZIndex = 9})
        art.prop = new("Line", {Thickness = 2, ZIndex = 10})
        art.hub = new("Circle", {Filled = true, NumSides = 10, ZIndex = 10})
    end
    return art
end

local function drawArt(art, cx, cy, s, a, sel, hov)
    local frameCol = cLerp(Theme.SubText, Theme.Text, math.max(sel, hov * 0.6))
    local acc = accentAt(0.3)
    if art.kind == "FPV" then
        local d = 28 * s
        art.arm1.Thickness = 4 * s
        art.arm2.Thickness = 4 * s
        setLine(art.arm1, cx - d, cy - d, cx + d, cy + d, cMix(Theme.Stroke, frameCol, 0.6), a)
        setLine(art.arm2, cx + d, cy - d, cx - d, cy + d, cMix(Theme.Stroke, frameCol, 0.6), a)
        art.body.Position = Vector2.new(cx - 8 * s, cy - 13 * s)
        art.body.Size = Vector2.new(16 * s, 26 * s)
        art.body.Color = cMix(Color3.fromRGB(40, 40, 48), frameCol, 0.25)
        show(art.body, a)
        art.war.Thickness = 7 * s
        setLine(art.war, cx, cy + 4 * s, cx, cy - 40 * s, OLIVE_UI, a)
        art.tip.Position = Vector2.new(cx, cy - 42 * s)
        art.tip.Radius = 3 * s
        art.tip.Color = DC.SILVER
        show(art.tip, a)
        local sgn = {{1, 1, 1}, {-1, 1, -1}, {1, -1, -1}, {-1, -1, 1}}
        for i = 1, 4 do
            local px, py = cx + sgn[i][1] * d, cy + sgn[i][2] * d
            local r = art.rot[i]
            r.Position = Vector2.new(px, py)
            r.Radius = 15 * s
            r.Color = cMix(frameCol, acc, sel)
            show(r, a, 0.8)
            local ang = clock * (18 + 12 * sel) * sgn[i][3] + i
            local bx, by = math.cos(ang) * 13 * s, math.sin(ang) * 13 * s
            setLine(art.blade[i], px - bx, py - by, px + bx, py + by, frameCol, a * 0.7)
            art.hub[i].Position = Vector2.new(px, py)
            art.hub[i].Radius = 3.5 * s
            art.hub[i].Color = frameCol
            show(art.hub[i], a)
        end
    else
        local nose, tail = cy - 44 * s, cy + 30 * s
        local wingCol = cMix(Color3.fromRGB(60, 62, 72), Color3.fromRGB(176, 178, 184), 0.4 + 0.6 * math.max(sel, hov))
        local edge = cMix(frameCol, acc, sel)
        local rootF, rootB, tipX = cy - 16 * s, cy + 28 * s, 52 * s
        if art.wl then
            art.wl.PointA = Vector2.new(cx - 3 * s, rootF)
            art.wl.PointB = Vector2.new(cx - 3 * s, rootB)
            art.wl.PointC = Vector2.new(cx - tipX, rootB)
            art.wl.Color = wingCol
            show(art.wl, a, 0.9)
        end
        if art.wr then
            art.wr.PointA = Vector2.new(cx + 3 * s, rootF)
            art.wr.PointB = Vector2.new(cx + 3 * s, rootB)
            art.wr.PointC = Vector2.new(cx + tipX, rootB)
            art.wr.Color = wingCol
            show(art.wr, a, 0.9)
        end
        setLine(art.el, cx - 3 * s, rootF, cx - tipX, rootB, edge, a)
        setLine(art.er, cx + 3 * s, rootF, cx + tipX, rootB, edge, a)
        setLine(art.te, cx - tipX, rootB, cx + tipX, rootB, edge, a * 0.7)
        art.fus.Thickness = 8 * s
        setLine(art.fus, cx, nose + 2 * s, cx, tail, cMix(wingCol, WHITE, 0.15), a)
        art.nose.Position = Vector2.new(cx, nose + 3 * s)
        art.nose.Radius = 4 * s
        art.nose.Color = cMix(wingCol, WHITE, 0.15)
        show(art.nose, a)
        art.fl.Thickness = 4 * s
        art.fr.Thickness = 4 * s
        setLine(art.fl, cx - tipX, cy + 18 * s, cx - tipX, cy + 32 * s, Color3.fromRGB(45, 46, 52), a)
        setLine(art.fr, cx + tipX, cy + 18 * s, cx + tipX, cy + 32 * s, Color3.fromRGB(45, 46, 52), a)
        local ang = clock * (22 + 14 * sel)
        local bx, by = math.cos(ang) * 11 * s, math.sin(ang) * 3 * s
        setLine(art.prop, cx - bx, tail + 4 * s - by, cx + bx, tail + 4 * s + by, frameCol, a * 0.8)
        art.hub.Position = Vector2.new(cx, tail + 4 * s)
        art.hub.Radius = 2.5 * s
        art.hub.Color = frameCol
        show(art.hub, a)
    end
end

function TabMT:DroneCards(o)
    local el = {h = 178, cards = {}, cb = o.Callback}
    for i, k in ipairs({"FPV", "SHAHED"}) do
        local c = {kind = k, hover = 0, sel = DroneCfg.kind == k and 1 or 0, pop = 0}
        c.bg = RoundRect.new(5)
        c.ring = RoundRect.new(6, true, 4)
        c.top = Gradient.new(20, 7)
        c.glow = new("Circle", {Filled = true, NumSides = 32, ZIndex = 6})
        c.name = new("Text", {Text = Specs[k].name, Size = 15, Font = FONT, ZIndex = 8, Color = Theme.Text})
        c.sub = new("Text", {Text = Specs[k].desc, Size = 11, Font = FONT, ZIndex = 8, Color = Theme.SubText})
        c.badge = new("Circle", {Filled = true, NumSides = 16, ZIndex = 8})
        c.badgeCore = new("Circle", {Filled = true, NumSides = 10, Radius = 2.2, ZIndex = 9, Color = WHITE})
        c.stats = {}
        for j, lbl in ipairs({"SPD", "AGL", "RNG"}) do
            c.stats[j] = {
                label = new("Text", {Text = lbl, Size = 11, Font = FONT, ZIndex = 8, Color = Theme.SubText}),
                track = RoundRect.new(7),
                fill = Gradient.new(12, 8),
                v = Specs[k].stats[j],
                anim = 0,
            }
        end
        c.art = buildArt(k)
        el.cards[i] = c
    end

    function el:press(m)
        for _, c in ipairs(self.cards) do
            if c.rect and inRect(m, c.rect) and DroneCfg.kind ~= c.kind then
                DroneCfg.kind = c.kind
                c.pop = 1
                fireCallback(self.cb, c.kind)
                return
            end
        end
    end

    function el:update(dt, x, y, w, a, hovered, m)
        local gap = 10
        local cw2 = math.floor((w - gap) / 2)
        for i, c in ipairs(self.cards) do
            local x0 = x + (i - 1) * (cw2 + gap)
            c.rect = {x0, y, cw2, self.h}
            local hov = hovered and inRect(m, c.rect)
            c.hover = damp(c.hover, hov and 1 or 0, 12, dt)
            c.sel = damp(c.sel, DroneCfg.kind == c.kind and 1 or 0, 10, dt)
            c.pop = damp(c.pop, 0, 8, dt)

            local fill = cMix(cLerp(Theme.Element, Theme.ElementHover, c.hover), accentAt(0.3), 0.1 * c.sel)
            c.bg:set(x0, y, cw2, self.h, 10, fill, a)
            c.ring:set(x0 - 1, y - 1, cw2 + 2, self.h + 2, 11, cMix(Theme.Stroke, accentAt(i * 0.4), c.sel), a)
            c.top:set(x0 + 10, y, cw2 - 20, 2, a * c.sel, accentAt, edgeFade)

            local acx = x0 + cw2 / 2
            local acy = y + 50 + math.sin(clock * 2 + i) * 2
            c.glow.Position = Vector2.new(acx, acy)
            c.glow.Radius = 38 + 6 * c.sel + c.pop * 10
            c.glow.Color = accentAt(i * 0.4)
            show(c.glow, a, 0.06 + 0.08 * c.sel)
            drawArt(c.art, acx, acy, 0.82 * (1 + 0.04 * c.hover + 0.08 * c.pop), a, c.sel, c.hover)

            c.name.Position = Vector2.new(x0 + 12, y + 96)
            c.name.Color = cLerp(Theme.SubText, Theme.Text, math.max(c.sel, 0.6))
            show(c.name, a)
            c.sub.Position = Vector2.new(x0 + 12, y + 114)
            show(c.sub, a)

            local bp = Vector2.new(x0 + cw2 - 16, y + 16)
            c.badge.Position = bp
            c.badge.Radius = 6 + c.pop * 3
            c.badge.Color = accentAt(0.5)
            show(c.badge, a, c.sel)
            c.badgeCore.Position = bp
            show(c.badgeCore, a, c.sel)

            for j, st in ipairs(c.stats) do
                local sy = y + 136 + (j - 1) * 13
                st.label.Position = Vector2.new(x0 + 12, sy - 6)
                show(st.label, a)
                local tx, tw = x0 + 44, cw2 - 58
                st.track:set(tx, sy, tw, 4, 2, Theme.Stroke, a)
                st.anim = damp(st.anim, st.v, 6, dt)
                st.fill:set(tx, sy, math.floor(tw * st.anim + 0.5), 4, a, accentAt)
            end
        end
    end

    table.insert(self.elements, el)
    return el
end
end

--==================== render ====================--

local function render(dt)
    frameCounter = frameCounter + 1
    clock += dt * Settings.speed
    CurMouse = getMouse()
    HoverAny = false
    pcall(updateCam)

    local ok, err = pcall(renderBody, dt)
    if not ok then reportError("renderBody", err) end
    if Fly.active and Fly.mode == "body" then
        local okb, errb = pcall(bodyStep, dt)
        if not okb then reportError("bodyStep", errb) end
    end
    local ok1, err1 = pcall(renderBoom, dt)
    if not ok1 then reportError("boom", err1) end
    local ok2, err2 = pcall(renderChip, dt)
    if not ok2 then reportError("chip", err2) end
    local ok3, err3 = pcall(renderOSD, dt)
    if not ok3 then reportError("osd", err3) end
    local ok4, err4 = pcall(renderCursor, dt)
    if not ok4 then reportError("cursor", err4) end
end

table.insert(Connections, RunService.RenderStepped:Connect(render))

--==================== free mouse in menu ====================--

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
    if Win.destroyed or Fly.active then return end
    if Win.open and Settings.unlockMouse then
        if not MouseCtl.active then
            MouseCtl.active = true
            pcall(function()
                MouseCtl.prevB = UIS.MouseBehavior
                MouseCtl.prevI = UIS.MouseIconEnabled
            end)
        end
        pcall(function()
            if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then UIS.MouseBehavior = Enum.MouseBehavior.Default end
        end)
        pcall(function()
            if not UIS.MouseIconEnabled then UIS.MouseIconEnabled = true end
        end)
    else
        restoreMouse()
    end
end

if not pcall(function()
    RunService:BindToRenderStep("AuroraDronesMouse", Enum.RenderPriority.Last.Value + 1, mouseStep)
end) then
    table.insert(Connections, RunService.RenderStepped:Connect(mouseStep))
end

--==================== input (опрос клавиш) ====================--

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
        dragTarget = Win
        dragOff = Vector2.new(m.X - Win.tx, m.Y - Win.ty)
    end
end

local prevKeys = {}
local function pressedEdge(name, down)
    local was = prevKeys[name]
    prevKeys[name] = down
    return down and not was
end

table.insert(Connections, RunService.Heartbeat:Connect(function()
    if Win.destroyed then return end
    local ok, err = pcall(function()
        local focused = robloxFocused()

        local m1 = focused and mouse1Down() or false
        if m1 and not MouseDown and not Fly.active then
            handleClick()
        end
        if (not m1) and MouseDown then
            dragTarget = nil
            for _, tab in ipairs(Win.tabs) do
                for _, el in ipairs(tab.elements) do el.dragging = false end
            end
        end
        MouseDown = m1

        if pressedEdge("menu", focused and keyDown(VK.RCTRL, KC.RightControl)) and not Fly.active then
            Win.open = not Win.open
            if not Win.open then dragTarget = nil end
        end

        if pressedEdge("drone", focused and keyDown(VK.T, KC.T)) then
            if Fly.active then
                -- повторное T в полёте = самоподрыв
                if Fly.phase == "flight" then impact(nil, Fly.pos) end
            elseif not typingInChat() then
                launchDrone()
            end
        end

        if dragTarget then
            local mm = getMouse()
            dragTarget.tx = mm.X - dragOff.X
            dragTarget.ty = mm.Y - dragOff.Y
        end
    end)
    if not ok then reportError("input", err) end
end))

function Win:Destroy()
    if self.destroyed then return end
    if Fly.active then
        if Fly.mode == "full" then
            pcall(fullEnd)
        else
            local home = Fly.home
            pcall(bodyEnd)
            task.spawn(function() pcall(bodyReturn, home) end)
        end
    end
    self.destroyed = true
    restoreMouse()
    pcall(function() RunService:UnbindFromRenderStep("AuroraDronesMouse") end)
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for i = #Objects, 1, -1 do pcall(function() Objects[i]:Remove() end) end
    table.clear(Objects)
    pcall(function() FX:Destroy() end)
    pcall(function() SoundFolder:Destroy() end)
    if env.AuroraDrones == self then env.AuroraDrones = nil end
end

function Win:Close()
    self.open = false
    task.delay(0.45, function() self:Destroy() end)
end

V.dots[1].action = function() Win:Close() end
V.dots[2].action = function()
    Win.open = false
    Win:Notify("Menu collapsed", "Press RightCtrl to open", 3)
end

env.AuroraDrones = Win

do
--==================== TABS ====================--

local tDrone = Win:Tab("Drone", "Pick a drone  |  T to launch")

tDrone:DroneCards({
    Callback = function(k)
        playOnce(SND.beep, 0.4, 1.2)
        Win:Notify("Drone", Specs[k].name .. " selected", 2)
    end,
})

tDrone:Toggle({
    Name = "Drone Enabled  (T)",
    Default = true,
    Callback = function(v) DroneCfg.enabled = v end,
})

tDrone:Button({
    Name = "Launch Now",
    Callback = function() launchDrone() end,
})

local tStrike = Win:Tab("Strike", "What happens on impact")

tStrike:Toggle({
    Name = "Knife Strike If Murder",
    Default = true,
    Callback = function(v) DroneCfg.useKnife = v end,
})

tStrike:Slider({
    Name = "Fling Power", Min = 50, Max = 300, Step = 5, Default = 100, Suffix = "%",
    Callback = function(v) DroneCfg.flingPower = v / 100 end,
})

tStrike:Slider({
    Name = "Hit Radius", Min = 50, Max = 200, Step = 5, Default = 100, Suffix = "%",
    Callback = function(v) DroneCfg.hitRadius = v / 100 end,
})

tStrike:Slider({
    Name = "Battery", Min = 10, Max = 90, Step = 1, Default = 40, Suffix = "s",
    Callback = function(v) DroneCfg.battery = v end,
})

tStrike:Slider({
    Name = "Mouse Sensitivity", Min = 20, Max = 300, Step = 5, Default = 100, Suffix = "%",
    Callback = function(v) DroneCfg.sensitivity = v / 100 end,
})

local tCam = Win:Tab("Camera", "Drone video feed")

tCam:Toggle({Name = "Color Grade", Default = true, Callback = function(v) DroneCfg.fx.color = v end})
tCam:Toggle({Name = "Static Noise", Default = true, Callback = function(v) DroneCfg.fx.noise = v end})
tCam:Toggle({Name = "Scanlines", Default = true, Callback = function(v) DroneCfg.fx.scan = v end})
tCam:Toggle({Name = "OSD Overlay", Default = true, Callback = function(v) DroneCfg.fx.osd = v end})
tCam:Toggle({Name = "Camera Shake", Default = true, Callback = function(v) DroneCfg.fx.shake = v end})

tCam:Slider({
    Name = "FPV Field Of View", Min = 80, Max = 130, Step = 1, Default = 110,
    Callback = function(v) DroneCfg.fovFPV = v end,
})

tCam:Slider({
    Name = "Volume", Min = 0, Max = 100, Step = 1, Default = 80, Suffix = "%",
    Callback = function(v) DroneCfg.volume = v / 100 end,
})

local tVis = Win:Tab("Visuals", "Menu effects")

tVis:Swatches({
    Name = "Accent",
    Callback = function(i)
        local names = {"Aurora", "Sunset", "Ocean", "Crimson", "Lime"}
        Win:Notify("Theme", "Accent: " .. (names[i] or "?"), 2.5)
    end,
})
tVis:Toggle({Name = "Neon Glow", Default = true, Callback = function(v) Settings.glow = v end})
tVis:Toggle({Name = "Particles", Default = true, Callback = function(v) Settings.particles = v end})
tVis:Toggle({Name = "Pulse", Default = true, Callback = function(v) Settings.pulse = v end})
tVis:Slider({
    Name = "Animation Speed", Min = 0.2, Max = 3, Step = 0.1, Default = 1, Suffix = "x",
    Callback = function(v) Settings.speed = v end,
})
end

task.delay(0.6, function()
    Win:Notify("Aurora Drones", "T - launch  |  RightCtrl - menu", 4)
end)

print("[Aurora Drones] loaded")

return Win
