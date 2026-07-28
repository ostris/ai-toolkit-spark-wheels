"""Remove MSVC debug artifacts (.pdb/.ilk/.exp) from a wheel.

Usage: strip_debug_from_wheel.py <wheel_path>

The TritonRelBuildWithAsserts config writes PDB/ILK next to the binaries and
setup.py's package glob packs them — ~8 GB uncompressed of debug data nobody
needs at runtime.
"""
import os
import shutil
import subprocess
import sys

STRIP_EXT = (".pdb", ".ilk", ".exp")


def main():
    whl = os.path.abspath(sys.argv[1])
    wheel_dir = os.path.dirname(whl)
    work = os.path.join(wheel_dir, "_strip")
    shutil.rmtree(work, ignore_errors=True)
    subprocess.run([sys.executable, "-m", "wheel", "unpack", whl, "-d", work],
                   check=True)
    root = os.path.join(work, os.listdir(work)[0])
    removed = 0
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            if name.lower().endswith(STRIP_EXT):
                path = os.path.join(dirpath, name)
                removed += os.path.getsize(path)
                os.remove(path)
    subprocess.run([sys.executable, "-m", "wheel", "pack", root,
                    "-d", wheel_dir], check=True)
    shutil.rmtree(work, ignore_errors=True)
    print("stripped %.1f MB of debug artifacts from %s"
          % (removed / 1e6, os.path.basename(whl)))


if __name__ == "__main__":
    main()
