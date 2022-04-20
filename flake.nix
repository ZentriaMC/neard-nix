{
  description = "NEAR Protocol validator node & Docker image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    docker-tools.url = "github:ZentriaMC/docker-tools";

    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, docker-tools, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
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

        # https://rust-lang.github.io/rustup-components-history/
        mkRustPlatform = flavor: version:
          let
            toolchain = pkgs.rust-bin.${flavor}."${version}".minimal;
          in
          pkgs.makeRustPlatform {
            cargo = toolchain;
            rustc = toolchain;
          };
      in
      rec {
        packages.neard = pkgs.callPackage ./neard.nix {
          rustPlatform = mkRustPlatform "stable" "1.58.1";
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation IOKit Security;
        };

        packages.neard-rc = pkgs.callPackage ./neard-rc.nix {
          rustPlatform = mkRustPlatform "stable" "1.60.0";
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

        packages.neardRcDockerImage = (packages.neardDockerImage.override {
          neard = packages.neard-rc;
        }).overrideAttrs (oa: {
          name = "neard-rc";
        });

        defaultPackage = packages.neard;

        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.curl
            pkgs.s5cmd
          ];
        };
      });
}
