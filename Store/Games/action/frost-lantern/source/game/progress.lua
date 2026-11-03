local Maps=require('game.maps')
local P={}
function P.world(w,cx,cy,R)
 if not w.clear then return end
 if not w.gateFlow then w.gateFlow=Maps.flow(w.map,w.map.exit.x,w.map.exit.y) end
 local x,y=w.player.x,w.player.y
 for step=1,24 do
  local dx,dy=Maps.toward(w.map,w.gateFlow,x,y);local length=math.sqrt(dx*dx+dy*dy)
  if length<1 then break end
  x=x+dx/length*16;y=y+dy/length*16
  if step%2==0 then R.rect(x-cx-1,y-cy-2,3,2,step%4==math.floor(w.time*5)%4 and '#FFF0B5' or '#83BDA8') end
 end
 local ex,ey=w.map.exit.x-cx,w.map.exit.y-cy-18
 for j=1,10 do local a=j*math.pi/5+w.time;R.rect(ex+math.cos(a)*19,ey+math.sin(a)*25,2,3,'#AADFD1') end
end
function P.hud(w,R,C)
 local alive=0;for _,e in ipairs(w.enemies) do if not e.dead then alive=alive+1 end end
 local title=w.clear and C.t({'GEÇİT AÇILDI · İZİ TAKİP ET','GATE OPEN · FOLLOW THE TRAIL'}) or C.t({'MUHAFIZLAR','KEEPERS'})..' '..alive
 if w.encounter and not w.clear then title=C.t({'DALGA','WAVE'})..' '..w.encounter.wave..' / '..w.encounter.total..'   '..title end
 R.panel(174,54,290,24);R.text(title,180,60,1,'center',278)
 if (w.clearBanner or 0)>0 and w.phase=='play' then
  R.panel(172,95,296,43);R.text(C.t({'BÖLGE TAMAMLANDI','DISTRICT COMPLETE'}),180,100,2,'center',280)
  R.text(C.t({'Fener yolu çıkışı gösteriyor','Your lantern reveals the way out'}),180,121,1,'center',280)
 elseif w.encounter and w.encounter.waiting>0 then
  R.panel(204,92,232,25);R.text(C.t({'YENİ DALGA YAKLAŞIYOR','NEXT WAVE APPROACHING'}),211,98,1,'center',218)
 end
 -- Tiny integer-grid room map, matching the real collision map and landmarks.
 local m=w.map;local mx,my=570,86;R.panel(mx-4,my-4,66,50)
 for y=0,m.h-1 do for x=0,m.w-1 do if m.solids[y*m.w+x+1] then R.rect(mx+x,my+y,1,1,'#627578') end end end
 R.rect(mx+math.floor(w.player.x/32)-1,my+math.floor(w.player.y/32)-1,3,3,'#FFF1C2')
 R.rect(mx+math.floor(m.exit.x/32)-1,my+math.floor(m.exit.y/32)-1,3,3,w.clear and '#A8E3BF' or '#C89483')
 if w.clear then
  local dx,dy=m.exit.x-w.player.x,m.exit.y-w.player.y;local a=math.atan(dy,dx)
  local x=math.max(40,math.min(600,320+math.cos(a)*240));local y=math.max(100,math.min(270,180+math.sin(a)*100))
  for i=0,6 do R.rect(x-math.cos(a)*i*2,y-math.sin(a)*i*2,2,2,'#F5DE99') end
  for _,s in ipairs({-1,1}) do for i=0,4 do R.rect(x-math.cos(a+s*.65)*i*2,y-math.sin(a+s*.65)*i*2,2,2,'#F5DE99') end end
 end
end
return P
