# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## What this repo is

`docker-spigot` builds and pushes the Docker image (`d3strukt0r/spigot`) that
wraps a Spigot server. It does **not** build the Spigot jars — those are built and
released by a separate repo,
[`Team-MaRo/spigot-build`](https://github.com/Team-MaRo/spigot-build) (the
jar-building used to live here). This repo **consumes** the finished jar.

There is no app source code — this repo is **CI/CD + a Docker entrypoint**. The
"architecture" is the workflows and the scripts they call.

## Big picture

- **The jar is a hash-pinned flake input.** `flake.nix` takes `spigot-build` as an
  input and bakes `spigot-build.legacyPackages.<sys>.spigotJar."<ver>"` (a pinned
  `fetchurl`, **not** an impure path) into the image at `/opt/spigot.jar`. The
  version is chosen by **attribute** (`.#"<ver>"`), not an env var. New jar
  versions / rebuilt hashes arrive via `nix flake update spigot-build` (a
  Dependabot `nix` bump); the `push` trigger then rebuilds the images.
- **The image is built with Nix** (`flake.nix`, `dockerTools.streamLayeredImage`),
  not a Dockerfile, with the **version-correct JRE** (the major comes from
  `spigot-build.lib.jdkMajorFor`). Built per-arch on native runners
  (`streamLayeredImage` is single-arch) and stitched into a multi-arch manifest,
  then published with an SBOM, cosign signatures and SLSA provenance.
- **`--impure` is only for OCI labels.** `DOCKER_LABELS_JSON` (CI metadata) is the
  single impure input; the jar and version are pure, so a plain
  `nix build .#"<ver>"` works (just with empty labels).
- **The image matrix comes from `.#imageMatrix`** — `[{spigot, java}]` derived from
  the pinned `spigot-build`'s released versions, so it matches exactly what can be
  built.

### Key files

| Path | Role |
|---|---|
| `.github/workflows/ci-cd.yml` | `matrix` (versions × JDK from `.#imageMatrix`) → `docker-build` (Nix image per version × arch via `nix build .#"<ver>"` + SBOM) → `docker-manifest` (multi-arch manifest, push, cosign sign/attest) → `docker-attest` (SLSA provenance). **No jar building** — that's spigot-build. |
| `.github/workflows/check-outdated.yml` | Weekly watchdog over the newest released version's **image**: pulls + boots it (StopOnStart plugin) and, if missing/outdated/broken, dispatches `ci-cd.yml`. Newest version from `.#imageMatrix`. Also the keepalive (re-arms the schedules). |
| `.github/check-outdated/StopOnStart.java` + `plugin.yml` | Tiny Bukkit plugin: `onEnable()` → `getServer().shutdown()`. Used by the image watchdog to cleanly stop a server right after it boots. |
| `flake.nix` | Builds the OCI image (`dockerTools.streamLayeredImage`) per released version: `packages.<sys>."<ver>"` (+ `default`/`dockerImage` = newest). Jar = the pinned `spigot-build` fetch; runtime JRE from `JAVA_MAJOR` via `mkJre` (jlinked all-modules JRE, not the full JDK). Inputs: `nixpkgs`, `nix-utils`, `mc-server-init`, `spigot-build`. `--impure` only feeds `DOCKER_LABELS_JSON`. Also exposes `.#imageMatrix` (versions × JDK) for CI. |
| `src/entrypoint.sh` | Renders `server.properties`/`bukkit.yml`/`spigot.yml` from `MC__`/`BUKKIT__`/`SPIGOT__` env (via `yq`), applies the EULA gate + `BUNGEECORD` shortcut + `server-ip=0.0.0.0`, builds the JVM command (memory + a flags preset + `JVM_OPTS`), then `exec mc-server-init … -- java …` (PID 1 — PTY console + graceful stop). Packaged with `writeShellApplication`. |
| `mc-server-init` (flake input → `github:Team-MaRo/mc-server-init`) | Our first-party PID-1 init (Rust; deps `nix` + `clap`), in its own repo. Runs the server on a **PTY** (so JLine keeps the `>` prompt), forwards the container stdin **and** `/tmp/console-in` into the console, and turns SIGTERM/SIGINT/typed-Ctrl+C into a clean `stop` (SIGKILL after `--stop-timeout`). Replaced itzg's `mc-server-runner` (which piped stdin → no prompt). `flake.nix` binds `mcServerInit = mc-server-init.packages.<sys>.default`. Bump with `nix flake update mc-server-init`. |
| `spigot-build` (flake input → `github:Team-MaRo/spigot-build`) | Builds + publishes the Spigot/CraftBukkit jars and exposes them as hash-pinned fetches. The image consumes `legacyPackages.<sys>.spigotJar."<ver>"`; the per-version JDK comes from `lib.jdkMajorFor`; the version list from `lib.versions`. Bump with `nix flake update spigot-build`. |

### JDK-per-version mapping

The runtime needs a specific JDK per Minecraft version. The version→major **rule
lives in spigot-build** (`lib.jdkMajorFor`, mirroring its `matrix.ts`
`JDK_BOUNDARIES`); docker-spigot reads it from the input and maps the major to a
JRE (`jdkForPkgs` in `flake.nix`):

| Spigot / Minecraft version | JDK |
|---|---|
| ≤ 1.16.5 | 8 |
| 1.17 – 1.17.1 | 16 |
| 1.18 – 1.20.4 | 17 |
| 1.20.5 – 1.21.11 | 21 |
| ≥ 26.1 (year-based) | 25 |

Minecraft switched to **year-based versioning after `1.21.11`** (next release is
`26.1`), which is why the newest versions need JDK 25.

## Commands

```bash
# The image build matrix CI uses (versions × JDK, from the pinned spigot-build):
nix eval --json .#imageMatrix

# Build the image for a version locally (needs Nix). The jar is the pinned
# spigot-build fetch; --impure only feeds labels. Quote the dotted version.
nix build --impure '.#"26.1.2"'        # or .#dockerImage / .#default for the newest
docker load < result   # then: docker run -e EULA=true -p 25565:25565 -v $PWD/data:/srv/spigot d3strukt0r/spigot:26.1.2

# No local Nix (e.g. Windows/macOS host)? Build inside the nixos/nix container:
docker run --rm -v spigot-nix:/nix -v "$PWD:/work" -w /work nixos/nix \
  sh -c "nix --extra-experimental-features 'nix-command flakes' build --impure '.#\"26.1.2\"' && cp -fL result /work/image.tar"
docker load -i image.tar
# Gotcha: flake.nix / scripts MUST be LF — CRLF makes Nix's inline `''…''` build
# scripts fail with `$'\r': command not found`. Enforced by .gitattributes
# (eol=lf) + .vscode files.eol; core.autocrlf=true alone would reintroduce CRLF.

# Test the image against LOCAL checkouts of the init and/or the jar repo (before
# pushing changes to them): override the inputs with their paths.
docker run --rm -v spigot-nix:/nix -v "$PWD:/work" \
  -v "$PWD/../mc-server-init:/mc-init" -v "$PWD/../spigot-build:/spigot-build" \
  -w /work nixos/nix sh -c "nix --extra-experimental-features 'nix-command flakes' build \
    --override-input mc-server-init path:/mc-init --override-input spigot-build path:/spigot-build \
    '.#dockerImage' && cp -fL result /work/image.tar"

# Build the StopOnStart plugin locally (against a spigot-build release jar, which
# bundles the Bukkit API):
javac --release 8 -cp spigot.jar -d plugin-build .github/check-outdated/StopOnStart.java
cp .github/check-outdated/plugin.yml plugin-build/
jar cf StopOnStart.jar -C plugin-build .

# Run a server (or the check) locally — see README "Running a server without Docker".
```

There is no test suite; validate by building an image (`nix build --impure
'.#"<ver>"'`) and by triggering the workflows via `workflow_dispatch`.

## Conventions & gotchas

- **Every workflow job and every step has a `name:`.** Keep it that way.
- **Actions are pinned to major versions** (`@v6`, `@v5`, …); dependabot tracks
  minors. When adding an action, use the current major.
- **Jars come from `spigot-build`** (a flake input), consumed as a hash-pinned
  fetch — this repo never runs BuildTools. To make a new version buildable here,
  release it in spigot-build, then `nix flake update spigot-build`.
- **`allow-nether` and `allow-end` are `bukkit.yml` settings** in modern Spigot —
  `allow-nether` in `server.properties` is the old, ignored location.
- **The "outdated" banner prints *before* the EULA gate**, so the image watchdog
  can detect it without accepting the EULA (the server then self-exits at the gate).
- **`yq` is the Go (mikefarah) `yq` everywhere now** — both the workflows and the
  entrypoint. It edits `server.properties` too (`-p props -o props`), which is a
  Java `.properties` file (not TOML). No Python in the image anymore.
- **Image is Nix-built and version-aware.** The old `FROM openjdk:8-alpine`
  limitation (couldn't run ≥ 1.17) is gone: the flake selects the runtime from
  `JAVA_MAJOR`, so every version runs. Build locally with, e.g.,
  `nix build --impure '.#"26.1.2"'`.
- **Ships a JRE, not the full JDK** (`mkJre` in `flake.nix`). A server needs no
  JDK tools, so Java 9+ uses a `jre_minimal` jlink runtime (kept at
  `ALL-MODULE-PATH` — every module, so any plugin works — only `jmods/`/dev
  tools/debug dropped); Java 8 ships `jdk8_headless` as-is (no jlink pre-Java 9).
  Cut the 26.1.2 image from ~1.73 GB to ~750 MB. Two non-obvious gotchas:
  (1) `jre_minimal.override` must set **both** `jdk` *and* `jdkOnBuild` to the
  same JDK, else jlink uses an older JDK and can't read newer jmods ("Unsupported
  major.minor version"); (2) jlink bakes the source JDK's store path into
  `lib/modules`, dragging the full JDK back into the closure — `mkJre` scrubs it
  with `remove-references-to` and asserts via `disallowedReferences`. The
  headless source keeps `java.desktop`'s AWT (no X11), required for
  `server-icon.png` / map rendering.
- **`flake.lock` must be committed.** Generate it on a Nix machine with
  `nix flake lock`; CI builds against it.

### Container configuration (entrypoint contract)

- **Env → config:** split a var name on `__` into a key path; the first segment
  selects the file (`MC`→server.properties, `BUKKIT`→bukkit.yml,
  `SPIGOT`→spigot.yml); a single `_` in a segment becomes `-`. Properties values
  are strings (`strenv`); YAML values are type-inferred (`env`). Re-applied every
  start (env wins for managed keys; other on-disk state persists). Limitation:
  a key segment with a literal `_` (e.g. a world named `world_nether` under
  `world-settings`) can't be expressed — edit the mounted file.
- **Shortcuts:** `EULA` (gate; refuses to start unless `true`; unset == `false`),
  `BUNGEECORD` (spans three files). Memory: `MEMORY`/`INIT_MEMORY`/`MAX_MEMORY` —
  **no default**; if all unset, no `-Xms`/`-Xmx` is passed (JVM default heap).
  Flags: `JVM_FLAGS_PRESET` (`aikars` default / `velocity` / `meowice` (Java 25+
  only, falls back to aikars otherwise) / `none`) + `JVM_OPTS` (appended last,
  wins) + `SERVER_ARGS`. All support the `_FILE` Docker-secret suffix.
- **Process model:** the entrypoint does `exec mc-server-init … -- java …`, so
  **mc-server-init is PID 1** (our first-party Rust init, its own repo
  `github:Team-MaRo/mc-server-init`, a flake input). It runs the
  server on a **PTY**, so JLine keeps the interactive `>` prompt. On `docker stop`
  (SIGTERM), `SIGINT`, or a typed Ctrl+C, it sends a real `stop` → graceful save
  **with the visible `Saving players/worlds/chunks` logs** (the JVM shutdown-hook
  path saved correctly too but Log4j swallowed those lines), `SIGKILL` only after
  `--stop-timeout` (60 s). Exits in <1 s, code 0. The PTY means `docker logs` may
  contain terminal escape codes. No in-container restart script — use Docker's
  restart policy. A non-empty `CMD`/args override still replaces the launch
  (handled before the mc-server-init exec). NB: Ctrl+C reliability depends on Docker
  delivering the `0x03` byte/SIGINT; `docker stop` is the canonical clean stop.
- **Console (no RCON):** mc-server-init forwards **both** the container's stdin
  (interactive `docker run -it` / `docker attach` typing at the `>` prompt) **and**
  a named pipe at `/tmp/console-in` into the server's console. Inject with the
  bundled `console` helper (`writeShellScriptBin` → `echo "$*" > /tmp/console-in`):
  `docker exec <c> console <cmd>`. (This replaced first a pure-bash FIFO+`cat`
  attempt that couldn't deliver interactive TTY input, then itzg's
  `mc-server-runner` which worked but piped stdin so JLine dropped the `>`
  prompt — the PTY in mc-server-init restores it.)
- **Persistence:** single `/srv/spigot` volume (server working dir; FHS location
  for served data); jar stays in the image at `/opt/spigot.jar`. Runs as the
  `nonroot` user, uid `65532`; a bind-mounted volume must be writable by it.
- **Resolved env for `exec`:** `docker exec` is a sibling of PID 1 and only sees
  the *configured* env, not the entrypoint's computed defaults. So the entrypoint
  writes every resolved value to `/etc/profile.d/spigot-env.sh` (the flake adds an
  `/etc/profile` that sources `profile.d`, and makes that dir writable by 65532):
  `docker exec -it <c> sh -l` (login shell) picks them up; a bare `sh` won't. The
  no-setup alternative is `tr '\0' '\n' < /proc/1/environ`.

## Required secrets / vars

`GITHUB_TOKEN` (provided), `vars.DOCKERHUB_USERNAME` + `secrets.DOCKERHUB_TOKEN`
for pushes, and `vars.IMAGE_NAME` for the image reference. The docker jobs need
`id-token: write` / `attestations: write` / `packages: write` (cosign + SLSA);
these are set per-job in `ci-cd.yml`. If the Docker Hub creds are absent, the
manifest/attest steps skip cleanly (build + SBOM still run).
