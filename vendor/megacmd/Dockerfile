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
		libreadline-dev:arm64 libpcre3-dev:arm64 libsodium-dev:arm64 libc-ares-dev:arm64 libicu-dev:arm64 libmediainfo-dev:arm64 && \
	git clone --recurse-submodules https://github.com/meganz/MEGAcmd.git /MEGAcmd && \
	git -C /MEGAcmd checkout ${MEGACMD_VERSION}

# Configuring with disabled features is necessary to build for updated systems:
# https://github.com/meganz/sdk/issues/2576
# It also is good to get rid of unnecessary cruft for our purposes.
# The package metadata was mostly copied from the closest official binary package
# at https://mega.nz/linux/repo/Debian_11/armhf/megacmd_1.5.0-8.1_armhf.deb
WORKDIR /MEGAcmd
RUN ./autogen.sh && \
	./configure --host=aarch64-linux-gnu \
		--without-freeimage --without-libuv --without-ffmpeg && \
	checkinstall -y --install=no \
		--strip=no \
		--pkgversion=$MEGACMD_PKG_VERSION --pkgarch=arm64 \
		--maintainer="MEGA Linux Team \\<linux@mega.co.nz\\>" \
		--requires="libatomic1 \(\>= 4.8\), libc-ares2 \(\>= 1.11.0~rc1\), libc6 \(\>= 2.30\), libgcc-s1 \(\>= 4.0\), libmediainfo0v5 \(\>= 0.7.56\), libpcrecpp0v5 \(\>= 7.7\), libssl3, libstdc++6 \(\>= 9\), libzen0v5 \(\>= 0.4.31-2~\), zlib1g \(\>= 1:1.2.11.dfsg\), libcrypto++8, libicu74, apt-transport-https, gpg" \
		make install -j$(nproc)

ENTRYPOINT cat /MEGAcmd/megacmd_*_arm64.deb
