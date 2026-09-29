-- The moving parts of every gun in someone's hands, and everything a reload looks and sounds like. Drawn on each
-- client for everyone, from the attributes the server puts on the character (GS_ReloadPhase / PhaseAt / PhaseDur /
-- ReloadCount, GS_PumpAt, GS_RecoilAt). Parts marked with a Motion attribute in the item model move:
--   Barrel  break-action barrels swing down on a hinge      Pump / Bolt  slide back and forward
-- Double barrel: break it open (overshoots, settles), the spent hulls kick out over the shoulder, the other hand
--   brings fresh shells up from the belt one by one and thumbs them into the chambers, then it's snapped shut.
-- Flare gun: the same with one fat flare cartridge.
-- Warden 870: rolled over to show the loading port, shells pushed into the tube one at a time, racked at the end;
--   after every shot the fore-end is pumped and the hull flies out of the ejection port.
-- After a shot the barrels smoke for a moment. Every sound goes through CombatAudio (no pile-ups).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Modules=RS:WaitForChild("Modules")
local ItemData=require(Modules:WaitForChild("ItemData"))
local Audio=require(Modules:WaitForChild("CombatAudio"))
local VFX=require(Modules:WaitForChild("CustomVFX"))
local GameSettings=require(Modules:WaitForChild("GameSettings"))

local folder=workspace:FindFirstChild("GS_FX") or Instance.new("Folder")
folder.Name="GS_FX" folder.Parent=workspace
local rng=Random.new()
local function low() return GameSettings.Get("LowGraphics")==true end
local function smooth(x) x=math.clamp(x,0,1) return x*x*(3-2*x) end
local function backOut(x) x=math.clamp(x,0,1) local c=1.9 return 1+(c+1)*(x-1)^3+c*(x-1)^2 end

-- per gun: how it opens and where the shells go (model space, before the held scale)
local RIG={
 doublebarrel={kind="break",hinge=Vector3.new(.15,-.08,0),angle=38,cartridge="shell",
  breech={Vector3.new(.12,.2,-.125),Vector3.new(.12,.2,.125)}},
 flaregun={kind="break",hinge=Vector3.new(.02,.08,0),angle=50,cartridge="flare",
  breech={Vector3.new(-.3,.28,0)}},
 warden870={kind="pump",pump=.34,bolt=.25,cartridge="shell"},
}
local CART={
 shell={len=.5,dia=.17,hull=Color3.fromRGB(158,26,24),spent=Color3.fromRGB(104,22,20),head=.11},
 flare={len=.52,dia=.27,hull=Color3.fromRGB(226,104,38),spent=Color3.fromRGB(150,70,30),head=.13,band=true},
}

-- a cartridge built from parts (X is its axis, the brass head at -X)
local function cartridge(kind,scale,spent)
 local c=CART[kind] or CART.shell
 local s=scale or 1
 local hull=Instance.new("Part") hull.Name="GS_Cartridge" hull.Shape=Enum.PartType.Cylinder
 hull.Size=Vector3.new(c.len,c.dia,c.dia)*s hull.Color=spent and c.spent or c.hull hull.Material=Enum.Material.SmoothPlastic
 hull.CanQuery=false hull.CanTouch=false hull.CastShadow=false
 local head=Instance.new("Part") head.Name="Head" head.Shape=Enum.PartType.Cylinder
 head.Size=Vector3.new(c.head,c.dia*1.08,c.dia*1.08)*s head.Color=Color3.fromRGB(196,160,72) head.Material=Enum.Material.Metal
 head.CanCollide=false head.CanQuery=false head.CanTouch=false head.Massless=true head.CastShadow=false
 head.CFrame=hull.CFrame*CFrame.new(-(c.len-c.head)/2*s,0,0) head.Parent=hull
 local w=Instance.new("WeldConstraint") w.Part0=hull w.Part1=head w.Parent=head
 if c.band then
  local band=Instance.new("Part") band.Name="Band" band.Shape=Enum.PartType.Cylinder
  band.Size=Vector3.new(.06,c.dia*1.02,c.dia*1.02)*s band.Color=Color3.fromRGB(236,232,222) band.Material=Enum.Material.SmoothPlastic
  band.CanCollide=false band.CanQuery=false band.CanTouch=false band.Massless=true band.CastShadow=false
  band.CFrame=hull.CFrame*CFrame.new(.12*s,0,0) band.Parent=hull
  local w2=Instance.new("WeldConstraint") w2.Part0=hull w2.Part1=band w2.Parent=band
 end
 return hull
end

-- a spent hull flying out: real physics on this client, a clink when it lands, gone after a while
local function spentHull(kind,cf,velocity,scale)
 local hull=cartridge(kind,scale,true)
 hull.CFrame=cf hull.Anchored=false hull.CanCollide=true hull.Parent=folder
 for _,d in ipairs(hull:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=false end end
 hull.AssemblyLinearVelocity=velocity
 hull.AssemblyAngularVelocity=Vector3.new(rng:NextNumber(-1,1),rng:NextNumber(-1,1),rng:NextNumber(-1,1))*18
 -- a wisp of smoke from the fired hull
 if not low() then VFX.Smoke(cf.Position,Vector3.yAxis,.35,Color3.fromRGB(120,114,108)) end
 task.delay(.45+rng:NextNumber(0,.15),function() if hull.Parent then Audio.Play("ShellDrop",hull,.35,rng:NextNumber(.9,1.15),45) end end)
 Debris:AddItem(hull,12)
end

-- ===== per character state =====
local states={}
local function stateFor(character,model)
 local st=states[character]
 if st and st.model==model then return st end
 if st and st.inHand then st.inHand:Destroy() end
 st={model=model,joints={},phaseKey=nil,events={},pumpDone=nil,recoilDone=nil,smokeUntil=0,lastSmoke=0}
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA("BasePart") and p:GetAttribute("Motion") then
   local w=p:FindFirstChild("GS_ItemWeld")
   if w and w:GetAttribute("ModelFrame") and w:GetAttribute("LocalFrame") then
    table.insert(st.joints,{w=w,motion=p:GetAttribute("Motion")})
   end
  end
 end
 st.anyWeld=model:FindFirstChild("GS_ItemWeld",true)
 states[character]=st
 return st
end

-- the held model's own frame in the world (all its welds share it)
local function modelFrame(st)
 local w=st.anyWeld
 if not w or not w.Parent or not w.Part0 then return nil end
 return w.Part0.CFrame*w:GetAttribute("ModelFrame")
end
local function barrelMotion(rig,scale,open)
 if not rig or rig.kind~="break" then return CFrame.new() end
 local h=rig.hinge*scale
 return CFrame.new(h)*CFrame.Angles(0,0,-math.rad(rig.angle)*open)*CFrame.new(-h)
end
local function breechCF(st,rig,scale,open,i)
 local mf=modelFrame(st)
 if not mf or not rig.breech then return nil end
 return mf*barrelMotion(rig,scale,open)*CFrame.new(rig.breech[i]*scale)
end
local function handCF(character)
 local arm=character:FindFirstChild("Left Arm")
 return arm and arm.CFrame*CFrame.new(0,-1.05,0) or nil
end
local function once(st,key,fn)
 if st.events[key] then return end
 st.events[key]=true
 fn()
end

RunService.RenderStepped:Connect(function()
 local now=workspace:GetServerTimeNow()
 for _,player in ipairs(Players:GetPlayers()) do
  local c=player.Character
  local model=c and c:FindFirstChild("GS_Held")
  local item=model and ItemData.Get(model:GetAttribute("ItemId"))
  if not item or item.kind~="gun" then
   local old=c and states[c]
   if old then if old.inHand then old.inHand:Destroy() end states[c]=nil end
   continue
  end
  local st=stateFor(c,model)
  local rig=RIG[item.id] or {kind="none"}
  local scale=model:GetScale()
  local head=c:FindFirstChild("Head")

  -- ===== the reload, phase by phase =====
  local phase=c:GetAttribute("GS_ReloadPhase")
  local phaseAt=c:GetAttribute("GS_ReloadPhaseAt") or now
  local dur=math.max(c:GetAttribute("GS_ReloadPhaseDur") or .5,.01)
  local pt=math.clamp((now-phaseAt)/dur,0,1)
  local key=phase and (phase..string.format("%.2f",phaseAt)) or nil
  if key~=st.phaseKey then
   st.phaseKey=key
   st.events={}
   if st.inHand then st.inHand:Destroy() st.inHand=nil end
  end
  local open=0
  local pump=0
  if rig.kind=="break" then
   if phase=="open" then
    open=backOut(pt/.7)
    once(st,"latch",function() Audio.Play("Click",head,.45,.85,40) end)
    if pt>.6 then
     -- the extractor kicks the hulls out, back over the shoulder
     once(st,"extract",function()
      local mf=modelFrame(st)
      local back=mf and -mf.XVector or Vector3.zero
      for i=1,#rig.breech do
       local cf=breechCF(st,rig,scale,1,i)
       if cf then
        spentHull(rig.cartridge,cf*CFrame.new(-.2*scale,0,0),back*rng:NextNumber(7,10)+Vector3.new(0,rng:NextNumber(7,10),0)+Vector3.new(rng:NextNumber(-1.5,1.5),0,rng:NextNumber(-1.5,1.5)))
       end
      end
      Audio.Play("Rack",head,.22,1.6,35)
     end)
    end
   elseif phase=="load" then
    open=1
   elseif phase=="close" then
    local k=pt/.35
    open=k<1 and 1-k*k or math.max(0,math.sin((k-1)*math.pi)*.04)
    once(st,"shut",function()
     task.delay(dur*.3,function() if head and head.Parent then Audio.Play("Click",head,.55,1.15,45) end end)
    end)
   end
  elseif rig.kind=="pump" then
   if phase=="close" then
    pump=math.sin(math.clamp(pt/.7,0,1)*math.pi)
    once(st,"rack",function() Audio.Play("Rack",head,.5,1,55) end)
   elseif phase=="open" then
    once(st,"gate",function() Audio.Play("Click",head,.35,1.2,35) end)
   end
  end

  -- ===== loading shells by hand =====
  if phase=="load" then
   local n=math.max(1,c:GetAttribute("GS_ReloadCount") or 1)
   local slot=math.min(math.floor(pt*n),n-1)
   local sub=math.clamp(pt*n-slot,0,1)
   local hand=handCF(c)
   local target
   if rig.kind=="break" then
    target=breechCF(st,rig,scale,1,math.min(slot+1,#rig.breech))
   else
    local port=model:FindFirstChild("LoadingPort",true)
    target=port and port.WorldCFrame*CFrame.Angles(0,math.pi/2,0)
   end
   if sub>=.3 and sub<.95 and hand and target then
    if not st.inHand then
     st.inHand=cartridge(rig.cartridge or "shell",scale,false)
     st.inHand.Anchored=true st.inHand.CanCollide=false
     for _,d in ipairs(st.inHand:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=true end end
     st.inHand.Parent=folder
     once(st,"grab"..slot,function() Audio.Play("Cloth",head,.18,1.5,20) end)
    end
    -- in the hand (pointing along the arm), then lined up with the chamber and pushed in
    local held=CFrame.fromMatrix(hand.Position,-hand.UpVector,hand.LookVector)
    local cf
    if sub<.72 then
     cf=held
    else
     local k=smooth((sub-.72)/.23)
     local mouth=target*CFrame.new(-.45*scale*(1-k),0,0)
     cf=held:Lerp(mouth,smooth((sub-.72)/.1))
     cf=cf:Lerp(mouth,k)
    end
    st.inHand:PivotTo(cf)
    if sub>.85 then once(st,"in"..slot,function() Audio.Play("ShellIn",head,.45,rng:NextNumber(.95,1.08),35) end) end
   elseif st.inHand then
    st.inHand:Destroy() st.inHand=nil
   end
  elseif st.inHand then
   st.inHand:Destroy() st.inHand=nil
  end

  -- ===== the pump after a shot =====
  local pumpAt=c:GetAttribute("GS_PumpAt")
  if rig.kind=="pump" and pumpAt then
   local t=(now-pumpAt)/(item.pumpDuration or .42)
   if t>=0 and t<=1 then
    pump=math.max(pump,math.sin(t*math.pi))
    -- (the shooter's own client and then the server both set it: one pump per shot)
    if not st.pumpDone or math.abs(st.pumpDone-pumpAt)>.4 then
     st.pumpDone=pumpAt
     Audio.Play("Rack",head,.5,1,60)
     task.delay((item.pumpDuration or .42)*.4,function()
      local port=model.Parent and model:FindFirstChild("EjectionPort",true)
      local mf=modelFrame(st)
      if port and mf then
       spentHull("shell",port.WorldCFrame*CFrame.Angles(0,-math.pi/2,0),mf.ZVector*rng:NextNumber(8,11)+Vector3.new(0,rng:NextNumber(8,11),0)-mf.XVector*2,scale)
      end
     end)
    end
   end
  end

  -- ===== smoke from the barrels after a shot =====
  local recoilAt=c:GetAttribute("GS_RecoilAt")
  if recoilAt and (not st.recoilDone or math.abs(st.recoilDone-recoilAt)>.2) and now-recoilAt<.5 then
   st.recoilDone=recoilAt
   st.smokeUntil=os.clock()+(item.fire and .8 or 1.8)
  end
  if os.clock()<st.smokeUntil and os.clock()-st.lastSmoke>(low() and .25 or .11) then
   st.lastSmoke=os.clock()
   local muzzle=model:FindFirstChild("Muzzle",true)
   if muzzle and muzzle:IsA("Attachment") then
    local left=(st.smokeUntil-os.clock())/1.8
    VFX.Smoke(muzzle.WorldPosition,Vector3.yAxis,.25+.25*left,Color3.fromRGB(130,126,120))
   end
  end

  -- ===== move the parts =====
  for _,j in ipairs(st.joints) do
   local w=j.w
   if w.Parent then
    local motion=CFrame.new()
    if j.motion=="Pump" then motion=CFrame.new(-(rig.pump or .34)*scale*pump,0,0)
    elseif j.motion=="Bolt" then motion=CFrame.new(-(rig.bolt or .25)*scale*pump,0,0)
    elseif j.motion=="Barrel" then motion=barrelMotion(rig,scale,open)
    end
    w.C0=w:GetAttribute("ModelFrame")*motion*w:GetAttribute("LocalFrame")
   end
  end
 end
 for character,st in pairs(states) do
  if not character.Parent or not st.model.Parent then
   if st.inHand then st.inHand:Destroy() end
   states[character]=nil
  end
 end
end)
