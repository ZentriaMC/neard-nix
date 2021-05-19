{ pkgs
, stdenv
, lib
, clang
, llvm
, llvmPackages
, openssl
, perl
, pkg-config
, rustPlatform
, rustc
  #, wasm-rustc ? (rustc.override {
  #    stdenv = pkgs.stdenv.override {
  #      targetPlatform = {
  #        isRedox = false;
  #        parsed = {
  #          cpu = { name = "wasm32"; };
  #          vendor = { name = "unknown"; };
  #          kernel = { name = "unknown"; };
  #          abi = { name = "unknown"; };
  #        };
  #      };
  #    };
  #  })
}:
rustPlatform.buildRustPackage rec {
  pname = "neard";
  version = "1.19.0";

  buildInputs = [ llvm openssl ];
  nativeBuildInputs = [ clang llvm.out perl pkg-config ];

  LIBCLANG_PATH = "${llvmPackages.libclang}/lib";
  buildAndTestSubdir = "neard";

  src = pkgs.fetchFromGitHub {
    owner = "near";
    repo = "nearcore";
    rev = version;
    sha256 = "0y3ads73nqdr4hmqzff7030l3hrwidns13dvjp9nhh366ca7ig6z";
  };

  # Concatenate all lockfiles so all needed dependencies end up being vendored
  #cargoUpdateHook = ''
  #  find . -name Cargo.lock -type f -print0 | xargs -0 cat > Cargo_new.lock
  #  mv Cargo_new.lock Cargo.lock
  #'';

  patches = [
    # runtime/near-test-contracts/build.rs calls `rustup target add wasm32-unknown-unknown` - this
    # derivation provides a wasm32 toolchain on its own.
    ./remove-rustup-call.patch
  ];

  cargoSha256 = "0hmnq7sii0hspbghi75nax8jdnv1dqv3jjsbkys57sjq8w1g47yz";

  # WARNING 2021-05-16: takes ram massively, >14GiB for purely linking (debug build)!
  doCheck = false;
}
