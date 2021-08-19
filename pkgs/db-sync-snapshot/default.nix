{ callPackage
, crystal
, lib
, openssl
, pkg-config
}:

let
  inherit (lib) cleanSourceWith hasSuffix removePrefix;
  filter = name: type: let
    baseName = baseNameOf (toString name);
    sansPrefix = removePrefix (toString ../.) name;
  in (
    baseName == "src" ||
    hasSuffix ".cr" baseName ||
    hasSuffix ".yml" baseName ||
    hasSuffix ".lock" baseName ||
    hasSuffix ".nix" baseName
  );
in {
  db-sync-snapshot = crystal.buildCrystalPackage {
    pname = "db-sync-snapshot";
    version = "0.1.0";
    src = cleanSourceWith {
      inherit filter;
      src = ./.;
      name = "db-sync-snapshot";
    };
    format = "shards";
    crystalBinaries.db-sync-snapshot.src = "src/db-sync-snapshot.cr";
    shardsFile = ./shards.nix;
    buildInputs = [ openssl pkg-config ];
    doCheck = true;
    doInstallCheck = false;
  };
}
