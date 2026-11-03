-- Stepped, low-resolution lantern mask. Integer pixels and coalesced spans;
-- no full-screen bitmap allocation, blur or per-frame texture upload.
local L={}
local floor,min,max,sqrt=math.floor,math.min,math.max,math.sqrt
function L.draw(w,cx,cy,rect,glow)
 local p=w.player;local lights={{p.x-cx+11,p.y-cy-20,148+floor((glow or 0)*24),1}}
 for _,prop in ipairs(w.map.props) do
  if prop.light and #lights<14 and prop.x-cx>-100 and prop.x-cx<740 and prop.y-cy>-100 and prop.y-cy<460 then
   lights[#lights+1]={prop.x-cx,prop.y-cy-24,84,.75+.08*math.sin(w.time*5+prop.x)}
  end
 end
 for _,e in ipairs(w.enemies) do if e.boss and not e.dead then lights[#lights+1]={e.x-cx,e.y-cy-25,96,.65} end end
 local colors={};for a=0,7 do colors[a]='#060F20'..string.format('%02X',a*12) end
 for y=0,359,16 do
  local start,last=0,nil
  for x=0,640,16 do
   local shade=0
   if x<640 then
    local amount=0
    for _,l in ipairs(lights) do
     local dx,dy=x+8-l[1],y+8-l[2];local d2=dx*dx+dy*dy
     if d2<l[3]*l[3] then amount=max(amount,(1-sqrt(d2)/l[3])*l[4]) end
    end
    shade=min(7,max(0,floor((1-amount)*7)))
   end
   if shade~=last or x==640 then
    if last and last>0 then rect(start,y,x-start,min(16,360-y),colors[last]) end
    start=x;last=shade
   end
  end
 end
 -- Tiny flame and its hard pixel highlights sit above the darkness mask.
 local x,y=floor(p.x-cx+11),floor(p.y-cy-20)
 rect(x-2,y-2,5,6,'#D98948');rect(x-1,y-3,3,6,'#FFD796');rect(x,y-2,1,3,'#FFF0CF')
end
return L
