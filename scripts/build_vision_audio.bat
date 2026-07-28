@echo on
REM ---- portable workspace roots (overridden by build.py) ----
if not defined SPARKW_ROOT set "SPARKW_ROOT=C:\Dev"
if not defined SPARKW_WHEELS set "SPARKW_WHEELS=%SPARKW_ROOT%\spark-wheels"
if not defined SPARKW_TMP set "SPARKW_TMP=C:\ot"
if not defined SPARKW_PYHOME set "SPARKW_PYHOME=%SPARKW_ROOT%\python\cpython-3.12-windows-aarch64-none"
if not exist "%SPARKW_TMP%" mkdir "%SPARKW_TMP%"
if not exist "%SPARKW_WHEELS%" mkdir "%SPARKW_WHEELS%"
REM Build torchvision + torchaudio win_arm64 wheels against the freshly built torch.
REM Prereq: torch wheel installed into %SPARKW_ROOT%\pytorch\.venv-arm

call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsarm64.bat"
if errorlevel 1 exit /b 1

call %SPARKW_ROOT%\pytorch\.venv-arm\Scripts\activate.bat

set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4"
set "CUDA_HOME=%CUDA_PATH%"
REM torch import needs the CUDA/cuDNN/APL runtime DLLs (wheel does not bundle them)
set "PATH=%CUDA_PATH%\bin;%CUDA_PATH%\bin\arm64;C:\Program Files\NVIDIA\CUDNN\v9.25\bin\13.4\arm64;C:\Program Files\Arm Performance Libraries\armpl_26.01\bin;%PATH%"
if not exist %SPARKW_TMP% mkdir %SPARKW_TMP%
set "TMP=%SPARKW_TMP%"
set "TEMP=%SPARKW_TMP%"
set MSSdk=1
set DISTUTILS_USE_SDK=1
set CMAKE_POLICY_VERSION_MINIMUM=3.5
set MAX_JOBS=14

if not exist %SPARKW_WHEELS% mkdir %SPARKW_WHEELS%

REM ---------------- torchvision (with CUDA ops, sm_121) ----------------
cd /d %SPARKW_ROOT%ision
set FORCE_CUDA=1
set TORCH_CUDA_ARCH_LIST=12.1
set BUILD_VERSION=0.29.0.dev20260727+cu134
pip install --quiet wheel
python setup.py bdist_wheel
if errorlevel 1 (
    echo VISION_BUILD_FAILED
    exit /b 1
)
copy /y dist\*.whl %SPARKW_WHEELS%\
echo VISION_BUILD_OK

REM ---------------- torchaudio (CPU ext only) ----------------
cd /d %SPARKW_ROOT%udio
set USE_CUDA=0
set FORCE_CUDA=
set USE_FFMPEG=0
set USE_SOX=0
set BUILD_VERSION=2.11.0.dev20260727+cu134
python setup.py bdist_wheel
if errorlevel 1 (
    echo AUDIO_BUILD_FAILED
    exit /b 1
)
copy /y dist\*.whl %SPARKW_WHEELS%\
echo AUDIO_BUILD_OK
dir %SPARKW_WHEELS%
