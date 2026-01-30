# WebUI JavaScript Interop Tests

## Verification Checklist

### 4.7.1 Verify JS is valid syntax

Run through Node.js:
```bash
node -c assets/js/web_ui_interop.js
```

Expected: No syntax errors

### 4.7.2 Verify Elm app initializes

Open browser console, should see:
```
WebUI: Elm app initialized
```

### 4.7.3 Verify port handlers are registered

In browser console after init:
```javascript
// Check if ports exist
Object.keys(app.ports)
// Should include: sendCloudEvent, initWebSocket, receiveCloudEvent, sendJSCommand, receiveJSResponse, connectionStatus, receiveJSError
```

### 4.7.4 Verify WebSocket can connect

In browser console:
```javascript
// Manually trigger connection
app.ports.initWebSocket.send("ws://localhost:4000/socket/websocket");
```

Expected: WebSocket connection established, status updates in UI

## Manual Test Steps

1. Load page with Elm app
2. Check browser console for initialization messages
3. Verify connection status indicator appears
4. Check for errors in console
5. Test sending a CloudEvent (if connected)

## Error Handling Tests

1. Disconnect WebSocket manually
2. Verify reconnection attempts occur
3. Verify exponential backoff delays
4. Verify max reconnect attempts stops reconnection

## Console Error Forwarding Tests

1. Trigger console.error in browser
2. Verify error is forwarded to Elm (if receiveJSError port subscribed)
