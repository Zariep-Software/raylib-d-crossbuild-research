# raylib-d: cross-compiling

This research explain how to compile games written in [raylib-d](https://github.com/schveiguy/raylib-d) for Linux, Windows, Android and the Web, using LDC and `-betterC`.

> **Status:** Research notes. Linux is the only tested host. Builds from Windows, macOS or Android/Termux have not been tried. Items marked **(untested)** are unverified.

> This document assumes Dev will use dub.json present in this repository.
## Contents

1. [Summary](#summary)
2. [Design decisions](#design-decisions)
3. [Requirements](#requirements)
4. [Directory layout](#directory-layout)
5. [Project structure](#project-structure)
6. [Platforms](#platforms): Linux, Windows, Android, WebAssembly
7. [Troubleshooting](#troubleshooting)
8. [Open questions](#open-questions)

## Summary

| Target | Compiler / toolchain | raylib build | Helper | Status |
| --- | --- | --- | --- | --- |
| Linux | system LDC | system or static `libraylib.a` | copy script | Works |
| Windows (x86_64) | LDC + `windows-msvc-sysroot` | `raylib.lib` (prebuilt, or custom CMake) | `dub` + copy script | Works |
| Android (arm64, armv7, x86_64) | LDC Android toolchain + NDK | `PLATFORM_ANDROID` | `raylib-d-android-template` | Works (Android 10+) |
| Web (WASM) | LDC + Emscripten | `PLATFORM_WEB` | `raylib-d-wasm-build` | Browser support  |


## Design decisions

### Host: Linux
All steps assume a Linux host.

### BetterC
`-betterC` is strongly recommended, for two reasons:

- **Platform support.** The D runtime and GC cause serious problems on Android and WASM. BetterC drops the runtime dependency.
- **Fit for games.** The D GC may pause the program to collect, which is a poor match for frame-sensitive code. Avoiding it with pervasive `@nogc` is more effort than it is worth. BetterC makes manual or arena allocation the default.

Trade-off: no GC, classes, exceptions, `TypeInfo` or druntime-dependent features (e.g. built-in associative arrays, `std.*` modules that need the runtime). Plan data structures accordingly. DMD/GDC builds unavailable.

### Compiler: LDC
LDC (LLVM-based D compiler) is the main compiler because LLVM has the broadest multi-platform support, it also has a better BetterC handling. DMD and GDC are not covered.

## Requirements

| Requirement | Needed for | Notes |
| --- | --- | --- |
| **LDC** (system-level) | All builds | Host compiler |
| **[raylib](https://github.com/raysan5/raylib) static library** | All targets | Cross-compiling needs only the `.a` / `.lib` per target |
| **[LDC2 cross toolchains](https://github.com/ldc-developers/ldc)** | Android/Windows | Cross-compiling needs the entire LDC release for the target |
| **[Windows MSVC sysroot](https://github.com/trcrsired/windows-msvc-sysroot)** | Windows | Headers and libs for linking against MSVC |
| **[Android NDK](https://developer.android.com/ndk/)** | Android | Used with [`raylib-d-android-template`](https://github.com/Zariep-Software/raylib-d-android-template) |
| **[Emscripten](https://emscripten.org)** | Web | Used with [`raylib-d-wasm-build`](https://github.com/Zariep-Software/raylib-d-wasm-build) |
| **CMake, Clang, LLD** | Windows raylib build | Only when building raylib from source |


## Directory layout

Expected install locations (all under `~/.local/include`). Paths are configurable in each helper script.

```
~/.local/include
├── ldc2
│   ├── w64            <- From ldc2-x.x-windows-x64.7z
│   ├── arm64-v8a      <- From ldc2-x.x-android-aarch64.tar.xz
│   └── armeabi-v7a    <- From ldc2-x.x-android-armv7a.tar.xz
├── raylib
│   └── windows
│       └── raylib.lib
├── raylib-android
│   ├── arm64-v8a
│   │   └── libraylib.a
│   ├── armeabi-v7a
│   │   └── libraylib.a
│   └── x86_64
│       └── libraylib.a
├── windows-msvc-sysroot
│   └── ...
└── android-ndk
    └── ...
```

## Project structure

This layout is optional but keeps things orderly.

```
.
├── GDD/
├── make/
│   ├── android/          <- submodule: raylib-d-android-template
│   ├── linux/            <- copy script
│   ├── windows/          <- copy script
│   ├── web/              <- submodule: raylib-d-wasm-build
│   └── ...               <- other platforms
└── src/
    ├── Assets/           <- copied to every target's build folder
    │   ├── maps/
    │   ├── music/
    │   ├── sfx/
    │   ├── textures/
    │   └── ...
    ├── build/
    │   ├── Android/      <- base Android project, packaged with Gradle
    │   ├── Linux/        <- game binary + assets
    │   ├── Windows/      <- game .exe + assets
    │   └── obj/          <- object files (if C libraries are included)
    └── source/           <- game source code
```

## Platforms

### Linux

The simplest target: build with the system LDC against the system or a static raylib.

```sh
dub build --compiler=ldc2 --build=release
```

A copy script in `make/linux` places the binary and `Assets/` into `src/build/Linux/`.

### Windows

**Target:** Windows 10 or newer. The MSVC sysroot is built against Windows 10.

**CPU note:** the prebuilt raylib binary expects the **AVX** instruction set. For pre-AVX CPUs (e.g. Core 2), rebuild raylib without AVX (see below).

#### 1. Get `raylib.lib`

Either download the prebuilt MSVC release from the raylib releases page and copy `raylib.lib` to `~/.local/include/raylib/windows/`, or build it yourself.

#### 2. Build raylib from source (optional)

```sh
git clone https://github.com/raysan5/raylib
cd raylib
```

In practice, raylib does not cross-build with MSVC unless a custom toolchain file is used. Save the following as `~/toolchain-win64.cmake`:

```cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)

set(SYSROOT "$ENV{HOME}/.local/include/windows-msvc-sysroot")

set(CMAKE_C_COMPILER clang)
set(CMAKE_C_COMPILER_TARGET x86_64-windows-msvc)
set(CMAKE_AR llvm-ar)
set(CMAKE_RANLIB llvm-ranlib)
set(CMAKE_LINKER lld-link)

# -mno-avx keeps the library usable on pre-AVX CPUs
set(CMAKE_C_FLAGS_INIT "-fuse-ld=lld -I${SYSROOT}/include -march=x86-64 -mno-avx")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${SYSROOT}/lib/x86_64-unknown-windows-msvc")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
```

Configure and build (run from the raylib root):

```sh
cmake -B build-win \
  -DCMAKE_TOOLCHAIN_FILE=$HOME/toolchain-win64.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DPLATFORM=Desktop
cmake --build build-win
```

Copy the resulting static library to `~/.local/include/raylib/windows/raylib.lib`.

#### 3. Small MSVC Toolchain fix

Dub with fail with `lld-link: error: could not open 'MSVCRT.lib': No such file or directory lld-link: error: could not open 'OLDNAMES.lib': No such file or directory`, Small fix: copy with lowercase

```
mkdir -p ~/.local/include/winlibs-upper
cd ~/.local/include/winlibs-upper
for f in ~/.local/include/windows-msvc-sysroot/lib/x86_64-unknown-windows-msvc/*.lib; do
	b=$(basename "$f" .lib)
  ln -sf "$f" "$(echo "$b" | tr a-z A-Z).lib"
done
```

#### 4. Build the game

```sh
dub build -c windows --compiler=ldc2 --arch=x86_64-windows-msvc --build=release
```

Then run the copy script in `make/windows` to place the `.exe` and `Assets/` into `src/build/Windows/`. Test with Wine or on a Windows machine.

### Android

**Minimum version: Android 10 (SDK 29).**

It may run on older devices, but LDC emits native thread-local storage (TLS), which older Android loaders do not handle. Observed failures:

- Runtime crash: `unknown reloc type 17 @ 0x9c436c64 (531)`
- Marking everything `__gshared` does not help; even the simplest example fails with `dlopen failed: cannot locate symbol "pthread_attr_setinheritsched"` (Android 9 and below).

#### 1. Build raylib for Android

```sh
git clone https://github.com/raysan5/raylib
cd raylib/src
make PLATFORM=PLATFORM_ANDROID \
     ANDROID_NDK=/path/to/android-ndk \
     ANDROID_ARCH=arm64 \
     ANDROID_API_VERSION=29
```

Repeat with `ANDROID_ARCH=arm` and `ANDROID_ARCH=x86_64` for the other ABIs (run `make clean` between builds), then copy each `libraylib.a` to its folder:

| `ANDROID_ARCH` | ABI folder |
|---|---|
| `arm64` | `~/.local/include/raylib-android/arm64-v8a/` |
| `arm` | `~/.local/include/raylib-android/armeabi-v7a/` |
| `x86_64` | `~/.local/include/raylib-android/x86_64/` |

#### 2. Add the template

```sh
git submodule add https://github.com/zariep-software/raylib-d-android-template.git make/android
```

#### 3. Configure paths

Edit `asetup.sh` in `make/android`:

```sh
export LDC_ANDROID_AARCH64_HOME=/home/user/ldc2-aarch64
export ANDROID_NDK_HOME=/opt/android-ndk
export RAYLIB_LIB_DIR=/home/user/raylib-android/
export ANDROID_OUTPUT_DIR=/path/to/your/apk/setup/
```

#### 4. Run the build helper

```sh
ldc -run ../make/android/build-android.d
```

Then package the project in `src/build/Android/` with Gradle. See [`raylib-d-android-template`](https://github.com/Zariep-Software/raylib-d-android-template) for details.

### WebAssembly

**Browser support:** raylib's web target is expected to need roughly Chrome 60 / Firefox 52 or newer **(untested on older browsers)**.

#### 1. Build raylib for the web

Install and activate [emsdk](https://emscripten.org/docs/getting_started/downloads.html) first so `emcc` is on your `PATH`:

```sh
git clone https://github.com/raysan5/raylib
cd raylib/src
make PLATFORM=PLATFORM_WEB -B
```


#### 2. Add the submodule

```sh
git submodule add https://github.com/Zariep-Software/raylib-d-wasm-build make/web
```

#### 3. Run the build helper

```sh
ldc -run ../make/web/build_web.d
```

See [`raylib-d-wasm-build`](https://github.com/Zariep-Software/raylib-d-wasm-build) for details.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `unknown reloc type 17` on launch (Android) | Native TLS on a device older than Android 10 | Target SDK 29+ |
| `cannot locate symbol "pthread_attr_setinheritsched"` | Android 9 or older | Same as above |
| Windows build crashes with illegal instruction on old CPU | raylib built with AVX | Rebuild with `-mno-avx` (see toolchain file) |
| raylib fails to configure with MSVC target | Missing sysroot or toolchain file | Use the custom CMake toolchain above |
| Linker can't find `raylib.lib` / `libraylib.a` | Wrong directory | Check [Directory layout](#directory-layout) and helper script paths |
| Link errors for D runtime symbols | Building without `-betterC` | Add `betterC` to `dub.json` / `dub.sdl` |
| `.wasm` fails to load in browser | Opened via `file://` | Serve over HTTP |

## Open questions

- [ ] Test builds from Windows, macOS and Termux hosts
- [ ] Can other platforms (e.g iOS, macOS or consoles like psvita be targets with cross LLVM compiling?