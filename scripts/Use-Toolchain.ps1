<#
.SYNOPSIS
Puts the AnyPS5 toolchain on PATH for the current PowerShell session only.

.DESCRIPTION
Dot-source it (note the leading dot) so the change stays in your session:
    . .\scripts\Use-Toolchain.ps1
The system PATH is never changed. CMake 4.5.0 comes first because WinLibs ships its own older cmake.exe.

.PARAMETER Root
Folder that Setup-Toolchain.ps1 used. Default: C:\tools
#>
param(
    [string]$Root = "C:\tools"
)

$entries = @(
    (Join-Path $Root "cmake-4.5.0-windows-x86_64\bin"),
    (Join-Path $Root "winlibs\mingw64\bin"),
    (Join-Path $Root "ninja"),
    "C:\Program Files\Git\cmd",
    "C:\Program Files\Git\usr\bin"
)
$missing = @($entries[0..2] | Where-Object { -not (Test-Path $_) })
if ($missing.Count -gt 0) {
    throw "Toolchain not found in $Root (missing: $($missing -join ', ')). Run .\scripts\Setup-Toolchain.ps1 first."
}
$present = @($entries | Where-Object { Test-Path $_ })
$rest = @($env:PATH -split ";" | Where-Object { $_ -and ($present -notcontains $_) })
$env:PATH = (@($present) + $rest) -join ";"

Write-Host ("gcc   : " + ((& gcc --version) | Select-Object -First 1))
Write-Host ("cmake : " + ((& cmake --version) | Select-Object -First 1))
Write-Host ("ninja : " + (& ninja --version))
