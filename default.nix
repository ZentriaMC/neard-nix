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
, CoreFoundation
, IOKit
}:
rustPlatform.buildRustPackage rec {
  pname = "neard";
  version = "1.23.0-rc.1";

  buildInputs = [
    llvm
    llvmPackages.libclang.lib
    openssl
  ] ++ lib.optionals stdenv.isDarwin [
    CoreFoundation
    IOKit
  ];
  nativeBuildInputs = [ clang llvm.out perl pkg-config ];

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  buildAndTestSubdir = "neard";

  src = fetchFromGitHub {
    owner = "near";
    repo = "nearcore";
    rev = version;
    sha256 = "sha256-hM2g1+dax27osNmalaP+VTqT35F73alrdlmIfBcXgo4=";
  };

  cargoSha256 = "sha256-TXDQ1f5YaOQeIL4ZqZFw4keQkawKHffM5jXhPlYQHiM=";

  # WARNING 2021-05-16: takes ram massively, >14GiB for purely linking (debug build)!
  # NOTE 2021-07-22: vendoring seems to be broken
  #    error: failed to run custom build command for `near-test-contracts v0.0.0 (/build/source/runtime/near-test-contracts)`
  #
  #    Caused by:
  #      process didn't exit successfully: `/build/source/target/release/build/near-test-contracts-e7d9e8d0fe5c3dd3/build-script-build` (exit status: 1)
  #      --- stderr
  #      error: failed to select a version for the requirement `serde_json = "=1.0.62"`
  #      candidate versions found which didn't match: 1.0.63
  #      location searched: directory source `/build/neard-1.19.2-vendor.tar.gz` (which is replacing registry `https://github.com/rust-lang/crates.io-index`)
  #      required by package `test-contract-rs v0.1.0 (/build/source/runtime/near-test-contracts/test-contract-rs)`
  #      perhaps a crate was updated and forgotten to be re-vendored?
  #      command `"cargo" "build" "--target=wasm32-unknown-unknown" "--release"` exited with non-zero status: ExitStatus(ExitStatus(25856))
  doCheck = false;

  meta = with lib; {
    platforms = platforms.linux ++ platforms.darwin;
  };
}
