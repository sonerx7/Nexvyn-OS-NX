local Levels=require("game.levels")
local World=require("game.world")
local Render=require("game.render")
local app={}
local sin,cos,min,max,floor=math.sin,math.cos,math.min,math.max,math.floor
local mode="loading"
local selected=1
local world,preview,progress,options,musicChannel
local keys,pending={},{}
local cam={x=0,y=1,z=0,yaw=0,pitch=.47,distance=10.7}
local accumulator=0
local clock=0
local viewport={w=1280,h=720}
local toast={text="",timer=0}
local touch={visible=false,drag=false,x=0,y=0,dx=0,dy=0,linger=0,jumpHeld=false}
local settingsReturn="title"
local loadingError=nil
local musicLevel=0
local resetCamera=true

local function clamp(v,a,b) return max(a,min(b,v)) end
local function trLevel(n) return TR("level."..n) end
local function countStars()
  local n=0
  for _,r in pairs(progress.records) do n=n+(tonumber(r.stars) or 0) end
  return n
end
local function save()
  if world and (mode=="play" or mode=="pause" or mode=="settings" or mode=="help") and world.status=="play" then progress.resume=world:snapshot() end
  store.set("progress.v1",progress);store.set("options.v1",options)
end
local function music(n)
  if musicChannel then audio.stop(musicChannel);musicChannel=nil end
  musicLevel=n
  if options.music and options.volume>0 then musicChannel=audio.play("bundle:/audio/world"..n..".wav",options.volume*.38,-1) end
end
local function sound(kind)
  if not options.sound then return end
  local notes={coin={1046,.07,"sine"},star={1568,.3,"triangle"},jump={520,.07,"sine"},doubleJump={784,.10,"triangle"},dash={220,.09,"triangle"},stomp={185,.1,"triangle"},hurt={130,.18,"saw"},checkpoint={880,.25,"sine"},spring={660,.16,"triangle"},["break"]={293,.1,"triangle"},complete={1174,.5,"sine"},bossHit={392,.2,"triangle"},bossDefeat={1568,.5,"sine"},slam={72,.18,"triangle"},extraLife={1318,.3,"sine"}}
  local n=notes[kind]
  if n then audio.tone(n[1],n[2],options.volume*.21,n[3]) end
end
local function notice(key,seconds) toast.text=TR(key);toast.timer=seconds or 3 end
local function setMode(m)
  mode=m;selected=1;keys={};pending={};touch.drag=false;touch.dx=0;touch.dy=0;touch.linger=0;touch.jumpHeld=false;accumulator=0
end

local function startLevel(n,restore)
  world=World.new(Levels.build(n),restore)
  world:step(1/120,{jumpHeld=true})
  world.events={}
  Render.prepare(world)
  cam.x,cam.y,cam.z=world.player.x,world.player.y+1,world.player.z
  cam.yaw,cam.pitch,cam.distance=0,.47,10.7
  resetCamera=true
  setMode("play");music(n);save();notice("hint."..n,6)
end
local function title()
  if not preview then
    preview=World.new(Levels.build(1));preview:step(1/120,{jumpHeld=true});preview.events={}
    preview.player.x=-.6;preview.player.z=0;preview.player.y=0;preview.player.facing=.38
  end
  Render.prepare(preview);setMode("title");music(1)
end
local function pause()
  if mode=="play" then save();setMode("pause") end
end
local function continueGame()
  if progress.resume and type(progress.resume)=="table" then
    local n=clamp(tonumber(progress.resume.level) or 1,1,10)
    startLevel(n,progress.resume)
  else startLevel(progress.unlocked) end
end
local function complete()
  local n=world.def.number
  local old=progress.records[tostring(n)] or {}
  local best=old.time and min(old.time,world.elapsed) or world.elapsed
  progress.records[tostring(n)]={stars=max(old.stars or 0,world.stars),coins=max(old.coins or 0,world.coins),time=best}
  progress.unlocked=max(progress.unlocked,min(10,n+1));progress.resume=nil
  setMode(n==10 and "ending" or "complete");save()
end
local function act(index)
  if mode=="title" then
    if index==1 then continueGame()
    elseif index==2 then setMode("select")
    elseif index==3 then settingsReturn="title";setMode("settings")
    elseif index==4 then settingsReturn="title";setMode("help")
    elseif index==5 then sys.exit() end
  elseif mode=="select" then if index<=progress.unlocked then startLevel(index) else notice("locked") end
  elseif mode=="pause" then
    if index==1 then setMode("play")
    elseif index==2 then startLevel(world.def.number)
    elseif index==3 then settingsReturn="pause";setMode("settings")
    elseif index==4 then settingsReturn="pause";setMode("help")
    elseif index==5 then save();title() end
  elseif mode=="complete" then
    if index==1 then startLevel(min(10,world.def.number+1)) elseif index==2 then startLevel(world.def.number) else title() end
  elseif mode=="ending" then
    if index==1 then title();setMode("select") else title() end
  elseif mode=="gameover" then
    if index==1 then startLevel(world.def.number) else title() end
  elseif mode=="settings" then
    if index==1 then options.quality=options.quality==2 and 1 or 2;Render.quality=options.quality
    elseif index==2 then options.music=not options.music;music(musicLevel)
    elseif index==3 then options.sound=not options.sound
    elseif index==4 then options.assist=not options.assist
    elseif index==5 then options.volume=options.volume>=.95 and .25 or min(1,options.volume+.25);music(musicLevel)
    elseif index==6 then setMode(settingsReturn) end
    save()
  elseif mode=="help" then setMode(settingsReturn) end
end
local function back()
  if mode=="play" then pause()
  elseif mode=="pause" then setMode("play")
  elseif mode=="settings" or mode=="help" then setMode(settingsReturn)
  elseif mode=="select" then title()
  elseif mode~="loading" and mode~="title" then title() end
end
local function itemCount()
  if mode=="title" or mode=="pause" then return 5 elseif mode=="select" then return 10 elseif mode=="settings" then return 6 elseif mode=="complete" then return 3 elseif mode=="ending" or mode=="gameover" then return 2 else return 1 end
end
local function navigate(delta)
  selected=(selected-1+delta)%itemCount()+1
  sound("coin")
end

function app.load()
  progress=store.get("progress.v1",{})
  if type(progress)~="table" then progress={} end
  progress.unlocked=clamp(tonumber(progress.unlocked) or 1,1,10)
  if type(progress.records)~="table" then progress.records={} end
  options=store.get("options.v1",{})
  if type(options)~="table" then options={} end
  options.quality=options.quality==1 and 1 or 2
  options.music=options.music~=false;options.sound=options.sound~=false
  options.assist=options.assist==true;options.volume=clamp(tonumber(options.volume) or .7,0,1)
  Render.quality=options.quality
  local ok,err=pcall(Render.init)
  if not ok then loadingError=tostring(err) end
end

local function events()
  for _,e in ipairs(world.events) do
    sound(e.kind)
    if e.kind=="checkpoint" then save();notice("checkpoint.saved")
    elseif e.kind=="star" then notice("star.found")
    elseif e.kind=="extraLife" then notice("life.extra")
    elseif e.kind=="bossWake" then notice("boss.hint",6)
    elseif e.kind=="bossHit" then notice("boss.hit")
    elseif e.kind=="bossDefeat" then notice("boss.defeat",5)
    elseif e.kind=="needStars" then notice("gate.needstars")
    elseif e.kind=="needBoss" then notice("gate.needboss")
    elseif e.kind=="respawn" then save();resetCamera=true
    elseif e.kind=="complete" then complete() end
  end
  world.events={}
end

local function cameraStep(dt)
  local p=world.player
  local rx,ry=input.stick("right")
  rx,ry=rx or 0,ry or 0
  local yawInput=(keys.e and 1 or 0)-(keys.q and 1 or 0)+(input.down("r") and 1 or 0)-(input.down("l") and 1 or 0)
  cam.yaw=cam.yaw+(rx*2.4+yawInput*1.7)*dt
  cam.pitch=clamp(cam.pitch-ry*1.3*dt,.22,.9)
  if resetCamera then cam.x,cam.y,cam.z=p.x,p.y+1,p.z;resetCamera=false end
  local amount=1-math.exp(-dt*7)
  cam.x=cam.x+(p.x-cam.x)*amount;cam.y=cam.y+(p.y+1-cam.y)*amount;cam.z=cam.z+(p.z-cam.z)*amount
  -- Pull the camera forward when its segment crosses an island. Sampled without per-frame allocations.
  local desired=10.7;local cp=cos(cam.pitch)
  for _,b in ipairs(world.def.platforms) do
    if b.active then
      for k=2,10 do
        local d=k*1.05
        local x,y,z=cam.x+sin(cam.yaw)*d*cp,cam.y+sin(cam.pitch)*d,cam.z+cos(cam.yaw)*d*cp
        if math.abs(x-b.x)<b.w/2+.22 and math.abs(z-b.z)<b.d/2+.22 and y<b.y+.4 and y>b.y-3 then desired=min(desired,max(2.3,d-1));break end
      end
    end
  end
  cam.distance=cam.distance+(desired-cam.distance)*(1-math.exp(-dt*10))
end

function app.update(dt)
  dt=clamp(tonumber(dt) or 0,0,.1);clock=clock+dt;toast.timer=max(0,toast.timer-dt)
  if mode=="loading" then
    if not loadingError then
      local ok,done=pcall(Render.loadNext)
      if not ok then loadingError=tostring(done) elseif done then title() end
    end
    return
  end
  if mode=="title" or mode=="select" or (not world and (mode=="settings" or mode=="help")) then
    preview.time=preview.time+dt
    preview.player.anim=preview.player.anim+dt*.1
    cam.x,cam.y,cam.z=-2.8,1.2,-.6;cam.yaw=.4+sin(clock*.1)*.14;cam.pitch=.20;cam.distance=7.0
    return
  end
  if mode~="play" then return end
  if input.pressed("a") then pending.jump=true end
  if input.pressed("b") then pending.dash=true end
  if input.pressed("y") then pending.pound=true end
  if input.pressed("rstick") then cam.yaw=0;cam.pitch=.47 end
  local sx,sy=input.stick("left");sx,sy=sx or 0,sy or 0
  if math.abs(sx)<.15 then sx=0 end;if math.abs(sy)<.15 then sy=0 end
  local ix=sx+(keys.d and 1 or 0)+(keys.right and 1 or 0)-(keys.a and 1 or 0)-(keys.left and 1 or 0)+(input.down("right") and 1 or 0)-(input.down("left") and 1 or 0)
  local iz=-sy+(keys.s and 1 or 0)+(keys.down and 1 or 0)-(keys.w and 1 or 0)-(keys.up and 1 or 0)+(input.down("down") and 1 or 0)-(input.down("up") and 1 or 0)
  touch.linger=max(0,touch.linger-dt)
  if touch.drag or touch.linger>0 then ix,iz=touch.dx,touch.dy end
  local cs,sn=cos(cam.yaw),sin(cam.yaw)
  local control={x=ix*cs+iz*sn,z=-ix*sn+iz*cs,run=keys.shift or keys.lshift or keys.rshift or input.down("zr") or input.down("x"),jumpHeld=keys.space or input.down("a") or touch.jumpHeld or (touch.drag and touch.dy<-.6)}
  accumulator=accumulator+dt
  local stepped=false
  while accumulator>=1/120 do
    if not stepped then
      if pending.jump then world:jump() end
      control.dash=pending.dash;control.pound=pending.pound
      pending={};stepped=true
    else control.dash=false;control.pound=false end
    if options.assist then world.lives=max(4,world.lives) end
    world:step(1/120,control);accumulator=accumulator-1/120
    if world.status~="play" then break end
  end
  events()
  if world.status=="gameover" then progress.resume=nil;setMode("gameover");save() end
  cameraStep(dt)
end

function app.event(e)
  if e.type=="keydown" then
    local repeated=keys[e.key];keys[e.key]=true
    if repeated then return end
    if e.key=="escape" or e.key=="p" then back()
    elseif mode=="play" then
      if e.key=="space" then pending.jump=true
      elseif e.key=="x" then pending.dash=true
      elseif e.key=="c" then pending.pound=true
      elseif e.key=="r" then cam.yaw=0;cam.pitch=.47
      elseif e.key=="f1" then save();settingsReturn="pause";setMode("help") end
    elseif mode~="loading" then
      if e.key=="up" or e.key=="w" then navigate(mode=="select" and -5 or -1)
      elseif e.key=="down" or e.key=="s" then navigate(mode=="select" and 5 or 1)
      elseif e.key=="left" or e.key=="a" then navigate(-1)
      elseif e.key=="right" or e.key=="d" then navigate(1)
      elseif e.key=="enter" or e.key=="space" then act(selected) end
    end
  elseif e.type=="keyup" then keys[e.key]=nil
  elseif e.type=="paddown" then
    if e.pad=="plus" then back()
    elseif mode=="play" then
      if e.pad=="a" then pending.jump=true elseif e.pad=="b" then pending.dash=true elseif e.pad=="y" then pending.pound=true elseif e.pad=="rstick" then cam.yaw=0;cam.pitch=.47 end
    else
      if e.pad=="a" then act(selected) elseif e.pad=="b" then back()
      elseif e.pad=="up" then navigate(mode=="select" and -5 or -1) elseif e.pad=="down" then navigate(mode=="select" and 5 or 1)
      elseif e.pad=="left" then navigate(-1) elseif e.pad=="right" then navigate(1) end
    end
  elseif e.type=="mousedown" and mode=="play" then
    if e.touch then touch.visible=true end
    if e.x<viewport.w*.30 and e.y>viewport.h*.55 then touch.drag=true;touch.x=e.x;touch.y=e.y;touch.dx=0;touch.dy=0 end
  elseif e.type=="mousemove" and touch.drag then
    local radius=max(40,min(viewport.w/1280,viewport.h/720)*65)
    touch.dx=clamp((e.x-touch.x)/radius,-1,1);touch.dy=clamp((e.y-touch.y)/radius,-1,1)
    if touch.dy<-.75 and world.player.grounded then pending.jump=true end
  elseif e.type=="mouseup" then
    if touch.drag then touch.linger=.3 end
    touch.drag=false
  elseif e.type=="scroll" and mode=="play" then cam.pitch=clamp(cam.pitch+e.dy*.001,.22,.9) end
end

-- Screen UI uses a 1280x720 design canvas, with physical coordinates for immediate-mode hit targets.
local S,OX,OY=1,0,0
local function rect(x,y,w,h,color,r)
  gfx.rect(OX+x*S,OY+y*S,w*S,h*S,(r or 0)*S,color)
end
local function text(str,x,y,size,color,font,align,width)
  local px=max(11,size*S)
  if width then while px>9 and gfx.textWidth(str,px,font or "sans")>width*S do px=px-.5 end end
  gfx.color(color or "#F4F0E8");gfx.text(str,OX+x*S,OY+y*S,px,font or "sans",align or "left",width and width*S or nil)
end
local function icon(name,x,y,size,color) gfx.icon(name,OX+x*S,OY+y*S,size*S,color) end
local function button(key,index,x,y,w,h,accent)
  local hit=ui.hit("btn."..mode.."."..index,OX+x*S,OY+y*S,w*S,h*S)
  local active=selected==index or hit.hovered
  rect(x,y,w,h,active and "#FFFFFF14" or "#0D1B2C33",12)
  if active then rect(x,y,4,h,accent or "#F5CE8B",2) end
  text(TR(key),x+24,y+(h-24)/2,21,active and "#FFE1A5" or "#DDE5EA","semibold")
  if active then icon("arrow_forward",x+w-27,y+h/2,19,"#F5CE8B") end
  if hit.clicked then act(index) end
end
local function panel(x,y,w,h)
  rect(x,y,w,h,"#15263BF2",24)
  rect(x+25,y+23,36,3,"#71D6C3",2)
end
local function darken() rect(-OX/S,-OY/S,viewport.w/S,viewport.h/S,"#081323A8") end
local function timerText(seconds) return string.format("%02d:%02d",floor(seconds/60),floor(seconds%60)) end

local function hud()
  local p=world.player
  rect(25,24,228,70,"#112438DB",18)
  for j=1,3 do icon("favorite",45+j*34,59,23,j<=p.hp and "#F7959D" or "#56677B") end
  text(TR("hud.lives",world.lives),203,48,17,"#EEE7DB","bold")
  rect(270,24,218,70,"#112438DB",18)
  icon("toll",301,59,26,"#F5CC83");text(string.format("%03d",world.coins),326,43,27,"#FFF2CA","bold")
  icon("star",415,59,27,"#F5CC83");text(TR("hud.stars",world.stars),440,49,18,"#FFF2CA","bold")
  rect(919,24,280,70,"#112438DB",18)
  text(TR("hud.world",world.def.number),940,35,12,"#A9C1CE","bold")
  text(trLevel(world.def.number),940,55,18,"#F3EFE2","semibold")
  local h=ui.hit("pause",OX+1200*S,OY+28*S,56*S,58*S)
  rect(1200,28,56,58,"#112438DB",13);icon("pause",1228,57,25,"#F5E3BC")
  if h.clicked then pause() end
  -- Route progress: a compact runway, not a spoiler map.
  local fraction=clamp(-p.z/((world.def.length-1)*7.2),0,1)
  rect(28,110,158,4,"#142B4277",2);rect(28,110,158*fraction,4,"#8ED9C6",2)
  text(timerText(world.elapsed),199,102,13,"#F1E5D4","mono")
  if p.dashCD>0 then rect(28,124,158*(1-p.dashCD/.85),3,"#D8B6EB",2) end
  local b=world.def.boss
  if b and b.state~="sleep" and b.hp>0 then
    rect(450,126,380,57,"#16223BEA",14)
    text(TR(b.state=="rest" and "boss.vulnerable" or "boss.name"),470,135,15,"#F6DBAE","semibold")
    for j=1,3 do rect(470+(j-1)*116,161,108,7,j<=b.hp and "#ECA885" or "#506079",3) end
  end
  if toast.timer>0 then
    local py,ph=S<.75 and 592 or 623,S<.75 and 90 or 54
    rect(302,py,676,ph,"#13273EEA",16);icon("auto_awesome",331,py+ph/2,23,"#F4D596")
    gfx.color("#F4E6CF");gfx.wrap(toast.text,OX+354*S,OY+(py+13)*S,593*S,max(11,17*S),"medium","center")
  elseif not touch.visible then text(TR("hud.controls"),280,680,13,"#F5F0E2","medium","center",720) end
  if touch.visible then
    local cx,cy=touch.drag and (touch.x-OX)/S or 106,touch.drag and (touch.y-OY)/S or 596
    gfx.color("#10253C88");gfx.circle(OX+cx*S,OY+cy*S,61*S)
    gfx.color("#D8F6E282");gfx.circle(OX+(cx+touch.dx*35)*S,OY+(cy+touch.dy*35)*S,25*S)
    local a=ui.hit("touch.jump",OX+1138*S,OY+548*S,92*S,92*S)
    local b2=ui.hit("touch.dash",OX+1036*S,OY+604*S,80*S,80*S)
    gfx.color(a.held and "#94D8C6CC" or "#18334BAA");gfx.circle(OX+1184*S,OY+594*S,46*S)
    icon("arrow_upward",1184,594,33,"#ECF7E8")
    gfx.color("#18334BAA");gfx.circle(OX+1076*S,OY+644*S,40*S);icon("bolt",1076,644,28,"#F4D596")
    if a.pressed then pending.jump=true end;touch.jumpHeld=a.held
    if b2.pressed then pending.dash=true end
    local pound=ui.hit("touch.pound",OX+1138*S,OY+446*S,80*S,80*S)
    gfx.color("#18334BAA");gfx.circle(OX+1178*S,OY+486*S,40*S);icon("arrow_downward",1178,486,29,"#F4D596")
    if pound.pressed then pending.pound=true end
  end
end

local function titleUI()
  gfx.gradient(0,0,viewport.w*.62,viewport.h,"#0D1D32F2","#0D1D3200",true)
  text(TR("title.eyebrow"),72,69,13,"#8ED7C6","bold")
  text(TR("title.name"),67,104,100,"#F9E5BB","bold")
  text(TR("title.subtitle"),74,221,26,"#E9EAE4","semibold")
  rect(75,274,44,3,"#8FD4BF",2)
  text(TR("title.tagline"),75,299,16,"#BACCD5")
  local list={"menu.continue","menu.worlds","menu.settings","menu.controls","menu.exit"}
  for j,key in ipairs(list) do button(key,j,65,344+(j-1)*62,345,56) end
  text(TR("title.footer",progress.unlocked,countStars()),74,672,13,"#AEC4CE","medium")
  rect(920,566,267,83,"#14273BCA",16)
  icon("star",948,593,22,"#FFD78D")
  text(TR("title.badge"),971,582,15,"#EFE5D4","semibold")
  text(TR("title.badge.sub"),942,614,12,"#AFC8D1")
end
local function selectUI()
  darken();panel(42,35,1196,650)
  text(TR("worlds.title"),75,82,33,"#F9E6C4","bold")
  text(TR("worlds.subtitle",countStars()),77,129,16,"#B6CBD1")
  for n=1,10 do
    local col,row=(n-1)%5,floor((n-1)/5)
    local x,y=75+col*227,190+row*207
    local unlocked=n<=progress.unlocked
    local pal=Levels.palette(n)
    local hit=ui.hit("world."..n,OX+x*S,OY+y*S,211*S,189*S)
    rect(x,y,211,189,selected==n and "#638C8E" or "#263B50",15)
    rect(x+3,y+3,205,115,unlocked and pal.sky or "#526073",12)
    -- Miniature island thumbnail built from the world's authored colours.
    rect(x+34,y+58,144,22,unlocked and pal.ground or "#73808C",8)
    gfx.color(unlocked and pal.rock or "#616D7C")
    gfx.poly({OX+(x+34)*S,OY+(y+79)*S,OX+(x+177)*S,OY+(y+79)*S,OX+(x+143)*S,OY+(y+101)*S,OX+(x+74)*S,OY+(y+101)*S})
    icon(unlocked and "star" or "lock",x+106,y+43,31,unlocked and "#FFE1A0" or "#C6D0D7")
    text(string.format("%02d",n),x+15,y+12,14,"#F8EDD7","bold")
    text(trLevel(n),x+14,y+130,16,unlocked and "#F0E9DB" or "#94A4B1","semibold")
    local record=progress.records[tostring(n)]
    for j=1,3 do icon("star",x+24+(j-1)*23,y+170,19,record and j<=(record.stars or 0) and "#F6D08B" or "#657485") end
    if record then text(timerText(record.time or 0),x+124,y+160,13,"#B9CDD3","mono") end
    if hit.clicked then selected=n;act(n);return end
  end
  text(TR("worlds.back"),78,640,14,"#BDD1D4")
end
local function menuUI(titleKey,entries,sub)
  darken();panel(389,98,502,535)
  text(TR(titleKey),430,146,34,"#F5E0BB","bold")
  if sub then text(sub,430,193,15,"#BBCFD3") end
  for j,key in ipairs(entries) do button(key,j,418,239+(j-1)*66,444,56) end
end
local function settingsUI()
  darken();panel(332,54,616,612)
  text(TR("settings.title"),372,100,33,"#F8E3BC","bold")
  local list={TR("settings.quality",TR(options.quality==2 and "quality.high" or "quality.low")),TR("settings.music",TR(options.music and "on" or "off")),TR("settings.sound",TR(options.sound and "on" or "off")),TR("settings.assist",TR(options.assist and "on" or "off")),TR("settings.volume",floor(options.volume*100)),TR("back")}
  for j,label in ipairs(list) do
    local x,y,w,h=361,165+(j-1)*68,558,56
    local hit=ui.hit("settings."..j,OX+x*S,OY+y*S,w*S,h*S)
    rect(x,y,w,h,(selected==j or hit.hovered) and "#FFFFFF17" or "#0B1D3022",11)
    if selected==j then rect(x,y,4,h,"#E9CD96",2) end
    text(label,x+22,y+17,18,"#E7E7DC","medium")
    if hit.clicked then selected=j;act(j) end
  end
  text(TR("settings.note"),373,609,13,"#AFC6CE")
end
local function helpUI()
  darken();panel(184,51,912,618)
  text(TR("controls.title"),224,98,34,"#F5E2BC","bold")
  text(TR("controls.keyboard"),224,163,17,"#83D3C0","bold")
  text(TR("controls.pad"),667,163,17,"#83D3C0","bold")
  local rows={"move","jump","run","dash","pound","camera","pause"}
  for j,k in ipairs(rows) do
    text(TR("key."..k),225,205+(j-1)*39,15,"#E7E5DB","sans","left",400)
    text(TR("pad."..k),668,205+(j-1)*39,15,"#E7E5DB","sans","left",400)
  end
  text(TR("controls.goal"),225,502,17,"#F6D89C","semibold")
  text(TR("controls.touch"),225,540,14,"#B8CDD1")
  button("back",1,222,586,833,56)
end
local function resultsUI(ending)
  darken();panel(324,71,632,580)
  text(TR(ending and "ending.title" or "complete.title"),364,120,35,"#F7E4BC","bold")
  text(ending and TR("ending.subtitle") or trLevel(world.def.number),365,175,18,"#B9CED4","medium")
  for j=1,3 do icon("star",532+(j-1)*108,265,68,j<=world.stars and "#FFD38B" or "#627185") end
  text(TR("complete.stats",world.coins,timerText(world.elapsed)),365,328,20,"#ECE3D3","semibold","center",551)
  text(TR(ending and "ending.total" or "complete.saved",ending and countStars() or progress.unlocked),365,369,15,"#A9CCC9","medium","center",551)
  if ending then button("menu.worlds",1,356,450,568,57);button("menu.title",2,356,523,568,57)
  else button("menu.next",1,356,424,568,56);button("menu.retry",2,356,489,568,56);button("menu.title",3,356,554,568,56) end
end

function app.draw(w,h)
  viewport.w,viewport.h=w,h
  S=min(w/1280,h/720);OX=(w-1280*S)/2;OY=(h-720*S)/2
  if mode=="loading" then
    gfx.clear("#11233A")
    text(TR("title.name"),0,210,64,"#F8E4BD","bold","center",1280)
    text(TR(loadingError and "loading.error" or "loading.assets",Render.loaded,Render.catalog and #Render.catalog or 0),160,319,17,"#B9D5D8","medium","center",960)
    rect(400,370,480,4,"#2D4557",2)
    if Render.catalog then rect(400,370,480*Render.loaded/#Render.catalog,4,"#8BD8BF",2) end
    if loadingError then text(loadingError:sub(1,200),140,415,13,"#FFB0AD","mono","center",1000) end
    return
  end
  local isPreview=mode=="title" or mode=="select" or ((mode=="settings" or mode=="help") and settingsReturn=="title")
  Render.scene(isPreview and preview or world,cam,w,h,isPreview and "title" or "play")
  if mode=="play" then hud()
  elseif mode=="title" then titleUI()
  elseif mode=="select" then selectUI()
  elseif mode=="pause" then menuUI("pause.title",{"menu.resume","menu.retry","menu.settings","menu.controls","menu.title"},trLevel(world.def.number))
  elseif mode=="settings" then settingsUI()
  elseif mode=="help" then helpUI()
  elseif mode=="complete" then resultsUI(false)
  elseif mode=="ending" then resultsUI(true)
  elseif mode=="gameover" then menuUI("gameover.title",{"menu.retry","menu.title"},TR("gameover.subtitle")) end
  if mode~="play" and toast.timer>0 and mode~="title" then text(toast.text,150,694,13,"#F6E0B0","medium","center",980) end
end

function app.menu()
  return {{title=TR("title.name"),items={{label=TR("menu.resume"),id=1},{label=TR("menu.controls"),id=2},{label=TR("menu.title"),id=3}}}}
end
function app.onmenu(id)
  if id==1 then if mode=="pause" then setMode("play") elseif mode=="play" then pause() end
  elseif id==2 and mode~="loading" then if mode=="play" then save() end;settingsReturn=world and "pause" or "title";setMode("help")
  elseif id==3 and mode~="loading" then save();title() end
end
function app.suspend() if mode=="play" then pause() end;save();if musicChannel then audio.stop(musicChannel);musicChannel=nil end end
function app.resume() if mode~="loading" and options.music then music(musicLevel>0 and musicLevel or 1) end end
function app.focus(focused) if not focused then keys={};if mode=="play" then pause() end end end
function app.autosave() save() end
function app.close() save();if musicChannel then audio.stop(musicChannel) end;return true end
return app
