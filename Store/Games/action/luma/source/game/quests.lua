local Q={}
function Q.update(w)
 local d,p=w.def,w.player;if not d.adventure then return end
 local function near(item,r)
  local b=d.platforms[item.platform]
  return math.abs(p.x-b.x-item.dx)<r and math.abs(p.z-b.z-item.dz)<r and math.abs(p.y-b.y)<1.2
 end
 for _,k in ipairs(d.keys) do if not k.collected and near(k,1) then k.collected=true;w:emit("key",p.x,p.y,p.z) end end
 local count=0;for _,s in ipairs(d.switches) do if s.active then count=count+1 end end
 for _,s in ipairs(d.switches) do
  if not s.active and near(s,1.1) then
   if not d.puzzleOrder or s.index==count+1 then s.active=true;count=count+1;w:emit("switch",p.x,p.y,p.z)
   elseif not w.wrongSwitchAt or w.time-w.wrongSwitchAt>2 then w.wrongSwitchAt=w.time;w:emit("order",p.x,p.y,p.z) end
  end
 end
 local keys=0;for _,k in ipairs(d.keys) do if k.collected then keys=keys+1 end end
 if keys==3 and not d.cage.opened and near(d.cage,2.4) then d.cage.opened=true;w:emit("rescue",p.x,p.y,p.z) end
 local alive=0;for _,e in ipairs(d.enemies) do if e.group=="arena" and e.alive then alive=alive+1 end end
 if alive==0 and not w.arenaCleared then w.arenaCleared=true;w:emit("arenaClear",p.x,p.y,p.z) end
 w.switchCount=count;w.keyCount=keys
end
function Q.available(w,star)
 return not star.unlock or (star.unlock=="arena" and w.arenaCleared) or (star.unlock=="rescue" and w.def.cage.opened)
end
return Q
