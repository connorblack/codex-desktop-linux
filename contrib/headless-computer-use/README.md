# Headless Computer Use Container

This image packages Codex Desktop Linux with a browser-streamed X11 desktop so Computer Use can run inside a container instead of on a host session.

It borrows the same core shape Daytona uses for browser-visible computer-use sandboxes:

- `dbus-launch` for a session bus
- `Xvfb` for the virtual X11 display
- `xfce4` for a lightweight desktop session
- `at-spi-bus-launcher` for accessibility trees
- `x11vnc` plus `noVNC`/`websockify` for browser streaming
- `xdotool` for X11-native input fallback inside the virtual display

The image builds `codex-app/` from this repo, enables the Computer Use UI patch, installs the Codex CLI under `/opt/codex-cli`, and launches Codex Desktop at container start.

Default ports:

- `6080` for `noVNC`
- `5901` for raw VNC
- `5175` for the embedded Codex webview server

Relevant environment variables:

- `VNC_RESOLUTION` default `1440x900`
- `VNC_PORT` default `5901`
- `NO_VNC_PORT` default `6080`
- `DISPLAY` default `:0`

For Coolify, deploy the root-level `deploy.headless-compose.yaml` as a Docker Compose application and route the public domain to port `6080`.
