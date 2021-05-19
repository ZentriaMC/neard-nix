{ pkgs ? import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/c58b97674b12d238d9d21e8ab9ee9d7a6b81ae8f.tar.gz") { }
, ...
}:
pkgs.callPackage ./default.nix { }
