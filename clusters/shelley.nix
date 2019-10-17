pkgs:
{ targetEnv
, tiny, large
}:
let

  inherit (pkgs) sources lib iohk-ops-lib;
  inherit (lib) recursiveUpdate mapAttrs;
  inherit (iohk-ops-lib) roles modules;

  nodes = {
    defaults = { ... }: {
      imports = [ modules.common ];
      deployment.targetEnv = targetEnv;
      nixpkgs.overlays = import ../overlays sources;
    };

    monitoring = { ... }: {
      imports = [ large roles.monitor ];
      deployment.ec2.region = "eu-central-1";
      deployment.packet.facility = "ams1";
    };

    # TODO add actual shelly nodes (use roles):
  };

in {
  network.description = "shelley-cluster";
  network.enableRollback = true;
} // nodes
