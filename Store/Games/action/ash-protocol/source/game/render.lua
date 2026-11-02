local F=require("game.physics")
local R={models={},catalog={},loaded=0,batches={},quality=2,drawCalls=0,triangles=0}
local sin,cos,sqrt,min,max,floor=math.sin,math.cos,math.sqrt,math.min,math.max,math.floor
local function rgb(c)return {tonumber(c:sub(2,3),16),tonumber(c:sub(4,5),16),tonumber(c:sub(6,7),16)}end
local function draw(mesh,x,y,z,rx,ry,rz,sx,sy,sz,color,flags)
 if mesh then g3d.draw(mesh,x,y,z,rx or 0,ry or 0,rz or 0,sx or 1,sy or sx or 1,sz or sx or 1,color,flags);R.drawCalls=R.drawCalls+1 end
end
function R.init()
 R.catalog=assert(json.decode(assert(fs.read("bundle:/models/catalog.json"))))
 R.box=g3d.mesh("cube",1);R.ball=g3d.mesh("sphere",1,10,7);R.ring=g3d.mesh("torus",1,.035,28,5)
end
function R.loadNext()
 local a=R.catalog[R.loaded+1];if not a then return true end
 local d=assert(json.decode(assert(fs.read("bundle:/models/"..a.name..".json"))))
 local m=g3d.custom(d.vertices,d.indices,d.colors,false,d.uvs)
 m:setTexture("bundle:/"..d.texture);R.models[a.name]=m;R.loaded=R.loaded+1
 return R.loaded>=#R.catalog
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
function R.prepare(w)
 local groups={}
 for _,l in ipairs(w.map.lights) do l.rgb=rgb(l.color) end
 local function get(material,x,y,z,room)
  local key=material..":"..floor(x/8)..":"..floor(y/5)..":"..floor(z/8)
  if not groups[key] then groups[key]=builder();groups[key].material=material end
  return groups[key]
 end
 for _,box in ipairs(w.map.boxes) do
  local x0,x1,y0,y1,z0,z1=box.x-box.w/2,box.x+box.w/2,box.y-box.h/2,box.y+box.h/2,box.z-box.d/2,box.z+box.d/2
  local b=get(box.material,box.x,box.y,box.z,box.room)
  quad(b,{x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},"z")
  quad(b,{x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},"z")
  quad(b,{x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},"x")
  quad(b,{x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},"x")
  quad(b,{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},{x0,y1,z0},"y")
  quad(b,{x0,y0,z0},{x1,y0,z0},{x1,y0,z1},{x0,y0,z1},"y")
 end
 for _,a in ipairs(w.map.ramps) do
  local b=get("grate",a.x,a.y,a.z,a.room);local x0,x1,z0,z1=a.x-a.w/2,a.x+a.w/2,a.z-a.d/2,a.z+a.d/2
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
 R.batches={}
 for _,b in pairs(groups) do
  b.mesh=g3d.custom(b.v,b.i,nil,true,b.uv);b.mesh:setTexture("bundle:/textures/"..b.material..".png")
  b.x,b.y,b.z=(b.minX+b.maxX)/2,(b.minY+b.maxY)/2,(b.minZ+b.maxZ)/2
  b.radius=sqrt((b.maxX-b.minX)^2+(b.maxY-b.minY)^2+(b.maxZ-b.minZ)^2)/2
  b.light,b.nearest=pointLight(w,b.x,b.y,b.z,true)
  b.v,b.i,b.uv=nil,nil,nil
  R.batches[#R.batches+1]=b
 end
end
local function tint(w,x,y,z,base,near)
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
function R.model(name,x,y,z,angle,scale,rx,rz,color,flags)
 draw(R.models[name],x,y,z,rx,angle,rz,scale,scale,scale,color,flags)
end
function R.scene(w,width,height,showcase)
 local p=w.player;local d=F.direction(p.yaw,p.pitch)
 local eyeY=p.y+1.54+(p.grounded and sin(p.anim*1.8)*.025 or 0)
 local fov=showcase and 78 or 88+(p.dash>0 and 8 or 0)
 gfx.clear(w.map.style.fog)
 g3d.begin(0,0,width,height,fov,.035,75)
 g3d.camera(p.x,eyeY,p.z,p.x+d.x*10,eyeY+d.y*10,p.z+d.z*10)
 g3d.light(.30,.85,.42,.44+(w.muzzle>0 and .04 or 0),"#D6E5E5")
 g3d.fog(w.map.style.fog,24,R.quality==2 and 65 or 44)
 R.drawCalls=0
 local far=R.quality==2 and 62 or 42
 local function visible(x,y,z,r)
  local dx,dy,dz=x-p.x,y-eyeY,z-p.z
  local distance=sqrt(dx*dx+dy*dy+dz*dz)
  return distance<far+r and dx*d.x+dy*d.y+dz*d.z> -r
 end
 for _,b in ipairs(R.batches) do if visible(b.x,b.y,b.z,b.radius) then draw(b.mesh,0,0,0,0,0,0,1,1,1,tint(w,b.x,b.y,b.z,b.light,b.nearest)) end end
 for _,a in ipairs(w.map.props) do if visible(a.x,a.y+1,a.z,2.5) then R.model(a.model,a.x,a.y,a.z,a.angle or 0,1,0,0,tint(w,a.x,a.y+1,a.z)) end end
 for _,a in ipairs(w.map.relays) do
  if visible(a.x,a.y+1,a.z,2) then
   R.model("relay",a.x,a.y,a.z,0,1,0,0,a.active and "#9EDFD0" or tint(w,a.x,a.y+1,a.z))
   draw(R.ball,a.x,a.y+2,a.z,0,0,0,.14,.14,.14,a.active and "#ACF2D2" or "#F0B88B","glow unlit")
  end
 end
 for _,a in ipairs(w.map.terminals) do if visible(a.x,1,a.z,2) then R.model("terminal",a.x,0,a.z,math.pi,1,0,0,tint(w,a.x,1,a.z)) end end
 for _,a in ipairs(w.map.logs) do if not a.read and visible(a.x,a.y,a.z,1) then R.model("datapad",a.x,a.y,a.z,w.time*.2,1,0,0,"#B7BDD1") end end
 for _,a in ipairs(w.map.pickups) do
  if not a.collected and visible(a.x,a.y,a.z,1) then
   local name=a.kind=="weapon" and "weapon"..a.weapon or a.kind
   R.model(name,a.x,a.y+.06*sin(w.time*2+a.x),a.z,w.time*.4,a.kind=="weapon" and .6 or 1,0,0,"#E2D9BB")
  end
 end
 for _,a in ipairs(w.map.doors) do
  local yy=a.open and a.y+2.8 or a.y
  draw(R.box,a.x,yy,a.z,0,0,0,a.w,a.h,a.d,w.hasKey and "#588B91" or "#754F4B")
  for j=-1,1 do draw(R.box,a.x+j*.8,yy,a.z+.23,0,0,0,.10,2.6,.025,a.open and "#87DDC1" or "#DCA776","unlit") end
 end
 local egress=w.map.exit
 if visible(egress.x,1,egress.z,3) then
  draw(R.box,egress.x,.025,egress.z,0,0,0,4,.05,3,"#698E91")
  draw(R.ring,egress.x,1.8,egress.z,0,0,w.time*.15,1.1,1.1,1.1,"#8BBAAF","glow unlit")
 end
 for _,l in ipairs(w.map.lights) do
  if visible(l.x,l.y,l.z,1) then
   local pulse=.90+.10*sin(w.time*2+l.phase)
   draw(R.box,l.x,l.y,l.z,0,0,0,.3,.9,.18,{l.rgb[1]*pulse,l.rgb[2]*pulse,l.rgb[3]*pulse},"unlit")
   if R.quality==2 then draw(R.ball,l.x,l.y,l.z,0,0,0,.18,.55,.18,{l.rgb[1]*.2,l.rgb[2]*.2,l.rgb[3]*.2},"glow unlit") end
  end
 end
 for _,e in ipairs(w.map.enemies) do
  if (e.alive or e.deadTime<1) and visible(e.x,e.y+e.h/2,e.z,e.h) then
   local dead=not e.alive;local yy=e.y-(dead and min(.7,e.deadTime) or 0)
   local color=e.flash>0 and "#F2CFAC" or tint(w,e.x,e.y+1,e.z)
   local scale=e.kind=="drone" and .95 or 1
   R.model(e.kind,e.x,yy+(e.kind=="drone" and .35 or 0),e.z,e.angle,scale,dead and min(1.3,e.deadTime*3) or 0,0,color)
   if e.kind=="stalker" or e.kind=="trooper" then
    local step=sin(e.anim*2)*.55
    for _,s in ipairs({-1,1}) do
     local x=e.x+s*.20*cos(e.angle);local z=e.z-s*.20*sin(e.angle)
     R.model("leg",x,yy+.72,z,e.angle,1,step*s,0,color)
     if e.kind=="stalker" then R.model("stalker_arm",e.x+s*.43*cos(e.angle),yy+1.35,e.z-s*.43*sin(e.angle),e.angle,1,-step*s,0,color) end
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
 if not showcase then
  local cs,sn=cos(p.yaw),sin(p.yaw)
  local bob=sin(p.anim*1.8)*.012
  local forward=.52
  if F.ray(w,{x=p.x,y=eyeY,z=p.z},d,1.2)<.9 then forward=.18 end
  local gx=p.x+cs*.27+d.x*forward;local gy=eyeY-.29+bob-w.recoil*.2;local gz=p.z+sn*.27+d.z*forward
  local ry,rx=-p.yaw,p.pitch+w.recoil
  R.model("weapon"..w.weapon,gx,gy,gz,ry,.43,rx,0,{235,240,230})
  R.model("glove",gx+cs*.02,gy-.14,gz+sn*.02,ry,.65,rx,0,"#B3BEBA")
  if w.weapon>1 then R.model("glove",gx-cs*.17+d.x*.20,gy-.09,gz-sn*.17+d.z*.20,ry,.65,rx,0,"#B3BEBA") end
  if w.muzzle>0 then
   draw(R.ball,gx+d.x*.54,gy+d.y*.54,gz+d.z*.54,0,0,0,.10+w.muzzle,.10,.18,"#FFD49B","glow unlit")
  end
 end
 R.triangles=g3d.finish()
end
return R
