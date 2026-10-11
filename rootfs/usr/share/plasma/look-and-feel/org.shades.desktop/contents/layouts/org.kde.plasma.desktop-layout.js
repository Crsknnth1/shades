// Shades default desktop: one Windows 11-style taskbar along the bottom.
// Two flexible spacers keep the Start button and pinned apps in the middle.

var panel = new Panel;
panel.location = "bottom";
panel.height = 2 * Math.floor(gridUnit * 2.7 / 2);
panel.floating = false;

panel.addWidget("org.kde.plasma.panelspacer");

var start = panel.addWidget("org.kde.plasma.kickoff");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "shades-start");
start.writeConfig("favoritesDisplay", 0);       // pinned apps as a grid
start.writeConfig("applicationsDisplay", 1);    // "All apps" as a list
start.writeConfig("showActionButtonCaptions", false);
// Pinned apps are set in scripts/setup-rootfs.sh; Kickoff ignores them here.

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop",
]);

panel.addWidget("org.kde.plasma.panelspacer");
panel.addWidget("org.kde.plasma.systemtray");

var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BelowTime");
clock.writeConfig("dateFormat", "shortDate");

panel.addWidget("org.kde.plasma.showdesktop");

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    var desktop = desktopsArray[j];
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/Shades/");
}
