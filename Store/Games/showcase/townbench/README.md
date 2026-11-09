# Village Bench

[Türkçe](README.tr.md)

A benchmark for Nexvyn OS. It flies a fixed 60 second camera path over a fully textured 3D village and shows the average, minimum and 1% low frame times, the frame rate and a score.

- Three quality presets: Low (render scale 60%, no shadows, no anti-aliasing), Medium (80%, sun shadows, anti-aliasing), High (100%, sun shadows, anti-aliasing).
- The same path every run, so results can be compared. The frame rate is not capped and there is no sound.
- Score = (0.7 x average fps + 0.3 x 1% low fps) x 10 x preset weight (1.0, 1.6, 2.4). The first second of each run is not counted.
- The best score of each preset is kept on the device (`best.txt`); the last result is also written to `townbench_result.json` in the app's data folder.
- Opens in a window; maximize it for full screen. Controls: Up / Down choose, A start, B quit (B during a run aborts it).
- Scene: a medieval village made with our own scripts; ground and wall materials are CC0 photo bases (ambientCG). No sound, no network, permission `files` only.

Package: `com.nexvyn.demo.townbench.nxvapp` (about 43 MB). Open it in Nexvyn OS Files to install. Requires Nexvyn OS 1.2.2 (SDK 1.12).
