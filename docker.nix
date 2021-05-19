{ pkgs ? import <nixpkgs> { } }:
let
  neard = import ./neard.nix { pkgs = pkgs; };
in
pkgs.dockerTools.buildImage {
  name = "neard-docker";
  config = {
    Entrypoint = [ "${pkgs.dumb-init}/bin/dumb-init" "--" ];
    Cmd = [ "${neard}/bin/neard" "--help" ];
  };
}
