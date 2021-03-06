package controllers.massivedecks

import javax.inject.Inject

import scala.util.{Failure, Success, Try}

import controllers.massivedecks.exceptions.{BadRequestException, ForbiddenException, NotFoundException, RequestFailedException}
import models.massivedecks.Player
import models.massivedecks.Lobby.Formatters._
import models.massivedecks.Player.Formatters._
import models.massivedecks.Game.Formatters._
import play.api.libs.json.{JsResult, JsValue, Json}
import play.api.mvc._


class Application @Inject() (store: LobbyStore) extends Controller {

  def index() = Action { request =>
    val protocol = request.headers.get("X-Forwarded-Proto") match {
      case Some(proto) => proto
      case None => if (request.secure) { "https" } else { "http" }
    }
    Ok(views.html.massivedecks.index(protocol + "://" + request.host + "/"))
  }

  def createLobby() = Action {
    wrap(Json.toJson(store.newLobby().lobby))
  }

  def notifications(gameCode: String) = WebSocket.using[String] { requestHeader =>
    store.getLobby(gameCode).register()
  }

  def getLobby(gameCode: String) = Action {
    wrap(Json.toJson(store.getLobby(gameCode).lobby))
  }

  def command(gameCode: String) = Action(parse.json) { request: Request[JsValue] =>
    wrap {
      val secret = (request.body \ "secret").validate[Player.Secret].getOrElse(throw ForbiddenException.json("badly-formed-secret"))
      val lobby = store.getLobby(gameCode)
      extractCommandArgument((request.body \ "command").validate[String]) match {
        case "addDeck" => lobby.addDeck(secret, extractCommandArgument((request.body \ "playCode").validate[String]))
        case "newGame" => lobby.newGame(secret)
        case "play" => lobby.play(secret, extractCommandArgument((request.body \ "ids").validate[List[String]]))
        case "choose" => lobby.choose(secret, extractCommandArgument((request.body \ "winner").validate[Int]))
        case "getLobbyAndHand" => lobby.getLobbyAndHand(secret)
        case "skip" => lobby.skip(secret, extractCommandArgument((request.body \ "players").validate[Set[Player.Id]]))
        case "back" => lobby.back(secret)
        case "enableRule" => lobby.enableRule(secret, extractCommandArgument((request.body \ "rule").validate[String]))
        case "disableRule" => lobby.disableRule(secret, extractCommandArgument((request.body \ "rule").validate[String]))
        case "redraw" => lobby.redraw(secret)
        case _ => throw BadRequestException.json("invalid-command")
      }
      Json.toJson(lobby.getLobbyAndHand(secret))
    }
  }

  def newPlayer(gameCode: String) = Action(parse.json) { request: Request[JsValue] =>
    val name = (request.body \ "name").validate[String].getOrElse(throw BadRequestException.json("invalid-name"))
    wrap(Json.toJson(store.getLobby(gameCode).newPlayer(name)))
  }

  def getPlayer(gameCode: String, playerId: Int) = Action(parse.json) { request: Request[JsValue] =>
    wrap {
      val secret = extractSecret(request)
      Json.toJson(store.getLobby(gameCode).getHand(secret))
    }
  }

  def getHistory(gameCode: String) = Action { request =>
    wrap {
      Json.toJson(store.getLobby(gameCode).getHistory())
    }
  }

  def newAi(gameCode: String) = Action(parse.json) { request: Request[JsValue] =>
    wrap({
      val secret = extractSecret(request)
      store.getLobby(gameCode).newAi(secret)
      Json.toJson("")
    })
  }

  def leave(gameCode: String, playerId: Int) = Action(parse.json) { request: Request[JsValue] =>
    wrap({
      val secret = extractSecret(request)
      store.getLobby(gameCode).leave(secret)
      Json.toJson("")
    })
  }

  private def extractSecret(request: Request[JsValue]) =
    request.body.validate[Player.Secret].getOrElse(throw ForbiddenException.json("badly-formed-secret"))

  private def extractCommandArgument[T](value: JsResult[T]) =
    value.getOrElse(throw BadRequestException.json("invalid-command"))

  private def wrap(attempt: => JsValue) = {
    (Try(attempt) match {
      case Success(result) =>
        Ok(result)

      case Failure(error) =>
        error match {
          case BadRequestException(msg) =>
            BadRequest(msg)
          case NotFoundException(msg) =>
            NotFound(msg)
          case RequestFailedException(msg) =>
            BadGateway(msg)
          case ForbiddenException(msg) =>
            Forbidden(msg)
          case _ =>
            throw error
        }
    }).as(JSON)
  }

}
