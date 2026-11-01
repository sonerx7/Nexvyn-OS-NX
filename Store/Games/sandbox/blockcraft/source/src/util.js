// Small math helpers shared by every module.
export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
export const lerp = (a, b, t) => a + (b - a) * t;
export const smooth = (e0, e1, x) => { const t = clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t); };
export const rand = (a, b) => a + Math.random() * (b - a);
export const randInt = n => (Math.random() * n) | 0;
export const angleDiff = (a, b) => { let d = (b - a) % (Math.PI * 2); if (d > Math.PI) d -= Math.PI * 2; if (d < -Math.PI) d += Math.PI * 2; return d; };
export const lerp3 = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
export const scale3 = (a, k) => [a[0] * k, a[1] * k, a[2] * k];
export const add3 = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const h2 = v => { const s = clamp(Math.round(v * 255), 0, 255).toString(16); return s.length < 2 ? "0" + s : s; };
export const hex3 = (c, a) => "#" + h2(c[0]) + h2(c[1]) + h2(c[2]) + (a === undefined ? "" : h2(a));

// Deterministic randomness (seeded, the same on every platform).
export function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
export function hash3(x, y, z, seed) {
  let h = (seed | 0) ^ Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263) ^ Math.imul(z | 0, 2147483647);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}
export const hash2 = (x, z, seed) => hash3(x, 0, z, seed);
export function seedFromString(s) {
  s = String(s).trim();
  if (s === "") return (Math.random() * 2 ** 31) | 0;
  if (/^-?\d+$/.test(s)) return Number(s) | 0;
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  return h;
}
