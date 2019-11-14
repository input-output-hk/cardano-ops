{ name
, ...
}:
with import ../nix {};
{

  imports = [
    ../modules/common.nix
    (sourcePaths.cardano-byron-proxy + "/nix/nixos")
  ];

  services.byron-proxy = {
    enable = true;
    environment = globals.environment;
    nodeId = name;
    pbftThreshold = "0.9";
    proxyHost = "0.0.0.0";
  };
}
