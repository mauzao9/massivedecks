name := "massivedecks"

version := "1.0-SNAPSHOT"

lazy val root = (project in file(".")).enablePlugins(PlayScala)

scalaVersion := "2.11.8"

libraryDependencies ++= Seq(
  cache,
  ws
)

resolvers += "scalaz-bintray" at "http://dl.bintray.com/scalaz/releases"

resolvers += "dl-john-ky" at "http://dl.john-ky.io/maven/releases"

libraryDependencies += "io.john-ky" %% "hashids-scala" % "1.1.1-7d841a8"

includeFilter in (Assets, LessKeys.less) := "massivedecks.less"

// Play provides two styles of routers, one expects its actions to be injected, the
// other, legacy style, accesses its actions statically.
routesGenerator := InjectedRoutesGenerator

fork in run := true
