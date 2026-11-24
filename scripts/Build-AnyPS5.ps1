<#
.SYNOPSIS
Configures and builds an AnyPS5 checkout on Windows with the toolchain from Setup-Toolchain.ps1.

.DESCRIPTION
- Relinker-only build (-RelinkerOnly): about 430 targets, no submodules, no GPU. Good for relinker and tools work.
- Full build (default): runs `git submodule update --init --recursive` first, then builds everything, about 11,000
  targets. Plan on 30-40 minutes the first time on an 8-core laptop.

The build always runs with `ninja -k 0`, so one failing target doesn't stop the rest and leave other test binaries
stale. The failed targets are listed at the end.

For the full build, the script fetches the FFmpeg prebuilt that AnyPS5's CMake downloads, because CMake's built-in
downloader can fail GitHub's TLS check on some Windows machines. It never turns TLS verification off.

.PARAMETER Source
Path to the AnyPS5 checkout.

.PARAMETER BuildDir
Build folder. Default: <Source>\build, or <Source>\build-relinker with -RelinkerOnly.

.PARAMETER Python
Python 3 interpreter. Default: the first python.exe on PATH that isn't a Microsoft Store alias.

.EXAMPLE
.\scripts\Build-AnyPS5.ps1 -Source C:\src\AnyPS5 -RelinkerOnly
.\scripts\Build-AnyPS5.ps1 -Source C:\src\AnyPS5
#>
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [switch]$RelinkerOnly,
    [string]$BuildDir,
    [string]$Python,
    [string]$Root = "C:\tools",
    [switch]$NoTests
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

. (Join-Path $PSScriptRoot "Use-Toolchain.ps1") -Root $Root | Out-Null

$Source = (Resolve-Path $Source).Path
if (-not (Test-Path (Join-Path $Source "core\relinker"))) { throw "$Source does not look like an AnyPS5 checkout" }
if (-not $BuildDir) { $BuildDir = Join-Path $Source $(if ($RelinkerOnly) { "build-relinker" } else { "build" }) }

if (-not $Python) {
    $candidates = @(Get-Command python.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch "\\WindowsApps\\" })
    if ($candidates.Count -eq 0) { throw "No usable Python 3 found. Install it from python.org, or pass -Python <path to python.exe>" }
    $Python = $candidates[0].Source
}
if ($Python -match "\\WindowsApps\\") { Write-Warning "$Python is a Microsoft Store alias; several AnyPS5 tests fail with it." }
Write-Host "python: $Python"

if (-not $RelinkerOnly) {
    Write-Host "[1/3] Updating submodules"
    & git -C $Source submodule update --init --recursive --jobs 8
    if ($LASTEXITCODE -ne 0) { throw "git submodule update failed" }

    $ffmpeg = Join-Path $Source "3rdparty\ffmpeg-core"
    if (Test-Path $ffmpeg) {
        $sha = (& git -C $ffmpeg rev-parse --short=12 HEAD).Trim()
        $zip = Join-Path $BuildDir "externals\$sha-ffmpeg-mingw-x64.zip"
        if (-not (Test-Path $zip)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $zip) | Out-Null
            Write-Host "      fetching FFmpeg prebuilt $sha"
            Invoke-WebRequest -Uri "https://github.com/KytyPS5/ext-ffmpeg-core/releases/download/$sha/ffmpeg-mingw-x64.zip" -OutFile $zip -UseBasicParsing
        }
    }
}

Write-Host "[2/3] Configuring $BuildDir"
$configure = @("-S", $Source, "-B", $BuildDir, "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_C_COMPILER=gcc", "-DCMAKE_CXX_COMPILER=g++", "-DPython3_EXECUTABLE=$($Python -replace '\\','/')",
    "-DBUILD_TESTING=$(if ($NoTests) { 'OFF' } else { 'ON' })")
if ($RelinkerOnly) { $configure += "-DANYPS5_RELINKER_ONLY=ON" }
& cmake @configure
if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed" }

Write-Host "[3/3] Building (ninja -k 0)"
$log = Join-Path $BuildDir "build.log"
$started = Get-Date
& cmd /c "cmake --build `"$BuildDir`" --parallel -- -k 0 > `"$log`" 2>&1"
$minutes = [int]((Get-Date) - $started).TotalMinutes
$failed = @(Select-String -Path $log -Pattern "^FAILED:" | ForEach-Object { $_.Line })
Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "Build finished in $minutes min with no failed targets. Log: $log"
} else {
    Write-Host "Build finished in $minutes min with $($failed.Count) failed target(s). Log: $log"
    $failed | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
    Write-Host "If Windows Defender quarantined test executables, see docs/TROUBLESHOOTING.md."
    exit 1
}
