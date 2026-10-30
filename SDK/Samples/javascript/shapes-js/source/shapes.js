// The seven g3d primitives with the arguments this demo uses. Imported by main.js (ES modules work inside a bundle).
// Every primitive comes with texture coordinates, so mesh.setTexture(path) works on all of them.
export const KINDS = [
  { kind: "cube", args: [1.1], color: "#FF6B6B", nameKey: "cube" },                 // size
  { kind: "box", args: [1.5, 0.7, 0.9], color: "#FFB84D", nameKey: "box" },         // width, height, depth
  { kind: "sphere", args: [0.72, 32, 20], color: "#FFE66D", nameKey: "sphere" },    // radius, segments, rings
  { kind: "cylinder", args: [0.5, 1.3, 32], color: "#6BCB77", nameKey: "cylinder" }, // radius, height, segments
  { kind: "cone", args: [0.62, 1.3, 32], color: "#4D96FF", nameKey: "cone" },       // radius, height, segments
  { kind: "torus", args: [0.56, 0.2, 48, 16], color: "#9B72FF", nameKey: "torus" }, // R, r, segments, sides
  { kind: "plane", args: [1.4, 1.4, 4], color: "#FF7AC6", nameKey: "plane" },       // width, depth, divisions
];

// the source line for one shape, shown in the info bar
export function codeFor(k) {
  return `g3d.mesh("${k.kind}", ${k.args.join(", ")})`;
}
