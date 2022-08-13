{
  description = "NEAR Protocol validator node & Docker image";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    docker-tools.url = "github:ZentriaMC/docker-tools";

    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
    docker-tools.inputs.nixpkgs.follows = "nixpkgs";
    docker-tools.inputs.flake-utils.follows = "flake-utils";
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
          rustPlatform = mkRustPlatform "stable" "1.61.0";
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation IOKit Security;
        };

        packages.neard-rc = pkgs.callPackage ./neard-rc.nix {
          rustPlatform = mkRustPlatform "stable" "1.61.0";
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation IOKit Security;
        };

        packages.neard-shardnet = pkgs.callPackage ./neard-shardnet.nix {
          rustPlatform = mkRustPlatform "stable" "1.63.0";
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation DiskArbitration Foundation IOKit Security;
        };

        packages.neardDockerImage = pkgs.callPackage
          ({ lib
           , runCommandNoCC
           , dockerTools
           , bash
           , cacert
           , coreutils
           , curl
           , dumb-init
           , iana-etc
           , neard
           , s5cmd
           , tzdata
           , name ? "neard"
           , tag ? neard.version
           }: dockerTools.buildLayeredImage {
            inherit name tag;
            config = {
              Env = [
                "PATH=/usr/bin"
                "HOME=/data"
              ];
              ExposedPorts = {
                "3030/tcp" = { };
                "24567/tcp" = { };
              };
              Volumes = {
                "/data" = { };
              };
              Labels = {
                "org.opencontainers.image.source" = "https://github.com/ZentriaMC/neard-nix";
              };
              Entrypoint = [ "/usr/bin/dumb-init" "--" ];
              Cmd = [ "neard" "--home" "/data" "--help" ];
            };

            contents =
              let
                inherit (docker-tools.lib) setupFHSScript symlinkCACerts;

                fhsScript = setupFHSScript {
                  inherit pkgs;
                  targetDir = "$out/usr";
                  paths = {
                    bin = [
                      bash
                      coreutils
                      curl
                      dumb-init
                      neard
                      s5cmd
                    ];
                  };
                };
              in
              [
                (runCommandNoCC "neard-nix-base" { } ''
                  mkdir -p $out/data

                  ${fhsScript}
                  ln -s usr/bin $out/bin
                  ln -s bin $out/usr/sbin
                  ln -s usr/bin $out/sbin
                  ln -s usr/lib $out/lib
                  ln -s usr/lib $out/lib64

                  ${symlinkCACerts { inherit cacert; targetDir = "$out"; }}

                  ln -s ${tzdata}/share/zoneinfo $out/etc/zoneinfo
                  ln -s /etc/zoneinfo/UTC $out/etc/localtime
                  echo "ID=distroless" > $out/etc/os-release
                  ln -s ${iana-etc}/etc/protocols $out/etc/protocols
                  ln -s ${iana-etc}/etc/services $out/etc/services
                '')
              ];
          })
          {
            inherit (packages) neard;
          };

        packages.neardRcDockerImage = (packages.neardDockerImage.override rec {
          neard = packages.neard-rc;
          name = "neard-rc";
          tag = neard.version;
        });

        packages.neardShardnetDockerImage = (packages.neardDockerImage.override rec {
          neard = packages.neard-shardnet;
          name = "neard-shardnet";
          tag = neard.version;
        });

        defaultPackage = packages.neard;

        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.curl
            pkgs.s5cmd
          ];
        };

        devShells.ci = pkgs.mkShell {
          buildInputs = [
            pkgs.cachix
            pkgs.jq
            pkgs.skopeo
          ];
        };
      });
}
