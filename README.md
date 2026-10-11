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

## Roadmap

1. ✅ Repo and tooling
2. ✅ Desktop playground in Docker
3. ⬜ Windows 11 look
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

## Layout

| Path | What |
|---|---|
| `container/` | Dockerfile and startup script for the desktop playground |
| `compose.yaml` | Runs the playground on port 6080 |
