# raylib cmake helper for MSVC builds
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)

set(SYSROOT "$ENV{HOME}/.local/include/windows-msvc-sysroot")

set(CMAKE_C_COMPILER clang)
set(CMAKE_C_COMPILER_TARGET x86_64-windows-msvc)
set(CMAKE_AR llvm-ar)
set(CMAKE_RANLIB llvm-ranlib)
set(CMAKE_LINKER lld-link)

set(CMAKE_C_FLAGS_INIT "-fuse-ld=lld -I${SYSROOT}/include -march=x86-64 -mno-avx")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${SYSROOT}/lib/x86_64-unknown-windows-msvc")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
