/*
    Shades Task Manager: a Windows 11-style Task Manager built on KDE's process and sensor
    engines (the same ones Plasma System Monitor uses).

    Pages, as in Windows: Processes (Apps and Background processes, with CPU / Memory /
    Disk / Network columns shaded by load), Performance (live graphs), Startup apps, and
    Details (every process). Run with /usr/bin/shades-taskmanager.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.process as Process
import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.formatter as Formatter
import org.kde.taskmanager as TaskManager
import org.kde.quickcharts as Charts
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kcmutils as KCM

ApplicationWindow {
    id: win
    title: qsTr("Task Manager")
    width: 980
    height: 680
    minimumWidth: 640
    minimumHeight: 420
    visible: true
    color: Kirigami.Theme.backgroundColor

    readonly property bool lightTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Light
    readonly property color cardColor: lightTheme ? "#fbfbfb" : "#2b2b2b"
    readonly property color lineColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
    readonly property color accent: Kirigami.Theme.highlightColor

    property int page: 0          // 0 Processes, 1 Performance, 2 Startup apps, 3 Details
    property string filter: ""
    property int selectedPid: -1
    property string selectedName: ""

    // ---------------------------------------------------------------- data

    // Column order of the process model (see enabledAttributes below).
    readonly property var cols: ({ name: 0, pid: 1, ppid: 2, usage: 3, mem: 4, read: 5, write: 6, netIn: 7, netOut: 8, user: 9, status: 10 })

    Process.ProcessDataModel {
        id: procModel
        flatList: true
        enabledAttributes: ["name", "pid", "parentPid", "usage", "vmPSS",
            "ioCharactersActuallyReadRate", "ioCharactersActuallyWrittenRate",
            "netInbound", "netOutbound", "username", "status"]
    }

    Process.ProcessController {
        id: controller
    }

    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    Sensors.Sensor { id: cpuSensor; sensorId: "cpu/all/usage" }
    Sensors.Sensor { id: cpuSpeed; sensorId: "cpu/all/averageFrequency" }
    Sensors.Sensor { id: cpuCores; sensorId: "cpu/all/coreCount" }
    Sensors.Sensor { id: memUsed; sensorId: "memory/physical/used" }
    Sensors.Sensor { id: memTotal; sensorId: "memory/physical/total" }
    Sensors.Sensor { id: memPercent; sensorId: "memory/physical/usedPercent" }
    Sensors.Sensor { id: diskRead; sensorId: "disk/all/read" }
    Sensors.Sensor { id: diskWrite; sensorId: "disk/all/write" }
    Sensors.Sensor { id: netDown; sensorId: "network/all/download" }
    Sensors.Sensor { id: netUp; sensorId: "network/all/upload" }
    Sensors.Sensor { id: uptime; sensorId: "os/system/uptime" }

    // Snapshot rebuilt every second, like Windows' "Normal" update speed.
    property var apps: []          // [{name, icon, pid, cpu, mem, disk, net, count}]
    property var backgroundProcs: []// [{name, pid, cpu, mem, disk, net}]
    property var details: []       // every process
    property real totalMemBytes: 1

    // Rolling history for the Performance graphs (60 samples).
    property var cpuHistory: []
    property var memHistory: []
    property var diskHistory: []
    property var netHistory: []

    function value(row, col) {
        return procModel.data(procModel.index(row, col), Process.ProcessDataModel.Value);
    }

    function pushHistory(list, v) {
        const next = list.slice(Math.max(0, list.length - 59));
        next.push(isFinite(v) ? v : 0);
        return next;
    }

    function refresh() {
        const byPid = {};
        const children = {};
        for (let r = 0; r < procModel.rowCount(); r++) {
            const p = {
                name: String(value(r, cols.name) ?? ""),
                pid: Number(value(r, cols.pid)),
                ppid: Number(value(r, cols.ppid)),
                cpu: Number(value(r, cols.usage)) || 0,
                // vmPSS is reported in KiB.
                mem: (Number(value(r, cols.mem)) || 0) * 1024,
                disk: (Number(value(r, cols.read)) || 0) + (Number(value(r, cols.write)) || 0),
                net: (Number(value(r, cols.netIn)) || 0) + (Number(value(r, cols.netOut)) || 0),
                user: String(value(r, cols.user) ?? ""),
                status: String(value(r, cols.status) ?? ""),
            };
            // Unnamed entries are kernel helpers and "finished" ones have already exited;
            // Windows lists neither.
            if (!p.pid || !p.name || p.status === "finished" || p.status === "zombie") {
                continue;
            }
            byPid[p.pid] = p;
            (children[p.ppid] = children[p.ppid] || []).push(p.pid);
        }

        // Apps: every window's process plus its children, added up, as Windows groups them.
        const claimed = {};
        const appRows = [];
        for (let i = 0; i < tasks.count; i++) {
            const ix = tasks.index(i, 0);
            const pid = Number(tasks.data(ix, TaskManager.AbstractTasksModel.AppPid));
            if (!pid || claimed[pid] || !byPid[pid]) {
                continue;
            }
            const app = {
                name: String(tasks.data(ix, TaskManager.AbstractTasksModel.AppName) || byPid[pid].name),
                icon: tasks.data(ix, Qt.DecorationRole),
                pid: pid, cpu: 0, mem: 0, disk: 0, net: 0, count: 0,
            };
            const stack = [pid];
            while (stack.length) {
                const q = stack.pop();
                if (claimed[q] || !byPid[q]) {
                    continue;
                }
                claimed[q] = true;
                const p = byPid[q];
                app.cpu += p.cpu; app.mem += p.mem; app.disk += p.disk; app.net += p.net; app.count++;
                for (const c of (children[q] || [])) {
                    stack.push(c);
                }
            }
            appRows.push(app);
        }

        const bg = [];
        const all = [];
        for (const pid in byPid) {
            const p = byPid[pid];
            all.push(p);
            if (!claimed[pid]) {
                bg.push(p);
            }
        }

        const byName = (a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" });
        appRows.sort(byName);
        bg.sort(byName);
        all.sort(byName);

        apps = appRows;
        backgroundProcs = bg;
        details = all;
        totalMemBytes = Math.max(1, Number(memTotal.value) || 1);

        cpuHistory = pushHistory(cpuHistory, Number(cpuSensor.value));
        memHistory = pushHistory(memHistory, Number(memPercent.value));
        diskHistory = pushHistory(diskHistory, (Number(diskRead.value) || 0) + (Number(diskWrite.value) || 0));
        netHistory = pushHistory(netHistory, (Number(netDown.value) || 0) + (Number(netUp.value) || 0));
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: win.refresh()
    }

    function matches(name, pid) {
        if (!filter) {
            return true;
        }
        const f = filter.toLowerCase();
        return name.toLowerCase().indexOf(f) !== -1 || String(pid).indexOf(f) === 0;
    }

    function formatBytes(bytes) {
        if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + " GB";
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB";
        if (bytes >= 1024) return (bytes / 1024).toFixed(1) + " KB";
        return Math.round(bytes) + " B";
    }
    function formatRate(bytesPerSec) {
        return (bytesPerSec / 1048576).toFixed(1) + " MB/s";
    }
    function formatNet(bytesPerSec) {
        return (bytesPerSec * 8 / 1000000).toFixed(1) + " Mbps";
    }

    // Windows shades busy cells yellow-to-orange.
    function heat(fraction) {
        const f = Math.max(0, Math.min(1, fraction));
        if (f < 0.005) {
            return "transparent";
        }
        return lightTheme ? Qt.rgba(1, 0.86 - 0.35 * f, 0.4 - 0.3 * f, 0.25 + 0.6 * f)
                          : Qt.rgba(0.55, 0.4 - 0.2 * f, 0.05, 0.3 + 0.5 * f);
    }

    function endTask() {
        if (selectedPid > 0) {
            controller.sendSignal([selectedPid], Process.ProcessController.TerminateSignal);
            selectedPid = -1;
            selectedName = "";
        }
    }

    // ---------------------------------------------------------------- layout

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Navigation, like Windows 11's left rail.
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: false
            Layout.preferredWidth: Kirigami.Units.gridUnit * 11
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: 2

            Repeater {
                model: [
                    { text: qsTr("Processes"), icon: "view-list-details" },
                    { text: qsTr("Performance"), icon: "office-chart-area" },
                    { text: qsTr("Startup apps"), icon: "system-run" },
                    { text: qsTr("Details"), icon: "view-list-text" },
                ]
                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                    height: Kirigami.Units.gridUnit * 2.2
                    highlighted: win.page === index
                    onClicked: win.page = index

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Rectangle {
                            Layout.preferredWidth: 3
                            Layout.preferredHeight: Kirigami.Units.gridUnit
                            radius: 1.5
                            color: win.accent
                            opacity: win.page === index ? 1 : 0
                        }
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: modelData.icon
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.text
                        }
                    }
                    background: Rectangle {
                        radius: 4
                        color: win.page === index ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
                             : (parent.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04) : "transparent")
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // Content card.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            color: win.cardColor
            radius: 8
            border.width: 1
            border.color: win.lineColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                // Page title, search, and actions.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    Label {
                        text: [qsTr("Processes"), qsTr("Performance"), qsTr("Startup apps"), qsTr("Details")][win.page]
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    TextField {
                        visible: win.page === 0 || win.page === 3
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                        placeholderText: qsTr("Type a name or PID to search")
                        onTextChanged: win.filter = text
                    }
                    Button {
                        text: qsTr("Run new task")
                        icon.name: "system-run"
                        flat: true
                        onClicked: win.runNewTask()
                    }
                    Button {
                        visible: win.page === 0 || win.page === 3
                        text: qsTr("End task")
                        icon.name: "process-stop"
                        enabled: win.selectedPid > 0
                        onClicked: win.endTask()
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: win.page

                    ProcessesPage {}
                    PerformancePage {}
                    StartupPage {}
                    DetailsPage {}
                }
            }
        }
    }

    // "Run new task" opens the Run box (KRunner), like Windows' Run dialog.
    function runNewTask() {
        DBus.SessionBus.asyncCall({
            service: "org.kde.krunner",
            path: "/App",
            iface: "org.kde.krunner.App",
            member: "display",
            arguments: [],
            signature: "",
        });
    }

    // ---------------------------------------------------------------- pages

    component HeaderCell: ColumnLayout {
        property string title
        property string total: ""
        property int align: Text.AlignRight
        spacing: 0
        Label {
            Layout.fillWidth: true
            horizontalAlignment: parent.align
            text: parent.total
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
            visible: text.length > 0
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: parent.align
            text: parent.title
            opacity: 0.75
        }
    }

    component ValueCell: Rectangle {
        property string text
        property real load: 0
        color: win.heat(load)
        Label {
            anchors.fill: parent
            anchors.rightMargin: Kirigami.Units.largeSpacing
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: parent.text
        }
    }

    // One row of the Processes table (an app or a background process).
    component ProcessRow: Rectangle {
        id: row
        required property var entry
        property bool isApp: false
        width: ListView.view ? ListView.view.width : 0
        height: Kirigami.Units.gridUnit * 1.8
        color: win.selectedPid === entry.pid ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.18)
             : (rowArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04) : "transparent")

        RowLayout {
            anchors.fill: parent
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: row.isApp ? row.entry.icon : "application-x-executable"
                }
                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: row.isApp && row.entry.count > 1 ? row.entry.name + " (" + row.entry.count + ")" : row.entry.name
                }
            }
            ValueCell {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                Layout.fillHeight: true
                text: row.entry.cpu.toFixed(1) + "%"
                load: row.entry.cpu / 100
            }
            ValueCell {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                Layout.fillHeight: true
                text: win.formatBytes(row.entry.mem)
                load: row.entry.mem / win.totalMemBytes * 4
            }
            ValueCell {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 5.5
                Layout.fillHeight: true
                text: win.formatRate(row.entry.disk)
                load: row.entry.disk / 20971520
            }
            ValueCell {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 5.5
                Layout.fillHeight: true
                text: win.formatNet(row.entry.net)
                load: row.entry.net / 1250000
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                win.selectedPid = row.entry.pid;
                win.selectedName = row.entry.name;
                if (mouse.button === Qt.RightButton) {
                    rowMenu.popup();
                }
            }
        }
        Menu {
            id: rowMenu
            MenuItem { text: qsTr("End task"); onTriggered: win.endTask() }
            MenuItem {
                text: qsTr("Go to details")
                onTriggered: win.page = 3
            }
        }
    }

    component ProcessesPage: ColumnLayout {
        spacing: 0

        // Header with totals, like Windows ("57%" above "CPU").
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: 0
            HeaderCell {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                title: qsTr("Name")
                align: Text.AlignLeft
            }
            HeaderCell {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                Layout.rightMargin: Kirigami.Units.largeSpacing
                title: qsTr("CPU")
                total: Math.round(Number(cpuSensor.value) || 0) + "%"
            }
            HeaderCell {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                Layout.rightMargin: Kirigami.Units.largeSpacing
                title: qsTr("Memory")
                total: Math.round(Number(memPercent.value) || 0) + "%"
            }
            HeaderCell {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 5.5
                Layout.rightMargin: Kirigami.Units.largeSpacing
                title: qsTr("Disk")
                total: win.formatRate((Number(diskRead.value) || 0) + (Number(diskWrite.value) || 0))
            }
            HeaderCell {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 5.5
                Layout.rightMargin: Kirigami.Units.largeSpacing
                title: qsTr("Network")
                total: win.formatNet((Number(netDown.value) || 0) + (Number(netUp.value) || 0))
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: win.lineColor }

        ScrollView {
            id: procScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                width: procScroll.availableWidth

                SectionLabel {
                    text: qsTr("Apps") + " (" + appList.count + ")"
                }
                ListView {
                    id: appList
                    width: parent.width
                    height: contentHeight
                    interactive: false
                    model: win.apps.filter(a => win.matches(a.name, a.pid))
                    delegate: ProcessRow {
                        required property var modelData
                        entry: modelData
                        isApp: true
                    }
                }
                SectionLabel {
                    text: qsTr("Background processes") + " (" + bgList.count + ")"
                }
                ListView {
                    id: bgList
                    width: parent.width
                    height: contentHeight
                    interactive: false
                    model: win.backgroundProcs.filter(p => win.matches(p.name, p.pid))
                    delegate: ProcessRow {
                        required property var modelData
                        entry: modelData
                    }
                }
            }
        }
    }

    component SectionLabel: Label {
        leftPadding: Kirigami.Units.largeSpacing
        topPadding: Kirigami.Units.largeSpacing
        bottomPadding: Kirigami.Units.smallSpacing
        font.weight: Font.DemiBold
    }

    // Performance: a tile per resource with a sparkline; the selected one large on the right.
    component PerformancePage: RowLayout {
        id: perf
        property int selected: 0
        spacing: Kirigami.Units.largeSpacing

        readonly property var resources: [
            { title: qsTr("CPU"), detail: () => Math.round(Number(cpuSensor.value) || 0) + "%  " + cpuSpeed.formattedValue,
              history: win.cpuHistory, max: 100, color: "#1a8fd8" },
            { title: qsTr("Memory"), detail: () => win.formatBytes(Number(memUsed.value) || 0) + " / " + win.formatBytes(Number(memTotal.value) || 0) + " (" + Math.round(Number(memPercent.value) || 0) + "%)",
              history: win.memHistory, max: 100, color: "#9b4fd8" },
            { title: qsTr("Disk"), detail: () => win.formatRate((Number(diskRead.value) || 0) + (Number(diskWrite.value) || 0)),
              history: win.diskHistory, max: -1, color: "#3fa548" },
            { title: qsTr("Network"), detail: () => win.formatNet((Number(netDown.value) || 0) + (Number(netUp.value) || 0)),
              history: win.netHistory, max: -1, color: "#d08a1a" },
        ]

        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 13
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: perf.resources.length
                delegate: Rectangle {
                    required property int index
                    readonly property var res: perf.resources[index]
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3.4
                    radius: 4
                    color: perf.selected === index ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.15) : "transparent"
                    border.width: perf.selected === index ? 1 : 0
                    border.color: win.accent

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.largeSpacing
                        Graph {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                            Layout.fillHeight: true
                            history: res.history
                            maximum: res.max
                            lineColor: res.color
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { text: res.title; font.weight: Font.DemiBold }
                            Label {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                opacity: 0.75
                                text: res.detail()
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: perf.selected = index
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Label {
                    text: perf.resources[perf.selected].title
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                Label {
                    opacity: 0.75
                    text: perf.selected === 0 ? (cpuCores.formattedValue + " " + qsTr("cores")) : ""
                }
            }
            Label {
                opacity: 0.75
                text: perf.selected === 0 ? qsTr("% Utilization over 60 seconds")
                    : perf.selected === 1 ? qsTr("Memory usage over 60 seconds")
                    : qsTr("Activity over 60 seconds")
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                border.width: 1
                border.color: perf.resources[perf.selected].color

                // Light grid, like Windows' graph.
                Repeater {
                    model: 9
                    delegate: Rectangle {
                        required property int index
                        x: (index + 1) * parent.width / 10
                        width: 1
                        height: parent.height
                        color: perf.resources[perf.selected].color
                        opacity: 0.12
                    }
                }
                Repeater {
                    model: 9
                    delegate: Rectangle {
                        required property int index
                        y: (index + 1) * parent.height / 10
                        height: 1
                        width: parent.width
                        color: perf.resources[perf.selected].color
                        opacity: 0.12
                    }
                }
                Graph {
                    anchors.fill: parent
                    anchors.margins: 1
                    history: perf.resources[perf.selected].history
                    maximum: perf.resources[perf.selected].max
                    lineColor: perf.resources[perf.selected].color
                }
            }
            GridLayout {
                columns: 4
                columnSpacing: Kirigami.Units.gridUnit * 2
                Label { text: qsTr("Utilization"); opacity: 0.75 }
                Label { text: qsTr("Speed"); opacity: 0.75 }
                Label { text: qsTr("Memory in use"); opacity: 0.75 }
                Label { text: qsTr("Up time"); opacity: 0.75 }
                Label { text: Math.round(Number(cpuSensor.value) || 0) + "%"; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4 }
                Label { text: cpuSpeed.formattedValue; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4 }
                Label { text: win.formatBytes(Number(memUsed.value) || 0); font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4 }
                Label { text: uptime.formattedValue; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4 }
            }
        }
    }

    // A filled line graph over the last 60 samples.
    component Graph: Charts.LineChart {
        property var history: []
        property real maximum: 100      // -1: scale to the data
        property color lineColor: "#1a8fd8"
        smooth: true
        lineWidth: 1.5
        fillOpacity: 0.15
        // Oldest sample on the left, newest on the right, always 60 points wide.
        readonly property var padded: Array(Math.max(0, 60 - history.length)).fill(0).concat(history)
        xRange { from: 0; to: 59; automatic: false }
        yRange {
            from: 0
            to: maximum > 0 ? maximum : Math.max(1, ...history) * 1.2
            automatic: false
        }
        valueSources: Charts.ArraySource { array: padded }
        colorSource: Charts.SingleValueSource { value: lineColor }
    }

    component StartupPage: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Choose which apps start automatically when you sign in.")
        }
        Button {
            text: qsTr("Manage startup apps")
            icon.name: "system-run"
            onClicked: KCM.KCMLauncher.openSystemSettings("kcm_autostart")
        }
        Item { Layout.fillHeight: true }
    }

    // Details: every process, as in Windows' Details page.
    component DetailsPage: ColumnLayout {
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: Kirigami.Units.gridUnit  // room for the scrollbar
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: 0
            Label { Layout.fillWidth: true; Layout.leftMargin: Kirigami.Units.largeSpacing; text: qsTr("Name"); opacity: 0.75 }
            Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 4; text: qsTr("PID"); opacity: 0.75; horizontalAlignment: Text.AlignRight }
            Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 6; Layout.leftMargin: Kirigami.Units.largeSpacing; text: qsTr("Status"); opacity: 0.75 }
            Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 6; text: qsTr("User name"); opacity: 0.75 }
            Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 4; text: qsTr("CPU"); opacity: 0.75; horizontalAlignment: Text.AlignRight }
            Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 6; Layout.rightMargin: Kirigami.Units.largeSpacing; text: qsTr("Memory"); opacity: 0.75; horizontalAlignment: Text.AlignRight }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: win.lineColor }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: win.details.filter(p => win.matches(p.name, p.pid))
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: Kirigami.Units.gridUnit * 1.6
                color: win.selectedPid === modelData.pid ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.18) : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.rightMargin: Kirigami.Units.gridUnit  // room for the scrollbar
                    spacing: 0
                    Label { Layout.fillWidth: true; Layout.leftMargin: Kirigami.Units.largeSpacing; elide: Text.ElideRight; text: modelData.name }
                    Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 4; horizontalAlignment: Text.AlignRight; text: modelData.pid }
                    Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 6; Layout.leftMargin: Kirigami.Units.largeSpacing; text: modelData.status === "sleeping" || modelData.status === "running" || modelData.status === "" ? qsTr("Running") : modelData.status }
                    Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 6; elide: Text.ElideRight; text: modelData.user }
                    Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 4; horizontalAlignment: Text.AlignRight; text: Math.round(modelData.cpu) }
                    Label { Layout.preferredWidth: Kirigami.Units.gridUnit * 6; Layout.rightMargin: Kirigami.Units.largeSpacing; horizontalAlignment: Text.AlignRight; text: win.formatBytes(modelData.mem) }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { win.selectedPid = modelData.pid; win.selectedName = modelData.name; }
                }
            }
        }
    }
}
