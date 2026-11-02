local C=require('game.content')
local R={images={},s=1,ox=0,oy=0,cx=0,cy=0,time=0}
local floor,min,max=math.floor,math.min,math.max
function R.load()
 for _,name in ipairs({'hero','enemies','bosses','props','icons','font','title','tiles1','tiles2','tiles3','tiles4','tiles5'}) do
  R.images[name]=gfx.image('bundle:/sprites/'..name..'.png')
 end
 local f=json.decode(fs.read('bundle:/sprites/font.json'));R.glyphs={}
 for _,code in utf8.codes(f.chars) do R.glyphs[code]=0 end
 local i=0;for _,code in utf8.codes(f.chars) do R.glyphs[code]=i;i=i+1 end
end
function R.begin(w,h)
 R.s=max(1,floor(min(w/640,h/360)));R.ox=floor((w-640*R.s)/2);R.oy=floor((h-360*R.s)/2)
 gfx.clear('#080f1b');gfx.clip(R.ox,R.oy,640*R.s,360*R.s)
end
function R.finish()gfx.unclip()end
function R.point(x,y)return floor(R.ox+x*R.s),floor(R.oy+y*R.s)end
function R.rect(x,y,w,h,c)
 local px,py=R.point(x,y);gfx.rect(px,py,max(1,floor(w*R.s)),max(1,floor(h*R.s)),0,c)
end
function R.panel(x,y,w,h,selected)
 R.rect(x+3,y+4,w,h,'#080f1bdd');R.rect(x,y,w,h,selected and '#aa9068' or '#435664');R.rect(x+1,y+1,w-2,h-2,'#142431f5');R.rect(x+3,y+3,w-6,1,selected and '#edce91' or '#5a6c72')
 for _,p in ipairs({{x+2,y+2},{x+w-4,y+2},{x+2,y+h-4},{x+w-4,y+h-4}}) do R.rect(p[1],p[2],2,2,'#d8ba7d') end
end
function R.region(name,sx,sy,sw,sh,x,y,w,h,angle)
 local img=R.images[name];if not img then return end
 local px,py=R.point(x,y);gfx.drawRegion(img,sx*2,sy*2,sw*2,sh*2,px,py,floor((w or sw)*R.s),floor((h or sh)*R.s),angle or 0)
end
function R.text(value,x,y,scale,align,width)
 local str=C.t(value);scale=scale or 1;local len=utf8.len(str) or #str
 if align=='center' then x=x+((width or 0)-len*7*scale)/2 elseif align=='right' then x=x+(width or 0)-len*7*scale end
 for _,code in utf8.codes(str) do
  local i=R.glyphs[code] or R.glyphs[63];R.region('font',(i%16)*8,floor(i/16)*14,8,14,x,y,8*scale,14*scale);x=x+7*scale
 end
end
function R.wrap(value,x,y,width)
 local line='';local row=0
 for word in C.t(value):gmatch('%S+') do
  local candidate=line=='' and word or line..' '..word
  if (utf8.len(candidate) or #candidate)*7>width and line~='' then R.text(line,x,y+row*14);row=row+1;line=word else line=candidate end
 end
 if line~='' then R.text(line,x,y+row*14);row=row+1 end;return row*14
end
function R.icon(id,x,y,size)
 id=id-1;R.region('icons',(id%8)*24,floor(id/8)*24,24,24,x,y,size or 24,size or 24)
end
function R.prop(id,x,y)
 id=id-1;R.region('props',(id%8)*64,floor(id/8)*64,64,64,x-32,y-55)
end
function R.disc(x,y,r,c)
 -- Stepped scanlines deliberately avoid anti-aliased geometric effects.
 for yy=-floor(r),floor(r),3 do local xx=floor(math.sqrt(max(0,r*r-yy*yy))/3)*3;R.rect(x-xx,y+yy,xx*2+3,3,c) end
end
function R.ring(x,y,r,c)
 for i=0,35 do local a=i*math.pi/18;R.rect(x+floor(math.cos(a)*r)-1,y+floor(math.sin(a)*r)-1,3,3,c) end
end
function R.camera(w)
 local p=w.player;local tx=max(0,min(w.map.w*32-640,p.x+p.ax*35-320));local ty=max(0,min(w.map.h*32-360,p.y+p.ay*65-205))
 R.cx=floor(tx);R.cy=floor(ty)
end
function R.scene(w,shake)
 R.camera(w);local cx,cy=R.cx,R.cy
 if shake and w.player.invul>.51 and w.player.invul<.7 then cx=cx+floor(math.sin(w.time*90)*3);cy=cy+floor(math.cos(w.time*77)*2) end
 local m=w.map;R.rect(0,0,640,360,'#101b29')
 local tiles='tiles'..w.biome
 for ty=max(0,floor(cy/32)),min(m.h-1,floor((cy+360)/32)) do
  for tx=max(0,floor(cx/32)),min(m.w-1,floor((cx+640)/32)) do
   local index=ty*m.w+tx+1;local id=m.tiles[index]-1
   if id>=17 and id<21 then id=17+floor(w.time*3)%4 end
   R.region(tiles,(id%8)*32,floor(id/8)*32,32,32,tx*32-cx,ty*32-cy)
   if not m.solids[index] and (m.solids[index-1] or m.solids[index-m.w]) then R.rect(tx*32-cx,ty*32-cy,32,5,'#08162064') end
  end
 end
 for _,h in ipairs(m.hazards) do
  local x,y=h.x-cx,h.y-cy;local active=(w.time+h.phase)%4<.8
  if active then R.disc(x,y,h.r,'#dc976b65');R.ring(x,y,h.r,'#ebba82') else R.ring(x,y,h.r,'#85796b66') end
 end
 for _,t in ipairs(w.tells) do
  local x,y=t.x-cx,t.y-cy;local c=t.friendly and '#9ce3ca' or '#ecad84'
  if t.t>0 then R.ring(x,y,t.r,c);R.disc(x,y,max(3,t.r*(1-min(1,t.t))),t.friendly and '#8ddac129' or '#d3695e35')
  else R.disc(x,y,t.r,t.friendly and '#9ce3ca90' or '#e899777f');R.ring(x,y,t.r,c) end
 end
 local drawables={};for _,p in ipairs(m.props) do drawables[#drawables+1]={type='prop',v=p,y=p.y} end
 if m.kind~='combat' and m.kind~='elite' and m.kind~='boss' then drawables[#drawables+1]={type='object',v=m.object,y=m.object.y} end
 drawables[#drawables+1]={type='exit',v=m.exit,y=m.exit.y}
 for _,e in ipairs(w.enemies) do if not e.dead or w.time-(e.deathTime or 0)<.7 then drawables[#drawables+1]={type='enemy',v=e,y=e.y} end end
 drawables[#drawables+1]={type='hero',v=w.player,y=w.player.y}
 table.sort(drawables,function(a,b)return a.y<b.y end)
 for _,o in ipairs(drawables) do local e=o.v;local x,y=floor(e.x-cx),floor(e.y-cy)
  if x>-110 and x<750 and y>-90 and y<460 then
   if o.type=='prop' then
    if e.light then R.disc(x,y-24,24,'#d4b47910') end
    R.prop(e.id,x,y)
   elseif o.type=='object' then
    R.disc(x,y-20,34,'#a8d9bc15');R.prop(w.objectUsed and m.kind=='treasure' and 12 or e.id,x,y)
   elseif o.type=='exit' then
    R.prop(15,x,y);if not w.clear then R.rect(x-9,y-31,18,23,'#0b1721aa');R.icon(27,x-9,y-30,18) else R.ring(x,y-16,18,'#b1ddc0') end
   elseif o.type=='hero' then
    R.disc(x,y-1,11,'#07141c9c')
    if e.dash>0 then for i=1,3 do R.rect(x-e.dashX*i*8-7,y-e.dashY*i*8-25,14,20,'#8dc5bb25') end end
    local frame=floor(e.walk)%8;local sx,sy=frame*48,e.face*48
    if (e.swing or 0)>0 then local idx=e.face*4+min(3,floor((.16-e.swing)*25));sx=(idx%8)*48;sy=(4+floor(idx/8))*48 end
    if e.invul<=0 or floor(w.time*18)%2==0 or e.dash>0 then R.region('hero',sx,sy,48,48,x-24,y-43) end
    if (e.swing or 0)>0 and w.weapon==1 then
     local a=math.atan(e.ay,e.ax);for i=-5,5 do local aa=a+i*.15;R.rect(x+math.cos(aa)*44-1,y-14+math.sin(aa)*30-1,3,3,'#d7e9c4') end
    end
    if e.shield>0 then R.ring(x,y-16,23,'#c6cbaa79') end
    for orb=1,w:rank('orbit') do local a=w.time*2.3+orb*math.pi*2/w:rank('orbit');local xx,yy=x+math.cos(a)*44,y+math.sin(a)*44-12;R.disc(xx,yy,5,'#86d6c7');R.rect(xx-1,yy-1,3,3,'#fff0c5') end
   elseif o.type=='enemy' then
    local boss=e.boss;local size=boss and 96 or 48;R.disc(x,y-1,boss and 22 or 12,'#06131c8f')
    if e.dead then gfx.alpha(max(0,1-(w.time-e.deathTime)/.7)) end
    if e.state=='windup' then R.ring(x,y-12,boss and 32 or 17,'#ecc58e');R.rect(x-2,y-size,4,11,'#f5cba0') end
    R.region(boss and 'bosses' or 'enemies',floor(e.age*7)%6*size,(e.kind-1)*size,size,size,x-size/2,y-size+6)
    if e.dead then gfx.unalpha() elseif not boss and e.hp<e.maxhp then R.rect(x-13,y-size+1,26,2,'#16232d');R.rect(x-13,y-size+1,26*max(0,e.hp/e.maxhp),2,'#d5a26a') end
    if e.burn>0 then R.rect(x-8,y-12,3,5,'#efab6d');R.rect(x+5,y-18,2,4,'#f4d598') end
    if e.poison>0 then R.rect(x+8,y-20,3,3,'#b4d785') end
    if e.slow>0 then R.rect(x-9,y-3,3,2,'#a9e0e8');R.rect(x+7,y-1,4,2,'#a9e0e8') end
   end
  end
 end
 for _,l in ipairs(w.loot) do R.icon(l.kind=='gold' and 32 or 5,l.x-cx-8,l.y-cy-10,16) end
 for _,s in ipairs(w.shots) do local x,y=s.x-cx,s.y-cy-12;R.rect(x-s.vx*.025-2,y-s.vy*.025-2,4,4,s.color..'50');R.disc(x,y,s.r,s.color);R.rect(x-1,y-1,2,2,'#ffe9c0') end
 for _,q in ipairs(w.particles) do R.rect(q.x-cx,q.y-cy-16,q.size,q.size,q.color) end
 -- Distant air and deliberately discrete dust motes, no blur or gradients.
 for i=1,28 do local x=(i*91+w.time*(i%3+1)*3)%670-15;local y=(i*47+math.sin(w.time*.4+i)*8)%360;R.rect(x,y,i%5==0 and 2 or 1,1,C.biomes[w.biome].color..'65') end
 R.rect(0,0,640,3,'#07111b');R.rect(0,357,640,3,'#07111b')
end
function R.hud(w,touch)
 local p=w.player;local color=C.biomes[w.biome].color
 R.panel(8,7,205,43);R.icon(5,15,14,22);R.rect(43,16,157,8,'#0a1421');R.rect(44,17,155*max(0,p.hp/p.maxhp),6,'#c97f78')
 R.text(math.ceil(p.hp)..' / '..p.maxhp,45,28);R.icon(7,131,28,15);R.text('x'..p.potions,149,28)
 R.panel(420,7,212,43);R.text(C.biomes[w.biome].name,430,13);R.text(string.format('%02d / 05',w.biome)..'  '..C.t(C.ui[w.node.kind]),430,28)
 R.panel(222,7,188,26);R.icon(32,227,11,18);R.text(tostring(w.gold),249,13);R.icon(38,307,11,18);R.text(tostring(w.shards),329,13)
 local boss=nil;for _,e in ipairs(w.enemies) do if e.boss and not e.dead then boss=e;break end end
 if boss then R.panel(167,56,306,29);R.text(C.biomes[w.biome].boss,176,59,1,'center',288);R.rect(178,78,284,3,'#1d263a');R.rect(178,78,284*max(0,boss.hp/boss.maxhp),3,color) end
 R.panel(8,322,624,30)
 R.icon(w.weapon+1,14,325,23);R.text(C.weapons[w.weapon].name,42,329)
 R.text('Q: '..C.t(C.ui.skill)..' '..(p.skillcd>0 and string.format('%.0f',p.skillcd) or C.t(C.ui.ready)),238,329)
 R.text('SPACE: '..C.t(C.ui.dash)..'  TAB: '..C.t(C.ui.map),410,329)
 if w.clear and w.phase=='play' then
  local hint=C.ui.exit;local o=w.map.object;local dx,dy=p.x-o.x,p.y-o.y
  if not w.objectUsed and dx*dx+dy*dy<95*95 and w.node.kind~='combat' and w.node.kind~='elite' and w.node.kind~='boss' then hint=C.ui[w.node.kind=='treasure' and 'treasurehint' or w.node.kind=='rest' and 'resthint' or 'interacthint'] end
  R.panel(121,289,398,25);R.text(hint,130,295,1,'center',380)
 end
 if touch then
  for _,b in ipairs({{4,270,56,'DASH'},{65,270,56,'HEAL'},{520,270,54,'Q'},{580,270,56,'USE'}}) do R.panel(b[1],b[2],b[3],35);R.text(b[4],b[1],b[2]+10,1,'center',b[3]) end
 end
end
return R
