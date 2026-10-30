// level.js: Water Sort rules, a seeded level generator and a depth-first solver.
// A tube is an array of colour indices from bottom to top; capacity CAP.
// The solver is a generator function: it yields every few hundred nodes so the caller can spread the search over
// frames (the runtime stops a callback after 3 seconds), and finally returns the move list or null.

export const CAP = 4;

export function mulberry(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function colorsFor(level) {
  return Math.min(12, 3 + Math.floor((level - 1) / 2));
}

export function topRun(t) {
  if (t.length === 0) return 0;
  const c = t[t.length - 1];
  let n = 0;
  for (let i = t.length - 1; i >= 0 && t[i] === c; i--) n++;
  return n;
}

export function isComplete(t) {
  return t.length === CAP && topRun(t) === CAP;
}

export function canPour(tubes, a, b) {
  if (a === b) return false;
  const A = tubes[a], Bt = tubes[b];
  if (A.length === 0 || Bt.length >= CAP) return false;
  if (Bt.length > 0 && Bt[Bt.length - 1] !== A[A.length - 1]) return false;
  return true;
}

// pours and returns the number of layers moved
export function pour(tubes, a, b) {
  const A = tubes[a], Bt = tubes[b];
  const n = Math.min(topRun(A), CAP - Bt.length);
  for (let k = 0; k < n; k++) Bt.push(A.pop());
  return n;
}

export function solved(tubes) {
  return tubes.every((t) => t.length === 0 || isComplete(t));
}

function key(tubes) {
  return tubes.map((t) => t.join(",")).sort().join("|");
}

// Depth-first search for a solution. Yields periodically; returns [[from, to], ...] or null (unsolvable / budget).
export function* solve(start, budget = 120000) {
  const tubes = start.map((t) => t.slice());
  const seen = new Set();
  const path = [];
  let nodes = 0;
  function moves() {
    const list = [];
    for (let a = 0; a < tubes.length; a++) {
      const A = tubes[a];
      if (A.length === 0 || isComplete(A)) continue;
      const run = topRun(A);
      for (let b = 0; b < tubes.length; b++) {
        if (!canPour(tubes, a, b)) continue;
        const Bt = tubes[b];
        if (Bt.length === 0 && run === A.length) continue; // moving a uniform tube into an empty one is pointless
        // prefer pours that stack onto the same colour and moves that empty or finish tubes
        let score = Bt.length === 0 ? 0 : 2;
        if (Math.min(run, CAP - Bt.length) === run) score += 1;
        list.push([score, a, b]);
      }
    }
    list.sort((x, y) => y[0] - x[0]);
    return list;
  }
  // iterative DFS with an explicit stack of move lists
  const stack = [{ list: moves(), i: 0, undo: null }];
  seen.add(key(tubes));
  while (stack.length > 0) {
    if (solved(tubes)) return path.slice();
    if (++nodes > budget) return null;
    if (nodes % 300 === 0) yield nodes;
    const top = stack[stack.length - 1];
    if (top.i >= top.list.length) {
      stack.pop();
      if (top.undo) {
        const [a, b, n] = top.undo;
        for (let k = 0; k < n; k++) tubes[a].push(tubes[b].pop());
        path.pop();
      }
      continue;
    }
    const [, a, b] = top.list[top.i++];
    const n = pour(tubes, a, b);
    const k = key(tubes);
    if (seen.has(k)) {
      for (let q = 0; q < n; q++) tubes[a].push(tubes[b].pop());
      continue;
    }
    seen.add(k);
    path.push([a, b]);
    stack.push({ list: moves(), i: 0, undo: [a, b, n] });
  }
  return solved(tubes) ? path.slice() : null;
}

// Generator of a solvable level: yields while searching, returns the tubes.
export function* generate(level) {
  const colors = colorsFor(level);
  const rnd = mulberry(level * 2654435761 + 97);
  for (let attempt = 0; attempt < 40; attempt++) {
    const layers = [];
    for (let c = 0; c < colors; c++) for (let k = 0; k < CAP; k++) layers.push(c);
    for (let i = layers.length - 1; i > 0; i--) {
      const j = Math.floor(rnd() * (i + 1));
      [layers[i], layers[j]] = [layers[j], layers[i]];
    }
    const tubes = [];
    for (let t = 0; t < colors; t++) tubes.push(layers.slice(t * CAP, t * CAP + CAP));
    tubes.push([], []);
    // never start (partly) solved
    if (tubes.some((t) => isComplete(t))) continue;
    const it = solve(tubes, 80000);
    let r = it.next();
    while (!r.done) {
      yield r.value;
      r = it.next();
    }
    if (r.value) return tubes;
  }
  // fallback: a simple valid start (always solvable)
  const tubes = [];
  for (let t = 0; t < colors; t++) tubes.push([t, (t + 1) % colors, t, (t + 1) % colors]);
  tubes.push([], []);
  return tubes;
}
