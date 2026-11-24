# AnyPS5 on Windows: setup and test scripts

PowerShell scripts that take a Windows PC from nothing to a working [AnyPS5](https://github.com/boykopovar/AnyPS5) build and test run, plus the problems I hit along the way and how I fixed them.

I wrote these while contributing to AnyPS5 from a Windows laptop with no PS5 and no game dumps. Following the project's instructions works, but a handful of Windows-specific snags cost me hours. These scripts fix them, so a new contributor can get to a test run in an afternoon.

> **Unofficial.** This repository isn't part of AnyPS5 and isn't affiliated with or endorsed by the AnyPS5 maintainers or Sony Interactive Entertainment. It contains no AnyPS5, Sony or game code. For anything about the project itself, follow AnyPS5's [BUILD.md](https://github.com/boykopovar/AnyPS5/blob/main/docs/dev/BUILD.md) and [CONTRIBUTING.md](https://github.com/boykopovar/AnyPS5/blob/main/CONTRIBUTING.md).

## What you get

| Script | What it does |
|---|---|
| `scripts/Setup-Toolchain.ps1` | Downloads the toolchain BUILD.md names: WinLibs GCC 15.2.0, CMake 4.5.0 and Ninja 1.13.2. Each archive is checked against its official SHA-256 and unpacked as a portable copy. Nothing is installed system-wide. |
| `scripts/Use-Toolchain.ps1` | Puts the tools on `PATH` for the current PowerShell session only. |
| `scripts/Build-AnyPS5.ps1` | Builds AnyPS5: the relinker-only build or the full one. Always uses `ninja -k 0` and lists failed targets. Works around the FFmpeg download that CMake's own downloader can fail on Windows. |
| `scripts/Test-AnyPS5.ps1` | Runs ctest on the CPU only or on a chosen GPU, with optional Vulkan validation checks. With `-Repeat N`, it shows which tests fail in some runs but not others. |
| `docs/TROUBLESHOOTING.md` | Every Windows-specific problem I hit, with its fix. |

## Requirements

- Windows 10 or 11, x86-64. About 8 GB free for the relinker-only build and 25 GB for the full build.
- [Git for Windows](https://git-scm.com/download/win), including Bash: the full build uses it.
- [Python 3 from python.org](https://www.python.org/downloads/windows/), **not** the Microsoft Store version (see [troubleshooting](docs/TROUBLESHOOTING.md#python)).
- For GPU tests: a Vulkan-capable GPU and driver. For graphics PRs, also the [LunarG Vulkan SDK](https://vulkan.lunarg.com/sdk/home#windows) (validation layer 1.4.335 or newer).

## Quick start

In PowerShell:

```powershell
git clone https://github.com/BrDhaker/anyps5-windows-setup.git
git clone https://github.com/boykopovar/AnyPS5.git
cd anyps5-windows-setup

# If PowerShell refuses to run scripts:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\scripts\Setup-Toolchain.ps1                                   # about 330 MB of downloads, into C:\tools
.\scripts\Build-AnyPS5.ps1 -Source ..\AnyPS5 -RelinkerOnly        # about 5 minutes, no GPU, no submodules
.\scripts\Test-AnyPS5.ps1 -BuildDir ..\AnyPS5\build-relinker      # about 1,000 tests
```

For the whole project, including the system libraries and the graphics tests:

```powershell
.\scripts\Build-AnyPS5.ps1 -Source ..\AnyPS5                      # submodules (about 4 GB) plus 30-40 minutes of building
.\scripts\Test-AnyPS5.ps1 -BuildDir ..\AnyPS5\build -CpuOnly      # about 4,500 CPU tests, roughly 6 minutes
```

Use `-Root D:\somewhere` on every script to keep the tools somewhere other than `C:\tools`.

## Testing on a GPU

```powershell
# Pick the GPU by part of its name. A missing GPU then fails instead of skipping.
.\scripts\Test-AnyPS5.ps1 -BuildDir ..\AnyPS5\build -Gpu 4060 -Filter '^agc_driver_msaa_dcc'

# The checks AnyPS5's AGENTS.md asks for on AGC, shader recompiler and VideoOut changes:
.\scripts\Test-AnyPS5.ps1 -BuildDir ..\AnyPS5\build -Gpu 4060 -Validation -Filter '^agc_driver_cached_image'
```

With `-Validation`, the script confirms the Khronos layer actually loaded and counts `VUID-` messages. Compare that count between `main` and your change.

## Finding something to fix

The fastest way I found to contribute without a console:

```powershell
.\scripts\Test-AnyPS5.ps1 -BuildDir ..\AnyPS5\build -CpuOnly -Repeat 3
```

```
Failures across 3 run(s) (X = failed in that run):
  [X.X] some_timing_test                                           flaky
  [XXX] some_broken_test                                           every run
```

- **Flaky tests** fail only sometimes. They are often a test bug that you can prove with before/after counts and fix in a few lines.
- **Every-run failures** on Windows are often already reported, so search AnyPS5's issues for the test name first.

My first AnyPS5 pull requests all came from this: #22782, #22934, #22945, #22973 and #22989.

Before opening a pull request, read AnyPS5's CONTRIBUTING.md. In short: fill in the pull request template completely, run `python tools/check_conventions.py`, and say whether AI helped.

## License

MIT, see [LICENSE](LICENSE). This covers the scripts and docs in this repository only. AnyPS5 is a separate project under GPL-2.0.
