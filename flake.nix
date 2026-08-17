{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = {
    self,
    nixpkgs,
  }: let
    forAll = f:
      nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux"]
      (system: f nixpkgs.legacyPackages.${system});
  in {
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
