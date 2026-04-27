#!/usr/bin/env bash
#
# Compile LTESniffer with the supported toolchain.
#
# LTESniffer (vendored srsRAN + FALCON) does not build cleanly on gcc 12+;
# pin to gcc-11 / g++-11 explicitly. This script follows the README flow:
#   mkdir build && cd build && cmake .. && make
# but verifies the compiler is installed, sets CC/CXX for the cmake configure,
# and refuses to run `make` on a build/ that was configured with a different
# compiler (which would silently produce broken artifacts).
#
# Usage:
#   ./build.sh            # configure (if needed) and build
#   ./build.sh --clean    # wipe build/ first, then configure and build
#   ./build.sh --jobs N   # override -j (defaults to $(nproc))

set -euo pipefail

REQUIRED_VER=11
CC_BIN="gcc-${REQUIRED_VER}"
CXX_BIN="g++-${REQUIRED_VER}"

JOBS="$(nproc)"
CLEAN=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)        CLEAN=1; shift ;;
        --jobs|-j)      JOBS="$2"; shift 2 ;;
        -h|--help)
            sed -n '3,15p' "$0"
            exit 0 ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Verify the pinned compiler is available.
for tool in "$CC_BIN" "$CXX_BIN"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: $tool not found in PATH." >&2
        echo "  Install with: sudo apt install ${CC_BIN} ${CXX_BIN}" >&2
        exit 1
    fi
done

CC_PATH="$(command -v "$CC_BIN")"
CXX_PATH="$(command -v "$CXX_BIN")"

echo "Compiler:"
echo "  CC  = $CC_PATH ($("$CC_BIN"  -dumpfullversion 2>/dev/null || "$CC_BIN"  --version | head -1))"
echo "  CXX = $CXX_PATH ($("$CXX_BIN" -dumpfullversion 2>/dev/null || "$CXX_BIN" --version | head -1))"
echo

# 2. Wipe build/ if asked.
if [[ "$CLEAN" -eq 1 && -d build ]]; then
    echo "--clean: removing existing build/"
    rm -rf build
fi

# 3. Configure (only if no cache yet) or sanity-check the cached compiler.
mkdir -p build
cd build

if [[ ! -f CMakeCache.txt ]]; then
    echo "Configuring with cmake..."
    CC="$CC_PATH" CXX="$CXX_PATH" cmake ..
else
    cached_cc="$(grep '^CMAKE_C_COMPILER:'   CMakeCache.txt | cut -d= -f2)"
    cached_cxx="$(grep '^CMAKE_CXX_COMPILER:' CMakeCache.txt | cut -d= -f2)"
    if [[ "$cached_cc" != "$CC_PATH" || "$cached_cxx" != "$CXX_PATH" ]]; then
        echo "Error: build/ is configured with a different compiler:" >&2
        echo "  cached CC  = $cached_cc"  >&2
        echo "  cached CXX = $cached_cxx" >&2
        echo "  expected   = $CC_PATH / $CXX_PATH" >&2
        echo "Re-run with --clean to wipe and reconfigure." >&2
        exit 1
    fi
fi

# 4. Build.
echo "Building with -j${JOBS}..."
make -j"${JOBS}"

echo
echo "Built: $(realpath src/LTESniffer)"
