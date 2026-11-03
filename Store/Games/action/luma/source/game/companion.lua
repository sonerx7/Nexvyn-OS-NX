-- The astral companion solves distant mechanisms and bonds with friendly spirits.
-- It stuns hostiles; collecting a spirit changes traversal rather than dealing damage.
local C={}
local sin,cos,sqrt=math.sin,math.cos,math.sqrt
function C.cast(w)
 if w.cap or (w.capCooldown or 0)>0 then return false end
 local p=w.player;w.cap={x=p.x,y=p.y+1.15,z=p.z,dx=sin(p.facing),dz=cos(p.facing),age=0,returning=false,hits={}}
 w.capCooldown=.45;w:emit('cast',p.x,p.y+1,p.z);return true
end
function C.bond(w,kind,source)
 if w.bondSource then w.bondSource.bonded=false;w.bondSource.stunned=2 end
 w.form=kind;w.formTimer=18;w.formShield=true;w.bondSource=source
 if source then source.bonded=true end
 w.player.formKind=kind;w:emit('bond',w.player.x,w.player.y,w.player.z,kind)
end
function C.update(w,dt)
 local p=w.player;w.capCooldown=math.max(0,(w.capCooldown or 0)-dt)
 if w.form then
  w.formTimer=w.formTimer-dt;p.formKind=w.form
  if w.formTimer<=0 then if w.bondSource then w.bondSource.bonded=false;w.bondSource.stunned=2 end;w.bondSource=nil;w.form=nil;p.formKind=nil end
 end
 local a=w.cap;if not a then return end;a.age=a.age+dt
 if a.age>.38 then a.returning=true end
 if a.returning then
  local dx,dy,dz=p.x-a.x,p.y+1.15-a.y,p.z-a.z;local d=sqrt(dx*dx+dy*dy+dz*dz)
  if d<.6 then w.cap=nil;w:emit('catch',p.x,p.y,p.z);return end
  a.x=a.x+dx/d*25*dt;a.y=a.y+dy/d*25*dt;a.z=a.z+dz/d*25*dt
 else
  a.x=a.x+a.dx*23*dt;a.z=a.z+a.dz*23*dt
  for _,b in ipairs(w.def.blockers or {}) do
   if math.abs(a.x-b.x)<b.w/2 and math.abs(a.z-b.z)<b.d/2 and a.y>b.y and a.y<b.y+b.h then a.returning=true;return end
  end
  for _,s in ipairs(w.def.switches or {}) do
   local b=w.def.platforms[s.platform]
   if (a.x-b.x-s.dx)^2+(a.z-b.z-s.dz)^2<1.3 and math.abs(a.y-b.y-.7)<1.5 then s.struck=true end
  end
  for _,sp in ipairs(w.def.spirits or {}) do
   local b=w.def.platforms[sp.platform]
   if (a.x-b.x-sp.dx)^2+(a.z-b.z-sp.dz)^2<1.7 and math.abs(a.y-b.y-1)<1.8 then C.bond(w,sp.kind);a.returning=true;break end
  end
  for _,box in ipairs(w.def.crates or {}) do
   local b=w.def.platforms[box.platform]
   if not box.broken and (a.x-b.x-box.dx)^2+(a.z-b.z-box.dz)^2<1.2 and math.abs(a.y-b.y-.7)<1.6 then w:breakCrate(box) end
  end
  for _,e in ipairs(w.def.enemies) do
   if e.alive and not a.hits[e] and (a.x-e.x)^2+(a.z-e.z)^2<1.4 and math.abs(a.y-e.y-.8)<1.8 then
    e.stunned=2.5;a.hits[e]=true;w:emit('stun',e.x,e.y,e.z)
   end
  end
 end
 if a.age>2 then w.cap=nil end
end
return C
