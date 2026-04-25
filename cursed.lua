-- ==========================================
-- ELITE TANKER ESP — FULL SCRIPT v11
-- База: v7 (1:1) + фичи v9 поверх
-- Меню не останавливает ESP
-- ==========================================

local Collection   = {}
local ChassisCache = {}
local DamagePopups = {}
local TrajectoryLines = {}

local Config = {
    BoxColor        = Color3.fromRGB(255, 50,  50),
    OutlineColor    = Color3.fromRGB(0,   0,   0),
    NameColor       = Color3.fromRGB(255, 255, 255),
    DistColor       = Color3.fromRGB(180, 180, 180),
    HPBarHigh       = Color3.fromRGB(50,  220, 80),
    HPBarMid        = Color3.fromRGB(255, 200, 0),
    HPBarLow        = Color3.fromRGB(220, 50,  50),
    HPTextColor     = Color3.fromRGB(255, 255, 255),
    SnaplineColor   = Color3.fromRGB(255, 180, 0),
    ArrowColor      = Color3.fromRGB(100, 200, 255),
    GlowColor       = Color3.fromRGB(255, 50,  50),
    Box3DColor      = Color3.fromRGB(255, 50,  50),
    DmgColor        = Color3.fromRGB(255, 80,  80),
    CrossColor      = Color3.fromRGB(255, 255, 0),
    TrajColor       = Color3.fromRGB(255, 220, 50),
    ReloadColor     = Color3.fromRGB(100, 200, 255),
}

local UICache = {
    isEnabled  = true,
    showBox    = true,
    show3DBox  = true,
    showName   = true,
    showDist   = true,
    showTeam   = false,
    showHP     = true,
    showHPNum  = true,
    showVHP    = true,
    useCorner  = true,
    showSnap   = true,
    showArrow  = true,
    showGlow   = true,
    showDmgPop = true,
    showCross  = true,
    showTraj   = true,
    showReload = true,
    minReload  = false,
    maxRange   = 3500,
}

local Players   = game:GetService("Players")
local Workspace = workspace
local TICK_RATE = 1 / 30
local GRAVITY   = Vector3.new(0, -196.2, 0)

-- ==========================================
-- ВСПОМОГАТЕЛЬНЫЕ (v7 — без изменений)
-- ==========================================
local function GetChassis(Player)
    local cached = ChassisCache[Player.Name]
    if cached and cached.Parent then return cached end
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then ChassisCache[Player.Name] = nil; return nil end
    local ch = vehicles:FindFirstChild("Chassis" .. Player.Name)
    ChassisCache[Player.Name] = ch
    return ch
end

local function GetTankModel(Player)
    local Chassis = GetChassis(Player)
    if not Chassis then return nil end
    local Hull = Chassis:FindFirstChild("Hull")
    if not Hull then return nil end
    return Hull:FindFirstChildOfClass("Model")
end

local function GetTankHull(Model)
    if not Model then return nil end
    return Model:FindFirstChild("Hull")
end

local function GetPlayerHP(Player, Chassis)
    if Chassis then
        local hum = Chassis:FindFirstChildOfClass("Humanoid", true)
        if hum then return hum.Health, hum.MaxHealth end
    end
    local char = Player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then return hum.Health, hum.MaxHealth end
    end
    if Chassis then
        local hpVal  = Chassis:FindFirstChild("HP") or Chassis:FindFirstChild("Health")
        local maxVal = Chassis:FindFirstChild("MaxHP") or Chassis:FindFirstChild("MaxHealth")
        if hpVal and maxVal then return hpVal.Value, maxVal.Value end
        if hpVal then return hpVal.Value, 100 end
    end
    return nil, nil
end

local function GetHPColorSmooth(pct)
    local hi = Config.HPBarHigh
    local mi = Config.HPBarMid
    local lo = Config.HPBarLow
    if pct > 0.5 then
        local t = (pct - 0.5) * 2
        return Color3.new(hi.R*t+mi.R*(1-t), hi.G*t+mi.G*(1-t), hi.B*t+mi.B*(1-t))
    else
        local t = pct * 2
        return Color3.new(mi.R*t+lo.R*(1-t), mi.G*t+lo.G*(1-t), mi.B*t+lo.B*(1-t))
    end
end

-- v9: reload
local function GetReloadTime(Chassis)
    if not Chassis then return nil end
    local rt = Chassis:FindFirstChild("ReloadTime", true)
    if rt and (rt:IsA("NumberValue") or rt:IsA("IntValue")) then
        return rt.Value
    end
    return nil
end

-- v9: min reload hack
local function ApplyMinReload(LocalPlayer)
    if not UICache.minReload then return end
    local ch = ChassisCache[LocalPlayer.Name]
    if not ch then
        local vehicles = Workspace:FindFirstChild("Vehicles")
        if vehicles then ch = vehicles:FindFirstChild("Chassis" .. LocalPlayer.Name) end
    end
    if not ch then return end
    pcall(function()
        for _, rt in pairs(ch:GetDescendants()) do
            if rt.Name == "ReloadTime" and (rt:IsA("NumberValue") or rt:IsA("IntValue")) then
                if rt.Value > 0 then rt.Value = 0 end
            end
        end
    end)
end

-- ==========================================
-- GLOW (v7 — без изменений)
-- ==========================================
local GlowFolder
pcall(function()
    GlowFolder = Workspace:FindFirstChild("__ESPGlow__")
    if not GlowFolder then
        GlowFolder = Instance.new("Folder")
        GlowFolder.Name = "__ESPGlow__"
        GlowFolder.Parent = Workspace
    end
end)

local function CreateGlowForModel(model)
    local boxes = {}
    if not model or not GlowFolder then return boxes end
    for _, part in pairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 0.9 then
            pcall(function()
                local sb = Instance.new("SelectionBox")
                sb.Color3              = Config.GlowColor
                sb.LineThickness       = 0.04
                sb.SurfaceTransparency = 0.85
                sb.SurfaceColor3       = Config.GlowColor
                sb.Adornee             = part
                sb.Parent              = GlowFolder
                table.insert(boxes, sb)
            end)
        end
    end
    return boxes
end

local function UpdateGlowColor(glowBoxes)
    if not glowBoxes then return end
    for _, sb in pairs(glowBoxes) do
        if sb and sb.Parent then
            sb.Color3        = Config.GlowColor
            sb.SurfaceColor3 = Config.GlowColor
        end
    end
end

local function RemoveGlow(glowBoxes)
    if not glowBoxes then return end
    for _, sb in pairs(glowBoxes) do
        pcall(function() sb:Destroy() end)
    end
end

local function SetGlowVisible(glowBoxes, visible)
    if not glowBoxes then return end
    for _, sb in pairs(glowBoxes) do
        if sb and sb.Parent then sb.Visible = visible end
    end
end

-- ==========================================
-- v9: BULLET TRAJECTORY
-- ==========================================
local TRAJ_STEPS = 30
local TRAJ_DT    = 0.06
local TRAJ_SPEED = 600
local TrajPoolUsed = 0

local function ResetTrajPool()
    for i = 1, TrajPoolUsed do
        if TrajectoryLines[i] then TrajectoryLines[i].Visible = false end
    end
    TrajPoolUsed = 0
end

local function DrawTrajectoryForTank(Chassis, HullNode)
    if not UICache.showTraj then return end
    if not Chassis or not HullNode then return end

    local muzzlePos = nil
    pcall(function()
        for _, p in pairs(Chassis:GetDescendants()) do
            if p:IsA("BasePart") then
                local n = p.Name:lower()
                if n:find("muzzle") or n:find("barrel") or n:find("cannon") then
                    muzzlePos = p.CFrame.Position
                    break
                end
            end
        end
    end)

    if not muzzlePos then
        muzzlePos = HullNode.CFrame:PointToWorldSpace(
            Vector3.new(0, HullNode.Size.Y * 0.3, -HullNode.Size.Z * 0.6)
        )
    end

    local pos = muzzlePos
    local vel = HullNode.CFrame.LookVector * TRAJ_SPEED

    for step = 1, TRAJ_STEPS do
        local nextPos = pos + vel * TRAJ_DT + GRAVITY * (TRAJ_DT * TRAJ_DT * 0.5)
        local nextVel = vel + GRAVITY * TRAJ_DT

        local sp1, on1 = WorldToScreen(pos)
        local sp2, on2 = WorldToScreen(nextPos)

        TrajPoolUsed = TrajPoolUsed + 1
        if TrajPoolUsed > #TrajectoryLines then
            local ln = Drawing.new("Line")
            ln.Visible = false; ln.Thickness = 1.5
            ln.Color = Config.TrajColor; ln.Transparency = 0.5
            table.insert(TrajectoryLines, ln)
        end

        local ln = TrajectoryLines[TrajPoolUsed]
        if ln and sp1 and sp2 and (on1 or on2) then
            local alpha = 1 - (step / TRAJ_STEPS) * 0.85
            ln.From = sp1; ln.To = sp2
            ln.Color = Config.TrajColor
            ln.Transparency = 1 - alpha
            ln.Visible = true
        elseif ln then
            ln.Visible = false
        end

        pos = nextPos
        vel = nextVel
        if pos.Y < -50 then break end
    end
end

-- ==========================================
-- v9: DAMAGE POPUPS
-- ==========================================
local function SpawnDamagePopup(screenPos, dmg)
    if not UICache.showDmgPop or not screenPos then return end
    local txt = Drawing.new("Text")
    txt.Text = "-" .. math.ceil(dmg)
    txt.Size = 16; txt.Color = Config.DmgColor
    txt.Center = true; txt.Outline = true
    txt.Position = screenPos; txt.Visible = true; txt.ZIndex = 10
    table.insert(DamagePopups, {
        obj = txt, startT = tick(), duration = 1.8,
        startY = screenPos.Y, x = screenPos.X,
    })
end

local function UpdateDamagePopups()
    local now = tick()
    local i = 1
    while i <= #DamagePopups do
        local p = DamagePopups[i]
        local elapsed = now - p.startT
        if elapsed >= p.duration then
            pcall(function() p.obj:Remove() end)
            table.remove(DamagePopups, i)
        else
            local t = elapsed / p.duration
            p.obj.Position     = Vector2.new(p.x, p.startY - t * 45)
            p.obj.Transparency = t
            p.obj.Size         = 16 + math.sin(t * math.pi) * 6
            i = i + 1
        end
    end
end

-- ==========================================
-- v9: 3D BOX
-- ==========================================
local BOX_EDGES = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}

local function Draw3DBox(B, HullCF, sX, sY, sZ, color)
    local hx, hy, hz = sX/2, sY/2, sZ/2
    local signs = {
        Vector3.new(-1,-1,-1), Vector3.new(1,-1,-1),
        Vector3.new(1,-1,1),   Vector3.new(-1,-1,1),
        Vector3.new(-1,1,-1),  Vector3.new(1,1,-1),
        Vector3.new(1,1,1),    Vector3.new(-1,1,1),
    }
    local pts = {}
    for i, s in ipairs(signs) do
        local wp     = HullCF:PointToWorldSpace(Vector3.new(s.X*hx, s.Y*hy, s.Z*hz))
        local sp, on = WorldToScreen(wp)
        pts[i] = {pos = sp, on = on}
    end
    for i, edge in ipairs(BOX_EDGES) do
        local a, b = pts[edge[1]], pts[edge[2]]
        if a.pos and b.pos and (a.on or b.on) then
            B.Box3DOutline[i].From  = a.pos; B.Box3DOutline[i].To = b.pos
            B.Box3DOutline[i].Color = Config.OutlineColor; B.Box3DOutline[i].Visible = true
            B.Box3D[i].From         = a.pos; B.Box3D[i].To = b.pos
            B.Box3D[i].Color        = color;  B.Box3D[i].Visible = true
        else
            B.Box3DOutline[i].Visible = false
            B.Box3D[i].Visible        = false
        end
    end
end

-- ==========================================
-- v9: CROSSHAIR TARGET
-- ==========================================
local CrosshairTarget = nil

local function UpdateCrosshairTarget(allPlayers, LocalPlayer)
    if not UICache.showCross then CrosshairTarget = nil; return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local center   = cam.ViewportSize / 2
    local bestDist = math.huge
    local bestName = nil
    for _, v in pairs(allPlayers) do
        if v ~= LocalPlayer then
            pcall(function()
                local ch = GetChassis(v)
                if not ch then return end
                local hn = ch:FindFirstChild("HullNode")
                if not hn then return end
                local sp, on = WorldToScreen(hn.Position)
                if not sp or not on then return end
                local d = (sp - center).Magnitude
                if d < bestDist then bestDist = d; bestName = v.Name end
            end)
        end
    end
    CrosshairTarget = bestName
end

-- ==========================================
-- СОЗДАНИЕ DRAWING-ОБЪЕКТОВ (v7 + v9 additions)
-- ==========================================
local function CreateBoxes()
    local B = {}

    local function Sq(thick, col, filled)
        local s = Drawing.new("Square")
        s.Visible = false; s.Thickness = thick; s.Color = col; s.Filled = filled
        return s
    end
    local function Ln(thick, col)
        local l = Drawing.new("Line")
        l.Visible = false; l.Thickness = thick; l.Color = col
        return l
    end
    local function Tx(size, col)
        local t = Drawing.new("Text")
        t.Visible = false; t.Size = size; t.Color = col
        t.Center = true; t.Outline = true
        return t
    end

    -- v7
    B.Outline = Sq(3,   Config.OutlineColor, false)
    B.Box     = Sq(1.5, Config.BoxColor,     false)
    B.Lines        = {}
    B.LinesOutline = {}
    for i = 1, 8 do
        B.Lines[i]        = Ln(2, Config.BoxColor)
        B.LinesOutline[i] = Ln(4, Config.OutlineColor)
    end
    B.Name   = Tx(14, Config.NameColor)
    B.Dist   = Tx(13, Config.DistColor)
    B.HPText = Tx(11, Config.HPTextColor)
    B.HPBg      = Sq(1, Color3.fromRGB(15,15,15), true)
    B.HPOutline = Sq(1, Color3.fromRGB(0,0,0),    false)
    B.HPFill    = Sq(1, Config.HPBarHigh,          true)
    B.Snap        = Ln(1, Config.SnaplineColor)
    B.SnapOutline = Ln(3, Color3.fromRGB(0,0,0))
    B.Snap.Transparency        = 0.4
    B.SnapOutline.Transparency = 0.6
    B.Arrow = {Ln(2,Config.ArrowColor), Ln(2,Config.ArrowColor), Ln(2,Config.ArrowColor)}
    B.GlowBoxes = nil

    -- v9 additions
    B.Box3D        = {}
    B.Box3DOutline = {}
    for i = 1, 12 do
        B.Box3D[i]                     = Ln(1.5, Config.Box3DColor)
        B.Box3DOutline[i]              = Ln(3,   Config.OutlineColor)
        B.Box3D[i].Transparency        = 0
        B.Box3DOutline[i].Transparency = 0.5
    end
    B.VHPBg      = Sq(1, Color3.fromRGB(15,15,15), true)
    B.VHPOutline = Sq(1, Color3.fromRGB(0,0,0),    false)
    B.VHPFill    = Sq(1, Config.HPBarHigh,          true)
    B.ReloadText  = Tx(12, Config.ReloadColor)
    B.CrossHL     = Sq(2, Config.CrossColor, false)
    B.CrossHL.Transparency = 0.2
    B.LastHP = nil

    return B
end

-- ==========================================
-- ОЧИСТКА (v7 + новые объекты)
-- ==========================================
local function CompleteClear(PlayerInfo)
    if not PlayerInfo.Boxes then return end
    local B = PlayerInfo.Boxes
    local function rem(o) if o then pcall(function() o:Remove() end) end end
    rem(B.Outline); rem(B.Box)
    rem(B.Name); rem(B.Dist); rem(B.HPText); rem(B.ReloadText)
    rem(B.HPBg); rem(B.HPOutline); rem(B.HPFill)
    rem(B.VHPBg); rem(B.VHPOutline); rem(B.VHPFill)
    rem(B.Snap); rem(B.SnapOutline); rem(B.CrossHL)
    if B.Lines        then for _,L in pairs(B.Lines)        do rem(L) end end
    if B.LinesOutline then for _,L in pairs(B.LinesOutline) do rem(L) end end
    if B.Arrow        then for _,L in pairs(B.Arrow)        do rem(L) end end
    if B.Box3D        then for _,L in pairs(B.Box3D)        do rem(L) end end
    if B.Box3DOutline then for _,L in pairs(B.Box3DOutline) do rem(L) end end
    RemoveGlow(B.GlowBoxes)
    PlayerInfo.Boxes = nil; PlayerInfo.TankModel = nil; PlayerInfo.TankHull = nil
end

local function HideAllDrawings(B)
    if not B then return end
    B.Outline.Visible = false; B.Box.Visible = false
    B.Name.Visible = false; B.Dist.Visible = false
    B.HPText.Visible = false; B.ReloadText.Visible = false
    B.HPBg.Visible = false; B.HPOutline.Visible = false; B.HPFill.Visible = false
    B.VHPBg.Visible = false; B.VHPOutline.Visible = false; B.VHPFill.Visible = false
    B.Snap.Visible = false; B.SnapOutline.Visible = false; B.CrossHL.Visible = false
    for _,L in pairs(B.Lines)        do L.Visible = false end
    for _,L in pairs(B.LinesOutline) do L.Visible = false end
    for _,L in pairs(B.Arrow)        do L.Visible = false end
    for _,L in pairs(B.Box3D)        do L.Visible = false end
    for _,L in pairs(B.Box3DOutline) do L.Visible = false end
    SetGlowVisible(B.GlowBoxes, false)
end

-- v7 — без изменений
local function CheckPlayerCollectionThings(Player, PlayerInfo)
    if not PlayerInfo.TankModel or not PlayerInfo.TankModel.Parent then
        PlayerInfo.TankModel = GetTankModel(Player)
        if PlayerInfo.Boxes then
            RemoveGlow(PlayerInfo.Boxes.GlowBoxes)
            PlayerInfo.Boxes.GlowBoxes = nil
        end
    end
    if not PlayerInfo.TankHull or not PlayerInfo.TankHull.Parent then
        PlayerInfo.TankHull = GetTankHull(PlayerInfo.TankModel)
    end
end

-- ==========================================
-- ОТРИСОВКА (v7 основа + v9 фичи поверх)
-- ==========================================
local function UpdateEsp(Player, PlayerInfo, LocalPlayer, LocalChassisNode)
    local B = PlayerInfo.Boxes
    if not B then return end

    if not UICache.showTeam then
        local pt = Player.Team; local lt = LocalPlayer.Team
        if pt and lt and pt.Name == lt.Name then HideAllDrawings(B); return end
    end

    local Chassis = GetChassis(Player)
    if not Chassis or not Chassis.Parent then HideAllDrawings(B); return end

    local HullNode = Chassis:FindFirstChild("HullNode")
    if not HullNode or not HullNode.Parent then HideAllDrawings(B); return end

    local Pos   = HullNode.Position
    local SizeY = HullNode.Size.Y

    local distance = 0
    if LocalChassisNode then
        distance = (Pos - LocalChassisNode.Position).Magnitude
    else
        local cam = Workspace.CurrentCamera
        if cam then distance = (cam.CFrame.Position - Pos).Magnitude end
    end
    if distance > UICache.maxRange then HideAllDrawings(B); return end

    -- v7: WorldToScreen напрямую
    local top_pos,    on1 = WorldToScreen(Pos + Vector3.new(0,  SizeY/2, 0))
    local bottom_pos, on2 = WorldToScreen(Pos + Vector3.new(0, -SizeY,   0))
    if not on1 and not on2           then HideAllDrawings(B); return end
    if not top_pos or not bottom_pos then HideAllDrawings(B); return end

    local meters = distance / 3.571428571
    local height = math.abs(top_pos.Y - bottom_pos.Y)
    local width  = height / 1.5
    local cx     = top_pos.X
    local ty     = math.min(top_pos.Y, bottom_pos.Y)
    local bx     = cx - width

    local hp, maxHp = GetPlayerHP(Player, Chassis)
    local hpPct = (hp and maxHp and maxHp > 0) and math.clamp(hp/maxHp, 0, 1) or 1

    -- v9: damage popup
    if hp and B.LastHP and B.LastHP > hp then
        local dmg = B.LastHP - hp
        if dmg > 0.5 then
            local sp, _ = WorldToScreen(Pos + Vector3.new(0, SizeY/2 + 2, 0))
            SpawnDamagePopup(sp, dmg)
        end
    end
    B.LastHP = hp

    -- GLOW (v7 — без изменений)
    if UICache.showGlow then
        if not B.GlowBoxes and PlayerInfo.TankModel then
            B.GlowBoxes = CreateGlowForModel(PlayerInfo.TankModel)
        end
        UpdateGlowColor(B.GlowBoxes)
        SetGlowVisible(B.GlowBoxes, true)
    else
        SetGlowVisible(B.GlowBoxes, false)
    end

    -- v9: crosshair highlight
    if UICache.showCross and CrosshairTarget == Player.Name then
        local pulse = 0.1 + math.abs(math.sin(tick()*4)) * 0.5
        B.CrossHL.Position     = Vector2.new(bx-3, ty-3)
        B.CrossHL.Size         = Vector2.new(width*2+6, height+6)
        B.CrossHL.Color        = Config.CrossColor
        B.CrossHL.Transparency = pulse
        B.CrossHL.Visible      = true
    else
        B.CrossHL.Visible = false
    end

    -- БОКСЫт: 3D или v7 2D
    if UICache.show3DBox then
        B.Outline.Visible = false; B.Box.Visible = false
        for i=1,8 do B.Lines[i].Visible=false; B.LinesOutline[i].Visible=false end
        Draw3DBox(B, HullNode.CFrame, HullNode.Size.X*1.1, SizeY, HullNode.Size.Z*1.1, Config.Box3DColor)
    else
        for i=1,12 do B.Box3D[i].Visible=false; B.Box3DOutline[i].Visible=false end
        -- v7 бокс без изменений
        if UICache.useCorner then
            B.Outline.Visible = false; B.Box.Visible = false
            if UICache.showBox then
                local tl = Vector2.new(bx,        ty)
                local tr = Vector2.new(bx+width*2, ty)
                local bl = Vector2.new(bx,        ty+height)
                local br = Vector2.new(bx+width*2, ty+height)
                local cl = math.max(height, width*2) / 4
                local pts = {
                    {tl,tl+Vector2.new(cl,0)}, {tl,tl+Vector2.new(0,cl)},
                    {tr,tr-Vector2.new(cl,0)}, {tr,tr+Vector2.new(0,cl)},
                    {bl,bl+Vector2.new(cl,0)}, {bl,bl-Vector2.new(0,cl)},
                    {br,br-Vector2.new(cl,0)}, {br,br-Vector2.new(0,cl)},
                }
                for i, p in ipairs(pts) do
                    B.LinesOutline[i].From=p[1]; B.LinesOutline[i].To=p[2]
                    B.LinesOutline[i].Color=Config.OutlineColor; B.LinesOutline[i].Visible=true
                    B.Lines[i].From=p[1]; B.Lines[i].To=p[2]
                    B.Lines[i].Color=Config.BoxColor; B.Lines[i].Visible=true
                end
            else
                for i=1,8 do B.Lines[i].Visible=false; B.LinesOutline[i].Visible=false end
            end
        else
            for i=1,8 do B.Lines[i].Visible=false; B.LinesOutline[i].Visible=false end
            if UICache.showBox then
                B.Outline.Position=Vector2.new(bx,ty); B.Outline.Size=Vector2.new(width*2,height)
                B.Outline.Color=Config.OutlineColor; B.Outline.Visible=true
                B.Box.Position=Vector2.new(bx,ty); B.Box.Size=Vector2.new(width*2,height)
                B.Box.Color=Config.BoxColor; B.Box.Visible=true
            else
                B.Outline.Visible=false; B.Box.Visible=false
            end
        end
    end

    -- Имя (v7)
    if UICache.showName then
        B.Name.Position=Vector2.new(cx,ty-18)
        B.Name.Text=Player.Name:upper()
        B.Name.Color=Config.NameColor; B.Name.Visible=true
    else B.Name.Visible=false end

    -- HP Bar горизонтальный (v7)
    local HP_H = 6
    local HP_W = math.max(50, math.min(width*2, 200))
    local hpX  = cx - HP_W/2
    local hpY  = ty + height + 4

    if UICache.showHP then
        B.HPBg.Position=Vector2.new(hpX,hpY); B.HPBg.Size=Vector2.new(HP_W,HP_H); B.HPBg.Visible=true
        B.HPOutline.Position=Vector2.new(hpX-1,hpY-1); B.HPOutline.Size=Vector2.new(HP_W+2,HP_H+2); B.HPOutline.Visible=true
        B.HPFill.Position=Vector2.new(hpX,hpY); B.HPFill.Size=Vector2.new(math.max(1,HP_W*hpPct),HP_H)
        B.HPFill.Color=GetHPColorSmooth(hpPct); B.HPFill.Visible=true
        if UICache.showHPNum and hp and maxHp then
            B.HPText.Position=Vector2.new(cx,hpY+HP_H+3)
            B.HPText.Text=math.ceil(hp).." / "..math.ceil(maxHp)
            B.HPText.Color=Config.HPTextColor; B.HPText.Visible=true
        else B.HPText.Visible=false end
    else
        B.HPBg.Visible=false; B.HPOutline.Visible=false; B.HPFill.Visible=false; B.HPText.Visible=false
    end

    -- v9: HP Bar вертикальный
    local VHP_W = 4
    local VHP_X = bx - VHP_W - 4
    if UICache.showVHP then
        local fillH = math.max(1, height*hpPct)
        local fillY = ty + height - fillH
        B.VHPBg.Position=Vector2.new(VHP_X,ty); B.VHPBg.Size=Vector2.new(VHP_W,height); B.VHPBg.Visible=true
        B.VHPOutline.Position=Vector2.new(VHP_X-1,ty-1); B.VHPOutline.Size=Vector2.new(VHP_W+2,height+2); B.VHPOutline.Visible=true
        B.VHPFill.Position=Vector2.new(VHP_X,fillY); B.VHPFill.Size=Vector2.new(VHP_W,fillH)
        B.VHPFill.Color=GetHPColorSmooth(hpPct); B.VHPFill.Visible=true
    else
        B.VHPBg.Visible=false; B.VHPOutline.Visible=false; B.VHPFill.Visible=false
    end

    -- v9: Reload
    local nextY
    if UICache.showHP then
        nextY = (UICache.showHPNum and hp and maxHp) and (hpY+HP_H+20) or (hpY+HP_H+5)
    else
        nextY = ty + height + 5
    end

    if UICache.showReload then
        local rt = GetReloadTime(Chassis)
        if rt and rt > 0 then
            B.ReloadText.Position=Vector2.new(cx,nextY)
            B.ReloadText.Text=string.format("%.1fs",rt)
            B.ReloadText.Color=Config.ReloadColor; B.ReloadText.Visible=true
        else
            B.ReloadText.Position=Vector2.new(cx,nextY)
            B.ReloadText.Text="READY"
            B.ReloadText.Color=Config.HPBarHigh; B.ReloadText.Visible=true
        end
        nextY = nextY + 16
    else
        B.ReloadText.Visible=false
    end

    -- Дистанция (v7)
    if UICache.showDist then
        B.Dist.Position=Vector2.new(cx,nextY)
        B.Dist.Text=string.format("%.0f m",meters)
        B.Dist.Color=Config.DistColor; B.Dist.Visible=true
    else B.Dist.Visible=false end

    -- Snapline (v7 — без изменений)
    if UICache.showSnap then
        local cam = Workspace.CurrentCamera
        local vp  = cam and cam.ViewportSize or Vector2.new(800,600)
        local org = Vector2.new(vp.X/2, vp.Y)
        local tgt = Vector2.new(cx, ty+height)
        B.SnapOutline.From=org; B.SnapOutline.To=tgt
        B.SnapOutline.Color=Color3.fromRGB(0,0,0); B.SnapOutline.Visible=true
        B.Snap.From=org; B.Snap.To=tgt
        B.Snap.Color=Config.SnaplineColor; B.Snap.Visible=true
    else
        B.Snap.Visible=false; B.SnapOutline.Visible=false
    end

    -- Arrow (v7 — без изменений)
    if UICache.showArrow then
        local mid       = Vector2.new(cx, ty+height/2)
        local lookWorld = Pos + HullNode.CFrame.LookVector*(SizeY*1.5)
        local frontPos2D, frontOn = WorldToScreen(lookWorld)
        local arrowShown = false
        if frontPos2D and (on1 or frontOn) then
            local dir = frontPos2D - mid
            local len = dir.Magnitude
            if len > 2 then
                local norm = dir/len
                local tip  = mid + norm*22
                local perp = Vector2.new(-norm.Y, norm.X)*7
                B.Arrow[1].From=mid;  B.Arrow[1].To=tip;             B.Arrow[1].Color=Config.ArrowColor; B.Arrow[1].Visible=true
                B.Arrow[2].From=tip;  B.Arrow[2].To=tip-norm*9+perp; B.Arrow[2].Color=Config.ArrowColor; B.Arrow[2].Visible=true
                B.Arrow[3].From=tip;  B.Arrow[3].To=tip-norm*9-perp; B.Arrow[3].Color=Config.ArrowColor; B.Arrow[3].Visible=true
                arrowShown = true
            end
        end
        if not arrowShown then for _,L in pairs(B.Arrow) do L.Visible=false end end
    else
        for _,L in pairs(B.Arrow) do L.Visible=false end
    end

    -- v9: trajectory
    if UICache.showTraj then
        DrawTrajectoryForTank(Chassis, HullNode)
    end
end

-- ==========================================
-- ОБРАБОТКА ИГРОКОВ (v7 — без изменений)
-- ==========================================
local function ProcessPlayer(Player, LocalPlayer, LocalChassisNode)
    pcall(function()
        local PI = Collection[Player.Name]
        if not PI then Collection[Player.Name] = {}; PI = Collection[Player.Name] end
        CheckPlayerCollectionThings(Player, PI)
        if not PI.TankModel or not PI.TankHull then CompleteClear(PI); return end
        if not PI.Boxes then PI.Boxes = CreateBoxes() end
        UpdateEsp(Player, PI, LocalPlayer, LocalChassisNode)
    end)
end

-- ==========================================
-- MATCHA UI (правила v7: ColorPicker сразу после Toggle, Keybind после Toggle)
-- ==========================================
UI.AddTab("Elite Tanker", function(tab)

    local vis = tab:Section("Visuals", "Left")

    vis:Toggle("esp_on", "Enable ESP", true)
    local kb = vis:Keybind("esp_kb", 0x46, "toggle")
    kb:AddToHotkey("Tank ESP", "esp_on")

    vis:Toggle("esp_team", "Show Allies", false)
    vis:Spacing()

    vis:Toggle("esp_3dbox", "3D Box", true)
    vis:ColorPicker("col_3dbox", 1, 0.20, 0.20, 1, function(c,a) Config.Box3DColor = c end)
    vis:Tip("Перспективный 3D-бокс по размеру HullNode")

    vis:Toggle("esp_box", "Show Box (2D)", true)
    vis:ColorPicker2("col_box", {1,0.20,0.20,1}, "col_outline", {0,0,0,1}, function(c1,a1,c2,a2)
        Config.BoxColor = c1; Config.OutlineColor = c2
    end)
    vis:Tip("Left = Box  |  Right = Outline")

    vis:Toggle("esp_corner", "Corner Box Style", true)
    vis:Spacing()

    vis:Toggle("esp_cross", "Crosshair Highlight", true)
    vis:ColorPicker("col_cross", 1, 1, 0, 1, function(c,a) Config.CrossColor = c end)
    vis:Spacing()

    vis:Toggle("esp_traj", "Bullet Trajectory", true)
    vis:ColorPicker("col_traj", 1, 0.86, 0.20, 1, function(c,a) Config.TrajColor = c end)
    vis:Spacing()

    vis:Toggle("esp_name", "Show Player Name", true)
    vis:ColorPicker("col_name", 1, 1, 1, 1, function(c,a) Config.NameColor = c end)
    vis:Spacing()

    vis:Toggle("esp_dist", "Show Distance", true)
    vis:ColorPicker("col_dist", 0.71, 0.71, 0.71, 1, function(c,a) Config.DistColor = c end)
    vis:Spacing()

    vis:Toggle("esp_snap", "Snapline", true)
    vis:ColorPicker("col_snap", 1, 0.71, 0, 1, function(c,a) Config.SnaplineColor = c end)
    vis:Spacing()

    vis:Toggle("esp_arrow", "Direction Arrow", true)
    vis:ColorPicker("col_arrow", 0.39, 0.78, 1, 1, function(c,a) Config.ArrowColor = c end)

    local hp_sec = tab:Section("Health", "Right")

    hp_sec:Toggle("esp_hp", "Horizontal HP Bar", true)
    hp_sec:ColorPicker2("col_hphi", {0.20,0.86,0.31,1}, "col_hplo", {0.86,0.20,0.20,1}, function(c1,a1,c2,a2)
        Config.HPBarHigh = c1; Config.HPBarLow = c2
    end)
    hp_sec:Tip("Left = High HP  |  Right = Low HP")

    hp_sec:Toggle("esp_hp_mid_toggle", "Mid HP Color", true)
    hp_sec:ColorPicker("col_hpmid", 1, 0.78, 0, 1, function(c,a) Config.HPBarMid = c end)
    hp_sec:Spacing()

    hp_sec:Toggle("esp_hp_num", "Show HP Numbers", true)
    hp_sec:ColorPicker("col_hptext", 1, 1, 1, 1, function(c,a) Config.HPTextColor = c end)
    hp_sec:Spacing()

    hp_sec:Toggle("esp_vhp", "Vertical HP Bar", true)
    hp_sec:Tip("Вертикальная полоска слева от бокса")
    hp_sec:Spacing()

    hp_sec:Toggle("esp_dmgpop", "Damage Popups", true)
    hp_sec:ColorPicker("col_dmg", 1, 0.31, 0.31, 1, function(c,a) Config.DmgColor = c end)
    hp_sec:Tip("Всплывающий урон при попадании")

    local rel_sec = tab:Section("Reload", "Right")

    rel_sec:Toggle("esp_reload", "Show Reload Timer", true)
    rel_sec:ColorPicker("col_reload", 0.39, 0.78, 1, 1, function(c,a) Config.ReloadColor = c end)
    rel_sec:Spacing()

    rel_sec:Toggle("esp_minreload", "Min Reload Hack", false)
    rel_sec:Tip("ReloadTime = 0 для своего танка")

    local glow_sec = tab:Section("Glow", "Right")

    glow_sec:Toggle("esp_glow", "Tank Part Glow", true)
    glow_sec:ColorPicker("col_glow", 1, 0.20, 0.20, 1, function(c, a)
        Config.GlowColor = c
        -- v7: обновляем цвет всех активных glow (как в оригинале)
        for _, info in pairs(Collection) do
            if info.Boxes and info.Boxes.GlowBoxes then
                UpdateGlowColor(info.Boxes.GlowBoxes)
            end
        end
    end)

    local settings = tab:Section("Settings", "Right")

    settings:SliderInt("esp_range", "Render Range (m)", 100, 10000, 3500)
    settings:Button("Clear ESP Cache", function()
        for _, data in pairs(Collection) do CompleteClear(data) end
        Collection = {}; ChassisCache = {}
    end)
end)

-- ==========================================
-- ГЛАВНЫЙ ЦИКЛ
-- Нет continue при закрытом меню — ESP работает всегда
-- ==========================================
local cleanupTick = 0

while true do
    task.wait(TICK_RATE)

    UICache.isEnabled  = UI.GetValue("esp_on")
    UICache.showBox    = UI.GetValue("esp_box")
    UICache.show3DBox  = UI.GetValue("esp_3dbox")
    UICache.showName   = UI.GetValue("esp_name")
    UICache.showDist   = UI.GetValue("esp_dist")
    UICache.showTeam   = UI.GetValue("esp_team")
    UICache.showHP     = UI.GetValue("esp_hp")
    UICache.showHPNum  = UI.GetValue("esp_hp_num")
    UICache.showVHP    = UI.GetValue("esp_vhp")
    UICache.useCorner  = UI.GetValue("esp_corner")
    UICache.showSnap   = UI.GetValue("esp_snap")
    UICache.showArrow  = UI.GetValue("esp_arrow")
    UICache.showGlow   = UI.GetValue("esp_glow")
    UICache.showDmgPop = UI.GetValue("esp_dmgpop")
    UICache.showCross  = UI.GetValue("esp_cross")
    UICache.showTraj   = UI.GetValue("esp_traj")
    UICache.showReload = UI.GetValue("esp_reload")
    UICache.minReload  = UI.GetValue("esp_minreload")
    UICache.maxRange   = UI.GetValue("esp_range")

    UpdateDamagePopups()
    ResetTrajPool()

    local LocalPlayer      = Players.LocalPlayer
    local LocalChassis     = GetChassis(LocalPlayer)
    local LocalChassisNode = LocalChassis and LocalChassis:FindFirstChild("HullNode") or nil
    local allPlayers = {}
    for _, v in pairs(Players:GetChildren()) do
        if v:IsA("Player") then table.insert(allPlayers, v) end
    end

    ApplyMinReload(LocalPlayer)
    UpdateCrosshairTarget(allPlayers, LocalPlayer)

    -- ESP рисуется всегда — и когда меню открыто и когда закрыто
    -- Если isEnabled = false, HideAllDrawings скрывает всё но не прерывает цикл
    for _, v in pairs(allPlayers) do
        if v.Name ~= LocalPlayer.Name then
            if UICache.isEnabled then
                ProcessPlayer(v, LocalPlayer, LocalChassisNode)
            else
                local PI = Collection[v.Name]
                if PI and PI.Boxes then HideAllDrawings(PI.Boxes) end
            end
        end
    end

    cleanupTick = cleanupTick + 1
    if cleanupTick >= 150 then
        cleanupTick = 0
        pcall(function()
            for name, info in pairs(Collection) do
                local ex = false
                for _, v in pairs(allPlayers) do if v.Name == name then ex = true; break end end
                if not ex then CompleteClear(info); Collection[name] = nil end
            end
            for name, ch in pairs(ChassisCache) do
                if not ch or not ch.Parent then ChassisCache[name] = nil end
            end
        end)
    end
end
