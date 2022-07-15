{ fetchFromGitHub
, stdenv
, lib
, clang
, llvm
, llvmPackages
, openssl
, perl
, pkg-config
, rustPlatform
, naersk
, callPackage
, CoreFoundation
, DiskArbitration
, Foundation
, IOKit
, Security
, features ? [ "shardnet" ]
}:
rustPlatform.buildRustPackage rec {
  pname = "neard-shardnet";
  version = "a6abf60122ce769f111823b5c1408777040cf0d6";

  buildInputs = [
    llvm
    llvmPackages.libclang.lib
    openssl
  ] ++ lib.optionals stdenv.isDarwin [
    CoreFoundation
    DiskArbitration
    Foundation
    IOKit
    Security
  ];
  nativeBuildInputs = [ clang llvm.out perl pkg-config ];

  OPENSSL_NO_VENDOR = 1; # we want to link to OpenSSL provided by Nix
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  buildAndTestSubdir = "neard";

  src = fetchFromGitHub {
    owner = "near";
    repo = "nearcore";
    rev = version;
    sha256 = "sha256-Y/1jpVD6xUJPez0BNrguCByd41eLCtn62S+iNmk+shQ=";
  };

  #cargoPatches = [ ./patches/0001-make-near-test-contracts-optional.patch ];
  #cargoSha256 = "sha256-DHxX1s4sK5ungQqSGiz4Ptk7n0I+7MrWvMJLjs9UFYw=";
  cargoSha256 = "sha256-GQ6afHak8GkEsw2ksFzU1RzHZYnKU8DLgt/mcUwDMSw=";

  postPatch = ''
    substituteInPlace neard/build.rs \
      --replace 'get_git_version()?' '"nix:${version}"'

    substituteInPlace runtime/near-test-contracts/build.rs \
      --replace 'fn try_main() -> Result<(), Error> {' 'fn try_main_DISABLED() -> Result<(), Error> {'

    echo 'fn try_main() -> Result<(), Error> { Ok(()) }' >> runtime/near-test-contracts/build.rs

    pushd runtime/near-test-contracts/res
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "ln -s ${v} ${k}.wasm") passthru.contracts)}
    popd
  '';

  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_LTO = "thin";
  RUSTFLAGS = "-D warnings";
  NEAR_RELEASE_BUILD = "release";

  cargoBuildFlags = lib.optional (features != [ ]) "--features=${lib.concatStringsSep "," features}";

  passthru.contracts = import ./misc/build-test-contracts.nix { inherit lib naersk callPackage src version; } ({ contract, ... }: [
    (contract "test-contract-rs" "test_contract_rs" [ "latest_protocol" ])
    (contract "test-contract-rs" "base_test_contract_rs" [ ])
    (contract "test-contract-rs" "nightly_test_contract_rs" [ "latest_protocol" "nightly" ])
    (contract "contract-for-fuzzing-rs" "contract_for_fuzzing_rs" [ ])
    (contract "estimator-contract" "stable_estimator_contract" [ ])
    (contract "estimator-contract" "nightly_estimator_contract" [ "nightly" ])
  ]);

  # WARNING 2021-05-16: takes ram massively, >14GiB for purely linking (debug build)!
  doCheck = true;

  meta = with lib; {
    platforms = platforms.linux ++ platforms.darwin;
    broken = stdenv.isAarch64 && !stdenv.isDarwin;
  };
}
