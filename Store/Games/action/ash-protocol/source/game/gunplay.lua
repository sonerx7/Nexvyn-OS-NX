local G={capacity={12,6,24,4},duration={1.15,1.9,1.55,2.1}}
function G.init(w,snapshot)
 w.magazines={12,math.min(6,w.ammo[1]),math.min(24,w.ammo[2]),math.min(4,math.floor(w.ammo[2]/5))};w.reloadTimer=0;w.reloadDuration=0;w.player.ads=0
 if snapshot and snapshot.magazines then for i=1,4 do w.magazines[i]=math.max(0,math.min(G.capacity[i],tonumber(snapshot.magazines[i]) or 0)) end end
end
function G.reload(w)
 local n=w.weapon
 if w.reloadTimer>0 or w.magazines[n]>=G.capacity[n] then return false end
 local ammoIndex=n==2 and 1 or n>2 and 2 or 0;local cost=n==4 and 5 or 1
 if ammoIndex>0 and (w.ammo[ammoIndex] or 0)<cost then return false end
 w.reloadDuration=G.duration[n];w.reloadTimer=w.reloadDuration;w.reloadWeapon=n;w:emit('reload',n);return true
end
function G.update(w,dt,c)
 local p=w.player;local target=c.aim and not c.run and p.dash<=0 and w.reloadTimer<=0 and 1 or 0
 p.ads=p.ads+(target-p.ads)*math.min(1,dt*12)
 w.hitMarker=math.max(0,(w.hitMarker or 0)-dt)
 if c.reload then G.reload(w) end
 if w.reloadTimer>0 then
  w.reloadTimer=math.max(0,w.reloadTimer-dt)
  if w.reloadTimer==0 and w.reloadWeapon==w.weapon then
   local n=w.weapon;local ammoIndex=n==2 and 1 or n>2 and 2 or 0;local cost=n==4 and 5 or 1
   w.magazines[n]=ammoIndex==0 and G.capacity[n] or math.min(G.capacity[n],math.floor(w.ammo[ammoIndex]/cost));w:emit('loaded',n)
  end
 end
end
return G
