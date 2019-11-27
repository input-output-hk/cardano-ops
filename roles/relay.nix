
{pkgs, ...} : {

  environment.systemPackages = [ pkgs.cardano-cli ];

  imports = [
    ../modules/base-service.nix
  ];

}
