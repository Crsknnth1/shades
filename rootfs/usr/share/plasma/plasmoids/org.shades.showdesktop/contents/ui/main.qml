/*
    Windows 11-style "Show desktop" strip: a thin sliver at the far right of the taskbar,
    with a hairline divider. Click it to show the desktop; click again to bring windows back.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.showdesktop
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: i18n("Show desktop")

    ShowDesktop {
        id: showDesktop
    }

    fullRepresentation: MouseArea {
        id: area
        Layout.minimumWidth: Kirigami.Units.smallSpacing * 3
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        hoverEnabled: true
        onClicked: showDesktop.toggleDesktop()

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Math.round(parent.height * 0.4)
            color: Kirigami.Theme.textColor
            opacity: area.containsMouse || showDesktop.showingDesktop ? 0.45 : 0.2
        }
    }
}
