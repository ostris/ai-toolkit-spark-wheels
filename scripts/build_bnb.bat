@echo on
REM ---- portable workspace roots (overridden by build.py) ----
if not defined SPARKW_ROOT set "SPARKW_ROOT=C:\Dev"
if not defined SPARKW_WHEELS set "SPARKW_WHEELS=%SPARKW_ROOT%\spark-wheels"
if not defined SPARKW_TMP set "SPARKW_TMP=C:\ot"
if not defined SPARKW_PYHOME set "SPARKW_PYHOME=%SPARKW_ROOT%\python\cpython-3.12-windows-aarch64-none"
if not exist "%SPARKW_TMP%" mkdir "%SPARKW_TMP%"
if not exist "%SPARKW_WHEELS%" mkdir "%SPARKW_WHEELS%"
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsarm64.bat"
if errorlevel 1 exit /b 1
set "PATH=%SPARKW_ROOT%\pytorch\.venv-arm\Scripts;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4"
set "CUDA_HOME=%CUDA_PATH%"
set "PATH=%CUDA_PATH%\bin;%PATH%"

if not exist %SPARKW_ROOT%\bnb git clone --depth 1 -b 0.50.0 https://github.com/bitsandbytes-foundation/bitsandbytes.git %SPARKW_ROOT%\bnb
cd /d %SPARKW_ROOT%\bnb
cmake -B build -G Ninja -DCOMPUTE_BACKEND=cuda -DCMAKE_CUDA_ARCHITECTURES=121 -DCMAKE_BUILD_TYPE=Release
if errorlevel 1 (
    echo BNB_CMAKE_FAILED
    exit /b 1
)
cmake --build build --config Release
if errorlevel 1 (
    echo BNB_BUILD_FAILED
    exit /b 1
)
dir bitsandbytes\*.dll
pip wheel --no-deps --no-build-isolation --wheel-dir %SPARKW_WHEELS% .
if errorlevel 1 (
    echo BNB_WHEEL_FAILED
    exit /b 1
)
python "%~dp0retag_wheel.py" "%SPARKW_WHEELS%" bitsandbytes 0.50.0 cu134
echo BNB_OK
