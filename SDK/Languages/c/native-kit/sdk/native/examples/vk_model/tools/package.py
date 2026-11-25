#!/usr/bin/env python3
"""Bake an FBX and build the vk_model package with it, without touching the source folder.

    python sdk/native/examples/vk_model/tools/package.py MODEL.fbx [-o build/vk_model/vk_model.nxvapp]

Steps: build the host bake tool (tools/vk_model_bake.c + lib/ufbx + lib/stb) with the host C compiler, copy the
example to a temporary stage, bake MODEL.fbx into <stage>/data/model.nxvmesh (geometry plus only the base textures
the materials use, as RGBA8 mip chains), build the windowed module with Vulkan shims and package it. The model never
enters the source tree.

Needs: NEXVYN_SYSROOT with the vulkan-headers recipe, NEXVYN_GLSLANG and NEXVYN_SPIRV_VAL (host shader tools),
NEXVYN_IMGUI_VULKAN_BACKENDS (the backends folder of Dear ImGui 1.91.5) and a host C compiler (gcc, cc or clang;
--host-cc overrides). Options can also be given as arguments.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

EXAMPLE_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = EXAMPLE_DIR.parents[3]


def find_host_cc(explicit):
    for name in ([explicit] if explicit else []) + ["gcc", "cc", "clang"]:
        found = shutil.which(name) if name else None
        if found:
            return found
    raise SystemExit("error: no host C compiler found (use --host-cc)")


def build_bake_tool(cc, out_dir):
    exe = out_dir / ("vk_model_bake" + (".exe" if os.name == "nt" else ""))
    cmd = [cc, "-O2", "-w", "-I", str(REPO_ROOT / "lib" / "ufbx"), "-I", str(REPO_ROOT / "lib" / "stb"),
           "-o", str(exe), str(EXAMPLE_DIR / "tools" / "vk_model_bake.c"), str(REPO_ROOT / "lib" / "ufbx" / "ufbx.c"),
           "-lm"]
    env = dict(os.environ)  # MSYS2 / MinGW compilers find their helper programs and DLLs through PATH
    env["PATH"] = str(Path(cc).parent) + os.pathsep + env.get("PATH", "")
    subprocess.run(cmd, check=True, env=env)
    return exe


def cmake_path(path):
    """The build runs CMake inside devkitPro's MSYS2 shell on Windows: C:/x becomes /c/x there."""
    p = Path(path).resolve().as_posix()
    if os.name == "nt" and len(p) > 2 and p[1] == ":":
        p = "/" + p[0].lower() + p[2:]
    return p


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("fbx", type=Path, help="the FBX model to bake into the package")
    parser.add_argument("-o", "--out", type=Path, default=REPO_ROOT / "build" / "vk_model" / "vk_model.nxvapp")
    parser.add_argument("--max-tex", type=int, default=512, help="largest texture side after baking (default 512)")
    parser.add_argument("--sysroot", default=os.environ.get("NEXVYN_SYSROOT", ""))
    parser.add_argument("--glslang", default=os.environ.get("NEXVYN_GLSLANG", ""))
    parser.add_argument("--spirv-val", default=os.environ.get("NEXVYN_SPIRV_VAL", ""))
    parser.add_argument("--imgui-backends", default=os.environ.get("NEXVYN_IMGUI_VULKAN_BACKENDS", ""))
    parser.add_argument("--host-cc", default=os.environ.get("NEXVYN_HOST_CC", ""))
    args = parser.parse_args(argv)

    fbx = args.fbx.resolve()
    if not fbx.is_file():
        raise SystemExit(f"error: model not found: {fbx}")
    for label, value in (("--sysroot", args.sysroot), ("--glslang", args.glslang), ("--spirv-val", args.spirv_val),
                         ("--imgui-backends", args.imgui_backends)):
        if not value or not Path(value).exists():
            raise SystemExit(f"error: {label} is missing or does not exist: {value!r}")

    env = dict(os.environ)
    env["NEXVYN_VK_SHIMS"] = "1"
    env["NEXVYN_SYSROOT"] = str(Path(args.sysroot).resolve())
    env["NEXVYN_GLSLANG"] = str(Path(args.glslang).resolve())
    env["NEXVYN_SPIRV_VAL"] = str(Path(args.spirv_val).resolve())
    env["NEXVYN_IMGUI_VULKAN_BACKENDS"] = cmake_path(args.imgui_backends)
    env.setdefault("NEXVYN_PYTHON", sys.executable)

    cli = [sys.executable, str(REPO_ROOT / "tools" / "nxv_native")]
    out = args.out.resolve()
    with tempfile.TemporaryDirectory(prefix="vk-model-") as tmp:
        tmp = Path(tmp)
        bake = build_bake_tool(find_host_cc(args.host_cc), tmp)
        stage = tmp / "vk_model"
        shutil.copytree(EXAMPLE_DIR, stage, ignore=shutil.ignore_patterns("build", "__pycache__", "*.pyc", "data"))
        (stage / "data").mkdir()
        subprocess.run([str(bake), str(fbx), str(stage / "data" / "model.nxvmesh"), "--max-tex", str(args.max_tex)],
                       check=True)
        subprocess.run([*cli, "build", str(stage), "--sysroot", env["NEXVYN_SYSROOT"]], env=env, check=True)
        out.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([*cli, "package", str(stage), "-o", str(out)], env=env, check=True)
    print(f"vk_model package: {out} ({out.stat().st_size // 1024} KiB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
