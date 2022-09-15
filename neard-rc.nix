{ fetchFromGitHub
, stdenv
, lib
, clang
, llvm
, llvmPackages
, openssl
, perl
, pkg-config
, protobuf
, rustPlatform
, CoreFoundation
, DiskArbitration
, Foundation
, IOKit
, Security
, features ? [ ]
}:
rustPlatform.buildRustPackage rec {
  pname = "neard-rc";
  version = "1.29.0-rc.3";

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
  nativeBuildInputs = [ clang llvm.out perl pkg-config protobuf ];

  OPENSSL_NO_VENDOR = 1; # we want to link to OpenSSL provided by Nix
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  buildAndTestSubdir = "neard";

  src = fetchFromGitHub {
    owner = "near";
    repo = "nearcore";
    rev = "refs/tags/${version}";
    hash = "sha256-VyED7mHM/lrcrTv4bz/ypXE4f8h8MHgcs7kTyC9ksSI=";
  };

  cargoPatches = [ ./patches/0001-make-near-test-contracts-optional.patch ];
  cargoHash = "sha256-n4m3mJLaaeVhNQM/pOD2iNVGYI6pwa8goX6YvQ59kYY=";

  postPatch = ''
    substituteInPlace neard/build.rs \
      --replace 'get_git_version()?' '"zentria-nix:${version}"'
  '';

  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_LTO = "thin";
  RUSTFLAGS = "-D warnings";
  NEAR_RELEASE_BUILD = "release";

  cargoBuildFlags = lib.optional (features != [ ]) "--features=${lib.concatStringsSep "," features}";
  doCheck = false; # tests only few CLI things

  meta = with lib; {
    platforms = platforms.linux ++ platforms.darwin;
    broken = stdenv.isAarch64 && !stdenv.isDarwin;
  };
}
