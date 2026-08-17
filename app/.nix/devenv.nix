{
  config,
  inputs,
  pkgs,
  ...
}: let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.system};

  fenix = inputs.fenix.packages.${pkgs.stdenv.system};

  # One toolchain carrying the host std plus the three Android ABIs Flutter
  # ships. `combine` is what makes that possible — there is no rustup here to
  # add a target after the fact.
  #
  # Note there is no aarch64-linux Android *emulator*, but cross-compiling to
  # these targets works from either host; only running an emulator needs x86_64.
  rustToolchain = fenix.combine [
    fenix.stable.rustc
    fenix.stable.cargo
    fenix.stable.clippy
    fenix.stable.rustfmt
    fenix.stable.rust-src
    fenix.targets.aarch64-linux-android.stable.rust-std
    fenix.targets.armv7-linux-androideabi.stable.rust-std
    fenix.targets.x86_64-linux-android.stable.rust-std
  ];
in {
  imports = [
    inputs.devkit.devenvModule
  ];

  # Keep cargo's downloads and the bridge's build artifacts inside the project.
  # The build tree is deliberately NOT shared with the asb-app workspace's own
  # target/: cargo fingerprints include rustc identity, so a second toolchain
  # pointed at the same directory invalidates every artifact in it.
  env = {
    CARGO_HOME = "${config.env.DEVENV_STATE}/cargo";
    CARGO_TARGET_DIR = "${config.env.DEVENV_STATE}/rust-target";
    # cargo-ndk reads ANDROID_NDK_HOME; devkit exports ANDROID_NDK_ROOT.
    ANDROID_NDK_HOME = "${config.env.ANDROID_NDK_ROOT}";
    # roam-pake is pulled as a path dep from ~/projects/roam; if that ever moves
    # to a git dep, cargo's bundled libgit2 cannot talk to ssh-agent, so hand
    # the fetch to the git CLI.
    CARGO_NET_GIT_FETCH_WITH_CLI = "true";
  };

  # The asb_client bridge toolchain.
  packages = [
    rustToolchain
    # Wraps the NDK's clang/ar/linker per target. Doing it by hand means three
    # sets of CC_<target>/AR_<target>/CARGO_TARGET_<TARGET>_LINKER variables,
    # and getting them wrong fails deep inside `ring`'s build script with
    # "unrecognized command-line option '-mthumb'" rather than anywhere useful.
    unstable.cargo-ndk
    unstable.flutter_rust_bridge_codegen
    # flutter_rust_bridge_codegen shells out to `cargo expand` to read the API
    # module after macro expansion. Declared here rather than left to codegen's
    # auto-install path, which builds an unpinned version into CARGO_HOME.
    unstable.cargo-expand
  ];

  modules.flutter = {
    enable = true;

    android = {
      enable = true;
      emulator.enable = true;
    };
  };

  # `android/gradlew` is generated and gitignored, and its shebang gets patched
  # to an absolute /nix/store bash. That path is specific to the machine that
  # patched it, so a gradlew that arrives from somewhere else — an rsync to a
  # build box, a restored backup, a shared checkout — names an interpreter that
  # does not exist here. exec then fails with "No such file or directory"
  # naming *gradlew*, not the missing interpreter.
  #
  # Heal only that case: rewrite the shebang when it points at a store path that
  # is gone. A shebang this machine patched itself still resolves, so it is left
  # alone rather than being clobbered on every shell entry.
  enterShell = ''
    gradlew="$DEVENV_ROOT/android/gradlew"
    if [ -f "$gradlew" ]; then
      interpreter=$(head -1 "$gradlew" | sed -n 's|^#!\([^ ]*\).*|\1|p')
      case "$interpreter" in
        /nix/store/*)
          if [ ! -x "$interpreter" ]; then
            sed -i '1s|.*|#!/usr/bin/env bash|' "$gradlew"
            echo "devenv: repointed android/gradlew at a live interpreter (was a stale store path)"
          fi
          ;;
      esac
    fi
  '';
}
