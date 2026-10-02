-- Authored curved ribbons, ballistic sparks and vapor: no Fire, Smoke, stock particle textures or emitters.
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local templates=RS:WaitForChild("GS_AssetPreviews"):WaitForChild("Effects")
local settings=require(script.Parent:WaitForChild("GameSettings"))
local VFX={}
local folder=workspace:FindFirstChild("GS_FX") or Instance.new("Folder")
folder.Name="GS_FX" folder.Parent=workspace
local transient={}
local fires={}
local rng=Random.new()
local function anchor(position)
 local p=templates:WaitForChild("FXAnchor"):Clone() p.Position=position or Vector3.zero p.Parent=folder return p
end
local function ribbon(parent,name,a,b,width,color)
 local first=Instance.new("Attachment") first.Position=a first.Parent=parent
 local last=Instance.new("Attachment") last.Position=b last.Parent=parent
 local beam=templates:WaitForChild(name):Clone()
 beam.Attachment0=first beam.Attachment1=last beam.Width0=width beam.Color=ColorSequence.new(color)
 beam.Parent=parent
 return {beam=beam,a=first,b=last}
end
local function add(entry)
 while #transient>140 do local old=table.remove(transient,1) old.part:Destroy() end
 table.insert(transient,entry)
end
function VFX.Smoke(position,direction,scale,color)
 scale=scale or 1
 local count=settings.Get("LowGraphics") and 1 or 3
 for i=1,count do
  local p=anchor(position)
  local r=ribbon(p,"SmokeRibbon",Vector3.zero,Vector3.new(.05,.3,0)*scale,.12*scale,color or Color3.fromRGB(94,88,82))
  r.beam.Width1=.35*scale r.beam.CurveSize0=.15*scale r.beam.CurveSize1=-.22*scale
  add({part=p,r=r,kind="smoke",age=0,life=rng:NextNumber(.5,.95),velocity=(direction or Vector3.yAxis)*rng:NextNumber(.4,1.2)+Vector3.new(rng:NextNumber(-.3,.3),.6,rng:NextNumber(-.3,.3)),scale=scale,phase=rng:NextNumber(0,6)})
 end
end
function VFX.Sparks(position,normal,color,count)
 count=math.min(count or 7,settings.Get("LowGraphics") and 4 or 12)
 for _=1,count do
  local p=anchor(position)
  local dir=(normal or Vector3.yAxis)+Vector3.new(rng:NextNumber(-.9,.9),rng:NextNumber(-.4,.9),rng:NextNumber(-.9,.9))
  if dir.Magnitude<.01 then dir=Vector3.yAxis end
  local r=ribbon(p,"SparkRibbon",Vector3.zero,Vector3.zero,.016,color or Color3.fromRGB(241,168,79))
  add({part=p,r=r,kind="spark",velocity=dir.Unit*rng:NextNumber(5,14),age=0,life=rng:NextNumber(.12,.32),position=position})
 end
end
function VFX.Impact(position,normal,color,sparks)
 if sparks then VFX.Sparks(position,normal,color,7) end
 VFX.Smoke(position,normal,.6,color)
end
function VFX.Muzzle(position,look)
 local p=anchor(position)
 local cf=CFrame.lookAt(position,position+look)
 p.CFrame=cf
 for i=1,4 do
  local angle=i*math.pi*.5
  local tip=Vector3.new(math.cos(angle)*.055,math.sin(angle)*.055,-rng:NextNumber(.38,.8))
  local r=ribbon(p,"FlameRibbon",Vector3.zero,tip,.07,Color3.fromRGB(255,208,120))
  r.beam.Transparency=NumberSequence.new(.15,1)
 end
 local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,195,105) light.Range=10 light.Brightness=2.4 light.Parent=p
 add({part=p,kind="flash",age=0,life=.045})
 VFX.Smoke(position,look,.5)
end
-- a shotgun's muzzle blast: a star of flame out of the barrel, a hard flash of light, burning powder sparks
-- thrown forward and a thick puff of smoke that hangs for a moment
function VFX.MuzzleBlast(position,look,strength)
 strength=strength or 1
 local p=anchor(position)
 p.CFrame=CFrame.lookAt(position,position+look)
 local tongues=settings.Get("LowGraphics") and 4 or 7
 for i=1,tongues do
  local angle=i/tongues*math.pi*2+rng:NextNumber(-.2,.2)
  local spread=rng:NextNumber(.04,.12)*strength
  local tip=Vector3.new(math.cos(angle)*spread,math.sin(angle)*spread,-rng:NextNumber(.5,1.15)*strength)
  local r=ribbon(p,"FlameRibbon",Vector3.zero,tip,.11*strength,Color3.fromRGB(255,214,140))
  r.beam.Transparency=NumberSequence.new(.05,1)
  r.beam.LightEmission=1
 end
 -- the core: a short bright cone straight ahead
 local core=ribbon(p,"FlameRibbon",Vector3.zero,Vector3.new(0,0,-.55*strength),.2*strength,Color3.fromRGB(255,244,210))
 core.beam.Transparency=NumberSequence.new(0,1)
 local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,196,110) light.Range=16*strength light.Brightness=3.6 light.Shadows=true light.Parent=p
 add({part=p,kind="flash",age=0,life=.06})
 VFX.Sparks(position+look*.3,look,Color3.fromRGB(255,190,110),settings.Get("LowGraphics") and 3 or 7)
 VFX.Smoke(position+look*.4,look*.6+Vector3.yAxis*.3,.9*strength,Color3.fromRGB(150,146,140))
 VFX.Smoke(position,Vector3.yAxis,.6*strength,Color3.fromRGB(120,116,110))
end
function VFX.Ignite(target,scale,offset)
 if not target or not target.Parent then return end
 local p=anchor(target.Position)
 p.Name="GS_CustomFlame"
 local state={part=p,target=target,scale=scale or 1,offset=offset or Vector3.zero,ribbons={},age=0,nextSmoke=0}
 for i=1,(settings.Get("LowGraphics") and 4 or 8) do
  local r=ribbon(p,"FlameRibbon",Vector3.zero,Vector3.yAxis,.16*(scale or 1),Color3.fromRGB(255,132,45))
  r.beam.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,223,144)),ColorSequenceKeypoint.new(.35,Color3.fromRGB(244,119,35)),ColorSequenceKeypoint.new(1,Color3.fromRGB(140,37,14))})
  r.phase=i*2.39996 r.height=rng:NextNumber(.6,1.2) table.insert(state.ribbons,r)
 end
 local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,140,60) light.Range=math.clamp(12*state.scale,3,20) light.Brightness=1.3 light.Parent=p state.light=light
 fires[state]=true
 local handle={}
 function handle:Destroy() fires[state]=nil p:Destroy() end
 return handle
end
RunService.RenderStepped:Connect(function(dt)
 dt=math.min(dt,.1)
 for i=#transient,1,-1 do
  local e=transient[i] e.age+=dt
  if e.age>=e.life or not e.part.Parent then e.part:Destroy() table.remove(transient,i)
  elseif e.kind=="spark" then
   local old=e.position e.velocity+=Vector3.new(0,-workspace.Gravity*.45,0)*dt e.position+=e.velocity*dt
   e.part.Position=e.position
   e.r.a.Position=Vector3.zero e.r.b.Position=-e.velocity.Unit*math.min(.35,e.velocity.Magnitude*.018)
   e.r.beam.Transparency=NumberSequence.new(math.clamp(e.age/e.life,.15,1),1)
  elseif e.kind=="smoke" then
   local k=e.age/e.life e.part.Position+=e.velocity*dt
   e.r.a.Position=Vector3.new(math.sin(e.phase+e.age*3)*.07,0,0)*e.scale
   e.r.b.Position=Vector3.new(math.cos(e.phase+e.age*2)*.24,.3+k*.7,0)*e.scale
   e.r.beam.Width0=(.13+k*.35)*e.scale e.r.beam.Width1=(.35+k*.6)*e.scale
   e.r.beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,.82+k*.18),NumberSequenceKeypoint.new(1,1)})
  end
 end
 local now=os.clock()
 for state in pairs(fires) do
  if not state.target.Parent then state.part:Destroy() fires[state]=nil
  else
   state.part.CFrame=CFrame.new(state.target.CFrame:PointToWorldSpace(state.offset))
   local s=state.scale
   for i,r in ipairs(state.ribbons) do
    local t=now*4.8+r.phase local pulse=.75+.25*math.sin(t*1.7)
    local radiusX=math.min(state.target.Size.X*.5+.035,s*.6)
 local radiusZ=math.min(state.target.Size.Z*.5+.035,s*.6)
 local radial=Vector3.new(math.cos(r.phase)*radiusX,0,math.sin(r.phase)*radiusZ)

    r.a.Position=radial
    r.b.Position=radial+Vector3.new(math.sin(t)*.14,r.height*pulse,math.cos(t*.8)*.1)*s
    r.beam.Width0=(.23+.07*math.sin(t+.5))*s
    r.beam.CurveSize0=math.sin(t*.9)*.3*s r.beam.CurveSize1=math.cos(t)*.2*s
    r.beam.Transparency=NumberSequence.new(.22+.12*math.sin(t),1)
   end
   state.light.Brightness=.9+.45*math.noise(now*12,2)
   if now>state.nextSmoke and s>.4 then
    state.nextSmoke=now+.25
    VFX.Smoke(state.part.Position+Vector3.yAxis*s,Vector3.yAxis,s*.45,Color3.fromRGB(66,62,58))
   end
  end
 end
end)
local emitters={}
function VFX.Emitter(parent,kind,props)
 local e={Parent=parent,Rate=0,Enabled=true,kind=kind or "smoke",acc=0}
 for k,value in pairs(props or {}) do e[k]=value end
 function e:Emit(count)
  local p=self.Parent if not p or not p.Parent or self.Enabled==false then return end
  local position=p:IsA("Attachment") and p.WorldPosition or p.Position
  local color=self.Color and self.Color.Keypoints[1].Value or Color3.fromRGB(134,128,120)
  if self.kind=="spark" then VFX.Sparks(position,Vector3.yAxis,color,math.min(count,8))
  else
   local scale=self.Size and math.clamp(self.Size.Keypoints[#self.Size.Keypoints].Value*.4,.3,3) or 1
   if p:IsA("BasePart") and p.Size.X>5 then position+=Vector3.new(rng:NextNumber(-p.Size.X/2,p.Size.X/2),0,rng:NextNumber(-p.Size.Z/2,p.Size.Z/2)) end
   VFX.Smoke(position,Vector3.yAxis,scale,color)
  end
 end
 function e:Destroy() self.destroyed=true end
 table.insert(emitters,e)
 return e
end
RunService.Heartbeat:Connect(function(dt)
 for i=#emitters,1,-1 do
  local e=emitters[i]
  if e.destroyed or (e.Parent and not e.Parent.Parent) then table.remove(emitters,i)
  elseif e.Parent and e.Enabled~=false then
   e.acc+=dt*math.min(e.Rate or 0,4)
   if e.acc>=1 then e.acc=0 e:Emit(1) end
  end
 end
end)
return VFX

