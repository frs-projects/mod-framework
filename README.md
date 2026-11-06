# FRS-Projects mod framework

The build framework every FRS-Projects Minecraft mod is built on: one source tree, many
Minecraft version × loader jars, a pure-Java engine that is tested without Minecraft, and
tag-driven releases.

It is a Gradle **included build** that each mod checks out as the `framework/` git submodule.
It ships only Gradle convention plugins and a reusable GitHub workflow; nothing in here ends
up in a mod jar.

| Piece | Version |
|---|---|
| Gradle | 9.7 (each mod's wrapper), daemon on Java 25 |
| Stonecutter | 0.9.8 (each mod's `settings.gradle.kts`) |
| Architectury Loom | 1.17.491 (pinned here, in `build.gradle.kts`) |
| `:core` Java level | 17 (`core.java`) |

## What the framework provides

| Plugin | Applied in | Does |
|---|---|---|
| `frs.controller` | `stonecutter.gradle.kts` | `buildAll`, `checkAll`, `collectJars`; puts Loom on the root classpath so all nodes share one Loom |
| `frs.core` | `core/build.gradle.kts` | Plain `java-library` at `core.java`, Gson 2.10 + annotations `compileOnly`, JUnit 5 |
| `frs.forge` | `build.forge.gradle.kts` | Loom + node conventions + Forge; mixin configs from `mod.mixins`; registers `META-INF/accesstransformer.cfg` if present |
| `frs.neoforge` | `build.neoforge.gradle.kts` | Loom + node conventions + NeoForge |
| `frs.fabric` | `build.fabric.gradle.kts` | Loom + node conventions + Fabric Loader + Fabric API |
| `frs.node` | (by the loader plugins) | Versioning, toolchain, repositories, `:core` folding (if present), metadata templating, `verifyModMetadata` |

`.github/workflows/mod-build.yml` is the reusable CI: `:core:test` once, every node built and
checked in parallel, and on a `v*` tag a GitHub Release carrying every node's jar.

## Repository layout of a mod

```
<mod>/
├── framework/                      # this repository, as a git submodule
├── settings.gradle.kts             # includeBuild("framework"), Stonecutter matrix, include("core")
├── stonecutter.gradle.kts          # Stonecutter + frs.controller, constants and swaps
├── build.<loader>.gradle.kts       # one per loader in the matrix: frs.<loader> + mod-specific deps
├── gradle.properties               # mod identity (mod.*), core.java, Gradle settings
├── .sc_active_version              # the node the IDE / plain src/ currently represent
├── versions/<mc>-<loader>/gradle.properties   # per-node dependency versions
├── core/                           # pure-Java engine + its JUnit tests
│   ├── build.gradle.kts            # plugins { id("frs.core") }
│   └── src/{main,test}/java/
├── src/main/java/                  # Minecraft-facing code, all nodes, Stonecutter comments
├── src/main/resources/             # metadata templates, mixin configs, assets
├── libs/                           # third-party jars that are on no maven (optional)
├── .github/workflows/build.yml     # calls mod-build.yml
├── gradle/ , gradlew , gradlew.bat # Gradle 9.7 wrapper; gradle-daemon-jvm.properties pins Java 25
└── README.md
```

`template/` holds a copy of every file a mod owns, with `examplemod` as the placeholder.

## Rules

### Nodes

- A node is `<minecraft>-<loader>`, e.g. `1.20.1-forge`, `1.21.1-neoforge`, `1.21.1-fabric`.
  The loader suffix selects the build script (`build.<loader>.gradle.kts`) and the
  Stonecutter constant (`//? if forge {`).
- Adding a target is one `match(...)` line in `settings.gradle.kts`, a
  `versions/<node>/gradle.properties`, and the node in the workflow's `nodes` list.
- Jars are named `<mod.id>-<mod.version>+<node>.jar`.
- Per-loader entry points live in one file per loader, wrapped whole in `//? if <loader> {`,
  so only the active loader's file compiles.
- Loader-gated files carry only `//` comments: Stonecutter comments an inactive file out with
  one block comment, which a Javadoc block inside would end early.
- Git holds the tree as the `vcsVersion` node; run `"Reset active project"` before committing.

### `:core`

- **Optional.** A mod without Minecraft-free logic leaves out `include("core")` and `core/`,
  and passes `core: false` to the workflow. Everything else works the same.
- **No Minecraft, no loader, no mod APIs.** Only the JDK, Gson (`compileOnly`, provided by
  Minecraft at runtime) and `org.jetbrains:annotations`.
- Holds everything that can be decided without the game: algorithms, config parsing and
  upgrades, formatting, protocol and data models. The Minecraft side adapts game objects to it
  (usually through a small interface or a few ints) and keeps the side effects.
- Compiled at `core.java` (17), once; every node folds its classes into the jar.
- Has JUnit 5 tests; `checkAll` and CI run them.
- Package `<mod.group>.core`.

### Mod identity: root `gradle.properties`

| Key | Example | |
|---|---|---|
| `mod.id` | `modsync` | Mod id and jar prefix |
| `mod.name` | `ModSync` | Display name |
| `mod.group` | `net.frsprojects.modsync` | Maven group and root Java package |
| `mod.version` | `0.1.6` | Release tags must be `v<mod.version>` |
| `mod.license` | `All Rights Reserved` | |
| `mod.description` | | |
| `mod.authors` | `FRS-Projects` | |
| `mod.source` | `https://github.com/frs-projects/<repo>` | Also yields the issue tracker URL |
| `mod.mixins` | `modsync.mixins.json` | Optional, comma-separated; Forge needs them in the manifest |
| `core.java` | `17` | The lowest Java in the matrix |

### Per-node `versions/<node>/gradle.properties`

| Key | Nodes | |
|---|---|---|
| `loom.platform` | all | `forge`, `neoforge` or `fabric` (read by Loom) |
| `java.version` | all | 17 for 1.20.1, 21 for 1.21.x, 25 for 26.x |
| `deps.minecraft` | all | |
| `deps.pack_format` | all | |
| `deps.mappings` | all | `mojang`, or `unobfuscated` for 26.x |
| `deps.minecraft.range.forgelike` | forge, neoforge | e.g. `[1.21.1,1.22)` |
| `deps.forge`, `deps.forge.range` | forge | e.g. `1.20.1-47.4.0`, `[47,)` |
| `deps.neoforge`, `deps.neoforge.range`, `deps.javafml.range` | neoforge | `javafml` is the language provider, **not** the NeoForge version (21.1 → `[4,)`) |
| `deps.minecraft.range.fabric`, `deps.fabric_loader`, `deps.fabric_api` | fabric | |

### Metadata tokens

`fabric.mod.json`, `META-INF/mods.toml`, `META-INF/neoforge.mods.toml` and `pack.mcmeta` are
templates. Only the active node's loader file is expanded and shipped; `verifyModMetadata`
fails the build if it or `pack.mcmeta` is missing from the jar.

Every `mod.*` and `deps.*` property, from the root or the node's `gradle.properties`, is a
token: the prefix is dropped and dots become underscores. `mod.version` is `${version}`,
`deps.minecraft.range.forgelike` is `${minecraft_range_forgelike}`, and a mod-specific
`deps.rinku.range` is `${rinku_range}`, with no framework change. `${java}` is the node's
`java.version`.

These always exist, with defaults when the property is missing:
`${id}` `${name}` `${version}` `${group}` `${license}` `${description}` `${authors}` `${source}`
`${issues}` (default `${source}/issues`) `${update_json}` (default empty)
`${java}` `${minecraft}` `${pack_format}` `${minecraft_range_fabric}` `${minecraft_range_forgelike}`
`${fabric_loader}` `${fabric_api}` `${neoforge}` `${neoforge_range}` `${javafml_range}`
`${forge}` `${forge_range}`

### Mixins

- Mixin configs are named `<mod.id>[.<area>].mixins.json`.
- **No refmaps.** Loom 1.17 rewrites mixin targets to the production names in `remapJar` on
  every loader (e.g. `startConnecting` -> `m_278792_` on Forge 1.20.1), so no mixin AP runs
  and no refmap is produced. A mixin config must not name a `"refmap"`.
- Forge: list every config in `mod.mixins`. NeoForge: `[[mixins]]` in `neoforge.mods.toml`.
  Fabric: `"mixins"` in `fabric.mod.json`.

### Access transformers (Forge)

`src/main/resources/META-INF/accesstransformer.cfg`, in SRG names on 1.20.1. `frs.forge`
registers it with Loom so the dev environment is transformed too.

### Third-party jars

Mod jars that are on no maven go into `libs/` as `<artifact>-<version>.jar` and are declared
with the `blank` group, which the flat-dir repository resolves by file name:

```kotlin
dependencies {
    "modImplementation"("blank:curios-forge:5.14.1")      // libs/curios-forge-5.14.1.jar
    "modCompileOnly"("blank:crac-1.20.1:1.5")             // optional integration
}
```

Use the `mod*` configurations so Loom remaps them to the dev mappings. Prefer a real maven
(Modrinth maven is already configured: `maven.modrinth:<slug>:<version>`) when there is one.

### Versioning and releases

Releases are cut with `framework/bump.sh`, run from the mod:

```sh
framework/bump.sh            # patch: 1.2.3 -> 1.2.4
framework/bump.sh minor      # 1.2.3 -> 1.3.0
framework/bump.sh major      # 1.2.3 -> 2.0.0
framework/bump.sh 1.5.0      # an explicit version
```

On Windows use `framework\bump.bat` from cmd or PowerShell, with the same arguments and checks:

```bat
framework\bump.bat            # patch: 1.2.3 -> 1.2.4
framework\bump.bat minor      # 1.2.3 -> 1.3.0
framework\bump.bat 1.5.0 -y   # an explicit version, no confirmation
```

It bumps `mod.version`, runs `./gradlew checkAll` (`--no-check` skips it), commits
`Release v<version>`, tags `v<version>` and pushes the commit and tag together (`-y` skips the
confirmation). It refuses a dirty tree, a branch that is behind origin, an existing tag, and a
`framework/` commit that is not on mod-framework's `origin/main`, since CI could not check that
one out.

- Builds only run on tags (and by hand via *workflow_dispatch*).
- The release job refuses a tag that does not match `mod.version`, so a hand-made tag must
  match too.

## Tasks

| Task | |
|---|---|
| `./gradlew checkAll` | `:core` tests + every node's build and `verifyModMetadata` |
| `./gradlew buildAll` | Every node's jar |
| `./gradlew collectJars` | Every node's jar copied into `build/libs/` |
| `./gradlew :<node>:runClient` / `runServer` | Dev runs in `versions/<node>/run/` |
| `./gradlew "Set active project to <node>"` | Switch the node `src/` represents (Stonecutter) |
| `./gradlew "Reset active project"` | Back to `vcsVersion`; run before committing |

## Using the framework in a mod

New mod:

```sh
cp -r mod-framework/template/. <mod>/               # then replace examplemod everywhere
cp -r <existing-mod>/gradle <existing-mod>/gradlew* <mod>/   # Gradle 9.7 wrapper
cd <mod>
git submodule add https://github.com/frs-projects/mod-framework.git framework
```

Fresh clone of a mod: `git clone --recurse-submodules …`, or `git submodule update --init`
after a plain clone.

Picking up framework changes in a mod:

```sh
git -C framework pull origin main
./gradlew checkAll
git commit -am "Update framework" framework
```

Each mod pins the framework commit it was verified with, so a framework change never breaks
a mod until that mod pulls it in. The reusable workflow is referenced as `@main`; it only
orchestrates Gradle tasks, while the build logic itself comes from the pinned submodule.

### CI access

The mods' workflows check out `framework/` with `submodules: recursive`. If
`frs-projects/mod-framework` is private, the default `GITHUB_TOKEN` cannot read it: either
make it public (it holds only build logic) or add a `FRAMEWORK_TOKEN` secret (a fine-grained
token with read access to it) to the organisation. The reusable workflow itself also needs
*Settings → Actions → Access* on mod-framework set to allow repositories in the organisation.

## Known limits

- **26.x is blocked.** Minecraft ships unobfuscated from 26.x on and Mojang no longer publishes
  mapping files; Architectury Loom 1.17.491 still requires them. `deps.mappings=unobfuscated`
  is the seam for when Loom (or a move to Fabric Loom + ModDevGradle) supports it.
- **No NeoForge on 1.20.1.** NeoForge for 1.20.1 is effectively Forge 47; use `1.20.1-forge`.
