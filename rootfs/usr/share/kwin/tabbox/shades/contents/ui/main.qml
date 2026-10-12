/*
    Shades task switcher (Alt+Tab), styled like Windows 11: a centered panel of window
    thumbnails, each with its app icon and title above it, the selected one outlined.
    Based on KWin's "Thumbnail Grid" switcher.

    SPDX-FileCopyrightText: 2020 Chris Holland <zrenfire@gmail.com>
    SPDX-FileCopyrightText: 2023 Nate Graham <nate@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kwin as KWin
import org.kde.kirigami as Kirigami

KWin.TabBoxSwitcher {
    id: tabBox

    Instantiator {
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            location: PlasmaCore.Types.Floating
            visible: true
            flags: Qt.Popup | Qt.X11BypassWindowManagerHint
            x: tabBox.screenGeometry.x + tabBox.screenGeometry.width * 0.5 - dialogMainItem.width * 0.5
            y: tabBox.screenGeometry.y + tabBox.screenGeometry.height * 0.5 - dialogMainItem.height * 0.5

            mainItem: FocusScope {
                id: dialogMainItem
                focus: true

                readonly property real screenFactor: tabBox.screenGeometry.width / tabBox.screenGeometry.height
                readonly property int maxWidth: tabBox.screenGeometry.width * 0.9
                readonly property int maxHeight: tabBox.screenGeometry.height * 0.8
                readonly property int columns: Math.max(1, Math.min(grid.count, Math.floor(maxWidth / grid.cellWidth)))
                readonly property int rows: Math.max(1, Math.ceil(grid.count / columns))

                width: Math.min(grid.cellWidth * columns, maxWidth)
                height: Math.min(grid.cellHeight * rows, maxHeight)
                clip: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    focus: true
                    model: tabBox.model
                    currentIndex: tabBox.currentIndex
                    keyNavigationWraps: true
                    highlightMoveDuration: 0

                    readonly property int padding: Kirigami.Units.largeSpacing
                    readonly property int captionHeight: Kirigami.Units.gridUnit * 1.6
                    readonly property int thumbnailWidth: Kirigami.Units.gridUnit * 13
                    readonly property int thumbnailHeight: Math.round(thumbnailWidth / dialogMainItem.screenFactor)
                    cellWidth: thumbnailWidth + padding * 2
                    cellHeight: captionHeight + thumbnailHeight + padding * 3

                    delegate: MouseArea {
                        id: item
                        required property int index
                        required property var model
                        width: grid.cellWidth
                        height: grid.cellHeight
                        hoverEnabled: true
                        onClicked: tabBox.model.activate(index)

                        Accessible.name: model.caption
                        Accessible.role: Accessible.ListItem

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: grid.padding
                            spacing: grid.padding

                            // Icon and title above the thumbnail, as in Windows 11.
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: grid.captionHeight
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    source: item.model.icon
                                }
                                PlasmaComponents3.Label {
                                    Layout.fillWidth: true
                                    text: item.model.caption
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents3.ToolButton {
                                    id: closeButton
                                    Layout.preferredWidth: grid.captionHeight
                                    Layout.preferredHeight: grid.captionHeight
                                    visible: item.model.closeable && typeof tabBox.model.close !== "undefined"
                                             && (item.containsMouse || closeButton.hovered)
                                    icon.name: "window-close-symbolic"
                                    onClicked: tabBox.model.close(item.index)
                                }
                            }

                            // KWin.WindowThumbnail needs a container to size itself.
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                KWin.WindowThumbnail {
                                    anchors.fill: parent
                                    wId: item.model.windowId
                                }
                            }
                        }
                    }

                    // Selected window: a rounded outline with a faint fill.
                    highlight: Rectangle {
                        radius: 8
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                        border.width: 2
                        border.color: Kirigami.Theme.textColor
                    }

                    onCurrentIndexChanged: tabBox.currentIndex = grid.currentIndex
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.largeSpacing * 2
                    icon.source: "edit-none"
                    text: i18ndc("kwin", "@info:placeholder no entries in the task switcher", "No open windows")
                    visible: grid.count === 0
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) {
                        grid.moveCurrentIndexLeft();
                    } else if (event.key === Qt.Key_Right) {
                        grid.moveCurrentIndexRight();
                    } else if (event.key === Qt.Key_Up) {
                        grid.moveCurrentIndexUp();
                    } else if (event.key === Qt.Key_Down) {
                        grid.moveCurrentIndexDown();
                    } else {
                        return;
                    }
                    grid.currentIndexChanged(grid.currentIndex);
                }
            }
        }
    }
}
