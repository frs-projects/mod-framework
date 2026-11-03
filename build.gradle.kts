plugins {
    `kotlin-dsl`
}

dependencies {
    // The loader plugins (frs.fabric / frs.neoforge / frs.forge) configure Loom directly, so the
    // framework pins the Loom version for every mod. Mods must not declare Loom themselves:
    // a second copy on the classpath would split Loom across classloaders.
    implementation("dev.architectury:architectury-loom:1.17.491")
}
