@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell"

where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  set "PS_EXE=pwsh"
)

echo Running Android build script...
echo Tip: you can pass custom SDK path:
echo   scripts\build_android.cmd -AndroidSdkPath "C:\path\to\Android\Sdk"
echo.

%PS_EXE% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build_android.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Android build failed with exit code %EXIT_CODE%.
  if /I not "%CI%"=="true" (
    echo.
    echo Press any key to close this window...
    pause >nul
  )
  endlocal & exit /b %EXIT_CODE%
)

echo.
echo Android build completed successfully.
endlocal

