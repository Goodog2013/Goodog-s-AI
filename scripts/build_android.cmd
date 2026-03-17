@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell"

where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  set "PS_EXE=pwsh"
)

%PS_EXE% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build_android.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Android build failed with exit code %EXIT_CODE%.
  endlocal & exit /b %EXIT_CODE%
)

echo.
echo Android build completed successfully.
endlocal
