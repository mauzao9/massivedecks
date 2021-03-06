package controllers.massivedecks.lobby

import java.util.UUID

import scala.util.Random

import models.massivedecks.Game.{Call, Response}
import controllers.massivedecks.cardcast.CardcastDeck

/**
  * A live deck of cards in a game, constructed from a collection of cardcast decks.
  *
  * @param decks The cardcast decks.
  */
case class Deck(decks: List[CardcastDeck]) {
  var calls: List[Call] = List()
  var responses: List[Response] = List()
  resetCalls()
  resetResponses()

  if (calls.length < 1) {
    throw new IllegalStateException("The lobby must have at least one call in it.")
  }

  if (responses.length < 1) {
    throw new IllegalStateException("The lobby must have at least one response in it.")
  }

  def drawCall(): Call = {
    if (calls.isEmpty) {
      resetCalls()
    }
    val drawn = calls.head
    calls = calls.tail
    drawn
  }

  def drawResponses(count: Int): List[Response] = {
    if (responses.length < count) {
      val partial = responses.take(count)
      resetResponses()
      partial ++ drawResponses(count - partial.length)
    } else {
      val drawn = responses.take(count)
      responses = responses.drop(count)
      drawn
    }
  }

  def resetCalls(): Unit = {
    calls = (for (deck <- decks) yield deck.calls).flatten.map(call => call.copy(id = UUID.randomUUID().toString))
    shuffleCalls()
  }
  def resetResponses(): Unit = {
    responses = (for (deck <- decks) yield deck.responses).flatten.map(call => call.copy(id = UUID.randomUUID().toString))
    shuffleResponses()
  }

  def shuffle(): Unit = {
    shuffleCalls()
    shuffleResponses()
  }
  def shuffleCalls(): Unit = calls = Random.shuffle(calls)
  def shuffleResponses(): Unit = responses = Random.shuffle(responses)
}
