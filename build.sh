#!/bin/bash
# Quick setup and build script for wiliwili on Knulli H700
# Run this inside WSL Ubuntu or any Linux x86_64 environment
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo " wiliwili for Knulli H700 - Build Script"
echo "============================================"

# ─── Install host dependencies ────────────────────────────────────────────────

if command -v apt-get &>/dev/null; then
    echo ">>> Installing host build dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        build-essential cmake meson ninja-build \
        wget git pkg-config python3 \
        nasm yasm \
        libssl-dev 2>/dev/null
elif command -v dnf &>/dev/null; then
    echo ">>> Installing host build dependencies..."
    sudo dnf install -y \
        @development-tools cmake meson ninja-build \
        wget git pkg-config python3 openssl-devel
elif command -v pacman &>/dev/null; then
    echo ">>> Installing host build dependencies..."
    sudo pacman -S --needed --noconfirm \
        base-devel cmake meson ninja wget git pkgconf python3 openssl
else
    echo "!!! Could not detect package manager."
    echo "    Please install: cmake meson ninja-build wget git pkg-config python3"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# ─── Build ────────────────────────────────────────────────────────────────────

echo ""
echo ">>> Step 1/5: Downloading and installing Knulli H700 toolchain..."
make toolchain

echo ""
echo ">>> Step 2/5: Inspecting sysroot..."
make check

echo ""
echo ">>> Step 3/5: Downloading dependency sources..."
make download

echo ""
echo ">>> Step 4/5: Building dependencies and wiliwili..."
make deps
make wiliwili

echo ""
echo ">>> Step 5/5: Packaging PortMaster port..."
make pkg

echo ""
echo "============================================"
echo " Build complete!"
echo "============================================"
echo ""
echo "The PortMaster package is in: pkg/"
echo ""
echo "To install on your RG35xx Pro:"
echo "  1. Copy pkg/wiliwili.sh and pkg/wiliwili/ to your SD card's"
echo "     /userdata/roms/ports/ directory"
echo "  2. Restart EmulationStation or refresh games list"
echo "  3. Launch wiliwili from the Ports section"
echo ""
