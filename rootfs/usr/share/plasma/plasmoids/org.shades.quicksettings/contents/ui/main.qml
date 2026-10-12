/*
    Shades Quick Settings: Windows 11's network / volume / battery button and flyout.
    The taskbar shows one button with the three status icons; clicking it opens toggle
    tiles (Wi-Fi, Bluetooth, Airplane mode, Battery saver), brightness and volume sliders,
    and the battery level with a Settings shortcut.
    Uses the same back-ends as Plasma's own network, volume, battery, brightness, and
    Bluetooth applets, which Shades removes from the system tray.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.private.volume
import org.kde.plasma.private.battery
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.workspace.components as WorkspaceComponents
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.mpris as Mpris
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    toolTipMainText: i18n("Quick Settings")
    toolTipSubText: [networkStatus.activeConnections, volumeText, batteryText].filter(t => t).join("\n")

    readonly property bool lightTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Light

    //BEGIN Network
    PlasmaNM.NetworkStatus { id: networkStatus }
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.AvailableDevices { id: availableDevices }
    PlasmaNM.Handler { id: nmHandler }
    PlasmaNM.ConnectionIcon {
        id: connectionIcon
        connectivity: networkStatus.connectivity
    }
    readonly property bool airplaneModeAvailable: availableDevices.modemDeviceAvailable || availableDevices.wirelessDeviceAvailable
    //END

    //BEGIN Volume
    SinkModel { id: sinkModel }
    readonly property var sink: PreferredDevice.sink
    readonly property bool hasSink: sink !== null && sink !== undefined
    readonly property int volumePercent: hasSink ? Math.round(sink.volume / PulseAudio.NormalVolume * 100) : 0
    readonly property string volumeIcon: AudioIcon.forVolume(volumePercent, hasSink ? sink.muted : true, "")
    readonly property string volumeText: hasSink ? (sink.muted ? i18n("Volume muted") : i18n("Volume %1%", volumePercent)) : ""

    function setVolumePercent(percent: int) {
        if (!hasSink) {
            return;
        }
        sink.volume = Math.round(Math.max(0, Math.min(100, percent)) * PulseAudio.NormalVolume / 100);
        if (sink.muted && percent > 0) {
            sink.muted = false;
        }
    }
    //END

    //BEGIN Power
    BatteryControlModel { id: battery }
    PowerProfilesControl { id: powerProfiles }
    ScreenBrightnessControl {
        id: screenBrightness
        isSilent: root.expanded
    }
    readonly property bool hasBattery: battery.hasInternalBatteries
    readonly property string batteryText: hasBattery ? i18n("Battery %1%", battery.percent) : ""
    readonly property bool batterySaverOn: powerProfiles.activeProfile === "power-saver"
    //END

    //BEGIN Do not disturb
    NotificationManager.Settings { id: notificationSettings }
    readonly property bool doNotDisturb: {
        const until = notificationSettings.notificationsInhibitedUntil;
        return !!until && until.getTime() > Date.now();
    }
    function setDoNotDisturb(enable: bool) {
        if (enable) {
            const until = new Date();
            until.setFullYear(until.getFullYear() + 1);  // "until turned off", as Plasma does it
            notificationSettings.notificationsInhibitedUntil = until;
        } else {
            notificationSettings.notificationsInhibitedUntil = undefined;
            notificationSettings.revokeApplicationInhibitions();
        }
        notificationSettings.save();
    }
    //END

    //BEGIN Media (whatever is playing, via MPRIS)
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool hasMedia: !!player && player.playbackStatus > Mpris.PlaybackStatus.Stopped
    readonly property bool mediaPlaying: hasMedia && player.playbackStatus === Mpris.PlaybackStatus.Playing
    //END

    //BEGIN Bluetooth
    readonly property bool bluetoothAvailable: BluezQt.Manager.adapters.length > 0 || BluezQt.Manager.bluetoothBlocked
    function setBluetoothEnabled(enable: bool) {
        BluezQt.Manager.bluetoothBlocked = !enable;
        BluezQt.Manager.adapters.forEach(adapter => {
            adapter.powered = enable;
        });
    }
    //END

    compactRepresentation: MouseArea {
        id: compactRoot
        Layout.minimumWidth: statusIcons.implicitWidth + Kirigami.Units.largeSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        // Like Windows, scrolling over the button changes the volume.
        onWheel: wheel => {
            root.setVolumePercent(root.volumePercent + (wheel.angleDelta.y > 0 ? 2 : -2));
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: Math.min(parent.height, Kirigami.Units.gridUnit * 2.2) - Kirigami.Units.smallSpacing
            radius: 4
            color: root.lightTheme ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.07)
            opacity: compactRoot.containsMouse || root.expanded ? 1 : 0
        }

        RowLayout {
            id: statusIcons
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing * 2

            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                source: connectionIcon.connectionIcon + "-symbolic"
            }
            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                visible: root.hasSink
                source: root.volumeIcon
            }
            WorkspaceComponents.BatteryIcon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                visible: root.hasBattery
                hasBattery: true
                percent: battery.percent
                pluggedIn: battery.pluggedIn
            }
        }
    }

    fullRepresentation: ColumnLayout {
        id: flyout
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumWidth: Layout.preferredWidth
        spacing: 0

        // Now playing: album art, title and artist, and previous / play-pause / next,
        // shown above the tiles while something is playing, as in Windows 11.
        Rectangle {
            visible: root.hasMedia
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.gridUnit
            Layout.bottomMargin: 0
            Layout.preferredHeight: mediaRow.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: 6
            color: root.lightTheme ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)

            RowLayout {
                id: mediaRow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                Image {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.6
                    Layout.preferredHeight: Layout.preferredWidth
                    source: root.player?.artUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    sourceSize.width: Layout.preferredWidth * 2
                }
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.6
                    Layout.preferredHeight: Layout.preferredWidth
                    visible: !(root.player?.artUrl)
                    source: root.player?.iconName || "media-default-album"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PC3.Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                        text: root.player?.track || root.player?.identity || ""
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                        text: root.player?.artist || root.player?.identity || ""
                    }
                }
                PC3.ToolButton {
                    icon.name: "media-skip-backward"
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player.Previous()
                }
                PC3.ToolButton {
                    icon.name: root.mediaPlaying ? "media-playback-pause" : "media-playback-start"
                    enabled: root.player?.canControl ?? false
                    onClicked: root.mediaPlaying ? root.player.Pause() : root.player.Play()
                }
                PC3.ToolButton {
                    icon.name: "media-skip-forward"
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player.Next()
                }
            }
        }

        // Toggle tiles, three to a row. Hardware tiles only show when the machine has it.
        GridLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.gridUnit
            columns: 3
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing

            ToggleTile {
                id: wifiTile
                visible: availableDevices.wirelessDeviceAvailable
                label: i18n("Wi-Fi")
                iconName: "network-wireless-symbolic"
                checked: enabledConnections.wirelessEnabled
                enabled: enabledConnections.wirelessHwEnabled && !PlasmaNM.Configuration.airplaneModeEnabled
                settingsModule: "kcm_networkmanagement"
                onToggled: nmHandler.enableWireless(!checked)
            }
            ToggleTile {
                id: bluetoothTile
                visible: root.bluetoothAvailable
                label: i18n("Bluetooth")
                iconName: "network-bluetooth-symbolic"
                checked: BluezQt.Manager.bluetoothOperational
                settingsModule: "kcm_bluetooth"
                onToggled: root.setBluetoothEnabled(!checked)
            }
            ToggleTile {
                id: airplaneTile
                visible: root.airplaneModeAvailable
                label: i18n("Airplane mode")
                iconName: "network-flightmode-on-symbolic"
                checked: PlasmaNM.Configuration.airplaneModeEnabled
                onToggled: {
                    const enable = !checked;
                    nmHandler.enableAirplaneMode(enable);
                    PlasmaNM.Configuration.airplaneModeEnabled = enable;
                }
            }
            ToggleTile {
                id: saverTile
                visible: root.hasBattery && powerProfiles.profiles.includes("power-saver")
                label: i18n("Battery saver")
                iconName: "battery-profile-powersave-symbolic"
                checked: root.batterySaverOn
                onToggled: powerProfiles.setProfile(checked ? (powerProfiles.configuredProfile || "balanced") : "power-saver")
            }
            ToggleTile {
                label: i18n("Do not disturb")
                iconName: "notifications-disabled-symbolic"
                checked: root.doNotDisturb
                onToggled: root.setDoNotDisturb(!checked)
            }
        }

        // Brightness (laptops and other screens that support it)
        Repeater {
            model: screenBrightness.isBrightnessAvailable ? screenBrightness.displays : null
            delegate: SliderRow {
                required property int index
                required property string displayName
                required property int brightness
                required property int maxBrightness
                visible: index === 0
                iconName: "brightness-high-symbolic"
                from: 0
                to: maxBrightness
                value: brightness
                onMoved: v => screenBrightness.setBrightness(displayName, v)
            }
        }

        // Volume
        SliderRow {
            visible: root.hasSink
            iconName: root.volumeIcon
            iconTip: root.hasSink && root.sink.muted ? i18n("Unmute") : i18n("Mute")
            onIconClicked: if (root.hasSink) root.sink.muted = !root.sink.muted
            from: 0
            to: 100
            value: root.volumePercent
            onMoved: v => root.setVolumePercent(v)
            settingsModule: "kcm_pulseaudio"
        }

        // Footer: battery on the left, Settings on the right
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.6
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
                anchors.leftMargin: Kirigami.Units.gridUnit
                anchors.rightMargin: Kirigami.Units.largeSpacing

                WorkspaceComponents.BatteryIcon {
                    visible: root.hasBattery
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    hasBattery: true
                    percent: battery.percent
                    pluggedIn: battery.pluggedIn
                }
                PC3.Label {
                    visible: root.hasBattery
                    text: battery.percent + "%"
                }
                Item { Layout.fillWidth: true }
                PC3.ToolButton {
                    icon.name: "configure"
                    display: PC3.AbstractButton.IconOnly
                    text: i18n("All settings")
                    PC3.ToolTip.text: text
                    PC3.ToolTip.visible: hovered
                    onClicked: {
                        KCM.KCMLauncher.openSystemSettings("");
                        root.expanded = false;
                    }
                }
            }
        }
    }

    //BEGIN Components
    // A Windows 11 quick-settings tile: a rounded button filled with the accent color
    // when on, with an optional ">" side that opens the matching Settings page.
    component ToggleTile: ColumnLayout {
        id: tile
        property string label
        property string iconName
        property bool checked: false
        property string settingsModule: ""
        signal toggled()

        // A fixed third of the flyout, so a lone tile doesn't stretch across it.
        // (Nested layouts fill by default, hence fillWidth: false.)
        Layout.fillWidth: false
        Layout.preferredWidth: Kirigami.Units.gridUnit * 5.6
        Layout.maximumWidth: Layout.preferredWidth
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.6
            radius: 4
            opacity: tile.enabled ? 1 : 0.5
            color: tile.checked ? Kirigami.Theme.highlightColor
                 : (root.lightTheme ? Qt.rgba(1, 1, 1, mainArea.containsMouse ? 1 : 0.8) : Qt.rgba(1, 1, 1, mainArea.containsMouse ? 0.12 : 0.08))
            border.width: tile.checked ? 0 : 1
            border.color: root.lightTheme ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(1, 1, 1, 0.1)

            RowLayout {
                anchors.fill: parent
                spacing: 0

                MouseArea {
                    id: mainArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    hoverEnabled: true
                    onClicked: tile.toggled()

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                        source: tile.iconName
                        color: tile.checked ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        isMask: true
                    }
                }
                Rectangle {
                    visible: tile.settingsModule.length > 0
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.smallSpacing * 2
                    Layout.bottomMargin: Kirigami.Units.smallSpacing * 2
                    color: tile.checked ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    opacity: 0.25
                }
                MouseArea {
                    visible: tile.settingsModule.length > 0
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
                    Layout.fillHeight: true
                    onClicked: {
                        KCM.KCMLauncher.openSystemSettings(tile.settingsModule);
                        root.expanded = false;
                    }

                    PC3.Label {
                        anchors.centerIn: parent
                        text: "›"
                        color: tile.checked ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    }
                }
            }
        }
        PC3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
            text: tile.label
        }
    }

    // Icon + slider, like Windows 11's brightness and volume rows.
    component SliderRow: RowLayout {
        id: sliderRow
        property string iconName
        property string iconTip: ""
        property real from: 0
        property real to: 100
        property real value: 0
        property string settingsModule: ""
        signal moved(real value)
        signal iconClicked()

        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        Layout.rightMargin: Kirigami.Units.gridUnit
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing

        PC3.ToolButton {
            icon.name: sliderRow.iconName
            display: PC3.AbstractButton.IconOnly
            text: sliderRow.iconTip
            enabled: sliderRow.iconTip.length > 0
            PC3.ToolTip.text: text
            PC3.ToolTip.visible: hovered && text.length > 0
            onClicked: sliderRow.iconClicked()
        }
        PC3.Slider {
            Layout.fillWidth: true
            from: sliderRow.from
            to: sliderRow.to
            stepSize: 1
            value: sliderRow.value
            onMoved: sliderRow.moved(value)
        }
        PC3.ToolButton {
            visible: sliderRow.settingsModule.length > 0
            text: "›"
            onClicked: {
                KCM.KCMLauncher.openSystemSettings(sliderRow.settingsModule);
                root.expanded = false;
            }
        }
    }
    //END
}
