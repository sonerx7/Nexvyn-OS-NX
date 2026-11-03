local Native=require("game.native_models")
local R={meshes={},parts={},loaded=0,catalog=nil,islands={},triangles=0,quality=2}
local Quests=require("game.quests")
local fx=require("game.fx")
local sin,cos,sqrt,pi,abs=math.sin,math.cos,math.sqrt,math.pi,math.abs
local function meshDraw(m,x,y,z,rx,ry,rz,sx,sy,sz,tint,flags)
  if m then g3d.draw(m,x,y,z,rx or 0,ry or 0,rz or 0,sx or 1,sy or sx or 1,sz or sx or 1,tint,flags) end
end
-- PBR values (only used when the pbr renderer is active, see game/fx.lua). textures/pbr holds a normal map and an
-- ORM map (R occlusion, G roughness, B metallic) for the model atlas and for every ground texture; factors are 1
-- so the maps decide. Small pickups also glow into the bloom (their own metal/roughness values replace the ORM).
local PBR="bundle:/textures/pbr/"
local function maps(name,extra,noMetal)
  local t={normalMap=PBR..name.."_n.jpg",occlusionMap=PBR..name.."_orm.jpg",metallic=1,roughness=1,normalScale=1.3}
  if not noMetal then t.metalRoughMap=PBR..name.."_orm.jpg" end
  if extra then for k,v in pairs(extra) do t[k]=v end end
  return t
end
local GLOW={
  coin={emissive="#FFC864",emissiveStrength=1.5,metallic=.7,roughness=.35},
  star={emissive="#FFD27A",emissiveStrength=2.4,roughness=.4},
  key={emissive="#FFD27A",emissiveStrength=1.6,metallic=.6,roughness=.35},
  heart={emissive="#FF8FA0",emissiveStrength=1.3,roughness=.4},
  orb={emissive="#B7EDF0",emissiveStrength=1.6,roughness=.3},
  crystals={emissive="#9EE8F0",emissiveStrength=.9,roughness=.2,clearcoat=.6},
  lantern={emissive="#FFC070",emissiveStrength=1.8,roughness=.45},
  brazier={emissive="#FF9A4A",emissiveStrength=.8,roughness=.6},
}
-- Material parts (tools/pbr_assets_luma.py splits glowing / metal / glass triangles out of a model by vertex colour;
-- catalog.json lists them under "parts"). The body keeps the atlas maps; a part gets plain values, set once per mesh.
local WARM,TEAL="#FFD27A","#7DE8CE"
local PART={
  metal={maps("characters",{metallic=.9,roughness=.36,normalScale=1},true)},
  gold={maps("characters",{metallic=1,roughness=.28,emissive="#FFC864",emissiveStrength=.25,normalScale=.8},true)},
  glow={maps("characters",{emissive=WARM,emissiveStrength=2.2,roughness=.5,normalScale=.5},true)},
  glass={maps("characters",{emissive="#FFC070",emissiveStrength=.5,metallic=0,roughness=.06,clearcoat=1,clearcoatRoughness=.03,ior=1.5,normalScale=.3},true),{transmission=.45}},
  water={maps("characters",{emissive="#77C9CD",emissiveStrength=.12,metallic=0,roughness=.04,clearcoat=1,clearcoatRoughness=.02,ior=1.33,normalScale=.2},true),{transmission=.35}},
  roof={maps("characters",{metallic=0,roughness=.34,clearcoat=.6,clearcoatRoughness=.12},true)},
}
local PARTX={   -- per model overrides of the part defaults
  ["gate/glow"]={emissive=TEAL,emissiveStrength=2.4},["checkpoint/glow"]={emissive=TEAL,emissiveStrength=2.0},
  ["shrine/glow"]={emissive=TEAL,emissiveStrength=2.2},["switch/glow"]={emissive=TEAL,emissiveStrength=2.0},
  ["brazier/glow"]={emissive="#FF9A4A",emissiveStrength=2.8},["guardian/glow"]={emissive="#FFB070",emissiveStrength=2.4},
  ["bat/glow"]={emissive="#FFCB78",emissiveStrength=2.6},["beetle/glow"]={emissive="#FFCB78",emissiveStrength=2.6},
  ["house/glow"]={emissive=WARM,emissiveStrength=1.5},["tower/glow"]={emissive=WARM,emissiveStrength=2.2},
  ["scout/glow"]={emissive="#FFF0A8",emissiveStrength=2.0},["lantern/glass"]={emissive="#FFC070",emissiveStrength=2.4},
  ["cage/glass"]={emissive="#9DE5DA",emissiveStrength=.3},
}
local MAIN={   -- bodies whose glowing triangles are split out into a part
  lantern={metallic=.85,roughness=.5},brazier={metallic=.8,roughness=.55},switch={metallic=.7,roughness=.45},
}
local function partMaterial(model,part)
  local base=PART[part] or PART.metal
  local o,hi={},base[2]
  for k,v in pairs(base[1]) do o[k]=v end
  local x=PARTX[model.."/"..part]
  if x then for k,v in pairs(x) do o[k]=v end end
  return o,hi
end
local function loadMesh(file)
  local d=assert(json.decode(assert(fs.read(file))))
  local m=assert(g3d.custom(d.vertices,d.indices,d.colors,false,d.uvs))
  if d.texture then m:setTexture("bundle:/"..d.texture) end
  return m
end
function R.init()
  R.native=Native.new();R.heroRig=nil
  if g3d.loadModel then R.native:request("bundle:/models/luma-rig.glb",function(m) fx.material(m,maps("characters"));R.heroRig={model=m} end) end
  R.catalog=assert(json.decode(assert(fs.read("bundle:/models/catalog.json"))))
  R.box=g3d.mesh("cube",1);R.ball=g3d.mesh("sphere",1,10,6)
  R.disc=g3d.mesh("cylinder",1,.025,18)
  R.ring=g3d.mesh("torus",1,.035,32,5)
  R.lowTree=g3d.mesh("cone",1.0,2.8,8)
end
function R.loadNext()
  R.native:update();if R.native.error then error(R.native.error) end
  local item=R.catalog[R.loaded+1]
  if not item then return R.native:ready() end
  R.meshes[item.name]=loadMesh("bundle:/models/"..item.name..".json")
  local glow=MAIN[item.name] or GLOW[item.name]
  local crystalHi=item.name=="crystals" and {transmission=.4} or nil   -- glass look at Effects High only
  fx.material(R.meshes[item.name],glow and maps("characters",glow,true) or maps("characters"),crystalHi)
  if item.parts then
    local list={}
    for _,part in ipairs(item.parts) do
      local m=loadMesh("bundle:/models/"..item.name.."__"..part..".json")
      local o,hi=partMaterial(item.name,part)
      fx.material(m,o,hi)
      list[#list+1]=m
    end
    R.parts[item.name]=list
  end
  R.loaded=R.loaded+1
  return R.loaded>=#R.catalog and R.native:ready()
end
function R.model(name,x,y,z,angle,scale,rx,rz,tint,flags)
  meshDraw(R.meshes[name],x,y,z,rx,angle,rz,scale,scale,scale,tint,flags)
  local ps=R.parts[name]
  if ps then for i=1,#ps do meshDraw(ps[i],x,y,z,rx,angle,rz,scale,scale,scale,tint,flags) end end
end
-- Repeated props of one model go to the GPU in one call (g3d.drawInstanced; the basic renderer draws them one by one).
local function drawBatch(name,b)
  if b.n==1 then R.model(name,b[1],b[2],b[3],b[5],b[7]);return end
  if R.meshes[name] then g3d.drawInstanced(R.meshes[name],b) end
  local ps=R.parts[name]
  if ps then for i=1,#ps do g3d.drawInstanced(ps[i],b) end end
end

local function island(w,d,palette,kind,seed)
  local topData={v={},i={},c={},uv={}};local sideData={v={},i={},c={},uv={}}
  local target=topData
  local function vertex(x,y,z,col)
    local v,c,uv=target.v,target.c,target.uv
    v[#v+1]=x;v[#v+1]=y;v[#v+1]=z;c[#c+1]=col
    uv[#uv+1]=target==topData and x/2 or (x+z)/2;uv[#uv+1]=target==topData and z/2 or -y/2
    return #c
  end
  local function tri(a,b,e,col)
    local i=target.i
    i[#i+1]=vertex(a[1],a[2],a[3],col);i[#i+1]=vertex(b[1],b[2],b[3],col);i[#i+1]=vertex(e[1],e[2],e[3],col)
  end
  local hw,hd,cut=w/2,d/2,.5
  local outline={{-hw+cut,-hd},{hw-cut,-hd},{hw,-hd+cut},{hw,hd-cut},{hw-cut,hd},{-hw+cut,hd},{-hw,hd-cut},{-hw,-hd+cut}}
  local top=kind=="road" and "#CBB98E" or (kind=="ice" and "#CAE7EE" or (kind=="crumble" and "#D0AA86" or palette.ground))
  for k=1,8 do
    local a,b=outline[k],outline[k%8+1]
    target=topData
    tri({0,0,0},{b[1],0,b[2]},{a[1],0,a[2]},top)
    target=sideData
    local prevY,prevScale=0,1
    for layer=1,4 do
      local yy=({-.20,-.55,-2.4,-3.35})[layer]
      local scale=({1.025,1, .91,.56})[layer]
      local col=layer==1 and palette.edge or (layer==3 and palette.rock or "#807C80")
      local p={a[1]*prevScale,prevY,a[2]*prevScale};local q={b[1]*prevScale,prevY,b[2]*prevScale}
      local s={a[1]*scale,yy,a[2]*scale};local t={b[1]*scale,yy,b[2]*scale}
      tri(p,q,t,col);tri(p,t,s,col)
      prevY,prevScale=yy,scale
    end
    if kind~="ice" and kind~="road" then
      for j=1,3 do
        local t=j/4;local x,z=a[1]*(1-t)+b[1]*t,a[2]*(1-t)+b[2]*t
        tri({x-.07,0,z},{x+.07,0,z},{x,.17+(j%2)*.1,z-.03},palette.edge)
        tri({x+.07,0,z},{x-.07,0,z},{x,.17+(j%2)*.1,z-.03},palette.edge)
      end
    end
  end
  -- Small pale seams embedded in the side walls; baked into one draw call per island.
  for j=1,12 do
    local x=sin(j*12.9+seed)*hw*.85;local y=-.7-(j%4)*.38
    tri({x-.11,y,-hd-.01},{x+.15,y+.08,-hd-.01},{x+.06,y+.23,-hd-.01},palette.edge)
  end
  -- Small rocks scattered on the top (about 64 triangles per island, baked into the side mesh: no extra draw call).
  if kind~="road" and kind~="ice" then
    target=sideData
    local rc=palette.rock
    for j=1,8 do
      local x=sin(j*7.3+seed*2.1)*(hw-.9);local z=cos(j*5.1+seed*1.7)*(hd-.9)
      if x*x+z*z>2.4 then
        local r=.07+((j*37+seed*11)%7)*.012;local hgt=r*.9
        local P={{x-r,.01,z},{x,.01,z+r},{x+r,.01,z},{x,.01,z-r}};local peak={x+r*.15,hgt,z-r*.1}
        for k=1,4 do local a,b=P[k],P[k%4+1];tri(a,b,peak,rc);tri(b,a,{x,.01,z},rc) end
      end
    end
  end
  local topMesh=g3d.custom(topData.v,topData.i,topData.c,true,topData.uv)
  local sides=g3d.custom(sideData.v,sideData.i,sideData.c,true,sideData.uv)
  topMesh:setTexture("bundle:/textures/"..(kind=="road" and "stone" or (kind=="ice" and "glass" or "grass"))..".png")
  sides:setTexture("bundle:/textures/rock.png")
  local ground=kind=="road" and "stone" or (kind=="ice" and "glass" or "grass")
  fx.material(topMesh,kind=="ice" and maps("glass",{clearcoat=.7,clearcoatRoughness=.06,ior=1.31}) or maps(ground))
  fx.material(sides,maps("rock"))
  return {topMesh,sides}
end
function R.prepare(world)
  for _,island in ipairs(R.islands) do for _,m in ipairs(island) do if m.free then m:free() end end end
  R.islands={}
  for n,p in ipairs(world.def.platforms) do R.islands[n]=island(p.w,p.d,world.def.palette,p.kind,n) end
end

function R.hero(p,t,showcase)
  local speed=sqrt(p.vx*p.vx+p.vz*p.vz)
  local phase=p.anim*1.6
  local stride=p.grounded and math.min(1,speed/5)*.65 or .35
  local bob=p.grounded and abs(sin(phase*2))*.035 or 0
  local x,y,z=p.x,p.y+bob,p.z
  local angle=p.facing
  if p.formKind then R.model(p.formKind,x,y+.2,z,angle,1);R.model("star",x,y+1.7,z,t*2,.18);return end
  if R.heroRig then
    if p.invul>0 and math.floor(t*15)%2==0 then return end
    meshDraw(R.heroRig.model,x,y,z,0,angle,0,1,1,1)
    return
  end
  local cs,sn=cos(angle),sin(angle)
  local function part(name,ox,oy,oz,rx,rz)
    R.model(name,x+ox*cs+oz*sn,y+oy,z-ox*sn+oz*cs,angle,1,rx,rz)
  end
  if p.invul>0 and math.floor(t*15)%2==0 then return end
  local tilt=p.dash>0 and -.3 or (p.pound and .4 or 0)
  part("hero_body",0,0,0,tilt,showcase and sin(t*1.5)*.025 or 0)
  local a=p.grounded and sin(phase)*stride or -.5
  part("hero_arm_l",-.39,1.22,0,-a, -.08)
  part("hero_arm_r",.39,1.22,0,a,.08)
  part("hero_leg_l",-.17,.56,0,a,0)
  part("hero_leg_r",.17,.56,0,-a,0)
end

function R.animate(p,dt,active)
  if not R.heroRig then return end
  local speed=sqrt(p.vx*p.vx+p.vz*p.vz)
  local clip=p.dash>0 and "Dash" or (not p.grounded and "Jump" or (active and speed>.3 and "Run" or "Idle"))
  Native.animate(R.heroRig,clip,dt,clip=="Run" and math.max(.6,speed/5) or 1)
end
function R.close()
 if R.native then R.native:close() end;R.heroRig=nil
 for _,island in ipairs(R.islands) do for _,m in ipairs(island) do if m.free then m:free() end end end;R.islands={}
 for _,m in pairs(R.meshes) do if m.free then m:free() end end;R.meshes={}
 for _,list in pairs(R.parts) do for _,m in ipairs(list) do if m.free then m:free() end end end;R.parts={}
 for _,name in ipairs({"box","ball","disc","ring","lowTree"}) do if R[name] then if R[name].free then R[name]:free() end;R[name]=nil end end
end
-- Real-time lights (pbr tier only): the explorer's glow, the two nearest stars, gate, guardian, fire, checkpoint, lava.
local function nearer(d,best) return d<best end
-- model -> {colour, height, intensity, flicker, range}
local EMIT={
  lantern={"#FFC070",1.2,3.2,true,6},brazier={"#FF9A4A",1.0,4,true,7},crystals={"accent",.8,2.6,false,6},
  shrine={"#7DE8CE",1.4,3,false,6.5},tower={"#FFD27A",3.2,3.5,false,8},fountain={"#77C9CD",.9,2.6,false,6},
}
local function setLights(world,cam)
  local def,p,t=world.def,world.player,world.time
  fx.light("hero",{type="point",x=p.x,y=p.y+1.9,z=p.z,color="#FFE6BC",intensity=2.2,range=6.5})
  local d1,d2,x1,y1,z1,x2,y2,z2=900,900
  for _,item in ipairs(def.stars) do
    if not item.collected and Quests.available(world,item) then
      local b=def.platforms[item.platform];local x,y,z=b.x+item.dx,b.y+item.dy+.4,b.z+item.dz
      local d=(x-p.x)^2+(z-p.z)^2
      if nearer(d,d1) then d2,x2,y2,z2=d1,x1,y1,z1;d1,x1,y1,z1=d,x,y,z elseif nearer(d,d2) then d2,x2,y2,z2=d,x,y,z end
    end
  end
  fx.light("star1",x1 and {type="point",x=x1,y=y1,z=z1,color="#FFD58A",intensity=4,range=6} or nil)
  fx.light("star2",x2 and {type="point",x=x2,y=y2,z=z2,color="#FFD58A",intensity=4,range=6} or nil)
  local goal=def.goal
  if (goal.z-p.z)^2<1600 then
    local open=world.stars>=2 and (not def.adventure or world.switchCount==3) and (not def.boss or def.boss.hp<=0)
    fx.light("goal",{type="point",x=goal.x,y=goal.y+1.8,z=goal.z,color=open and "#7DE8CE" or "#9093B0",intensity=open and 6 or 2.5,range=9})
  else fx.light("goal",nil) end
  local boss=def.boss
  fx.light("boss",boss and boss.hp>0 and (boss.z-p.z)^2<1600 and {type="point",x=boss.x,y=boss.y+3,z=boss.z,color="#FFB38F",intensity=7,range=13} or nil)
  local fire
  for _,a in ipairs(def.hazards) do
    if a.kind=="beam" or a.kind=="brazier" then
      local b=def.platforms[a.platform]
      if b.active and (b.z-p.z)^2+(b.x-p.x)^2<900 then fire={type="point",x=b.x+a.dx,y=b.y+1,z=b.z+a.dz,color="#FF9A5A",intensity=4.5+math.sin(t*9)*.5,range=7};break end
    end
  end
  fx.light("fire",fire)
  local cp
  for _,c in ipairs(def.checkpoints) do if (c.z-p.z)^2+(c.x-p.x)^2<400 then cp={type="point",x=c.x,y=c.y+1.6,z=c.z,color=c.index<=world.checkpoint and "#8FE8D0" or "#9AA6C0",intensity=2.5,range=5.5};break end end
  fx.light("check",cp)
  -- Accent lights: the two nearest glowing props (lanterns, braziers, crystals, shrines, towers, fountains).
  local n1,n2,e1,e2=900,900
  for _,a in ipairs(def.props) do
    local e=EMIT[a.model]
    if e then
      local b=def.platforms[a.platform]
      if b.active then
        local d=(a.x-p.x)^2+(a.z-p.z)^2
        if d<n1 then n2,e2=n1,e1;n1=d;e1={a,e,b} elseif d<n2 then n2=d;e2={a,e,b} end
      end
    end
  end
  for i,hit in ipairs({e1 or false,e2 or false}) do
    local name="accent"..i
    if hit then
      local a,e,b=hit[1],hit[2],hit[3]
      fx.light(name,{type="point",x=a.x+(b.x-b.ox),y=a.y+(b.y-b.oy)+e[2]*a.scale,z=a.z+(b.z-b.oz),color=e[1]=="accent" and def.palette.accent or e[1],intensity=e[3]+(e[4] and sin(t*7+i)*.4 or 0),range=e[5]})
    else fx.light(name,nil) end
  end
  fx.light("lava",def.lava and {type="point",x=p.x,y=math.max(-7,cam and cam.y-10 or -7)+.6,z=p.z,color="#FF7A4A",intensity=6,range=12} or nil)
end
-- Mood per world (pbr tier only): sun colour, ambient, exposure, bloom, fog length. The sky probe in textures/env
-- (tools/pbr_assets_luma.py) is made from the same palette; its sun matches g3d.light's direction.
local MOOD={
  {sun="#FFF1D6",amb=.48,exp=1.05,bloom=.05,thr=1,envSun=2.4,fog=1},
  {sun="#FFE0AE",amb=.42,exp=1.10,bloom=.05,thr=1.05,envSun=2.9,fog=.95},
  {sun="#FFF6E6",amb=.50,exp=1.05,bloom=.06,thr=1,envSun=2.5,fog=1.05},
  {sun="#E9CFF2",amb=.55,exp=1.00,bloom=.08,thr=.9,envSun=1.9,fog=.8},
  {sun="#FFEBCB",amb=.48,exp=1.05,bloom=.05,thr=1,envSun=2.4,fog=1},
  {sun="#F3F6FF",amb=.55,exp=.98,bloom=.05,thr=1.1,envSun=2.2,fog=.75},
  {sun="#FFC890",amb=.45,exp=1.08,bloom=.07,thr=.95,envSun=2.6,fog=.9},
  {sun="#BDC9F5",amb=.50,exp=.95,bloom=.08,thr=.9,envSun=1.7,fog=.8},
  {sun="#FFB080",amb=.40,exp=1.00,bloom=.09,thr=.85,envSun=1.8,fog=.65},
  {sun="#C9D2FF",amb=.50,exp=.95,bloom=.08,thr=.9,envSun=1.6,fog=.8},
}
function R.scene(world,cam,w,h,mode)
  local def,p,t=world.def,world.player,world.time
  local pal=def.palette
  local quality=R.quality
  local distance=quality==2 and 66 or 43
  if not g3d.gpu() then distance=25;quality=0 end
  gfx.gradient(0,0,w,h,pal.sky,pal.horizon,false)
  -- Soft sun and its halo are 2D behind the 3D pass, avoiding far clipping artifacts.
  gfx.color("#FFF0C128");gfx.circle(w*.76,h*.20,h*.11)
  gfx.color("#FFEBCB");gfx.circle(w*.76,h*.20,h*.055)
  if R.envFor~=def.number then
    R.envFor=def.number
    local m=MOOD[def.number] or MOOD[1]
    local cube={}
    for _,f in ipairs({"px","nx","py","ny","pz","nz"}) do cube[#cube+1]="bundle:/textures/env/w"..def.number.."_"..f..".png" end
    fx.environment({sky=pal.sky,ground=pal.rock,intensity=.8,sun=m.envSun,cubemap=cube})
    fx.mood({exposure=m.exp,bloom=m.bloom,threshold=m.thr})
  end
  local mood=fx.active() and (MOOD[def.number] or MOOD[1]) or nil
  if fx.active() then setLights(world,cam) end
  g3d.begin(0,0,w,h,58,.12,110)
  local cp=cos(cam.pitch)
  local ex=cam.x+sin(cam.yaw)*cam.distance*cp
  local ey=cam.y+sin(cam.pitch)*cam.distance
  local ez=cam.z+cos(cam.yaw)*cam.distance*cp
  local shake=R.shake or 0   -- cosmetic camera shake (Effects Medium and High), set by main.lua
  if shake>0 then ex=ex+sin(t*83)*shake*.16;ey=ey+cos(t*71)*shake*.12 end
  g3d.camera(ex,ey,ez,cam.x,cam.y,cam.z)
  g3d.light(-.55,1,.45,mood and mood.amb or .48,mood and mood.sun or "#FFF3DD")
  local fogK=mood and mood.fog or 1
  g3d.fog(pal.horizon,distance*.55*fogK,distance+18)
  if def.number==3 or def.number==6 then
    meshDraw(R.box,0,-3.8,-45,0,0,0,160,.12,160,def.number==3 and "#6BBAC7" or "#82B6C7")
    for j=1,12 do local z=-100+j*11;g3d.line(-50,-3.71,z,60,-3.71,z,"#ACDAD8",1) end
  end
  -- Distant cloud banks and miniature floating islands give depth to the route.
  if quality>0 then
    for j=1,9 do
      local z=math.floor(p.z/28)*28+36-j*14
      local x=sin(j*3.7)*24+(j%2==0 and 24 or -24)
      local yy=cam.y-5+sin(j*1.7)*7
      R.model("cloud",x,yy,z,t*.008,3.8+(j%3))
      meshDraw(R.lowTree,x*1.6,yy-8,z-8,pi,0,0,3,3,3,pal.rock)
    end
  end
  if def.lava then
    for j=0,6 do
      local z=math.floor(p.z/16)*16+32-j*16
      local yy=math.max(-7,cam.y-10)
      meshDraw(R.box,0,yy,z,0,0,0,65,.18,16,"#DB735C","unlit")
      for k=1,4 do meshDraw(R.ball,sin(j*4+k*3)*24,yy+.1,z+cos(k*4)*6,0,0,0,.8,.1,.8,"#FFC180","glow unlit") end
    end
  end
  for n,b in ipairs(def.platforms) do
    if b.active and abs(b.z-p.z)<distance and abs(b.x-p.x)<distance then
      local shake=b.kind=="crumble" and b.crumble>0 and sin(t*65)*.04 or 0
      for _,mesh in ipairs(R.islands[n]) do meshDraw(mesh,b.x+shake,b.y+(b.road and .025 or 0),b.z) end
      if b.kind=="spring" then R.model("spring",b.x,b.y,b.z,0,1)
      elseif b.kind=="conveyor" then
        for j=-1,1 do meshDraw(R.box,b.x+j*.9,b.y+.025,b.z,0,0,-.4,.07,.035,3.8,"#EAD3A0") end
      elseif b.kind=="moveX" or b.kind=="moveY" or b.kind=="moveZ" then
        meshDraw(R.disc,b.x,b.y-3.35,b.z,0,0,0,1.1,1,1.1,pal.accent,"unlit")
      elseif b.kind=="crumble" then
        for j=1,3 do g3d.line(b.x-1.5,b.y+.015,b.z+j*.6-1.2,b.x+1.4,b.y+.015,b.z+j*.6-1.6,"#9A796A",2) end
      end
    end
  end
  if quality>0 then
    local batches,order={},{}
    for _,a in ipairs(def.props) do
      local d2=(a.x-p.x)^2+(a.z-p.z)^2
      if d2<distance*distance and (quality==2 or d2<24*24) then
        local b=def.platforms[a.platform]
        if b.active then
          local x,y,z=a.x+(b.x-b.ox),a.y+(b.y-b.oy),a.z+(b.z-b.oz)
          if d2<38*38 then
            local model=a.model=="cage" and def.cage and def.cage.opened and "scout" or a.model
            local bt=batches[model]
            if not bt then bt={n=0};batches[model]=bt;order[#order+1]=model end
            local k=bt.n*7;bt[k+1]=x;bt[k+2]=y;bt[k+3]=z;bt[k+4]=0;bt[k+5]=a.angle;bt[k+6]=0;bt[k+7]=a.scale;bt.n=bt.n+1
            if a.model=="windmill" then R.model("windmill_blades",x+sin(a.angle)*.82*a.scale,y+2.7*a.scale,z+cos(a.angle)*.82*a.scale,a.angle,a.scale,0,t*.8) end
          elseif a.model=="house" or a.model=="tower" or a.model=="ship" then
            R.model(a.model,x,y,z,a.angle,a.scale)
          elseif a.model=="tree" or a.model=="palm" then
            meshDraw(R.box,x,y+1,z,0,0,0,.25,2,.25,"#997352")
            meshDraw(R.ball,x,y+2.7,z,0,0,0,1.1,.85,1.1,pal.ground)
          elseif a.model=="pine" then meshDraw(R.lowTree,x,y+1.5,z,0,a.angle,0,.8,1,.8,pal.edge) end
        end
      end
    end
    for _,name in ipairs(order) do drawBatch(name,batches[name]) end
  end
  for _,item in ipairs(def.coins) do
    if not item.collected then
      local b=def.platforms[item.platform]
      if b.active and abs(b.z-p.z)<distance*.7 then R.model("coin",b.x+item.dx,b.y+item.dy+sin(t*3+item.id)*.09,b.z+item.dz,t*2.2,1) end
    end
  end
  for _,item in ipairs(def.stars) do
    local b=def.platforms[item.platform]
    if not item.collected and Quests.available(world,item) and abs(b.z-p.z)<distance then
      local y=b.y+item.dy+sin(t*2)*.13
      R.model("star",b.x+item.dx,y,b.z+item.dz,t,1)
      if quality==2 then meshDraw(R.ring,b.x+item.dx,y,b.z+item.dz,pi*.5,t*.5,0,.70,.70,.70,"#B7965D","glow unlit") end
    end
  end
  for _,cp2 in ipairs(def.checkpoints) do
    if abs(cp2.z-p.z)<distance then R.model("checkpoint",cp2.x,cp2.y,cp2.z,0,1,0,0,cp2.index<=world.checkpoint and "#FFFFFF" or "#BCC9D5") end
  end
  for _,box in ipairs(def.crates) do
    local b=def.platforms[box.platform]
    if not box.broken and b.active and abs(b.z-p.z)<distance*.7 then R.model("crate",b.x+box.dx,b.y,b.z+box.dz,0,1) end
  end
  for _,e in ipairs(def.enemies) do
    if e.alive and abs(e.z-p.z)<distance*.65 then
      local b=def.platforms[e.platform]
      if b.active then
        meshDraw(R.disc,e.x,b.y+.015,e.z,0,0,0,.5,1,.4,"#3E536A66")
        local model=e.kind=="mimic" and e.state=="patrol" and "crate" or e.kind
        local tint=e.flash>0 and "#FFF1CE" or nil
        R.model(model,e.x,e.y,e.z,e.angle or 0,.9,0,e.kind=="bat" and sin(t*10)*.15 or 0,tint)
        if e.state=="windup" or e.state=="stunned" then
          meshDraw(R.ring,e.x,b.y+.04,e.z,pi/2,0,0,1.2,1.2,1.2,e.state=="stunned" and "#8AE6CF" or "#FF9B85","glow unlit")
          if e.state=="windup" then g3d.line(e.x,b.y+.03,e.z,e.x+(e.chargeX or 0)*6,b.y+.03,e.z+(e.chargeZ or 0)*6,"#FFB18A",3) end
        end
      end
    end
  end
  for _,a in ipairs(world.projectiles) do
    meshDraw(R.ball,a.x,a.y,a.z,0,0,0,.19,.19,.19,a.reflected and "#85E8CB" or "#FFAD85","unlit")
  end
  for _,s in ipairs(def.switches or {}) do
    local b=def.platforms[s.platform]
    if abs(b.z-p.z)<distance then
      R.model("switch",b.x+s.dx,b.y,b.z+s.dz,0,1,0,0,s.active and "#8FE8BD" or "#FFFFFF")
      if not s.active then R.model("star",b.x+s.dx,b.y+1.5,b.z+s.dz,t,.22) end
    end
  end
  for _,k in ipairs(def.keys or {}) do
    local b=def.platforms[k.platform]
    if not k.collected and abs(b.z-p.z)<distance then R.model("key",b.x+k.dx,b.y+1.2+sin(t*2)*.12,b.z+k.dz,t,1.4) end
  end
  for _,a in ipairs(def.hazards) do
    local b=def.platforms[a.platform]
    if b.active and abs(b.z-p.z)<distance*.6 then
      if a.kind=="beam" then
        local angle=t*.7+a.phase
        meshDraw(R.box,b.x+a.dx,b.y+.4,b.z+a.dz,0,angle,0,a.radius*2,.18,.18,"#FFB681","unlit")
        R.model("brazier",b.x+a.dx,b.y,b.z+a.dz,0,.6)
      elseif a.kind=="vent" then
        local active=sin(t*1.7+a.phase)>.3
        meshDraw(R.ring,b.x+a.dx,b.y+.04,b.z+a.dz,pi/2,0,0,a.radius,a.radius,a.radius,active and "#E6C48D" or "#91C6C8","unlit")
        if active then meshDraw(R.ball,b.x+a.dx,b.y+.45,b.z+a.dz,0,0,0,1.3,.6,1.3,def.number==3 and "#A5E0E8" or "#C7B6D9") end
      else R.model(a.kind,b.x+a.dx,b.y,b.z+a.dz,0,1) end
    end
  end
  local boss=def.boss
  if boss and boss.hp>0 and abs(boss.z-p.z)<distance then
    local angle=math.atan(p.x-boss.x,p.z-boss.z)
    local lean=boss.state=="rest" and .16 or 0
    R.model("guardian",boss.x,boss.y,boss.z,angle,1,lean,0)
    for _,s in ipairs({-1,1}) do
      R.model("guardian_arm",boss.x+s*1.1*cos(angle),boss.y+2,boss.z-s*1.1*sin(angle),angle,1,boss.state=="charge" and -1.9 or .1,0)
    end
    if boss.state=="wave" then meshDraw(R.ring,boss.x,boss.y+.12,boss.z,pi/2,0,0,boss.radius,boss.radius,boss.radius,"#FFC98B","glow unlit") end
    if boss.state=="rest" then R.model("star",boss.x,boss.y+3.8,boss.z,t*2,.42) end
  end
  for _,sp in ipairs(def.spirits or {}) do
    local b=def.platforms[sp.platform];local xx,yy,zz=b.x+sp.dx,b.y+.3+sin(t*2+sp.dx)*.12,b.z+sp.dz
    if abs(zz-p.z)<distance then R.model(sp.kind,xx,yy,zz,t*.3,.68);meshDraw(R.ring,xx,b.y+.08,zz,pi/2,0,t,.8,.8,.8,"#B7EDD7","unlit glow");R.model("star",xx,yy+1.25,zz,t,.16) end
  end
  if world.cap then local a=world.cap;R.model("star",a.x,a.y,a.z,t*16,.32);meshDraw(R.ring,a.x,a.y,a.z,pi/2,0,t*8,.4,.4,.4,"#FFE3A1","unlit glow") end
  local goal=def.goal
  if abs(goal.z-p.z)<distance then
    R.model("gate",goal.x,goal.y,goal.z,0,1)
    local tint=world.stars>=2 and (not def.adventure or world.switchCount==3) and (not boss or boss.hp<=0) and "#7DE8CE" or "#9093B0"
    meshDraw(R.ring,goal.x,goal.y+1.5,goal.z,0,0,t*.25,1.02,1.02,1.02,tint,"glow unlit")
    if quality>0 then
      for j=1,8 do local a=j*pi/4+t;g3d.point(goal.x+cos(a)*.8,goal.y+1.5+sin(a)*.8,goal.z,3,tint) end
    end
  end
  -- Ground shadow remains at the support surface; it never follows the feet into the air.
  local shadowY=nil
  for _,b in ipairs(def.platforms) do
    if b.active and abs(p.x-b.x)<b.w/2 and abs(p.z-b.z)<b.d/2 and b.y<=p.y+.1 then shadowY=math.max(shadowY or -100,b.y) end
  end
  if shadowY then meshDraw(R.disc,p.x,shadowY+.025,p.z,0,0,0,.48,1,.36,"#364A6166") end
  R.hero(p,t,mode=="title")
  for _,a in ipairs(world.particles) do g3d.point(a.x,a.y,a.z,math.max(1,a.life*6),a.kind=="stomp" and "#C6EFF0" or "#FFD68C") end
  R.triangles=g3d.finish()
end
return R
