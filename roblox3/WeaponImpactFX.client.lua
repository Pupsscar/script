-- What guns do to the world, drawn on every client:
--   * pellet impacts: a puff of the surface's own dust, sparks and a ring off metal, a small scorched mark
--   * the flare: leaves the muzzle (not the head), a white-hot core in a red glow, a spark and smoke trail, a hiss.
--     It skips off walls, sticks burning in whatever it hits, or lies on the floor and burns like a road flare:
--     a flickering red light, a steady shower of sparks and a pink-grey plume, then it dies out.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Audio=require(RS:WaitForChild("Modules"):WaitForChild("CombatAudio"))
local VFX=require(RS.Modules:WaitForChild("CustomVFX"))
local GameSettings=require(RS.Modules:WaitForChild("GameSettings"))
local remote=RS:WaitForChild("GS_Weapon")
local folder=workspace:FindFirstChild("GS_FX") or Instance.new("Folder")
folder.Name="GS_FX" folder.Parent=workspace

local RED=Color3.fromRGB(255,62,48)
local HOT=Color3.fromRGB(255,228,210)
local SMOKE=Color3.fromRGB(176,128,126)
local rng=Random.new()
local function low() return GameSettings.Get("LowGraphics")==true end

local function anchor(pos)
 local p=Instance.new("Part") p.Name="GS_Impact" p.Size=Vector3.one*.08 p.Position=pos
 p.Transparency=1 p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.Parent=folder return p
end
local holes={}
local function dust(pos,normal,color,sparks) VFX.Impact(pos,normal,color,sparks) end

-- ===== the flare in flight =====
local flights={}
local function muzzleOf(character)
 local held=typeof(character)=="Instance" and character:FindFirstChild("GS_Held")
 local m=held and held:FindFirstChild("Muzzle",true)
 return m and m:IsA("Attachment") and m.WorldPosition or nil
end
local function makeFlare(position)
 local core=Instance.new("Part") core.Name="GS_FlareProjectile" core.Shape=Enum.PartType.Ball core.Size=Vector3.one*.34
 core.Material=Enum.Material.Neon core.Color=RED core.Anchored=true core.CanCollide=false core.CanQuery=false core.CanTouch=false
 core.CastShadow=false core.Position=position core.Parent=folder
 local heart=Instance.new("Part") heart.Name="GS_FlareHeart" heart.Shape=Enum.PartType.Ball heart.Size=Vector3.one*.17
 heart.Material=Enum.Material.Neon heart.Color=HOT heart.Anchored=true heart.CanCollide=false heart.CanQuery=false heart.CanTouch=false
 heart.CastShadow=false heart.Position=position heart.Parent=core
 local light=Instance.new("PointLight") light.Color=RED light.Range=30 light.Brightness=3.2 light.Shadows=not low() light.Parent=core
 local a0=Instance.new("Attachment") a0.Position=Vector3.new(0,.14,0) a0.Parent=core
 local a1=Instance.new("Attachment") a1.Position=Vector3.new(0,-.14,0) a1.Parent=core
 local trail=Instance.new("Trail") trail.Attachment0=a0 trail.Attachment1=a1 trail.Lifetime=.4 trail.LightEmission=1 trail.FaceCamera=true
 trail.Color=ColorSequence.new(Color3.fromRGB(255,120,90),Color3.fromRGB(120,20,16))
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=NumberSequence.new(1,.15) trail.Parent=core
 local hiss=Audio.Play("Sizzle",core,.3,1.6,70,true)
 return {core=core,heart=heart,light=light,hiss=hiss}
end
local function endFlight(f)
 if f.fx.hiss then f.fx.hiss:Destroy() end
 f.fx.core:Destroy()
end

-- ===== a flare stuck in something, burning =====
local function stuckFlare(part,position,normal)
 if typeof(part)~="Instance" or not part:IsA("BasePart") then return end
 local fx=makeFlare(position)
 local offset=part.CFrame:ToObjectSpace(CFrame.new(position))
 local t0=os.clock()
 local conn
 conn=RunService.RenderStepped:Connect(function()
  local age=os.clock()-t0
  if not part.Parent or age>5 then
   conn:Disconnect()
   if fx.hiss then fx.hiss:Destroy() end
   fx.core:Destroy()
   return
  end
  local cf=part.CFrame*offset
  fx.core.CFrame=cf fx.heart.CFrame=cf
  fx.light.Brightness=2.4+math.noise(age*14,1)*1.2
  if rng:NextNumber()<.3 then VFX.Sparks(cf.Position,Vector3.yAxis,Color3.fromRGB(255,170,120),2) end
  if rng:NextNumber()<.15 then VFX.Smoke(cf.Position,Vector3.yAxis,.5,SMOKE) end
 end)
end

remote.OnClientEvent:Connect(function(kind,a,b,c,d,e,f)
 if kind=="surface" then
  local pos,normal,material=a,b,c
  local metal=material==Enum.Material.Metal or material==Enum.Material.DiamondPlate or material==Enum.Material.CorrodedMetal
  local wood=material==Enum.Material.Wood or material==Enum.Material.WoodPlanks
  dust(pos,normal,metal and Color3.fromRGB(235,192,116) or wood and Color3.fromRGB(116,87,56) or Color3.fromRGB(141,137,126),metal)
  if metal then local p=anchor(pos) Audio.Play("MetalHit",p,.22,1.25,65) Debris:AddItem(p,1) end
  while #holes>=50 do local old=table.remove(holes,1) old:Destroy() end
  local p=anchor(pos+normal*.012) p.Name="GS_BulletMark" p.Transparency=.18 p.Color=Color3.fromRGB(23,22,20)
  p.Shape=Enum.PartType.Cylinder p.Size=Vector3.new(.012,.065,.065)
  p.CFrame=CFrame.lookAt(pos+normal*.012,pos+normal)*CFrame.Angles(0,math.pi/2,0)
  table.insert(holes,p) Debris:AddItem(p,18)
 elseif kind=="bodyimpact" then
  dust(b,c,Color3.fromRGB(100,10,9),false)
 elseif kind=="flareflight" then
  local id,origin,velocity,gravity,start,shooter=a,b,c,d,e,f
  if typeof(origin)~="Vector3" or typeof(velocity)~="Vector3" then return end
  -- drawn from the gun's muzzle, easing onto the real path over the first moment
  local muzzle=muzzleOf(shooter) or origin
  local fl={fx=makeFlare(muzzle),origin=origin,velocity=velocity,gravity=gravity or Vector3.zero,start=start,
   muzzle=muzzle,blendUntil=.12,lastSpark=0,lastSmoke=0,prev=muzzle}
  flights[id]=fl
  -- the thump and the whoosh of it leaving the barrel
  local head=typeof(shooter)=="Instance" and shooter:FindFirstChild("Head")
  if head then
   -- not a bang: the hammer snaps, the charge coughs and the flare rushes out hissing
   Audio.Play("Click",head,.5,.7,40)
   Audio.Play("FlareLaunch",head,.8,1,200)
   Audio.Play("FlareHiss",head,.45,.9,120,false,"FlareHiss")
  end
 elseif kind=="flarebounce" then
  local fl=flights[a]
  if not fl then return end
  fl.origin,fl.velocity,fl.gravity,fl.start=b,c,d,e
  fl.blendUntil=0
  VFX.Sparks(b,(c.Magnitude>0 and c.Unit or Vector3.yAxis),Color3.fromRGB(255,170,120),8)
  local p=anchor(b) Audio.Play("MetalHit",p,.25,1.6,60) Debris:AddItem(p,1)
 elseif kind=="flarestop" then
  local fl=flights[a]
  flights[a]=nil
  if fl then endFlight(fl) end
  local pos,normal,part=b,c,d
  if typeof(pos)~="Vector3" then return end
  VFX.Sparks(pos,typeof(normal)=="Vector3" and normal or Vector3.yAxis,Color3.fromRGB(255,170,120),10)
  if typeof(part)=="Instance" then stuckFlare(part,pos,normal) end
 end
end)

RunService.RenderStepped:Connect(function()
 local now=workspace:GetServerTimeNow()
 for id,fl in pairs(flights) do
  local t=now-fl.start
  if t>7 or not fl.fx.core.Parent then endFlight(fl) flights[id]=nil
  else
   local pos=fl.origin+fl.velocity*math.max(t,0)+fl.gravity*(.5*t*t)
   if t<fl.blendUntil then pos=fl.muzzle:Lerp(pos,math.clamp(t/fl.blendUntil,0,1)) end
   local vel=pos-fl.prev
   fl.prev=pos
   local cf=vel.Magnitude>1e-3 and CFrame.lookAt(pos,pos+vel) or CFrame.new(pos)
   fl.fx.core.CFrame=cf fl.fx.heart.CFrame=cf
   fl.fx.light.Brightness=3+math.noise(now*20,3)*.8
   if now-fl.lastSpark>.05 then fl.lastSpark=now VFX.Sparks(pos,-vel.Unit,Color3.fromRGB(255,170,120),low() and 1 or 2) end
   if now-fl.lastSmoke>.06 then fl.lastSmoke=now VFX.Smoke(pos,Vector3.yAxis,.4,SMOKE) end
  end
 end
end)

-- ===== flares burning on the floor (the server's GS_FlareBurn parts) =====
local burning={}
local function watchBurn(part)
 if not part:IsA("BasePart") or part.Name~="GS_FlareBurn" or burning[part] then return end
 local light=part:FindFirstChildOfClass("PointLight")
 burning[part]={light=light,hiss=Audio.Play("Sizzle",part,.4,1.2,80,true),lastSpark=0,lastSmoke=0,base=light and light.Brightness or 3}
end
workspace.DescendantAdded:Connect(function(d) if d.Name=="GS_FlareBurn" then task.defer(watchBurn,d) end end)
for _,d in ipairs(workspace:GetDescendants()) do if d.Name=="GS_FlareBurn" then watchBurn(d) end end
RunService.Heartbeat:Connect(function()
 local now=os.clock()
 local camera=workspace.CurrentCamera
 for part,st in pairs(burning) do
  if not part.Parent then
   if st.hiss then st.hiss:Destroy() end
   burning[part]=nil
  else
   local left=(part:GetAttribute("GS_BurnUntil") or 0)-workspace:GetServerTimeNow()
   local strength=math.clamp(left/2.5,0,1) -- dies out over the last seconds
   if st.light then st.light.Brightness=st.base*(0.7+0.3*math.noise(now*11,part.Position.X))*strength end
   local near=camera and (camera.CFrame.Position-part.Position).Magnitude<150
   if near and strength>0 then
    if now-st.lastSpark>(low() and .2 or .08) then
     st.lastSpark=now
     VFX.Sparks(part.Position+Vector3.new(0,.15,0),Vector3.yAxis,Color3.fromRGB(255,176,128),2)
    end
    if now-st.lastSmoke>(low() and .35 or .16) then
     st.lastSmoke=now
     VFX.Smoke(part.Position+Vector3.new(0,.2,0),Vector3.yAxis,.9,SMOKE)
    end
   end
   if st.hiss then st.hiss.Volume=.4*strength end
  end
 end
end)
