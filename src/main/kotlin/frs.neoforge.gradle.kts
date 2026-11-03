import frs.applyLoomNode

// A NeoForge node (e.g. 1.21.1-neoforge). The node's gradle.properties must set
// loom.platform=neoforge, deps.minecraft, deps.neoforge, deps.neoforge.range,
// deps.javafml.range and deps.minecraft.range.forgelike.
// Mixin configs are declared in neoforge.mods.toml ([[mixins]]), not here.

applyLoomNode()

dependencies {
    "neoForge"("net.neoforged:neoforge:${property("deps.neoforge")}")
}
