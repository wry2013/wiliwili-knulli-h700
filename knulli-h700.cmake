# CMake toolchain file for cross-compiling to Knulli H700 (Allwinner H700, Mali G31, aarch64)
# Based on trimui-port/trimui.cmake, adapted for Knulli Buildroot SDK

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Toolchain prefix and root (override via -DTOOLCHAIN=/path if needed)
if(NOT DEFINED TOOLCHAIN)
    set(TOOLCHAIN $ENV{XTOOL})
endif()
if(NOT DEFINED TARGET)
    set(TARGET $ENV{XHOST})
endif()

set(CMAKE_C_COMPILER   ${TOOLCHAIN}/bin/${TARGET}-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN}/bin/${TARGET}-g++)
set(CMAKE_AR           ${TOOLCHAIN}/bin/${TARGET}-ar CACHE FILEPATH "" FORCE)
set(CMAKE_RANLIB       ${TOOLCHAIN}/bin/${TARGET}-ranlib CACHE FILEPATH "" FORCE)
set(CMAKE_STRIP        ${TOOLCHAIN}/bin/${TARGET}-strip CACHE FILEPATH "" FORCE)

set(CMAKE_SYSROOT ${TOOLCHAIN}/${TARGET}/sysroot)
set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# H700 is Cortex-A53 (aarch64). NOTE: do NOT pass -mfpu here — that option is
# only valid for 32-bit ARM (AArch32); on aarch64 NEON is part of the base ISA
# and -mfpu is rejected by the compiler ("unrecognized command-line option").
set(ARCH_FLAGS "-march=armv8-a -mtune=cortex-a53")
set(CMAKE_C_FLAGS_INIT   "${ARCH_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${ARCH_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${ARCH_FLAGS}")
