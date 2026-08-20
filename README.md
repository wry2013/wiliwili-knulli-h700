# wiliwili for Knulli H700 (RG35xx Pro)

Cross-compile [wiliwili](https://github.com/xfangfang/wiliwili) (third-party Bilibili client) for Anbernic RG35xx Pro / RG35xx H / RG35xx Plus and other Allwinner H700 devices running [Knulli](https://knulli.org) CFW.

## Target hardware

| | |
|---|---|
| SoC | Allwinner H700 (4× Cortex-A53 @ 1.5GHz, aarch64) |
| GPU | Mali G31 MP2 (OpenGL ES 3.2, fbdev) |
| RAM | 1 GB LPDDR4 |
| Screen | 640×480 IPS (4:3) |
| Kernel | Linux 4.9.170 (Allwinner BSP, **no DRM/KMS**, fbdev only) |
| Video decode | **Software only** (V4L2 mem2mem not enabled in H700 kernel) |

## Build with GitHub Actions (no local Linux needed)

1. Fork this repository to your GitHub account
2. Push the code to your fork
3. Go to **Actions** tab → select **Build wiliwili for Knulli H700** → click **Run workflow**
4. Wait ~30-60 minutes for the build to complete
5. Download the `wiliwili-knulli-h700` artifact from the workflow run page

The artifact contains `wiliwili.sh` and `wiliwili/` ready to copy to your device.

## Build locally (Linux/WSL)

A Linux x86_64 host with:
- gcc/clang, make, cmake, meson, ninja
- wget, git, pkg-config
- Python 3 (for meson)

On Ubuntu/Debian:
```bash
sudo apt install build-essential cmake meson ninja-build wget git pkg-config python3
```

## Quick start

```bash
# 1. Download and install the Knulli H700 cross toolchain
make toolchain

# 2. Inspect the sysroot (check for Mali GLES/EGL, SDL2, ALSA)
make check

# 3. Download all dependency sources
make download

# 4. Build all dependencies (openssl, curl, libwebp, fribidi, harfbuzz, libass, ffmpeg, mpv, SDL2)
make deps

# 5. Build wiliwili
make wiliwili

# 6. Package as PortMaster port
make pkg
```

## Installation on device

Copy the packaged files to your SD card:

```
/userdata/roms/ports/
├── wiliwili.sh          # launch script
└── wiliwili/
    ├── wiliwili         # executable
    ├── resources/       # fonts, icons, translations
    ├── config/
    │   ├── mpv.conf     # mpv config (low-quality decode, cache)
    │   └── settings.json
    └── ssl/             # CA certificates
```

Then restart EmulationStation or refresh the games list. wiliwili will appear under **Ports**.

## Configuration notes

- **Software decoding**: The H700 Knulli kernel does not enable V4L2 mem2mem drivers, so hardware video decoding is not available. The build uses pure software decoding. With "low-quality decoding" enabled, 720P H.264 should play smoothly on Cortex-A53.
- **Graphics**: Mali G31 provides OpenGL ES 3.2 through the binary blob on fbdev. SDL2 is built with the fbcon video driver and EGL/GLES2 support.
- **Screen**: Default settings use 0.85 interface scale and 720P max quality for the 640×480 display.
- **Controller**: Built-in gamepad mapping is included in the launch script (Deeplay-keys).

## Project structure

```
.
├── Makefile                 # Main build file
├── knulli-h700.cmake        # CMake toolchain file
├── knulli-h700.ini.in       # Meson cross file template
├── wiliwili.sh              # PortMaster launch script
├── wiliwili_settings.json   # Default settings for 640×480
├── patches/                 # Patches (if needed)
├── download/                # Downloaded source tarballs
├── build/                   # Build directory
│   ├── aarch64-buildroot-linux-gnu_sdk-buildroot/  # Toolchain
│   ├── out/                 # Installed dependencies
│   └── wiliwili/            # wiliwili source
└── pkg/                     # Packaged PortMaster port
```

## Troubleshooting

### Black screen / no UI
- Check that Mali G31 EGL libraries exist in the sysroot (`make check`)
- Try GLES2 instead of GLES3: change `-DUSE_GLES3=ON` to `-DUSE_GLES2=ON` in the Makefile
- Verify `/dev/fb0` exists on the device

### Controller not working
- Check `dmesg` for input device detection
- Try different SDL_GAMECONTROLLERCONFIG strings
- Place a custom `gamecontrollerdb.txt` in the wiliwili config directory

### Video stutters
- Lower max quality to 480P in settings
- Ensure "low-quality decoding" is enabled
- Check CPU governor is set to performance

### Network errors
- Ensure Wi-Fi is connected in Knulli settings
- Check system time is correct (TLS)
- Try disabling TLS verification in wiliwili settings

## Credits

- [xfangfang/wiliwili](https://github.com/xfangfang/wiliwili) - original project
- [dragonflylee/trimui-port](https://github.com/dragonflylee/trimui-port) - Trimui Smart Pro / Knulli port reference
- [knulli-cfw](https://github.com/knulli-cfw) - Knulli CFW and cross toolchain
