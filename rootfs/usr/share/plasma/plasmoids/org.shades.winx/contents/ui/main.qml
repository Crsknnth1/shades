/*
    Win+X: an invisible taskbar widget, placed right after Start, whose global shortcut
    (set to Meta+X by the Shades layout) opens the power-user menu beside the Start button.
    A separate widget because a widget's shortcut can only "activate" it, and activating
    the Start widget already means opening Start.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.dbus as DBus
import "file:///usr/share/shades/qml" as Shades

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Plasmoid.onActivated: winx.open(root.fullRepresentationItem)

    fullRepresentation: Item {
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        Layout.maximumWidth: 0
    }

    Shades.WinXMenu {
        id: winx
        // "Search" opens Start through Plasma's launcher shortcut, like the Search box does.
        openSearch: () => DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/component/plasmashell",
            iface: "org.kde.kglobalaccel.Component",
            member: "invokeShortcut",
            arguments: [new DBus.string("activate application launcher")],
            signature: "(s)",
        })
    }
}
