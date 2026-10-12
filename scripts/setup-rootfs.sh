#!/bin/bash
# Installs the Shades rootfs overlay onto a Debian system. Run as root.
# Usage: setup-rootfs.sh <repo-rootfs-dir>
# Shared by the Docker playground and the ISO build.
set -euo pipefail

src="${1:?usage: setup-rootfs.sh <rootfs-dir>}"

cp -rT "$src" /
chmod 755 /usr/libexec/shades/*

# KDE apps read colors from kdeglobals, not from the scheme file, so copy them in.
cat /usr/share/color-schemes/ShadesLight.colors >> /etc/xdg/kdeglobals

# Windows names for the core apps. Copies in /usr/local/share/applications keep the same
# IDs (so pins and shortcuts still match) and take priority over the originals.
rename_app() {
    local id="$1" name="$2"
    install -d /usr/local/share/applications
    sed -e '/^Name\[/d' -e "s/^Name=.*/Name=$name/" \
        "/usr/share/applications/$id" > "/usr/local/share/applications/$id"
}
rename_app org.kde.dolphin.desktop "File Explorer"
rename_app org.kde.konsole.desktop "Terminal"
rename_app org.kde.plasma-systemmonitor.desktop "Task Manager"
rename_app org.kde.spectacle.desktop "Screenshot"
rename_app systemsettings.desktop "Settings"

# Keep the Start menu to what Windows would show.
hide_app() {
    local id="$1"
    [ -f "/usr/share/applications/$id" ] || return 0
    install -d /usr/local/share/applications
    { grep -v '^NoDisplay=' "/usr/share/applications/$id"; echo "NoDisplay=true"; } \
        > "/usr/local/share/applications/$id"
}
hide_app kdesystemsettings.desktop             # duplicate of Settings
hide_app klassy-settings.desktop               # titlebar tuning; Settings covers it
hide_app org.kde.drkonqi.coredump.gui.desktop  # crash viewer
hide_app org.kde.plasma.emojier.desktop        # still on Win+. via its shortcut
hide_app display-im7.q16.desktop               # ImageMagick (container screenshot tool)

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
# Copied, not symlinked: KPackage refuses files that resolve outside the theme folder.
breeze=/usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents
shades=/usr/share/plasma/look-and-feel/org.shades.desktop/contents
for part in logout osd splash systemdialog previews; do
    if [ -e "$breeze/$part" ]; then
        rm -rf "${shades:?}/$part"
        cp -r "$breeze/$part" "$shades/$part"
    fi
done
