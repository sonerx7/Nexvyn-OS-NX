// In-game HUD: crosshair, hotbar with the item icons, hearts, hunger, air, messages, the held item name,
// sleep fade, the debug overlay and the on-screen touch controls.
import icons from "../textures/icons.json";
import { itemDef, nameKey } from "./registry.js";
import { shadowText } from "./widgets.js";
import { clamp } from "./util.js";

const ICONS = "bundle:/textures/icons.png", HUDTEX = "bundle:/textures/hud.png";

export function itemName(id) {
  const d = itemDef(id);
  if (!d) return "?";
  if (d.tool) return TR("tool." + d.tool.type, TR("tier." + ["wood", "stone", "iron", "diamond"][d.tool.tier]));
  return TR("n." + nameKey(id));
}

// draws an inventory icon (48 px cells of icons.png) at x, y with size s
export function drawIcon(id, x, y, s) {
  const cell = icons[id];
  if (cell === undefined) return;
  const img = gfx.image(ICONS);
  if (!img) return;
  gfx.drawRegion(img, (cell % 16) * 48, Math.floor(cell / 16) * 48, 48, 48, x, y, s, s);
}

export function drawStack(st, x, y, s, k) {
  if (!st) return;
  drawIcon(st.id, x + s * 0.1, y + s * 0.1, s * 0.8);
  const d = itemDef(st.id);
  if (d && d.durability && st.damage > 0) {
    const f = clamp(1 - st.damage / d.durability, 0, 1);
    gfx.color("#000000"); gfx.rect(x + s * 0.14, y + s * 0.82, s * 0.72, 3 * k);
    gfx.color(f > 0.5 ? "#4CD84C" : f > 0.25 ? "#E8C83A" : "#E84A3A"); gfx.rect(x + s * 0.14, y + s * 0.82, s * 0.72 * f, 3 * k);
  }
  if (st.count > 1) shadowText(String(st.count), x, y + s - 19 * k, 15 * k, "#FFFFFF", "right", s - 3 * k);
}

export class Hud {
  constructor(app) {
    this.app = app;
    this.messages = [];
    this.flash = 0;
    this.nameTimer = 0;
    this.debug = false;
    this.hidden = false;
    this.sleep = 0;
  }
  message(text) {
    this.messages.push({ text, t: 4.5 });
    if (this.messages.length > 4) this.messages.shift();
  }
  flashDamage() { this.flash = 0.4; }
  showItemName() { this.nameTimer = 2; }

  sprite(cell, x, y, s) {
    const img = gfx.image(HUDTEX);
    if (img) gfx.drawRegion(img, cell * 16, 0, 16, 16, x, y, s, s);
  }

  draw(g, w, h, dt) {
    const k = this.app.uiScale(w, h);
    for (const m of this.messages) m.t -= dt;
    this.messages = this.messages.filter(m => m.t > 0);
    this.flash = Math.max(0, this.flash - dt);
    this.nameTimer = Math.max(0, this.nameTimer - dt);
    const p = g.player, inv = g.inventory;
    if (this.sleep > 0) { gfx.alpha(this.sleep); gfx.color("#05060C"); gfx.rect(0, 0, w, h); gfx.unalpha(); }
    if (this.hidden || p.dead) { this.drawMessages(w, h, k); return; }

    // crosshair
    const cx = w / 2, cy = h / 2, c = 9 * k, t = 2 * k;
    gfx.color("#00000080"); gfx.rect(cx - c - 1, cy - t / 2 - 1, c * 2 + 2, t + 2); gfx.rect(cx - t / 2 - 1, cy - c - 1, t + 2, c * 2 + 2);
    gfx.color("#FFFFFFE0"); gfx.rect(cx - c, cy - t / 2, c * 2, t); gfx.rect(cx - t / 2, cy - c, t, c * 2);

    // hotbar
    const S = 46 * k, n = 9, hbW = S * n + 8 * k, hx = (w - hbW) / 2, hy = h - S - 14 * k;
    gfx.color("#00000088"); gfx.rect(hx, hy, hbW, S + 8 * k, 6 * k);
    for (let i = 0; i < n; i++) {
      const x = hx + 4 * k + i * S, y = hy + 4 * k;
      gfx.color("#FFFFFF10"); gfx.rect(x + 2 * k, y + 2 * k, S - 4 * k, S - 4 * k, 3 * k);
      drawStack(inv.slots[i], x, y, S, k);
    }
    const sx = hx + 4 * k + inv.selected * S;
    gfx.color("#FFFFFF"); gfx.rectLine(sx - 1 * k, hy + 3 * k, S + 2 * k, S + 2 * k, 4 * k, 3 * k);

    // survival bars
    if (!p.creative) {
      const hs = 18 * k, by = hy - hs - 6 * k;
      for (let i = 0; i < 10; i++) {
        const v = p.health - i * 2;
        const shake = p.health <= 4 ? Math.sin(g.clock * 30 + i) * 1.5 * k : 0;
        this.sprite(2, hx + i * (hs - 1 * k), by + shake, hs);
        if (v >= 2) this.sprite(0, hx + i * (hs - 1 * k), by + shake, hs);
        else if (v === 1) this.sprite(1, hx + i * (hs - 1 * k), by + shake, hs);
      }
      for (let i = 0; i < 10; i++) {
        const v = p.food - i * 2;
        const x = hx + hbW - (i + 1) * (hs - 1 * k);
        this.sprite(5, x, by, hs);
        if (v >= 2) this.sprite(3, x, by, hs);
        else if (v === 1) this.sprite(4, x, by, hs);
      }
      if (p.eyeInWater || p.air < 10) {
        const air = Math.ceil(p.air);
        for (let i = 0; i < 10; i++) if (i < air) this.sprite(6, hx + hbW - (i + 1) * (hs - 1 * k), by - hs, hs);
      }
    }
    // held item name
    if (this.nameTimer > 0 && inv.held) {
      gfx.alpha(clamp(this.nameTimer, 0, 1));
      shadowText(itemName(inv.held.id), 0, hy - (p.creative ? 34 : 62) * k, 18 * k, "#FFFFFF", "center", w);
      gfx.unalpha();
    }
    if (this.flash > 0) { gfx.alpha(this.flash); gfx.color("#FF000040"); gfx.rect(0, 0, w, h); gfx.unalpha(); }
    this.drawMessages(w, h, k);
    if (this.debug || this.app.settings.showFps) this.drawDebug(g, w, h, k);
    if (this.app.input.touchMode) this.drawTouch(g, w, h, k, hx, hy, hbW, S);
    else this.app.input.buttons = [];
  }

  drawMessages(w, h, k) {
    let y = h * 0.2;
    for (const m of this.messages) {
      gfx.alpha(clamp(m.t, 0, 1));
      const tw = gfx.textWidth(m.text, 18 * k, "bold") + 28 * k;
      gfx.color("#000000A0"); gfx.rect((w - tw) / 2, y - 4 * k, tw, 30 * k, 8 * k);
      shadowText(m.text, 0, y, 18 * k, "#FFFFFF", "center", w);
      gfx.unalpha();
      y += 36 * k;
    }
  }

  drawDebug(g, w, h, k) {
    const p = g.player, s = g.world.v.stats();
    const lines = [`BlockCraft  ${g.fps} fps  ${(sys.fps && sys.fps()) || ""}`];
    if (this.debug) {
      const l = g.world.getLight(Math.floor(p.pos.x), Math.floor(p.eyeY), Math.floor(p.pos.z));
      lines.push(`XYZ ${p.pos.x.toFixed(1)} ${p.pos.y.toFixed(1)} ${p.pos.z.toFixed(1)}   ${TR("biome." + Math.max(0, g.world.biome(Math.floor(p.pos.x), Math.floor(p.pos.z))))}`);
      lines.push(`chunks ${s.visible}/${s.meshed}/${s.chunks}  quads ${s.quads}  draws ${s.drawCalls}  jobs ${s.pending}`);
      lines.push(`gen ${s.genMs.toFixed(1)} ms  mesh ${s.meshMs.toFixed(1)} ms  light ${l >> 4}/${l & 15}  entities ${g.entities.list.length}`);
      lines.push(`time ${((g.time % 1) * 24).toFixed(1)}h  ${g.weather.state}`);
    }
    gfx.color("#00000080");
    gfx.rect(6 * k, 6 * k, 520 * k, lines.length * 20 * k + 8 * k, 4 * k);
    lines.forEach((t, i) => { gfx.color("#FFFFFF"); gfx.text(t, 12 * k, 9 * k + i * 20 * k, 15 * k, "mono"); });
  }

  drawTouch(g, w, h, k, hx, hy, hbW, S) {
    const inp = this.app.input, b = [];
    const btn = (id, icon, x, y, s) => {
      b.push({ id, x, y, w: s, h: s });
      gfx.color(inp.btn(id) ? "#FFFFFF55" : "#00000055"); gfx.circle(x + s / 2, y + s / 2, s / 2);
      gfx.color("#FFFFFFAA"); gfx.circleLine(x + s / 2, y + s / 2, s / 2, 2 * k);
      gfx.icon(icon, x + s / 2, y + s / 2, s * 0.5, "#FFFFFF");
    };
    const s = 74 * k;
    btn("jump", "keyboard_double_arrow_up", w - s - 28 * k, h - s - 40 * k, s);
    btn("use", "pan_tool", w - s * 2 - 44 * k, h - s - 20 * k, s * 0.86);
    btn("sneak", "keyboard_double_arrow_down", w - s - 28 * k, h - s * 2 - 56 * k, s * 0.8);
    btn("inv", "backpack", hx + hbW + 12 * k, hy + 4 * k, S);
    btn("pause", "pause", w - 64 * k, 14 * k, 50 * k);
    inp.buttons = b;
    const t = inp.touch;
    if (t && t.id === "stick") {
      const r = Math.min(w, h) * 0.12;
      gfx.color("#00000050"); gfx.circle(t.x0, t.y0, r);
      gfx.color("#FFFFFF90"); gfx.circle(t.x0 + inp.stickVec[0] * r, t.y0 - inp.stickVec[1] * r, r * 0.4);
    } else {
      gfx.color("#FFFFFF30"); gfx.circleLine(w * 0.14, h * 0.7, Math.min(w, h) * 0.1, 2 * k);
    }
  }
}
