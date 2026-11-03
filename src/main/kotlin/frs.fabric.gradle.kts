import frs.applyLoomNode

// A Fabric node (e.g. 1.21.1-fabric). The node's gradle.properties must set
// loom.platform=fabric, deps.minecraft, deps.fabric_loader, deps.fabric_api and
// deps.minecraft.range.fabric. Mixin configs are declared in fabric.mod.json.

// No refmap: Loom 1.17 no longer runs the mixin AP on Fabric and remaps mixins in remapJar.
applyLoomNode()

dependencies {
    "modImplementation"("net.fabricmc:fabric-loader:${property("deps.fabric_loader")}")
    "modImplementation"("net.fabricmc.fabric-api:fabric-api:${property("deps.fabric_api")}")
}
