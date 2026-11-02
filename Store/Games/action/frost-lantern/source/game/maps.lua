local Random=require('game.random')
local M={W=29,H=21,T=32}
function M.routes(seed,biome)
 local r=Random.new(seed+biome*7919);local rows={}
 for y=1,4 do rows[y]={};for lane=1,3 do
  local kind='combat'
  if y==2 then kind=({'combat','treasure','shrine'})[(lane+biome)%3+1]
  elseif y==3 then kind=({'elite','shop','combat'})[r:int(1,3)]
  elseif y==4 then kind=({'elite','rest','combat'})[(lane+biome)%3+1] end
  rows[y][lane]={row=y,lane=lane,kind=kind,seed=r:int(1,2000000000)}
 end end
 rows[5]={{row=5,lane=1,kind='boss',seed=r:int(1,2000000000)}}
 return rows
end
function M.layout(m,r,biome)
 local function paint(x,y,tile,solid)
  if x>=2 and x<m.w-2 and y>=2 and y<m.h-2 and math.abs(x-14)>1 then
   m.tiles[y*m.w+x+1]=tile;m.solids[y*m.w+x+1]=solid or false
  end
 end
 local variant=r:int(0,2)
 if biome==1 then
  -- Broken cloister wings and a still-water crypt, crossed by a clear aisle.
  for _,yy in ipairs({6+variant,13-variant}) do for x=4,10 do if x~=7 then paint(x,yy,14,true) end end end
  for y=5,8 do for x=21,24 do paint(x,y,18,true) end end
  for y=12,16 do for x=18,24 do if (x+y)%4==0 then paint(x,y,4,false) end end end
 elseif biome==2 then
  -- Two lava races. Three broad bridges link all three foundry wings.
  for _,xx in ipairs({8,19}) do for y=3,17 do for x=xx,xx+1 do
   if y~=7 and y~=8 and y~=10 and y~=13 and y~=14 then paint(x,y,18,true) else paint(x,y,26,false) end
  end end end
  for _,p in ipairs({{4,5},{24,6},{4,15},{24,15}}) do paint(p[1],p[2],16,true) end
 elseif biome==3 then
  -- Frozen crossing, broken pews and ice-covered side chapels.
  for y=3,17 do for x=3,25 do if (y==9 or y==10 or y==11) and math.abs(x-14)>2 then paint(x,y,20,false) end end end
  for _,yy in ipairs({6,14}) do for _,xx in ipairs({5,19}) do for x=xx,xx+4 do paint(x,yy,15,true) end end end
 elseif biome==4 then
  -- Irregular garden ponds, rather than rectangular rooms with a colour swap.
  for _,center in ipairs({{7,7},{21,13}}) do for yy=-3,3 do for xx=-4,4 do
   if (xx*xx)/14+(yy*yy)/7<1 then paint(center[1]+xx,center[2]+yy,18,true) end
  end end end
  for _,p in ipairs({{5,15},{23,5},{9,16},{20,4}}) do paint(p[1],p[2],14,true) end
 else
  -- Star archive shelves form diagonal wings around a large central mosaic.
  for i=0,4 do paint(4+i,4+i,16,true);paint(24-i,4+i,16,true);paint(4+i,16-i,16,true);paint(24-i,16-i,16,true) end
  for y=7,13 do for x=10,18 do if math.abs(x-14)+math.abs(y-10)<6 then paint(x,y,12,false) end end end
 end
 -- Preserve a cross-shaped traversal spine in every generated layout.
 for x=2,m.w-3 do m.tiles[10*m.w+x+1]=x%3==0 and 12 or 2;m.solids[10*m.w+x+1]=false end
end
function M.build(seed,biome,kind)
 local r=Random.new(seed);local m={w=M.W,h=M.H,tiles={},solids={},props={},hazards={},seed=seed,kind=kind}
 for y=0,m.h-1 do for x=0,m.w-1 do
  local index=y*m.w+x+1;local edge=x<2 or x>=m.w-2 or y<2 or y>=m.h-2
  m.tiles[index]=edge and r:int(13,16) or r:int(1,12);m.solids[index]=edge
  if not edge and y>3 and y<m.h-4 and x>3 and x<m.w-4 then
   if (x==7 or x==21) and (y==6 or y==14) then
    m.solids[index]=true;m.tiles[index]=14;m.props[#m.props+1]={x=x*32+16,y=y*32+23,id=biome,solid=true}
   end
  end
 end end
 M.layout(m,r,biome)
 -- Broad central aisle always connects the entry to every interaction.
 for y=2,m.h-3 do for x=13,15 do m.tiles[y*m.w+x+1]=21+(y%4);m.solids[y*m.w+x+1]=false end end
 for _,y in ipairs({3,10,17}) do
  for _,x in ipairs({3,25}) do m.props[#m.props+1]={x=x*32+16,y=y*32+16,id=biome+5,light=true} end
 end
 for i=1,34 do
  local x,y=r:int(3,m.w-4),r:int(3,m.h-4)
  if math.abs(x-14)>3 and not m.solids[y*m.w+x+1] then
   m.props[#m.props+1]={x=x*32+r:int(4,27),y=y*32+r:int(8,28),id=(i%3==0) and r:int(27,32) or 17+biome}
  end
 end
 for i=#m.props,1,-1 do local p=m.props[i]
  if p.solid and not M.solid(m,p.x,p.y) then table.remove(m.props,i) end
 end
 if kind=='boss' or kind=='combat' or kind=='elite' then
  for _,pos in ipairs({{5,9},{23,9},{9,15},{19,5}}) do
   local x,y=pos[1],pos[2];m.hazards[#m.hazards+1]={x=x*32+16,y=y*32+16,r=19,phase=r:next()*6}
   m.tiles[y*m.w+x+1]=18
  end
 end
 m.entry={x=14.5*32,y=17.5*32};m.exit={x=14.5*32,y=2.8*32}
 m.object={x=14.5*32,y=8.5*32,id=kind=='shop' and 16 or kind=='rest' and 17 or kind=='treasure' and 11 or 14}
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
