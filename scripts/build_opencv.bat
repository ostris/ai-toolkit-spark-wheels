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
set MSSdk=1
set DISTUTILS_USE_SDK=1
set "CMAKE_GENERATOR=Visual Studio 17 2022"
set "CMAKE_GENERATOR_PLATFORM=ARM64"
set "CMAKE_GENERATOR_TOOLSET=v143,host=arm64"
REM opencv's dnn Winograd FP16 code uses __fp16, which MSVC arm64 cannot
REM compile (same failure in 4.11 and 4.12). The toolkit runs all NNs in
REM torch; cv2 is only used for classic image ops, so drop the dnn module.
REM CPU_BASELINE=NEON only: opencv's runtime feature detection on Windows
REM ARM64 cannot see DOTPROD/FP16, and a baseline it can't confirm makes cv2
REM abort at import with "build doesn't support current CPU/HW configuration".
set "CMAKE_ARGS=-DBUILD_opencv_dnn=OFF -DCPU_BASELINE=NEON -DCPU_DISPATCH="
if not exist %SPARKW_TMP% mkdir %SPARKW_TMP%
set "TMP=%SPARKW_TMP%"
set "TEMP=%SPARKW_TMP%"

REM GUI flavor first (the requirement name used by requirements_base/controlnet_aux)
%SPARKW_ROOT%\pytorch\.venv-arm\Scripts\pip.exe wheel --no-deps --wheel-dir %SPARKW_WHEELS% "opencv-python==4.12.0.88"
if errorlevel 1 (
    echo OPENCV_GUI_FAILED
    exit /b 1
)
echo OPENCV_GUI_OK

%SPARKW_ROOT%\pytorch\.venv-arm\Scripts\pip.exe wheel --no-deps --wheel-dir %SPARKW_WHEELS% "opencv-python-headless==4.12.0.88"
if errorlevel 1 (
    echo OPENCV_HEADLESS_FAILED
    exit /b 1
)
echo OPENCV_HEADLESS_OK
dir %SPARKW_WHEELS%
