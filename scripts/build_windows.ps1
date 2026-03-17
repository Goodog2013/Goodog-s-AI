param(
  [string]$FlutterExe = "",
  [string]$BuildRoot = "C:\\goodogs_ai_build",
  [switch]$SkipClean,
  [switch]$SkipInstaller,
  [string]$InnoCompiler = "",
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

function Copy-ReleaseArtifacts {
  param(
    [string]$ReleaseDir,
    [string]$PreferredArtifactDir,
    [string]$FallbackNamePrefix
  )

  $artifactDir = $PreferredArtifactDir
  try {
    New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
    Get-ChildItem -Path $artifactDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $ReleaseDir "*") -Destination $artifactDir -Recurse -Force
  }
  catch {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $artifactDir = Join-Path (Split-Path $PreferredArtifactDir -Parent) "${FallbackNamePrefix}_$timestamp"
    New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
    Copy-Item -Path (Join-Path $ReleaseDir "*") -Destination $artifactDir -Recurse -Force
    Write-Warning "Could not overwrite $PreferredArtifactDir (files are locked). Used fallback directory: $artifactDir"
  }

  return (Resolve-Path $artifactDir).Path
}

function Resolve-PrimaryExe {
  param(
    [string]$ArtifactDir,
    [string]$ExpectedName,
    [string]$FallbackName
  )

  $expected = Join-Path $ArtifactDir $ExpectedName
  if (Test-Path $expected) {
    return $expected
  }

  $fallback = Join-Path $ArtifactDir $FallbackName
  if (Test-Path $fallback) {
    return $fallback
  }

  $latestExe = Get-ChildItem -Path $ArtifactDir -Filter "*.exe" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (-not $latestExe) {
    throw "No executable file was found in: $ArtifactDir"
  }
  return $latestExe.FullName
}

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$flutter = Resolve-FlutterExe -UserValue $FlutterExe -ProjectDir $projectDir

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$workspaceDir = Join-Path $BuildRoot "workspace_$timestamp"
$releaseDir = Join-Path $workspaceDir "build\\windows\\x64\\runner\\Release"

$chatArtifactBaseDir = Join-Path $projectDir "artifacts\\windows_release"
$adminArtifactBaseDir = Join-Path $projectDir "artifacts\\windows_admin_release"
$installerDir = Join-Path $projectDir "artifacts\\installer"

New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
New-Item -ItemType Directory -Force -Path $chatArtifactBaseDir | Out-Null
New-Item -ItemType Directory -Force -Path $adminArtifactBaseDir | Out-Null
New-Item -ItemType Directory -Force -Path $installerDir | Out-Null

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

Write-Host ""
Write-Host "Building user app..."
Invoke-Checked -Executable $flutter -Arguments @("build", "windows", "--release") -WorkingDirectory $workspaceDir
if (-not (Test-Path $releaseDir)) {
  throw "Release directory was not produced: $releaseDir"
}

$chatArtifactDir = Copy-ReleaseArtifacts -ReleaseDir $releaseDir -PreferredArtifactDir $chatArtifactBaseDir -FallbackNamePrefix "windows_release"
$chatExePath = Resolve-PrimaryExe -ArtifactDir $chatArtifactDir -ExpectedName "Goodog's AI.exe" -FallbackName "goodogs_chat.exe"

$installerPath = ""
if (-not $SkipInstaller) {
  $installerScript = Join-Path $projectDir "scripts\\build_installer.ps1"
  if (-not (Test-Path $installerScript)) {
    throw "Installer script was not found: $installerScript"
  }

  $installerArgs = @{
    SourceDir = $chatArtifactDir
    OutputDir = $installerDir
  }
  if ($InnoCompiler) {
    $installerArgs["InnoCompiler"] = $InnoCompiler
  }

  $installerOutput = & $installerScript @installerArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Installer creation failed."
  }
  if ($installerOutput) {
    $installerPath = $installerOutput[-1]
  }
}

Write-Host ""
Write-Host "Building admin app..."
Invoke-Checked -Executable $flutter -Arguments @("build", "windows", "--release", "-t", "lib/main_admin.dart") -WorkingDirectory $workspaceDir
if (-not (Test-Path $releaseDir)) {
  throw "Admin release directory was not produced: $releaseDir"
}

$adminArtifactDir = Copy-ReleaseArtifacts -ReleaseDir $releaseDir -PreferredArtifactDir $adminArtifactBaseDir -FallbackNamePrefix "windows_admin_release"
$adminExePath = Resolve-PrimaryExe -ArtifactDir $adminArtifactDir -ExpectedName "Goodog's AI Admin.exe" -FallbackName "goodogs_chat.exe"
$renamedAdminExe = Join-Path (Split-Path $adminExePath -Parent) "Goodog's AI Admin.exe"
if ($adminExePath -ne $renamedAdminExe) {
  if (Test-Path $renamedAdminExe) {
    Remove-Item -Path $renamedAdminExe -Force
  }
  Move-Item -Path $adminExePath -Destination $renamedAdminExe -Force
  $adminExePath = $renamedAdminExe
}

Write-Host ""
Write-Host "Build completed successfully."
Write-Host "User artifacts:  $chatArtifactDir"
Write-Host "User exe:        $chatExePath"
if ($installerPath) {
  Write-Host "Installer:       $installerPath"
}
Write-Host "Admin artifacts: $adminArtifactDir"
Write-Host "Admin exe:       $adminExePath"

if ($OpenOutput) {
  Start-Process explorer.exe $chatArtifactDir
}
