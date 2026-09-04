{
  buildPackages,
  callPackage,
  makeRustPlatform,
  rust,
  nix-update-script,
}:
let
  # Need to use the build platform rustc and Cargo so that
  # we don't infrec
  mkRustPlatform =
    args:
    makeRustPlatform (
      {
        inherit (buildPackages) rustc;
        cargo = buildPackages.cargo.override {
          auditable = false;
        };
      }
      // args
    );

  # The bootstrap build is needed to build Cargo, which is needed to build Git,
  # so no Git built by the from-source toolchain exists yet at this point.
  bootstrapRustPlatform = mkRustPlatform {
    gitMinimal = rust.packages.gitMinimalBootstrap;
  };

  # The final build happens once Git can be built from source, so it gets the
  # regular gitMinimal.
  rustPlatform = mkRustPlatform { };

  bootstrapBuilder = callPackage ./builder.nix {
    rustPlatform = bootstrapRustPlatform;
    auditable-bootstrap = bootstrap;
  };

  auditableBuilder = callPackage ./builder.nix {
    inherit rustPlatform;
    auditable-bootstrap = bootstrap;
  };

  version = "0.7.5";
  hash = "sha256-0VONJCv/msLcGenItWMLJ7DH79RTD6vsU9gX/nphh1g=";
  cargoHash = "sha256-/iAYib+xDQSJ8B559/V7b994ErSUGsPSDx64jFF5B6I=";

  # cargo-auditable cannot be built with cargo-auditable until cargo-auditable is built
  bootstrap = bootstrapBuilder {
    inherit version hash cargoHash;
    pname = "cargo-auditable-bootstrap";
    auditable = false;
  };
in
auditableBuilder {
  inherit version hash cargoHash;
  auditable = true;
  passthru.updateScript = nix-update-script { };
}
