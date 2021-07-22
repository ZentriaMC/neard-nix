{ rust-overlay ? import (builtins.fetchTarball "https://github.com/oxalica/rust-overlay/archive/6c425e7d49f186862460bb5c7d6a0df1a43db3e0.tar.gz")
, pkgs ? import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/f102bcee7d1f3f607ad502dfe346f4d4066e534a.tar.gz") { overlays = [ rust-overlay ]; }
, ...
}:
let
  rustVersion = "2021-07-14";
  wasmRust = (pkgs.rust-bin.nightly."${rustVersion}".default.override {
    targets = [ "wasm32-unknown-unknown" ];
  });
  rustPlatform = pkgs.makeRustPlatform {
    cargo = wasmRust;
    rustc = wasmRust;
  };
in
pkgs.callPackage ./default.nix { inherit rustPlatform; }
