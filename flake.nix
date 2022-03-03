{
  description = "NEAR Protocol validator node & Docker image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    docker-tools.url = "github:ZentriaMC/docker-tools";
    crane.url = "github:ipetkov/crane";

    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
    crane.inputs.nixpkgs.follows = "nixpkgs";
    crane.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, docker-tools, crane, ... }:
    let
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

        # https://rust-lang.github.io/rustup-components-history/
        mkRust' = flavor: version: pkgs.rust-bin.${flavor}."${version}".minimal;

        mkRustPlatform = flavor: version:
          let
            toolchain = mkRust' flavor version;
          in
          pkgs.makeRustPlatform {
            cargo = toolchain;
            rustc = toolchain;
          };
      in
      rec {
        packages.neard = pkgs.callPackage ./default.nix {
          rustPlatform = mkRustPlatform "stable" "1.57.0";
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation IOKit Security;
        };

        packages.neard-rc = pkgs.callPackage ./neard-rc.nix {
          crane = crane.lib.${system}.overrideScope' (super: self: {
            cargo = mkRust' "stable" "1.57.0";
          });
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation IOKit Security;
        };

        packages.neardDockerImage = pkgs.callPackage
          ({ lib, cacert, dockerTools, dumb-init, neard }: dockerTools.buildLayeredImage {
            name = "neard";
            config = {
              Env = [
                "PATH=${lib.makeBinPath [ dumb-init neard ]}"
                "HOME=/data"
              ];
              ExposedPorts = {
                "3030/tcp" = { };
                "24567/tcp" = { };
              };
              Volumes = {
                "/data" = { };
              };
              Entrypoint = [ "${dumb-init}/bin/dumb-init" "--" ];
              Cmd = [ "neard" "--home" "/data" "--help" ];
            };

            extraCommands = ''
              mkdir -p data
              ${docker-tools.lib.symlinkCACerts { inherit cacert; }}
            '';
          })
          {
            inherit (packages) neard;
          };

        packages.neardRcDockerImage = packages.neardDockerImage.override {
          neard = packages.neard-rc;
        };

        defaultPackage = packages.neard;
      });
}
