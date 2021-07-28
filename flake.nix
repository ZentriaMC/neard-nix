{
  description = "eteu-near-contract";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:mikroskeem/rust-overlay/enable-aarch64-darwin";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    let
      # https://rust-lang.github.io/rustup-components-history/
      rustVersion = "2021-07-27";
      supportedSystems = [
# NOTE(2021-07-28): Does not build on aarch64-darwin, use --system x86_64-darwin
# > error[E0425]: cannot find function `get_fault_info` in this scope
# >    --> /private/tmp/nix-build-neard-1.19.2.drv-0/neard-1.19.2-vendor.tar.gz/wasmer-runtime-core-near/src/fault.rs:289:21
# >     |
# > 289 |         let fault = get_fault_info(siginfo as _, ucontext);
# >     |                     ^^^^^^^^^^^^^^ not found in this scope
        #"aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rustToolchain = pkgs.rust-bin.nightly."${rustVersion}".minimal;

        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };
      in
      rec {
        devShell = pkgs.mkShell {
          buildInputs = [
            rustToolchain
          ];
        };

        packages.neard = pkgs.callPackage ./default.nix {
          inherit rustPlatform;
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation IOKit;
        };

        defaultPackage = packages.neard;
      });
}
