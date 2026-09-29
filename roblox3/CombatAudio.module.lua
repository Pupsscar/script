-- Combat sounds through the AudioBus: every body gets a few separate channels, so sounds of the same kind replace
-- each other (no pile-ups) but different kinds never cut each other off:
--   Shot    the bang itself            ShotTail  its echo in the cave (a moment later, lower, softer)
--   Action  racks, clicks, shells in   Shell     spent shells hitting the floor (three at a time)
--   Weapon  swings and whooshes        Foley     cloth, plates, flesh...
-- Far away shots are muffled (high end cut), close ones are full.
local ItemData=require(script.Parent:WaitForChild("ItemData"))
local Bus=require(script.Parent:WaitForChild("AudioBus"))
local GameSettings=require(script.Parent:WaitForChild("GameSettings"))
local Audio={}
local last={}
local shellSlot=0
local duration={Shotgun=1.6,Flare=1.2,Rack=.6,Click=.3,ShellIn=.4,ShellDrop=.6,Swing=.45,Cloth=.7,Plate=.45,MetalHit=.6,BloodHit=.4,Flesh=.45,Bone=.55,Rattle=.9,Spray=.9,ShockWhoosh=.6,Shock=.8}
local CHANNEL={Shotgun="Shot",Flare="Shot",Rack="Action",Click="Action",ShellIn="Action",Swing="Weapon",ShockWhoosh="Weapon",Shock="Weapon"}
local PRIORITY={Shot=60,ShotTail=40,Action=50,Weapon=45}

local function make(name,id,parent,volume,speed,range,looped)
 local s=Instance.new("Sound") s.Name="GS_Audio_"..name s.SoundId=id s.Volume=math.clamp(volume or .5,0,1)
 s.PlaybackSpeed=speed or 1 s.RollOffMinDistance=7 s.RollOffMaxDistance=range or 100
 s.RollOffMode=Enum.RollOffMode.InverseTapered s.Looped=looped==true
 pcall(function() s.SoundGroup=GameSettings.GetGroup("SFX") end)
 s.Parent=parent
 return s
end

local function distanceTo(parent)
 local camera=workspace.CurrentCamera
 if not camera then return 0 end
 local p=parent:IsA("BasePart") and parent.Position or parent:IsA("Attachment") and parent.WorldPosition
 if not p then return 0 end
 return (p-camera.CFrame.Position).Magnitude
end

-- channel: optional override
function Audio.Play(name,parent,volume,speed,range,looped,channel)
 if not parent or not parent.Parent then return end
 local id=ItemData.Sound(name) if not id then return end
 local now=os.clock()
 if parent:IsA("BasePart") then
  local p=parent.Position local key=name..math.floor(p.X/8)..","..math.floor(p.Y/8)..","..math.floor(p.Z/8)
  if now-(last[key] or 0)<.06 then return end
  last[key]=now
 end
 local s=make(name,id,parent,volume,speed,range,looped)
 channel=channel or (looped and "Loop") or CHANNEL[name]
 if not channel and name=="ShellDrop" then shellSlot=(shellSlot+1)%3 channel="Shell"..shellSlot end
 channel=channel or "Foley"
 local playing=Bus.Play(s,parent,channel,PRIORITY[channel] or 30,.05,looped and math.huge or duration[name] or 1.2,looped)
 if math.random()<.02 then for key,t in pairs(last) do if now-t>10 then last[key]=nil end end end
 return playing
end

-- a gunshot: the bang (muffled with distance) and a late, low echo off the cave walls
function Audio.Shot(name,parent,volume,speed,range)
 local s=Audio.Play(name,parent,volume,speed,range,false,"Shot")
 if not s then return end
 local d=distanceTo(parent)
 if d>45 then
  local eq=Instance.new("EqualizerSoundEffect")
  eq.HighGain=-math.clamp((d-45)/6,0,26) eq.MidGain=-math.clamp((d-45)/14,0,10) eq.LowGain=2
  eq.Parent=s
 end
 local id=ItemData.Sound(name)
 task.delay(.09+math.min(d,200)/1500,function()
  if not parent.Parent or not id then return end
  local tail=make(name.."Tail",id,parent,(volume or .8)*.28,(speed or 1)*.62,(range or 300)*1.2,false)
  local eq=Instance.new("EqualizerSoundEffect") eq.HighGain=-22 eq.MidGain=-6 eq.LowGain=3 eq.Parent=tail
  Bus.Play(tail,parent,"ShotTail",PRIORITY.ShotTail,.05,1.8,false)
 end)
 return s
end

return Audio
