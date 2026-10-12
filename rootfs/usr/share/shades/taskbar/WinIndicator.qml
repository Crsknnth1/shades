/*
    Windows 11-style taskbar button, drawn behind each task's icon in org.shades.taskbar:
    a soft rounded tile on hover or for the active window, and a pill under the icon for
    open windows (long accent pill = active window, short grey pill = open in background).
    setup-rootfs.sh copies this into Plasma's task manager and hides its own frame.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property bool hovered: false
    property bool active: false
    property bool open: false
    property bool attention: false

    readonly property bool lightTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Light
    readonly property real tileSize: Math.min(width, height) - Kirigami.Units.smallSpacing

    function withAlpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    Rectangle {
        id: tile
        anchors.centerIn: parent
        width: root.tileSize
        height: root.tileSize
        radius: 4

        color: root.attention ? root.withAlpha(Kirigami.Theme.neutralTextColor, 0.3)
             : root.lightTheme ? Qt.rgba(1, 1, 1, root.active ? 0.9 : 0.65)
             : Qt.rgba(1, 1, 1, root.active ? 0.1 : 0.06)
        border.width: 1
        border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.07)

        opacity: root.hovered || root.active || root.attention ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: tile.horizontalCenter
        anchors.bottom: tile.bottom
        anchors.bottomMargin: 1
        height: 3
        radius: height / 2
        visible: root.open

        width: root.active ? Math.round(root.tileSize * 0.4) : 6
        color: root.active ? Kirigami.Theme.highlightColor : root.withAlpha(Kirigami.Theme.textColor, 0.45)

        Behavior on width {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
    }
}
