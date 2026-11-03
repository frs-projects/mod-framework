package frs

import net.fabricmc.loom.api.LoomGradleExtensionAPI
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.dependencies
import org.gradle.kotlin.dsl.the

/**
 * The part of every loader plugin that is the same on Fabric, NeoForge and Forge: Loom,
 * the node conventions, Minecraft + mappings and the dev run directories.
 *
 * Loom is applied imperatively rather than in a `plugins {}` block, so the framework does
 * not have to generate Kotlin accessors for it (which would apply Loom to a dummy project
 * at framework compile time).
 */
fun Project.applyLoomNode(): LoomGradleExtensionAPI {
    apply(plugin = "dev.architectury.loom")
    // After Loom, so frs.node's verifyModMetadata finds remapJar.
    apply(plugin = "frs.node")

    val loom = the<LoomGradleExtensionAPI>()
    loom.silentMojangMappingsLicense()

    dependencies {
        "minecraft"("com.mojang:minecraft:${property("deps.minecraft")}")
        // Minecraft ships unobfuscated from the 26.x line on, so Mojang no longer
        // publishes mapping files and there is nothing to remap against.
        if (findProperty("deps.mappings") == "unobfuscated") {
            "mappings"(loom.layered { })
        } else {
            "mappings"(loom.officialMojangMappings())
        }
    }

    // Deprecated in Architectury Loom 1.17 without a replacement in its public API yet.
    @Suppress("DEPRECATION")
    loom.runs.named("client") { runDir("run/client") }
    @Suppress("DEPRECATION")
    loom.runs.named("server") { runDir("run/server") }
    return loom
}

/** `mod.mixins` from the mod's gradle.properties: comma-separated mixin config file names. */
fun Project.mixinConfigs(): List<String> =
    (findProperty("mod.mixins") as String?)
        ?.split(',')
        ?.map { it.trim() }
        ?.filter { it.isNotEmpty() }
        .orEmpty()

/**
 * Names the mixin refmap `<mod.id>.refmap.json` on the loaders whose production runtime is
 * obfuscated (Fabric: intermediary, Forge 1.20.1: SRG), where the mixin AP has to run. A mixin
 * config can then name its refmap and be right on every node; Loom also writes it into each
 * config. NeoForge runs on Mojang names and has no mixin AP, so it is not called there.
 */
fun Project.useModRefmap(loom: LoomGradleExtensionAPI) {
    loom.mixin.defaultRefmapName.set("${rootProject.property("mod.id")}.refmap.json")
}
