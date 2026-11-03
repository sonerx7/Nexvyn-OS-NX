local M={}
local locations={
 {{0,0},{0,-25},{27,-25},{27,-53},{0,-53},{0,-84}},
 {{0,0},{-28,0},{-28,-28},{0,-28},{28,-28},{28,-61}},
 {{0,0},{0,-29},{-30,-29},{30,-29},{0,-58},{0,-90}},
 {{0,0},{0,-27},{29,-27},{29,-57},{0,-57},{0,-91}},
 {{0,0},{0,-28},{-30,-28},{-30,-60},{0,-60},{0,-94}},
 {{0,0},{0,-31},{-34,-31},{-34,-65},{0,-65},{0,-106}}
}
local connections={{{1,2},{2,3},{3,4},{4,5},{5,6},{2,5}},{{1,2},{2,3},{3,4},{4,5},{5,6},{1,4}},{{1,2},{2,3},{2,4},{2,5},{5,6},{3,4}},{{1,2},{2,3},{3,4},{4,5},{5,6},{2,5}},{{1,2},{2,3},{3,4},{4,5},{5,6},{2,5}},{{1,2},{2,3},{3,4},{4,5},{5,6},{2,5}}}
local styles={
 {wall="wall",floor="floor",fog="#17232F",color="#79C8C5",ambient=.29},
 {wall="concrete",floor="grate",fog="#25262F",color="#E9AE77",ambient=.27},
 {wall="wall",floor="grate",fog="#172A32",color="#75D7D3",ambient=.25},
 {wall="concrete",floor="floor",fog="#29212F",color="#BA9ADC",ambient=.25},
 {wall="organic",floor="grate",fog="#301F28",color="#D18E8D",ambient=.27},
 {wall="wall",floor="floor",fog="#24212D",color="#F0AE76",ambient=.25}
}
local function add(t,v)t[#t+1]=v;return v end
function M.build(chapter)
 local d={chapter=chapter,rooms={},boxes={},floors={},ramps={},doors={},props={},enemies={},pickups={},lights={},relays={},links=connections[chapter],style=styles[chapter],terminals={},logs={}}
 local points=locations[chapter]
 for i,p in ipairs(points) do
  d.rooms[i]={id=i,x=p[1],z=p[2],w=i==6 and (chapter==6 and 32 or 25) or (i%2==0 and 21 or 18),d=i==6 and 26 or (i%2==0 and 21 or 18),y=0,h=chapter==6 and 8.5 or 6.5,open={},neighbors={}}
  if i==4 then d.rooms[i].w=30;d.rooms[i].d=30 end
 end
 local function box(x,y,z,w,h,depth,mat,room,solid)
  return add(d.boxes,{x=x,y=y,z=z,w=w,h=h,d=depth,material=mat,room=room or 0,solid=solid~=false})
 end
 local function floor(x,y,z,w,depth,room)
  add(d.floors,{x=x,y=y,z=z,w=w,d=depth,room=room})
  box(x,y-.15,z,w,.3,depth,d.style.floor,room,true)
 end
 local function wallStrip(x1,z1,x2,z2)
  local length=math.sqrt((x2-x1)^2+(z2-z1)^2);local steps=math.max(1,math.ceil(length));local run=nil
  local function flush(first,last)
   local t0,t1=first/steps,last/steps;local t=(t0+t1)/2;local span=length*(t1-t0)
   if span>.01 then box(x1+(x2-x1)*t,2,z1+(z2-z1)*t,x1==x2 and .25 or span,4,x1==x2 and span or .25,d.style.wall,0) end
  end
  for j=0,steps do
   local inside=false
   if j<steps then
    local t=(j+.5)/steps;local x,z=x1+(x2-x1)*t,z1+(z2-z1)*t
    for _,r in ipairs(d.rooms) do if math.abs(x-r.x)<r.w/2+.5 and math.abs(z-r.z)<r.d/2+.5 then inside=true;break end end
   else inside=true end
   if not inside and not run then run=j elseif inside and run then flush(run,j);run=nil end
  end
 end
 local function corridor(a,b)
  if a.x==b.x then
   floor(a.x,0,(a.z+b.z)/2,4.2,math.abs(a.z-b.z)+1,0)
   box(a.x,4.1,(a.z+b.z)/2,4.2,.20,math.abs(a.z-b.z)+1,"ceiling",0)
   for _,s in ipairs({-1,1}) do wallStrip(a.x+s*2.2,a.z,a.x+s*2.2,b.z) end
  else
   floor((a.x+b.x)/2,0,a.z,math.abs(a.x-b.x)+1,4.2,0)
   box((a.x+b.x)/2,4.1,a.z,math.abs(a.x-b.x)+1,.20,4.2,"ceiling",0)
   for _,s in ipairs({-1,1}) do wallStrip(a.x,a.z+s*2.2,b.x,a.z+s*2.2) end
  end
 end
 for _,edge in ipairs(d.links) do
  local a,b=d.rooms[edge[1]],d.rooms[edge[2]]
  a.neighbors[#a.neighbors+1]=b.id;b.neighbors[#b.neighbors+1]=a.id
  if a.x==b.x then local side=b.z<a.z and "n" or "s";a.open[side]=true;b.open[side=="n" and "s" or "n"]=true
  else local side=b.x>a.x and "e" or "w";a.open[side]=true;b.open[side=="e" and "w" or "e"]=true end
  corridor(a,b)
 end
 for _,r in ipairs(d.rooms) do
  floor(r.x,0,r.z,r.w,r.d,r.id);box(r.x,r.h,r.z,r.w,.35,r.d,"ceiling",r.id)
  for _,sx in ipairs({-1,1}) do
   box(r.x+sx*(r.w/2-.65),r.h-.35,r.z,.35,.55,r.d,"wall",r.id)
  end
  for _,side in ipairs({"n","s","e","w"}) do
   local xSide=side=="e" or side=="w";local length=xSide and r.d or r.w
   local wallX=r.x+(side=="e" and r.w/2 or (side=="w" and -r.w/2 or 0))
   local wallZ=r.z+(side=="s" and r.d/2 or (side=="n" and -r.d/2 or 0))
   local function segment(offset,len,y,h)
    box(wallX+(xSide and 0 or offset),y,wallZ+(xSide and offset or 0),xSide and .4 or len,h,xSide and len or .4,d.style.wall,r.id)
   end
   if r.open[side] then
    local len=(length-4.4)/2
    segment(-(length+4.4)/4,len,r.h/2,r.h);segment((length+4.4)/4,len,r.h/2,r.h)
    segment(0,4.4,(3.3+r.h)/2,r.h-3.3)
    -- Door-frame strips and emissive indicators are geometry, not painted fake depth.
    for _,s in ipairs({-1,1}) do segment(s*2.16,.13,1.65,3.3) end
   else segment(0,length,r.h/2,r.h) end
  end
  for j=1,4 do
   local sx=j%2==0 and 1 or -1;local sz=j<=2 and 1 or -1
   add(d.lights,{x=r.x+sx*(r.w/2-1),y=3.5,z=r.z+sz*(r.d/2-1),r=12,color=(j%2==0 and d.style.color or "#E7B383"),room=r.id,phase=j+r.id})
   add(d.props,{model=j%2==0 and "turbine" or "crate",x=r.x+sx*(r.w/2-2),y=0,z=r.z+sz*(r.d/2-2),angle=j,room=r.id,solid=true,w=1.8,d=1.8,h=2})
  end
  add(d.pickups,{kind="ammo",x=r.x-3,y=.3,z=r.z+2,room=r.id})
  add(d.pickups,{kind=r.id==1 and "armor" or "medkit",x=r.x+4,y=.3,z=r.z-3,room=r.id})
 end
 -- Vertical space: a real elevated deck with a walkable ramp and an underside.
 local r=d.rooms[4]
 floor(r.x+r.w/2-4,2.4,r.z-r.d/2+4,6,5,4)
 add(d.ramps,{x=r.x+4,z=r.z-r.d/2+4,w=8,d=3.4,y=0,rise=2.4,axis="x",negative=false,room=4})
 add(d.pickups,{kind="armor",x=r.x+r.w/2-4,y=2.7,z=r.z-r.d/2+4,room=4})
 local spawn=d.rooms[1];local target=d.rooms[2]
 d.start={x=spawn.x,y=0,z=spawn.z+2,yaw=math.atan(target.x-spawn.x,-(target.z-spawn.z))}
 for _,id in ipairs({2,4}) do local a=d.rooms[id];add(d.relays,{x=a.x-4,y=0,z=a.z-4,room=id,active=false}) end
 local keyRoom=d.rooms[3];add(d.pickups,{kind="key",x=keyRoom.x+3,y=.7,z=keyRoom.z-3,room=3})
 local gunRoom=d.rooms[2];add(d.pickups,{kind="weapon",weapon=chapter==1 and 2 or math.min(4,chapter+1),x=gunRoom.x+3,y=.6,z=gunRoom.z+3,room=2})
 for _,id in ipairs({1,4,5}) do local a=d.rooms[id];add(d.terminals,{x=a.x-4,y=0,z=a.z+3,room=id});add(d.logs,{x=a.x+3,y=.4,z=a.z-4,room=id,index=id,read=false}) end
 local last=d.rooms[6];local prev=d.rooms[5]
 local gate={x=last.x,y=1.65,z=last.z+last.d/2,w=4.2,h=3.3,d=.42,open=false,room=6}
 if last.z==prev.z then gate.x=last.x+(prev.x<last.x and -last.w/2 or last.w/2);gate.z=last.z;gate.w=.42;gate.d=4.2 end
 d.doors[1]=gate
 d.exit={x=last.x,y=0,z=last.z-7,room=6}
 add(d.props,{model="core",x=last.x-7,y=0,z=last.z-5,room=6,angle=0})
 local rosters={{"stalker","trooper","drone"},{"trooper","stalker","siege"},{"drone","trooper","priest"},{"priest","stalker","siege"},{"siege","priest","drone"},{"trooper","siege","priest"}}
 for room=2,6 do
  local a=d.rooms[room]
  for j=1,chapter>=3 and 4 or 3 do
   local kind=rosters[chapter][(j-1)%3+1]
   add(d.enemies,{kind=kind,x=a.x+(j%2==0 and -1 or 1)*(2+j*.7),y=0,z=a.z-2-j*.7,room=room})
  end
 end
 if chapter==6 then add(d.enemies,{kind="warden",x=last.x,y=0,z=last.z-2,room=6,boss=true}) end
 d.cover={}
 for _,r in ipairs(d.rooms) do
  for _,side in ipairs({-1,1}) do
   add(d.props,{model="pipe_rack",x=r.x+side*(r.w/2-1.1),y=0,z=r.z+side*2.5,angle=0,room=r.id})
   add(d.props,{model="generator",x=r.x+side*(r.w/2-2.3),y=0,z=r.z-side*(r.d/2-3.8),angle=side*math.pi/2,room=r.id})
   local x,z=r.x+side*(r.w/2-4),r.z+side*r.d*.23
   add(d.props,{model="cover_panel",x=x,y=0,z=z,angle=0,room=r.id,solid=true,w=2.1,h=1.65,d=.4});add(d.cover,{x=x,z=z,room=r.id})
   add(d.props,{model="supply_stack",x=r.x+side*(r.w/2-1.8),y=0,z=r.z-side*1.2,angle=side,room=r.id})
  end
  add(d.props,{model="gantry",x=r.x,y=0,z=r.z+r.d/2-.8,angle=0,room=r.id})
  add(d.props,{model="comms",x=r.x-r.w/2+1.1,y=0,z=r.z-2.5,angle=math.pi/2,room=r.id})
 end
 return d
end
return M
