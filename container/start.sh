#!/bin/bash
# Starts a VNC X server, the noVNC web bridge, and a Plasma X11 session.
set -e

export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-$USER
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=KDE
# startplasma sets this too, but kglobalacceld starts first (below) and would otherwise
# build KDE's app cache without the Plasma menu, leaving pinned apps unresolved.
export XDG_MENU_PREFIX=plasma-
# Same for the language (Shades English): apps started through kglobalacceld (Win+E etc.)
# inherit its environment, not Plasma's.
LANGUAGE="$(kreadconfig6 --file plasma-localerc --group Translations --key LANGUAGE)"
export LANGUAGE
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

# A container that was killed (e.g. by a Docker restart) leaves its X lock behind.
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# VNC listens only inside the container; the browser reaches it through websockify.
Xvnc :1 -geometry "${SHADES_GEOMETRY:-1600x900}" -depth 24 \
    -SecurityTypes None -localhost yes -AlwaysShared &

websockify --web /usr/share/novnc 6080 localhost:5901 &

for _ in $(seq 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done

# Without systemd nothing can launch kglobalacceld on demand, so start it before KWin
# registers its shortcuts; otherwise every KWin shortcut ends up unbound.
exec dbus-run-session bash -c '
    # Sound server (systemd starts these on the real distro). With no sound hardware,
    # PipeWire provides a dummy output so the volume controls have something to drive.
    pipewire & sleep 0.5; wireplumber & pipewire-pulse &
    /usr/lib/x86_64-linux-gnu/libexec/kglobalacceld &
    for _ in $(seq 50); do
        dbus-send --session --print-reply --dest=org.freedesktop.DBus / \
            org.freedesktop.DBus.NameHasOwner string:org.kde.kglobalaccel 2>/dev/null \
            | grep -q true && break
        sleep 0.1
    done
    exec startplasma-x11
'
