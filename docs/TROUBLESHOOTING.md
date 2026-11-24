# Troubleshooting AnyPS5 on Windows

Problems I hit while building and testing [AnyPS5](https://github.com/boykopovar/AnyPS5) on Windows 11, with the fix for each. Where the project documents something itself, I link to it.

## Python

**Tests fail with `WinError 1920` or exit codes that should be 7 come back as 0.** You're using the Microsoft Store Python. Its `python.exe` in `AppData\Local\Microsoft\WindowsApps` is an App Execution Alias: it can't be copied, and the real interpreter runs from another folder. Install Python from [python.org](https://www.python.org/downloads/windows/) and pass it to CMake with `-DPython3_EXECUTABLE=` (Build-AnyPS5.ps1 does this for you). The affected tests now skip under the alias (AnyPS5 #22782), but a real install gives full coverage.

## Building

**Configuration stops at `Could not download FFmpeg …: SSL peer certificate or SSH remote key was not OK`.** CMake's built-in downloader failed GitHub's TLS check. Don't set `CMAKE_TLS_VERIFY=0`. Download the same file over HTTPS into the place CMake expects: `<build>\externals\<12-char ffmpeg-core commit>-ffmpeg-mingw-x64.zip` from `https://github.com/KytyPS5/ext-ffmpeg-core/releases/download/<commit>/ffmpeg-mingw-x64.zip`. Build-AnyPS5.ps1 does this automatically.

**A test keeps failing with the old behaviour after you changed its code.** The test binary wasn't rebuilt. Without `-k 0`, ninja stops at the first failing target and never relinks the others, so an unrelated broken target leaves your test stale. Always build with `cmake --build build -- -k 0`.

**`objcopy` fails with `Invalid argument` on some AGC test executables.** Microsoft Defender quarantines a few of them because they contain generated machine code. Add the build folder to Defender's exclusions; see AnyPS5's [BUILD.md](https://github.com/boykopovar/AnyPS5/blob/main/docs/dev/BUILD.md#windows-setup-and-troubleshooting).

**Which compiler?** BUILD.md names WinLibs GCC 15.2.0 (`15.2.0posix-14.0.0-ucrt-r7`), which is what Setup-Toolchain.ps1 installs. MSYS2's GCC 16 also builds AnyPS5, but some tests behave differently with it:
- `guest_raise_short_sleep` fails nearly every run (AnyPS5 issue #24358).
- `unwind_cursor`, `unwind_enclosing_function` and `agc_process_sampler_stack` report "native Windows unwind metadata".

Compare against WinLibs before reporting a failure.

**A rebuild after updating takes as long as the first build.** That happens when your checkout was far behind `main`: shared headers change and almost everything recompiles. Updating often keeps rebuilds short.

## Testing

**About 40 tests skip with `symlinks unavailable`.** Windows only lets programs create symlinks with Developer Mode on (Settings → System → For developers) or as administrator. The skips are harmless; turn Developer Mode on if you want those tests to run.

**GPU tests run on the wrong GPU.** On laptops with two GPUs, Windows uses the integrated one when the discrete one is off. Pick a device with `ANYPS5_GPU=<part of its name>`, for example `4060`, `Arc` or `Radeon`, and set `ANYPS5_REQUIRE_VULKAN=1` so a missing GPU fails instead of skipping. Test-AnyPS5.ps1 `-Gpu` sets both.

**A timing test fails once and then passes.** Several AnyPS5 tests measure sleeps and wake-ups, and a busy laptop occasionally misses a deadline. Run it a few times (`Test-AnyPS5.ps1 -Repeat 3`, or `ctest --repeat until-fail:50 -R <name>`) and compare with `main` before calling it a regression. A test that fails *sometimes* on `main` is often a test bug worth fixing; that's how the fixes in AnyPS5 #22945 and #22989 started.

**`ctest --timeout` doesn't raise a test's limit.** A `TIMEOUT` set on the test in CMake wins. To time a slow test, run its executable directly from its working directory, with the library folder from `ctest --show-only=json-v1` on `PATH`.

**Graphics PRs need the validation layer.** AnyPS5's AGENTS.md asks for AGC, shader recompiler and VideoOut changes to be tested with the Khronos validation layer **1.4.335 or newer**. It comes with the [LunarG Vulkan SDK](https://vulkan.lunarg.com/sdk/home#windows). Run the same focused tests on `main` and on your change. `Test-AnyPS5.ps1 -Validation` sets the variables and checks that the layer really loaded.

**Logs written with `*>` in Windows PowerShell 5.1 are UTF-16**, and `grep` can't read them. Redirect through `cmd /c "... > log 2>&1"` as the scripts here do; see AnyPS5's [GAME_TESTING.md](https://github.com/boykopovar/AnyPS5/blob/main/docs/dev/GAME_TESTING.md).
