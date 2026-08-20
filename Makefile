# Makefile for cross-compiling wiliwili to Knulli H700 (Allwinner H700, Mali G31, aarch64)
# Based on dragonflylee/trimui-port Makefile.knulli, adapted for Knulli Buildroot SDK
#
# Usage:
#   make toolchain    # Download and install Knulli H700 cross toolchain
#   make check        # Inspect sysroot for available libraries
#   make download     # Download all dependency sources
#   make deps         # Build all dependencies (openssl curl webp ass ffmpeg mpv sdl2)
#   make wiliwili     # Build wiliwili
#   make all          # Build everything
#   make pkg          # Package as PortMaster port
#   make clean        # Clean build directory

# ─── Configuration ────────────────────────────────────────────────────────────

# Knulli H700 toolchain
TC_URL    := https://github.com/knulli-cfw/toolchains/releases/download/rg35xx-plush-sdk-20240421/aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz
TC_TARBALL := aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz
TC_DIR    := aarch64-buildroot-linux-gnu_sdk-buildroot
TARGET    := aarch64-buildroot-linux-gnu

# Directories
ROOT      := $(CURDIR)
TOOLCHAIN := $(ROOT)/$(TC_DIR)
SYSROOT   := $(TOOLCHAIN)/$(TARGET)/sysroot
PREFIX    := $(ROOT)/build/out
BUILD     := $(ROOT)/build
TMPDIR    := $(ROOT)/build/tmp
DOWNLOAD  := $(ROOT)/download

# ─── Toolchain binaries ───────────────────────────────────────────────────────

# NOTE: append (not prepend) toolchain bin to PATH so that host tools
# (perl, python3, make, pkg-config) from the runner take precedence.
# The SDK ships its own perl with compiled-in @INC pointing at the
# original build path (/h700/host/...) which relocate-sdk.sh does not
# fix, so using it breaks openssl's Configure and other perl scripts.
# Cross tools have the $(TARGET)- prefix and are still found.
export PATH          := $(PATH):$(TOOLCHAIN)/bin

# NOTE: do NOT export CC/CXX/AR/RANLIB/STRIP here.  Each dependency
# specifies its cross-compiler via its own mechanism:
#   - openssl:  --cross-compile-prefix=$(TARGET)-
#   - curl/libass: --host=$(TARGET)
#   - ffmpeg:   --cross-prefix=$(TARGET)-
#   - cmake:    CMAKE_TOOLCHAIN_FILE
#   - meson:    cross file (knulli-h700.ini)
# Exporting CC *and* passing --cross-compile-prefix causes the prefix
# to be doubled: aarch64-buildroot-linux-gnu-aarch64-buildroot-linux-gnu-gcc

# Consumed by knulli-h700.cmake ($ENV{XTOOL}/$ENV{XHOST}).  These are plain
# paths/names, not compiler vars, so exporting them cannot double prefixes.
export XTOOL         := $(TOOLCHAIN)
export XHOST         := $(TARGET)

STRIP                := $(TOOLCHAIN)/bin/$(TARGET)-strip

export CFLAGS        := -march=armv8-a -mtune=cortex-a53 -O2 -fPIC
export CXXFLAGS      := -march=armv8-a -mtune=cortex-a53 -O2 -fPIC
export PKG_CONFIG_PATH := $(PREFIX)/lib/pkgconfig:$(SYSROOT)/usr/lib/pkgconfig
export PKG_CONFIG_SYSROOT_DIR := $(SYSROOT)

CMAKE_TOOLCHAIN := $(ROOT)/knulli-h700.cmake

# ─── Dependency versions ──────────────────────────────────────────────────────

OPENSSL_VER  := 1.1.1q
CURL_VER     := 7.85.0
LIBWEBP_VER  := 1.3.0
FRIBIDI_VER  := 1.0.12
HARFBUZZ_VER := 4.2.1
LIBASS_VER   := 0.17.0
FFMPEG_VER   := 4.4.1
MPV_VER      := 0.36.0
SDL2_VER     := 2.28.1
WILIWILI_VER := v1.6.0

# ─── Download URLs ────────────────────────────────────────────────────────────

OPENSSL_URL  := https://www.openssl.org/source/old/1.1.1/openssl-$(OPENSSL_VER).tar.gz
CURL_URL     := https://curl.se/download/curl-$(CURL_VER).tar.gz
LIBWEBP_URL  := https://github.com/webmproject/libwebp/archive/refs/tags/v$(LIBWEBP_VER).tar.gz
FRIBIDI_URL  := https://github.com/fribidi/fribidi/releases/download/v$(FRIBIDI_VER)/fribidi-$(FRIBIDI_VER).tar.xz
HARFBUZZ_URL := https://github.com/harfbuzz/harfbuzz/archive/refs/tags/$(HARFBUZZ_VER).tar.gz
LIBASS_URL   := https://github.com/libass/libass/releases/download/$(LIBASS_VER)/libass-$(LIBASS_VER).tar.gz
FFMPEG_URL   := https://ffmpeg.org/releases/ffmpeg-$(FFMPEG_VER).tar.bz2
MPV_URL      := https://github.com/mpv-player/mpv/archive/refs/tags/v$(MPV_VER).tar.gz
SDL2_URL     := https://github.com/libsdl-org/SDL/archive/refs/tags/release-$(SDL2_VER).tar.gz
WILIWILI_URL := https://github.com/xfangfang/wiliwili.git

# ─── Phony targets ────────────────────────────────────────────────────────────

.PHONY: all toolchain check download deps openssl curl webp ass ffmpeg mpv sdl2 wiliwili pkg clean

all: deps wiliwili pkg

# ─── Toolchain ────────────────────────────────────────────────────────────────

toolchain: $(TOOLCHAIN)/.installed

$(TOOLCHAIN)/.installed:
	@echo ">>> Downloading Knulli H700 toolchain..."
	mkdir -p $(BUILD)
	cd $(BUILD) && wget -q --show-progress -c $(TC_URL)
	@echo ">>> Extracting toolchain..."
	cd $(ROOT) && tar xzf $(BUILD)/$(TC_TARBALL)
	@echo ">>> Relocating SDK..."
	cd $(TOOLCHAIN) && ./relocate-sdk.sh
	touch $@
	@echo ">>> Toolchain installed at $(TOOLCHAIN)"

# ─── Inspect sysroot ──────────────────────────────────────────────────────────

check:
	@echo "=== Sysroot: $(SYSROOT) ==="
	@echo ""
	@echo "--- GLES/EGL libraries ---"
	@ls -la $(SYSROOT)/usr/lib/libGLES* $(SYSROOT)/usr/lib/libEGL* $(SYSROOT)/usr/lib/libmali* 2>/dev/null || echo "  (not found)"
	@echo ""
	@echo "--- GLES/EGL headers ---"
	@ls $(SYSROOT)/usr/include/GLES3/ $(SYSROOT)/usr/include/EGL/ 2>/dev/null || echo "  (not found)"
	@echo ""
	@echo "--- SDL2 ---"
	@ls $(SYSROOT)/usr/lib/libSDL2* $(SYSROOT)/usr/lib/pkgconfig/sdl2.pc 2>/dev/null || echo "  (not found)"
	@echo ""
	@echo "--- ALSA ---"
	@ls $(SYSROOT)/usr/lib/libasound* $(SYSROOT)/usr/lib/pkgconfig/alsa.pc 2>/dev/null || echo "  (not found)"
	@echo ""
	@echo "--- libdrm / gbm ---"
	@ls $(SYSROOT)/usr/lib/libdrm* $(SYSROOT)/usr/lib/libgbm* 2>/dev/null || echo "  (not found)"
	@echo ""
	@echo "--- Other useful libs ---"
	@ls $(SYSROOT)/usr/lib/libz* $(SYSROOT)/usr/lib/libbz2* $(SYSROOT)/usr/lib/libpthread* 2>/dev/null || true
	@echo ""
	@echo "--- Kernel headers (video) ---"
	@ls $(SYSROOT)/usr/include/linux/videodev2.h 2>/dev/null && echo "  V4L2 headers: present" || echo "  V4L2 headers: not found"
	@echo ""
	@echo "--- Compiler version ---"
	@$(TARGET)-gcc --version 2>/dev/null | head -1 || echo "  Toolchain not installed. Run 'make toolchain' first."

# ─── Download sources ─────────────────────────────────────────────────────────

download:
	@echo ">>> Downloading dependency sources..."
	mkdir -p $(DOWNLOAD)
	cd $(DOWNLOAD) && \
	[ -f openssl-$(OPENSSL_VER).tar.gz ]  || wget -q --show-progress $(OPENSSL_URL) && \
	[ -f curl-$(CURL_VER).tar.gz ]       || wget -q --show-progress $(CURL_URL) && \
	[ -f libwebp-$(LIBWEBP_VER).tar.gz ] || wget -q --show-progress $(LIBWEBP_URL) -O libwebp-$(LIBWEBP_VER).tar.gz && \
	[ -f fribidi-$(FRIBIDI_VER).tar.xz ] || wget -q --show-progress $(FRIBIDI_URL) && \
	[ -f harfbuzz-$(HARFBUZZ_VER).tar.gz ] || wget -q --show-progress $(HARFBUZZ_URL) -O harfbuzz-$(HARFBUZZ_VER).tar.gz && \
	[ -f libass-$(LIBASS_VER).tar.gz ]   || wget -q --show-progress $(LIBASS_URL) && \
	[ -f ffmpeg-$(FFMPEG_VER).tar.bz2 ]  || wget -q --show-progress $(FFMPEG_URL) && \
	[ -f mpv-$(MPV_VER).tar.gz ]         || wget -q --show-progress $(MPV_URL) -O mpv-$(MPV_VER).tar.gz && \
	[ -f SDL-$(SDL2_VER).tar.gz ]        || wget -q --show-progress $(SDL2_URL) -O SDL-$(SDL2_VER).tar.gz
	@if [ ! -d $(BUILD)/wiliwili ]; then \
		echo ">>> Cloning wiliwili ($(WILIWILI_VER))..."; \
		git clone --depth 1 --branch $(WILIWILI_VER) --recursive $(WILIWILI_URL) $(BUILD)/wiliwili; \
	fi
	@echo ">>> All sources ready."

# ─── Extract helper ───────────────────────────────────────────────────────────

define extract
	@mkdir -p $(BUILD) $(TMPDIR)
	@if [ ! -d $(BUILD)/$(1) ]; then \
		echo ">>> Extracting $(1)..."; \
		tar xf $(DOWNLOAD)/$(2) -C $(TMPDIR); \
		mv $(TMPDIR)/$(1) $(BUILD)/$(1); \
	fi
endef

# ─── OpenSSL ──────────────────────────────────────────────────────────────────

openssl: $(PREFIX)/lib/libssl.a

$(PREFIX)/lib/libssl.a: $(TOOLCHAIN)/.installed
	$(call extract,openssl-$(OPENSSL_VER),openssl-$(OPENSSL_VER).tar.gz)
	@echo ">>> Building OpenSSL $(OPENSSL_VER)..."
	cd $(BUILD)/openssl-$(OPENSSL_VER) && \
	./Configure linux-aarch64 no-shared no-tests \
		--prefix=$(PREFIX) \
		--cross-compile-prefix=$(TARGET)- && \
	$(MAKE) -j$$(nproc) && \
	$(MAKE) install_sw

# ─── curl ─────────────────────────────────────────────────────────────────────

curl: $(PREFIX)/lib/libcurl.a

$(PREFIX)/lib/libcurl.a: $(PREFIX)/lib/libssl.a
	$(call extract,curl-$(CURL_VER),curl-$(CURL_VER).tar.gz)
	@echo ">>> Building curl $(CURL_VER)..."
	cd $(BUILD)/curl-$(CURL_VER) && \
	./configure --prefix=$(PREFIX) \
		--host=$(TARGET) \
		--build=x86_64-linux-gnu \
		--disable-shared --enable-static \
		--disable-debug --enable-optimize \
		--disable-werror \
		--with-ssl=$(PREFIX) \
		--without-zlib \
		--without-brotli \
		--without-zstd \
		--without-nghttp2 \
		--without-libidn2 \
		--without-librtmp \
		--without-libpsl \
		--without-libgsasl \
		--disable-ldap --disable-ldaps \
		--disable-rtsp --disable-dict --disable-telnet \
		--disable-tftp --disable-pop3 --disable-imap \
		--disable-smb --disable-gopher --disable-manual \
		--disable-file --disable-ftp && \
	$(MAKE) -j$$(nproc) && \
	$(MAKE) install

# ─── libwebp ──────────────────────────────────────────────────────────────────

webp: $(PREFIX)/lib/libwebp.a

$(PREFIX)/lib/libwebp.a: $(TOOLCHAIN)/.installed
	$(call extract,libwebp-$(LIBWEBP_VER),libwebp-$(LIBWEBP_VER).tar.gz)
	@echo ">>> Building libwebp $(LIBWEBP_VER)..."
	cd $(BUILD)/libwebp-$(LIBWEBP_VER) && \
	cmake -B build -G Ninja \
		-DCMAKE_TOOLCHAIN_FILE=$(CMAKE_TOOLCHAIN) \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DBUILD_SHARED_LIBS=OFF \
		-DWEBP_BUILD_CWEBP=OFF \
		-DWEBP_BUILD_DWEBP=OFF \
		-DWEBP_BUILD_GIF2WEBP=OFF \
		-DWEBP_BUILD_IMG2WEBP=OFF \
		-DWEBP_BUILD_VWEBP=OFF \
		-DWEBP_BUILD_WEBPINFO=OFF \
		-DWEBP_BUILD_WEBPMUX=OFF \
		-DWEBP_BUILD_EXTRAS=OFF && \
	cmake --build build -j$$(nproc) && \
	cmake --install build

# ─── fribidi + harfbuzz + libass ──────────────────────────────────────────────

ass: $(PREFIX)/lib/libass.a

$(PREFIX)/lib/libfribidi.a: $(TOOLCHAIN)/.installed $(ROOT)/knulli-h700.ini
	$(call extract,fribidi-$(FRIBIDI_VER),fribidi-$(FRIBIDI_VER).tar.xz)
	@echo ">>> Building fribidi $(FRIBIDI_VER)..."
	cd $(BUILD)/fribidi-$(FRIBIDI_VER) && \
	meson setup build --cross-file=$(ROOT)/knulli-h700.ini --default-library=static --prefix=$(PREFIX) \
		-Ddocs=false -Dtests=false -Dbin=false && \
	meson compile -C build -j$$(nproc) && \
	meson install -C build

$(PREFIX)/lib/libharfbuzz.a: $(PREFIX)/lib/libfribidi.a
	$(call extract,harfbuzz-$(HARFBUZZ_VER),harfbuzz-$(HARFBUZZ_VER).tar.gz)
	@echo ">>> Building harfbuzz $(HARFBUZZ_VER)..."
	cd $(BUILD)/harfbuzz-$(HARFBUZZ_VER) && \
	meson setup build --cross-file=$(ROOT)/knulli-h700.ini --default-library=static --prefix=$(PREFIX) \
		-Dtests=disabled -Ddocs=disabled -Dbenchmark=disabled \
		-Dicu=disabled -Dglib=disabled -Dgobject=disabled \
		-Dcairo=disabled -Dfontconfig=disabled -Dfreetype=disabled && \
	meson compile -C build -j$$(nproc) && \
	meson install -C build

$(PREFIX)/lib/libass.a: $(PREFIX)/lib/libfribidi.a $(PREFIX)/lib/libharfbuzz.a
	$(call extract,libass-$(LIBASS_VER),libass-$(LIBASS_VER).tar.gz)
	@echo ">>> Building libass $(LIBASS_VER)..."
	cd $(BUILD)/libass-$(LIBASS_VER) && \
	./configure --prefix=$(PREFIX) \
		--host=$(TARGET) \
		--build=x86_64-linux-gnu \
		--disable-shared --enable-static \
		--disable-require-system-font-provider \
		FREETYPE_CFLAGS="-I$(SYSROOT)/usr/include/freetype2" \
		FREETYPE_LIBS="-lfreetype" \
		FRIBIDI_CFLAGS="-I$(PREFIX)/include/fribidi" \
		FRIBIDI_LIBS="-L$(PREFIX)/lib -lfribidi" \
		HARFBUZZ_CFLAGS="-I$(PREFIX)/include/harfbuzz" \
		HARFBUZZ_LIBS="-L$(PREFIX)/lib -lharfbuzz -lfribidi" && \
	$(MAKE) -j$$(nproc) && \
	$(MAKE) install

# ─── FFmpeg (software decoding only, no V4L2-request) ─────────────────────────

ffmpeg: $(PREFIX)/lib/libavcodec.a

$(PREFIX)/lib/libavcodec.a: $(PREFIX)/lib/libssl.a
	$(call extract,ffmpeg-$(FFMPEG_VER),ffmpeg-$(FFMPEG_VER).tar.bz2)
	@echo ">>> Building FFmpeg $(FFMPEG_VER) (software decode only)..."
	cd $(BUILD)/ffmpeg-$(FFMPEG_VER) && \
	./configure --prefix=$(PREFIX) \
		--enable-cross-compile \
		--cross-prefix=$(TARGET)- \
		--arch=aarch64 --cpu=cortex-a53 \
		--target-os=linux \
		--sysroot=$(SYSROOT) \
		--disable-doc \
		--disable-debug \
		--disable-ffplay \
		--disable-ffprobe \
		--disable-ffmpeg \
		--disable-shared --enable-static \
		--enable-small \
		--enable-gpl \
		--enable-openssl \
		--with-ssl=$(PREFIX) \
		--disable-sdl2 \
		--disable-xlib \
		--disable-libxcb \
		--disable-libxcb-shm \
		--disable-libxcb-xfixes \
		--disable-libxcb-shape \
		--disable-vdpau \
		--disable-vaapi \
		--disable-videotoolbox \
		--disable-audiotoolbox \
		--disable-v4l2-m2m \
		--extra-cflags="-I$(PREFIX)/include" \
		--extra-ldflags="-L$(PREFIX)/lib" && \
	$(MAKE) -j$$(nproc) && \
	$(MAKE) install

# ─── mpv (GLES3 rendering, software decode) ───────────────────────────────────

mpv: $(PREFIX)/lib/libmpv.a

$(PREFIX)/lib/libmpv.a: $(PREFIX)/lib/libavcodec.a $(PREFIX)/lib/libass.a $(ROOT)/knulli-h700.ini
	$(call extract,mpv-$(MPV_VER),mpv-$(MPV_VER).tar.gz)
	@echo ">>> Building mpv $(MPV_VER) (GLES3, no hwdec)..."
	cd $(BUILD)/mpv-$(MPV_VER) && \
	meson setup build --cross-file=$(ROOT)/knulli-h700.ini --default-library=static --prefix=$(PREFIX) \
		-Dlibmpv=enabled \
		-Dplayer=disabled \
		-Dcplayer=false \
		-Dbuild-date=disabled \
		-Dtests=disabled \
		-Dta-leak-report=disabled \
		-Dglib=disabled \
		-Dlua=disabled \
		-Djavascript=disabled \
		-Dzimg=disabled \
		-Dlcms2=disabled \
		-Dvapoursynth=disabled \
		-Dass=enabled \
		-Drubberband=disabled \
		-Dzlib=enabled \
		-Dfreetype=enabled \
		-Dfribidi=enabled \
		-Dharfbuzz=enabled \
		-Dlibavdevice=disabled \
		-Dlibavfilter=disabled \
		-Diconv=disabled \
		-Dmanpage-build=disabled \
		-Dgpl=true \
		-Dcdda=disabled \
		-Ddvdnav=disabled \
		-Ddvbin=disabled \
		-Dlibbluray=disabled \
		-Djpeg=disabled \
		-Dsdl2=disabled \
		-Dsdl2-gamepad=disabled \
		-Dsdl2-audio=disabled \
		-Dsndio=disabled \
		-Dsixel=disabled \
		-Dwayland=disabled \
		-Dx11=disabled \
		-Ddrm=disabled \
		-Dgbm=disabled \
		-Degl=enabled \
		-Dgl=enabled \
		-Dvulkan=disabled \
		-Dalsa=enabled \
		-Dpulse=disabled \
		-Dpipewire=disabled \
		-Djack=disabled \
		-Dopensles=disabled \
		-Doss-audio=disabled \
		-Daudio-encoding=false \
		-Dvideo-encoding=false \
		-Dvaapi=disabled \
		-Dvaapi-drm=disabled \
		-Dvaapi-x11=disabled \
		-Dvaapi-wayland=disabled \
		-Dvdpau=disabled \
		-Dv4l2=disabled \
		-Dvideotoolbox-gl=disabled \
		-Dd3d-hwaccel=disabled \
		-Dd3d9-hwaccel=disabled \
		-Drpi-mmal=disabled \
		-Dios-gl=disabled \
		-Dvulkan-interop=disabled \
		-Dcuda-hwaccel=disabled \
		-Dnvdec=disabled \
		-Ddxva2-hwaccel=disabled \
		-Dandroid-media-ndk=disabled \
		-Dmediafoundation=disabled \
		-Dplain-gl=enabled \
		-Dgl-x11=disabled \
		-Dgl-wayland=disabled \
		-Dgl-drm=disabled \
		-Dgl-win32=disabled \
		-Dgl-cocoa=disabled \
		-Dgl-egl=enabled \
		--wrap-mode=nofallback && \
	meson compile -C build -j$$(nproc) && \
	meson install -C build

# ─── SDL2 (fbdev + EGL + GLES2 + ALSA) ───────────────────────────────────────

sdl2: $(PREFIX)/lib/libSDL2.a

$(PREFIX)/lib/libSDL2.a: $(TOOLCHAIN)/.installed
	$(call extract,SDL-release-$(SDL2_VER),SDL-$(SDL2_VER).tar.gz)
	@echo ">>> Building SDL2 $(SDL2_VER) (fbdev + EGL + GLES2 + ALSA)..."
	cd $(BUILD)/SDL-release-$(SDL2_VER) && \
	cmake -B build -G Ninja \
		-DCMAKE_TOOLCHAIN_FILE=$(CMAKE_TOOLCHAIN) \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DSDL_SHARED=OFF \
		-DSDL_STATIC=ON \
		-DSDL_TEST=OFF \
		-DSDL_LIBC=ON \
		-DSDL_GCC_ATOMICS=ON \
		-DSDL_ALTIVEC=OFF \
		-DSDL_OSS=OFF \
		-DSDL_ALSA=ON \
		-DSDL_ALSA_SHARED=OFF \
		-DSDL_SNDIO=OFF \
		-DSDL_JACK=OFF \
		-DSDL_JACK_SHARED=OFF \
		-DSDL_ESD=OFF \
		-DSDL_NAS=OFF \
		-DSDL_SNDIO_SHARED=OFF \
		-DSDL_FUSIONSOUND=OFF \
		-DSDL_FUSIONSOUND_SHARED=OFF \
		-DSDL_PIPEWIRE=OFF \
		-DSDL_PULSEAUDIO=OFF \
		-DSDL_PULSEAUDIO_SHARED=OFF \
		-DSDL_ARTS=OFF \
		-DSDL_NDS=OFF \
		-DSDL_VIDEO=ON \
		-DSDL_RENDER=ON \
		-DSDL_EVENTS=ON \
		-DSDL_VIDEO_DRIVER_OFFSCREEN=OFF \
		-DSDL_VIDEO_DRIVER_X11=OFF \
		-DSDL_VIDEO_DRIVER_WAYLAND=OFF \
		-DSDL_VIDEO_DRIVER_KMSDRM=OFF \
		-DSDL_VIDEO_DRIVER_FBCON=ON \
		-DSDL_VIDEO_DRIVER_VIVANTE=OFF \
		-DSDL_VIDEO_DRIVER_COCOA=OFF \
		-DSDL_VIDEO_DRIVER_UIKIT=OFF \
		-DSDL_VIDEO_DRIVER_DIRECTFB=OFF \
		-DSDL_VIDEO_DRIVER_ANDROID=OFF \
		-DSDL_VIDEO_DRIVER_PSP=OFF \
		-DSDL_VIDEO_DRIVER_RPI=OFF \
		-DSDL_VIDEO_DRIVER_WINRT=OFF \
		-DSDL_VIDEO_DRIVER_HAIKU=OFF \
		-DSDL_VIDEO_DRIVER_EMSCRIPTEN=OFF \
		-DSDL_VIDEO_DRIVER_N3DS=OFF \
		-DSDL_VIDEO_DRIVER_RISCOS=OFF \
		-DSDL_VIDEO_DRIVER_MIR=OFF \
		-DSDL_VIDEO_DRIVER_WIN32=OFF \
		-DSDL_VIDEO_DRIVER_QNX=OFF \
		-DSDL_VIDEO_DRIVER_UTYPE=OFF \
		-DSDL_VIDEO_OPENGL=ON \
		-DSDL_VIDEO_OPENGL_ES=ON \
		-DSDL_VIDEO_OPENGL_ES2=ON \
		-DSDL_VIDEO_OPENGL_EGL=ON \
		-DSDL_VIDEO_OPENGL_GLX=OFF \
		-DSDL_VIDEO_OPENGL_OSMESA=OFF \
		-DSDL_VIDEO_VULKAN=OFF \
		-DSDL_VIDEO_METAL=OFF \
		-DSDL_JOYSTICK=ON \
		-DSDL_HAPTIC=ON \
		-DSDL_HIDAPI=ON \
		-DSDL_POWER=ON \
		-DSDL_FILE=ON \
		-DSDL_FILESYSTEM=ON \
		-DSDL_TIMERS=ON \
		-DSDL_HAPTIC=ON \
		-DSDL_SENSOR=OFF \
		-DSDL_LOCALE=ON \
		-DSDL_MISC=ON && \
	cmake --build build -j$$(nproc) && \
	cmake --install build

# ─── Build all dependencies ──────────────────────────────────────────────────

deps: download openssl curl webp ass ffmpeg mpv sdl2
	@echo ">>> All dependencies built successfully."

# ─── Generate meson cross file ───────────────────────────────────────────────

$(ROOT)/knulli-h700.ini: $(ROOT)/knulli-h700.ini.in
	@sed -e 's|@TOOLCHAIN@|$(TOOLCHAIN)|g' \
	     -e 's|@TARGET@|$(TARGET)|g' \
	     -e 's|@SYSROOT@|$(SYSROOT)|g' \
	     $< > $@

# ─── wiliwili ─────────────────────────────────────────────────────────────────

wiliwili: $(PREFIX)/lib/libmpv.a $(PREFIX)/lib/libSDL2.a $(PREFIX)/lib/libcurl.a $(PREFIX)/lib/libwebp.a $(ROOT)/knulli-h700.ini
	@if [ ! -d $(BUILD)/wiliwili ]; then \
		echo ">>> Cloning wiliwili..."; \
		git clone --depth 1 --branch $(WILIWILI_VER) --recursive $(WILIWILI_URL) $(BUILD)/wiliwili; \
	fi
	@echo ">>> Building wiliwili..."
	cd $(BUILD)/wiliwili && \
	cmake -B cmake-build -G Ninja \
		-DCMAKE_TOOLCHAIN_FILE=$(CMAKE_TOOLCHAIN) \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DPLATFORM_DESKTOP=ON \
		-DUSE_SYSTEM_CURL=ON \
		-DUSE_SYSTEM_SDL2=ON \
		-DMPV_NO_FB=ON \
		-DUSE_SDL2=ON \
		-DUSE_GLES3=ON \
		-DCMAKE_CXX_FLAGS="-DKNULLI_H700 -I$(PREFIX)/include" \
		-DCMAKE_EXE_LINKER_FLAGS="-L$(PREFIX)/lib" && \
	cmake --build cmake-build -j$$(nproc)
	@echo ">>> wiliwili built: $(BUILD)/wiliwili/cmake-build/wiliwili"

# ─── Package as PortMaster port ──────────────────────────────────────────────

pkg: wiliwili
	@echo ">>> Packaging PortMaster port..."
	rm -rf $(ROOT)/pkg/wiliwili
	mkdir -p $(ROOT)/pkg/wiliwili
	cp $(BUILD)/wiliwili/cmake-build/wiliwili $(ROOT)/pkg/wiliwili/
	cp -r $(BUILD)/wiliwili/resources $(ROOT)/pkg/wiliwili/
	cp $(ROOT)/wiliwili.sh $(ROOT)/pkg/
	# Bundle CA certificates
	cp -r $(PREFIX)/ssl $(ROOT)/pkg/wiliwili/ssl 2>/dev/null || true
	# Strip binary
	$(STRIP) $(ROOT)/pkg/wiliwili/wiliwili 2>/dev/null || true
	# Create mpv.conf with software decoding defaults
	mkdir -p $(ROOT)/pkg/wiliwili/config
	echo 'vd-lavc-skiploopfilter=all' > $(ROOT)/pkg/wiliwili/config/mpv.conf
	echo 'vd-lavc-fast=yes' >> $(ROOT)/pkg/wiliwili/config/mpv.conf
	echo 'cache=yes' >> $(ROOT)/pkg/wiliwili/config/mpv.conf
	echo 'demuxer-max-bytes=10MiB' >> $(ROOT)/pkg/wiliwili/config/mpv.conf
	# Create wiliwili settings for 640x480 screen
	cp $(ROOT)/wiliwili_settings.json $(ROOT)/pkg/wiliwili/config/settings.json 2>/dev/null || true
	@echo ">>> Package ready in $(ROOT)/pkg/"
	@echo ">>> Copy pkg/wiliwili.sh and pkg/wiliwili/ to /userdata/roms/ports/ on your device"

# ─── Clean ────────────────────────────────────────────────────────────────────

clean:
	rm -rf $(BUILD) $(PREFIX) $(ROOT)/knulli-h700.ini
	@echo ">>> Build cleaned (toolchain and downloads preserved)"

clean-all: clean
	rm -rf $(TOOLCHAIN) $(DOWNLOAD)
	@echo ">>> Everything cleaned"
