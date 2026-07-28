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
set MSSdk=1
set DISTUTILS_USE_SDK=1
if not exist %SPARKW_TMP% mkdir %SPARKW_TMP%
set "TMP=%SPARKW_TMP%"
set "TEMP=%SPARKW_TMP%"
if not exist %SPARKW_ROOT%
umba-0.67.0rc1 (
    pip download --no-deps --no-binary :all: "numba==0.67.0rc1" -d %SPARKW_TMP%\numba-sdist
    for %%F in (%SPARKW_TMP%\numba-sdist\numba-*.tar.gz) do tar -xzf %%F -C %SPARKW_ROOT%\
)
cd /d %SPARKW_ROOT%
umba-0.67.0rc1
pip wheel --no-deps --no-build-isolation --wheel-dir %SPARKW_WHEELS% .
if errorlevel 1 (
    echo NUMBA_FAILED
    exit /b 1
)
echo NUMBA_OK
