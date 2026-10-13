# Shades desktop playground: Debian 13 + KDE Plasma, viewed in a browser via noVNC.
# This is for iterating on the look and apps quickly; the bootable ISO comes later.
# Build context is the repo root (see compose.yaml).

# --- Assets: third-party icon theme and rendered artwork ---
FROM debian:trixie AS assets

ARG FLUENT_ICONS_TAG=2026-07-27

ARG SELAWIK_TAG=1.01

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates librsvg2-bin unzip \
    && rm -rf /var/lib/apt/lists/*

# Selawik: Microsoft's open-source (OFL) stand-in for Segoe UI, Windows' interface font.
RUN mkdir -p /src/selawik /out/usr/share/fonts/truetype/selawik \
    && curl -fsSL -o /src/selawik.zip \
        "https://github.com/microsoft/Selawik/releases/download/${SELAWIK_TAG}/Selawik_Release.zip" \
    && unzip -q /src/selawik.zip -d /src/selawik \
    && find /src/selawik -iname "*.ttf" -exec install -m 644 {} /out/usr/share/fonts/truetype/selawik/ \; \
    && curl -fsSL -o /out/usr/share/fonts/truetype/selawik/LICENSE.txt \
        "https://raw.githubusercontent.com/microsoft/Selawik/${SELAWIK_TAG}/LICENSE.txt" \
    && ls /out/usr/share/fonts/truetype/selawik/

RUN mkdir -p /src/fluent /out/usr/share/icons \
    && curl -fsSL "https://github.com/vinceliuice/Fluent-icon-theme/archive/refs/tags/${FLUENT_ICONS_TAG}.tar.gz" \
        | tar -xz -C /src/fluent --strip-components=1 \
    && /src/fluent/install.sh -d /out/usr/share/icons yellow \
    && sed -i 's/^Inherits=hicolor$/Inherits=breeze,hicolor/' /out/usr/share/icons/Fluent*/index.theme

COPY artwork/ /src/artwork/
# Light and dark variants; Plasma picks images_dark/ when a dark color scheme is active.
RUN w=/out/usr/share/wallpapers/Shades/contents \
    && mkdir -p "$w/images" "$w/images_dark" \
    && for size in 1920x1080 3840x2160; do \
        rsvg-convert -w "${size%x*}" -h "${size#*x}" /src/artwork/wallpaper.svg -o "$w/images/$size.png" \
        && rsvg-convert -w "${size%x*}" -h "${size#*x}" /src/artwork/wallpaper-dark.svg -o "$w/images_dark/$size.png"; \
    done

# --- Klassy: Breeze-based window decoration with Windows 11-style titlebar buttons ---
FROM debian:trixie AS klassy

ARG KLASSY_TAG=v6.3

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates build-essential cmake extra-cmake-modules gettext \
        qt6-base-dev qt6-declarative-dev qt6-svg-dev libx11-dev \
        libkdecorations3-dev libkf6coreaddons-dev libkf6colorscheme-dev libkf6config-dev \
        libkf6guiaddons-dev libkf6i18n-dev libkf6iconthemes-dev libkf6windowsystem-dev \
        libkf6kcmutils-dev libkirigami-dev libkf6style-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /src/klassy \
    && curl -fsSL "https://github.com/paulmcauley/klassy/archive/refs/tags/${KLASSY_TAG}.tar.gz" \
        | tar -xz -C /src/klassy --strip-components=1 \
    && cmake -S /src/klassy -B /build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF -DBUILD_QT5=OFF -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
    && cmake --build /build -j"$(nproc)" \
    && DESTDIR=/out cmake --install /build \
    # Keep only the decoration and its settings; drop Klassy's own icons and themes.
    && rm -rf /out/usr/share/icons /out/usr/share/plasma /out/usr/share/color-schemes

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

# Apps: Wine, ONLYOFFICE, Microsoft Edge (big and slow-changing, so its own layer).
COPY scripts/install-apps.sh /tmp/install-apps.sh
RUN bash /tmp/install-apps.sh && rm /tmp/install-apps.sh

# Network, sound, power, and Bluetooth back-ends for Quick Settings, plus PipeWire so the
# container has a (dummy) sound device to drive.
RUN apt-get update && apt-get install -y --no-install-recommends \
        plasma-nm plasma-pa powerdevil bluedevil kscreen kinfocenter sddm \
        pipewire pipewire-pulse wireplumber \
        gettext \
    && rm -rf /var/lib/apt/lists/*

# Everyday apps in Windows' roles (renamed by setup-rootfs.sh): Notepad, Photos, Calculator,
# Paint, Media Player, plus zip support and thumbnails in File Explorer. qml-qt6 runs
# Shades' own Task Manager.
RUN apt-get update && apt-get install -y --no-install-recommends \
        kwrite gwenview kcalc kolourpaint haruna ark kio-extras \
        qml-qt6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=assets /out/ /
COPY --from=klassy /out/ /
COPY rootfs/ /tmp/shades-rootfs/
COPY scripts/ /tmp/shades-scripts/
RUN bash /tmp/shades-scripts/setup-rootfs.sh /tmp/shades-rootfs && rm -rf /tmp/shades-rootfs /tmp/shades-scripts

# No systemd in a container, so Plasma must start its services itself.
COPY container/startkderc /etc/xdg/startkderc
COPY container/kscreenlockerrc /etc/xdg/kscreenlockerrc

# Desktop user. No password; passwordless sudo for tinkering inside the container.
RUN useradd -m -s /bin/bash shades \
    && echo 'shades ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/shades \
    && chmod 440 /etc/sudoers.d/shades

COPY container/start.sh /usr/local/bin/start-desktop
RUN chmod +x /usr/local/bin/start-desktop

USER shades
WORKDIR /home/shades

# Build the per-user app index and font caches now, so the first app launch isn't slow.
RUN XDG_MENU_PREFIX=plasma- kbuildsycoca6 --noincremental >/dev/null 2>&1 && fc-cache

EXPOSE 6080
CMD ["start-desktop"]
