@echo on
REM ---- portable workspace roots (overridden by build.py) ----
if not defined SPARKW_ROOT set "SPARKW_ROOT=C:\Dev"
if not defined SPARKW_WHEELS set "SPARKW_WHEELS=%SPARKW_ROOT%\spark-wheels"
if not defined SPARKW_TMP set "SPARKW_TMP=C:\ot"
if not defined SPARKW_PYHOME set "SPARKW_PYHOME=%SPARKW_ROOT%\python\cpython-3.12-windows-aarch64-none"
if not exist "%SPARKW_TMP%" mkdir "%SPARKW_TMP%"
if not exist "%SPARKW_WHEELS%" mkdir "%SPARKW_WHEELS%"
REM LLVM at triton's pinned commit (850a2b1b...) for win_arm64 — the one
REM platform triton has no prebuilt LLVM for. mlir+llvm, host+NVPTX+AMDGPU.
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsarm64.bat"
if errorlevel 1 exit /b 1
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%SPARKW_ROOT%\pytorch\.venv-arm\Scripts;%PATH%"
if not exist %SPARKW_TMP% mkdir %SPARKW_TMP%
set "TMP=%SPARKW_TMP%"
set "TEMP=%SPARKW_TMP%"

if not exist %SPARKW_ROOT%\llvm-triton (
    git clone --filter=blob:none https://github.com/llvm/llvm-project.git %SPARKW_ROOT%\llvm-triton
)
cd /d %SPARKW_ROOT%\llvm-triton
git fetch --depth 1 origin 850a2b1b975c061ae0fc982ba68064d305485cb2
if errorlevel 1 exit /b 1
git checkout 850a2b1b975c061ae0fc982ba68064d305485cb2
if errorlevel 1 exit /b 1

cmake -S llvm -B build -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_INSTALL_PREFIX=%SPARKW_ROOT%\llvm-triton-install ^
  -DLLVM_ENABLE_PROJECTS=mlir;llvm;lld ^
  -DLLVM_TARGETS_TO_BUILD=AArch64;NVPTX;AMDGPU ^
  -DLLVM_ENABLE_ASSERTIONS=OFF ^
  -DLLVM_ENABLE_DIA_SDK=OFF ^
  -DLLVM_ENABLE_ZLIB=OFF ^
  -DLLVM_ENABLE_ZSTD=OFF ^
  -DLLVM_ENABLE_LIBXML2=OFF ^
  -DLLVM_INCLUDE_TESTS=OFF ^
  -DLLVM_INCLUDE_BENCHMARKS=OFF ^
  -DLLVM_INCLUDE_EXAMPLES=OFF ^
  -DLLVM_BUILD_TOOLS=OFF ^
  -DLLVM_PARALLEL_COMPILE_JOBS=8 ^
  -DLLVM_PARALLEL_LINK_JOBS=2
if errorlevel 1 (
    echo TRITON_LLVM_CMAKE_FAILED
    exit /b 1
)
cmake --build build --target install -j 8
if errorlevel 1 (
    echo TRITON_LLVM_BUILD_FAILED
    exit /b 1
)
echo TRITON_LLVM_OK
