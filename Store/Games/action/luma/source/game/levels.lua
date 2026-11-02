-- Authored routes, not random generation. All coordinates use metres; Y is up.
local levels = {}
local palettes = {
  {sky="#72BBD4",horizon="#D4E9DC",ground="#83B87C",edge="#B8D692",rock="#A78B76",accent="#FFC880",prop="tree",detail="flowers"},
  {sky="#75A7C5",horizon="#EAD6BB",ground="#D7AE78",edge="#F4CF92",rock="#AA7866",accent="#F5AD77",prop="ruins",detail="cactus"},
  {sky="#6CBACD",horizon="#C3E8DE",ground="#E4D4A3",edge="#F5E7BB",rock="#A9ADA0",accent="#6ED5C8",prop="palm",detail="coral"},
  {sky="#655D97",horizon="#BBA7CA",ground="#B498B6",edge="#D5B8CD",rock="#786B90",accent="#F3A2BD",prop="mushroom",detail="crystals"},
  {sky="#8DADC0",horizon="#DDCDBB",ground="#AA9C84",edge="#DEC395",rock="#7B8090",accent="#FFD289",prop="windmill",detail="crate"},
  {sky="#92BACC",horizon="#DDEAEF",ground="#DCE9E5",edge="#F7F4E9",rock="#8AA9BA",accent="#A6E8F4",prop="pine",detail="crystals"},
  {sky="#C4A6AD",horizon="#F0D1AB",ground="#D5AD7E",edge="#F5D09B",rock="#B78776",accent="#F7CB81",prop="cactus",detail="ruins"},
  {sky="#6F7FA9",horizon="#C0C5DB",ground="#A9BBD0",edge="#D2DEE7",rock="#737D9E",accent="#A2E3E0",prop="tower",detail="crystals"},
  {sky="#675D78",horizon="#BD8D8A",ground="#827783",edge="#B5A1A2",rock="#5B556A",accent="#FFB079",prop="brazier",detail="crystals"},
  {sky="#434B77",horizon="#B5A0B7",ground="#AAA3BC",edge="#D9C9CD",rock="#73748E",accent="#FFD48B",prop="tower",detail="lantern"},
}

-- {absolute x, absolute height, kind}; Z advances down the route. Branches are separate optional islands.
local routes = {
  {{0,0},{0,.3},{1,.7},{3,1},{4,1},{2,1.6},{0,1.6},{-2,2},{-4,2},{-4,2.8,"spring"},{-2,3.5},{1,3.5},{3,4},{5,4},{5,4.7},{3,5},{0,5},{-2,5.5},{-2,6},{0,6},{2,6.5},{2,7}},
  {{0,0},{3,.6},{6,1.3},{3,1.8},{0,2.6},{-3,2.6,"moveX"},{-6,3.2},{-4,3.9},{0,4.2},{4,4.2},{7,5,"spring"},{4,6.5},{0,7},{-4,7.5},{-7,8},{-4,8,"moveY"},{0,8.7},{4,9.2},{6,9.8},{3,10},{0,10.8},{0,11.3}},
  {{0,0},{-3,.2},{-6,.6,"moveX"},{-3,1},{0,1},{3,1.5},{6,2},{8,2.4,"moveZ"},{5,3},{1,3.5},{-3,3.5},{-6,4,"spring"},{-3,5.5},{1,6},{5,6.5,"moveX"},{8,7},{5,7.5},{1,8},{-3,8.4},{-5,9},{-2,9.5},{0,10}},
  {{0,0},{-2,.8,"spring"},{-4,2.5},{-1,3},{2,3.8},{5,4.5},{3,5,"spring"},{0,6.7},{-3,7.5},{-5,8.2},{-2,8.8},{1,9.4},{4,10,"spring"},{2,12},{-1,12.5},{-4,13.2},{-2,14},{1,14.5},{4,15},{2,15.5},{0,16},{0,16.5}},
  {{0,0},{0,.5,"conveyor"},{3,1,"moveX"},{6,1.5},{3,2,"conveyor"},{0,2.5},{-3,3,"moveY"},{-6,3.5},{-3,4,"conveyor"},{0,4.5},{3,5,"moveZ"},{6,5.5},{3,6},{0,6.5,"moveX"},{-3,7},{-5,7.5,"conveyor"},{-2,8},{1,8.5,"moveY"},{4,9},{2,9.5},{0,10},{0,10.5}},
  {{0,0},{2,.4,"ice"},{5,.8,"ice"},{7,1.4},{4,2,"ice"},{1,2.5,"moveX"},{-2,3,"ice"},{-5,3.5},{-7,4.2,"ice"},{-4,4.8},{0,5.4,"spring"},{4,7},{7,7.4,"ice"},{4,8,"ice"},{0,8.5},{-4,9,"moveZ"},{-6,9.7},{-3,10.3,"ice"},{1,11,"ice"},{4,11.5},{2,12},{0,12.5}},
  {{0,0},{-3,.4,"crumble"},{-6,1,"crumble"},{-3,1.6},{0,2.2,"crumble"},{3,2.8,"crumble"},{6,3.4},{8,4,"spring"},{5,5.5},{2,6,"crumble"},{-1,6.5,"crumble"},{-4,7},{-7,7.5,"crumble"},{-4,8},{0,8.5,"moveX"},{4,9,"crumble"},{7,9.5},{4,10,"crumble"},{0,10.5},{-3,11},{-1,11.5},{0,12}},
  {{0,0},{4,.8,"moveX"},{7,1.6},{4,2.3},{0,3,"moveY"},{-4,3.7},{-7,4.5},{-4,5.2,"spring"},{0,7},{4,7.6,"moveZ"},{7,8.3},{4,9},{0,9.8},{-4,10.5,"moveX"},{-7,11.2},{-4,12},{0,12.6,"spring"},{4,14.3},{7,15},{4,15.7},{0,16.4},{0,17}},
  {{0,0},{-2,.6},{-4,1.3,"crumble"},{-1,2},{2,2.7,"moveY"},{5,3.4},{2,4.1},{-1,4.8,"spring"},{-4,6.5},{-1,7.2,"crumble"},{2,8},{5,8.7},{2,9.4,"moveX"},{-1,10.1},{-4,10.8,"crumble"},{-1,11.5},{2,12.2,"spring"},{5,14},{2,14.8},{-1,15.5},{0,16.2},{0,17}},
  {{0,0},{0,.6},{-3,1.3,"moveX"},{-6,2},{-3,2.7},{0,3.4,"conveyor"},{3,4.1},{6,4.8,"spring"},{3,6.5},{0,7.2},{-3,7.9,"crumble"},{-6,8.6},{-3,9.3,"moveY"},{0,10},{3,10.7},{6,11.4},{3,12.1,"spring"},{0,13.8},{-2,14.5},{0,15},{0,15},{0,15}},
}

local function add(t,v) t[#t+1]=v; return v end
function levels.count() return #routes end
function levels.palette(n) return palettes[n] end
function levels.build(n)
  local def={number=n,palette=palettes[n],platforms={},coins={},stars={},enemies={},props={},hazards={},crates={},checkpoints={}}
  local route=routes[n]
  for i,p in ipairs(route) do
    local w,d=6.6,5.8
    if i==1 then w,d=10,9 end
    if i==#route then w,d=n==10 and 18 or 10,n==10 and 17 or 10 end
    local kind=p[3] or "normal"
    if i==1 or i==8 or i==16 or i==#route then kind="normal" end
    local z=-(i-1)*7.2
    if n==10 and i==#route then z=z-4 end
    local platform=add(def.platforms,{x=p[1],y=p[2],z=z,w=w,d=d,kind=kind,route=i,phase=i*.83})
    if i==1 then def.start={x=p[1],y=p[2]+.05,z=z+1.4} end
    if i==8 or i==16 or (n==10 and i==21) then
      add(def.checkpoints,{platform=#def.platforms,x=p[1]-w*.31,y=p[2],z=z+1,index=#def.checkpoints+1})
    end
    for j=1,3 do add(def.coins,{platform=#def.platforms,dx=0,dy=1.05,dz=(j-2)*1.3,id=#def.coins+1}) end
    if i==5 or i==12 or i==19 then
      add(def.stars,{platform=#def.platforms,dx=1.6,dy=1.35,dz=-.4,id=#def.stars+1})
    end
    if i>2 and i<#route-1 and i%3==0 and kind=="normal" then
      add(def.enemies,{platform=#def.platforms,kind=(n>=4 and i%2==0) and "hopper" or "beetle",phase=i,range=1.8})
    end
    if n>=4 and i%7==3 then add(def.enemies,{platform=#def.platforms,kind="bat",phase=i,range=2}) end
    if n>=2 and i%5==4 then add(def.hazards,{platform=#def.platforms,dx=-1.8,dz=-.4,kind="spikes"}) end
    if i%4==2 then add(def.crates,{platform=#def.platforms,dx=2.1,dz=1,broken=false}) end
    if i%2==1 then
      add(def.props,{model=palettes[n].prop,x=p[1]-w*.33,y=p[2],z=z-1.25,scale=.8+(i%3)*.12,angle=i*.7,platform=#def.platforms})
      add(def.props,{model=palettes[n].detail,x=p[1]+w*.34,y=p[2],z=z-1.4,scale=.65,angle=i*.3,platform=#def.platforms})
    end
    if n==1 or n==3 then add(def.props,{model="flowers",x=p[1]+2.1,y=p[2],z=z+1.7,scale=1,angle=i,platform=#def.platforms}) end
    -- Side islands create optional exploration loops without blocking the main route.
    if i==6 or i==14 then
      local sign=i==6 and -1 or 1
      local side=add(def.platforms,{x=p[1]+sign*6.6,y=p[2]+.7,z=z,w=4.2,d=4.2,kind="normal",phase=i})
      for j=1,5 do add(def.coins,{platform=#def.platforms,dx=math.sin(j*1.256)*1.05,dy=1,dz=math.cos(j*1.256)*1.05,id=#def.coins+1}) end
      add(def.crates,{platform=#def.platforms,dx=0,dz=0,broken=false,heart=true})
      add(def.props,{model="lantern",x=side.x+1.4,y=side.y,z=side.z-1.4,scale=.7,angle=0,platform=#def.platforms})
    end
    platform.main=true
  end
  local last=def.platforms[1]
  for _,p in ipairs(def.platforms) do if p.main then last=p end end
  def.goal={x=last.x,y=last.y,z=last.z-2.5,platform=last}
  if n==10 then def.boss={x=last.x,y=last.y,z=last.z-1,hp=3,state="sleep",timer=0,radius=0} end
  def.wind=n==8 and 2.0 or 0
  def.lava=n==9
  def.length=#route
  return def
end
return levels
