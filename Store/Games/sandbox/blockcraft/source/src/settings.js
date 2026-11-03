// Persisted settings are untrusted input: never forward NaN/Infinity or arbitrary radii to native streaming.
export function normalizeSettings(saved, defaults) {
  const result = { ...defaults };
  if (!saved || typeof saved !== "object" || Array.isArray(saved)) return result;
  const limits = { renderDistance: [3, 8], fov: [50, 110], sensitivity: [0.1, 3], volume: [0, 1], uiScale: [0, 3] };
  for (const key of Object.keys(defaults)) {
    const v = saved[key];
    if (limits[key]) {
      if (typeof v === "number" && Number.isFinite(v)) {
        result[key] = Math.max(limits[key][0], Math.min(limits[key][1], v));
        if (key === "renderDistance") result[key] = Math.round(result[key]);
      }
    } else if (typeof v === "boolean") result[key] = v;
  }
  return result;
}
