#!/bin/bash
set -Eeuo pipefail

export HOME="${HOME:-/root}"
export CODEX_HOME="${CODEX_HOME:-/data/.codex}"
export CODEX_CLI_PATH="${CODEX_CLI_PATH:-/opt/codex-cli/bin/codex}"
export DISPLAY="${DISPLAY:-:0}"
export VNC_RESOLUTION="${VNC_RESOLUTION:-1440x900}"
export VNC_PORT="${VNC_PORT:-5901}"
export NO_VNC_PORT="${NO_VNC_PORT:-6080}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-XFCE}"
export DESKTOP_SESSION="${DESKTOP_SESSION:-xfce}"
export BROWSER="${BROWSER:-codex-browserless-open}"

mkdir -p "$CODEX_HOME" "$XDG_RUNTIME_DIR" "$HOME/.config/codex-desktop" "$HOME/.config/xfce4" /tmp/codex-headless
chmod 700 "$XDG_RUNTIME_DIR"

printf '%s\n' '{"codex-linux-computer-use-ui-enabled": true}' >"$HOME/.config/codex-desktop/settings.json"

configure_default_browser() {
    local browser_desktop="codex-browserless-open.desktop"
    local browser_helper="codex-browserless-open"

    if ! command -v "$browser_helper" >/dev/null 2>&1; then
        return 0
    fi

    mkdir -p "$HOME/.config" "$HOME/.local/share/applications" "$HOME/.config/xfce4"
    printf 'WebBrowser=%s\n' "$browser_helper" >"$HOME/.config/xfce4/helpers.rc"

    if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default "$browser_desktop" text/html >/dev/null 2>&1 || true
        xdg-mime default "$browser_desktop" x-scheme-handler/http >/dev/null 2>&1 || true
        xdg-mime default "$browser_desktop" x-scheme-handler/https >/dev/null 2>&1 || true
    fi

    if command -v xdg-settings >/dev/null 2>&1; then
        xdg-settings set default-web-browser "$browser_desktop" >/dev/null 2>&1 || true
    fi
}

configure_default_browser

eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface toolkit-accessibility true >/dev/null 2>&1 || true
fi

Xvfb "$DISPLAY" -screen 0 "${VNC_RESOLUTION}x24" -ac +extension RANDR >/tmp/codex-headless/xvfb.log 2>&1 &
sleep 1

if [ -x /usr/libexec/at-spi-bus-launcher ]; then
    /usr/libexec/at-spi-bus-launcher --launch-immediately >/tmp/codex-headless/atspi.log 2>&1 &
elif [ -x /usr/lib/at-spi2-core/at-spi-bus-launcher ]; then
    /usr/lib/at-spi2-core/at-spi-bus-launcher --launch-immediately >/tmp/codex-headless/atspi.log 2>&1 &
fi

startxfce4 >/tmp/codex-headless/xfce4.log 2>&1 &
sleep 2

x11vnc -display "$DISPLAY" -forever -shared -rfbport "$VNC_PORT" -nopw >/tmp/codex-headless/x11vnc.log 2>&1 &

if [ -x /usr/share/novnc/utils/launch.sh ]; then
    /usr/share/novnc/utils/launch.sh --vnc "localhost:${VNC_PORT}" --listen "$NO_VNC_PORT" >/tmp/codex-headless/novnc.log 2>&1 &
elif [ -x /usr/share/novnc/utils/novnc_proxy ]; then
    /usr/share/novnc/utils/novnc_proxy --vnc "localhost:${VNC_PORT}" --listen "$NO_VNC_PORT" >/tmp/codex-headless/novnc.log 2>&1 &
else
    websockify --web=/usr/share/novnc/ "$NO_VNC_PORT" "localhost:${VNC_PORT}" >/tmp/codex-headless/novnc.log 2>&1 &
fi

cd /opt/codex-desktop/content/webview
python3 /opt/codex-desktop/.codex-linux/webview-server.py 5175 --bind 127.0.0.1 >/tmp/codex-headless/webview.log 2>&1 &

cd /opt/codex-desktop
exec /opt/codex-desktop/start.sh
