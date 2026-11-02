-- Eight districts per world, linked by walkable roads, loops and optional elevated routes.
local A={}
local layouts={
 {{0,14,24,20,0},{0,-8,28,24,0},{-27,-12,22,22,0},{25,-11,22,24,0},{38,-34,16,16,2},{-28,-40,24,22,0},{0,-40,26,20,0},{0,-66,24,22,1}},
 {{0,12,20,18,0},{0,-12,20,20,1},{-27,-12,22,18,2},{26,-12,18,24,0},{35,-39,16,18,3},{-27,-42,24,20,2},{0,-42,20,20,2},{0,-68,24,20,3}},
 {{0,15,28,22,0},{0,-10,30,24,0},{-29,-10,24,22,0},{29,-10,24,24,0},{42,-36,18,18,1},{-29,-39,24,24,0},{0,-39,28,22,0},{0,-66,26,22,0}},
 {{0,13,22,22,0},{0,-12,26,26,0},{-28,-15,24,22,0},{26,-14,24,22,1},{40,-40,18,18,2},{-26,-43,24,24,0},{1,-42,24,22,1},{1,-69,26,24,1}},
 {{0,14,24,22,0},{0,-12,26,22,0},{-28,-12,24,24,0},{28,-12,24,24,0},{42,-40,18,18,2},{-28,-42,24,24,0},{0,-42,26,24,1},{0,-70,26,24,1}},
 {{0,15,26,22,0},{0,-10,30,26,0},{-31,-13,24,24,0},{30,-13,24,24,1},{43,-42,18,18,3},{-30,-43,26,24,1},{0,-42,28,24,0},{0,-72,28,24,2}},
 {{0,14,26,20,0},{0,-12,26,24,0},{-28,-12,24,24,0},{28,-12,24,24,0},{42,-41,18,18,2},{-28,-43,26,24,1},{0,-42,26,26,1},{0,-71,28,24,2}},
 {{0,15,24,22,0},{0,-10,24,24,1},{-29,-11,24,22,2},{28,-12,24,24,1},{42,-40,18,18,4},{-29,-41,24,24,2},{0,-41,24,24,3},{0,-70,26,24,4}},
 {{0,15,26,24,0},{0,-12,26,24,0},{-29,-12,24,24,1},{29,-12,24,24,0},{43,-42,18,18,3},{-29,-43,24,24,1},{0,-43,26,26,2},{0,-74,28,26,3}},
 {{0,16,28,24,0},{0,-12,28,24,0},{-31,-12,26,24,0},{30,-12,26,24,0},{44,-42,20,20,3},{-31,-44,26,26,1},{0,-44,28,26,1},{0,-77,32,32,1}},
}
local edges={{1,2},{2,3},{2,4},{4,5},{3,6},{6,7},{4,7},{7,8},{5,6}}
-- Different silhouettes: canyon ravine, harbour U, forest branches, factory ring, lake and castle wings.
layouts[2]={{-15,20,20,18,0},{-15,-4,20,20,1},{-35,-24,20,18,2},{10,-2,22,24,0},{35,-23,18,18,3},{-30,-56,24,20,2},{0,-47,22,22,2},{26,-70,24,24,3}}
layouts[3]={{0,22,32,20,0},{0,-2,40,24,0},{-35,-20,24,30,0},{35,-20,24,30,0},{36,-58,20,20,1},{-34,-58,26,24,0},{0,-60,30,22,0},{0,-90,26,24,0}}
layouts[4]={{-18,19,22,20,0},{-18,-6,24,24,0},{-37,-35,22,24,0},{11,-8,24,22,1},{36,-28,20,20,2},{-23,-65,24,24,0},{12,-57,26,24,1},{38,-78,26,24,1}}
layouts[5]={{0,21,24,20,0},{0,-4,26,24,0},{-31,-6,24,24,0},{31,-6,24,24,0},{31,-41,20,22,2},{-31,-41,24,24,0},{-15,-73,24,22,1},{17,-73,28,24,1}}
layouts[6]={{0,23,26,20,0},{0,-5,42,34,0},{-36,-17,24,28,0},{36,-17,24,28,1},{38,-58,20,22,3},{-36,-58,26,24,1},{0,-57,28,24,0},{0,-89,28,24,2}}
layouts[7]={{-17,23,24,20,0},{-17,-4,28,24,0},{-17,-38,28,28,0},{19,-4,28,24,0},{42,-40,18,20,2},{-17,-76,28,26,1},{19,-40,24,28,1},{20,-78,30,26,2}}
layouts[8]={{-19,20,24,20,0},{-19,-6,24,24,1},{-39,-36,22,24,2},{12,-6,24,24,1},{39,-31,20,20,4},{-30,-70,24,24,2},{5,-55,24,26,3},{33,-82,26,26,4}}
layouts[9]={{0,22,26,20,0},{0,-5,30,24,0},{-35,-21,24,24,1},{35,-21,24,24,0},{36,-59,20,22,3},{-35,-59,26,26,1},{0,-62,28,26,2},{0,-93,30,26,3}}
layouts[10]={{0,23,30,22,0},{0,-4,34,26,0},{-39,-22,28,28,0},{39,-22,28,28,0},{40,-61,22,22,3},{-39,-61,28,28,1},{0,-61,30,26,1},{0,-97,36,34,1}}
local forestEdges={{1,2},{2,4},{4,5},{5,7},{2,3},{3,6},{6,7},{7,8},{4,6}}
local factoryEdges={{1,2},{2,3},{3,6},{6,7},{7,8},{8,5},{5,4},{4,2},{4,7}}
local roster={
 {"beetle","hopper","plant"},{"ram","beetle","turtle"},{"plant","bat","mimic"},
 {"bat","plant","hopper"},{"turtle","orb","ram"},{"ram","turtle","bat"},
 {"mimic","plant","turtle"},{"orb","bat","ram"},{"ram","orb","plant"},{"turtle","orb","mimic"}
}
local landmarks={"house","ruins","ship","mushroom","windmill","pine","shrine","tower","brazier","tower"}
local function add(t,v)t[#t+1]=v;return #t end
function A.build(n,palette)
 local d={number=n,palette=palette,platforms={},coins={},stars={},enemies={},props={},hazards={},crates={},checkpoints={},switches={},keys={},blockers={},links={},adventure=true,revision=2,wind=n==8 and 1.2 or 0,lava=n==9,length=12}
 local zones={};d.zones=zones
 for i,a in ipairs(layouts[n]) do
  local kind=(n==6 and (i==3 or i==4)) and "ice" or (n==5 and i==4 and "conveyor" or "normal")
  local p={x=a[1],z=a[2],w=a[3],d=a[4],y=a[5],kind=kind,phase=i,main=true,zone=i}
  zones[i]=add(d.platforms,p)
 end
 local function floor(x,y,z,w,depth,kind)
  return add(d.platforms,{x=x,y=y,z=z,w=w,d=depth,kind=kind or "road",phase=0,road=true})
 end
 local function roadSegment(x1,y1,z1,x2,y2,z2)
  local len=math.sqrt((x2-x1)^2+(z2-z1)^2);local steps=math.max(1,math.ceil(len/3),math.ceil(math.abs(y2-y1)/.45))
  local ids={}
  for j=0,steps do
   local t=j/steps
   ids[#ids+1]=floor(x1+(x2-x1)*t,y1+(y2-y1)*t,z1+(z2-z1)*t,x1==x2 and 5 or len/steps+1.6,x1==x2 and len/steps+1.6 or 5)
  end
  return ids
 end
 for _,edge in ipairs(n==4 and forestEdges or (n==5 and factoryEdges or edges)) do
  local a,b=d.platforms[zones[edge[1]]],d.platforms[zones[edge[2]]]
  -- Roads start at district borders: stairs never run invisibly through raised rooms.
  local x1,z1,x2,z2=a.x,a.z,b.x,b.z
  if math.abs(x2-x1)>math.abs(z2-z1) then
   local s=x2>x1 and 1 or -1;x1=x1+s*(a.w/2-1);x2=x2-s*(b.w/2-1)
  else local s=z2>z1 and 1 or -1;z1=z1+s*(a.d/2-1);z2=z2-s*(b.d/2-1) end
  local bendY=b.y
  if z1==z2 then bendY=b.y end
  if math.abs(x1-x2)<6 and math.abs(z1-b.z)>b.d/2+1 then bendY=a.y end
  local first=roadSegment(x1,a.y,z1,x2,bendY,z1)
  local second=roadSegment(x2,bendY,z1,x2,b.y,z2)
  add(d.links,{a=zones[edge[1]],b=zones[edge[2]],path=first,tail=second})
 end
 local function prop(model,zone,dx,dz,scale,solid,angle)
  local p=d.platforms[zones[zone]]
  add(d.props,{model=model,x=p.x+dx,y=p.y,z=p.z+dz,scale=scale or 1,angle=angle or 0,platform=zones[zone]})
  if solid then add(d.blockers,{x=p.x+dx,y=p.y,z=p.z+dz,w=solid[1],d=solid[2],h=solid[3]}) end
 end
 for z=1,8 do
  local p=d.platforms[zones[z]]
  local landmark=landmarks[n]
  if n==3 and z~=3 and z~=6 then landmark="coral" end
  if n==5 and z~=2 and z~=6 then landmark="house" end
  if n==7 and z~=4 and z~=8 then landmark="ruins" end
  prop(landmark,z,-p.w*.30,-p.d*.29,n==1 and 1.1 or .9,landmark=="house" and {4.4,3.8,4.5} or nil)
  prop(palette.prop,z,p.w*.32,-p.d*.3,.9)
  prop(palette.detail,z,p.w*.33,p.d*.31,.75)
  if n==1 or n==3 then prop("flowers",z,-p.w*.33,p.d*.3,1.2) end
  -- Treasure clusters are scattered around courtyards, rather than lines between identical jumps.
  for j=1,9 do local a=j*math.pi*2/9;add(d.coins,{platform=zones[z],dx=math.cos(a)*3.7,dy=1,dz=math.sin(a)*3.7,id=#d.coins+1}) end
  for j=1,2 do add(d.crates,{platform=zones[z],dx=(j==1 and -1 or 1)*(p.w*.28),dz=2.6,heart=z%3==0,broken=false}) end
 end
 local centers={"fountain","ruins","ship","mushroom","windmill","crystals","shrine","tower","brazier","arch"}
 local center=centers[n]
 prop(center,2,0,0,n==4 and 1.8 or 1.2,(center=="arch" or center=="ruins") and nil or {n==3 and 6.5 or 3,n==3 and 3 or 3,n==8 and 6.5 or 1.4})
 prop("arch",1,0,-7,1.1)
 prop("shrine",4,0,-5,1.2)
 prop("cage",6,0,-3.7,1)
 prop("scout",1,3,1,1)
 for _,z in ipairs({2,7,8}) do
  if z~=8 or n==10 then
   local p=d.platforms[zones[z]]
   add(d.checkpoints,{platform=zones[z],x=p.x+2,y=p.y,z=p.z+4,index=#d.checkpoints+1})
  end
 end
 for i,z in ipairs({2,4,7}) do
  add(d.switches,{platform=zones[z],dx=-4,dz=-3,active=false,index=i})
  local kz=({2,4,7})[i];add(d.keys,{platform=zones[kz],dx=4.5,dz=-4.5,collected=false,id=i})
 end
 d.puzzleOrder=n==7
 if n==5 or n==9 then
  for _,zone in ipairs({2,4,7}) do add(d.hazards,{platform=zones[zone],dx=0,dz=4,kind="beam",phase=zone,radius=3.8}) end
 elseif n==3 or n==4 then
  for _,zone in ipairs({3,4,7}) do add(d.hazards,{platform=zones[zone],dx=-3,dz=3,kind="vent",phase=zone,radius=1.8}) end
 end
 d.cage={platform=zones[6],dx=0,dz=-3.7,opened=false}
 add(d.stars,{platform=zones[5],dx=0,dy=1.3,dz=-1,id=1})
 add(d.stars,{platform=zones[3],dx=0,dy=1.3,dz=0,id=2,unlock="arena"})
 add(d.stars,{platform=zones[6],dx=0,dy=1.3,dz=-3.7,id=3,unlock="rescue"})
 for i,z in ipairs({2,3,3,3,4,5,6,6,7}) do
  local k=roster[n][(i-1)%3+1]
  add(d.enemies,{platform=zones[z],kind=k,phase=i,range=3,dx=(i%3-1)*3,dz=(i%2==0 and -1 or 1)*2,group=z==3 and "arena" or nil})
 end
 local start=d.platforms[zones[1]];d.start={x=start.x,y=start.y+.05,z=start.z+3}
 local exit=d.platforms[zones[8]];d.goal={x=exit.x,y=exit.y,z=exit.z-5,platform=exit}
 if n==10 then d.boss={x=exit.x,y=exit.y,z=exit.z,hp=3,state="sleep",timer=0,radius=0} end
 -- Optional rooftop: double jump is useful for secrets, while the district roads remain walkable.
 local p=d.platforms[zones[5]]
 local roof=floor(p.x+3,p.y+1.7,p.z+3,5,5,"normal")
 add(d.coins,{platform=roof,dx=0,dy=1,dz=0,id=#d.coins+1})
 d.bounds={minX=-60,maxX=65,minZ=-120,maxZ=40}
 return d
end
return A
