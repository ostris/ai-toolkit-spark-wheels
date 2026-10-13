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
call %SPARKW_ROOT%\pytorch\.venv-arm\Scripts\activate.bat
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4"
set "CUDA_HOME=%CUDA_PATH%"
set "PATH=%CUDA_PATH%\bin;%CUDA_PATH%\bin\arm64;C:\Program Files\NVIDIA\CUDNN\v9.25\bin\13.4\arm64;C:\Program Files\Arm Performance Libraries\armpl_26.01\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
set "LINK=/LIBPATH:%SPARKW_PYHOME%\libs"

cd /d %SPARKW_ROOT%\natten
if errorlevel 1 exit /b 1
set NATTEN_CUDA_ARCH=12.1
set NATTEN_N_WORKERS=6
set NATTEN_VERBOSE=1
set MAX_JOBS=6
set MSSdk=1
set DISTUTILS_USE_SDK=1
if not exist %SPARKW_TMP% mkdir %SPARKW_TMP%
set "TMP=%SPARKW_TMP%"
set "TEMP=%SPARKW_TMP%"

pip wheel --no-deps --no-build-isolation --wheel-dir %SPARKW_WHEELS% .
if errorlevel 1 (
    echo NATTEN_FAILED
    exit /b 1
)
echo NATTEN_OK
