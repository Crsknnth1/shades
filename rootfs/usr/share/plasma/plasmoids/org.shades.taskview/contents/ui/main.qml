/*
    Windows 11-style Task View button: toggles KWin's Overview (same as Win+Tab).

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: i18n("Task View")

    readonly property bool lightTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Light

    fullRepresentation: MouseArea {
        id: area
        Layout.minimumWidth: height
        Layout.preferredWidth: height
        Layout.maximumWidth: height
        hoverEnabled: true

        onClicked: {
            const reply = DBus.SessionBus.asyncCall({
                service: "org.kde.kglobalaccel",
                path: "/component/kwin",
                iface: "org.kde.kglobalaccel.Component",
                member: "invokeShortcut",
                arguments: [new DBus.string("Overview")],
                signature: "(s)",
            });
            reply.finished.connect(() => {
                if (reply.isError) {
                    console.warn("Task View: could not toggle Overview:", reply.error.name, reply.error.message);
                }
            });
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - Kirigami.Units.smallSpacing
            height: width
            radius: 4
            color: root.lightTheme ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.07)
            opacity: area.containsMouse ? 1 : 0
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(Math.min(parent.width, parent.height) * 0.7)
            height: width
            source: "shades-taskview"
            // Drawn in the text color, so it reads on both the light and dark taskbar.
            isMask: true
            color: Kirigami.Theme.textColor
        }
    }
}
