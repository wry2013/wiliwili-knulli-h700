#!/bin/bash
# wiliwili launch script for Knulli on RG35xx Pro (H700)
# PortMaster-compatible launch script
#
# Installation:
#   Place this file and the wiliwili/ directory in:
#   /userdata/roms/ports/
#
#   So you have:
#   /userdata/roms/ports/wiliwili.sh
#   /userdata/roms/ports/wiliwili/wiliwili
#   /userdata/roms/ports/wiliwili/resources/
#   /userdata/roms/ports/wiliwili/config/

# Determine script directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

cd "$DIR/wiliwili"

# ─── Environment setup ────────────────────────────────────────────────────────

# Home directory for config/cache
export HOME="$DIR/wiliwili"

# Audio: ALSA (Knulli uses PipeWire with ALSA compatibility)
export SDL_AUDIODRIVER=alsa

# Video: framebuffer (H700 kernel has no DRM/KMS)
export SDL_VIDEODRIVER=fbcon
export SDL_FBDEV=/dev/fb0

# ─── Controller mapping ───────────────────────────────────────────────────────
# RG35xx Pro / RG35xx H controller mapping (Deeplay-keys)
# This covers the built-in gamepad on Anbernic RG35xx H700 devices
export SDL_GAMECONTROLLERCONFIG="19000000010000000100000000010000,Deeplay-keys,a:b3,b:b4,x:b6,y:b5,leftshoulder:b7,rightshoulder:b8,lefttrigger:b13,righttrigger:b14,guide:b11,start:b10,back:b9,dpup:h0.1,dpleft:h0.8,dpright:h0.2,dpdown:h0.4,volumedown:b1,volumeup:b2,leftx:a0,lefty:a1,leftstick:b12,rightx:a2,righty:a3,rightstick:b15,platform:Linux,"

# ─── Performance / system ─────────────────────────────────────────────────────

# Limit CPU governor to performance for smoother video playback
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
fi

# ─── Launch ───────────────────────────────────────────────────────────────────

./wiliwili "$@"

# ─── Cleanup ──────────────────────────────────────────────────────────────────

# Restore CPU governor
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo schedutil > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
fi
