// Weather: clear / rain / thunder cycles, snow in cold biomes, none in deserts, lightning that starts fires and
// rain that puts them out.
import { B } from "./registry.js";
import { rand } from "./util.js";

const DESERT = 4, TAIGA = 5, PEAKS = 6;

export class Weather {
  constructor(game, saved) {
    this.game = game;
    this.state = (saved && saved.state) || "clear";
    this.timer = saved && saved.timer !== undefined ? saved.timer : rand(500, 1500);
    this.rain = this.state === "clear" ? 0 : 1;
    this.thunder = this.state === "thunder" ? 1 : 0;
    this.flash = 0;
    this.nextBolt = rand(6, 20);
    this.pending = [];
    this.bolts = [];
  }

  get raining() { return this.rain > 0.2; }

  set(state, duration) {
    this.state = state;
    this.timer = duration ?? (state === "clear" ? rand(600, 2400) : rand(180, 600));
    this.game.hud.message(TR(state === "clear" ? "msg.weather_clear" : state === "rain" ? "msg.weather_rain" : "msg.weather_storm"));
  }

  precipitationAt(x, z) {
    const g = this.game;
    if (g.meta.type !== "normal") return "rain";
    const b = g.world.biome(Math.floor(x), Math.floor(z));
    const biome = b >= 0 ? b : g.column(Math.floor(x), Math.floor(z)).biome;
    if (biome === DESERT) return "none";
    if (biome === TAIGA || biome === PEAKS) return "snow";
    return "rain";
  }

  isRainingAt(x, y, z) {
    if (!this.raining || this.precipitationAt(x, z) !== "rain") return false;
    return this.game.world.topY(Math.floor(x), Math.floor(z)) < Math.floor(y);
  }

  update(dt) {
    const g = this.game;
    this.timer -= dt;
    if (this.timer <= 0) {
      if (this.state === "clear") this.set(Math.random() < 0.3 ? "thunder" : "rain");
      else this.set("clear");
    }
    const wantRain = this.state === "clear" ? 0 : 1, wantThunder = this.state === "thunder" ? 1 : 0;
    this.rain += (wantRain - this.rain) * Math.min(1, dt * 0.12);
    this.thunder += (wantThunder - this.thunder) * Math.min(1, dt * 0.12);
    if (this.rain < 0.002) this.rain = 0;
    g.world.updater.raining = this.raining;
    this.flash = Math.max(0, this.flash - dt * 3.5);
    for (let i = this.bolts.length - 1; i >= 0; i--) { this.bolts[i].t -= dt; if (this.bolts[i].t <= 0) this.bolts.splice(i, 1); }
    if (this.thunder > 0.6) {
      this.nextBolt -= dt;
      if (this.nextBolt <= 0) { this.nextBolt = rand(5, 25); this.strikeNear(); }
    }
    for (let i = this.pending.length - 1; i >= 0; i--) {
      const s = this.pending[i];
      s.t -= dt;
      if (s.t <= 0) { g.sound.play("thunder", { volume: s.volume }); this.pending.splice(i, 1); }
    }
    const p = g.player;
    const here = this.precipitationAt(p.pos.x, p.pos.z);
    g.sound.rain(here === "rain" && this.rain > 0.3);
  }

  strikeNear() {
    const g = this.game, p = g.player, w = g.world;
    const a = Math.random() * Math.PI * 2, r = rand(8, 90);
    const x = Math.floor(p.pos.x + Math.cos(a) * r), z = Math.floor(p.pos.z + Math.sin(a) * r);
    if (!w.isLoaded(x, z) || this.precipitationAt(x, z) !== "rain") return;
    this.strike(x, w.topY(x, z) + 1, z);
  }

  strike(x, y, z) {
    const g = this.game, w = g.world, p = g.player;
    this.flash = 1;
    this.bolts.push({ x: x + 0.5, y, z: z + 0.5, t: 0.35, seed: Math.random() * 1000 });
    const d = Math.hypot(p.pos.x - x, p.pos.y - y, p.pos.z - z);
    this.pending.push({ t: d / 340, volume: Math.max(0.35, 1 - d / 160) });
    if (w.getBlock(x, y, z) === B.air && w.updater.fireCanSurvive(x, y, z)) w.setBlock(x, y, z, B.fire);
    for (const e of g.entities.list) {
      if (e.dead || !e.hurt) continue;
      if (Math.hypot(e.pos.x - x, e.pos.z - z) < 3 && Math.abs(e.pos.y - y) < 4) { e.hurt(5, { x, y, z }, 0.5, "lightning"); if (e.fireTime !== undefined) e.fireTime = Math.max(e.fireTime, 8); }
    }
    if (!p.dead && Math.hypot(p.pos.x - x, p.pos.z - z) < 3 && Math.abs(p.pos.y - y) < 4) {
      p.damage(5, "lightning", null, true);
      if (!p.creative) p.fireTime = Math.max(p.fireTime, 8);
    }
  }

  toJSON() { return { state: this.state, timer: this.timer }; }
}
