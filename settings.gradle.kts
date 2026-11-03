// The FRS-Projects mod framework: an included build that every mod pulls in as the
// `framework/` git submodule (see README.md). It only provides Gradle convention plugins;
// nothing in here ends up in a mod jar.

dependencyResolutionManagement {
    repositories {
        mavenCentral()
        gradlePluginPortal()
        // Architectury Loom itself, plus what it resolves while being compiled against.
        maven("https://maven.architectury.dev/") { name = "Architectury" }
        maven("https://maven.fabricmc.net/") { name = "Fabric" }
        maven("https://maven.neoforged.net/releases/") { name = "NeoForged" }
        maven("https://maven.minecraftforge.net/") { name = "MinecraftForge" }
    }
}

rootProject.name = "mod-framework"
