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
      imports = [ modules.common ];
      deployment.targetEnv = targetEnv;
      nixpkgs.overlays = import ../overlays sources;
    };

    monitoring = {
      imports = [ tiny roles.monitor ];
    };

    node = {
      imports = [ tiny ../roles/core.nix ];
    };

    # TODO add actual shelly nodes (use roles):
  };

in {
  network.description = "shelley-cluster";
  network.enableRollback = true;
} // nodes
