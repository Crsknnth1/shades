/*
    Shades Start menu: a Windows 11-style launcher.
    Search on top, "Pinned" grid with an "All apps" list behind it, "Recommended"
    recent files, and the user plus power button along the bottom.
    Uses the same data models as Plasma's Kickoff (org.kde.plasma.private.kicker).

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions
import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "file:///usr/share/shades/qml" as Shades

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    // "pinned", "allApps", or "search" (search wins whenever the field has text)
    property string page: "pinned"
    readonly property bool searching: searchQuery.length > 0
    property string searchQuery: ""

    function close() {
        root.expanded = false;
    }

    onExpandedChanged: {
        if (root.expanded) {
            page = "pinned";
            searchQuery = "";
        }
    }

    //BEGIN Models
    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        appletInterface: root
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: true

        Component.onCompleted: {
            favoritesModel.initForClient("org.shades.startmenu.favorites.instance-" + Plasmoid.id);
            if (!Plasmoid.configuration.favoritesPortedToKAstats) {
                if (favoritesModel.count < 1) {
                    favoritesModel.portOldFavorites(Plasmoid.configuration.favorites);
                }
                Plasmoid.configuration.favoritesPortedToKAstats = true;
            }
            refresh();
        }
    }

    // Row 0 is the favorites placeholder; row 1 is "All Applications".
    property var appsModel: rootModel.modelForRow(1)
    Connections {
        target: rootModel
        function onRefreshed() {
            root.appsModel = rootModel.modelForRow(1);
        }
    }

    Kicker.RunnerModel {
        id: runnerModel
        query: root.searchQuery
        appletInterface: root
        mergeResults: true
        favoritesModel: rootModel.favoritesModel
    }

    Kicker.RecentUsageModel {
        id: recentDocsModel
        shownItems: Kicker.RecentUsageModel.OnlyDocs
        favoritesModel: rootModel.favoritesModel
    }

    Sessions.SessionManagement {
        id: session
    }

    KCoreAddons.KUser {
        id: kuser
    }
    //END

    // Right-click menu: Windows' "Win+X" power-user menu (shared with the Win+X widget).
    // The Start button opens it itself: Plasma shows no widget menus on a locked taskbar.
    Shades.WinXMenu {
        id: winx
        openSearch: () => root.expanded = true
    }

    compactRepresentation: MouseArea {
        id: compactRoot
        // Square button as big as the taskbar's other icons.
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.medium : height
        Layout.minimumHeight: vertical ? width : Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                winx.open(compactRoot);
            } else {
                root.expanded = !root.expanded;
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.textColor
            opacity: root.expanded ? 0.10 : (compactRoot.containsMouse ? 0.06 : 0)
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            // Same size as the pinned app icons next to it.
            width: Math.round(Math.min(parent.width, parent.height) * 0.9)
            height: width
            source: Plasmoid.configuration.icon
        }
    }

    fullRepresentation: Item {
        id: menu

        Layout.preferredWidth: Kirigami.Units.gridUnit * 34
        Layout.preferredHeight: Kirigami.Units.gridUnit * 38
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight

        Keys.forwardTo: [searchField]

        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded) {
                    searchField.text = "";
                    searchField.forceActiveFocus();
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Search
            PlasmaExtras.SearchField {
                id: searchField
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.gridUnit
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                placeholderText: i18n("Search for apps, settings, and documents")
                onTextChanged: root.searchQuery = text
                Keys.onReturnPressed: searchResults.triggerFirst()
                Keys.onEscapePressed: root.close()
            }

            // Pinned + Recommended
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Kirigami.Units.gridUnit * 2
                Layout.rightMargin: Kirigami.Units.gridUnit * 2
                visible: !root.searching && root.page === "pinned"
                spacing: Kirigami.Units.largeSpacing

                SectionHeader {
                    title: i18n("Pinned")
                    buttonText: i18n("All apps") + "  ›"
                    onButtonClicked: root.page = "allApps"
                }

                GridView {
                    id: pinnedGrid
                    Layout.fillWidth: true
                    Layout.preferredHeight: cellHeight * 3
                    clip: true
                    interactive: contentHeight > height
                    cellWidth: Math.floor(width / 6)
                    cellHeight: Kirigami.Units.gridUnit * 5
                    model: rootModel.favoritesModel
                    delegate: Tile {
                        width: pinnedGrid.cellWidth
                        height: pinnedGrid.cellHeight
                        menuText: i18n("Unpin from Start")
                        onActivated: if (rootModel.favoritesModel.trigger(index, "", null)) root.close()
                        onMenuTriggered: rootModel.favoritesModel.removeFavorite(model.favoriteId)
                    }
                }

                SectionHeader {
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    title: i18n("Recommended")
                }

                GridView {
                    id: recommendedGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: Math.floor(width / 2)
                    cellHeight: Kirigami.Units.gridUnit * 3
                    model: recentDocsModel
                    delegate: WideRow {
                        width: recommendedGrid.cellWidth
                        height: recommendedGrid.cellHeight
                        onActivated: if (recentDocsModel.trigger(index, "", null)) root.close()
                    }

                    PC3.Label {
                        anchors.centerIn: parent
                        width: parent.width
                        visible: recommendedGrid.count === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                        text: i18n("The more you use your device, the more of your recent files will show up here.")
                    }
                }
            }

            // All apps
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Kirigami.Units.gridUnit * 2
                Layout.rightMargin: Kirigami.Units.gridUnit * 2
                visible: !root.searching && root.page === "allApps"
                spacing: Kirigami.Units.largeSpacing

                SectionHeader {
                    title: i18n("All apps")
                    buttonText: "‹  " + i18n("Back")
                    onButtonClicked: root.page = "pinned"
                }

                PC3.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: allAppsList
                        model: root.appsModel
                        section.property: "display"
                        section.criteria: ViewSection.FirstCharacter
                        section.delegate: PC3.Label {
                            required property string section
                            text: section.toUpperCase()
                            font.weight: Font.DemiBold
                            leftPadding: Kirigami.Units.largeSpacing
                            topPadding: Kirigami.Units.smallSpacing
                            bottomPadding: Kirigami.Units.smallSpacing
                        }
                        delegate: WideRow {
                            width: allAppsList.width
                            height: Kirigami.Units.gridUnit * 2.2
                            showDescription: false
                            menuText: rootModel.favoritesModel.isFavorite(model.favoriteId) ? "" : i18n("Pin to Start")
                            onActivated: if (allAppsList.model.trigger(index, "", null)) root.close()
                            onMenuTriggered: rootModel.favoritesModel.addFavorite(model.favoriteId, -1)
                        }
                    }
                }
            }

            // Search results
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Kirigami.Units.gridUnit * 2
                Layout.rightMargin: Kirigami.Units.gridUnit * 2
                visible: root.searching
                spacing: Kirigami.Units.largeSpacing

                SectionHeader {
                    title: i18n("Best matches")
                }

                PC3.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: searchResults
                        model: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null

                        function triggerFirst() {
                            if (model && count > 0 && model.trigger(0, "", null)) {
                                root.close();
                            }
                        }

                        delegate: WideRow {
                            width: searchResults.width
                            height: Kirigami.Units.gridUnit * 2.4
                            highlighted: index === 0
                            onActivated: if (searchResults.model.trigger(index, "", null)) root.close()
                        }
                    }
                }
            }

            // Footer: user and power
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3.5
                Layout.topMargin: Kirigami.Units.largeSpacing
                color: Qt.darker(Kirigami.Theme.backgroundColor, 1.03)

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Kirigami.Theme.textColor
                    opacity: 0.08
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.gridUnit * 2
                    anchors.rightMargin: Kirigami.Units.gridUnit * 2

                    PC3.ToolButton {
                        icon.name: "user-identity"
                        icon.source: kuser.faceIconUrl
                        text: kuser.fullName || kuser.loginName
                        display: PC3.AbstractButton.TextBesideIcon
                        onClicked: userMenu.popup()

                        PC3.Menu {
                            id: userMenu
                            PC3.MenuItem {
                                text: i18n("Change account settings")
                                icon.name: "system-users"
                                onTriggered: { KCM.KCMLauncher.openSystemSettings("kcm_users"); root.close(); }
                            }
                            PC3.MenuItem {
                                text: i18n("Lock")
                                icon.name: "system-lock-screen"
                                enabled: session.canLock
                                onTriggered: { root.close(); session.lock(); }
                            }
                            PC3.MenuItem {
                                text: i18n("Sign out")
                                icon.name: "system-log-out"
                                enabled: session.canLogout
                                onTriggered: { root.close(); session.requestLogout(); }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    PC3.ToolButton {
                        icon.name: "system-shutdown"
                        display: PC3.AbstractButton.IconOnly
                        text: i18n("Power")
                        PC3.ToolTip.text: text
                        PC3.ToolTip.visible: hovered
                        onClicked: powerMenu.popup()

                        PC3.Menu {
                            id: powerMenu
                            PC3.MenuItem {
                                text: i18n("Sleep")
                                icon.name: "system-suspend"
                                enabled: session.canSuspend
                                onTriggered: { root.close(); session.suspend(); }
                            }
                            PC3.MenuItem {
                                text: i18n("Shut down")
                                icon.name: "system-shutdown"
                                enabled: session.canShutdown
                                onTriggered: { root.close(); session.requestShutdown(); }
                            }
                            PC3.MenuItem {
                                text: i18n("Restart")
                                icon.name: "system-reboot"
                                enabled: session.canReboot
                                onTriggered: { root.close(); session.requestReboot(); }
                            }
                        }
                    }
                }
            }
        }
    }

    //BEGIN Components
    component SectionHeader: RowLayout {
        property string title
        property string buttonText: ""
        signal buttonClicked()

        Layout.fillWidth: true

        PC3.Label {
            text: parent.title
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        PC3.Button {
            visible: parent.buttonText.length > 0
            text: parent.buttonText
            flat: false
            onClicked: parent.buttonClicked()
        }
    }

    // Shared hover/press highlight for the tiles and rows below.
    component Highlight: Rectangle {
        property bool hovered: false
        property bool pressed: false
        property bool selected: false
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.textColor
        opacity: pressed ? 0.12 : (hovered || selected ? 0.06 : 0)
    }

    // Pinned app: icon above its name.
    component Tile: MouseArea {
        id: tile
        required property var model
        required property int index
        property string menuText: ""
        signal activated()
        signal menuTriggered()

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (menuText) tileMenu.popup();
            } else {
                activated();
            }
        }

        Highlight {
            anchors.fill: parent
            anchors.margins: 2
            hovered: tile.containsMouse
            pressed: tile.pressed
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: Kirigami.Units.iconSizes.medium
                source: tile.model.decoration
            }
            PC3.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                font: Kirigami.Theme.smallFont
                text: tile.model.display
            }
        }

        PC3.Menu {
            id: tileMenu
            PC3.MenuItem {
                text: tile.menuText
                onTriggered: tile.menuTriggered()
            }
        }
    }

    // App list entry, search result, or recommended file: icon beside its name.
    component WideRow: MouseArea {
        id: row
        required property var model
        required property int index
        property string menuText: ""
        property bool highlighted: false
        property bool showDescription: true
        signal activated()
        signal menuTriggered()

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (menuText) rowMenu.popup();
            } else {
                activated();
            }
        }

        Highlight {
            anchors.fill: parent
            anchors.margins: 1
            hovered: row.containsMouse
            pressed: row.pressed
            selected: row.highlighted
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                source: row.model.decoration
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: row.model.display
                }
                PC3.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    visible: row.showDescription && text.length > 0
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    text: row.model.description || ""
                }
            }
        }

        PC3.Menu {
            id: rowMenu
            PC3.MenuItem {
                text: row.menuText
                onTriggered: row.menuTriggered()
            }
        }
    }
    //END

    Component.onCompleted: {
        if (Plasmoid.hasOwnProperty("activationTogglesExpanded")) {
            Plasmoid.activationTogglesExpanded = true;
        }
    }
}
