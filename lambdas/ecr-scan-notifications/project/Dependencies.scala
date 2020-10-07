import sbt._

object Dependencies {
  lazy val circeCore = "io.circe" %% "circe-core" % "0.13.0"
  lazy val circeGeneric = "io.circe" %% "circe-generic" % "0.13.0"
  lazy val circeParser = "io.circe" %% "circe-parser" % "0.13.0"
  lazy val sttpCatsEffect = "com.softwaremill.sttp.client" %% "async-http-client-backend-cats" % "2.2.9"
  lazy val typesafe = "com.typesafe" % "config" % "1.4.0"
  lazy val scalaTags = "com.lihaoyi" %% "scalatags" % "0.8.2"
  lazy val awsUtils =  "uk.gov.nationalarchives.aws.utils" %% "tdr-aws-utils" % "0.1.4"
  lazy val scalaTest = "org.scalatest" %% "scalatest" % "3.2.2"
  lazy val wiremock = "com.github.tomakehurst" % "wiremock" % "2.27.2"

}
