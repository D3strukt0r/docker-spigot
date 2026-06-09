#!/usr/bin/env bash
#
# Spigot container entrypoint.
#
# Responsibilities, in order:
#   1. Render server.properties / bukkit.yml / spigot.yml from MC_ / BUKKIT_ /
#      SPIGOT_ environment variables (see "Config from env" below).
#   2. Apply the few convenience shortcuts (BUNGEECORD).
#   3. Assemble the JVM command line (memory + a flags preset + user overrides).
#   4. Gate on the EULA (an override CMD/args bypasses it), then exec
#      mc-server-init as PID 1 (own repo github:Team-MaRo/mc-server-init, a
#      flake input). It runs the server on a PTY so
#      the JLine console keeps its `>` prompt, forwards the container stdin and a
#      named pipe into the console, and turns SIGTERM/SIGINT/Ctrl+C into a clean
#      `stop` so worlds are saved with the "Saving…" logs.
#
# When packaged with Nix `writeShellApplication`, `set -euo pipefail` and a PATH
# containing java/yq/coreutils/grep are prepended; the lines below let the script
# also run standalone for local testing.
set -euo pipefail

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log()   { printf '%s [%s] [entrypoint] %s\n' "$(date '+%Y-%m-%d %T %z')" "${2:-note}" "$1"; }
note()  { log "$1" note; }
warn()  { log "$1" warn >&2; }
fatal() { log "$1" ERROR >&2; exit 1; }

# usage: file_env VAR [DEFAULT]
# Lets "${VAR}_FILE" supply the value of "$VAR" (Docker/Swarm secrets).
file_env() {
    local var="$1" fileVar="${1}_FILE" def="${2:-}" val
    if [ -n "${!var:-}" ] && [ -n "${!fileVar:-}" ]; then
        fatal "both $var and $fileVar are set (mutually exclusive)"
    fi
    val="$def"
    if   [ -n "${!var:-}" ];     then val="${!var}"
    elif [ -n "${!fileVar:-}" ]; then val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Config from env
#
# A variable name is split on "__" into path segments; the first segment selects
# the file, the rest form the key path; within a segment a single "_" becomes a
# "-". Examples:
#   MC__LOG_IPS=true                  -> server.properties  log-ips=true
#   MC__QUERY__PORT=25565             -> server.properties  query.port=25565
#   BUKKIT__SETTINGS__UPDATE_FOLDER=x -> bukkit.yml          settings.update-folder: x
#   SPIGOT__SETTINGS__BUNGEECORD=true -> spigot.yml          settings.bungeecord: true
#
# Properties values stay strings (strenv); YAML values are typed (env) so
# `true` becomes a bool and `10` an int. A YAML value that *looks* numeric is
# therefore typed — quote it in the value if you need a literal string.
# ---------------------------------------------------------------------------

# Turn the part of the var name after the prefix into a bracketed yq path, e.g.
# "SETTINGS__UPDATE_FOLDER" -> '["settings"]["update-folder"]'.
env_to_path() {
    local rest="$1" seg path=""
    while IFS= read -r seg; do
        [ -z "$seg" ] && continue
        seg="$(printf '%s' "$seg" | tr 'A-Z_' 'a-z-')"
        path="${path}[\"${seg}\"]"
    done <<< "${rest//__/$'\n'}"
    printf '%s' "$path"
}

# usage: render <file> <PREFIX__> <props|yaml>
render() {
    local file="$1" prefix="$2" fmt="$3" var path
    [ -f "$file" ] || : > "$file"
    while IFS= read -r var; do
        path="$(env_to_path "${var#"$prefix"}")"
        [ -z "$path" ] && continue
        if [ "$fmt" = props ]; then
            yq -p props -o props --properties-separator='=' -i ".${path} = strenv(${var})" "$file"
        else
            yq -i ".${path} = env(${var})" "$file"
        fi
        note "set ${path} in ${file} (from ${var})"
        # printenv lists exported env vars (NAME=value); grep -o keeps just the
        # names with our prefix. (compgen isn't available in the minimal bash.)
    done < <(printenv | grep -oE "^${prefix}[^=]*" || true)
}

# Convenience setters used by the shortcuts below.
set_prop() { yq -p props -o props --properties-separator='=' -i ".[\"$2\"] = \"$3\"" "$1"; }

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
note 'Spigot entrypoint starting'

for v in EULA BUNGEECORD MEMORY INIT_MEMORY MAX_MEMORY JVM_OPTS JVM_FLAGS_PRESET SERVER_ARGS; do
    file_env "$v"
done

# No memory default: if MEMORY/INIT_MEMORY/MAX_MEMORY are all unset we pass no
# -Xms/-Xmx and the JVM uses its own default heap sizing.
: "${EULA:=false}"
: "${BUNGEECORD:=false}"
: "${MEMORY:=}"
: "${INIT_MEMORY:=${MEMORY}}"
: "${MAX_MEMORY:=${MEMORY}}"
: "${JVM_OPTS:=}"
: "${JVM_FLAGS_PRESET:=aikars}"
: "${SERVER_ARGS:=}"
: "${JAVA_MAJOR:=0}"

# Defaults applied before the generic render, so an explicit MC__/SPIGOT__/
# BUKKIT__ var can still override them.
for f in server.properties bukkit.yml spigot.yml; do [ -f "$f" ] || : > "$f"; done
set_prop server.properties server-ip 0.0.0.0   # bind inside the container

if [ "$BUNGEECORD" = true ]; then
    note 'BUNGEECORD=true: enabling proxy settings'
    set_prop server.properties online-mode false
    yq -i '.settings.bungeecord = true' spigot.yml
    yq -i '.settings["connection-throttle"] = -1' bukkit.yml
fi

note 'Rendering config from environment'
render server.properties 'MC__'     props
render bukkit.yml         'BUKKIT__' yaml
render spigot.yml         'SPIGOT__' yaml

# ---------------------------------------------------------------------------
# JVM flags
# ---------------------------------------------------------------------------
mem_to_mb() {
    local v="${1:-}"
    [ -z "$v" ] && { echo 0; return; }
    v="${v^^}"
    case "$v" in
        *G) echo $(( ${v%G} * 1024 )) ;;
        *M) echo "${v%M}" ;;
        *K) echo $(( ${v%K} / 1024 )) ;;
        *)  echo $(( v / 1024 / 1024 )) ;;
    esac
}
# 0 when memory is unset → preset picks its small-heap tuning by default.
max_mb="$(mem_to_mb "$MAX_MEMORY")"

# MeowIce needs Java 25+ (compact object headers, EagerJVMCI); downgrade early
# so the case below stays a clean single-match.
if [ "$JVM_FLAGS_PRESET" = meowice ] && ! { [ "$JAVA_MAJOR" -ge 25 ] 2>/dev/null; }; then
    warn "JVM_FLAGS_PRESET=meowice needs Java 25+, but this image is Java ${JAVA_MAJOR}; falling back to aikars"
    JVM_FLAGS_PRESET=aikars
fi

# Each preset is the GC/tuning flag set only; -Xms/-Xmx come from MEMORY.
preset_flags=()
case "$JVM_FLAGS_PRESET" in
    none)
        ;;
    velocity)
        # For the Velocity proxy (https://docs.papermc.io/velocity/).
        read -r -a preset_flags <<< "-XX:+AlwaysPreTouch -XX:+ParallelRefProcEnabled -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:MaxInlineLevel=15"
        ;;
    meowice)
        # https://github.com/MeowIce/meowice-flags (Java 25+). G1GC < 32G, ZGC >= 32G.
        common="--add-modules=jdk.incubator.vector -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:+PerfDisableSharedMem -XX:+UseNUMA -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:NmethodSweepActivity=1 -XX:+UseCriticalJavaThreadPriority -XX:+AlwaysActAsServerClassMachine -XX:+UseTransparentHugePages -XX:LargePageSizeInBytes=2M -XX:+UseLargePages -XX:+EagerJVMCI -XX:+UseStringDeduplication -XX:+UseAES -XX:+UseAESIntrinsics -XX:+UseFMA -XX:+UseLoopPredicate -XX:+RangeCheckElimination -XX:+OptimizeStringConcat -XX:+UseCompressedOops -XX:+UseThreadPriorities -XX:+OmitStackTraceInFastThrow -XX:+RewriteBytecodes -XX:+RewriteFrequentPairs -XX:+UseFPUForSpilling -XX:+UseFastStosb -XX:+UseNewLongLShift -XX:+UseVectorCmov -XX:+UseXMMForArrayCopy -XX:+UseXmmI2D -XX:+UseXmmI2F -XX:+UseXmmLoadAndClearUpper -XX:+UseXmmRegToRegMoveAll -XX:+EliminateLocks -XX:+DoEscapeAnalysis -XX:+AlignVector -XX:+OptimizeFill -XX:+EnableVectorSupport -XX:+UseCharacterCompareIntrinsics -XX:+UseCopySignIntrinsic -XX:+UseVectorStubs -XX:+UseFastJNIAccessors -XX:+UseInlineCaches -XX:+SegmentedCodeCache -XX:+UseCompactObjectHeaders -Djdk.nio.maxCachedBufferSize=262144 -Djdk.graal.UsePriorityInlining=true -Djdk.graal.Vectorization=true -Djdk.graal.OptDuplication=true -Djdk.graal.DetectInvertedLoopsAsCounted=true -Djdk.graal.LoopInversion=true -Djdk.graal.VectorizeHashes=true -Djdk.graal.EnterprisePartialUnroll=true -Djdk.graal.VectorizeSIMD=true -Djdk.graal.StripMineNonCountedLoops=true -Djdk.graal.SpeculativeGuardMovement=true -Djdk.graal.TuneInlinerExploration=1 -Djdk.graal.LoopRotation=true -Djdk.graal.CompilerConfiguration=enterprise"
        if [ "$max_mb" -ge 32768 ]; then
            note 'Using MeowIce ZGC flags (>=32G)'
            read -r -a preset_flags <<< "-XX:+UseZGC -XX:-ZProactive -XX:SoftMaxHeapSize=$(( max_mb - 2048 ))M -XX:AllocatePrefetchStyle=1 $common"
        else
            note 'Using MeowIce G1GC flags (<32G)'
            read -r -a preset_flags <<< "-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1NewSizePercent=28 -XX:G1MaxNewSizePercent=50 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=15 -XX:G1MixedGCCountTarget=3 -XX:InitiatingHeapOccupancyPercent=20 -XX:G1MixedGCLiveThresholdPercent=90 -XX:SurvivorRatio=32 -XX:G1HeapWastePercent=5 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5 -XX:G1RSetUpdatingPauseTimePercent=0 -XX:AllocatePrefetchStyle=3 $common"
        fi
        ;;
    aikars|*)
        [ "$JVM_FLAGS_PRESET" = aikars ] || warn "Unknown JVM_FLAGS_PRESET='${JVM_FLAGS_PRESET}', using aikars"
        # https://docs.papermc.io/paper/aikars-flags/ — larger heaps tune a few knobs.
        if [ "$max_mb" -ge 12288 ]; then
            g1new=40; g1maxnew=50; region=16M; reserve=15; ihop=20; mixedtarget=3; rset=0
        else
            g1new=30; g1maxnew=40; region=8M;  reserve=20; ihop=15; mixedtarget=4; rset=5
        fi
        read -r -a preset_flags <<< "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=${g1new} -XX:G1MaxNewSizePercent=${g1maxnew} -XX:G1HeapRegionSize=${region} -XX:G1ReservePercent=${reserve} -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=${mixedtarget} -XX:InitiatingHeapOccupancyPercent=${ihop} -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=${rset} -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true"
        ;;
esac

# Build the final argv as an array so flags with no values keep their boundaries.
java_args=()
[ -n "$INIT_MEMORY" ] && java_args+=( "-Xms${INIT_MEMORY}" )
[ -n "$MAX_MEMORY" ]  && java_args+=( "-Xmx${MAX_MEMORY}" )
[ "${#preset_flags[@]}" -gt 0 ] && java_args+=( "${preset_flags[@]}" )
if [ -n "$JVM_OPTS" ]; then read -r -a _o <<< "$JVM_OPTS"; java_args+=( "${_o[@]}" ); fi
java_args+=( -jar /opt/spigot.jar --nogui )
if [ -n "$SERVER_ARGS" ]; then read -r -a _s <<< "$SERVER_ARGS"; java_args+=( "${_s[@]}" ); fi

# Record the fully-resolved env so `docker exec -it <c> sh -l` can see it. A bare
# `docker exec` is a sibling of PID 1 and only inherits the container's CONFIGURED
# env (image ENV + run -e), never these runtime-computed defaults. Best-effort:
# a non-writable /etc/profile.d must never block startup.
{ for v in EULA BUNGEECORD MEMORY INIT_MEMORY MAX_MEMORY JVM_OPTS \
           JVM_FLAGS_PRESET SERVER_ARGS JAVA_MAJOR; do
    printf 'export %s=%q\n' "$v" "${!v}"
  done; } > /etc/profile.d/spigot-env.sh 2>/dev/null || true

# Full escape hatch: a CMD/args override replaces the launch entirely. It sits
# before the EULA gate on purpose — `docker run <image> bash` (or any other
# override) should drop you in without EULA=true; the gate guards the server
# launch, not entering the container.
if [ "$#" -gt 0 ]; then
    note "Running override command: $*"
    exec "$@"
fi

# EULA gate. The banner about agreeing to the Minecraft EULA prints regardless;
# we simply refuse to launch the server unless it was accepted.
printf '# https://aka.ms/MinecraftEULA\neula=%s\n' "$EULA" > eula.txt
if [ "$EULA" != true ]; then
    fatal "You must accept the Minecraft EULA to run the server: pass -e EULA=true (https://aka.ms/MinecraftEULA)"
fi

# Launch via mc-server-init (PID 1; own repo, a flake input). It runs the server behind a PTY
# (so JLine keeps the `>` prompt), forwards the container's stdin (interactive
# `docker run -it` / `docker attach`) AND a named pipe at /tmp/console-in
# (scripted `console <cmd>` injection, no RCON) into the console, and on SIGTERM /
# SIGINT / a typed Ctrl+C sends a clean `stop` — graceful save with the "Saving…"
# logs — falling back to SIGKILL only after --stop-timeout.
note "Launching via mc-server-init: java ${java_args[*]}  (console: console <cmd>)"
exec mc-server-init -- java "${java_args[@]}"
