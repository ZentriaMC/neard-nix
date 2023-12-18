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
stdenv.mkDerivation rec {
  pname = "neard";
  version = "1.36.2";

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
  nativeBuildInputs = [ rustPlatform.cargoSetupHook clang llvm.out perl pkg-config protobuf ];

  OPENSSL_NO_VENDOR = 1; # we want to link to OpenSSL provided by Nix
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  buildAndTestSubdir = "neard";

  src = fetchFromGitHub {
    owner = "near";
    repo = "nearcore";
    rev = "refs/tags/${version}";
    hash = "sha256-7jP6NomoAxFoEszCXZsKHeFQmygA7Yx6DFxma/ZoZJM=";
  };

  cargoDeps = rustPlatform.importCargoLock {
    lockFile = ./patches/1.36.2/Cargo.lock;
    outputHashes = {
      "protobuf-3.0.2" = "sha256-HVNlMXZRNa9F8hr6sj75uuCvppR6mVOSumSLnye/F3Y=";
    };
  };

  patches = [ ./patches/1.36.2/0001-Make-near-test-contracts-optional.patch ];

  postPatch = ''
    substituteInPlace neard/build.rs \
      --replace 'get_git_version()?' '"zentria-nix:${version}"'
  '';

  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_LTO = "thin";
  RUSTFLAGS = "-D warnings";
  NEAR_RELEASE_BUILD = "release";

  buildPhase = ''
    runHook preBuild

    cargo build -p $buildAndTestSubdir --release $cargoBuildFlags

    runHook postBuild
  '';

  cargoBuildFlags = lib.optional (features != [ ]) "--features=${lib.concatStringsSep "," features}";
  doCheck = false; # tests only few CLI things

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/neard --version

    runHook postInstallCheck
  '';

  meta = with lib; {
    platforms = platforms.linux ++ platforms.darwin;
    broken = stdenv.isAarch64 && !stdenv.isDarwin;
  };
}
