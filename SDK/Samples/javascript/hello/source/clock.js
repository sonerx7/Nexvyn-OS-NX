// Analog + digital clock drawn with gfx primitives. Angles are radians, 0 = pointing right, clockwise.
const TAU = Math.PI * 2;
let lastSec = -1;
let secStart = 0;

const pad2 = (v) => String(v).padStart(2, "0");

function hand(cx, cy, turns, len, back, width, color) {
  const a = turns * TAU - Math.PI / 2;
  const dx = Math.cos(a), dy = Math.sin(a);
  gfx.color(color);
  gfx.line(cx - dx * back, cy - dy * back, cx + dx * len, cy + dy * len, width);
}

export function drawClock(w, h) {
  const d = sys.date();
  const now = sys.time();
  if (d.sec !== lastSec) {
    lastSec = d.sec;
    secStart = now;
  }
  // the seconds hand moves to the new second with a short ease-out
  const t = Math.min(1, (now - secStart) * 5);
  const sec = d.sec - 1 + (1 - Math.pow(1 - t, 3));
  const min = d.min + d.sec / 60;
  const hour = (d.hour % 12) + min / 60;

  const r = Math.max(60, Math.min(w * 0.3, (h - 190) / 2));
  const cx = w / 2, cy = 62 + r;
  gfx.shadow(cx - r, cy - r, r * 2, r * 2, r, 18, 6);
  gfx.circle(cx, cy, r, theme.window);
  gfx.color(theme.separator);
  gfx.circleLine(cx, cy, r, 2);
  for (let i = 0; i < 60; i++) {
    const a = (i / 60) * TAU - Math.PI / 2;
    const major = i % 5 === 0;
    const r0 = r - (major ? 16 : 9), r1 = r - 6;
    gfx.color(major ? theme.text : theme.text3);
    gfx.line(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0, cx + Math.cos(a) * r1, cy + Math.sin(a) * r1, major ? 3 : 1);
  }
  gfx.color(theme.text);
  for (let n = 1; n <= 12; n++) {
    const a = (n / 12) * TAU - Math.PI / 2;
    const rr = r - 34;
    gfx.text(String(n), cx + Math.cos(a) * rr - 20, cy + Math.sin(a) * rr - 10, 16, "semibold", "center", 40);
  }
  hand(cx, cy, hour / 12, r * 0.5, 10, 6, theme.text);
  hand(cx, cy, min / 60, r * 0.74, 12, 4, theme.text);
  hand(cx, cy, sec / 60, r * 0.84, 18, 2, theme.red);
  gfx.circle(cx, cy, 6, theme.red);
  gfx.circle(cx, cy, 2.5, theme.window);

  gfx.color(theme.text);
  gfx.text(`${pad2(d.hour)}:${pad2(d.min)}:${pad2(d.sec)}`, 0, cy + r + 18, 28, "monobold", "center", w);
  gfx.color(theme.text2);
  const month = TR("date.months." + (d.month - 1));
  const day = TR("date.days." + d.wday);
  gfx.text(TR("date_fmt", d.day, month, d.year, day), 0, cy + r + 58, 14, "sans", "center", w);
}
