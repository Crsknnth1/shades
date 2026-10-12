/*
    Shades login screen (SDDM), styled like Windows 11's:
    first a big clock over the wallpaper; any key or click reveals a dimmed wallpaper with
    the user's round picture, name, and a password box (arrow inside). Other users are
    listed bottom-left; Sleep / Restart / Shut down sit behind the power button bottom-right.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: 1600
    height: 900
    color: "black"

    property bool signingIn: false
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    readonly property color accent: "#0067c0"

    // Current user's details, read from the model through a hidden Repeater.
    property string userName: ""
    property string userRealName: ""
    property string userIcon: ""

    Repeater {
        model: userModel
        delegate: Item {
            required property int index
            required property string name
            required property string realName
            required property string icon
            Component.onCompleted: if (index === root.userIndex) root.pickUser(index, name, realName, icon)
        }
    }

    function pickUser(index, name, realName, icon) {
        userIndex = index;
        userName = name;
        userRealName = realName || name;
        userIcon = icon;
        password.text = "";
        error.text = "";
        password.forceActiveFocus();
    }

    function signIn() {
        error.text = "";
        busy.running = true;
        sddm.login(userName, password.text, sessionModel.lastIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            busy.running = false;
            error.text = qsTr("The password is incorrect. Try again.");
            password.text = "";
            password.forceActiveFocus();
        }
    }

    // Wallpaper, dimmed on the sign-in step.
    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.signingIn ? 0.45 : 0.08
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    // Step 1: clock and date.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.12
        visible: !root.signingIn
        spacing: 4

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            font.family: config.font
            font.pixelSize: 112
            font.weight: Font.DemiBold
            text: root.timeText(new Date())
        }
        Text {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            font.family: config.font
            font.pixelSize: 26
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
        }
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                clock.text = root.timeText(new Date());
                date.text = Qt.formatDate(new Date(), "dddd, MMMM d");
            }
        }
    }

    // Any click or key on the clock step moves to signing in.
    MouseArea {
        anchors.fill: parent
        enabled: !root.signingIn
        onClicked: root.revealSignIn()
    }
    focus: !root.signingIn
    Keys.onPressed: event => {
        if (!root.signingIn) {
            root.revealSignIn();
            event.accepted = true;
        }
    }
    // "8:12", like Windows' lock screen: 12-hour, no AM/PM.
    function timeText(d) {
        return (d.getHours() % 12 || 12) + ":" + String(d.getMinutes()).padStart(2, "0");
    }

    function revealSignIn() {
        signingIn = true;
        password.forceActiveFocus();
    }

    // Step 2: user picture, name, password.
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        visible: root.signingIn
        spacing: 18

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 192
            height: 192
            radius: width / 2
            color: "#3b3b3b"
            clip: true

            Image {
                id: face
                anchors.fill: parent
                // SDDM's stock picture is low-resolution; draw the default below instead.
                source: root.userIcon.replace("file://", "").startsWith("/usr/share/sddm/") ? "" : root.userIcon
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                layer.enabled: true
            }
            // Default picture: a person outline, like Windows' default account picture.
            Item {
                anchors.fill: parent
                visible: !face.visible
                Rectangle {
                    width: parent.width * 0.32
                    height: width
                    radius: width / 2
                    x: (parent.width - width) / 2
                    y: parent.height * 0.24
                    color: "#d6d6d6"
                }
                Rectangle {
                    width: parent.width * 0.62
                    height: parent.height * 0.5
                    radius: width / 2
                    x: (parent.width - width) / 2
                    y: parent.height * 0.62
                    color: "#d6d6d6"
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            font.family: config.font
            font.pixelSize: 30
            text: root.userRealName
        }

        // Password box with the arrow button inside it.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 296
            height: 36
            radius: 4
            color: password.activeFocus ? "#ffffff" : "#f2f2f2"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.2)

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 2
                color: password.activeFocus ? root.accent : "transparent"
            }

            TextField {
                id: password
                anchors.left: parent.left
                anchors.right: go.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 4
                echoMode: TextInput.Password
                placeholderText: qsTr("Password")
                font.family: config.font
                font.pixelSize: 15
                color: "#1b1b1b"
                placeholderTextColor: "#6b6b6b"
                background: null
                enabled: !busy.running
                Keys.onReturnPressed: root.signIn()
                Keys.onEnterPressed: root.signIn()
                Keys.onEscapePressed: root.signingIn = false
            }

            Button {
                id: go
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 4
                width: 28
                height: 28
                flat: true
                enabled: !busy.running
                onClicked: root.signIn()
                contentItem: Text {
                    text: "→"
                    color: "#1b1b1b"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 3
                    color: go.hovered ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                }
            }
        }

        BusyIndicator {
            id: busy
            anchors.horizontalCenter: parent.horizontalCenter
            running: false
            visible: running
            width: 32
            height: 32
        }

        Text {
            id: error
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            font.family: config.font
            font.pixelSize: 14
            visible: text.length > 0
        }
    }

    // Other users, bottom-left (only when there's more than one).
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 4
        visible: root.signingIn && userModel.count > 1

        Repeater {
            model: userModel
            delegate: Rectangle {
                required property int index
                required property string name
                required property string realName
                required property string icon
                width: 240
                height: 44
                radius: 4
                color: index === root.userIndex ? Qt.rgba(1, 1, 1, 0.2)
                     : (userArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    spacing: 10
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: "#5a5a5a"
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: icon
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"
                        font.family: config.font
                        font.pixelSize: 15
                        text: realName || name
                    }
                }
                MouseArea {
                    id: userArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.pickUser(index, name, realName, icon)
                }
            }
        }
    }

    // Power button, bottom-right.
    Button {
        id: powerButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        width: 44
        height: 44
        visible: root.signingIn
        flat: true
        onClicked: powerMenu.open()
        contentItem: Text {
            text: "⏻"
            color: "white"
            font.pixelSize: 22
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 4
            color: powerButton.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        }

        Menu {
            id: powerMenu
            y: -height - 4
            MenuItem {
                text: qsTr("Sleep")
                enabled: sddm.canSuspend
                onTriggered: sddm.suspend()
            }
            MenuItem {
                text: qsTr("Shut down")
                enabled: sddm.canPowerOff
                onTriggered: sddm.powerOff()
            }
            MenuItem {
                text: qsTr("Restart")
                enabled: sddm.canReboot
                onTriggered: sddm.reboot()
            }
        }
    }

    Component.onCompleted: {
        if (userModel.count > 0 && root.userName === "") {
            root.userIndex = 0;
        }
        // Take the keyboard so any key press on the clock step reveals sign-in.
        root.forceActiveFocus();
    }
}
