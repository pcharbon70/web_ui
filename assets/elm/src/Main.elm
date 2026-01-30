module Main exposing
    ( Flags
    , Model
    , Msg(..)
    , Page(..)
    , init
    , main
    , subscriptions
    , update
    , view
    )

{-| Main application entry point for WebUI Elm SPA.

This module ties together all Elm modules following The Elm Architecture (TEA).

# Types

@docs Flags, Model, Msg, Page

# Entry Point

@docs main

# TEA Functions

@docs init, update, view, subscriptions

-}

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Encode as Encode
import Url exposing (Url)
import WebUI.CloudEvents as CloudEvents
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


{-| Flags passed from JavaScript when initializing the Elm app.

Example from JavaScript:

    var flags = {
        websocketUrl: "ws://localhost:4000/socket",
        pageMetadata: {
            title: "My Page",
            description: "My Description"
        }
    };

    var app = Elm.Main.init({ flags: flags });

-}
type alias Flags =
    { websocketUrl : String
    , pageMetadata : PageMetadata
    }


{-| Page metadata passed from server.

-}
type alias PageMetadata =
    { title : Maybe String
    , description : Maybe String
    }



-- MODEL


{-| The main application model.

-}
type alias Model =
    { wsModel : WebSocket.Model
    , page : Page
    , flags : Flags
    , key : Nav.Key
    }


{-| Current page in the SPA.

-}
type Page
    = HomePage
    | NotFound



-- MESSAGES


{-| Messages for the application.

-}
type Msg
    = WebSocketMsg WebSocket.Msg
    | ReceivedCloudEvent String
    | ConnectionChanged WebSocket.State
    | LinkClicked Url.Request
    | UrlChanged Url.Url
    | SentCloudEvent String



-- INIT


{-| Initialize the application.

-}
init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        wsConfig : WebSocket.Config Msg
        wsConfig =
            { url = flags.websocketUrl
            , onMessage = ReceivedCloudEvent
            , onStatusChange = ConnectionChanged
            , heartbeatInterval = 30
            , reconnectDelay = 1000
            , maxReconnectAttempts = 5
            }

        ( wsModel, wsCmd ) =
            WebSocket.init wsConfig

        initCmd : Cmd Msg
        initCmd =
            Cmd.batch
                [ Cmd.map WebSocketMsg wsCmd
                , Ports.initWebSocket flags.websocketUrl
                ]
    in
    ( { wsModel = wsModel
      , page = urlToPage url
      , flags = flags
      , key = key
      }
    , initCmd
    )



-- UPDATE


{-| Update the application state.

-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        WebSocketMsg wsMsg ->
            let
                ( newWsModel, wsCmd ) =
                    WebSocket.update wsMsg model.wsModel wsConfig
            in
            ( { model | wsModel = newWsModel }
            , Cmd.map WebSocketMsg wsCmd
            )

        ReceivedCloudEvent data ->
            -- Handle incoming CloudEvent
            handleCloudEvent data model

        ConnectionChanged state ->
            -- Handle connection state change
            ( model, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
                Url.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Url.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | page = urlToPage url }, Cmd.none )

        SentCloudEvent data ->
            -- Event was sent, update model if needed
            ( model, Cmd.none )



-- WEBSOCKET CONFIG


wsConfig : WebSocket.Config Msg
wsConfig =
    { url = ""
    , onMessage = ReceivedCloudEvent
    , onStatusChange = ConnectionChanged
    , heartbeatInterval = 30
    , reconnectDelay = 1000
    , maxReconnectAttempts = 5
    }



-- CLOUD EVENT HANDLER


handleCloudEvent : String -> Model -> ( Model, Cmd Msg )
handleCloudEvent data model =
    case CloudEvents.decodeFromString data of
        Ok event ->
            -- Route CloudEvent to appropriate handler
            ( model, Cmd.none )

        Err err ->
            -- Log error, ignore invalid CloudEvent
            ( model, Cmd.none )



-- URL TO PAGE


urlToPage : Url -> Page
urlToPage url =
    case url.path of
        "/" ->
            HomePage

        "" ->
            HomePage

        _ ->
            NotFound



-- VIEW


{-| Render the application.

-}
view : Model -> Html Msg
view model =
    div [ class "webui-app" ]
        [ viewHeader model
        , viewPage model
        , viewFooter model
        ]



viewHeader : Model -> Html Msg
viewHeader model =
    header [ class "webui-header" ]
        [ nav [ class "webui-nav" ]
            [ a [ class "webui-nav-link", href "/" ]
                [ text "Home" ]
            ]
        , viewConnectionStatus model
        ]



viewConnectionStatus : Model -> Html Msg
viewConnectionStatus model =
    let
        state =
            WebSocket.getState model.wsModel
    in
    case state of
        WebSocket.Connected ->
            span [ class "webui-status webui-status-connected" ]
                [ text "● Connected" ]

        WebSocket.Connecting ->
            span [ class "webui-status webui-status-connecting" ]
                [ text "● Connecting..." ]

        WebSocket.Reconnecting _ ->
            span [ class "webui-status webui-status-reconnecting" ]
                [ text "● Reconnecting..." ]

        WebSocket.Disconnected ->
            span [ class "webui-status webui-status-disconnected" ]
                [ text "● Disconnected" ]

        WebSocket.Error err ->
            span [ class "webui-status webui-status-error" ]
                [ text ("● Error: " ++ err) ]



viewPage : Model -> Html Msg
viewPage model =
    main_ [ class "webui-main" ]
        [ case model.page of
            HomePage ->
                viewHomePage model

            NotFound ->
                viewNotFound model
        ]



viewHomePage : Model -> Html Msg
viewHomePage model =
    div [ class "webui-page" ]
        [ h1 [] [ text "Welcome to WebUI" ]
        , p []
            [ text "This is the WebUI application powered by Elm and Phoenix." ]
        , viewConnectionDetails model
        , viewSendExample model
        ]



viewConnectionDetails : Model -> Html Msg
viewConnectionDetails model =
    let
        state =
            WebSocket.getState model.wsModel
    in
    div [ class "webui-connection-details" ]
        [ h2 [] [ text "Connection Details" ]
        , ul []
            [ li [] [ text ("URL: " ++ model.flags.websocketUrl) ]
            , li []
                [ text ("State: " ++ stateToString state) ]
            , li []
                [ text
                    ("Status: "
                        ++ (if WebSocket.isConnected model.wsModel then
                                "Ready"

                            else
                                "Not Ready"
                           )
                    )
                ]
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

        WebSocket.Error _ ->
            "Error"


viewSendExample : Model -> Html Msg
viewSendExample model =
    div [ class "webui-send-example" ]
        [ h2 [] [ text "Send a Test Event" ]
        , button
            [ type_ "button"
            , onClick (SentCloudEvent "test")
            , disabled (not (WebSocket.isConnected model.wsModel))
            ]
            [ text "Send Test Event" ]
        ]



viewNotFound : Model -> Html Msg
viewNotFound model =
    div [ class "webui-page webui-not-found" ]
        [ h1 [] [ text "404 - Page Not Found" ]
        , p [] [ text "The page you requested could not be found." ]
        , a [ href "/" ] [ text "Go to Home" ]
        ]



viewFooter : Model -> Html Msg
viewFooter model =
    footer [ class "webui-footer" ]
        [ p []
            [ text "Powered by "
            , a [ href "https://elm-lang.org/", target "_blank" ]
                [ text "Elm" ]
            , text " and "
            , a [ href "https://www.phoenixframework.org/", target "_blank" ]
                [ text "Phoenix" ]
            ]
        ]



-- SUBSCRIPTIONS


{-| Subscriptions for the application.

-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Sub.map WebSocketMsg <|
            WebSocket.subscriptions model.wsModel wsConfig
        ]
