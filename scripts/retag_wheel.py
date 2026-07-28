"""Retag a wheel with a PEP 440 local version (e.g. 0.50.0 -> 0.50.0+cu134).

Usage: retag_wheel.py <wheel_dir> <dist_name> <version> <local_tag>

Why: our bitsandbytes build has the same version number as PyPI's CPU-only
win_arm64 wheel; the local tag makes resolvers prefer ours (locals sort
higher than the bare version).
"""
import os
import subprocess
import sys


def main():
    wheel_dir, dist, version, tag = sys.argv[1:5]
    src = os.path.join(
        wheel_dir, "%s-%s-cp312-cp312-win_arm64.whl" % (dist, version))
    if not os.path.isfile(src):
        matches = [f for f in os.listdir(wheel_dir)
                   if f.startswith("%s-%s-" % (dist, version)) and "+" not in f]
        if not matches:
            print("nothing to retag (already tagged?)")
            return
        src = os.path.join(wheel_dir, matches[0])
    work = os.path.join(wheel_dir, "_retag")
    subprocess.run([sys.executable, "-m", "wheel", "unpack", src, "-d", work],
                   check=True)
    root = os.path.join(work, "%s-%s" % (dist, version))
    di = os.path.join(root, "%s-%s.dist-info" % (dist, version))
    meta = os.path.join(di, "METADATA")
    with open(meta, encoding="utf-8") as f:
        s = f.read()
    s = s.replace("Version: %s" % version, "Version: %s+%s" % (version, tag), 1)
    with open(meta, "w", encoding="utf-8") as f:
        f.write(s)
    os.rename(di, os.path.join(root, "%s-%s+%s.dist-info" % (dist, version, tag)))
    newroot = os.path.join(work, "%s-%s+%s" % (dist, version, tag))
    os.rename(root, newroot)
    subprocess.run([sys.executable, "-m", "wheel", "pack", newroot,
                    "-d", wheel_dir], check=True)
    os.remove(src)
    import shutil
    shutil.rmtree(work, ignore_errors=True)
    print("retagged -> %s-%s+%s" % (dist, version, tag))


if __name__ == "__main__":
    main()
