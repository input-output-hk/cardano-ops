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
  kes-rotation = crystal.buildCrystalPackage {
    pname = "kes-rotation";
    version = "0.1.0";
    src = cleanSourceWith {
      inherit filter;
      src = ./.;
      name = "kes-rotation";
    };
    format = "shards";
    crystalBinaries.kes-rotation.src = "src/kes-rotation.cr";
    shardsFile = ./shards.nix;
    buildInputs = [ openssl pkg-config ];
    doCheck = true;
    doInstallCheck = false;
  };
}
