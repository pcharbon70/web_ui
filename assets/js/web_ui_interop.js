/**
 * WebUI JavaScript Interop Layer
 *
 * Provides communication between Elm and the browser via ports.
 * Handles WebSocket connections to Phoenix endpoints.
 */

// WebSocket connection state
let ws = null;
let wsUrl = null;
let reconnectTimer = null;
let reconnectAttempts = 0;
let maxReconnectAttempts = 10;
let reconnectDelay = 1000; // Start at 1 second
let heartbeatInterval = null;
let app = null;

// Configuration
const config = {
  wsPath: window.wsUrl || "/socket/websocket",
  heartbeatIntervalMs: 30000
};

/**
 * Initialize the Elm app with ports
 */
export function initElm(ElmModule) {
  // Extract page metadata from DOM
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
    console.error("Elm mount point #app not found");
    return null;
  }

  app = ElmModule.Main.init({
    node: node,
    flags: flags
  });

  // Register port subscriptions
  if (app.ports && app.ports.sendCloudEvent) {
    app.ports.sendCloudEvent.subscribe(sendCloudEvent);
  }

  if (app.ports && app.ports.initWebSocket) {
    app.ports.initWebSocket.subscribe(connectWebSocket);
  }

  if (app.ports && app.ports.sendJSCommand) {
    app.ports.sendJSCommand.subscribe(handleJSCommand);
  }

  // Register JSError port for forwarding JavaScript errors to Elm
  registerJSErrorHandler();

  console.log("WebUI: Elm app initialized");

  return app;
}

/**
 * Send a CloudEvent to the server via WebSocket
 */
function sendCloudEvent(eventJson) {
  if (!ws || ws.readyState !== WebSocket.OPEN) {
    console.warn("WebSocket not connected, queuing event:", eventJson);
    return;
  }

  try {
    // Phoenix channel message format
    const message = {
      topic: "events:lobby",
      event: "cloudevent",
      payload: JSON.parse(eventJson),
      ref: generateRef()
    };

    ws.send(JSON.stringify(message));
  } catch (error) {
    console.error("Error sending CloudEvent:", error);
  }
}

/**
 * Initialize WebSocket connection
 */
function connectWebSocket(url) {
  wsUrl = url || config.wsPath;

  if (ws) {
    ws.close();
  }

  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const host = window.location.host;
  const fullUrl = `${protocol}//${host}${wsUrl}`;

  console.log("WebUI: Connecting to WebSocket:", fullUrl);

  ws = new WebSocket(fullUrl);

  ws.onopen = function() {
    console.log("WebUI: WebSocket connected");
    reconnectAttempts = 0;
    reconnectDelay = 1000;
    notifyConnectionStatus("Connected");

    // Start heartbeat
    startHeartbeat();
  };

  ws.onmessage = function(event) {
    try {
      const message = JSON.parse(event.data);

      // Handle Phoenix channel messages
      if (message.event === "cloudevent" && message.payload) {
        receiveCloudEvent(JSON.stringify(message.payload));
      } else if (message.event === "phx_reply") {
        // Handle Phoenix replies
        console.debug("WebUI: Phoenix reply:", message);
      }
    } catch (error) {
      console.error("Error parsing WebSocket message:", error);
    }
  };

  ws.onclose = function(event) {
    console.log("WebUI: WebSocket closed:", event.code, event.reason);
    notifyConnectionStatus("Disconnected");
    stopHeartbeat();

    // Attempt to reconnect
    if (reconnectAttempts < maxReconnectAttempts) {
      scheduleReconnect();
    } else {
      notifyConnectionStatus("Error:Max reconnect attempts reached");
    }
  };

  ws.onerror = function(error) {
    console.error("WebUI: WebSocket error:", error);
    notifyConnectionStatus("Error:WebSocket connection error");
  };
}

/**
 * Receive a CloudEvent from the server and forward to Elm
 */
function receiveCloudEvent(eventJson) {
  if (app && app.ports && app.ports.receiveCloudEvent) {
    app.ports.receiveCloudEvent.send(eventJson);
  }
}

/**
 * Notify Elm of connection status changes
 */
function notifyConnectionStatus(status) {
  if (app && app.ports && app.ports.connectionStatus) {
    app.ports.connectionStatus.send(status);
  }
}

/**
 * Register global error handler to forward errors to Elm
 */
function registerJSErrorHandler() {
  // Forward console errors to Elm
  const originalError = console.error;
  console.error = function(...args) {
    // Call original console.error
    originalError.apply(console, args);

    // Forward to Elm if port exists
    if (app && app.ports && app.ports.receiveJSError) {
      const message = args.map(arg =>
        typeof arg === 'string' ? arg : JSON.stringify(arg)
      ).join(" ");
      app.ports.receiveJSError.send(message);
    }
  };

  // Catch unhandled errors
  window.addEventListener('error', (event) => {
    if (app && app.ports && app.ports.receiveJSError) {
      app.ports.receiveJSError.send(`Uncaught Error: ${event.message} at ${event.filename}:${event.lineno}`);
    }
  });

  // Catch unhandled promise rejections
  window.addEventListener('unhandledrejection', (event) => {
    if (app && app.ports && app.ports.receiveJSError) {
      app.ports.receiveJSError.send(`Unhandled Promise Rejection: ${event.reason}`);
    }
  });
}

/**
 * Notify Elm of a JavaScript error
 */
function notifyJSError(message) {
  if (app && app.ports && app.ports.receiveJSError) {
    app.ports.receiveJSError.send(message);
  }
}

/**
 * Schedule a reconnection attempt with exponential backoff
 */
function scheduleReconnect() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
  }

  reconnectAttempts++;
  notifyConnectionStatus("Reconnecting");

  const delay = reconnectDelay * Math.pow(2, reconnectAttempts - 1);
  console.log(`WebUI: Reconnecting in ${delay}ms (attempt ${reconnectAttempts})`);

  reconnectTimer = setTimeout(() => {
    connectWebSocket(wsUrl);
  }, delay);
}

/**
 * Start heartbeat to detect stale connections
 */
function startHeartbeat() {
  stopHeartbeat();

  heartbeatInterval = setInterval(() => {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        topic: "phoenix",
        event: "heartbeat",
        payload: {},
        ref: generateRef()
      }));
    }
  }, config.heartbeatIntervalMs);
}

/**
 * Stop heartbeat
 */
function stopHeartbeat() {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
    heartbeatInterval = null;
  }
}

/**
 * Handle JavaScript commands from Elm
 */
function handleJSCommand(commandJson) {
  try {
    const command = JSON.parse(commandJson);

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

/**
 * Handle scroll commands
 */
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

/**
 * Handle focus commands
 */
function handleFocus(command) {
  if (command.selector) {
    const element = document.querySelector(command.selector);
    if (element) {
      element.focus();
    }
  }
}

/**
 * Handle localStorage commands
 */
function handleLocalStorage(command) {
  switch (command.action) {
    case "get":
      const value = localStorage.getItem(command.key);
      sendJSResponse({ type: "localStorage", key: command.key, value: value });
      break;

    case "set":
      localStorage.setItem(command.key, command.value);
      break;

    case "remove":
      localStorage.removeItem(command.key);
      break;

    case "clear":
      localStorage.clear();
      break;
  }
}

/**
 * Handle clipboard commands
 */
async function handleClipboard(command) {
  try {
    switch (command.action) {
      case "read":
        const text = await navigator.clipboard.readText();
        sendJSResponse({ type: "clipboard", action: "read", text: text });
        break;

      case "write":
        await navigator.clipboard.writeText(command.text);
        break;
    }
  } catch (error) {
    console.error("Clipboard error:", error);
  }
}

/**
 * Send a response back to Elm
 */
function sendJSResponse(response) {
  if (app && app.ports && app.ports.receiveJSResponse) {
    app.ports.receiveJSResponse.send(JSON.stringify(response));
  }
}

/**
 * Generate a Phoenix message reference
 */
function generateRef() {
  return String(Date.now());
}

/**
 * Cleanup on page unload
 */
window.addEventListener("beforeunload", () => {
  if (ws) {
    ws.close();
  }
  stopHeartbeat();
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
  }
});
