{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # The sidecar's workspace path-deps roam-pake from a sibling roam checkout.
  inputs.roam = {
    url = "github:Hexhound/roam";
    flake = false;
  };
  outputs = {
    self,
    nixpkgs,
    roam,
  }: let
    forAll = f:
      nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux"]
      (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = forAll (pkgs: {
      asb-sidecar = pkgs.callPackage ./nix/sidecar.nix {
        asb-app-src = self;
        roam-src = roam;
      };
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.asb-sidecar;
    });

    devShells = forAll (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.cargo
          pkgs.rustc
          pkgs.rust-analyzer
          pkgs.clippy
          pkgs.rustfmt
          pkgs.pkg-config
          pkgs.openssl
        ];
        PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
        RUST_BACKTRACE = "1";
      };
    });
  };
}
