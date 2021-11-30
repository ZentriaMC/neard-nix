{
  description = "eteu-near-contract";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    let
      # https://rust-lang.github.io/rustup-components-history/
      rustVersion = "1.56.0";
      supportedSystems = [
        # NOTE(2021-11-30): Does not build on aarch64-darwin (nor aarch64-linux), use --system x86_64-darwin
        # > Compiling wasmer-compiler-near v2.0.3
        # > error[E0425]: cannot find function `get_fault_info` in this scope
        # >    --> /private/tmp/nix-build-neard-1.23.0-rc.1.drv-0/neard-1.23.0-rc.1-vendor.tar.gz/wasmer-runtime-core-near/src/fault.rs:304:21
        # >     |
        # > 304 |         let fault = get_fault_info(siginfo as _, ucontext);
        # >     |                     ^^^^^^^^^^^^^^ not found in this scope
        #"aarch64-darwin"
        #"aarch64-linux"
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

        rustToolchain = pkgs.rust-bin.stable."${rustVersion}".minimal;

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
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation IOKit Security;
        };

        defaultPackage = packages.neard;
      });
}
