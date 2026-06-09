#!/usr/bin/env bash
#
# Devcontainer post-create: fetch BuildTools and build the latest Spigot so the
# Java extension can resolve the Bukkit API (org.bukkit.*) for the StopOnStart
# plugin. The produced jar — buildtools/Spigot/Spigot-API/target/spigot-api-*-
# shaded.jar — is what devcontainer.json's java.project.referencedLibraries
# points at. Slow (~10-20 min: git clones + decompile + compile), runs once per
# container creation, and is idempotent (skips if already built).
set -euo pipefail

cd "$(dirname "$0")/.."  # repo root

if ls buildtools/Spigot/Spigot-API/target/spigot-api-*-shaded.jar >/dev/null 2>&1; then
    echo "spigot-api already built — skipping BuildTools."
    exit 0
fi

# BuildTools clones/commits internally and needs a git identity + to trust the
# checkout dirs.
git config --global user.email >/dev/null 2>&1 || git config --global user.email "dev@docker-spigot.local"
git config --global user.name  >/dev/null 2>&1 || git config --global user.name  "docker-spigot dev"
git config --global --add safe.directory '*' 2>/dev/null || true

mkdir -p buildtools
cd buildtools

echo "Downloading BuildTools…"
curl -fsSL -o BuildTools.jar \
    https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar

echo "Building the latest Spigot to produce spigot-api (this takes a while)…"
java -Xmx2G -jar BuildTools.jar --rev latest --compile spigot

echo "Done:"
ls -1 Spigot/Spigot-API/target/spigot-api-*-shaded.jar

# If the Java extension still can't find the JDK, compare this with the
# java.jdt.ls.java.home set in devcontainer.json.
echo "JAVA_HOME=${JAVA_HOME:-<unset>}"
