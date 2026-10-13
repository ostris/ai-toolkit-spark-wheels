"""Build the full RTX Spark (Windows on ARM, CUDA 13.4) wheel set.

    python build.py all                  # everything, dependency order
    python build.py torch triton         # specific components
    python build.py --plan               # show what would run
    python build.py --prepare-only torch # clone/checkout/patch, no compile
    python build.py doctor               # toolchain checks

Layout: all sources build inside <repo>/workspaces/ (gitignored), wheels land
in <repo>/dist/. Nothing is machine-specific; set SPARKW_ROOT to reuse an
existing workspace tree elsewhere.

Prerequisites (README): CUDA 13.4 preview toolkit + R616 driver installed
manually; VS2022 BuildTools(ARM64), cuDNN, APL, Rust, pkg-config-lite.

Stdlib only. Run with any native arm64 Python >= 3.10 (build.py provisions
the pinned build interpreter itself via uv).
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(HERE, "scripts")
PATCHES = os.path.join(HERE, "patches")
DIST = os.path.join(HERE, "dist")
WORKSPACES = os.environ.get("SPARKW_ROOT") or os.path.join(HERE, "workspaces")

FFMPEG_URL = ("https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/"
              "ffmpeg-n8.1-latest-winarm64-lgpl-shared-8.1.zip")
NLOHMANN_URL = ("https://github.com/nlohmann/json/releases/download/v3.11.3/"
                "json.hpp")

# Build order: libuv before torch; torch before everything torch-linked.
ORDER = [
    "libuv", "torch", "torchvision", "torchaudio", "torchcodec",
    "flash-attn", "natten",
    "triton-llvm", "triton",
    "llvmlite", "numba",
    "bitsandbytes", "opencv-python", "small-wheels", "kornia-rs",
]

HELPERS = {
    "libuv": {"script": "build_libuv.bat"},
    "triton-llvm": {"script": "build_triton_llvm.bat"},
}


def load_pins():
    with open(os.path.join(HERE, "pins.json")) as f:
        return json.load(f)


def run(cmd, **kw):
    print("+ %s" % (cmd if isinstance(cmd, str) else " ".join(cmd)))
    subprocess.run(cmd, check=True, **kw)


def build_env(pins):
    env = os.environ.copy()
    env["SPARKW_ROOT"] = WORKSPACES
    env["SPARKW_WHEELS"] = DIST
    # keep TMP short-ish: CUTLASS/opencv object paths overflow MAX_PATH fast
    env["SPARKW_TMP"] = env.get("SPARKW_TMP", os.path.join(WORKSPACES, "t"))
    env["SPARKW_PYHOME"] = os.path.join(
        WORKSPACES, "python", pins["python"])
    return env


def download(url, dest):
    if os.path.exists(dest):
        return
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    print("downloading %s" % url)
    try:
        urllib.request.urlretrieve(url, dest + ".part")
        os.replace(dest + ".part", dest)
    except Exception:
        # fresh Windows machines can miss intermediate CAs; curl (schannel)
        # fetches them on demand
        run(["curl", "-fsSL", "--retry", "3", "-o", dest, url])


def ensure_buildenv(pins, env):
    """Pinned arm64 python (uv) + the shared build venv + shared downloads."""
    os.makedirs(WORKSPACES, exist_ok=True)
    pyhome = env["SPARKW_PYHOME"]
    python = os.path.join(pyhome, "python.exe")
    if not os.path.isfile(python):
        uv = shutil.which("uv")
        if not uv:
            sys.exit("uv is required to provision the build python "
                     "(https://docs.astral.sh/uv/)")
        e = env.copy()
        e["UV_PYTHON_INSTALL_DIR"] = os.path.join(WORKSPACES, "python")
        run([uv, "python", "install", pins["python"]], env=e)
        # uv places it under a versioned dir name; normalize via junction-free
        # search
        for name in os.listdir(os.path.join(WORKSPACES, "python")):
            cand = os.path.join(WORKSPACES, "python", name, "python.exe")
            if os.path.isfile(cand) and not os.path.isfile(python):
                os.makedirs(os.path.dirname(pyhome), exist_ok=True)
                if name != os.path.basename(pyhome):
                    shutil.copytree(
                        os.path.join(WORKSPACES, "python", name), pyhome,
                        dirs_exist_ok=True)
    # shared build venv lives inside the pytorch workspace (scripts expect it)
    venv = os.path.join(WORKSPACES, "pytorch", ".venv-arm")
    vpython = os.path.join(venv, "Scripts", "python.exe")
    if not os.path.isfile(vpython):
        os.makedirs(os.path.join(WORKSPACES, "pytorch"), exist_ok=True)
        run([python, "-m", "venv", venv])
    # Always (re)install: idempotent, and heals a venv whose bootstrap died
    # part-way. Go through python -m pip: pip.exe refuses to upgrade itself
    # on Windows. The torch build runs --no-isolation, so everything in its
    # requirements-build.txt must be here (six: NNPACK -> PeachPy -> six).
    pip = [vpython, "-m", "pip"]
    run(pip + ["install", "--quiet", "--upgrade", "pip"])
    run(pip + ["install", "--quiet", "build", "wheel", "setuptools",
               "cmake", "ninja", "pybind11", "numpy", "pyyaml",
               "typing-extensions", "maturin", "scikit_build_core",
               "setuptools-scm", "nanobind", "psutil", "einops",
               "six", "packaging", "requests", "spin"])
    # shared third-party downloads
    ffdir = os.path.join(
        WORKSPACES, "ffmpeg-n8.1-latest-winarm64-lgpl-shared-8.1")
    if not os.path.isdir(ffdir):
        zip_path = os.path.join(WORKSPACES, "ffmpeg.zip")
        download(FFMPEG_URL, zip_path)
        import zipfile
        with zipfile.ZipFile(zip_path) as z:
            z.extractall(WORKSPACES)
        os.remove(zip_path)
    download(NLOHMANN_URL,
             os.path.join(WORKSPACES, "json-nlohmann", "include", "nlohmann",
                          "json.hpp"))


def prepare_source(name, comp, env):
    """Clone/fetch at the pinned ref (or sdist) and apply patches."""
    ws_name = comp.get("workspace")
    ws = os.path.join(WORKSPACES, ws_name) if ws_name else None
    if comp.get("repo") and ws:
        if not os.path.isdir(os.path.join(ws, ".git")):
            run(["git", "init", ws])
            run(["git", "-C", ws, "remote", "add", "origin", comp["repo"]])
            run(["git", "-C", ws, "config", "core.longpaths", "true"])
        # Fetch the pinned SHA directly when one is set: a PR ref such as
        # refs/pull/N/head moves on force-push, and a depth-1 fetch of it
        # would no longer contain the pin. GitHub serves any existing SHA.
        run(["git", "-C", ws, "fetch", "--depth", "1", "origin",
             comp.get("pin") or comp["ref"]])
        run(["git", "-C", ws, "checkout", "-f", "FETCH_HEAD"])
        run(["git", "-C", ws, "submodule", "update", "--init", "--recursive",
             "--depth", "1"])
    elif comp.get("sdist") and ws and not os.path.isdir(ws):
        pip = os.path.join(WORKSPACES, "pytorch", ".venv-arm", "Scripts",
                           "pip.exe")
        dl = os.path.join(WORKSPACES, "_sdists")
        run([pip, "download", "--no-deps", "--no-binary", ":all:",
             comp["sdist"], "-d", dl])
        import tarfile
        for f in os.listdir(dl):
            if f.endswith(".tar.gz"):
                with tarfile.open(os.path.join(dl, f)) as t:
                    t.extractall(WORKSPACES)
    for rel in comp.get("patches", []):
        run(["git", "-C", ws or HERE, "apply", "--verbose",
             os.path.join(PATCHES, rel)])
    if name == "kornia-rs" and ws and os.path.isdir(ws):
        cargo = os.path.expanduser(r"~\.cargo\bin\cargo.exe")
        run([cargo, "update", "-p", "generator"], cwd=ws)


def build_component(name, comp, env, prepare_only=False):
    print("=" * 60)
    print("## %s" % name)
    if comp.get("workspace") or comp.get("repo"):
        prepare_source(name, comp, env)
    if prepare_only:
        return
    run(["cmd", "/c", os.path.join(SCRIPTS, comp["script"])], env=env)


def doctor():
    checks = [
        ("CUDA 13.4 toolkit (MANUAL install)",
         r"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4\bin\nvcc.exe"),
        ("cuDNN 9.x arm64", r"C:\Program Files\NVIDIA\CUDNN"),
        ("Arm Performance Libraries",
         r"C:\Program Files\Arm Performance Libraries"),
        ("VS2022 BuildTools ARM64",
         r"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
         r"\VC\Auxiliary\Build\vcvarsarm64.bat"),
        ("Rust (cargo)", os.path.expanduser(r"~\.cargo\bin\cargo.exe")),
    ]
    bad = 0
    for label, path in checks:
        present = os.path.exists(path)
        print("[%s] %s" % ("OK  " if present else "MISS", label))
        bad += 0 if present else 1
    if not shutil.which("uv"):
        print("[MISS] uv (needed to provision the build python)")
        bad += 1
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("components", nargs="*", default=[])
    ap.add_argument("--plan", action="store_true")
    ap.add_argument("--prepare-only", action="store_true")
    args = ap.parse_args()

    if args.components == ["doctor"]:
        sys.exit(1 if doctor() else 0)

    pins = load_pins()
    comps = dict(HELPERS)
    comps.update(pins["components"])

    wanted = ORDER if (not args.components or args.components == ["all"]) \
        else args.components
    for name in wanted:
        if name not in comps:
            sys.exit("unknown component: %s (known: %s)"
                     % (name, ", ".join(ORDER)))

    if args.plan:
        for name in wanted:
            comp = comps[name]
            print("%-14s -> %s%s" % (
                name, comp.get("script", "?"),
                "  [patches: %s]" % ", ".join(comp["patches"])
                if comp.get("patches") else ""))
        return

    env = build_env(pins)
    os.makedirs(DIST, exist_ok=True)
    ensure_buildenv(pins, env)
    for name in wanted:
        build_component(name, comps[name], env,
                        prepare_only=args.prepare_only)
    print("wheels in %s:" % DIST)
    for f in sorted(os.listdir(DIST)):
        if f.endswith(".whl"):
            print("  " + f)


if __name__ == "__main__":
    main()
