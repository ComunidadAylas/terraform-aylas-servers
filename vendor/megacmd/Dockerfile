# Use a similar base image to our production environment to guarantee e.g.
# compatible versions of OpenSSL
FROM ubuntu:noble

ARG MEGACMD_VERSION=1.7.0_Linux
ARG MEGACMD_PKG_VERSION=1.7.0

ARG DEBIAN_FRONTEND=noninteractive

RUN echo 'deb [arch=arm64] http://ports.ubuntu.com/ noble main multiverse universe' >> /etc/apt/sources.list
RUN echo 'deb [arch=arm64] http://ports.ubuntu.com/ noble-security main multiverse universe' >> /etc/apt/sources.list
RUN echo 'deb [arch=arm64] http://ports.ubuntu.com/ noble-backports main multiverse universe' >> /etc/apt/sources.list
RUN echo 'deb [arch=arm64] http://ports.ubuntu.com/ noble-updates main multiverse universe' >> /etc/apt/sources.list
RUN apt-get update && \
	dpkg --add-architecture arm64 && \
	apt-get install -yq \
		git autoconf crossbuild-essential-arm64 checkinstall libtool \
		libcrypto++-dev:arm64 libz-dev:arm64 libsqlite3-dev:arm64 libssl-dev:arm64 libcurl4-gnutls-dev:arm64 \
		libreadline-dev:arm64 libpcre3-dev:arm64 libsodium-dev:arm64 libc-ares-dev:arm64 libicu-dev:arm64 libuv1-dev:arm64 && \
	git clone --recurse-submodules https://github.com/meganz/MEGAcmd.git /MEGAcmd && \
	git -C /MEGAcmd checkout ${MEGACMD_VERSION}

# Configuring with disabled features is necessary to build for updated systems:
# https://github.com/meganz/sdk/issues/2576
# It also is good to get rid of unnecessary cruft for our purposes.
# The package metadata was mostly copied from the closest official binary package
# at https://mega.nz/linux/repo/Debian_11/armhf/megacmd_1.5.0-8.1_armhf.deb
# The latest MEGA SDK version dropped autotools (./configure) support, but an older
# version of it with such support is still used by MEGAcmd, and many build configuration
# are inherited from it. For more information about those, see the last commit with them:
# https://github.com/meganz/sdk/commit/0f280214173bd903f6e3f0a171d72f536cc9eb47#diff-49473dca262eeab3b4a43002adb08b4db31020d190caaad1594b47f1d5daa810
WORKDIR /MEGAcmd
RUN ./autogen.sh && \
	./configure --host=aarch64-linux-gnu --with-freeimage=no --with-ffmpeg=no --enable-examples=no && \
	checkinstall -y --install=no \
		--strip=no \
		--pkgversion=$MEGACMD_PKG_VERSION --pkgarch=arm64 \
		--maintainer="MEGA Linux Team \\<linux@mega.co.nz\\>" \
		--requires="libatomic1 \(\>= 4.8\), libc-ares2 \(\>= 1.11.0~rc1\), libc6 \(\>= 2.30\), libgcc-s1 \(\>= 4.0\), libpcrecpp0v5 \(\>= 7.7\), libssl3, libstdc++6 \(\>= 9\), libzen0v5 \(\>= 0.4.31-2~\), zlib1g \(\>= 1:1.2.11.dfsg\), libuv1t64 \(\>= 1.48.0\), libcrypto++8, libicu74, apt-transport-https, gpg" \
		make install -j$(nproc)

ENTRYPOINT cat /MEGAcmd/megacmd_*_arm64.deb
