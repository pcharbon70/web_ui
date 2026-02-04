module WebUI.Constants exposing
    ( cloudEventsSpecVersion, defaultContentType, maxMessageQueueSize, maxCloudEventSizeBytes, websocketDefaults
    , WebSocketDefaults
    )

{-| Constant values used across the WebUI framework.

Centralized configuration values to prevent magic numbers and ensure consistency.


# Constants

@docs cloudEventsSpecVersion, defaultContentType, maxMessageQueueSize, maxCloudEventSizeBytes, websocketDefaults

-}


{-| CloudEvents specification version.
-}
cloudEventsSpecVersion : String
cloudEventsSpecVersion =
    "1.0"


{-| Default content type for CloudEvent data.
-}
defaultContentType : String
defaultContentType =
    "application/json"


{-| Maximum number of messages to queue when WebSocket is disconnected.

Prevents memory exhaustion from unlimited queue growth.

-}
maxMessageQueueSize : Int
maxMessageQueueSize =
    100


{-| Maximum size of a CloudEvent data payload in bytes.

Prevents large payloads from causing performance issues.

-}
maxCloudEventSizeBytes : Int
maxCloudEventSizeBytes =
    1024 * 1024



-- 1 MB


{-| Default WebSocket configuration values.
-}
websocketDefaults : WebSocketDefaults
websocketDefaults =
    { heartbeatInterval = 30
    , reconnectDelay = 1000
    , maxReconnectAttempts = 5
    , baseBackoffDelay = 1000
    , maxBackoffDelay = 30000
    }


{-| WebSocket default configuration values.
-}
type alias WebSocketDefaults =
    { heartbeatInterval : Int
    , reconnectDelay : Int
    , maxReconnectAttempts : Int
    , baseBackoffDelay : Int
    , maxBackoffDelay : Int
    }
