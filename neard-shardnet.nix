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
, DiskArbitration
, Foundation
, IOKit
, Security
, features ? [ "shardnet" ]
}:
rustPlatform.buildRustPackage rec {
  pname = "neard-shardnet";
  version = "0f81dca95a55f975b6e54fe6f311a71792e21698";

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
    hash = "sha256-DashyY5fmAj4Q2DJL326MGZDiLb3tBkxuj572eCBTyI=";
  };

  cargoPatches = [ ./patches/0001-make-near-test-contracts-optional.patch ];
  cargoHash = "sha256-1UXhN+gyErnln8yv7fHsGPu632EFHGti9HyQ2500+mE=";

  postPatch = ''
    substituteInPlace neard/build.rs \
      --replace 'get_git_version()?' '"nix:${version}"'
  '';

  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_LTO = "thin";
  RUSTFLAGS = "-D warnings";
  NEAR_RELEASE_BUILD = "release";

  cargoBuildFlags = lib.optional (features != [ ]) "--features=${lib.concatStringsSep "," features}";

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
    broken = stdenv.isAarch64 && !stdenv.isDarwin;
  };
}
