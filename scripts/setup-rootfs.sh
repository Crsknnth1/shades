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

# White, Windows-style pointer everywhere, including outside Plasma.
update-alternatives --install /usr/share/icons/default/index.theme x-cursor-theme /usr/share/shades/cursor.theme 100
update-alternatives --set x-cursor-theme /usr/share/shades/cursor.theme

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

# Clock calendar like Windows 11's: "October 2026" heading with up/down arrows, no
# Days/Months/Years tabs, and today as a filled accent circle. The calendar module normally
# loads its compiled-in QML ("prefer :/..."); dropping that line makes it use (and lets us
# patch) the identical files on disk.
cal=/usr/lib/x86_64-linux-gnu/qt6/qml/org/kde/plasma/workspace/calendar
sed -i '/^prefer :\//d' "$cal/qmldir"
perl -0pi -e 's/(\n(\s*)id: tabBar\n)/$1$2visible: false \/\/ Shades: no Days\/Months\/Years tabs\n/' "$cal/MonthViewHeader.qml"
perl -0pi -e 's/text: root\.swipeView\.currentIndex > 0 \|\| root\.monthViewRoot\.selectedYear !== today\.getFullYear\(\)/text: true \/\/ Shades: always "Month Year"\n/' "$cal/MonthViewHeader.qml"
perl -0pi -e 's/active: today \|\| selected \|\| dayStyle\.hovered \|\| dayStyle\.activeFocus/active: !today \&\& (selected || dayStyle.hovered || dayStyle.activeFocus) \/\/ Shades: today drawn below/' "$cal/DayDelegate.qml"
perl -0pi -e 's/(\n    contentItem: Item \{\n)/\n    \/\/ Shades: today as a filled accent circle, like Windows 11\x27s calendar.\n    Rectangle {\n        visible: dayStyle.today\n        anchors.centerIn: parent\n        width: Math.min(parent.width, parent.height) * 0.8\n        height: width\n        radius: width \/ 2\n        color: Kirigami.Theme.highlightColor\n        z: -1\n    }\n$1/' "$cal/DayDelegate.qml"
perl -0pi -e 's/(\n(\s*)id: label\n)/$1$2color: dayStyle.today ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor \/\/ Shades\n/' "$cal/DayDelegate.qml"
perl -0pi -e 's/(sourceComponent: dateAndPin\n\s*)active: root\.isDigitalClock/${1}active: false \/\/ Shades: no settings or pin buttons/' "$cal/MonthViewHeader.qml"
for check in "Shades: no Days" "Shades: always" "Shades: no settings or pin"; do
    grep -q "$check" "$cal/MonthViewHeader.qml" || { echo "setup-rootfs: could not patch MonthViewHeader.qml ($check)" >&2; exit 1; }
done
for check in "Shades: today drawn below" "Shades: today as a filled" "highlightedTextColor : Kirigami.Theme.textColor // Shades"; do
    grep -q "$check" "$cal/DayDelegate.qml" || { echo "setup-rootfs: could not patch DayDelegate.qml ($check)" >&2; exit 1; }
done
! grep -q "^prefer " "$cal/qmldir" || { echo "setup-rootfs: could not patch the calendar qmldir" >&2; exit 1; }

# Plasma themes "shades" and "shades-dark": Breeze / Breeze Dark with solid panels and popups.
# Translucency without blur looks muddy, and VMs (software rendering) never get blur, so
# Shades is opaque everywhere.
themes=/usr/share/plasma/desktoptheme
make_solid_theme() {
    local from="$1" to="$2" name="$3" from_id="$4" from_name="$5"
    rm -rf "${themes:?}/$to"
    cp -r "$themes/$from" "$themes/$to"
    # Breeze Dark only overrides colors, so the solid artwork comes from Breeze itself.
    (cd "$themes/default/solid" && find . -type f) | while read -r f; do
        for variant in . translucent opaque; do
            mkdir -p "$(dirname "$themes/$to/$variant/$f")"
            cp "$themes/default/solid/$f" "$themes/$to/$variant/$f"
        done
    done
    sed -i -e "s/\"Id\": \"$from_id\"/\"Id\": \"$to\"/" -e "s/\"Name\": \"$from_name\"/\"Name\": \"$name\"/" \
        "$themes/$to/metadata.json"
    [ -f "$themes/$to/plasmarc" ] && sed -i '/^\[ContrastEffect\]/,$d' "$themes/$to/plasmarc"
    grep -q "\"Id\": \"$to\"" "$themes/$to/metadata.json" \
        || { echo "setup-rootfs: could not create Plasma theme $to" >&2; exit 1; }
}
make_solid_theme default shades "Shades" default "Breeze"
make_solid_theme breeze-dark shades-dark "Shades Dark" breeze-dark "Breeze Dark"

# Settings' sidebar sections in Windows 11 terms (Shades English names in the category files).
name_category() {
    local file="/usr/share/systemsettings/categories/$1.desktop" name="$2"
    [ -f "$file" ] || return 0
    sed -i '/^Name\[en_SH\]=/d' "$file"
    # "&" means "the matched text" in a sed replacement, so escape it in names like "Bluetooth & devices".
    sed -i "0,/^Name=.*/s//&\nName[en_SH]=${name//&/\\&}/" "$file"
}
name_category settings-appearance "Personalization"
name_category settings-applications "Apps"
name_category settings-applications-defaults "Default apps"
name_category settings-hardware "Bluetooth & devices"
name_category settings-hardware-input "System"
name_category settings-hardware-display "Display"
name_category settings-hardware-input-pointing-devices "Mouse"
name_category settings-hardware-removable-storage "Storage & cameras"
name_category settings-network "Network & internet"
name_category settings-network-networksettings "Wi-Fi"
name_category settings-personalization "Accounts"
name_category settings-regionalsettings "Time & language"
name_category settings-security-privacy "Privacy & security"
name_category settings-system-administration "About & updates"
name_category settings-workspace "Taskbar & desktop"
name_category settings-appearance-themes "Themes"
name_category settings-appearance-font "Fonts"

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
for part in logout splash systemdialog; do
    if [ -e "$breeze/$part" ]; then
        rm -rf "${shades:?}/$part"
        cp -r "$breeze/$part" "$shades/$part"
    fi
done

# Shades Dark global theme: same layout and screens as Shades (each theme ships its own
# preview screenshots).
dark=/usr/share/plasma/look-and-feel/org.shades.dark/contents
for part in layouts osd logout splash systemdialog; do
    rm -rf "${dark:?}/$part"
    cp -r "$shades/$part" "$dark/$part"
done
