/*
    Windows 11-style "Search" box on the taskbar. Clicking it opens the Start menu,
    whose search field takes the typing (the same thing pressing Win does).

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property bool lightTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Light

    Layout.minimumWidth: Kirigami.Units.gridUnit * 9
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth

    function openStartSearch() {
        DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/component/plasmashell",
            iface: "org.kde.kglobalaccel.Component",
            member: "invokeShortcut",
            arguments: [new DBus.string("activate application launcher")],
            signature: "(s)",
        });
    }

    fullRepresentation: MouseArea {
        id: area
        hoverEnabled: true
        onClicked: root.openStartSearch()

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: Math.round(Math.min(parent.height, Kirigami.Units.gridUnit * 2) * 0.8)
            radius: height / 2
            color: root.lightTheme ? Qt.rgba(1, 1, 1, area.containsMouse ? 1 : 0.8)
                                   : Qt.rgba(1, 1, 1, area.containsMouse ? 0.1 : 0.06)
            border.width: 1
            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    source: "search"
                }
                PC3.Label {
                    Layout.fillWidth: true
                    text: i18n("Search")
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
        }
    }
}
