@echo on
REM ---- portable workspace roots (overridden by build.py) ----
if not defined SPARKW_ROOT set "SPARKW_ROOT=C:\Dev"
if not defined SPARKW_WHEELS set "SPARKW_WHEELS=%SPARKW_ROOT%\spark-wheels"
if not defined SPARKW_TMP set "SPARKW_TMP=C:\ot"
if not defined SPARKW_PYHOME set "SPARKW_PYHOME=%SPARKW_ROOT%\python\cpython-3.12-windows-aarch64-none"
if not exist "%SPARKW_TMP%" mkdir "%SPARKW_TMP%"
if not exist "%SPARKW_WHEELS%" mkdir "%SPARKW_WHEELS%"
REM Build triton-windows natively for win_arm64 against our LLVM (triton pin).
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsarm64.bat"
if errorlevel 1 exit /b 1
call %SPARKW_ROOT%\pytorch\.venv-arm\Scripts\activate.bat
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4"
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%CUDA_PATH%\bin;%PATH%"
if not exist %SPARKW_TMP% mkdir %SPARKW_TMP%
set "TMP=%SPARKW_TMP%"
set "TEMP=%SPARKW_TMP%"

set TRITON_OFFLINE_BUILD=1
set "LLVM_SYSPATH=%SPARKW_ROOT%\llvm-triton-install"
set "JSON_SYSPATH=%SPARKW_ROOT%\json-nlohmann"
set "TRITON_PTXAS_PATH=%CUDA_PATH%\bin\ptxas.exe"
set "TRITON_CUOBJDUMP_PATH=%CUDA_PATH%\bin\cuobjdump.exe"
set "TRITON_NVDISASM_PATH=%CUDA_PATH%\bin\nvdisasm.exe"
set "TRITON_CUDACRT_PATH=%CUDA_PATH%\include"
set "TRITON_CUDART_PATH=%CUDA_PATH%\include"
set TRITON_BUILD_PROTON=OFF
set "TRITON_APPEND_CMAKE_ARGS=-DLLD_DIR=C:/Dev/llvm-triton-install/lib/cmake/lld"
set TRITON_PARALLEL_LINK_JOBS=2
set MAX_JOBS=6
set MSSdk=1
set DISTUTILS_USE_SDK=1

cd /d %SPARKW_ROOT%	riton-windows
pip install --quiet pybind11 wheel nanobind setuptools-scm cmake ninja
pip wheel --no-deps --no-build-isolation --wheel-dir %SPARKW_WHEELS% .
if errorlevel 1 (
    echo TRITON_FAILED
    exit /b 1
)
echo TRITON_OK
dir %SPARKW_WHEELS%\triton*
