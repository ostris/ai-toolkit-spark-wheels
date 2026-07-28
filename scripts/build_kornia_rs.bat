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
set "PATH=%SPARKW_ROOT%\pytorch\.venv-arm\Scripts;%USERPROFILE%\.cargo\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
set CMAKE_GENERATOR=Ninja
set CARGO_BUILD_JOBS=4
set CARGO_TARGET_DIR=%SPARKW_ROOT%\ktgt
%SPARKW_ROOT%\pytorch\.venv-arm\Scripts\pip.exe wheel --no-deps --no-build-isolation --wheel-dir %SPARKW_WHEELS% %SPARKW_ROOT%\ksrc
if errorlevel 1 (
    echo KORNIA_RS_FAILED
    exit /b 1
)
echo KORNIA_RS_OK
