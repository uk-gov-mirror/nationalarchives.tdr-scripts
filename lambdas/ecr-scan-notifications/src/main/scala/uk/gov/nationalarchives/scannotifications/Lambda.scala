package uk.gov.nationalarchives.scannotifications

import java.io.{InputStream, OutputStream}

import cats.effect._
import io.circe.parser.decode
import sttp.client.asynchttpclient.cats.AsyncHttpClientCatsBackend
import uk.gov.nationalarchives.aws.utils.SESUtils
import uk.gov.nationalarchives.aws.utils.Clients._
import uk.gov.nationalarchives.scannotifications.ScanResultDecoder._

import scala.io.Source

class Lambda {
  implicit val cs: ContextShift[IO] = IO.contextShift(scala.concurrent.ExecutionContext.global)

  def process(input: InputStream, output: OutputStream): String = {
    AsyncHttpClientCatsBackend[IO]().flatMap { implicit backend =>
      for {
        scanEvent <- IO.fromEither(decode[ScanEvent](Source.fromInputStream(input).mkString))
        utils <- MessageUtils(scanEvent)
        _ <- IO.fromTry(SESUtils(ses).sendEmail(utils.emailMessage))
        response <- utils.slackRequest.send
        _ <- IO.fromEither(response.body.left.map(e => new RuntimeException(e)))
      } yield s"Scan for ${scanEvent.detail.repositoryName} sent"
    }.unsafeRunSync()
  }
}

