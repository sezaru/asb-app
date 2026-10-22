# The agent-shell-bridge phone daemon. Its workspace path-deps roam-pake from a
# sibling repo (`../roam/roam-sync/...`). We reproduce that sibling layout in a
# single source tree and build from the asb-app subdir; roam must stay OUTSIDE
# asb-app's tree or cargo mis-attaches roam-pake to asb-app's workspace.
{
  rustPlatform,
  runCommandLocal,
  pkg-config,
  openssl,
  asb-app-src,
  roam-src,
}: let
  src = runCommandLocal "asb-sidecar-src" {} ''
    mkdir -p $out/asb-app $out/roam
    cp ${asb-app-src}/Cargo.toml ${asb-app-src}/Cargo.lock $out/asb-app/
    cp -r ${asb-app-src}/crates $out/asb-app/crates
    cp -r ${roam-src} $out/roam/roam-sync
  '';
in
  rustPlatform.buildRustPackage {
    pname = "asb-sidecar";
    version = "0.1.0";
    inherit src;
    sourceRoot = "asb-sidecar-src/asb-app";

    cargoLock.lockFile = "${asb-app-src}/Cargo.lock";

    nativeBuildInputs = [pkg-config];
    buildInputs = [openssl];

    cargoBuildFlags = ["-p" "asb-sidecar"];
    # Sidecar tests need a live network / host FS; nothing unit-testable here.
    doCheck = false;

    meta = {
      description = "agent-shell-bridge phone daemon (iroh)";
      mainProgram = "asb-sidecar";
    };
  }
