// BlockCraft for Nexvyn OS: a voxel sandbox game. The world (chunks, generation, light, meshes, saving) runs natively
// through g3d.voxels (SDK 1.7); the game itself - player, blocks, crafting, mobs, weather, menus - is JavaScript.
import { Input } from "./src/input.js";
import { Sound } from "./src/sound.js";
import { Hud } from "./src/hud.js";
import { InvUI } from "./src/invui.js";
import { Screens } from "./src/screens.js";
import { Game } from "./src/game.js";
import { clamp } from "./src/util.js";

import { normalizeSettings } from "./src/settings.js";

const DEFAULTS = {
  renderDistance: 6, fov: 75, sensitivity: 1, volume: 0.8, music: true, viewBobbing: true, waving: true, clouds: true,
  invertY: false, rumble: true, showFps: false, uiScale: 0, autoSprint: false,
};

const A = globalThis.__blockcraft = {
  settings: { ...DEFAULTS },
  game: null,
  state: "menu",   // menu | game
  w: 1280, h: 720,
};

A.uiScale = (w, h) => {
  const base = Math.min(w / 1280, h / 720);
  return clamp(base * (A.settings.uiScale || 1), 0.5, 3);
};
A.saveSettings = () => store.set("settings", A.settings);

// share of the script heap in use (0..1); 0 when the system does not say
A.memUse = () => {
  try { const m = sys.memory(); return m && m[1] > 0 ? m[0] / m[1] : 0; } catch (e) { return 0; }
};
A.startGame = (meta) => {
  if (A.noGpu || A.noVoxels) {
    ui.alert(TR("title"), TR(A.noGpu ? "ui.no_gpu" : "ui.no_voxels"), [TR("ui.ok")], () => {});
    return;
  }
  if (A.game) { A.game.dispose(); A.game = null; }
  if (A.memUse() > 0.85) { ui.alert(TR("title"), TR("msg.low_memory"), [TR("ui.ok")], () => {}); return; }
  try {
    A.game = new Game(A, meta);
  } catch (e) {
    console.log("world load failed: " + (e && e.stack || e));
    if (A.game) { try { A.game.dispose(); } catch (e2) { /* already gone */ } }
    A.game = null;
    A.state = "menu";
    A.screens.screen = "title";
    A.screens.stack = [];
    ui.alert(TR("title"), TR("msg.load_failed"), [TR("ui.ok")], () => {});
    return;
  }
  A.state = "game";
  A.screens.screen = "loading";
};
A.resume = () => { A.screens.screen = null; A.screens.stack = []; };
A.pause = () => {
  const g = A.game;
  if (!g || g.state === "loading") return;
  g.stopRumble();
  if (g.state === "screen") g.closeScreen();
  g.interaction.reset();
  A.screens.screen = "pause";
  A.screens.stack = [];
  A.screens.t = 0;
  A.screens.menu.focus = 0;
  A.screens.menu.usePad = true;
  g.save();
};
A.quitToTitle = () => {
  if (A.game) A.game.stopRumble();
  if (A.game) { A.game.save(); A.game.dispose(); A.game = null; }
  A.state = "menu";
  A.screens.screen = "title";
  A.screens.stack = [];
};

app.load = () => {
  const saved = store.get("settings", null);
  A.settings = normalizeSettings(saved, DEFAULTS);
  A.input = new Input();
  A.sound = new Sound(A.settings);
  A.hud = new Hud(A);
  A.invui = new InvUI(A);
  A.screens = new Screens(A);
  // Capability checks must not call the native world constructor during startup.
  A.noGpu = typeof g3d === "undefined" || typeof g3d.gpu !== "function" || !g3d.gpu();
  A.noVoxels = typeof g3d === "undefined" || typeof g3d.voxels !== "function";
};

app.update = (dt) => {
  dt = Math.min(dt, 0.05);
  const g = A.game;
  A.input.w = A.w; A.input.h = A.h;
  A.input.updateTouch();
  if (g) {
    const sc = A.screens.screen;
    if (g.state === "loading") {
      g.frame(dt);
      if (g.state !== "loading") A.resume();
    } else if (g.state === "dead") {
      if (sc !== "dead") { A.screens.screen = "dead"; A.screens.menu.focus = 0; }
      g.frame(dt);
    } else if (sc === "pause" || sc === "settings" || sc === "help") {
      // paused: the world does not move
      g.rumbleWatch(dt);
      g.updateEnv(0);
      g.updateCamera(0);
    } else {
      if (A.input.pausePressed()) A.pause();
      else if (A.input.helpPressed() && g.state === "playing") { A.pause(); A.screens.go("help"); }
      else g.frame(dt);
    }
  }
  A.input.endFrame();
};

app.draw = (w, h) => {
  A.w = w; A.h = h;
  const dt = 1 / 60;
  if (A.noGpu || A.noVoxels) {
    gfx.clear("#101418");
    gfx.color("#FFFFFF");
    gfx.wrap(TR(A.noGpu ? "ui.no_gpu" : "ui.no_voxels"), 40, h / 2 - 40, w - 80, 20, "semibold", "center");
    return;
  }
  const g = A.game;
  if (g && g.state !== "loading") {
    gfx.clear("#000000");
    g.renderer.draw(w, h);
    if (g.state === "screen") A.invui.draw(w, h, dt);
    else A.hud.draw(g, w, h, dt);
  } else if (!A.screens.screen) {
    gfx.clear("#000000");
  }
  if (A.screens.screen && !(g && g.state === "screen")) A.screens.draw(w, h, dt);
};

app.event = (e) => {
  // the inventory screen takes finger input itself (tap, drag, hold, swipe)
  if (A.invui && A.invui.isOpen && (e.type === "mousedown" || e.type === "mousemove" || e.type === "mouseup") && A.invui.pointer(e)) {
    if (A.input) A.input.touchMode = true;
    return;
  }
  if (A.input) A.input.event(e);
};

app.suspend = () => {
  if (A.game) A.game.stopRumble();
  if (A.game && A.game.state !== "loading") A.pause();
};
app.autosave = () => { if (A.game && A.game.state !== "loading") A.game.save(); };
app.unsaved = () => false;
app.close = () => {
  try { sys.vibrate(0, 0); } catch (e) { /* no rumble */ }
  if (A.game) { A.game.save(); A.game.dispose(); A.game = null; }
  return true;
};
