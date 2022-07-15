{ lib, naersk, callPackage, src, version, ... }@args: contractFn:
let
  contracts' = contractFn {
    contract = subdir: name: features: {
      inherit subdir name features;
    };
  };

  contractDrv =
    { subdir
    , features ? [ ]
    , name
    }:
    let
      name' = lib.replaceChars [ "-" ] [ "_" ] subdir;
      src' = "${src}/runtime/near-test-contracts/${subdir}";
    in
    callPackage (_:naersk.buildPackage rec {
      pname = name;
      inherit version;
      src = src';

      cargoBuildOptions = x: (x ++ [ "--target=wasm32-unknown-unknown" ] ++ (lib.optional (features != [ ]) "--features=${lib.concatStringsSep "," features}"));

      copyBins = false;
      copyLibs = true;

      doCheck = false;

      postInstall = lib.optionalString (name' != name) ''
        ln -s $out/lib/${name'}.wasm $out/lib/${name}.wasm
      '';

      # TODO: ${placeholder "out"} returned neard nix store path!!!
      passthru.contractPath = "lib/${name}.wasm";
    });

  contracts = lib.listToAttrs (map
    (p: let
      built = contractDrv p { };
    in {
      inherit (p) name;
      value = "${built}/${built.contractPath}";
    })
    contracts');
in
contracts
