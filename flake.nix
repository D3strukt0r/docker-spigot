{
  description = "Spigot Minecraft server — Docker image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Shared OCI helpers (createdFromDate, fixOciImageHistory, secondsToNanos).
    nix-utils.url = "github:Team-MaRo/nix-utils";
    nix-utils.inputs.nixpkgs.follows = "nixpkgs";

    # Our PID-1 init (PTY console + named-pipe injection + signal→stop), built
    # from its own repo. The image bakes its binary in and execs it as PID 1.
    mc-server-init.url = "github:Team-MaRo/mc-server-init";
    mc-server-init.inputs.nixpkgs.follows = "nixpkgs";

    # Spigot jars are built + published by their own repo. We consume the
    # finished jar as a hash-pinned fetch (spigot-build pins the hash; we just
    # reference the version). Bump available versions/hashes with
    # `nix flake update spigot-build`.
    spigot-build.url = "github:Team-MaRo/spigot-build";
    spigot-build.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-utils, mc-server-init, spigot-build }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems
        (system: f (import nixpkgs { inherit system; }));

      dataDir = "/srv/spigot"; # FHS: site-specific data served by this system
      uid = "65532";

      # Per-Minecraft-version runtime JDK. The version→major mapping is owned by
      # spigot-build (`spigot-build.lib.jdkMajorFor`); here we only map the major
      # to a JRE. Major "16" is NOT here: nixpkgs ships no JDK 16 and Spigot
      # 1.17/1.17.1 reject Java 17+ at boot ("Only up to Java 16 is supported"),
      # so it needs a real Java 16 — handled by the `temurin16` fetch below.
      jdkForPkgs = pkgs: {
        "8" = pkgs.jdk8_headless;
        "17" = pkgs.jdk17_headless;
        "21" = pkgs.jdk21_headless;
        "25" = pkgs.jdk25_headless;
      };

      # docker/metadata-action labels (KEY=VAL\n…) serialised to JSON by CI and
      # read via `--impure`. This is the ONLY impure input — image metadata, not a
      # build artifact. Pure builds (no --impure) simply get no labels.
      labelsJson = builtins.getEnv "DOCKER_LABELS_JSON";
      labels = if labelsJson == "" then { } else builtins.fromJSON labelsJson;

      # Newest released version (semver), used for the `default`/`dockerImage`
      # outputs. Per-version images are also exposed as `packages.<sys>."<ver>"`.
      versions = spigot-build.lib.versions;
      latest =
        if versions == [ ] then null
        else nixpkgs.lib.last (builtins.sort (a: b: builtins.compareVersions a b < 0) versions);
    in
    {
      packages = forAllSystems (pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          jdkFor = jdkForPkgs pkgs;

          # Ship a runtime, not the full JDK (the ~680 MB headless JDK is mostly
          # jmods/ + dev tools + debug that a server never uses). Java 9+ → jlink a
          # runtime with EVERY module (ALL-MODULE-PATH) so any plugin still works;
          # only dev tools/jmods/debug are dropped. Java 8 predates jlink, so ship
          # the (comparatively small) headless JDK 8 as-is. Source stays nixpkgs
          # openjdk in both cases (single distributor, clean glibc closure). The
          # headless source keeps java.desktop's AWT libs (no X11) — required for
          # server-icon.png / map rendering.
          # jre_minimal takes both `jdk` (jmods to link) and `jdkOnBuild` (the
          # jlink binary). Override BOTH to our chosen JDK, else jlink defaults to
          # an older JDK and can't read newer jmods ("Unsupported major.minor
          # version"). Native per-arch builds, so jdkOnBuild == jdk is correct.
          #
          # jlink bakes the source JDK's store path into lib/modules, which would
          # drag the full ~680 MB JDK into the runtime closure. That path is
          # vestigial (the jlink image is self-contained; the launcher's
          # interpreter/RPATH point only at glibc/zlib), so scrub it with
          # remove-references-to and assert it's gone via disallowedReferences.
          # Major 8 (predates jlink) and 16 (already a jlinked+patched JRE —
          # temurin16Jre, built below) ship as-is; everything else is a nixpkgs
          # JDK that gets jlinked here to an ALL-MODULE-PATH runtime.
          mkJre = major: jdk:
            if major == "8" || major == "16" then jdk
            else
              let
                raw = pkgs.jre_minimal.override {
                  inherit jdk;
                  jdkOnBuild = jdk;
                  modules = [ "ALL-MODULE-PATH" ];
                };
              in
              pkgs.runCommand "spigot-jre-${major}"
                {
                  nativeBuildInputs = [ pkgs.removeReferencesTo ];
                  disallowedReferences = [ jdk ];
                } ''
                cp -r ${raw} $out
                chmod -R u+w $out
                find $out -type f -exec remove-references-to -t ${jdk} {} +
              '';

          # Our own PID-1 init, from the github:Team-MaRo/mc-server-init flake
          # (Minecraft-server-generic, so the same binary serves a Paper image
          # too). Unlike itzg's mc-server-runner it runs the server behind a PTY,
          # so the JLine console keeps the `>` prompt and line-editing; it still
          # forwards the terminal AND a named pipe into the console (interactive
          # `docker attach` + scripted `console <cmd>`, no RCON) and turns
          # SIGTERM / SIGINT / a typed Ctrl+C into a clean `stop` (graceful save
          # with the "Saving" logs), SIGKILL only after a timeout.
          mcServerInit = mc-server-init.packages.${system}.default;

          # `docker exec <c> console <cmd>` → inject a console command via the
          # named pipe mc-server-init feeds to the server's stdin (no RCON).
          console = pkgs.writeShellScriptBin "console" ''
            printf '%s\n' "$*" > /tmp/console-in
          '';

          inherit (nix-utils.lib.oci) secondsToNanos createdFromDate;
          fixHistoryScript = nix-utils.packages.${system}.fixOciImageHistory;

          # Java 16 for 1.17/1.17.1. nixpkgs (nixos-26.05) ships no JDK 16 and
          # those versions reject Java 17+ at boot ("Only up to Java 16 is
          # supported"). Adoptium published no standalone Temurin 16 JRE, so fetch
          # the JDK, autoPatchelf it to run in the minimal image (a build-time
          # tool only — never shipped), then jlink a proper JRE from it below.
          javaLibs = [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
            pkgs.alsa-lib
            pkgs.fontconfig.lib
            pkgs.freetype
            pkgs.cups.lib
            pkgs.xorg.libX11
            pkgs.xorg.libXext
            pkgs.xorg.libXi
            pkgs.xorg.libXrender
            pkgs.xorg.libXtst
          ];
          temurin16Jdk =
            let
              sel = {
                "x86_64-linux" = { arch = "x64"; hash = "sha256-Mj1tdHSjWaKO/33dDfjmW9YVVKjtEu9C/ZNlNJ5XPCw="; };
                "aarch64-linux" = { arch = "aarch64"; hash = "sha256-y3fZ0Sb5eJjf3ItftpTR4OXZPROgpssq7advhjU4Q0A="; };
              }.${system};
            in
            pkgs.stdenv.mkDerivation {
              pname = "temurin-jdk-bin";
              version = "16.0.2+7";
              src = pkgs.fetchurl {
                url = "https://github.com/adoptium/temurin16-binaries/releases/download/jdk-16.0.2%2B7/OpenJDK16U-jdk_${sel.arch}_linux_hotspot_16.0.2_7.tar.gz";
                hash = sel.hash;
              };
              nativeBuildInputs = [ pkgs.autoPatchelfHook ];
              buildInputs = javaLibs;
              dontConfigure = true;
              dontBuild = true;
              installPhase = ''
                runHook preInstall
                mkdir -p $out
                cp -a . $out/
                runHook postInstall
              '';
            };

          # Ship a JRE, not the full JDK: jlink an ALL-MODULE-PATH runtime (every
          # module → any plugin works) from the patched JDK, then autoPatchelf it
          # (the launcher/libs come from the JDK's jmods, so they carry Adoptium's
          # interpreter/RPATH and need re-patching) and scrub the JDK store path
          # jlink bakes into lib/modules, so the full JDK stays out of the closure.
          # This mirrors mkJre's jlink path for the nixpkgs JDKs (9+).
          temurin16Jre = pkgs.stdenv.mkDerivation {
            name = "spigot-jre-16";
            dontUnpack = true;
            # mkDerivation (not runCommand) so the fixup phase runs autoPatchelfHook
            # over the jlink output — runCommand skips fixup, leaving the launcher's
            # interpreter unpatched ("no such file or directory" on exec).
            nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.removeReferencesTo ];
            buildInputs = javaLibs;
            disallowedReferences = [ temurin16Jdk ];
            installPhase = ''
              runHook preInstall
              # No --compress: jlink bakes the JDK store path into lib/modules,
              # and remove-references-to below rewrites it in place (same length →
              # offsets stay valid). Compressing would put that path inside a
              # compressed blob, so the byte-rewrite corrupts it → SIGSEGV at boot.
              ${temurin16Jdk}/bin/jlink \
                --module-path ${temurin16Jdk}/jmods \
                --add-modules ALL-MODULE-PATH \
                --strip-debug --no-man-pages --no-header-files \
                --output $out
              chmod -R u+w $out
              find $out -type f -exec remove-references-to -t ${temurin16Jdk} {} +
              runHook postInstall
            '';
          };

          # The Nix minimal image ships no distro release files, so the JVM
          # (oshi/JNA, crash reports) logs "File not found or not readable:
          # /etc/os-release" / "/etc/lsb-release" on every boot. nixpkgs has no
          # prebuilt os-release package (only the NixOS module generates one), so
          # provide them declaratively — same writeTextDir approach NixOS uses —
          # with VERSION_ID taken from nixpkgs rather than hardcoded.
          osReleaseFiles = pkgs.symlinkJoin {
            name = "spigot-os-release";
            paths = [
              (pkgs.writeTextDir "etc/os-release" ''
                NAME="Spigot (Nix)"
                ID=spigot
                PRETTY_NAME="d3strukt0r/spigot (Nix-built minimal image)"
                VERSION_ID="${nixpkgs.lib.trivial.release}"
                BUILD_ID="${nixpkgs.lib.trivial.version}"
                HOME_URL="https://github.com/Team-MaRo/docker-spigot"
              '')
              (pkgs.writeTextDir "etc/lsb-release" ''
                DISTRIB_ID=Spigot
                DISTRIB_RELEASE="${nixpkgs.lib.trivial.release}"
                DISTRIB_DESCRIPTION="d3strukt0r/spigot (Nix-built minimal image)"
              '')
            ];
          };

          # Build the image for one Minecraft version. The jar is the pinned fetch
          # from spigot-build (no impure path); the runtime JDK is chosen from the
          # version via spigot-build.lib.jdkMajorFor.
          mkImage = version:
            let
              javaMajor = spigot-build.lib.jdkMajorFor version;
              # Major 16 is already a jlinked JRE (temurin16Jre); mkJre ships it
              # as-is. Everything else is a nixpkgs JDK that mkJre jlinks.
              jdkBase = if javaMajor == "16" then temurin16Jre
                        else jdkFor.${javaMajor} or pkgs.jdk25_headless;
              jre = mkJre javaMajor jdkBase;

              # The entrypoint with its runtime PATH baked in (java/yq/coreutils/
              # grep + mc-server-init). writeShellApplication shellchecks it.
              entrypoint = pkgs.writeShellApplication {
                name = "spigot-entrypoint";
                runtimeInputs = [ jre pkgs.yq-go pkgs.coreutils pkgs.gnugrep pkgs.bashInteractive mcServerInit ];
                text = builtins.readFile ./src/entrypoint.sh;
              };

              # Bake the (pinned) jar at /opt/spigot.jar — an image layer, never in
              # the data volume, so it is not on the host.
              jarLayer = pkgs.runCommand "spigot-jar-layer" { } ''
                mkdir -p $out/opt
                cp ${spigot-build.legacyPackages.${system}.spigotJar.${version}} $out/opt/spigot.jar
              '';

              dockerImageStream = pkgs.dockerTools.streamLayeredImage {
                name = "d3strukt0r/spigot";
                tag = version;
                created = createdFromDate self.lastModifiedDate;

                contents = [
                  pkgs.dockerTools.usrBinEnv
                  (pkgs.dockerTools.fakeNss.override {
                    extraPasswdLines = [ "nonroot:x:65532:65532:nonroot:${dataDir}:/sbin/nologin" ];
                    extraGroupLines = [ "nonroot:x:65532:" ];
                  })
                  pkgs.bashInteractive
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.yq-go
                  jre
                  # libudev for the bundled oshi/JNA. Listed as a content so its lib/
                  # is merged into /lib alongside the JRE's libs (same as every other
                  # package here) — oshi then finds it by name with no env var, flag,
                  # or hand-made symlink. Otherwise it would sit only in /nix/store,
                  # which nothing scans. Without it oshi logs "Did not find udev".
                  pkgs.systemdLibs
                  osReleaseFiles
                  entrypoint
                  console
                  jarLayer
                ];

                # The data dir is the server working directory and the single
                # persistence volume; it must be writable by the nonroot user.
                # /etc/profile.d is made writable too so the entrypoint can drop
                # spigot-env.sh there (the resolved env, for `docker exec … sh -l`);
                # the nix image ships no /etc/profile, so we add one that sources it.
                enableFakechroot = true;
                fakeRootCommands = ''
                  mkdir -p .${dataDir}
                  chown -R ${uid}:${uid} .${dataDir}
                  chown ${uid}:${uid} etc/profile.d
                '';
                extraCommands = ''
                  mkdir -p tmp
                  chmod 1777 tmp
                  mkdir -p etc/profile.d
                  printf '%s\n' 'for f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done' > etc/profile
                '';

                config = {
                  User = "${uid}:${uid}";
                  WorkingDir = dataDir;
                  Entrypoint = [ "${entrypoint}/bin/spigot-entrypoint" ];
                  Env = [
                    "HOME=${dataDir}"
                    "JVM_FLAGS_PRESET=aikars"
                    "JAVA_MAJOR=${javaMajor}"
                    "PATH=/bin:/usr/bin"
                    # 🐳 prompt for `docker exec -it … bash`. Bash keeps an inherited
                    # PS1 (only sets its default when PS1 is unset), so no rc file is
                    # needed. <green> user@host <normal> : <blue> dir <normal> $
                    ''PS1=🐳 \e[38;5;10m\u@\h\e[0m:\e[38;5;12m\w\e[0m\$ ''
                  ];
                  ExposedPorts = { "25565/tcp" = { }; };
                  Volumes = { "${dataDir}" = { }; };
                  # /dev/tcp is a bash feature, so invoke bash explicitly rather than
                  # via CMD-SHELL (/bin/sh — which here is only a symlink to bash).
                  # Opening the socket exits 0 if the port is accepting, which proves
                  # the port is open, not that worlds/plugins finished loading.
                  Healthcheck = {
                    Test = [ "CMD" "bash" "-c" "exec 3<>/dev/tcp/localhost/25565" ];
                    Interval = secondsToNanos 30;
                    Timeout = secondsToNanos 5;
                    StartPeriod = secondsToNanos 120;
                  };
                  Labels = labels;
                };
              };
            in
            pkgs.runCommand "spigot-image-${version}.tar" { } ''
              ${dockerImageStream} | ${fixHistoryScript} > $out
            '';

          # One image per released version: `nix build --impure .#"26.1.2"`.
          perVersion = nixpkgs.lib.genAttrs versions mkImage;
        in
        perVersion // nixpkgs.lib.optionalAttrs (latest != null) {
          default = perVersion.${latest};
          dockerImage = perVersion.${latest}; # convenience alias for the newest
        });

      # CI helper: the image build matrix (each released version × its runtime
      # JDK) derived from the PINNED spigot-build input — so it matches exactly
      # what `nix build .#"<ver>"` will build. Read with `nix eval --json .#imageMatrix`.
      imageMatrix = builtins.map (v: { spigot = v; java = spigot-build.lib.jdkMajorFor v; }) versions;
    };
}
