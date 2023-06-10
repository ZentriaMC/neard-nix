{ fetchFromGitHub
, stdenv
, lib
, clang
, llvm
, llvmPackages
, mold
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
  version = "1.34.0-rc.2";

  buildInputs = [
    llvm
    llvmPackages.libclang.lib
    mold
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
    hash = "sha256-KMfd07fPu4LGskCceQjMzq3veZ50d+5Jv5n8ELQnQ8k=";
  };

  cargoPatches = [ ./patches/1.34.0/0001-Make-near-test-contracts-optional.patch ];
  cargoHash = "sha256-HB5PR4K3/lj315CQ6NSj16QGGewzoHI3MR4AghYpBBs=";

  postPatch = ''
    substituteInPlace neard/build.rs \
      --replace 'get_git_version()?' '"zentria-nix:${version}"'
  '';

  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_LTO = "thin";

  CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "clang";
  RUSTFLAGS = ["-D" "warnings"] ++ lib.optionals (!stdenv.isDarwin) [
    "-C" "link-arg=-fuse-ld=${mold}/bin/mold"
  ];
  NEAR_RELEASE_BUILD = "release";

  cargoBuildFlags = lib.optional (features != [ ]) "--features=${lib.concatStringsSep "," features}";
  doCheck = false; # tests only few CLI things

  meta = with lib; {
    platforms = platforms.linux ++ platforms.darwin;
    broken = stdenv.isAarch64 && !stdenv.isDarwin;
  };
}
