// Applied in a mod's stonecutter.gradle.kts, next to Stonecutter itself. Adds the
// cross-node aggregate tasks; the Stonecutter parameters (constants, swaps) stay in the
// mod's controller script because they need the Stonecutter API.
//
// Applying this plugin at the root also puts the framework (and with it Loom) on the root
// classpath, so every node shares one Loom classloader.

val modId = property("mod.id") as String

// Every Stonecutter node is a subproject named <mc>-<loader>; :core is the only other one.
val nodes = subprojects.filter { it.path != ":core" }

tasks.register("buildAll") {
    group = modId
    description = "Builds every Minecraft version x loader node in the matrix."
    dependsOn(nodes.map { "${it.path}:build" })
}

tasks.register("checkAll") {
    group = modId
    description = "Runs :core's tests and every node's checks, including mod metadata verification."
    dependsOn(":core:check")
    dependsOn(nodes.map { "${it.path}:check" })
}

// One place to find every jar the matrix produced.
tasks.register<Copy>("collectJars") {
    group = modId
    description = "Copies every node's remapped jar into the root build/libs."
    into(layout.buildDirectory.dir("libs"))
    nodes.forEach { node ->
        from(node.layout.buildDirectory.dir("libs")) {
            include("*.jar")
            exclude("*-sources.jar", "*-dev.jar", "*-dev-shadow.jar")
        }
    }
    dependsOn(nodes.map { "${it.path}:build" })
}
