# Shades desktop playground: Debian 13 + KDE Plasma, viewed in a browser via noVNC.
# This is for iterating on the look and apps quickly; the bootable ISO comes later.
# Build context is the repo root (see compose.yaml).

# --- Assets: third-party icon theme and rendered artwork ---
FROM debian:trixie AS assets

ARG FLUENT_ICONS_TAG=2026-07-27

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates librsvg2-bin \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /src/fluent /out/usr/share/icons \
    && curl -fsSL "https://github.com/vinceliuice/Fluent-icon-theme/archive/refs/tags/${FLUENT_ICONS_TAG}.tar.gz" \
        | tar -xz -C /src/fluent --strip-components=1 \
    && /src/fluent/install.sh -d /out/usr/share/icons \
    && sed -i 's/^Inherits=hicolor$/Inherits=breeze,hicolor/' /out/usr/share/icons/Fluent*/index.theme

COPY artwork/wallpaper.svg /src/wallpaper.svg
RUN mkdir -p /out/usr/share/wallpapers/Shades/contents/images \
    && rsvg-convert -w 1920 -h 1080 /src/wallpaper.svg \
        -o /out/usr/share/wallpapers/Shades/contents/images/1920x1080.png \
    && rsvg-convert -w 3840 -h 2160 /src/wallpaper.svg \
        -o /out/usr/share/wallpapers/Shades/contents/images/3840x2160.png

# --- Desktop ---
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        kde-plasma-desktop plasma-workspace kwin-x11 breeze \
        systemsettings dolphin konsole kde-spectacle plasma-systemmonitor \
        fonts-inter fonts-noto-core xdg-user-dirs \
        tigervnc-standalone-server tigervnc-tools novnc websockify \
        dbus-x11 xauth x11-xserver-utils \
        mesa-utils libgl1-mesa-dri \
        locales sudo ca-certificates \
        xdotool imagemagick \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

COPY --from=assets /out/ /
COPY rootfs/ /tmp/shades-rootfs/
COPY scripts/setup-rootfs.sh /tmp/setup-rootfs.sh
RUN bash /tmp/setup-rootfs.sh /tmp/shades-rootfs && rm -rf /tmp/shades-rootfs /tmp/setup-rootfs.sh

# No systemd in a container, so Plasma must start its services itself.
COPY container/startkderc /etc/xdg/startkderc

# Desktop user. No password; passwordless sudo for tinkering inside the container.
RUN useradd -m -s /bin/bash shades \
    && echo 'shades ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/shades \
    && chmod 440 /etc/sudoers.d/shades

COPY container/start.sh /usr/local/bin/start-desktop
RUN chmod +x /usr/local/bin/start-desktop

USER shades
WORKDIR /home/shades
EXPOSE 6080
CMD ["start-desktop"]
