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

cd /d %SPARKW_ROOT%lash-attention
git submodule update --init csrc/cutlass
if errorlevel 1 exit /b 1

set TORCH_CUDA_ARCH_LIST=12.1
set FLASH_ATTN_CUDA_ARCHS=120
set FLASH_ATTENTION_FORCE_BUILD=TRUE
set MAX_JOBS=2
set NVCC_THREADS=2
set MSSdk=1
set DISTUTILS_USE_SDK=1
set "FLASH_ATTN_LOCAL_VERSION=cu134torch2.14"
if not exist %SPARKW_TMP% mkdir %SPARKW_TMP%
set "TMP=%SPARKW_TMP%"
set "TEMP=%SPARKW_TMP%"

pip install --quiet ninja psutil einops
python setup.py bdist_wheel
if errorlevel 1 (
    echo FLASH_ATTN_FAILED
    exit /b 1
)
copy /y dist\*.whl %SPARKW_WHEELS%\
echo FLASH_ATTN_OK
dir dist
