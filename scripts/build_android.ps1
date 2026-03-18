param(
  [string]$FlutterExe = "",
  [string]$AndroidSdkPath = "",
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

function Test-AndroidSdkLayout {
  param(
    [string]$SdkRoot
  )

  $missing = @()

  $platformToolsDir = Join-Path $SdkRoot "platform-tools"
  if (-not (Test-Path $platformToolsDir)) {
    $missing += "platform-tools"
  }

  $buildToolsDir = Join-Path $SdkRoot "build-tools"
  $hasBuildTools = Get-ChildItem -Path $buildToolsDir -Directory -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (-not $hasBuildTools) {
    $missing += "build-tools"
  }

  $platformsDir = Join-Path $SdkRoot "platforms"
  $hasPlatforms = Get-ChildItem -Path $platformsDir -Directory -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (-not $hasPlatforms) {
    $missing += "platforms"
  }

  return @{
    IsValid = ($missing.Count -eq 0)
    Missing = $missing
  }
}

function Resolve-AndroidSdkPath {
  param(
    [string]$ProjectDir,
    [string]$FlutterExe,
    [string]$UserSdkPath
  )

  $candidates = @()

  if ($UserSdkPath) {
    $candidates += $UserSdkPath
  }

  if ($env:ANDROID_HOME) {
    $candidates += $env:ANDROID_HOME
  }
  if ($env:ANDROID_SDK_ROOT) {
    $candidates += $env:ANDROID_SDK_ROOT
  }
  if ($env:ANDROID_SDK_HOME) {
    $candidates += $env:ANDROID_SDK_HOME
  }

  if ($FlutterExe) {
    try {
      $configOutput = & $FlutterExe config --list 2>$null
      foreach ($line in $configOutput) {
        if ($line -match 'android-sdk:\s*(.+)$') {
          $flutterSdk = $Matches[1].Trim()
          if ($flutterSdk) {
            $candidates += $flutterSdk
          }
        }
      }
    }
    catch {
      # Ignore parsing errors and continue probing defaults.
    }
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
  $defaultUserProfile = Join-Path $env:USERPROFILE "AppData\\Local\\Android\\Sdk"
  $nearbyPlatformTools = Join-Path (Split-Path $ProjectDir -Parent) "platform-tools"
  $candidates += $defaultLocal
  $candidates += $defaultProgramData
  $candidates += $defaultUserProfile
  $candidates += $nearbyPlatformTools

  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if ($adb) {
    $adbDir = Split-Path $adb.Source -Parent
    if ($adbDir) {
      $sdkFromAdb = Split-Path $adbDir -Parent
      if ($sdkFromAdb) {
        $candidates += $sdkFromAdb
      }
    }
  }

  $uniqueCandidates = $candidates |
    Where-Object { $_ -and $_.Trim().Length -gt 0 } |
    ForEach-Object { $_.Trim() -replace '\\\\', '\' } |
    Select-Object -Unique

  $checkedRoots = @()
  $invalidRoots = @()

  foreach ($candidate in $uniqueCandidates) {
    if (-not (Test-Path $candidate)) {
      continue
    }

    $resolvedCandidate = (Resolve-Path $candidate).Path
    if ((Split-Path $resolvedCandidate -Leaf) -ieq "platform-tools") {
      $rootsToCheck = @((Split-Path $resolvedCandidate -Parent))
    }
    else {
      $rootsToCheck = @($resolvedCandidate)
    }
    $rootsToCheck = $rootsToCheck |
      Where-Object { $_ -and $_.Trim().Length -gt 0 } |
      Select-Object -Unique

    foreach ($root in $rootsToCheck) {
      if (-not (Test-Path $root)) {
        continue
      }
      if ($checkedRoots -contains $root) {
        continue
      }

      $checkedRoots += $root
      $layout = Test-AndroidSdkLayout -SdkRoot $root
      if ($layout.IsValid) {
        return @{
          Path = $root
          Checked = $uniqueCandidates
          CheckedRoots = $checkedRoots
          InvalidRoots = $invalidRoots
        }
      }

      $missingText = ($layout.Missing | ForEach-Object { $_ }) -join ", "
      $invalidRoots += "$root (missing: $missingText)"
    }
  }

  return @{
    Path = ""
    Checked = $uniqueCandidates
    CheckedRoots = $checkedRoots
    InvalidRoots = $invalidRoots
  }
}

function Format-SdkHints {
  param(
    [string]$UserSdkPath
  )

  $hints = @()
  if ($UserSdkPath) {
    $hints += "Provided -AndroidSdkPath: $UserSdkPath"
  }
  else {
    $hints += "Tip: pass -AndroidSdkPath explicitly if your SDK is in a custom location."
  }

  $hints += "If you only have 'platform-tools', install full Android SDK (platforms + build-tools)."
  $hints += "Android Studio -> SDK Manager -> install 'Android SDK Platform' and 'Android SDK Build-Tools'."

  return ($hints | ForEach-Object { " - $_" }) -join [Environment]::NewLine
}

function Throw-AndroidSdkError {
  param(
    [hashtable]$Probe,
    [string]$UserSdkPath
  )

  $checkedPathsText = if ($Probe.Checked -and $Probe.Checked.Count -gt 0) {
    ($Probe.Checked | ForEach-Object { " - $_" }) -join [Environment]::NewLine
  }
  else {
    " - no candidate paths were found"
  }

  $invalidRootsText = if ($Probe.InvalidRoots -and $Probe.InvalidRoots.Count -gt 0) {
    ($Probe.InvalidRoots | ForEach-Object { " - $_" }) -join [Environment]::NewLine
  }
  else {
    " - none"
  }

  $hintsText = Format-SdkHints -UserSdkPath $UserSdkPath

  throw @"
Android SDK was not found or is incomplete.
Checked candidate paths:
$checkedPathsText
Detected incomplete SDK roots:
$invalidRootsText
Hints:
$hintsText
"@
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
$androidSdkProbe = Resolve-AndroidSdkPath -ProjectDir $projectDir -FlutterExe $flutter -UserSdkPath $AndroidSdkPath
$androidSdk = $androidSdkProbe.Path
if (-not $androidSdk) {
  Throw-AndroidSdkError -Probe $androidSdkProbe -UserSdkPath $AndroidSdkPath
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

$workspaceLocalPropertiesPath = Join-Path $workspaceDir "android\\local.properties"
$escapedSdk = $androidSdk -replace '\\', '\\'
Set-Content -Path $workspaceLocalPropertiesPath -Encoding UTF8 -Value "sdk.dir=$escapedSdk"

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

