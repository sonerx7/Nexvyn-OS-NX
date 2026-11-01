// Controller-first input with keyboard, mouse and touch on top.
//   Controller: left stick move (click: sprint), right stick look (click: sneak), ZR break / attack, ZL use / place,
//   B jump (double tap in creative: fly), X inventory, Y drop, L / R hotbar, D-pad up camera, D-pad down drop,
//   D-pad left / right hotbar, + pause, - map of controls.
//   Keyboard: WASD move, arrows look, Space jump, Shift sneak, Ctrl sprint, E inventory, Q drop, 1-9 hotbar,
//   F5 / V camera, Esc pause, F3 debug, F1 hide HUD, T time of day (Creative). Mouse: left break, right click place, right drag look.
//   Touch: left third = move stick, drag elsewhere = look, tap = use, hold = break, on-screen buttons.
import { clamp } from "./util.js";

export class Input {
  constructor() {
    this.keys = new Set();
    this.keysPressed = new Set();
    this.mouse = { x: 0, y: 0, l: false, r: false, lPressed: false, rPressed: false, rDrag: 0, lookDx: 0, lookDy: 0 };
    this.wheel = 0;
    this.touch = null;        // { id: "stick"|"look"|button, x0, y0, x, y, t, moved }
    this.touchMode = false;
    this.stickVec = [0, 0];   // virtual stick
    this.touchLook = [0, 0];
    this.touchTap = false;    // short tap: use
    this.touchHold = false;   // long press: break
    this.buttons = [];        // on-screen touch buttons this frame [{id, x, y, w, h}]
    this.buttonPressed = new Set();
    this.buttonHeld = new Set();
    this.lastJump = -1;
    this.doubleJump = false;
    this.lastFwd = -1;
    this.doubleFwd = false;
    this.sneakToggle = false;
    this.sprintToggle = false;
    this.w = 1280; this.h = 720;
    this.padStamp = {};
  }
  echo(key) {
    const pad = key === "escape" ? "b" : key;
    const t = this.padStamp[pad];
    return t !== undefined && sys.time() - t < 0.15;
  }

  event(e) {
    switch (e.type) {
      case "keydown":
        if ((e.key === "escape" || e.key === "up" || e.key === "down" || e.key === "left" || e.key === "right") && this.echo(e.key)) break;
        if (!this.keys.has(e.key)) this.keysPressed.add(e.key);
        this.keys.add(e.key);
        this.touchMode = false;
        break;
      case "keyup": this.keys.delete(e.key); break;
      case "mousedown":
        if (e.touch) { this.touchDown(e); break; }
        this.touchMode = false;
        if (e.button === "right") { this.mouse.r = true; this.mouse.rDrag = 0; }
        else { this.mouse.l = true; this.mouse.lPressed = true; }
        this.mouse.x = e.x; this.mouse.y = e.y;
        break;
      case "mouseup":
        if (e.touch || this.touch) { this.touchUp(e); break; }
        if (e.button === "right") { if (this.mouse.r && this.mouse.rDrag < 6) this.mouse.rPressed = true; this.mouse.r = false; }
        else this.mouse.l = false;
        break;
      case "mousemove":
        if (this.touch) { this.touchMove(e); break; }
        if (this.mouse.r) {
          const dx = e.x - this.mouse.x, dy = e.y - this.mouse.y;
          this.mouse.lookDx += dx; this.mouse.lookDy += dy;
          this.mouse.rDrag += Math.abs(dx) + Math.abs(dy);
        }
        this.mouse.x = e.x; this.mouse.y = e.y;
        break;
      case "scroll": this.wheel += e.dy > 0 ? 1 : e.dy < 0 ? -1 : 0; break;
      case "paddown": this.padStamp[e.pad] = sys.time(); this.touchMode = false; break;
    }
  }

  // ---------- touch ----------
  buttonAt(x, y) { for (const b of this.buttons) if (x >= b.x && x < b.x + b.w && y >= b.y && y < b.y + b.h) return b.id; return null; }
  touchDown(e) {
    this.touchMode = true;
    const b = this.buttonAt(e.x, e.y);
    const now = sys.time();
    if (b) { this.touch = { id: b, x0: e.x, y0: e.y, x: e.x, y: e.y, t: now, moved: 0 }; this.buttonPressed.add(b); this.buttonHeld.add(b); return; }
    const stick = e.x < this.w * 0.33 && e.y > this.h * 0.35;
    this.touch = { id: stick ? "stick" : "look", x0: e.x, y0: e.y, x: e.x, y: e.y, t: now, moved: 0 };
  }
  touchMove(e) {
    const t = this.touch;
    if (!t) return;
    const dx = e.x - t.x, dy = e.y - t.y;
    t.moved += Math.abs(dx) + Math.abs(dy);
    t.x = e.x; t.y = e.y;
    if (t.id === "look") { this.touchLook[0] += dx; this.touchLook[1] += dy; }
  }
  touchUp() {
    const t = this.touch;
    if (t) {
      if (t.id === "look" && t.moved < 14 && sys.time() - t.t < 0.3) this.touchTap = true;
      this.buttonHeld.delete(t.id);
    }
    this.touch = null;
    this.stickVec = [0, 0];
    this.touchHold = false;
  }
  updateTouch() {
    const t = this.touch;
    if (!t) return;
    if (t.id === "stick") {
      const r = Math.min(this.w, this.h) * 0.12;
      this.stickVec = [clamp((t.x - t.x0) / r, -1, 1), clamp(-(t.y - t.y0) / r, -1, 1)];
    } else if (t.id === "look") {
      this.touchHold = t.moved < 18 && sys.time() - t.t > 0.35;
    }
  }

  // ---------- queries (call once per frame, then endFrame) ----------
  key(k) { return this.keys.has(k); }
  keyPressed(k) { return this.keysPressed.has(k); }
  pad(b) { return input.down(b); }
  padPressed(b) { return input.pressed(b); }
  btn(id) { return this.buttonHeld.has(id); }
  btnPressed(id) { return this.buttonPressed.has(id); }

  // [strafe, forward] in -1..1
  move() {
    const [lx, ly] = input.stick("left");
    let s = Math.abs(lx) > 0.15 ? lx : 0, f = Math.abs(ly) > 0.15 ? ly : 0;
    if (this.key("w")) f += 1;
    if (this.key("s")) f -= 1;
    if (this.key("d")) s += 1;
    if (this.key("a")) s -= 1;
    s += this.stickVec[0]; f += this.stickVec[1];
    return [clamp(s, -1, 1), clamp(f, -1, 1)];
  }
  // [dyaw, dpitch] radians for this frame
  look(dt, sens) {
    const [rx, ry] = input.stick("right");
    const k = 2.6 * sens * dt;
    const curve = v => (Math.abs(v) < 0.12 ? 0 : Math.sign(v) * Math.pow((Math.abs(v) - 0.12) / 0.88, 1.6));
    let dyaw = -curve(rx) * k * 1.15, dpitch = curve(ry) * k;
    const kb = 2.2 * sens * dt;
    if (this.key("left")) dyaw += kb;
    if (this.key("right")) dyaw -= kb;
    if (this.key("up")) dpitch += kb;
    if (this.key("down")) dpitch -= kb;
    const m = 0.0042 * sens;
    dyaw -= this.mouse.lookDx * m; dpitch -= this.mouse.lookDy * m;
    dyaw -= this.touchLook[0] * m * 1.4; dpitch -= this.touchLook[1] * m * 1.4;
    this.mouse.lookDx = this.mouse.lookDy = 0;
    this.touchLook[0] = this.touchLook[1] = 0;
    return [dyaw, dpitch];
  }
  jumpHeld() { return this.pad("b") || this.key("space") || this.btn("jump"); }
  jumpPressed() {
    const p = this.padPressed("b") || this.keyPressed("space") || this.btnPressed("jump");
    if (p) {
      const now = sys.time();
      this.doubleJump = now - this.lastJump < 0.3;
      this.lastJump = now;
    }
    return p;
  }
  sneakHeld() {
    if (this.padPressed("rstick") || this.btnPressed("sneak")) this.sneakToggle = !this.sneakToggle;
    return this.key("shift") || this.key("lshift") || this.sneakToggle;
  }
  sprintPressed() { return this.padPressed("lstick") || this.keyPressed("ctrl") || this.keyPressed("r") || this.btnPressed("sprint"); }
  breakHeld() { return this.pad("zr") || this.mouse.l || this.key("f") || this.touchHold; }
  breakPressed() { return this.padPressed("zr") || this.mouse.lPressed || this.keyPressed("f"); }
  useHeld() { return this.pad("zl") || this.pad("a") || this.key("g") || this.btn("use"); }
  usePressed() { return this.padPressed("zl") || this.padPressed("a") || this.mouse.rPressed || this.keyPressed("g") || this.touchTap || this.btnPressed("use"); }
  inventoryPressed() { return this.padPressed("x") || this.keyPressed("e") || this.btnPressed("inv"); }
  dropPressed() { return this.padPressed("y") || this.padPressed("down") || this.keyPressed("q"); }
  pausePressed() { return this.padPressed("plus") || this.keyPressed("escape") || this.btnPressed("pause"); }
  cameraPressed() { return this.padPressed("up") || this.keyPressed("f5") || this.keyPressed("v"); }
  helpPressed() { return this.padPressed("minus") || this.keyPressed("h"); }
  hotbarDelta() {
    let d = this.wheel;
    if (this.padPressed("r") || this.padPressed("right")) d += 1;
    if (this.padPressed("l") || this.padPressed("left")) d -= 1;
    this.wheel = 0;
    return d;
  }
  hotbarKey() { for (let i = 1; i <= 9; i++) if (this.keyPressed(String(i))) return i - 1; return -1; }

  endFrame() {
    this.keysPressed.clear();
    this.buttonPressed.clear();
    this.mouse.lPressed = this.mouse.rPressed = false;
    this.touchTap = false;
  }
}
