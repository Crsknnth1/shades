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

# Taskbar "org.shades.taskbar": Plasma's icons-only task manager with Windows 11-style
# buttons (rounded tile + pill, see /usr/share/shades/taskbar/WinIndicator.qml) in place
# of its frame, and without the "+" badge on grouped windows.
tm=/usr/share/plasma/plasmoids/org.kde.plasma.taskmanager
tb=/usr/share/plasma/plasmoids/org.shades.taskbar
rm -rf "$tb"
cp -r "$tm" "$tb"
cp /usr/share/shades/taskbar/metadata.json "$tb/metadata.json"
cp /usr/share/shades/taskbar/WinIndicator.qml "$tb/contents/ui/WinIndicator.qml"
printf 'import QtQuick\nItem {}\n' > "$tb/contents/ui/GroupExpanderOverlay.qml"
grep -rl '"org.kde.plasma.icontasks"' "$tb/contents" | xargs sed -i 's/"org.kde.plasma.icontasks"/"org.shades.taskbar"/g'
task_qml="$tb/contents/ui/Task.qml"
perl -0pi -e 's/(\n    KSvg\.FrameSvgItem \{\n        id: frame\n)/$1        visible: false \/\/ Shades: WinIndicator draws the button\n/' "$task_qml"
perl -0pi -e 's/(\n    Loader \{\n        id: taskProgressOverlayLoader\n)/\n    WinIndicator {\n        anchors.fill: frame\n        hovered: task.highlighted\n        active: model.IsActive === true\n        open: model.IsWindow === true\n        attention: model.IsDemandingAttention === true\n    }\n$1/' "$task_qml"
grep -q "visible: false // Shades" "$task_qml" && grep -q "WinIndicator {" "$task_qml" \
    || { echo "setup-rootfs: could not patch the task manager's Task.qml" >&2; exit 1; }

# Notifications bell beside the clock: small like Windows', not scaled to the taskbar's
# height. (The applet has a compiled part, so it's patched in place rather than copied.)
bell_qml=/usr/share/plasma/plasmoids/org.kde.plasma.notifications/contents/ui/CompactRepresentation.qml
sed -i 's/width: Kirigami.Units.iconSizes.roundedIconSize(Math.min(parent.width, parent.height))$/width: Kirigami.Units.iconSizes.small \/\/ Shades: small bell/' "$bell_qml"
grep -q "Shades: small bell" "$bell_qml" || { echo "setup-rootfs: could not patch the notifications icon size" >&2; exit 1; }

# No tab-style line over a taskbar button while its popup is open: Windows has none, and
# Shades' own taskbar widgets highlight themselves.
compact_qml=/usr/share/plasma/shells/org.kde.plasma.desktop/contents/applet/CompactApplet.qml
sed -i 's/opacity: plasmoidItem \&\& plasmoidItem.expanded ? 1 : 0$/opacity: 0 \/\/ Shades: no open-popup line/' "$compact_qml"
grep -q "Shades: no open-popup line" "$compact_qml" || { echo "setup-rootfs: could not patch CompactApplet.qml" >&2; exit 1; }

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
