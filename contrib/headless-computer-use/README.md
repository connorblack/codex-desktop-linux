# Headless Computer Use Container

This image packages Codex Desktop Linux with a browser-streamed X11 desktop so Computer Use can run inside a container instead of on a host session.

It borrows the same core shape Daytona uses for browser-visible computer-use sandboxes, but keeps browser execution outside this image:

- `dbus-launch` for a session bus
- `Xvfb` for the virtual X11 display
- `xfce4` for a lightweight desktop session
- `at-spi-bus-launcher` for accessibility trees
- `x11vnc` plus `noVNC`/`websockify` for browser streaming
- `scrot` for X11 screenshot capture when GNOME Shell and XDG portals are unavailable
- `xdg-utils` plus a `codex-browserless-open` desktop handler for Browserless-backed login/device-activation handoff
- `git` and `xz-utils` for Codex runtime/skills installation paths after startup

The entrypoint configures `codex-browserless-open` as the default `xdg-open` browser before Codex starts. Set `BROWSERLESS_ENDPOINT` and `BROWSERLESS_TOKEN` to point it at an external Browserless service; login URLs will be opened through Browserless instead of trying to run Chromium inside this container. In Coolify, attach this service to the Browserless application's Docker network and use the internal endpoint (`http://browserless:3000`) for runtime calls while keeping `BROWSERLESS_PUBLIC_ENDPOINT` on the public Coolify URL for the watch/debug link.

The image builds `codex-app/` from this repo, enables the Computer Use UI patch, installs the Codex CLI under `/opt/codex-cli`, and launches Codex Desktop at container start.

Default ports:

- `6080` for `noVNC`
- `5901` for raw VNC
- `5175` for the embedded Codex webview server

Relevant environment variables:

- `VNC_RESOLUTION` default `1440x900`
- `VNC_PORT` default `5901`
- `NO_VNC_PORT` default `6080`
- `BROWSERLESS_ENDPOINT` Browserless HTTP endpoint, for example `http://browserless:3000`
- `BROWSERLESS_TOKEN` Browserless API token
- `BROWSERLESS_PUBLIC_ENDPOINT` optional public Browserless base URL used when writing the watch/debug URL
- `BROWSERLESS_SESSION_TTL_SECONDS` default `1800`
- `BROWSERLESS_NETWORK` external Docker network name for the Browserless Coolify app, used by the compose files
- `DISPLAY` default `:0`

For Coolify, deploy the root-level `deploy.headless-compose.yaml` as a Docker Compose application and route the public domain to port `6080`.
The compose files set `SERVICE_URL_CODEX_HEADLESS_6080=/vnc.html?autoconnect=1&resize=scale` so Coolify's generated service link opens the browser-ready noVNC session directly.
