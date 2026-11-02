-- Distinct tells, attack windows and counters. All enemies stay in their authored district.
local E={}
local sin,cos,sqrt,abs,min,max=math.sin,math.cos,math.sqrt,math.abs,math.min,math.max
local function clamp(v,a,b)return max(a,min(b,v))end
function E.init(e,b)
 e.alive=true;e.x=b.x+(e.dx or 0);e.y=b.y;e.z=b.z+(e.dz or 0)
 e.homeX,e.homeZ=e.x,e.z;e.state="patrol";e.timer=0;e.cooldown=1+(e.phase or 0)*.13
 e.hp=(e.kind=="turtle" or e.kind=="ram" or e.kind=="mimic") and 2 or 1;e.flash=0;e.angle=0
end
function E.hit(world,e,heavy)
 if not e.alive or e.flash>0 then return false end
 if e.kind=="turtle" and not heavy then world:emit("armor",e.x,e.y,e.z);return false end
 if e.kind=="ram" and e.state~="stunned" and not heavy then world:emit("armor",e.x,e.y,e.z);return false end
 e.hp=e.hp-1;e.flash=.35
 if e.hp<=0 then e.alive=false;world:emit("stomp",e.x,e.y,e.z);world:addCoins(2)
 else world:emit("enemyHit",e.x,e.y,e.z) end
 return true
end
local function shoot(w,e,dx,dz)
 local dy=w.player.y-e.y
 local l=max(.01,sqrt(dx*dx+dy*dy+dz*dz))
 w.projectiles[#w.projectiles+1]={x=e.x,y=e.y+.8,z=e.z,vx=dx/l*7,vy=dy/l*7,vz=dz/l*7,life=4,reflected=false}
 w:emit("shoot",e.x,e.y,e.z)
end
function E.update(w,dt,prevY)
 local p=w.player
 for _,e in ipairs(w.def.enemies) do
  if e.alive then
   local b=w.def.platforms[e.platform]
   e.flash=max(0,e.flash-dt);e.cooldown=e.cooldown-dt;e.timer=max(0,e.timer-dt)
   local dx,dz=p.x-e.x,p.z-e.z;local dist=sqrt(dx*dx+dz*dz);local l=max(.01,dist)
   e.angle=math.atan(dx,dz)
   local speed=0
   if e.kind=="plant" then
    e.y=b.y
    if dist<13 and abs(p.y-b.y)<4 and e.cooldown<=0 then shoot(w,e,dx,dz);e.cooldown=2.1;e.timer=.45;e.state="firing" end
    if e.timer<=0 then e.state="idle" end
   elseif e.kind=="ram" then
    if e.state=="windup" and e.timer<=0 then e.state="charge";e.timer=.65
    elseif e.state=="charge" then
     e.x=e.x+e.chargeX*15*dt;e.z=e.z+e.chargeZ*15*dt
     if e.timer<=0 or abs(e.x-b.x)>b.w/2-1 or abs(e.z-b.z)>b.d/2-1 then e.state="stunned";e.timer=2.3 end
    elseif e.state=="stunned" and e.timer<=0 then e.state="patrol"
    elseif e.state=="patrol" and dist<10 and abs(p.y-b.y)<3 then e.state="windup";e.timer=.8;e.chargeX=dx/l;e.chargeZ=dz/l
    elseif e.state=="patrol" then speed=1 end
    e.y=b.y
   elseif e.kind=="bat" or e.kind=="orb" then
    if e.kind=="orb" then
     e.x=e.homeX+sin(w.time*.9+e.phase)*2.8;e.z=e.homeZ+cos(w.time*.9+e.phase)*2
     e.y=b.y+2+sin(w.time*2)*.5
     if dist<15 and e.cooldown<=0 then shoot(w,e,dx,dz);e.cooldown=2.8 end
    else
     if e.state=="dive" then
      e.x=e.x+dx/l*7*dt;e.z=e.z+dz/l*7*dt;e.y=max(b.y+.25,e.y-6*dt)
      if e.timer<=0 then e.state="recover";e.timer=1.8 end
     elseif e.state=="recover" then e.y=min(b.y+2.5,e.y+2*dt);if e.timer<=0 then e.state="patrol" end
     else
      e.x=e.homeX+sin(w.time*1.4+e.phase)*3;e.z=e.homeZ+cos(w.time*1.4+e.phase)*2;e.y=b.y+2.5
      if dist<7 and e.cooldown<=0 then e.state="dive";e.timer=.85;e.cooldown=3 end
     end
    end
   elseif e.kind=="mimic" then
    if e.state=="patrol" and dist<5 then e.state="wake";e.timer=.7
    elseif e.state=="wake" and e.timer<=0 then e.state="chase"
    elseif e.state=="chase" then speed=3.4 end
    e.y=b.y+(e.state=="chase" and abs(sin(w.time*7))*.35 or 0)
   elseif e.kind=="hopper" then speed=dist<9 and 2.7 or 1;e.y=b.y+max(0,sin(w.time*3+e.phase))*1.7
   else speed=dist<8 and (e.kind=="turtle" and 1.2 or 2.3) or .8;e.y=b.y end
   if speed>0 then
    if dist<10 then e.x=e.x+dx/l*speed*dt;e.z=e.z+dz/l*speed*dt
    else e.x=e.homeX+sin(w.time+e.phase)*(e.range or 2);e.z=e.homeZ+cos(w.time*.7+e.phase)*1.3 end
   end
   e.x=clamp(e.x,b.x-b.w/2+1,b.x+b.w/2-1);e.z=clamp(e.z,b.z-b.d/2+1,b.z+b.d/2-1)
   if b.active and dist<.95 and p.y<e.y+1.1 and p.y+1.6>e.y then
    local stomp=p.vy<-.8 and prevY>=e.y+.55
    if stomp or p.dash>0 then
     local hit=E.hit(w,e,p.pound)
     if stomp then p.vy=hit and 8 or 5;p.jumps=min(p.jumps,1);p.pound=false end
     if not hit then w:damage(false,e.x,e.z) end
    else w:damage(false,e.x,e.z) end
   end
  end
 end
 for i=#w.projectiles,1,-1 do
  local a=w.projectiles[i];a.life=a.life-dt;a.x=a.x+a.vx*dt;a.y=a.y+(a.vy or 0)*dt;a.z=a.z+a.vz*dt
  for _,b in ipairs(w.def.blockers or {}) do if abs(a.x-b.x)<b.w/2 and abs(a.z-b.z)<b.d/2 and a.y>b.y and a.y<b.y+b.h then a.life=0 end end
  if a.life<=0 then table.remove(w.projectiles,i)
  else
   if not a.reflected and (p.x-a.x)^2+(p.z-a.z)^2<.8 and abs(p.y+.8-a.y)<1 then
    if p.dash>0 then a.reflected=true;a.vx=-a.vx*1.5;a.vy=-(a.vy or 0)*1.5;a.vz=-a.vz*1.5;w:emit("parry",a.x,a.y,a.z)
    else w:damage(false,a.x,a.z);a.life=0 end
   end
   if a.reflected then for _,e in ipairs(w.def.enemies) do if e.alive and (e.x-a.x)^2+(e.z-a.z)^2<1.5 and abs(e.y+.7-a.y)<1.5 then E.hit(w,e,true);a.life=0;break end end end
  end
 end
end
return E
