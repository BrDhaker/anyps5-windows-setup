<#
.SYNOPSIS
Downloads the Windows toolchain that AnyPS5's BUILD.md names, verifies the checksums and unpacks it.

.DESCRIPTION
Installs portable copies of WinLibs GCC 15.2.0 (UCRT, POSIX threads), CMake 4.5.0 and Ninja 1.13.2 into one
folder. Nothing is installed system-wide and the system PATH is not changed; dot-source Use-Toolchain.ps1 to put
the tools on PATH for the current session. Already-unpacked tools are skipped.

.PARAMETER Root
Folder that receives the tools. Default: C:\tools

.EXAMPLE
.\scripts\Setup-Toolchain.ps1
.\scripts\Setup-Toolchain.ps1 -Root D:\dev\tools
#>
param(
    [string]$Root = "C:\tools"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$tools = @(
    @{
        Name   = "WinLibs GCC 15.2.0 (x86_64, UCRT, POSIX threads)"
        Url    = "https://github.com/brechtsanders/winlibs_mingw/releases/download/15.2.0posix-14.0.0-ucrt-r7/winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64ucrt-14.0.0-r7.zip"
        Sha256 = "cb2fbad6162540cdf5e1facdce08d4dac359e8cf64f7f696a99274291763b815"
        Into   = "winlibs"
        Check  = "winlibs\mingw64\bin\g++.exe"
    },
    @{
        Name   = "CMake 4.5.0"
        Url    = "https://github.com/Kitware/CMake/releases/download/v4.5.0/cmake-4.5.0-windows-x86_64.zip"
        Sha256 = "301b1728317ccd84e984b02e366a8293735bc5ac618757d3d8f58b578f062411"
        Into   = ""
        Check  = "cmake-4.5.0-windows-x86_64\bin\cmake.exe"
    },
    @{
        Name   = "Ninja 1.13.2"
        Url    = "https://github.com/ninja-build/ninja/releases/download/v1.13.2/ninja-win.zip"
        Sha256 = "07fc8261b42b20e71d1720b39068c2e14ffcee6396b76fb7a795fb460b78dc65"
        Into   = "ninja"
        Check  = "ninja\ninja.exe"
    }
)

New-Item -ItemType Directory -Force -Path $Root | Out-Null
$downloads = Join-Path $Root "_downloads"
New-Item -ItemType Directory -Force -Path $downloads | Out-Null
$tar = Get-Command tar.exe -ErrorAction SilentlyContinue

foreach ($tool in $tools) {
    $check = Join-Path $Root $tool.Check
    if (Test-Path $check) {
        Write-Host "[skip] $($tool.Name) is already in $Root"
        continue
    }
    $archive = Join-Path $downloads ([IO.Path]::GetFileName($tool.Url))
    if (-not (Test-Path $archive)) {
        Write-Host "[get ] $($tool.Name)"
        Invoke-WebRequest -Uri $tool.Url -OutFile $archive -UseBasicParsing
    }
    $hash = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
    if ($hash -ne $tool.Sha256) {
        Remove-Item $archive -Force
        throw "Checksum mismatch for $($tool.Name): got $hash, expected $($tool.Sha256). The download was deleted; run the script again."
    }
    $target = if ($tool.Into) { Join-Path $Root $tool.Into } else { $Root }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Write-Host "[open] $($tool.Name) -> $target"
    if ($tar) {
        & $tar.Source -xf $archive -C $target
        if ($LASTEXITCODE -ne 0) { throw "tar could not unpack $archive" }
    } else {
        Expand-Archive -Path $archive -DestinationPath $target -Force
    }
    if (-not (Test-Path $check)) { throw "$($tool.Name) unpacked, but $check is missing" }
}

Write-Host ""
Write-Host "Other things the full AnyPS5 build needs:"
$git = Get-Command git.exe -ErrorAction SilentlyContinue
$bash = Test-Path "C:\Program Files\Git\usr\bin\bash.exe"
if ($git -and $bash) {
    Write-Host "  [ok ] Git for Windows with Bash"
} else {
    Write-Host "  [!! ] Git for Windows with Bash (libusb's header generation needs bash.exe): https://git-scm.com/download/win"
}
$pythons = @(Get-Command python.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch "\\WindowsApps\\" })
if ($pythons.Count -gt 0) {
    Write-Host "  [ok ] Python 3: $($pythons[0].Source)"
} else {
    Write-Host "  [!! ] Python 3 from python.org. The Microsoft Store Python is an App Execution Alias and breaks several AnyPS5 tests; see docs/TROUBLESHOOTING.md"
}
Write-Host ""
Write-Host "Done. Next:  . .\scripts\Use-Toolchain.ps1 -Root $Root"
