import sbt.*

object Dependencies {
  private val keycloakVersion = "16.1.1"

  lazy val keycloakCore = "org.keycloak" % "keycloak-core" % keycloakVersion
  lazy val keycloakAdminClient = "org.keycloak" % "keycloak-admin-client" % keycloakVersion
  lazy val typesafe = "com.typesafe" % "config" % "1.4.2"
}
