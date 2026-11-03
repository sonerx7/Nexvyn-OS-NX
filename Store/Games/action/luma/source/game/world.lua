local Companion=require('game.companion')
-- SDK-independent 3D character controller and game rules. Fixed step: 120 Hz.
local World={}; World.__index=World
local Enemies=require("game.enemies")
local Quests=require("game.quests")
local sqrt,sin,cos,abs,min,max=math.sqrt,math.sin,math.cos,math.abs,math.min,math.max
local function clamp(v,a,b) return max(a,min(b,v)) end
local function approach(v,target,delta)
  if v<target then return min(v+delta,target) end
  return max(v-delta,target)
end
local function distance(a,b) local x,z=a.x-b.x,a.z-b.z; return sqrt(x*x+z*z) end
local function inside(p,b,r) return abs(p.x-b.x)<b.w/2+r and abs(p.z-b.z)<b.d/2+r end

function World.new(def,snapshot)
  local self=setmetatable({def=def,time=0,elapsed=0,coins=0,stars=0,checkpoint=0,lives=4,events={},particles={},projectiles={},status="play",jumpBuffer=0,switchCount=0,keyCount=0},World)
  for _,p in ipairs(def.platforms) do p.ox,p.oy,p.oz=p.x,p.y,p.z; p.active=true; p.crumble=0 end
  for _,e in ipairs(def.enemies) do Enemies.init(e,def.platforms[e.platform]) end
  if def.adventure and snapshot and snapshot.revision~=2 then snapshot=nil end
  if snapshot then
    self.checkpoint=clamp(tonumber(snapshot.checkpoint) or 0,0,#def.checkpoints)
    self.coins=tonumber(snapshot.coins) or 0; self.stars=0
    self.elapsed=tonumber(snapshot.elapsed) or 0; self.lives=clamp(tonumber(snapshot.lives) or 4,1,9)
    for i,c in ipairs(def.coins) do c.collected=snapshot.collected and snapshot.collected[tostring(i)] or false end
    for i,c in ipairs(def.stars) do c.collected=snapshot.relics and snapshot.relics[tostring(i)] or false; if c.collected then self.stars=self.stars+1 end end
    for i,c in ipairs(def.crates) do c.broken=snapshot.crates and snapshot.crates[tostring(i)] or false end
    for i,e in ipairs(def.enemies) do e.alive=not (snapshot.defeated and snapshot.defeated[tostring(i)]) end
    for i,k in ipairs(def.keys or {}) do k.collected=snapshot.keys and snapshot.keys[tostring(i)] or false end
    for i,s in ipairs(def.switches or {}) do s.active=snapshot.switches and snapshot.switches[tostring(i)] or false end
    if def.cage then def.cage.opened=snapshot.rescued==true end
  end
  self:respawn(true)
  return self
end

function World:emit(kind,x,y,z,value)
  self.events[#self.events+1]={kind=kind,x=x,y=y,z=z,value=value}
  if #self.events>64 then table.remove(self.events,1) end
  if kind=="coin" or kind=="star" or kind=="stomp" or kind=="checkpoint" or kind=="break" or kind=="bossHit" then
    local count=kind=="star" and 18 or 8
    for j=1,count do
      local a=j*2.39996
      self.particles[#self.particles+1]={x=x,y=y+.3,z=z,vx=cos(a)*(1+j%3),vy=2+j%4,vz=sin(a)*(1+j%3),life=.6+j%3*.12,kind=kind}
    end
  end
end

function World:respawn(initial)
  if self.bondSource then self.bondSource.bonded=false end;self.cap=nil;self.form=nil;self.bondSource=nil
  local s=self.def.start
  if self.checkpoint>0 then
    local c=self.def.checkpoints[self.checkpoint]; s={x=c.x+1.3,y=c.y+.08,z=c.z}
  end
  self.player={x=s.x,y=s.y,z=s.z,vx=0,vy=0,vz=0,hp=3,grounded=false,support=nil,jumps=0,coyote=0,invul=initial and 0 or 1.6,dash=0,dashCD=0,facing=math.pi,pound=false,anim=0}
  self.jumpBuffer=0
  self.projectiles={}
  local b=self.def.boss
  if b and b.hp>0 then b.hp=3;b.state="sleep";b.timer=0;b.radius=0 end
end

function World:snapshot()
  local s={revision=2,level=self.def.number,checkpoint=self.checkpoint,coins=self.coins,elapsed=self.elapsed,lives=self.lives,collected={},relics={},crates={},keys={},switches={},defeated={},rescued=self.def.cage and self.def.cage.opened or false}
  for i,c in ipairs(self.def.coins) do if c.collected then s.collected[tostring(i)]=true end end
  for i,c in ipairs(self.def.stars) do if c.collected then s.relics[tostring(i)]=true end end
  for i,c in ipairs(self.def.crates) do if c.broken then s.crates[tostring(i)]=true end end
  for i,e in ipairs(self.def.enemies) do if not e.alive then s.defeated[tostring(i)]=true end end
  for i,k in ipairs(self.def.keys or {}) do if k.collected then s.keys[tostring(i)]=true end end
  for i,k in ipairs(self.def.switches or {}) do if k.active then s.switches[tostring(i)]=true end end
  return s
end

function World:damage(fall,sourceX,sourceZ)
  local p=self.player
  if not fall and p.invul>0 then return end
  if not fall and self.form=="turtle" and self.formShield then self.formShield=false;p.invul=1.2;self:emit("bondShield",p.x,p.y,p.z);return end
  p.hp=p.hp-1; p.invul=1.4
  self:emit("hurt",p.x,p.y,p.z)
  if fall or p.hp<=0 then
    self.lives=self.lives-1
    if self.lives<=0 then self.status="gameover";return end
    self:respawn(false); self:emit("respawn",self.player.x,self.player.y,self.player.z)
  else
    local dx,dz=p.x-(sourceX or p.x),p.z-(sourceZ or p.z+1)
    local l=max(.01,sqrt(dx*dx+dz*dz)); p.vx,p.vz=dx/l*5,dz/l*5;p.vy=5;p.grounded=false;p.support=nil
  end
end

function World:jump()
  self.jumpBuffer=.14
end

function World:step(dt,c)
  if self.status~="play" then return end
  self.time=self.time+dt;self.elapsed=self.elapsed+dt
  local p=self.player
  p.invul=max(0,p.invul-dt);p.dashCD=max(0,p.dashCD-dt);p.dash=max(0,p.dash-dt)
  self.jumpBuffer=max(0,self.jumpBuffer-dt)
  for i=#self.particles,1,-1 do
    local a=self.particles[i];a.life=a.life-dt
    if a.life<=0 then table.remove(self.particles,i) else a.x=a.x+a.vx*dt;a.y=a.y+a.vy*dt;a.z=a.z+a.vz*dt;a.vy=a.vy-10*dt end
  end
  for _,b in ipairs(self.def.platforms) do
    local oldX,oldY,oldZ=b.x,b.y,b.z
    if b.kind=="moveX" then b.x=b.ox+sin(self.time*1.25+b.phase)*1.5
    elseif b.kind=="moveY" then b.y=b.oy+sin(self.time*1.4+b.phase)*.85
    elseif b.kind=="moveZ" then b.z=b.oz+sin(self.time*1.2+b.phase)*1.35
    elseif b.kind=="crumble" and b.crumble>0 then
      b.crumble=b.crumble+dt;b.active=b.crumble<.85
      if b.crumble>4.5 then b.active=true;b.crumble=0 end
    end
    if p.support==b and b.active then p.x=p.x+b.x-oldX;p.y=p.y+b.y-oldY;p.z=p.z+b.z-oldZ end
  end
  if p.grounded then p.coyote=.11 else p.coyote=max(0,p.coyote-dt) end
  local mx,mz=c.x or 0,c.z or 0
  local length=sqrt(mx*mx+mz*mz)
  if length>1 then mx,mz=mx/length,mz/length;length=1 end
  if length>.12 then p.facing=math.atan(mx,mz) end
  if c.cast then Companion.cast(self) end;Companion.update(self,dt)
  if self.jumpBuffer>0 and (p.coyote>0 or p.jumps<2) then
    if p.coyote>0 then p.jumps=0 end
    p.jumps=p.jumps+1;p.vy=(p.jumps==1 and 10.3 or 9.7)*(self.form=="hopper" and 1.38 or 1)
    p.grounded=false;p.support=nil;p.coyote=0;p.pound=false;self.jumpBuffer=0
    self:emit(p.jumps==1 and "jump" or "doubleJump",p.x,p.y,p.z)
  end
  if c.dash and p.dashCD<=0 then
    p.dash=.18;p.dashCD=.85;p.vx=sin(p.facing)*18;p.vz=cos(p.facing)*18
    self:emit("dash",p.x,p.y,p.z)
  end
  if c.pound and not p.grounded and p.y>self.def.start.y+.4 then p.pound=true;p.vy=-22;p.vx=p.vx*.35;p.vz=p.vz*.35 end
  local support=p.support
  if p.dash<=0 then
    local speed=c.run and 9.2 or 6.6
    local accel=p.grounded and (support and support.kind=="ice" and 9 or 48) or 19
    p.vx=approach(p.vx,mx*speed,accel*dt);p.vz=approach(p.vz,mz*speed,accel*dt)
  end
  if support and support.kind=="conveyor" then p.x=p.x+2.3*dt end
  p.vx=p.vx+self.def.wind*sin(self.time*.7)*dt
  local prevY=p.y
  p.vy=p.vy-25*dt
  if self.form=="bat" and c.jumpHeld and p.vy< -2.8 then p.vy=-2.8;p.vx=p.vx*1.003;p.vz=p.vz*1.003 end
  if not c.jumpHeld and p.vy>4.5 and p.dash<=0 then p.vy=p.vy-23*dt end
  local oldX=p.x;p.x=p.x+p.vx*dt
  for _,b in ipairs(self.def.platforms) do
    if b.active and inside(p,b,.30) and p.grounded and b.y>p.y and b.y-p.y<=(b.road and 1.05 or .55) then p.y=b.y;prevY=p.y end
    if b.active and inside(p,b,.30) and p.y<b.y-.06 and p.y+1.7>b.y-2.5 then p.x=oldX;p.vx=0;break end
  end
  for _,b in ipairs(self.def.blockers or {}) do if inside(p,b,.3) and p.y<b.y+b.h and p.y+1.7>b.y then p.x=oldX;p.vx=0 end end
  local oldZ=p.z;p.z=p.z+p.vz*dt
  for _,b in ipairs(self.def.platforms) do
    if b.active and inside(p,b,.30) and p.grounded and b.y>p.y and b.y-p.y<=(b.road and 1.05 or .55) then p.y=b.y;prevY=p.y end
    if b.active and inside(p,b,.30) and p.y<b.y-.06 and p.y+1.7>b.y-2.5 then p.z=oldZ;p.vz=0;break end
  end
  for _,b in ipairs(self.def.blockers or {}) do if inside(p,b,.3) and p.y<b.y+b.h and p.y+1.7>b.y then p.z=oldZ;p.vz=0 end end
  p.y=p.y+p.vy*dt;p.grounded=false;p.support=nil
  for _,b in ipairs(self.def.platforms) do
    if b.active and inside(p,b,-.10) then
      if p.vy<=0 and prevY>=b.y-.13 and p.y<=b.y then
        local landedPound=p.pound
        p.y=b.y;p.vy=0;p.grounded=true;p.support=b;p.jumps=0;p.pound=false
        if b.kind=="crumble" and b.crumble==0 then b.crumble=dt end
        if landedPound then
          self:emit("slam",p.x,p.y,p.z)
          for _,e in ipairs(self.def.enemies) do if e.alive and distance(p,e)<2.5 and abs(p.y-e.y)<1.5 then Enemies.hit(self,e,true) end end
          for _,box in ipairs(self.def.crates) do
            local bp=self.def.platforms[box.platform]
            if not box.broken and sqrt((p.x-bp.x-box.dx)^2+(p.z-bp.z-box.dz)^2)<2 then self:breakCrate(box) end
          end
        end
        if b.kind=="spring" and abs(p.x-b.x)<1.05 and abs(p.z-b.z)<1.05 then
          p.vy=14.5;p.grounded=false;p.support=nil;p.jumps=1;self:emit("spring",p.x,p.y,p.z)
        end
        break
      elseif p.vy>0 and prevY+1.7<=b.y-2.5 and p.y+1.7>=b.y-2.5 then p.y=b.y-4.21;p.vy=0 end
    end
  end
  for _,b in ipairs(self.def.blockers or {}) do
    local top=b.y+b.h
    if p.vy<=0 and inside(p,b,-.1) and prevY>=top-.1 and p.y<=top then p.y=top;p.vy=0;p.grounded=true;p.jumps=0;p.pound=false end
  end
  if not p.grounded and p.coyote<=0 and p.jumps==0 then p.jumps=1 end
  p.anim=p.anim+sqrt(p.vx*p.vx+p.vz*p.vz)*dt
  -- Fall plane follows the route, not the camera; the start island cannot become lethal when looking up.
  local floorY=-8
  for _,b in ipairs(self.def.platforms) do if abs(b.z-p.z)<12 then floorY=max(floorY,b.y-9) end end
  if p.y<floorY then self:damage(true);return end
  for _,item in ipairs(self.def.coins) do
    if not item.collected then
      local b=self.def.platforms[item.platform];local x,y,z=b.x+item.dx,b.y+item.dy,b.z+item.dz
      if b.active and abs(p.x-x)<.65 and abs(p.z-z)<.65 and abs(p.y+.9-y)<1 then
        item.collected=true;self:addCoins(1);self:emit("coin",x,y,z)
      end
    end
  end
  Quests.update(self)
  for _,item in ipairs(self.def.stars) do
    if not item.collected and Quests.available(self,item) then
      local b=self.def.platforms[item.platform];local x,y,z=b.x+item.dx,b.y+item.dy,b.z+item.dz
      if abs(p.x-x)<.85 and abs(p.z-z)<.85 and abs(p.y+1-y)<1.3 then item.collected=true;self.stars=self.stars+1;self:emit("star",x,y,z) end
    end
  end
  for _,cp in ipairs(self.def.checkpoints) do
    if cp.index>self.checkpoint and abs(p.x-cp.x)<1.35 and abs(p.z-cp.z)<1.35 and abs(p.y-cp.y)<.3 then self.checkpoint=cp.index;p.hp=3;self:emit("checkpoint",cp.x,cp.y,cp.z) end
  end
  for _,box in ipairs(self.def.crates) do
    local b=self.def.platforms[box.platform]
    if not box.broken and abs(p.x-b.x-box.dx)<.8 and abs(p.z-b.z-box.dz)<.8 and abs(p.y-b.y)<1.4 and p.dash>0 then self:breakCrate(box) end
  end
  Enemies.update(self,dt,prevY)
  for _,h in ipairs(self.def.hazards) do
    local b=self.def.platforms[h.platform]
    local hx,hz=b.x+h.dx,b.z+h.dz
    local hit=false
    if h.kind=="beam" then
      local angle=self.time*.7+h.phase;local x,z=p.x-hx,p.z-hz
      local along=x*cos(angle)-z*sin(angle);local across=x*sin(angle)+z*cos(angle)
      hit=abs(along)<h.radius+.25 and abs(across)<.45 and p.y<b.y+.68
    elseif h.kind=="vent" then hit=sin(self.time*1.7+h.phase)>.3 and (p.x-hx)^2+(p.z-hz)^2<h.radius^2 and p.y<b.y+1.2
    else hit=abs(p.x-hx)<.85 and abs(p.z-hz)<.85 and p.y<b.y+.55 end
    if b.active and hit and p.y+1.7>b.y then self:damage(false,hx,hz) end
  end
  self:updateBoss(dt,prevY)
  local goal=self.def.goal
  if distance(p,goal)<1.4 and abs(p.y-goal.y)<1 then
    if self.stars>=2 and (not self.def.adventure or self.switchCount==3) and (not self.def.boss or self.def.boss.hp<=0) then
      self.status="complete";self:emit("complete",goal.x,goal.y,goal.z)
    elseif not self.goalNotice or self.time-self.goalNotice>3 then
      self.goalNotice=self.time;self:emit(self.stars<2 and "needStars" or (self.def.adventure and self.switchCount<3 and "needSwitches" or "needBoss"),goal.x,goal.y,goal.z)
    end
  end
end

function World:addCoins(amount)
  local before=math.floor(self.coins/50)
  self.coins=self.coins+amount
  local earned=math.floor(self.coins/50)-before
  if earned>0 then self.lives=min(9,self.lives+earned);self:emit("extraLife",self.player.x,self.player.y,self.player.z) end
end

function World:breakCrate(box)
  if box.broken then return end
  box.broken=true;local b=self.def.platforms[box.platform]
  self:addCoins(5)
  if box.heart then self.player.hp=min(3,self.player.hp+1) end
  self:emit("break",b.x+box.dx,b.y+.6,b.z+box.dz,box.heart)
end

function World:updateBoss(dt,prevY)
  local b=self.def.boss;if not b or b.hp<=0 then return end
  local p=self.player
  if b.state=="sleep" then if distance(p,b)<12 then b.state="charge";b.timer=1.8;self:emit("bossWake",b.x,b.y,b.z) end;return end
  b.timer=b.timer-dt
  if b.state=="charge" and b.timer<=0 then b.state="wave";b.timer=1.8;b.radius=.4;self:emit("slam",b.x,b.y,b.z)
  elseif b.state=="wave" then
    b.radius=b.radius+7.5*dt
    if abs(distance(p,b)-b.radius)<.40 and p.y<b.y+.65 then self:damage(false,b.x,b.z) end
    if b.timer<=0 then b.state="rest";b.timer=3.6 end
  elseif b.state=="rest" then
    if distance(p,b)<1.35 and p.vy<-.5 and prevY>=b.y+2.9 and p.y<b.y+3.35 then
      b.hp=b.hp-1;p.vy=11;p.jumps=1;p.pound=false;p.invul=1
      b.state="charge";b.timer=2;self:emit("bossHit",b.x,b.y+2,b.z)
      if b.hp<=0 then self:emit("bossDefeat",b.x,b.y+2,b.z) end
    elseif b.timer<=0 then b.state="charge";b.timer=1.8 end
  end
  if distance(p,b)<1.2 and p.y<b.y+2.8 and p.y+1.7>b.y and b.state~="rest" then self:damage(false,b.x,b.z) end
end
return World
