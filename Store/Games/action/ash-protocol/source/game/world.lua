local Maps=require("game.maps")
local F=require("game.physics")
local W={};W.__index=W
local sin,cos,sqrt,abs,min,max=math.sin,math.cos,math.sqrt,math.abs,math.min,math.max
local function clamp(v,a,b)return max(a,min(b,v))end
local function dist(a,b)local x,z=a.x-b.x,a.z-b.z;return sqrt(x*x+z*z)end
local stats={stalker={hp=50,speed=5,h=1.9,w=.7},trooper={hp=72,speed=2.8,h=2,w=.75},drone={hp=48,speed=3.6,h=.8,w=.9},siege={hp=190,speed=1.7,h=2.3,w=1.25},priest={hp=115,speed=2.2,h=2.2,w=.8},warden={hp=1050,speed=2,h=4.3,w=2.3}}
W.weapons={{rate=.17,damage=16,ammo=0,cost=0,pellets=1,spread=.008},{rate=.69,damage=13,ammo=1,cost=1,pellets=9,spread=.075},{rate=.11,damage=26,ammo=2,cost=1,pellets=1,spread=.018},{rate=.86,damage=125,ammo=2,cost=5,pellets=1,spread=0,pierce=true}}
local function initEnemy(e,index)
 local s=stats[e.kind];e.maxHp=s.hp;e.hp=s.hp;e.speed=s.speed;e.h=s.h;e.w=s.w;e.alive=true;e.timer=.7+(index%4)*.31;e.flash=0;e.active=false;e.anim=0;e.angle=0;e.state="idle";e.baseY=e.y;e.deadTime=0
 if e.kind=="drone" then e.y=e.y+1.6;e.baseY=e.y end
end
function W.new(chapter,snapshot)
 local self=setmetatable({map=Maps.build(chapter),time=0,elapsed=0,events={},projectiles={},fx={},visited={},status="play",kills=0,totalKills=0,shots=0,hits=0,relayCount=0,hasKey=false,flashlight=true,weapon=1,unlocked={true,chapter>=2,chapter>=3,chapter>=4},ammo={18,90},cooldown=0,muzzle=0,recoil=0,hurt=0,checkpoint=1,logs={},score=0},W)
 local s=self.map.start
 self.player={x=s.x,y=s.y,z=s.z,vx=0,vy=0,vz=0,yaw=s.yaw,pitch=0,hp=100,armor=35,grounded=true,dash=0,dashCD=0,invul=0,anim=0}
 for i,e in ipairs(self.map.enemies) do initEnemy(e,i);self.totalKills=self.totalKills+1 end
 if snapshot and snapshot.chapter==chapter then
  for _,k in ipairs({"weapon","kills","shots","hits","elapsed","score","hasKey","checkpoint","flashlight"}) do if snapshot[k]~=nil then self[k]=snapshot[k] end end
  if snapshot.player then for k,v in pairs(snapshot.player) do if self.player[k]~=nil and type(v)==type(self.player[k]) then self.player[k]=v end end end
  self.unlocked=snapshot.unlocked or self.unlocked;self.ammo=snapshot.ammo or self.ammo;self.visited=snapshot.visited or {};self.logs=snapshot.logs or {}
  for i,e in ipairs(self.map.enemies) do local hp=snapshot.enemies and snapshot.enemies[tostring(i)];if hp then e.hp=hp;e.alive=hp>0 end end
  for i,a in ipairs(self.map.pickups) do a.collected=snapshot.pickups and snapshot.pickups[tostring(i)] or false end
  for i,r in ipairs(self.map.relays) do r.active=snapshot.relays and snapshot.relays[tostring(i)] or false end
  for i,d in ipairs(self.map.doors) do d.open=snapshot.doors and snapshot.doors[tostring(i)] or false end
  if snapshot.actors then
   self.map.enemies={}
   for i,a in ipairs(snapshot.actors) do
    local e={kind=a.kind,x=a.x,y=a.y,z=a.z,room=a.room,boss=a.boss};initEnemy(e,i)
    e.y=a.y;e.baseY=a.baseY;e.hp=a.hp;e.alive=a.hp>0;e.active=a.active;e.deadTime=e.alive and 0 or 2
    self.map.enemies[#self.map.enemies+1]=e
   end
   self.totalKills=#self.map.enemies
  end
  if snapshot.pickupDetails then self.map.pickups=snapshot.pickupDetails end
  for _,log in ipairs(self.map.logs) do log.read=self.logs[tostring(log.index)]==true end
 end
 return self
end
function W:emit(kind,value,x,y,z)
 self.events[#self.events+1]={kind=kind,value=value,x=x,y=y,z=z}
end
function W:snapshot()
 local function copy(t)local out={};for k,v in pairs(t) do out[k]=v end;return out end
 local s={chapter=self.map.chapter,player={},unlocked=copy(self.unlocked),ammo=copy(self.ammo),visited=copy(self.visited),logs=copy(self.logs),enemies={},actors={},pickups={},pickupDetails={},relays={},doors={}}
 for _,k in ipairs({"x","y","z","yaw","pitch","hp","armor"}) do s.player[k]=self.player[k] end
 for _,k in ipairs({"weapon","kills","shots","hits","elapsed","score","hasKey","checkpoint","flashlight"}) do s[k]=self[k] end
 for i,e in ipairs(self.map.enemies) do
  s.enemies[tostring(i)]=e.hp
  s.actors[i]={kind=e.kind,x=e.x,y=e.y,z=e.z,baseY=e.baseY,room=e.room,boss=e.boss,hp=e.hp,active=e.active}
 end
 for i,a in ipairs(self.map.pickups) do if a.collected then s.pickups[tostring(i)]=true end;s.pickupDetails[i]=copy(a) end
 for i,r in ipairs(self.map.relays) do if r.active then s.relays[tostring(i)]=true end end
 for i,d in ipairs(self.map.doors) do if d.open then s.doors[tostring(i)]=true end end
 return s
end
function W:select(n)
 if self.unlocked[n] then self.weapon=n;self.cooldown=max(self.cooldown,.10);self:emit("weapon",n)
 else self:emit("lockedWeapon") end
end
function W:damage(amount)
 local p=self.player;if p.invul>0 or self.status~="play" then return end
 local absorbed=min(p.armor,amount*.65);p.armor=p.armor-absorbed;p.hp=max(0,p.hp-amount+absorbed);p.invul=.28;self.hurt=.35
 self:emit("hurt")
 if p.hp<=0 then self.status="dead";self:emit("dead") end
end
function W:hitEnemy(e,amount,y,heavy)
 if not e.alive then return end
 if e.kind=="siege" and not heavy then amount=amount*.65 end
 if e.kind=="warden" and y and abs(y-e.y-2.1)<.45 then amount=amount*1.7 end
 e.hp=max(0,e.hp-amount);e.flash=.12;e.active=true;self.hits=self.hits+1
 if e.hp==0 then
  e.alive=false;e.deadTime=0;self.kills=self.kills+1;self.score=self.score+(e.boss and 1000 or 100)
  self.player.armor=min(100,self.player.armor+3)
  self.map.pickups[#self.map.pickups+1]={kind="ammo",x=e.x,y=max(0,e.y)+.3,z=e.z,drop=true}
  self:emit(e.boss and "bossDead" or "kill",e.kind,e.x,e.y+1,e.z)
 else self:emit("hit",nil,e.x,e.y+1,e.z) end
end
function W:shoot()
 if self.status~="play" or self.cooldown>0 then return false end
 local weapon=W.weapons[self.weapon];local p=self.player
 if weapon.ammo>0 and self.ammo[weapon.ammo]<weapon.cost then self.cooldown=.2;self:emit("empty");return false end
 if weapon.ammo>0 then self.ammo[weapon.ammo]=self.ammo[weapon.ammo]-weapon.cost end
 self.cooldown=weapon.rate;self.muzzle=.065;self.recoil=min(.18,self.recoil+.10);self.shots=self.shots+1
 self:emit("shot",self.weapon)
 local origin={x=p.x,y=p.y+1.52,z=p.z}
 for pellet=1,weapon.pellets do
  local spread=weapon.spread
  local d=F.direction(p.yaw+(math.random()-.5)*spread*2,p.pitch+(math.random()-.5)*spread*2)
  if self.weapon==3 then
   self.projectiles[#self.projectiles+1]={x=origin.x,y=origin.y,z=origin.z,dx=d.x,dy=d.y,dz=d.z,speed=38,life=2,friendly=true,damage=weapon.damage,r=.12,kind="plasma"}
  else
   local wall=F.ray(self,origin,d,75);local targets={}
   for _,e in ipairs(self.map.enemies) do
    if e.alive then
     local t=F.hit(origin,d,{x=e.x,y=e.y+e.h/2,z=e.z,w=e.w,h=e.h,d=e.w},wall)
     if t then targets[#targets+1]={enemy=e,t=t} end
    end
   end
   table.sort(targets,function(a,b)return a.t<b.t end)
   local endT=wall
   for i,target in ipairs(targets) do
    if i>1 and not weapon.pierce then break end
    self:hitEnemy(target.enemy,weapon.damage,origin.y+d.y*target.t,weapon.pierce)
    endT=target.t
    if i>=3 then break end
   end
   self.fx[#self.fx+1]={kind=self.weapon==4 and "rail" or "tracer",x=origin.x,y=origin.y,z=origin.z,tx=origin.x+d.x*endT,ty=origin.y+d.y*endT,tz=origin.z+d.z*endT,life=self.weapon==4 and .18 or .045}
  end
 end
 for _,e in ipairs(self.map.enemies) do if e.alive and dist(e,p)<22 then e.active=true end end
 return true
end
function W:melee()
 if self.meleeCD and self.meleeCD>0 then return end
 self.meleeCD=.6;local p=self.player;local best,range=nil,2.5
 for _,e in ipairs(self.map.enemies) do if e.alive and abs(e.y-p.y)<2 then
  local l=dist(e,p);local a=math.atan(e.x-p.x,-(e.z-p.z));local delta=(a-p.yaw+math.pi)%(2*math.pi)-math.pi
  if l<range and abs(delta)<.9 then best=e;range=l end
 end end
 if best then self:hitEnemy(best,55,best.y+1,true);p.hp=min(100,p.hp+12);self.ammo[1]=min(60,self.ammo[1]+2);self:emit("melee") end
end
function W:use()
 local p=self.player
 for _,r in ipairs(self.map.relays) do
  if not r.active and dist(p,r)<2.7 then r.active=true;self:emit("relay");return end
 end
 for _,t in ipairs(self.map.terminals) do
  if dist(p,t)<2.7 then p.hp=min(100,p.hp+20);self.checkpoint=t.room;self:emit("checkpoint");return end
 end
 for _,d in ipairs(self.map.doors) do
  if not d.open and dist(p,d)<3.5 then
   if self.hasKey and self.relayCount==2 then d.open=true;self:emit("door") else self:emit("gateLocked") end
   return
  end
 end
 if dist(p,self.map.exit)<3 then
  local alive=0;for _,e in ipairs(self.map.enemies) do if e.alive and e.room==6 then alive=alive+1 end end
  if self.hasKey and self.relayCount==2 and alive==0 then self.status="complete";self:emit("complete")
  else self:emit("exitLocked") end
 end
end
local function nextRoom(map,start,target)
 local queue={start};local prev={[start]=false};local index=1
 while queue[index] do
  local room=queue[index];index=index+1;if room==target then break end
  for _,id in ipairs(map.rooms[room].neighbors) do if prev[id]==nil then prev[id]=room;queue[#queue+1]=id end end
 end
 local id=target;if prev[id]==nil then return start end
 while prev[id] and prev[id]~=start do id=prev[id] end
 return id
end
function W:updateEnemies(dt)
 local p=self.player
 for _,e in ipairs(self.map.enemies) do
  e.flash=max(0,e.flash-dt)
  if e.alive then
   local range=dist(e,p);e.timer=e.timer-dt
   if range<13 or self.visited[tostring(e.room)] then e.active=true end
   if e.active then
    local dx,dz=p.x-e.x,p.z-e.z;local l=max(.01,range)
    local o={x=e.x,y=e.y+e.h*.67,z=e.z};local aim={x=dx,y=p.y+1.0-o.y,z=dz};local len=sqrt(aim.x^2+aim.y^2+aim.z^2)
    local dir={x=aim.x/max(.01,len),y=aim.y/max(.01,len),z=aim.z/max(.01,len)}
    e.visionTimer=(e.visionTimer or 0)-dt
    if e.visionTimer<=0 then e.clear=F.ray(self,o,dir,len)>=len-.1;e.visionTimer=.12 end
    local clear=e.clear
    e.angle=math.atan(-dx,-dz)
    local mx,mz=dx/l,dz/l
    if not clear and self.playerRoom and self.playerRoom>0 then
     local current=F.room(self,e.x,e.z)
     if current>0 then e.room=current end
     local route=nextRoom(self.map,e.room,self.playerRoom);local target=self.map.rooms[route]
     local tx,tz=target.x-e.x,target.z-e.z;local r=max(.01,sqrt(tx*tx+tz*tz));mx,mz=tx/r,tz/r
    end
    if e.kind=="drone" then e.y=e.baseY+sin(self.time*2+e.x)*.3
    elseif e.kind=="priest" then e.y=e.baseY+.3+sin(self.time*1.5)*.15 end
    local moving=e.kind=="stalker" or not clear or range>11
    if clear and range<5 and e.kind~="stalker" and e.kind~="warden" then mx,mz=-mx,-mz;moving=true end
    if clear and range>=5 and range<=11 and e.kind~="stalker" then
     local strafe=sin(self.time*.9+e.z)>0 and 1 or -1;mx,mz=-dz/l*strafe,dx/l*strafe;moving=true
    end
    if e.kind=="warden" then moving=range>10;e.speed=e.hp<e.maxHp*.35 and 4.2 or 2 end
    if moving then
     local nx=e.x+mx*e.speed*dt;local nz=e.z+mz*e.speed*dt
     if not F.blocked(self,nx,e.y,e.z,e.w*.35,e.h) then e.x=nx end
     if not F.blocked(self,e.x,e.y,nz,e.w*.35,e.h) then e.z=nz end
     e.anim=e.anim+e.speed*dt
     if e.kind~="drone" and e.kind~="priest" then local floor=F.floor(self,e.x,e.y,e.z);if floor>-10 then e.y=floor end end
    end
    if e.kind=="stalker" then
     if range<1.45 and abs(p.y-e.y)<2 and e.timer<=0 then self:damage(16);e.timer=.7;e.state="attack" else e.state="chase" end
    elseif clear and range<28 and e.timer<=0 then
     local shots=e.kind=="warden" and 7 or (e.kind=="siege" and 2 or 1)
     for j=1,shots do
      local spread=shots>1 and (j-(shots+1)/2)*.13 or 0;local cs,sn=cos(spread),sin(spread)
      self.projectiles[#self.projectiles+1]={x=o.x,y=o.y,z=o.z,dx=dir.x*cs+dir.z*sn,dy=dir.y,dz=-dir.x*sn+dir.z*cs,speed=e.kind=="siege" and 8 or 12,life=5,damage=e.kind=="warden" and 22 or (e.kind=="siege" and 27 or 13),r=e.kind=="siege" and .25 or .14,kind=e.kind=="priest" and "void" or "bolt",friendly=false}
     end
     e.timer=e.kind=="trooper" and 1.2 or (e.kind=="warden" and 1.35 or 2.2);e.state="attack";e.flash=.08
     self:emit("enemyShot",e.kind,e.x,e.y+1,e.z)
     if e.kind=="priest" and #self.map.enemies<25 and self.time-(e.summonedAt or -10)>9 then
      local child={kind="stalker",x=e.x+1.1,y=0,z=e.z,room=e.room};initEnemy(child,#self.map.enemies+1);child.active=true
      self.map.enemies[#self.map.enemies+1]=child;self.totalKills=self.totalKills+1;e.summonedAt=self.time;self:emit("summon")
     end
    else e.state=e.timer<.35 and "windup" or "move" end
   end
  else e.deadTime=e.deadTime+dt end
 end
end
function W:updateProjectiles(dt)
 local p=self.player
 for i=#self.projectiles,1,-1 do
  local a=self.projectiles[i];a.life=a.life-dt
  local dir={x=a.dx,y=a.dy,z=a.dz};local origin={x=a.x,y=a.y,z=a.z};local travel=a.speed*dt
  local allowed=F.ray(self,origin,dir,travel)
  if allowed<travel then a.life=0 end
  if a.friendly then
   for _,e in ipairs(self.map.enemies) do
    if e.alive then local hit=F.hit(origin,dir,{x=e.x,y=e.y+e.h/2,z=e.z,w=e.w+a.r*2,h=e.h,d=e.w+a.r*2},allowed)
     if hit then self:hitEnemy(e,a.damage,a.y,true);a.life=0;break end end
   end
  else
   local hit=F.hit(origin,dir,{x=p.x,y=p.y+.8,z=p.z,w=.7,h=1.65,d=.7},allowed)
   if hit then
    if p.dash>0 then a.friendly=true;a.dx=-a.dx;a.dy=-a.dy;a.dz=-a.dz;a.speed=a.speed*1.5;self:emit("parry")
    else self:damage(a.damage);a.life=0 end
   end
  end
  a.x=a.x+a.dx*travel;a.y=a.y+a.dy*travel;a.z=a.z+a.dz*travel
  if a.life<=0 then self.fx[#self.fx+1]={kind="spark",x=a.x,y=a.y,z=a.z,life=.18};table.remove(self.projectiles,i) end
 end
end
function W:step(dt,c)
 if self.status~="play" then return end
 self.time=self.time+dt;self.elapsed=self.elapsed+dt;self.cooldown=max(0,self.cooldown-dt);self.meleeCD=max(0,(self.meleeCD or 0)-dt);self.muzzle=max(0,self.muzzle-dt);self.recoil=max(0,self.recoil-dt*1.1);self.hurt=max(0,self.hurt-dt)
 local p=self.player;p.invul=max(0,p.invul-dt);p.dashCD=max(0,p.dashCD-dt);p.dash=max(0,p.dash-dt)
 for i=#self.fx,1,-1 do local a=self.fx[i];a.life=a.life-dt;if a.life<=0 then table.remove(self.fx,i) end end
 local strafe,forward=c.strafe or 0,c.forward or 0;local l=sqrt(strafe*strafe+forward*forward)
 if l>1 then strafe,forward=strafe/l,forward/l end
 local dx,dz=cos(p.yaw)*strafe+sin(p.yaw)*forward,sin(p.yaw)*strafe-cos(p.yaw)*forward
 local speed=c.run and 11.5 or 8.6
 if c.dash and p.dashCD<=0 then
  p.dash=.16;p.dashCD=.85;p.dashX=l>.1 and dx or sin(p.yaw);p.dashZ=l>.1 and dz or -cos(p.yaw);self:emit("dash")
 end
 if p.dash>0 then p.vx=(p.dashX or dx)*24;p.vz=(p.dashZ or dz)*24
 else
  local blend=min(1,dt*(p.grounded and 25 or 8));p.vx=p.vx+(dx*speed-p.vx)*blend;p.vz=p.vz+(dz*speed-p.vz)*blend
 end
 if c.jump and p.grounded then p.vy=8.4;p.grounded=false;self:emit("jump") end
 local ground=F.floor(self,p.x,p.y,p.z)
 local nx=p.x+p.vx*dt;local top=F.floor(self,nx,p.y,p.z);local foot=p.grounded and max(p.y,top) or p.y
 if not F.blocked(self,nx,foot,p.z,.30,1.62) then p.x=nx;if p.grounded and top>-10 then p.y=top end end
 local nz=p.z+p.vz*dt;top=F.floor(self,p.x,p.y,nz);foot=p.grounded and max(p.y,top) or p.y
 if not F.blocked(self,p.x,foot,nz,.30,1.62) then p.z=nz;if p.grounded and top>-10 then p.y=top end end
 local oldY=p.y;p.vy=p.vy-24*dt;p.y=p.y+p.vy*dt
 ground=F.floor(self,p.x,oldY,p.z);p.grounded=false
 if p.y<=ground and oldY>=ground-.1 then p.y=ground;p.vy=0;p.grounded=true end
 if p.vy>0 and F.blocked(self,p.x,p.y,p.z,.28,1.6) then p.y=oldY;p.vy=0 end
 if p.y< -10 then self:damage(300) end
 p.anim=p.anim+sqrt(p.vx*p.vx+p.vz*p.vz)*dt
 local room=F.room(self,p.x,p.z)
 if room>0 then self.playerRoom=room;if not self.visited[tostring(room)] then self.visited[tostring(room)]=true;self:emit("room",room) end end
 for _,a in ipairs(self.map.pickups) do
  if not a.collected and dist(p,a)<1.15 and abs(p.y+.8-a.y)<1.7 then
   local used=true
   if a.kind=="medkit" then used=p.hp<100;p.hp=min(100,p.hp+30)
   elseif a.kind=="armor" then used=p.armor<100;p.armor=min(100,p.armor+35)
   elseif a.kind=="ammo" then self.ammo[1]=min(60,self.ammo[1]+(a.drop and 2 or 6));self.ammo[2]=min(200,self.ammo[2]+(a.drop and 6 or 25))
   elseif a.kind=="key" then self.hasKey=true
   elseif a.kind=="weapon" then self.unlocked[a.weapon]=true;self:select(a.weapon) end
   if used then a.collected=true;self:emit("pickup",a.kind) end
  end
 end
 for _,log in ipairs(self.map.logs) do if not log.read and dist(p,log)<1.3 then log.read=true;self.logs[tostring(log.index)]=true;self:emit("log",log.index) end end
 self.relayCount=0;for _,r in ipairs(self.map.relays) do if r.active then self.relayCount=self.relayCount+1 end end
 if c.use then self:use() end
 if c.melee then self:melee() end
 if c.fire then self:shoot() end
 self:updateEnemies(dt);self:updateProjectiles(dt)
end
return W
