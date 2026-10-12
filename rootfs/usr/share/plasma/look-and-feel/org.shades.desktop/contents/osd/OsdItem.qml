/*
    Shades on-screen display: a compact Windows 11-style pill for volume, brightness and
    similar changes (icon, thin accent bar, value), or just the text for messages such as a
    keyboard-layout switch. Same properties as Plasma's Breeze OSD, which this replaces.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    // How long the OSD stays up, in ms
    property int timeout: 1800
    // A number (shown as a bar) when showingProgress is true, otherwise text
    property var osdValue
    property int osdMaxValue: 100
    property string osdAdditionalText: ""
    property string icon
    property bool showingProgress: false

    spacing: Kirigami.Units.largeSpacing

    readonly property real pillWidth: showingProgress ? Kirigami.Units.gridUnit * 12
                                                      : Math.min(implicitWidth, Screen.desktopAvailableWidth / 2)
    Layout.preferredWidth: pillWidth
    Layout.preferredHeight: Kirigami.Units.gridUnit * 2
    Layout.minimumWidth: Layout.preferredWidth
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumWidth: Layout.preferredWidth
    Layout.maximumHeight: Layout.preferredHeight
    width: Layout.preferredWidth
    height: Layout.preferredHeight

    Kirigami.Icon {
        id: iconItem
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        Layout.alignment: Qt.AlignVCenter
        source: root.icon
        visible: valid
    }

    // Value bar: a thin track with an accent-colored fill, like Windows' volume flyout.
    Item {
        visible: root.showingProgress
        Layout.fillWidth: true
        Layout.preferredHeight: 4
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Kirigami.Theme.textColor
            opacity: 0.2
        }
        Rectangle {
            height: parent.height
            radius: height / 2
            width: parent.width * Math.max(0, Math.min(1, Number(root.osdValue) / Math.max(1, root.osdMaxValue)))
            color: Number(root.osdValue) > 100 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
            Behavior on width {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
    }

    PlasmaComponents3.Label {
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: !root.showingProgress
        horizontalAlignment: root.showingProgress ? Text.AlignRight : Text.AlignHCenter
        textFormat: Text.PlainText
        elide: Text.ElideRight
        // The value as a plain number (Windows shows "42", not "42%"), or the message text.
        text: root.showingProgress ? String(Math.round(Number(root.osdValue)))
                                   : ((root.osdValue ?? "") + (root.osdAdditionalText ? " " + root.osdAdditionalText : ""))
        Layout.preferredWidth: root.showingProgress ? Math.ceil(widest.advanceWidth) : -1

        TextMetrics {
            id: widest
            text: "100"
        }
    }
}
