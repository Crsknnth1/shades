/*
    Shades' "Win+X" power-user menu, like Windows': settings shortcuts, Terminal, Task
    Manager, Settings, File Explorer, Search, Run, power options, and Desktop.
    Shared by the Start button (right-click) and the org.shades.winx widget (Win+X), which
    import this folder by path.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQml.Models
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.sessions as Sessions
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.showdesktop
import org.kde.kcmutils as KCM

Item {
    id: winx

    // Called for "Search": the Start menu passes a function that opens itself.
    property var openSearch: null

    function open(visualParent) {
        menu.visualParent = visualParent;
        menu.openRelative();
    }

    function run(command) {
        launcher.connectSource(command);
    }

    P5Support.DataSource {
        id: launcher
        engine: "executable"
        onNewData: sourceName => disconnectSource(sourceName)
    }

    ShowDesktop {
        id: showDesktop
    }

    Sessions.SessionManagement {
        id: session
    }

    PlasmaExtras.Menu {
        id: menu
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup
    }

    Instantiator {
        model: winx.actions
        delegate: PlasmaExtras.MenuItem {
            required property var modelData
            text: modelData.text
            icon: modelData.icon.name
            separator: modelData.isSeparator
            enabled: modelData.enabled
            visible: modelData.visible
            onClicked: modelData.trigger()
        }
        onObjectAdded: (index, object) => menu.addMenuItem(object)
    }

    readonly property list<PlasmaCore.Action> actions: [
        PlasmaCore.Action {
            text: i18n("Power Options")
            icon.name: "preferences-system-power-management"
            onTriggered: KCM.KCMLauncher.openSystemSettings("kcm_powerdevilprofilesconfig")
        },
        PlasmaCore.Action {
            text: i18n("System")
            icon.name: "computer"
            onTriggered: KCM.KCMLauncher.openSystemSettings("kcm_about-distro")
        },
        PlasmaCore.Action {
            text: i18n("Network Connections")
            icon.name: "network-wired"
            onTriggered: KCM.KCMLauncher.openSystemSettings("kcm_networkmanagement")
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: i18n("Terminal")
            icon.name: "utilities-terminal"
            onTriggered: winx.run("konsole")
        },
        PlasmaCore.Action {
            text: i18n("Task Manager")
            icon.name: "utilities-system-monitor"
            onTriggered: winx.run("plasma-systemmonitor")
        },
        PlasmaCore.Action {
            text: i18n("Settings")
            icon.name: "preferences-system"
            onTriggered: winx.run("systemsettings")
        },
        PlasmaCore.Action {
            text: i18n("File Explorer")
            icon.name: "system-file-manager"
            onTriggered: winx.run("dolphin")
        },
        PlasmaCore.Action {
            text: i18n("Search")
            icon.name: "search"
            visible: winx.openSearch !== null
            onTriggered: winx.openSearch()
        },
        PlasmaCore.Action {
            text: i18n("Run")
            icon.name: "system-run"
            onTriggered: winx.run("krunner")
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: i18n("Sign out")
            icon.name: "system-log-out"
            enabled: session.canLogout
            onTriggered: session.requestLogout()
        },
        PlasmaCore.Action {
            text: i18n("Sleep")
            icon.name: "system-suspend"
            enabled: session.canSuspend
            onTriggered: session.suspend()
        },
        PlasmaCore.Action {
            text: i18n("Shut down")
            icon.name: "system-shutdown"
            enabled: session.canShutdown
            onTriggered: session.requestShutdown()
        },
        PlasmaCore.Action {
            text: i18n("Restart")
            icon.name: "system-reboot"
            enabled: session.canReboot
            onTriggered: session.requestReboot()
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: i18n("Desktop")
            icon.name: "user-desktop"
            onTriggered: showDesktop.toggleDesktop()
        }
    ]
}
