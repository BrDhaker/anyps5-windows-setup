<#
.SYNOPSIS
Runs AnyPS5's ctest suite on Windows, optionally several times, and lists the tests that fail only sometimes.

.DESCRIPTION
- -CpuOnly skips the graphics tests (AGC, shader recompiler, video out, Vulkan). About 4,500 tests run in roughly
  6 minutes with -Jobs 8 and need no GPU.
- -Gpu <name> picks the Vulkan device by a case-insensitive part of its name ("4060", "Arc", "Radeon") and fails
  instead of skipping when it is missing.
- -Validation adds the Khronos validation layer settings that AnyPS5's AGENTS.md asks for on AGC, shader recompiler
  and VideoOut changes. It then checks that the layer was really loaded and counts VUID- messages.
- -Repeat N runs the selection N times and prints which tests failed in every run and which only in some.
  The flaky ones are often a test bug that is quick to prove and fix.

.EXAMPLE
.\scripts\Test-AnyPS5.ps1 -BuildDir C:\src\AnyPS5\build -CpuOnly -Repeat 3
.\scripts\Test-AnyPS5.ps1 -BuildDir C:\src\AnyPS5\build -Gpu 4060 -Filter '^agc_driver_msaa_dcc'
.\scripts\Test-AnyPS5.ps1 -BuildDir C:\src\AnyPS5\build -Gpu 4060 -Validation -Filter '^agc_driver_cached_image'
#>
param(
    [Parameter(Mandatory = $true)][string]$BuildDir,
    [switch]$CpuOnly,
    [string]$Gpu,
    [switch]$Validation,
    [string]$Filter,
    [int]$Jobs = 8,
    [int]$Repeat = 1,
    [string]$Root = "C:\tools"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Use-Toolchain.ps1") -Root $Root | Out-Null
$BuildDir = (Resolve-Path $BuildDir).Path

$graphics = '^(agc_|shader|video_out|guest_video|vulkan|spirv|recompiler|guest_agc|guest_gnm|gnm_|draw_|render|present|swapchain|frame_replay|guest_shader)|_gpu|vulkan|_vk_|videoout|_shader_'
$selection = @()
if ($Filter) { $selection += @("-R", $Filter) }
if ($CpuOnly) { $selection += @("-E", $graphics) }

if ($Gpu) {
    $env:ANYPS5_GPU = $Gpu
    $env:ANYPS5_REQUIRE_VULKAN = "1"
}
if ($Validation) {
    $env:ANYPS5_REQUIRE_VULKAN = "1"
    $env:ANYPS5_NO_SHADER_CACHE = "1"
    $env:VK_INSTANCE_LAYERS = "VK_LAYER_KHRONOS_validation"
    $env:VK_LOADER_DEBUG = "layer"
}

$runs = @()
for ($run = 1; $run -le $Repeat; $run++) {
    $log = Join-Path $BuildDir "test-run-$run.log"
    $verbosity = if ($Validation) { "-V" } else { "--output-on-failure" }
    $ctestArgs = @("--test-dir", $BuildDir, "-j", $Jobs, $verbosity) + $selection
    $started = Get-Date
    $argText = ($ctestArgs | ForEach-Object { if ($_ -match '\s|\|') { "`"$_`"" } else { $_ } }) -join " "
    & cmd /c "ctest $argText > `"$log`" 2>&1"
    $minutes = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)
    $summary = (Select-String -Path $log -Pattern "tests passed" | Select-Object -Last 1).Line
    $failed = @()
    $start = (Select-String -Path $log -Pattern "The following tests FAILED").LineNumber
    if ($start) {
        $failed = @(Get-Content $log | Select-Object -Skip $start |
            ForEach-Object { if ($_ -match '^\s+\d+ - (\S+) \(') { $Matches[1] } })
    }
    Write-Host "run $run/$Repeat ($minutes min): $summary"
    if ($Validation) {
        $inserted = (Select-String -Path $log -Pattern 'Insert instance layer "VK_LAYER_KHRONOS_validation"' -SimpleMatch).Count
        $notFound = (Select-String -Path $log -Pattern "was not found but was requested by env var VK_INSTANCE_LAYERS" -SimpleMatch).Count
        $vuids = (Select-String -Path $log -Pattern "VUID-" -SimpleMatch).Count
        Write-Host "  validation: layer inserted $inserted time(s), 'not found' $notFound, VUID- lines $vuids"
        if ($inserted -eq 0 -or $notFound -gt 0) { Write-Warning "The validation layer was not loaded; install the LunarG Vulkan SDK (1.4.335 or newer)." }
    }
    $runs += , $failed
}

$all = @($runs | ForEach-Object { $_ }) | Sort-Object -Unique
Write-Host ""
if ($all.Count -eq 0) {
    Write-Host "No failures in $Repeat run(s)."
    exit 0
}
Write-Host "Failures across $Repeat run(s) (X = failed in that run):"
foreach ($test in $all) {
    $marks = ($runs | ForEach-Object { if ($_ -contains $test) { "X" } else { "." } }) -join ""
    $count = ($marks.ToCharArray() | Where-Object { $_ -eq "X" }).Count
    $kind = if ($count -eq $Repeat) { "every run" } else { "flaky" }
    Write-Host ("  [{0}] {1,-60} {2}" -f $marks, $test, $kind)
}
Write-Host ""
Write-Host "Logs: $BuildDir\test-run-*.log. Search the AnyPS5 issues for a test's name before reporting it."
exit 1
