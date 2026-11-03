local Random=require('game.random')
local M={W=59,H=43,T=32}
function M.routes(seed,biome)
 local r=Random.new(seed+biome*7919);local rows={}
 for y=1,4 do rows[y]={};for lane=1,3 do
  local kind='combat'
  if y==2 then kind=({'combat','treasure','shrine'})[(lane+biome)%3+1]
  elseif y==3 then kind=({'elite','shop','combat'})[r:int(1,3)]
  elseif y==4 then kind=({'elite','rest','combat'})[(lane+biome)%3+1] end
  rows[y][lane]={row=y,lane=lane,kind=kind,seed=r:int(1,2000000000)}
 end end
 rows[5]={{row=5,lane=1,kind='boss',seed=r:int(1,2000000000)}};return rows
end
function M.build(seed,biome,kind)
 local r=Random.new(seed);local combat=kind=='combat' or kind=='elite'
 local m={w=combat and 59 or kind=='boss' and 43 or 37,h=combat and 43 or kind=='boss' and 33 or 27,tiles={},solids={},props={},hazards={},seed=seed,kind=kind}
 local cx,cy=math.floor(m.w/2),math.floor(m.h/2)
 local function paint(x,y,tile,solid)
  if x>2 and x<m.w-3 and y>2 and y<m.h-3 then local i=y*m.w+x+1;m.tiles[i]=tile;m.solids[i]=solid or false end
 end
 for y=0,m.h-1 do for x=0,m.w-1 do
  local i=y*m.w+x+1;local edge=x<2 or y<2 or x>=m.w-2 or y>=m.h-2
  m.tiles[i]=edge and r:int(13,16) or r:int(1,12);m.solids[i]=edge
 end end
 -- Four authored district motifs around a central crossing, scaled to each room.
 for district=1,4 do
  local ox=math.floor(m.w*(district%2==1 and .25 or .75));local oy=math.floor(m.h*(district<3 and .27 or .70))
  for dy=-5,5 do for dx=-6,6 do
   local x,y=ox+dx,oy+dy
   if biome==1 then
    if (dy==-4 or dy==4) and math.abs(dx)>1 then paint(x,y,14,true)
    elseif dx*dx+dy*dy<12 then paint(x,y,21+((x+y)%4),false) end
   elseif biome==2 then
    if math.abs(dx)<2 and math.abs(dy)>1 then paint(x,y,18,true)
    elseif math.abs(dy)<2 then paint(x,y,26,false) end
   elseif biome==3 then
    if math.abs(dy)==3 and math.abs(dx)>2 then paint(x,y,15,true)
    elseif math.abs(dx)<4 and math.abs(dy)<2 then paint(x,y,20,false) end
   elseif biome==4 then
    if dx*dx/25+dy*dy/12<1 and dx~=0 and dy~=0 then paint(x,y,18,true) end
   elseif math.abs(dx)==math.abs(dy) and math.abs(dx)>2 then paint(x,y,16,true)
   elseif dx*dx+dy*dy<16 then paint(x,y,12,false) end
  end end
  m.props[#m.props+1]={x=ox*32+16,y=(oy-5)*32+16,id=biome+5,light=true,animated=true}
 end
 -- Wide traversal spine and a circuit route tie the landmarks together.
 for y=2,m.h-3 do for x=cx-1,cx+1 do paint(x,y,21+y%4,false) end end
 for x=2,m.w-3 do for y=cy-1,cy+1 do paint(x,y,x%4==0 and 12 or 2,false) end end
 m.entry={x=cx*32+16,y=(m.h-4)*32+16};m.exit={x=cx*32+16,y=3.5*32}
 m.object={x=cx*32+16,y=cy*32+16,id=kind=='shop' and 16 or kind=='rest' and 17 or kind=='treasure' and 11 or 14}
 -- Connectivity repair carves bridges to the central aisle; disconnected scenery
 -- can never strand drops, wave spawns or the gate.
 local reached=M.flow(m,m.entry.x,m.entry.y)
 for y=3,m.h-4 do for x=3,m.w-4 do local id=y*m.w+x+1
  if not m.solids[id] and not reached[id] then
   for xx=math.min(cx,x),math.max(cx,x) do local old=m.tiles[y*m.w+xx+1];paint(xx,y,old==18 and 26 or 2,false) end
  end
 end end
 for i=1,(combat and 120 or 65) do
  local x,y=r:int(3,m.w-4),r:int(3,m.h-4)
  if math.abs(x-cx)>3 and math.abs(y-cy)>2 and not m.solids[y*m.w+x+1] then
   m.props[#m.props+1]={x=x*32+r:int(6,26),y=y*32+r:int(8,26),id=i%3==0 and r:int(27,32) or 17+biome,animated=i%7==0}
  end
 end
 if combat or kind=='boss' then for i=1,8 do
  local x,y=r:int(4,m.w-5),r:int(4,m.h-5)
  if math.abs(x-cx)>3 and not m.solids[y*m.w+x+1] then m.hazards[#m.hazards+1]={x=x*32+16,y=y*32+16,r=19,phase=r:next()*6} end
 end end
 return m
end
function M.solid(m,x,y)
 local tx,ty=math.floor(x/32),math.floor(y/32)
 return tx<0 or ty<0 or tx>=m.w or ty>=m.h or m.solids[ty*m.w+tx+1]
end
function M.blocked(m,x,y,r)
 return M.solid(m,x-r,y-r) or M.solid(m,x+r,y-r) or M.solid(m,x-r,y+r) or M.solid(m,x+r,y+r)
end
function M.move(m,e,dx,dy,r)
 local steps=math.max(1,math.ceil(math.max(math.abs(dx),math.abs(dy))/6));dx=dx/steps;dy=dy/steps
 for _=1,steps do if not M.blocked(m,e.x+dx,e.y,r) then e.x=e.x+dx end;if not M.blocked(m,e.x,e.y+dy,r) then e.y=e.y+dy end end
end
function M.los(m,x,y,tx,ty)
 local dx,dy=tx-x,ty-y;local n=math.max(1,math.ceil(math.sqrt(dx*dx+dy*dy)/9))
 for i=1,n do if M.solid(m,x+dx*i/n,y+dy*i/n) then return false end end;return true
end
function M.flow(m,x,y)
 local sx,sy=math.floor(x/32),math.floor(y/32);local start=sy*m.w+sx+1
 local out={[start]=0};local queue={start};local head=1
 while queue[head] do local id=queue[head];head=head+1;local tx,ty=(id-1)%m.w,math.floor((id-1)/m.w)
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do local xx,yy=tx+d[1],ty+d[2];local nextid=yy*m.w+xx+1
   if xx>=0 and yy>=0 and xx<m.w and yy<m.h and out[nextid]==nil and not m.solids[nextid] then out[nextid]=out[id]+1;queue[#queue+1]=nextid end
  end
 end;return out
end
function M.toward(m,flow,x,y)
 local tx,ty=math.floor(x/32),math.floor(y/32);local best=flow[ty*m.w+tx+1] or 9999;local gx,gy=x,y
 for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do local xx,yy=tx+d[1],ty+d[2];local value=flow[yy*m.w+xx+1]
  if value and value<best then best=value;gx=xx*32+16;gy=yy*32+16 end
 end
 return gx-x,gy-y
end
return M
