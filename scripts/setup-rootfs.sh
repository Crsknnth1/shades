#!/bin/bash
# Installs the Shades rootfs overlay onto a Debian system. Run as root.
# Usage: setup-rootfs.sh <repo-rootfs-dir>
# Shared by the Docker playground and the ISO build.
set -euo pipefail

src="${1:?usage: setup-rootfs.sh <rootfs-dir>}"
scripts="$(cd "$(dirname "$0")" && pwd)"

cp -rT "$src" /
chmod 755 /usr/libexec/shades/*

# Shades English (language "en_SH", see /etc/xdg/plasma-localerc): an English copy of every
# KDE catalog that mentions something Windows calls differently, reworded by
# shades-english.pl. KDE's German catalogs are complete, so they supply the source strings.
build_shades_english() {
    local out=/usr/share/locale/en_SH/LC_MESSAGES count=0 mo domain tmp
    tmp="$(mktemp -d)"
    install -d "$out"
    # "source=target" pairs: Shades' copies of KDE widgets use their own translation domain.
    local aliases="plasma_applet_org.kde.plasma.taskmanager=plasma_applet_org.shades.taskbar"
    for mo in /usr/share/locale/de/LC_MESSAGES/*.mo; do
        domain="$(basename "$mo" .mo)"
        msgunfmt --no-wrap "$mo" > "$tmp/de.po" 2>/dev/null || continue
        for target in "$domain" $(echo "$aliases" | tr ' ' '\n' | sed -n "s/^$domain=//p"); do
            if perl "$scripts/shades-english.pl" "$target" < "$tmp/de.po" > "$tmp/shades.po"; then
                msgfmt -o "$out/$target.mo" "$tmp/shades.po"
                count=$((count + 1))
            fi
        done
    done
    rm -rf "$tmp"
    echo "setup-rootfs: Shades English catalogs: $count"
    [ -f "$out/plasma_applet_org.kde.desktopcontainment.mo" ] \
        || { echo "setup-rootfs: Shades English is missing the desktop catalog" >&2; exit 1; }
}
build_shades_english

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
# Button menus: no "Configure Taskbar…" (Windows' taskbar menus have no such entry).
menu_qml="$tb/contents/ui/ContextMenu.qml"
sed -i 's/^\(\s*\)visible: configureAction \&\& configureAction.visible$/\1visible: false \/\/ Shades: no Configure Taskbar/' "$menu_qml"
grep -q "Shades: no Configure Taskbar" "$menu_qml" \
    || { echo "setup-rootfs: could not patch the task manager's ContextMenu.qml" >&2; exit 1; }

# File Explorer toolbar: KXMLGUI only picks up a newer dolphinui.rc from the user's own
# data folder, so give every new user a copy.
install -D -m 644 /usr/share/kxmlgui5/dolphin/dolphinui.rc /etc/skel/.local/share/kxmlgui5/dolphin/dolphinui.rc

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

# Plasma loads the OSD from the shell package before the global theme, so the Shades OSD
# goes there too.
shell=/usr/share/plasma/shells/org.kde.plasma.desktop/contents
cp /usr/share/plasma/look-and-feel/org.shades.desktop/contents/osd/*.qml "$shell/osd/"

# Lock screen like Windows: the big clock while idle, then only the sign-in box.
lock_qml="$shell/lockscreen/LockScreenUi.qml"
sed -i 's/^\(\s*\)visible: y > 0 \&\& config.alwaysShowClock$/\1visible: y > 0 \&\& config.alwaysShowClock \&\& !lockScreenRoot.uiVisible \/\/ Shades: clock only while idle/' "$lock_qml"
sed -i 's/^\(\s*\)visible: !softwareRendering \&\& config.alwaysShowClock$/\1visible: !softwareRendering \&\& config.alwaysShowClock \&\& !lockScreenRoot.uiVisible \/\/ Shades: clock shadow only while idle/' "$lock_qml"
grep -q "Shades: clock only while idle" "$lock_qml" && grep -q "Shades: clock shadow only while idle" "$lock_qml" \
    || { echo "setup-rootfs: could not patch LockScreenUi.qml" >&2; exit 1; }

# Reuse Breeze's logout, splash, and system dialog screens in the Shades global theme
# (Shades has its own OSD). Copied, not symlinked: KPackage refuses files that resolve
# outside the theme folder.
breeze=/usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents
shades=/usr/share/plasma/look-and-feel/org.shades.desktop/contents
for part in logout splash systemdialog previews; do
    if [ -e "$breeze/$part" ]; then
        rm -rf "${shades:?}/$part"
        cp -r "$breeze/$part" "$shades/$part"
    fi
done
