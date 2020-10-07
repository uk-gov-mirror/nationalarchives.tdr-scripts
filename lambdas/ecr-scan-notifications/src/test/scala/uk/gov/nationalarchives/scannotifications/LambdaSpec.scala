package uk.gov.nationalarchives.scannotifications

import java.nio.charset.StandardCharsets
import java.util.Base64

import com.github.tomakehurst.wiremock.client.WireMock._
import uk.gov.nationalarchives.scannotifications.ScanResultDecoder.{ScanDetail, ScanEvent, ScanFindingCounts}

class LambdaSpec extends LambdaSpecUtils {

  forAll(scanEvents) {
    scanEvent => {
      "the process method" should s"send an email message for event $scanEvent" in {
        val expectedBody = Base64.getEncoder.encodeToString(body(scanEvent).getBytes(StandardCharsets.UTF_8))
        val stream = new java.io.ByteArrayInputStream(inputText(scanEvent).getBytes(java.nio.charset.StandardCharsets.UTF_8.name))
        new Lambda().process(stream, null)
        val b = wiremockSesEndpoint.getAllServeEvents
        wiremockSesEndpoint.verify(
          postRequestedFor(urlEqualTo("/"))
            .withRequestBody(binaryEqualTo(expectedBody))
        )
      }

      "the process method" should s"send a slack message for event $scanEvent" in {
        val expectedBody = bodyJson(scanEvent)
        val stream = new java.io.ByteArrayInputStream(inputText(scanEvent).getBytes(java.nio.charset.StandardCharsets.UTF_8.name))
        new Lambda().process(stream, null)
        wiremockSlackServer.verify(
          postRequestedFor(urlEqualTo("/webhook"))
            .withRequestBody(equalToJson(expectedBody))
        )
      }
    }
  }

  "the process method" should "error if the ses service is unavailable" in {
    val scanEvent = ScanEvent(ScanDetail("", ScanFindingCounts(Some(10), Some(100), Some(1000), Some(10000))))
    val stream = new java.io.ByteArrayInputStream(inputText(scanEvent).getBytes(java.nio.charset.StandardCharsets.UTF_8.name))
    wiremockSesEndpoint.resetAll()
    val exception = intercept[Exception] {
      new Lambda().process(stream, null)
    }
    exception.getMessage should be("null (Service: Ses, Status Code: 404, Request ID: null, Extended Request ID: null)")
  }

  "the process method" should "error if the slack service is unavailable" in {
    val scanEvent = ScanEvent(ScanDetail("", ScanFindingCounts(Some(10), Some(100), Some(1000), Some(10000))))
    val stream = new java.io.ByteArrayInputStream(inputText(scanEvent).getBytes(java.nio.charset.StandardCharsets.UTF_8.name))
    wiremockSlackServer.resetAll()
    val exception = intercept[Exception] {
      new Lambda().process(stream, null)
    }
    exception.getMessage should be("No response could be served as there are no stub mappings in this WireMock instance.")
  }

  def body(scanEvent: ScanEvent) = {
    val (critical, high, medium, low) = getCounts(scanEvent)
    "Action=SendEmail&Version=2010-12-01&Source=scanresults%40tdr-management.nationalarchives.gov.uk" +
      "&Destination.ToAddresses.member.1=aws_tdr_management%40nationalarchives.gov.uk" +
      "&Message.Subject.Data=ECR+scan+results+for+yara-dependencies&Message.Subject.Charset=UTF-8" +
      "&Message.Body.Html.Data=%3Chtml%3E%3Cbody%3E%3Ch1%3EImage+scan+results+for+yara-dependencies%3C%2Fh1%3E%3Cdiv%3E%3Cp%3E" +
      s"$critical+critical+vulnerabilities%3C%2Fp%3E%3Cp%3E" +
      s"$high+high+vulnerabilities%3C%2Fp%3E%3Cp%3E" +
      s"$medium+medium+vulnerabilities%3C%2Fp%3E%3Cp%3E" +
      s"$low+low+vulnerabilities%3C%2Fp%3E%3C%2Fdiv%3E%3C%2Fbody%3E%3C%2Fhtml%3E" +
      "&Message.Body.Html.Charset=UTF-8"
  }

  def bodyJson(scanEvent: ScanEvent): String = {
    val (critical, high, medium, low) = getCounts(scanEvent)
    s"""
        |{
        |  "blocks" : [ {
        |    "type" : "section",
        |    "text" : {
        |      "type" : "mrkdwn",
        |      "text" : "*ECR image scan complete on image yara-dependencies*"
        |    }
        |  }, {
        |    "type" : "section",
        |    "text" : {
        |      "type" : "mrkdwn",
        |      "text" : "$critical critical severity vulnerabilities"
        |    }
        |  }, {
        |    "type" : "section",
        |    "text" : {
        |      "type" : "mrkdwn",
        |      "text" : "$high high severity vulnerabilities"
        |    }
        |  }, {
        |    "type" : "section",
        |    "text" : {
        |      "type" : "mrkdwn",
        |      "text" : "$medium medium severity vulnerabilities"
        |    }
        |  }, {
        |    "type" : "section",
        |    "text" : {
        |      "type" : "mrkdwn",
        |      "text" : "$low low severity vulnerabilities"
        |    }
        |  } ]
        |}
        |""".stripMargin
  }

  def inputText(scanEvent: ScanEvent): String = {
    val (critical, high, medium, low) = getCounts(scanEvent)
    s"""
      |{
      |  "detail": {
      |    "scan-status": "COMPLETE",
      |    "repository-name": "yara-dependencies",
      |    "finding-severity-counts": {
      |      "CRITICAL": $critical,
      |      "HIGH": $high,
      |      "MEDIUM": $medium,
      |      "LOW": $low
      |    }
      |  }
      |}
      |""".stripMargin
  }
}
