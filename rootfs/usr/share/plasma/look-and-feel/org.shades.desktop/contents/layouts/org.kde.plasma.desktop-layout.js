// Shades default desktop: one Windows 11-style taskbar along the bottom.
// Two flexible spacers keep the Start button and pinned apps in the middle.

var panel = new Panel;
panel.location = "bottom";
panel.height = 2 * Math.floor(gridUnit * 2.7 / 2);
panel.floating = false;

panel.addWidget("org.kde.plasma.panelspacer");

// Windows 11 order: Start, Search, Task View, then pinned and open apps.
// Start's pinned apps are in its config/main.xml.
panel.addWidget("org.shades.startmenu");
panel.addWidget("org.shades.search");
panel.addWidget("org.shades.taskview");

var tasks = panel.addWidget("org.shades.taskbar");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:microsoft-edge.desktop",
    "applications:onlyoffice-desktopeditors.desktop",
]);

panel.addWidget("org.kde.plasma.panelspacer");
panel.addWidget("org.kde.plasma.systemtray");

var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BelowTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "M/d/yyyy");

// Thin "show desktop" strip at the far right, like Windows.
panel.addWidget("org.shades.showdesktop");

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    var desktop = desktopsArray[j];
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/Shades/");
}
