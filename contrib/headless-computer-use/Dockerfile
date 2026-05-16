FROM ubuntu:24.04 AS builder

COPY --from=node:22-bookworm /usr/local/ /usr/local/
COPY --from=rust:1-bookworm /usr/local/cargo/ /usr/local/cargo/
COPY --from=rust:1-bookworm /usr/local/rustup/ /usr/local/rustup/

ENV DEBIAN_FRONTEND=noninteractive
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH=/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV CODEX_LINUX_ENABLE_COMPUTER_USE_UI=1
ENV PACKAGE_WITH_UPDATER=0

WORKDIR /src
COPY . /src

RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    p7zip-full \
    pkg-config \
    python3 \
    unzip \
    && rm -rf /var/lib/apt/lists/*
RUN make build-app
RUN /src/codex-app/resources/node-runtime/bin/npm install -g --prefix /opt/codex-cli @openai/codex

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CODEX_HOME=/data/.codex
ENV CODEX_CLI_PATH=/opt/codex-cli/bin/codex
ENV CODEX_LINUX_ENABLE_COMPUTER_USE_UI=1
ENV DISPLAY=:0
ENV VNC_RESOLUTION=1440x900
ENV VNC_PORT=5901
ENV NO_VNC_PORT=6080
ENV XDG_RUNTIME_DIR=/tmp/runtime-root
ENV XDG_SESSION_TYPE=x11
ENV XDG_CURRENT_DESKTOP=XFCE
ENV DESKTOP_SESSION=xfce
ENV PATH=/opt/codex-cli/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN apt-get update && apt-get install -y \
    at-spi2-core \
    ca-certificates \
    curl \
    dbus-x11 \
    libasound2t64 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcairo2 \
    libcups2t64 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0t64 \
    libgtk-3-0t64 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb-dri3-0 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxrender1 \
    novnc \
    python3 \
    websockify \
    xfce4 \
    xfce4-terminal \
    x11vnc \
    xauth \
    xdotool \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data/.codex /data/.config/codex-desktop /opt/codex-desktop

COPY --from=builder /src/codex-app /opt/codex-desktop
COPY --from=builder /opt/codex-cli /opt/codex-cli
COPY contrib/headless-computer-use/entrypoint.sh /usr/local/bin/codex-headless-entrypoint

RUN chmod +x /usr/local/bin/codex-headless-entrypoint

VOLUME ["/data"]
EXPOSE 6080 5901 5175

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
  CMD curl -fsS http://127.0.0.1:6080/vnc.html >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/codex-headless-entrypoint"]
