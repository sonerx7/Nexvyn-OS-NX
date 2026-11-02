local World=require("game.world")
local Render=require("game.render")
local app={}
local mode="loading"
local world,preview,progress,options
local keys,pending={},{}
local selected,chapter=1,1
local clock,accum=0,0
local viewport={w=1280,h=720}
local toast={text="",time=0}
local radio={text="",time=0}
local audioChannel,lastMouse=nil,nil
local returnMode="title"
local touch={visible=false,drag=nil,dx=0,dz=0,linger=0,fire=false}
local errorText=nil
local archivePage=1
local S,OX,OY=1,0,0
local min,max,sin,cos,floor=math.min,math.max,math.sin,math.cos,math.floor
local function clamp(v,a,b)return max(a,min(b,v))end
local function chapterName(n)return TR("chapter."..n)end
local function message(key,seconds)toast.text=TR(key);toast.time=seconds or 3 end
local function save()
 if world and world.status=="play" and mode~="title" and mode~="select" and mode~="briefing" then progress.resume=world:snapshot() end
 store.set("ash.progress.v1",progress);store.set("ash.options.v1",options)
end
local function music(n)
 if audioChannel then audio.stop(audioChannel);audioChannel=nil end
 if options.music then audioChannel=audio.play("bundle:/audio/chapter"..n..".wav",options.volume*.35,-1) end
end
local function modeTo(m)
 mode=m;selected=1;keys={};pending={};touch.drag=nil;touch.fire=false;touch.linger=0;lastMouse=nil;accum=0
end
local function start(n,resume)
 chapter=n;world=World.new(n,resume);Render.prepare(world)
 modeTo("play");music(n);save();radio.text=TR("radio."..n..".1");radio.time=7
end
local function title()
 if not preview or preview.map.chapter~=1 then preview=World.new(1);preview.player.z=3;preview.player.yaw=.13;preview.player.pitch=.02 end
 Render.prepare(preview);modeTo("title");music(1)
end
local function briefing(n)chapter=n;preview=World.new(n);Render.prepare(preview);modeTo("briefing")end
local function pause()if mode=="play" then save();modeTo("pause")end end
local function back()
 if mode=="play" then pause()
 elseif mode=="pause" or mode=="map" then modeTo("play")
 elseif mode=="codex" then modeTo("pause")
 elseif mode=="settings" or mode=="help" then modeTo(returnMode)
 elseif mode~="loading" and mode~="title" then title() end
end
local function cycle(delta)
 if not world then return end
 for i=1,4 do local n=(world.weapon-1+delta*i)%4+1;if world.unlocked[n] then world:select(n);break end end
end
local function activate(index)
 if mode=="title" then
  if index==1 then if progress.resume then start(progress.resume.chapter,progress.resume) else briefing(progress.unlocked) end
  elseif index==2 then briefing(1)
  elseif index==3 then modeTo("select")
  elseif index==4 then returnMode="title";modeTo("settings")
  elseif index==5 then returnMode="title";modeTo("help")
  else sys.exit() end
 elseif mode=="briefing" then start(chapter)
 elseif mode=="select" then if index<=progress.unlocked then briefing(index) else message("chapter.locked") end
 elseif mode=="pause" then
  if index==1 then modeTo("play")
  elseif index==2 then start(chapter,progress.resume)
  elseif index==3 then modeTo("map")
  elseif index==4 then returnMode="pause";modeTo("settings")
  elseif index==5 then returnMode="pause";modeTo("help")
  elseif index==6 then archivePage=1;modeTo("codex")
  else save();title() end
 elseif mode=="dead" then if index==1 then start(chapter,progress.resume) else title() end
 elseif mode=="complete" then if index==1 then briefing(min(6,chapter+1)) else title() end
 elseif mode=="choice" then progress.ending=index;modeTo("epilogue");save()
 elseif mode=="epilogue" then title()
 elseif mode=="map" or mode=="help" then back()
 elseif mode=="codex" then
  local pages=0;for _ in pairs(progress.archive) do pages=pages+1 end
  if index==1 then archivePage=(archivePage-2)%max(1,pages)+1 elseif index==2 then archivePage=archivePage%max(1,pages)+1 else modeTo("pause") end
 elseif mode=="settings" then
  if index==1 then options.quality=options.quality==2 and 1 or 2;Render.quality=options.quality
  elseif index==2 then options.music=not options.music;music(chapter)
  elseif index==3 then options.sensitivity=options.sensitivity>=.004 and .0018 or options.sensitivity+.0006
  elseif index==4 then options.volume=options.volume>=.99 and .25 or min(1,options.volume+.25);music(chapter)
  else modeTo(returnMode) end
  save()
 end
end
local function count()
 if mode=="pause" then return 7 elseif mode=="codex" then return 3 elseif mode=="title" or mode=="select" then return 6 elseif mode=="settings" then return 5 elseif mode=="dead" or mode=="complete" or mode=="choice" then return 2 else return 1 end
end
function app.load()
 progress=store.get("ash.progress.v1",{});if type(progress)~="table" then progress={} end
 progress.unlocked=clamp(tonumber(progress.unlocked) or 1,1,6);progress.records=progress.records or {};progress.archive=progress.archive or {}
 options=store.get("ash.options.v1",{});if type(options)~="table" then options={} end
 options.music=options.music~=false;options.volume=clamp(tonumber(options.volume) or .75,0,1);options.sensitivity=tonumber(options.sensitivity) or .0024;options.quality=options.quality==1 and 1 or 2;Render.quality=options.quality
 local ok,err=pcall(Render.init);if not ok then errorText=tostring(err) end
end
local function events()
 for _,e in ipairs(world.events) do
  if e.kind=="shot" then
   audio.tone(e.value==2 and 70 or (e.value==4 and 210 or 115),e.value==2 and .12 or .055,options.volume*.23,e.value==4 and "triangle" or "noise")
  elseif e.kind=="hurt" then audio.tone(90,.09,options.volume*.18,"saw")
  elseif e.kind=="hit" then audio.tone(480,.025,options.volume*.09,"triangle")
  elseif e.kind=="pickup" then message("pickup."..e.value);audio.tone(740,.06,options.volume*.12,"sine");save()
  elseif e.kind=="relay" then message("relay.activated");save()
  elseif e.kind=="checkpoint" then message("checkpoint.saved");save()
  elseif e.kind=="door" then message("door.open");save()
  elseif e.kind=="gateLocked" then message("gate.locked")
  elseif e.kind=="exitLocked" then message("exit.locked")
  elseif e.kind=="lockedWeapon" then message("weapon.locked")
  elseif e.kind=="empty" then message("weapon.empty",1.5)
  elseif e.kind=="parry" then message("combat.parry",1.5)
  elseif e.kind=="bossDead" then radio.text=TR("radio.bossDead");radio.time=6
  elseif e.kind=="room" then radio.text=TR("radio."..chapter.."."..e.value);radio.time=6;save()
  elseif e.kind=="log" then
   progress.archive[chapter..":"..e.value]=true;radio.text=TR("log."..chapter.."."..e.value);radio.time=9;save()
  elseif e.kind=="complete" then
   progress.unlocked=max(progress.unlocked,min(6,chapter+1));progress.records[tostring(chapter)]={kills=world.kills,time=world.elapsed,score=world.score};progress.resume=nil
   modeTo(chapter==6 and "choice" or "complete");save()
  elseif e.kind=="dead" then modeTo("dead") end
 end
 world.events={}
end
function app.update(dt)
 dt=clamp(tonumber(dt) or 0,0,.1);clock=clock+dt;toast.time=max(0,toast.time-dt);radio.time=max(0,radio.time-dt)
 if mode=="loading" then
  if not errorText then local ok,done=pcall(Render.loadNext);if not ok then errorText=tostring(done) elseif done then title() end end
  return
 end
 if mode=="title" or mode=="select" then preview.time=preview.time+dt;return end
 if mode~="play" then return end
 local p=world.player
 local rx,ry=input.stick("right");rx,ry=rx or 0,ry or 0
 p.yaw=p.yaw+((keys.right and 1 or 0)-(keys.left and 1 or 0)+rx*1.6)*2.0*dt
 p.pitch=clamp(p.pitch+((keys.up and 1 or 0)-(keys.down and 1 or 0)+ry*1.4)*1.6*dt,-1.25,1.25)
 local lx,ly=input.stick("left");lx,ly=lx or 0,ly or 0;if math.abs(lx)<.15 then lx=0 end;if math.abs(ly)<.15 then ly=0 end
 local c={strafe=lx+(keys.d and 1 or 0)-(keys.a and 1 or 0),forward=ly+(keys.w and 1 or 0)-(keys.s and 1 or 0),run=input.down("lstick"),fire=keys.fire or input.down("zr") or touch.fire}
 touch.linger=max(0,touch.linger-dt)
 if touch.drag=="move" or touch.linger>0 then c.strafe=touch.dx;c.forward=touch.dz end
 accum=accum+dt;local used=false
 while accum>=1/120 do
  c.jump=not used and pending.jump;c.dash=not used and pending.dash;c.use=not used and pending.use;c.melee=not used and pending.melee
  if not used then pending={};used=true end
  world:step(1/120,c);accum=accum-1/120
  if world.status~="play" then break end
 end
 events()
end
function app.event(e)
 if e.type=="keydown" then
  local repeatKey=keys[e.key];keys[e.key]=true;if repeatKey then return end
  if e.key=="escape" or e.key=="p" then back()
  elseif mode=="play" then
   if e.key=="space" then pending.jump=true
   elseif e.key=="shift" or e.key=="lshift" or e.key=="z" then pending.dash=true
   elseif e.key=="e" then pending.use=true
   elseif e.key=="c" then pending.melee=true
   elseif e.key=="f" then world.flashlight=not world.flashlight;message(world.flashlight and "flashlight.on" or "flashlight.off",1.5)
   elseif e.key=="q" then cycle(-1)
   elseif e.key=="tab" then save();modeTo("map")
   elseif e.key=="k" then save();archivePage=1;modeTo("codex")
   elseif e.key=="f1" then save();returnMode="pause";modeTo("help")
   elseif tonumber(e.key) and tonumber(e.key)>=1 and tonumber(e.key)<=4 then world:select(tonumber(e.key)) end
  else
   if e.key=="up" or e.key=="w" then selected=(selected-2)%count()+1
   elseif e.key=="down" or e.key=="s" then selected=selected%count()+1
   elseif e.key=="enter" or e.key=="space" then activate(selected) end
  end
 elseif e.type=="keyup" then keys[e.key]=nil
 elseif e.type=="paddown" then
  if e.pad=="plus" then back()
  elseif mode=="play" then
   if e.pad=="a" then pending.jump=true elseif e.pad=="b" then pending.dash=true elseif e.pad=="x" then pending.use=true elseif e.pad=="zl" then pending.melee=true elseif e.pad=="y" or e.pad=="r" then cycle(1) elseif e.pad=="l" then cycle(-1) elseif e.pad=="rstick" then world.flashlight=not world.flashlight elseif e.pad=="minus" then save();modeTo("map") end
  else
   if e.pad=="a" then activate(selected) elseif e.pad=="b" then back() elseif e.pad=="up" then selected=(selected-2)%count()+1 elseif e.pad=="down" then selected=selected%count()+1 end
  end
 elseif e.type=="mousedown" and mode=="play" then
  if e.touch then
   touch.visible=true;touch.x=e.x;touch.y=e.y;touch.drag=e.x<viewport.w*.45 and "move" or "aim";touch.fire=touch.drag=="aim"
  elseif e.button=="left" then keys.fire=true elseif e.button=="right" then keys.look=true;lastMouse={x=e.x,y=e.y} end
 elseif e.type=="mousemove" and mode=="play" then
  if e.touch and touch.drag then
   if touch.drag=="move" then touch.dx=clamp((e.x-touch.x)/65,-1,1);touch.dz=clamp((touch.y-e.y)/65,-1,1)
   else world.player.yaw=world.player.yaw+(e.x-touch.x)*options.sensitivity;world.player.pitch=clamp(world.player.pitch-(e.y-touch.y)*options.sensitivity,-1.25,1.25);touch.x=e.x;touch.y=e.y end
  elseif keys.look then
   if lastMouse then world.player.yaw=world.player.yaw+(e.x-lastMouse.x)*options.sensitivity;world.player.pitch=clamp(world.player.pitch-(e.y-lastMouse.y)*options.sensitivity,-1.25,1.25) end
   lastMouse={x=e.x,y=e.y}
  end
 elseif e.type=="mouseup" then
  if e.touch then if touch.drag=="move" then touch.linger=.6 end;touch.drag=nil;touch.fire=false
  elseif e.button=="left" then keys.fire=false elseif e.button=="right" then keys.look=false;lastMouse=nil end
 elseif e.type=="scroll" and mode=="play" then cycle(e.dy>0 and 1 or -1) end
end

local function rect(x,y,w,h,color,r)gfx.rect(OX+x*S,OY+y*S,w*S,h*S,(r or 0)*S,color)end
local function text(s,x,y,size,color,font,align,width)
 gfx.color(color or "#DBE2DF");gfx.text(s,OX+x*S,OY+y*S,max(11,size*S),font or "sans",align or "left",width and width*S)
end
local function wrap(s,x,y,w,size,color,font)
 gfx.color(color or "#C6CFCC");return gfx.wrap(s,OX+x*S,OY+y*S,w*S,max(12,size*S),font or "sans")/S
end
local function button(key,index,x,y,w,h)
 local hit=ui.hit("ash."..mode.."."..index,OX+x*S,OY+y*S,w*S,h*S)
 local active=selected==index or hit.hovered
 rect(x,y,w,h,active and "#CC96652B" or "#0A1521AA",6)
 if active then rect(x,y,3,h,"#E8AD73") end
 text(TR(key),x+20,y+(h-20)/2,19,active and "#EFC393" or "#C0CECF","semibold")
 if hit.clicked then activate(index) end
end
local function panel(x,y,w,h)rect(x,y,w,h,"#101E2BEF",10);rect(x+26,y+22,42,3,"#C58F64")end
local function shade()rect(-OX/S,-OY/S,viewport.w/S,viewport.h/S,"#07101AA8")end
local function timeText(t)return string.format("%02d:%02d",floor(t/60),floor(t%60))end
local function hud()
 local p=world.player;local weapon=World.weapons[world.weapon]
 rect(24,23,520,83,"#101C29DF",8)
 text(TR("chapter.label",chapter),44,34,12,"#B79775","bold")
 text(chapterName(chapter),44,56,22,"#E3D8C7","semibold")
 text(TR("objective.progress",world.relayCount,TR(world.hasKey and "yes" or "no")),44,112,14,"#BBD1CD","medium")
 rect(28,618,341,78,"#101C29DF",8)
 text(TR("hud.health"),46,630,12,"#9DB1B8","bold");text(tostring(floor(p.hp)),46,651,32,"#E4D4C0","bold")
 text(TR("hud.armor"),162,630,12,"#9DB1B8","bold");text(tostring(floor(p.armor)),162,651,32,"#83C4C4","bold")
 rect(40,706,315,4,"#243843",2);rect(40,706,315*p.hp/100,4,"#D9AD7E",2)
 rect(925,618,327,78,"#101C29DF",8)
 text(TR("weapon."..world.weapon),946,630,13,"#A5BCBD","bold")
 text(weapon.ammo==0 and TR("ammo.infinite") or tostring(world.ammo[weapon.ammo]),946,653,33,"#E2C8A4","bold")
 text(TR("hud.kills",world.kills),1120,664,13,"#A2B7B8")
 local gap=world.weapon==2 and 13 or 7
 gfx.color(world.muzzle>0 and "#F2CE9E" or "#C9D8D1")
 gfx.line(OX+(640-gap-7)*S,OY+360*S,OX+(640-gap)*S,OY+360*S,1.3*S)
 gfx.line(OX+(640+gap)*S,OY+360*S,OX+(640+gap+7)*S,OY+360*S,1.3*S)
 gfx.line(OX+640*S,OY+(360-gap-7)*S,OX+640*S,OY+(360-gap)*S,1.3*S)
 gfx.line(OX+640*S,OY+(360+gap)*S,OX+640*S,OY+(360+gap+7)*S,1.3*S)
 if p.dashCD>0 then rect(596,395,88*(1-p.dashCD/.85),2,"#88BDBA",1) end
 if radio.time>0 then
  rect(25,486,530,110,"#101E2BEA",8);text(TR("radio.sender"),45,499,11,"#B68F6E","bold")
  wrap(radio.text,45,523,490,14,"#C6D3D0")
 end
 if toast.time>0 then text(toast.text,230,592,15,"#E1B58A","medium","center",820) end
 local near=false
 for _,r in ipairs(world.map.relays) do if not r.active and (r.x-p.x)^2+(r.z-p.z)^2<8 then near=true end end
 for _,r in ipairs(world.map.terminals) do if (r.x-p.x)^2+(r.z-p.z)^2<8 then near=true end end
 if near then text(TR("hud.interact"),380,420,16,"#D8D1B9","semibold","center",520) end
 for _,e in ipairs(world.map.enemies) do if e.boss and e.alive and e.active then
  rect(720,30,530,58,"#101C29DF",7);text(TR("boss.name"),741,39,14,"#D9B794","bold");rect(740,68,490,5,"#3A3541",1);rect(740,68,490*e.hp/e.maxHp,5,"#BA806D",1)
 end end
 if world.hurt>0 then rect(-OX/S,-OY/S,viewport.w/S,viewport.h/S,"#B4443828") end
 if touch.visible then
  local y=586
  for i,key in ipairs({"touch.use","touch.jump","touch.dash"}) do
   local x=465+(i-1)*116;local hit=ui.hit("touch."..i,OX+x*S,OY+y*S,106*S,52*S)
   rect(x,y,106,52,"#172938C9",8);text(TR(key),x,y+17,13,"#D9C3A4","medium","center",106)
   if hit.pressed then if i==1 then pending.use=true elseif i==2 then pending.jump=true else pending.dash=true end end
  end
 end
end
local function titleUI()
 gfx.gradient(0,0,viewport.w*.75,viewport.h,"#0A1522F2","#0A152200",true)
 text(TR("title.kicker"),70,65,14,"#BCA083","bold")
 text(TR("title.name"),64,119,62,"#E6DAC6","bold")
 text(TR("title.subtitle"),70,206,23,"#7FB5B8","medium")
 rect(72,257,56,3,"#CB976C")
 local list={"menu.continue","menu.new","menu.chapters","menu.settings","menu.controls","menu.exit"}
 for i,k in ipairs(list) do button(k,i,65,297+(i-1)*57,382,50) end
 text(TR("title.footer",progress.unlocked),73,675,13,"#8CA5AD")
 if not g3d.gpu() then text(TR("gpu.required"),565,663,13,"#D4B897","medium","center",650) end
end
local function menuUI(titleKey,items)
 shade();panel(391,80,498,570);text(TR(titleKey),425,129,33,"#E7D7BF","bold")
 for i,k in ipairs(items) do button(k,i,417,195+(i-1)*60,446,54) end
end
local function codexUI()
 shade();panel(224,71,832,584);text(TR("menu.archive"),263,117,32,"#E1D0B6","bold")
 local pages={};for key in pairs(progress.archive) do pages[#pages+1]=key end;table.sort(pages)
 local key=pages[archivePage]
 if key then
  local ch,id=key:match("(%d+):(%d+)")
  text(chapterName(tonumber(ch)),264,185,24,"#85B3B7","semibold")
  wrap(TR("log."..ch.."."..id),264,246,752,22,"#C8D3CD")
 else wrap(TR("archive.empty"),264,228,752,21,"#B8CBC8") end
 button("archive.previous",1,255,527,230,58);button("archive.next",2,499,527,230,58);button("back",3,743,527,282,58)
end
local function briefingUI()
 shade();panel(224,71,832,584)
 text(TR("chapter.label",chapter),263,116,14,"#B79572","bold")
 text(chapterName(chapter),260,155,37,"#E5D6C0","bold")
 wrap(TR("brief."..chapter),264,225,750,21,"#C5D1CF")
 text(TR("brief.mission"),264,440,13,"#81B9BC","bold")
 wrap(TR("objective.long"),264,474,746,17,"#B2C3C2")
 button("menu.deploy",1,254,567,772,58)
end
local function selectUI()
 shade();panel(88,53,1104,614);text(TR("menu.chapters"),128,104,34,"#E1D4BF","bold")
 for n=1,6 do
  local x,y=125+(n-1)%3*350,178+floor((n-1)/3)*219
  local h=ui.hit("chapter."..n,OX+x*S,OY+y*S,328*S,196*S)
  rect(x,y,328,196,selected==n and "#405C66" or "#223543",8)
  text(string.format("%02d",n),x+20,y+16,32,"#9CB4B7","bold")
  text(chapterName(n),x+20,y+72,21,"#DEC8A8","semibold")
  wrap(TR("tagline."..n),x+20,y+112,288,14,"#B2C3C1")
  if n>progress.unlocked then text(TR("chapter.locked"),x+20,y+164,12,"#997C6B") end
  if h.clicked then selected=n;activate(n);return end
 end
end
local function mapUI()
 shade();panel(125,52,1030,615);text(TR("map.title"),162,98,30,"#E0D4BF","bold")
 local minX,maxX,minZ,maxZ=1e9,-1e9,1e9,-1e9
 for _,r in ipairs(world.map.rooms) do minX=min(minX,r.x-r.w/2);maxX=max(maxX,r.x+r.w/2);minZ=min(minZ,r.z-r.d/2);maxZ=max(maxZ,r.z+r.d/2) end
 local scale=min(560/(maxX-minX),420/(maxZ-minZ))
 local function xy(x,z)return 230+(x-minX)*scale,170+(z-minZ)*scale end
 for _,r in ipairs(world.map.rooms) do
  local x,z=xy(r.x,r.z);rect(x-r.w*scale/2,z-r.d*scale/2,r.w*scale,r.d*scale,world.visited[tostring(r.id)] and "#577D84" or "#2B424E",4)
  text(tostring(r.id),x-9,z-9,16,"#DDC9AB","bold")
 end
 local p=world.player;local x,z=xy(p.x,p.z);gfx.color("#E3BE86");gfx.circle(OX+x*S,OY+z*S,5*S)
 wrap(TR("objective.long"),828,187,277,19,"#B6CFCA")
 local logs=0;for _ in pairs(progress.archive) do logs=logs+1 end
 text(TR("map.logs",logs),829,376,16,"#B69A7D","medium")
 button("back",1,159,585,962,56)
end
local function helpUI()
 shade();panel(184,48,912,622);text(TR("controls.title"),224,98,32,"#E3D4BC","bold")
 wrap(TR("controls.keyboard"),225,169,812,18,"#BBCFCC")
 wrap(TR("controls.pad"),225,292,812,18,"#BBCFCC")
 wrap(TR("controls.touch"),225,417,812,16,"#A9C2C1")
 wrap(TR("controls.flow"),225,524,812,16,"#D4B187","semibold")
 button("back",1,219,584,842,56)
end
local function settingsUI()
 shade();panel(343,86,594,552);text(TR("menu.settings"),380,132,33,"#E3D3BA","bold")
 local list={TR("settings.detail",TR(options.quality==2 and "high" or "balanced")),TR("settings.music",TR(options.music and "on" or "off")),TR("settings.aim",string.format("%.1f",options.sensitivity*1000)),TR("settings.volume",floor(options.volume*100)),TR("back")}
 for i,label in ipairs(list) do
  local x,y=369,220+(i-1)*73;local hit=ui.hit("setting."..i,OX+x*S,OY+y*S,542*S,60*S)
  rect(x,y,542,60,selected==i and "#A97D572B" or "#152A37",7);text(label,x+18,y+20,18,"#CCCEC1","medium")
  if hit.clicked then activate(i) end
 end
end
local function resultsUI()
 shade();panel(295,90,690,542);text(TR("complete.title"),334,135,34,"#E5D4B9","bold")
 text(chapterName(chapter),335,193,23,"#91BBBC","semibold")
 text(TR("complete.stats",world.kills,timeText(world.elapsed),world.score),335,278,20,"#C7D2CA")
 wrap(TR("debrief."..chapter),335,337,609,19,"#A9C1BD")
 button("menu.next",1,324,465,632,58);button("menu.title",2,324,539,632,58)
end
local function endingUI()
 shade();panel(246,74,788,574)
 text(TR("ending.title"),284,120,35,"#E6D5BA","bold")
 if mode=="choice" then
  wrap(TR("ending.choice"),284,206,710,22,"#C7D4CE")
  button("ending.shutdown",1,275,455,730,62);button("ending.command",2,275,532,730,62)
 else
  wrap(TR(progress.ending==1 and "ending.shutdown.text" or "ending.command.text"),284,210,710,22,"#BCD0CA")
  button("menu.title",1,275,547,730,62)
 end
end
function app.draw(w,h)
 viewport.w,viewport.h=w,h;S=min(w/1280,h/720);OX=(w-1280*S)/2;OY=(h-720*S)/2
 if mode=="loading" then
  gfx.clear("#0C1925");text(TR("title.name"),0,230,55,"#DCCBB2","bold","center",1280)
  text(TR(errorText and "loading.error" or "loading.assets",Render.loaded,#Render.catalog),0,337,16,"#95B7B9","medium","center",1280)
  rect(420,393,440,3,"#263E4A");if #Render.catalog>0 then rect(420,393,440*Render.loaded/#Render.catalog,3,"#C6986D") end
  if errorText then text(errorText:sub(1,120),140,430,12,"#D5A28D","mono","center",1000) end
  return
 end
 local isPreview=mode=="title" or mode=="select" or mode=="briefing" or ((mode=="settings" or mode=="help") and returnMode=="title")
 Render.scene(isPreview and preview or world,w,h,isPreview)
 if mode=="play" then hud()
 elseif mode=="title" then titleUI()
 elseif mode=="briefing" then briefingUI()
 elseif mode=="select" then selectUI()
 elseif mode=="pause" then menuUI("pause.title",{"menu.resume","menu.checkpoint","map.title","menu.settings","menu.controls","menu.archive","menu.title"})
 elseif mode=="dead" then menuUI("dead.title",{"menu.checkpoint","menu.title"})
 elseif mode=="map" then mapUI()
 elseif mode=="help" then helpUI()
 elseif mode=="settings" then settingsUI()
 elseif mode=="codex" then codexUI()
 elseif mode=="complete" then resultsUI()
 elseif mode=="choice" or mode=="epilogue" then endingUI() end
end
function app.menu()return {{title=TR("title.name"),items={{label=TR("menu.resume"),id=1},{label=TR("menu.controls"),id=2},{label=TR("menu.title"),id=3}}}}end
function app.onmenu(id)
 if id==1 then back()
 elseif id==2 and mode~="loading" then if mode=="play" then save() end;returnMode=world and "pause" or "title";modeTo("help")
 elseif id==3 and mode~="loading" then save();title() end
end
function app.focus(focused)if not focused then keys={};if mode=="play" then pause() end end end
function app.suspend()pause();save();if audioChannel then audio.stop(audioChannel);audioChannel=nil end end
function app.resume()if mode~="loading" then music(chapter) end end
function app.autosave()save()end
function app.close()save();if audioChannel then audio.stop(audioChannel) end;return true end
return app
