local R={meshes={},loaded=0,catalog=nil,islands={},triangles=0,quality=2}
local Quests=require("game.quests")
local sin,cos,sqrt,pi,abs=math.sin,math.cos,math.sqrt,math.pi,math.abs
local function meshDraw(m,x,y,z,rx,ry,rz,sx,sy,sz,tint,flags)
  if m then g3d.draw(m,x,y,z,rx or 0,ry or 0,rz or 0,sx or 1,sy or sx or 1,sz or sx or 1,tint,flags) end
end
function R.init()
  R.catalog=assert(json.decode(assert(fs.read("bundle:/models/catalog.json"))))
  R.box=g3d.mesh("cube",1);R.ball=g3d.mesh("sphere",1,10,6)
  R.disc=g3d.mesh("cylinder",1,.025,18)
  R.ring=g3d.mesh("torus",1,.035,32,5)
  R.lowTree=g3d.mesh("cone",1.0,2.8,8)
end
function R.loadNext()
  local item=R.catalog[R.loaded+1]
  if not item then return true end
  local d=assert(json.decode(assert(fs.read("bundle:/models/"..item.name..".json"))))
  R.meshes[item.name]=assert(g3d.custom(d.vertices,d.indices,d.colors,false,d.uvs))
  if d.texture then R.meshes[item.name]:setTexture("bundle:/"..d.texture) end
  R.loaded=R.loaded+1
  return R.loaded>=#R.catalog
end
function R.model(name,x,y,z,angle,scale,rx,rz,tint,flags)
  meshDraw(R.meshes[name],x,y,z,rx,angle,rz,scale,scale,scale,tint,flags)
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
  local topMesh=g3d.custom(topData.v,topData.i,topData.c,true,topData.uv)
  local sides=g3d.custom(sideData.v,sideData.i,sideData.c,true,sideData.uv)
  topMesh:setTexture("bundle:/textures/"..(kind=="road" and "stone" or (kind=="ice" and "glass" or "grass"))..".png")
  sides:setTexture("bundle:/textures/rock.png")
  return {topMesh,sides}
end
function R.prepare(world)
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
  g3d.begin(0,0,w,h,58,.12,110)
  local cp=cos(cam.pitch)
  local ex=cam.x+sin(cam.yaw)*cam.distance*cp
  local ey=cam.y+sin(cam.pitch)*cam.distance
  local ez=cam.z+cos(cam.yaw)*cam.distance*cp
  g3d.camera(ex,ey,ez,cam.x,cam.y,cam.z)
  g3d.light(-.55,1,.45,.48,"#FFF3DD")
  g3d.fog(pal.horizon,distance*.55,distance+18)
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
    for _,a in ipairs(def.props) do
      local d2=(a.x-p.x)^2+(a.z-p.z)^2
      if d2<distance*distance and (quality==2 or d2<24*24) then
        local b=def.platforms[a.platform]
        if b.active then
          local x,y,z=a.x+(b.x-b.ox),a.y+(b.y-b.oy),a.z+(b.z-b.oz)
          if d2<38*38 then
            local model=a.model=="cage" and def.cage and def.cage.opened and "scout" or a.model
            R.model(model,x,y,z,a.angle,a.scale)
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
