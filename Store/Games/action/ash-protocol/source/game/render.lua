local Native=require("game.native_models")
local F=require("game.physics")
local fx=require("game.fx")
local R={models={},split={},catalog={},loaded=0,batches={},glow={},quality=2,drawCalls=0,triangles=0}
local sin,cos,sqrt,min,max,floor,abs=math.sin,math.cos,math.sqrt,math.min,math.max,math.floor,math.abs
local function rgb(c)return {tonumber(c:sub(2,3),16),tonumber(c:sub(4,5),16),tonumber(c:sub(6,7),16)}end
local function draw(mesh,x,y,z,rx,ry,rz,sx,sy,sz,color,flags)
 if mesh then g3d.draw(mesh,x,y,z,rx or 0,ry or 0,rz or 0,sx or 1,sy or sx or 1,sz or sx or 1,color,flags);R.drawCalls=R.drawCalls+1 end
end
-- PBR values (only used when the pbr renderer is active, see game/fx.lua). textures/pbr holds a normal map and an
-- ORM map (R occlusion, G roughness, B metallic) per surface texture: scans for floor, concrete and wall, procedural
-- ones for ceiling, grate and organic. The metallic and roughness numbers below are factors on those maps (the OS
-- clamps them to 0..1). Map roughness means: floor .59, grate .41, wall .28, concrete .77, organic .44, ceiling .81,
-- grain (props, enemies, weapons) .9 since 1.5.0 (tools/ash_pbr_assets.py), so a model's factor is its roughness/.9.
local PBR="bundle:/textures/pbr/"
local function maps(name,metal,rough,extra)
 local t={normalMap=PBR..name.."_n.jpg",occlusionMap=PBR..name.."_orm.jpg",metalRoughMap=PBR..name.."_orm.jpg",metallic=metal,roughness=rough,normalScale=1.5}
 if extra then for k,v in pairs(extra) do t[k]=v end end
 return t
end
local function copy(t)local o={};for k,v in pairs(t) do o[k]=v end;return o end
local SURFACE={floor=maps("floor",.6,.85),grate=maps("grate",.9,1),wall=maps("wall",.55,1),concrete=maps("concrete",0,1),
 organic=maps("organic",0,1,{clearcoat=.35,clearcoatRoughness=.25}),ceiling=maps("ceiling",.3,1)}
-- Per-area mood of the pbr tier (one area per chapter): exposure / bloom, fog start and end, environment ambient,
-- the room key light (a ceiling spot over the room the player is in; it casts the shadow at Effects Medium, and at
-- High while the flashlight is off), and how wet floors are (clearcoat on floor and grate, puddles).
local AREA={
 {id=1,exposure=1.10,bloom=.06,threshold=.9,fog={20,62},ambient=.72,key="#D6EAF0",keyI=24,wet=.25,puddles=1},
 {id=2,exposure=1.05,bloom=.07,threshold=.85,fog={18,58},ambient=.68,key="#FFD3A1",keyI=22,wet=.2,puddles=1},
 {id=3,exposure=1.15,bloom=.06,threshold=.9,fog={16,55},ambient=.74,key="#CBEDEE",keyI=22,wet=.6,puddles=3},
 {id=4,exposure=1.10,bloom=.065,threshold=.9,fog={20,60},ambient=.7,key="#E0D4F2",keyI=22,wet=.3,puddles=1},
 {id=5,exposure=1.20,bloom=.07,threshold=.85,fog={12,46},ambient=.8,key="#F2C6C0",keyI=20,wet=.7,puddles=3},
 {id=6,exposure=1.05,bloom=.08,threshold=.85,fog={22,66},ambient=.68,key="#FFDDB6",keyI=28,wet=.35,puddles=2}}
local surfCache={}
local function surface(material,area)
 local base=SURFACE[material];if not base then return {roughness=.7} end
 local key=material..":"..area.id;local t=surfCache[key]
 if not t then
  t=copy(base)
  if material=="floor" or material=="grate" then t.clearcoat=area.wet;t.clearcoatRoughness=.06+.2*(1-area.wet)
  elseif material=="organic" then t.clearcoat=max(.45,area.wet);t.clearcoatRoughness=.15 end
  surfCache[key]=t
 end
 return t
end
-- Props, weapons and enemies share textures/grain.png: {metallic, roughness, clearcoat} per model.
local MODEL={weapon1={.9,.32},weapon2={.9,.34},weapon3={.9,.3},weapon4={.9,.28},glove={0,.85},
 stalker={.15,.5,.55},stalker_arm={.15,.5,.55},leg={.55,.42},trooper={.5,.45},drone={.85,.3},siege={.8,.38},warden={.75,.34},
 priest={.2,.55,.3},core={.9,.22},barrel={.7,.45},crate={.2,.75},ammo={.55,.5},armor={.6,.35,.4},medkit={.05,.55,.5},
 key={.9,.25},datapad={.4,.35,.6},terminal={.6,.35},comms={.6,.4},relay={.75,.3},generator={.8,.45},turbine={.9,.3},
 gantry={.7,.5},pipe_rack={.85,.32},cover_panel={.65,.45},supply_stack={.2,.8}}
-- Emissive parts (split out of the models by vertex colour, tools/ash_pbr_assets.py): colour and strength (> 1 blooms).
local GLOW={stalker={"#FF6A3D",3},siege={"#FFB060",2.5},drone={"#FF7A50",3},warden={"#FF9A50",2.5},priest={"#B88CFF",2.5},
 terminal={"#8FF2E0",2.2},comms={"#7FF0E0",3},key={"#7CCBFF",2},core={"#E070C0",4},datapad={"#C0A0FF",2},barrel={"#FF9A50",2.5}}
local matCache={}
local function modelMaterial(name)   -- one options table per model kind, shared by every mesh / handle of that kind
 local t=matCache[name]
 if not t then
  local v=MODEL[name] or {.5,.6}
  t=maps("grain",v[1],min(1,v[2]/.9));if v[3] then t.clearcoat=v[3];t.clearcoatRoughness=.12 end
  matCache[name]=t
 end
 return t
end
local function partMaterial(name,part)
 local key=name..":"..part;local t=matCache[key]
 if not t then
  t=copy(modelMaterial(name))
  if part~="body" then
   local g=GLOW[name] or {"#FFFFFF",2};t.emissive=g[1];t.emissiveStrength=g[2]
   if part=="screen" or name=="stalker" then t.clearcoat=1;t.clearcoatRoughness=.04;t.roughness=.2/.9 end   -- glass over screens and visors
  end
  matCache[key]=t
 end
 return t
end
function R.init()
 R.native=Native.new();R.pool={stalker={},trooper={}};R.rigs=setmetatable({},{__mode="k"})
 if g3d.loadModel then
  for _,kind in ipairs({"stalker","trooper"}) do
   local mat=modelMaterial(kind)
   for i=1,12 do local pool=R.pool[kind];R.native:request("bundle:/models/"..kind.."-rig.glb",function(m) fx.material(m,mat);pool[#pool+1]={model=m} end) end
  end
 end
 R.catalog=assert(json.decode(assert(fs.read("bundle:/models/catalog.json"))))
 R.box=g3d.mesh("cube",1);R.ball=g3d.mesh("sphere",1,10,7);R.ring=g3d.mesh("torus",1,.035,28,5)
 -- pbr-tier meshes: glass (relay domes, the core's containment), puddles' look, emissive door strips and alarm
 R.dome=g3d.mesh("sphere",1,18,12);R.dome:setColor("#CFEFEA")
 fx.material(R.dome,{metallic=0,roughness=.05,transmission=.85,ior=1.45})
 R.tube=g3d.mesh("cylinder",1,1,28);R.tube:setColor("#D8E8EE")
 fx.material(R.tube,{metallic=0,roughness=.04,transmission=.9,ior=1.5,clearcoat=.6,clearcoatRoughness=.03})
 local function emitter(color,strength,w,h,d)
  local m=g3d.mesh("box",w,h,d);m:setColor(color);fx.material(m,{emissive=color,emissiveStrength=strength,roughness=.35});return m
 end
 R.stripOpen=emitter("#87DDC1",3,.10,2.6,.025);R.stripShut=emitter("#DCA776",3,.10,2.6,.025)
 R.alarm=emitter("#FF3326",6,.5,.18,.5)
 R.lampMeshes={}
 -- lamp halo for instancing: the 1.4.0 halo was a sphere drawn at .18 x .55 x .18; this mesh has that shape built in
 local v,idx,uv={},{},{}
 for ring=0,7 do
  local a=ring/7*math.pi;local y,rr=cos(a)*.55,sin(a)*.18
  for k=0,10 do local b=k/10*math.pi*2;v[#v+1]=cos(b)*rr;v[#v+1]=y;v[#v+1]=sin(b)*rr;uv[#uv+1]=k/10;uv[#uv+1]=ring/7 end
 end
 for ring=0,6 do for k=0,9 do
  local i0=ring*11+k+1;local i1=i0+11
  idx[#idx+1]=i0;idx[#idx+1]=i0+1;idx[#idx+1]=i1;idx[#idx+1]=i0+1;idx[#idx+1]=i1+1;idx[#idx+1]=i1
 end end
 R.halo=g3d.custom(v,idx,nil,false,uv)
end
local function loadMesh(file,name,mat)
 local d=assert(json.decode(assert(fs.read("bundle:/models/"..file..".json"))))
 local m=g3d.custom(d.vertices,d.indices,d.colors,false,d.uvs)
 m:setTexture("bundle:/"..d.texture);fx.material(m,mat);return m
end
function R.loadNext()
 R.native:update();if R.native.error then error(R.native.error) end
 local a=R.catalog[R.loaded+1];if not a then return R.native:ready() end
 R.models[a.name]=loadMesh(a.name,a.name,modelMaterial(a.name))   -- the whole model: basic renderer
 if a.parts then   -- body + emissive parts: pbr renderer
  local s={}
  for _,part in ipairs(a.parts) do s[#s+1]={mesh=loadMesh(a.name.."__"..part,a.name,partMaterial(a.name,part)),part=part} end
  R.split[a.name]=s
 end
 R.loaded=R.loaded+1
 return R.loaded>=#R.catalog and R.native:ready()
end
local function quad(b,a,c,d,e,axis)
 local start=#b.v/3
 for _,p in ipairs({a,c,d,e}) do
  b.v[#b.v+1]=p[1];b.v[#b.v+1]=p[2];b.v[#b.v+1]=p[3]
  b.uv[#b.uv+1]=(axis=="x" and p[3] or p[1])/2
  b.uv[#b.uv+1]=(axis=="y" and p[3] or -p[2])/2
  b.minX=min(b.minX,p[1]);b.maxX=max(b.maxX,p[1]);b.minY=min(b.minY,p[2]);b.maxY=max(b.maxY,p[2]);b.minZ=min(b.minZ,p[3]);b.maxZ=max(b.maxZ,p[3])
 end
 for _,id in ipairs({1,2,3,1,3,4}) do b.i[#b.i+1]=start+id end
end
local function boxQuads(b,x0,x1,y0,y1,z0,z1)
 quad(b,{x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},"z")
 quad(b,{x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},"z")
 quad(b,{x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},"x")
 quad(b,{x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},"x")
 quad(b,{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},{x0,y1,z0},"y")
 quad(b,{x0,y0,z0},{x1,y0,z0},{x1,y0,z1},{x0,y0,z1},"y")
end
local function builder()return {v={},i={},uv={},minX=1e9,maxX=-1e9,minY=1e9,maxY=-1e9,minZ=1e9,maxZ=-1e9}end
local function pointLight(w,x,y,z,doOcclusion)
 local result={.62,.65,.68};local nearest=nil;local best=1e9
 for _,l in ipairs(w.map.lights) do
  local dx,dy,dz=l.x-x,l.y-y,l.z-z;local d2=dx*dx+dy*dy+dz*dz
  if d2<best then best=d2;nearest=l end
  if d2<l.r*l.r then
   local distance=sqrt(d2);local amount=(1-distance/l.r)*.40
   if doOcclusion and distance>.1 then
    local ray={x=dx/distance,y=dy/distance,z=dz/distance}
    if F.ray(w,{x=x+ray.x*.1,y=y+ray.y*.1,z=z+ray.z*.1},ray,distance)<distance-.4 then amount=amount*.15 end
   end
   for c=1,3 do result[c]=result[c]+amount*l.rgb[c]/255 end
  end
 end
 return result,nearest
end
local function inRoom(map,x,z,margin)
 for _,r in ipairs(map.rooms) do if abs(x-r.x)<r.w/2+(margin or 0) and abs(z-r.z)<r.d/2+(margin or 0) then return r end end
end
-- Render-only detail (no collision, gameplay unchanged): skirting, wall ribs, ceiling beams, lamp hangers, wall pipes,
-- corridor pipes with brackets. Merged into the level batches (no extra draw calls). Emissive strips (door frames,
-- corridor ceiling) and hazard paint go to two merged meshes. Box list: {material, x0, x1, y0, y1, z0, z1}.
local function detail(map)
 local out,strips,hazard={}, {}, {}
 local function add(list,m,x0,x1,y0,y1,z0,z1) list[#list+1]={m,min(x0,x1),max(x0,x1),y0,y1,min(z0,z1),max(z0,z1)} end
 local wallMat=map.style.wall
 for _,r in ipairs(map.rooms) do
  local cy=r.h-.175
  for _,side in ipairs({"n","s","e","w"}) do
   local xSide=side=="e" or side=="w";local L=xSide and r.d or r.w
   local sign=(side=="e" or side=="s") and 1 or -1
   local inner=(xSide and r.x or r.z)+sign*((xSide and r.w or r.d)/2-.2)
   local centre=xSide and r.z or r.x
   -- a box against this wall: along t0..t1 (offset from the wall centre), from depth a to b inward, height y0..y1
   local function wallBox(list,m,t0,t1,a,b,y0,y1)
    local p0,p1=inner-sign*a,inner-sign*b
    if xSide then add(list,m,p0,p1,y0,y1,centre+t0,centre+t1) else add(list,m,centre+t0,centre+t1,y0,y1,p0,p1) end
   end
   local open=r.open[side]
   local spans=open and {{-L/2+.2,-2.35},{2.35,L/2-.2}} or {{-L/2+.2,L/2-.2}}
   for _,s in ipairs(spans) do wallBox(out,wallMat,s[1],s[2],0,.1,0,.22) end           -- skirting
   local t=-L/2+1.6
   while t<=L/2-1.6 do                                                               -- ribs every 3 m
    if not open or abs(t)>3.1 then wallBox(out,wallMat,t-.16,t+.16,0,.14,.22,r.h-.62) end
    t=t+3
   end
   if not open and not xSide then                                                    -- two pipes on closed n/s walls
    for _,y in ipairs({r.h-1.45,r.h-1.15}) do wallBox(out,"ceiling",-L/2+.6,L/2-.6,.2,.34,y,y+.14) end
   end
   if open then
    for _,s in ipairs({-1,1}) do wallBox(strips,"",s*2.16-.03,s*2.16+.03,-.005,.03,.4,2.9) end   -- status strips on the door frames
    -- hazard paint across the threshold, inside the room and in the corridor
    for _,a in ipairs({{.25,.4},{-.55,-.4}}) do wallBox(hazard,"",-2.1,2.1,a[1],a[2],.004,.022) end
   end
  end
  local z=r.z-r.d/2+2
  while z<=r.z+r.d/2-2 do add(out,"ceiling",r.x-r.w/2+.2,r.x+r.w/2-.2,cy-.4,cy,z-.18,z+.18);z=z+4 end   -- beams
 end
 for _,l in ipairs(map.lights) do                                                    -- lamp hangers
  local r=map.rooms[l.room];if r then add(out,"ceiling",l.x-.035,l.x+.035,l.y+.45,r.h-.175,l.z-.035,l.z+.035) end
 end
 for _,edge in ipairs(map.links) do                                                  -- corridors
  local a,b=map.rooms[edge[1]],map.rooms[edge[2]]
  local alongX=a.x~=b.x
  local s0,s1=alongX and min(a.x,b.x) or min(a.z,b.z),alongX and max(a.x,b.x) or max(a.z,b.z)
  local c=alongX and a.z or a.x
  local function at(s,o) if alongX then return s,c+o else return c+o,s end end
  local runs,run={},nil
  for s=s0,s1-1 do
   local x,z=at(s+.5,0);local outside=not inRoom(map,x,z,.3)
   if outside and not run then run={s,s+1} elseif outside then run[2]=s+1 elseif run then runs[#runs+1]=run;run=nil end
  end
  if run then runs[#runs+1]=run end
  local function span(list,m,u0,u1,o0,o1,y0,y1)
   local xa,za=at(u0,o0);local xb,zb=at(u1,o1);add(list,m,xa,xb,y0,y1,za,zb)
  end
  for _,ru in ipairs(runs) do
   for _,o in ipairs({-1,1}) do
    span(out,"ceiling",ru[1],ru[2],o*1.62,o*1.78,3.52,3.68)                         -- pipe
    span(out,wallMat,ru[1],ru[2],o*1.975,o*2.075,0,.18)                              -- skirting
    local u=ru[1]+1.5
    while u<ru[2]-.5 do span(out,"ceiling",u-.04,u+.04,o*1.55,o*2.075,3.48,3.72);u=u+3 end   -- brackets
   end
   local u=ru[1]+.6
   while u+1.4<=ru[2] do span(strips,"",u,u+1.4,-.08,.08,3.965,3.995);u=u+2.5 end   -- ceiling light strips
  end
 end
 return out,strips,hazard
end
local function seeded(seed)
 local s=seed
 return function() s=(s*1103515245+12345)%2147483648;return s/2147483648 end
end
-- Translucent puddles (pbr tier only): flat, slightly irregular discs just above the floor.
local function puddles(map,area,b)
 for _,r in ipairs(map.rooms) do
  local rnd=seeded(map.chapter*131+r.id*17)
  for _=1,area.puddles do
   local cx,cz=r.x+(rnd()-.5)*(r.w-7),r.z+(rnd()-.5)*(r.d-7);local rad=.7+rnd()*.9
   if r.id==4 then cz=r.z+abs(cz-r.z) end   -- keep clear of room 4's raised deck and ramp (north half)
   local start=#b.v/3;b.v[#b.v+1]=cx;b.v[#b.v+1]=.008;b.v[#b.v+1]=cz;b.uv[#b.uv+1]=0;b.uv[#b.uv+1]=0
   for k=0,11 do
    local a=k/12*math.pi*2;local rr=rad*(.72+.28*rnd())*(k%2==0 and 1 or .9)
    b.v[#b.v+1]=cx+cos(a)*rr*1.3;b.v[#b.v+1]=.008;b.v[#b.v+1]=cz-sin(a)*rr;b.uv[#b.uv+1]=0;b.uv[#b.uv+1]=0
   end
   for k=0,11 do b.i[#b.i+1]=start+1;b.i[#b.i+1]=start+2+k;b.i[#b.i+1]=start+2+(k+1)%12 end
  end
 end
end
local function freeAll(list)for _,b in ipairs(list) do if b.mesh and b.mesh.free then b.mesh:free() end end end
function R.prepare(w)
 R.world=w
 freeAll(R.batches);R.batches={};freeAll(R.glow);R.glow={}
 if R.puddle and R.puddle.free then R.puddle:free() end;R.puddle=nil
 local groups={}
 local area=AREA[w.map.chapter] or AREA[1];R.area=area
 for _,l in ipairs(w.map.lights) do l.rgb=rgb(l.color) end
 -- the pbr tier draws every batch untinted, so it uses bigger cells (fewer draw calls); the basic tier tints each
 -- batch with its light and keeps the 1.4.0 cells
 local cell=fx.active() and 16 or 8
 local function get(material,x,y,z)
  local key=material..":"..floor(x/cell)..":"..floor(y/(cell>8 and 10 or 5))..":"..floor(z/cell)
  if not groups[key] then groups[key]=builder();groups[key].material=material end
  return groups[key]
 end
 for _,box in ipairs(w.map.boxes) do
  local x0,x1,y0,y1,z0,z1=box.x-box.w/2,box.x+box.w/2,box.y-box.h/2,box.y+box.h/2,box.z-box.d/2,box.z+box.d/2
  boxQuads(get(box.material,box.x,box.y,box.z),x0,x1,y0,y1,z0,z1)
 end
 for _,a in ipairs(w.map.ramps) do
  local b=get("grate",a.x,a.y,a.z);local x0,x1,z0,z1=a.x-a.w/2,a.x+a.w/2,a.z-a.d/2,a.z+a.d/2
  local yl,yh=a.y,a.y+a.rise
  if a.axis=="x" then
   quad(b,{x0,yl,z1},{x1,yh,z1},{x1,yh,z0},{x0,yl,z0},"y")
   quad(b,{x0,yl,z0},{x1,yl,z0},{x1,yh,z0},{x0,yl,z0},"z")
   quad(b,{x1,yl,z1},{x0,yl,z1},{x0,yl,z1},{x1,yh,z1},"z")
  else
   quad(b,{x0,yl,z1},{x1,yl,z1},{x1,yh,z0},{x0,yh,z0},"y")
   quad(b,{x0,yl,z0},{x0,yl,z1},{x0,yh,z0},{x0,yh,z0},"x")
   quad(b,{x1,yl,z1},{x1,yl,z0},{x1,yh,z0},{x1,yh,z0},"x")
  end
 end
 -- detail geometry and emissive strips: pbr tier only, the basic tier (Effects Low, GPUs without pbr) keeps the
 -- 1.4.0 level exactly (same meshes, same draw calls)
 local extra,strips,hazard={},{},{}
 if fx.active() then extra,strips,hazard=detail(w.map) end
 for _,e in ipairs(extra) do boxQuads(get(e[1],(e[2]+e[3])/2,(e[4]+e[5])/2,(e[6]+e[7])/2),e[2],e[3],e[4],e[5],e[6],e[7]) end
 for _,b in pairs(groups) do
  b.mesh=g3d.custom(b.v,b.i,nil,true,b.uv);b.mesh:setTexture("bundle:/textures/"..b.material..".png")
  fx.material(b.mesh,surface(b.material,area))
  b.x,b.y,b.z=(b.minX+b.maxX)/2,(b.minY+b.maxY)/2,(b.minZ+b.maxZ)/2
  b.radius=sqrt((b.maxX-b.minX)^2+(b.maxY-b.minY)^2+(b.maxZ-b.minZ)^2)/2
  b.light,b.nearest=pointLight(w,b.x,b.y,b.z,true)
  b.v,b.i,b.uv=nil,nil,nil
  R.batches[#R.batches+1]=b
 end
 -- emissive strips: one mesh per colour for the whole map (drawn unlit on the basic tier)
 for _,g in ipairs({{list=strips,color=w.map.style.color,strength=2.6},{list=hazard,color="#E0A050",strength=1.1}}) do
  if #g.list>0 then
   local b=builder()
   for _,e in ipairs(g.list) do boxQuads(b,e[2],e[3],e[4],e[5],e[6],e[7]) end
   b.mesh=g3d.custom(b.v,b.i,nil,true,b.uv);b.mesh:setColor(g.color)
   fx.material(b.mesh,{emissive=g.color,emissiveStrength=g.strength,roughness=.4})
   b.color=g.color;b.v,b.i,b.uv=nil,nil,nil
   R.glow[#R.glow+1]=b
  end
 end
 if fx.active() then
  local b=builder();puddles(w.map,area,b)
  if #b.i>0 then
   R.puddle=g3d.custom(b.v,b.i,nil,true,b.uv);R.puddle:setColor("#2A3238")
   fx.material(R.puddle,{metallic=0,roughness=.03,clearcoat=1,clearcoatRoughness=.02})
  end
 end
 -- accent lights of the map (pbr tier): terminals, relays, the core, the exit and the alarm over the locked gate
 local acc={};R.core=nil
 for _,a in ipairs(w.map.terminals) do acc[#acc+1]={x=a.x,y=1.35,z=a.z,color="#5FE3D8",i=6,r=4} end
 for _,a in ipairs(w.map.relays) do acc[#acc+1]={x=a.x,y=a.y+2,z=a.z,relay=a,i=6,r=5} end
 for _,a in ipairs(w.map.props) do if a.model=="core" then acc[#acc+1]={x=a.x,y=1.5,z=a.z,color="#E070C0",i=9,r=9};R.core=a end end
 acc[#acc+1]={x=w.map.exit.x,y=1.2,z=w.map.exit.z,color="#7FE0C8",i=6,r=6}
 local gate=w.map.doors[1]
 if gate then
  local room=w.map.rooms[gate.room];local ax,az=gate.x,gate.z
  if room then local dx,dz=room.x-gate.x,room.z-gate.z;local d=sqrt(dx*dx+dz*dz);if d>0 then ax,az=gate.x+dx/d*.6,gate.z+dz/d*.6 end end
  acc[#acc+1]={x=ax,y=3.75,z=az,color="#FF2A1E",i=10,r=10,alarm=gate}
  R.alarmAt={x=ax,y=3.75,z=az,gate=gate}
 else R.alarmAt=nil end
 R.accents=acc
 R.lampWorld=nil
end
-- Effects changed (Low <-> Medium/High): rebuild the level meshes for the other tier.
function R.reprepare() if R.world then R.prepare(R.world) end end
local NEUTRAL={196,203,205}
local function tint(w,x,y,z,base,near)
 if fx.active() then return NEUTRAL end   -- pbr tier: the real lights do the lighting (see setLights)
 local values=base or pointLight(w,x,y,z,false)
 local pulse=near and (.96+.04*sin(w.time*3+near.phase)) or 1
 local flash=0
 local beam=0
 if w.flashlight then
  local p=w.player;local dx,dy,dz=x-p.x,y-p.y-1.52,z-p.z;local distance=sqrt(dx*dx+dy*dy+dz*dz)
  if distance>.7 and distance<18 then
   local d=F.direction(p.yaw,p.pitch);local alignment=(dx*d.x+dy*d.y+dz*d.z)/distance
   if alignment>.84 then
    local ray={x=dx/distance,y=dy/distance,z=dz/distance}
    if F.ray(w,{x=p.x,y=p.y+1.52,z=p.z},ray,distance)>=distance-.5 then beam=((alignment-.84)/.16)^1.5*(1-distance/18)*.40 end
   end
  end
 end
 if w.muzzle>0 then
  local p=w.player;local d2=(x-p.x)^2+(y-p.y-1.5)^2+(z-p.z)^2
  if d2<65 then flash=(1-sqrt(d2)/8)*.32*w.muzzle/.065 end
 end
 return {min(255,floor((values[1]*pulse+flash+beam*.92)*255)),min(255,floor((values[2]*pulse+flash*.7+beam)*255)),min(255,floor((values[3]*pulse+flash*.4+beam)*255))}
end
-- Instancing (pbr tier): copies of one mesh with one tint go to g3d.drawInstanced at the end of the frame.
local queue={}
local order={}
local function enqueue(key,mesh,tint_,flags,x,y,z,rx,ry,rz,s)
 local q=queue[key]
 if not q then q={mesh=mesh,tint=tint_,flags=flags,list={}};queue[key]=q;order[#order+1]=key end
 local l=q.list;local n=#l
 l[n+1]=x;l[n+2]=y;l[n+3]=z;l[n+4]=rx or 0;l[n+5]=ry or 0;l[n+6]=rz or 0;l[n+7]=s or 1
end
local function flush()
 for _,key in ipairs(order) do
  local q=queue[key]
  if #q.list>0 then g3d.drawInstanced(q.mesh,q.list,q.tint,q.flags);R.drawCalls=R.drawCalls+math.ceil(#q.list/896) end
 end
 queue,order={},{}
end
function R.model(name,x,y,z,angle,scale,rx,rz,color,flags)
 local s=fx.active() and R.split[name]
 if s then for _,p in ipairs(s) do draw(p.mesh,x,y,z,rx,angle,rz,scale,scale,scale,color,flags) end
 else draw(R.models[name],x,y,z,rx,angle,rz,scale,scale,scale,color,flags) end
end
-- pbr tier: a model as instanced copies (untinted props, pickups, legs)
local function instModel(name,x,y,z,angle,scale,rx,rz,color)
 local s=R.split[name]
 -- one group per room: the OS picks the 8 lights of an instanced draw for the bounds of all its copies, so groups
 -- stay local (the room's lamps keep lighting its props)
 local room=R.world and inRoom(R.world.map,x,z,1)
 local cell=room and ":r"..room.id or ":c"
 if s then for _,p in ipairs(s) do enqueue(name..":"..p.part..cell,p.mesh,color,nil,x,y,z,rx,angle,rz,scale) end
 elseif R.models[name] then enqueue(name..cell,R.models[name],color,nil,x,y,z,rx,angle,rz,scale) end
end
function R.animate(w,dt,active)
 if not R.pool then return end
 if R.rigWorld~=w then R.rigWorld=w;R.rigs=setmetatable({},{__mode="k"});for _,pool in pairs(R.pool) do for _,s in ipairs(pool) do s.owner=nil;s.clip=nil end end end
 for _,e in ipairs(w.map.enemies) do
  local pool=R.pool[e.kind];local state=R.rigs[e]
  if pool and not state and e.alive then
   for _,s in ipairs(pool) do if not s.owner or not s.owner.alive and (s.owner.deadTime or 0)>1 then s.owner=e;s.clip=nil;R.rigs[e]=s;state=s;break end end
  end
  if state and state.owner==e then
   local clip=not e.alive and "Death" or ((e.state=="windup" or e.state=="attack") and "Attack" or (active and e.state=="chase" and "Run" or "Idle"))
   Native.animate(state,clip,dt,1,e.alive)
  end
 end
end
function R.close()
 if R.native then R.native:close() end;R.pool=nil;R.rigs={}
 freeAll(R.batches);R.batches={};freeAll(R.glow);R.glow={}
 if R.puddle and R.puddle.free then R.puddle:free() end;R.puddle=nil
 for _,m in pairs(R.models) do if m.free then m:free() end end;R.models={}
 for _,s in pairs(R.split) do for _,p in ipairs(s) do if p.mesh.free then p.mesh:free() end end end;R.split={}
 for _,m in pairs(R.lampMeshes or {}) do if m.free then m:free() end end;R.lampMeshes={}
 for _,name in ipairs({"box","ball","ring","halo","dome","tube","stripOpen","stripShut","alarm"}) do if R[name] then if R[name].free then R[name]:free() end;R[name]=nil end end
 R.world=nil
end
local function lift(hex,k)
 local c=rgb(hex);return string.format("#%02X%02X%02X",min(255,floor(c[1]*k+10)),min(255,floor(c[2]*k+10)),min(255,floor(c[3]*k+10)))
end
local function lampMesh(color)   -- emissive lamp fixture (pbr tier), one per lamp colour
 local m=R.lampMeshes[color]
 if not m then
  m=g3d.mesh("box",.3,.9,.18);m:setColor(color);fx.material(m,{emissive=color,emissiveStrength=5,roughness=.35})
  R.lampMeshes[color]=m
 end
 return m
end
local function visibleFrom(w,p,eyeY,x,y,z,d2)
 local dist=sqrt(d2);if dist<1 then return true end
 local dx,dy,dz=x-p.x,y-eyeY,z-p.z
 return F.ray(w,{x=p.x,y=eyeY,z=p.z},{x=dx/dist,y=dy/dist,z=dz/dist},dist)>=dist-.8
end
-- Real-time lights (pbr tier, at most 11 of the 16; the OS lights each draw with the 8 strongest near it, so usually
-- 9 are on and the accents are a bit stronger than a lamp but short-ranged): the 5 nearest ceiling lamps the player
-- can see, 2 accents
-- (terminals, relays, core, exit, alarm), the key spot over the player's room, the flashlight, muzzle flash and the
-- first projectile. The sets are re-chosen 5 times a second. Exactly one spot asks for the shadow: the flashlight at
-- Effects High while it is on, otherwise the room's key light.
local function setLights(w,p,eyeY,d,showcase)
 local lights=w.map.lights
 R.lampClock=(R.lampClock or 0)+1
 if R.lampWorld~=w or R.lampClock>=12 then
  R.lampWorld=w;R.lampClock=0
  local picked={}
  for i,l in ipairs(lights) do
   local d2=(l.x-p.x)^2+(l.y-eyeY)^2+(l.z-p.z)^2
   if d2<324 and visibleFrom(w,p,eyeY,l.x,l.y,l.z,d2) then picked[#picked+1]={i=i,d=d2} end
  end
  table.sort(picked,function(a,b) return a.d<b.d end)
  local now={};for n=1,min(5,#picked) do now[picked[n].i]=true end
  for i in pairs(R.lampOn or {}) do if not now[i] then fx.light("lamp"..i,nil) end end
  R.lampOn=now
  local acc={}
  for i,a in ipairs(R.accents or {}) do
   local d2=(a.x-p.x)^2+(a.y-eyeY)^2+(a.z-p.z)^2
   if d2<(a.r+6)^2 and (not a.alarm or not a.alarm.open) and visibleFrom(w,p,eyeY,a.x,a.y,a.z,d2) then acc[#acc+1]={i=i,d=d2} end
  end
  table.sort(acc,function(a,b) return a.d<b.d end)
  local on={};for n=1,min(2,#acc) do on[acc[n].i]=true end
  for i in pairs(R.accOn or {}) do if not on[i] then fx.light("acc"..i,nil) end end
  R.accOn=on
  local room=inRoom(w.map,p.x,p.z,0);R.keyRoom=room
 end
 for i in pairs(R.lampOn) do
  local l=lights[i]
  if l then
   local pulse=.9+.1*sin(w.time*2+l.phase)
   fx.light("lamp"..i,{type="point",x=l.x,y=l.y-.2,z=l.z,color=l.color,intensity=8*pulse,range=l.r})
  end
 end
 for i in pairs(R.accOn) do
  local a=R.accents[i]
  if a then
   local color,k=a.color,1
   if a.relay then color=a.relay.active and "#6FF0C8" or "#FF9A4A" end
   if a.alarm then k=.15+.85*max(0,sin(w.time*5))^2 elseif a.color=="#E070C0" then k=.85+.15*sin(w.time*1.7) end
   fx.light("acc"..i,{type="point",x=a.x,y=a.y,z=a.z,color=color,intensity=a.i*k,range=a.r})
  end
 end
 local area=R.area or AREA[1]
 local torchShadow=w.flashlight and fx.level>=3
 local room=R.keyRoom
 local key=room and {type="spot",x=room.x,y=room.h-.45,z=room.z,dx=0,dy=-1,dz=0,color=area.key,intensity=area.keyI*(room.h/6.5)^2,
  range=room.h+5,inner=38,outer=68,shadow=not torchShadow}
 local torch=w.flashlight and {type="spot",x=p.x+d.x*.3,y=eyeY-.1+d.y*.3,z=p.z+d.z*.3,dx=d.x,dy=d.y,dz=d.z,color="#EAF4F0",intensity=24,range=20,inner=9,outer=20,shadow=torchShadow}
 -- the light that gives the shadow up is updated first, so two spots never ask for it at once
 if torchShadow then fx.light("key",key);fx.light("torch",torch or nil) else fx.light("torch",torch or nil);fx.light("key",key) end
 if w.muzzle>0 and not showcase then
  fx.light("muzzle",{type="point",x=p.x+d.x*.9,y=eyeY-.15+d.y*.9,z=p.z+d.z*.9,color="#FFC37A",intensity=18*w.muzzle/.065,range=9})
 else fx.light("muzzle",nil) end
 local a=w.projectiles[1]
 fx.light("shot",a and {type="point",x=a.x,y=a.y,z=a.z,color=a.friendly and "#72DED3" or (a.kind=="void" and "#BA91EB" or "#EDAA74"),intensity=5,range=6} or nil)
end
function R.scene(w,width,height,showcase)
 local p=w.player;local d=F.direction(p.yaw,p.pitch)
 local eyeY=p.y+1.54+(p.grounded and sin(p.anim*1.8)*.025 or 0)
 local fov=showcase and 78 or 88-30*(p.ads or 0)+(p.dash>0 and 8 or 0)
 local pbr=fx.active()
 local area=AREA[w.map.chapter] or AREA[1]
 gfx.clear(w.map.style.fog)
 if R.envFor~=w.map.chapter then
  R.envFor=w.map.chapter
  local cube={};for _,f in ipairs({"px","nx","py","ny","pz","nz"}) do cube[#cube+1]="bundle:/textures/env/c"..w.map.chapter.."_"..f..".png" end
  -- indoors: no sun (its shadow map would be skipped anyway, the ceilings block it); ambient and reflections come
  -- from the chapter's interior probe
  fx.environment({sky=lift(w.map.style.fog,2.2),ground=w.map.style.fog,intensity=area.ambient,sun=0,cubemap=cube})
 end
 if pbr then
  local alarm=R.alarmAt and not R.alarmAt.gate.open and R.keyRoom and R.keyRoom.id==R.alarmAt.gate.room
  fx.area({exposure=area.exposure,bloom=area.bloom+(alarm and .015 or 0),threshold=area.threshold})
  setLights(w,p,eyeY,d,showcase)
 end
 g3d.begin(0,0,width,height,fov,.035,75)
 local sk=R.shake or 0   -- cosmetic aim jitter (Effects Medium and High), set by main.lua
 local jx,jy=sin(w.time*91)*sk*.1,cos(w.time*77)*sk*.1
 g3d.camera(p.x,eyeY,p.z,p.x+d.x*10+jx,eyeY+d.y*10+jy,p.z+d.z*10+jx)
 g3d.light(.30,.85,.42,.44+(w.muzzle>0 and .04 or 0),"#D6E5E5")
 if pbr then g3d.fog(w.map.style.fog,area.fog[1],min(area.fog[2],R.quality==2 and 65 or 44))
 else g3d.fog(w.map.style.fog,24,R.quality==2 and 65 or 44) end
 R.drawCalls=0
 local far=R.quality==2 and 62 or 42
 local function visible(x,y,z,r)
  local dx,dy,dz=x-p.x,y-eyeY,z-p.z
  local distance=sqrt(dx*dx+dy*dy+dz*dz)
  return distance<far+r and dx*d.x+dy*d.y+dz*d.z> -r
 end
 local before=R.drawCalls
 for _,b in ipairs(R.batches) do if visible(b.x,b.y,b.z,b.radius) then draw(b.mesh,0,0,0,0,0,0,1,1,1,tint(w,b.x,b.y,b.z,b.light,b.nearest)) end end
 R.batchCalls=R.drawCalls-before   -- statistics (tools/ash_mock_check.py)
 for _,b in ipairs(R.glow) do if pbr then draw(b.mesh,0,0,0) else draw(b.mesh,0,0,0,0,0,0,1,1,1,b.color,"unlit") end end
 if pbr and R.puddle then draw(R.puddle,0,0,0,0,0,0,1,1,1,"#FFFFFF9C") end
 for _,a in ipairs(w.map.props) do
  if visible(a.x,a.y+1,a.z,2.5) then
   if pbr then instModel(a.model,a.x,a.y,a.z,a.angle or 0,1,0,0,NEUTRAL) else R.model(a.model,a.x,a.y,a.z,a.angle or 0,1,0,0,tint(w,a.x,a.y+1,a.z)) end
  end
 end
 if pbr and R.core and visible(R.core.x,1.5,R.core.z,2.5) then   -- containment glass around the core
  draw(R.tube,R.core.x,1.55,R.core.z,0,0,0,1.75,3.4,1.75)
 end
 for _,a in ipairs(w.map.relays) do
  if visible(a.x,a.y+1,a.z,2) then
   R.model("relay",a.x,a.y,a.z,0,1,0,0,a.active and "#9EDFD0" or tint(w,a.x,a.y+1,a.z))
   draw(R.ball,a.x,a.y+2,a.z,0,0,0,.14,.14,.14,a.active and "#ACF2D2" or "#F0B88B","glow unlit")
   if pbr then draw(R.dome,a.x,a.y+2,a.z,0,0,0,.27,.27,.27) end
  end
 end
 for _,a in ipairs(w.map.terminals) do
  if visible(a.x,1,a.z,2) then if pbr then instModel("terminal",a.x,0,a.z,math.pi,1,0,0,NEUTRAL) else R.model("terminal",a.x,0,a.z,math.pi,1,0,0,tint(w,a.x,1,a.z)) end end
 end
 for _,a in ipairs(w.map.logs) do
  if not a.read and visible(a.x,a.y,a.z,1) then
   if pbr then instModel("datapad",a.x,a.y,a.z,w.time*.2,1,0,0,"#B7BDD1") else R.model("datapad",a.x,a.y,a.z,w.time*.2,1,0,0,"#B7BDD1") end
  end
 end
 for _,a in ipairs(w.map.pickups) do
  if not a.collected and visible(a.x,a.y,a.z,1) then
   local name=a.kind=="weapon" and "weapon"..a.weapon or a.kind
   local y,s=a.y+.06*sin(w.time*2+a.x),a.kind=="weapon" and .6 or 1
   if pbr then instModel(name,a.x,y,a.z,w.time*.4,s,0,0,"#E2D9BB") else R.model(name,a.x,y,a.z,w.time*.4,s,0,0,"#E2D9BB") end
  end
 end
 for _,a in ipairs(w.map.doors) do
  local yy=a.open and a.y+2.8 or a.y
  draw(R.box,a.x,yy,a.z,0,0,0,a.w,a.h,a.d,w.hasKey and "#588B91" or "#754F4B")
  for j=-1,1 do
   if pbr then enqueue(a.open and "stripOpen" or "stripShut",a.open and R.stripOpen or R.stripShut,nil,nil,a.x+j*.8,yy,a.z+.23,0,0,0,1)
   else draw(R.box,a.x+j*.8,yy,a.z+.23,0,0,0,.10,2.6,.025,a.open and "#87DDC1" or "#DCA776","unlit") end
  end
 end
 if pbr and R.alarmAt and not R.alarmAt.gate.open and sin(w.time*5)>0 and visible(R.alarmAt.x,R.alarmAt.y,R.alarmAt.z,1) then
  draw(R.alarm,R.alarmAt.x,R.alarmAt.y,R.alarmAt.z,0,w.time*3,0)
 end
 local egress=w.map.exit
 if visible(egress.x,1,egress.z,3) then
  draw(R.box,egress.x,.025,egress.z,0,0,0,4,.05,3,"#698E91")
  draw(R.ring,egress.x,1.8,egress.z,0,0,w.time*.15,1.1,1.1,1.1,"#8BBAAF","glow unlit")
 end
 for i,l in ipairs(w.map.lights) do
  if visible(l.x,l.y,l.z,1) then
   if pbr then
    enqueue("lamp"..l.color,lampMesh(l.color),nil,nil,l.x,l.y,l.z,0,0,0,1)
    if R.quality==2 then enqueue("halo"..l.color,R.halo,{floor(l.rgb[1]*.2+.5),floor(l.rgb[2]*.2+.5),floor(l.rgb[3]*.2+.5)},"glow unlit",l.x,l.y,l.z,0,0,0,1) end
   else
    local pulse=.90+.10*sin(w.time*2+l.phase)
    draw(R.box,l.x,l.y,l.z,0,0,0,.3,.9,.18,{floor(l.rgb[1]*pulse+.5),floor(l.rgb[2]*pulse+.5),floor(l.rgb[3]*pulse+.5)},"unlit")
    if R.quality==2 then draw(R.ball,l.x,l.y,l.z,0,0,0,.18,.55,.18,{floor(l.rgb[1]*.2+.5),floor(l.rgb[2]*.2+.5),floor(l.rgb[3]*.2+.5)},"glow unlit") end
   end
  end
 end
 for _,e in ipairs(w.map.enemies) do
  if (e.alive or e.deadTime<1) and visible(e.x,e.y+e.h/2,e.z,e.h) then
   local dead=not e.alive;local yy=e.y-(dead and min(.7,e.deadTime) or 0)
   local color=e.flash>0 and "#F2CFAC" or tint(w,e.x,e.y+1,e.z)
   local scale=e.kind=="drone" and .95 or 1
   local rig=R.rigs[e];if rig and rig.owner==e and (e.x-p.x)^2+(e.z-p.z)^2<400 then draw(rig.model,e.x,yy,e.z,0,e.angle,0,scale,scale,scale,color) else
   R.model(e.kind,e.x,yy+(e.kind=="drone" and .35 or 0),e.z,e.angle,scale,dead and min(1.3,e.deadTime*3) or 0,0,color)
   if e.kind=="stalker" or e.kind=="trooper" then
    local step=sin(e.anim*2)*.55
    for _,s in ipairs({-1,1}) do
     local x=e.x+s*.20*cos(e.angle);local z=e.z-s*.20*sin(e.angle)
     if pbr and e.flash<=0 then
      instModel("leg",x,yy+.72,z,e.angle,1,step*s,0,NEUTRAL)
      if e.kind=="stalker" then instModel("stalker_arm",e.x+s*.43*cos(e.angle),yy+1.35,e.z-s*.43*sin(e.angle),e.angle,1,-step*s,0,NEUTRAL) end
     else
      R.model("leg",x,yy+.72,z,e.angle,1,step*s,0,color)
      if e.kind=="stalker" then R.model("stalker_arm",e.x+s*.43*cos(e.angle),yy+1.35,e.z-s*.43*sin(e.angle),e.angle,1,-step*s,0,color) end
     end
    end
   end
   end
   if e.state=="windup" then draw(R.ball,e.x,e.y+e.h*.67,e.z-.2,0,0,0,.09,.09,.09,"#D88B65","glow unlit") end
  end
 end
 for _,a in ipairs(w.projectiles) do
  if visible(a.x,a.y,a.z,1) then
   local color=a.friendly and "#72DED3" or (a.kind=="void" and "#BA91EB" or "#EDAA74")
   draw(R.ball,a.x,a.y,a.z,0,0,0,a.r,a.r,a.r,color,"unlit glow")
  end
 end
 for _,a in ipairs(w.fx) do
  if a.kind=="spark" then g3d.point(a.x,a.y,a.z,a.life*36,"#F2C18A")
  else g3d.line(a.x,a.y,a.z,a.tx,a.ty,a.tz,a.kind=="rail" and "#B89CDE" or "#F0C695",a.kind=="rail" and 4 or 1) end
 end
 flush()
 if not showcase then
  local cs,sn=cos(p.yaw),sin(p.yaw)
  local bob=sin(p.anim*1.8)*.012
  local forward=.52
  if F.ray(w,{x=p.x,y=eyeY,z=p.z},d,1.2)<.9 then forward=.18 end
  local ads=p.ads or 0;local reload=w.reloadTimer>0 and math.sin((1-w.reloadTimer/w.reloadDuration)*math.pi) or 0
  local side=.27*(1-ads)+reload*.08
  local gx=p.x+cs*side+d.x*forward;local gy=eyeY-.29+.155*ads+bob*(1-ads*.8)-w.recoil*.2-reload*.18;local gz=p.z+sn*side+d.z*forward
  local ry,rx=-p.yaw,p.pitch+w.recoil+reload*.45
  R.model("weapon"..w.weapon,gx,gy,gz,ry,.43,rx,reload*.35,{235,240,230})
  R.model("glove",gx+cs*.02,gy-.14,gz+sn*.02,ry,.65,rx,0,"#B3BEBA")
  if w.weapon>1 then R.model("glove",gx-cs*.17+d.x*.20,gy-.09-reload*.15,gz-sn*.17+d.z*(.20-.20*reload),ry,.65,rx,0,"#B3BEBA") end
  if w.muzzle>0 then
   draw(R.ball,gx+d.x*.54,gy+d.y*.54,gz+d.z*.54,0,0,0,.10+w.muzzle,.10,.18,"#FFD49B","glow unlit")
  end
 end
 R.triangles=g3d.finish()
end
return R
