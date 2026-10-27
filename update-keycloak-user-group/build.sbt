import Dependencies.*
ThisBuild / version := "0.1.0-SNAPSHOT"

ThisBuild / scalaVersion := "2.13.9"

lazy val root = (project in file("."))
  .settings(
    name := "update-keycloak-user-group",
    libraryDependencies ++= Seq(
      keycloakCore,
      keycloakAdminClient,
      typesafe
    )
  )
