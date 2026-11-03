local Maps=require('game.maps')
local E={}
function E.begin(w)
 if w.node.kind~='combat' and w.node.kind~='elite' then w.encounter=nil;return false end
 w.encounter={wave=0,total=w.node.kind=='elite' and 3 or 2,waiting=0}
 E.wave(w);return true
end
function E.wave(w)
 local e=w.encounter;e.wave=e.wave+1;e.waiting=0
 -- Recycle corpses between waves, keeping collision/separation work bounded.
 local alive={};for _,a in ipairs(w.enemies) do if not a.dead then alive[#alive+1]=a end end;w.enemies=alive
 local count=8+w.biome*2+e.wave*2
 for i=1,count do
  local x,y
  for attempt=1,80 do
   local angle=w.rng:next()*math.pi*2;local radius=200+w.rng:next()*200
   x=math.max(100,math.min(w.map.w*32-100,w.player.x+math.cos(angle)*radius))
   y=math.max(100,math.min(w.map.h*32-100,w.player.y+math.sin(angle)*radius))
   if not Maps.blocked(w.map,x,y,14) then break end;x=nil
  end
  if x then local kind=(i+e.wave+w.biome-3)%10+1;local a=w:spawn(kind,x,y);a.spawnIn=.8 end
 end
 w.waveBanner=2.4;w:event('wave',e.wave)
end
function E.empty(w,dt)
 if not w.encounter or w.encounter.wave>=w.encounter.total then return true end
 local e=w.encounter
 if e.waiting<=0 then e.waiting=2.2;w:event('wavewarn');return false end
 e.waiting=e.waiting-(dt or 1/60)
 if e.waiting<=0 then E.wave(w) end
 return false
end
return E
