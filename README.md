# ai-toolkit Spark wheel set (Windows on ARM, CUDA 13.4)

Builds the complete native `win_arm64` Python wheel set that
[ai-toolkit](https://github.com/ostris/ai-toolkit) uses on NVIDIA RTX Spark
(N1X) machines: PyTorch + CUDA 13.4 (sm_121), torchvision, torchaudio,
torchcodec, flash-attn, NATTEN, triton (torch.compile), bitsandbytes,
llvmlite/numba (librosa), opencv, and the small deps with no upstream arm64
wheels.

Everything is reproducible from pinned sources + patches:

- `pins.json` — every upstream repo/sdist, ref, version, and build note
- `patches/` — our modifications as reviewable diffs
- `scripts/` — the per-component build scripts (exact proven flags)
- `build.py` — orchestrator: `python build.py all` → `dist/*.whl`

## Prerequisites

One **manual** install (NVIDIA's developer-preview EULA requires their own
click-through; we do not redistribute any NVIDIA components):

1. **CUDA 13.4 toolkit (arm64)** + **RTX Spark developer driver (R616+)** —
   <https://developer.nvidia.com/cuda-13-4-0-download-archive?target_os=Windows&target_arch=arm64>

Everything else installs unattended (or run `python build.py doctor` to check):

- VS2022 Build Tools with ARM64 MSVC + Windows 11 SDK (winget)
- cuDNN 9.x arm64 (NVIDIA's official public installer)
- Arm Performance Libraries (winget)
- Rust aarch64-pc-windows-msvc (rustup), pkg-config-lite (winget)
- native arm64 Python 3.12 (uv)

## Build

```powershell
python build.py doctor      # verify toolchain
python build.py --plan      # see the component order
python build.py all         # several hours; torch and LLVM dominate
```

Wheels land in `dist/`. Memory guidance: the flash-attn/NATTEN CUTLASS
compiles are memory-hungry — the scripts pin low job counts on purpose
(learned the hard way on a 54 GB machine).

## Publishing

Upload `dist/*.whl` as a GitHub release, publish a simple find-links
`index.html` (GitHub Pages) linking to the assets, then point ai-toolkit's
`manager/spec.py` `SPARK_WHEELS_URL` at that page. The ai-toolkit manager
handles end-user runtime provisioning (cuDNN/APL/MSVC auto-install, CUDA
detection + instructions) by itself.

## Updating

Bump the pin in `pins.json`, re-run the component. A patch that no longer
applies fails loudly at exactly the hunk that needs attention. Watch
upstream: pytorch#190448 / #189949 (WoA CUDA enablement),
triton-windows#49 (official ARM64 wheels — retire our triton when solid),
numba cp312 arm64 wheels (retire the LLVM/llvmlite/numba chain).
