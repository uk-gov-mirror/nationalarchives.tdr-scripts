package uk.gov.nationalarchives.scannotifications

import com.github.tomakehurst.wiremock.WireMockServer
import com.github.tomakehurst.wiremock.client.WireMock.{ok, post, urlEqualTo}
import org.scalatest.{BeforeAndAfterAll, BeforeAndAfterEach}
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers
import org.scalatest.prop.TableDrivenPropertyChecks
import uk.gov.nationalarchives.scannotifications.ScanResultDecoder.{ScanDetail, ScanEvent, ScanFindingCounts}

class LambdaSpecUtils extends AnyFlatSpec with Matchers with BeforeAndAfterAll with BeforeAndAfterEach with TableDrivenPropertyChecks {

  def getCounts(scanEvent: ScanEvent): (Int, Int, Int, Int) = {
    val critical = scanEvent.detail.findingSeverityCounts.critical.getOrElse(0)
    val high = scanEvent.detail.findingSeverityCounts.high.getOrElse(0)
    val medium = scanEvent.detail.findingSeverityCounts.medium.getOrElse(0)
    val low = scanEvent.detail.findingSeverityCounts.low.getOrElse(0)
    (critical, high, medium, low)
  }

  val scanEvents =
    Table(
      "scanEvent",
      ScanEvent(ScanDetail("", ScanFindingCounts(Some(10), Some(100), Some(1000), Some(10000)))),
      ScanEvent(ScanDetail("", ScanFindingCounts(Option.empty, Some(0), Option.empty, Some(10)))),
      ScanEvent(ScanDetail("", ScanFindingCounts(Option.empty,Option.empty,Option.empty,Option.empty)))
    )

  val wiremockSesEndpoint = new WireMockServer(9001)


  val wiremockSlackServer = new WireMockServer(9002)

  override def beforeEach(): Unit = {
    wiremockSlackServer.stubFor(post(urlEqualTo("/webhook")).willReturn(ok("")))
    wiremockSesEndpoint.stubFor(post(urlEqualTo("/"))
      .willReturn(ok(
        """
          |<SendEmailResponse xmlns="https://email.amazonaws.com/doc/2010-03-31/">
          |  <SendEmailResult>
          |    <MessageId>000001271b15238a-fd3ae762-2563-11df-8cd4-6d4e828a9ae8-000000</MessageId>
          |  </SendEmailResult>
          |  <ResponseMetadata>
          |    <RequestId>fd3ae762-2563-11df-8cd4-6d4e828a9ae8</RequestId>
          |  </ResponseMetadata>
          |</SendEmailResponse>
          |""".stripMargin)))
  }

  override def afterEach(): Unit = {
    wiremockSlackServer.resetAll()
    wiremockSesEndpoint.resetAll()
  }

  override def beforeAll(): Unit = {
    wiremockSlackServer.start()
    wiremockSesEndpoint.start()
  }

  override def afterAll(): Unit = {
    wiremockSlackServer.stop()
    wiremockSesEndpoint.stop()
  }


}
