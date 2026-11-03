// Convention for a mod's `:core` project: the pure-Java engine. No Minecraft, no mappings,
// no preprocessing, so it sits outside the Stonecutter tree and is compiled and tested
// exactly once. Every node folds its classes into the node jar (see frs.node).

plugins {
    `java-library`
}

group = "${rootProject.property("mod.group")}.core"
version = rootProject.property("mod.version") as String

repositories { mavenCentral() }

val coreJava = (rootProject.property("core.java") as String).toInt()

java {
    toolchain.languageVersion = JavaLanguageVersion.of(coreJava)
}

tasks.withType<JavaCompile>().configureEach {
    options.encoding = "UTF-8"
    // The lowest Java in the matrix (1.20.1 runs on 17), so :core must stay at that level.
    options.release = coreJava
}

dependencies {
    // Gson is on every loader's runtime classpath (Minecraft ships it), so it is compile-only:
    // no shading, no jar-size cost. Pinned to 2.10, what Minecraft 1.20.1 ships: compiling
    // against anything newer lets in methods (e.g. JsonObject.isEmpty, 2.10.1) that fail at runtime.
    "compileOnly"("com.google.code.gson:gson:2.10")
    "compileOnly"("org.jetbrains:annotations:26.0.2")

    "testImplementation"("com.google.code.gson:gson:2.10")
    "testImplementation"(platform("org.junit:junit-bom:5.11.4"))
    "testImplementation"("org.junit.jupiter:junit-jupiter")
    "testRuntimeOnly"("org.junit.platform:junit-platform-launcher")
}

tasks.named<Test>("test") {
    useJUnitPlatform()
    testLogging { events("passed", "skipped", "failed") }
}
