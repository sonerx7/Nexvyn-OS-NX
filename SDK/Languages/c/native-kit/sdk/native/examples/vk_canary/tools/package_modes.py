#!/usr/bin/env python3
"""Build and package vk_canary in window and/or fullscreen mode without mutating source files."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


EXAMPLE_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = EXAMPLE_DIR.parents[3]


def package_mode(mode, out_path, sysroot, shims, glslang, spirv_val):
    manifest_name = "app.json" if mode == "window" else "app.fullscreen.json"
    manifest_src = EXAMPLE_DIR / manifest_name
    if not manifest_src.is_file():
        raise FileNotFoundError(f"Manifest not found: {manifest_src}")

    env = dict(os.environ)
    env["NEXVYN_VK_SHIMS"] = "1" if shims else "0"
    if sysroot:
        env["NEXVYN_SYSROOT"] = str(Path(sysroot).resolve())
    if glslang:
        env["NEXVYN_GLSLANG"] = str(Path(glslang).resolve())
    if spirv_val:
        env["NEXVYN_SPIRV_VAL"] = str(Path(spirv_val).resolve())

    cli = [sys.executable, str(REPO_ROOT / "tools" / "nxv_native")]
    with tempfile.TemporaryDirectory(prefix=f"vk-canary-{mode}-") as tmp:
        stage = Path(tmp) / "vk_canary"
        shutil.copytree(
            EXAMPLE_DIR,
            stage,
            ignore=shutil.ignore_patterns("build", "__pycache__", "*.pyc"),
        )
        shutil.copy2(manifest_src, stage / "app.json")
        build_cmd = [*cli, "build", str(stage)]
        if sysroot:
            build_cmd += ["--sysroot", str(Path(sysroot).resolve())]
        subprocess.run(build_cmd, env=env, check=True)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([*cli, "package", str(stage), "-o", str(out_path.resolve())], env=env, check=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("window", "fullscreen", "both"), default="both")
    parser.add_argument("--out-dir", type=Path, default=REPO_ROOT / "build" / "vk_canary")
    parser.add_argument("--sysroot", default=os.environ.get("NEXVYN_SYSROOT", ""))
    parser.add_argument("--shims", type=int, choices=(0, 1), default=1)
    parser.add_argument("--glslang", default=os.environ.get("NEXVYN_GLSLANG", ""))
    parser.add_argument("--spirv-val", default=os.environ.get("NEXVYN_SPIRV_VAL", ""))
    args = parser.parse_args(argv)

    modes = ("window", "fullscreen") if args.mode == "both" else (args.mode,)
    for mode in modes:
        name = "vk_canary.nxvapp" if mode == "window" else "vk_canary_fullscreen.nxvapp"
        package_mode(mode, args.out_dir / name, args.sysroot, bool(args.shims), args.glslang, args.spirv_val)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
