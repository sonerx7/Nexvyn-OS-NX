# Nexy Benchmark 2 changes

## 2.4.0

- Use the shared native OS frame, typography, scale, focus, touch scrolling and input backend.
- Keep Confirm/Cancel semantic, enable keyboard and gamepad widget navigation, and cancel input on focus loss or suspend.
- Add a real Stop Test button and touch-accessible camera Reset and Back actions.
- Capture scene gestures by stable contact ID; support two-contact pinch zoom without transferring a toolbar drag to the scene.
- Reflow page actions and use a scene dropdown in compact layouts. UI text supports eight locales.
- Use workload profile 2: fixed 904x508 3D targets (459,232 pixels, 50.17% below 1280x720), with unchanged 1280x720 2D targets.
- Scale Explore's prior pixel budget by 0.5 at every quality level; use a 720x720 shadow map instead of 1024x1024.
- Remove forced `glFinish` probes from Explore. Frame timing and supported asynchronous timer queries remain available.
- Preserve history and settings. Persist the workload identity and block score deltas between different profiles or render sizes.

These are workload and interaction changes, not a measured 50% frame-time or crash-freedom guarantee. Physical-device acceptance remains required.
