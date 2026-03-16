param(
  [string]$FlutterExe = "",
  [string]$BuildRoot = "C:\\goodogs_ai_build",
  [switch]$SkipClean,
  [switch]$OpenOutput
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Resolve-FlutterExe {
  param(
    [string]$UserValue,
    [string]$ProjectDir
  )

  if ($UserValue) {
    if (-not (Test-Path $UserValue)) {
      throw "Flutter executable was not found: $UserValue"
    }
    return (Resolve-Path $UserValue).Path
  }

  $fromPath = Get-Command flutter -ErrorAction SilentlyContinue
  if ($fromPath) {
    return $fromPath.Source
  }

  $nearbyFlutter = Join-Path (Split-Path $ProjectDir -Parent) "flutter\\bin\\flutter.bat"
  if (Test-Path $nearbyFlutter) {
    return (Resolve-Path $nearbyFlutter).Path
  }

  throw "Flutter executable was not found. Add flutter to PATH or pass -FlutterExe."
}

function Invoke-Checked {
  param(
    [string]$Executable,
    [string[]]$Arguments,
    [string]$WorkingDirectory
  )

  Push-Location $WorkingDirectory
  try {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "Command failed with exit code $($LASTEXITCODE): $Executable $($Arguments -join ' ')"
    }
  }
  finally {
    Pop-Location
  }
}

function Invoke-RobocopyMirror {
  param(
    [string]$Source,
    [string]$Destination
  )

  $excludeDirs = @(
    ".dart_tool",
    ".idea",
    ".git",
    "build",
    "artifacts",
    "windows\\flutter\\ephemeral",
    "ios",
    "macos",
    "linux",
    "web"
  )

  $excludeFiles = @(
    "pubspec.lock",
    "flutter_*.log"
  )

  $args = @(
    $Source,
    $Destination,
    "/MIR",
    "/R:1",
    "/W:1",
    "/NFL",
    "/NDL",
    "/NJH",
    "/NJS",
    "/NP",
    "/XD"
  ) + $excludeDirs + @("/XF") + $excludeFiles

  robocopy @args | Out-Null
  if ($LASTEXITCODE -gt 7) {
    throw "Robocopy failed with code $LASTEXITCODE"
  }
}

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$flutter = Resolve-FlutterExe -UserValue $FlutterExe -ProjectDir $projectDir

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$workspaceDir = Join-Path $BuildRoot "workspace_$timestamp"
$releaseDir = Join-Path $workspaceDir "build\\windows\\x64\\runner\\Release"
$artifactDir = Join-Path $projectDir "artifacts\\windows_release"

New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

Write-Host "Project:   $projectDir"
Write-Host "Flutter:   $flutter"
Write-Host "Workspace: $workspaceDir"

Invoke-RobocopyMirror -Source $projectDir -Destination $workspaceDir

$ephemeralDir = Join-Path $workspaceDir "windows\\flutter\\ephemeral"
if (Test-Path $ephemeralDir) {
  Remove-Item -Path $ephemeralDir -Recurse -Force
}

if (-not $SkipClean) {
  Invoke-Checked -Executable $flutter -Arguments @("clean") -WorkingDirectory $workspaceDir
}

Invoke-Checked -Executable $flutter -Arguments @("pub", "get") -WorkingDirectory $workspaceDir
Invoke-Checked -Executable $flutter -Arguments @("build", "windows", "--release") -WorkingDirectory $workspaceDir

if (-not (Test-Path $releaseDir)) {
  throw "Release directory was not produced: $releaseDir"
}

Get-ChildItem -Path $artifactDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $releaseDir "*") -Destination $artifactDir -Recurse -Force

$exePath = Join-Path $artifactDir "Goodog's AI.exe"
if (-not (Test-Path $exePath)) {
  $exePath = Join-Path $artifactDir "goodogs_chat.exe"
}

Write-Host ""
Write-Host "Build completed successfully."
Write-Host "Artifacts: $artifactDir"
Write-Host "Exe:       $exePath"

if ($OpenOutput) {
  Start-Process explorer.exe $artifactDir
}
