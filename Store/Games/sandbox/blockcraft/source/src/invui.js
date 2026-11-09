import { RecipeBook } from './recipebook.js';
// Inventory screens: player inventory with 2x2 crafting, crafting table (3x3), furnace, chest and the creative
// palette. Click rules: A / left click picks up, places or swaps a stack, Y / right click splits or places
// one, ZR / shift quick-moves. The controller moves a slot cursor with the D-pad or left stick.
// Touch: tap a slot to take, tap again to place; drag a stack with the finger; hold a slot to split (or to drop one
// from the carried stack); tap outside the panel to drop what is carried; swipe the creative list to scroll.
import { B, I, creativeList, maxStack, itemDef } from "./registry.js";
import { matchRecipe, SMELT_SECONDS, smeltResult, fuelSeconds } from "./crafting.js";
import { stack, clone, canStack, addToSlots } from "./inventory.js";
import { drawStack, itemName, drawIcon } from "./hud.js";
import { shadowText } from "./widgets.js";
import icons from "../textures/icons.json";

const TITLES = { inventory: "ui.crafting", crafting: "ui.crafting_table", furnace: "ui.furnace", chest: "ui.chest", creative: "ui.creative" };

export class InvUI {
  constructor(app) {
    this.app = app;
    this.recipeBook=new RecipeBook();
    this.isOpen = false;
    this.kind = null;
    this.be = null;
    this.grid = [];
    this.gridW = 2;
    this.result = null;
    this.carried = null;
    this.cursor = 0;
    this.slots = [];
    this.tab = 0;
    this.scroll = 0;
    this.search = '';
    this.paletteCache = null;
    this.repeat = 0;
    this.hover = -1;
    this.tp = null;          // active touch: { x0, y0, x, y, t0, slot, moved, mode, from, scroll0 }
    this.touchUI = false;    // last pointer was a finger: slot clicks come from pointer(), not ui.hit
    this.S = 44; this.panel = [0, 0, 0, 0];
    this.palette = [[], []];
    for (const id of creativeList()) if (icons[id] !== undefined) this.palette[id < 256 ? 0 : 1].push(id);
  }

  get game() { return this.app.game; }

  open(kind, be) {
    this.isOpen = true;this.recipeBook.open=false;
    this.kind = kind;
    this.be = be || null;
    this.gridW = kind === "crafting" ? 3 : 2;
    this.grid = new Array(this.gridW * this.gridW).fill(null);
    this.result = null;
    this.carried = null;
    this.cursor = -1;
    this.scroll = 0;
    this.tp = null;
  }

  close() {
    const g = this.game;
    const back = s => { if (!s) return; const left = g.inventory.add(s); if (left > 0) g.throwStack(stack(s.id, left, s.damage)); };
    for (const s of this.grid) back(s);
    back(this.carried);
    this.grid = []; this.carried = null; this.tp = null;
    this.isOpen = false;
    if (this.kind === "chest" && g) { const p = g.player; g.sound.play("door_close", { x: p.pos.x, y: p.pos.y, z: p.pos.z, volume: 0.5 }); }
    this.kind = null;
  }

  clearGrid() {
    const g=this.game;
    for(let i=0;i<this.grid.length;i++) {
      const s=this.grid[i];if(!s)continue;
      const left=g.inventory.add(s);
      this.grid[i]=left>0?stack(s.id,left,s.damage):null;
    }
    this.result=matchRecipe(this.grid,this.gridW);
    g.inventory.changed();
  }

  filteredPalette() {
    const query=this.search.trim().toLocaleLowerCase();
    if(!this.paletteCache || this.paletteCache.query!==query || this.paletteCache.tab!==this.tab) {
      this.paletteCache={query,tab:this.tab,list:this.palette[this.tab].filter(id=>!query||itemName(id).toLocaleLowerCase().includes(query))};
    }
    return this.paletteCache.list;
  }

  // ---------- slot actions ----------
  arrOf(sl) { return sl.arr; }
  leftClick(sl) {
    const g = this.game, inv = g.inventory;
    if (sl.kind === "palette") {
      if (this.carried) this.carried = null;
      else this.carried = stack(sl.id, maxStack(sl.id));
      return;
    }
    if (sl.kind === "trash") { this.carried = null; return; }
    if (sl.kind === "result") { this.takeResult(false); return; }
    const arr = sl.arr, i = sl.i, s = arr[i], c = this.carried;
    if (sl.kind === "output") {
      if (!s) return;
      if (!c) { this.carried = s; arr[i] = null; }
      else if (canStack(c, s) && c.count + s.count <= maxStack(c.id)) { c.count += s.count; arr[i] = null; }
      inv.changed();
      return;
    }
    if (!c) { if (s) { this.carried = s; arr[i] = null; } }
    else if (!s) { arr[i] = c; this.carried = null; }
    else if (canStack(c, s)) {
      const n = Math.min(maxStack(s.id) - s.count, c.count);
      s.count += n; c.count -= n;
      if (c.count <= 0) this.carried = null;
    } else { arr[i] = c; this.carried = s; }
    inv.changed();
  }
  rightClick(sl) {
    const g = this.game;
    if (sl.kind === "palette") { if (!this.carried) this.carried = stack(sl.id, 1); else if (this.carried.id === sl.id && this.carried.count < maxStack(sl.id)) this.carried.count++; return; }
    if (sl.kind === "result" || sl.kind === "output" || sl.kind === "trash") { this.leftClick(sl); return; }
    const arr = sl.arr, i = sl.i, s = arr[i], c = this.carried;
    if (!c) {
      if (!s) return;
      const half = Math.ceil(s.count / 2);
      this.carried = stack(s.id, half, s.damage);
      s.count -= half;
      if (s.count <= 0) arr[i] = null;
    } else if (!s) {
      arr[i] = stack(c.id, 1, c.damage);
      if (--c.count <= 0) this.carried = null;
    } else if (canStack(c, s) && s.count < maxStack(s.id)) {
      s.count++;
      if (--c.count <= 0) this.carried = null;
    } else { arr[i] = c; this.carried = s; }
    g.inventory.changed();
  }
  quickMove(sl) {
    const g = this.game, inv = g.inventory;
    if (sl.kind === "palette") { inv.add(stack(sl.id, maxStack(sl.id))); return; }
    if (sl.kind === "result") { this.takeResult(true); return; }
    if (sl.kind === "trash") return;
    const arr = sl.arr, s = arr[sl.i];
    if (!s) return;
    const copy = clone(s);
    let left;
    if (arr === inv.slots) {
      if (this.be && this.kind === "chest") left = addToSlots(this.be.slots, copy, [...Array(27).keys()]);
      else if (this.be && this.kind === "furnace") {
        const target = smeltResult(s.id) !== null ? 0 : fuelSeconds(s.id) > 0 ? 1 : -1;
        left = target >= 0 ? addToSlots(this.be.slots, copy, [target]) : addToSlots(inv.slots, copy, sl.i < 9 ? [...Array(27).keys()].map(k => k + 9) : [...Array(9).keys()]);
      } else left = addToSlots(inv.slots, copy, sl.i < 9 ? [...Array(27).keys()].map(k => k + 9) : [...Array(9).keys()]);
    } else left = addToSlots(inv.slots, copy, [...Array(36).keys()]);
    if (left <= 0) arr[sl.i] = null; else arr[sl.i].count = left;
    inv.changed();
  }
  takeResult(all) {
    const g = this.game, inv = g.inventory;
    for (let n = 0; n < (all ? 64 : 1); n++) {
      const r = matchRecipe(this.grid, this.gridW);
      if (!r) return;
      const out = stack(r.id, r.count);
      if (all) { if (!inv.canFit(out)) return; inv.add(out); }
      else {
        const c = this.carried;
        if (c && !(canStack(c, out) && c.count + out.count <= maxStack(c.id))) return;
        if (c) c.count += out.count; else this.carried = out;
      }
      for (let i = 0; i < this.grid.length; i++) {
        const s = this.grid[i];
        if (!s) continue;
        if (s.id === I.water_bucket || s.id === I.lava_bucket || s.id === I.milk_bucket) { this.grid[i] = stack(I.bucket, 1); continue; }
        if (--s.count <= 0) this.grid[i] = null;
      }
      inv.changed();
      g.sound.play("pop", { volume: 0.4 });
    }
  }

  // ---------- touch ----------
  slotAt(x, y) {
    const S = this.S;
    for (let i = 0; i < this.slots.length; i++) { const sl = this.slots[i]; if (x >= sl.x && x < sl.x + S && y >= sl.y && y < sl.y + S) return i; }
    return -1;
  }
  inPanel(x, y) { const [px, py, pw, ph] = this.panel; return x >= px && x < px + pw && y >= py && y < py + ph; }
  dropCarried() {
    if (!this.carried) return;
    if (this.kind !== "creative") this.game.throwStack(this.carried);
    this.carried = null;
    this.game.inventory.changed();
  }
  // Mouse events while the screen is open (main.js app.event). Finger events are handled here and consumed;
  // mouse events go on to ui.hit as before.
  pointer(e) {
    if (this.recipeBook.open) return false;
    if (e.type === "mousedown") {
      this.touchUI = !!e.touch;
      if (!e.touch) return false;
      this.cursor = -1;
      this.tp = { x0: e.x, y0: e.y, x: e.x, y: e.y, t0: sys.time(), slot: this.slotAt(e.x, e.y), moved: 0, mode: null, from: null, scroll0: this.scroll };
      return true;
    }
    const t = this.tp;
    if (!t) return false;
    if (e.type === "mousemove") {
      t.moved = Math.max(t.moved, Math.hypot(e.x - t.x0, e.y - t.y0));
      t.x = e.x; t.y = e.y;
      if (!t.mode && t.moved > 12) {
        const sl = t.slot >= 0 ? this.slots[t.slot] : null;
        if (sl && sl.kind === "palette" && !this.carried && Math.abs(e.y - t.y0) > Math.abs(e.x - t.x0)) t.mode = "scroll";
        else if (sl && !this.carried) {
          const before = sl.arr ? sl.arr[sl.i] : null;
          this.leftClick(sl);
          if (this.carried) { t.mode = "drag"; t.from = sl.arr && before ? sl : null; } else t.mode = "none";
        } else t.mode = this.carried ? "drag" : "none";
      }
      if (t.mode === "scroll") this.scroll = Math.max(0, t.scroll0 - Math.round((e.y - t.y0) / this.S));
      return true;
    }
    if (e.type === "mouseup") {
      this.tp = null;
      t.x = e.x; t.y = e.y;
      const i = this.slotAt(e.x, e.y);
      if (t.mode === "scroll" || t.mode === "split" || t.mode === "none") return true;
      if (t.mode === "drag") {
        if (i >= 0) this.leftClick(this.slots[i]);
        else if (!this.inPanel(e.x, e.y)) this.dropCarried();
        // what is still in hand (a swap, or a drop outside any slot inside the panel) goes back where it came from
        if (this.carried && t.from && !t.from.arr[t.from.i]) { t.from.arr[t.from.i] = this.carried; this.carried = null; this.game.inventory.changed(); }
        return true;
      }
      if (i >= 0) this.leftClick(this.slots[i]);
      else if (!this.inPanel(e.x, e.y)) this.dropCarried();
      return true;
    }
    return false;
  }
  // long press: split a stack (take half), or put one item of the carried stack down
  touchFrame() {
    const t = this.tp;
    if (!t || t.mode || t.moved > 12 || sys.time() - t.t0 < 0.45) return;
    t.mode = "split";
    if (t.slot >= 0 && t.slot < this.slots.length) { this.rightClick(this.slots[t.slot]); this.game.sound.play("click", { volume: 0.4 }); }
  }

  // ---------- frame ----------
  update() {
    const g = this.game, inp = this.app.input;
    if (this.recipeBook.open) {
      if(input.pressed('b')||inp.keyPressed('escape')||inp.keyPressed('r'))this.recipeBook.open=false;
      else {
        const count=this.recipeBook.items(this).length;
        if(count&&inp.keyPressed('down'))this.recipeBook.selected=(this.recipeBook.selected+1)%count;
        if(count&&inp.keyPressed('up'))this.recipeBook.selected=(this.recipeBook.selected-1+count)%count;
        if(inp.keyPressed('enter'))this.recipeBook.apply(this);
      }
      return;
    }
    if ((this.kind==='inventory'||this.kind==='crafting')&&(input.pressed('minus')||inp.keyPressed('r'))) {this.recipeBook.toggle();return;}
    if (inp.inventoryPressed() || input.pressed("b") || inp.keyPressed("escape")) { g.closeScreen(); return; }
    this.result = this.kind === "inventory" || this.kind === "crafting" ? matchRecipe(this.grid, this.gridW) : null;
    if (this.kind === "creative" && (input.pressed("l") || input.pressed("r") || inp.keyPressed("tab"))) { this.tab = 1 - this.tab; this.scroll = 0; }
    if(this.kind==='creative'&&(input.pressed('minus')||inp.keyPressed('f')))this.editSearch();
  }

  editSearch() {
    ui.keyboard(this.search,t=>{if(t!==null&&t!==undefined){this.search=t.slice(0,32);this.scroll=0;}},TR('ui.search_items'));
  }

  // slot cursor movement with the controller
  navigate(dt) {
    const [sx, sy] = input.stick("left");
    let dx = 0, dy = 0;
    if (input.pressed("left")) dx = -1; else if (input.pressed("right")) dx = 1;
    if (input.pressed("up")) dy = -1; else if (input.pressed("down")) dy = 1;
    if (!dx && !dy && Math.hypot(sx, sy) > 0.6) {
      this.repeat -= dt;
      if (this.repeat <= 0) { this.repeat = 0.14; if (Math.abs(sx) > Math.abs(sy)) dx = Math.sign(sx); else dy = -Math.sign(sy); }
    } else if (Math.hypot(sx, sy) <= 0.6) this.repeat = 0;
    if (!dx && !dy) return;
    if (this.cursor < 0 || this.cursor >= this.slots.length) { this.cursor = 0; return; }
    const cur = this.slots[this.cursor];
    let best = -1, bd = Infinity;
    for (let i = 0; i < this.slots.length; i++) {
      if (i === this.cursor) continue;
      const s = this.slots[i];
      const vx = s.x - cur.x, vy = s.y - cur.y;
      const along = vx * dx + vy * dy;
      if (along <= 1) continue;
      const across = Math.abs(dx ? vy : vx);
      const d = along + across * 2.5;
      if (d < bd) { bd = d; best = i; }
    }
    if (best >= 0) this.cursor = best;
    else if (this.kind === "creative" && dy) this.scroll = Math.max(0, this.scroll + dy);
  }

  draw(w, h, dt) {
    if (this.recipeBook.open) {this.recipeBook.draw(w,h,this);return;}
    const g = this.game, k = Math.min(this.app.uiScale(w, h),(h-28)/(this.kind==='creative'?550:460)), inv = g.inventory;
    gfx.color("#00000088"); gfx.rect(0, 0, w, h);
    // slots stay at least 44 px for fingers as long as nine of them fit
    const rows=this.kind==='creative'?9:7,extra=this.kind==='creative'?136:112;
    const S = Math.min(Math.max(44 * k, 44), (w - 24) / 9.8,(h-28-extra*k)/rows), pad = 16 * k;
    this.S = S;
    const PW = S * 9 + pad * 2;
    const topH = this.kind === "chest" ? S * 3 + 40 * k : this.kind === "creative" ? S * 5 + 64 * k : S * 3 + 40 * k;
    const PH = topH + S * 4 + 30 * k + pad * 2 + 10 * k;
    const px = (w - PW) / 2, py = Math.max(8 * k, (h - PH) / 2);
    this.panel = [px, py, PW, PH];
    gfx.color("#00000066"); gfx.rect(px + 4 * k, py + 6 * k, PW, PH, 10 * k);
    gfx.color("#C6C6C6"); gfx.rect(px, py, PW, PH, 0);
    gfx.color("#FFFFFF80"); gfx.rect(px + 3 * k, py + 3 * k, PW - 6 * k, 3 * k, 2 * k);
    gfx.color("#3F3F3F"); gfx.text(TR(TITLES[this.kind] || "ui.crafting"), px + pad, py + 10 * k, 18 * k, "bold");
    const slots = [];
    const add = (arr, i, x, y, kind = "normal", id) => slots.push({ arr, i, x, y, kind, id });
    const top = py + 40 * k;
    if (this.kind === "inventory" || this.kind === "crafting") {
      const gw = this.gridW, gx = px + PW / 2 - (gw * S) - 20 * k, gy = top + (3 - gw) * S / 2;
      for (let i = 0; i < gw * gw; i++) add(this.grid, i, gx + (i % gw) * S, gy + Math.floor(i / gw) * S);
      add(null, 0, px + PW / 2 + 60 * k, top + S, "result");
      gfx.color("#8B8B8B"); this.arrow(px + PW / 2 + 8 * k, top + S + S / 2, k);
    } else if (this.kind === "furnace") {
      const fx = px + PW / 2 - S * 2, be = this.be;
      add(be.slots, 0, fx, top);
      add(be.slots, 1, fx, top + S * 2);
      add(be.slots, 2, px + PW / 2 + S, top + S, "output");
      const burn = be.burnMax > 0 ? be.burn / be.burnMax : 0;
      gfx.color("#8B8B8B"); gfx.rect(fx + S * 0.25, top + S * 1.2, S * 0.5, S * 0.6, 3 * k);
      if (burn > 0) { gfx.color("#FF8A1E"); gfx.rect(fx + S * 0.25, top + S * 1.2 + S * 0.6 * (1 - burn), S * 0.5, S * 0.6 * burn, 3 * k); }
      gfx.color("#8B8B8B"); this.arrow(px + PW / 2 - S * 0.6, top + S * 1.5, k);
      const cook = be.cook / SMELT_SECONDS;
      if (cook > 0) { gfx.color("#FFFFFF"); gfx.rect(px + PW / 2 - S * 0.6, top + S * 1.5 - 4 * k, S * 1.2 * cook, 8 * k, 3 * k); }
    } else if (this.kind === "chest") {
      for (let i = 0; i < 27; i++) add(this.be.slots, i, px + pad + (i % 9) * S, top + Math.floor(i / 9) * S);
    } else if (this.kind === "creative") {
      const list = this.filteredPalette();
      const rows = Math.ceil(list.length / 9);
      this.scroll = Math.max(0, Math.min(this.scroll, Math.max(0, rows - 5)));
      const tabs = [TR("ui.tab_blocks"), TR("ui.tab_items")];
      for (let t = 0; t < 2; t++) {
        const tx = px + PW - pad - (2 - t) * 120 * k, on = this.tab === t;
        gfx.color(on ? "#E8E8E8" : "#9A9A9A"); gfx.rect(tx, py + 8 * k, 112 * k, 26 * k, 6 * k);
        gfx.color("#303030"); gfx.text(tabs[t], tx, py + 12 * k, 15 * k, "bold", "center", 112 * k);
        if (ui.hit("tab" + t, tx, py + 8 * k, 112 * k, 26 * k).clicked) { this.tab = t; this.scroll = 0; }
      }
      for (let r = 0; r < 5; r++) for (let c = 0; c < 9; c++) {
        const idx = (this.scroll + r) * 9 + c;
        if (idx >= list.length) continue;
        add(null, idx, px + pad + c * S, top + r * S, "palette", list[idx]);
      }
      const sy=top+S*5+3*k;
      gfx.color('#7C7C7C');gfx.rect(px+pad,sy,PW-pad*2-32*k,23*k,0);
      gfx.color('#FFFFFF');gfx.text(TR('ui.search_items')+': '+(this.search||TR('ui.search_all')),px+pad+6*k,sy+3*k,13*k,'sans');
      if(ui.hit('creative:search',px+pad,sy,PW-pad*2-32*k,23*k).clicked)this.editSearch();
      const tx=px+PW-pad-26*k;
      gfx.color('#8E4141');gfx.rect(tx,sy,26*k,23*k,0);gfx.icon('delete',tx+13*k,sy+11*k,18*k,'#FFFFFF');
      if(ui.hit('creative:trash',tx,sy,26*k,23*k).clicked){this.carried=null;inv.changed();}
      // scroll bar
      if (rows > 5) {
        const sh = S * 5, f = this.scroll / Math.max(1, rows - 5);
        gfx.color("#8B8B8B"); gfx.rect(px + PW - 10 * k, top, 6 * k, sh, 3 * k);
        gfx.color("#4A4A4A"); gfx.rect(px + PW - 10 * k, top + f * (sh - 30 * k), 6 * k, 30 * k, 3 * k);
      }
      const [rx, ry] = input.stick("right");
      this.scrollAcc = (this.scrollAcc || 0) - ry * dt * 8;
      if (Math.abs(this.scrollAcc) >= 1) { this.scroll += Math.trunc(this.scrollAcc); this.scrollAcc -= Math.trunc(this.scrollAcc); }
      void rx;
      if (this.app.input.wheel) { this.scroll += this.app.input.wheel; this.app.input.wheel = 0; }
    }
    // player inventory
    const iy = py + PH - pad - S * 4 - 8 * k;
    for (let i = 9; i < 36; i++) add(inv.slots, i, px + pad + ((i - 9) % 9) * S, iy + Math.floor((i - 9) / 9) * S);
    for (let i = 0; i < 9; i++) add(inv.slots, i, px + pad + i * S, iy + S * 3 + 8 * k);
    this.slots = slots;

    // input: controller cursor, then mouse per slot (fingers go through pointer())
    this.navigate(dt);
    this.touchFrame();
    if (this.cursor >= slots.length) this.cursor = slots.length - 1;
    this.hover = -1;
    slots.forEach((sl, i) => {
      const hit = ui.hit("slot" + i, sl.x, sl.y, S, S);
      if (this.touchUI) return;
      if (hit.hovered) this.hover = i;
      if (hit.clicked) { this.cursor = -1; if (this.app.input.key("shift")) this.quickMove(sl); else this.leftClick(sl); }
      if (hit.rightClicked) this.rightClick(sl);
    });
    if (this.tp) this.hover = this.slotAt(this.tp.x, this.tp.y);
    // close button (X) on the panel's top-right corner
    const cs = Math.max(44, S), cx = Math.min(w - cs, px + PW - cs * 0.6), cy = Math.max(0, py - cs * 0.4);
    gfx.color("#00000066"); gfx.circle(cx + cs / 2 + 2 * k, cy + cs / 2 + 3 * k, cs * 0.42);
    gfx.color("#B23A3A"); gfx.circle(cx + cs / 2, cy + cs / 2, cs * 0.42);
    gfx.icon("close", cx + cs / 2, cy + cs / 2, cs * 0.55, "#FFFFFF");
    if (ui.hit("invclose", cx, cy, cs, cs).clicked) { this.tp = null; g.closeScreen(); return; }
    const cur = this.cursor >= 0 ? slots[this.cursor] : null;
    if (cur) {
      if (input.pressed("a")) this.leftClick(cur);
      if (input.pressed("y")) this.rightClick(cur);
      if (input.pressed("zr")) this.quickMove(cur);
    } else if (input.pressed("a") || input.pressed("down") || input.pressed("up") || input.pressed("left") || input.pressed("right")) this.cursor = Math.max(0, slots.length - 9);

    if (this.kind==='inventory'||this.kind==='crafting') {
      const bx=px+PW-130*k,by=py+8*k;gfx.color('#5B7948');gfx.rect(bx,by,110*k,27*k,0);
      gfx.color('#FFFFFF');gfx.text(TR('book.button'),bx,by+5*k,13*k,'bold','center',110*k);
      if(ui.hit('recipe:open',bx,by,110*k,27*k).clicked)this.recipeBook.toggle();
      const ex=px+PW/2+60*k,ey=top+S*2.3;
      gfx.color('#737373');gfx.rect(ex,ey,120*k,25*k,0);gfx.color('#FFFFFF');
      gfx.text(TR('book.clear'),ex,ey+5*k,12*k,'bold','center',120*k);
      if(ui.hit('recipe:clear',ex,ey,120*k,25*k).clicked||input.pressed('l'))this.clearGrid();
    }
    // draw slots
    for (let i = 0; i < slots.length; i++) {
      const sl = slots[i];
      gfx.color(sl.kind === "result" || sl.kind === "output" ? "#8B8B8B" : "#8B8B8B");
      gfx.rect(sl.x + 2 * k, sl.y + 2 * k, S - 4 * k, S - 4 * k, 2 * k);
      gfx.color("#373737"); gfx.rect(sl.x + 2 * k, sl.y + 2 * k, S - 4 * k, 2 * k);
      if (sl.kind === "trash") { gfx.icon("delete", sl.x + S / 2, sl.y + S / 2, S * 0.6, "#5A2020"); continue; }
      let st = null;
      if (sl.kind === "palette") st = stack(sl.id, 1);
      else if (sl.kind === "result") st = this.result ? stack(this.result.id, this.result.count) : null;
      else st = sl.arr[sl.i];
      drawStack(st, sl.x, sl.y, S, k);
      if (i === this.hover || i === this.cursor) { gfx.color("#FFFFFF60"); gfx.rect(sl.x + 2 * k, sl.y + 2 * k, S - 4 * k, S - 4 * k, 2 * k); }
      if (this.tp && i === this.hover && this.carried) { gfx.color("#FFE45C"); gfx.rectLine(sl.x, sl.y, S, S, 4 * k, 3 * k); }
      if (i === this.cursor) { gfx.color("#FFFFFF"); gfx.rectLine(sl.x, sl.y, S, S, 4 * k, 3 * k); }
    }
    // tooltip
    const tip = this.hover >= 0 ? slots[this.hover] : cur;
    if (tip && !this.carried) {
      const st = tip.kind === "palette" ? stack(tip.id, 1) : tip.kind === "result" ? (this.result ? stack(this.result.id, 1) : null) : tip.kind === "trash" ? null : tip.arr[tip.i];
      if (st) {
        const name = itemName(st.id), tw = gfx.textWidth(name, 16 * k, "bold") + 16 * k;
        const tx = Math.min(w - tw - 4, tip.x + S), ty = tip.y - 28 * k;
        gfx.color("#100010F0"); gfx.rect(tx, ty, tw, 26 * k, 5 * k);
        gfx.color("#5000FF80"); gfx.rectLine(tx, ty, tw, 26 * k, 5 * k, 1.5 * k);
        gfx.color("#FFFFFF"); gfx.text(name, tx + 8 * k, ty + 4 * k, 16 * k, "bold");
      }
    }
    // carried stack follows the pointer or the cursor
    if (this.carried) {
      const [mx, my] = this.tp ? [this.tp.x, this.tp.y - S * 0.6] : ui.mouse();
      const at = cur ? [cur.x + S * 0.35, cur.y + S * 0.35] : [mx - S / 2, my - S / 2];
      drawStack(this.carried, at[0], at[1], S, k);
    }
    shadowText(TR(this.touchUI || this.app.input.touchMode ? "ui.inv_help_touch" : "ui.inv_help"), 0, Math.min(h - 20 * k, py + PH + 8 * k), 14 * k, "#DDDDDD", "center", w, "sans");
    void drawIcon; void itemDef; void B;
  }

  arrow(x, y, k) {
    gfx.rect(x, y - 4 * k, 34 * k, 8 * k);
    gfx.poly([x + 30 * k, y - 12 * k, x + 46 * k, y, x + 30 * k, y + 12 * k]);
  }
}
