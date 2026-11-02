local C=require('game.content')
local Maps=require('game.maps')
local Random=require('game.random')
local W={};W.__index=W
local pi,sin,cos,sqrt,min,max=math.pi,math.sin,math.cos,math.sqrt,math.min,math.max
local function dist(a,b)local x,y=a.x-b.x,a.y-b.y;return sqrt(x*x+y*y)end
local function norm(x,y)local l=sqrt(x*x+y*y);if l<.001 then return 0,1 end;return x/l,y/l end
local function copy(v)if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
W.copy=copy
function W.new(seed,weapon,meta,snapshot)
 if snapshot and snapshot.revision==1 then
  local w=setmetatable(copy(snapshot),W);w.rng=Random.new(snapshot.rngstate);w.events={};w.particles={};w.flow=nil;w.flowTimer=0;return w
 end
 meta=meta or {};local w=setmetatable({revision=1,seed=seed or 1,weapon=weapon or 1,biome=1,row=0,lane=2,
   phase='route',boons={},gold=0,shards=0,kills=0,clears=0,time=0,events={},enemies={},shots={},tells={},loot={},particles={},
   visited={},meta=copy(meta),nextId=1,hits=0,roomTime=0,objectUsed=false,clear=false},W)
 w.rng=Random.new(w.seed);w.player={x=464,y=560,hp=100+(meta.health or 0)*5,maxhp=100+(meta.health or 0)*5,
   potions=2+(meta.flask or 0),ax=0,ay=-1,face=3,attack=0,invul=0,dash=0,dashcd=0,skillcd=0,walk=0,shield=0}
 w.routes=Maps.routes(w.seed,1);return w
end
function W:rank(id)return self.boons[id] or 0 end
function W:event(kind,data)if #self.events<40 then self.events[#self.events+1]={kind=kind,data=data} end end
function W:particle(x,y,color,n)
 for _=1,min(n or 8,180-#self.particles) do local a=self.rng:next()*pi*2;local speed=self.rng:int(20,90)
  self.particles[#self.particles+1]={x=x,y=y,vx=cos(a)*speed,vy=sin(a)*speed,life=.25+self.rng:next()*.35,color=color,size=self.rng:int(1,3)} end
end
function W:stats()
 local p=self.player;local weapon=C.weapons[self.weapon]
 return {damage=weapon.damage*(1+.18*self:rank('edge')+.12*self:rank('relic')+.35*self:rank('glass')+.05*(self.meta.power or 0)+
   (p.hp<p.maxhp*.3 and .25*self:rank('resolve') or 0)),cool=weapon.cool*(.9^self:rank('haste')),speed=112*(1+.1*self:rank('stride')),
   dashcd=.88*(.8^self:rank('dash')),skillcd=max(4,14-2*self:rank('focus'))}
end
function W:addBoon(id)
 local b=C.byId[id];if not b or self:rank(id)>=b.max then return false end
 self.boons[id]=self:rank(id)+1;local p=self.player
 if id=='vital' then p.maxhp=p.maxhp+15;p.hp=min(p.maxhp,p.hp+15)
 elseif id=='flask' then p.potions=p.potions+1
 elseif id=='relic' then p.maxhp=p.maxhp+10;p.hp=min(p.maxhp,p.hp+20);p.potions=p.potions+1 end
 self:particle(p.x,p.y,'#b6e9d0',22);self:event('boon',id);return true
end
function W:offer(rare)
 local pool={};for _,b in ipairs(C.boons) do if self:rank(b.id)<b.max and (not rare or b.rarity>=2) then
  for _=1,(b.rarity==1 and 3 or b.rarity==2 and 2 or 1) do pool[#pool+1]=b.id end end end
 local out={};while #out<3 and #pool>0 do
  local id=self.rng:pick(pool);out[#out+1]=id
  for i=#pool,1,-1 do if pool[i]==id then table.remove(pool,i) end end
 end
 return out
end
function W:takeReward(index)
 if self.phase~='reward' or not self.rewards[index] then return false end
 self:addBoon(self.rewards[index]);self.rewards=nil;self.phase='play';self:event('save');return true
end
function W:available(lane)
 if self.phase~='route' then return false end
 local row=self.row+1
 return row==5 and lane==1 or row<=4 and lane>=1 and lane<=3 and (row==1 or math.abs(lane-self.lane)<=1)
end
function W:spawn(kind,x,y,boss)
 local e={id=self.nextId,kind=kind,x=x,y=y,homeX=x,homeY=y,boss=boss or false,r=boss and 24 or 12,
 hp=boss and (260+self.biome*115) or (23+self.biome*10+(kind>=6 and 18 or 0)),timer=1+self.rng:next(),
 invul=0,slow=0,burn=0,poison=0,stacks=0,bleed=0,flash=0,state='walk',cycle=0,age=0}
 e.maxhp=e.hp;self.nextId=self.nextId+1;self.enemies[#self.enemies+1]=e;return e
end
function W:choose(lane)
 if not self:available(lane) then return false end
 self.row=self.row+1;self.lane=lane;self.node=copy(self.routes[self.row][lane]);self.visited[self.biome..':'..self.row..':'..lane]=true
 self.map=Maps.build(self.node.seed,self.biome,self.node.kind);self.roomTime=0;self.enemies={};self.shots={};self.tells={};self.loot={};self.particles={}
 local p=self.player;p.x=self.map.entry.x;p.y=self.map.entry.y;p.invul=1.1;p.shield=self:rank('shield');p.dash=0;p.attack=0
 self.objectUsed=false;self.clear=false;self.phase='play';self.pendingReward=false;self.flow=nil;self.flowTimer=0
 if self.node.kind=='boss' then self:spawn(self.biome,self.map.w*16,7*32,true)
 elseif self.node.kind=='combat' or self.node.kind=='elite' then
  local r=Random.new(self.node.seed+21);local n=4+self.biome+(self.node.kind=='elite' and 3 or 0)
  for i=1,n do local x,y=r:int(4,24)*32+16,r:int(4,12)*32+16
   while Maps.blocked(self.map,x,y,14) do x,y=r:int(4,24)*32+16,r:int(4,12)*32+16 end
   local kind=i%3==0 and min(10,self.biome+5) or ((self.biome+i-2)%5+1);self:spawn(kind,x,y)
  end
 else self.clear=true end
 self:event('room',self.biome);self:event('save');return true
end
function W:snapshot()
 local t={};for k,v in pairs(self) do if k~='rng' and k~='events' and k~='particles' and k~='flow' then t[k]=copy(v) end end
 t.rngstate=self.rng.state;return t
end
function W:heal()
 local p=self.player;if self.phase~='play' or p.potions<1 or p.hp>=p.maxhp then return false end
 p.potions=p.potions-1;p.hp=min(p.maxhp,p.hp+40+self:rank('flask')*10);self:particle(p.x,p.y,'#afd9a0',24);self:event('boon');return true
end
function W:hurt(amount)
 local p=self.player;if p.invul>0 or self.phase~='play' then return false end
 if p.shield>0 then p.shield=p.shield-1;p.invul=.5;self:particle(p.x,p.y,'#cfdbbd',18);return false end
 amount=max(1,amount*(1-.08*self:rank('guard'))*(1+.15*self:rank('glass')))
 p.hp=max(0,p.hp-amount);p.invul=.7;self:particle(p.x,p.y,'#e6a880',16);self:event('hurt',amount)
 if self:rank('thorns')>0 then self:blast(p.x,p.y,70,15*self:rank('thorns'),false) end
 if p.hp<=0 then self.phase='dead';self:event('end',false) end;return true
end
function W:hit(e,damage,secondary)
 if e.dead then return end
 if not secondary then
  self.hits=self.hits+1
  if self.rng:next()<.06+.08*self:rank('crit') then damage=damage*1.8 end
  if e.hp<e.maxhp*.35 then damage=damage*(1+.3*self:rank('execute')+(e.bleed>0 and self:rank('execute')>0 and .35 or 0)) end
  if e.burn>0 and self:rank('frost')>0 and self:rank('ember')>0 and (e.thermal or 0)<=0 then damage=damage+18;e.thermal=1;self:particle(e.x,e.y,'#dbe7c6',12) end
  if self:rank('ember')>0 then e.burn=3;e.burnRank=self:rank('ember') end
  if self:rank('frost')>0 or self.weapon==3 then e.slow=2 end
  if self:rank('venom')>0 then e.poison=5;e.stacks=min(6,e.stacks+1) end
  if self:rank('bleed')>0 then e.bleed=4 end
 end
 e.hp=e.hp-damage;e.flash=.11;self:particle(e.x,e.y,'#e9d3a1',4)
 if not secondary and self:rank('spark')>0 and self.hits%4==0 then
  local count=0;for _,other in ipairs(self.enemies) do if other~=e and not other.dead and dist(e,other)<120 and Maps.los(self.map,e.x,e.y,other.x,other.y) then
   self:hit(other,12*self:rank('spark'),true);self:particle(other.x,other.y,'#b1d7f4',8);count=count+1;if count>=3 then break end
  end end
 end
 if e.hp<=0 and not e.dead then
  e.dead=true;e.deathTime=self.time;self.kills=self.kills+1
  self:particle(e.x,e.y,C.biomes[self.biome].color,e.boss and 60 or 18)
  self.loot[#self.loot+1]={x=e.x,y=e.y,kind='gold',value=math.floor((e.boss and 50 or 5+self.biome)*(1+.25*self:rank('fortune')))}
  if self.rng:next()<.14 then self.loot[#self.loot+1]={x=e.x+8,y=e.y,kind='heart',value=7} end
  self.shards=self.shards+(e.boss and 12+self.biome*3 or self.rng:next()<.24 and 1 or 0)
  if self:rank('leech')>0 and self.kills%5==0 then self.player.hp=min(self.player.maxhp,self.player.hp+5*self:rank('leech')*(self:rank('renew')>0 and 2 or 1)) end
  if self:rank('blast')>0 then self:blast(e.x,e.y,46,10*self:rank('blast'),self:rank('venom')>0) end
 end
end
function W:blast(x,y,r,damage,venom)
 self:particle(x,y,'#e5c489',16)
 for _,e in ipairs(self.enemies) do if not e.dead and dist(e,{x=x,y=y})<r+e.r and Maps.los(self.map,x,y,e.x,e.y) then
  if venom then e.poison=5;e.stacks=max(e.stacks,3) end;self:hit(e,damage,true)
 end end
end
function W:projectile(x,y,a,speed,damage,enemy,life,pierce,color)
 if #self.shots>=260 then return end
 self.shots[#self.shots+1]={x=x,y=y,vx=cos(a)*speed,vy=sin(a)*speed,damage=damage,enemy=enemy,life=life or 3,r=enemy and 5 or 4,
 pierce=pierce or 0,hit={},color=color or (enemy and '#f0a378' or '#9fe9d3')}
end
function W:attack()
 local p=self.player;if self.phase~='play' or p.attack>0 or p.dash>0 then return false end
 local s=self:stats();p.attack=s.cool;p.swing=.16;self:event('attack')
 if self.weapon==1 then
  for _,e in ipairs(self.enemies) do if not e.dead and dist(p,e)<C.weapons[1].reach+e.r then
   local dx,dy=norm(e.x-p.x,e.y-p.y)
   if (dx*p.ax+dy*p.ay)>.05 and Maps.los(self.map,p.x,p.y,e.x,e.y) then self:hit(e,s.damage);Maps.move(self.map,e,dx*12,dy*12,e.r) end
  end end
 else
  local angle=math.atan(p.ay,p.ax);local extra=self:rank('echo')
  for i=0,extra do local off=(i-extra/2)*.14
   self:projectile(p.x+p.ax*16,p.y+p.ay*16,angle+off,self.weapon==2 and 360 or 275,s.damage,false,1.25,self:rank('pierce')+(self.weapon==2 and 1 or 0))
  end
 end;return true
end
function W:dash(dx,dy)
 local p=self.player;if self.phase~='play' or p.dashcd>0 then return false end
 if dx*dx+dy*dy<.01 then dx,dy=p.ax,p.ay end;dx,dy=norm(dx,dy);p.dashX=dx;p.dashY=dy;p.dash=.16;p.invul=max(p.invul,.24);p.dashcd=self:stats().dashcd
 if self:rank('dashfire')>0 then self.tells[#self.tells+1]={x=p.x,y=p.y,r=self:rank('ember')>0 and 68 or 46,t=.22,life=.28,friendly=true,damage=18*self:rank('dashfire'),ember=self:rank('ember')>0} end
 self:particle(p.x,p.y,'#96c9bc',14);self:event('dash');return true
end
function W:skill()
 local p=self.player;if self.phase~='play' or p.skillcd>0 then return false end
 p.skillcd=self:stats().skillcd;self:blast(p.x,p.y,135,40*(1+.3*self:rank('nova')),false)
 for _,s in ipairs(self.shots) do if s.enemy and dist(p,s)<145 then s.life=0 end end
 self:event('skill');return true
end
function W:tell(x,y,r,delay,damage,life)
 if #self.tells<72 then self.tells[#self.tells+1]={x=x,y=y,r=r,t=delay,damage=damage,life=life or .4} end
end
function W:enemyFire(e,n,spread,speed)
 local a=math.atan(self.player.y-e.y,self.player.x-e.x)
 for i=1,n do self:projectile(e.x,e.y,a+(i-(n+1)/2)*spread,speed or 95,10+self.biome*2,true,5) end
end
function W:bossStep(e,dt)
 e.timer=e.timer-dt;local p=self.player
 if e.state=='charge' then
  Maps.move(self.map,e,e.cx*220*dt,e.cy*220*dt,e.r)
  if dist(e,p)<e.r+10 then self:hurt(20+self.biome*2) end
  if e.timer<=0 then e.state='recover';e.timer=1.1 end
 elseif e.state=='windup' then
  if e.timer<=0 then
   local k=e.kind;local cycle=e.cycle%3
   if k==1 then
    if cycle==0 then e.cx,e.cy=norm(p.x-e.x,p.y-e.y);e.state='charge';e.timer=.85
    else for i=-2,2 do self:tell(p.x+i*40,p.y,25,.55,18,1.2) end;self:enemyFire(e,5,.3,100) end
   elseif k==2 then
    if cycle==0 then for i=0,11 do self:projectile(e.x,e.y,i*pi/6,105,17,true,5) end
    else for i=1,5 do self:tell(p.x+self.rng:int(-90,90),p.y+self.rng:int(-75,75),34,.65,22,.65) end end
   elseif k==3 then
    if cycle==0 then for i=0,15 do self:projectile(e.x,e.y,i*pi/8+e.cycle*.2,75,16,true,6,0,'#b6e9ed') end
    else self:enemyFire(e,7,.17,135);self:tell(p.x,p.y,52,.85,25,1.2) end
   elseif k==4 then
    for i=1,4 do self:tell(p.x+self.rng:int(-100,100),p.y+self.rng:int(-80,80),37,.65,17,2.3) end
    if cycle==0 then local alive=0;for _,v in ipairs(self.enemies) do if not v.dead then alive=alive+1 end end
     if alive<10 then self:spawn(4,e.x-55,e.y+35);self:spawn(9,e.x+55,e.y+35) end
    else self:enemyFire(e,5,.35,115) end
   else
    if cycle==0 then
     for i=0,19 do self:projectile(e.x,e.y,i*pi/10+e.cycle*.21,95,18,true,6,0,'#c8b6f0') end
     self:tell(p.x,p.y,46,.65,25,1)
    elseif cycle==1 then self:enemyFire(e,9,.13,155)
    else
     local x,y=self.rng:int(5,23)*32+16,self.rng:int(5,13)*32+16
     if not Maps.blocked(self.map,x,y,e.r) then self:particle(e.x,e.y,'#b4a7e5',24);e.x=x;e.y=y;self:particle(e.x,e.y,'#b4a7e5',24) end
     self:enemyFire(e,5,.25,125)
    end
   end
   if e.state~='charge' then e.state='recover';e.timer=e.hp<e.maxhp*.5 and .65 or 1.2 end
   self:event('bossattack')
  end
 elseif e.timer<=0 then
  e.cycle=e.cycle+1;e.state='windup';e.timer=e.hp<e.maxhp*.5 and .6 or .9
  e.targetX=p.x;e.targetY=p.y
 else
  local dx,dy=norm(p.x-e.x,p.y-e.y)
  if dist(e,p)>135 then Maps.move(self.map,e,dx*30*dt,dy*30*dt,e.r) end
 end
end
function W:enemyStep(e,dt)
 e.age=e.age+dt;e.flash=max(0,e.flash-dt);e.slow=max(0,e.slow-dt);e.thermal=max(0,(e.thermal or 0)-dt)
 local dot=0
 if e.burn>0 then e.burn=e.burn-dt;dot=dot+4*(e.burnRank or 1) end
 if e.poison>0 then e.poison=e.poison-dt;dot=dot+e.stacks*(1+self:rank('venom')) else e.stacks=0 end
 if e.bleed>0 then e.bleed=e.bleed-dt;dot=dot+3*self:rank('bleed') end
 if dot>0 then self:hit(e,dot*dt,true);if e.dead then return end end
 if e.boss then self:bossStep(e,dt);return end
 e.timer=e.timer-dt;local p=self.player;local d=dist(e,p);local dx,dy=norm(p.x-e.x,p.y-e.y)
 local caster=e.kind==3 or e.kind==4 or e.kind==5 or e.kind==7 or e.kind==10
 if self.flow and not Maps.los(self.map,e.x,e.y,p.x,p.y) then local fx,fy=Maps.toward(self.map,self.flow,e.x,e.y);if fx*fx+fy*fy>.01 then dx,dy=norm(fx,fy) end end
 local speed=(e.kind==6 and 86 or 47+self.biome*3)*(e.slow>0 and .5 or 1)
 if not caster or d>180 then
  -- Slide around masonry rather than walking through it. A perpendicular nudge
  -- breaks corner stalls without permitting enemies to cross collision tiles.
  local px,py=e.x,e.y;Maps.move(self.map,e,dx*speed*dt,dy*speed*dt,e.r)
  if math.abs(e.x-px)+math.abs(e.y-py)<speed*dt*.25 then Maps.move(self.map,e,-dy*speed*dt,dx*speed*dt,e.r) end
 elseif d<100 then Maps.move(self.map,e,-dx*speed*dt,-dy*speed*dt,e.r) end
 if d<e.r+13 then self:hurt(9+self.biome*2) end
 if caster and e.timer<=0 and d<360 and Maps.los(self.map,e.x,e.y,p.x,p.y) then
  if e.kind==4 then self:tell(p.x,p.y,28,.8,12+self.biome,.9)
  else self:enemyFire(e,e.kind==7 and 3 or 1,.2,e.kind==10 and 140 or 95) end
  e.timer=1.6+self.rng:next()*.8
 end
end
function W:completeRoom()
 if self.pendingReward or self.clear then return end
 self.pendingReward=true;self.clears=self.clears+1;self.player.hp=min(self.player.maxhp,self.player.hp+4*self:rank('renew'))
 -- Collect pending drops before the modal reward so gold cannot be stranded.
 for _,l in ipairs(self.loot) do if l.kind=='gold' then self.gold=self.gold+l.value else self.player.hp=min(self.player.maxhp,self.player.hp+l.value) end end;self.loot={}
 self.clear=true;self.rewards=self:offer(self.node.kind=='boss' or self.node.kind=='elite');self.phase='reward';self:event('clear');self:event('save')
end
function W:interact()
 if self.phase~='play' then return false end
 local p=self.player
 if self.clear and dist(p,self.map.exit)<55 then
  if self.node.kind=='boss' then
   if self.biome==5 then self.phase='won';self:event('end',true);return true end
   self.biome=self.biome+1;self.row=0;self.lane=2;self.routes=Maps.routes(self.seed,self.biome);self.player.hp=min(p.maxhp,p.hp+25);p.potions=min(5,p.potions+1)
  end
  self.phase='route';self:event('save');return true
 end
 if dist(p,self.map.object)<60 and not self.objectUsed then
  local kind=self.node.kind
  if kind=='treasure' then self.objectUsed=true;self.gold=self.gold+25;self.rewards=self:offer(true);self.phase='reward';self:event('boon')
  elseif kind=='shop' then self.phase='shop'
  elseif kind=='shrine' then self.phase='shrine'
  elseif kind=='rest' then self.objectUsed=true;p.hp=min(p.maxhp,p.hp+35);p.potions=min(5,p.potions+1);self:event('boon');self:event('save') end
  return true
 end
 return false
end
function W:shop(index)
 if self.phase~='shop' then return false end
 local prices={35,45,65};if index==4 then self.phase='play';return true end
 local cost=prices[index];if not cost or self.gold<cost then self:event('poor');return false end
 if index==1 and self.player.hp>=self.player.maxhp then return false end
 if index==2 and self.player.potions>=5 then return false end
 self.gold=self.gold-cost
 if index==1 then self.player.hp=min(self.player.maxhp,self.player.hp+30)
 elseif index==2 then self.player.potions=self.player.potions+1
 elseif index==3 then self.rewards=self:offer(true);self.phase='reward' end
 self:event('boon');self:event('save');return true
end
function W:shrine(index)
 if self.phase~='shrine' then return false end
 local p=self.player
 if index==1 then
  if p.maxhp<=35 then return false end;p.maxhp=p.maxhp-12;p.hp=min(p.hp,p.maxhp);self.rewards=self:offer(true);self.phase='reward'
 else p.hp=min(p.maxhp,p.hp+18);self.phase='play' end
 self.objectUsed=true;self:event('save');return true
end
function W:step(dt,c)
 if self.phase~='play' then return end
 c=c or {};dt=min(dt,1/30);self.time=self.time+dt;self.roomTime=self.roomTime+dt;local p=self.player
 p.invul=max(0,p.invul-dt);p.attack=max(0,p.attack-dt);p.swing=max(0,(p.swing or 0)-dt);p.dashcd=max(0,p.dashcd-dt);p.skillcd=max(0,p.skillcd-dt)
 local dx,dy=c.x or 0,c.y or 0;local l=sqrt(dx*dx+dy*dy);if l>1 then dx,dy=dx/l,dy/l end
 if c.ax and c.ay and c.ax*c.ax+c.ay*c.ay>.01 then p.ax,p.ay=norm(c.ax,c.ay) end
 if c.autoaim then
  local nearest,distance=nil,350
  for _,e in ipairs(self.enemies) do if not e.dead then local d=dist(p,e);if d<distance and Maps.los(self.map,p.x,p.y,e.x,e.y) then nearest=e;distance=d end end end
  if nearest then p.ax,p.ay=norm(nearest.x-p.x,nearest.y-p.y) elseif l>.1 then p.ax,p.ay=norm(dx,dy) end
 end
 if math.abs(p.ax)>math.abs(p.ay) then p.face=p.ax<0 and 1 or 2 else p.face=p.ay<0 and 3 or 0 end
 if c.dash then self:dash(dx,dy) end;if c.heal then self:heal() end;if c.skill then self:skill() end
 if p.dash>0 then p.dash=p.dash-dt;Maps.move(self.map,p,p.dashX*390*dt,p.dashY*390*dt,9)
 else Maps.move(self.map,p,dx*self:stats().speed*dt,dy*self:stats().speed*dt,9) end
 if l>.1 then p.walk=p.walk+dt*10 end
 self.flowTimer=(self.flowTimer or 0)-dt
 if self.flowTimer<=0 then self.flow=Maps.flow(self.map,p.x,p.y);self.flowTimer=.35 end
 if c.attack then self:attack() end
 for _,e in ipairs(self.enemies) do if not e.dead then self:enemyStep(e,dt) end end
 -- Separate living bodies, including bosses, so contact attacks remain readable.
 for i=1,#self.enemies do local a=self.enemies[i];if not a.dead then
  for j=i+1,#self.enemies do local b=self.enemies[j];if not b.dead then
   local d=dist(a,b);local rr=a.r+b.r;if d>0 and d<rr then local nx,ny=norm(a.x-b.x,a.y-b.y);local push=(rr-d)*.3;Maps.move(self.map,a,nx*push,ny*push,a.r);Maps.move(self.map,b,-nx*push,-ny*push,b.r) end
  end end
 end end
 for i=#self.shots,1,-1 do local s=self.shots[i];s.life=s.life-dt
  local steps=max(1,math.ceil(max(math.abs(s.vx*dt),math.abs(s.vy*dt))/5))
  for _=1,steps do if s.life>0 then
   s.x=s.x+s.vx*dt/steps;s.y=s.y+s.vy*dt/steps
   if Maps.solid(self.map,s.x,s.y) then s.life=0
   elseif s.enemy then if dist(s,p)<s.r+9 then self:hurt(s.damage);s.life=0 end
   else
    for _,e in ipairs(self.enemies) do if not e.dead and not s.hit[tostring(e.id)] and dist(s,e)<s.r+e.r then
     s.hit[tostring(e.id)]=true;self:hit(e,s.damage);s.pierce=s.pierce-1;if s.pierce<0 then s.life=0;break end
    end end
   end
  end end
  if s.life<=0 then table.remove(self.shots,i) end
 end
 for i=#self.tells,1,-1 do local t=self.tells[i];t.t=t.t-dt
  if t.t<=0 then
   if not t.triggered then
    t.triggered=true
    if t.friendly then self:blast(t.x,t.y,t.r,t.damage,false);if t.ember then for _,e in ipairs(self.enemies) do if not e.dead and dist(t,e)<t.r+e.r then e.burn=3;e.burnRank=self:rank('ember') end end end end
   end
   if not t.friendly and dist(t,p)<t.r+7 then self:hurt(t.damage) end
   t.life=t.life-dt;if t.life<=0 then table.remove(self.tells,i) end
  end
 end
 if self:rank('orbit')>0 then
  self.orbitTimer=(self.orbitTimer or 0)-dt
  if self.orbitTimer<=0 then self.orbitTimer=.24
   for orb=1,self:rank('orbit') do local a=self.time*2.3+orb*2*pi/self:rank('orbit');local o={x=p.x+cos(a)*44,y=p.y+sin(a)*44}
    for _,e in ipairs(self.enemies) do if not e.dead and dist(o,e)<e.r+12 and Maps.los(self.map,p.x,p.y,e.x,e.y) then self:hit(e,7,self:rank('spark')==0) end end
   end
  end
 end
 for _,h in ipairs(self.map.hazards) do if (self.time+h.phase)%4<.8 and dist(h,p)<h.r and p.dash<=0 then self:hurt(8+self.biome) end end
 for i=#self.loot,1,-1 do local l=self.loot[i];local d=dist(l,p)
  if d<52+self:rank('magnet')*45 then local nx,ny=norm(p.x-l.x,p.y-l.y);l.x=l.x+nx*180*dt;l.y=l.y+ny*180*dt end
  if d<16 then if l.kind=='gold' then self.gold=self.gold+l.value else p.hp=min(p.maxhp,p.hp+l.value) end;table.remove(self.loot,i);self:event('coin') end
 end
 for i=#self.particles,1,-1 do local q=self.particles[i];q.x=q.x+q.vx*dt;q.y=q.y+q.vy*dt;q.life=q.life-dt;q.vx=q.vx*.96;q.vy=q.vy*.96;if q.life<=0 then table.remove(self.particles,i) end end
 if c.use then self:interact() end
 if not self.clear and self.phase=='play' then local alive=false;for _,e in ipairs(self.enemies) do if not e.dead then alive=true;break end end;if not alive then self:completeRoom() end end
end
return W
