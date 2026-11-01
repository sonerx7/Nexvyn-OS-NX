// Sound effects and music: synthesized sounds rendered to Ogg files (tools/render_sounds.mjs, the Puffcap's from
// tools/blockcraft_assets.py). Positional sounds fade with distance (full within 2 blocks, silent at 24).
const NEAR = 2, FAR = 24;
const RANGE = { explode: 3, thunder: 8, fuse: 1.2, lava: 0.7, fire: 0.7 };

export class Sound {
  constructor(settings) {
    this.settings = settings;
    this.lx = 0; this.ly = 0; this.lz = 0;
    this.recent = new Map();
    this.musicTimer = 25;
    this.music = 0;
    this.rainChannel = -1;
  }

  setListener(x, y, z) { this.lx = x; this.ly = y; this.lz = z; }

  play(name, opts) {
    const vol0 = this.settings.volume;
    if (!(vol0 > 0)) return;
    let v = opts && opts.volume !== undefined ? opts.volume : 1;
    if (opts && opts.x !== undefined) {
      const d = Math.hypot(opts.x - this.lx, opts.y - this.ly, opts.z - this.lz);
      const far = FAR * (RANGE[name] || 1);
      if (d >= far) return;
      if (d > NEAR) v *= 1 - (d - NEAR) / (far - NEAR);
    }
    v *= vol0;
    if (v < 0.02) return;
    const now = sys.time();
    const last = this.recent.get(name) || 0;
    if (now - last < 0.045) return;  // the same sound twice in one frame: once is enough
    this.recent.set(name, now);
    try { audio.play(`bundle:/sounds/${name.replace(":", "_")}.ogg`, Math.min(1, v)); } catch (e) { /* missing file */ }
  }

  // background music: a phrase of generative piano every 1-3 minutes
  update(dt, playing) {
    if (!this.settings.music || !playing) return;
    this.musicTimer -= dt;
    if (this.musicTimer <= 0) {
      this.musicTimer = 60 + Math.random() * 120;
      try { audio.music(`bundle:/sounds/music_${this.music % 3}.ogg`); } catch (e) { /* ignore */ }
      this.music++;
    }
  }

  stopMusic() { try { audio.musicStop(); } catch (e) { /* ignore */ } this.musicTimer = 25; }

  rain(on) {
    if (on && this.rainChannel < 0 && this.settings.volume > 0) {
      try { this.rainChannel = audio.play("bundle:/sounds/rain.ogg", 0.35 * this.settings.volume, -1); } catch (e) { this.rainChannel = -1; }
    } else if (!on && this.rainChannel >= 0) {
      try { audio.stop(this.rainChannel); } catch (e) { /* ignore */ }
      this.rainChannel = -1;
    }
  }
}
