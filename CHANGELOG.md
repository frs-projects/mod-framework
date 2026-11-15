# Changelog

All notable changes to the FRS mod framework. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Mods pin a framework commit, so entries
are by date.

## [Unreleased]

### Added
- CurseMaven repository (exclusive to the `curse.maven` group): CurseForge files resolve as
  `curse.maven:<slug>-<projectId>:<fileId>`, so mods can depend on jars that may not be
  redistributed without keeping them in `libs/`.
- `template/.gitattributes`: LF for every text file, CRLF only for `.bat`, binary jars and PNGs.
  Mods made on Windows committed `gradlew` with CRLF, which breaks `./gradlew` on Linux and in CI
  ("/bin/sh^M: bad interpreter"); propbrush and battlegroundsmenu both had this.
- `template/CHANGELOG.md`: every mod keeps a changelog.
- README: third-party jars that may not be redistributed (e.g. All Rights Reserved) are never
  committed, not even to a private repository; gitignore them and document where to get them.

## 2026-11-06

### Added
- `bump.bat`, the Windows version of `bump.sh`.

## 2026-11-03

### Added
- The framework: convention plugins (`frs.controller`, `frs.core`, `frs.forge`, `frs.neoforge`,
  `frs.fabric`), the reusable `mod-build.yml` workflow, the mod template, `bump.sh`, AGPL v3 license.
