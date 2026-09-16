local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G

if type(env.UnifiedTP_Cleanup) == "function" then
    pcall(env.UnifiedTP_Cleanup)
end

local running, revision, uses = true, 0, 0
local connections = {}
local selectedPlayer
local heldE = false
local pressKey, releaseKey = keypress, keyrelease
local flags = {hamam=false, portal=false, kill=false, loop=false, tap=false, afk=false, freeze=false}
local BOX_CENTER = Vector3.new(12000,1500,12000)
local boxActive,boxModel,boxCharacter,boxReturn = false,nil,nil,nil
local visited = setmetatable({}, {__mode="k"})
local progress = setmetatable({}, {__mode="k"})
local colors = {
    bg=Color3.fromRGB(16,18,29), panel=Color3.fromRGB(30,34,51),
    field=Color3.fromRGB(40,46,66), accent=Color3.fromRGB(132,113,255),
    active=Color3.fromRGB(40,119,92), text=Color3.fromRGB(245,246,255),
    muted=Color3.fromRGB(183,193,213), error=Color3.fromRGB(255,161,153),
}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function make(class, parent, properties)
    local object = Instance.new(class)
    for key,value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function round(object, radius)
    make("UICorner", object, {CornerRadius=UDim.new(0,radius or 12)})
end

local parent = player:WaitForChild("PlayerGui")
if type(gethui) == "function" then
    local ok,result = pcall(gethui)
    if ok and typeof(result) == "Instance" then parent = result end
end
local old = parent:FindFirstChild("UnifiedTPGUI")
if old then old:Destroy() end

local gui = make("ScreenGui", parent, {
    Name="UnifiedTPGUI", ResetOnSpawn=false, DisplayOrder=50,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
local screen = make("Frame", gui, {Size=UDim2.fromScale(1,1), BackgroundTransparency=1})
local window = make("Frame", screen, {
    AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0,8),
    Size=UDim2.fromOffset(530,700), BackgroundColor3=colors.bg,
    BorderSizePixel=0, ClipsDescendants=true,
})
round(window,18)
make("UIStroke",window,{Color=colors.accent,Transparency=0.4})
local header = make("Frame",window,{
    Size=UDim2.new(1,0,0,64), BackgroundColor3=colors.panel, BorderSizePixel=0,
})
make("UIGradient",header,{
    Rotation=15, Color=ColorSequence.new(Color3.fromRGB(230,195,255),Color3.fromRGB(145,219,255)),
})
make("TextLabel",header,{
    Position=UDim2.fromOffset(16,7),Size=UDim2.new(1,-126,0,29),
    BackgroundTransparency=1,Text="HAMAM",TextSize=24,Font=Enum.Font.GothamBold,
    TextColor3=colors.text,TextXAlignment=Enum.TextXAlignment.Left,
})
local fpsLabel = make("TextLabel",header,{
    Position=UDim2.fromOffset(16,37),Size=UDim2.new(1,-126,0,18),
    BackgroundTransparency=1,Text="MuMu · FPS: —",TextSize=14,Font=Enum.Font.Gotham,
    TextColor3=colors.muted,TextXAlignment=Enum.TextXAlignment.Left,
})
local function headerButton(text,x,color)
    local b=make("TextButton",header,{
        Position=UDim2.new(1,x,0,10),Size=UDim2.fromOffset(44,44),
        BackgroundColor3=color,Text=text,TextSize=24,TextColor3=colors.text,
        Font=Enum.Font.GothamBold,
    })
    round(b)
    return b
end
local minimize=headerButton("−",-102,colors.field)
local close=headerButton("×",-52,Color3.fromRGB(110,49,66))
local content=make("Frame",window,{
    Position=UDim2.fromOffset(0,64),Size=UDim2.new(1,0,1,-64),BackgroundTransparency=1,
})
local tabBar=make("Frame",content,{
    Position=UDim2.fromOffset(12,10),Size=UDim2.new(1,-24,0,46),BackgroundTransparency=1,
})
make("UIListLayout",tabBar,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6)})
local status=make("TextLabel",content,{
    Position=UDim2.new(0,12,1,-76),Size=UDim2.new(1,-24,0,64),
    BackgroundColor3=colors.panel,Text="Готово",TextSize=15,TextWrapped=true,
    Font=Enum.Font.Gotham,TextColor3=colors.muted,
})
round(status)
make("UIPadding",status,{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
local pages,tabs,orders={},{},{}
local function createPage(name,title)
    tabs[name]=make("TextButton",tabBar,{
        Size=UDim2.new(1/3,-4,1,0),BackgroundColor3=colors.panel,
        Text=title,TextSize=14,Font=Enum.Font.GothamBold,TextColor3=colors.text,
    })
    round(tabs[name],10)
    local page=make("ScrollingFrame",content,{
        Position=UDim2.fromOffset(12,66),Size=UDim2.new(1,-24,1,-152),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
        ScrollBarImageColor3=colors.accent,CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
        Visible=false,
    })
    make("UIListLayout",page,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
    make("UIPadding",page,{
        PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,8),
        PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,8),
    })
    pages[name]=page
    return page
end
local controls=createPage("controls","Режимы")
local people=createPage("people","Игроки")
local settingsPage=createPage("settings","Настройки")
local function showPage(name)
    for key,page in pairs(pages) do
        page.Visible=key==name
        tabs[key].BackgroundColor3=key==name and colors.accent or colors.panel
    end
end
for name,tab in pairs(tabs) do
    local key=name
    connect(tab.Activated,function() showPage(key) end)
end
local function order(container)
    orders[container]=(orders[container] or 0)+1
    return orders[container]
end
local function label(container,text,height)
    return make("TextLabel",container,{
        LayoutOrder=order(container),Size=UDim2.new(1,0,0,height or 32),
        BackgroundTransparency=1,Text=text,TextSize=16,TextWrapped=true,
        Font=Enum.Font.Gotham,TextColor3=colors.muted,TextXAlignment=Enum.TextXAlignment.Left,
    })
end
local function button(container,text,color)
    local b=make("TextButton",container,{
        LayoutOrder=order(container),Size=UDim2.new(1,0,0,58),
        BackgroundColor3=color or colors.panel,Text=text,TextSize=17,TextWrapped=true,
        Font=Enum.Font.GothamBold,TextColor3=colors.text,
    })
    round(b,13)
    make("UIStroke",b,{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=colors.accent,Transparency=0.75})
    make("UIGradient",b,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(195,203,230))})
    return b
end
local function field(title,default)
    label(settingsPage,title)
    local b=make("TextBox",settingsPage,{
        LayoutOrder=order(settingsPage),Size=UDim2.new(1,0,0,52),
        BackgroundColor3=colors.field,Text=default,ClearTextOnFocus=false,
        TextSize=19,Font=Enum.Font.Gotham,TextColor3=colors.text,
    })
    round(b)
    return b
end
local targetButton=button(controls,"Выбрать игрока ›",colors.field)
local boxButton=button(controls,"Бокс · ВЫКЛ",colors.field)
connect(targetButton.Activated,function() showPage("people") end)
local names={hamam="Hamam",portal="Цикл портала",kill="Автосброс после цели",loop="Повторный TP",tap="Автонажатие",afk="Anti-AFK",freeze="Заморозка"}
local buttons={}
for _,name in ipairs({"hamam","portal","kill","loop","tap","afk","freeze"}) do
    buttons[name]=button(controls,names[name].." · ВЫКЛ")
end
local counter=label(controls,"Завершено циклов: 0")
local stopButton=button(controls,"Остановить режимы",Color3.fromRGB(110,49,66))
local intervalBox=field("Интервал повторного TP, сек.","1")
local killDelayBox=field("Сброс после цели, сек.","3")
local beforeEBox=field("Ожидание перед E, сек.","1.5")
local resetDelayBox=field("Ожидание после E, сек.","3")
local boxPortalDelay=field("После возрождения: портал → бокс, сек.","1.5")
local tapRateBox=field("Кликов / активаций в секунду (1–30)","2")
local tapInfo=label(settingsPage,"Автонажатие: ожидание",58)
label(settingsPage,"Значение 0 убирает ожидание перед E; это не ускоряет возрождение.",58)
local optimizeButton=button(settingsPage,"Оптимизация · ВЫКЛ",Color3.fromRGB(53,75,126))
local optimizeInfo=label(settingsPage,"Графика не изменена",64)
local afkTest=button(settingsPage,"Проверить отправку Anti-AFK")
local afkInfo=label(settingsPage,"Anti-AFK: ещё не проверен",70)
local search=make("TextBox",people,{
    LayoutOrder=order(people),Size=UDim2.new(1,0,0,52),BackgroundColor3=colors.field,
    Text="",PlaceholderText="Поиск по имени...",ClearTextOnFocus=false,
    TextSize=18,Font=Enum.Font.Gotham,TextColor3=colors.text,PlaceholderColor3=colors.muted,
})
round(search)
local list=make("Frame",people,{
    LayoutOrder=order(people),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
    BackgroundTransparency=1,
})
make("UIListLayout",list,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
local function setStatus(text,failed)
    if running then status.Text=text; status.TextColor3=failed and colors.error or colors.muted end
end
local function paint()
    for name,b in pairs(buttons) do
        b.Text=names[name]..(flags[name] and " · ВКЛ" or " · ВЫКЛ")
        b.BackgroundColor3=flags[name] and colors.active or colors.panel
    end
end
local function refresh(excluded)
    if not running then return end
    if selectedPlayer and (selectedPlayer==excluded or selectedPlayer.Parent~=Players) then selectedPlayer=nil end
    targetButton.Text=selectedPlayer and ("Цель: @"..selectedPlayer.Name.." ›") or "Выбрать игрока ›"
    for _,v in ipairs(list:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    local players=Players:GetPlayers()
    table.sort(players,function(a,b) return a.Name:lower()<b.Name:lower() end)
    local query=search.Text:lower()
    orders[list]=0
    for _,other in ipairs(players) do
        if other~=player and other~=excluded and (query=="" or other.Name:lower():find(query,1,true) or other.DisplayName:lower():find(query,1,true)) then
            local b=button(list,other.DisplayName.."\n@"..other.Name,other==selectedPlayer and colors.active or colors.panel)
            b.Size=UDim2.new(1,0,0,66)
            b.TextSize=16
            b.Activated:Connect(function() selectedPlayer=other; refresh(); showPage("controls") end)
        end
    end
end
connect(search:GetPropertyChangedSignal("Text"),function() refresh() end)
connect(Players.PlayerAdded,function() refresh() end)
connect(Players.PlayerRemoving,refresh)
local minimized=false
local function resize()
    if not running then return end
    local size=screen.AbsoluteSize
    if size.X<=0 or size.Y<=0 then return end
    window.Size=UDim2.fromOffset(math.min(530,size.X-16),minimized and 64 or math.min(740,size.Y-16))
end
connect(screen:GetPropertyChangedSignal("AbsoluteSize"),resize)
connect(minimize.Activated,function()
    minimized=not minimized; content.Visible=not minimized; minimize.Text=minimized and "+" or "−"; resize()
end)
local frameCount,frameTime=0,0
connect(RunService.RenderStepped,function(dt)
    frameCount=frameCount+1; frameTime=frameTime+dt
    if frameTime>=1 then
        fpsLabel.Text=string.format("MuMu · FPS: %.0f",frameCount/frameTime)
        frameCount,frameTime=0,0
    end
end)

local function numberValue(box,default,minimum,maximum)
    local value=tonumber((box.Text:gsub(",",".")))
    if not value or value~=value then value=default end
    return math.clamp(value,minimum,maximum)
end
local function alive(character)
    if not character or character~=player.Character or not character.Parent then return nil end
    local root=character:FindFirstChild("HumanoidRootPart")
    local hum=character:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health<=0 then return nil end
    return root,hum
end
local frozenRoot,frozenHumanoid,savedAnchored,savedAutoRotate,frozenCFrame
local function restoreFreeze()
    if frozenRoot and frozenRoot.Parent then
        pcall(function()
            frozenRoot.AssemblyLinearVelocity=Vector3.zero
            frozenRoot.AssemblyAngularVelocity=Vector3.zero
            frozenRoot.Anchored=savedAnchored
        end)
    end
    if frozenHumanoid and frozenHumanoid.Parent then
        pcall(function() frozenHumanoid.AutoRotate=savedAutoRotate end)
    end
    frozenRoot,frozenHumanoid,savedAnchored,savedAutoRotate,frozenCFrame=nil,nil,nil,nil,nil
end
local function updateFreeze()
    local root,hum=alive(player.Character)
    if not flags.freeze or not root then restoreFreeze(); return end
    if root~=frozenRoot or hum~=frozenHumanoid then
        restoreFreeze()
        frozenRoot,frozenHumanoid=root,hum
        savedAnchored,savedAutoRotate=root.Anchored,hum.AutoRotate
        frozenCFrame=root.CFrame
    end
    root.Anchored=true
    if root.CFrame~=frozenCFrame then
        player.Character:PivotTo(frozenCFrame*root.CFrame:ToObjectSpace(player.Character:GetPivot()))
    end
    root.AssemblyLinearVelocity=Vector3.zero
    root.AssemblyAngularVelocity=Vector3.zero
    hum.AutoRotate=false
    hum.Jump=false
end
connect(RunService.Heartbeat,function()
    local ok,err=pcall(updateFreeze)
    if not ok then
        flags.freeze=false
        restoreFreeze()
        paint()
        setStatus("Заморозка: "..tostring(err),true)
    end
end)
local function valid(character,token)
    return running and token==revision and alive(character)~=nil
end
local function waitActive(duration,character,token)
    local finish=os.clock()+duration
    while os.clock()<finish do
        if not valid(character,token) then return false end
        task.wait(0.05)
    end
    return valid(character,token)
end
local function portalPart(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") then return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart",true) end
    if object:IsA("Folder") then return object:FindFirstChildWhichIsA("BasePart",true) end
end
local function findPortal()
    local namesList={"Teleport1","Teleport2","Teleport3","Teleport","Portal"}
    local lobby=workspace:FindFirstChild("Lobby")
    for _,name in ipairs(namesList) do
        local part=portalPart(lobby and lobby:FindFirstChild(name,true))
        if part then return part end
    end
    for _,name in ipairs(namesList) do
        local part=portalPart(workspace:FindFirstChild(name,true))
        if part then return part end
    end
end
local function moveRoot(character,cf)
    local root=alive(character)
    if not root then return false end
    root.AssemblyLinearVelocity=Vector3.zero
    root.AssemblyAngularVelocity=Vector3.zero
    character:PivotTo(cf*root.CFrame:ToObjectSpace(character:GetPivot()))
    if flags.freeze and root==frozenRoot then frozenCFrame=root.CFrame end
    return true
end
local function toPortal(character,token)
    if not valid(character,token) then return false,"Cancelled" end
    if visited[character] then return true end
    local portal=findPortal()
    if not portal then return false,"Портал не найден" end
    if not moveRoot(character,portal.CFrame+Vector3.new(0,2,0)) then return false,"Cancelled" end
    visited[character]=true
    return true
end
local function toTarget(character)
    local target=selectedPlayer
    if not target or target.Parent~=Players then return false,"Выбери игрока" end
    local char=target.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health<=0 then return false,"Ожидание цели" end
    local destination=root.CFrame*CFrame.new(0,0,-3.5)*CFrame.Angles(0,math.pi,0)
    if boxActive then
        local offset=root.Position-BOX_CENTER
        if math.abs(offset.X)>16 or math.abs(offset.Y)>10 or math.abs(offset.Z)>16 then
            return false,"Цель вне бокса · ожидание её возвращения"
        end
        local position=destination.Position-BOX_CENTER
        destination=CFrame.new(BOX_CENTER+Vector3.new(
            math.clamp(position.X,-14,14),math.clamp(position.Y,-7,7),math.clamp(position.Z,-14,14)
        ))*destination.Rotation
    end
    return moveRoot(character,destination)
end
local function releaseE()
    if heldE and type(releaseKey)=="function" then pcall(releaseKey,0x45) end
    heldE=false
end
local function paintBox()
    boxButton.Text=boxActive and "Бокс · ВКЛ" or "Бокс · ВЫКЛ"
    boxButton.BackgroundColor3=boxActive and colors.active or colors.field
end
local function disableBox(restore)
    if restore and boxReturn and boxCharacter and alive(boxCharacter) then
        local ok,moved=pcall(moveRoot,boxCharacter,boxReturn)
        if not ok or not moved then
            setStatus("Не удалось вернуть персонажа; бокс сохранён",true)
            return false
        end
    end
    boxActive=false
    revision=revision+1
    flags.loop=false
    flags.kill=false
    paint()
    if boxModel then boxModel:Destroy() end
    boxModel,boxCharacter,boxReturn=nil,nil,nil
    paintBox()
    return true
end
local function enableBox()
    if boxActive then return true end
    local character=player.Character
    local root,hum=alive(character)
    if not root then setStatus("Дождись появления персонажа",true); return false end
    if hum.Sit or (root.Anchored and root~=frozenRoot) then
        setStatus("Сначала встань с сиденья и дождись возможности двигаться",true)
        return false
    end
    local original=root.CFrame
    local model=Instance.new("Model")
    model.Name="HamamLocalBox"
    local ok,err=pcall(function()
        local function wall(name,size,offset,transparency)
            make("Part",model,{
                Name=name,Size=size,CFrame=CFrame.new(BOX_CENTER+offset),
                Anchored=true,CanCollide=true,CanTouch=false,CanQuery=true,
                CastShadow=false,Material=Enum.Material.SmoothPlastic,
                Color=colors.field,Transparency=transparency or 0,
            })
        end
        wall("Floor",Vector3.new(34,2,34),Vector3.new(0,-11,0))
        wall("Roof",Vector3.new(34,2,34),Vector3.new(0,11,0),0.25)
        wall("Left",Vector3.new(2,20,34),Vector3.new(-17,0,0),0.25)
        wall("Right",Vector3.new(2,20,34),Vector3.new(17,0,0),0.25)
        wall("Front",Vector3.new(32,20,2),Vector3.new(0,0,-17),0.25)
        wall("Back",Vector3.new(32,20,2),Vector3.new(0,0,17),0.25)
        boxModel=model
        model.Parent=workspace
        assert(moveRoot(character,CFrame.new(BOX_CENTER+Vector3.new(0,-5,0))),"Персонаж недоступен")
    end)
    if not ok then
        pcall(moveRoot,character,original)
        model:Destroy(); boxModel=nil
        setStatus("Бокс: "..tostring(err),true)
        return false
    end
    boxCharacter,boxReturn,boxActive=character,original,true
    revision=revision+1
    releaseE()
    flags.hamam,flags.portal=false,false
    paint(); paintBox()
    setStatus("Бокс включён · повторный TP внутри бокса доступен")
    return true
end
connect(boxButton.Activated,function()
    if boxActive then
        if disableBox(true) then setStatus("Бокс удалён · возврат на прежнее место") end
    else
        enableBox()
    end
end)
local boxCheckElapsed=0
local function checkBox(dt)
    if not boxActive then boxCheckElapsed=0; return end
    boxCheckElapsed=boxCheckElapsed+dt
    if boxCheckElapsed<0.1 then return end
    boxCheckElapsed=0
    local root=alive(boxCharacter)
    if not boxModel or not boxModel.Parent then
        disableBox(root~=nil)
        return
    end
    if not root then return end
    local offset=root.Position-BOX_CENTER
    if math.abs(offset.X)>16 or math.abs(offset.Y)>10 or math.abs(offset.Z)>16 then
        local ok,moved=pcall(moveRoot,boxCharacter,CFrame.new(BOX_CENTER+Vector3.new(0,-5,0)))
        if not ok or not moved then
            setStatus("Не удалось вернуть в бокс · повторная проверка активна",true)
        end
    end
end
connect(RunService.Heartbeat,checkBox)
local function sendE(character,token)
    if type(pressKey)~="function" or type(releaseKey)~="function" then return false,"Нет keypress/keyrelease для E" end
    if not valid(character,token) then return false,"Cancelled" end
    local focused=UIS:GetFocusedTextBox()
    if focused then focused:ReleaseFocus() end
    heldE=true
    local ok,err=pcall(pressKey,0x45)
    if not ok then releaseE(); return false,tostring(err) end
    local completed=waitActive(0.1,character,token)
    local released,releaseError=pcall(releaseKey,0x45)
    heldE=false
    if not released then return false,tostring(releaseError) end
    if not completed then return false,"Cancelled" end
    return true
end
local function resetCharacter(character,token)
    if not valid(character,token) then return false,"Cancelled" end
    local _,hum=alive(character)
    hum.Health=0
    local finish=os.clock()+2
    repeat
        if not running or token~=revision then return false,"Cancelled" end
        if player.Character~=character or not hum.Parent or hum.Health<=0 then return true end
        task.wait(0.05)
    until os.clock()>=finish
    return false,"Сброс не применился"
end
local function runCycle(character,token)
    local ok,err=toPortal(character,token)
    if not ok then return false,err end
    if flags.hamam then
        local state=progress[character] or {}
        progress[character]=state
        if not state.sent then
            setStatus("Ожидание перед E")
            if not waitActive(numberValue(beforeEBox,1.5,0,30),character,token) then return false,"Cancelled" end
            ok,err=sendE(character,token)
            if not ok then return false,err end
            state.sent=true
            state.resetAt=os.clock()+numberValue(resetDelayBox,3,0,60)
        end
        setStatus("E отправлена · ожидание сброса")
        if not waitActive(math.max(0,state.resetAt-os.clock()),character,token) then return false,"Cancelled" end
        ok,err=resetCharacter(character,token)
        if not ok then return false,err end
        if not state.counted then
            state.counted=true; uses=uses+1; counter.Text="Завершено циклов: "..uses
        end
        setStatus("Ожидание возрождения · режим сохранён")
        return true
    end
    if not waitActive(0.5,character,token) then return false,"Cancelled" end
    ok,err=toTarget(character)
    if not ok then return false,err end
    if flags.kill then
        if not waitActive(numberValue(killDelayBox,3,0,60),character,token) then return false,"Cancelled" end
        if flags.kill then return resetCharacter(character,token) end
    end
    setStatus("Цель достигнута")
    return true
end

local optimized=false
local generation=0
local saved=setmetatable({}, {__mode="k"})
local changed,failures,lastFailure=0,0,""
local queue,queued={},setmetatable({}, {__mode="k"})
local queueIndex=1
local function writeProperty(object,key,value)
    local ok,current=pcall(function() return object[key] end)
    if not ok then failures=failures+1; lastFailure=tostring(current); return false end
    if current==value then return true end
    local previous=saved[object] and saved[object][key]
    local written,err=pcall(function() object[key]=value end)
    if not written then failures=failures+1; lastFailure=tostring(err); return false end
    saved[object]=saved[object] or {}
    local original=current
    if previous then original=previous.before end
    saved[object][key]={before=original, applied=value}
    changed=changed+1
    return true
end
local function applyGraphics(object)
    if not object.Parent then return end
    if boxModel and object:IsDescendantOf(boxModel) then return end
    if object:IsA("PostEffect") or object:IsA("ParticleEmitter") or object:IsA("Trail")
        or object:IsA("Beam") or object:IsA("Smoke") or object:IsA("Fire")
        or object:IsA("Sparkles") or object:IsA("Light") then
        writeProperty(object,"Enabled",false)
    elseif object:IsA("Atmosphere") then
        writeProperty(object,"Density",0)
        writeProperty(object,"Haze",0)
        writeProperty(object,"Glare",0)
    elseif object:IsA("Decal") or object:IsA("Texture") then
        writeProperty(object,"Transparency",1)
    elseif object:IsA("BasePart") then
        writeProperty(object,"CastShadow",false)
        writeProperty(object,"Reflectance",0)
        writeProperty(object,"Material",Enum.Material.SmoothPlastic)
    end
end
local function enqueue(object)
    if optimized and not queued[object] then
        queued[object]=true; table.insert(queue,object)
    end
end
local function restoreGraphics()
    local errors=0
    for object,properties in pairs(saved) do
        for key,record in pairs(properties) do
            local ok=pcall(function()
                if object[key]==record.applied then object[key]=record.before end
            end)
            if not ok then errors=errors+1 end
        end
    end
    saved=setmetatable({}, {__mode="k"})
    return errors
end
local function setOptimized(enabled)
    generation=generation+1
    local token=generation
    optimized=enabled
    queue,queued,queueIndex={},setmetatable({}, {__mode="k"}),1
    optimizeButton.Text=enabled and "Оптимизация · ВКЛ" or "Оптимизация · ВЫКЛ"
    optimizeButton.BackgroundColor3=enabled and colors.active or colors.panel
    if not enabled then
        local errors=restoreGraphics()
        optimizeInfo.Text=errors==0 and "Исходные настройки восстановлены" or ("Ошибок восстановления: "..errors)
        return
    end
    changed,failures,lastFailure=0,0,""
    optimizeInfo.Text="Обработка графики..."
    writeProperty(Lighting,"GlobalShadows",false)
    writeProperty(workspace.Terrain,"WaterWaveSize",0)
    writeProperty(workspace.Terrain,"WaterWaveSpeed",0)
    writeProperty(workspace.Terrain,"WaterReflectance",0)
    task.spawn(function()
        for _,container in ipairs({workspace,Lighting}) do
            for index,object in ipairs(container:GetDescendants()) do
                if not running or not optimized or token~=generation then return end
                enqueue(object)
                if index%250==0 then task.wait() end
            end
        end
    end)
end
connect(workspace.DescendantAdded,enqueue)
connect(Lighting.DescendantAdded,enqueue)
connect(optimizeButton.Activated,function() setOptimized(not optimized) end)
local graphicsTimer=0
connect(RunService.Heartbeat,function(dt)
    if not optimized then return end
    local deadline=os.clock()+0.002
    local count=0
    while queueIndex<=#queue and count<80 and os.clock()<deadline do
        local object=queue[queueIndex]
        queue[queueIndex]=false
        queueIndex=queueIndex+1
        queued[object]=nil
        local ok,err=pcall(applyGraphics,object)
        if not ok then failures=failures+1; lastFailure=tostring(err) end
        count=count+1
    end
    if queueIndex>#queue then queue={}; queueIndex=1 end
    graphicsTimer=graphicsTimer+dt
    if graphicsTimer>=0.5 then
        graphicsTimer=0
        optimizeInfo.Text=string.format("Изменений: %d · в очереди: %d · ошибок: %d",changed,math.max(0,#queue-queueIndex+1),failures)
        if failures>0 then optimizeInfo.Text=optimizeInfo.Text.."\n"..lastFailure:sub(1,95) end
    end
end)

local afkAttempts,afkSuccess=0,0
local nextAFK=0
local function afkPulse()
    if not running then return false end
    afkAttempts=afkAttempts+1
    local ok,err=pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
    if ok then afkSuccess=afkSuccess+1 end
    afkInfo.Text=ok
        and string.format("Ввод отправлен: %d/%d · %s\nЗащита от отключения ещё не подтверждена",afkSuccess,afkAttempts,os.date("%H:%M:%S"))
        or ("Ошибка отправки: "..tostring(err):sub(1,140))
    afkInfo.TextColor3=ok and colors.muted or colors.error
    return ok
end
connect(afkTest.Activated,function() afkPulse() end)
connect(player.Idled,function()
    if running and flags.afk and os.clock()>=nextAFK then nextAFK=os.clock()+60; afkPulse() end
end)
task.spawn(function()
    while running do
        if flags.afk and os.clock()>=nextAFK then nextAFK=os.clock()+60; afkPulse() end
        task.wait(0.5)
    end
end)

local handledCharacter,handledRevision=nil,-1
local nextAttempt,nextTarget=0,0
local boxResetCharacter,boxResetAt,boxResetRevision
local function stepBoxTarget(character)
    if boxResetCharacter~=character or boxResetRevision~=revision or not flags.kill then
        boxResetCharacter,boxResetAt,boxResetRevision=nil,nil,nil
    end
    if not boxActive or boxCharacter~=character or not alive(character) then return end
    if boxResetAt and os.clock()>=boxResetAt then
        local token=revision
        boxResetCharacter,boxResetAt,boxResetRevision=nil,nil,nil
        local executed,result,reason=pcall(resetCharacter,character,token)
        if not executed or not result then
            setStatus(tostring(executed and reason or result),true)
            nextTarget=os.clock()+1
        else
            setStatus("Автосброс выполнен · после возрождения портал → бокс")
        end
        return
    end
    if os.clock()<nextTarget or not (flags.loop or (flags.kill and not boxResetAt)) then return end
    local executed,moved,reason=pcall(toTarget,character)
    nextTarget=os.clock()+numberValue(intervalBox,1,0.05,30)
    if not executed or not moved then
        setStatus(tostring(executed and reason or moved),true)
        return
    end
    if flags.kill and not boxResetAt then
        boxResetCharacter=character
        boxResetRevision=revision
        boxResetAt=os.clock()+numberValue(killDelayBox,3,0,60)
        setStatus("Цель в боксе достигнута · ожидание автосброса")
    end
end
for name,b in pairs(buttons) do
    local key=name
    connect(b.Activated,function()
        if boxActive and (key=="hamam" or key=="portal") then
            setStatus("Сначала выключи бокс, чтобы вернуться на карту",true)
            return
        end
        flags[key]=not flags[key]
        if key=="freeze" and not flags.freeze then restoreFreeze() end
        if key=="hamam" and flags.hamam then flags.portal=false; flags.loop=false; flags.kill=false
        elseif (key=="portal" or key=="loop" or key=="kill") and flags[key] then flags.hamam=false end
        if key=="hamam" or key=="portal" or key=="loop" or key=="kill" then
            revision=revision+1; nextAttempt=0; releaseE()
        end
        if key=="afk" and flags.afk then nextAFK=0 end
        paint(); setStatus(names[key]..(flags[key] and " включён" or " выключен"))
    end)
end
connect(stopButton.Activated,function()
    for key in pairs(flags) do flags[key]=false end
    restoreFreeze()
    if boxActive then disableBox(true) end
    revision=revision+1; nextAttempt=0; releaseE(); paint(); setStatus("Режимы остановлены")
end)
connect(player.CharacterAdded,function()
    nextAttempt=0; nextTarget=0
    if flags.hamam or flags.portal or flags.loop or flags.kill then setStatus("Ожидание готовности персонажа") end
end)
connect(player.CharacterRemoving,function(character)
    if frozenRoot and frozenRoot:IsDescendantOf(character) then restoreFreeze() end
    if boxCharacter==character then
        boxCharacter,boxReturn=nil,nil
        setStatus("Бокс сохранён · ожидание возрождения")
    end
    releaseE()
    if flags.hamam or flags.portal or flags.loop or flags.kill then setStatus("Ожидание возрождения · режим сохранён") end
end)
task.spawn(function()
    while running do
        local character=player.Character
        if boxActive and alive(character) then
            if boxCharacter~=character and os.clock()>=nextAttempt then
                local token=revision
                local root=alive(character)
                local returnPosition=root.CFrame
                local executed,result,reason=pcall(function()
                    local ok,err=toPortal(character,token)
                    if not ok then return false,err end
                    setStatus("Возрождение · портал → ожидание перехода → бокс")
                    if not waitActive(numberValue(boxPortalDelay,1.5,0,30),character,token) or not boxActive then
                        return false,"Cancelled"
                    end
                    if not moveRoot(character,CFrame.new(BOX_CENTER+Vector3.new(0,-5,0))) then return false,"Cancelled" end
                    boxCharacter,boxReturn=character,returnPosition
                    setStatus("Персонаж вернулся в бокс")
                    return true
                end)
                if running and boxActive and token==revision and (not executed or not result) then
                    nextAttempt=os.clock()+1
                    local message=executed and reason or result
                    if message~="Cancelled" then setStatus(tostring(message),true) end
                end
                nextTarget=os.clock()+numberValue(intervalBox,1,0.05,30)
            elseif boxCharacter==character then
                stepBoxTarget(character)
            end
        elseif not boxActive and (flags.hamam or flags.portal or flags.loop or flags.kill) and alive(character) then
            local token=revision
            local fresh=handledCharacter~=character or handledRevision~=token
            if fresh and os.clock()>=nextAttempt then
                handledCharacter,handledRevision=character,token
                local executed,result,reason=pcall(runCycle,character,token)
                releaseE()
                if running and revision==token and (not executed or not result) then
                    if not alive(character) then setStatus("Ожидание возрождения · режим сохранён")
                    else
                        handledCharacter,handledRevision=nil,-1
                        nextAttempt=os.clock()+3
                        local message=executed and reason or result
                        if message~="Cancelled" then setStatus(tostring(message or "Ошибка").." · повтор действия через 3 сек.",true) end
                    end
                end
                nextTarget=os.clock()+numberValue(intervalBox,1,0.05,30)
            elseif not fresh and flags.loop and not flags.hamam and os.clock()>=nextTarget then
                local executed,result,reason=pcall(toTarget,character)
                if not executed or not result then setStatus(tostring(executed and reason or result),true) end
                nextTarget=os.clock()+numberValue(intervalBox,1,0.05,30)
            end
        end
        task.wait(0.05)
    end
end)
local activeTool
local function releaseTool()
    if activeTool then pcall(function() activeTool:Deactivate() end) end
    activeTool=nil
end
local function autoTap(holdDuration)
    local character=player.Character
    if not running or not flags.tap or not alive(character) then return false,"Ожидание персонажа" end
    local tool=character:FindFirstChildOfClass("Tool")
    if tool then
        if not tool.Enabled then return false,"Предмет на перезарядке" end
        if tool.RequiresHandle and not tool:FindFirstChild("Handle") then return false,"У предмета отсутствует Handle" end
        activeTool=tool
        local ok,err=pcall(function() tool:Activate() end)
        if not ok then releaseTool(); return false,tostring(err) end
        task.wait(holdDuration or 0.05)
        releaseTool()
        return true,"Активация предмета отправлена"
    end
    local ok,err=pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.zero)
    end)
    return ok,ok and "Клик отправлен · предмет не выбран" or tostring(err)
end
task.spawn(function()
    local lastTap=-math.huge
    while running do
        local interval=1/numberValue(tapRateBox,2,1,30)
        local elapsed=os.clock()-lastTap
        if flags.tap and elapsed>=interval then
            lastTap=os.clock()
            local executed,ok,message=pcall(autoTap,math.min(0.05,interval*0.4))
            if running then
                tapInfo.Text="Автонажатие: "..tostring(executed and message or ok)
                tapInfo.TextColor3=executed and ok and colors.muted or colors.error
            end
        end
        if flags.tap then
            local remaining=1/numberValue(tapRateBox,2,1,30)-(os.clock()-lastTap)
            task.wait(math.max(0,math.min(0.05,remaining)))
        else
            lastTap=-math.huge
            task.wait(0.1)
        end
    end
end)
local cleanup
cleanup=function()
    if not running then return end
    flags.freeze=false
    restoreFreeze()
    disableBox(true)
    running=false; revision=revision+1; generation=generation+1; optimized=false
    releaseTool()
    releaseE()
    for _,connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    queue={}; queued={}
    restoreGraphics()
    if env.UnifiedTP_Cleanup==cleanup then env.UnifiedTP_Cleanup=nil end
    gui:Destroy()
end
env.UnifiedTP_Cleanup=cleanup
connect(close.Activated,cleanup)
connect(gui.Destroying,cleanup)
showPage("controls")
refresh()
paint()
task.defer(resize)
