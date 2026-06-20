# docker-spigot

Use the Minecraft Spigot server as a Docker container

[![License](https://img.shields.io/github/license/Team-MaRo/docker-spigot)](LICENSE.txt)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa)][code-of-conduct]
[![Docker Stars](https://img.shields.io/docker/stars/d3strukt0r/spigot)][docker]
[![Docker Pulls](https://img.shields.io/docker/pulls/d3strukt0r/spigot)][docker]

[![GH Action Docker](https://github.com/Team-MaRo/docker-spigot/actions/workflows/docker.yml/badge.svg)][gh-action]
[![Codacy grade](https://img.shields.io/codacy/grade/b674b9fdcd8a429ca863e975e685cbd1/master)][codacy]

## Getting Started

These instructions will cover usage information and for the docker container

### Prerequisities

In order to run this container you'll need docker installed.

- [Windows](https://docs.docker.com/docker-for-windows/install/)
- [OS X](https://docs.docker.com/docker-for-mac/install/)
- [Linux](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

### Usage

#### Starting a server

```shell
docker run \
    -d \
    --restart unless-stopped \
    -p 25565:25565 \
    -v $(pwd)/data:/srv/spigot \
    -e EULA=true \
    -e MEMORY=2G \
    --name spigot \
    d3strukt0r/spigot
```

`server-ip` is forced to `0.0.0.0` automatically (required so the server is
reachable from outside the container), so you don't need to set it.

`-d`: Start detached. Leave it out (and add `-it`) to attach the interactive
server console — see [Console](#console) below.

`--restart unless-stopped`: Let Docker restart the server if it crashes or runs
`/restart`. The container is the server process, so restarts are Docker's job
(there is no in-container restart script).

`-p 25565:25565`: Publish the server port. Open more with additional `-p` flags
(e.g. `-p 25565:25565 -p 8192:8192`).

`-v $(pwd)/data:/srv/spigot`: Persist the server. Everything the server writes —
worlds, plugins, configs, logs — lives under `/srv/spigot`. The `spigot.jar`
itself is baked into the image (at `/opt/spigot.jar`), so it is **not** in this
volume. See [Data persistence](#data-persistence).

`-e EULA=true`: Accept the [Minecraft EULA](https://aka.ms/MinecraftEULA). The
server refuses to start without it (leaving it unset is the same as `false`).

`-e MEMORY=2G`: Optional heap size (sets both `-Xms` and `-Xmx`); if unset the
JVM picks its own default. See [Environment variables](#environment-variables)
for the JVM knobs and flag presets (Aikar's by default).

`--name spigot`: Give the container a name, for easier referencing later on.

`d3strukt0r/spigot`: This is the repository where the container is maintained. You can also specify what version you want to use. e. g. `d3strukt0r/spigot:latest` or `d3strukt0r/spigot:1.8`. For all versions check the [Tags on Docker Hub](https://hub.docker.com/repository/docker/d3strukt0r/spigot/tags).

#### Reading the logs

While running you can access the output with `docker logs -f <container name>` and leave with `CTRL + Q`.

`-f`: To not just output the logs until now, but keep reading, until we exit with `CTRL + D`. This will not close the server, you'll just leave the logs.

#### Console

The server is supervised by a small first-party init
([`mc-server-init`](https://github.com/Team-MaRo/mc-server-init)) that runs it
behind a PTY and feeds the console from both your terminal and a named pipe, so
you can drive it two ways.

**Interactively** — start with `-it` and `docker attach`:

```shell
docker run -it --name spigot ... d3strukt0r/spigot   # console is attached
# detach without stopping: CTRL + P, then CTRL + Q
docker attach spigot                                  # re-attach later
```

Type Minecraft commands directly at the `>` prompt (e.g. `op D3strukt0r`). The
prompt and line-editing work because the server runs on a real terminal; a side
effect is that `docker logs` may contain some terminal escape codes.

**Scriptably (no RCON)** — inject a single command with the bundled `console`
helper (or the raw pipe), without attaching:

```shell
docker exec <container> console op D3strukt0r
docker exec <container> console "say hello from a script"
# equivalent without the helper:
docker exec <container> sh -c 'echo "list" > /tmp/console-in'
```

##### Stopping the server

Use `docker stop -t 60 <container name>`. `docker stop` sends `SIGTERM`, which
`mc-server-init` turns into a clean `stop` command so the server saves worlds and
shuts down gracefully; `-t 60` gives it up to 60 s to finish before Docker
force-kills it. (A typed Ctrl+C in an attached `-it` session does the same. The
console `stop` command works too.)

#### Inspecting the resolved config (env in a shell)

A plain `docker exec <container> sh` is a *sibling* of the server process, so it
only sees the container's **configured** env (image defaults + the vars you
passed at `run`/`compose` time) — **not** the values the entrypoint computes at
startup (e.g. `INIT_MEMORY`/`MAX_MEMORY` defaulting from `MEMORY`). Two ways to
see the fully-resolved values:

```shell
# 1. Login shell — sources /etc/profile.d/spigot-env.sh, which the entrypoint
#    writes with every resolved value:
docker exec -it <container> sh -l
# (a bare `sh` won't have them — that's normal; only login shells source it)

# 2. Read the server process's real environment directly, no setup:
docker exec <container> sh -c "tr '\0' '\n' < /proc/1/environ"
```

#### Using Docker Compose (docker-compose.yml)

Create a file called `docker-compose.yml`

```yaml
services:
  spigot:
    image: d3strukt0r/spigot
    restart: unless-stopped
    stdin_open: true   # keep the console usable via `docker attach`
    tty: true
    stop_grace_period: 60s
    ports:
      - 25565:25565
    volumes:
      - ./data:/srv/spigot
    environment:
      - EULA=true
      - MEMORY=2G
      - JVM_FLAGS_PRESET=aikars
      # Any server.properties / bukkit.yml / spigot.yml key, e.g.:
      - MC__MOTD=My Server
      - MC__MAX_PLAYERS=20
      - SPIGOT__SETTINGS__BUNGEECORD=false
```

##### Compose: Starting a server

To start the server use `docker-compose up` or `docker-compose up -d` for starting detached (in the background).  When running without `-d`, you can still detach with `CTRL + P` followed by `CTRL + Q`.

##### Compose: Reading the logs

While running you can access the output with `docker-compose logs -f` and leave with `CTRL + Q`.

##### Compose: Console

With `stdin_open: true` and `tty: true` set above, attach the console with
`docker compose attach spigot` (detach with `CTRL + P`, `CTRL + Q`).

##### Compose: Stopping the server

Use `docker compose down` (or `docker compose stop`). `stop_grace_period: 60s`
gives the server time to save before being force-killed.

#### Environment variables

All variables support Docker Secrets: append `_FILE` (e.g. `EULA_FILE`) and point
it at a path like `/run/secrets/<something>`.

| Variable | Default | Description |
| --- | --- | --- |
| `EULA` | _(unset = `false`)_ | Accept the [Minecraft EULA](https://aka.ms/MinecraftEULA). The server refuses to start unless `true`. |
| `MEMORY` | _(unset)_ | Heap size; sets both `-Xms` and `-Xmx`. Integer + `K`/`M`/`G`. If unset (and `INIT_MEMORY`/`MAX_MEMORY` too), no `-Xms`/`-Xmx` is passed and the JVM uses its own default. |
| `INIT_MEMORY` | `${MEMORY}` | Override just `-Xms`. |
| `MAX_MEMORY` | `${MEMORY}` | Override just `-Xmx`. |
| `JVM_FLAGS_PRESET` | `aikars` | GC/tuning preset: `aikars`, `velocity`, `meowice` (Java 25+ only), or `none`. |
| `JVM_OPTS` | _(empty)_ | Extra JVM flags, appended after the preset so they win (e.g. `-Xmx3G`). |
| `BUNGEECORD` | `false` | Shortcut: when `true`, sets `online-mode=false`, `spigot.yml settings.bungeecord=true`, `bukkit.yml settings.connection-throttle=-1`. |

To pass arguments to the server itself, append them to the container command — if the first one
starts with `-` they're forwarded after `--nogui` (e.g.
`docker run … d3strukt0r/spigot --world-dir worlds`). A non-option command such as `bash` runs as an
override instead (and bypasses the EULA gate): `docker run -it … d3strukt0r/spigot bash`.

##### JVM flag presets

- **`aikars`** (default) — [Aikar's flags](https://docs.papermc.io/paper/aikars-flags/); tunes a few knobs automatically for heaps ≥ 12 GB.
- **`velocity`** — flags recommended for the [Velocity](https://docs.papermc.io/velocity/) proxy.
- **`meowice`** — [MeowIce's flags](https://github.com/MeowIce/meowice-flags) (**requires Java 25+**, i.e. the year-based image tags); picks G1GC < 32 GB and ZGC ≥ 32 GB. On older images it logs a warning and falls back to `aikars`.
- **`none`** — no preset flags.

To pass your own complete command instead, just append it: anything after the
image name replaces the launch entirely (e.g. `... d3strukt0r/spigot java -Xmx4G -jar /opt/spigot.jar`).

#### Configuring the server from environment variables

Any key in `server.properties`, `bukkit.yml` or `spigot.yml` can be set from an
env var. The name is split on **`__`** (double underscore) into a key path; the
**first segment selects the file**; within a segment a single **`_`** becomes a
**`-`**:

| Prefix | File |
| --- | --- |
| `MC__…` | `server.properties` |
| `BUKKIT__…` | `bukkit.yml` |
| `SPIGOT__…` | `spigot.yml` |

Examples:

```shell
-e MC__MOTD="My Server"                 # server.properties  motd=My Server
-e MC__MAX_PLAYERS=20                    # server.properties  max-players=20
-e MC__VIEW_DISTANCE=10                  # server.properties  view-distance=10
-e MC__QUERY__PORT=25565                 # server.properties  query.port=25565   (dotted key)
-e BUKKIT__SETTINGS__UPDATE_FOLDER=update  # bukkit.yml  settings.update-folder: update
-e SPIGOT__SETTINGS__BUNGEECORD=true     # spigot.yml  settings.bungeecord: true
```

These are re-applied on every start, so the env vars are the source of truth for
the keys you set; anything else the server writes to those files is left intact.
YAML values are type-inferred (`true` → bool, `10` → int) — quote a value if you
need a literal string. (Limitation: a key segment that legitimately contains an
underscore — e.g. a world named `world_nether` under `world-settings` — can't be
expressed this way; edit the mounted file directly for those.)

#### Volumes

- `/srv/spigot` — the server working directory and the single persistence volume
  (worlds, plugins, configs, logs, …). The `spigot.jar` is in the image, not
  here. The volume must be writable by uid `65532` (the container's `nonroot`
  user) — `chown 65532:65532 ./data` a bind mount if needed.

#### Data persistence

Spigot keeps all its state in one working directory, so the image uses a single
`/srv/spigot` volume for it (FHS's location for site-specific served data):
mount it (`-v $(pwd)/data:/srv/spigot`) and your worlds, plugins,
`*.yml`/`server.properties`, `ops.json`, logs, etc. all survive container
recreation. The server jar is baked into the image at `/opt/spigot.jar`, so it
never ends up on your host. Config keys set via the `MC__`/`BUKKIT__`/`SPIGOT__`
env vars are re-applied at every start; everything else on disk is left as the
server wrote it.

## Where the Spigot jars come from

The Spigot/CraftBukkit jars are built and released by a separate repo,
[**Team-MaRo/spigot-build**](https://github.com/Team-MaRo/spigot-build) (this used
to live here). It compiles them with
[BuildTools](https://www.spigotmc.org/wiki/buildtools/), publishes a GitHub
Release per Minecraft version, and exposes them as **hash-pinned Nix fetches**.

This image **consumes** the finished `spigot.jar` — it never builds one. The flake
takes `spigot-build` as an input and bakes
`spigot-build.legacyPackages.<sys>.spigotJar."<version>"` (a pinned `fetchurl`, not
an impure path) into `/opt/spigot.jar`; the runtime JDK per version comes from
`spigot-build.lib.jdkMajorFor`.

- **Build one version's image:** `nix build --impure '.#"26.1.2"'` (or
  `.#dockerImage` / `.#default` for the newest released version). `--impure` only
  feeds the OCI labels — the jar and version are pure inputs.
- **Pick up new jar versions / rebuilt hashes:** `nix flake update spigot-build`.

See spigot-build's docs for the JDK-per-version table and the build/release flow.

## Running a server without Docker

If you just want the jar (no container), download the `spigot.jar` for the
version you want from the [releases][gh-releases] page and run it with the JDK
that version requires (see the table above).

In the same directory as `spigot.jar`, create a start script (replace `#` with
the amount of RAM in GB to allocate):

Other settings to consider, can be found in [Aikar's flags](https://docs.papermc.io/paper/aikars-flags/).

#### Windows (`start.bat`)

```bat
@echo off
java -Xms#G -Xmx#G -XX:+UseG1GC -jar spigot.jar nogui
pause
```

#### Linux (`start.sh`)

```shell
#!/bin/sh

java -Xms#G -Xmx#G -XX:+UseG1GC -jar spigot.jar nogui
```

#### macOS (`start.sh`)

```shell
#!/bin/sh

cd "$( dirname "$0" )"
java -Xms#G -Xmx#G -XX:+UseG1GC -jar spigot.jar nogui
```

On Linux/macOS run `chmod a+x start.sh` to make it executable. For more detail
see the official [Spigot Wiki](https://www.spigotmc.org/wiki/spigot/).

## Example configuration files

These live in the `/srv/spigot` volume after the first start. The samples below
show the defaults Spigot generates, for reference.

<details>
<summary>Example <code>bukkit.yml</code></summary>

```yml
# This is the main configuration file for Bukkit.
# As you can see, there's actually not that much to configure without any plugins.
# For a reference for any variable inside this file, check out the Bukkit Wiki at
# https://www.spigotmc.org/go/bukkit-yml
# 
# If you need help on this file, feel free to join us on irc or leave a message
# on the forums asking for advice.
# 
# IRC: #spigot @ irc.spi.gt
#    (If this means nothing to you, just go to https://www.spigotmc.org/go/irc )
# Forums: https://www.spigotmc.org/
# Bug tracker: https://www.spigotmc.org/go/bugs


settings:
  minimum-api: none
  allow-end: false
  warn-on-overload: true
  permissions-file: permissions.yml
  update-folder: update
  plugin-profiling: false
  connection-throttle: -1
  query-plugins: true
  deprecated-verbose: default
  shutdown-message: Server closed
spawn-limits:
  monsters: 70
  animals: 15
  water-animals: 5
  ambient: 15
chunk-gc:
  period-in-ticks: 600
  load-threshold: 0
ticks-per:
  water-spawns: 1
  ambient-spawns: 1
  animal-spawns: 400
  monster-spawns: 1
  autosave: 6000
aliases: now-in-commands.yml
```

</details>

<details>
<summary>Example <code>server.properties</code></summary>

```properties
#Minecraft server properties
#Sun Mar 08 23:57:11 CET 2020
spawn-protection=16
max-tick-time=60000
query.port=25565
generator-settings=3;minecraft\:bedrock,minecraft\:wool;1;
force-gamemode=false
allow-nether=false
enforce-whitelist=false
gamemode=survival
broadcast-console-to-ops=true
enable-query=false
player-idle-timeout=0
difficulty=easy
spawn-monsters=false
broadcast-rcon-to-ops=true
op-permission-level=4
pvp=false
snooper-enabled=true
level-type=flat
hardcore=false
enable-command-block=false
max-players=20
network-compression-threshold=256
resource-pack-sha1=
max-world-size=29999984
function-permission-level=2
rcon.port=25575
server-port=25566
debug=false
server-ip=127.0.0.1
spawn-npcs=false
allow-flight=false
level-name=world
view-distance=10
resource-pack=
spawn-animals=false
white-list=false
rcon.password=
generate-structures=false
online-mode=false
max-build-height=256
level-seed=
use-native-transport=true
prevent-proxy-connections=false
motd=A Minecraft Server
enable-rcon=false
```

</details>

<details>
<summary>Example <code>spigot.yml</code></summary>

```yml
# This is the main configuration file for Spigot.
# As you can see, there's tons to configure. Some options may impact gameplay, so use
# with caution, and make sure you know what each option does before configuring.
# For a reference for any variable inside this file, check out the Spigot wiki at
# http://www.spigotmc.org/wiki/spigot-configuration/
# 
# If you need help with the configuration or have any questions related to Spigot,
# join us at the IRC or drop by our forums and leave a post.
# 
# IRC: #spigot @ irc.spi.gt ( http://www.spigotmc.org/pages/irc/ )
# Forums: http://www.spigotmc.org/

config-version: 12
settings:
  log-villager-deaths: true
  debug: false
  save-user-cache-on-stop-only: false
  moved-wrongly-threshold: 0.0625
  filter-creative-items: true
  moved-too-quickly-multiplier: 10.0
  player-shuffle: 0
  item-dirty-ticks: 20
  late-bind: false
  netty-threads: 4
  sample-count: 12
  bungeecord: true
  int-cache-limit: 1024
  timeout-time: 60
  restart-on-crash: true
  restart-script: ./start.bat
  user-cache-size: 1000
  attribute:
    maxHealth:
      max: 2048.0
    movementSpeed:
      max: 2048.0
    attackDamage:
      max: 2048.0
messages:
  whitelist: You are not whitelisted on this server!
  unknown-command: Unknown command. Type "/help" for help.
  server-full: The server is full!
  outdated-client: Outdated client! Please use {0}
  outdated-server: Outdated server! I'm still on {0}
  restart: Server is restarting
commands:
  send-namespaced: true
  tab-complete: 0
  silent-commandblock-console: false
  spam-exclusions:
  - /skill
  replace-commands:
  - setblock
  - summon
  - testforblock
  - tellraw
  log: true
advancements:
  disable-saving: false
  disabled:
  - minecraft:story/disabled
stats:
  disable-saving: false
  forced-stats: {}
world-settings:
  default:
    seed-desert: 14357617
    seed-igloo: 14357618
    seed-jungle: 14357619
    seed-swamp: 14357620
    seed-shipwreck: 165745295
    seed-ocean: 14357621
    seed-outpost: 165745296
    view-distance: default
    trident-despawn-rate: 1200
    verbose: false
    enable-zombie-pigmen-portal-spawns: true
    wither-spawn-sound-radius: 0
    hanging-tick-frequency: 100
    arrow-despawn-rate: 1200
    merge-radius:
      item: 2.5
      exp: 3.0
    item-despawn-rate: 6000
    zombie-aggressive-towards-villager: true
    nerf-spawner-mobs: false
    ticks-per:
      hopper-transfer: 8
      hopper-check: 1
    hopper-amount: 1
    hunger:
      jump-walk-exhaustion: 0.05
      jump-sprint-exhaustion: 0.2
      combat-exhaustion: 0.1
      regen-exhaustion: 6.0
      swim-multiplier: 0.01
      sprint-multiplier: 0.1
      other-multiplier: 0.0
    growth:
      beetroot-modifier: 100
      carrot-modifier: 100
      potato-modifier: 100
      bamboo-modifier: 100
      sweetberry-modifier: 100
      kelp-modifier: 100
      cactus-modifier: 100
      cane-modifier: 100
      melon-modifier: 100
      mushroom-modifier: 100
      pumpkin-modifier: 100
      sapling-modifier: 100
      wheat-modifier: 100
      netherwart-modifier: 100
      vine-modifier: 100
      cocoa-modifier: 100
    entity-tracking-range:
      players: 48
      animals: 48
      monsters: 48
      misc: 32
      other: 64
    squid-spawn-range:
      min: 45.0
    entity-activation-range:
      raiders: 48
      animals: 32
      monsters: 32
      misc: 16
      tick-inactive-villagers: true
    max-tnt-per-tick: 100
    max-tick-time:
      tile: 50
      entity: 50
    save-structure-info: true
    mob-spawn-range: 4
    random-light-updates: false
    seed-village: 10387312
    seed-feature: 14357617
    seed-monument: 10387313
    seed-slime: 987234911
    dragon-death-sound-radius: 0
```

</details>

## Server version usage

Minecraft server version distribution (last checked: 2020-05-28).

From [bStats](https://bstats.org/global/bukkit):

![bStats Versions](https://i.imgur.com/GuUEZtB.png)

From [MCStats](http://mcstats.org/global/):

![MCStats Versions](https://i.imgur.com/zyJgQcr.png)

## Built With

- [Nix](https://nixos.org/) - Builds the reproducible, multi-arch OCI image (with the version-correct JRE)
- [OpenJDK](https://openjdk.org/) - The Java runtime baked into the image: a trimmed JRE (jlinked from the headless OpenJDK; no JDK dev tools), version-matched to each Minecraft release
- [Spigot](https://www.spigotmc.org/wiki/spigot/) - The main software
- [BuildTools](https://www.spigotmc.org/wiki/buildtools/) - Compiles the Spigot/CraftBukkit jars
- [Rust](https://www.rust-lang.org/) - The language of the container's PID-1 init, [`mc-server-init`](https://github.com/Team-MaRo/mc-server-init) (own repo): PTY-backed console, named-pipe injection, signal → graceful stop
- [Github Actions](https://github.com/features/actions) - Automatic CI (Testing) / CD (Deployment)
- [Docker](https://www.docker.com/) - Runs the Server container

## Find Us

- [GitHub](https://github.com/Team-MaRo/docker-spigot)
- [Docker Hub](https://hub.docker.com/r/d3strukt0r/spigot)

## Contributing

Please read [CONTRIBUTING.md][contributing] for details on our code of conduct and the process for submitting pull requests.

## Versioning

There is no project-specific versioning. The tags you see are the Minecraft
versions: each tag (on the `builds` branch) carries the compiled jars for that
version, and the Docker image is published under the same version tag, with the
newest version also tagged `latest`.

## Authors

### Special thanks for all the people who had helped this project so far

- **Manuele** - [D3strukt0r](https://github.com/D3strukt0r)

See also the full list of [contributors][gh-contributors] who participated in this project.

### I would like to join this list. How can I help the project?

We're currently looking for contributions for the following:

- [ ] Bug fixes
- [ ] Translations
- [ ] etc...

For more information, please refer to our [CONTRIBUTING.md][contributing] guide.

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details.

## Acknowledgments

This project uses code from the following libraries:

- [Minecraft](https://www.minecraft.net), Unknown License
- [BuildTools](https://www.spigotmc.org), Unknown License
- [Spigot](https://www.spigotmc.org), Unknown License
- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server), Apache-2.0 license
- Kjell Havnesköld with [nimmis/docker-spigot](https://github.com/nimmis/docker-spigot)
- Sylvain CAU with [AshDevFr/docker-spigot](https://github.com/AshDevFr/docker-spigot)
- Hat tip to anyone whose code was used
- Inspiration
- etc

[docker]: https://hub.docker.com/r/d3strukt0r/spigot
[codacy]: https://www.codacy.com/manual/D3strukt0r/docker-spigot
[gh-action]: https://github.com/D3strukt0r/docker-spigot/actions/workflows/docker.yml
[gh-releases]: https://github.com/Team-MaRo/docker-spigot/releases
[gh-contributors]: https://github.com/Team-MaRo/docker-spigot/contributors
[contributing]: https://github.com/Team-MaRo/.github/blob/master/CONTRIBUTING.md
[code-of-conduct]: https://github.com/Team-MaRo/.github/blob/master/CODE_OF_CONDUCT.md
