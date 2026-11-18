let volume = 0.5, name = "", selected = 0, zoom = 1, angle = 0;
let last = "";
let lastw=0, lasth=0;
export default {
 event(e) {
  if (e.type === "pinch") zoom = Math.max(0.25, Math.min(4, zoom * e.scale));
  if (e.type === "rotate") angle += e.angle;
 },
 draw(w,h) {
  const compact=w<620, shift=compact?46:0;
  if(w!==lastw || h!==lasth) { sys.log("Layout "+(compact?"compact":"wide")+" "+w+" "+h); lastw=w; lasth=h; }
  gfx.clear(theme.window); gfx.color(theme.text);
  gfx.text(TR("title"),20,16,19,"bold");
  gfx.text(compact?TR("hint.compact"):TR("hint.wide"),20,48,13.8);
  selected=ui.dropdown("mode",[TR("mode.touch"),TR("mode.pad"),TR("mode.keyboard")],selected,20,80,230,30);
  name=ui.textfield("name",name,compact?20:270,80+shift,compact?w-40:w-290,30,TR("placeholder"));
  volume=ui.slider("volume",volume,0,1,20,126+shift,w-40);
  const status = "Value "+volume.toFixed(2)+" | Pinch "+zoom.toFixed(2)+" | Rotation "+angle.toFixed(2);
  if (status !== last) { sys.log(status); last = status; }
  const visible=TR("value")+" "+volume.toFixed(2)+" | "+TR("pinch")+" "+zoom.toFixed(2)+(compact?"":" | "+TR("rotation")+" "+angle.toFixed(2));
  gfx.text(visible,20,164+shift,13.8);
  ui.beginScroll("outer",20,200+shift,w-40,h-220-shift,1100);
  gfx.color(theme.text); gfx.text(compact?TR("frame.compact"):TR("frame.wide"),12,8,15,"bold");
  ui.beginScroll("inner",12,44,w-90,180,900);
  for(let i=0;i<20;i++) ui.button(TR("row.inner")+" "+(i+1),8,i*44,w-130,36);
  ui.endScroll();
  for(let i=0;i<18;i++) ui.button(TR("row.outer")+" "+(i+1),12,244+i*44,w-90,36);
  ui.endScroll();
 }
};
