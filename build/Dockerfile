# Ambiente di build riproducibile per 2D OS
# Debian 13 (trixie) con live-build e la toolchain completa.
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        live-build \
        debootstrap \
        dosfstools \
        mtools \
        xorriso \
        isolinux \
        syslinux-common \
        syslinux-efi \
        grub-efi-amd64-bin \
        grub-pc-bin \
        squashfs-tools \
        xz-utils \
        zstd \
        cpio \
        librsvg2-bin \
        fonts-dejavu-core \
        file \
        rsync \
        ca-certificates \
        gnupg \
        git \
        python3 \
        make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

CMD ["/build/build/container-entrypoint.sh"]
