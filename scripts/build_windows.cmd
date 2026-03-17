@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell"

where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  set "PS_EXE=pwsh"
)

%PS_EXE% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build_windows.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Build failed with exit code %EXIT_CODE%.
  endlocal & exit /b %EXIT_CODE%
)

echo.
echo Build completed successfully.
endlocal
