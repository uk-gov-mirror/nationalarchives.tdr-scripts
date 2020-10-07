package uk.gov.nationalarchives.scannotifications

import cats.effect.IO
import com.typesafe.config.{Config, ConfigFactory}
import uk.gov.nationalarchives.scannotifications.ScanResultDecoder.ScanEvent
import io.circe.generic.auto._
import io.circe.syntax._
import scalatags.Text.all._
import sttp.client._
import sttp.model.MediaType
import uk.gov.nationalarchives.aws.utils.SESUtils.Email
import uk.gov.nationalarchives.scannotifications.MessageUtils.{SlackBlock, SlackMessage, SlackText}

class MessageUtils(scanEvent: ScanEvent) {
  val config: Config = ConfigFactory.load

  private def slackBlock(text: String) = SlackBlock("section", SlackText("mrkdwn", text))

  private def countBlock(count: Option[Int], level: String) = slackBlock(s"${count.getOrElse(0)} $level severity vulnerabilities")


  def slackMessage: String = {
    val headerBlock = slackBlock(s"*ECR image scan complete on image ${scanEvent.detail.repositoryName}*")
    val severityCounts = scanEvent.detail.findingSeverityCounts
    val criticalBlock = countBlock(severityCounts.critical, "critical")
    val highBlock = countBlock(severityCounts.high, "high")
    val mediumBlock = countBlock(severityCounts.medium, "medium")
    val lowBlock = countBlock(severityCounts.low, "low")
    SlackMessage(List(headerBlock, criticalBlock, highBlock, mediumBlock, lowBlock))
      .asJson.noSpaces
  }

  def emailMessage: Email = {
    val critical = scanEvent.detail.findingSeverityCounts.critical.getOrElse(0)
    val high = scanEvent.detail.findingSeverityCounts.high.getOrElse(0)
    val medium = scanEvent.detail.findingSeverityCounts.medium.getOrElse(0)
    val low = scanEvent.detail.findingSeverityCounts.low.getOrElse(0)

    val message = html(
      body(
        h1(s"Image scan results for ${scanEvent.detail.repositoryName}"),
        div(
          p(s"$critical critical vulnerabilities"),
          p(s"$high high vulnerabilities"),
          p(s"$medium medium vulnerabilities"),
          p(s"$low low vulnerabilities")
        )
      )
    ).toString()
   Email("scanresults@tdr-management.nationalarchives.gov.uk", "aws_tdr_management@nationalarchives.gov.uk", s"ECR scan results for ${scanEvent.detail.repositoryName}", message)
  }

  def slackRequest: RequestT[Identity, Either[String, String], Nothing] = {
    basicRequest
      .post(uri"${config.getString("slack.webhook.url")}")
      .body(slackMessage)
      .contentType(MediaType.ApplicationJson)
  }
}

object MessageUtils {
  case class SlackText(`type`: String, text: String)
  case class SlackBlock(`type`: String, text: SlackText)
  case class SlackMessage(blocks: List[SlackBlock])

  def apply(scanEvent: ScanEvent): IO[MessageUtils] = IO(new MessageUtils(scanEvent))
}
