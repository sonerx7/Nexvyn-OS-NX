local C=require('game.content')
local W=require('game.world')
local R=require('game.render')
local app={}
local mode,selected,weapon='title',1,1
local w,progress,options
local keys,once,buttons={},{},{}
local clock,accum=0,0
local pointer={x=320,y=180,fire=false,aim=false}
local touch={visible=false,drag=false,x=0,y=0,linger=0}
local toast={text='',time=0}
local returnMode='title'
local floor,min,max=math.floor,math.min,math.max
local function ui(key)return C.t(C.ui[key])end
local function notify(value)toast.text=C.t(value);toast.time=2.3 end
local function clearInput()keys={};once={};pointer.fire=false;touch.drag=false;touch.linger=0;accum=0 end
local function to(m)mode=m;selected=m=='title' and progress and not progress.resume and 2 or 1;clearInput()end
local function save()
 if w and w.phase~='dead' and w.phase~='won' then progress.resume=w:snapshot() end
 store.set('frost.progress.v1',W.copy(progress));store.set('frost.options.v1',W.copy(options))
end
local function music(n)
 audio.musicStop();if options.music then audio.music('bundle:/audio/biome'..n..'.wav') end
end
local function sound(name)if options.sound then audio.play('bundle:/audio/'..name..'.wav',.35,0) end end
local function beginRun()
 progress.runs=progress.runs+1
 local seed=(math.floor(sys.epoch())+progress.runs*7919)%2147483646+1
 w=W.new(seed,weapon,progress.meta);to('game');music(1);save()
end
local function resumeRun()
 if not progress.resume then to('weapons');return end
 local ok,value=pcall(W.new,1,1,{},progress.resume)
 if ok and value and value.player then w=value;to('game');music(w.biome) else progress.resume=nil;to('weapons') end
end
local function settle(win)
 progress.shards=progress.shards+w.shards;progress.kills=progress.kills+w.kills
 progress.best=max(progress.best,w.biome);progress.wins=progress.wins+(win and 1 or 0)
 progress.resume=nil;store.set('frost.progress.v1',W.copy(progress));sound(win and 'boon' or 'hurt')
end
local function handleEvents()
 local events=w.events;w.events={}
 for _,event in ipairs(events) do
  if event.kind=='save' then save()
  elseif event.kind=='end' then settle(event.data)
  elseif event.kind=='room' then selected=1;music(event.data)
  elseif event.kind=='poor' then notify(C.ui.unaffordable)
  elseif event.kind=='boon' then sound('boon')
  elseif event.kind=='coin' then sound('coin')
  elseif event.kind=='attack' then sound(w.weapon==1 and 'hit' or 'shoot')
  elseif event.kind=='hurt' then sound('hurt');sys.vibrate(.3,90)
  elseif event.kind=='dash' then sound('dash')
  elseif event.kind=='clear' then selected=1;sound('boon') end
 end
end
local function count()
 if mode=='title' then return 6 elseif mode=='weapons' then return 3 elseif mode=='pause' then return 6
 elseif mode=='settings' then return 7 elseif mode=='workshop' then return 4 elseif mode=='help' then return 1
 elseif mode=='journal' then return 30
 elseif mode=='game' and w then
  if w.phase=='route' then return w.row==4 and 1 or 3 elseif w.phase=='reward' then return #w.rewards
  elseif w.phase=='shop' then return 4 elseif w.phase=='shrine' then return 2 elseif w.phase=='dead' or w.phase=='won' then return 2 end
 end;return 1
end
local function activate(index)
 if mode=='title' then
  if index==1 then resumeRun() elseif index==2 then to('weapons') elseif index==3 then to('workshop')
  elseif index==4 then returnMode='title';to('help') elseif index==5 then returnMode='title';to('settings') else sys.exit() end
 elseif mode=='weapons' then weapon=index;beginRun()
 elseif mode=='pause' then
  if index==1 then to('game') elseif index==2 then to('journal')
  elseif index==3 then returnMode='pause';to('settings') elseif index==4 then returnMode='pause';to('help')
  elseif index==5 then save();w=nil;to('title');music(1) else save();sys.exit() end
 elseif mode=='workshop' then
  local defs={{'health',5,8},{'power',5,10},{'flask',2,20}}
  if index==4 then to('title') else local def=defs[index];local rank=progress.meta[def[1]] or 0;local cost=def[3]*(rank+1)
   if rank<def[2] and progress.shards>=cost then progress.shards=progress.shards-cost;progress.meta[def[1]]=rank+1;save();sound('boon') end
  end
 elseif mode=='settings' then
  local names={'sound','music','shake','autoaim'}
  if index<=4 then local key=names[index];options[key]=not options[key];if key=='music' then music(w and w.biome or 1) end
  elseif index==5 then C.lang=3-C.lang;options.lang=C.lang
  elseif index==6 then options.touch=not options.touch;touch.visible=options.touch
  else to(returnMode) end;save()
 elseif mode=='help' then to(returnMode)
 elseif mode=='journal' then selected=index
 elseif mode=='game' then
  if w.phase=='route' then if w:choose(index) then clearInput();selected=1;handleEvents() end
  elseif w.phase=='reward' then if w:takeReward(index) then selected=1;clearInput();handleEvents() end
  elseif w.phase=='shop' then w:shop(index);selected=1;handleEvents()
  elseif w.phase=='shrine' then w:shrine(index);selected=1;handleEvents()
  elseif w.phase=='dead' or w.phase=='won' then w=nil;if index==1 then to('weapons') else to('title');music(1) end end
 end
end
local function back()
 if mode=='game' then
  if w.phase=='play' or w.phase=='route' or w.phase=='reward' then save();to('pause')
  elseif w.phase=='shop' or w.phase=='shrine' then w.phase='play';clearInput() else w=nil;to('title') end
 elseif mode=='pause' or mode=='journal' then to('game')
 elseif mode=='settings' or mode=='help' then to(returnMode) else to('title') end
end
function app.load()
 progress=store.get('frost.progress.v1',{shards=0,runs=0,wins=0,kills=0,best=1,meta={health=0,power=0,flask=0}})
 progress.meta=progress.meta or {};progress.shards=progress.shards or 0
 options=store.get('frost.options.v1',{sound=true,music=true,shake=true,autoaim=false,touch=false,lang=sys.lang()=='tr' and 1 or 2})
 C.lang=options.lang or 1;R.load();touch.visible=options.touch;to('title');music(1)
end
function app.update(dt)
 dt=min(dt,.15);clock=clock+dt;toast.time=max(0,toast.time-dt)
 if mode~='game' or not w or w.phase~='play' then return end
 accum=accum+dt
 while accum>=1/60 do
  accum=accum-1/60
  local sx,sy=input.stick('left');local ax,ay=input.stick('right');sx,sy=sx or 0,-(sy or 0);ax,ay=ax or 0,-(ay or 0)
  local dx=(keys.d and 1 or 0)-(keys.a and 1 or 0)+(keys.right and 1 or 0)-(keys.left and 1 or 0)+sx
  local dy=(keys.s and 1 or 0)-(keys.w and 1 or 0)+(keys.down and 1 or 0)-(keys.up and 1 or 0)+sy
  if touch.drag then touch.linger=.18 end
  if touch.linger>0 then touch.linger=max(0,touch.linger-1/60);dx=touch.x;dy=touch.y end
  local auto=options.autoaim or touch.visible
  if pointer.aim and not auto and ax*ax+ay*ay<.04 then ax=pointer.x+R.cx-w.player.x;ay=pointer.y+R.cy-w.player.y end
  w:step(1/60,{x=dx,y=dy,ax=ax,ay=ay,autoaim=auto,
   attack=keys.j or pointer.fire or input.down('zr') or (touch.drag and touch.visible),
   dash=once.dash,heal=once.heal,skill=once.skill,use=once.use})
  once={};handleEvents();if w.phase~='play' then clearInput();break end
 end
end
local function button(index,label,x,y,width,height,enabled)
 enabled=enabled~=false;buttons[#buttons+1]={index=index,x=x,y=y,w=width,h=height,enabled=enabled}
 R.panel(x,y,width,height,selected==index and enabled)
 if not enabled then gfx.alpha(.4) end
 R.text(label,x+8,y+floor((height-14)/2),1,'center',width-16)
 if not enabled then gfx.unalpha() end
end
local function header(title,subtitle)
 R.panel(12,10,616,48);R.text(title,22,15,2);if subtitle then R.text(subtitle,24,43) end
end
local function background()
 if R.images.title then R.region('title',0,0,640,360,0,0,640,360) else R.rect(0,0,640,360,'#102330') end
 R.rect(0,0,640,360,'#0c142955')
end
local function titleUI()
 background();R.rect(12,13,302,336,'#101c2dd9');R.text(C.ui.title,28,28,2);R.text(C.ui.subtitle,28,64)
 R.rect(29,86,267,1,'#9c865f');R.text('PIXEL ROGUELIKE',29,95)
 local labels={C.ui.continue,C.ui.new,C.ui.workshop,C.ui.help,C.ui.settings,C.ui.quit}
 for i,label in ipairs(labels) do button(i,label,28,125+(i-1)*29,268,25,i~=1 or progress.resume~=nil) end
 R.icon(38,29,306,20);R.text(tostring(progress.shards)..' '..ui('shards'),54,310);R.text(C.ui.savehint,28,332)
 R.panel(430,302,196,43);R.text('SONERX7',442,309);R.text('v1.0.0  /  NEXVYN OS',442,326)
end
local function weaponUI()
 background();header(C.ui.chooseweapon,{'Üç farklı oyun tarzı · Her yolculuk yeni bir rota','Three playstyles · Every journey a new route'})
 for i,def in ipairs(C.weapons) do
  local x=16+(i-1)*208;R.panel(x,85,192,222,selected==i);R.icon(i+1,x+64,104,64)
  R.text(def.name,x+8,182,1,'center',176);R.wrap(def.desc,x+14,211,164)
  button(i,{'Yola çık','Begin journey'},x+17,266,158,27)
 end
 R.text({'Esc: geri','Esc: back'},18,335)
end
local function routesUI()
 if not w:available(selected) then selected=w.row==4 and 1 or w.lane end
 background();R.rect(0,0,640,360,'#0b1629d0');header(C.ui.route,C.biomes[w.biome].name)
 -- All thirteen nodes are drawn. Only adjacent lanes in the next tier can be chosen.
 for row=1,5 do
  for lane,node in ipairs(w.routes[row]) do
   local x=row==5 and 258 or 66+(lane-1)*192;local y=274-(row-1)*44
   if row<5 then
    for nextLane=1,(row==4 and 1 or 3) do if row==4 or math.abs(lane-nextLane)<=1 then
     local nx=row==4 and 314 or 122+(nextLane-1)*192
     local sx=x+56;local len=math.sqrt((nx-sx)^2+44^2)
     for k=0,floor(len/7) do local t=k/max(1,floor(len/7));R.rect(sx+(nx-sx)*t,y-44*t,2,2,'#81928250') end
    end end
   end
   local nextrow=row==w.row+1;local eligible=nextrow and w:available(lane)
   if not eligible then gfx.alpha(w.visited[w.biome..':'..row..':'..lane] and .85 or .4) end
   R.panel(x,y,112,30,eligible and selected==lane);R.text(C.ui[node.kind],x+4,y+9,1,'center',104)
   if not eligible then gfx.unalpha() else buttons[#buttons+1]={index=lane,x=x,y=y,w=112,h=30,enabled=true} end
  end
 end
 R.rect(10,315,620,41,'#101d2bf5');R.wrap(C.biomes[w.biome].story,19,319,602)
 R.text('A / ENTER',511,66)
end
local function rewardUI()
 R.rect(0,0,640,360,'#081324dc');header(w.node.kind=='boss' and C.ui.bossreward or C.ui.reward,{'Birini seç · Diğer ikisi bu yolculukta kaybolur','Choose one · The other two are left behind'})
 for i,id in ipairs(w.rewards) do
  local b=C.byId[id];local x=14+(i-1)*210;R.panel(x,81,196,244,selected==i)
  R.icon(b.icon,x+72,95,48);R.text(string.rep('*',b.rarity),x+7,148,1,'center',182)
  R.wrap(b.name,x+13,172,172);R.wrap(b.desc,x+13,207,171)
  R.text(ui('rank')..' '..(w:rank(id)+1)..' / '..b.max,x+12,269)
  button(i,{'Lütfu al','Accept boon'},x+13,290,170,25)
 end
end
local function pauseUI()
 R.rect(0,0,640,360,'#071423d9');R.panel(172,27,296,306);R.text(C.ui.pause,185,42,1,'center',270)
 for i,label in ipairs({C.ui.resume,C.ui.build,C.ui.settings,C.ui.help,C.ui.menu,C.ui.quit}) do button(i,label,193,80+(i-1)*39,254,32) end
end
local function workshopUI()
 background();R.rect(0,0,640,360,'#0b1727ce');header(C.ui.workshop,ui('shards')..': '..progress.shards)
 local defs={{'health',5,8,'healthmeta'},{'power',5,10,'powermeta'},{'flask',2,20,'flaskmeta'}}
 for i,def in ipairs(defs) do local rank=progress.meta[def[1]] or 0;local cost=def[3]*(rank+1);local y=79+(i-1)*72
  R.panel(35,y,570,60,selected==i);R.icon(({5,2,7})[i],48,y+15,28);R.text(C.ui[def[4]],91,y+10);R.text(ui('rank')..' '..rank..' / '..def[2],91,y+34)
  button(i,rank>=def[2] and C.ui.maxed or ui('cost')..': '..cost,397,y+15,190,29,rank<def[2] and progress.shards>=cost)
 end
 button(4,C.ui.back,216,308,208,29)
end
local function settingsUI()
 background();R.rect(0,0,640,360,'#0b1629bf');header(C.ui.settings)
 local labels={};for i,key in ipairs({'sound','music','shake','autoaim'}) do labels[i]=ui(key)..': '..ui(options[key] and 'on' or 'off') end
 labels[5]='DIL / LANGUAGE: '..(C.lang==1 and 'TÜRKÇE' or 'ENGLISH');labels[6]=(C.lang==1 and 'DOKUNMATIK: ' or 'TOUCH: ')..ui(options.touch and 'on' or 'off');labels[7]=ui('back')
 for i,label in ipairs(labels) do button(i,label,148,69+(i-1)*39,344,32) end
end
local function journalUI()
 R.rect(0,0,640,360,'#101d2bf5');header(C.ui.build,ui('seed')..': '..w.seed..'   '..ui('kills')..': '..w.kills)
 for i,b in ipairs(C.boons) do local col=(i-1)%6;local row=floor((i-1)/6);local x=23+col*102;local y=73+row*39;local rank=w:rank(b.id)
  if rank==0 then gfx.alpha(.35) end
  R.panel(x,y,91,33,selected==i);R.icon(b.icon,x+5,y+5,24);R.text('x'..rank,x+43,y+10)
  if rank==0 then gfx.unalpha() end
  buttons[#buttons+1]={index=i,x=x,y=y,w=91,h=33,enabled=true}
 end
 local b=C.boons[selected];R.panel(18,276,604,71);R.text(b.name,29,282);R.wrap(b.desc,29,301,575)
 for _,s in ipairs(C.synergies) do if (s.a==b.id or s.b==b.id) and w:rank(s.a)>0 and w:rank(s.b)>0 then R.text(s.name,29,329) end end
 R.text({'Esc / Tab: geri','Esc / Tab: back'},424,44)
end
local function endUI()
 background();R.rect(0,0,640,360,'#0b1629cc');local win=w.phase=='won';header(win and C.ui.victory or C.ui.death)
 R.panel(59,80,522,155);R.wrap(win and C.ui.victorybody or C.ui.deathbody,77,96,485)
 R.text(ui('shards')..': '..w.shards,79,159);R.text(ui('kills')..': '..w.kills,79,183);R.text(ui('floor')..': '..w.biome..' / 5',335,159)
 R.text(ui('seed')..': '..w.seed,335,183)
 button(1,C.ui.new,165,260,310,32);button(2,C.ui.back,165,304,310,32)
end
local function merchantUI()
 R.rect(0,0,640,360,'#091626d9');local shrine=w.phase=='shrine';header(shrine and C.ui.shrine or C.ui.shop,ui('gold')..': '..w.gold)
 if shrine then
  R.panel(47,77,546,107);R.wrap(C.ui.shrinebody,65,94,510)
  button(1,C.ui.sacrifice,103,210,434,36,w.player.maxhp>35);button(2,C.ui.blessing,103,264,434,36)
 else
  R.prop(16,93,194)
  for i,key in ipairs({'buyheal','buypotion','buyboon','leave'}) do button(i,C.ui[key],177,82+(i-1)*61,414,43) end
 end
end
function app.draw(width,height)
 R.begin(width,height);buttons={}
 if mode=='title' then titleUI()
 elseif mode=='weapons' then weaponUI()
 elseif mode=='workshop' then workshopUI()
 elseif mode=='settings' then settingsUI()
 elseif mode=='help' then background();R.rect(0,0,640,360,'#091827e0');header(C.ui.help);R.panel(17,72,606,230);R.wrap(C.ui.helpbody,32,84,575);button(1,C.ui.back,220,316,200,29)
 else
  if w and w.map then R.scene(w,options.shake);R.hud(w,touch.visible) else background() end
  if mode=='pause' then pauseUI() elseif mode=='journal' then journalUI()
  elseif mode=='game' and w then
   if w.phase=='route' then routesUI() elseif w.phase=='reward' then rewardUI()
   elseif w.phase=='shop' or w.phase=='shrine' then merchantUI()
   elseif w.phase=='dead' or w.phase=='won' then endUI() end
  end
 end
 if toast.time>0 then R.panel(90,286,460,27);R.text(toast.text,98,293,1,'center',444) end
 R.finish()
end
function app.event(e)
 local kind=e.type;local key=e.key;local pad=e.pad
 if kind=='keydown' or kind=='paddown' then
  if kind=='keydown' then keys[key]=true;touch.visible=options.touch else touch.visible=options.touch end
  local backKey=key=='escape' or key=='p' or pad=='plus'
  if backKey then back();return end
  if (key=='tab' or pad=='minus') and w and (mode=='game' or mode=='journal') then if mode=='journal' then to('game') else save();to('journal') end;return end
  if mode=='game' and w and w.phase=='play' then
   if key=='space' or pad=='b' then once.dash=true elseif key=='q' or pad=='y' then once.skill=true
   elseif key=='h' or pad=='l' then once.heal=true elseif key=='e' or pad=='x' then once.use=true end
  else
   local delta=(key=='down' or key=='right' or pad=='down' or pad=='right') and 1 or (key=='up' or key=='left' or pad=='up' or pad=='left') and -1 or 0
   if mode=='journal' and (key=='down' or pad=='down' or key=='up' or pad=='up') then delta=delta*6 end
   selected=(selected-1+delta)%max(1,count())+1
   if mode=='title' and selected==1 and not progress.resume then selected=delta<0 and 6 or 2 end
   if key=='enter' or key=='space' or pad=='a' then activate(selected) elseif pad=='b' then back() end
  end
 elseif kind=='keyup' then keys[key]=nil
 elseif kind=='mousemove' or kind=='mousedown' or kind=='mouseup' then
  local x,y=((e.x or 0)-R.ox)/R.s,((e.y or 0)-R.oy)/R.s;pointer.x=x;pointer.y=y
  if e.touch then touch.visible=true else pointer.aim=true end
  if kind=='mousedown' then
   for _,b in ipairs(buttons) do if b.enabled and x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then selected=b.index;activate(b.index);return end end
   if mode=='game' and w and w.phase=='play' then
    if e.touch then
     if y>=265 and y<310 then
      if x<61 then once.dash=true elseif x<126 then once.heal=true elseif x>=580 then once.use=true elseif x>=520 then once.skill=true end
     elseif x<320 then touch.drag=true;touch.originX=x;touch.originY=y;touch.x=0;touch.y=0;touch.linger=.18
     else pointer.fire=true end
    elseif e.button=='left' then pointer.fire=true elseif e.button=='right' then once.dash=true end
   end
  elseif kind=='mousemove' and touch.drag and e.touch then
   touch.x=max(-1,min(1,(x-touch.originX)/30));touch.y=max(-1,min(1,(y-touch.originY)/30));touch.linger=.18
  elseif kind=='mouseup' then pointer.fire=false;touch.drag=false;touch.linger=0;touch.x=0;touch.y=0 end
 end
end
function app.suspend()if w and mode=='game' then save();to('pause') else save() end;audio.musicPause(true)end
function app.resume()audio.musicPause(false)end
function app.focus(focused)if not focused then app.suspend()end end
function app.autosave()save()end
function app.close()save();audio.musicStop();return true end
function app.unsaved()return false end
function app.menu()return {{title=ui('title'),items={{label=ui('resume'),id=1},{label=ui('help'),id=2},{label=ui('settings'),id=3}}}}end
function app.onmenu(id)if id==1 and w then to('game') elseif id==2 then returnMode=mode;to('help') elseif id==3 then returnMode=mode;to('settings')end end
return app
