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
    inherit cardanoLib;
    environment = globals.environment;
    nodeId = name;
    proxyHost = "0.0.0.0";
  };
}
