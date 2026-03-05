module Main exposing
    ( Flags, Model, Msg(..), Page(..)
    , main
    , init, update, view, subscriptions
    , stateToString, urlToPage
    )

import Browser
import Browser.Navigation as Nav
import Html exposing (Html, a, button, div, footer, h1, header, main_, nav, p, span, text)
import Html.Attributes exposing (class, disabled, href, type_)
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
    , key : Nav.Key
    , counter : Int
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
      , key = key
      , counter = 0
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
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External target ->
                    ( model, Nav.load target )

        UrlChanged url ->
            ( { model | page = urlToPage url }, Cmd.none )

        SentCloudEvent _ ->
            ( model, Cmd.none )

        IncrementClicked ->
            sendCounterCommand "com.webui.counter.increment" model

        DecrementClicked ->
            sendCounterCommand "com.webui.counter.decrement" model

        ResetClicked ->
            sendCounterCommand "com.webui.counter.reset" model


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

        syncCmd =
            case wsMsg of
                WebSocket.ConnectionStatusChanged Ports.Connected ->
                    sendCounterCommandCmd "com.webui.counter.sync" modelAfterEvent

                _ ->
                    Cmd.none
    in
    ( modelAfterEvent
    , Cmd.batch
        [ Cmd.map WebSocketMsg wsCmd
        , cloudEventCmd
        , syncCmd
        ]
    )


sendCounterCommand : String -> Model -> ( Model, Cmd Msg )
sendCounterCommand eventType model =
    let
        payload =
            CloudEvents.new "urn:webui:examples:counter:client" eventType Encode.null
                |> CloudEvents.encodeToString

        ( nextWsModel, wsCmd ) =
            WebSocket.send payload model.wsModel (websocketConfig model.flags)
    in
    ( { model | wsModel = nextWsModel }
    , Cmd.map WebSocketMsg wsCmd
    )


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
            if event.type_ == "com.webui.counter.state_changed" then
                case decodeCount event.data of
                    Just count ->
                        ( { model | counter = count }, Cmd.none )

                    Nothing ->
                        ( model, Cmd.none )

            else
                ( model, Cmd.none )

        Err _ ->
            ( model, Cmd.none )


decodeCount : Encode.Value -> Maybe Int
decodeCount data =
    case Decode.decodeValue (Decode.field "count" Decode.int) data of
        Ok count ->
            Just count

        Err _ ->
            Nothing



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
    span [ class statusClass ] [ text ("● " ++ stateToString state) ]


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
    div [ class "webui-page" ]
        [ h1 [] [ text "Counter Example" ]
        , p [] [ text "Server state is synchronized over WebSocket CloudEvents." ]
        , div [ class "card" ]
            [ p [ class "text-sm text-gray-600" ] [ text "Current Count" ]
            , div [ class "text-5xl font-bold py-3" ] [ text (String.fromInt model.counter) ]
            , div [ class "flex gap-3 flex-wrap" ]
                [ button
                    [ type_ "button"
                    , class "btn btn-primary"
                    , onClick IncrementClicked
                    , disabled (not connected)
                    ]
                    [ text "Increment" ]
                , button
                    [ type_ "button"
                    , class "btn btn-secondary"
                    , onClick DecrementClicked
                    , disabled (not connected)
                    ]
                    [ text "Decrement" ]
                , button
                    [ type_ "button"
                    , class "btn btn-secondary"
                    , onClick ResetClicked
                    , disabled (not connected)
                    ]
                    [ text "Reset" ]
                ]
            ]
        ]


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
