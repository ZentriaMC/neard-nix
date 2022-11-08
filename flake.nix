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
  };

  nixConfig = {
    extra-substituters = [ "https://zentria-near.cachix.org" ];
    extra-trusted-substituters = [ "https://zentria-near.cachix.org" ];
    extra-trusted-public-keys = [ "zentria-near.cachix.org-1:BKvOv13hKSkWX5RZpLs9Da5b5ZCySBdYFWukCvR5YVY=" ];
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
          rustPlatform = mkRustPlatform "stable" "1.68.2";
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation DiskArbitration Foundation IOKit Security;
        };

        packages.neard-rc = pkgs.callPackage ./neard-rc.nix {
          rustPlatform = mkRustPlatform "stable" "1.69.0";
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
           , jq
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
                "org.opencontainers.image.revision" = self.rev or "dirty";
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
                      jq
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

        cargoDeps =
          let
            allDeps' = map
              (p:
                let
                  pkg = packages.${p};
                in
                if (pkg ? cargoDeps)
                then { name = p; value = pkg.cargoDeps; }
                else null
              )
              (builtins.attrNames packages);
          in
          builtins.listToAttrs
            (builtins.filter (p: p != null) allDeps');

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
            pkgs.cosign
          ];
        };
      });
}
