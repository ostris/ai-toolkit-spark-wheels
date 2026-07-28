@echo on
REM ---- portable workspace roots (overridden by build.py) ----
if not defined SPARKW_ROOT set "SPARKW_ROOT=C:\Dev"
if not defined SPARKW_WHEELS set "SPARKW_WHEELS=%SPARKW_ROOT%\spark-wheels"
if not defined SPARKW_TMP set "SPARKW_TMP=C:\ot"
if not defined SPARKW_PYHOME set "SPARKW_PYHOME=%SPARKW_ROOT%\python\cpython-3.12-windows-aarch64-none"
if not exist "%SPARKW_TMP%" mkdir "%SPARKW_TMP%"
if not exist "%SPARKW_WHEELS%" mkdir "%SPARKW_WHEELS%"
REM Build small missing win_arm64 wheels from sdist: pywavelets, soxr, brotli
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsarm64.bat"
if errorlevel 1 exit /b 1

call %SPARKW_ROOT%\pytorch\.venv-arm\Scripts\activate.bat
set MSSdk=1
set DISTUTILS_USE_SDK=1
set CMAKE_POLICY_VERSION_MINIMUM=3.5
set MAX_JOBS=3
if not exist %SPARKW_WHEELS% mkdir %SPARKW_WHEELS%

pip wheel --no-deps --wheel-dir %SPARKW_WHEELS% "pywavelets==1.9.0"
if errorlevel 1 echo PYWAVELETS_FAILED

pip wheel --no-deps --wheel-dir %SPARKW_WHEELS% "soxr==1.1.0"
if errorlevel 1 echo SOXR_FAILED

pip wheel --no-deps --wheel-dir %SPARKW_WHEELS% "brotli==1.2.0"
if errorlevel 1 echo BROTLI_FAILED

echo SMALL_WHEELS_DONE
dir %SPARKW_WHEELS%
