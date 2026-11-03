// Persisted settings are untrusted input: never forward NaN/Infinity or arbitrary radii to native streaming.
export function normalizeSettings(saved, defaults) {
  const result = { ...defaults };
  if (!saved || typeof saved !== "object" || Array.isArray(saved)) return result;
  const limits = { renderDistance: [3, 8], graphics: [0, 2], fov: [50, 110], sensitivity: [0.1, 3], volume: [0, 1], uiScale: [0, 3] };
  for (const key of Object.keys(defaults)) {
    const v = saved[key];
    if (limits[key]) {
      if (typeof v === "number" && Number.isFinite(v)) {
        result[key] = Math.max(limits[key][0], Math.min(limits[key][1], v));
        if (key === "renderDistance" || key === "graphics") result[key] = Math.round(result[key]);
      }
    } else if (typeof v === "boolean") result[key] = v;
  }
  // Existing installations predate graphics profiles. Migrate once to the
  // balanced budget; a subsequently selected custom profile remains intact.
  if ('graphics' in defaults && typeof saved.graphics !== 'number') {
    result.graphics=1;result.renderDistance=Math.min(result.renderDistance,4);result.clouds=false;
  }
  return result;
}
