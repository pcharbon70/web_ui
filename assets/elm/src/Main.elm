module Main exposing
    ( Flags
    , Model
    , Msg(..)
    , Page(..)
    , init
    , main
    , stateToString
    , subscriptions
    , update
    , urlToPage
    , view
    )

import Browser
import Browser.Navigation as Nav
import Html exposing (Html, a, button, div, footer, h1, header, main_, nav, p, span, text)
import Html.Attributes exposing (attribute, class, disabled, href, type_)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Url exposing (Url)
import WebUI.CloudEvents as CloudEvents
import WebUI.Constants as Constants
import WebUI.Internal.WebSocket as WebSocket
import WebUI.Ports as Ports



-- PROGRAM


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- FLAGS


type alias Flags =
    { websocketUrl : String
    , pageMetadata : PageMetadata
    }


type alias PageMetadata =
    { title : Maybe String
    , description : Maybe String
    }



-- MODEL


type alias Model =
    { wsModel : WebSocket.Model
    , page : Page
    , flags : Flags
    , key : Maybe Nav.Key
    , counter : Int
    , syncPending : Bool
    , counterError : Maybe String
    }


type Page
    = HomePage
    | CounterPage
    | NotFound



-- MESSAGES


type Msg
    = WebSocketMsg WebSocket.Msg
    | ReceivedCloudEvent String
    | ConnectionChanged WebSocket.State
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | SentCloudEvent String
    | IncrementClicked
    | DecrementClicked
    | ResetClicked



-- INIT


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        wsConfig =
            websocketConfig flags

        ( wsModel, wsCmd ) =
            WebSocket.init wsConfig
    in
    ( { wsModel = wsModel
      , page = urlToPage url
      , flags = flags
      , key = Just key
      , counter = 0
      , syncPending = True
      , counterError = Nothing
      }
    , Cmd.batch
        [ Cmd.map WebSocketMsg wsCmd
        , Ports.initWebSocket flags.websocketUrl
        ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        WebSocketMsg wsMsg ->
            handleWebSocketMsg wsMsg model

        ReceivedCloudEvent data ->
            handleCloudEvent data model

        ConnectionChanged _ ->
            ( model, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    case model.key of
                        Just navKey ->
                            ( model, Nav.pushUrl navKey (Url.toString url) )

                        Nothing ->
                            ( model, Cmd.none )

                Browser.External target ->
                    ( model, Nav.load target )

        UrlChanged url ->
            ( { model | page = urlToPage url }, Cmd.none )

        SentCloudEvent _ ->
            ( model, Cmd.none )

        IncrementClicked ->
            sendCounterCommand counterIncrementType model

        DecrementClicked ->
            sendCounterCommand counterDecrementType model

        ResetClicked ->
            sendCounterCommand counterResetType model


handleWebSocketMsg : WebSocket.Msg -> Model -> ( Model, Cmd Msg )
handleWebSocketMsg wsMsg model =
    let
        ( nextWsModel, wsCmd ) =
            WebSocket.update wsMsg model.wsModel (websocketConfig model.flags)

        nextModel =
            { model | wsModel = nextWsModel }

        ( modelAfterEvent, cloudEventCmd ) =
            case wsMsg of
                WebSocket.ReceiveMessage payload ->
                    handleCloudEvent payload nextModel

                _ ->
                    ( nextModel, Cmd.none )

        modelAfterStatus =
            applyConnectionSideEffects wsMsg modelAfterEvent

        syncCmd =
            case wsMsg of
                WebSocket.ConnectionStatusChanged Ports.Connected ->
                    sendCounterCommandCmd counterSyncType modelAfterStatus

                _ ->
                    Cmd.none
    in
    ( modelAfterStatus
    , Cmd.batch
        [ Cmd.map WebSocketMsg wsCmd
        , cloudEventCmd
        , syncCmd
        ]
    )


applyConnectionSideEffects : WebSocket.Msg -> Model -> Model
applyConnectionSideEffects wsMsg model =
    case wsMsg of
        WebSocket.ConnectionStatusChanged Ports.Connected ->
            { model | syncPending = True, counterError = Nothing }

        WebSocket.ConnectionStatusChanged Ports.Reconnecting ->
            { model | syncPending = True }

        WebSocket.ConnectionStatusChanged Ports.Disconnected ->
            { model | syncPending = True }

        WebSocket.ConnectionStatusChanged (Ports.Error _) ->
            { model | syncPending = True }

        _ ->
            model


sendCounterCommand : String -> Model -> ( Model, Cmd Msg )
sendCounterCommand eventType model =
    if WebSocket.isConnected model.wsModel then
        let
            payload =
                CloudEvents.new counterClientSource eventType Encode.null
                    |> CloudEvents.encodeToString

            ( nextWsModel, wsCmd ) =
                WebSocket.send payload model.wsModel (websocketConfig model.flags)
        in
        ( { model | wsModel = nextWsModel, counterError = Nothing }
        , Cmd.map WebSocketMsg wsCmd
        )

    else
        ( model, Cmd.none )


sendCounterCommandCmd : String -> Model -> Cmd Msg
sendCounterCommandCmd eventType model =
    let
        ( _, cmd ) =
            sendCounterCommand eventType model
    in
    cmd



-- CLOUD EVENTS


handleCloudEvent : String -> Model -> ( Model, Cmd Msg )
handleCloudEvent payload model =
    case CloudEvents.decodeFromString payload of
        Ok event ->
            handleCounterEvent event model

        Err _ ->
            ( { model | counterError = Just "Received malformed CloudEvent payload from server." }, Cmd.none )


handleCounterEvent : CloudEvents.CloudEvent -> Model -> ( Model, Cmd Msg )
handleCounterEvent event model =
    if event.type_ == counterStateChangedType then
        handleStateChangedEvent event.data model

    else if event.type_ == counterErrorType || event.type_ == counterServerErrorType then
        ( { model | counterError = Just (decodeServerErrorMessage event.data) }, Cmd.none )

    else
        ( model, Cmd.none )


handleStateChangedEvent : Encode.Value -> Model -> ( Model, Cmd Msg )
handleStateChangedEvent data model =
    case Decode.decodeValue stateChangedPayloadDecoder data of
        Ok payload ->
            ( { model
                | counter = payload.count
                , syncPending = False
                , counterError = Nothing
              }
            , Cmd.none
            )

        Err _ ->
            ( { model | counterError = Just "Received malformed counter state payload from server." }, Cmd.none )


decodeServerErrorMessage : Encode.Value -> String
decodeServerErrorMessage data =
    Decode.decodeValue
        (Decode.oneOf
            [ Decode.field "message" Decode.string
            , Decode.field "reason" Decode.string
            ]
        )
        data
        |> Result.withDefault "Server returned an unknown counter error."


type alias StateChangedPayload =
    { count : Int
    , operation : Maybe String
    }


stateChangedPayloadDecoder : Decode.Decoder StateChangedPayload
stateChangedPayloadDecoder =
    Decode.map2
        (\count operation ->
            { count = count
            , operation = operation
            }
        )
        (Decode.field "count" Decode.int)
        (Decode.maybe (Decode.field "operation" Decode.string))



-- WEBSOCKET CONFIG


websocketConfig : Flags -> WebSocket.Config Msg
websocketConfig flags =
    let
        defaults =
            Constants.websocketDefaults
    in
    { url = flags.websocketUrl
    , onMessage = ReceivedCloudEvent
    , onStatusChange = ConnectionChanged
    , heartbeatInterval = defaults.heartbeatInterval
    , reconnectDelay = defaults.reconnectDelay
    , maxReconnectAttempts = defaults.maxReconnectAttempts
    }



-- ROUTING


urlToPage : Url -> Page
urlToPage url =
    case url.path of
        "/" ->
            HomePage

        "" ->
            HomePage

        "/counter" ->
            CounterPage

        _ ->
            NotFound


counterClientSource : String
counterClientSource =
    "urn:webui:examples:counter:client"


counterIncrementType : String
counterIncrementType =
    "com.webui.counter.increment"


counterDecrementType : String
counterDecrementType =
    "com.webui.counter.decrement"


counterResetType : String
counterResetType =
    "com.webui.counter.reset"


counterSyncType : String
counterSyncType =
    "com.webui.counter.sync"


counterStateChangedType : String
counterStateChangedType =
    "com.webui.counter.state_changed"


counterErrorType : String
counterErrorType =
    "com.webui.counter.error"


counterServerErrorType : String
counterServerErrorType =
    "com.webui.counter.server_error"



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = documentTitle model.page
    , body =
        [ div [ class "webui-app" ]
            [ viewHeader model
            , viewPage model
            , viewFooter
            ]
        ]
    }


documentTitle : Page -> String
documentTitle page =
    case page of
        CounterPage ->
            "Counter Example"

        _ ->
            "WebUI"


viewHeader : Model -> Html Msg
viewHeader model =
    header [ class "webui-header" ]
        [ nav [ class "webui-nav" ]
            [ a [ class "webui-nav-link", href "/" ] [ text "Home" ]
            , a [ class "webui-nav-link", href "/counter" ] [ text "Counter" ]
            ]
        , viewConnectionStatus model
        ]


viewConnectionStatus : Model -> Html Msg
viewConnectionStatus model =
    let
        state =
            WebSocket.getState model.wsModel

        statusClass =
            case state of
                WebSocket.Connected ->
                    "webui-status webui-status-connected"

                WebSocket.Connecting ->
                    "webui-status webui-status-connecting"

                WebSocket.Reconnecting _ ->
                    "webui-status webui-status-reconnecting"

                WebSocket.Disconnected ->
                    "webui-status webui-status-disconnected"

                WebSocket.Error _ ->
                    "webui-status webui-status-error"
    in
    span
        [ class statusClass
        , attribute "role" "status"
        , attribute "aria-live" "polite"
        ]
        [ text ("● " ++ stateToString state) ]


viewPage : Model -> Html Msg
viewPage model =
    main_ [ class "webui-main" ]
        [ case model.page of
            HomePage ->
                viewHomePage

            CounterPage ->
                viewCounterPage model

            NotFound ->
                viewNotFound
        ]


viewHomePage : Html Msg
viewHomePage =
    div [ class "webui-page" ]
        [ h1 [] [ text "Welcome to WebUI" ]
        , p [] [ text "Open the counter example to try end-to-end CloudEvents." ]
        , p []
            [ a [ href "/counter", class "btn btn-primary" ] [ text "Open Counter" ] ]
        ]


viewCounterPage : Model -> Html Msg
viewCounterPage model =
    let
        connected =
            WebSocket.isConnected model.wsModel
    in
    div [ class "webui-page max-w-3xl mx-auto w-full px-4 sm:px-6" ]
        [ h1 [ attribute "id" "counter-title" ] [ text "Counter Example" ]
        , p [ class "text-sm sm:text-base text-gray-700" ] [ text "Server state is synchronized over WebSocket CloudEvents." ]
        , viewCounterStatusMessages model
        , div [ class "card p-5 sm:p-6", attribute "aria-labelledby" "counter-title" ]
            [ p [ class "text-sm text-gray-600" ] [ text "Current Count" ]
            , div
                [ class "text-5xl sm:text-6xl font-bold py-3 leading-none"
                , attribute "role" "status"
                , attribute "aria-live" "polite"
                , attribute "aria-atomic" "true"
                ]
                [ text (String.fromInt model.counter) ]
            , div [ class "flex gap-3 flex-wrap", attribute "role" "group", attribute "aria-label" "Counter controls" ]
                [ button
                    [ type_ "button"
                    , class "btn btn-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-phoenix-primary"
                    , onClick IncrementClicked
                    , disabled (not connected)
                    , attribute "aria-label" "Increment counter"
                    , attribute "aria-disabled"
                        (if connected then
                            "false"

                         else
                            "true"
                        )
                    ]
                    [ text "Increment" ]
                , button
                    [ type_ "button"
                    , class "btn btn-secondary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-phoenix-primary"
                    , onClick DecrementClicked
                    , disabled (not connected)
                    , attribute "aria-label" "Decrement counter"
                    , attribute "aria-disabled"
                        (if connected then
                            "false"

                         else
                            "true"
                        )
                    ]
                    [ text "Decrement" ]
                , button
                    [ type_ "button"
                    , class "btn btn-secondary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-phoenix-primary"
                    , onClick ResetClicked
                    , disabled (not connected)
                    , attribute "aria-label" "Reset counter"
                    , attribute "aria-disabled"
                        (if connected then
                            "false"

                         else
                            "true"
                        )
                    ]
                    [ text "Reset" ]
                ]
            ]
        ]


viewCounterStatusMessages : Model -> Html Msg
viewCounterStatusMessages model =
    let
        connectionMessage =
            connectionStatusMessage model

        connectionMessageView =
            case connectionMessage of
                Just message ->
                    [ viewInfoMessage message ]

                Nothing ->
                    []

        errorMessageView =
            case model.counterError of
                Just message ->
                    [ viewErrorMessage message ]

                Nothing ->
                    []

        messageViews =
            connectionMessageView ++ errorMessageView
    in
    if List.isEmpty messageViews then
        text ""

    else
        div [ class "space-y-2 mt-4 mb-5" ] messageViews


connectionStatusMessage : Model -> Maybe String
connectionStatusMessage model =
    case WebSocket.getState model.wsModel of
        WebSocket.Connected ->
            if model.syncPending then
                Just "Connected. Synchronizing counter state..."

            else
                Nothing

        WebSocket.Connecting ->
            Just "Connecting to the counter service..."

        WebSocket.Reconnecting attempt ->
            Just ("Reconnecting to the counter service (attempt " ++ String.fromInt attempt ++ ").")

        WebSocket.Disconnected ->
            Just "Disconnected from the counter service. Reconnect is in progress."

        WebSocket.Error message ->
            Just ("Connection error: " ++ message)


viewInfoMessage : String -> Html Msg
viewInfoMessage message =
    p
        [ class "rounded-md border border-blue-200 bg-blue-50 px-3 py-2 text-sm text-blue-900"
        , attribute "role" "status"
        , attribute "aria-live" "polite"
        ]
        [ text message ]


viewErrorMessage : String -> Html Msg
viewErrorMessage message =
    p
        [ class "rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-900"
        , attribute "role" "alert"
        , attribute "aria-live" "assertive"
        ]
        [ text message ]


viewNotFound : Html Msg
viewNotFound =
    div [ class "webui-page webui-not-found" ]
        [ h1 [] [ text "404 - Page Not Found" ]
        , p [] [ text "The page you requested could not be found." ]
        , a [ href "/" ] [ text "Go to Home" ]
        ]


viewFooter : Html Msg
viewFooter =
    footer [ class "webui-footer" ]
        [ p []
            [ text "Powered by "
            , a [ href "https://elm-lang.org/" ] [ text "Elm" ]
            , text " and "
            , a [ href "https://www.phoenixframework.org/" ] [ text "Phoenix" ]
            ]
        ]


stateToString : WebSocket.State -> String
stateToString state =
    case state of
        WebSocket.Connecting ->
            "Connecting"

        WebSocket.Connected ->
            "Connected"

        WebSocket.Reconnecting _ ->
            "Reconnecting"

        WebSocket.Disconnected ->
            "Disconnected"

        WebSocket.Error message ->
            "Error: " ++ message



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Sub.map WebSocketMsg <|
            WebSocket.subscriptions model.wsModel (websocketConfig model.flags)
        ]
