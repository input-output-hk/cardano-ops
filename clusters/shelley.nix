{ targetEnv
, tiny, medium
, ...
}:
with (import ../nix {});
let

  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap1;
  inherit (iohk-ops-lib) roles modules;

  # for now, keys need to be generated for each core nodes with:
  # for i in {1..2}; do cardano-cli --byron-legacy keygen --secret ./keys/$i.sk --no-password; done
  coreNodes = [
    {
      name = "a1";
      region = "eu-central-1";
      staticRoutes = [["a2"]];
    }
    {
      name = "a2";
      region = "eu-central-1";
      staticRoutes = [["a1"]];
    }
  ];

  relayNodes = [];

  cardanoNodes = listToAttrs (imap1 mkCoreNode coreNodes)
    // listToAttrs (map mkRelayNode relayNodes);

  otherNodes = {
    monitoring = {
      deployment.ec2.region = "eu-central-1";
      imports = [ medium roles.monitor ];
    };
  };

  nodes = mapAttrs (_: mkNode) (cardanoNodes // otherNodes);

  mkCoreNode = i: def: {
    inherit (def) name;
    value = {
      deployment.ec2.region = def.region;
      imports = [ tiny ../roles/core.nix ];
      services.cardano-node.nodeId = i;
      # imports = [ tiny (import ../roles/legacy-core.nix i) ];
      # services.cardano-node-legacy.staticRoutes = def.staticRoutes;
    };
  };

  mkRelayNode = def: {
    inherit (def) name;
    value = {
      deployment.ec2.region = def.region;
      imports = [ tiny ../roles/legacy-relay.nix ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes;
    };
  };

  mkNode = args:
    recursiveUpdate {
      deployment.targetEnv = targetEnv;
      nixpkgs.overlays = import ../overlays sources;
    } args;

in {
  network.description = "shelley-cluster";
  network.enableRollback = true;
} // nodes
