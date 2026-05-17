#!/usr/bin/env node

import { chmod, mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

const targetUrl = process.argv.find((arg, index) => index > 1 && /^https?:\/\//.test(arg));

if (targetUrl == null) {
  console.error("codex-browserless-open: no http(s) URL argument found");
  process.exit(0);
}

const endpoint = process.env.BROWSERLESS_ENDPOINT?.replace(/\/+$/, "");
const token = process.env.BROWSERLESS_TOKEN;

if (!endpoint || !token) {
  console.error("codex-browserless-open: BROWSERLESS_ENDPOINT and BROWSERLESS_TOKEN are required");
  process.exit(0);
}

const publicEndpoint = (process.env.BROWSERLESS_PUBLIC_ENDPOINT || endpoint).replace(/\/+$/, "");
const ttlMs = Number(process.env.BROWSERLESS_SESSION_TTL_SECONDS || "1800") * 1000;
const sessionId = `${process.env.BROWSERLESS_SESSION_ID_PREFIX || "codex-login"}-${Date.now()}`;
const sessionUrlFile = process.env.BROWSERLESS_SESSION_URL_FILE || "/tmp/codex-headless/browserless-session.url";

function browserlessUrl(path) {
  return new URL(path, `${endpoint}/`);
}

function rewriteWebSocketUrl(rawUrl) {
  const source = new URL(rawUrl);
  const base = new URL(endpoint);
  source.protocol = base.protocol === "https:" ? "wss:" : "ws:";
  source.host = base.host;
  if (!source.searchParams.has("token")) {
    source.searchParams.set("token", token);
  }
  return source.toString();
}

function rewriteDevtoolsUrl(rawUrl) {
  const source = new URL(rawUrl, `${publicEndpoint}/`);
  const base = new URL(publicEndpoint);
  source.protocol = base.protocol;
  source.host = base.host;
  const ws = source.searchParams.get("ws");
  if (ws) {
    const wsProtocol = base.protocol === "https:" ? "wss" : "ws";
    const wsSource = new URL(`${wsProtocol}://${ws}`);
    wsSource.host = base.host;
    if (!wsSource.searchParams.has("token")) {
      wsSource.searchParams.set("token", token);
    }
    source.searchParams.set("ws", `${wsSource.host}${wsSource.pathname}${wsSource.search}`);
  }
  return source.toString();
}

function redact(value) {
  return value.replaceAll(token, "[redacted]");
}

function waitForOpen(socket) {
  return new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener(
      "error",
      () => reject(new Error("Browserless websocket failed to open")),
      { once: true },
    );
  });
}

function makeCdpClient(socket) {
  let nextId = 1;
  const pending = new Map();

  socket.addEventListener("message", (event) => {
    let payload;
    try {
      payload = JSON.parse(String(event.data));
    } catch {
      return;
    }

    if (payload.id == null) {
      return;
    }

    const deferred = pending.get(payload.id);
    if (deferred == null) {
      return;
    }
    pending.delete(payload.id);

    if (payload.error) {
      deferred.reject(new Error(payload.error.message || "CDP command failed"));
    } else {
      deferred.resolve(payload.result);
    }
  });

  return (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = nextId;
      nextId += 1;
      pending.set(id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params }));
    });
}

const newPageUrl = browserlessUrl("json/new");
newPageUrl.searchParams.set("token", token);
newPageUrl.searchParams.set("id", sessionId);
newPageUrl.searchParams.set("pause", "true");

const response = await fetch(newPageUrl, { method: "PUT" });
if (!response.ok) {
  throw new Error(`Browserless /json/new failed with HTTP ${response.status}`);
}

const session = await response.json();
const webSocketDebuggerUrl = rewriteWebSocketUrl(session.webSocketDebuggerUrl);
const devtoolsFrontendUrl = session.devtoolsFrontendUrl
  ? rewriteDevtoolsUrl(session.devtoolsFrontendUrl)
  : `${publicEndpoint}/sessions`;

await mkdir(dirname(sessionUrlFile), { recursive: true });
await writeFile(sessionUrlFile, `${devtoolsFrontendUrl}\n`, "utf8");
await chmod(sessionUrlFile, 0o600);

console.error(`codex-browserless-open: opened ${targetUrl}`);
console.error(`codex-browserless-open: session ${sessionId}`);
console.error(`codex-browserless-open: watch ${redact(devtoolsFrontendUrl)}`);

const socket = new WebSocket(webSocketDebuggerUrl);
await waitForOpen(socket);
const cdp = makeCdpClient(socket);

await cdp("Page.enable");
await cdp("Page.navigate", { url: targetUrl });

const keepalive = setInterval(() => {
  socket.send(JSON.stringify({ id: 0, method: "Runtime.evaluate", params: { expression: "void 0" } }));
}, 30_000);

await new Promise((resolve) => setTimeout(resolve, ttlMs));
clearInterval(keepalive);
socket.close();
