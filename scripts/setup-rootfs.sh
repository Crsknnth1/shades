#!/bin/bash
# Installs the Shades rootfs overlay onto a Debian system. Run as root.
# Usage: setup-rootfs.sh <repo-rootfs-dir>
# Shared by the Docker playground and the ISO build.
set -euo pipefail

src="${1:?usage: setup-rootfs.sh <rootfs-dir>}"

cp -rT "$src" /

# KDE apps read colors from kdeglobals, not from the scheme file, so copy them in.
cat /usr/share/color-schemes/ShadesLight.colors >> /etc/xdg/kdeglobals

# Start menu pinned apps. Kickoff copies its built-in default list into KDE's activity
# database before layout scripts can change it, so the default itself has to change.
favorites="org.kde.dolphin.desktop,org.kde.konsole.desktop,org.kde.plasma-systemmonitor.desktop,org.kde.spectacle.desktop,systemsettings.desktop"
kickoff_xml=/usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/config/main.xml
sed -i "s|<default>preferred://browser,org.kde.kontact.desktop,[^<]*</default>|<default>$favorites</default>|" "$kickoff_xml"
grep -q "$favorites" "$kickoff_xml" || { echo "setup-rootfs: could not patch Kickoff favorites" >&2; exit 1; }

# Plasma theme "shades": Breeze with solid panels and popups. Translucency without blur looks
# muddy, and VMs (software rendering) never get blur, so Shades is opaque everywhere.
themes=/usr/share/plasma/desktoptheme
rm -rf "$themes/shades"
cp -r "$themes/default" "$themes/shades"
(cd "$themes/default/solid" && find . -type f) | while read -r f; do
    for variant in . translucent opaque; do
        mkdir -p "$(dirname "$themes/shades/$variant/$f")"
        cp "$themes/default/solid/$f" "$themes/shades/$variant/$f"
    done
done
sed -i -e 's/"Id": "default"/"Id": "shades"/' -e 's/"Name": "Breeze"/"Name": "Shades"/' \
    "$themes/shades/metadata.json"
sed -i '/^\[ContrastEffect\]/,$d' "$themes/shades/plasmarc"

# Reuse Breeze's logout, OSD, splash, and system dialog screens in the Shades global theme.
breeze=/usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents
shades=/usr/share/plasma/look-and-feel/org.shades.desktop/contents
for part in logout osd splash systemdialog previews; do
    [ -e "$breeze/$part" ] && ln -sfn "$breeze/$part" "$shades/$part"
done
