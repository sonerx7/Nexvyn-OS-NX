local F={}
local abs,min,max=math.abs,math.min,math.max
local CELL=6
function F.hit(o,d,b,limit)
 local near,far=0,limit or 1000
 for _,axis in ipairs({"x","y","z"}) do
  local span=axis=="x" and b.w or (axis=="y" and b.h or b.d)
  local lo,hi=b[axis]-span/2,b[axis]+span/2;local v=d[axis]
  if abs(v)<1e-8 then if o[axis]<lo or o[axis]>hi then return nil end
  else
   local a,c=(lo-o[axis])/v,(hi-o[axis])/v;if a>c then a,c=c,a end
   near=max(near,a);far=min(far,c);if near>far then return nil end
  end
 end
 return near
end
function F.eachSolid(w,fn)
 for _,b in ipairs(w.map.boxes) do if b.solid then fn(b) end end
 for _,b in ipairs(w.map.doors) do if not b.open then fn(b) end end
 for _,b in ipairs(w.map.props) do if b.solid then fn({x=b.x,y=b.y+b.h/2,z=b.z,w=b.w,h=b.h,d=b.d}) end end
end
function F.index(w)
 local grid={};local all={}
 for _,b in ipairs(w.map.boxes) do if b.solid then all[#all+1]=b end end
 for _,b in ipairs(w.map.doors) do b._door=true;all[#all+1]=b end
 for _,p in ipairs(w.map.props) do if p.solid then all[#all+1]={x=p.x,y=p.y+p.h/2,z=p.z,w=p.w,h=p.h,d=p.d} end end
 for _,b in ipairs(all) do
  for x=math.floor((b.x-b.w/2)/CELL),math.floor((b.x+b.w/2)/CELL) do
   for z=math.floor((b.z-b.d/2)/CELL),math.floor((b.z+b.d/2)/CELL) do
    local key=x..":"..z;if not grid[key] then grid[key]={} end;grid[key][#grid[key]+1]=b
   end
  end
 end
 w.collisionGrid=grid;w.gridBoxes=w.map.boxes;w.gridDoors=w.map.doors;w.gridProps=w.map.props
end
local function ensure(w)
 if not w.collisionGrid or w.gridBoxes~=w.map.boxes or w.gridDoors~=w.map.doors or w.gridProps~=w.map.props then F.index(w) end
end
function F.ray(w,o,d,limit)
 ensure(w)
 local best=limit;local seen={};local x,z=math.floor(o.x/CELL),math.floor(o.z/CELL)
 local sx=d.x>=0 and 1 or -1;local sz=d.z>=0 and 1 or -1
 local tx=abs(d.x)<1e-9 and 1e12 or (((sx>0 and x+1 or x)*CELL-o.x)/d.x)
 local tz=abs(d.z)<1e-9 and 1e12 or (((sz>0 and z+1 or z)*CELL-o.z)/d.z)
 local dx=abs(d.x)<1e-9 and 1e12 or CELL/abs(d.x);local dz=abs(d.z)<1e-9 and 1e12 or CELL/abs(d.z)
 local travelled=0
 for step=1,128 do
  local list=w.collisionGrid[x..":"..z]
  if list then for _,b in ipairs(list) do
   if not seen[b] and (not b._door or not b.open) then seen[b]=true;local hit=F.hit(o,d,b,best);if hit and hit<best then best=hit end end
  end end
  if tx<tz then travelled=tx;x=x+sx;tx=tx+dx else travelled=tz;z=z+sz;tz=tz+dz end
  if travelled>best then break end
 end
 return best
end
function F.blocked(w,x,y,z,r,h)
 ensure(w)
 local blocked=false;local seen={}
 for gx=math.floor((x-r)/CELL),math.floor((x+r)/CELL) do for gz=math.floor((z-r)/CELL),math.floor((z+r)/CELL) do
  local list=w.collisionGrid[gx..":"..gz]
  if list then for _,b in ipairs(list) do
   if not seen[b] and (not b._door or not b.open) then
    seen[b]=true
    if abs(x-b.x)<b.w/2+r and abs(z-b.z)<b.d/2+r and y+h>b.y-b.h/2+.025 and y<b.y+b.h/2-.025 then blocked=true end
   end
  end end
 end end
 for _,b in ipairs(w.map.ramps) do
  if abs(x-b.x)<b.w/2+r and abs(z-b.z)<b.d/2+r then
   local t=b.axis=="z" and (z-b.z)/b.d+.5 or (x-b.x)/b.w+.5
   if b.negative then t=1-t end
   local top=b.y+max(0,min(1,t))*b.rise
   if y<top-.05 and y+h>b.y then blocked=true end
  end
 end
 return blocked
end
function F.floor(w,x,y,z)
 local ground=-100
 for _,b in ipairs(w.map.floors) do if abs(x-b.x)<b.w/2+.05 and abs(z-b.z)<b.d/2+.05 and b.y<=y+.55 then ground=max(ground,b.y) end end
 for _,b in ipairs(w.map.ramps) do
  if abs(x-b.x)<=b.w/2 and abs(z-b.z)<=b.d/2 then
   local t=b.axis=="z" and (z-b.z)/b.d+.5 or (x-b.x)/b.w+.5
   if b.negative then t=1-t end
   local top=b.y+t*b.rise;if top<=y+.55 then ground=max(ground,top) end
  end
 end
 return ground
end
function F.room(w,x,z)
 for i,r in ipairs(w.map.rooms) do if abs(x-r.x)<r.w/2 and abs(z-r.z)<r.d/2 then return i end end
 return 0
end
function F.direction(yaw,pitch)
 local cp=math.cos(pitch);return {x=math.sin(yaw)*cp,y=math.sin(pitch),z=-math.cos(yaw)*cp}
end
return F
