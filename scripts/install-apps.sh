#!/bin/bash
# Installs the Shades app layer on Debian 13: Wine (to run Windows programs),
# ONLYOFFICE (Office-style editors), and Microsoft Edge (browser + Office web apps).
# Run as root. Shared by the Docker playground and the ISO build.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Must match Debian's Wine 10.0; see dlls/appwiz.cpl/addons.c in the Wine source.
WINE_MONO_VERSION=9.4.0
WINE_GECKO_VERSION=2.47.4

apt-get update
apt-get install -y --no-install-recommends curl gpg ca-certificates

# winetricks lives in contrib. Most Windows installers are 32-bit, so Wine needs i386 too.
sed -i 's/^Components: main$/Components: main contrib/' /etc/apt/sources.list.d/debian.sources
dpkg --add-architecture i386

install -d -m 755 /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" \
    > /etc/apt/sources.list.d/microsoft-edge.list
curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
    | gpg --dearmor --yes -o /etc/apt/keyrings/onlyoffice.gpg
echo "deb [signed-by=/etc/apt/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" \
    > /etc/apt/sources.list.d/onlyoffice.list

apt-get update
apt-get install -y --no-install-recommends \
    wine wine64 wine32:i386 winetricks fonts-wine cabextract \
    microsoft-edge-stable \
    onlyoffice-desktopeditors

# Ship Wine's .NET (Mono) and web engine (Gecko) so new Wine setups don't stop to download them.
install -d /usr/share/wine/mono /usr/share/wine/gecko
curl -fsSL -o "/usr/share/wine/mono/wine-mono-${WINE_MONO_VERSION}-x86.msi" \
    "https://dl.winehq.org/wine/wine-mono/${WINE_MONO_VERSION}/wine-mono-${WINE_MONO_VERSION}-x86.msi"
for arch in x86 x86_64; do
    curl -fsSL -o "/usr/share/wine/gecko/wine-gecko-${WINE_GECKO_VERSION}-${arch}.msi" \
        "https://dl.winehq.org/wine/wine-gecko/${WINE_GECKO_VERSION}/wine-gecko-${WINE_GECKO_VERSION}-${arch}.msi"
done

rm -rf /var/lib/apt/lists/*
