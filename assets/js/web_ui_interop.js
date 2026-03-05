/**
 * WebUI JavaScript Interop Layer
 *
 * Bridges Elm ports and Phoenix Channels over WebSocket.
 */

let ws = null;
let wsUrl = null;
let reconnectTimer = null;
let reconnectAttempts = 0;
let maxReconnectAttempts = 10;
let reconnectDelay = 1000;
let heartbeatInterval = null;
let app = null;
let jsErrorHandlerRegistered = false;

let joinRef = null;
let channelJoined = false;
const channelTopic = "events:lobby";
const pendingCloudEvents = [];

let refCounter = 0;

const config = {
  wsPath: window.wsUrl || "/socket/websocket",
  heartbeatIntervalMs: 30000,
  phoenixVsn: "2.0.0"
};

function initElm(ElmModule) {
  if (app) {
    return app;
  }

  const pageMetadata = {
    title: document.querySelector('meta[name="page-title"]')?.getAttribute("content") || null,
    description: document.querySelector('meta[name="page-description"]')?.getAttribute("content") || null
  };

  const flags = {
    websocketUrl: config.wsPath,
    pageMetadata: pageMetadata
  };

  const node = document.getElementById("app");
  if (!node) {
    console.error("WebUI: Elm mount point #app not found");
    return null;
  }

  app = ElmModule.Main.init({ node, flags });

  if (app.ports && app.ports.sendCloudEvent) {
    app.ports.sendCloudEvent.subscribe(sendCloudEvent);
  }

  if (app.ports && app.ports.initWebSocket) {
    app.ports.initWebSocket.subscribe(connectWebSocket);
  }

  if (app.ports && app.ports.sendJSCommand) {
    app.ports.sendJSCommand.subscribe(handleJSCommand);
  }

  registerJSErrorHandler();

  console.log("WebUI: Elm app initialized");
  return app;
}

function bootstrapElm(maxAttempts = 200) {
  let attempts = 0;

  const tryBoot = () => {
    if (app) {
      return;
    }

    if (window.Elm && window.Elm.Main) {
      initElm(window.Elm);
      return;
    }

    attempts += 1;
    if (attempts >= maxAttempts) {
      console.error("WebUI: Elm runtime not found on window.Elm.Main");
      return;
    }

    setTimeout(tryBoot, 25);
  };

  tryBoot();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => bootstrapElm());
} else {
  bootstrapElm();
}

window.initElm = initElm;

function sendCloudEvent(eventJson) {
  const payload = normalizeEventPayload(eventJson);
  if (!payload) {
    return;
  }

  if (!ws || ws.readyState !== WebSocket.OPEN || !channelJoined) {
    pendingCloudEvents.push(payload);
    return;
  }

  sendPhoenixFrame(channelTopic, "cloudevent", payload, true);
}

function normalizeEventPayload(eventJson) {
  if (typeof eventJson === "string") {
    try {
      return JSON.parse(eventJson);
    } catch (error) {
      console.error("WebUI: Failed to parse CloudEvent JSON:", error);
      return null;
    }
  }

  if (eventJson && typeof eventJson === "object") {
    return eventJson;
  }

  console.warn("WebUI: Invalid CloudEvent payload:", eventJson);
  return null;
}

function connectWebSocket(url) {
  wsUrl = url || config.wsPath;

  if (ws) {
    ws.close();
  }

  channelJoined = false;
  joinRef = null;
  notifyConnectionStatus("Connecting");

  const fullUrl = addPhoenixVsn(resolveWebSocketUrl(wsUrl));
  console.log("WebUI: Connecting to WebSocket:", fullUrl);

  ws = new WebSocket(fullUrl);

  ws.onopen = () => {
    reconnectAttempts = 0;
    reconnectDelay = 1000;
    joinLobbyChannel();
  };

  ws.onmessage = event => {
    try {
      const message = JSON.parse(event.data);

      if (Array.isArray(message)) {
        handlePhoenixFrame(message);
        return;
      }

      // Backward-compatible fallback for object-shaped payloads.
      handleLegacyMessage(message);
    } catch (error) {
      console.error("WebUI: Error parsing WebSocket message:", error);
    }
  };

  ws.onclose = event => {
    console.log("WebUI: WebSocket closed:", event.code, event.reason);
    channelJoined = false;
    joinRef = null;
    notifyConnectionStatus("Disconnected");
    stopHeartbeat();

    if (reconnectAttempts < maxReconnectAttempts) {
      scheduleReconnect();
    } else {
      notifyConnectionStatus("Error:Max reconnect attempts reached");
    }
  };

  ws.onerror = error => {
    console.error("WebUI: WebSocket error:", error);
    notifyConnectionStatus("Error:WebSocket connection error");
  };
}

function joinLobbyChannel() {
  if (!ws || ws.readyState !== WebSocket.OPEN) {
    return;
  }

  joinRef = generateRef();
  const joinFrame = [joinRef, joinRef, channelTopic, "phx_join", {}];
  ws.send(JSON.stringify(joinFrame));
}

function handlePhoenixFrame(frame) {
  const [incomingJoinRef, incomingRef, topic, event, payload] = frame;

  if (topic === channelTopic && event === "phx_reply" && incomingRef === joinRef) {
    if (payload && payload.status === "ok") {
      channelJoined = true;
      notifyConnectionStatus("Connected");
      startHeartbeat();
      flushPendingCloudEvents();
      return;
    }

    const reason = payload && payload.response && payload.response.reason;
    emitServerErrorEvent({
      message: reason || "Channel join failed",
      reason: reason || "channel_join_failed"
    });
    return;
  }

  if (topic === channelTopic && event === "cloudevent" && payload) {
    receiveCloudEvent(JSON.stringify(payload));
    return;
  }

  if (topic === channelTopic && event === "error") {
    emitServerErrorEvent(payload || {});
    return;
  }

  if (event === "phx_error") {
    emitServerErrorEvent({ message: "Channel error", reason: "phx_error" });
    return;
  }

  if (event === "phx_close") {
    notifyConnectionStatus("Disconnected");
    return;
  }

  // Ignore heartbeats and unrelated messages.
  void incomingJoinRef;
}

function handleLegacyMessage(message) {
  if (!message || typeof message !== "object") {
    return;
  }

  if (message.event === "cloudevent" && message.payload) {
    receiveCloudEvent(JSON.stringify(message.payload));
  }
}

function flushPendingCloudEvents() {
  if (!ws || ws.readyState !== WebSocket.OPEN || !channelJoined) {
    return;
  }

  while (pendingCloudEvents.length > 0) {
    const payload = pendingCloudEvents.shift();
    sendPhoenixFrame(channelTopic, "cloudevent", payload, true);
  }
}

function sendPhoenixFrame(topic, event, payload, includeJoinRef = false) {
  if (!ws || ws.readyState !== WebSocket.OPEN) {
    return;
  }

  const frame = [includeJoinRef ? joinRef : null, generateRef(), topic, event, payload || {}];
  ws.send(JSON.stringify(frame));
}

function resolveWebSocketUrl(url) {
  const rawUrl = url || config.wsPath;
  const wsProtocol = window.location.protocol === "https:" ? "wss:" : "ws:";

  if (/^wss?:\/\//i.test(rawUrl)) {
    return rawUrl;
  }

  if (/^https?:\/\//i.test(rawUrl)) {
    const parsed = new URL(rawUrl);
    parsed.protocol = parsed.protocol === "https:" ? "wss:" : "ws:";
    return parsed.toString();
  }

  if (rawUrl.startsWith("//")) {
    return `${wsProtocol}${rawUrl}`;
  }

  const path = rawUrl.startsWith("/") ? rawUrl : `/${rawUrl}`;
  return `${wsProtocol}//${window.location.host}${path}`;
}

function addPhoenixVsn(url) {
  const parsed = new URL(url);

  if (!parsed.searchParams.has("vsn")) {
    parsed.searchParams.set("vsn", config.phoenixVsn);
  }

  return parsed.toString();
}

function receiveCloudEvent(eventJson) {
  if (app && app.ports && app.ports.receiveCloudEvent) {
    app.ports.receiveCloudEvent.send(eventJson);
  }
}

function emitServerErrorEvent(payload) {
  const message =
    payload && typeof payload.message === "string"
      ? payload.message
      : payload && typeof payload.reason === "string"
      ? payload.reason
      : "Unknown server error";

  const errorEvent = {
    specversion: "1.0",
    id: `server-error-${Date.now()}-${generateRef()}`,
    source: "urn:webui:interop",
    type: "com.webui.counter.server_error",
    data: {
      message,
      reason: payload && typeof payload.reason === "string" ? payload.reason : "unknown"
    }
  };

  receiveCloudEvent(JSON.stringify(errorEvent));
  notifyConnectionStatus(`Error:${message}`);
}

function notifyConnectionStatus(status) {
  if (app && app.ports && app.ports.connectionStatus) {
    app.ports.connectionStatus.send(status);
  }
}

function registerJSErrorHandler() {
  if (jsErrorHandlerRegistered) {
    return;
  }

  jsErrorHandlerRegistered = true;

  const originalError = console.error;
  console.error = function (...args) {
    originalError.apply(console, args);

    if (app && app.ports && app.ports.receiveJSError) {
      const message = args
        .map(arg => (typeof arg === "string" ? arg : JSON.stringify(arg)))
        .join(" ");

      app.ports.receiveJSError.send(message);
    }
  };

  window.addEventListener("error", event => {
    if (app && app.ports && app.ports.receiveJSError) {
      app.ports.receiveJSError.send(
        `Uncaught Error: ${event.message} at ${event.filename}:${event.lineno}`
      );
    }
  });

  window.addEventListener("unhandledrejection", event => {
    if (app && app.ports && app.ports.receiveJSError) {
      app.ports.receiveJSError.send(`Unhandled Promise Rejection: ${event.reason}`);
    }
  });
}

function scheduleReconnect() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
  }

  reconnectAttempts += 1;
  notifyConnectionStatus("Reconnecting");

  const delay = reconnectDelay * Math.pow(2, reconnectAttempts - 1);
  reconnectTimer = setTimeout(() => {
    connectWebSocket(wsUrl);
  }, delay);
}

function startHeartbeat() {
  stopHeartbeat();

  heartbeatInterval = setInterval(() => {
    if (ws && ws.readyState === WebSocket.OPEN) {
      sendPhoenixFrame("phoenix", "heartbeat", {}, false);
    }
  }, config.heartbeatIntervalMs);
}

function stopHeartbeat() {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
    heartbeatInterval = null;
  }
}

function handleJSCommand(commandValue) {
  try {
    const command =
      typeof commandValue === "string" ? JSON.parse(commandValue) : commandValue;

    if (!command || typeof command !== "object") {
      console.warn("Invalid JS command payload:", commandValue);
      return;
    }

    switch (command.type) {
      case "scroll":
        handleScroll(command);
        break;

      case "focus":
        handleFocus(command);
        break;

      case "localStorage":
        handleLocalStorage(command);
        break;

      case "clipboard":
        handleClipboard(command);
        break;

      default:
        console.warn("Unknown JS command:", command.type);
    }
  } catch (error) {
    console.error("Error handling JS command:", error);
  }
}

function handleScroll(command) {
  if (command.selector) {
    const element = document.querySelector(command.selector);
    if (element) {
      element.scrollIntoView(command.behavior || { behavior: "smooth" });
    }
  } else if (command.top !== undefined || command.left !== undefined) {
    window.scrollTo({
      top: command.top || 0,
      left: command.left || 0,
      behavior: command.behavior || "smooth"
    });
  }
}

function handleFocus(command) {
  if (command.selector) {
    const element = document.querySelector(command.selector);
    if (element) {
      element.focus();
    }
  }
}

function handleLocalStorage(command) {
  switch (command.action) {
    case "get": {
      const value = localStorage.getItem(command.key);
      sendJSResponse({ type: "localStorage", key: command.key, value });
      break;
    }

    case "set":
      localStorage.setItem(command.key, command.value);
      break;

    case "remove":
      localStorage.removeItem(command.key);
      break;

    case "clear":
      localStorage.clear();
      break;

    default:
      console.warn("Unknown localStorage action:", command.action);
  }
}

async function handleClipboard(command) {
  try {
    switch (command.action) {
      case "read": {
        const text = await navigator.clipboard.readText();
        sendJSResponse({ type: "clipboard", action: "read", text });
        break;
      }

      case "write":
        await navigator.clipboard.writeText(command.text);
        break;

      default:
        console.warn("Unknown clipboard action:", command.action);
    }
  } catch (error) {
    console.error("Clipboard error:", error);
  }
}

function sendJSResponse(response) {
  if (app && app.ports && app.ports.receiveJSResponse) {
    app.ports.receiveJSResponse.send(response);
  }
}

function generateRef() {
  refCounter += 1;
  return String(refCounter);
}

window.addEventListener("beforeunload", () => {
  if (ws) {
    ws.close();
  }

  stopHeartbeat();

  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
  }
});
