@echo on
REM ---- portable workspace roots (overridden by build.py) ----
if not defined SPARKW_ROOT set "SPARKW_ROOT=C:\Dev"
if not defined SPARKW_WHEELS set "SPARKW_WHEELS=%SPARKW_ROOT%\spark-wheels"
if not defined SPARKW_TMP set "SPARKW_TMP=C:\ot"
if not defined SPARKW_PYHOME set "SPARKW_PYHOME=%SPARKW_ROOT%\python\cpython-3.12-windows-aarch64-none"
if not exist "%SPARKW_TMP%" mkdir "%SPARKW_TMP%"
if not exist "%SPARKW_WHEELS%" mkdir "%SPARKW_WHEELS%"
REM Build PyTorch (main + PR190448) for Windows ARM64 with CUDA 13.4 / cuDNN 9.25
REM Target: NVIDIA RTX Spark (N1X, sm_121)

call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsarm64.bat"
if errorlevel 1 exit /b 1

cd /d %SPARKW_ROOT%\pytorch
if errorlevel 1 exit /b 1
call .venv-arm\Scripts\activate.bat

set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4"
set "CUDA_HOME=%CUDA_PATH%"
set "CUDACXX=%CUDA_PATH%\bin\nvcc.exe"
set "PATH=%CUDA_PATH%\bin;%PATH%"

set USE_CUDA=1
set USE_CUDNN=1
set "CUDNN_HOME=C:\Program Files\NVIDIA\CUDNN\v9.25"
set "CUDNN_ROOT_DIR=%CUDNN_HOME%"
set "CUDNN_INCLUDE_DIR=%CUDNN_HOME%\include\13.4"
set "CUDNN_LIB_DIR=%CUDNN_HOME%\lib\13.4\arm64"
set "CUDNN_LIBRARY=%CUDNN_HOME%\lib\13.4\arm64\cudnn.lib"

set TORCH_CUDA_ARCH_LIST=12.1
set CMAKE_CUDA_ARCHITECTURES=121
set USE_MAGMA=0
set TH_BINARY_BUILD=0
set "CMAKE_CUDA_FLAGS=-Xcompiler /Zc:preprocessor"
set "CFLAGS=/Zc:preprocessor /EHsc"
set "CXXFLAGS=/Zc:preprocessor /EHsc"

REM In-tree CUTLASS flash + mem-eff SDPA kernels ENABLED for sm_121 (long build)
set USE_FLASH_ATTENTION=1
set USE_MEM_EFF_ATTENTION=1

set BLAS=APL
set USE_LAPACK=1
set "ARMPL_DIR=C:\Program Files\Arm Performance Libraries\armpl_26.01"

REM distributed ON: torchao (hard toolkit dep) references
REM torch.ops._c10d_functional at import time; a no-distributed torch breaks
REM transformers/peft too. Matches NVIDIA's CI recipe (libuv + gloo).
set USE_DISTRIBUTED=1
set "libuv_ROOT=%SPARKW_ROOT%\libuv\install"
copy /y "%SPARKW_ROOT%\libuv\install\bin\uv.dll" torch\lib\uv.dll

set INSTALL_TEST=0
set MSSdk=1
set DISTUTILS_USE_SDK=1
set CMAKE_POLICY_VERSION_MINIMUM=3.5
set MAX_JOBS=10

set PYTORCH_BUILD_VERSION=2.14.0.dev20260727+cu134
set PYTORCH_BUILD_NUMBER=1

python -m build --wheel --no-isolation --outdir dist
if errorlevel 1 (
    echo BUILD_FAILED
    exit /b 1
)
echo BUILD_SUCCEEDED
copy /y dist\*.whl "%SPARKW_WHEELS%"
REM Downstream scripts (vision/audio/codec/flash-attn/natten/bnb/triton) import torch from this venv.
for %%f in (dist\torch-*.whl) do pip install --quiet --force-reinstall --no-deps "%%f"
if errorlevel 1 exit /b 1
REM second pass pulls torch runtime deps (filelock, sympy, networkx, jinja2, fsspec) without reinstalling torch
for %%f in (dist\torch-*.whl) do pip install --quiet "%%f"
if errorlevel 1 exit /b 1
dir dist
