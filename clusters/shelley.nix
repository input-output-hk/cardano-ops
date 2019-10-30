{ targetEnv
, tiny, medium
, ...
}:
with (import ../nix {});
let

  inherit (lib) recursiveUpdate mapAttrs;
  inherit (iohk-ops-lib) roles modules;

  nodes = {
    defaults = {
      deployment.targetEnv = targetEnv;
      nixpkgs.overlays = import ../overlays sources;
    };

    monitoring = {
      imports = [ medium roles.monitor ];
    };

    a2 = {nodes, ...}: {
      imports = [ tiny ../roles/legacy-core.nix ];
      deployment.ec2.region = "eu-central-1";

      deployment.keys.cardano-node.keyFile = ../keys/1.sk;
      services.cardano-node-legacy.staticRoutes = [[ nodes.a1 ]];
    };

    a1 = {nodes, ...}: {
      imports = [ tiny ../roles/legacy-core.nix ];
      deployment.ec2.region = "eu-central-1";

      deployment.keys.cardano-node.keyFile = ../keys/1.sk;
      services.cardano-node-legacy.staticRoutes = [[ nodes.a2 ]];
    };

    # TODO add actual shelly nodes (use roles):
  };

in {
  network.description = "shelley-cluster";
  network.enableRollback = true;
} // nodes
