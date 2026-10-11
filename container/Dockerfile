# Shades desktop playground: Debian 13 + KDE Plasma, viewed in a browser via noVNC.
# This is for iterating on the look and apps quickly; the bootable ISO comes later.
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        kde-plasma-desktop plasma-workspace kwin-x11 \
        dolphin konsole \
        tigervnc-standalone-server tigervnc-tools novnc websockify \
        dbus-x11 xauth x11-xserver-utils \
        mesa-utils libgl1-mesa-dri \
        fonts-noto-core locales sudo ca-certificates \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# Desktop user. No password; passwordless sudo for tinkering inside the container.
RUN useradd -m -s /bin/bash shades \
    && echo 'shades ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/shades \
    && chmod 440 /etc/sudoers.d/shades

COPY start.sh /usr/local/bin/start-desktop
RUN chmod +x /usr/local/bin/start-desktop

USER shades
WORKDIR /home/shades
EXPOSE 6080
CMD ["start-desktop"]
