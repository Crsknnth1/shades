# Shades

*You use shades to cover windows.*

Shades is a just-for-fun Linux distro that feels like Windows 11, without the clutter and slowness.
It is built on **Debian 13** with a heavily customized **KDE Plasma 6** desktop.

## Goals

- **Familiar:** Windows 11-style taskbar, Start menu, Explorer-like file manager, and Win-key shortcuts.
- **Lean:** no telemetry, ads, or bundled trials; a small set of default apps.
- **Runs Windows apps:** Wine + Bottles, with double-click `.exe` support.
- **Office:** OnlyOffice by default; Microsoft's Office web apps through Edge for Linux.

Shades ships no Microsoft logos, fonts, or wallpapers. It uses look-alikes instead.

![Shades Start menu](docs/start-menu.png)

## What it looks like

- **Taskbar:** centered Start button and pinned apps, tray and clock on the right, flush to the bottom.
- **Start menu:** a "blinds" Start button; pinned apps in a grid, search at the top.
- **Theme:** Shades Light colors (Windows 11 greys and blue accent), Fluent icons, Inter font.
- **Solid, not see-through:** menus and panels are opaque. Virtual machines have no GPU for blur,
  and translucency without blur looks muddy.
- **File Explorer:** Dolphin, with Documents, Downloads, Pictures, and so on in the sidebar.
- **No splash screen, no hot corners, no file indexing.**

| Shortcut | Does |
|---|---|
| Win | Start menu |
| Win+E | File Explorer (Dolphin) |
| Win+R | Run / search |
| Win+I | Settings |
| Win+L | Lock |
| Win+D | Show desktop |
| Win+V | Clipboard history |
| Win+Up / Win+Down | Maximize / restore |
| Win+Left / Win+Right | Snap to half the screen |
| Win+Tab | Task view (Overview) |
| Win+Shift+S | Screenshot (Spectacle) |
| Ctrl+Shift+Esc | Task Manager (System Monitor) |
| Alt+Tab | Switch windows (thumbnail grid) |

## Roadmap

1. ✅ Repo and tooling
2. ✅ Desktop playground in Docker
3. ✅ Windows 11 look (first pass; see "Still to do")
4. ⬜ Windows-app layer (Wine, Bottles, OnlyOffice, Edge)
5. ⬜ Bootable ISO with installer (`live-build`, Calamares)
6. ⬜ Real targets: laptop, and server VM with remote desktop

## Try the desktop in Docker

Docker can't boot the distro itself, but it can run the desktop so you can try the look and the apps.

```bash
docker compose up -d --build
```

Then open <http://localhost:6080/vnc.html?autoconnect=1&resize=scale> in a browser.
The session has no password, so the port is bound to localhost only.

To stop it:

```bash
docker compose down
```

## Still to do on the look

- **Start menu layout:** it's KDE's Kickoff with a category sidebar. A true Windows 11 layout
  (pinned grid plus "Recommended") needs a custom Start menu widget.
- **Window buttons:** Breeze's round buttons rather than Windows 11's flat, square ones.
- **Login screen and boot splash:** these come with the ISO, since Docker never shows them.

## Container quirks

These only affect the Docker playground, not the real distro:

- No systemd, so `start.sh` starts KDE's shortcut service (`kglobalacceld`) itself before Plasma.
- No GPU, so KWin renders in software (llvmpipe).
- System Monitor can't see disks or per-app usage.

## Layout

| Path | What |
|---|---|
| `rootfs/` | Files laid over the system: `/etc/xdg` defaults, `/etc/skel` user defaults, theme, artwork |
| `scripts/setup-rootfs.sh` | Installs `rootfs/` and patches KDE defaults. Shared by Docker and the ISO |
| `artwork/` | Source art (the wallpaper SVG is rendered to PNG at build time) |
| `container/` | Dockerfile and startup script for the desktop playground |
| `compose.yaml` | Runs the playground on port 6080 |

Third-party pieces downloaded at build time: the
[Fluent icon theme](https://github.com/vinceliuice/Fluent-icon-theme) (GPL-3.0).
