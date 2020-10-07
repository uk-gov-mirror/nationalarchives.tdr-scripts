import Dependencies._

ThisBuild / scalaVersion     := "2.13.3"
ThisBuild / version          := "0.1.0-SNAPSHOT"
ThisBuild / organization     := "com.example"
ThisBuild / organizationName := "example"

lazy val root = (project in file("."))
  .settings(
    name := "ecr-scan-notifications",
    libraryDependencies ++= Seq(
      circeCore,
      circeGeneric,
      circeParser,
      sttpCatsEffect,
      awsUtils,
      typesafe,
      scalaTags,
      scalaTest % Test,
      wiremock % Test
    )
  )

fork in Test := true
javaOptions in Test += s"-Dconfig.file=${sourceDirectory.value}/test/resources/application.conf"

resolvers += "TDR Releases" at "s3://tdr-releases-mgmt"
assemblyJarName in assembly := "scan-notifications.jar"

assemblyMergeStrategy in assembly := {
  case PathList("META-INF", xs@_*) => MergeStrategy.discard
  case _ => MergeStrategy.first
}

