import frs.applyLoomNode
import frs.mixinConfigs

// A Forge node (e.g. 1.20.1-forge). The node's gradle.properties must set loom.platform=forge,
// deps.minecraft, deps.forge, deps.forge.range and deps.minecraft.range.forgelike.

val loom = applyLoomNode()

// Forge 47 reads mixin configs from the jar manifest, not from mods.toml; Loom writes the
// MixinConfigs attribute and passes the configs to the dev runs.
mixinConfigs().forEach { loom.forge.mixinConfig(it) }

// Forge's AT has to be registered with Loom so the dev jar is transformed as well; Forge
// itself only reads it from META-INF in the shipped jar. Written in SRG names on 1.20.1.
rootProject.file("src/main/resources/META-INF/accesstransformer.cfg")
    .takeIf { it.isFile }
    ?.let { loom.forge.accessTransformer(it) }

dependencies {
    "forge"("net.minecraftforge:forge:${property("deps.forge")}")
}
