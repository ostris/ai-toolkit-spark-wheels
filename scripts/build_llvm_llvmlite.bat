@echo on
REM ---- portable workspace roots (overridden by build.py) ----
if not defined SPARKW_ROOT set "SPARKW_ROOT=C:\Dev"
if not defined SPARKW_WHEELS set "SPARKW_WHEELS=%SPARKW_ROOT%\spark-wheels"
if not defined SPARKW_TMP set "SPARKW_TMP=C:\ot"
if not defined SPARKW_PYHOME set "SPARKW_PYHOME=%SPARKW_ROOT%\python\cpython-3.12-windows-aarch64-none"
if not exist "%SPARKW_TMP%" mkdir "%SPARKW_TMP%"
if not exist "%SPARKW_WHEELS%" mkdir "%SPARKW_WHEELS%"
REM Stage 1: LLVM 22 static libs for win_arm64 (llvmlite 0.49 requires LLVM 22.x)
REM Stage 2: llvmlite 0.49.0rc1 wheel  Stage 3: numba 0.67.0rc1 wheel
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsarm64.bat"
if errorlevel 1 exit /b 1
set "PATH=%SPARKW_ROOT%\pytorch\.venv-arm\Scripts;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
if not exist %SPARKW_TMP% mkdir %SPARKW_TMP%
set "TMP=%SPARKW_TMP%"
set "TEMP=%SPARKW_TMP%"

if not exist %SPARKW_ROOT%\llvm-project git clone --depth 1 -b release/22.x https://github.com/llvm/llvm-project.git %SPARKW_ROOT%\llvm-project
cd /d %SPARKW_ROOT%\llvm-project

cmake -S llvm -B build -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_INSTALL_PREFIX=%SPARKW_ROOT%\llvm22 ^
  -DLLVM_TARGETS_TO_BUILD=AArch64;NVPTX ^
  -DLLVM_ENABLE_RTTI=ON ^
  -DLLVM_ENABLE_ZLIB=OFF ^
  -DLLVM_ENABLE_ZSTD=OFF ^
  -DLLVM_ENABLE_LIBXML2=OFF ^
  -DLLVM_ENABLE_DIA_SDK=OFF ^
  -DLLVM_INCLUDE_TESTS=OFF ^
  -DLLVM_INCLUDE_BENCHMARKS=OFF ^
  -DLLVM_INCLUDE_EXAMPLES=OFF ^
  -DLLVM_PARALLEL_COMPILE_JOBS=6 ^
  -DLLVM_PARALLEL_LINK_JOBS=2
if errorlevel 1 (
    echo LLVM_CMAKE_FAILED
    exit /b 1
)
cmake --build build --target install -j 6
if errorlevel 1 (
    echo LLVM_BUILD_FAILED
    exit /b 1
)
echo LLVM_OK

REM ---- Stage 2: llvmlite ----
set "LLVM_PATH=%SPARKW_ROOT%\llvm22"
set "LLVM_DIR=%SPARKW_ROOT%\llvm22\lib\cmake\llvm"
set "CMAKE_PREFIX_PATH=%SPARKW_ROOT%\llvm22"
set LLVMLITE_SKIP_LLVM_VERSION_CHECK=1
cd /d %SPARKW_ROOT%\llvmlite-0.49.0rc1
pip wheel --no-deps --no-build-isolation --wheel-dir %SPARKW_WHEELS% .
if errorlevel 1 (
    echo LLVMLITE_FAILED
    exit /b 1
)
pip install --no-index --find-links %SPARKW_WHEELS% llvmlite
echo LLVMLITE_OK

REM ---- Stage 3: numba ----
pip download --no-deps --no-binary :all: "numba==0.67.0rc1" -d %SPARKW_TMP%\numba-sdist
if errorlevel 1 (
    echo NUMBA_DOWNLOAD_FAILED
    exit /b 1
)
for %%F in (%SPARKW_TMP%\numba-sdist\numba-*.tar.gz) do tar -xzf %%F -C %SPARKW_ROOT%\
cd /d %SPARKW_ROOT%
umba-0.67.0rc1
pip wheel --no-deps --no-build-isolation --wheel-dir %SPARKW_WHEELS% .
if errorlevel 1 (
    echo NUMBA_FAILED
    exit /b 1
)
echo NUMBA_OK
dir %SPARKW_WHEELS%\*.whl
