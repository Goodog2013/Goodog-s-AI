param(
  [string]$FlutterExe = "",
  [string]$BuildRoot = "C:\\goodogs_ai_android_build",
  [switch]$SkipClean,
  [switch]$BuildAab,
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

  $asciiFlutter = "C:\flutter\bin\flutter.bat"
  if (Test-Path $asciiFlutter) {
    return (Resolve-Path $asciiFlutter).Path
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

function Resolve-AndroidSdkPath {
  param([string]$ProjectDir)

  $candidates = @()

  if ($env:ANDROID_HOME) {
    $candidates += $env:ANDROID_HOME
  }
  if ($env:ANDROID_SDK_ROOT) {
    $candidates += $env:ANDROID_SDK_ROOT
  }

  $localPropertiesPath = Join-Path $ProjectDir "android\\local.properties"
  if (Test-Path $localPropertiesPath) {
    $sdkLine = Get-Content -Path $localPropertiesPath -Encoding UTF8 |
      Where-Object { $_ -match '^\s*sdk\.dir\s*=' } |
      Select-Object -First 1
    if ($sdkLine -and $sdkLine -match '^\s*sdk\.dir\s*=\s*(.+)\s*$') {
      $sdkDirValue = $Matches[1].Trim()
      if ($sdkDirValue) {
        $sdkDirValue = $sdkDirValue -replace '\\\\', '\'
        $candidates += $sdkDirValue
      }
    }
  }

  $defaultLocal = Join-Path $env:LOCALAPPDATA "Android\\Sdk"
  $defaultProgramData = "C:\\Android\\Sdk"
  $candidates += $defaultLocal
  $candidates += $defaultProgramData

  $uniqueCandidates = $candidates |
    Where-Object { $_ -and $_.Trim().Length -gt 0 } |
    Select-Object -Unique

  foreach ($candidate in $uniqueCandidates) {
    if (-not (Test-Path $candidate)) {
      continue
    }
    $platformTools = Join-Path $candidate "platform-tools"
    if (Test-Path $platformTools) {
      return (Resolve-Path $candidate).Path
    }
  }

  return ""
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
    "Releases",
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

function Copy-BuildFiles {
  param(
    [string]$SourceDir,
    [string]$Filter,
    [string]$PreferredOutputDir,
    [string]$FallbackPrefix
  )

  $files = Get-ChildItem -Path $SourceDir -Filter $Filter -File -ErrorAction SilentlyContinue
  if (-not $files -or $files.Count -eq 0) {
    throw "No files matching '$Filter' were found in: $SourceDir"
  }

  $targetDir = $PreferredOutputDir
  try {
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Get-ChildItem -Path $targetDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
  }
  catch {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $targetDir = Join-Path (Split-Path $PreferredOutputDir -Parent) "${FallbackPrefix}_$timestamp"
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Write-Warning "Could not clear $PreferredOutputDir (files may be locked). Used fallback: $targetDir"
  }

  foreach ($file in $files) {
    Copy-Item -Path $file.FullName -Destination (Join-Path $targetDir $file.Name) -Force
  }

  return (Resolve-Path $targetDir).Path
}

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$flutter = Resolve-FlutterExe -UserValue $FlutterExe -ProjectDir $projectDir
$androidSdk = Resolve-AndroidSdkPath -ProjectDir $projectDir
if (-not $androidSdk) {
  throw "Android SDK was not found. Install Android SDK (Android Studio) or set ANDROID_HOME/ANDROID_SDK_ROOT."
}

$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$platformToolsPath = Join-Path $androidSdk "platform-tools"
if (Test-Path $platformToolsPath) {
  $env:PATH = "$platformToolsPath;$env:PATH"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$workspaceDir = Join-Path $BuildRoot "workspace_$timestamp"
$releaseRoot = Join-Path $projectDir "Releases\\android"
$apkOutputDir = Join-Path $releaseRoot "apk"
$aabOutputDir = Join-Path $releaseRoot "aab"

New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
New-Item -ItemType Directory -Force -Path $apkOutputDir | Out-Null

Write-Host "Project:   $projectDir"
Write-Host "Flutter:   $flutter"
Write-Host "AndroidSDK:$androidSdk"
Write-Host "Workspace: $workspaceDir"

Invoke-RobocopyMirror -Source $projectDir -Destination $workspaceDir

if (-not $SkipClean) {
  Invoke-Checked -Executable $flutter -Arguments @("clean") -WorkingDirectory $workspaceDir
}

Invoke-Checked -Executable $flutter -Arguments @("pub", "get") -WorkingDirectory $workspaceDir

Write-Host ""
Write-Host "Building Android APK (release)..."
Invoke-Checked -Executable $flutter -Arguments @("build", "apk", "--release") -WorkingDirectory $workspaceDir

$apkSourceDir = Join-Path $workspaceDir "build\\app\\outputs\\flutter-apk"
$apkArtifactDir = Copy-BuildFiles `
  -SourceDir $apkSourceDir `
  -Filter "*.apk" `
  -PreferredOutputDir $apkOutputDir `
  -FallbackPrefix "apk_release"

$aabArtifactDir = ""
if ($BuildAab) {
  New-Item -ItemType Directory -Force -Path $aabOutputDir | Out-Null
  Write-Host ""
  Write-Host "Building Android App Bundle (release)..."
  Invoke-Checked -Executable $flutter -Arguments @("build", "appbundle", "--release") -WorkingDirectory $workspaceDir

  $aabSourceDir = Join-Path $workspaceDir "build\\app\\outputs\\bundle\\release"
  $aabArtifactDir = Copy-BuildFiles `
    -SourceDir $aabSourceDir `
    -Filter "*.aab" `
    -PreferredOutputDir $aabOutputDir `
    -FallbackPrefix "aab_release"
}

Write-Host ""
Write-Host "Android build completed successfully."
Write-Host "Releases root:   $releaseRoot"
Write-Host "APK artifacts:   $apkArtifactDir"
if ($aabArtifactDir) {
  Write-Host "AAB artifacts:   $aabArtifactDir"
}

if ($OpenOutput) {
  Start-Process explorer.exe $releaseRoot
}
