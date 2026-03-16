param(
  [string]$SourceDir = "",
  [string]$OutputDir = "",
  [string]$InnoCompiler = "",
  [string]$AppVersion = "",
  [string]$OutputBaseFilename = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Resolve-InnoCompiler {
  param([string]$UserValue)

  if ($UserValue) {
    if (-not (Test-Path $UserValue)) {
      throw "Inno Setup compiler was not found: $UserValue"
    }
    return (Resolve-Path $UserValue).Path
  }

  $fromPath = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($fromPath) {
    return $fromPath.Source
  }

  $candidates = @(
    "C:\Users\$env:USERNAME\AppData\Local\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
  }

  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) {
    Write-Host "Inno Setup was not found. Installing via winget..."
    & $winget.Source install --id JRSoftware.InnoSetup -e --source winget --accept-package-agreements --accept-source-agreements --silent | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to install Inno Setup with winget."
    }

    foreach ($candidate in $candidates) {
      if (Test-Path $candidate) {
        return (Resolve-Path $candidate).Path
      }
    }
  }

  throw "Inno Setup compiler (ISCC.exe) was not found."
}

function Resolve-AppVersion {
  param([string]$ProjectDir)

  $pubspecPath = Join-Path $ProjectDir "pubspec.yaml"
  if (-not (Test-Path $pubspecPath)) {
    return "1.0.0"
  }

  $line = Get-Content -Path $pubspecPath -Encoding UTF8 |
    Where-Object { $_ -match '^\s*version\s*:' } |
    Select-Object -First 1
  if (-not $line) {
    return "1.0.0"
  }

  if ($line -match '^\s*version\s*:\s*([^+]+)') {
    return $Matches[1].Trim()
  }
  return "1.0.0"
}

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourceDirPath = if ($SourceDir) {
  (Resolve-Path $SourceDir).Path
} else {
  (Resolve-Path (Join-Path $projectDir "artifacts\windows_release")).Path
}
if (-not (Test-Path $sourceDirPath)) {
  throw "Release directory was not found: $sourceDirPath"
}

$outputDirPath = if ($OutputDir) {
  $OutputDir
} else {
  Join-Path $projectDir "artifacts\installer"
}
New-Item -ItemType Directory -Force -Path $outputDirPath | Out-Null
$outputDirPath = (Resolve-Path $outputDirPath).Path

$appVersionValue = if ($AppVersion) { $AppVersion } else { Resolve-AppVersion -ProjectDir $projectDir }
$baseFilename = if ($OutputBaseFilename) { $OutputBaseFilename } else { "Goodog's AI Setup v$appVersionValue" }

$exeName = "Goodog's AI.exe"
if (-not (Test-Path (Join-Path $sourceDirPath $exeName))) {
  $fallbackExe = Get-ChildItem -Path $sourceDirPath -Filter "*.exe" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (-not $fallbackExe) {
    throw "No executable file was found in: $sourceDirPath"
  }
  $exeName = $fallbackExe.Name
}

$issPath = Join-Path $projectDir "installer\goodogs_ai_installer.iss"
$wizardImage = Join-Path $projectDir "installer\assets\wizard.bmp"
$wizardSmallImage = Join-Path $projectDir "installer\assets\wizard_small.bmp"
$setupIcon = Join-Path $projectDir "Goodog's AI.ico"
if (-not (Test-Path $issPath)) {
  throw "Installer script was not found: $issPath"
}
if (-not (Test-Path $wizardImage)) {
  throw "Wizard image was not found: $wizardImage"
}
if (-not (Test-Path $wizardSmallImage)) {
  throw "Wizard small image was not found: $wizardSmallImage"
}
if (-not (Test-Path $setupIcon)) {
  throw "Setup icon file was not found: $setupIcon"
}

$iscc = Resolve-InnoCompiler -UserValue $InnoCompiler

$args = @(
  "/DSourceDir=$sourceDirPath",
  "/DOutputDir=$outputDirPath",
  "/DAppVersion=$appVersionValue",
  "/DOutputBaseFilename=$baseFilename",
  "/DAppExeName=$exeName",
  "/DSetupIconFile=$setupIcon",
  "/DWizardImageFile=$wizardImage",
  "/DWizardSmallImageFile=$wizardSmallImage",
  $issPath
)

Write-Host "Inno Setup: $iscc"
Write-Host "Source:     $sourceDirPath"
Write-Host "Output:     $outputDirPath"
Write-Host "Version:    $appVersionValue"

& $iscc @args
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup failed with exit code $LASTEXITCODE."
}

$installer = Get-ChildItem -Path $outputDirPath -Filter "$baseFilename*.exe" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if (-not $installer) {
  throw "Installer was not produced in: $outputDirPath"
}

Write-Host "Installer:  $($installer.FullName)"
$installer.FullName
