#!/usr/bin/env bash
# Bumps mod.version, commits, tags v<version> and pushes both, which starts the release build.
#
# Run from anywhere inside a mod that has this framework as its framework/ submodule:
#
#   framework/bump.sh            # patch: 1.2.3 -> 1.2.4
#   framework/bump.sh minor      # 1.2.3 -> 1.3.0
#   framework/bump.sh major      # 1.2.3 -> 2.0.0
#   framework/bump.sh 1.5.0      # an explicit version
#
# Options:
#   --no-check   skip ./gradlew checkAll before tagging
#   -y, --yes    do not ask for confirmation
set -euo pipefail

die() { echo "bump: $*" >&2; exit 1; }

part=patch check=1 yes=0
for arg in "$@"; do
    case "$arg" in
        major|minor|patch) part=$arg ;;
        [0-9]*.[0-9]*.[0-9]*) part=$arg ;;
        --no-check) check=0 ;;
        -y|--yes) yes=1 ;;
        -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown argument '$arg' (see --help)" ;;
    esac
done

# The mod is the repository this framework is checked out in.
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
mod_dir=$(git -C "$script_dir" rev-parse --show-superproject-working-tree)
[ -n "$mod_dir" ] || die "run this as framework/bump.sh inside a mod, not in mod-framework itself"
cd "$mod_dir"
[ -f gradle.properties ] || die "no gradle.properties in $mod_dir"

current=$(sed -n 's/^mod\.version=//p' gradle.properties)
[[ "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || die "mod.version '$current' is not MAJOR.MINOR.PATCH"
major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}
case "$part" in
    major) next="$((major + 1)).0.0" ;;
    minor) next="$major.$((minor + 1)).0" ;;
    patch) next="$major.$minor.$((patch + 1))" ;;
    *) next=$part ;;
esac
[[ "$next" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "'$next' is not MAJOR.MINOR.PATCH"
[ "$next" != "$current" ] || die "mod.version is already $current"
tag="v$next"

# Refuse anything that would tag something other than what is on the remote branch.
branch=$(git symbolic-ref --short HEAD 2>/dev/null) || die "not on a branch"
[ -z "$(git status --porcelain)" ] || die "the working tree has uncommitted changes"
git fetch -q origin "$branch" --tags
[ "$(git rev-list --count "HEAD..origin/$branch")" = 0 ] || die "origin/$branch has commits you do not have; pull first"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "tag $tag already exists"
# CI checks the framework out from GitHub, so the commit the mod points at must be pushed.
git -C framework fetch -q origin
git -C framework merge-base --is-ancestor HEAD origin/main \
    || die "framework/ points at a commit that is not on mod-framework's origin/main; push mod-framework first"

name=$(sed -n 's/^mod\.name=//p' gradle.properties)
echo "$name: $current -> $next (commit on $branch, tag $tag, push to origin)"
if [ "$yes" = 0 ]; then
    read -r -p "Continue? [y/N] " answer
    [[ "$answer" =~ ^[yY]$ ]] || die "aborted"
fi

awk -v v="$next" '/^mod\.version=/ { print "mod.version=" v; next } { print }' gradle.properties > gradle.properties.tmp
mv gradle.properties.tmp gradle.properties

if [ "$check" = 1 ]; then
    ./gradlew checkAll || { git checkout -- gradle.properties; die "checkAll failed; mod.version left at $current"; }
fi

git commit -q -m "Release $tag" gradle.properties
git tag -a "$tag" -m "$name $next"
# Atomic, so the tag never reaches GitHub without the commit it points at.
git push -q --atomic origin "$branch" "$tag"
echo "Pushed $tag. The release build runs at: $(git remote get-url origin | sed -E 's#^[^:]+:#https://github.com/#; s#\.git$##')/actions"
