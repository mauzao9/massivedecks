module MassiveDecks.Scenes.Playing.UI exposing (view)

import Html exposing (..)
import Html.App as Html
import Html.Attributes exposing (..)
import Html.Events exposing (..)

import MassiveDecks.Components.Icon as Icon
import MassiveDecks.Models.Game as Game
import MassiveDecks.Models.Player as Player exposing (Player)
import MassiveDecks.Models.Card as Card
import MassiveDecks.Scenes.History as History
import MassiveDecks.Scenes.Lobby.Models as Lobby
import MassiveDecks.Scenes.Playing.UI.Cards as CardsUI
import MassiveDecks.Scenes.Playing.Models exposing (ShownCard)
import MassiveDecks.Scenes.Playing.Messages exposing (Message(..))
import MassiveDecks.Scenes.Playing.HouseRule as HouseRule exposing (HouseRule)
import MassiveDecks.Scenes.Playing.HouseRule.Available exposing (houseRules)
import MassiveDecks.Util as Util


view : Lobby.Model -> (List (Html Message), List (Html Message))
view lobbyModel =
  let
    model = lobbyModel.playing
    lobby = lobbyModel.lobby
    (header, content) = case model.finishedRound of
          Just round ->
            winnerHeaderAndContents round lobby.players

          Nothing ->
            case lobby.round of
              Just round ->
                ([ Icon.icon "gavel", text (" " ++ (czarName lobby.players round.czar)) ], roundContents lobbyModel round)

              Nothing ->
                ([], [])
  in
    case model.history of
      Nothing ->
        (header, List.concat [ infoBar lobby lobbyModel.secret
                             , content
                             , [ warningDrawer (List.concat [ skippingNotice lobby.players lobbyModel.secret.id
                                                            , disconnectedNotice lobby.players
                                                            ]) ]
                             ])
      Just history ->
        ([], [ History.view history lobbyModel.lobby.players |> Html.map HistoryMessage ])


gameMenu : Lobby.Model -> Html Message
gameMenu lobbyModel =
  let
    enabled = List.filter (\rule -> List.member rule.id lobbyModel.lobby.config.houseRules) houseRules
  in
    div [ class "action-menu mui-dropdown"]
        [ button [ class "mui-btn mui-btn--small mui-btn--fab"
                 , title "Game actions."
                 , attribute "data-mui-toggle" "dropdown"
                 ]
                 [ Icon.icon "bars" ]
        , ul [ class "mui-dropdown__menu mui-dropdown__menu--right" ]
             ( [ li [] [ a [ classList [ ("link", True) ]
                           , title "View previous rounds from the game."
                           , attribute "tabindex" "0"
                           , attribute "role" "button"
                           , onClick ViewHistory
                           ]
                           [ Icon.fwIcon "history", text " ", text "Game History" ]
                       ]
               ] ++
               (List.concatMap (gameMenuItems lobbyModel) enabled))
        ]


gameMenuItems : Lobby.Model -> HouseRule -> List (Html Message)
gameMenuItems lobbyModel rule = List.map (gameMenuItem lobbyModel rule) rule.actions


gameMenuItem : Lobby.Model -> HouseRule -> HouseRule.Action -> Html Message
gameMenuItem lobbyModel rule action =
  let
    enabled = action.enabled lobbyModel
    message = if enabled then action.onClick else NoOp
  in
    li [] [ a [ classList [ ("link", True), ("disabled", not enabled) ]
              , title action.description
              , attribute "tabindex" "0"
              , attribute "role" "button"
              , onClick message
              ]
              [ Icon.fwIcon action.icon, text " ", text action.text ]
          ]


roundContents : Lobby.Model -> Game.Round -> List (Html Message)
roundContents lobbyModel round =
  let
    lobby = lobbyModel.lobby
    hand = lobbyModel.hand.hand
    model = lobbyModel.playing
    picked = getAllById model.picked hand
    id = lobbyModel.secret.id
    isCzar = round.czar == id
    canPlay = List.filter (\player -> player.id == id) lobby.players
      |> List.all (\player -> player.status == Player.NotPlayed)
    callFill = case round.responses of
      Card.Revealed responses ->
        Maybe.withDefault [] (model.considering `Maybe.andThen` (Util.get responses.cards))
      Card.Hidden _ ->
        picked
    pickedOrChosen = case round.responses of
      Card.Revealed responses ->
        case model.considering of
          Just considering ->
            case Util.get responses.cards considering of
              Just consideringCards -> [ consideringView considering consideringCards isCzar ]
              Nothing -> []
          Nothing -> []
      Card.Hidden _ -> pickedView picked (Card.slots round.call) (model.shownPlayed.animated ++ model.shownPlayed.toAnimate)
    playedOrHand = case round.responses of
      Card.Revealed responses -> playedView isCzar responses
      Card.Hidden _ -> handView model.picked (not canPlay) hand
  in
    [ playArea
      ([ div [ class "round-area" ] (List.concat [ [ CardsUI.call round.call callFill ], pickedOrChosen ])
       , playedOrHand
       , gameMenu lobbyModel
       ])
    ]


getAllById : List String -> List Card.Response -> List Card.Response
getAllById ids cards =
  List.filterMap (getById cards) ids


getById : List Card.Response -> String -> Maybe Card.Response
getById cards id = List.filter (\card -> card.id == id) cards |> List.head


consideringView : Int -> List Card.Response -> Bool -> Html Message
consideringView considering consideringCards isCzar =
  let
    extra = if isCzar then [ chooseButton considering ] else []
  in
    ol [ class "considering" ]
      (List.append (List.map (\card -> li [] [ (playedResponse card) ]) consideringCards) extra)


winnerHeaderAndContents : Game.FinishedRound -> List Player -> (List (Html Message), List (Html Message))
winnerHeaderAndContents round players =
  let
    cards = round.responses
    winning = Card.winningCards cards round.playedByAndWinner |> Maybe.withDefault []
    winner = Maybe.map .name (Util.get players round.playedByAndWinner.winner) |> Maybe.withDefault ""
  in
    ( [ Icon.icon "trophy", text (" " ++ winner) ]
    , [ div [ class "winner mui-panel" ]
            [ h1 [] [ Icon.icon "trophy" ]
            , h2 [] [ text (" " ++ Card.filled round.call winning) ]
            , h3 [] [ text ("- " ++ winner) ]
            ]
      , button [ id "next-round-button", class "mui-btn mui-btn--primary mui-btn--raised", onClick NextRound ]
               [ text "Next Round" ]
      ]
    )


czarName : List Player -> Player.Id -> String
czarName players czarId =
  (List.filter (\player -> player.id == czarId) players) |> List.head |> Maybe.map .name |> Maybe.withDefault ""


playArea : List (Html Message) -> Html Message
playArea contents = div [ class "play-area" ] contents


response : List String -> Bool -> Card.Response -> Html Message
response picked disabled response =
  let
    isPicked = List.member response.id picked
    clickHandler = if isPicked || disabled then [] else [ onClick (Pick response.id) ]
  in
    CardsUI.response isPicked clickHandler response


blankResponse : ShownCard -> Html Message
blankResponse shownCard = div [ class "card mui-panel", positioning shownCard ] []


positioning : ShownCard -> Html.Attribute msg
positioning shownCard =
  let
    horizontalDirection = if shownCard.isLeft then "left" else "right"
  in
    style
      [ ("transform", "rotate(" ++ (toString shownCard.rotation) ++ "deg)")
      , (horizontalDirection, (toString shownCard.horizontalPos) ++ "%")
      , ("top", (toString shownCard.verticalPos) ++ "%")
      ]


handRender : Bool -> List (Html Message) -> Html Message
handRender disabled contents =
  let
    classes = "hand mui--divider-top" ++ if disabled then " disabled" else ""
  in
    ul [ class classes ] (List.map (\item -> li [] [ item ]) contents)


handView : List String -> Bool -> List Card.Response -> Html Message
handView picked disabled responses =
  handRender disabled (List.map (response picked disabled) responses)


pickedResponse : Card.Response -> Html Message
pickedResponse response =
  li []
     [ div [ class "card response mui-panel" ] [ div [ class "response-text" ]
                                                     [ text (Util.firstLetterToUpper response.text)
                                                     , text "."
                                                     ]
                                               , withdrawButton response.id
                                               ] ]


pickedView : List Card.Response -> Int -> List (ShownCard) -> List (Html Message)
pickedView picked slots shownPlayed =
  let
    numberPicked = List.length picked
    pb = if (numberPicked < slots) then [] else [ playButton ]
    pickedResponses = List.map (pickedResponse) picked
  in
    [ ol [ class "picked" ] (List.concat [ pickedResponses, pb ])
    , div [ class "others-picked" ] (List.map blankResponse shownPlayed)
    ]


withdrawButton : String -> Html Message
withdrawButton id = button
  [ class "withdraw-button mui-btn mui-btn--small mui-btn--danger mui-btn--fab"
  , title "Take back this response."
  , onClick (Withdraw id) ]
  [ Icon.icon "times" ]


playButton : Html Message
playButton = li [ class "play-button" ] [ button
  [ class "mui-btn mui-btn--small mui-btn--accent mui-btn--fab", title "Play these responses.", onClick Play ]
  [ Icon.icon "check" ] ]


playedView : Bool -> Card.RevealedResponses -> Html Message
playedView isCzar responses =
  ol [ class "played mui--divider-top" ]
     (List.indexedMap (\index pc -> li [] [ (playedCards isCzar index pc) ]) responses.cards)


playedCards : Bool -> Int -> Card.PlayedCards -> Html Message
playedCards isCzar playedId cards =
    ol
    [ onClick (Consider playedId) ]
    (List.map (\card -> li [] [ (playedResponse card) ]) cards)


playedResponse : Card.Response -> Html Message
playedResponse response =
  div [ class "card response mui-panel" ]
    [ div [ class "response-text" ]
          [ text (Util.firstLetterToUpper response.text), text "." ] ]


chooseButton : Int -> Html Message
chooseButton playedId = li [ class "choose-button" ] [ button
  [ class "mui-btn mui-btn--small mui-btn--accent mui-btn--fab", onClick (Choose playedId) ]
  [ Icon.icon "trophy" ] ]


infoBar : Game.Lobby -> Player.Secret -> List (Html Message)
infoBar lobby secret =
  let
    content = Maybe.oneOf [ statusInfo lobby.players secret.id, stateInfo lobby.round ]
  in
    case content of
      Just message ->
        [ div [ id "info-bar" ]
           [ Icon.icon "info-circle"
           , text " "
           , text message
           ]
        ]
      Nothing ->
        []


statusInfo : List Player -> Player.Id -> Maybe String
statusInfo players id =
  case players |> Util.find (\player -> player.id == id) |> Maybe.map .status of
    Just status ->
      case status of
        Player.Skipping ->
          Nothing {- There is a warning for this instead. -}
        Player.Neutral ->
          Just "You joined while this round was already in play, you will be able to play next round."
        Player.Czar ->
          Just "As card czar for this round - you don't play into the round, you pick the winner."
        _ ->
          Nothing
    Nothing ->
      Nothing


stateInfo : Maybe Game.Round -> Maybe String
stateInfo round =
  round `Maybe.andThen` (\round ->
    case round.responses of
      Card.Hidden _ ->
        Nothing
      Card.Revealed _ ->
        Just "The card czar is now picking a winner.")


warningDrawer : List (Html Message) -> Html Message
warningDrawer contents =
  let
    hidden = List.isEmpty contents
    classes =
      [ ("hidden", hidden)
      ]
  in
  div [ id "warning-drawer", classList classes ]
      [ button [ attribute "onClick" "toggleWarningDrawer()"
               , class "toggle mui-btn mui-btn--small mui-btn--fab"
               , title "Warning notices."
               ] [ Icon.icon "exclamation-triangle" ]
      , div [ class "top" ] []
      , div [ class "contents" ] contents
      ]


skippingNotice : List Player -> Player.Id -> List (Html Message)
skippingNotice players id =
  let
    status = players |> Util.find (\player -> player.id == id) |> Maybe.map .status
    renderSkippingNoticeIfSkipping = (\status ->
      case status of
        Player.Skipping ->
          renderSkippingNotice
        _ ->
          [])
  in
    Maybe.map renderSkippingNoticeIfSkipping status |> Maybe.withDefault []


renderSkippingNotice : List (Html Message)
renderSkippingNotice =
  [ div [ class "notice" ]
    [ h3 [] [ Icon.icon "fast-forward" ]
    , span [] [ text "You are currently being skipped because you took too long to play. "
              , a [ class "link"
                  , attribute "tabindex" "0"
                  , attribute "role" "button"
                  ]
                  [ Icon.fwIcon "bell", text "Enable Notifications?" ]
              ]
    , div [ class "actions" ]
          [ button [ class "mui-btn mui-btn--small"
                   , onClick Back
                   , title "Rejoin the game."
                   ]
                   [ Icon.icon "sign-in", text " Rejoin" ]
          ]
    ]
 ]


timeoutNotice : List Player -> Bool -> List (Html Message)
timeoutNotice players timeout =
  let
    timedOutPlayers = List.filter (\player -> player.status == Player.NotPlayed) players
    timedOutNames = Util.joinWithAnd (List.map .name timedOutPlayers)
    timedOutIds = List.map .id timedOutPlayers
  in
    if timeout then
      Maybe.map (renderTimeoutNotice timedOutIds (Util.pluralHas timedOutPlayers)) timedOutNames
      |> Maybe.map (\item -> [ item ])
      |> Maybe.withDefault []
    else
      []


renderTimeoutNotice : List Player.Id -> String -> String -> Html Message
renderTimeoutNotice ids has names =
  div [ class "notice" ]
      [ h3 [] [ Icon.icon "minus-circle" ]
      , span [] [ text names
                , text " "
                , text has
                , text " not played into the round before the round timer ran out."
                ]
      , div [ class "actions" ]
            [ button [ class "mui-btn mui-btn--small"
                     , onClick (Skip ids)
                     , title "They will be removed from this round, and won't be in future rounds until they come back."
                     ]
                     [ Icon.icon "fast-forward", text " Skip" ]
            ]
      ]


disconnectedNotice : List Player -> List (Html Message)
disconnectedNotice players =
  let
    disconnected = List.filter (\player -> player.disconnected && (not (player.status == Player.Skipping))) players
    disconnectedNames = Util.joinWithAnd (List.map .name disconnected)
    disconnectedIds = List.map .id disconnected
  in
    Maybe.map (renderDisconnectedNotice disconnectedIds (Util.pluralHas disconnected)) disconnectedNames
    |> Maybe.map (\item -> [ item ])
    |> Maybe.withDefault []


renderDisconnectedNotice : List Player.Id -> String -> String -> Html Message
renderDisconnectedNotice ids has disconnectedNames =
  div [ class "notice" ]
      [ h3 [] [ Icon.icon "minus-circle" ]
      , span [] [ text disconnectedNames
                , text " "
                , text has
                , text " disconnected from the game."
                ]
      , div [ class "actions" ]
            [ button [ class "mui-btn mui-btn--small"
                     , onClick (Skip ids)
                     , title "They will be removed from this round, and won't be in future rounds until they reconnect."
                     ]
                     [ Icon.icon "fast-forward", text " Skip" ]
            ]
      ]
