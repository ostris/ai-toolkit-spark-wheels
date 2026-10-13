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

set "VENV=%SPARKW_ROOT%\pytorch\.venv-arm"
set "FFMPEG=%SPARKW_ROOT%\ffmpeg-n8.1-latest-winarm64-lgpl-shared-8.1"
set "PKGCONF=%LOCALAPPDATA%\Microsoft\WinGet\Packages\bloodrock.pkg-config-lite_Microsoft.Winget.Source_8wekyb3d8bbwe\pkg-config-lite-0.28-1\bin"
set "PATH=%VENV%\Scripts;%PKGCONF%;%FFMPEG%\bin;C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4\bin\arm64;C:\Program Files\NVIDIA\CUDNN\v9.25\bin\13.4\arm64;C:\Program Files\Arm Performance Libraries\armpl_26.01\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"

set CMAKE_GENERATOR=Ninja
set "PKG_CONFIG_PATH=%FFMPEG%\lib\pkgconfig"
set "CMAKE_PREFIX_PATH=%VENV%\Lib\site-packages\torch\share\cmake;%VENV%\Lib\site-packages\pybind11\share\cmake"
set I_CONFIRM_THIS_IS_NOT_A_LICENSE_VIOLATION=1
set TORCHCODEC_BUILD_IMAGE=OFF
set ENABLE_CUDA=
set MSSdk=1
set DISTUTILS_USE_SDK=1
if not exist %SPARKW_TMP% mkdir %SPARKW_TMP%
set "TMP=%SPARKW_TMP%"
set "TEMP=%SPARKW_TMP%"

pip install --quiet pybind11
cd /d %SPARKW_ROOT%\torchcodec
if errorlevel 1 exit /b 1
pip wheel --no-deps --no-build-isolation --wheel-dir %SPARKW_WHEELS% .
if errorlevel 1 (
    echo TORCHCODEC_FAILED
    exit /b 1
)
echo TORCHCODEC_OK
dir %SPARKW_WHEELS%
